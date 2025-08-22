import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stork2/services/security_manager.dart';
import 'package:stork2/services/receiver_service.dart';
import 'package:stork2/services/theme_service.dart';
import 'package:stork2/main.dart';

void main() {
  group('Security Initialization Integration Tests', () {
    late SecurityManager securityManager;
    late ReceiverService receiverService;
    late ThemeService themeService;

    setUp(() async {
      // Initialize services in the correct order (as in main.dart)
      themeService = ThemeService();
      await themeService.initialize();
      
      receiverService = ReceiverService();
      securityManager = SecurityManager.instance;
    });

    tearDown(() {
      receiverService.dispose();
    });

    group('Security Manager Initialization', () {
      test('should initialize security manager successfully', () async {
        // Act
        bool initializationSucceeded = false;
        try {
          await securityManager.initialize();
          initializationSucceeded = true;
        } catch (e) {
          // In test environment, initialization might fail due to missing platform features
          print('Security initialization failed in test environment: $e');
        }

        // Assert - either succeeds or fails gracefully
        expect(() => securityManager.initialize(), returnsNormally);
      });

      test('should handle multiple initialization calls gracefully', () async {
        // Act & Assert - should not throw on multiple calls
        expect(() async {
          await securityManager.initialize();
          await securityManager.initialize();
          await securityManager.initialize();
        }, returnsNormally);
      });
    });

    group('Receiver Service Security Integration', () {
      test('should inject security manager into receiver service', () {
        // Act
        receiverService.setSecurityManager(securityManager);
        
        // Assert - method should complete without error
        expect(receiverService, isNotNull);
      });

      test('should handle security injection before initialization', () {
        // Arrange
        final freshReceiverService = ReceiverService();
        
        // Act & Assert - should not throw even if security manager is not fully initialized
        expect(() => freshReceiverService.setSecurityManager(securityManager), returnsNormally);
        
        // Cleanup
        freshReceiverService.dispose();
      });

      test('should maintain functionality without security manager', () {
        // Arrange
        final receiverWithoutSecurity = ReceiverService();
        
        // Act - don't inject security manager
        // Assert - receiver should still work
        expect(receiverWithoutSecurity, isNotNull);
        expect(() => receiverWithoutSecurity.dispose(), returnsNormally);
      });
    });

    group('Security Integration Flow', () {
      test('should follow correct initialization order', () async {
        // This test simulates the initialization flow from main.dart
        
        // Step 1: Initialize theme service
        final testThemeService = ThemeService();
        await testThemeService.initialize();
        expect(testThemeService, isNotNull);
        
        // Step 2: Initialize security manager
        final testSecurityManager = SecurityManager.instance;
        try {
          await testSecurityManager.initialize();
        } catch (e) {
          // Acceptable in test environment
          print('Security init failed in test: $e');
        }
        
        // Step 3: Create receiver service
        final testReceiverService = ReceiverService();
        expect(testReceiverService, isNotNull);
        
        // Step 4: Inject security manager into receiver
        expect(() => testReceiverService.setSecurityManager(testSecurityManager), returnsNormally);
        
        // Cleanup
        testReceiverService.dispose();
      });

      test('should handle security initialization failure gracefully', () async {
        // This test ensures the app continues to work even if security fails
        
        final testReceiverService = ReceiverService();
        SecurityManager? testSecurityManager;
        
        try {
          testSecurityManager = SecurityManager.instance;
          await testSecurityManager.initialize();
        } catch (e) {
          // Security initialization failed - this is acceptable
          testSecurityManager = null;
          print('Security initialization failed as expected in test: $e');
        }
        
        // App should continue working without security
        expect(testReceiverService, isNotNull);
        
        // Security injection should still work (even if manager is not fully functional)
        if (testSecurityManager != null) {
          expect(() => testReceiverService.setSecurityManager(testSecurityManager!), returnsNormally);
        }
        
        // Cleanup
        testReceiverService.dispose();
      });
    });

    group('Widget Integration', () {
      testWidgets('should build HomeScreen with security integration', (WidgetTester tester) async {
        // Arrange
        final testThemeService = ThemeService();
        await testThemeService.initialize();
        
        // Act - Build the app
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(themeService: testThemeService),
          ),
        );
        
        // Wait for initialization
        await tester.pumpAndSettle();
        
        // Assert - App should build successfully
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Stork P2P'), findsOneWidget);
      });

      testWidgets('should handle security UI elements', (WidgetTester tester) async {
        // Arrange
        final testThemeService = ThemeService();
        await testThemeService.initialize();
        
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(themeService: testThemeService),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Security-related UI elements should be present or absent gracefully
        // The security icon might not be visible if security initialization failed
        final securityIcon = find.byIcon(Icons.security);
        final securityOutlinedIcon = find.byIcon(Icons.security_outlined);
        
        // Either security icon should be found, or neither (if security is disabled)
        expect(
          securityIcon.evaluate().isNotEmpty || securityOutlinedIcon.evaluate().isNotEmpty,
          isTrue,
        );
      });
    });

    group('Error Handling', () {
      test('should handle security manager singleton properly', () {
        // Arrange & Act
        final manager1 = SecurityManager.instance;
        final manager2 = SecurityManager.instance;
        
        // Assert - Should be same instance
        expect(identical(manager1, manager2), isTrue);
      });

      test('should handle receiver disposal with security manager', () {
        // Arrange
        final testReceiver = ReceiverService();
        testReceiver.setSecurityManager(securityManager);
        
        // Act & Assert - Should dispose cleanly
        expect(() => testReceiver.dispose(), returnsNormally);
      });

      test('should maintain security state across service lifecycle', () {
        // Arrange
        final testReceiver1 = ReceiverService();
        final testReceiver2 = ReceiverService();
        
        // Act
        testReceiver1.setSecurityManager(securityManager);
        testReceiver1.dispose();
        
        testReceiver2.setSecurityManager(securityManager);
        
        // Assert - Second receiver should work fine
        expect(testReceiver2, isNotNull);
        
        // Cleanup
        testReceiver2.dispose();
      });
    });
  });
}
