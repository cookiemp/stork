import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/pointycastle.dart' hide SecureRandom;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling end-to-end encryption of file transfers
/// Uses RSA-2048 for key exchange and AES-256-GCM for file encryption
class EncryptionService {
  static const String _privateKeyKey = 'stork_private_key';
  static const String _publicKeyKey = 'stork_public_key';
  static const String _deviceIdKey = 'stork_device_id';
  
  // RSA key size for key exchange
  static const int rsaKeySize = 2048;
  
  // AES key size (256 bits = 32 bytes)
  static const int aesKeySize = 32;
  
  // IV size for AES-GCM (96 bits = 12 bytes)
  static const int ivSize = 12;
  
  late RSAPrivateKey _privateKey;
  late RSAPublicKey _publicKey;
  late String _deviceId;
  
  bool _initialized = false;
  
  /// Initialize the encryption service with device keys
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate or load device ID
      _deviceId = prefs.getString(_deviceIdKey) ?? _generateDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId);
      
      // Check if we have existing keys
      final privateKeyPem = prefs.getString(_privateKeyKey);
      final publicKeyPem = prefs.getString(_publicKeyKey);
      
      if (privateKeyPem != null && publicKeyPem != null) {
        // Load existing keys
        _privateKey = _parsePrivateKey(privateKeyPem);
        _publicKey = _parsePublicKey(publicKeyPem);
        
        if (kDebugMode) {
          print('🔐 Loaded existing RSA key pair for device: $_deviceId');
        }
      } else {
        // Generate new key pair
        await _generateKeyPair();
        
        // Save keys to preferences
        await prefs.setString(_privateKeyKey, _encodePrivateKey(_privateKey));
        await prefs.setString(_publicKeyKey, _encodePublicKey(_publicKey));
        
        if (kDebugMode) {
          print('🔐 Generated new RSA key pair for device: $_deviceId');
        }
      }
      
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize encryption service: $e');
      }
      rethrow;
    }
  }
  
  /// Get this device's public key in PEM format for sharing
  String getPublicKeyPem() {
    if (!_initialized) throw StateError('Encryption service not initialized');
    return _encodePublicKey(_publicKey);
  }
  
  /// Get this device's ID
  String getDeviceId() {
    if (!_initialized) throw StateError('Encryption service not initialized');
    return _deviceId;
  }
  
  /// Create a secure session for file transfer with a peer
  Future<SecureSession> createSession(String peerPublicKeyPem, String peerId) async {
    if (!_initialized) throw StateError('Encryption service not initialized');
    
    try {
      // Parse peer's public key
      final peerPublicKey = _parsePublicKey(peerPublicKeyPem);
      
      // Generate a random AES key for this session
      final aesKey = _generateSecureRandom(aesKeySize);
      
      // Encrypt the AES key with peer's public key
      final encryptedAesKeyBytes = _encryptWithRSA(aesKey, peerPublicKey);
      final encryptedAesKey = base64.encode(encryptedAesKeyBytes);
      
      // Create session
      final session = SecureSession(
        sessionId: _generateSessionId(),
        deviceId: _deviceId,
        peerId: peerId,
        aesKey: aesKey,
        encryptedAesKey: encryptedAesKey,
        createdAt: DateTime.now(),
      );
      
      if (kDebugMode) {
        print('🔒 Created secure session ${session.sessionId} with peer $peerId');
      }
      
      return session;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to create secure session: $e');
      }
      rethrow;
    }
  }
  
  /// Accept a secure session from a peer
  Future<SecureSession> acceptSession({
    required String sessionId,
    required String peerId,
    required String encryptedAesKey,
  }) async {
    if (!_initialized) throw StateError('Encryption service not initialized');
    
    try {
      // Decrypt the AES key with our private key
      final aesKey = _decryptWithRSA(base64.decode(encryptedAesKey), _privateKey);
      
      // Create session
      final session = SecureSession(
        sessionId: sessionId,
        deviceId: _deviceId,
        peerId: peerId,
        aesKey: aesKey,
        encryptedAesKey: encryptedAesKey,
        createdAt: DateTime.now(),
      );
      
      if (kDebugMode) {
        print('🔓 Accepted secure session $sessionId from peer $peerId');
      }
      
      return session;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to accept secure session: $e');
      }
      rethrow;
    }
  }
  
  /// Encrypt file data using AES-256-GCM
  Uint8List encryptData(Uint8List data, SecureSession session) {
    try {
      // Generate random IV
      final iv = _generateSecureRandom(ivSize);
      
      // Create encrypter
      final key = encrypt.Key(session.aesKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      
      // Encrypt data
      final encrypted = encrypter.encryptBytes(data, iv: encrypt.IV(iv));
      
      // Combine IV + encrypted data + auth tag
      final result = Uint8List(iv.length + encrypted.bytes.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, result.length, encrypted.bytes);
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to encrypt data: $e');
      }
      rethrow;
    }
  }
  
  /// Decrypt file data using AES-256-GCM
  Uint8List decryptData(Uint8List encryptedData, SecureSession session) {
    try {
      // Extract IV
      final iv = encryptedData.sublist(0, ivSize);
      
      // Extract encrypted data
      final ciphertext = encryptedData.sublist(ivSize);
      
      // Create encrypter
      final key = encrypt.Key(session.aesKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      
      // Decrypt data
      final encrypted = encrypt.Encrypted(ciphertext);
      final decrypted = encrypter.decryptBytes(encrypted, iv: encrypt.IV(iv));
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to decrypt data: $e');
      }
      rethrow;
    }
  }
  
  /// Generate a new RSA key pair
  Future<void> _generateKeyPair() async {
    final keyGen = RSAKeyGenerator();
    final params = RSAKeyGeneratorParameters(BigInt.from(65537), rsaKeySize, 80);
    keyGen.init(ParametersWithRandom(params, _getSecureRandom()));
    
    final keyPair = keyGen.generateKeyPair();
    _privateKey = keyPair.privateKey as RSAPrivateKey;
    _publicKey = keyPair.publicKey as RSAPublicKey;
  }
  
  /// Encrypt data with RSA public key
  Uint8List _encryptWithRSA(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(data);
  }
  
  /// Decrypt data with RSA private key
  Uint8List _decryptWithRSA(Uint8List encryptedData, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding(RSAEngine());
    cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return cipher.process(encryptedData);
  }
  
  /// Generate cryptographically secure random bytes
  Uint8List _generateSecureRandom(int length) {
    final random = _getSecureRandom();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextUint8();
    }
    return bytes;
  }
  
  /// Get secure random number generator
  SecureRandom _getSecureRandom() {
    final random = Random.secure();
    final seed = List.generate(32, (_) => random.nextInt(256));
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));
    return secureRandom;
  }
  
  /// Generate a unique device ID
  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 22); // Remove padding
  }
  
  /// Generate a unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999);
    return 'session_${timestamp}_$random';
  }
  
  /// Parse JSON-encoded private key (simplified storage format)
  RSAPrivateKey _parsePrivateKey(String jsonKey) {
    final data = json.decode(jsonKey);
    return RSAPrivateKey(
      BigInt.parse(data['n']),
      BigInt.parse(data['d']),
      BigInt.parse(data['p']),
      BigInt.parse(data['q']),
    );
  }
  
  /// Parse JSON-encoded public key (simplified storage format)
  RSAPublicKey _parsePublicKey(String jsonKey) {
    final data = json.decode(jsonKey);
    return RSAPublicKey(
      BigInt.parse(data['n']),
      BigInt.parse(data['e']),
    );
  }
  
  /// Encode private key to JSON format (simplified storage)
  String _encodePrivateKey(RSAPrivateKey key) {
    return json.encode({
      'type': 'RSAPrivateKey',
      'n': key.n!.toString(),
      'd': key.d!.toString(),
      'p': key.p!.toString(),
      'q': key.q!.toString(),
    });
  }
  
  /// Encode public key to JSON format (simplified storage)
  String _encodePublicKey(RSAPublicKey key) {
    return json.encode({
      'type': 'RSAPublicKey',
      'n': key.n!.toString(),
      'e': key.e!.toString(),
    });
  }
}

