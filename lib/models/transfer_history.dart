import 'package:flutter/material.dart';

/// Represents a completed file transfer record
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
  final double? averageSpeed; // bytes per second
  final String? errorMessage;
  final TransferType type;
  final String? batchId; // For multi-file transfers

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
    required this.type,
    this.batchId,
  });

  /// Create a copy with updated fields
  TransferRecord copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? targetHost,
    int? targetPort,
    String? targetName,
    TransferDirection? direction,
    TransferStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    double? averageSpeed,
    String? errorMessage,
    TransferType? type,
    String? batchId,
  }) {
    return TransferRecord(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      targetName: targetName ?? this.targetName,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      errorMessage: errorMessage ?? this.errorMessage,
      type: type ?? this.type,
      batchId: batchId ?? this.batchId,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'targetHost': targetHost,
      'targetPort': targetPort,
      'targetName': targetName,
      'direction': direction.name,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'averageSpeed': averageSpeed,
      'errorMessage': errorMessage,
      'type': type.name,
      'batchId': batchId,
    };
  }

  /// Create from JSON for persistence
  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      targetHost: json['targetHost'] as String,
      targetPort: json['targetPort'] as int,
      targetName: json['targetName'] as String,
      direction: TransferDirection.values.byName(json['direction'] as String),
      status: TransferStatus.values.byName(json['status'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      duration: json['duration'] != null ? Duration(milliseconds: json['duration'] as int) : null,
      averageSpeed: json['averageSpeed'] as double?,
      errorMessage: json['errorMessage'] as String?,
      type: TransferType.values.byName(json['type'] as String),
      batchId: json['batchId'] as String?,
    );
  }

  /// Get formatted file size
  String get formattedFileSize {
    return _formatBytes(fileSize);
  }

  /// Get formatted duration
  String get formattedDuration {
    if (duration == null) return 'N/A';
    final seconds = duration!.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}m ${seconds % 60}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get formatted average speed
  String get formattedSpeed {
    if (averageSpeed == null) return 'N/A';
    return '${_formatBytes(averageSpeed!.round())}/s';
  }

  /// Get status color
  Color get statusColor {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.orange;
      case TransferStatus.inProgress:
        return Colors.blue;
    }
  }

  /// Get status icon
  IconData get statusIcon {
    switch (status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
      case TransferStatus.inProgress:
        return Icons.sync;
    }
  }

  /// Get direction icon
  IconData get directionIcon {
    switch (direction) {
      case TransferDirection.sent:
        return Icons.upload;
      case TransferDirection.received:
        return Icons.download;
    }
  }

  /// Get type icon
  IconData get typeIcon {
    switch (type) {
      case TransferType.single:
        return Icons.insert_drive_file;
      case TransferType.batch:
        return Icons.folder;
      case TransferType.large:
        return Icons.storage;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Transfer direction
enum TransferDirection {
  sent,
  received,
}

/// Transfer status
enum TransferStatus {
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Transfer type
enum TransferType {
  single,
  batch,
  large,
}

/// Extension to add Color support
extension TransferStatusColor on TransferStatus {
  Color get color => switch (this) {
    TransferStatus.completed => Colors.green,
    TransferStatus.failed => Colors.red,
    TransferStatus.cancelled => Colors.orange,
    TransferStatus.inProgress => Colors.blue,
  };
}

