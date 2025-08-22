import 'dart:io';

class FileHelper {
  /// Get a safe downloads directory for the current platform
  static Future<Directory> getDownloadsDirectory() async {
    Directory downloadsDir;
    
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        downloadsDir = Directory('$userProfile\\Downloads\\LocalP2P');
      } else {
        downloadsDir = Directory('downloads');
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        downloadsDir = Directory('$home/Downloads/LocalP2P');
      } else {
        downloadsDir = Directory('downloads');
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        downloadsDir = Directory('$home/Downloads/LocalP2P');
      } else {
        downloadsDir = Directory('downloads');
      }
    } else {
      downloadsDir = Directory('downloads');
    }

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    return downloadsDir;
  }

  /// Generate a safe filename to avoid conflicts
  static Future<String> getSafeFileName(String originalName, Directory directory) async {
    String fileName = originalName;
    String baseName = fileName;
    String extension = '';
    
    // Split name and extension
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot != -1) {
      baseName = fileName.substring(0, lastDot);
      extension = fileName.substring(lastDot);
    }

    int counter = 1;
    while (await File('${directory.path}${Platform.pathSeparator}$fileName').exists()) {
      fileName = '${baseName}_$counter$extension';
      counter++;
    }

    return fileName;
  }

  /// Simple file size comparison for basic integrity check
  static Future<String> calculateFileInfo(String filePath) async {
    final file = File(filePath);
    final size = await file.length();
    final modified = await file.lastModified();
    return '$size-${modified.millisecondsSinceEpoch}';
  }

  /// Verify file integrity by comparing size and basic content
  static Future<bool> verifyFileIntegrity(String originalPath, String receivedPath) async {
    try {
      final originalFile = File(originalPath);
      final receivedFile = File(receivedPath);
      
      // Check file sizes first
      final originalSize = await originalFile.length();
      final receivedSize = await receivedFile.length();
      
      if (originalSize != receivedSize) {
        return false;
      }
      
      // For small files, compare content directly
      if (originalSize < 1024 * 1024) { // Less than 1MB
        final originalContent = await originalFile.readAsBytes();
        final receivedContent = await receivedFile.readAsBytes();
        
        if (originalContent.length != receivedContent.length) {
          return false;
        }
        
        for (int i = 0; i < originalContent.length; i++) {
          if (originalContent[i] != receivedContent[i]) {
            return false;
          }
        }
      }
      
      return true;
    } catch (e) {
      print('⚠️ Error verifying file integrity: $e');
      return false;
    }
  }

  /// Get human-readable file size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get MIME type from file extension (basic implementation)
  static String getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'txt':
        return 'text/plain';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'zip':
        return 'application/zip';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      default:
        return 'application/octet-stream';
    }
  }

  /// Check if file is safe to transfer (basic security check)
  static bool isSafeFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    // Blocked extensions (add more as needed)
    final blockedExtensions = [
      'exe', 'bat', 'cmd', 'com', 'scr', 'pif', 'msi', 'app',
      'deb', 'rpm', 'dmg', 'pkg', 'run', 'bin', 'sh', 'ps1'
    ];
    
    return !blockedExtensions.contains(extension);
  }

  /// Create a temporary file for testing
  static Future<File> createTestFile(String name, String content) async {
    final file = File(name);
    await file.writeAsString(content);
    return file;
  }

  /// Clean up temporary test files
  static Future<void> cleanupTestFiles(List<String> fileNames) async {
    for (final fileName in fileNames) {
      try {
        final file = File(fileName);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('⚠️ Could not delete test file $fileName: $e');
      }
    }
  }
}
