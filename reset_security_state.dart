import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Utility to reset security state for testing first-launch behavior
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🔄 Resetting security state for first-launch testing...');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Remove all security-related keys
    final securityKeys = [
      'stork_device_pin_hash',
      'stork_auth_config', 
      'stork_pending_approvals',
      'stork_failed_attempts',
      'stork_device_keys',
      'stork_trusted_peers',
      'stork_security_config',
      'stork_security_sessions',
    ];
    
    int removedCount = 0;
    for (final key in securityKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
        removedCount++;
        print('   ✅ Removed: $key');
      }
    }
    
    print('🎯 Reset complete! Removed $removedCount security preferences.');
    print('📱 Next app launch will show first-time PIN setup.');
    
  } catch (e) {
    print('❌ Error resetting security state: $e');
  }
}
