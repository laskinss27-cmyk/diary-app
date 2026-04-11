import 'dart:math' as math;
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
        return 'Цветы засохли';
      case VaseState.wilting:
        return 'Цветы увядают';
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 108,
            child: CustomPaint(
              painter: _VasePainter(
                state: state,
                isDark: t.brightness == Brightness.dark,
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
    );
  }
}

class _Stem {
  final Offset base;
  final Offset control;
  final Offset tip;
  const _Stem(this.base, this.control, this.tip);
}

class _VasePainter extends CustomPainter {
  final VaseState state;
  final bool isDark;

  _VasePainter({required this.state, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final vaseTopY = h * 0.52;
    final vaseBottomY = h * 0.96;

    if (state != VaseState.empty) {
      _drawStems(canvas, w, h, cx, vaseTopY);
    }

    _drawVase(canvas, w, h, cx, vaseTopY, vaseBottomY);
  }

  void _drawVase(Canvas canvas, double w, double h, double cx,
      double vaseTopY, double vaseBottomY) {
    final openW = w * 0.42;
    final bodyW = w * 0.58;
    final bottomW = w * 0.34;
    final vaseH = vaseBottomY - vaseTopY;

    Color fill;
    Color outline;
    switch (state) {
      case VaseState.empty:
        fill = isDark ? const Color(0xFF5A5A5A) : const Color(0xFFD0C8BC);
        outline = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFB8AFA3);
        break;
      case VaseState.dried:
        fill = isDark ? const Color(0xFF5C5346) : const Color(0xFFC4B8A8);
        outline = isDark ? const Color(0xFF4C4338) : const Color(0xFFADA192);
        break;
      case VaseState.wilting:
        fill = isDark ? const Color(0xFF6B5F4E) : const Color(0xFFD4C4A8);
        outline = isDark ? const Color(0xFF5A4F3E) : const Color(0xFFBFAF93);
        break;
      case VaseState.alive:
        fill = isDark ? const Color(0xFF5E6B5A) : const Color(0xFFC8D4C0);
        outline = isDark ? const Color(0xFF4E5B4A) : const Color(0xFFB0BCA8);
        break;
      case VaseState.fresh:
        fill = isDark ? const Color(0xFF5A6B6E) : const Color(0xFFBCD4D8);
        outline = isDark ? const Color(0xFF4A5B5E) : const Color(0xFFA4BCC0);
        break;
    }

    final path = Path();
    final rimY = vaseTopY - 2;
    path.moveTo(cx - openW / 2 - 2, rimY);
    path.lineTo(cx + openW / 2 + 2, rimY);
    path.lineTo(cx + openW / 2, vaseTopY);
    path.cubicTo(
      cx + bodyW / 2 + 2, vaseTopY + vaseH * 0.3,
      cx + bodyW / 2, vaseTopY + vaseH * 0.65,
      cx + bottomW / 2, vaseBottomY,
    );
    path.lineTo(cx - bottomW / 2, vaseBottomY);
    path.cubicTo(
      cx - bodyW / 2, vaseTopY + vaseH * 0.65,
      cx - bodyW / 2 - 2, vaseTopY + vaseH * 0.3,
      cx - openW / 2, vaseTopY,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = fill);

    canvas.save();
    canvas.clipPath(path);
    final hlPath = Path();
    hlPath.moveTo(cx - openW / 2 + 3, vaseTopY + 3);
    hlPath.cubicTo(
      cx - bodyW / 2 + 7, vaseTopY + vaseH * 0.35,
      cx - bodyW / 2 + 9, vaseTopY + vaseH * 0.6,
      cx - bottomW / 2 + 5, vaseBottomY - 4,
    );
    hlPath.lineTo(cx - bottomW / 2 + 8, vaseBottomY - 4);
    hlPath.cubicTo(
      cx - bodyW / 2 + 12, vaseTopY + vaseH * 0.6,
      cx - bodyW / 2 + 10, vaseTopY + vaseH * 0.35,
      cx - openW / 2 + 6, vaseTopY + 3,
    );
    hlPath.close();
    canvas.drawPath(
      hlPath,
      Paint()..color = Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawStems(
      Canvas canvas, double w, double h, double cx, double vaseTopY) {
    List<_Stem> stems;
    Color stemColor;
    Color leafColor;
    List<Color> flowerColors;
    double petalRadius;
    int petalCount;
    bool showLeaves;
    bool showPetals;

    switch (state) {
      case VaseState.empty:
        return;

      case VaseState.dried:
        stems = [
          _Stem(Offset(cx - 6, vaseTopY), Offset(cx - 18, vaseTopY - 18),
              Offset(cx - 22, vaseTopY - 8)),
          _Stem(Offset(cx, vaseTopY), Offset(cx + 2, vaseTopY - 28),
              Offset(cx + 4, vaseTopY - 22)),
          _Stem(Offset(cx + 6, vaseTopY), Offset(cx + 16, vaseTopY - 16),
              Offset(cx + 24, vaseTopY - 6)),
        ];
        stemColor =
            isDark ? const Color(0xFF7A6B55) : const Color(0xFF8B7355);
        leafColor = Colors.transparent;
        flowerColors = [
          const Color(0xFF6B5A42),
          const Color(0xFF7A6950),
          const Color(0xFF5C4A35),
        ];
        petalRadius = 0;
        petalCount = 0;
        showLeaves = false;
        showPetals = false;
        break;

      case VaseState.wilting:
        stems = [
          _Stem(Offset(cx - 6, vaseTopY), Offset(cx - 14, vaseTopY - 26),
              Offset(cx - 16, vaseTopY - 18)),
          _Stem(Offset(cx, vaseTopY), Offset(cx + 1, vaseTopY - 34),
              Offset(cx + 2, vaseTopY - 28)),
          _Stem(Offset(cx + 6, vaseTopY), Offset(cx + 12, vaseTopY - 24),
              Offset(cx + 18, vaseTopY - 16)),
        ];
        stemColor =
            isDark ? const Color(0xFF8A8550) : const Color(0xFF9A9060);
        leafColor =
            isDark ? const Color(0xFF7A7A40) : const Color(0xFFB0A860);
        flowerColors = [
          const Color(0xFFD4A840),
          const Color(0xFFC49838),
          const Color(0xFFD4B050),
        ];
        petalRadius = 3.0;
        petalCount = 4;
        showLeaves = true;
        showPetals = true;
        break;

      case VaseState.alive:
        stems = [
          _Stem(Offset(cx - 7, vaseTopY), Offset(cx - 12, vaseTopY - 30),
              Offset(cx - 14, vaseTopY - 38)),
          _Stem(Offset(cx, vaseTopY), Offset(cx, vaseTopY - 36),
              Offset(cx, vaseTopY - 42)),
          _Stem(Offset(cx + 7, vaseTopY), Offset(cx + 10, vaseTopY - 28),
              Offset(cx + 16, vaseTopY - 36)),
        ];
        stemColor =
            isDark ? const Color(0xFF4A8A4A) : const Color(0xFF5A9A5A);
        leafColor =
            isDark ? const Color(0xFF3A7A3A) : const Color(0xFF6AAA5A);
        flowerColors = [
          const Color(0xFFD07090),
          const Color(0xFFB060A0),
          const Color(0xFFC06888),
        ];
        petalRadius = 3.8;
        petalCount = 5;
        showLeaves = true;
        showPetals = true;
        break;

      case VaseState.fresh:
        stems = [
          _Stem(Offset(cx - 8, vaseTopY), Offset(cx - 16, vaseTopY - 32),
              Offset(cx - 18, vaseTopY - 42)),
          _Stem(Offset(cx - 2, vaseTopY), Offset(cx - 3, vaseTopY - 38),
              Offset(cx - 2, vaseTopY - 46)),
          _Stem(Offset(cx + 4, vaseTopY), Offset(cx + 5, vaseTopY - 36),
              Offset(cx + 6, vaseTopY - 44)),
          _Stem(Offset(cx + 9, vaseTopY), Offset(cx + 16, vaseTopY - 30),
              Offset(cx + 20, vaseTopY - 40)),
        ];
        stemColor =
            isDark ? const Color(0xFF3A9A3A) : const Color(0xFF4AAA4A);
        leafColor =
            isDark ? const Color(0xFF2A8A2A) : const Color(0xFF5ABA4A);
        flowerColors = [
          const Color(0xFFE06090),
          const Color(0xFFA050C0),
          const Color(0xFFD07098),
          const Color(0xFF7070D0),
        ];
        petalRadius = 4.5;
        petalCount = 5;
        showLeaves = true;
        showPetals = true;
        break;
    }

    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < stems.length; i++) {
      final s = stems[i];

      final stemPath = Path()
        ..moveTo(s.base.dx, s.base.dy)
        ..quadraticBezierTo(s.control.dx, s.control.dy, s.tip.dx, s.tip.dy);
      canvas.drawPath(stemPath, stemPaint);

      if (showLeaves && i < 3) {
        final t = 0.4;
        final lx = _bezierPoint(s.base.dx, s.control.dx, s.tip.dx, t);
        final ly = _bezierPoint(s.base.dy, s.control.dy, s.tip.dy, t);
        final side = (i % 2 == 0) ? 1.0 : -1.0;
        _drawLeaf(canvas, lx, ly, side * 35, leafColor, 7);
      }

      if (showPetals) {
        _drawFlower(canvas, s.tip.dx, s.tip.dy, petalRadius, petalCount,
            flowerColors[i % flowerColors.length]);
      } else {
        canvas.drawCircle(
          s.tip,
          2.5,
          Paint()..color = flowerColors[i % flowerColors.length],
        );
      }
    }
  }

  double _bezierPoint(double p0, double p1, double p2, double t) {
    final mt = 1 - t;
    return mt * mt * p0 + 2 * mt * t * p1 + t * t * p2;
  }

  void _drawFlower(Canvas canvas, double x, double y, double radius,
      int petals, Color color) {
    final petalPaint = Paint()..color = color;
    final centerColor = Color.lerp(color, const Color(0xFFFFF8DC), 0.45)!;
    final centerPaint = Paint()..color = centerColor;

    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi / petals) - math.pi / 2;
      final px = x + radius * 0.9 * math.cos(angle);
      final py = y + radius * 0.9 * math.sin(angle);
      canvas.drawCircle(Offset(px, py), radius * 0.55, petalPaint);
    }

    canvas.drawCircle(Offset(x, y), radius * 0.38, centerPaint);
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angleDeg,
      Color color, double length) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angleDeg * math.pi / 180);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(length * 0.3, -length * 0.18, length * 0.7, -length * 0.18,
          length, 0)
      ..cubicTo(
          length * 0.7, length * 0.18, length * 0.3, length * 0.18, 0, 0);
    canvas.drawPath(leafPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VasePainter old) {
    return old.state != state || old.isDark != isDark;
  }
}
