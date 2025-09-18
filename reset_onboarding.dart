import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

/// Utility to reset onboarding state for testing first-launch behavior
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🔄 Resetting onboarding state for first-launch testing...');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Remove onboarding completion flag
    if (prefs.containsKey('onboarding_completed')) {
      await prefs.remove('onboarding_completed');
      print('   ✅ Removed: onboarding_completed');
      print('🎯 Reset complete! Next app launch will show onboarding screen.');
    } else {
      print('   ℹ️  No onboarding flag found - onboarding will show by default.');
    }
    
    // Optionally, also reset theme preference to test complete first-run experience
    if (prefs.containsKey('theme_mode')) {
      await prefs.remove('theme_mode');
      print('   ✅ Removed: theme_mode (will use system default)');
    }
    
    print('📱 Next app launch will show the complete first-time user experience.');
    
  } catch (e) {
    print('❌ Error resetting onboarding state: $e');
  }
}