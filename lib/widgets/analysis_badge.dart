import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';

/// Small chip on an entry's preview showing who produced the analysis:
/// 📖 dictionary, 🧠 AI, ✍️ manual. When [pending] is true (an AI pass is
/// queued/running for a still-dictionary entry) it shows a pulsing
/// "анализ ИИ…" so the quick dictionary result isn't mistaken for the net.
class AnalysisBadge extends StatefulWidget {
  final AnalysisSource? source;
  final bool pending;
  const AnalysisBadge({super.key, required this.source, this.pending = false});

  @override
  State<AnalysisBadge> createState() => _AnalysisBadgeState();
}

class _AnalysisBadgeState extends State<AnalysisBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pending) _startPulse();
  }

  @override
  void didUpdateWidget(AnalysisBadge old) {
    super.didUpdateWidget(old);
    if (widget.pending && _pulse == null) _startPulse();
    if (!widget.pending && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  void _startPulse() {
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    if (widget.pending) {
      final chip = _chip(t, '🧠', 'анализ ИИ…', t.primary);
      return FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(
          CurvedAnimation(parent: _pulse!, curve: Curves.easeInOut),
        ),
        child: chip,
      );
    }

    final (emoji, label) = switch (widget.source) {
      AnalysisSource.local || AnalysisSource.ai => ('🧠', 'ИИ'),
      AnalysisSource.manual => ('✍️', 'Вручную'),
      AnalysisSource.fast || AnalysisSource.lexicon => ('📖', 'Словарь'),
      null => ('', ''),
    };
    if (emoji.isEmpty) return const SizedBox.shrink();
    return _chip(t, emoji, label, t.textHint);
  }

  Widget _chip(dynamic t, String emoji, String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (tint as Color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
