// Standalone Key Management Service Test
// Tests key management functionality without Flutter dependencies

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

void main() async {
  print('🔑 Testing Key Management Service (Standalone)');
  print('==============================================');
  
  try {
    // Test peer management
    await testPeerManagement();
    
    // Test key generation and validation
    await testKeyGeneration();
    
    // Test session management
    await testSessionManagement();
    
    // Test trust management
    await testTrustManagement();
    
    print('\n✅ All standalone key management tests passed!');
    
  } catch (e, stackTrace) {
    print('\n❌ Test failed: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Test peer management functionality
Future<void> testPeerManagement() async {
  print('\n👥 Testing Peer Management...');
  
  final keyManager = MockKeyManager();
  
  // Test adding trusted peer
  final peerId = 'peer_123';
  final peerName = 'Test Device';
  final publicKey = generateMockPublicKey();
  
  await keyManager.addTrustedPeer(peerId, peerName, publicKey);
  
  assert(keyManager.isTrustedPeer(peerId), 'Peer should be trusted after adding');
  print('   ✓ Added trusted peer: $peerName');
  
  // Test retrieving peer info
  final peerInfo = keyManager.getTrustedPeer(peerId);
  assert(peerInfo != null, 'Should retrieve peer info');
  assert(peerInfo!.name == peerName, 'Peer name should match');
  assert(peerInfo!.publicKey == publicKey, 'Public key should match');
  print('   ✓ Retrieved peer info successfully');
  
  // Test listing peers
  final peers = keyManager.listTrustedPeers();
  assert(peers.length == 1, 'Should have one trusted peer');
  assert(peers.first.id == peerId, 'Peer ID should match');
  print('   ✓ Listed trusted peers successfully');
  
  // Test removing peer
  await keyManager.removeTrustedPeer(peerId);
  assert(!keyManager.isTrustedPeer(peerId), 'Peer should not be trusted after removal');
  print('   ✓ Removed trusted peer successfully');
  
  print('   ✅ Peer management tests completed');
}

/// Test key generation and validation
Future<void> testKeyGeneration() async {
  print('\n🔐 Testing Key Generation...');
  
  // Test device key generation
  final deviceKeys = generateDeviceKeyPair();
  assert(deviceKeys.privateKey.isNotEmpty, 'Private key should not be empty');
  assert(deviceKeys.publicKey.isNotEmpty, 'Public key should not be empty');
  assert(deviceKeys.privateKey != deviceKeys.publicKey, 'Private and public keys should be different');
  print('   ✓ Device key pair generated');
  
  // Test session key generation
  final sessionKey = generateSessionKey();
  assert(sessionKey.isNotEmpty, 'Session key should not be empty');
  assert(sessionKey.length == 44, 'Session key should be 32 bytes base64 encoded'); // 32 * 4/3 ≈ 44 chars
  print('   ✓ Session key generated: ${sessionKey.substring(0, 8)}...');
  
  // Test key validation
  assert(isValidPublicKey(deviceKeys.publicKey), 'Generated public key should be valid');
  assert(!isValidPublicKey('invalid_key'), 'Invalid key should not validate');
  assert(!isValidPublicKey(''), 'Empty key should not validate');
  print('   ✓ Key validation working');
  
  // Test different session keys
  final sessionKey2 = generateSessionKey();
  assert(sessionKey != sessionKey2, 'Different session keys should be generated');
  print('   ✓ Session key uniqueness verified');
  
  print('   ✅ Key generation tests completed');
}

/// Test session management
Future<void> testSessionManagement() async {
  print('\n🔗 Testing Session Management...');
  
  final sessionManager = MockSessionManager();
  
  // Create test session
  final sessionId = generateSessionId();
  final peerId = 'peer_456';
  final sessionKey = generateSessionKey();
  
  final session = MockSecureSession(
    id: sessionId,
    peerId: peerId,
    sessionKey: sessionKey,
    createdAt: DateTime.now(),
    lastUsedAt: DateTime.now(),
    isActive: true,
  );
  
  await sessionManager.createSession(session);
  print('   ✓ Session created: ${session.id}');
  
  // Test session retrieval
  final retrieved = sessionManager.getSession(sessionId);
  assert(retrieved != null, 'Should retrieve created session');
  assert(retrieved!.peerId == peerId, 'Peer ID should match');
  assert(retrieved!.sessionKey == sessionKey, 'Session key should match');
  print('   ✓ Session retrieved successfully');
  
  // Test session activity update
  await Future.delayed(Duration(milliseconds: 10));
  await sessionManager.updateSessionActivity(sessionId);
  
  final updated = sessionManager.getSession(sessionId);
  assert(updated!.lastUsedAt.isAfter(session.lastUsedAt), 'Last used time should be updated');
  print('   ✓ Session activity updated');
  
  // Test session expiry
  final expiredSession = MockSecureSession(
    id: generateSessionId(),
    peerId: 'peer_789',
    sessionKey: generateSessionKey(),
    createdAt: DateTime.now().subtract(Duration(hours: 25)), // Expired
    lastUsedAt: DateTime.now().subtract(Duration(hours: 25)),
    isActive: true,
  );
  
  await sessionManager.createSession(expiredSession);
  
  final isExpired = sessionManager.isSessionExpired(expiredSession.id);
  assert(isExpired, 'Old session should be expired');
  print('   ✓ Session expiry detection working');
  
  // Test cleanup
  final cleanedUp = await sessionManager.cleanupExpiredSessions();
  assert(cleanedUp >= 1, 'Should clean up at least one expired session');
  print('   ✓ Expired sessions cleaned up: $cleanedUp');
  
  // Test listing active sessions
  final activeSessions = sessionManager.getActiveSessions();
  assert(activeSessions.isNotEmpty, 'Should have active sessions');
  assert(activeSessions.every((s) => s.isActive), 'All listed sessions should be active');
  print('   ✓ Active sessions listed: ${activeSessions.length}');
  
  print('   ✅ Session management tests completed');
}

/// Test trust management
Future<void> testTrustManagement() async {
  print('\n🛡️  Testing Trust Management...');
  
  final trustManager = MockTrustManager();
  
  // Test manual trust
  final peerId1 = 'manual_peer';
  await trustManager.setTrustLevel(peerId1, TrustLevel.trusted);
  
  assert(trustManager.getTrustLevel(peerId1) == TrustLevel.trusted, 'Should be manually trusted');
  print('   ✓ Manual trust assignment working');
  
  // Test automatic trust through usage
  final peerId2 = 'usage_peer';
  
  // Simulate successful transfers
  for (int i = 0; i < 10; i++) {
    await trustManager.recordSuccessfulTransfer(peerId2);
  }
  
  final trustScore = trustManager.calculateTrustScore(peerId2);
  assert(trustScore > 0.5, 'Trust score should increase with successful transfers');
  print('   ✓ Trust score calculation: ${trustScore.toStringAsFixed(2)}');
  
  // Test trust degradation
  for (int i = 0; i < 3; i++) {
    await trustManager.recordFailedTransfer(peerId2);
  }
  
  final degradedScore = trustManager.calculateTrustScore(peerId2);
  assert(degradedScore < trustScore, 'Trust score should decrease with failed transfers');
  print('   ✓ Trust degradation: ${degradedScore.toStringAsFixed(2)}');
  
  // Test blacklisting
  final peerId3 = 'malicious_peer';
  await trustManager.setTrustLevel(peerId3, TrustLevel.blocked);
  
  assert(trustManager.getTrustLevel(peerId3) == TrustLevel.blocked, 'Should be blocked');
  assert(!trustManager.shouldAllowTransfer(peerId3), 'Should not allow transfer from blocked peer');
  print('   ✓ Blacklisting working');
  
  // Test trust thresholds
  final peerId4 = 'threshold_peer';
  await trustManager.setTrustLevel(peerId4, TrustLevel.unknown);
  
  // Should allow with manual approval
  assert(trustManager.shouldAllowTransfer(peerId4, requireApproval: true), 'Should allow unknown peer with approval');
  
  // Should not allow without approval based on settings
  final allowWithoutApproval = trustManager.shouldAllowTransfer(peerId4, requireApproval: false, autoTrustThreshold: 0.8);
  assert(!allowWithoutApproval, 'Should not auto-allow unknown peer with high threshold');
  print('   ✓ Trust thresholds working');
  
  print('   ✅ Trust management tests completed');
}

// Mock classes and utility functions

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

bool isValidPublicKey(String key) {
  if (key.isEmpty) return false;
  
  try {
    final decoded = base64Decode(key);
    return decoded.length >= 16; // Minimum reasonable key size
  } catch (e) {
    return false;
  }
}
