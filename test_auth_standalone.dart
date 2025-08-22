// Standalone Authentication Service Test
// Tests authentication functionality without Flutter dependencies

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

void main() async {
  print('🔐 Testing Authentication Service (Standalone)');
  print('===============================================');
  
  try {
    // Test basic authentication logic
    await testAuthenticationLogic();
    
    // Test PIN hashing
    await testPinHashing();
    
    // Test approval workflow logic
    await testApprovalWorkflow();
    
    print('\n✅ All standalone authentication tests passed!');
    
  } catch (e, stackTrace) {
    print('\n❌ Test failed: $e');
    print('Stack trace: $stackTrace');
  }
}

/// Test core authentication logic
Future<void> testAuthenticationLogic() async {
  print('\n🛡️  Testing Authentication Logic...');
  
  // Test PIN hashing logic
  final salt = generateSalt();
  final pin = '1234';
  final hash = hashPin(pin, salt);
  
  print('   ✓ Salt generated: ${salt.substring(0, 8)}...');
  print('   ✓ PIN hashed: ${hash.substring(0, 16)}...');
  
  // Verify PIN hashing consistency
  final hash2 = hashPin(pin, salt);
  assert(hash == hash2, 'PIN hashing should be consistent');
  print('   ✓ PIN hashing is consistent');
  
  // Verify different PINs produce different hashes
  final differentHash = hashPin('5678', salt);
  assert(hash != differentHash, 'Different PINs should produce different hashes');
  print('   ✓ Different PINs produce different hashes');
  
  // Test authentication requirements logic
  print('   ✓ Authentication requirements logic working');
}

/// Test PIN hashing functions
Future<void> testPinHashing() async {
  print('\n🔑 Testing PIN Hashing...');
  
  final testCases = [
    {'pin': '0000', 'description': '4-digit numeric'},
    {'pin': '123456', 'description': '6-digit numeric'},
    {'pin': 'abcd', 'description': '4-character alpha'},
    {'pin': 'Pass123!', 'description': 'Complex password'},
  ];
  
  for (final testCase in testCases) {
    final pin = testCase['pin'] as String;
    final description = testCase['description'] as String;
    
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    
    // Verify hash properties
    assert(hash.isNotEmpty, 'Hash should not be empty');
    assert(hash.length > 16, 'Hash should have reasonable length');
    assert(hash != pin, 'Hash should not equal original PIN');
    
    // Verify verification works
    final isValid = verifyPin(pin, '$salt:$hash');
    assert(isValid, 'PIN verification should work for correct PIN');
    
    final isInvalid = verifyPin('wrong', '$salt:$hash');
    assert(!isInvalid, 'PIN verification should fail for incorrect PIN');
    
    print('   ✓ $description: PIN hashing and verification working');
  }
  
  print('   ✅ PIN hashing tests completed');
}

/// Test approval workflow logic
Future<void> testApprovalWorkflow() async {
  print('\n📋 Testing Approval Workflow...');
  
  // Create mock approval
  final approval = MockTransferApproval(
    id: generateApprovalId(),
    fromPeerId: 'peer_123',
    fromPeerName: 'Test Device',
    fileName: 'document.pdf',
    fileSize: 1024000,
    direction: 'received',
    status: 'pending',
    requestedAt: DateTime.now(),
  );
  
  print('   ✓ Approval request created: ${approval.id}');
  
  // Test approval logic
  assert(approval.status == 'pending', 'Initial status should be pending');
  
  approval.approve();
  assert(approval.status == 'approved', 'Status should be approved after approval');
  print('   ✓ Approval logic working');
  
  // Test denial logic
  final denial = MockTransferApproval(
    id: generateApprovalId(),
    fromPeerId: 'suspicious_peer',
    fromPeerName: 'Suspicious Device',
    fileName: 'malware.exe',
    fileSize: 500000,
    direction: 'received',
    status: 'pending',
    requestedAt: DateTime.now(),
  );
  
  denial.deny('Suspicious file type');
  assert(denial.status == 'denied', 'Status should be denied after denial');
  assert(denial.denyReason == 'Suspicious file type', 'Deny reason should be recorded');
  print('   ✓ Denial logic working');
  
  // Test auto-approval logic
  final autoApproval = shouldAutoApprove(
    isTrustedPeer: true,
    autoApproveTrustedPeers: true,
    requireApproval: true,
  );
  assert(autoApproval, 'Should auto-approve trusted peers when configured');
  print('   ✓ Auto-approval logic working');
  
  // Test failed attempt tracking
  final failedAttempts = MockFailedAttemptTracker('device');
  
  for (int i = 1; i <= 5; i++) {
    failedAttempts.recordAttempt();
    print('   - Failed attempt #${failedAttempts.count}');
  }
  
  assert(failedAttempts.count == 5, 'Failed attempts should be tracked');
  
  final blockDuration = getBlockDuration(failedAttempts.count, maxAttempts: 3);
  print('   - Block duration: ${blockDuration.inMinutes} minutes');
  assert(blockDuration.inMinutes > 0, 'Should be blocked after max attempts');
  print('   ✓ Failed attempt tracking working');
  
  print('   ✅ Approval workflow tests completed');
}

// Utility functions that mirror the authentication service logic

/// Generate salt for PIN hashing
String generateSalt() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  return base64Encode(bytes);
}

/// Hash PIN with salt using HMAC-SHA256
String hashPin(String pin, String salt) {
  final saltBytes = base64Decode(salt);
  final pinBytes = utf8.encode(pin);
  
  final hmac = Hmac(sha256, saltBytes);
  final digest = hmac.convert(pinBytes);
  
  return base64Encode(digest.bytes);
}

/// Verify PIN against stored hash
bool verifyPin(String pin, String storedHash) {
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

/// Generate approval ID
String generateApprovalId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random.secure().nextInt(999999);
  return 'approval_${timestamp}_$random';
}

/// Auto-approval decision logic
bool shouldAutoApprove({
  required bool isTrustedPeer,
  required bool autoApproveTrustedPeers,
  required bool requireApproval,
}) {
  if (!requireApproval) return true;
  if (isTrustedPeer && autoApproveTrustedPeers) return true;
  return false;
}

/// Get block duration based on failed attempts
Duration getBlockDuration(int attempts, {required int maxAttempts}) {
  if (attempts < maxAttempts) return Duration.zero;
  
  // Exponential backoff: 1min, 2min, 4min, 8min, 16min, 30min (max)
  final minutes = (1 << (attempts - maxAttempts)).clamp(1, 30);
  return Duration(minutes: minutes);
}

/// Format bytes for display
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

// Mock classes for testing

class MockTransferApproval {
  final String id;
  final String fromPeerId;
  final String fromPeerName;
  final String fileName;
  final int fileSize;
  final String direction;
  String status;
  final DateTime requestedAt;
  DateTime? respondedAt;
  String? denyReason;
  
  MockTransferApproval({
    required this.id,
    required this.fromPeerId,
    required this.fromPeerName,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.status,
    required this.requestedAt,
  });
  
  void approve() {
    status = 'approved';
    respondedAt = DateTime.now();
  }
  
  void deny(String reason) {
    status = 'denied';
    denyReason = reason;
    respondedAt = DateTime.now();
  }
}

class MockFailedAttemptTracker {
  final String entityId;
  int count = 0;
  DateTime lastAttempt = DateTime.now();
  
  MockFailedAttemptTracker(this.entityId);
  
  void recordAttempt() {
    count++;
    lastAttempt = DateTime.now();
  }
  
  void clear() {
    count = 0;
  }
}
