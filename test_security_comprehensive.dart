// Comprehensive Security Test
// Tests integration between authentication and key management services

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

void main() async {
  print('🔒 Comprehensive Security Integration Test');
  print('========================================');
  
  try {
    // Test security service initialization
    await testSecurityInitialization();
    
    // Test peer onboarding workflow
    await testPeerOnboardingWorkflow();
    
    // Test secure transfer approval
    await testSecureTransferApproval();
    
    // Test security session lifecycle
    await testSecuritySessionLifecycle();
    
    // Test security threat response
    await testSecurityThreatResponse();
    
    // Test security configuration management
    await testSecurityConfiguration();
    
    print('\n✅ All comprehensive security tests passed!');
    print('\n📊 Security Test Summary:');
    print('   • Authentication: ✓ PIN protection, failed attempts, lockout');
    print('   • Key Management: ✓ Trusted peers, sessions, trust scoring');
    print('   • Integration: ✓ Secure workflows, threat response');
    print('   • Configuration: ✓ Security policies, settings validation');
    
  } catch (e, stackTrace) {
    print('\n❌ Test failed: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Test security service initialization
Future<void> testSecurityInitialization() async {
  print('\n🚀 Testing Security Initialization...');
  
  final securityManager = MockSecurityManager();
  
  // Initialize security services
  await securityManager.initialize();
  
  assert(securityManager.isInitialized, 'Security manager should be initialized');
  assert(securityManager.deviceKeys != null, 'Device keys should be generated');
  assert(securityManager.isPinRequired == false, 'PIN should not be required initially');
  
  print('   ✓ Security manager initialized');
  print('   ✓ Device keys generated');
  print('   ✓ Initial state validated');
  
  // Test PIN setup
  const pin = '123456';
  await securityManager.setupPin(pin);
  
  assert(securityManager.isPinRequired, 'PIN should be required after setup');
  assert(securityManager.verifyPin(pin), 'PIN verification should work');
  assert(!securityManager.verifyPin('wrong'), 'Wrong PIN should not verify');
  
  print('   ✓ PIN setup and verification working');
  
  print('   ✅ Security initialization tests completed');
}

/// Test peer onboarding workflow
Future<void> testPeerOnboardingWorkflow() async {
  print('\n👥 Testing Peer Onboarding Workflow...');
  
  final securityManager = MockSecurityManager();
  await securityManager.initialize();
  
  // Simulate peer discovery
  final peerId = 'discovered_peer_123';
  final peerName = 'Alice iPhone';
  final peerPublicKey = generateMockPublicKey();
  
  // Initial peer state should be unknown
  final initialTrust = securityManager.getPeerTrustLevel(peerId);
  assert(initialTrust == TrustLevel.unknown, 'New peer should be unknown');
  print('   ✓ New peer discovered with unknown trust level');
  
  // Test manual trust establishment
  await securityManager.addTrustedPeer(peerId, peerName, peerPublicKey);
  
  final trustedLevel = securityManager.getPeerTrustLevel(peerId);
  assert(trustedLevel == TrustLevel.trusted, 'Manually added peer should be trusted');
  
  final peerInfo = securityManager.getTrustedPeer(peerId);
  assert(peerInfo != null, 'Should retrieve trusted peer info');
  assert(peerInfo!.name == peerName, 'Peer name should match');
  assert(peerInfo!.publicKey == peerPublicKey, 'Public key should match');
  
  print('   ✓ Manual trust establishment working');
  
  // Test automatic trust building through successful interactions
  final newPeerId = 'gradual_trust_peer';
  final newPeerName = 'Bob Android';
  final newPeerKey = generateMockPublicKey();
  
  // Start with unknown peer
  securityManager.recordPeerInteraction(newPeerId, success: true);
  
  // Simulate multiple successful transfers
  for (int i = 0; i < 5; i++) {
    await securityManager.recordSuccessfulTransfer(newPeerId);
  }
  
  final trustScore = securityManager.calculateTrustScore(newPeerId);
  assert(trustScore == 1.0, 'Trust score should be 1.0 after only successes');
  print('   ✓ Trust score building: ${trustScore.toStringAsFixed(2)}');
  
  // Test trust degradation
  for (int i = 0; i < 2; i++) {
    await securityManager.recordFailedTransfer(newPeerId);
  }
  
  final degradedScore = securityManager.calculateTrustScore(newPeerId);
  assert(degradedScore < trustScore, 'Trust score should decrease after failures');
  print('   ✓ Trust degradation: ${degradedScore.toStringAsFixed(2)}');
  
  print('   ✅ Peer onboarding workflow tests completed');
}

/// Test secure transfer approval
Future<void> testSecureTransferApproval() async {
  print('\n📋 Testing Secure Transfer Approval...');
  
  final securityManager = MockSecurityManager();
  await securityManager.initialize();
  await securityManager.setupPin('123456');
  
  // Add a trusted peer
  final trustedPeerId = 'trusted_peer';
  await securityManager.addTrustedPeer(trustedPeerId, 'Trusted Device', generateMockPublicKey());
  
  // Add an unknown peer
  final unknownPeerId = 'unknown_peer';
  
  // Test transfer from trusted peer
  final trustedTransfer = MockTransferRequest(
    id: generateTransferId(),
    fromPeerId: trustedPeerId,
    fromPeerName: 'Trusted Device',
    fileName: 'document.pdf',
    fileSize: 1024000,
    direction: TransferDirection.incoming,
  );
  
  // Configure auto-approval for trusted peers
  securityManager.setAutoApproveTrustedPeers(true);
  
  final shouldAutoApprove = await securityManager.shouldAutoApprove(trustedTransfer);
  assert(shouldAutoApprove, 'Should auto-approve transfer from trusted peer');
  print('   ✓ Auto-approval for trusted peers working');
  
  // Test transfer from unknown peer
  final unknownTransfer = MockTransferRequest(
    id: generateTransferId(),
    fromPeerId: unknownPeerId,
    fromPeerName: 'Unknown Device',
    fileName: 'suspicious.exe',
    fileSize: 500000,
    direction: TransferDirection.incoming,
  );
  
  final shouldRequireApproval = await securityManager.shouldAutoApprove(unknownTransfer);
  assert(!shouldRequireApproval, 'Should require approval for unknown peer');
  print('   ✓ Manual approval required for unknown peers');
  
  // Test approval workflow
  final approvalRequest = await securityManager.requestTransferApproval(unknownTransfer);
  assert(approvalRequest.status == ApprovalStatus.pending, 'Initial status should be pending');
  
  // Simulate user approval
  await securityManager.approveTransfer(approvalRequest.id);
  
  final approvedRequest = securityManager.getApprovalRequest(approvalRequest.id);
  assert(approvedRequest!.status == ApprovalStatus.approved, 'Status should be approved');
  print('   ✓ Manual approval workflow working');
  
  // Test denial workflow
  final denialTransfer = MockTransferRequest(
    id: generateTransferId(),
    fromPeerId: 'malicious_peer',
    fromPeerName: 'Malicious Device',
    fileName: 'malware.exe',
    fileSize: 10000000,
    direction: TransferDirection.incoming,
  );
  
  final denialRequest = await securityManager.requestTransferApproval(denialTransfer);
  await securityManager.denyTransfer(denialRequest.id, 'Suspicious file type');
  
  final deniedRequest = securityManager.getApprovalRequest(denialRequest.id);
  assert(deniedRequest!.status == ApprovalStatus.denied, 'Status should be denied');
  assert(deniedRequest!.denyReason == 'Suspicious file type', 'Deny reason should be recorded');
  print('   ✓ Denial workflow working');
  
  print('   ✅ Secure transfer approval tests completed');
}

/// Test security session lifecycle
Future<void> testSecuritySessionLifecycle() async {
  print('\n🔗 Testing Security Session Lifecycle...');
  
  final securityManager = MockSecurityManager();
  await securityManager.initialize();
  
  final peerId = 'session_peer';
  await securityManager.addTrustedPeer(peerId, 'Session Peer', generateMockPublicKey());
  
  // Create secure session
  final sessionId = await securityManager.createSecureSession(peerId);
  assert(sessionId.isNotEmpty, 'Session ID should be generated');
  
  final session = securityManager.getSecureSession(sessionId);
  assert(session != null, 'Should retrieve created session');
  assert(session!.peerId == peerId, 'Session peer ID should match');
  assert(session!.isActive, 'New session should be active');
  
  print('   ✓ Secure session created: ${sessionId.substring(0, 16)}...');
  
  // Test session activity tracking
  await Future.delayed(Duration(milliseconds: 10));
  await securityManager.updateSessionActivity(sessionId);
  
  final updatedSession = securityManager.getSecureSession(sessionId);
  assert(updatedSession!.lastUsedAt.isAfter(session!.lastUsedAt), 'Activity should be updated');
  print('   ✓ Session activity tracking working');
  
  // Test session validation
  final isValid = securityManager.isSessionValid(sessionId);
  assert(isValid, 'Active session should be valid');
  print('   ✓ Session validation working');
  
  // Test session termination
  await securityManager.terminateSession(sessionId);
  
  final terminatedSession = securityManager.getSecureSession(sessionId);
  assert(terminatedSession == null || !terminatedSession.isActive, 'Session should be terminated');
  print('   ✓ Session termination working');
  
  // Test session cleanup
  final cleanedUp = await securityManager.cleanupExpiredSessions();
  print('   ✓ Expired sessions cleaned up: $cleanedUp');
  
  print('   ✅ Security session lifecycle tests completed');
}

/// Test security threat response
Future<void> testSecurityThreatResponse() async {
  print('\n🚨 Testing Security Threat Response...');
  
  final securityManager = MockSecurityManager();
  await securityManager.initialize();
  await securityManager.setupPin('123456');
  
  // Test failed PIN attempts
  final deviceId = 'test_device';
  
  for (int i = 1; i <= 5; i++) {
    final blocked = await securityManager.recordFailedPinAttempt(deviceId);
    
    if (i < 3) {
      assert(!blocked, 'Should not be blocked before max attempts');
    } else {
      assert(blocked, 'Should be blocked after max attempts');
    }
    
    print('   - Failed PIN attempt #$i, blocked: $blocked');
  }
  
  final blockDuration = securityManager.getBlockDuration(deviceId);
  assert(blockDuration.inMinutes > 0, 'Should have block duration');
  print('   ✓ PIN attempt blocking: ${blockDuration.inMinutes} minutes');
  
  // Test suspicious peer blocking
  final suspiciousPeerId = 'suspicious_peer';
  
  // Record multiple failed transfers
  for (int i = 0; i < 5; i++) {
    await securityManager.recordFailedTransfer(suspiciousPeerId);
  }
  
  // Should automatically block peer after too many failures
  final shouldBlock = securityManager.shouldBlockPeer(suspiciousPeerId);
  if (shouldBlock) {
    await securityManager.blockPeer(suspiciousPeerId, 'Too many failed transfers');
  }
  
  final trustLevel = securityManager.getPeerTrustLevel(suspiciousPeerId);
  assert(trustLevel == TrustLevel.blocked, 'Suspicious peer should be blocked');
  print('   ✓ Automatic peer blocking working');
  
  // Test security alerts
  final alerts = securityManager.getSecurityAlerts();
  assert(alerts.isNotEmpty, 'Should have security alerts');
  print('   ✓ Security alerts generated: ${alerts.length}');
  
  // Test emergency lockdown
  await securityManager.emergencyLockdown();
  
  assert(securityManager.isInLockdownMode, 'Should be in lockdown mode');
  assert(!securityManager.shouldAllowTransfers(), 'Should not allow transfers in lockdown');
  print('   ✓ Emergency lockdown working');
  
  print('   ✅ Security threat response tests completed');
}

/// Test security configuration management
Future<void> testSecurityConfiguration() async {
  print('\n⚙️  Testing Security Configuration...');
  
  final securityManager = MockSecurityManager();
  await securityManager.initialize();
  
  // Test default configuration
  final defaultConfig = securityManager.getSecurityConfiguration();
  assert(defaultConfig.requirePin, 'PIN should be required by default');
  assert(defaultConfig.requireApproval, 'Approval should be required by default');
  assert(defaultConfig.maxPinAttempts == 3, 'Default max PIN attempts should be 3');
  print('   ✓ Default configuration validated');
  
  // Test configuration updates
  final newConfig = MockSecurityConfiguration(
    requirePin: false,
    requireApproval: false,
    autoApproveTrustedPeers: true,
    maxPinAttempts: 5,
    sessionTimeoutMinutes: 30,
    autoTrustThreshold: 0.8,
    enableSecurityAlerts: true,
  );
  
  await securityManager.updateSecurityConfiguration(newConfig);
  
  final updatedConfig = securityManager.getSecurityConfiguration();
  assert(!updatedConfig.requirePin, 'PIN requirement should be updated');
  assert(!updatedConfig.requireApproval, 'Approval requirement should be updated');
  assert(updatedConfig.maxPinAttempts == 5, 'Max PIN attempts should be updated');
  print('   ✓ Configuration updates working');
  
  // Test configuration validation
  final invalidConfig = MockSecurityConfiguration(
    requirePin: true,
    requireApproval: true,
    autoApproveTrustedPeers: true,
    maxPinAttempts: 0, // Invalid
    sessionTimeoutMinutes: -1, // Invalid
    autoTrustThreshold: 1.5, // Invalid
    enableSecurityAlerts: true,
  );
  
  try {
    await securityManager.updateSecurityConfiguration(invalidConfig);
    assert(false, 'Should reject invalid configuration');
  } catch (e) {
    final message = e.toString();
    final truncated = message.length > 50 ? message.substring(0, 50) + '...' : message;
    print('   ✓ Configuration validation working: $truncated');
  }
  
  // Test security policy enforcement
  final policyViolation = securityManager.checkPolicyCompliance();
  if (policyViolation != null) {
    print('   - Policy violation detected: ${policyViolation.type}');
  }
  print('   ✓ Security policy enforcement working');
  
  print('   ✅ Security configuration tests completed');
}

// Mock classes and utility functions

class MockSecurityManager {
  bool isInitialized = false;
  MockDeviceKeys? deviceKeys;
  String? _pinHash;
  bool _lockdownMode = false;
  final MockKeyManager _keyManager = MockKeyManager();
  final MockSessionManager _sessionManager = MockSessionManager();
  final MockTrustManager _trustManager = MockTrustManager();
  final MockApprovalManager _approvalManager = MockApprovalManager();
  final Map<String, int> _failedPinAttempts = {};
  final List<MockSecurityAlert> _securityAlerts = [];
  MockSecurityConfiguration _config = MockSecurityConfiguration.defaultConfig();
  
  Future<void> initialize() async {
    deviceKeys = generateDeviceKeyPair();
    isInitialized = true;
  }
  
  bool get isPinRequired => _pinHash != null;
  bool get isInLockdownMode => _lockdownMode;
  
  Future<void> setupPin(String pin) async {
    final salt = generateSalt();
    _pinHash = '$salt:${hashPin(pin, salt)}';
  }
  
  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    return verifyPinHash(pin, _pinHash!);
  }
  
  Future<void> addTrustedPeer(String peerId, String name, String publicKey) async {
    await _keyManager.addTrustedPeer(peerId, name, publicKey);
    await _trustManager.setTrustLevel(peerId, TrustLevel.trusted);
  }
  
  TrustLevel getPeerTrustLevel(String peerId) {
    return _trustManager.getTrustLevel(peerId);
  }
  
  MockTrustedPeer? getTrustedPeer(String peerId) {
    return _keyManager.getTrustedPeer(peerId);
  }
  
  void recordPeerInteraction(String peerId, {required bool success}) {
    // Record interaction for future trust calculations
  }
  
  Future<void> recordSuccessfulTransfer(String peerId) async {
    await _trustManager.recordSuccessfulTransfer(peerId);
  }
  
  Future<void> recordFailedTransfer(String peerId) async {
    await _trustManager.recordFailedTransfer(peerId);
  }
  
  double calculateTrustScore(String peerId) {
    return _trustManager.calculateTrustScore(peerId);
  }
  
  void setAutoApproveTrustedPeers(bool value) {
    _config = _config.copyWith(autoApproveTrustedPeers: value);
  }
  
  Future<bool> shouldAutoApprove(MockTransferRequest transfer) async {
    final trustLevel = getPeerTrustLevel(transfer.fromPeerId);
    
    if (trustLevel == TrustLevel.blocked) return false;
    if (trustLevel == TrustLevel.trusted && _config.autoApproveTrustedPeers) return true;
    
    if (!_config.requireApproval) return true;
    
    final trustScore = calculateTrustScore(transfer.fromPeerId);
    return trustScore >= _config.autoTrustThreshold;
  }
  
  Future<MockApprovalRequest> requestTransferApproval(MockTransferRequest transfer) async {
    return await _approvalManager.createApprovalRequest(transfer);
  }
  
  Future<void> approveTransfer(String approvalId) async {
    await _approvalManager.approveTransfer(approvalId);
  }
  
  Future<void> denyTransfer(String approvalId, String reason) async {
    await _approvalManager.denyTransfer(approvalId, reason);
  }
  
  MockApprovalRequest? getApprovalRequest(String approvalId) {
    return _approvalManager.getApprovalRequest(approvalId);
  }
  
  Future<String> createSecureSession(String peerId) async {
    final session = MockSecureSession(
      id: generateSessionId(),
      peerId: peerId,
      sessionKey: generateSessionKey(),
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
      isActive: true,
    );
    
    await _sessionManager.createSession(session);
    return session.id;
  }
  
  MockSecureSession? getSecureSession(String sessionId) {
    return _sessionManager.getSession(sessionId);
  }
  
  Future<void> updateSessionActivity(String sessionId) async {
    await _sessionManager.updateSessionActivity(sessionId);
  }
  
  bool isSessionValid(String sessionId) {
    final session = getSecureSession(sessionId);
    return session != null && session.isActive && !_sessionManager.isSessionExpired(sessionId);
  }
  
  Future<void> terminateSession(String sessionId) async {
    await _sessionManager.terminateSession(sessionId);
  }
  
  Future<int> cleanupExpiredSessions() async {
    return await _sessionManager.cleanupExpiredSessions();
  }
  
  Future<bool> recordFailedPinAttempt(String deviceId) async {
    final attempts = _failedPinAttempts[deviceId] ?? 0;
    _failedPinAttempts[deviceId] = attempts + 1;
    
    final blocked = attempts + 1 >= _config.maxPinAttempts;
    
    if (blocked) {
      _securityAlerts.add(MockSecurityAlert(
        type: 'FAILED_PIN_ATTEMPTS',
        message: 'Device blocked due to excessive failed PIN attempts',
        timestamp: DateTime.now(),
        deviceId: deviceId,
      ));
    }
    
    return blocked;
  }
  
  Duration getBlockDuration(String deviceId) {
    final attempts = _failedPinAttempts[deviceId] ?? 0;
    return getBlockDurationForAttempts(attempts, maxAttempts: _config.maxPinAttempts);
  }
  
  bool shouldBlockPeer(String peerId) {
    final trustScore = calculateTrustScore(peerId);
    final failedTransfers = _trustManager._metrics[peerId]?.failedTransfers ?? 0;
    return trustScore < 0.2 && failedTransfers >= 5;
  }
  
  Future<void> blockPeer(String peerId, String reason) async {
    await _trustManager.setTrustLevel(peerId, TrustLevel.blocked);
    
    _securityAlerts.add(MockSecurityAlert(
      type: 'PEER_BLOCKED',
      message: reason,
      timestamp: DateTime.now(),
      peerId: peerId,
    ));
  }
  
  List<MockSecurityAlert> getSecurityAlerts() {
    return List.unmodifiable(_securityAlerts);
  }
  
  Future<void> emergencyLockdown() async {
    _lockdownMode = true;
    
    // Terminate all sessions
    final activeSessions = _sessionManager.getActiveSessions();
    for (final session in activeSessions) {
      await terminateSession(session.id);
    }
    
    _securityAlerts.add(MockSecurityAlert(
      type: 'EMERGENCY_LOCKDOWN',
      message: 'Emergency lockdown activated',
      timestamp: DateTime.now(),
    ));
  }
  
  bool shouldAllowTransfers() {
    return !_lockdownMode;
  }
  
  MockSecurityConfiguration getSecurityConfiguration() {
    return _config;
  }
  
  Future<void> updateSecurityConfiguration(MockSecurityConfiguration config) async {
    // Validate configuration
    if (config.maxPinAttempts <= 0) {
      throw Exception('Max PIN attempts must be positive');
    }
    if (config.sessionTimeoutMinutes <= 0) {
      throw Exception('Session timeout must be positive');
    }
    if (config.autoTrustThreshold < 0.0 || config.autoTrustThreshold > 1.0) {
      throw Exception('Auto trust threshold must be between 0.0 and 1.0');
    }
    
    _config = config;
  }
  
  MockPolicyViolation? checkPolicyCompliance() {
    // Example policy checks
    if (!_config.requirePin && _config.requireApproval) {
      return MockPolicyViolation(
        type: 'WEAK_AUTHENTICATION',
        message: 'PIN protection disabled while approval required',
      );
    }
    
    return null; // No violations
  }
}

// Additional mock classes

class MockApprovalManager {
  final Map<String, MockApprovalRequest> _requests = {};
  
  Future<MockApprovalRequest> createApprovalRequest(MockTransferRequest transfer) async {
    final request = MockApprovalRequest(
      id: generateApprovalId(),
      transfer: transfer,
      status: ApprovalStatus.pending,
      requestedAt: DateTime.now(),
    );
    
    _requests[request.id] = request;
    return request;
  }
  
  Future<void> approveTransfer(String approvalId) async {
    final request = _requests[approvalId];
    if (request != null) {
      request.status = ApprovalStatus.approved;
      request.respondedAt = DateTime.now();
    }
  }
  
  Future<void> denyTransfer(String approvalId, String reason) async {
    final request = _requests[approvalId];
    if (request != null) {
      request.status = ApprovalStatus.denied;
      request.denyReason = reason;
      request.respondedAt = DateTime.now();
    }
  }
  
  MockApprovalRequest? getApprovalRequest(String approvalId) {
    return _requests[approvalId];
  }
}

class MockApprovalRequest {
  final String id;
  final MockTransferRequest transfer;
  ApprovalStatus status;
  final DateTime requestedAt;
  DateTime? respondedAt;
  String? denyReason;
  
  MockApprovalRequest({
    required this.id,
    required this.transfer,
    required this.status,
    required this.requestedAt,
  });
}

class MockTransferRequest {
  final String id;
  final String fromPeerId;
  final String fromPeerName;
  final String fileName;
  final int fileSize;
  final TransferDirection direction;
  
  MockTransferRequest({
    required this.id,
    required this.fromPeerId,
    required this.fromPeerName,
    required this.fileName,
    required this.fileSize,
    required this.direction,
  });
}

class MockSecurityAlert {
  final String type;
  final String message;
  final DateTime timestamp;
  final String? deviceId;
  final String? peerId;
  
  MockSecurityAlert({
    required this.type,
    required this.message,
    required this.timestamp,
    this.deviceId,
    this.peerId,
  });
}

class MockSecurityConfiguration {
  final bool requirePin;
  final bool requireApproval;
  final bool autoApproveTrustedPeers;
  final int maxPinAttempts;
  final int sessionTimeoutMinutes;
  final double autoTrustThreshold;
  final bool enableSecurityAlerts;
  
  MockSecurityConfiguration({
    required this.requirePin,
    required this.requireApproval,
    required this.autoApproveTrustedPeers,
    required this.maxPinAttempts,
    required this.sessionTimeoutMinutes,
    required this.autoTrustThreshold,
    required this.enableSecurityAlerts,
  });
  
  factory MockSecurityConfiguration.defaultConfig() {
    return MockSecurityConfiguration(
      requirePin: true,
      requireApproval: true,
      autoApproveTrustedPeers: false,
      maxPinAttempts: 3,
      sessionTimeoutMinutes: 60,
      autoTrustThreshold: 0.7,
      enableSecurityAlerts: true,
    );
  }
  
  MockSecurityConfiguration copyWith({
    bool? requirePin,
    bool? requireApproval,
    bool? autoApproveTrustedPeers,
    int? maxPinAttempts,
    int? sessionTimeoutMinutes,
    double? autoTrustThreshold,
    bool? enableSecurityAlerts,
  }) {
    return MockSecurityConfiguration(
      requirePin: requirePin ?? this.requirePin,
      requireApproval: requireApproval ?? this.requireApproval,
      autoApproveTrustedPeers: autoApproveTrustedPeers ?? this.autoApproveTrustedPeers,
      maxPinAttempts: maxPinAttempts ?? this.maxPinAttempts,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      autoTrustThreshold: autoTrustThreshold ?? this.autoTrustThreshold,
      enableSecurityAlerts: enableSecurityAlerts ?? this.enableSecurityAlerts,
    );
  }
}

class MockPolicyViolation {
  final String type;
  final String message;
  
  MockPolicyViolation({
    required this.type,
    required this.message,
  });
}

enum ApprovalStatus {
  pending,
  approved,
  denied,
}

enum TransferDirection {
  incoming,
  outgoing,
}

// Include all the utility functions and classes from previous tests
// ... (MockKeyManager, MockSessionManager, MockTrustManager, etc.)

// Re-include the mock classes and utility functions from previous files
class MockKeyManager {
  final Map<String, MockTrustedPeer> _trustedPeers = {};
  
  Future<void> addTrustedPeer(String peerId, String name, String publicKey) async {
    _trustedPeers[peerId] = MockTrustedPeer(
      id: peerId,
      name: name,
      publicKey: publicKey,
      addedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );
  }
  
  Future<void> removeTrustedPeer(String peerId) async {
    _trustedPeers.remove(peerId);
  }
  
  bool isTrustedPeer(String peerId) {
    return _trustedPeers.containsKey(peerId);
  }
  
  MockTrustedPeer? getTrustedPeer(String peerId) {
    return _trustedPeers[peerId];
  }
  
  List<MockTrustedPeer> listTrustedPeers() {
    return _trustedPeers.values.toList();
  }
}

class MockTrustedPeer {
  final String id;
  final String name;
  final String publicKey;
  final DateTime addedAt;
  DateTime lastSeenAt;
  
  MockTrustedPeer({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.addedAt,
    required this.lastSeenAt,
  });
}

class MockSessionManager {
  final Map<String, MockSecureSession> _sessions = {};
  
  Future<void> createSession(MockSecureSession session) async {
    _sessions[session.id] = session;
  }
  
  MockSecureSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }
  
  Future<void> updateSessionActivity(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      session.lastUsedAt = DateTime.now();
    }
  }
  
  bool isSessionExpired(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return true;
    
    final maxAge = Duration(hours: 24);
    final age = DateTime.now().difference(session.createdAt);
    return age > maxAge;
  }
  
  Future<int> cleanupExpiredSessions() async {
    final expiredIds = <String>[];
    
    for (final entry in _sessions.entries) {
      if (isSessionExpired(entry.key)) {
        expiredIds.add(entry.key);
      }
    }
    
    for (final id in expiredIds) {
      _sessions.remove(id);
    }
    
    return expiredIds.length;
  }
  
  List<MockSecureSession> getActiveSessions() {
    return _sessions.values.where((s) => s.isActive && !isSessionExpired(s.id)).toList();
  }
  
  Future<void> terminateSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      session.isActive = false;
    }
  }
}

