import 'dart:convert';
import 'lib/services/transfer_history_service.dart';
import 'lib/models/transfer_history.dart';

void main() async {
  print('🧪 Testing Transfer Statistics Calculation');
  print('=' * 50);
  
  final historyService = TransferHistoryService();
  await historyService.initialize();
  
  // Add test records
  print('📝 Adding test transfer records...');
  
  // Completed transfers
  final completedRecord1 = historyService.completeTransferRecord(
    record: historyService.createTransferRecord(
      fileName: 'test1.txt',
      filePath: '/path/test1.txt',
      fileSize: 1024, // 1 KB
      targetHost: '192.168.1.100',
      targetPort: 8080,
      targetName: 'Test Device 1',
      direction: TransferDirection.sent,
      type: TransferType.single,
    ),
    finalStatus: TransferStatus.completed,
  );
  
  final completedRecord2 = historyService.completeTransferRecord(
    record: historyService.createTransferRecord(
      fileName: 'test2.jpg',
      filePath: '/path/test2.jpg',
      fileSize: 2048000, // ~2 MB
      targetHost: '192.168.1.200',
      targetPort: 8080,
      targetName: 'Test Device 2',
      direction: TransferDirection.received,
      type: TransferType.single,
    ),
    finalStatus: TransferStatus.completed,
  );
  
  // Failed transfer
  final failedRecord = historyService.completeTransferRecord(
    record: historyService.createTransferRecord(
      fileName: 'test3.pdf',
      filePath: '/path/test3.pdf',
      fileSize: 5120000, // ~5 MB
      targetHost: '192.168.1.300',
      targetPort: 8080,
      targetName: 'Test Device 3',
      direction: TransferDirection.sent,
      type: TransferType.single,
    ),
    finalStatus: TransferStatus.failed,
    errorMessage: 'Network timeout',
  );
  
  await historyService.addTransferRecord(completedRecord1);
  await historyService.addTransferRecord(completedRecord2);
  await historyService.addTransferRecord(failedRecord);
  
  print('✅ Added 3 test records (2 completed, 1 failed)');
  print('');
  
  // Calculate statistics
  final stats = historyService.getStatistics();
  
  print('📊 Transfer Statistics:');
  print('  Total Transfers: ${stats.totalTransfers}');
  print('  Completed Transfers: ${stats.completedTransfers}');
  print('  Failed Transfers: ${stats.failedTransfers}');
  print('  Sent Transfers: ${stats.sentTransfers}');
  print('  Received Transfers: ${stats.receivedTransfers}');
  print('  Total Bytes Transferred: ${stats.totalBytesTransferred} (${stats.formattedTotalBytes})');
  print('  Total Files Transferred: ${stats.totalFilesTransferred}');
  print('  Average Transfer Speed: ${stats.averageTransferSpeed.toStringAsFixed(2)} bytes/s (${stats.formattedAverageSpeed})');
  print('  Success Rate: ${stats.successRate.toStringAsFixed(1)}%');
  print('');
  
  // Verify calculations
  print('🔍 Verification:');
  print('  Expected Total: >= 3 (sample + our tests)');
  print('  Expected Completed: >= 2');
  print('  Expected Failed: >= 1');
  print('  Expected Sent: >= 2 (at least 2 sent)');
  print('  Expected Received: >= 1 (at least 1 received)');
  print('  Expected Bytes: >= ${1024 + 2048000} (our completed transfers)');
  print('');
  
  // Test calculations
  bool allTestsPass = true;
  
  if (stats.totalTransfers < 3) {
    print('❌ Total transfers should be at least 3');
    allTestsPass = false;
  }
  
  if (stats.completedTransfers < 2) {
    print('❌ Completed transfers should be at least 2');
    allTestsPass = false;
  }
  
  if (stats.failedTransfers < 1) {
    print('❌ Failed transfers should be at least 1');
    allTestsPass = false;
  }
  
  if (stats.totalBytesTransferred < (1024 + 2048000)) {
    print('❌ Total bytes should be at least ${1024 + 2048000}');
    allTestsPass = false;
  }
  
  if (stats.successRate < 0 || stats.successRate > 100) {
    print('❌ Success rate should be between 0 and 100');
    allTestsPass = false;
  }
  
  if (stats.completedTransfers != stats.totalFilesTransferred) {
    print('❌ Total files transferred should equal completed transfers');
    allTestsPass = false;
  }
  
  if (allTestsPass) {
    print('✅ All statistics calculations are correct!');
  } else {
    print('❌ Some statistics calculations failed');
  }
  
  print('');
  print('🧹 Cleaning up test data...');
  await historyService.clearHistory();
  print('✅ Test completed!');
}
