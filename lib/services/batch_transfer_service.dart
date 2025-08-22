import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'sender_service.dart';
import 'compression_service.dart';
import '../models/peer.dart';
import '../utils/file_helper.dart';
import 'package:path/path.dart' as path;

/// Model for a file in a batch transfer
class BatchFile {
  final String path;
  final String name;
  final int size;
  final String id;
  
  BatchFileStatus status;
  double progress;
  String? errorMessage;
  
  BatchFile({
    required this.path,
    required this.name,
    required this.size,
    required this.id,
    this.status = BatchFileStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
  });
  
  String get formattedSize => _formatBytes(size);
  
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Status of a file in batch transfer
enum BatchFileStatus {
  queued,
  transferring,
  completed,
  failed,
  cancelled,
}

/// Model for a batch transfer operation
class BatchTransfer {
  final String id;
  final Peer targetPeer;
  final List<BatchFile> files;
  final DateTime createdAt;
  
  BatchTransferStatus status;
  int completedFiles;
  int failedFiles;
  DateTime? startedAt;
  DateTime? completedAt;
  
  BatchTransfer({
    required this.id,
    required this.targetPeer,
    required this.files,
    required this.createdAt,
    this.status = BatchTransferStatus.queued,
    this.completedFiles = 0,
    this.failedFiles = 0,
    this.startedAt,
    this.completedAt,
  });
  
  int get totalFiles => files.length;
  int get remainingFiles => totalFiles - completedFiles - failedFiles;
  double get overallProgress => totalFiles > 0 ? (completedFiles + failedFiles) / totalFiles : 0.0;
  bool get isActive => status == BatchTransferStatus.transferring;
  bool get isCompleted => status == BatchTransferStatus.completed || status == BatchTransferStatus.failed;
  
  Duration? get elapsedTime {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }
}

/// Status of a batch transfer
enum BatchTransferStatus {
  queued,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}

/// Service for managing batch file transfers
class BatchTransferService {
  static final BatchTransferService _instance = BatchTransferService._internal();
  factory BatchTransferService() => _instance;
  BatchTransferService._internal();

  final SenderService _senderService = SenderService();
  final CompressionService _compressionService = CompressionService();
  
  // Active transfers
  final Map<String, BatchTransfer> _activeTransfers = {};
  final Map<String, StreamController<BatchTransfer>> _transferControllers = {};
  
  // Concurrent transfer settings
  int _maxConcurrentTransfers = 3;
  int _currentActiveTransfers = 0;
  
  /// Stream for all transfer updates
  final StreamController<List<BatchTransfer>> _allTransfersController = 
      StreamController<List<BatchTransfer>>.broadcast();
  Stream<List<BatchTransfer>> get allTransfersStream => _allTransfersController.stream;
  
  /// Get stream for a specific transfer
  Stream<BatchTransfer>? getTransferStream(String transferId) {
    return _transferControllers[transferId]?.stream;
  }
  
  /// Create files from file paths (including folder expansion)
  Future<List<BatchFile>> createBatchFilesFromPaths(List<String> filePaths) async {
    final List<BatchFile> batchFiles = [];
    
    for (final path in filePaths) {
      final entity = FileSystemEntity.typeSync(path);
      
      if (entity == FileSystemEntityType.file) {
        // Single file
        final file = File(path);
        if (await file.exists()) {
          final stat = await file.stat();
          batchFiles.add(BatchFile(
            id: '${path}_${DateTime.now().millisecondsSinceEpoch}',
            path: path,
            name: file.path.split(Platform.pathSeparator).last,
            size: stat.size,
          ));
        }
      } else if (entity == FileSystemEntityType.directory) {
        // Folder - recursively add all files
        final directory = Directory(path);
        if (await directory.exists()) {
          final files = await _getAllFilesFromDirectory(directory);
          batchFiles.addAll(files);
        }
      }
    }
    
    return batchFiles;
  }
  
