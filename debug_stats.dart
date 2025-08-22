import 'dart:convert';
import 'dart:io';

// Simplified versions of the model classes for debugging
enum TransferStatus { inProgress, completed, failed }
enum TransferDirection { sent, received }

class TransferRecord {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String targetHost;
  final int targetPort;
  final String targetName;
  final TransferDirection direction;
  final TransferStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final double? averageSpeed;
  final String? errorMessage;

  TransferRecord({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.targetHost,
    required this.targetPort,
    required this.targetName,
    required this.direction,
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
    this.averageSpeed,
    this.errorMessage,
  });

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      targetHost: json['targetHost'] as String,
      targetPort: json['targetPort'] as int,
      targetName: json['targetName'] as String,
      direction: TransferDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => TransferDirection.sent,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.failed,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      duration: json['duration'] != null ? Duration(microseconds: json['duration'] as int) : null,
      averageSpeed: json['averageSpeed']?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

void main() async {
  // Try to read the SharedPreferences file on Windows
  // SharedPreferences typically stores data in the registry or app data folder
  // For debugging, let's check if we can access the app's data
  
  print('=== Debug Transfer Statistics ===\n');
  
  // Since we can't easily access SharedPreferences from a standalone script,
  // let's create some test data that matches what might be in the app
  final testRecords = [
    // Sample records similar to what might be in the app
    TransferRecord(
      id: 'test1',
      fileName: 'test1.txt',
      filePath: '/path/test1.txt',
      fileSize: 1024000, // ~1MB
      targetHost: '192.168.1.100',
      targetPort: 8080,
      targetName: 'TestDevice1',
      direction: TransferDirection.sent,
      status: TransferStatus.completed,
      startTime: DateTime.now().subtract(Duration(hours: 1)),
      endTime: DateTime.now().subtract(Duration(hours: 1, minutes: -1)),
      duration: Duration(minutes: 1),
      averageSpeed: 17066.67, // ~1024000 bytes / 60 seconds
    ),
    TransferRecord(
      id: 'test2',
      fileName: 'test2.txt',
      filePath: '/path/test2.txt',
      fileSize: 2048000, // ~2MB
      targetHost: '192.168.1.101',
      targetPort: 8080,
      targetName: 'TestDevice2',
      direction: TransferDirection.received,
      status: TransferStatus.completed,
      startTime: DateTime.now().subtract(Duration(hours: 2)),
      endTime: DateTime.now().subtract(Duration(hours: 2, minutes: -2)),
      duration: Duration(minutes: 2),
      averageSpeed: 17066.67, // ~2048000 bytes / 120 seconds
    ),
    TransferRecord(
      id: 'test3',
      fileName: 'test3.txt',
      filePath: '/path/test3.txt',
      fileSize: 512000, // ~0.5MB
      targetHost: '192.168.1.102',
      targetPort: 8080,
      targetName: 'TestDevice3',
      direction: TransferDirection.sent,
      status: TransferStatus.failed,
      startTime: DateTime.now().subtract(Duration(hours: 3)),
      errorMessage: 'Connection failed',
    ),
    TransferRecord(
      id: 'test4',
      fileName: 'test4.txt',
      filePath: '/path/test4.txt',
      fileSize: 4096000, // ~4MB
      targetHost: '192.168.1.103',
      targetPort: 8080,
      targetName: 'TestDevice4',
      direction: TransferDirection.received,
      status: TransferStatus.completed,
      startTime: DateTime.now().subtract(Duration(hours: 4)),
      endTime: DateTime.now().subtract(Duration(hours: 4, minutes: -4)),
      duration: Duration(minutes: 4),
      averageSpeed: 17066.67, // ~4096000 bytes / 240 seconds
    ),
    TransferRecord(
      id: 'test5',
      fileName: 'test5.txt',
      filePath: '/path/test5.txt',
      fileSize: 1024000, // ~1MB
      targetHost: '192.168.1.104',
      targetPort: 8080,
      targetName: 'TestDevice5',
      direction: TransferDirection.sent,
      status: TransferStatus.inProgress,
      startTime: DateTime.now().subtract(Duration(minutes: 10)),
    ),
    TransferRecord(
      id: 'test6',
      fileName: 'test6.txt',
      filePath: '/path/test6.txt',
      fileSize: 2048000, // ~2MB
      targetHost: '192.168.1.105',
      targetPort: 8080,
      targetName: 'TestDevice6',
      direction: TransferDirection.received,
      status: TransferStatus.completed,
      startTime: DateTime.now().subtract(Duration(hours: 5)),
      endTime: DateTime.now().subtract(Duration(hours: 5, minutes: -3)),
      duration: Duration(minutes: 3),
      averageSpeed: 11377.78, // ~2048000 bytes / 180 seconds
    ),
  ];
  
  print('Total Records: ${testRecords.length}');
  print('\nRecord Details:');
  for (var i = 0; i < testRecords.length; i++) {
    final record = testRecords[i];
    print('${i + 1}. ${record.fileName}');
    print('   Status: ${record.status.name}');
    print('   Direction: ${record.direction.name}');
    print('   Size: ${_formatBytes(record.fileSize)}');
    if (record.averageSpeed != null) {
      print('   Speed: ${_formatBytes(record.averageSpeed!.round())}/s');
    }
    print('');
  }
  
  // Calculate statistics using the same logic as the app
  final completed = testRecords.where((r) => r.status == TransferStatus.completed).toList();
  final failed = testRecords.where((r) => r.status == TransferStatus.failed).toList();
  final inProgress = testRecords.where((r) => r.status == TransferStatus.inProgress).toList();
  
  print('\n=== Statistics Breakdown ===');
  print('Total records: ${testRecords.length}');
  print('Completed: ${completed.length}');
  print('Failed: ${failed.length}');
  print('In Progress: ${inProgress.length}');
  
  // Calculate total bytes transferred (only completed transfers)
  final totalBytesTransferred = completed.fold<int>(0, (sum, r) => sum + r.fileSize);
  print('Total bytes from completed transfers: ${_formatBytes(totalBytesTransferred)}');
  
  // Calculate average speed from completed transfers with speed data
  double avgSpeed = 0.0;
  if (completed.isNotEmpty) {
    final speedRecords = completed.where((r) => r.averageSpeed != null && r.averageSpeed! > 0).toList();
    print('Records with speed data: ${speedRecords.length}');
    if (speedRecords.isNotEmpty) {
      final totalSpeed = speedRecords.fold<double>(0.0, (sum, r) => sum + r.averageSpeed!);
      avgSpeed = totalSpeed / speedRecords.length;
      print('Individual speeds: ${speedRecords.map((r) => "${_formatBytes(r.averageSpeed!.round())}/s").join(", ")}');
      print('Average speed calculation: $totalSpeed / ${speedRecords.length} = $avgSpeed');
    }
  }
  
  // Success rate
  final successRate = testRecords.isEmpty ? 0.0 : (completed.length / testRecords.length) * 100;
  
  print('\n=== Final Statistics ===');
  print('Total Transfers: ${testRecords.length}');
  print('Success Rate: ${successRate.toStringAsFixed(1)}%');
  print('Total Size: ${_formatBytes(totalBytesTransferred)}');
  print('Avg Speed: ${_formatBytes(avgSpeed.round())}/s');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
}
