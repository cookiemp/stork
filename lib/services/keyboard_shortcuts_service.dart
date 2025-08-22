import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for managing keyboard shortcuts throughout the application
class KeyboardShortcutsService {
  static final Map<LogicalKeySet, VoidCallback> _shortcuts = {};
  static final Map<String, ShortcutInfo> _registeredShortcuts = {};

  /// Register a keyboard shortcut with callback
  static void registerShortcut({
    required String id,
    required LogicalKeySet keySet,
    required VoidCallback callback,
    required String description,
    String? category,
  }) {
    _shortcuts[keySet] = callback;
    _registeredShortcuts[id] = ShortcutInfo(
      id: id,
      keySet: keySet,
      description: description,
      category: category ?? 'General',
    );
  }

  /// Unregister a keyboard shortcut
  static void unregisterShortcut(String id) {
    final shortcut = _registeredShortcuts[id];
    if (shortcut != null) {
      _shortcuts.remove(shortcut.keySet);
      _registeredShortcuts.remove(id);
    }
  }

  /// Get all registered shortcuts
  static List<ShortcutInfo> getAllShortcuts() {
    return _registeredShortcuts.values.toList();
  }

  /// Get shortcuts by category
  static List<ShortcutInfo> getShortcutsByCategory(String category) {
    return _registeredShortcuts.values
        .where((shortcut) => shortcut.category == category)
        .toList();
  }

  /// Create a shortcuts widget that handles all registered shortcuts
  static Widget createShortcutsWidget({required Widget child}) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: child,
    );
  }

  /// Initialize common application shortcuts
  static void initializeDefaultShortcuts(AppShortcutHandlers handlers) {
    // File operations
    registerShortcut(
      id: 'open_file',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO),
      callback: handlers.openFile,
      description: 'Pick and send file',
      category: 'File Operations',
    );

    registerShortcut(
      id: 'add_peer',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN),
      callback: handlers.addPeer,
      description: 'Add peer manually',
      category: 'Peer Management',
    );

    // Server operations
    registerShortcut(
      id: 'toggle_receiving',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR),
      callback: handlers.toggleReceiving,
      description: 'Toggle receiving mode',
      category: 'Server Control',
    );

    registerShortcut(
      id: 'refresh_peers',
      keySet: LogicalKeySet(LogicalKeyboardKey.f5),
      callback: handlers.refreshPeers,
      description: 'Refresh peer discovery',
      category: 'Peer Management',
    );

    // Theme operations
    registerShortcut(
      id: 'toggle_theme',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT),
      callback: handlers.toggleTheme,
      description: 'Toggle dark/light theme',
      category: 'Appearance',
    );

    // Navigation
    registerShortcut(
      id: 'focus_ip_input',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL),
      callback: handlers.focusIpInput,
      description: 'Focus IP address input',
      category: 'Navigation',
    );

    registerShortcut(
      id: 'show_help',
      keySet: LogicalKeySet(LogicalKeyboardKey.f1),
      callback: handlers.showHelp,
      description: 'Show keyboard shortcuts help',
      category: 'Help',
    );

    // Quick actions
    registerShortcut(
      id: 'send_to_last_peer',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS),
      callback: handlers.sendToLastPeer,
      description: 'Send file to last used peer',
      category: 'Quick Actions',
    );

    registerShortcut(
      id: 'copy_my_ip',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyC),
      callback: handlers.copyMyIp,
      description: 'Copy my IP address to clipboard',
      category: 'Quick Actions',
    );
  }

  /// Clear all registered shortcuts
  static void clearAllShortcuts() {
    _shortcuts.clear();
    _registeredShortcuts.clear();
  }
}

/// Information about a registered shortcut
class ShortcutInfo {
  final String id;
  final LogicalKeySet keySet;
  final String description;
  final String category;

  ShortcutInfo({
    required this.id,
    required this.keySet,
    required this.description,
    required this.category,
  });

  /// Get human-readable key combination string
  String get keyString {
    final keys = <String>[];
    
    if (keySet.keys.contains(LogicalKeyboardKey.control)) {
      keys.add('Ctrl');
    }
    if (keySet.keys.contains(LogicalKeyboardKey.shift)) {
      keys.add('Shift');
    }
    if (keySet.keys.contains(LogicalKeyboardKey.alt)) {
      keys.add('Alt');
    }
    if (keySet.keys.contains(LogicalKeyboardKey.meta)) {
      keys.add('Win');
    }
    
    // Add the main key
    final mainKey = keySet.keys.firstWhere(
      (key) => key != LogicalKeyboardKey.control &&
               key != LogicalKeyboardKey.shift &&
               key != LogicalKeyboardKey.alt &&
               key != LogicalKeyboardKey.meta,
      orElse: () => keySet.keys.first,
    );
    
    keys.add(_getKeyLabel(mainKey));
    
    return keys.join(' + ');
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    
    // For letter keys, extract the letter
    if (key.keyLabel.length == 1) {
      return key.keyLabel.toUpperCase();
    }
    
    return key.keyLabel;
  }
}

/// Interface for handling application shortcuts
abstract class AppShortcutHandlers {
  void openFile();
  void addPeer();
  void toggleReceiving();
  void refreshPeers();
  void toggleTheme();
  void focusIpInput();
  void showHelp();
  void sendToLastPeer();
  void copyMyIp();
}

/// Widget that displays keyboard shortcuts help
class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final shortcuts = KeyboardShortcutsService.getAllShortcuts();
    final categories = shortcuts.map((s) => s.category).toSet().toList()..sort();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard, size: 24),
          const SizedBox(width: 12),
          const Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categories.map((category) {
              final categoryShortcuts = KeyboardShortcutsService
                  .getShortcutsByCategory(category);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != categories.first) const SizedBox(height: 20),
                  Text(
                    category,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...categoryShortcuts.map((shortcut) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              shortcut.keyString,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            shortcut.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Focus management utilities
class FocusManager {
  static final Map<String, FocusNode> _focusNodes = {};

  /// Register a focus node with an ID
  static void registerFocusNode(String id, FocusNode focusNode) {
    _focusNodes[id] = focusNode;
  }

  /// Request focus for a registered focus node
  static void requestFocus(String id) {
    final focusNode = _focusNodes[id];
    focusNode?.requestFocus();
  }

  /// Check if a focus node has focus
  static bool hasFocus(String id) {
    final focusNode = _focusNodes[id];
    return focusNode?.hasFocus ?? false;
  }

  /// Dispose of all registered focus nodes
  static void disposeAll() {
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _focusNodes.clear();
  }
}

/// Widget that automatically handles focus management for keyboard navigation
class KeyboardNavigationWrapper extends StatelessWidget {
  final Widget child;
  final bool autofocus;

  const KeyboardNavigationWrapper({
    super.key,
    required this.child,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      child: child,
    );
  }
}