  /// Recursively get all files from a directory
  Future<List<BatchFile>> _getAllFilesFromDirectory(Directory directory) async {
    final List<BatchFile> files = [];
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(BatchFile(
            id: '${entity.path}_${DateTime.now().millisecondsSinceEpoch}',
            path: entity.path,
            name: entity.path.split(Platform.pathSeparator).last,
            size: stat.size,
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading directory ${directory.path}: $e');
      }
    }
    
    return files;
  }
  
  /// Start a batch transfer with optional compression
  Future<String> startBatchTransfer({
    required List<BatchFile> files,
    required Peer targetPeer,
    bool useCompression = false,
    CompressionLevel compressionLevel = CompressionLevel.balanced,
    bool smartCompression = true,
  }) async {
    if (files.isEmpty) {
      throw Exception('No files provided for batch transfer');
    }
    
    final transferId = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    final batchTransfer = BatchTransfer(
      id: transferId,
      targetPeer: targetPeer,
      files: files,
      createdAt: DateTime.now(),
    );
    
    // Create stream controller for this transfer
    _transferControllers[transferId] = StreamController<BatchTransfer>.broadcast();
    
    // Add to active transfers
    _activeTransfers[transferId] = batchTransfer;
    _notifyAllTransfersUpdate();
    
    // Start the transfer process
    _processBatchTransfer(
      transferId,
      useCompression: useCompression,
      compressionLevel: compressionLevel,
      smartCompression: smartCompression,
    );
    
    return transferId;
  }
  
  /// Process a batch transfer
  Future<void> _processBatchTransfer(
    String transferId, {
    bool useCompression = false,
    CompressionLevel compressionLevel = CompressionLevel.balanced,
    bool smartCompression = true,
  }) async {
    final batchTransfer = _activeTransfers[transferId];
    if (batchTransfer == null) return;
    
    try {
      // Update status to transferring
      batchTransfer.status = BatchTransferStatus.transferring;
      batchTransfer.startedAt = DateTime.now();
      _notifyTransferUpdate(transferId);
      
      // Check if we should compress multiple files
      if (useCompression && batchTransfer.files.length > 1) {
        await _processCompressedBatch(
          batchTransfer, 
          compressionLevel, 
          smartCompression,
        );
      } else {
        // Process files individually with concurrency control
        await _processFilesWithConcurrency(batchTransfer);
      }
      
      // Update final status
      if (batchTransfer.failedFiles == 0) {
        batchTransfer.status = BatchTransferStatus.completed;
      } else if (batchTransfer.completedFiles == 0) {
        batchTransfer.status = BatchTransferStatus.failed;
      } else {
        batchTransfer.status = BatchTransferStatus.completed; // Partial success
      }
      
      batchTransfer.completedAt = DateTime.now();
      _notifyTransferUpdate(transferId);
      
    } catch (e) {
      batchTransfer.status = BatchTransferStatus.failed;
      batchTransfer.completedAt = DateTime.now();
      _notifyTransferUpdate(transferId);
      
      if (kDebugMode) {
        print('Batch transfer failed: $e');
      }
    }
  }
  
