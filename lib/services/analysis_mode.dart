import 'package:shared_preferences/shared_preferences.dart';
import 'local_llm_service.dart';

/// How diary entries should be analyzed.
enum AnalysisMode {
  /// Fast hardcoded keyword analyzer (no internet, no extra assets).
  fast,

  /// Lexicon-based analyzer using RuSentiLex + stemmer + rules (no internet).
  lexicon,

  /// AI analyzer via OpenAI-compatible API (requires network).
  ai,

  /// On-device LLM (Gemma 3n) — no internet, nothing leaves the phone.
  /// Requires the model file (~3.1 GB) to be downloaded first.
  local,

  /// No analysis at all — entries are saved as plain text; the user can
  /// pick a mood by hand, or leave none.
  none,
}

extension AnalysisModeX on AnalysisMode {
  String get id => switch (this) {
        AnalysisMode.fast => 'fast',
        AnalysisMode.lexicon => 'lexicon',
        AnalysisMode.ai => 'ai',
        AnalysisMode.local => 'local',
        AnalysisMode.none => 'none',
      };

  String get title => switch (this) {
        AnalysisMode.fast => 'Быстрый',
        AnalysisMode.lexicon => 'Точный офлайн',
        AnalysisMode.ai => 'AI (облако)',
        AnalysisMode.local => 'Локальный ИИ',
        AnalysisMode.none => 'Без анализа',
      };

  String get description => switch (this) {
        AnalysisMode.fast =>
          'Мгновенный, без интернета. Простой словарь ключевых слов.',
        AnalysisMode.lexicon =>
          'Без интернета. Использует словарь RuSentiLex (~14 000 слов) и морфологический стеммер. Более точная оценка тональности.',
        AnalysisMode.ai =>
          'Лучшее качество, понимает контекст и иронию. Требует интернет, текст отправляется на API.',
        AnalysisMode.local =>
          'Нейросеть Gemma 3n работает прямо на телефоне: понимает контекст, а записи никогда не покидают устройство. Нужно один раз скачать модель (~3 ГБ).',
        AnalysisMode.none =>
          'Без автоматической оценки. Настроение выбираешь сам при записи (или оставляешь без него). Анализ ИИ можно запустить вручную для любой записи.',
      };
}

class AnalysisModeStore {
  static const _key = 'analysis_mode';

  static Future<AnalysisMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final saved = switch (raw) {
      'fast' => AnalysisMode.fast,
      'lexicon' => AnalysisMode.lexicon,
      'ai' => AnalysisMode.ai,
      'local' => AnalysisMode.local,
      'none' => AnalysisMode.none,
      _ => null,
    };
    if (saved != null) return saved;
    // No explicit choice: the on-device LLM is the default as soon as its
    // model is on disk; until then — the lexicon analyzer.
    if (await LocalLlmService.isModelReady()) return AnalysisMode.local;
    return AnalysisMode.lexicon;
  }

  static Future<void> save(AnalysisMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.id);
  }
}