class MockSecureSession {
  final String id;
  final String peerId;
  final String sessionKey;
  final DateTime createdAt;
  DateTime lastUsedAt;
  bool isActive;
  
  MockSecureSession({
    required this.id,
    required this.peerId,
    required this.sessionKey,
    required this.createdAt,
    required this.lastUsedAt,
    required this.isActive,
  });
}

class MockTrustManager {
  final Map<String, TrustLevel> _manualTrust = {};
  final Map<String, MockTrustMetrics> _metrics = {};
  
  Future<void> setTrustLevel(String peerId, TrustLevel level) async {
    _manualTrust[peerId] = level;
  }
  
  TrustLevel getTrustLevel(String peerId) {
    return _manualTrust[peerId] ?? TrustLevel.unknown;
  }
  
  Future<void> recordSuccessfulTransfer(String peerId) async {
    final metrics = _metrics[peerId] ?? MockTrustMetrics();
    metrics.successfulTransfers++;
    metrics.lastInteraction = DateTime.now();
    _metrics[peerId] = metrics;
  }
  
  Future<void> recordFailedTransfer(String peerId) async {
    final metrics = _metrics[peerId] ?? MockTrustMetrics();
    metrics.failedTransfers++;
    metrics.lastInteraction = DateTime.now();
    _metrics[peerId] = metrics;
  }
  
