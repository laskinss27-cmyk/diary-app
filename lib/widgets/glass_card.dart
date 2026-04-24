import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';

/// Frosted-glass container. Uses BackdropFilter — on the FrostedBackground
/// (with colour blobs underneath) the blur is visible and richly tinted.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double sigma;
  final VoidCallback? onTap;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 22,
    this.sigma = 18,
    this.onTap,
    this.opacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final isDark = t.brightness == Brightness.dark;
    final fill = (isDark ? Colors.white : Colors.white).withValues(
      alpha: isDark ? 0.08 : opacity,
    );
    final borderColor = (isDark ? Colors.white : Colors.white)
        .withValues(alpha: isDark ? 0.12 : 0.55);

    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      body = InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: body,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: body,
        ),
      ),
    );
  }
}
