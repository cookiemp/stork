import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable PIN entry dialog for authentication
class PinEntryDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final bool isSetup; // true for setup, false for verification
  final String? confirmTitle; // For PIN confirmation during setup
  final Function(String pin) onPinEntered;
  final VoidCallback? onCancel;
  
  const PinEntryDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPinEntered,
    this.isSetup = false,
    this.confirmTitle,
    this.onCancel,
  });
  
  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showConfirm = false;
  
  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
  
  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
  
  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }
  
  bool _validatePin(String pin) {
    if (pin.length < 4 || pin.length > 8) {
      setState(() {
        _errorMessage = 'PIN must be 4-8 digits';
      });
      return false;
    }
    
    // Check if PIN contains only digits
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN must contain only numbers';
      });
      return false;
    }
    
    return true;
  }
  
  void _handleSubmit() {
    _clearError();
    
    final pin = _pinController.text;
    
    if (!_validatePin(pin)) {
      return;
    }
    
    // If this is setup mode and we haven't shown confirmation yet
    if (widget.isSetup && !_showConfirm) {
      setState(() {
        _showConfirm = true;
      });
      return;
    }
    
    // If this is setup mode with confirmation
    if (widget.isSetup && _showConfirm) {
      final confirmPin = _confirmController.text;
      
      if (pin != confirmPin) {
        setState(() {
          _errorMessage = 'PINs do not match';
        });
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    widget.onPinEntered(pin);
  }
  
  void _handleBack() {
    if (widget.isSetup && _showConfirm) {
      setState(() {
        _showConfirm = false;
        _confirmController.clear();
        _errorMessage = null;
      });
    } else {
      widget.onCancel?.call();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isSetup && _showConfirm 
                            ? (widget.confirmTitle ?? 'Confirm PIN')
                            : widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isSetup && _showConfirm
                            ? 'Re-enter your PIN to confirm'
                            : widget.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // PIN Input
            TextField(
              controller: widget.isSetup && _showConfirm 
                  ? _confirmController 
                  : _pinController,
              obscureText: _obscureText,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                labelText: widget.isSetup && _showConfirm 
                    ? 'Confirm PIN' 
                    : 'Enter PIN',
                prefixIcon: const Icon(Icons.pin),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: _toggleVisibility,
                ),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              autofocus: true,
            ),
            
            if (widget.isSetup && !_showConfirm) ...[
              const SizedBox(height: 8),
              Text(
                'PIN should be 4-8 digits for security',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null || (widget.isSetup && _showConfirm))
                  TextButton(
                    onPressed: _isLoading ? null : _handleBack,
                    child: Text(
                      widget.isSetup && _showConfirm ? 'Back' : 'Cancel'
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isSetup && _showConfirm 
                              ? 'Confirm' 
                              : widget.buttonText
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show PIN entry dialog
Future<String?> showPinDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  String buttonText = 'Continue',
  bool isSetup = false,
  String? confirmTitle,
}) async {
  String? enteredPin;
  
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinEntryDialog(
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
      isSetup: isSetup,
      confirmTitle: confirmTitle,
      onPinEntered: (pin) {
        enteredPin = pin;
        Navigator.of(context).pop(pin);
      },
      onCancel: () => Navigator.of(context).pop(null),
    ),
  );
  
  return result;
}

/// Show PIN setup dialog for first-time users
Future<String?> showPinSetupDialog(BuildContext context) {
  return showPinDialog(
    context: context,
    title: 'Secure Your Files',
    subtitle: 'Set up a PIN to protect your file transfers',
    buttonText: 'Set PIN',
    isSetup: true,
    confirmTitle: 'Confirm Your PIN',
  );
}

/// Show PIN verification dialog
Future<String?> showPinVerificationDialog(BuildContext context) {
  return showPinDialog(
    context: context,
    title: 'Enter PIN',
    subtitle: 'Enter your PIN to access Stork',
    buttonText: 'Unlock',
    isSetup: false,
  );
}
