import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for showing progress indicators in the Windows taskbar
class TaskbarService {
  static const MethodChannel _channel = MethodChannel('taskbar_progress');
  static bool _initialized = false;

  /// Initialize the taskbar service
  static Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) return;
    
    try {
      _initialized = true;
    } catch (e) {
      // Platform channel not available - this is expected in debug mode
      // or when running without proper Windows integration
      debugPrint('TaskbarService: Platform channel not available: $e');
    }
  }

  /// Show progress in taskbar (0.0 to 1.0)
  static Future<void> setProgress(double progress) async {
    if (!_initialized || !Platform.isWindows) return;
    
    try {
      await _channel.invokeMethod('setProgress', {
        'progress': progress.clamp(0.0, 1.0),
      });
    } catch (e) {
      debugPrint('TaskbarService: Failed to set progress: $e');
    }
  }

  /// Set taskbar state (normal, indeterminate, error, paused)
  static Future<void> setState(TaskbarState state) async {
    if (!_initialized || !Platform.isWindows) return;
    
    try {
      await _channel.invokeMethod('setState', {
        'state': state.name,
      });
    } catch (e) {
      debugPrint('TaskbarService: Failed to set state: $e');
    }
  }

  /// Clear progress from taskbar
  static Future<void> clearProgress() async {
    if (!_initialized || !Platform.isWindows) return;
    
    try {
      await _channel.invokeMethod('clearProgress');
    } catch (e) {
      debugPrint('TaskbarService: Failed to clear progress: $e');
    }
  }

  /// Show indeterminate progress (for unknown duration operations)
  static Future<void> setIndeterminate() async {
    await setState(TaskbarState.indeterminate);
  }

  /// Show error state in taskbar
  static Future<void> setError() async {
    await setState(TaskbarState.error);
  }

  /// Show paused state in taskbar
  static Future<void> setPaused() async {
    await setState(TaskbarState.paused);
  }

  /// Reset to normal state
  static Future<void> setNormal() async {
    await setState(TaskbarState.normal);
  }
}

/// Taskbar progress states
enum TaskbarState {
  normal,
  indeterminate,
  error,
  paused,
}

/// Utility class for managing taskbar progress during file transfers
class TaskbarProgressManager {
  static bool _isActive = false;
  
  /// Start showing progress for a file transfer
  static Future<void> startTransfer() async {
    if (_isActive) return;
    
    _isActive = true;
    await TaskbarService.setNormal();
    await TaskbarService.setProgress(0.0);
  }
  
  /// Update transfer progress
  static Future<void> updateProgress(double progress) async {
    if (!_isActive) return;
    
    await TaskbarService.setProgress(progress);
  }
  
  /// Complete the transfer successfully
  static Future<void> completeTransfer() async {
    if (!_isActive) return;
    
    await TaskbarService.setProgress(1.0);
    
    // Show completed state briefly
    await Future.delayed(const Duration(milliseconds: 500));
    await TaskbarService.clearProgress();
    
    _isActive = false;
  }
  
  /// Mark transfer as failed
  static Future<void> failTransfer() async {
    if (!_isActive) return;
    
    await TaskbarService.setError();
    
    // Show error state briefly
    await Future.delayed(const Duration(seconds: 2));
    await TaskbarService.clearProgress();
    
    _isActive = false;
  }
  
  /// Pause the transfer
  static Future<void> pauseTransfer() async {
    if (!_isActive) return;
    
    await TaskbarService.setPaused();
  }
  
  /// Resume the transfer
  static Future<void> resumeTransfer() async {
    if (!_isActive) return;
    
    await TaskbarService.setNormal();
  }
  
  /// Cancel the transfer
  static Future<void> cancelTransfer() async {
    if (!_isActive) return;
    
    await TaskbarService.clearProgress();
    _isActive = false;
  }
}

/// Widget that automatically manages taskbar progress for wrapped operations
class TaskbarProgressWrapper extends StatefulWidget {
  final Widget child;
  final Stream<double>? progressStream;
  final bool showProgress;

  const TaskbarProgressWrapper({
    super.key,
    required this.child,
    this.progressStream,
    this.showProgress = false,
  });

  @override
  State<TaskbarProgressWrapper> createState() => _TaskbarProgressWrapperState();
}

class _TaskbarProgressWrapperState extends State<TaskbarProgressWrapper> {
  @override
  void initState() {
    super.initState();
    
    if (widget.showProgress) {
      TaskbarProgressManager.startTransfer();
    }
    
    widget.progressStream?.listen((progress) {
      TaskbarProgressManager.updateProgress(progress);
    });
  }

  @override
  void didUpdateWidget(TaskbarProgressWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showProgress != oldWidget.showProgress) {
      if (widget.showProgress) {
        TaskbarProgressManager.startTransfer();
      } else {
        TaskbarProgressManager.clearProgress();
      }
    }
  }

  @override
  void dispose() {
    if (widget.showProgress) {
      TaskbarProgressManager.clearProgress();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Simple mock implementation for non-Windows platforms or when platform channel is unavailable
class MockTaskbarService {
  static void setProgress(double progress) {
    debugPrint('MockTaskbarService: Progress ${(progress * 100).toInt()}%');
  }
  
  static void setState(TaskbarState state) {
    debugPrint('MockTaskbarService: State ${state.name}');
  }
  
  static void clearProgress() {
    debugPrint('MockTaskbarService: Progress cleared');
  }
}