/// Represents a secure session between two devices
class SecureSession {
  final String sessionId;
  final String deviceId;
  final String peerId;
  final Uint8List aesKey;
  final String encryptedAesKey;
  final DateTime createdAt;
  
  SecureSession({
    required this.sessionId,
    required this.deviceId,
    required this.peerId,
    required this.aesKey,
    required this.encryptedAesKey,
    required this.createdAt,
  });
  
  /// Check if session has expired (24 hours)
  bool get isExpired {
    return DateTime.now().difference(createdAt).inHours > 24;
  }
  
  /// Get session info for debugging
  Map<String, dynamic> toDebugMap() {
    return {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'peerId': peerId,
      'createdAt': createdAt.toIso8601String(),
      'isExpired': isExpired,
      'aesKeyLength': aesKey.length,
    };
  }
}

/// Security configuration for transfers
class SecurityConfig {
  final bool encryptionEnabled;
  final bool requireAuthentication;
  final bool allowAnonymousTransfers;
  final Duration sessionTimeout;
  final int maxFailedAttempts;
  
  const SecurityConfig({
    this.encryptionEnabled = true,
    this.requireAuthentication = true,
    this.allowAnonymousTransfers = false,
    this.sessionTimeout = const Duration(hours: 24),
    this.maxFailedAttempts = 3,
  });
  
  /// Default secure configuration
  static const SecurityConfig secure = SecurityConfig(
    encryptionEnabled: true,
    requireAuthentication: true,
    allowAnonymousTransfers: false,
    sessionTimeout: Duration(hours: 24),
    maxFailedAttempts: 3,
  );
  
  /// Development configuration (less secure)
  static const SecurityConfig development = SecurityConfig(
    encryptionEnabled: false,
    requireAuthentication: false,
    allowAnonymousTransfers: true,
    sessionTimeout: Duration(hours: 1),
    maxFailedAttempts: 10,
  );
}
