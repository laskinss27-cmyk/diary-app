import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';
import '../screens/entry_detail_screen.dart';
import 'mood_badge.dart';

/// Collapsible "Сегодня / Вчера / Ранее" group.
/// Collapsed by default — privacy: nothing of the entry's content is visible
/// from the main screen until explicitly tapped.
class EntrySection extends StatefulWidget {
  final String title;
  final List<DiaryEntry> entries;
  final void Function(String id) onDelete;

  const EntrySection({
    super.key,
    required this.title,
    required this.entries,
    required this.onDelete,
  });

  @override
  State<EntrySection> createState() => _EntrySectionState();
}

class _EntrySectionState extends State<EntrySection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final count = widget.entries.length;

    final isDark = t.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.white)
              .withValues(alpha: isDark ? 0.08 : 0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.white)
                .withValues(alpha: isDark ? 0.12 : 0.55),
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
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: t.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    color: t.textHint.withValues(alpha: 0.15),
                    indent: 16,
                    endIndent: 16,
                  ),
                  ...widget.entries.map((e) => _entryRow(context, t, e)),
                  const SizedBox(height: 8),
                ],
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
        ),
        ),
    );
  }

  Widget _entryRow(BuildContext context, t, DiaryEntry e) {
    final score = e.analysis?.score ?? 5;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EntryDetailScreen(
            entry: e,
            onDelete: () => widget.onDelete(e.id),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MoodBadge(score: score, size: 36),
            const SizedBox(width: 14),
            Text(
              _formatTime(e.date),
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: t.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final isToday = _isSameDay(d, DateTime.now());
    if (isToday) {
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${d.day} ${months[d.month]}, '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
