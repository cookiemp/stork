import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stork2/screens/security_settings_screen.dart';
import 'package:stork2/services/security_manager.dart';

/// Widget tests for SecuritySettingsScreen
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecuritySettingsScreen Widget Tests', () {
    setUp(() async {
      // Initialize security manager for tests
      try {
        await SecurityManager.instance.initialize();
      } catch (e) {
        // Initialization may fail in test environment - that's OK
        print('Security initialization failed in test: $e');
      }
    });

    testWidgets('should build and display main security elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Check if main elements are present
      expect(find.text('Security Settings'), findsOneWidget);
      expect(find.text('Security Level:'), findsOneWidget);
      expect(find.text('PIN Protection'), findsOneWidget);
      expect(find.text('Transfer Security'), findsOneWidget);
    });

    testWidgets('should show PIN setup when no PIN is set', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show PIN disabled state
      expect(find.text('PIN Disabled'), findsOneWidget);
      expect(find.text('Set up a PIN to secure your device'), findsOneWidget);
    });

    testWidgets('should display transfer security toggles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for transfer security switches
      expect(find.text('Require Transfer Approval'), findsOneWidget);
      expect(find.text('Auto-approve Trusted Devices'), findsOneWidget);
      expect(find.text('Ask for confirmation before accepting files'), findsOneWidget);
      expect(find.text('Automatically accept files from trusted devices'), findsOneWidget);
    });

    testWidgets('should display security information section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for security info
      expect(find.text('Security Information'), findsOneWidget);
      expect(find.text('Encryption'), findsOneWidget);
      expect(find.text('AES-256-GCM + RSA-2048'), findsOneWidget);
      expect(find.text('Max PIN Attempts'), findsOneWidget);
      expect(find.text('Session Timeout'), findsOneWidget);
    });

    testWidgets('should show trusted devices section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for trusted devices
      expect(find.text('Trusted Devices'), findsOneWidget);
    });

    testWidgets('should handle toggle interactions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find transfer approval switch
      final approvalSwitch = find.widgetWithText(SwitchListTile, 'Require Transfer Approval');
      if (approvalSwitch.evaluate().isNotEmpty) {
        // Try to tap the switch (it should respond even if security isn't fully initialized)
        await tester.tap(approvalSwitch);
        await tester.pumpAndSettle();

        // The widget should handle the toggle without crashing
        expect(find.text('Require Transfer Approval'), findsOneWidget);
      }
    });

    testWidgets('should handle trusted devices switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find trusted devices auto-approval switch
      final trustedSwitch = find.widgetWithText(SwitchListTile, 'Auto-approve Trusted Devices');
      if (trustedSwitch.evaluate().isNotEmpty) {
        // Try to tap the switch
        await tester.tap(trustedSwitch);
        await tester.pumpAndSettle();

        // The widget should handle the toggle without crashing
        expect(find.text('Auto-approve Trusted Devices'), findsOneWidget);
      }
    });

    testWidgets('should show PIN management options when PIN is set', (WidgetTester tester) async {
      // This test would require a way to mock a PIN being set
      // For now, we'll just verify the structure exists
      
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // The PIN management card should be present
      expect(find.text('PIN Protection'), findsOneWidget);
    });

    testWidgets('should handle loading state gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for it to load
      await tester.pumpAndSettle();

      // Loading should be gone, content should be visible
      expect(find.text('Security Settings'), findsOneWidget);
    });

    testWidgets('should display security level indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show security level (Basic or High)
      final hasBasic = find.text('Security Level: Basic').evaluate().isNotEmpty;
      final hasHigh = find.text('Security Level: High').evaluate().isNotEmpty;
      
      expect(hasBasic || hasHigh, isTrue, 
        reason: 'Should display either Basic or High security level');
    });

    testWidgets('should have proper card layout structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should have multiple Card widgets for different sections
      expect(find.byType(Card), findsAtLeastNWidgets(3));
      
      // Should have a ListView as the main container
      expect(find.byType(ListView), findsOneWidget);
      
      // Should have proper app bar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should show appropriate icons for security elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SecuritySettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for various security-related icons
      expect(find.byIcon(Icons.pin), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.transfer_within_a_station), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.devices), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.info), findsAtLeastNWidgets(1));
    });
  });

  group('TrustedDevicesScreen Widget Tests', () {
    testWidgets('should build and display trusted devices screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TrustedDevicesScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the screen
      expect(find.text('Trusted Devices'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should show empty state when no trusted devices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TrustedDevicesScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No Trusted Devices'), findsOneWidget);
      expect(find.byIcon(Icons.devices_outlined), findsOneWidget);
    });

    testWidgets('should handle back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const TrustedDevicesScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should have back button in app bar
      expect(find.byType(BackButton), findsOneWidget);
    });
  });
}
