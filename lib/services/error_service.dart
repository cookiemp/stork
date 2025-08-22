import 'dart:io';
import 'package:flutter/material.dart';

/// Centralized error handling service providing user-friendly error messages
/// with actionable suggestions and context-aware solutions
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  /// Show an error message with context and possible actions
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    List<ErrorAction>? actions,
    ErrorType type = ErrorType.general,
    bool persistent = false,
  }) {
    if (persistent) {
      _showErrorDialog(context, title, message, details, actions, type);
    } else {
      _showErrorSnackBar(context, title, message, actions, type);
    }
  }

  /// Show network-related error with specific troubleshooting steps
  static void showNetworkError(
    BuildContext context, {
    required String operation,
    required String targetDevice,
    Exception? exception,
    bool showTroubleshooting = true,
  }) {
    final errorInfo = _analyzeNetworkError(exception);
    
    final actions = showTroubleshooting ? [
      ErrorAction(
        label: 'Check Connection',
        icon: Icons.network_check,
        onPressed: () => _showNetworkTroubleshooting(context, targetDevice),
      ),
      ErrorAction(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ] : null;

    showError(
      context,
      title: 'Network Error',
      message: 'Failed to $operation with $targetDevice',
      details: errorInfo.message,
      actions: actions,
      type: ErrorType.network,
      persistent: showTroubleshooting,
    );
  }

  /// Show file-related error with file system context
  static void showFileError(
    BuildContext context, {
    required String operation,
    required String fileName,
    Exception? exception,
    String? filePath,
  }) {
    final errorInfo = _analyzeFileError(exception, filePath);
    
    final actions = <ErrorAction>[];
    
    // Add specific actions based on error type
    if (errorInfo.isPermissionError) {
      actions.add(ErrorAction(
        label: 'Check Permissions',
        icon: Icons.security,
        onPressed: () => _showPermissionHelp(context),
      ));
    }
    
    if (errorInfo.isSpaceError) {
      actions.add(ErrorAction(
        label: 'Free Up Space',
        icon: Icons.storage,
        onPressed: () => _showStorageHelp(context),
      ));
    }
    
    actions.add(ErrorAction(
      label: 'Try Again',
      icon: Icons.refresh,
      onPressed: () => Navigator.of(context).pop(),
    ));

    showError(
      context,
      title: 'File Error',
      message: 'Failed to $operation: $fileName',
      details: errorInfo.message,
      actions: actions,
      type: ErrorType.file,
      persistent: true,
    );
  }

  /// Show validation error for user input
  static void showValidationError(
    BuildContext context, {
    required String field,
    required String issue,
    String? suggestion,
  }) {
    final message = 'Invalid $field: $issue';
    final details = suggestion != null ? 'Suggestion: $suggestion' : null;

    showError(
      context,
      title: 'Input Error',
      message: message,
      details: details,
      type: ErrorType.validation,
    );
  }

  /// Show service initialization error
  static void showServiceError(
    BuildContext context, {
    required String serviceName,
    required String operation,
    Exception? exception,
  }) {
    final errorInfo = _analyzeServiceError(exception);
    
    final actions = [
      ErrorAction(
        label: 'Restart Service',
        icon: Icons.restart_alt,
        onPressed: () => Navigator.of(context).pop(),
      ),
      if (errorInfo.isPlatformError)
        ErrorAction(
          label: 'Platform Help',
          icon: Icons.help_outline,
          onPressed: () => _showPlatformHelp(context, serviceName),
        ),
    ];

    showError(
      context,
      title: 'Service Error',
      message: 'Failed to $operation $serviceName',
      details: errorInfo.message,
      actions: actions,
      type: ErrorType.service,
      persistent: true,
    );
  }

  // Private helper methods

  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
    String? details,
    List<ErrorAction>? actions,
    ErrorType type,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          _getErrorIcon(type),
          color: _getErrorColor(type),
          size: 32,
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (actions != null)
            ...actions.map((action) => TextButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 16),
              label: Text(action.label),
            )),
        ],
      ),
    );
  }

  static void _showErrorSnackBar(
    BuildContext context,
    String title,
    String message,
    List<ErrorAction>? actions,
    ErrorType type,
  ) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(type),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: _getErrorColor(type),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      action: actions?.isNotEmpty == true
          ? SnackBarAction(
              label: actions!.first.label,
              textColor: Colors.white,
              onPressed: actions.first.onPressed,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.file:
        return Icons.folder_off;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.service:
        return Icons.settings_applications;
      case ErrorType.general:
        return Icons.warning;
    }
  }

  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.file:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.service:
        return Colors.deepOrange;
      case ErrorType.general:
        return Colors.red;
    }
  }

  static _NetworkErrorInfo _analyzeNetworkError(Exception? exception) {
    if (exception == null) {
      return _NetworkErrorInfo('Connection failed', false, false, false);
    }

    final errorString = exception.toString().toLowerCase();
    
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return _NetworkErrorInfo(
        'Connection timed out. The target device may be offline or unreachable.',
        true,
        false,
        false,
      );
    }
    
    if (errorString.contains('connection refused')) {
      return _NetworkErrorInfo(
        'Connection refused. The target device may not be running the receiver.',
        false,
        true,
        false,
      );
    }
    
    if (errorString.contains('no route to host') || errorString.contains('network unreachable')) {
      return _NetworkErrorInfo(
        'No route to host. Check if both devices are on the same network.',
        false,
        false,
        true,
      );
    }

    return _NetworkErrorInfo(
      'Network error: ${exception.toString()}',
      false,
      false,
      false,
    );
  }

  static _FileErrorInfo _analyzeFileError(Exception? exception, String? filePath) {
    if (exception == null) {
      return _FileErrorInfo('File operation failed', false, false, false);
    }

    final errorString = exception.toString().toLowerCase();
    
    if (errorString.contains('permission') || errorString.contains('access denied')) {
      return _FileErrorInfo(
        'Permission denied. Check if you have access to this file or directory.',
        true,
        false,
        false,
      );
    }
    
    if (errorString.contains('no space') || errorString.contains('disk full')) {
      return _FileErrorInfo(
        'Insufficient storage space. Free up space and try again.',
        false,
        true,
        false,
      );
    }
    
    if (errorString.contains('not found') || errorString.contains('does not exist')) {
      return _FileErrorInfo(
        'File or directory not found. The file may have been moved or deleted.',
        false,
        false,
        true,
      );
    }

    return _FileErrorInfo(
      'File error: ${exception.toString()}',
      false,
      false,
      false,
    );
  }

  static _ServiceErrorInfo _analyzeServiceError(Exception? exception) {
    if (exception == null) {
      return _ServiceErrorInfo('Service initialization failed', false);
    }

    final errorString = exception.toString().toLowerCase();
    
    if (errorString.contains('platform') || 
        errorString.contains('missing plugin') || 
        errorString.contains('method not implemented')) {
      return _ServiceErrorInfo(
        'Platform-specific error. This feature may not be supported on your system.',
        true,
      );
    }

    return _ServiceErrorInfo(
      'Service error: ${exception.toString()}',
      false,
    );
  }

  static void _showNetworkTroubleshooting(BuildContext context, String targetDevice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Troubleshooting'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Having trouble connecting to $targetDevice? Try these steps:'),
              const SizedBox(height: 16),
              _buildTroubleshootingStep('1', 'Check Network Connection', 
                'Ensure both devices are connected to the same Wi-Fi network.'),
              _buildTroubleshootingStep('2', 'Verify Target Device', 
                'Make sure the target device is running Stork and has receiving enabled.'),
              _buildTroubleshootingStep('3', 'Check Firewall', 
                'Temporarily disable firewall or add Stork to firewall exceptions.'),
              _buildTroubleshootingStep('4', 'Try Manual Connection', 
                'Add the peer manually using the exact IP address shown on their device.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  static void _showPermissionHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Issues'),
        content: const Text(
          'Stork needs permission to access files. Please:\n\n'
          '• Check file permissions in File Explorer\n'
          '• Run Stork as administrator (if needed)\n'
          '• Ensure the destination folder is writable',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  static void _showStorageHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Space'),
        content: const Text(
          'Your device is running low on storage space. To continue:\n\n'
          '• Delete unnecessary files\n'
          '• Empty Recycle Bin\n'
          '• Move files to external storage\n'
          '• Choose a different destination folder',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showPlatformHelp(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$serviceName Platform Support'),
        content: Text(
          'The $serviceName feature may have limited support on your platform. '
          'This could be due to:\n\n'
          '• Platform-specific limitations\n'
          '• Missing system dependencies\n'
          '• Incomplete feature implementation\n\n'
          'Some features may work differently or be unavailable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static Widget _buildTroubleshootingStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Types of errors for context-specific handling
enum ErrorType {
  network,
  file,
  validation,
  service,
  general,
}

/// Action button for error dialogs
class ErrorAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  ErrorAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

// Private helper classes for error analysis
class _NetworkErrorInfo {
  final String message;
  final bool isTimeout;
  final bool isConnectionRefused;
  final bool isNoRoute;

  _NetworkErrorInfo(this.message, this.isTimeout, this.isConnectionRefused, this.isNoRoute);
}

class _FileErrorInfo {
  final String message;
  final bool isPermissionError;
  final bool isSpaceError;
  final bool isNotFoundError;

  _FileErrorInfo(this.message, this.isPermissionError, this.isSpaceError, this.isNotFoundError);
}

class _ServiceErrorInfo {
  final String message;
  final bool isPlatformError;

  _ServiceErrorInfo(this.message, this.isPlatformError);
}
