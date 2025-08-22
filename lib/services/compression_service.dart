import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

/// Compression level options
enum CompressionLevel {
  fast(1),     // Fast compression, larger size
  balanced(6), // Balanced speed/size
  maximum(9);  // Maximum compression, slower
  
  const CompressionLevel(this.level);
  final int level;
  
  String get displayName => switch (this) {
    CompressionLevel.fast => 'Fast',
    CompressionLevel.balanced => 'Balanced',
    CompressionLevel.maximum => 'Maximum',
  };
}

/// Result of a compression operation
class CompressionResult {
  final bool success;
  final String? compressedFilePath;
  final int originalSize;
  final int compressedSize;
  final Duration compressionTime;
  final String? errorMessage;
  final bool wasAlreadyCompressed;
  final List<String> sourceFiles;
  
  CompressionResult({
    required this.success,
    this.compressedFilePath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionTime,
    this.errorMessage,
    this.wasAlreadyCompressed = false,
    required this.sourceFiles,
  });
  
  /// Compression ratio as percentage (0-100)
  double get compressionRatio => 
      originalSize > 0 ? ((originalSize - compressedSize) / originalSize) * 100 : 0.0;
      
  /// Size reduction in bytes
  int get sizeReduction => originalSize - compressedSize;
  
  /// Formatted compression ratio
  String get formattedRatio => '${compressionRatio.toStringAsFixed(1)}%';
  
  /// Formatted size reduction
  String get formattedReduction => _formatBytes(sizeReduction);
  
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Service for file compression and optimization
class CompressionService {
  static final CompressionService _instance = CompressionService._internal();
  factory CompressionService() => _instance;
  CompressionService._internal();
  
  /// File extensions that are already compressed and should be skipped
  static const Set<String> _compressedExtensions = {
    // Archive formats
    '.zip', '.rar', '.7z', '.tar.gz', '.tgz', '.bz2', '.xz',
    // Image formats (lossy/compressed)
    '.jpg', '.jpeg', '.png', '.webp', '.avif', '.heic',
    // Video formats
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v',
    // Audio formats
    '.mp3', '.aac', '.ogg', '.m4a', '.wma', '.flac',
    // Document formats (already compressed)
    '.pdf', '.docx', '.xlsx', '.pptx', '.odt', '.ods', '.odp',
    // Executable and binary formats
    '.exe', '.msi', '.deb', '.dmg', '.iso',
  };
  
  /// Check if a file should be compressed based on its extension
  bool shouldCompress(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return !_compressedExtensions.contains(extension);
  }
  
