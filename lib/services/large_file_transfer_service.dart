import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Service for optimized large file transfers with chunking and resume capability
class LargeFileTransferService {
  static const int defaultChunkSize = 1024 * 1024; // 1MB chunks
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  /// Transfer a large file with chunking and resume capability
  Future<bool> sendLargeFile({
    required String filePath,
    required String targetIp,
    required int targetPort,
    int chunkSize = defaultChunkSize,
    Function(int sent, int total, double speed)? onProgress,
    Function(String message)? onStatusUpdate,
    VoidCallback? onPaused,
    VoidCallback? onResumed,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }

      final fileSize = await file.length();
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      if (kDebugMode) {
        print('🚀 Starting large file transfer: $fileName (${_formatBytes(fileSize)})');
      }
      
      onStatusUpdate?.call('Preparing large file transfer...');

      // Calculate file hash for integrity verification
      final fileHash = await _calculateFileHash(file);
      
      // Initialize transfer session
      final transferId = await _initializeTransfer(
        targetIp: targetIp,
        targetPort: targetPort,
        fileName: fileName,
        fileSize: fileSize,
        fileHash: fileHash,
        chunkSize: chunkSize,
      );

      if (transferId == null) {
        throw Exception('Failed to initialize transfer session');
      }

      onStatusUpdate?.call('Transfer session initialized');

      // Check for existing partial transfer
      final resumeOffset = await _checkResumeCapability(
        targetIp: targetIp,
        targetPort: targetPort,
        transferId: transferId,
      );

      if (resumeOffset > 0) {
        onStatusUpdate?.call('Resuming from ${_formatBytes(resumeOffset)}');
        if (kDebugMode) {
          print('📍 Resuming transfer from offset: ${_formatBytes(resumeOffset)}');
        }
      }

      // Send file in chunks
      return await _sendFileChunks(
        file: file,
        targetIp: targetIp,
        targetPort: targetPort,
        transferId: transferId,
        chunkSize: chunkSize,
        startOffset: resumeOffset,
        totalSize: fileSize,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );

    } catch (e) {
      if (kDebugMode) {
        print('❌ Large file transfer error: $e');
      }
      onStatusUpdate?.call('Transfer failed: $e');
      return false;
    }
  }

  /// Initialize transfer session with the receiver
  Future<String?> _initializeTransfer({
    required String targetIp,
    required int targetPort,
    required String fileName,
    required int fileSize,
    required String fileHash,
    required int chunkSize,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://$targetIp:$targetPort/init_large_transfer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fileName': fileName,
          'fileSize': fileSize,
          'fileHash': fileHash,
          'chunkSize': chunkSize,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['transferId'] as String?;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize transfer: $e');
      }
      return null;
    }
  }

  /// Check if transfer can be resumed
  Future<int> _checkResumeCapability({
    required String targetIp,
    required int targetPort,
    required String transferId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('http://$targetIp:$targetPort/check_resume/$transferId'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['resumeOffset'] as int? ?? 0;
      }
      
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('Resume check failed: $e');
      }
      return 0;
    }
  }

  /// Send file in chunks with progress tracking
  Future<bool> _sendFileChunks({
    required File file,
    required String targetIp,
    required int targetPort,
    required String transferId,
    required int chunkSize,
    required int startOffset,
    required int totalSize,
    Function(int sent, int total, double speed)? onProgress,
    Function(String message)? onStatusUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();
    int bytesSent = startOffset;
    int chunkNumber = startOffset ~/ chunkSize;

    try {
      final randomAccessFile = await file.open(mode: FileMode.read);
      await randomAccessFile.setPosition(startOffset);

      while (bytesSent < totalSize) {
        // Calculate current chunk size (might be smaller for the last chunk)
        final currentChunkSize = (bytesSent + chunkSize > totalSize) 
            ? totalSize - bytesSent 
            : chunkSize;

        // Read chunk data
        final chunkData = await randomAccessFile.read(currentChunkSize);
        
        if (chunkData.isEmpty) {
          break;
        }

        // Send chunk with retry logic
        final chunkSent = await _sendChunkWithRetry(
          targetIp: targetIp,
          targetPort: targetPort,
          transferId: transferId,
          chunkNumber: chunkNumber,
          chunkData: chunkData,
          offset: bytesSent,
        );

        if (!chunkSent) {
          await randomAccessFile.close();
          return false;
        }

        bytesSent += chunkData.length;
        chunkNumber++;

        // Calculate transfer speed
        final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
        final speed = elapsedSeconds > 0 ? (bytesSent - startOffset) / elapsedSeconds : 0.0;

        // Update progress
        onProgress?.call(bytesSent, totalSize, speed);
        
        if (chunkNumber % 10 == 0) { // Update status every 10 chunks
          onStatusUpdate?.call('Sent ${_formatBytes(bytesSent)} of ${_formatBytes(totalSize)} (${_formatSpeed(speed)})');
        }
      }

      await randomAccessFile.close();

      // Finalize transfer
      final finalized = await _finalizeTransfer(
        targetIp: targetIp,
        targetPort: targetPort,
        transferId: transferId,
      );

        if (finalized) {
          onStatusUpdate?.call('Transfer completed successfully');
          if (kDebugMode) {
            final totalTime = stopwatch.elapsedMilliseconds / 1000.0;
            final avgSpeed = totalTime > 0 ? totalSize / totalTime : 0.0;
            print('✅ Large file transfer completed in ${totalTime.toStringAsFixed(1)}s (avg: ${_formatSpeed(avgSpeed)})');
          }
        }

      return finalized;

    } catch (e) {
      if (kDebugMode) {
        print('Chunk sending error: $e');
      }
      onStatusUpdate?.call('Transfer error: $e');
      return false;
    }
  }

  /// Send a single chunk with retry logic
  Future<bool> _sendChunkWithRetry({
    required String targetIp,
    required int targetPort,
    required String transferId,
    required int chunkNumber,
    required Uint8List chunkData,
    required int offset,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Calculate chunk hash for verification
        final chunkHash = sha256.convert(chunkData).toString();

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://$targetIp:$targetPort/send_chunk'),
        );

        request.fields['transferId'] = transferId;
        request.fields['chunkNumber'] = chunkNumber.toString();
        request.fields['offset'] = offset.toString();
        request.fields['chunkHash'] = chunkHash;

        request.files.add(
          http.MultipartFile.fromBytes(
            'chunk',
            chunkData,
            filename: 'chunk_$chunkNumber',
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return true;
        } else {
          throw http.ClientException('HTTP ${response.statusCode}: ${response.body}');
        }

      } catch (e) {
        if (kDebugMode) {
          print('Chunk $chunkNumber send attempt $attempt failed: $e');
        }

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt); // Exponential backoff
        } else {
          if (kDebugMode) {
            print('Failed to send chunk $chunkNumber after $maxRetries attempts');
          }
          return false;
        }
      }
    }

    return false;
  }

  /// Finalize the transfer and verify integrity
  Future<bool> _finalizeTransfer({
    required String targetIp,
    required int targetPort,
    required String transferId,
  }) async {
    try {
      if (kDebugMode) {
        print('🏁 Finalizing transfer: $transferId');
      }
      
      final response = await http.post(
        Uri.parse('http://$targetIp:$targetPort/finalize_transfer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'transferId': transferId,
        }),
      );

      if (kDebugMode) {
        print('📄 Finalization response:');
        print('   - Status code: ${response.statusCode}');
        print('   - Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final success = responseData['success'] == true;
        
        if (kDebugMode) {
          print('✅ Transfer finalized successfully: $success');
        }
        
        return success;
      } else {
        if (kDebugMode) {
          print('❌ Finalization failed with status ${response.statusCode}: ${response.body}');
        }
        return false;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Transfer finalization error: $e');
      }
      return false;
    }
  }

  /// Calculate SHA-256 hash of file for integrity verification
  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final hash = digest.toString();
    
    if (kDebugMode) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      print('🔐 Calculated hash for $fileName:');
      print('   - File size: ${bytes.length}');
      print('   - Hash: $hash');
    }
    
    return hash;
  }

  /// Format bytes for human-readable display
  String _formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format transfer speed for display
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  /// Get optimal chunk size based on file size
  static int getOptimalChunkSize(int fileSize) {
    if (fileSize < 10 * 1024 * 1024) return 256 * 1024; // 256KB for small files
    if (fileSize < 100 * 1024 * 1024) return 1024 * 1024; // 1MB for medium files
    if (fileSize < 1024 * 1024 * 1024) return 2 * 1024 * 1024; // 2MB for large files
    return 4 * 1024 * 1024; // 4MB for very large files
  }

  /// Check if file should use large file transfer
  static bool shouldUseLargeFileTransfer(int fileSize) {
    return fileSize > 10 * 1024 * 1024; // Files larger than 10MB
  }
}

/// Data class for tracking large file transfer progress
class LargeFileTransferProgress {
  final String transferId;
  final String fileName;
  final int totalSize;
  final int transferredSize;
  final double progress;
  final double speed; // bytes per second
  final String status;
  final DateTime lastUpdate;
  final int chunksCompleted;
  final int totalChunks;
  final Duration estimatedTimeRemaining;

  LargeFileTransferProgress({
    required this.transferId,
    required this.fileName,
    required this.totalSize,
    required this.transferredSize,
    required this.progress,
    required this.speed,
    required this.status,
    required this.lastUpdate,
    required this.chunksCompleted,
    required this.totalChunks,
    required this.estimatedTimeRemaining,
  });

  String get formattedSize => _formatBytes(totalSize);
  String get formattedTransferred => _formatBytes(transferredSize);
  String get formattedSpeed => _formatSpeed(speed);
  String get formattedTimeRemaining => _formatDuration(estimatedTimeRemaining);

  static String _formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
