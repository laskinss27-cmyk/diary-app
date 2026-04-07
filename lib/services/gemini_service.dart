import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class ApiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;

  const ApiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  // Default built-in config
  static const defaultConfig = ApiConfig(
    baseUrl: 'REDACTED_BASE_URL',
    apiKey: 'REDACTED_API_KEY',
    model: 'claude-sonnet-4-6',
  );

  // Presets for quick setup
  static const presets = <String, ApiConfig>{
    'builtin': defaultConfig,
    'openai': ApiConfig(
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      apiKey: '',
      model: 'gpt-4o-mini',
    ),
    'gemini': ApiConfig(
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      apiKey: '',
      model: 'gemini-2.0-flash',
    ),
  };

  static const _urlKey = 'api_base_url';
  static const _keyKey = 'api_key';
  static const _modelKey = 'api_model';

  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    // If nothing saved, return default
    if (url == null || url.isEmpty) return defaultConfig;
    return ApiConfig(
      baseUrl: url,
      apiKey: prefs.getString(_keyKey) ?? '',
      model: prefs.getString(_modelKey) ?? '',
    );
  }

  static Future<void> save(ApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, config.baseUrl);
    await prefs.setString(_keyKey, config.apiKey);
    await prefs.setString(_modelKey, config.model);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_keyKey);
    await prefs.remove(_modelKey);
  }
}

class GeminiService {
  static const _systemPrompt = '''
Ты — эмоциональный аналитик дневника. Проанализируй запись пользователя и определи его РЕАЛЬНОЕ эмоциональное состояние.
Обращай внимание на контекст, скрытые эмоции, тревогу, радость, грусть, злость и т.д.

Верни ответ ТОЛЬКО в JSON формате, без markdown, без блоков кода, без пояснений:
{"emoji":"одно эмодзи","score":число_1_10,"keywords":["3-5 слов"],"brief":"краткий анализ одним предложением"}

Примеры:
- "Хочу выйти в окно" → тревога/отчаяние, score 2-3
- "Сегодня был отличный день" → радость, score 8-9
- "Ничего особенного" → нейтральность, score 5''';

  static Future<http.Response?> _postWithRetry(
    ApiConfig config,
    Map<String, dynamic> body, {
    int retries = 2,
    int timeoutSec = 30,
  }) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse(config.baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${config.apiKey}',
              },
              body: jsonEncode(body),
            )
            .timeout(Duration(seconds: timeoutSec));
        if (response.statusCode == 200) return response;
        debugPrint('API attempt ${i + 1}: status ${response.statusCode}');
        if (response.statusCode == 401) return response; // Don't retry auth errors
      } catch (e) {
        debugPrint('API attempt ${i + 1}: $e');
        if (i < retries) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
    return null;
  }

  static Future<MoodAnalysis?> analyze(String text, String apiKey) async {
    final config = await ApiConfig.load();
    if (!config.isConfigured) return null;

    final response = await _postWithRetry(config, {
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': 'Проанализируй эту дневниковую запись:\n\n$text'},
      ],
      'max_tokens': 200,
      'temperature': 0.3,
    }, timeoutSec: 45);

    if (response == null || response.statusCode != 200) return null;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;

      final content = choices[0]['message']['content'] as String;
      debugPrint('AI response: $content');

      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      return MoodAnalysis(
        emoji: json['emoji'] as String,
        score: (json['score'] as num).toInt(),
        keywords: List<String>.from(json['keywords'] as List),
        brief: json['brief'] as String,
      );
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  /// Tests the API connection with given config.
  static Future<String> testConnection(ApiConfig config) async {
    if (!config.isConfigured) return 'empty';

    try {
      final response = await http
          .post(
            Uri.parse(config.baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode({
              'model': config.model,
              'messages': [
                {'role': 'user', 'content': 'Ответь одним словом: привет'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Test response: ${response.statusCode}');
      debugPrint('Test body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to extract model name from response
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final model = body['model'] as String? ?? config.model;
          return 'ok:$model';
        } catch (_) {
          return 'ok:${config.model}';
        }
      }
      if (response.statusCode == 401) return 'invalid';
      if (response.statusCode == 429) return 'rate_limit';
      if (response.statusCode == 403) return 'forbidden';
      return 'error:${response.statusCode}';
    } catch (e) {
      debugPrint('Test exception: $e');
      return 'network';
    }
  }

  /// Legacy method for backward compat
  static Future<String> testApiKey(String apiKey) async {
    final config = await ApiConfig.load();
    return testConnection(config);
  }
}
