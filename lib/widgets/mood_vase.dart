import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';

enum VaseState { empty, dried, wilting, alive, fresh }

VaseState computeVaseState(List<DiaryEntry> entries, int capacity) {
  if (entries.isEmpty) return VaseState.empty;
  final count = entries.length.clamp(0, capacity);
  double sum = 0;
  for (int i = 0; i < count; i++) {
    sum += (entries[i].analysis?.score ?? 5);
  }
  final avg = sum / count;
  if (avg <= 3) return VaseState.dried;
  if (avg <= 5) return VaseState.wilting;
  if (avg <= 7) return VaseState.alive;
  return VaseState.fresh;
}

class MoodVase extends StatelessWidget {
  final List<DiaryEntry> entries;
  final int capacity;

  const MoodVase({
    super.key,
    required this.entries,
    this.capacity = 10,
  });

  String _title(VaseState state) {
    switch (state) {
      case VaseState.empty:
        return 'Твоё состояние';
      case VaseState.dried:
        return 'Цветам нужна вода';
      case VaseState.wilting:
        return 'Цветы поникли';
      case VaseState.alive:
        return 'Цветы живые';
      case VaseState.fresh:
        return 'Свежий букет';
    }
  }

  String _subtitle(VaseState state) {
    final count = entries.length.clamp(0, capacity);
    switch (state) {
      case VaseState.empty:
        return 'Ваза пуста. Первая запись —\nпервый цветок.';
      case VaseState.dried:
        return 'Так тоже бывает.\n$count из $capacity записей.';
      case VaseState.wilting:
        return 'Им нужно время.\n$count из $capacity записей.';
      case VaseState.alive:
        return 'Всё идёт своим чередом.\n$count из $capacity записей.';
      case VaseState.fresh:
        return 'Хорошие дни.\n$count из $capacity записей.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final state = computeVaseState(entries, capacity);
    final isDark = t.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.cardShadow.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 124,
                  child: CustomPaint(
                    painter: _VasePainter(
                      state: state,
                      isDark: isDark,
                      tint: t.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title(state),
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(state),
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stem {
  final Offset base;
  final Offset c1;
  final Offset c2;
  final Offset tip;
  const _Stem(this.base, this.c1, this.c2, this.tip);
}

class _VasePainter extends CustomPainter {
  final VaseState state;
  final bool isDark;
  final Color tint;

  _VasePainter({required this.state, required this.isDark, required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final vaseTopY = h * 0.56;
    final vaseBottomY = h * 0.97;

    if (state != VaseState.empty) {
      _drawStems(canvas, cx, vaseTopY, vaseBottomY);
    }

    _drawVase(canvas, w, cx, vaseTopY, vaseBottomY);

    if (state == VaseState.dried) {
      _drawFallenPetals(canvas, cx, vaseBottomY);
    }
  }

  void _drawVase(
      Canvas canvas, double w, double cx, double vaseTopY, double vaseBottomY) {
    final openW = w * 0.46;
    final bodyW = w * 0.66;
    final bottomW = w * 0.38;
    final vaseH = vaseBottomY - vaseTopY;

    // Ceramic tinted by the current theme so the vase always matches it.
    final fillTop = Color.lerp(
        isDark ? const Color(0xFF3A3A50) : Colors.white, tint,
        isDark ? 0.30 : 0.22)!;
    final fillBottom = Color.lerp(
        isDark ? const Color(0xFF2E2E42) : Colors.white, tint,
        isDark ? 0.45 : 0.40)!;
    final outline = Color.lerp(
        isDark ? const Color(0xFF55556E) : const Color(0xFFB0A6B8), tint,
        0.35)!;

    final path = Path();
    final rimY = vaseTopY - 3;
    path.moveTo(cx - openW / 2 - 2.5, rimY);
    path.quadraticBezierTo(cx, rimY - 2.5, cx + openW / 2 + 2.5, rimY);
    path.lineTo(cx + openW / 2, vaseTopY);
    path.cubicTo(
      cx + bodyW / 2 + 3, vaseTopY + vaseH * 0.30,
      cx + bodyW / 2 + 1, vaseTopY + vaseH * 0.68,
      cx + bottomW / 2, vaseBottomY - 2,
    );
    path.quadraticBezierTo(
        cx, vaseBottomY + 2, cx - bottomW / 2, vaseBottomY - 2);
    path.cubicTo(
      cx - bodyW / 2 - 1, vaseTopY + vaseH * 0.68,
      cx - bodyW / 2 - 3, vaseTopY + vaseH * 0.30,
      cx - openW / 2, vaseTopY,
    );
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillTop, fillBottom],
      ).createShader(
          Rect.fromLTRB(cx - bodyW / 2, rimY, cx + bodyW / 2, vaseBottomY));
    canvas.drawPath(path, fillPaint);

    // Glossy highlight along the left side.
    canvas.save();
    canvas.clipPath(path);
    final hl = Path()
      ..moveTo(cx - openW / 2 + 4, vaseTopY + 4)
      ..cubicTo(
        cx - bodyW / 2 + 8, vaseTopY + vaseH * 0.34,
        cx - bodyW / 2 + 10, vaseTopY + vaseH * 0.62,
        cx - bottomW / 2 + 6, vaseBottomY - 6,
      )
      ..lineTo(cx - bottomW / 2 + 12, vaseBottomY - 6)
      ..cubicTo(
        cx - bodyW / 2 + 16, vaseTopY + vaseH * 0.62,
        cx - bodyW / 2 + 14, vaseTopY + vaseH * 0.34,
        cx - openW / 2 + 10, vaseTopY + 4,
      )
      ..close();
    canvas.drawPath(
      hl,
      Paint()..color = Colors.white.withValues(alpha: isDark ? 0.08 : 0.35),
    );
    // Water line just below the neck.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, vaseTopY + vaseH * 0.18),
        width: openW + 8,
        height: 7,
      ),
      Paint()..color = Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawStems(
      Canvas canvas, double cx, double vaseTopY, double vaseBottomY) {
    List<_Stem> stems;
    Color stemColor;
    Color leafColor;
    List<Color> flowerColors;
    double flowerR;
    int petalCount;
    bool drooping;
    bool showLeaves;

    switch (state) {
      case VaseState.empty:
        return;

      case VaseState.dried:
        // Heads hang over the rim — sad, but soft and cared-for, not ugly.
        stems = [
          _Stem(Offset(cx - 5, vaseTopY), Offset(cx - 9, vaseTopY - 24),
              Offset(cx - 22, vaseTopY - 26), Offset(cx - 24, vaseTopY - 12)),
          _Stem(Offset(cx, vaseTopY), Offset(cx + 1, vaseTopY - 32),
              Offset(cx + 9, vaseTopY - 33), Offset(cx + 11, vaseTopY - 22)),
          _Stem(Offset(cx + 5, vaseTopY), Offset(cx + 9, vaseTopY - 20),
              Offset(cx + 21, vaseTopY - 21), Offset(cx + 23, vaseTopY - 9)),
        ];
        stemColor =
            isDark ? const Color(0xFF8A7A60) : const Color(0xFFA08868);
        leafColor =
            isDark ? const Color(0xFF7A6E55) : const Color(0xFFB0A07A);
        flowerColors = const [
          Color(0xFFB08A78),
          Color(0xFFA89070),
          Color(0xFFBA9484),
        ];
        flowerR = 4.5;
        petalCount = 5;
        drooping = true;
        showLeaves = false;
        break;

      case VaseState.wilting:
        stems = [
          _Stem(Offset(cx - 6, vaseTopY), Offset(cx - 10, vaseTopY - 22),
              Offset(cx - 15, vaseTopY - 30), Offset(cx - 17, vaseTopY - 26)),
          _Stem(Offset(cx, vaseTopY), Offset(cx + 1, vaseTopY - 26),
              Offset(cx + 2, vaseTopY - 36), Offset(cx + 3, vaseTopY - 34)),
          _Stem(Offset(cx + 6, vaseTopY), Offset(cx + 10, vaseTopY - 20),
              Offset(cx + 16, vaseTopY - 28), Offset(cx + 19, vaseTopY - 24)),
        ];
        stemColor =
            isDark ? const Color(0xFF8A8A55) : const Color(0xFF9A9A60);
        leafColor =
            isDark ? const Color(0xFF7E8048) : const Color(0xFFB0AC68);
        flowerColors = const [
          Color(0xFFE0B060),
          Color(0xFFD89A58),
          Color(0xFFE0A878),
        ];
        flowerR = 6.0;
        petalCount = 5;
        drooping = false;
        showLeaves = true;
        break;

      case VaseState.alive:
        stems = [
          _Stem(Offset(cx - 8, vaseTopY), Offset(cx - 11, vaseTopY - 18),
              Offset(cx - 14, vaseTopY - 32), Offset(cx - 16, vaseTopY - 40)),
          _Stem(Offset(cx - 1, vaseTopY), Offset(cx - 1, vaseTopY - 20),
              Offset(cx, vaseTopY - 36), Offset(cx, vaseTopY - 46)),
          _Stem(Offset(cx + 7, vaseTopY), Offset(cx + 9, vaseTopY - 18),
              Offset(cx + 13, vaseTopY - 30), Offset(cx + 17, vaseTopY - 38)),
        ];
        stemColor =
            isDark ? const Color(0xFF4A8A4A) : const Color(0xFF5FA05F);
        leafColor =
            isDark ? const Color(0xFF3A7A3A) : const Color(0xFF6FB060);
        flowerColors = const [
          Color(0xFFE27A9E),
          Color(0xFFB57BC8),
          Color(0xFFD9719A),
        ];
        flowerR = 7.5;
        petalCount = 6;
        drooping = false;
        showLeaves = true;
        break;

      case VaseState.fresh:
        stems = [
          _Stem(Offset(cx - 9, vaseTopY), Offset(cx - 13, vaseTopY - 18),
              Offset(cx - 17, vaseTopY - 32), Offset(cx - 20, vaseTopY - 40)),
          _Stem(Offset(cx - 3, vaseTopY), Offset(cx - 4, vaseTopY - 22),
              Offset(cx - 4, vaseTopY - 38), Offset(cx - 3, vaseTopY - 48)),
          _Stem(Offset(cx + 3, vaseTopY), Offset(cx + 4, vaseTopY - 20),
              Offset(cx + 6, vaseTopY - 34), Offset(cx + 8, vaseTopY - 44)),
          _Stem(Offset(cx + 9, vaseTopY), Offset(cx + 13, vaseTopY - 16),
              Offset(cx + 18, vaseTopY - 28), Offset(cx + 22, vaseTopY - 36)),
        ];
        stemColor =
            isDark ? const Color(0xFF3A9A3A) : const Color(0xFF4FAF5F);
        leafColor =
            isDark ? const Color(0xFF2A8A2A) : const Color(0xFF5FBF55);
        flowerColors = const [
          Color(0xFFE85A90),
          Color(0xFF8E5FD8),
          Color(0xFFF0789C),
          Color(0xFF6A78E0),
        ];
        flowerR = 8.5;
        petalCount = 6;
        drooping = false;
        showLeaves = true;
        break;
    }

    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < stems.length; i++) {
      final s = stems[i];

      final stemPath = Path()
        ..moveTo(s.base.dx, s.base.dy)
        ..cubicTo(s.c1.dx, s.c1.dy, s.c2.dx, s.c2.dy, s.tip.dx, s.tip.dy);
      canvas.drawPath(stemPath, stemPaint);

      if (showLeaves) {
        const t = 0.42;
        final lx = _cubicPoint(s.base.dx, s.c1.dx, s.c2.dx, s.tip.dx, t);
        final ly = _cubicPoint(s.base.dy, s.c1.dy, s.c2.dy, s.tip.dy, t);
        final side = (i % 2 == 0) ? 1.0 : -1.0;
        _drawLeaf(canvas, lx, ly, side * 38, leafColor, 13);
      }

      _drawFlower(canvas, s.tip.dx, s.tip.dy, flowerR, petalCount,
          flowerColors[i % flowerColors.length],
          drooping: drooping);
    }

    // Baby's breath between the stems on the best days.
    if (state == VaseState.fresh) {
      final dotPaint = Paint()
        ..color = (isDark ? Colors.white70 : Colors.white)
            .withValues(alpha: isDark ? 0.7 : 0.95);
      canvas.drawCircle(Offset(cx - 11, vaseTopY - 28), 2.2, dotPaint);
      canvas.drawCircle(Offset(cx + 1, vaseTopY - 26), 1.8, dotPaint);
      canvas.drawCircle(Offset(cx + 13, vaseTopY - 22), 2.2, dotPaint);
    }
  }

  double _cubicPoint(double p0, double p1, double p2, double p3, double t) {
    final mt = 1 - t;
    return mt * mt * mt * p0 +
        3 * mt * mt * t * p1 +
        3 * mt * t * t * p2 +
        t * t * t * p3;
  }

  /// Lush layered flower: a ring of oval petals, a lighter inner ring and
  /// a warm centre. [drooping] tilts the head downward for sad states.
  void _drawFlower(Canvas canvas, double x, double y, double r, int petals,
      Color color,
      {bool drooping = false}) {
    canvas.save();
    canvas.translate(x, y);
    if (drooping) canvas.rotate(math.pi * 0.85);

    final outerPaint = Paint()..color = color;
    final innerPaint = Paint()..color = Color.lerp(color, Colors.white, 0.30)!;

    for (int i = 0; i < petals; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / petals);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.62),
          width: r * 0.80,
          height: r * 1.10,
        ),
        outerPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.46, innerPaint);
    canvas.drawCircle(
      Offset.zero,
      r * 0.26,
      Paint()..color = const Color(0xFFFFF0C0),
    );
    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angleDeg,
      Color color, double length) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angleDeg * math.pi / 180);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(length * 0.3, -length * 0.26, length * 0.7, -length * 0.26,
          length, 0)
      ..cubicTo(
          length * 0.7, length * 0.26, length * 0.3, length * 0.26, 0, 0);
    canvas.drawPath(leafPath, paint);
    canvas.restore();
  }

  void _drawFallenPetals(Canvas canvas, double cx, double vaseBottomY) {
    final paint = Paint()
      ..color = const Color(0xFFB08A78).withValues(alpha: 0.8);
    canvas.save();
    canvas.translate(cx + 22, vaseBottomY - 1);
    canvas.rotate(0.5);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 3.6), paint);
    canvas.restore();
    canvas.save();
    canvas.translate(cx - 24, vaseBottomY - 1);
    canvas.rotate(-0.4);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 5, height: 3), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VasePainter old) {
    return old.state != state || old.isDark != isDark || old.tint != tint;
  }
}
