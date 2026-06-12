import 'package:flutter/material.dart';
import '../main.dart';
import 'mood_face.dart';

/// Soft mood indicator: a theme-tinted circle with the user's own mood
/// emoji. No traffic-light colours and no visible grade — the tint just
/// gets richer on better days. Crisis entries (score <= 1) keep the
/// pulsing SOS so the help path stays noticeable.
class MoodBadge extends StatefulWidget {
  final int score;
  final double size;
  final String? emoji;
  const MoodBadge({super.key, required this.score, this.size = 36, this.emoji});

  @override
  State<MoodBadge> createState() => _MoodBadgeState();
}

class _MoodBadgeState extends State<MoodBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.score <= 1) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final color = t.moodColor(widget.score);
    final size = widget.size;
    final crisis = widget.score <= 1;
    final emoji = widget.emoji;

    // The faces are round neon bubbles already — a circle around them
    // would be a double frame, so they go full-size on their own.
    final badge = crisis
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text('🆘', style: TextStyle(fontSize: size * 0.5)),
          )
        : MoodFace(
            emoji: emoji ?? '',
            score: widget.score,
            size: size,
          );

    if (_pulse == null) return badge;
    return ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulse!, curve: Curves.easeInOut),
      ),
      child: badge,
    );
  }
}
