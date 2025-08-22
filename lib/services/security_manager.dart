import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication_service.dart';
import 'key_management_service.dart';
import 'encryption_service.dart';

/// Central security manager that coordinates all security services
/// Provides a clean, unified API for the UI to interact with security features
class SecurityManager extends ChangeNotifier {
  static SecurityManager? _instance;
  static SecurityManager get instance {
    _instance ??= SecurityManager._internal();
    return _instance!;
  }
  
  SecurityManager._internal();
  
  // Security services
  late final AuthenticationService _authService;
  late final KeyManagementService _keyService;
  late final EncryptionService _encryptionService;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Security state
  bool get isPinRequired => _authService.hasPinProtection;
  bool get isLocked => _authService.isDeviceLocked;
  
  // Settings storage keys
  static const String _requireApprovalKey = 'security_require_approval';
  static const String _autoApproveTrustedKey = 'security_auto_approve_trusted';
  
  // Cached settings
  bool? _requireApproval;
  bool? _autoApproveTrusted;
  
  /// Initialize all security services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔒 Initializing Security Manager...');
      
      // Initialize services in dependency order
      _encryptionService = EncryptionService();
      _authService = AuthenticationService();
      _keyService = KeyManagementService(_encryptionService);
      
      await _encryptionService.initialize();
      await _authService.initialize();
      await _keyService.initialize();
      
      _isInitialized = true;
      
      debugPrint('✅ Security Manager initialized successfully');
      notifyListeners();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize Security Manager: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Check if this is the first time the app is being launched
  bool get isFirstLaunch => !_authService.hasPinProtection;
  
  /// Setup PIN for first-time users
  Future<bool> setupPin(String pin) async {
    try {
      await _authService.setupPin(pin);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to setup PIN: $e');
      return false;
    }
  }
  
  /// Verify PIN for authentication
  Future<bool> verifyPin(String pin) async {
    try {
      final success = await _authService.verifyPin(pin);
      if (success) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('PIN verification failed: $e');
      return false;
    }
  }
  