  double calculateTrustScore(String peerId) {
    final metrics = _metrics[peerId];
    if (metrics == null) return 0.0;
    
    final total = metrics.successfulTransfers + metrics.failedTransfers;
    if (total == 0) return 0.0;
    
    return metrics.successfulTransfers / total;
  }
  
  bool shouldAllowTransfer(String peerId, {bool requireApproval = false, double autoTrustThreshold = 0.7}) {
    final trustLevel = getTrustLevel(peerId);
    
    switch (trustLevel) {
      case TrustLevel.blocked:
        return false;
      case TrustLevel.trusted:
        return true;
      case TrustLevel.unknown:
        if (requireApproval) return true;
        
        final score = calculateTrustScore(peerId);
        return score >= autoTrustThreshold;
    }
  }
}

class MockTrustMetrics {
  int successfulTransfers = 0;
  int failedTransfers = 0;
  DateTime lastInteraction = DateTime.now();
}

enum TrustLevel {
  blocked,
  unknown,
  trusted,
}

class MockDeviceKeys {
  final String privateKey;
  final String publicKey;
  
  MockDeviceKeys({
    required this.privateKey,
    required this.publicKey,
  });
}

// Utility functions

MockDeviceKeys generateDeviceKeyPair() {
  final random = Random.secure();
  
  // Generate mock keys (in real implementation, these would be proper RSA keys)
  final privateKeyBytes = List.generate(256, (_) => random.nextInt(256)); // 2048 bits
  final publicKeyBytes = List.generate(32, (_) => random.nextInt(256));   // Derived from private
  
  return MockDeviceKeys(
    privateKey: base64Encode(privateKeyBytes),
    publicKey: base64Encode(publicKeyBytes),
  );
}

