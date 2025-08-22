import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling authentication, authorization, and transfer approvals
class AuthenticationService {
  static const String _devicePinKey = 'stork_device_pin_hash';
  static const String _authConfigKey = 'stork_auth_config';
  static const String _pendingApprovalsKey = 'stork_pending_approvals';
  static const String _failedAttemptsKey = 'stork_failed_attempts';
  
  // Authentication configuration
  AuthConfig _authConfig = AuthConfig.standard;
  
  // Pending transfer approvals
  final Map<String, TransferApproval> _pendingApprovals = {};
  
  // Failed authentication attempts tracking
  final Map<String, FailedAttemptTracker> _failedAttempts = {};
  
  String? _devicePinHash;
  bool _initialized = false;
  bool _isDeviceLocked = false;
  
  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadStoredData();
    _initialized = true;
    
    if (kDebugMode) {
      print('🔐 Authentication service initialized');
      print('   - PIN protection: ${_devicePinHash != null}');
      print('   - Device locked: $_isDeviceLocked');
      print('   - Require approval: ${_authConfig.requireTransferApproval}');
    }
  }
  
  /// Get current authentication configuration
  AuthConfig get authConfig => _authConfig;
  
  /// Update authentication configuration
  Future<void> updateAuthConfig(AuthConfig config) async {
    _authConfig = config;
    await _saveAuthConfig();
    
    if (kDebugMode) {
      print('🔧 Authentication configuration updated:');
      print('   - PIN required: ${config.requirePin}');
      print('   - Transfer approval: ${config.requireTransferApproval}');
      print('   - Auto-approve trusted: ${config.autoApproveTrustedPeers}');
    }
  }
  
  /// Check if device has PIN protection enabled
  bool get hasPinProtection => _devicePinHash != null;
  
  /// Check if device is currently locked
  bool get isDeviceLocked => _isDeviceLocked;
  
  /// Set up PIN protection for the device
  Future<void> setupPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits');
    }
    
    // Generate salt and hash the PIN
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    
    _devicePinHash = '$salt:$hash';
    _isDeviceLocked = false;
    
    await _saveDevicePinHash();
    
    if (kDebugMode) {
      print('🔒 PIN protection enabled');
    }
  }
  
  /// Verify PIN and unlock device
  Future<bool> verifyPin(String pin) async {
    if (_devicePinHash == null) return true; // No PIN set
    
    try {
      final parts = _devicePinHash!.split(':');
      if (parts.length != 2) throw FormatException('Invalid PIN hash format');
      
      final salt = parts[0];
      final storedHash = parts[1];
      final inputHash = _hashPin(pin, salt);
      
      if (inputHash == storedHash) {
        _isDeviceLocked = false;
        _clearFailedAttempts('device');
        
        if (kDebugMode) {
          print('🔓 Device unlocked with correct PIN');
        }
        return true;
      } else {
        await _recordFailedAttempt('device');
        
        if (kDebugMode) {
          print('❌ Incorrect PIN entered');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PIN verification error: $e');
      }
      return false;
    }
  }
  
  /// Lock the device (requires PIN to unlock)
  void lockDevice() {
    if (_devicePinHash != null) {
      _isDeviceLocked = true;
      
      if (kDebugMode) {
        print('🔒 Device locked');
      }
    }
  }
  
  /// Remove PIN protection
  Future<void> removePin(String currentPin) async {
    if (!await verifyPin(currentPin)) {
      throw SecurityException('Current PIN is incorrect');
    }
    
    _devicePinHash = null;
    _isDeviceLocked = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_devicePinKey);
    
    if (kDebugMode) {
      print('🔓 PIN protection disabled');
    }
  }
  
  /// Request approval for a file transfer
  Future<String> requestTransferApproval({
    required String fromPeerId,
    required String fromPeerName,
    required String fileName,
    required int fileSize,
    required TransferDirection direction,
    bool isTrustedPeer = false,
  }) async {
    // Check if approval is required
    if (!_authConfig.requireTransferApproval) {
      if (kDebugMode) {
        print('⚡ Transfer approved automatically (approval disabled)');
      }
      return 'auto_approved';
    }
    
    // Auto-approve for trusted peers if configured
    if (isTrustedPeer && _authConfig.autoApproveTrustedPeers) {
      if (kDebugMode) {
        print('⚡ Transfer auto-approved for trusted peer: $fromPeerName');
      }
      return 'auto_approved_trusted';
    }
    
    // Create approval request
    final approval = TransferApproval(
      id: _generateApprovalId(),
      fromPeerId: fromPeerId,
      fromPeerName: fromPeerName,
      fileName: fileName,
      fileSize: fileSize,
      direction: direction,
      requestedAt: DateTime.now(),
      status: ApprovalStatus.pending,
    );
    
    _pendingApprovals[approval.id] = approval;
    await _savePendingApprovals();
    
    if (kDebugMode) {
      print('📋 Transfer approval requested:');
      print('   - From: $fromPeerName ($fromPeerId)');
      print('   - File: $fileName (${_formatBytes(fileSize)})');
      print('   - Direction: $direction');
      print('   - Approval ID: ${approval.id}');
    }
    
    return approval.id;
  }
  
  /// Approve a pending transfer
  Future<void> approveTransfer(String approvalId) async {
    final approval = _pendingApprovals[approvalId];
    if (approval == null) {
      throw ArgumentError('Approval request $approvalId not found');
    }
    
    _pendingApprovals[approvalId] = approval.copyWith(
      status: ApprovalStatus.approved,
      respondedAt: DateTime.now(),
    );
    
    await _savePendingApprovals();
    
    if (kDebugMode) {
      print('✅ Transfer approved: ${approval.fileName} from ${approval.fromPeerName}');
    }
  }
  
  /// Deny a pending transfer
  Future<void> denyTransfer(String approvalId, [String? reason]) async {
    final approval = _pendingApprovals[approvalId];
    if (approval == null) {
      throw ArgumentError('Approval request $approvalId not found');
    }
    
    _pendingApprovals[approvalId] = approval.copyWith(
      status: ApprovalStatus.denied,
      respondedAt: DateTime.now(),
      denyReason: reason,
    );
    
    await _savePendingApprovals();
    
    if (kDebugMode) {
      print('❌ Transfer denied: ${approval.fileName} from ${approval.fromPeerName}');
      if (reason != null) print('   - Reason: $reason');
    }
  }
  
  /// Check if a transfer is approved
  bool isTransferApproved(String approvalId) {
    if (approvalId == 'auto_approved' || approvalId == 'auto_approved_trusted') {
      return true;
    }
    
    final approval = _pendingApprovals[approvalId];
    return approval?.status == ApprovalStatus.approved;
  }
  
  /// Get pending approvals
  List<TransferApproval> get pendingApprovals => 
      _pendingApprovals.values.where((a) => a.status == ApprovalStatus.pending).toList();
  
  /// Get all approvals (for history view)
  List<TransferApproval> get allApprovals => _pendingApprovals.values.toList();
  
  /// Clean up old approval records
  void cleanupOldApprovals() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final toRemove = <String>[];
    
    for (final entry in _pendingApprovals.entries) {
      if (entry.value.requestedAt.isBefore(cutoff) && 
          entry.value.status != ApprovalStatus.pending) {
        toRemove.add(entry.key);
      }
    }
    
    for (final id in toRemove) {
      _pendingApprovals.remove(id);
    }
    
    if (toRemove.isNotEmpty) {
      _savePendingApprovals();
      
      if (kDebugMode) {
        print('🧹 Cleaned up ${toRemove.length} old approval records');
      }
    }
  }
  
  /// Check if authentication is required for an operation
  bool isAuthRequired(String operation, {String? peerId}) {
    // Always require auth if device is locked
    if (_isDeviceLocked) return true;
    
    switch (operation) {
      case 'send_file':
        return _authConfig.requirePin || _authConfig.requireTransferApproval;
      case 'receive_file':
        return _authConfig.requireTransferApproval;
      case 'trust_peer':
        return _authConfig.requirePin;
      case 'change_settings':
        return _authConfig.requirePin;
      default:
        return false;
    }
  }
  
  /// Get failed attempts for an entity (device or peer)
  int getFailedAttempts(String entityId) {
    return _failedAttempts[entityId]?.count ?? 0;
  }
  
  /// Check if an entity is temporarily blocked
  bool isBlocked(String entityId) {
    final tracker = _failedAttempts[entityId];
    if (tracker == null) return false;
    
    final maxAttempts = _authConfig.maxFailedAttempts;
    if (tracker.count < maxAttempts) return false;
    
    final blockDuration = _getBlockDuration(tracker.count);
    final unblockTime = tracker.lastAttempt.add(blockDuration);
    
    return DateTime.now().isBefore(unblockTime);
  }
  
  /// Record a failed authentication attempt
  Future<void> _recordFailedAttempt(String entityId) async {
    final tracker = _failedAttempts[entityId] ?? FailedAttemptTracker(entityId: entityId);
    
    _failedAttempts[entityId] = FailedAttemptTracker(
      entityId: entityId,
      count: tracker.count + 1,
      lastAttempt: DateTime.now(),
    );
    
    await _saveFailedAttempts();
    
    if (kDebugMode) {
      final attempts = _failedAttempts[entityId]!.count;
      print('⚠️ Failed attempt #$attempts for $entityId');
      
      if (attempts >= _authConfig.maxFailedAttempts) {
        final blockDuration = _getBlockDuration(attempts);
        print('🚫 Entity $entityId blocked for ${blockDuration.inMinutes} minutes');
      }
    }
  }
  
  /// Clear failed attempts for an entity
  void _clearFailedAttempts(String entityId) {
    if (_failedAttempts.remove(entityId) != null) {
      _saveFailedAttempts();
      
      if (kDebugMode) {
        print('✅ Cleared failed attempts for $entityId');
      }
    }
  }
  
  /// Get block duration based on failed attempt count
  Duration _getBlockDuration(int attempts) {
    // Exponential backoff: 1min, 2min, 4min, 8min, 16min, 30min (max)
    final minutes = (1 << (attempts - _authConfig.maxFailedAttempts)).clamp(1, 30);
    return Duration(minutes: minutes);
  }
  
  /// Generate a unique approval ID
  String _generateApprovalId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999);
    return 'approval_${timestamp}_$random';
  }
  
  /// Generate salt for PIN hashing
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
  
  /// Hash PIN with salt using PBKDF2
  String _hashPin(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final pinBytes = utf8.encode(pin);
    
    // Simple HMAC-SHA256 based hash (in production, use proper PBKDF2)
    final hmac = Hmac(sha256, saltBytes);
    final digest = hmac.convert(pinBytes);
    
    return base64Encode(digest.bytes);
  }
  
  /// Format bytes for display
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Load stored data from preferences
  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load device PIN hash
    _devicePinHash = prefs.getString(_devicePinKey);
    _isDeviceLocked = _devicePinHash != null;
    
    // Load auth config
    final authConfigJson = prefs.getString(_authConfigKey);
    if (authConfigJson != null) {
      try {
        final data = json.decode(authConfigJson);
        _authConfig = AuthConfig.fromJson(data);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load auth config: $e');
        }
      }
    }
    
    // Load pending approvals
    final approvalsJson = prefs.getString(_pendingApprovalsKey);
    if (approvalsJson != null) {
      try {
        final data = json.decode(approvalsJson) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _pendingApprovals[entry.key] = TransferApproval.fromJson(entry.value);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load pending approvals: $e');
        }
      }
    }
    
    // Load failed attempts
    final attemptsJson = prefs.getString(_failedAttemptsKey);
    if (attemptsJson != null) {
      try {
        final data = json.decode(attemptsJson) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _failedAttempts[entry.key] = FailedAttemptTracker.fromJson(entry.value);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load failed attempts: $e');
        }
      }
    }
  }
  
  /// Save device PIN hash
  Future<void> _saveDevicePinHash() async {
    final prefs = await SharedPreferences.getInstance();
    if (_devicePinHash != null) {
      await prefs.setString(_devicePinKey, _devicePinHash!);
    } else {
      await prefs.remove(_devicePinKey);
    }
  }
  
  /// Save auth config
  Future<void> _saveAuthConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authConfigKey, json.encode(_authConfig.toJson()));
  }
  
  /// Save pending approvals
  Future<void> _savePendingApprovals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _pendingApprovals.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_pendingApprovalsKey, json.encode(data));
  }
  
  /// Save failed attempts
  Future<void> _saveFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _failedAttempts.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_failedAttemptsKey, json.encode(data));
  }
}

