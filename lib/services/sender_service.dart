import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'large_file_transfer_service.dart';

class SenderService {
  final LargeFileTransferService _largeFileService = LargeFileTransferService();
  
  /// Send a file to the target IP address and port
  /// Automatically chooses between regular and large file transfer based on file size
  Future<bool> sendFile({
    required String filePath,
    required String targetIp,
    required int targetPort,
    void Function(int sentBytes, int totalBytes)? onProgress,
    Function(String message)? onStatusUpdate,
  }) async {
    try {
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          print('❌ File not found: $filePath');
        }
        return false;
      }

      final fileSize = await file.length();
      
      // Use large file transfer for files > 10MB
      if (LargeFileTransferService.shouldUseLargeFileTransfer(fileSize)) {
        if (kDebugMode) {
          print('🚀 Using large file transfer for file: ${_formatBytes(fileSize)}');
        }
        
        return await _largeFileService.sendLargeFile(
          filePath: filePath,
          targetIp: targetIp,
          targetPort: targetPort,
          onProgress: onProgress != null 
              ? (sent, total, speed) => onProgress(sent, total)
              : null,
          onStatusUpdate: onStatusUpdate,
        );
      } else {
        // Use regular transfer for smaller files
        return await _sendRegularFile(
          filePath: filePath,
          targetIp: targetIp,
          targetPort: targetPort,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in sendFile: $e');
      }
      return false;
    }
  }
  
  /// Send a regular file using the original method
  Future<bool> _sendRegularFile({
    required String filePath,
    required String targetIp,
    required int targetPort,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    try {
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File not found: $filePath');
        return false;
      }

      // Extract filename from path
      final filename = file.path.split(Platform.pathSeparator).last;
      print('📤 Sending file: $filename to $targetIp:$targetPort');

      // Create the target URL
      final url = Uri.parse('http://$targetIp:$targetPort/send');

      // Create a streamed request to handle large files efficiently
      final request = http.StreamedRequest('POST', url);
      
      // Set headers
      request.headers.addAll({
        'Content-Type': 'application/octet-stream',
        'X-Filename': filename,
      });

      // Get file size for progress tracking
      final fileSize = await file.length();
      request.contentLength = fileSize;

      print('📁 File size: ${_formatBytes(fileSize)}');

      // Stream the file content with progress
      int sent = 0;
      final fileStream = file.openRead();
      fileStream.listen(
        (chunk) {
          sent += chunk.length;
          if (onProgress != null) {
            onProgress(sent, fileSize);
          }
          request.sink.add(chunk);
        },
        onDone: () {
          request.sink.close();
        },
        onError: (error) {
          print('❌ Error reading file: $error');
          request.sink.close();
        },
      );

      // Send the request and wait for response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ File sent successfully: ${responseData['filename']}');
        // Ensure final 100% progress
        if (onProgress != null) {
          onProgress(fileSize, fileSize);
        }
        return true;
      } else {
        print('❌ Send failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending file: $e');
      return false;
    }
  }

  /// Check if target device is reachable
  Future<Map<String, dynamic>?> getDeviceInfo({
    required String targetIp,
    required int targetPort,
  }) async {
    try {
      final url = Uri.parse('http://$targetIp:$targetPort/info');
      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Device info request failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting device info: $e');
      return null;
    }
  }

  /// Format bytes into human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
