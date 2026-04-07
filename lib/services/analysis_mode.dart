import 'package:shared_preferences/shared_preferences.dart';

/// How diary entries should be analyzed.
enum AnalysisMode {
  /// Fast hardcoded keyword analyzer (no internet, no extra assets).
  fast,

  /// Lexicon-based analyzer using RuSentiLex + stemmer + rules (no internet).
  lexicon,

  /// AI analyzer via OpenAI-compatible API (requires network).
  ai,
}

extension AnalysisModeX on AnalysisMode {
  String get id => switch (this) {
        AnalysisMode.fast => 'fast',
        AnalysisMode.lexicon => 'lexicon',
        AnalysisMode.ai => 'ai',
      };

  String get title => switch (this) {
        AnalysisMode.fast => 'Быстрый',
        AnalysisMode.lexicon => 'Точный офлайн',
        AnalysisMode.ai => 'AI (нейросеть)',
      };

  String get description => switch (this) {
        AnalysisMode.fast =>
          'Мгновенный, без интернета. Простой словарь ключевых слов.',
        AnalysisMode.lexicon =>
          'Без интернета. Использует словарь RuSentiLex (~14 000 слов) и морфологический стеммер. Более точная оценка тональности.',
        AnalysisMode.ai =>
          'Лучшее качество, понимает контекст и иронию. Требует интернет, текст отправляется на API.',
      };
}

class AnalysisModeStore {
  static const _key = 'analysis_mode';

  static Future<AnalysisMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return switch (raw) {
      'fast' => AnalysisMode.fast,
      'lexicon' => AnalysisMode.lexicon,
      'ai' => AnalysisMode.ai,
      _ => AnalysisMode.lexicon, // default — best balance
    };
  }

  static Future<void> save(AnalysisMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.id);
  }
}
