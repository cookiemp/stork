import 'package:flutter/material.dart';
import '../services/security_manager.dart';

/// Result of transfer approval dialog
enum ApprovalResult {
  approved,      // Accept once
  trusted,       // Accept and trust device
  denied,        // Deny transfer
}

/// Transfer approval dialog for unknown devices
class TransferApprovalDialog extends StatefulWidget {
  final String peerName;
  final String fileName;
  final int fileSize;
  final SecurityTransferDirection direction;
  final String? peerIcon; // Optional icon for the device
  
  const TransferApprovalDialog({
    super.key,
    required this.peerName,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    this.peerIcon,
  });
  
  @override
  State<TransferApprovalDialog> createState() => _TransferApprovalDialogState();
}

class _TransferApprovalDialogState extends State<TransferApprovalDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  IconData _getDirectionIcon() {
    return widget.direction == SecurityTransferDirection.received
        ? Icons.download
        : Icons.upload;
  }
  
  String _getDirectionText() {
    return widget.direction == SecurityTransferDirection.received
        ? 'wants to send you'
        : 'requesting';
  }
  
  Color _getSecurityColor(BuildContext context) {
    return widget.direction == SecurityTransferDirection.received
        ? Colors.orange // Incoming is more concerning
        : Colors.blue;   // Outgoing is less concerning
  }
  
  void _handleResponse(ApprovalResult result) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final securityColor = _getSecurityColor(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Security warning header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: securityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: securityColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: securityColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Approval Required',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: securityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'This device is not in your trusted list',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: securityColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Transfer details
                Row(
                  children: [
                    // Device icon
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: widget.peerIcon != null 
                          ? Text(
                              widget.peerIcon!,
                              style: const TextStyle(fontSize: 24),
                            )
                          : Icon(
                              Icons.devices,
                              size: 32,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Transfer info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device name
                          Text(
                            widget.peerName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Transfer description
                          Row(
                            children: [
                              Icon(
                                _getDirectionIcon(),
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_getDirectionText()} a file',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // File details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'File Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // File name
                      Row(
                        children: [
                          Text(
                            'Name: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.fileName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // File size
                      Row(
                        children: [
                          Text(
                            'Size: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _formatFileSize(widget.fileSize),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Processing...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  // Primary actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleResponse(ApprovalResult.denied),
                          icon: const Icon(Icons.block),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.withOpacity(0.5)),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleResponse(ApprovalResult.approved),
                          icon: const Icon(Icons.check),
                          label: const Text('Accept Once'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Trust option
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _handleResponse(ApprovalResult.trusted),
                      icon: const Icon(Icons.verified_user),
                      label: const Text('Accept & Trust Device'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Trust explanation
                  Text(
                    'Trusted devices can send files without asking permission',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Show transfer approval dialog
Future<ApprovalResult?> showTransferApprovalDialog({
  required BuildContext context,
  required String peerName,
  required String fileName,
  required int fileSize,
  required SecurityTransferDirection direction,
  String? peerIcon,
}) async {
  return await showDialog<ApprovalResult>(
    context: context,
    barrierDismissible: false, // Must make a choice
    builder: (context) => TransferApprovalDialog(
      peerName: peerName,
      fileName: fileName,
      fileSize: fileSize,
      direction: direction,
      peerIcon: peerIcon,
    ),
  );
}
