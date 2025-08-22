import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';
import '../models/peer.dart';

/// Service for managing cryptographic keys and trusted peer relationships
class KeyManagementService {
  static const String _trustedPeersKey = 'stork_trusted_peers';
  static const String _knownKeysKey = 'stork_known_keys';
  static const String _securityConfigKey = 'stork_security_config';
  
  final EncryptionService _encryptionService;
  
  // Active secure sessions
  final Map<String, SecureSession> _activeSessions = {};
  
  // Trusted peers with their public keys
  final Map<String, TrustedPeer> _trustedPeers = {};
  
  // Known peer public keys (not necessarily trusted)
  final Map<String, String> _knownKeys = {};
  
  SecurityConfig _securityConfig = SecurityConfig.secure;
  
  bool _initialized = false;
  
  KeyManagementService(this._encryptionService);
  
  /// Initialize the key management service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _encryptionService.initialize();
    await _loadStoredData();
    
    _initialized = true;
    
    if (kDebugMode) {
      print('🔑 Key management service initialized');
      print('   - Trusted peers: ${_trustedPeers.length}');
      print('   - Known keys: ${_knownKeys.length}');
      print('   - Security config: ${_securityConfig.encryptionEnabled ? "Secure" : "Development"}');
    }
  }
  
  /// Get current security configuration
  SecurityConfig get securityConfig => _securityConfig;
  
  /// Update security configuration
  Future<void> updateSecurityConfig(SecurityConfig config) async {
    _securityConfig = config;
    await _saveSecurityConfig();
    
    if (kDebugMode) {
      print('🔧 Security configuration updated:');
      print('   - Encryption: ${config.encryptionEnabled}');
      print('   - Authentication: ${config.requireAuthentication}');
      print('   - Anonymous transfers: ${config.allowAnonymousTransfers}');
    }
  }
  
  /// Add a peer's public key to known keys
  Future<void> addKnownKey(String peerId, String publicKey) async {
    _knownKeys[peerId] = publicKey;
    await _saveKnownKeys();
    
    if (kDebugMode) {
      print('🔑 Added public key for peer: $peerId');
    }
  }
  
  /// Get a peer's public key if known
  String? getKnownKey(String peerId) {
    return _knownKeys[peerId];
  }
  
  /// Trust a peer (moves from known to trusted)
  Future<void> trustPeer(String peerId, String displayName, {String? publicKey}) async {
    final peerPublicKey = publicKey ?? _knownKeys[peerId];
    if (peerPublicKey == null) {
      throw StateError('Cannot trust peer $peerId: no public key known');
    }
    
    final trustedPeer = TrustedPeer(
      id: peerId,
      displayName: displayName,
      publicKey: peerPublicKey,
      trustedAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );
    
    _trustedPeers[peerId] = trustedPeer;
    await _saveTrustedPeers();
    
    if (kDebugMode) {
      print('✅ Trusted peer: $displayName ($peerId)');
    }
  }
  
  /// Untrust a peer (removes from trusted list)
  Future<void> untrustPeer(String peerId) async {
    final removed = _trustedPeers.remove(peerId);
    if (removed != null) {
      await _saveTrustedPeers();
      
      // Terminate any active sessions with this peer
      _terminateSessionsForPeer(peerId);
      
      if (kDebugMode) {
        print('❌ Untrusted peer: ${removed.displayName} ($peerId)');
      }
    }
  }
  
  /// Check if a peer is trusted
  bool isPeerTrusted(String peerId) {
    return _trustedPeers.containsKey(peerId);
  }
  
  /// Get all trusted peers
  List<TrustedPeer> get trustedPeers => _trustedPeers.values.toList();
  
  /// Create a secure session with a peer
  Future<SecureSession?> createSecureSession(String peerId, String displayName) async {
    if (!_initialized) throw StateError('Key management service not initialized');
    
    // Check if encryption is enabled
    if (!_securityConfig.encryptionEnabled) {
      if (kDebugMode) {
        print('⚠️ Encryption disabled - no secure session created');
      }
      return null;
    }
    
    // Check if authentication is required and peer is trusted
    if (_securityConfig.requireAuthentication && !isPeerTrusted(peerId)) {
      throw SecurityException('Peer $peerId is not trusted and authentication is required');
    }
    
    // Get peer's public key
    final peerPublicKey = _knownKeys[peerId] ?? _trustedPeers[peerId]?.publicKey;
    if (peerPublicKey == null) {
      throw SecurityException('No public key available for peer $peerId');
    }
    
    try {
      // Create secure session
      final session = await _encryptionService.createSession(peerPublicKey, peerId);
      _activeSessions[session.sessionId] = session;
      
      // Update last seen for trusted peers
      if (_trustedPeers.containsKey(peerId)) {
        _trustedPeers[peerId] = _trustedPeers[peerId]!.copyWith(lastSeen: DateTime.now());
        await _saveTrustedPeers();
      }
      
      if (kDebugMode) {
        print('🔒 Created secure session with $displayName ($peerId)');
      }
      
      return session;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to create secure session with $peerId: $e');
      }
      rethrow;
    }
  }
  
  /// Accept a secure session from a peer
  Future<SecureSession?> acceptSecureSession({
    required String sessionId,
    required String peerId,
    required String encryptedAesKey,
    required String displayName,
  }) async {
    if (!_initialized) throw StateError('Key management service not initialized');
    
    // Check if encryption is enabled
    if (!_securityConfig.encryptionEnabled) {
      if (kDebugMode) {
        print('⚠️ Encryption disabled - no secure session accepted');
      }
      return null;
    }
    
    // Check if authentication is required and peer is trusted
    if (_securityConfig.requireAuthentication && !isPeerTrusted(peerId)) {
      throw SecurityException('Peer $peerId is not trusted and authentication is required');
    }
    
    try {
      // Accept secure session
      final session = await _encryptionService.acceptSession(
        sessionId: sessionId,
        peerId: peerId,
        encryptedAesKey: encryptedAesKey,
      );
      
      _activeSessions[sessionId] = session;
      
      // Update last seen for trusted peers
      if (_trustedPeers.containsKey(peerId)) {
        _trustedPeers[peerId] = _trustedPeers[peerId]!.copyWith(lastSeen: DateTime.now());
        await _saveTrustedPeers();
      }
      
      if (kDebugMode) {
        print('🔓 Accepted secure session from $displayName ($peerId)');
      }
      
      return session;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to accept secure session from $peerId: $e');
      }
      rethrow;
    }
  }
  
  /// Get an active session
  SecureSession? getActiveSession(String sessionId) {
    return _activeSessions[sessionId];
  }
  
  /// Terminate a session
  void terminateSession(String sessionId) {
    final session = _activeSessions.remove(sessionId);
    if (session != null && kDebugMode) {
      print('🔚 Terminated session: $sessionId');
    }
  }
  
  /// Terminate all sessions for a peer
  void _terminateSessionsForPeer(String peerId) {
    final sessionsToRemove = <String>[];
    
    for (final entry in _activeSessions.entries) {
      if (entry.value.peerId == peerId) {
        sessionsToRemove.add(entry.key);
      }
    }
    
    for (final sessionId in sessionsToRemove) {
      terminateSession(sessionId);
    }
  }
  
  /// Clean up expired sessions
  void cleanupExpiredSessions() {
    final expiredSessions = <String>[];
    
    for (final entry in _activeSessions.entries) {
      if (entry.value.isExpired) {
        expiredSessions.add(entry.key);
      }
    }
    
    for (final sessionId in expiredSessions) {
      terminateSession(sessionId);
    }
    
    if (expiredSessions.isNotEmpty && kDebugMode) {
      print('🧹 Cleaned up ${expiredSessions.length} expired sessions');
    }
  }
  
  /// Get this device's public key for sharing
  String getDevicePublicKey() {
    return _encryptionService.getPublicKeyPem();
  }
  
  /// Get this device's ID
  String getDeviceId() {
    return _encryptionService.getDeviceId();
  }
  
  /// Check if a transfer should be encrypted
  bool shouldEncryptTransfer(String peerId) {
    if (!_securityConfig.encryptionEnabled) return false;
    if (_securityConfig.requireAuthentication && !isPeerTrusted(peerId)) return false;
    return true;
  }
  
  /// Export trusted peers for backup
  Map<String, dynamic> exportTrustedPeers() {
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'device_id': getDeviceId(),
      'trusted_peers': _trustedPeers.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
  
  /// Import trusted peers from backup
  Future<int> importTrustedPeers(Map<String, dynamic> data) async {
    if (data['version'] != 1) {
      throw ArgumentError('Unsupported backup version: ${data['version']}');
    }
    
    final trustedPeersData = data['trusted_peers'] as Map<String, dynamic>;
    int imported = 0;
    
    for (final entry in trustedPeersData.entries) {
      try {
        final peer = TrustedPeer.fromJson(entry.value);
        _trustedPeers[entry.key] = peer;
        _knownKeys[peer.id] = peer.publicKey;
        imported++;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to import trusted peer ${entry.key}: $e');
        }
      }
    }
    
    await _saveTrustedPeers();
    await _saveKnownKeys();
    
    if (kDebugMode) {
      print('📥 Imported $imported trusted peers');
    }
    
    return imported;
  }
  
  /// Load stored data from preferences
  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load security config
    final configJson = prefs.getString(_securityConfigKey);
    if (configJson != null) {
      try {
        final data = json.decode(configJson);
        _securityConfig = SecurityConfig(
          encryptionEnabled: data['encryptionEnabled'] ?? true,
          requireAuthentication: data['requireAuthentication'] ?? true,
          allowAnonymousTransfers: data['allowAnonymousTransfers'] ?? false,
          sessionTimeout: Duration(hours: data['sessionTimeoutHours'] ?? 24),
          maxFailedAttempts: data['maxFailedAttempts'] ?? 3,
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load security config: $e');
        }
      }
    }
    
    // Load trusted peers
    final trustedPeersJson = prefs.getString(_trustedPeersKey);
    if (trustedPeersJson != null) {
      try {
        final data = json.decode(trustedPeersJson) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _trustedPeers[entry.key] = TrustedPeer.fromJson(entry.value);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load trusted peers: $e');
        }
      }
    }
    
    // Load known keys
    final knownKeysJson = prefs.getString(_knownKeysKey);
    if (knownKeysJson != null) {
      try {
        final data = json.decode(knownKeysJson) as Map<String, dynamic>;
        _knownKeys.addAll(data.cast<String, String>());
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load known keys: $e');
        }
      }
    }
  }
  
  /// Save security config to preferences
  Future<void> _saveSecurityConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'encryptionEnabled': _securityConfig.encryptionEnabled,
      'requireAuthentication': _securityConfig.requireAuthentication,
      'allowAnonymousTransfers': _securityConfig.allowAnonymousTransfers,
      'sessionTimeoutHours': _securityConfig.sessionTimeout.inHours,
      'maxFailedAttempts': _securityConfig.maxFailedAttempts,
    };
    await prefs.setString(_securityConfigKey, json.encode(data));
  }
  
  /// Save trusted peers to preferences
  Future<void> _saveTrustedPeers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _trustedPeers.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_trustedPeersKey, json.encode(data));
  }
  
  /// Save known keys to preferences
  Future<void> _saveKnownKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_knownKeysKey, json.encode(_knownKeys));
  }
}

/// Represents a trusted peer with their cryptographic information
class TrustedPeer {
  final String id;
  final String displayName;
  final String publicKey;
  final DateTime trustedAt;
  final DateTime lastSeen;
  
  TrustedPeer({
    required this.id,
    required this.displayName,
    required this.publicKey,
    required this.trustedAt,
    required this.lastSeen,
  });
  
  /// Create a copy with updated fields
  TrustedPeer copyWith({
    String? displayName,
    DateTime? lastSeen,
  }) {
    return TrustedPeer(
      id: id,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey,
      trustedAt: trustedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'publicKey': publicKey,
      'trustedAt': trustedAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
    };
  }
  
  /// Create from JSON data
  static TrustedPeer fromJson(Map<String, dynamic> json) {
    return TrustedPeer(
      id: json['id'],
      displayName: json['displayName'],
      publicKey: json['publicKey'],
      trustedAt: DateTime.parse(json['trustedAt']),
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }
  
  /// Convert to regular peer model for UI compatibility
  Peer toPeer(String host, int port) {
    return Peer(name: displayName, host: host, port: port);
  }
}

/// Security-related exceptions
class SecurityException implements Exception {
  final String message;
  
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}
