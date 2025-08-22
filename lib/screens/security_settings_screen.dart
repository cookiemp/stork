import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_manager.dart';
import '../services/key_management_service.dart';
import '../widgets/pin_entry_dialog.dart';

/// Comprehensive security settings screen
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityManager _securityManager = SecurityManager.instance;
  bool _isLoading = false;
  SecurityConfiguration? _config;

  @override
  void initState() {
    super.initState();
    _loadSecurityConfig();
  }

  void _loadSecurityConfig() async {
    final config = await _securityManager.getSecurityConfigurationAsync();
    setState(() {
      _config = config;
    });
  }

  Future<void> _showPinSetupDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinEntryDialog(
        title: 'Set Up PIN',
        subtitle: 'Choose a 4-digit PIN to secure your device',
        buttonText: 'Set PIN',
        isSetup: true,
        onPinEntered: (pin) => Navigator.of(context).pop(pin),
        onCancel: () => Navigator.of(context).pop(),
      ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      
      final success = await _securityManager.setupPin(result);
      
      setState(() => _isLoading = false);
      
      if (success) {
        _loadSecurityConfig();
        _showSnackBar('PIN setup successful', Icons.check_circle, Colors.green);
      } else {
        _showSnackBar('Failed to setup PIN', Icons.error, Colors.red);
      }
    }
  }

  Future<void> _showChangePinDialog() async {
    // First verify current PIN
    final currentPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinEntryDialog(
        title: 'Enter Current PIN',
        subtitle: 'Enter your current PIN to proceed',
        buttonText: 'Verify',
        isSetup: false,
        onPinEntered: (pin) => Navigator.of(context).pop(pin),
        onCancel: () => Navigator.of(context).pop(),
      ),
    );

    if (currentPin == null) return;

    // Verify current PIN
    final verified = await _securityManager.verifyPin(currentPin);
    if (!verified) {
      if (mounted) {
        _showSnackBar('Incorrect PIN', Icons.error, Colors.red);
      }
      return;
    }

    // Get new PIN
    if (mounted) {
      final newPin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinEntryDialog(
          title: 'Set New PIN',
          subtitle: 'Choose a new 4-digit PIN',
          buttonText: 'Change PIN',
          isSetup: true,
          onPinEntered: (pin) => Navigator.of(context).pop(pin),
          onCancel: () => Navigator.of(context).pop(),
        ),
      );

      if (newPin != null && mounted) {
        setState(() => _isLoading = true);
        
        final success = await _securityManager.changePin(currentPin, newPin);
        
        setState(() => _isLoading = false);
        
        if (success) {
          _showSnackBar('PIN changed successfully', Icons.check_circle, Colors.green);
        } else {
          _showSnackBar('Failed to change PIN', Icons.error, Colors.red);
        }
      }
    }
  }

  Future<void> _showRemovePinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove PIN Protection'),
        content: const Text('Are you sure you want to remove PIN protection? This will make your device less secure.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Verify PIN before removal
      final pin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinEntryDialog(
          title: 'Enter Current PIN',
          subtitle: 'Enter your current PIN to remove protection',
          buttonText: 'Verify',
          isSetup: false,
          onPinEntered: (pin) => Navigator.of(context).pop(pin),
          onCancel: () => Navigator.of(context).pop(),
        ),
      );

      if (pin != null && mounted) {
        setState(() => _isLoading = true);
        
        final success = await _securityManager.removePin(pin);
        
        if (success) {
          _loadSecurityConfig();
          _showSnackBar('PIN protection removed', Icons.info, Colors.orange);
        } else {
          _showSnackBar('Incorrect PIN', Icons.error, Colors.red);
        }
        
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSecurityOverviewCard(),
                const SizedBox(height: 16),
                _buildPinManagementCard(),
                const SizedBox(height: 16),
                _buildTransferSecurityCard(),
                const SizedBox(height: 16),
                _buildTrustedDevicesCard(),
                const SizedBox(height: 16),
                _buildSecurityInfoCard(),
              ],
            ),
    );
  }

  Widget _buildSecurityOverviewCard() {
    final hasPin = _config!.requirePin;
    final securityLevel = hasPin ? 'High' : 'Basic';
    final securityColor = hasPin ? Colors.green : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          Row(
            children: [
              Icon(
                hasPin ? Icons.security : Icons.security_outlined,
                color: securityColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Level: $securityLevel',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: securityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPin
                          ? 'Your device is protected with PIN and encryption'
                          : 'Consider enabling PIN protection for better security',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinManagementCard() {
    final hasPin = _config!.requirePin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          Row(
            children: [
              Icon(
                Icons.pin,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Text(
                'PIN Protection',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(
              hasPin ? Icons.lock : Icons.lock_open,
              color: hasPin ? Colors.green : Colors.grey,
            ),
            title: Text(hasPin ? 'PIN Enabled' : 'PIN Disabled'),
            subtitle: Text(
              hasPin
                  ? 'Your device is protected with a 4-digit PIN'
                  : 'Set up a PIN to secure your device',
            ),
            trailing: hasPin ? null : const Icon(Icons.chevron_right),
            onTap: hasPin ? null : _showPinSetupDialog,
          ),
          if (hasPin) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Change PIN'),
              subtitle: const Text('Update your current PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePinDialog,
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove PIN Protection'),
              subtitle: const Text('Disable PIN protection (not recommended)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showRemovePinDialog,
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransferSecurityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          Row(
            children: [
              Icon(
                Icons.transfer_within_a_station,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Text(
                'Transfer Security',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            secondary: const Icon(Icons.approval),
            title: const Text('Require Transfer Approval'),
            subtitle: const Text('Ask for confirmation before accepting files'),
            value: _config!.requireApproval,
            onChanged: _isLoading ? null : (value) async {
              setState(() => _isLoading = true);
              
              final success = await _securityManager.setRequireApproval(value);
              
              setState(() => _isLoading = false);
              
              if (success) {
                _loadSecurityConfig();
                _showSnackBar(
                  value ? 'Transfer approval required' : 'Transfer approval disabled', 
                  Icons.check_circle, 
                  Colors.green,
                );
              } else {
                _showSnackBar('Failed to update setting', Icons.error, Colors.red);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.verified_user),
            title: const Text('Auto-approve Trusted Devices'),
            subtitle: const Text('Automatically accept files from trusted devices'),
            value: _config!.autoApproveTrustedPeers,
            onChanged: _isLoading ? null : (value) async {
              setState(() => _isLoading = true);
              
              final success = await _securityManager.setAutoApproveTrusted(value);
              
              setState(() => _isLoading = false);
              
              if (success) {
                _loadSecurityConfig();
                _showSnackBar(
                  value ? 'Auto-approval enabled for trusted devices' : 'Auto-approval disabled', 
                  Icons.check_circle, 
                  Colors.green,
                );
              } else {
                _showSnackBar('Failed to update setting', Icons.error, Colors.red);
              }
            },
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustedDevicesCard() {
    final trustedDevices = _securityManager.getTrustedPeers();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          Row(
            children: [
              Icon(
                Icons.devices,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Trusted Devices',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${trustedDevices.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (trustedDevices.isEmpty)
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              title: const Text('No trusted devices'),
              subtitle: const Text('Trust devices to enable automatic file acceptance'),
            )
          else
            ...trustedDevices.take(3).map((device) => ListTile(
              leading: const Icon(Icons.device_hub),
              title: Text(device.displayName),
              subtitle: Text('Trusted since ${_formatDate(device.trustedAt)}'),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove Trust'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'remove') {
                    _removeTrustedDevice(device);
                  }
                },
              ),
            )),
          if (trustedDevices.isNotEmpty) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Manage Trusted Devices'),
              subtitle: Text('View and manage all ${trustedDevices.length} trusted devices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTrustedDevicesScreen(),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Text(
                'Security Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Encryption', 'AES-256-GCM + RSA-2048'),
          _buildInfoRow('Device ID', SecurityManager.instance.isInitialized ? '••••••••' : 'Loading...'),
          _buildInfoRow('Max PIN Attempts', '${_config!.maxPinAttempts}'),
          _buildInfoRow('Session Timeout', '${_config!.sessionTimeoutMinutes} minutes'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _removeTrustedDevice(TrustedPeer device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Trusted Device'),
        content: Text('Are you sure you want to remove "${device.displayName}" from trusted devices?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _securityManager.removeTrustedPeer(device.id);
        _showSnackBar('Device removed from trusted list', Icons.check_circle, Colors.green);
        _loadSecurityConfig();
      } catch (e) {
        _showSnackBar('Failed to remove device', Icons.error, Colors.red);
      }
    }
  }

  void _showTrustedDevicesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrustedDevicesScreen(),
      ),
    );
  }
}

/// Screen for managing trusted devices
class TrustedDevicesScreen extends StatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  State<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends State<TrustedDevicesScreen> {
  final SecurityManager _securityManager = SecurityManager.instance;
  List<TrustedPeer> _trustedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadTrustedDevices();
  }

  void _loadTrustedDevices() {
    setState(() {
      _trustedDevices = _securityManager.getTrustedPeers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Devices'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _trustedDevices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Trusted Devices',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Devices become trusted when you accept transfers from them multiple times or manually trust them.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _trustedDevices.length,
              itemBuilder: (context, index) {
                final device = _trustedDevices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        device.displayName.isNotEmpty 
                            ? device.displayName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(device.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Device ID: ${device.id.substring(0, 8)}...'),
                        Text('Trusted: ${_formatDate(device.trustedAt)}'),
                        Text('Last seen: ${_formatDate(device.lastSeen)}'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remove Trust'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'remove') {
                          _removeTrustedDevice(device);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _removeTrustedDevice(TrustedPeer device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Trusted Device'),
        content: Text('Are you sure you want to remove "${device.displayName}" from trusted devices?\n\nFuture transfers from this device will require manual approval.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _securityManager.removeTrustedPeer(device.id);
        _loadTrustedDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${device.displayName} removed from trusted devices'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to remove device'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
