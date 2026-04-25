import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import 'analysis_mode.dart';
import 'database_service.dart';
import 'gemini_service.dart';

/// Re-runs AI analysis for entries that were originally analyzed offline
/// (lexicon or fast). Triggered on app resume — if the AI is unreachable
/// the attempt silently fails and we try again next time.
///
/// Quiet by design: no UI, no notifications. The user only sees the
/// updated score the next time they open the entry.
class ReanalysisService {
  static const _lastRunKey = 'reanalysis_last_run_ms';
  static const _minIntervalMinutes = 30;
  static const _lookbackDays = 7;
  static const _scoreDeltaThreshold = 2;
  static const _maxPerRun = 5;

  static bool _running = false;

  /// Runs in the background. Safe to call repeatedly — internally
  /// throttles itself to `_minIntervalMinutes`.
  static Future<void> tryRun() async {
    if (_running) return;
    _running = true;
    try {
      await _run();
    } catch (e) {
      debugPrint('Reanalysis error: $e');
    } finally {
      _running = false;
    }
  }

  static Future<void> _run() async {
    // Only meaningful when the user has AI mode enabled and configured.
    final mode = await AnalysisModeStore.load();
    if (mode != AnalysisMode.ai) return;

    final cfg = await ApiConfig.load();
    if (!cfg.isConfigured) return;

    // Throttle.
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastRunKey) ?? 0;
    final now = DateTime.now();
    final elapsed = now.millisecondsSinceEpoch - lastMs;
    if (elapsed < _minIntervalMinutes * 60 * 1000) {
      debugPrint('Reanalysis: throttled');
      return;
    }
    await prefs.setInt(_lastRunKey, now.millisecondsSinceEpoch);

    // Find candidate entries: from last N days, source != ai, has text.
    final all = await DatabaseService.loadEntries();
    final cutoff = now.subtract(const Duration(days: _lookbackDays));
    final candidates = all.where((e) {
      if (e.text.trim().isEmpty) return false;
      if (!e.date.isAfter(cutoff)) return false;
      final a = e.analysis;
      if (a == null) return true;
      return a.source != AnalysisSource.ai;
    }).take(_maxPerRun).toList();

    if (candidates.isEmpty) {
      debugPrint('Reanalysis: nothing to do');
      return;
    }
    debugPrint('Reanalysis: ${candidates.length} candidate(s)');

    int updated = 0;
    for (final entry in candidates) {
      MoodAnalysis? aiResult;
      try {
        aiResult = await GeminiService.analyze(entry.text, '');
      } catch (e) {
        debugPrint('Reanalysis: API failed ($e), aborting batch');
        return; // network or API down — try again later
      }
      if (aiResult == null) {
        debugPrint('Reanalysis: API returned null, aborting batch');
        return;
      }

      final marked = aiResult.copyWith(source: AnalysisSource.ai);
      final old = entry.analysis;
      final delta = old == null ? 999 : (marked.score - old.score).abs();

      if (delta >= _scoreDeltaThreshold) {
        await DatabaseService.updateEntry(
          entry.copyWith(analysis: marked, mood: marked.emoji),
        );
        updated++;
        debugPrint(
            'Reanalysis: ${entry.id} score ${old?.score} -> ${marked.score}');
      } else {
        // Still mark as ai-sourced so we don't keep re-checking it.
        await DatabaseService.updateEntry(
          entry.copyWith(analysis: marked),
        );
        debugPrint(
            'Reanalysis: ${entry.id} no significant change (delta $delta)');
      }
    }
    debugPrint('Reanalysis: done, $updated entries updated');
  }
}
