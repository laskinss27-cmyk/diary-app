import 'package:flutter_test/flutter_test.dart';
import 'package:snowball_stemmer/snowball_stemmer.dart';

void main() {
  test('russian stemmer matches python snowball output', () {
    final s = SnowballStemmer(Algorithm.russian);
    // Reference values produced by python snowballstemmer 3.0.1
    final cases = {
      'грустить': 'груст',
      'грущу': 'грущ',
      'грустный': 'грустн',
      'грусть': 'груст',
      'хороший': 'хорош',
      'хорошо': 'хорош',
      'счастливый': 'счастлив',
      'счастье': 'счаст',
      'тревога': 'тревог',
      'тревожный': 'тревожн',
      'тревожусь': 'тревож',
      'боюсь': 'бо',
      'страшно': 'страшн',
      'устал': 'уста',
      'усталость': 'устал',
      'радость': 'радост',
      'любовь': 'любов',
      'любить': 'люб',
      'ненависть': 'ненавист',
      'ненавижу': 'ненавиж',
      'покончить': 'поконч',
    };
    for (final entry in cases.entries) {
      final got = s.stem(entry.key);
      expect(got, entry.value, reason: '${entry.key} -> $got (expected ${entry.value})');
    }
  });
}
