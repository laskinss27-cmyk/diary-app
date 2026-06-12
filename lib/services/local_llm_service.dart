import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/domain/model_source.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';
import 'database_service.dart';
import 'secrets.dart';

/// On-device mood analysis via Gemma 3n (MediaPipe LLM Inference).
///
/// The model (~2.9 GB) is downloaded by our own downloader: honest
/// progress, resume from the exact byte after a dropped connection, and a
/// stall watchdog (the plugin's downloader silently hangs on connection
/// loss and restarts from zero — both reported by Sergey, 2026-06-12).
/// The finished file is then registered with the plugin in place, no copy.
/// Models already downloaded through the plugin keep working as-is.
class LocalLlmService {
  static const modelFileName = 'gemma-3n-E2B-it-int4.task';

  static const defaultModelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';

  static const _hfTokenKey = 'hf_token';
  static const _totalBytesKey = 'gemma_model_total_bytes';
  static const _gpuKey = 'llm_use_gpu';

  /// A file below this size is clearly not the real model.
  static const _minValidBytes = 2500 * 1024 * 1024;

  /// Abort the download if no bytes arrive for this long.
  static const _stallTimeout = Duration(seconds: 30);

  // Compact prompt — same JSON contract as the cloud analyzer, trimmed for
  // a small on-device model. Keywords capped at 3 and brief kept short to
  // cut decode time on slow phone CPUs.
  static const _prompt = '''
Ты — тёплый внимательный помощник в личном дневнике. Определи эмоциональное состояние в записи: контекст, скрытые эмоции, тревогу, радость, грусть, злость.

Ответь ТОЛЬКО JSON без пояснений и без markdown:
{"emoji":"одно эмодзи","score":число_от_1_до_10,"keywords":["3 слова"],"brief":"одно короткое тёплое предложение"}

Правила для brief:
- простые слова, как сказал бы близкий друг
- БЕЗ обращений (никаких «ты», «вы») и БЕЗ слов «автор», «пользователь»
- безличные формулировки, не угадывай род: «усталость», «чувствуется», «впереди отдых»
- никакого канцелярита и сухих диагнозов

Примеры brief:
«Тяжёлая неделя позади, впереди отдых — и от этого легче»
«Усталость пополам с облегчением: можно наконец выдохнуть»
«Тревожный день, многое навалилось разом»

Запись:
''';

  static InferenceModel? _model;
  static bool _initFailed = false;

