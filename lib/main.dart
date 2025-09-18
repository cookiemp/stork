import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'services/sender_service.dart';
import 'services/receiver_service.dart';
import 'services/mdns_discovery_service.dart';
import 'services/theme_service.dart';
import 'services/animation_service.dart';
import 'services/drag_drop_service.dart';
import 'services/notification_service.dart';
import 'services/error_service.dart';
import 'services/batch_transfer_service.dart';
import 'services/transfer_history_service.dart';
import 'services/compression_service.dart';
import 'services/security_manager.dart';
import 'models/peer.dart';
import 'models/transfer_history.dart';
import 'widgets/empty_states.dart';
import 'widgets/multi_file_picker.dart';
import 'widgets/batch_transfer_progress.dart';
import 'screens/transfer_history_screen.dart';
import 'screens/security_settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/pin_entry_dialog.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize theme service
  final themeService = ThemeService();
  await themeService.initialize();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize security services (non-blocking for existing functionality)
  try {
    final securityManager = SecurityManager.instance;
    await securityManager.initialize();
    debugPrint('✅ Security services initialized');
  } catch (e) {
    debugPrint('⚠️ Security initialization failed (continuing without security): $e');
    // Continue without security to maintain backward compatibility
  }
  
  runApp(LocalP2PApp(themeService: themeService));
}

class LocalP2PApp extends StatelessWidget {
  final ThemeService themeService;
  
  const LocalP2PApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Stork P2P',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.currentThemeMode,
          // Add theme animation duration for smoother transitions
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          home: AppRouter(themeService: themeService),
        );
      },
    );
  }
}

/// Router that handles onboarding flow
class AppRouter extends StatefulWidget {
  final ThemeService themeService;
  
  const AppRouter({super.key, required this.themeService});
  
  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _showOnboarding = true;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }
  
  Future<void> _checkOnboardingStatus() async {
    try {
      final shouldShow = await _shouldShowOnboarding();
      setState(() {
        _showOnboarding = shouldShow;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      setState(() {
        _showOnboarding = false; // Default to not showing onboarding on error
        _isLoading = false;
      });
    }
  }
  
  void _completeOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }
  
  /// Check if onboarding should be shown
  Future<bool> _shouldShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool('onboarding_completed') ?? false);
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false; // Default to not showing onboarding on error
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: _completeOnboarding,
      );
    }
    
    return HomeScreen(themeService: widget.themeService);
  }
}

class HomeScreen extends StatefulWidget {
  final ThemeService themeService;
  
