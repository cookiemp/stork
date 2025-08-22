import 'dart:io';
import 'lib/services/sender_service.dart';
import 'lib/services/receiver_service.dart';

void main() async {
  final sender = SenderService();
  final receiver = ReceiverService();

  // Create a test file to send
  final testFile = File('test_file.txt');
  await testFile.writeAsString('This is a test file created by sender_service test!\n'
      'It contains multiple lines of text to test the transfer.\n'
      'File size should be larger than the previous simple test.\n'
      'Timestamp: ${DateTime.now()}');

  print('📁 Created test file: ${testFile.path} (${await testFile.length()} bytes)');

  try {
    // Start receiver on port 8081 to avoid conflicts
    print('\n🔄 Starting receiver server...');
    await receiver.startServer(port: 8081);

    // Set up callback to know when file is received
    receiver.onFileReceived = (filename) {
      print('🎉 Receiver callback: File "$filename" received!');
    };

    // Give server a moment to start
    await Future.delayed(Duration(milliseconds: 500));

    // Test getting device info first
    print('\n🔍 Testing device info...');
    final deviceInfo = await sender.getDeviceInfo(
      targetIp: 'localhost', 
      targetPort: 8081
    );
    
    if (deviceInfo != null) {
      print('✅ Device info received: $deviceInfo');
    } else {
      print('❌ Failed to get device info');
      return;
    }

    // Now test sending the file
    print('\n📤 Testing file send...');
    final success = await sender.sendFile(
      filePath: testFile.path,
      targetIp: 'localhost',
      targetPort: 8081,
    );

    if (success) {
      print('✅ File transfer completed successfully!');
      
      // Verify the file was received correctly
      final receivedFile = File('downloads/${testFile.path.split(Platform.pathSeparator).last}');
      if (await receivedFile.exists()) {
        final originalContent = await testFile.readAsString();
        final receivedContent = await receivedFile.readAsString();
        
        if (originalContent == receivedContent) {
          print('✅ File content verification: PASSED');
        } else {
          print('❌ File content verification: FAILED');
          print('Original: ${originalContent.length} chars');
          print('Received: ${receivedContent.length} chars');
        }
      }
    } else {
      print('❌ File transfer failed!');
    }

  } catch (e) {
    print('❌ Test error: $e');
  } finally {
    // Cleanup
    await receiver.stopServer();
    if (await testFile.exists()) {
      await testFile.delete();
    }
    print('\n🧹 Cleanup completed');
  }
}