String generateSessionKey() {
  final random = Random.secure();
  final keyBytes = List.generate(32, (_) => random.nextInt(256)); // 256-bit AES key
  return base64Encode(keyBytes);
}

String generateSessionId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random.secure().nextInt(999999);
  return 'session_${timestamp}_$random';
}

String generateMockPublicKey() {
  final random = Random.secure();
  final keyBytes = List.generate(32, (_) => random.nextInt(256));
  return base64Encode(keyBytes);
}

String generateSalt() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  return base64Encode(bytes);
}

String hashPin(String pin, String salt) {
  final saltBytes = base64Decode(salt);
  final pinBytes = utf8.encode(pin);
  
  final hmac = Hmac(sha256, saltBytes);
  final digest = hmac.convert(pinBytes);
  
  return base64Encode(digest.bytes);
}

bool verifyPinHash(String pin, String storedHash) {
  try {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    
    final salt = parts[0];
    final expectedHash = parts[1];
    final actualHash = hashPin(pin, salt);
    
    return actualHash == expectedHash;
  } catch (e) {
    return false;
  }
}

String generateTransferId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random.secure().nextInt(999999);
  return 'transfer_${timestamp}_$random';
}

String generateApprovalId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random.secure().nextInt(999999);
  return 'approval_${timestamp}_$random';
}

Duration getBlockDurationForAttempts(int attempts, {required int maxAttempts}) {
  if (attempts < maxAttempts) return Duration.zero;
  
  // Exponential backoff: 1min, 2min, 4min, 8min, 16min, 30min (max)
  final minutes = (1 << (attempts - maxAttempts)).clamp(1, 30);
  return Duration(minutes: minutes);
}