  /// Get recommended compression level based on file types
  CompressionLevel getRecommendedLevel(List<String> filePaths) {
    bool hasLargeFiles = false;
    bool hasManySmallFiles = false;
    int totalFiles = filePaths.length;
    
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final size = file.lengthSync();
          if (size > 10 * 1024 * 1024) { // 10MB
            hasLargeFiles = true;
          }
        }
      } catch (e) {
        // Skip file if we can't read it
        continue;
      }
    }
    
    if (totalFiles > 50) hasManySmallFiles = true;
    
    // Recommend based on file characteristics
    if (hasLargeFiles && !hasManySmallFiles) {
      return CompressionLevel.fast; // Prioritize speed for large files
    } else if (hasManySmallFiles) {
      return CompressionLevel.maximum; // Maximum compression for many small files
    } else {
      return CompressionLevel.balanced; // Default balanced approach
    }
  }
  
  /// Compress multiple files into a single ZIP archive
  Future<CompressionResult> compressFiles({
    required List<String> filePaths,
    required String outputPath,
    CompressionLevel level = CompressionLevel.balanced,
    bool smartCompression = true,
    Function(String fileName, double progress)? onProgress,
    Function(String message)? onStatusUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      onStatusUpdate?.call('Analyzing files for compression...');
      
      // Filter files based on smart compression setting
      List<String> filesToCompress = filePaths;
      List<String> skippedFiles = [];
      
      if (smartCompression) {
        filesToCompress = [];
        for (final filePath in filePaths) {
          if (shouldCompress(filePath)) {
            filesToCompress.add(filePath);
          } else {
            skippedFiles.add(filePath);
            if (kDebugMode) {
              print('Skipping already compressed file: ${path.basename(filePath)}');
            }
          }
        }
        
        if (skippedFiles.isNotEmpty) {
          onStatusUpdate?.call('Skipped ${skippedFiles.length} pre-compressed files');
        }
      }
      
      if (filesToCompress.isEmpty) {
        // All files were already compressed
        return CompressionResult(
          success: true,
          originalSize: await _calculateTotalSize(filePaths),
          compressedSize: await _calculateTotalSize(filePaths),
          compressionTime: stopwatch.elapsed,
          wasAlreadyCompressed: true,
          sourceFiles: filePaths,
          errorMessage: 'All files are already compressed, no compression needed',
        );
      }
      
      onStatusUpdate?.call('Creating compressed archive...');
      
      final archive = Archive();
      int totalSize = 0;
      int processedFiles = 0;
      
      // Calculate total size for progress tracking
      final totalFiles = filesToCompress.length;
      
      for (final filePath in filesToCompress) {
        try {
          final file = File(filePath);
          if (!await file.exists()) {
            if (kDebugMode) {
              print('File not found, skipping: $filePath');
            }
            continue;
          }
          
          final fileName = path.basename(filePath);
          onProgress?.call(fileName, processedFiles / totalFiles);
          onStatusUpdate?.call('Compressing: $fileName');
          
          final bytes = await file.readAsBytes();
          totalSize += bytes.length;
          
          // Create archive file with compression
          final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
          // Note: Compression level is set in the encoder, not per file
          
          archive.addFile(archiveFile);
          processedFiles++;
          
          if (kDebugMode) {
            print('Added to archive: $fileName (${bytes.length} bytes)');
          }
          
        } catch (e) {
          if (kDebugMode) {
            print('Error adding file to archive: $filePath - $e');
          }
          continue;
        }
      }
      
      if (archive.files.isEmpty) {
        return CompressionResult(
          success: false,
          originalSize: totalSize,
          compressedSize: 0,
          compressionTime: stopwatch.elapsed,
          errorMessage: 'No files could be added to the archive',
          sourceFiles: filePaths,
        );
      }
      
      onStatusUpdate?.call('Writing compressed archive...');
      
      // Encode the archive
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      
      if (zipData == null) {
        return CompressionResult(
          success: false,
          originalSize: totalSize,
          compressedSize: 0,
          compressionTime: stopwatch.elapsed,
          errorMessage: 'Failed to encode ZIP archive',
          sourceFiles: filePaths,
        );
      }
      
      // Write to output file
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipData);
      
      final compressedSize = zipData.length;
      stopwatch.stop();
      
      onStatusUpdate?.call('Compression completed successfully');
      onProgress?.call('Completed', 1.0);
      
      if (kDebugMode) {
        final ratio = totalSize > 0 ? ((totalSize - compressedSize) / totalSize * 100) : 0;
        print('Compression completed:');
        print('  Original size: ${_formatBytes(totalSize)}');
        print('  Compressed size: ${_formatBytes(compressedSize)}');
        print('  Compression ratio: ${ratio.toStringAsFixed(1)}%');
        print('  Time taken: ${stopwatch.elapsed.inSeconds}s');
      }
      
      return CompressionResult(
        success: true,
        compressedFilePath: outputPath,
        originalSize: totalSize,
        compressedSize: compressedSize,
        compressionTime: stopwatch.elapsed,
        sourceFiles: filePaths,
      );
      
    } catch (e) {
      stopwatch.stop();
      
      if (kDebugMode) {
        print('Compression error: $e');
      }
      
      return CompressionResult(
        success: false,
        originalSize: await _calculateTotalSize(filePaths),
        compressedSize: 0,
        compressionTime: stopwatch.elapsed,
        errorMessage: e.toString(),
        sourceFiles: filePaths,
      );
    }
  }
  
  /// Compress a single folder recursively
  Future<CompressionResult> compressFolder({
    required String folderPath,
    required String outputPath,
    CompressionLevel level = CompressionLevel.balanced,
    bool smartCompression = true,
    Function(String fileName, double progress)? onProgress,
    Function(String message)? onStatusUpdate,
  }) async {
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        return CompressionResult(
          success: false,
          originalSize: 0,
          compressedSize: 0,
          compressionTime: Duration.zero,
          errorMessage: 'Folder does not exist: $folderPath',
          sourceFiles: [folderPath],
        );
      }
      
      onStatusUpdate?.call('Scanning folder for files...');
      
      // Get all files in the folder recursively
      final List<String> filePaths = [];
      await for (final entity in folder.list(recursive: true)) {
        if (entity is File) {
          filePaths.add(entity.path);
        }
      }
      
      if (filePaths.isEmpty) {
        return CompressionResult(
          success: false,
          originalSize: 0,
          compressedSize: 0,
          compressionTime: Duration.zero,
          errorMessage: 'No files found in folder',
          sourceFiles: [folderPath],
        );
      }
      
      onStatusUpdate?.call('Found ${filePaths.length} files to process');
      
      // Use the regular file compression method
      return await compressFiles(
        filePaths: filePaths,
        outputPath: outputPath,
        level: level,
        smartCompression: smartCompression,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );
      
    } catch (e) {
      return CompressionResult(
        success: false,
        originalSize: 0,
        compressedSize: 0,
        compressionTime: Duration.zero,
        errorMessage: e.toString(),
        sourceFiles: [folderPath],
      );
    }
  }
  
  /// Calculate total size of files
  Future<int> _calculateTotalSize(List<String> filePaths) async {
    int totalSize = 0;
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (e) {
        // Skip files we can't read
        continue;
      }
    }
    return totalSize;
  }
  
  /// Generate a unique output filename for compressed archive
  String generateCompressedFileName(List<String> filePaths, {String? baseName}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    if (baseName != null) {
      return '${baseName}_compressed_$timestamp.zip';
    }
    
    if (filePaths.length == 1) {
      final fileName = path.basenameWithoutExtension(filePaths.first);
      return '${fileName}_compressed_$timestamp.zip';
    } else {
      return 'files_compressed_$timestamp.zip';
    }
  }
  
  /// Get compression statistics for a set of files
  Future<CompressionAnalysis> analyzeFiles(List<String> filePaths) async {
    int compressibleSize = 0;
    int alreadyCompressedSize = 0;
    int compressibleCount = 0;
    int alreadyCompressedCount = 0;
    
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final size = await file.length();
          if (shouldCompress(filePath)) {
            compressibleSize += size;
            compressibleCount++;
          } else {
            alreadyCompressedSize += size;
            alreadyCompressedCount++;
          }
        }
      } catch (e) {
        // Skip files we can't read
        continue;
      }
    }
    
    return CompressionAnalysis(
      totalFiles: filePaths.length,
      compressibleFiles: compressibleCount,
      alreadyCompressedFiles: alreadyCompressedCount,
      compressibleSize: compressibleSize,
      alreadyCompressedSize: alreadyCompressedSize,
    );
  }
  
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Analysis result for compression potential
class CompressionAnalysis {
  final int totalFiles;
  final int compressibleFiles;
  final int alreadyCompressedFiles;
  final int compressibleSize;
  final int alreadyCompressedSize;
  
  CompressionAnalysis({
    required this.totalFiles,
    required this.compressibleFiles,
    required this.alreadyCompressedFiles,
    required this.compressibleSize,
    required this.alreadyCompressedSize,
  });
  
  int get totalSize => compressibleSize + alreadyCompressedSize;
  double get compressiblePercentage => 
      totalSize > 0 ? (compressibleSize / totalSize) * 100 : 0.0;
      
  String get formattedCompressibleSize => CompressionService._formatBytes(compressibleSize);
  String get formattedAlreadyCompressedSize => CompressionService._formatBytes(alreadyCompressedSize);
  String get formattedTotalSize => CompressionService._formatBytes(totalSize);
}