  /// Process compressed batch transfer
  Future<void> _processCompressedBatch(
    BatchTransfer batchTransfer,
    CompressionLevel compressionLevel,
    bool smartCompression,
  ) async {
    try {
      // Update all files to transferring status
      for (final file in batchTransfer.files) {
        file.status = BatchFileStatus.transferring;
      }
      _notifyTransferUpdate(batchTransfer.id);
      
      // Create temporary directory for compression
      final tempDir = await Directory.systemTemp.createTemp('stork_compression_');
      
      try {
        // Generate compressed file name
        final compressedFileName = _compressionService.generateCompressedFileName(
          batchTransfer.files.map((f) => f.path).toList(),
          baseName: 'batch_${batchTransfer.id}',
        );
        
        final compressedPath = path.join(tempDir.path, compressedFileName);
        
        // Compress files
        final compressionResult = await _compressionService.compressFiles(
          filePaths: batchTransfer.files.map((f) => f.path).toList(),
          outputPath: compressedPath,
          level: compressionLevel,
          smartCompression: smartCompression,
          onProgress: (fileName, progress) {
            // Update progress for all files proportionally during compression
            final compressionProgress = progress * 0.5; // First half is compression
            for (final file in batchTransfer.files) {
              file.progress = compressionProgress;
            }
            _notifyTransferUpdate(batchTransfer.id);
          },
          onStatusUpdate: (message) {
            if (kDebugMode) {
              print('Compression: $message');
            }
          },
        );
        
        if (compressionResult.success && compressionResult.compressedFilePath != null) {
          // Send the compressed file
          final success = await _senderService.sendFile(
            filePath: compressionResult.compressedFilePath!,
            targetIp: batchTransfer.targetPeer.host,
            targetPort: batchTransfer.targetPeer.port,
            onProgress: (sent, total) {
              // Second half is transfer progress
              final transferProgress = 0.5 + (total > 0 ? (sent / total) * 0.5 : 0.0);
              for (final file in batchTransfer.files) {
                file.progress = transferProgress;
              }
              _notifyTransferUpdate(batchTransfer.id);
            },
          );
          
          // Update all file statuses based on transfer result
          if (success) {
            for (final file in batchTransfer.files) {
              file.status = BatchFileStatus.completed;
              file.progress = 1.0;
            }
            batchTransfer.completedFiles = batchTransfer.files.length;
          } else {
            for (final file in batchTransfer.files) {
              file.status = BatchFileStatus.failed;
              file.errorMessage = 'Compressed transfer failed';
            }
            batchTransfer.failedFiles = batchTransfer.files.length;
          }
          
          if (kDebugMode) {
            print('Compressed batch transfer completed:');
            print('  Original size: ${compressionResult.originalSize} bytes');
            print('  Compressed size: ${compressionResult.compressedSize} bytes');
            print('  Compression ratio: ${compressionResult.formattedRatio}');
            print('  Transfer success: $success');
          }
          
        } else {
          // Compression failed, mark all files as failed
          for (final file in batchTransfer.files) {
            file.status = BatchFileStatus.failed;
            file.errorMessage = compressionResult.errorMessage ?? 'Compression failed';
          }
          batchTransfer.failedFiles = batchTransfer.files.length;
        }
        
      } finally {
        // Clean up temporary directory
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to clean up temporary directory: $e');
          }
        }
      }
      
    } catch (e) {
      // Handle any unexpected errors
      for (final file in batchTransfer.files) {
        file.status = BatchFileStatus.failed;
        file.errorMessage = 'Compression process failed: $e';
      }
      batchTransfer.failedFiles = batchTransfer.files.length;
      
      if (kDebugMode) {
        print('Compressed batch transfer error: $e');
      }
    }
    
