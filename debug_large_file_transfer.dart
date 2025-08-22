import 'dart:io';
import 'dart:isolate';
import 'lib/services/large_file_transfer_service.dart';
import 'lib/services/receiver_service.dart';
import 'package:crypto/crypto.dart';

void main() async {
  print('🚀 DEBUG: Large File Transfer Hash Verification');
  print('=' * 60);
  
  // Test file to use
  final testFile = File('test_files/large_test_file.bin');
  if (!await testFile.exists()) {
    print('❌ Test file not found: ${testFile.path}');
    return;
  }
  
  final fileSize = await testFile.length();
  print('📄 Test file: ${testFile.path}');
  print('📊 File size: ${_formatBytes(fileSize)}');
  print('');
  
  // Calculate original file hash
  print('🔐 Calculating original file hash...');
  final originalBytes = await testFile.readAsBytes();
  final originalHash = sha256.convert(originalBytes).toString();
  print('✅ Original hash: $originalHash');
  print('');
  
  // Start receiver in background
  print('🔧 Starting receiver service...');
  final receiver = ReceiverService();
  receiver.onFileReceived = (filename) {
    print('📨 File received callback: $filename');
  };
  
  try {
    await receiver.startServer(port: 8081);
    print('✅ Receiver started on port 8081');
  } catch (e) {
    print('❌ Failed to start receiver: $e');
    return;
  }
  
  // Wait a moment for server to fully start
  await Future.delayed(Duration(seconds: 1));
  
  // Start large file transfer
  print('');
  print('🚀 Starting large file transfer...');
  print('-' * 40);
  
  final largeFileService = LargeFileTransferService();
  
  final success = await largeFileService.sendLargeFile(
    filePath: testFile.path,
    targetIp: '127.0.0.1',
    targetPort: 8081,
    chunkSize: 1024 * 1024, // 1MB chunks
    onProgress: (sent, total, speed) {
      final percent = (sent / total * 100).toInt();
      print('📊 Progress: $percent% (${_formatBytes(sent)}/${_formatBytes(total)}) - ${_formatSpeed(speed)}');
    },
    onStatusUpdate: (message) {
      print('📢 Status: $message');
    },
  );
  
  print('-' * 40);
  print('🏁 Transfer result: ${success ? "SUCCESS" : "FAILED"}');
  
  // Stop receiver
  await receiver.stopServer();
  print('🔧 Receiver stopped');
  
  // Check if received file exists and compare
  final downloadDir = Directory('downloads');
  if (await downloadDir.exists()) {
    final receivedFiles = await downloadDir.list().toList();
    print('');
    print('📁 Files in downloads directory:');
    for (final file in receivedFiles) {
      if (file is File) {
        final receivedSize = await file.length();
        print('  - ${file.path}: ${_formatBytes(receivedSize)}');
        
        // Compare hashes if it's our test file
        if (file.path.contains('large_test_file.bin')) {
          print('');
          print('🔍 Comparing received file...');
          final receivedBytes = await file.readAsBytes();
          final receivedHash = sha256.convert(receivedBytes).toString();
          
          print('🔐 Received hash: $receivedHash');
          print('✅ Hashes match: ${originalHash == receivedHash}');
          
          if (originalHash != receivedHash) {
            print('❌ HASH MISMATCH DETECTED!');
            print('   - Original size: ${originalBytes.length}');
            print('   - Received size: ${receivedBytes.length}');
            
            // Compare first few bytes
            print('');
            print('🔍 First 32 bytes comparison:');
            final originalStart = originalBytes.take(32).toList();
            final receivedStart = receivedBytes.take(32).toList();
            print('   Original: $originalStart');
            print('   Received: $receivedStart');
            print('   Match: ${_listsEqual(originalStart, receivedStart)}');
            
            // Compare last few bytes
            print('');
            print('🔍 Last 32 bytes comparison:');
            final originalEnd = originalBytes.skip(originalBytes.length - 32).toList();
            final receivedEnd = receivedBytes.skip(receivedBytes.length - 32).toList();
            print('   Original: $originalEnd');
            print('   Received: $receivedEnd');
            print('   Match: ${_listsEqual(originalEnd, receivedEnd)}');
          }
        }
      }
    }
  }
  
  print('');
  print('🏁 Debug session complete');
}

String _formatBytes(num bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(1)} B/s';
  if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
}

bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
