#!/usr/bin/env dart

/// Simple validation script for security integration features
/// This script can be run with: dart run validate_security_integration.dart

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔒 Validating Security Integration Implementation...\n');

  final results = <String, bool>{};

  // Check if PendingTransfer class exists in receiver_service.dart
  results['PendingTransfer class exists'] = await validatePendingTransferClass();

  // Check if security methods exist in receiver_service.dart
  results['Security methods exist'] = await validateSecurityMethods();

  // Check if security integration exists in main.dart
  results['Security initialization exists'] = await validateSecurityInitialization();

  // Check if test files exist
  results['Test files exist'] = await validateTestFiles();

  // Check if enum is properly defined
  results['PendingTransferStatus enum exists'] = await validatePendingTransferStatusEnum();

  // Check new SecurityManager methods
  results['SecurityManager removePin method exists'] = await validateSecurityManagerExtended();

  // Check transfer approval settings
  results['Transfer approval settings exist'] = await validateTransferApprovalSettings();

  // Check receiver service security integration
  results['Receiver service uses security settings'] = await validateReceiverSecurityIntegration();

  // Check security settings screen updates
  results['Security settings screen updated'] = await validateSecuritySettingsScreen();

  // Check new test files
  results['Extended test files exist'] = await validateExtendedTestFiles();

  // Display results
  print('\n📋 Validation Results:');
  print('=' * 50);

  int passed = 0;
  int total = results.length;

  results.forEach((test, result) {
    final status = result ? '✅' : '❌';
    print('$status $test');
    if (result) passed++;
  });

  print('\n📊 Summary: $passed/$total tests passed');

  if (passed == total) {
    print('🎉 All validations passed! Security integration looks good.');
  } else {
    print('⚠️  Some validations failed. Please check the implementation.');
    exit(1);
  }
}

Future<bool> validatePendingTransferClass() async {
  try {
    final file = File('lib/services/receiver_service.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('class PendingTransfer') &&
           content.contains('final String transferId') &&
           content.contains('final String fileName') &&
           content.contains('final int fileSize') &&
           content.contains('final String senderInfo') &&
           content.contains('final DateTime timestamp');
  } catch (e) {
    return false;
  }
}

Future<bool> validateSecurityMethods() async {
  try {
    final file = File('lib/services/receiver_service.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('void setSecurityManager(SecurityManager') &&
           content.contains('Future<bool> _requiresApproval(String') &&
           content.contains('Future<String?> _requestApproval(String');
  } catch (e) {
    return false;
  }
}

Future<bool> validateSecurityInitialization() async {
  try {
    final file = File('lib/main.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('_receiver.setSecurityManager') &&
           content.contains('SecurityManager?') &&
           content.contains('_initializeSecurity');
  } catch (e) {
    return false;
  }
}

Future<bool> validateTestFiles() async {
  final testFiles = [
    'test/services/security_integration_test.dart',
    'test/services/security_approval_workflow_test.dart',
    'test/integration/security_initialization_test.dart',
  ];

  for (final testFile in testFiles) {
    final file = File(testFile);
    if (!await file.exists()) return false;
  }

  return true;
}

Future<bool> validatePendingTransferStatusEnum() async {
  try {
    final file = File('lib/services/receiver_service.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('enum PendingTransferStatus') &&
           content.contains('pending') &&
           content.contains('approved') &&
           content.contains('rejected');
  } catch (e) {
    return false;
  }
}

Future<bool> validateSecurityManagerExtended() async {
  try {
    final file = File('lib/services/security_manager.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('Future<bool> removePin(String currentPin)') &&
           content.contains('Future<bool> changePin(String oldPin, String newPin)') &&
           content.contains('Future<bool> setRequireApproval(bool') &&
           content.contains('Future<bool> setAutoApproveTrusted(bool');
  } catch (e) {
    return false;
  }
}

Future<bool> validateTransferApprovalSettings() async {
  try {
    final file = File('lib/services/security_manager.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('static const String _requireApprovalKey') &&
           content.contains('static const String _autoApproveTrustedKey') &&
           content.contains('getSecurityConfigurationAsync()') &&
           content.contains('SharedPreferences');
  } catch (e) {
    return false;
  }
}

Future<bool> validateReceiverSecurityIntegration() async {
  try {
    final file = File('lib/services/receiver_service.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('getSecurityConfigurationAsync()') &&
           content.contains('config.requireApproval') &&
           content.contains('config.autoApproveTrustedPeers');
  } catch (e) {
    return false;
  }
}

Future<bool> validateSecuritySettingsScreen() async {
  try {
    final file = File('lib/screens/security_settings_screen.dart');
    if (!await file.exists()) return false;

    final content = await file.readAsString();
    return content.contains('_securityManager.removePin') &&
           content.contains('_securityManager.setRequireApproval') &&
           content.contains('_securityManager.setAutoApproveTrusted') &&
           content.contains('_loadSecurityConfig()') &&
           !content.contains('Feature coming soon');
  } catch (e) {
    return false;
  }
}

Future<bool> validateExtendedTestFiles() async {
  final testFiles = [
    'test/services/security_manager_extended_test.dart',
    'test/widgets/security_settings_screen_test.dart',
  ];

  for (final testFile in testFiles) {
    final file = File(testFile);
    if (!await file.exists()) return false;
  }

  return true;
}
