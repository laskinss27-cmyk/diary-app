import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Theme-tinted background with soft colour blobs that BackdropFilter
/// has something rich to blur. Without these blobs the glass effect
/// is invisible against a flat gradient.
class FrostedBackground extends StatelessWidget {
  final AppThemeData theme;
  final Widget child;
  const FrostedBackground({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(gradient: theme.backgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: _blob(theme.primary.withValues(alpha: 0.55), 280),
          ),
          Positioned(
            top: 200,
            right: -90,
            child: _blob(theme.accent.withValues(alpha: 0.35), 240),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: _blob(theme.primary.withValues(alpha: 0.4), 320),
          ),
          Positioned(
            bottom: 120,
            right: -60,
            child: _blob(theme.accent.withValues(alpha: 0.28), 200),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
