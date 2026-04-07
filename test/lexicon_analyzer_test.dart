import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diary_app/services/lexicon_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Make rootBundle work for assets in tests by reading from disk.
  setUpAll(() async {
    // ServicesBinding loads asset bundle from project root automatically when
    // assets are declared in pubspec; no extra setup needed.
  });

  test('skeptical melancholic text should NOT be rated as happy', () async {
    const text = '''День как день. Вроде бы хотолось бы какого то внезапного счастья. А вроде бы зачем мне это? За счастьем потом всегда идет разочарование.''';
    final result = await LexiconAnalyzer.analyze(text);
    print('result: score=${result.score}, emoji=${result.emoji}, brief=${result.brief}');
    print('keywords: ${result.keywords}');
    // Should NOT be rated 7-10 (happy). Acceptable: 3-6 (mixed/neutral/slight negative).
    expect(result.score, lessThanOrEqualTo(6),
        reason: 'Skeptical text was rated as positive: ${result.score}/10');
  });

  test('clearly happy text is still rated positive', () async {
    const text = 'Сегодня был замечательный день! Я очень рад, всё прекрасно, чувствую огромное счастье и радость.';
    final result = await LexiconAnalyzer.analyze(text);
    print('happy result: score=${result.score}, emoji=${result.emoji}');
    expect(result.score, greaterThanOrEqualTo(7));
  });

  test('clearly sad text is rated negative', () async {
    const text = 'Мне так грустно и тоскливо. Я устал, всё плохо, ничего не хочется. Чувствую себя ужасно.';
    final result = await LexiconAnalyzer.analyze(text);
    print('sad result: score=${result.score}, emoji=${result.emoji}');
    expect(result.score, lessThanOrEqualTo(4));
  });

  test('crisis text is detected by override layer', () async {
    const text = 'Я больше не хочу жить, всё бессмысленно.';
    final result = await LexiconAnalyzer.analyze(text);
    print('crisis result: score=${result.score}, emoji=${result.emoji}');
    expect(result.score, equals(1));
    expect(result.emoji, equals('🆘'));
  });
}
