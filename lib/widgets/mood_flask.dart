import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';

/// Компактная визуализация последних N записей в виде химической колбы.
///
/// Каждая запись = один горизонтальный слой жидкости. Старые записи
/// внизу, свежие — сверху. Цвет слоя зависит от score настроения:
/// приглушённая палитра без "светофорного" эффекта. Мы не хотим,
/// чтобы красный цвет воспринимался как "неправильно". Это просто
/// честный срез состояния за последние N записей.
///
/// При добавлении новой записи верхний слой "наливается" — плавно
/// растёт из нуля до полной высоты.
///
/// Это статичная визуализация — тап ничего не делает. Деталировка
/// живёт на отдельном экране отчётов.
class MoodFlask extends StatefulWidget {
  /// Список записей в порядке от самой свежей к самой старой
  /// (как они хранятся в home_screen в `_entries`).
  final List<DiaryEntry> entries;

  /// Максимальное число слоёв в колбе.
  final int capacity;

  const MoodFlask({
    super.key,
    required this.entries,
    this.capacity = 10,
  });

  @override
  State<MoodFlask> createState() => _MoodFlaskState();
}

class _MoodFlaskState extends State<MoodFlask>
    with SingleTickerProviderStateMixin {
  late AnimationController _pourCtrl;
  late Animation<double> _pour;
  int _lastShownCount = 0;

  @override
  void initState() {
    super.initState();
    _pourCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pour = CurvedAnimation(parent: _pourCtrl, curve: Curves.easeOutCubic);
    _lastShownCount = widget.entries.length.clamp(0, widget.capacity);
    // Колба уже "налита" при первом показе — без анимации.
    _pourCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant MoodFlask oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCount = widget.entries.length.clamp(0, widget.capacity);
    // ВАЖНО: сравниваем с сохранённым _lastShownCount, а не с oldWidget.
    // В home_screen список мутируется на месте (_entries.insert(0, ...)),
    // так что oldWidget.entries и widget.entries — один и тот же объект
    // с уже обновлённой длиной.
    if (newCount > _lastShownCount) {
      _lastShownCount = newCount;
      _pourCtrl
        ..reset()
        ..forward();
    } else if (newCount < _lastShownCount) {
      // Запись удалили — показываем статично.
      _lastShownCount = newCount;
      _pourCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pourCtrl.dispose();
    super.dispose();
  }

  /// Берём последние N записей в хронологическом порядке:
  /// индекс 0 — самая старая (пойдёт на дно), индекс N-1 — самая свежая
  /// (пойдёт наверх). В `widget.entries` наоборот — [0] свежая, поэтому
  /// разворачиваем.
  List<int> _layerScores() {
    final count = widget.entries.length.clamp(0, widget.capacity);
    final scores = <int>[];
    for (int i = count - 1; i >= 0; i--) {
      final e = widget.entries[i];
      final s = e.analysis?.score ?? 5;
      scores.add(s.clamp(1, 10));
    }
    return scores;
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final scores = _layerScores();
    final filled = scores.length;

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
          // Колба
          SizedBox(
            width: 72,
            height: 108,
            child: AnimatedBuilder(
              animation: _pour,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FlaskPainter(
                    scores: scores,
                    capacity: widget.capacity,
                    pourProgress: _pour.value,
                    glassColor: t.textHint.withValues(alpha: 0.35),
                    isDark: t.brightness == Brightness.dark,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Текст справа
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Твоё состояние',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  filled == 0
                      ? 'Колба пока пуста. Первая запись —\nпервый слой.'
                      : 'Последние $filled из ${widget.capacity} записей.\nСвежие — сверху.',
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

/// Рисует колбу с цветными слоями.
///
/// Форма: узкое горлышко сверху + круглое тело снизу. Слои — горизонтальные
/// полосы, обрезанные по внутреннему контуру колбы (так они принимают
/// форму тела — уже к горлышку, шире к дну).
class _FlaskPainter extends CustomPainter {
  /// Список score от дна (индекс 0) к верху (индекс N-1).
  final List<int> scores;
  final int capacity;

  /// 0..1 — прогресс анимации налива верхнего слоя.
  final double pourProgress;

  final Color glassColor;
  final bool isDark;

  _FlaskPainter({
    required this.scores,
    required this.capacity,
    required this.pourProgress,
    required this.glassColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Геометрия колбы.
    // Всё в пропорциях от размера, чтобы масштабировалось.
    final neckWidth = w * 0.28;
    final neckHeight = h * 0.22;
    final bodyTopY = neckHeight;
    final bodyHeight = h - neckHeight;
    final bodyCenterX = w / 2;

    // Внутренний контур колбы (клип для жидкости).
    final insidePath = Path();
    // Верх горлышка — чуть ниже самой кромки, чтобы был "ободок" стекла
    final neckInset = 2.0;
    insidePath.moveTo(bodyCenterX - neckWidth / 2 + neckInset, neckInset);
    insidePath.lineTo(bodyCenterX + neckWidth / 2 - neckInset, neckInset);
    insidePath.lineTo(bodyCenterX + neckWidth / 2 - neckInset, bodyTopY);
    // Плечи колбы — плавный переход от горлышка к телу
    insidePath.cubicTo(
      bodyCenterX + w * 0.48,
      bodyTopY + bodyHeight * 0.15,
      bodyCenterX + w * 0.48,
      bodyTopY + bodyHeight * 0.6,
      bodyCenterX + w * 0.35,
      bodyTopY + bodyHeight * 0.92,
    );
    // Дно — дуга
    insidePath.arcToPoint(
      Offset(bodyCenterX - w * 0.35, bodyTopY + bodyHeight * 0.92),
      radius: Radius.circular(w * 0.45),
      clockwise: false,
    );
    // Левое плечо вверх к горлышку
    insidePath.cubicTo(
      bodyCenterX - w * 0.48,
      bodyTopY + bodyHeight * 0.6,
      bodyCenterX - w * 0.48,
      bodyTopY + bodyHeight * 0.15,
      bodyCenterX - neckWidth / 2 + neckInset,
      bodyTopY,
    );
    insidePath.close();

    // Область, которую занимает жидкость — только тело колбы,
    // горлышко оставляем пустым (так визуально честнее: "неполное"
    // состояние видно сразу).
    final liquidTopY = bodyTopY + 2;
    final liquidBottomY = bodyTopY + bodyHeight * 0.96;
    final liquidHeight = liquidBottomY - liquidTopY;

    // Высота одного слоя
    final layerHeight = liquidHeight / capacity;

    canvas.save();
    canvas.clipPath(insidePath);

    // Фон жидкости — едва заметный, чтобы пустая колба не выглядела
    // полностью прозрачной.
    final bgPaint = Paint()
      ..color = glassColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, 0, w, h), bgPaint);

    // Рисуем слои снизу вверх.
    for (int i = 0; i < scores.length; i++) {
      final isTopLayer = (i == scores.length - 1);
      // Целевая высота слоя
      final targetH = layerHeight;
      // Эффективная высота с учётом анимации (только для верхнего)
      final effH = isTopLayer ? targetH * pourProgress : targetH;

      // Y-координата верха и низа этого слоя.
      // Нижний слой (i=0) лежит у дна. Слой i занимает полосу:
      // bottom = liquidBottomY - i * layerHeight
      // top    = bottom - layerHeight
      final layerBottom = liquidBottomY - i * targetH;
      final layerTop = layerBottom - effH;

      final color = _colorForScore(scores[i]);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(0, layerTop, w, layerBottom),
        paint,
      );

      // Мягкая граница между слоями — тонкая тёмная линия сверху слоя
      if (i > 0 || isTopLayer) {
        final edgePaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        canvas.drawLine(
          Offset(0, layerBottom - targetH),
          Offset(w, layerBottom - targetH),
          edgePaint,
        );
      }
    }

    // Блик слева сверху — добавляет ощущение стекла
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.08 : 0.18)
      ..style = PaintingStyle.fill;
    final highlightPath = Path();
    highlightPath.moveTo(bodyCenterX - w * 0.28, bodyTopY + bodyHeight * 0.25);
    highlightPath.quadraticBezierTo(
      bodyCenterX - w * 0.42,
      bodyTopY + bodyHeight * 0.55,
      bodyCenterX - w * 0.30,
      bodyTopY + bodyHeight * 0.82,
    );
    highlightPath.lineTo(bodyCenterX - w * 0.24, bodyTopY + bodyHeight * 0.8);
    highlightPath.quadraticBezierTo(
      bodyCenterX - w * 0.35,
      bodyTopY + bodyHeight * 0.55,
      bodyCenterX - w * 0.22,
      bodyTopY + bodyHeight * 0.27,
    );
    highlightPath.close();
    canvas.drawPath(highlightPath, highlightPaint);

    canvas.restore();

    // Обводка стекла поверх — чтобы был чёткий край колбы.
    final glassPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(insidePath, glassPaint);

    // Ободок горлышка — короткая горизонтальная риска
    final rimPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bodyCenterX - neckWidth / 2 - 2, 1),
      Offset(bodyCenterX + neckWidth / 2 + 2, 1),
      rimPaint,
    );
  }

  /// Приглушённая палитра. Без яркого красного и зелёного —
  /// это не светофор, это честный срез состояния.
  Color _colorForScore(int score) {
    switch (score) {
      case 1:
        return const Color(0xFF6E2A2A); // глубокий бордовый
      case 2:
        return const Color(0xFF8B3838);
      case 3:
        return const Color(0xFFA85232); // терракота
      case 4:
        return const Color(0xFFC2743A);
      case 5:
        return const Color(0xFFB8994A); // приглушённая охра
      case 6:
        return const Color(0xFF9AA257); // олива
      case 7:
        return const Color(0xFF7A9C5E);
      case 8:
        return const Color(0xFF5E9373);
      case 9:
        return const Color(0xFF488C7C);
      case 10:
        return const Color(0xFF3C8A86); // мягкий teal
      default:
        return const Color(0xFFB8994A);
    }
  }

  @override
  bool shouldRepaint(covariant _FlaskPainter old) {
    return old.pourProgress != pourProgress ||
        old.scores.length != scores.length ||
        !_listEq(old.scores, scores);
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
