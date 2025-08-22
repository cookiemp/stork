import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transfer_history.dart';

/// Service for managing transfer history persistence and operations
class TransferHistoryService extends ChangeNotifier {
  static const String _historyKey = 'transfer_history';
  static const int _maxHistoryItems = 1000; // Prevent unlimited growth

  SharedPreferences? _prefs;
  List<TransferRecord> _history = [];
  bool _isInitialized = false;

  /// Get current transfer history (read-only)
  List<TransferRecord> get history => List.unmodifiable(_history);

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the service and load existing history
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadHistory();
      _isInitialized = true;
      
      if (kDebugMode) {
        print('TransferHistoryService: Initialized with ${_history.length} records');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to initialize: $e');
      }
      // Continue with empty history if initialization fails
      _isInitialized = true;
    }
  }

  /// Add a new transfer record
  Future<void> addTransferRecord(TransferRecord record) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Add to the beginning of the list (most recent first)
      _history.insert(0, record);
      
      // Maintain maximum history size
      if (_history.length > _maxHistoryItems) {
        _history = _history.take(_maxHistoryItems).toList();
      }
      
      await _saveHistory();
      notifyListeners();
      
      if (kDebugMode) {
        print('TransferHistoryService: Added record - ${record.fileName} to ${record.targetName}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to add record: $e');
      }
    }
  }

  /// Update an existing transfer record
  Future<void> updateTransferRecord(String id, TransferRecord updatedRecord) async {
    if (!_isInitialized) return;

    try {
      final index = _history.indexWhere((record) => record.id == id);
      if (index != -1) {
        _history[index] = updatedRecord;
        await _saveHistory();
        notifyListeners();
        
        if (kDebugMode) {
          print('TransferHistoryService: Updated record - ${updatedRecord.fileName}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to update record: $e');
      }
    }
  }

  /// Remove a transfer record by ID
  Future<void> removeTransferRecord(String id) async {
    if (!_isInitialized) return;

    try {
      final initialLength = _history.length;
      _history.removeWhere((record) => record.id == id);
      final removed = initialLength - _history.length;
      if (removed > 0) {
        await _saveHistory();
        notifyListeners();
        
        if (kDebugMode) {
          print('TransferHistoryService: Removed $removed record(s)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to remove record: $e');
      }
    }
  }

  /// Clear all transfer history
  Future<void> clearHistory() async {
    if (!_isInitialized) return;

    try {
      _history.clear();
      await _saveHistory();
      notifyListeners();
      
      if (kDebugMode) {
        print('TransferHistoryService: Cleared all history');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to clear history: $e');
      }
    }
  }

  /// Search transfer history by filename, target, or status
  List<TransferRecord> searchHistory(String query) {
    if (query.isEmpty) return history;

    final lowerQuery = query.toLowerCase();
    return _history.where((record) {
      return record.fileName.toLowerCase().contains(lowerQuery) ||
             record.targetName.toLowerCase().contains(lowerQuery) ||
             record.targetHost.toLowerCase().contains(lowerQuery) ||
             record.status.name.toLowerCase().contains(lowerQuery) ||
             record.direction.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter history by status
  List<TransferRecord> filterByStatus(TransferStatus status) {
    return _history.where((record) => record.status == status).toList();
  }

  /// Filter history by direction
  List<TransferRecord> filterByDirection(TransferDirection direction) {
    return _history.where((record) => record.direction == direction).toList();
  }

  /// Filter history by date range
  List<TransferRecord> filterByDateRange(DateTime start, DateTime end) {
    return _history.where((record) {
      return record.startTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
             record.startTime.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  /// Get transfer statistics
  TransferStatistics getStatistics() {
    final completed = _history.where((r) => r.status == TransferStatus.completed).toList();
    final failed = _history.where((r) => r.status == TransferStatus.failed).toList();
    final inProgress = _history.where((r) => r.status == TransferStatus.inProgress).toList();
    final sent = _history.where((r) => r.direction == TransferDirection.sent).toList();
    final received = _history.where((r) => r.direction == TransferDirection.received).toList();
    
    // Debug logging
    if (kDebugMode) {
      print('\n=== DEBUG STATISTICS CALCULATION ===');
      print('Total records: ${_history.length}');
      print('Completed: ${completed.length}');
      print('Failed: ${failed.length}');
      print('In Progress: ${inProgress.length}');
      print('Sent: ${sent.length}');
      print('Received: ${received.length}');
      
      print('\nRecord details:');
      for (var i = 0; i < _history.length; i++) {
        final r = _history[i];
        print('${i + 1}. ${r.fileName}');
        print('   Status: ${r.status.name}');
        print('   Size: ${r.fileSize} bytes');
        print('   Speed: ${r.averageSpeed}');
        print('   Direction: ${r.direction.name}');
      }
    }
    
    // Calculate total bytes transferred (only completed transfers)
    final totalBytesTransferred = completed.fold<int>(0, (sum, r) => sum + r.fileSize);
    
    // Calculate total files attempted vs successfully transferred
    final totalFilesAttempted = _history.length;
    final totalFilesCompleted = completed.length;
    
    // Calculate average speed from completed transfers with speed data
    double avgSpeed = 0.0;
    if (completed.isNotEmpty) {
      final speedRecords = completed.where((r) => r.averageSpeed != null && r.averageSpeed! > 0).toList();
      if (speedRecords.isNotEmpty) {
        final totalSpeed = speedRecords.fold<double>(0.0, (sum, r) => sum + r.averageSpeed!);
        avgSpeed = totalSpeed / speedRecords.length;
        
        if (kDebugMode) {
          print('\nSpeed calculation:');
          print('Records with speed: ${speedRecords.length}');
          for (final r in speedRecords) {
            print('  ${r.fileName}: ${r.averageSpeed} bytes/s');
          }
          print('Total speed: $totalSpeed');
          print('Average speed: $avgSpeed');
        }
      }
    }
    
    if (kDebugMode) {
      print('\nFinal calculations:');
      print('Total bytes transferred: $totalBytesTransferred');
      print('Success rate: ${totalFilesAttempted > 0 ? (totalFilesCompleted / totalFilesAttempted * 100).toStringAsFixed(1) : "0.0"}%');
      print('=====================================\n');
    }

    return TransferStatistics(
      totalTransfers: totalFilesAttempted,
      completedTransfers: totalFilesCompleted,
      failedTransfers: failed.length,
      sentTransfers: sent.length,
      receivedTransfers: received.length,
      totalBytesTransferred: totalBytesTransferred,
      totalFilesTransferred: totalFilesCompleted, // Successfully transferred files
      averageTransferSpeed: avgSpeed,
    );
  }

  /// Get transfer record by ID
  TransferRecord? getRecord(String id) {
    try {
      return _history.firstWhere((record) => record.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if a file path still exists
  Future<bool> doesFileExist(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Create a transfer record for a started transfer
  TransferRecord createTransferRecord({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String targetHost,
    required int targetPort,
    required String targetName,
    required TransferDirection direction,
    required TransferType type,
    String? batchId,
  }) {
    return TransferRecord(
      id: _generateTransferId(),
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      targetHost: targetHost,
      targetPort: targetPort,
      targetName: targetName,
      direction: direction,
      status: TransferStatus.inProgress,
      startTime: DateTime.now(),
      type: type,
      batchId: batchId,
    );
  }

  /// Complete a transfer record with final statistics
  TransferRecord completeTransferRecord({
    required TransferRecord record,
    required TransferStatus finalStatus,
    String? errorMessage,
  }) {
    final now = DateTime.now();
    final duration = now.difference(record.startTime);
    double? averageSpeed;
    
    if (finalStatus == TransferStatus.completed && duration.inSeconds > 0) {
      averageSpeed = record.fileSize / duration.inSeconds;
    }

    return record.copyWith(
      status: finalStatus,
      endTime: now,
      duration: duration,
      averageSpeed: averageSpeed,
      errorMessage: errorMessage,
    );
  }

  /// Load history from SharedPreferences
  Future<void> _loadHistory() async {
    try {
      final historyJson = _prefs?.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _history = historyList
            .map((json) => TransferRecord.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Sort by start time (most recent first)
        _history.sort((a, b) => b.startTime.compareTo(a.startTime));
      }
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to load history: $e');
      }
      _history = [];
    }
  }

  /// Save history to SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final historyJson = jsonEncode(_history.map((record) => record.toJson()).toList());
      await _prefs?.setString(_historyKey, historyJson);
    } catch (e) {
      if (kDebugMode) {
        print('TransferHistoryService: Failed to save history: $e');
      }
    }
  }

  /// Generate a unique transfer ID
  String _generateTransferId() {
    return 'transfer_${DateTime.now().millisecondsSinceEpoch}_${_history.length}';
  }
}

/// Transfer statistics summary
class TransferStatistics {
  final int totalTransfers;
  final int completedTransfers;
  final int failedTransfers;
  final int sentTransfers;
  final int receivedTransfers;
  final int totalBytesTransferred;
  final int totalFilesTransferred;
  final double averageTransferSpeed;

  TransferStatistics({
    required this.totalTransfers,
    required this.completedTransfers,
    required this.failedTransfers,
    required this.sentTransfers,
    required this.receivedTransfers,
    required this.totalBytesTransferred,
    required this.totalFilesTransferred,
    required this.averageTransferSpeed,
  });

  /// Get formatted total bytes
  String get formattedTotalBytes {
    return _formatBytes(totalBytesTransferred);
  }

  /// Get formatted average speed
  String get formattedAverageSpeed {
    return '${_formatBytes(averageTransferSpeed.round())}/s';
  }

  /// Get success rate as percentage
  double get successRate {
    if (totalTransfers == 0) return 0.0;
    return (completedTransfers / totalTransfers) * 100;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
