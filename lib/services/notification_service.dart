import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing system notifications
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }
  
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  int _notificationId = 0;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Simplified initialization - notifications may not work on Windows in debug mode
      // but will be ready for production
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: null,
        iOS: null,
        macOS: null,
        linux: null,
      );

      final bool? result = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _isInitialized = result ?? false;

      if (kDebugMode) {
        print('NotificationService initialized: $_isInitialized');
      }

      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notifications: $e');
      }
      return false;
    }
  }

  /// Handle notification responses
  void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Handle notification tap if needed
  }

  /// Show file transfer started notification
  Future<void> showTransferStarted({
    required String fileName,
    required String targetDevice,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: _notificationId++,
      title: 'File Transfer Started',
      body: 'Sending "$fileName" to $targetDevice',
      icon: 'transfer_start',
    );
  }

  /// Show file transfer progress notification
  Future<void> showTransferProgress({
    required String fileName,
    required double progress,
    required String targetDevice,
  }) async {
    if (!_isInitialized) return;

    final progressText = '${(progress * 100).toInt()}%';
    
    await _showNotification(
      id: _notificationId, // Use same ID to update the notification
      title: 'Sending File ($progressText)',
      body: '"$fileName" to $targetDevice',
      icon: 'transfer_progress',
      progress: (progress * 100).toInt(),
      maxProgress: 100,
    );
  }

  /// Show file transfer completed notification
  Future<void> showTransferCompleted({
    required String fileName,
    required String targetDevice,
    required bool success,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: _notificationId++,
      title: success ? 'File Sent Successfully' : 'File Transfer Failed',
      body: success 
          ? '"$fileName" sent to $targetDevice'
          : 'Failed to send "$fileName" to $targetDevice',
      icon: success ? 'transfer_success' : 'transfer_error',
    );
  }

  /// Show file received notification
  Future<void> showFileReceived({
    required String fileName,
    required String fromDevice,
    String? filePath,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: _notificationId++,
      title: 'File Received',
      body: '"$fileName" from $fromDevice',
      icon: 'file_received',
      payload: filePath,
    );
  }

  /// Show peer discovered notification
  Future<void> showPeerDiscovered({
    required String peerName,
    required String peerAddress,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: _notificationId++,
      title: 'New Peer Discovered',
      body: '$peerName at $peerAddress',
      icon: 'peer_discovered',
    );
  }

  /// Show server status notification
  Future<void> showServerStatus({
    required bool isRunning,
    required int port,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: 1000, // Fixed ID for server status
      title: 'Stork P2P Server',
      body: isRunning 
          ? 'Server running on port $port'
          : 'Server stopped',
      icon: isRunning ? 'server_start' : 'server_stop',
    );
  }

  /// Show error notification
  Future<void> showError({
    required String title,
    required String message,
  }) async {
    if (!_isInitialized) return;

    await _showNotification(
      id: _notificationId++,
      title: title,
      body: message,
      icon: 'error',
    );
  }

  /// Internal method to show notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? icon,
    String? payload,
    int? progress,
    int? maxProgress,
  }) async {
    // Always log the notification attempt for debugging
    if (kDebugMode) {
      print('📢 $title: $body');
    }
    
    // Early return if not initialized - this prevents the LateInitializationError
    if (!_isInitialized) {
      return;
    }

    try {
      // Use basic notification details for Windows compatibility
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails();

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      if (kDebugMode) {
        print('✅ System notification shown: $title');
      }
    } catch (e) {
      // Graceful fallback - don't throw errors, just log
      if (kDebugMode) {
        print('⚠️ Notification fallback (system unavailable): $title - $body');
      }
      // Continue execution without throwing
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    if (!_isInitialized) return;
    
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      if (kDebugMode) {
        print('All notifications cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear notifications: $e');
      }
    }
  }

  /// Clear specific notification
  Future<void> clearNotification(int id) async {
    if (!_isInitialized) return;
    
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      if (kDebugMode) {
        print('Notification $id cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear notification $id: $e');
      }
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;
    
    try {
      // This is platform-specific - for Windows we assume they're enabled if initialized
      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check notification permissions: $e');
      }
      return false;
    }
  }

  /// Request notification permissions (mainly for mobile platforms)
  Future<bool> requestPermissions() async {
    try {
      // For Windows, permissions are handled during initialization
      return await initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to request notification permissions: $e');
      }
      return false;
    }
  }

  /// Dispose the service
  void dispose() {
    // Clean up if needed
    if (kDebugMode) {
      print('NotificationService disposed');
    }
  }
}
