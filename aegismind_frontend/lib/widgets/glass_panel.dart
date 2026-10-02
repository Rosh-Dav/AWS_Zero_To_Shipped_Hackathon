import 'dart:ui';

import 'package:flutter/material.dart';

/// A shared translucent surface used throughout the app's frosted-glass UI.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Color? tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = tint ?? theme.colorScheme.surface.withValues(alpha: isDark ? 0.58 : 0.70);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Provides the soft color layers that make the glass surfaces visible.
class GlassBackdrop extends StatelessWidget {
  final Widget child;

  const GlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF10162B), Color(0xFF1F1A3B), Color(0xFF092C3D)]
              : const [Color(0xFFF1F5FF), Color(0xFFFFF4FA), Color(0xFFEAFBFA)],
        ),
      ),
      child: child,
    );
  }
}