/// Authentication configuration
class AuthConfig {
  final bool requirePin;
  final bool requireTransferApproval;
  final bool autoApproveTrustedPeers;
  final int maxFailedAttempts;
  final Duration autoLockTimeout;
  
  const AuthConfig({
    this.requirePin = false,
    this.requireTransferApproval = true,
    this.autoApproveTrustedPeers = false,
    this.maxFailedAttempts = 3,
    this.autoLockTimeout = const Duration(minutes: 15),
  });
  
  /// Standard authentication configuration
  static const AuthConfig standard = AuthConfig(
    requirePin: false,
    requireTransferApproval: true,
    autoApproveTrustedPeers: false,
    maxFailedAttempts: 3,
    autoLockTimeout: Duration(minutes: 15),
  );
  
  /// Strict authentication configuration
  static const AuthConfig strict = AuthConfig(
    requirePin: true,
    requireTransferApproval: true,
    autoApproveTrustedPeers: false,
    maxFailedAttempts: 3,
    autoLockTimeout: Duration(minutes: 5),
  );
  
  /// Relaxed authentication configuration
  static const AuthConfig relaxed = AuthConfig(
    requirePin: false,
    requireTransferApproval: false,
    autoApproveTrustedPeers: true,
    maxFailedAttempts: 5,
    autoLockTimeout: Duration(hours: 1),
  );
  
