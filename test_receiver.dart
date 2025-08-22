import 'lib/services/receiver_service.dart';

void main() async {
  final receiver = ReceiverService();
  
  // Set up file received callback
  receiver.onFileReceived = (filename) {
    print('✅ File received callback: $filename');
  };

  try {
    print('Starting receiver server...');
    await receiver.startServer(port: 8080);
    
    print('Server is running. Test with:');
    print('curl -X GET http://localhost:8080/info');
    print('curl -X POST http://localhost:8080/send -H "X-Filename: test.txt" -d "Hello World"');
    print('Press Ctrl+C to stop...');
    
    // Keep the server running
    while (receiver.isRunning) {
      await Future.delayed(Duration(seconds: 1));
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    await receiver.stopServer();
  }
}
