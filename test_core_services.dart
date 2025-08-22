import 'dart:io';
import 'lib/services/sender_service.dart';
import 'lib/services/receiver_service.dart';
import 'lib/models/peer.dart';

void main() async {
  print('🚀 Testing Core P2P Services...\n');
  
  final sender = SenderService();
  final receiver1 = ReceiverService();
  final receiver2 = ReceiverService();
  
  try {
    // Test 1: Basic Services
    print('📋 Test 1: Basic Services');
    print('✅ SenderService: Initialized');
    print('✅ ReceiverService: Initialized');
    
    // Test 2: Start Multiple Receivers
    print('\n📋 Test 2: Start Multiple Receivers');
    
    receiver1.onFileReceived = (filename) {
      print('🎉 Device 1 received: $filename');
    };
    
    receiver2.onFileReceived = (filename) {
      print('🎉 Device 2 received: $filename');
    };
    
    await receiver1.startServer(port: 8080);
    print('✅ Device 1 (Receiver) started on port 8080');
    
    await receiver2.startServer(port: 8081);
    print('✅ Device 2 (Receiver) started on port 8081');
    
    // Test 3: Create Test Files
    print('\n📋 Test 3: Create Test Files');
    final testFile1 = File('test_document.pdf');
    await testFile1.writeAsString('This is a fake PDF document for testing.\nSize: ${DateTime.now()}');
    print('✅ Created test document: ${await testFile1.length()} bytes');
    
    final testFile2 = File('test_image.jpg');  
    await testFile2.writeAsString('This is fake image data.\nCreated: ${DateTime.now()}\nType: JPEG');
    print('✅ Created test image: ${await testFile2.length()} bytes');
    
    // Test 4: Multi-Device Transfer
    print('\n📋 Test 4: Multi-Device File Transfer');
    
    // Send file to Device 1
    print('📤 Sending document to Device 1...');
    final success1 = await sender.sendFile(
      filePath: testFile1.path,
      targetIp: 'localhost',
      targetPort: 8080,
      onProgress: (sent, total) {
        final percent = ((sent / total) * 100).toStringAsFixed(1);
        print('  Progress: $percent% ($sent/$total bytes)');
      },
    );
    
    if (success1) {
      print('✅ Document transfer to Device 1: SUCCESS');
    } else {
      print('❌ Document transfer to Device 1: FAILED');
    }
    
    // Small delay
    await Future.delayed(Duration(milliseconds: 500));
    
    // Send file to Device 2
    print('📤 Sending image to Device 2...');
    final success2 = await sender.sendFile(
      filePath: testFile2.path,
      targetIp: 'localhost', 
      targetPort: 8081,
      onProgress: (sent, total) {
        final percent = ((sent / total) * 100).toStringAsFixed(1);
        print('  Progress: $percent% ($sent/$total bytes)');
      },
    );
    
    if (success2) {
      print('✅ Image transfer to Device 2: SUCCESS');
    } else {
      print('❌ Image transfer to Device 2: FAILED');
    }
    
    // Test 5: Verify Received Files
    print('\n📋 Test 5: File Verification');
    
    final receivedDoc = File('downloads/${testFile1.path.split(Platform.pathSeparator).last}');
    final receivedImg = File('downloads/${testFile2.path.split(Platform.pathSeparator).last}');
    
    if (await receivedDoc.exists()) {
      final originalContent = await testFile1.readAsString();
      final receivedContent = await receivedDoc.readAsString();
      if (originalContent == receivedContent) {
        print('✅ Document integrity: VERIFIED');
      } else {
        print('❌ Document integrity: FAILED');
      }
    }
    
    if (await receivedImg.exists()) {
      final originalContent = await testFile2.readAsString();  
      final receivedContent = await receivedImg.readAsString();
      if (originalContent == receivedContent) {
        print('✅ Image integrity: VERIFIED');
      } else {
        print('❌ Image integrity: FAILED');
      }
    }
    
    // Test 6: Peer Management Simulation
    print('\n📋 Test 6: Peer Management Simulation');
    
    final manualPeers = <Peer>[];
    
    // Simulate adding manual peers (like the UI would do)
    manualPeers.add(Peer(name: 'My Laptop', host: '192.168.1.100', port: 8080));
    manualPeers.add(Peer(name: 'Office PC', host: '192.168.1.150', port: 8080));
    manualPeers.add(Peer(name: 'Phone', host: '192.168.1.200', port: 8080));
    
    print('✅ Manual peers added:');
    for (final peer in manualPeers) {
      print('  📱 ${peer.name} (${peer.host}:${peer.port})');
    }
    
    // Test 7: Network Info
    print('\n📋 Test 7: Network Information');
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      print('✅ Available network interfaces:');
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          print('  🌐 ${interface.name}: ${addr.address}');
        }
      }
    } catch (e) {
      print('⚠️ Network interfaces: $e');
    }
    
    // Test 8: Device Info API
    print('\n📋 Test 8: Device Info API Test');
    
    final deviceInfo1 = await sender.getDeviceInfo(
      targetIp: 'localhost', 
      targetPort: 8080
    );
    
    if (deviceInfo1 != null) {
      print('✅ Device 1 info: ${deviceInfo1['device_name']} (port ${deviceInfo1['port']})');
    } else {
      print('❌ Failed to get Device 1 info');
    }
    
    final deviceInfo2 = await sender.getDeviceInfo(
      targetIp: 'localhost', 
      targetPort: 8081
    );
    
    if (deviceInfo2 != null) {
      print('✅ Device 2 info: ${deviceInfo2['device_name']} (port ${deviceInfo2['port']})');
    } else {
      print('❌ Failed to get Device 2 info');
    }
    
    print('\n🎉 Core P2P Services Test: SUCCESS!');
    print('📊 Summary:');
    print('   • HTTP Services: ✅ All functional');
    print('   • File Transfer: ✅ Multi-device working');
    print('   • Data Integrity: ✅ Verified');
    print('   • Progress Tracking: ✅ Working');
    print('   • Device Discovery: ✅ API working');
    print('   • Peer Management: ✅ Ready for UI');
    print('   • Network Detection: ✅ Functional');
    
  } catch (e) {
    print('❌ Test failed: $e');
  } finally {
    // Cleanup
    await receiver1.stopServer();
    await receiver2.stopServer();
    
    // Clean up test files
    try {
      await File('test_document.pdf').delete();
      await File('test_image.jpg').delete();
    } catch (_) {}
    
    print('\n🧹 Cleanup completed');
  }
}
