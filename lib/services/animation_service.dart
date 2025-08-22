import 'package:flutter/material.dart';

/// Service for managing animations throughout the app
class AnimationService {
  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  
  // Animation curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceInCurve = Curves.elasticOut;
  static const Curve slideInCurve = Curves.easeOutCubic;
  
  /// Create a slide transition from bottom
  static Widget slideFromBottom({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: slideInCurve,
      )),
      child: child,
    );
  }
  
  /// Create a slide transition from right
  static Widget slideFromRight({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: slideInCurve,
      )),
      child: child,
    );
  }
  
  /// Create a fade transition
  static Widget fadeTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: defaultCurve,
      ),
      child: child,
    );
  }
  
  /// Create a scale transition with bounce
  static Widget scaleWithBounce({
    required Widget child,
    required Animation<double> animation,
  }) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: bounceInCurve,
      ),
      child: child,
    );
  }
  
  /// Create a combined fade and scale transition
  static Widget fadeAndScale({
    required Widget child,
    required Animation<double> animation,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: defaultCurve,
    );
    
    return FadeTransition(
      opacity: curvedAnimation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

/// Custom animated progress indicator for file transfers
class AnimatedProgressIndicator extends StatefulWidget {
  final double progress;
  final Color? primaryColor;
  final Color? backgroundColor;
  final double strokeWidth;
  final Duration animationDuration;
  
  const AnimatedProgressIndicator({
    Key? key,
    required this.progress,
    this.primaryColor,
    this.backgroundColor,
    this.strokeWidth = 4.0,
    this.animationDuration = AnimationService.normalDuration,
  }) : super(key: key);
  
  @override
  State<AnimatedProgressIndicator> createState() => _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _currentProgress,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationService.defaultCurve,
    ));
    
    _controller.forward();
  }
  
  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _currentProgress = _animation.value;
      _animation = Tween<double>(
        begin: _currentProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: AnimationService.defaultCurve,
      ));
      _controller.reset();
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _animation.value,
          backgroundColor: widget.backgroundColor ?? theme.colorScheme.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.primaryColor ?? theme.colorScheme.primary,
          ),
          minHeight: widget.strokeWidth,
        );
      },
    );
  }
}

/// Animated transfer status widget
class AnimatedTransferStatus extends StatefulWidget {
  final String status;
  final IconData icon;
  final Color? color;
  final Duration animationDuration;
  
  const AnimatedTransferStatus({
    Key? key,
    required this.status,
    required this.icon,
    this.color,
    this.animationDuration = AnimationService.normalDuration,
  }) : super(key: key);
  
  @override
  State<AnimatedTransferStatus> createState() => _AnimatedTransferStatusState();
}

class _AnimatedTransferStatusState extends State<AnimatedTransferStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationService.bounceInCurve,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationService.defaultCurve,
    ));
    
    _controller.forward();
  }
  
  @override
  void didUpdateWidget(AnimatedTransferStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.icon != widget.icon) {
      _controller.reset();
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = widget.color ?? theme.colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated file item card for the transfer list
class AnimatedFileCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration animationDuration;
  
  const AnimatedFileCard({
    Key? key,
    required this.child,
    this.delay = Duration.zero,
    this.animationDuration = AnimationService.normalDuration,
  }) : super(key: key);
  
  @override
  State<AnimatedFileCard> createState() => _AnimatedFileCardState();
}

class _AnimatedFileCardState extends State<AnimatedFileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationService.slideInCurve,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationService.defaultCurve,
    ));
    
    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}