  // ---------------------------------------------------------------- token

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_hfTokenKey);
    if (t != null && t.trim().isNotEmpty) return t.trim();
    // Built-in token from the gitignored secrets file (test builds).
    if (Secrets.defaultHfToken.isNotEmpty) return Secrets.defaultHfToken;
    return null;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hfTokenKey, token.trim());
  }

  static Future<bool> useGpu() async {
    final prefs = await SharedPreferences.getInstance();
    // Default CPU: GPU inference froze the whole phone on Mali-G57
    // (Redmi Note 11S, 2026-06-13). Opt-in only.
    return prefs.getBool(_gpuKey) ?? false;
  }

  static Future<void> setUseGpu(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpuKey, value);
    // Reload the model with the new backend on next analysis.
    await dispose();
    _initFailed = false;
  }

  // ---------------------------------------------------------------- specs

  static Future<String> _ownFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$modelFileName';
  }

  static Future<InferenceModelSpec> _fileSpec() async => InferenceModelSpec(
        name: 'gemma-3n-e2b',
        modelSource: ModelSource.file(await _ownFilePath()),
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      );

  /// Legacy spec — models downloaded through the plugin's own manager
  /// (first test builds). Kept so an already-downloaded model survives.
  static Future<InferenceModelSpec> _networkSpec() async =>
      InferenceModelSpec(
        name: 'gemma-3n-e2b',
        modelSource:
            ModelSource.network(defaultModelUrl, authToken: await loadToken()),
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      );

  // --------------------------------------------------------------- status

  static Future<bool> _ownFileComplete() async {
    try {
      final f = File(await _ownFilePath());
      if (!f.existsSync()) return false;
      final len = f.lengthSync();
      if (len < _minValidBytes) return false;
      final prefs = await SharedPreferences.getInstance();
      final total = prefs.getInt(_totalBytesKey) ?? 0;
      // If we know the exact size, demand it; otherwise the floor is enough.
      return total == 0 || len >= total;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _pluginInstalled() async {
    try {
      final manager = FlutterGemmaPlugin.instance.modelManager;
      return await manager.isModelInstalled(await _networkSpec());
    } catch (e) {
      debugPrint('Local LLM plugin-install check error: $e');
      return false;
    }
  }

  static Future<bool> isModelReady() async =>
      await _ownFileComplete() || await _pluginInstalled();

  // ------------------------------------------------------------- download

  /// Streaming download with byte-exact resume and a stall watchdog.
  /// Returns null on success, otherwise a short human-readable error.
  static Future<String?> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (await isModelReady()) return null;

    final targetPath = await _ownFilePath();
    final partFile = File('$targetPath.part');
    final token = await loadToken();
    final prefs = await SharedPreferences.getInstance();

    final client = http.Client();
    try {
      final existing = partFile.existsSync() ? partFile.lengthSync() : 0;
      final req = http.Request('GET', Uri.parse(defaultModelUrl));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (existing > 0) req.headers['Range'] = 'bytes=$existing-';

      final res = await client.send(req).timeout(_stallTimeout);
      if (res.statusCode == 401 || res.statusCode == 403) {
        return 'Нет доступа: проверь токен HuggingFace и принятие лицензии Gemma';
      }
      if (res.statusCode != 200 && res.statusCode != 206) {
        return 'Сервер ответил ${res.statusCode} — попробуй позже';
      }

      // Server ignored the Range header — start over.
      final resuming = res.statusCode == 206 && existing > 0;
      final offset = resuming ? existing : 0;
      final total = (res.contentLength ?? 0) + offset;
      if (total > _minValidBytes) {
        await prefs.setInt(_totalBytesKey, total);
      }

      final sink = partFile.openWrite(
        mode: resuming ? FileMode.append : FileMode.write,
      );
      int done = offset;
      try {
        // The watchdog: if the connection silently dies, the stream stops
        // yielding chunks and we abort instead of pretending to download.
        await for (final chunk in res.stream.timeout(
          _stallTimeout,
          onTimeout: (sink) =>
              sink.addError(TimeoutException('download stalled')),
        )) {
          sink.add(chunk);
          done += chunk.length;
          if (total > 0 && onProgress != null) onProgress(done / total);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final knownTotal = prefs.getInt(_totalBytesKey) ?? 0;
      final gotAll = knownTotal > 0
          ? partFile.lengthSync() >= knownTotal
          : partFile.lengthSync() >= _minValidBytes;
      if (!gotAll) {
        return 'Соединение оборвалось — нажми ещё раз, продолжу с ${_gb(partFile.lengthSync())} ГБ';
      }

      final target = File(targetPath);
      if (target.existsSync()) target.deleteSync();
      partFile.renameSync(targetPath);

      // Register the finished file with the plugin (in place, no copy).
      final manager = FlutterGemmaPlugin.instance.modelManager;
      await manager.ensureModelReadyFromSpec(await _fileSpec());
      return null;
    } on TimeoutException {
      final got = partFile.existsSync() ? partFile.lengthSync() : 0;
      return 'Соединение пропало — нажми ещё раз, продолжу с ${_gb(got)} ГБ';
    } catch (e) {
      debugPrint('Model download error: $e');
      return 'Ошибка загрузки — нажми ещё раз, докачка продолжится';
    } finally {
      client.close();
    }
  }

  static String _gb(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

  static Future<void> deleteModel() async {
    await dispose();
    try {
      final manager = FlutterGemmaPlugin.instance.modelManager;
      if (await _pluginInstalled()) {
        await manager.deleteModel(await _networkSpec());
      }
      if (await _ownFileComplete()) {
        await manager.deleteModel(await _fileSpec());
      }
    } catch (e) {
      debugPrint('Model delete (plugin) error: $e');
    }
    for (final p in [await _ownFilePath(), '${await _ownFilePath()}.part']) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalBytesKey);
    _initFailed = false;
  }

  // ------------------------------------------------------------ inference

  static Future<InferenceModel?> _ensureModel() async {
    if (_model != null) return _model;
    if (_initFailed) return null;
    try {
      final gemma = FlutterGemmaPlugin.instance;
      final manager = gemma.modelManager;
      InferenceModelSpec? spec;
      if (await _ownFileComplete()) {
        spec = await _fileSpec();
        // Idempotent: registers the external file if it isn't yet.
        await manager.ensureModelReadyFromSpec(spec);
      } else if (await _pluginInstalled()) {
        spec = await _networkSpec();
      }
      if (spec == null) return null;
      manager.setActiveModel(spec);
      final gpu = await useGpu();
      try {
        _model = await gemma.createModel(
          modelType: ModelType.gemmaIt,
          maxTokens: 2048,
          preferredBackend: gpu ? PreferredBackend.gpu : PreferredBackend.cpu,
        );
      } catch (e) {
        if (!gpu) rethrow;
        // GPU refused — one retry on CPU before giving up.
        debugPrint('Local LLM GPU init failed, retrying on CPU: $e');
        _model = await gemma.createModel(
          modelType: ModelType.gemmaIt,
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
      }
      return _model;
    } catch (e) {
      debugPrint('Local LLM init failed: $e');
      _initFailed = true;
      return null;
    }
  }

  // MediaPipe handles one inference at a time: concurrent calls (fresh
  // entry + archive sweep) used to break each other. Everything goes
  // through one queue; priority jobs are counted so the sweep can yield.
  static Future<void> _queueTail = Future.value();
  static int _priorityWaiting = 0;

  /// True when a just-saved entry is waiting for analysis — the archive
  /// sweep checks this between items and steps aside.
  static bool get hasPriorityWaiting => _priorityWaiting > 0;

  /// Analyze a diary entry on-device. Returns null when the model is not
  /// available or produced an unparseable answer — callers keep their
  /// lexicon fallback in that case. [priority] marks a just-saved entry.
  static Future<MoodAnalysis?> analyze(String text,
      {bool priority = false}) {
    if (priority) _priorityWaiting++;
    final run = _queueTail.then((_) => _analyzeNow(text));
    _queueTail = run.then((_) {}, onError: (_) {});
    if (priority) run.whenComplete(() => _priorityWaiting--);
    return run;
  }

  static Future<MoodAnalysis?> _analyzeNow(String text) async {
    final model = await _ensureModel();
    if (model == null) return null;

    try {
      final session = await model.createSession(
        temperature: 0.3,
        topK: 40,
      );
      try {
        await session.addQueryChunk(
          Message.text(text: '$_prompt$text', isUser: true),
        );
        final raw = await session.getResponse();
        debugPrint('Local LLM response: $raw');
        return _parse(raw);
      } finally {
        await session.close();
      }
    } catch (e) {
      debugPrint('Local LLM inference error: $e');
      return null;
    }
  }

  /// Quietly re-analyzes a just-saved entry and updates it in the database.
  /// Fire-and-forget: the entry was already saved with the fast offline
  /// analysis, so the user never waits for the model.
  static Future<void> upgradeEntryInBackground(DiaryEntry entry) async {
    try {
      final result = await analyze(entry.text, priority: true);
      if (result == null) return;
      await DatabaseService.updateEntry(
        entry.copyWith(analysis: result, mood: result.emoji),
      );
      debugPrint('Local LLM: entry ${entry.id} upgraded in background');
    } catch (e) {
      debugPrint('Local LLM background upgrade error: $e');
    }
  }

  static MoodAnalysis? _parse(String raw) {
    try {
      var cleaned =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      // Small models love to wrap JSON in prose — cut to the outermost braces.
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      cleaned = cleaned.substring(start, end + 1);

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final score = (json['score'] as num).toInt().clamp(1, 10);
      return MoodAnalysis(
        emoji: (json['emoji'] as String?)?.trim().isNotEmpty == true
            ? (json['emoji'] as String).trim()
            : '📝',
        score: score,
        keywords: json['keywords'] is List
            ? List<String>.from(
                (json['keywords'] as List).map((e) => e.toString()))
            : const [],
        brief: (json['brief'] as String?) ?? '',
        source: AnalysisSource.local,
      );
    } catch (e) {
      debugPrint('Local LLM parse error: $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
  }
}
