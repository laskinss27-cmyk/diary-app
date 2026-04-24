import 'package:flutter/material.dart';

class MoodBadge extends StatefulWidget {
  final int score;
  final double size;
  const MoodBadge({super.key, required this.score, this.size = 36});

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

  Color _colorForScore(int s) {
    if (s >= 9) return const Color(0xFF43A047);
    if (s >= 7) return const Color(0xFF8BC34A);
    if (s >= 5) return const Color(0xFFFFC107);
    if (s >= 3) return const Color(0xFFFF9800);
    if (s >= 2) return const Color(0xFFE53935);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForScore(widget.score);
    final size = widget.size;
    final crisis = widget.score <= 1;

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.95), color],
          stops: const [0.0, 1.0],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: crisis
          ? Text('🆘', style: TextStyle(fontSize: size * 0.5))
          : Text(
              '${widget.score}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            ),
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
