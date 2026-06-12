import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import 'analysis_mode.dart';
import 'database_service.dart';
import 'gemini_service.dart';
import 'local_llm_service.dart';

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
  /// throttles itself to `_minIntervalMinutes`. [force] skips the throttle
  /// (used right after the local model finishes downloading).
  static Future<void> tryRun({bool force = false}) async {
    if (_running) return;
    _running = true;
    try {
      await _run(force: force);
    } catch (e) {
      debugPrint('Reanalysis error: $e');
    } finally {
      _running = false;
    }
  }

  static Future<void> _run({bool force = false}) async {
    // Only meaningful when an AI analyzer (cloud or on-device) is active.
    final mode = await AnalysisModeStore.load();
    if (mode != AnalysisMode.ai && mode != AnalysisMode.local) return;

    final useLocal = mode == AnalysisMode.local;
    if (useLocal) {
      if (!await LocalLlmService.isModelReady()) return;
    } else {
      final cfg = await ApiConfig.load();
      if (!cfg.isConfigured) return;
    }

    // Throttle. The on-device model is free — sweep far more often than
    // the paid cloud API.
    final throttleMinutes = useLocal ? 5 : _minIntervalMinutes;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastRunKey) ?? 0;
    final now = DateTime.now();
    final elapsed = now.millisecondsSinceEpoch - lastMs;
    if (!force && elapsed < throttleMinutes * 60 * 1000) {
      debugPrint('Reanalysis: throttled');
      return;
    }
    await prefs.setInt(_lastRunKey, now.millisecondsSinceEpoch);

    // Find candidate entries analyzed offline. The cloud analyzer keeps a
    // recency window (paid API calls); the on-device model is free, so it
    // works through the whole archive batch by batch.
    final all = await DatabaseService.loadEntries();
    final cutoff = now.subtract(const Duration(days: _lookbackDays));
    final candidates = all.where((e) {
      if (e.text.trim().isEmpty) return false;
      if (!useLocal && !e.date.isAfter(cutoff)) return false;
      final a = e.analysis;
      if (a == null) return true;
      return a.source != AnalysisSource.ai &&
          a.source != AnalysisSource.local;
    }).take(useLocal ? 10 : _maxPerRun).toList();

    if (candidates.isEmpty) {
      debugPrint('Reanalysis: nothing to do');
      return;
    }
    debugPrint('Reanalysis: ${candidates.length} candidate(s)');

    int updated = 0;
    int failures = 0;
    for (final entry in candidates) {
      // A freshly saved entry is waiting — step aside, the sweep will
      // continue on the next run.
      if (useLocal && LocalLlmService.hasPriorityWaiting) {
        debugPrint('Reanalysis: yielding to a fresh entry');
        break;
      }
      MoodAnalysis? aiResult;
      try {
        aiResult = useLocal
            ? await LocalLlmService.analyze(entry.text)
            : await GeminiService.analyze(entry.text, '');
      } catch (e) {
        debugPrint('Reanalysis: analyzer failed ($e)');
        aiResult = null;
      }
      if (aiResult == null) {
        if (!useLocal) {
          // Cloud: network is probably down — retry the batch later.
          debugPrint('Reanalysis: API unavailable, aborting batch');
          return;
        }
        // Local: one garbled answer must not kill the whole batch.
        failures++;
        debugPrint('Reanalysis: skipped ${entry.id} (failure $failures)');
        if (failures >= 2) break;
        continue;
      }

      final marked = aiResult.copyWith(
          source: useLocal ? AnalysisSource.local : AnalysisSource.ai);
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
