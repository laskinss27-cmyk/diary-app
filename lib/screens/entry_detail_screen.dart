import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';
import '../widgets/frosted_background.dart';
import '../widgets/mood_badge.dart';

/// Read-only full-screen view of a diary entry.
class EntryDetailScreen extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback? onDelete;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final score = entry.analysis?.score ?? 5;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: t.textHint),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: FrostedBackground(
        theme: t,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Row(
                children: [
                  MoodBadge(score: score, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(entry.date),
                          style: TextStyle(
                            color: t.textHint,
                            fontSize: 12,
                          ),
                        ),
                        if (entry.analysis != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.analysis!.brief,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SelectableText(
                entry.text,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
              if (entry.photoPaths.isNotEmpty) ...[
                const SizedBox(height: 20),
                _photoStrip(context, entry),
              ],
              if (entry.analysis != null &&
                  entry.analysis!.keywords.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: entry.analysis!.keywords
                      .map((k) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: t.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: t.primary.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: 12,
                                color: t.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStrip(BuildContext context, DiaryEntry e) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: e.photoPaths.length,
        itemBuilder: (ctx, i) {
          final f = File(e.photoPaths[i]);
          if (!f.existsSync()) return const SizedBox();
          return GestureDetector(
            onTap: () => _showPhoto(context, e.photoPaths[i]),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  f,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPhoto(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(path))),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить запись?'),
        content: const Text('Эта запись будет удалена навсегда.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE94560),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
