import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing Windows context menu integration
class ContextMenuService {
  static const String _appName = 'Stork P2P';
  static const String _commandKey = 'StorkSendFile';
  static const String _menuText = 'Send with Stork P2P';

  /// Check if context menu integration is supported on this platform
  static bool get isSupported => Platform.isWindows;

  /// Install context menu integration for Windows File Explorer
  /// This adds "Send with Stork P2P" to right-click context menu
  static Future<bool> installContextMenu() async {
    if (!isSupported) {
      if (kDebugMode) {
        print('Context menu integration not supported on this platform');
      }
      return false;
    }

    try {
      // Get the current executable path
      final executablePath = Platform.resolvedExecutable;
      final appDirectory = Directory(executablePath).parent.path;
      
      if (kDebugMode) {
        print('Installing context menu for: $executablePath');
      }

      // Create registry entries for context menu
      final registryCommands = [
        // Add to all files context menu
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\shell\\$_commandKey" /ve /d "$_menuText" /f',
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\shell\\$_commandKey" /v "Icon" /d "$executablePath,0" /f',
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\shell\\$_commandKey\\command" /ve /d "\\"$executablePath\\" --send \\"%1\\"" /f',
        
        // Add to directory context menu
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Directory\\shell\\$_commandKey" /ve /d "$_menuText" /f',
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Directory\\shell\\$_commandKey" /v "Icon" /d "$executablePath,0" /f',
        'reg add "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Directory\\shell\\$_commandKey\\command" /ve /d "\\"$executablePath\\" --send \\"%1\\"" /f',
      ];

      for (final command in registryCommands) {
        final result = await Process.run('cmd', ['/c', command]);
        if (result.exitCode != 0) {
          if (kDebugMode) {
            print('Failed to execute: $command');
            print('Error: ${result.stderr}');
          }
          return false;
        }
      }

      if (kDebugMode) {
        print('Context menu integration installed successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to install context menu: $e');
      }
      return false;
    }
  }

  /// Uninstall context menu integration
  static Future<bool> uninstallContextMenu() async {
    if (!isSupported) return false;

    try {
      final registryCommands = [
        // Remove from files context menu
        'reg delete "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\shell\\$_commandKey" /f',
        // Remove from directory context menu
        'reg delete "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\Directory\\shell\\$_commandKey" /f',
      ];

      for (final command in registryCommands) {
        final result = await Process.run('cmd', ['/c', command]);
        // Don't fail if the key doesn't exist
        if (result.exitCode != 0 && !result.stderr.toString().contains('cannot find')) {
          if (kDebugMode) {
            print('Failed to execute: $command');
            print('Error: ${result.stderr}');
          }
        }
      }

      if (kDebugMode) {
        print('Context menu integration uninstalled');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to uninstall context menu: $e');
      }
      return false;
    }
  }

  /// Check if context menu is currently installed
  static Future<bool> isInstalled() async {
    if (!isSupported) return false;

    try {
      final result = await Process.run('reg', [
        'query',
        'HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\shell\\$_commandKey'
      ]);
      
      return result.exitCode == 0;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check context menu status: $e');
      }
      return false;
    }
  }

  /// Handle command line arguments for file sending
  /// This is called when the app is launched from context menu
  static Future<List<String>?> parseCommandLineArgs(List<String> args) async {
    if (args.isEmpty) return null;

    final List<String> filesToSend = [];

    for (int i = 0; i < args.length; i++) {
      if (args[i] == '--send' && i + 1 < args.length) {
        final filePath = args[i + 1];
        if (await File(filePath).exists() || await Directory(filePath).exists()) {
          filesToSend.add(filePath);
        }
      }
    }

    return filesToSend.isEmpty ? null : filesToSend;
  }

  /// Create a desktop shortcut for easy access
  static Future<bool> createDesktopShortcut() async {
    if (!isSupported) return false;

    try {
      // Get desktop directory
      final String? desktopPath = await _getDesktopPath();
      if (desktopPath == null) return false;

      final executablePath = Platform.resolvedExecutable;
      final shortcutPath = '$desktopPath\\$_appName.lnk';

      // Create VBS script to create shortcut
      final vbsScript = '''
Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = "$shortcutPath"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "$executablePath"
oLink.WorkingDirectory = "${Directory(executablePath).parent.path}"
oLink.Description = "$_appName - Local P2P File Transfer"
oLink.Save
''';

      // Write VBS script to temp file
      final tempDir = await getTemporaryDirectory();
      final vbsFile = File('${tempDir.path}\\create_shortcut.vbs');
      await vbsFile.writeAsString(vbsScript);

      // Execute VBS script
      final result = await Process.run('cscript', [vbsFile.path, '//NoLogo']);
      
      // Clean up
      await vbsFile.delete();

      if (result.exitCode == 0) {
        if (kDebugMode) {
          print('Desktop shortcut created: $shortcutPath');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to create desktop shortcut: ${result.stderr}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create desktop shortcut: $e');
      }
      return false;
    }
  }

  /// Get the desktop path
  static Future<String?> _getDesktopPath() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetFolderPath("Desktop")'
      ]);
      
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get desktop path: $e');
      }
    }
    return null;
  }

  /// Add to Windows startup (optional)
  static Future<bool> addToStartup({bool enable = true}) async {
    if (!isSupported) return false;

    try {
      final executablePath = Platform.resolvedExecutable;
      final startupKeyPath = 'HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run';
      
      if (enable) {
        final result = await Process.run('reg', [
          'add',
          startupKeyPath,
          '/v',
          _appName,
          '/d',
          '"$executablePath" --minimized',
          '/f'
        ]);
        
        if (result.exitCode == 0) {
          if (kDebugMode) {
            print('Added to Windows startup');
          }
          return true;
        }
      } else {
        final result = await Process.run('reg', [
          'delete',
          startupKeyPath,
          '/v',
          _appName,
          '/f'
        ]);
        
        // Don't fail if key doesn't exist
        if (result.exitCode == 0 || result.stderr.toString().contains('cannot find')) {
          if (kDebugMode) {
            print('Removed from Windows startup');
          }
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to modify startup entry: $e');
      }
    }
    return false;
  }

  /// Check if app is in Windows startup
  static Future<bool> isInStartup() async {
    if (!isSupported) return false;

    try {
      final result = await Process.run('reg', [
        'query',
        'HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _appName
      ]);
      
      return result.exitCode == 0;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check startup status: $e');
      }
      return false;
    }
  }

  /// Show installation dialog and handle user choice
  static Future<bool> showInstallationDialog() async {
    // This would need to be called from the Flutter UI
    // For now, we'll return true to indicate the dialog should be shown
    return true;
  }

  /// Get installation status information
  static Future<Map<String, bool>> getInstallationStatus() async {
    return {
      'contextMenu': await isInstalled(),
      'startup': await isInStartup(),
      'supported': isSupported,
    };
  }
}
