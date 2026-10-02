import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UrgencyBadge extends StatefulWidget {
  final String urgency;

  const UrgencyBadge({super.key, required this.urgency});

  @override
  State<UrgencyBadge> createState() => _UrgencyBadgeState();
}

class _UrgencyBadgeState extends State<UrgencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.urgency == 'CRITICAL') {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant UrgencyBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.urgency == 'CRITICAL' && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.urgency != 'CRITICAL') {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getUrgencyColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.urgency) {
      case 'CRITICAL':
        return theme.dangerColor;
      case 'HIGH':
        return theme.warningColor;
      case 'MEDIUM':
        return theme.successColor;
      default:
        return theme.idleColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getUrgencyColor(context);
    final isCritical = widget.urgency == 'CRITICAL';

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isCritical ? 0.3 + (_glowAnimation.value * 0.3) : 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: isCritical ? _glowAnimation.value : 0.2),
              width: 1,
            ),
            boxShadow: isCritical
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: _glowAnimation.value * 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCritical) ...[
                Icon(Icons.warning_amber_rounded, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                widget.urgency,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