  const HomeScreen({super.key, required this.themeService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _discoverable = false;
  bool _isReceiving = false;
  final List<String> _receivedFiles = [];
  final List<Peer> _discoveredPeers = [];
  final List<Peer> _manualPeers = [];

  // Services
  final SenderService _sender = SenderService();
  final ReceiverService _receiver = ReceiverService();
  final MdnsDiscoveryService _discovery = MdnsDiscoveryService();
  final NotificationService _notifications = NotificationService();
  final TransferHistoryService _historyService = TransferHistoryService();
  
  // Security (optional - app works without it)
  SecurityManager? _securityManager;
  bool _securityEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeSecurity();
    // In debug builds, auto-start receiving so we can validate with curl easily
    if (kDebugMode) {
      _startReceiving();
    }
    // Start discovery
    _discovery.start();
    _discovery.peersStream.listen((peers) {
      setState(() {
        _discoveredPeers
          ..clear()
          ..addAll(peers);
      });
      if (kDebugMode) {
        // ignore: avoid_print
        for (final p in peers) {
          print('Discovered peer: $p');
        }
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _receiver.dispose();
    _discovery.dispose();
    super.dispose();
  }

  /// Initialize services
  Future<void> _initializeServices() async {
    await _historyService.initialize();
    
    // Inject history service into receiver for logging received files
    _receiver.setHistoryService(_historyService);
    
    // Add sample transfer history in debug mode for testing
    if (kDebugMode && _historyService.history.isEmpty) {
      await _addSampleTransferHistory();
    }
  }
  
  /// Initialize security services (optional - app works without them)
  Future<void> _initializeSecurity() async {
    try {
      _securityManager = SecurityManager.instance;
      if (_securityManager!.isInitialized) {
        _securityEnabled = true;
        
        // Check if first launch and show PIN setup if needed
        if (_securityManager!.isFirstLaunch) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFirstTimeSetup();
          });
        }
        
        // Inject security manager into receiver now that it's initialized
        _receiver.setSecurityManager(_securityManager!);
        
        debugPrint('🔒 Security initialized in HomeScreen');
      }
    } catch (e) {
      debugPrint('⚠️ Security not available in HomeScreen: $e');
      _securityEnabled = false;
      _securityManager = null;
    }
  }
  
  /// Show first-time security setup
  Future<void> _showFirstTimeSetup() async {
    if (!_securityEnabled || _securityManager == null) return;
    
    final pin = await showPinSetupDialog(context);
    
    if (pin != null) {
      final success = await _securityManager!.setupPin(pin);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Security PIN set up successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to set up security PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Add sample transfer history for testing purposes
  Future<void> _addSampleTransferHistory() async {
    final now = DateTime.now();
    
    // Sample completed successful transfer
    final record1 = _historyService.completeTransferRecord(
      record: _historyService.createTransferRecord(
        fileName: 'document.pdf',
        filePath: 'C:\\downloads\\document.pdf',
        fileSize: 2048576, // 2MB
        targetHost: '192.168.1.100',
        targetPort: 8080,
        targetName: 'Desktop PC',
        direction: TransferDirection.sent,
        type: TransferType.single,
      ).copyWith(startTime: now.subtract(const Duration(hours: 2))),
      finalStatus: TransferStatus.completed,
    );
    
    // Sample failed transfer
    final record2 = _historyService.completeTransferRecord(
      record: _historyService.createTransferRecord(
        fileName: 'large_video.mp4',
        filePath: 'C:\\downloads\\large_video.mp4',
        fileSize: 104857600, // 100MB
        targetHost: '192.168.1.50',
        targetPort: 8080,
        targetName: 'Laptop',
        direction: TransferDirection.sent,
        type: TransferType.large,
      ).copyWith(startTime: now.subtract(const Duration(hours: 5))),
      finalStatus: TransferStatus.failed,
      errorMessage: 'Network timeout',
    );
    
    // Sample received transfer
    final record3 = _historyService.completeTransferRecord(
      record: _historyService.createTransferRecord(
        fileName: 'photo.jpg',
        filePath: 'C:\\downloads\\photo.jpg',
        fileSize: 5242880, // 5MB
        targetHost: '192.168.1.75',
        targetPort: 8080,
        targetName: 'Phone',
        direction: TransferDirection.received,
        type: TransferType.single,
      ).copyWith(startTime: now.subtract(const Duration(minutes: 30))),
      finalStatus: TransferStatus.completed,
    );
    
    // Sample batch transfer
    final batchId = 'batch_${now.millisecondsSinceEpoch}';
    final record4 = _historyService.completeTransferRecord(
      record: _historyService.createTransferRecord(
        fileName: 'file1.txt',
        filePath: 'C:\\downloads\\file1.txt',
        fileSize: 1024, // 1KB
        targetHost: '192.168.1.200',
        targetPort: 8080,
        targetName: 'Work PC',
        direction: TransferDirection.sent,
        type: TransferType.batch,
        batchId: batchId,
      ).copyWith(startTime: now.subtract(const Duration(hours: 1))),
      finalStatus: TransferStatus.completed,
    );
    
    // Add all sample records
    await _historyService.addTransferRecord(record1);
    await _historyService.addTransferRecord(record2);
    await _historyService.addTransferRecord(record3);
    await _historyService.addTransferRecord(record4);
    
    if (kDebugMode) {
      print('Added sample transfer history records for testing');
    }
  }

  /// Open transfer history screen
  void _openTransferHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TransferHistoryScreen(
          historyService: _historyService,
        ),
      ),
    );
  }
  
