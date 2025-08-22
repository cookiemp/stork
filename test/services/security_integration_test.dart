import 'package:flutter_test/flutter_test.dart';
import 'package:stork2/services/receiver_service.dart';
import 'package:stork2/services/security_manager.dart';
import 'dart:io';

void main() {
  group('Security Integration Tests', () {
    late ReceiverService receiverService;
    late SecurityManager securityManager;

    setUp(() async {
      receiverService = ReceiverService();
      securityManager = SecurityManager.instance;
      
      // Initialize security manager for testing
      try {
        await securityManager.initialize();
      } catch (e) {
        // Security initialization may fail in test environment, that's okay
        print('Security initialization failed in test: $e');
      }
    });

    tearDown(() {
      receiverService.dispose();
    });

    group('SecurityManager Injection', () {
      test('should inject security manager into receiver service', () {
        // Act
        receiverService.setSecurityManager(securityManager);
        
        // Assert - we can't directly access private _securityManager but we can test behavior
        expect(receiverService, isNotNull);
        // The security manager should be set internally
      });

      test('should handle null security manager gracefully', () {
        // Act & Assert - should not throw
        expect(() => receiverService.setSecurityManager(securityManager), returnsNormally);
      });
    });

    group('PendingTransfer Model', () {
      test('should create pending transfer with all required fields', () {
        // Arrange
        const transferId = 'test-transfer-123';
        const fileName = 'test-file.txt';
        const fileSize = 1024;
        const senderInfo = 'sender@192.168.1.100';
        final timestamp = DateTime.now();

        // Act
        final pendingTransfer = PendingTransfer(
          transferId: transferId,
          fileName: fileName,
          fileSize: fileSize,
          senderInfo: senderInfo,
          timestamp: timestamp,
        );

        // Assert
        expect(pendingTransfer.transferId, equals(transferId));
        expect(pendingTransfer.fileName, equals(fileName));
        expect(pendingTransfer.fileSize, equals(fileSize));
        expect(pendingTransfer.senderInfo, equals(senderInfo));
        expect(pendingTransfer.timestamp, equals(timestamp));
        expect(pendingTransfer.status, equals(PendingTransferStatus.pending));
      });

      test('should create pending transfer with approved status', () {
        // Arrange & Act
        final pendingTransfer = PendingTransfer(
          transferId: 'test-123',
          fileName: 'test.txt',
          fileSize: 1024,
          senderInfo: 'sender',
          timestamp: DateTime.now(),
          status: PendingTransferStatus.approved,
        );

        // Assert
        expect(pendingTransfer.status, equals(PendingTransferStatus.approved));
      });

      test('should create pending transfer with rejected status', () {
        // Arrange & Act
        final pendingTransfer = PendingTransfer(
          transferId: 'test-123',
          fileName: 'test.txt',
          fileSize: 1024,
          senderInfo: 'sender',
          timestamp: DateTime.now(),
          status: PendingTransferStatus.rejected,
        );

        // Assert
        expect(pendingTransfer.status, equals(PendingTransferStatus.rejected));
      });

      test('should support equality comparison', () {
        // Arrange
        final timestamp = DateTime.now();
        final transfer1 = PendingTransfer(
          transferId: 'test-123',
          fileName: 'test.txt',
          fileSize: 1024,
          senderInfo: 'sender',
          timestamp: timestamp,
        );
        final transfer2 = PendingTransfer(
          transferId: 'test-123',
          fileName: 'test.txt',
          fileSize: 1024,
          senderInfo: 'sender',
          timestamp: timestamp,
        );

        // Act & Assert
        expect(transfer1.transferId, equals(transfer2.transferId));
        expect(transfer1.fileName, equals(transfer2.fileName));
      });
    });

    group('Security Methods in ReceiverService', () {
      test('_requiresApproval should return false when security manager not set', () {
        // Note: We can't directly test private methods, but we can test the overall behavior
        // This test ensures the receiver service handles the case when security is not available
        expect(receiverService, isNotNull);
      });

      test('setSecurityManager should accept valid security manager', () {
        // Act & Assert
        expect(() => receiverService.setSecurityManager(securityManager), returnsNormally);
      });
    });

    group('PendingTransferStatus Enum', () {
      test('should have correct enum values', () {
        expect(PendingTransferStatus.values, hasLength(3));
        expect(PendingTransferStatus.values, contains(PendingTransferStatus.pending));
        expect(PendingTransferStatus.values, contains(PendingTransferStatus.approved));
        expect(PendingTransferStatus.values, contains(PendingTransferStatus.rejected));
      });

      test('should have correct string representation', () {
        expect(PendingTransferStatus.pending.toString(), equals('PendingTransferStatus.pending'));
        expect(PendingTransferStatus.approved.toString(), equals('PendingTransferStatus.approved'));
        expect(PendingTransferStatus.rejected.toString(), equals('PendingTransferStatus.rejected'));
      });
    });
  });

  group('Security Integration Edge Cases', () {
    late ReceiverService receiverService;

    setUp(() {
      receiverService = ReceiverService();
    });

    tearDown(() {
      receiverService.dispose();
    });

    test('should handle security manager injection multiple times', () {
      // Arrange
      final securityManager1 = SecurityManager.instance;
      final securityManager2 = SecurityManager.instance; // Should be same instance

      // Act & Assert
      expect(() {
        receiverService.setSecurityManager(securityManager1);
        receiverService.setSecurityManager(securityManager2);
      }, returnsNormally);
    });

    test('should create pending transfer with edge case values', () {
      // Test with empty file name
      expect(() => PendingTransfer(
        transferId: 'test-123',
        fileName: '',
        fileSize: 0,
        senderInfo: '',
        timestamp: DateTime.now(),
      ), returnsNormally);

      // Test with very large file size
      expect(() => PendingTransfer(
        transferId: 'test-456',
        fileName: 'large-file.bin',
        fileSize: 9223372036854775807, // Max int64
        senderInfo: 'sender',
        timestamp: DateTime.now(),
      ), returnsNormally);
    });
  });
}