  Map<String, dynamic> toJson() {
    return {
      'requirePin': requirePin,
      'requireTransferApproval': requireTransferApproval,
      'autoApproveTrustedPeers': autoApproveTrustedPeers,
      'maxFailedAttempts': maxFailedAttempts,
      'autoLockTimeoutMinutes': autoLockTimeout.inMinutes,
    };
  }
  
  static AuthConfig fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      requirePin: json['requirePin'] ?? false,
      requireTransferApproval: json['requireTransferApproval'] ?? true,
      autoApproveTrustedPeers: json['autoApproveTrustedPeers'] ?? false,
      maxFailedAttempts: json['maxFailedAttempts'] ?? 3,
      autoLockTimeout: Duration(minutes: json['autoLockTimeoutMinutes'] ?? 15),
    );
  }
}

/// Transfer approval request
class TransferApproval {
  final String id;
  final String fromPeerId;
  final String fromPeerName;
  final String fileName;
  final int fileSize;
  final TransferDirection direction;
  final DateTime requestedAt;
  final ApprovalStatus status;
  final DateTime? respondedAt;
  final String? denyReason;
  
  TransferApproval({
    required this.id,
    required this.fromPeerId,
    required this.fromPeerName,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.requestedAt,
    required this.status,
    this.respondedAt,
    this.denyReason,
  });
  