    _notifyTransferUpdate(batchTransfer.id);
  }
  
  /// Process files with concurrency control
  Future<void> _processFilesWithConcurrency(BatchTransfer batchTransfer) async {
    final semaphore = Semaphore(_maxConcurrentTransfers);
    final futures = <Future>[];
    
    for (final file in batchTransfer.files) {
      if (file.status == BatchFileStatus.cancelled) continue;
      
      final future = semaphore.acquire(() async {
        await _transferSingleFile(batchTransfer, file);
      });
      
      futures.add(future);
    }
    
    await Future.wait(futures);
  }
  
  /// Transfer a single file in the batch
  Future<void> _transferSingleFile(BatchTransfer batchTransfer, BatchFile file) async {
    try {
      // Update file status
      file.status = BatchFileStatus.transferring;
      _notifyTransferUpdate(batchTransfer.id);
      
      // Send the file
      final success = await _senderService.sendFile(
        filePath: file.path,
        targetIp: batchTransfer.targetPeer.host,
        targetPort: batchTransfer.targetPeer.port,
        onProgress: (sent, total) {
          file.progress = total > 0 ? sent / total : 0.0;
          _notifyTransferUpdate(batchTransfer.id);
        },
      );
      
      // Update file and batch status
      if (success) {
        file.status = BatchFileStatus.completed;
        file.progress = 1.0;
        batchTransfer.completedFiles++;
      } else {
        file.status = BatchFileStatus.failed;
        file.errorMessage = 'Transfer failed';
        batchTransfer.failedFiles++;
      }
      
      _notifyTransferUpdate(batchTransfer.id);
      
    } catch (e) {
      file.status = BatchFileStatus.failed;
      file.errorMessage = e.toString();
      batchTransfer.failedFiles++;
      _notifyTransferUpdate(batchTransfer.id);
      
      if (kDebugMode) {
        print('File transfer failed: ${file.name} - $e');
      }
    }
  }
  
  /// Cancel a batch transfer
  Future<void> cancelBatchTransfer(String transferId) async {
    final batchTransfer = _activeTransfers[transferId];
    if (batchTransfer == null) return;
    
    // Update status
    batchTransfer.status = BatchTransferStatus.cancelled;
    
    // Cancel all queued files
    for (final file in batchTransfer.files) {
      if (file.status == BatchFileStatus.queued) {
        file.status = BatchFileStatus.cancelled;
      }
    }
    
    _notifyTransferUpdate(transferId);
  }
  
  /// Cancel a specific file in a batch
  Future<void> cancelFile(String transferId, String fileId) async {
    final batchTransfer = _activeTransfers[transferId];
    if (batchTransfer == null) return;
    
    final file = batchTransfer.files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('File not found'),
    );
    
    if (file.status == BatchFileStatus.queued) {
      file.status = BatchFileStatus.cancelled;
      _notifyTransferUpdate(transferId);
    }
  }
  
  /// Retry a failed file
  Future<void> retryFile(String transferId, String fileId) async {
    final batchTransfer = _activeTransfers[transferId];
    if (batchTransfer == null) return;
    
    final file = batchTransfer.files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('File not found'),
    );
    
    if (file.status == BatchFileStatus.failed) {
      file.status = BatchFileStatus.queued;
      file.progress = 0.0;
      file.errorMessage = null;
      batchTransfer.failedFiles--;
      
      _notifyTransferUpdate(transferId);
      
      // Re-process this file
      _transferSingleFile(batchTransfer, file);
    }
  }
  
  /// Get all active transfers
  List<BatchTransfer> getAllTransfers() {
    return _activeTransfers.values.toList();
  }
  
  /// Get a specific transfer
  BatchTransfer? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }
  
  /// Remove completed transfers from memory
  void cleanupCompletedTransfers() {
    final completedIds = _activeTransfers.entries
        .where((entry) => entry.value.isCompleted)
        .map((entry) => entry.key)
        .toList();
    
    for (final id in completedIds) {
      _activeTransfers.remove(id);
      _transferControllers[id]?.close();
      _transferControllers.remove(id);
    }
    
    _notifyAllTransfersUpdate();
  }
  
  /// Set maximum concurrent transfers
  void setMaxConcurrentTransfers(int max) {
    _maxConcurrentTransfers = max.clamp(1, 10);
  }
  
  /// Notify transfer update
  void _notifyTransferUpdate(String transferId) {
    final batchTransfer = _activeTransfers[transferId];
    if (batchTransfer != null) {
      _transferControllers[transferId]?.add(batchTransfer);
    }
    _notifyAllTransfersUpdate();
  }
  
  /// Notify all transfers update
  void _notifyAllTransfersUpdate() {
    _allTransfersController.add(getAllTransfers());
  }
  
  /// Dispose the service
  void dispose() {
    for (final controller in _transferControllers.values) {
      controller.close();
    }
    _transferControllers.clear();
    _allTransfersController.close();
    _activeTransfers.clear();
  }
}

/// Simple semaphore implementation for concurrency control
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer> _waitQueue = Queue<Completer>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<T> acquire<T>(Future<T> Function() operation) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
