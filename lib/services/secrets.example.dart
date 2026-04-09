/// ШАБЛОН файла с секретами.
///
/// Скопируй этот файл как `secrets.dart` в этой же папке и заполни
/// значениями. Файл `secrets.dart` находится в .gitignore и не будет
/// закоммичен.
///
/// ```
/// cp lib/services/secrets.example.dart lib/services/secrets.dart
/// ```
///
/// Если `secrets.dart` отсутствует или ключи пустые — приложение
/// автоматически переключится на оффлайн-анализатор (lexicon_analyzer),
/// и всё продолжит работать. ИИ просто будет недоступен.
class Secrets {
  /// Базовый URL OpenAI-совместимого эндпоинта.
  /// Примеры:
  ///   https://api.openai.com/v1/chat/completions
  ///   https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
  static const String defaultBaseUrl = '';

  /// API-ключ для встроенного провайдера.
  /// НИКОГДА не коммить это значение в публичный репозиторий.
  static const String defaultApiKey = '';

  /// Название модели.
  static const String defaultModel = '';
}
