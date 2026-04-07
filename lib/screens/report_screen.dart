import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/diary_entry.dart';
import '../services/storage_service.dart';
import '../widgets/disclaimer_dialog.dart';

class ReportScreen extends StatelessWidget {
  final List<DiaryEntry> entries;

  const ReportScreen({super.key, required this.entries});

  List<DiaryEntry> get _weekEntries {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return entries.where((e) => e.date.isAfter(weekAgo)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final week = _weekEntries;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Отчёт за неделю',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: week.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📊', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Нет записей за последнюю неделю',
                    style: TextStyle(color: t.textHint, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMoodChart(week, t),
                  const SizedBox(height: 16),
                  _buildStats(week, t),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed =
                            await DisclaimerDialog.showBeforeShare(context);
                        if (confirmed) _share(week, weekAgo, now);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Поделиться отчётом'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMoodChart(List<DiaryEntry> week, t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'График настроения',
            style: TextStyle(
              color: t.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _MoodChart(entries: week, primary: t.primary, accent: t.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(List<DiaryEntry> week, t) {
    final avgScore = week
            .where((e) => e.analysis != null)
            .fold<int>(0, (sum, e) => sum + e.analysis!.score) /
        (week.where((e) => e.analysis != null).length.clamp(1, 9999));

    final moodCounts = <String, int>{};
    for (final e in week) {
      moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1;
    }
    final topMood = moodCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _statRow('Записей за неделю', '${week.length}', t),
          const Divider(height: 20),
          _statRow('Среднее настроение',
              '${avgScore.toStringAsFixed(1)}/10', t),
          const Divider(height: 20),
          _statRow('Преобладающее настроение',
              '${topMood.key} (${topMood.value} раз)', t),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: t.textHint, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
      ],
    );
  }

  Future<void> _share(List<DiaryEntry> week, DateTime from, DateTime to) async {
    final profile = await StorageService.loadProfile();
    final avgScore = week
            .where((e) => e.analysis != null)
            .fold<int>(0, (sum, e) => sum + e.analysis!.score) /
        (week.where((e) => e.analysis != null).length.clamp(1, 9999));

    final moodCounts = <String, int>{};
    for (final e in week) {
      moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1;
    }
    final topMood = moodCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);

    final scores = week
        .where((e) => e.analysis != null)
        .map((e) => e.analysis!.score)
        .toList();
    String dynamics = 'Недостаточно данных';
    if (scores.length >= 2) {
      final first = scores.take((scores.length / 2).ceil()).fold<int>(0, (a, b) => a + b) /
          (scores.length / 2).ceil();
      final second = scores.skip((scores.length / 2).ceil()).fold<int>(0, (a, b) => a + b) /
          scores.skip((scores.length / 2).ceil()).length;
      if (second > first + 0.5) {
        dynamics = 'Настроение улучшилось к концу недели';
      } else if (first > second + 0.5) {
        dynamics = 'Настроение ухудшилось к концу недели';
      } else {
        dynamics = 'Настроение стабильное в течение недели';
      }
    }

    final buf = StringBuffer();
    buf.writeln('🌸 Отчёт за неделю ${_fmtShort(from)}–${_fmtShort(to)}');

    final name = profile['name'] ?? '';
    final age = profile['age'] ?? '';
    final note = profile['note'] ?? '';
    if (name.isNotEmpty) {
      buf.write('Пациент: $name');
      if (age.isNotEmpty) buf.write(', $age лет');
      buf.writeln();
    }
    if (note.isNotEmpty) {
      buf.writeln('Заметка: $note');
    }
    buf.writeln();
    buf.writeln('Записей: ${week.length}');
    buf.writeln('Среднее настроение: ${avgScore.toStringAsFixed(1)}/10');
    buf.writeln('Преобладающее состояние: ${topMood.key} (${topMood.value} раз)');
    buf.writeln('Динамика: $dynamics');
    buf.writeln();

    for (final e in week) {
      buf.writeln('${e.mood} ${_fmtShort(e.date)}');
      if (e.analysis != null) {
        buf.writeln('  ${e.analysis!.score}/10 — ${e.analysis!.brief}');
        buf.writeln('  ${e.analysis!.keywords.join(', ')}');
      }
      buf.writeln();
    }

    Share.share(buf.toString());
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

class _MoodChart extends StatelessWidget {
  final List<DiaryEntry> entries;
  final Color primary;
  final Color accent;

  const _MoodChart({required this.entries, required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final padding = 30.0;
        final chartW = w - padding * 2;
        final chartH = h - padding * 2;

        final points = <_ChartPoint>[];
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];
          final score = e.analysis?.score ?? 5;
          final x = padding +
              (entries.length == 1
                  ? chartW / 2
                  : (i / (entries.length - 1)) * chartW);
          final y = padding + chartH - (score / 10.0) * chartH;
          points.add(_ChartPoint(x, y, score, e.mood, e.date));
        }

        return CustomPaint(
          size: Size(w, h),
          painter: _ChartPainter(points, padding, chartW, chartH, primary, accent),
          child: Stack(
            children: points
                .map((p) => Positioned(
                      left: p.x - 14,
                      top: p.y - 28,
                      child: Tooltip(
                        message:
                            '${p.date.day}.${p.date.month} — ${p.score}/10',
                        child: Text(p.emoji,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ChartPoint {
  final double x, y;
  final int score;
  final String emoji;
  final DateTime date;
  _ChartPoint(this.x, this.y, this.score, this.emoji, this.date);
}

class _ChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final double padding, chartW, chartH;
  final Color primary;
  final Color accent;

  _ChartPainter(this.points, this.padding, this.chartW, this.chartH, this.primary, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = primary.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (var i = 0; i <= 10; i += 2) {
      final y = padding + chartH - (i / 10.0) * chartH;
      canvas.drawLine(
          Offset(padding, y), Offset(padding + chartW, y), gridPaint);
    }

    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(points[0].x, points[0].y);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = accent;
    for (final p in points) {
      canvas.drawCircle(Offset(p.x, p.y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