  /// Change PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // First verify the old PIN, then remove it and setup new one
      if (await _authService.verifyPin(oldPin)) {
        await _authService.removePin(oldPin);
        await _authService.setupPin(newPin);
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Failed to change PIN: $e');
      return false;
    }
  }
  
  /// Remove PIN protection
  Future<bool> removePin(String currentPin) async {
    try {
      // First verify the current PIN
      if (await _authService.verifyPin(currentPin)) {
        await _authService.removePin(currentPin);
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Failed to remove PIN: $e');
      return false;
    }
  }
  
  /// Get transfer approval setting
  Future<bool> getRequireApproval() async {
    if (_requireApproval == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _requireApproval = prefs.getBool(_requireApprovalKey) ?? true; // Default to true for security
      } catch (e) {
        debugPrint('Failed to load requireApproval setting: $e');
        _requireApproval = true;
      }
    }
    return _requireApproval!;
  }
  
  /// Set transfer approval setting
  Future<bool> setRequireApproval(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireApprovalKey, value);
      _requireApproval = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to save requireApproval setting: $e');
      return false;
    }
  }
  
  /// Get auto-approve trusted peers setting
  Future<bool> getAutoApproveTrusted() async {
    if (_autoApproveTrusted == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _autoApproveTrusted = prefs.getBool(_autoApproveTrustedKey) ?? false; // Default to false for security
      } catch (e) {
        debugPrint('Failed to load autoApproveTrusted setting: $e');
        _autoApproveTrusted = false;
      }
    }
    return _autoApproveTrusted!;
  }
  
  /// Set auto-approve trusted peers setting
  Future<bool> setAutoApproveTrusted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoApproveTrustedKey, value);
      _autoApproveTrusted = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to save autoApproveTrusted setting: $e');
      return false;
    }
  }
  
  /// Get security configuration
  Future<SecurityConfiguration> getSecurityConfigurationAsync() async {
    return SecurityConfiguration(
      requirePin: isPinRequired,
      requireApproval: await getRequireApproval(),
      autoApproveTrustedPeers: await getAutoApproveTrusted(),
      maxPinAttempts: 3,
      sessionTimeoutMinutes: 60,
      autoTrustThreshold: 0.7,
      enableSecurityAlerts: true,
    );
  }
  
  /// Get security configuration (synchronous version for compatibility)
  SecurityConfiguration getSecurityConfiguration() {
    return SecurityConfiguration(
      requirePin: isPinRequired,
      requireApproval: _requireApproval ?? true, // Default to true for security
      autoApproveTrustedPeers: _autoApproveTrusted ?? false, // Default to false for security
      maxPinAttempts: 3,
      sessionTimeoutMinutes: 60,
      autoTrustThreshold: 0.7,
      enableSecurityAlerts: true,
    );
  }
  
  /// Check if a peer is trusted
  bool isTrustedPeer(String peerId) {
    return _keyService.isPeerTrusted(peerId);
  }
  
  /// Add a trusted peer
  Future<void> addTrustedPeer(String peerId, String peerName, String publicKey) async {
    await _keyService.trustPeer(peerId, peerName, publicKey: publicKey);
    notifyListeners();
  }
  
  /// Remove a trusted peer
  Future<void> removeTrustedPeer(String peerId) async {
    await _keyService.untrustPeer(peerId);
    notifyListeners();
  }
  
  /// Get list of trusted peers
  List<TrustedPeer> getTrustedPeers() {
    return _keyService.trustedPeers;
  }
  
  /// Check if a transfer should be auto-approved
  Future<bool> shouldAutoApprove(String peerId) async {
    // For now, only auto-approve if peer is explicitly trusted
    return isTrustedPeer(peerId);
  }
  
  /// Request approval for a transfer
  Future<String> requestTransferApproval({
    required String peerId,
    required String peerName,
    required String fileName,
    required int fileSize,
    required SecurityTransferDirection direction,
  }) async {
    // Convert SecurityTransferDirection to TransferDirection
    final transferDirection = direction == SecurityTransferDirection.sent 
        ? TransferDirection.sent 
        : TransferDirection.received;
    
    return await _authService.requestTransferApproval(
      fromPeerId: peerId,
      fromPeerName: peerName,
      fileName: fileName,
      fileSize: fileSize,
      direction: transferDirection,
      isTrustedPeer: isTrustedPeer(peerId),
    );
  }
  
  /// Approve a transfer
  Future<void> approveTransfer(String approvalId) async {
    await _authService.approveTransfer(approvalId);
    notifyListeners();
  }
  
  /// Deny a transfer
  Future<void> denyTransfer(String approvalId, String reason) async {
    await _authService.denyTransfer(approvalId, reason);
    notifyListeners();
  }
  
  /// Get pending transfer approvals
  List<TransferApproval> getPendingApprovals() {
    return _authService.pendingApprovals;
  }
  
  /// Lock the app (require PIN re-entry)
  void lockApp() {
    _authService.lockDevice();
    notifyListeners();
  }
  
  /// Clean shutdown
  @override
  Future<void> dispose() async {
    // Service classes don't have dispose methods, just clean up listeners
    super.dispose();
  }
}

/// Security configuration class
class SecurityConfiguration {
  final bool requirePin;
  final bool requireApproval;
  final bool autoApproveTrustedPeers;
  final int maxPinAttempts;
  final int sessionTimeoutMinutes;
  final double autoTrustThreshold;
  final bool enableSecurityAlerts;
  
  const SecurityConfiguration({
    required this.requirePin,
    required this.requireApproval,
    required this.autoApproveTrustedPeers,
    required this.maxPinAttempts,
    required this.sessionTimeoutMinutes,
    required this.autoTrustThreshold,
    required this.enableSecurityAlerts,
  });
}

/// Security transfer direction enum
enum SecurityTransferDirection { sent, received }

// Use the real TrustedPeer and TransferApproval classes from the service files
// They are imported automatically from the service imports