  /// Open security settings screen
  void _openSecuritySettings() {
    if (!_securityEnabled || _securityManager == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SecuritySettingsScreen(),
      ),
    );
  }

  Future<void> _pickAndSendFile() async {
    final target = _ipController.text.trim();
    if (target.isEmpty) {
      ErrorService.showValidationError(
        context,
        field: 'IP Address',
        issue: 'Field is required',
        suggestion: 'Enter a target IP address (e.g., 192.168.1.42)',
      );
      return;
    }

    await _pickAndSendTo(target, 8080);
  }

  Future<void> _pickAndSendTo(String host, int port) async {
    TransferRecord? currentRecord;
    
    try {
      // 🔒 SECURITY CHECK: Authenticate user if device is locked
      if (_securityEnabled && _securityManager != null) {
        if (_securityManager!.isLocked) {
          final pin = await showPinVerificationDialog(context);
          
          if (pin == null) {
            // User cancelled PIN entry
            return;
          }
          
          final unlocked = await _securityManager!.verifyPin(pin);
          if (!unlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Incorrect PIN. File transfer cancelled.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
        
        // 🔒 SECURITY CHECK: Check if target peer is trusted
        final peerId = '$host:$port';
        final isTrusted = _securityManager!.isTrustedPeer(peerId);
        
        if (!isTrusted) {
          // Show security warning for untrusted peer
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Untrusted Device'),
                  ],
                ),
                content: Text(
                  'You are about to send files to an untrusted device:\n\n'
                  '📍 $host:$port\n\n'
                  'This device is not in your trusted devices list. '
                  'Only send files to devices you recognize and trust.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send Anyway'),
                  ),
                ],
              );
            },
          );
          
          if (proceed != true) {
            return;
          }
        }
      }
      
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) {
        // User cancelled
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        ErrorService.showFileError(
          context,
          operation: 'read file path',
          fileName: result.files.single.name,
          exception: Exception('File path is null - this can happen with certain file types or locations'),
        );
        return;
      }

      double progress = 0.0;
      final totalLabel = ValueNotifier<String>('Preparing...');
      final progressNotifier = ValueNotifier<double>(0.0);

      // Show a simple modal progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Sending file'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, value, _) {
                    return AnimatedProgressIndicator(
                      progress: value,
                      strokeWidth: 6.0,
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: totalLabel,
                  builder: (context, text, _) {
                    return Text(text);
                  },
                ),
              ],
            ),
          );
        },
      );

      // Show transfer started notification
      final fileName = path.split(Platform.pathSeparator).last;
      await _notifications.showTransferStarted(
        fileName: fileName,
        targetDevice: '$host:$port',
      );
      
      // Create transfer history record
      final fileSize = await File(path).length();
      final transferType = fileSize > 10485760 ? TransferType.large : TransferType.single; // 10MB threshold
      currentRecord = _historyService.createTransferRecord(
        fileName: fileName,
        filePath: path,
        fileSize: fileSize,
        targetHost: host,
        targetPort: port,
        targetName: host, // Use IP as name for now
        direction: TransferDirection.sent,
        type: transferType,
      );
      await _historyService.addTransferRecord(currentRecord);
      
      if (kDebugMode) {
        print('📝 Created transfer history record: ${currentRecord.id}');
      }
      
      final ok = await _sender.sendFile(
        filePath: path,
        targetIp: host,
        targetPort: port,
        onProgress: (sent, total) {
          progress = total > 0 ? sent / total : 0.0;
          progressNotifier.value = progress.clamp(0.0, 1.0);
          totalLabel.value = 'Sent ${_formatBytes(sent)} of ${_formatBytes(total)}';
          
          // Update progress notification periodically (every 10%)
          final progressPercent = (progress * 100).toInt();
          if (progressPercent % 10 == 0 && progressPercent > 0) {
            _notifications.showTransferProgress(
              fileName: fileName,
              progress: progress,
              targetDevice: '$host:$port',
            );
          }
        },
      );

      Navigator.of(context, rootNavigator: true).pop();

      // Show transfer completed notification
      await _notifications.showTransferCompleted(
        fileName: fileName,
        targetDevice: '$host:$port',
        success: ok,
      );
      
      // Update transfer history record
      if (true) {
        final completedRecord = _historyService.completeTransferRecord(
          record: currentRecord,
          finalStatus: ok ? TransferStatus.completed : TransferStatus.failed,
          errorMessage: ok ? null : 'Transfer failed',
        );
        await _historyService.updateTransferRecord(currentRecord.id, completedRecord);
        
        if (kDebugMode) {
          print('📝 Updated transfer history: ${completedRecord.status}');
        }
      }
      
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File sent successfully')),
        );
      } else {
        ErrorService.showNetworkError(
          context,
          operation: 'send file',
          targetDevice: '$host:$port',
          showTroubleshooting: false,
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).maybePop();
      
      // Update transfer history record on error
      if (currentRecord != null) {
        final failedRecord = _historyService.completeTransferRecord(
          record: currentRecord,
          finalStatus: TransferStatus.failed,
          errorMessage: e.toString(),
        );
        await _historyService.updateTransferRecord(currentRecord.id, failedRecord);
        
        if (kDebugMode) {
          print('📝 Updated transfer history with error: ${e.toString()}');
        }
      }
      
      ErrorService.showNetworkError(
        context,
        operation: 'transfer file',
        targetDevice: '$host:$port',
        exception: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _startReceiving() async {
    try {
      if (_receiver.isRunning) return;
      _receiver.onFileReceived = (name) {
        setState(() {
          _receivedFiles.add(name);
        });
        
        // Show file received notification
        _notifications.showFileReceived(
          fileName: name,
          fromDevice: 'Unknown Device',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Received: $name')),
        );
      };
      await _receiver.startServer(port: 8080);
      
      // Start broadcasting this device on the network
      final deviceName = 'Flutter-${Platform.localHostname}';
      await _discovery.startBroadcasting(deviceName: deviceName, port: 8080);
      
      // Show server status notification
      await _notifications.showServerStatus(
        isRunning: true,
        port: 8080,
      );
      
      setState(() {
        _isReceiving = true;
        _discoverable = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start server: $e')),
      );
    }
  }

  Future<void> _stopReceiving() async {
    await _receiver.stopServer();
    await _discovery.stopBroadcasting();
    
    // Show server status notification
    await _notifications.showServerStatus(
      isRunning: false,
      port: 8080,
    );
    
    setState(() {
      _isReceiving = false;
      _discoverable = false;
    });
  }

  Future<void> _addPeerManually() async {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '8080');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Peer Manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name (optional)',
                  hintText: 'My Device',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.1.42',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ipController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('IP address is required')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim().isNotEmpty 
          ? nameController.text.trim() 
          : ipController.text.trim();
      final port = int.tryParse(portController.text) ?? 8080;
      
      final peer = Peer(
        name: name,
        host: ipController.text.trim(),
        port: port,
      );
      
      setState(() {
        // Remove existing peer with same host:port if exists
        _manualPeers.removeWhere((p) => p.host == peer.host && p.port == peer.port);
        _manualPeers.add(peer);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added peer: ${peer.name}')),
      );
    }
  }

  List<Peer> get _allPeers {
    final all = <Peer>[..._discoveredPeers, ..._manualPeers];
    // Remove duplicates based on host:port
    final unique = <String, Peer>{};
    for (final peer in all) {
      unique['${peer.host}:${peer.port}'] = peer;
    }
    return unique.values.toList();
  }
  
  /// Handle files dropped onto the app
  Future<void> _handleDroppedFiles(List<XFile> files) async {
    try {
      if (files.isEmpty) return;
      
      final fileInfos = await DragDropService.getMultipleFileInfo(files);
      
      if (!mounted) return;
      
      // If there are multiple files, show selection dialog
      if (fileInfos.length > 1) {
        await _showFileSelectionDialog(fileInfos);
      } else if (fileInfos.length == 1) {
        // Single file - check if there's a target IP set
        final target = _ipController.text.trim();
        if (target.isNotEmpty) {
          await _sendSingleFile(fileInfos.first.path, target, 8080);
        } else {
          await _showFileSelectionDialog(fileInfos);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing dropped files: $e')),
        );
      }
    }
  }
  
  /// Show file selection dialog for multiple files
  Future<void> _showFileSelectionDialog(List<FileInfo> fileInfos) async {
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return FileSelectionDialog(
          files: fileInfos,
          onFilesConfirmed: (selectedFiles) async {
            Navigator.of(context).pop(true);
            await _sendSelectedFiles(selectedFiles);
          },
          onCancel: () {
            Navigator.of(context).pop(false);
          },
        );
      },
    );
  }
  
  /// Send selected files to target
  Future<void> _sendSelectedFiles(List<FileInfo> files) async {
    final target = _ipController.text.trim();
    if (target.isEmpty) {
      // Show peer selection if no target IP is set
      await _showPeerSelectionForFiles(files);
      return;
    }
    
    for (final file in files) {
      await _sendSingleFile(file.path, target, 8080);
      // Small delay between files to prevent overwhelming the receiver
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  /// Show peer selection dialog for files
  Future<void> _showPeerSelectionForFiles(List<FileInfo> files) async {
    if (_allPeers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No peers available. Please add a peer manually or set a target IP address.',
          ),
        ),
      );
      return;
    }
    
    final selectedPeer = await showDialog<Peer>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Target Peer'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView.builder(
              itemCount: _allPeers.length,
              itemBuilder: (context, index) {
                final peer = _allPeers[index];
                final isManual = _manualPeers.any((p) => p.host == peer.host && p.port == peer.port);
                return ListTile(
                  leading: Icon(
                    isManual ? Icons.person_add : Icons.devices_other,
                    color: isManual ? Colors.orange : null,
                  ),
                  title: Text(peer.name.isEmpty ? peer.host : peer.name),
                  subtitle: Text('${peer.host}:${peer.port}'),
                  onTap: () {
                    Navigator.of(context).pop(peer);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    
    if (selectedPeer != null) {
      for (final file in files) {
        await _sendSingleFile(file.path, selectedPeer.host, selectedPeer.port);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }
  
  /// Show multi-file picker
  Future<void> _showMultiFilePicker() async {
    final targetPeer = _ipController.text.trim().isNotEmpty
        ? Peer(
            name: _ipController.text.trim(),
            host: _ipController.text.trim(),
            port: 8080,
          )
        : null;

    await showMultiFilePicker(
      context,
      onFilesSelected: _handleMultiFileSelection,
      defaultPeer: targetPeer,
      showPeerSelection: _allPeers.isNotEmpty || targetPeer != null,
    );
  }

  /// Handle multi-file selection and start batch transfer
  Future<void> _handleMultiFileSelection(
    List<BatchFile> files, 
    Peer? targetPeer, {
    bool useCompression = false,
    CompressionLevel compressionLevel = CompressionLevel.balanced,
    bool smartCompression = true,
  }) async {
    if (files.isEmpty) return;

    // Determine target peer
    Peer? selectedPeer = targetPeer;
    if (selectedPeer == null) {
      if (_allPeers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add a peer or enter an IP address first.'),
          ),
        );
        return;
      }
      // Use the first available peer if no specific peer selected
      selectedPeer = _allPeers.first;
    }

    try {
      final batchService = BatchTransferService();
      final transferId = await batchService.startBatchTransfer(
        files: files,
        targetPeer: selectedPeer,
        useCompression: useCompression,
        compressionLevel: compressionLevel,
        smartCompression: smartCompression,
      );

      // Show batch transfer started notification
      final statusMessage = useCompression 
          ? 'Compressing and sending ${files.length} files'
          : 'Sending ${files.length} files';
      
      await _notifications.showTransferStarted(
        fileName: statusMessage,
        targetDevice: '${selectedPeer.host}:${selectedPeer.port}',
      );

      // Show batch transfer progress dialog
      showBatchTransferProgress(
        context,
        transferId: transferId,
        batchService: batchService,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            useCompression
                ? 'Started compressed batch transfer of ${files.length} files to ${selectedPeer.name}'
                : 'Started batch transfer of ${files.length} files to ${selectedPeer.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start batch transfer: $e')),
      );
    }
  }

  /// Send a single file to target
  Future<void> _sendSingleFile(String filePath, String host, int port) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final totalLabel = ValueNotifier<String>('Preparing...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Sending ${filePath.split(Platform.pathSeparator).last}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, _) {
                  return AnimatedProgressIndicator(
                    progress: value,
                    strokeWidth: 6.0,
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: totalLabel,
                builder: (context, text, _) {
                  return Text(text);
                },
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Show transfer started notification
      final fileName = filePath.split(Platform.pathSeparator).last;
      await _notifications.showTransferStarted(
        fileName: fileName,
        targetDevice: '$host:$port',
      );
      
      final ok = await _sender.sendFile(
        filePath: filePath,
        targetIp: host,
        targetPort: port,
        onProgress: (sent, total) {
          final progress = total > 0 ? sent / total : 0.0;
          progressNotifier.value = progress.clamp(0.0, 1.0);
          totalLabel.value = 'Sent ${_formatBytes(sent)} of ${_formatBytes(total)}';
          
          // Update progress notification periodically (every 20%)
          final progressPercent = (progress * 100).toInt();
          if (progressPercent % 20 == 0 && progressPercent > 0) {
            _notifications.showTransferProgress(
              fileName: fileName,
              progress: progress,
              targetDevice: '$host:$port',
            );
          }
        },
      );
      
      Navigator.of(context, rootNavigator: true).pop();
      
      // Show transfer completed notification
      await _notifications.showTransferCompleted(
        fileName: fileName,
        targetDevice: '$host:$port',
        success: ok,
      );
      
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File sent successfully: ${filePath.split(Platform.pathSeparator).last}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${filePath.split(Platform.pathSeparator).last}'),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stork P2P'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transfer History',
            onPressed: _openTransferHistory,
          ),
          if (_securityEnabled) // Only show if security is available
            IconButton(
              icon: Icon(
                _securityManager?.isPinRequired == true
                    ? Icons.security
                    : Icons.security_outlined,
                color: _securityManager?.isPinRequired == true
                    ? Colors.green
                    : null,
              ),
              tooltip: 'Security Settings',
              onPressed: _openSecuritySettings,
            ),
          IconButton(
            icon: Icon(
              widget.themeService.isDarkMode 
                  ? Icons.light_mode_outlined 
                  : Icons.dark_mode_outlined,
            ),
            tooltip: widget.themeService.isDarkMode 
                ? 'Switch to light theme' 
                : 'Switch to dark theme',
            onPressed: () {
              widget.themeService.toggleTheme();
            },
          ),
          PopupMenuButton<AppThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Theme options',
            onSelected: (mode) {
              widget.themeService.setThemeMode(mode);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AppThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode, 
                         color: widget.themeService.themeMode == AppThemeMode.light 
                             ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    const Text('Light'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode, 
                         color: widget.themeService.themeMode == AppThemeMode.dark 
                             ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    const Text('Dark'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.settings_brightness, 
                         color: widget.themeService.themeMode == AppThemeMode.system 
                             ? Theme.of(context).primaryColor : null),
                    const SizedBox(width: 8),
                    const Text('System'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: DragDropOverlay(
        onFilesDropped: _handleDroppedFiles,
        hintText: 'Drop files here to send to peers',
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Target IP address',
                      hintText: 'e.g. 192.168.1.42',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickAndSendFile,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showMultiFilePicker,
                  icon: const Icon(Icons.attachment),
                  label: const Text('Multi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Discoverable / Receiving'),
                    const SizedBox(width: 8),
                    if (_isReceiving)
                      AnimatedTransferStatus(
                        status: 'Active',
                        icon: Icons.radio_button_checked,
                        color: Colors.green,
                      ),
                  ],
                ),
                Switch(
                  value: _discoverable,
                  onChanged: (v) async {
                    if (v) {
                      await _startReceiving();
                    } else {
                      await _stopReceiving();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isReceiving ? null : _startReceiving,
                  child: const Text('Start Receiving'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isReceiving ? _stopReceiving : null,
                  child: const Text('Stop Receiving'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Peers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addPeerManually,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Peer'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _allPeers.isEmpty
                  ? PeerListEmptyState(
                      onAddPeer: _addPeerManually,
                      onStartDiscovery: () async {
                        // Restart discovery
                        _discovery.stop();
                        await Future.delayed(const Duration(milliseconds: 500));
                        _discovery.start();
                      },
                      isDiscovering: false,
                    )
                  : ListView.builder(
                      itemCount: _allPeers.length,
                      itemBuilder: (context, index) {
                        final peer = _allPeers[index];
                        final isManual = _manualPeers.any((p) => p.host == peer.host && p.port == peer.port);
                        
                        return AnimatedFileCard(
                          delay: Duration(milliseconds: index * 50),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                isManual ? Icons.person_add : Icons.devices_other,
                                color: isManual ? Colors.orange : null,
                              ),
                              title: Text(peer.name.isEmpty ? peer.host : peer.name),
                              subtitle: Text('${peer.host}:${peer.port}${isManual ? ' (Manual)' : ''}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isManual)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _manualPeers.removeWhere((p) => p.host == peer.host && p.port == peer.port);
                                        });
                                      },
                                    ),
                                  const Icon(Icons.send),
                                ],
                              ),
                              onTap: () async {
                                // One-tap: pick a file and send directly to this peer
                                await _pickAndSendTo(peer.host, peer.port);
                              },
                              onLongPress: () {
                                // Long-press: just populate the IP field (legacy/manual flow)
                                _ipController.text = peer.host;
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