  TransferApproval copyWith({
    ApprovalStatus? status,
    DateTime? respondedAt,
    String? denyReason,
  }) {
    return TransferApproval(
      id: id,
      fromPeerId: fromPeerId,
      fromPeerName: fromPeerName,
      fileName: fileName,
      fileSize: fileSize,
      direction: direction,
      requestedAt: requestedAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      denyReason: denyReason ?? this.denyReason,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromPeerId': fromPeerId,
      'fromPeerName': fromPeerName,
      'fileName': fileName,
      'fileSize': fileSize,
      'direction': direction.toString(),
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.toString(),
      'respondedAt': respondedAt?.toIso8601String(),
      'denyReason': denyReason,
    };
  }
  
  static TransferApproval fromJson(Map<String, dynamic> json) {
    return TransferApproval(
      id: json['id'],
      fromPeerId: json['fromPeerId'],
      fromPeerName: json['fromPeerName'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      direction: TransferDirection.values.firstWhere(
        (e) => e.toString() == json['direction'],
      ),
      requestedAt: DateTime.parse(json['requestedAt']),
      status: ApprovalStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt']) 
          : null,
      denyReason: json['denyReason'],
    );
  }
}

/// Failed attempt tracker
class FailedAttemptTracker {
  final String entityId;
  final int count;
  final DateTime lastAttempt;
  
  FailedAttemptTracker({
    required this.entityId,
    this.count = 0,
    DateTime? lastAttempt,
  }) : lastAttempt = lastAttempt ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'entityId': entityId,
      'count': count,
      'lastAttempt': lastAttempt.toIso8601String(),
    };
  }
  
  static FailedAttemptTracker fromJson(Map<String, dynamic> json) {
    return FailedAttemptTracker(
      entityId: json['entityId'],
      count: json['count'] ?? 0,
      lastAttempt: DateTime.parse(json['lastAttempt']),
    );
  }
}

/// Transfer direction enum
enum TransferDirection { sent, received }

/// Approval status enum
enum ApprovalStatus { pending, approved, denied }

/// Security exception for authentication errors
class SecurityException implements Exception {
  final String message;
  
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}
