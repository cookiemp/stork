import 'package:flutter/material.dart';

/// Enhanced empty state widget with better illustrations and user guidance
class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customMessage;
  final List<EmptyStateAction>? actions;
  final bool animated;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.customTitle,
    this.customMessage,
    this.actions,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getEmptyStateConfig(type);
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated illustration
              if (animated)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: _buildIllustration(config, theme),
                )
              else
                _buildIllustration(config, theme),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                customTitle ?? config.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                customMessage ?? config.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Steps or tips
              if (config.steps.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSteps(config.steps, theme),
              ],
              
              // Actions
              if (actions?.isNotEmpty == true) ...[
                const SizedBox(height: 32),
                _buildActions(actions!, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(_EmptyStateConfig config, ThemeData theme) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        config.icon,
        size: 64,
        color: config.color,
      ),
    );
  }

  Widget _buildSteps(List<String> steps, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions(List<EmptyStateAction> actions, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: actions.map((action) {
        return action.isPrimary
            ? ElevatedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              );
      }).toList(),
    );
  }

  _EmptyStateConfig _getEmptyStateConfig(EmptyStateType type) {
    switch (type) {
      case EmptyStateType.noPeers:
        return _EmptyStateConfig(
          icon: Icons.devices_outlined,
          color: Colors.blue,
          title: 'No Peers Available',
          message: 'No devices found on your network. You can discover peers automatically or add them manually.',
          steps: [
            'Make sure both devices are connected to the same Wi-Fi network',
            'Enable receiving mode on the target device',
            'Wait a few seconds for automatic discovery',
            'Or add peers manually using their IP address',
          ],
        );
      
      case EmptyStateType.noFiles:
        return _EmptyStateConfig(
          icon: Icons.folder_outlined,
          color: Colors.orange,
          title: 'No Files Received',
          message: 'Files you receive will appear here. Make sure receiving is enabled to accept incoming transfers.',
          steps: [
            'Turn on the receiving switch to accept files',
            'Share your IP address with senders',
            'Files will be saved to your Downloads folder',
            'You\'ll get notifications for completed transfers',
          ],
        );
      
      case EmptyStateType.searchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off_outlined,
          color: Colors.grey,
          title: 'No Results Found',
          message: 'Try adjusting your search terms or check if the device is online.',
          steps: [
            'Check the spelling of device names or IP addresses',
            'Make sure the target device is powered on',
            'Verify both devices are on the same network',
          ],
        );
      
      case EmptyStateType.networkError:
        return _EmptyStateConfig(
          icon: Icons.wifi_off_outlined,
          color: Colors.red,
          title: 'Network Connection Issues',
          message: 'Unable to discover devices or connect to peers. Check your network connection.',
          steps: [
            'Verify your Wi-Fi connection is active',
            'Check if your router allows device communication',
            'Try restarting your Wi-Fi adapter',
            'Consider adding peers manually',
          ],
        );
      
      case EmptyStateType.firstTime:
        return _EmptyStateConfig(
          icon: Icons.waving_hand_outlined,
          color: Colors.green,
          title: 'Welcome to Stork P2P!',
          message: 'Send files quickly and securely between devices on your local network.',
          steps: [
            'Turn on receiving to accept files from other devices',
            'Share your device IP with others to receive files',
            'Discovered devices will appear here automatically',
            'Drag and drop files for quick sharing',
          ],
        );
    }
  }
}

/// Specific empty state for peer list with discovery guidance
class PeerListEmptyState extends StatelessWidget {
  final VoidCallback? onAddPeer;
  final VoidCallback? onStartDiscovery;
  final bool isDiscovering;

  const PeerListEmptyState({
    super.key,
    this.onAddPeer,
    this.onStartDiscovery,
    this.isDiscovering = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: EmptyStateType.noPeers,
      actions: [
        if (onStartDiscovery != null)
          EmptyStateAction(
            label: isDiscovering ? 'Discovering...' : 'Scan for Devices',
            icon: isDiscovering ? Icons.refresh : Icons.radar,
            onPressed: isDiscovering ? () {} : onStartDiscovery!,
            isPrimary: true,
          ),
        if (onAddPeer != null)
          EmptyStateAction(
            label: 'Add Manually',
            icon: Icons.add,
            onPressed: onAddPeer!,
            isPrimary: false,
          ),
      ],
    );
  }
}

/// Specific empty state for file list with receiving guidance
class FileListEmptyState extends StatelessWidget {
  final VoidCallback? onEnableReceiving;
  final bool isReceiving;

  const FileListEmptyState({
    super.key,
    this.onEnableReceiving,
    this.isReceiving = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: EmptyStateType.noFiles,
      actions: [
        if (onEnableReceiving != null && !isReceiving)
          EmptyStateAction(
            label: 'Enable Receiving',
            icon: Icons.download,
            onPressed: onEnableReceiving!,
            isPrimary: true,
          ),
      ],
    );
  }
}

/// First-time user onboarding empty state
class OnboardingEmptyState extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const OnboardingEmptyState({
    super.key,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: EmptyStateType.firstTime,
      actions: [
        if (onGetStarted != null)
          EmptyStateAction(
            label: 'Get Started',
            icon: Icons.rocket_launch,
            onPressed: onGetStarted!,
            isPrimary: true,
          ),
      ],
    );
  }
}

/// Types of empty states
enum EmptyStateType {
  noPeers,
  noFiles,
  searchResults,
  networkError,
  firstTime,
}

/// Action button for empty states
class EmptyStateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}

/// Internal configuration for empty states
class _EmptyStateConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<String> steps;

  const _EmptyStateConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.steps = const [],
  });
}

/// Loading state widget for when content is being fetched
class LoadingEmptyState extends StatelessWidget {
  final String message;

  const LoadingEmptyState({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 6.28, // 2 * pi for full rotation
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
