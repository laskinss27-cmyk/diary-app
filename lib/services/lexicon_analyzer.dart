import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:snowball_stemmer/snowball_stemmer.dart';

import '../models/diary_entry.dart';
import 'mood_fallback.dart';

/// Offline mood analyzer powered by RuSentiLex (stemmed) + Russian Snowball
/// stemmer + rule layer (negations, intensifiers, exclamations).
///
/// Crisis detection is delegated to [MoodFallback] as a hard override layer:
/// regardless of lexicon score, suicidal / self-harm content forces score=1.
///
/// Lexicon source: RuSentiLex (ИСП РАН), CC BY-NC-SA 4.0.
class LexiconAnalyzer {
  static final _stemmer = SnowballStemmer(Algorithm.russian);

  // stem -> weight (1=fact, 2=opinion, 3=feeling)
  static Map<String, int>? _pos;
  static Map<String, int>? _neg;

  // Multi-word phrases (joined stems)
  static Map<String, int>? _posPhrases;
  static Map<String, int>? _negPhrases;

  static bool _loading = false;

  /// Loads lexicon assets into memory. Safe to call multiple times.
  static Future<void> ensureLoaded() async {
    if (_pos != null && _neg != null) return;
    if (_loading) {
      // Wait for the in-flight load.
      while (_loading) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      return;
    }
    _loading = true;
    try {
      final posRaw = await rootBundle.loadString('assets/lexicon/rusentilex_pos.txt');
      final negRaw = await rootBundle.loadString('assets/lexicon/rusentilex_neg.txt');
      _pos = {};
      _neg = {};
      _posPhrases = {};
      _negPhrases = {};
      _parse(posRaw, _pos!, _posPhrases!);
      _parse(negRaw, _neg!, _negPhrases!);
      debugPrint('Lexicon loaded: ${_pos!.length} pos, ${_neg!.length} neg, '
          '${_posPhrases!.length} pos phrases, ${_negPhrases!.length} neg phrases');
    } catch (e) {
      debugPrint('Lexicon load error: $e');
      _pos = {};
      _neg = {};
      _posPhrases = {};
      _negPhrases = {};
    } finally {
      _loading = false;
    }
  }

  static void _parse(String raw, Map<String, int> single, Map<String, int> phrase) {
    for (final line in raw.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final tab = l.indexOf('\t');
      if (tab < 0) continue;
      final w = int.tryParse(l.substring(0, tab)) ?? 1;
      final stem = l.substring(tab + 1);
      if (stem.contains(' ')) {
        // Keep highest weight on duplicates.
        final prev = phrase[stem];
        if (prev == null || prev < w) phrase[stem] = w;
      } else {
        final prev = single[stem];
        if (prev == null || prev < w) single[stem] = w;
      }
    }
  }

  // ---- Rule layer constants ----

  static const _negators = {'не', 'ни', 'нет', 'без', 'никак', 'ничто', 'ничего', 'никогда'};
  static const _intensifiers = {
    'очень', 'крайне', 'абсолютно', 'совсем', 'ужасно', 'страшно',
    'чересчур', 'слишком', 'дико', 'жутко', 'безумно', 'невероятно',
    'капец', 'пиздец', 'пипец', 'охуенно', 'охренеть',
  };
  static const _diminishers = {
    'немного', 'чуть', 'слегка', 'отчасти', 'едва', 'почти',
  };

  /// Markers of skepticism / rhetorical questions / hedging.
  /// When found, positive contributions in the same sentence are heavily
  /// discounted (because the writer is doubting, not feeling).
  static const _skepticPhrases = [
    'вроде бы', 'вроде как', 'как будто', 'якобы',
    'зачем мне', 'зачем оно', 'зачем это', 'к чему',
    'а смысл', 'какой смысл', 'нет смысла',
    'хотелось бы', 'хочется бы', 'если бы',
    'кому это надо', 'кому нужно',
    'разве', 'неужели',
  ];

  /// Returns indices of tokens that are inside a skeptical context window.
  /// We mark all tokens within +/- 6 of a skeptic-phrase match.
  static Set<int> _findSkepticWindows(String text, List<String> tokens) {
    final lower = text.toLowerCase().replaceAll('ё', 'е');
    final marks = <int>{};
    for (final phrase in _skepticPhrases) {
      int idx = 0;
      while ((idx = lower.indexOf(phrase, idx)) != -1) {
        // Find approximate token index by counting words before this position.
        final before = lower.substring(0, idx);
        final tokensBefore = RegExp(r'[а-я]+').allMatches(before).length;
        for (var k = tokensBefore; k < tokensBefore + phrase.split(' ').length + 6 && k < tokens.length; k++) {
          marks.add(k);
        }
        idx += phrase.length;
      }
    }
    return marks;
  }

  /// Main entry point.
  static Future<MoodAnalysis> analyze(String text) async {
    await ensureLoaded();

    // 1. Crisis override layer — keyword based, hardcoded.
    final crisisHit = _detectCrisis(text);
    if (crisisHit != null) return crisisHit;

    // 2. Tokenize and stem.
    final tokens = _tokenize(text);
    if (tokens.isEmpty) {
      return const MoodAnalysis(
        emoji: '😐',
        score: 5,
        keywords: ['нейтрально'],
        brief: 'Нейтральное состояние без выраженных эмоций.',
      );
    }
    final stems = tokens.map((t) => _stemmer.stem(t)).toList();

    // 3. Score by walking tokens, applying negation/intensifier window.
    double posScore = 0;
    double negScore = 0;
    final foundPos = <String>{};
    final foundNeg = <String>{};

    bool isExclaim = text.contains('!');
    final exclaimBoost = isExclaim ? 1.15 : 1.0;

    // Skeptical context windows (rhetorical / hedging phrases).
    final skepticIdx = _findSkepticWindows(text, tokens);

    // Stem occurrence counter for diminishing returns (dedup).
    // Same stem mentioned 1st time: 1.0, 2nd: 0.35, 3rd: 0.15, 4th+: 0.07.
    final stemCount = <String, int>{};
    double diminishingFactor(int n) {
      switch (n) {
        case 1:
          return 1.0;
        case 2:
          return 0.35;
        case 3:
          return 0.15;
        default:
          return 0.07;
      }
    }

    for (var i = 0; i < stems.length; i++) {
      final stem = stems[i];
      if (stem.isEmpty) continue;

      // Determine modifier from previous tokens (window of 3).
      double modifier = 1.0;
      bool negated = false;
      for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
        final prev = tokens[j];
        if (_negators.contains(prev)) {
          negated = !negated;
        } else if (_intensifiers.contains(prev)) {
          modifier *= 1.6;
        } else if (_diminishers.contains(prev)) {
          modifier *= 0.5;
        }
      }
      modifier *= exclaimBoost;

      // Skeptical context: heavily discount positives, slightly discount negatives.
      final inSkeptic = skepticIdx.contains(i);

      // Check single-word lexicon.
      final pw = _pos![stem];
      final nw = _neg![stem];

      if (pw != null) {
        // Bump count for this stem.
        final n = (stemCount[stem] ?? 0) + 1;
        stemCount[stem] = n;
        var delta = pw * modifier * diminishingFactor(n);
        if (inSkeptic) delta *= 0.25; // skeptical "happiness" is doubt, not joy
        if (negated) {
          negScore += delta * 0.7;
          foundNeg.add(tokens[i]);
        } else {
          posScore += delta;
          foundPos.add(tokens[i]);
        }
      }
      if (nw != null) {
        final n = (stemCount[stem] ?? 0) + 1;
        stemCount[stem] = n;
        var delta = nw * modifier * diminishingFactor(n);
        if (inSkeptic) delta *= 0.7;
        if (negated) {
          posScore += delta * 0.5;
          foundPos.add(tokens[i]);
        } else {
          negScore += delta;
          foundNeg.add(tokens[i]);
        }
      }
    }

    // 4. Multi-word phrase scan (bigrams + trigrams of stems).
    for (var i = 0; i < stems.length - 1; i++) {
      final bg = '${stems[i]} ${stems[i + 1]}';
      _accumPhrase(bg, tokens, i, 2,
          (p) => posScore += p,
          (n) => negScore += n,
          foundPos, foundNeg);
      if (i < stems.length - 2) {
        final tg = '${stems[i]} ${stems[i + 1]} ${stems[i + 2]}';
        _accumPhrase(tg, tokens, i, 3,
            (p) => posScore += p,
            (n) => negScore += n,
            foundPos, foundNeg);
      }
    }

    // 5. Map to result.
    return _buildResult(posScore, negScore, foundPos, foundNeg, tokens.length);
  }

  static void _accumPhrase(
    String key,
    List<String> tokens,
    int startIdx,
    int len,
    void Function(double) addPos,
    void Function(double) addNeg,
    Set<String> foundPos,
    Set<String> foundNeg,
  ) {
    final p = _posPhrases![key];
    final n = _negPhrases![key];
    if (p != null) {
      addPos(p * 1.2); // phrases are slightly more reliable signals
      foundPos.add(tokens.sublist(startIdx, startIdx + len).join(' '));
    }
    if (n != null) {
      addNeg(n * 1.2);
      foundNeg.add(tokens.sublist(startIdx, startIdx + len).join(' '));
    }
  }

  static List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    // Cyrillic letters + dash inside words
    final re = RegExp(r"[а-яё]+(?:-[а-яё]+)*");
    return re.allMatches(lower).map((m) => m.group(0)!.replaceAll('ё', 'е')).toList();
  }

  // ---- Crisis detector (hardcoded, language-specific) ----
  // This is the safety net: lexicon may rate "хочу умереть" as merely
  // negative, but we MUST flag it as crisis.
  static const _crisisPatterns = [
    'суицид', 'суицидальн',
    'покончить с собой', 'покончу с собой', 'покончила с собой',
    'убить себя', 'убью себя', 'убила себя',
    'повеситься', 'повешусь', 'повесилась',
    'хочу умереть', 'хочется умереть', 'хочу сдохнуть', 'хочется сдохнуть',
    'лучше бы я умер', 'лучше бы умереть', 'лучше б умереть',
    'не хочу жить', 'не хочется жить', 'нет смысла жить', 'незачем жить',
    'устал жить', 'устала жить',
    'выйти в окно', 'выйду в окно', 'прыгну с', 'прыгнуть с крыш',
    'выброшусь', 'выброситься',
    // Self-harm: вены / порезы / резать (любая форма глагола)
    'перерезать вен', 'вскрою вен', 'вскрыть вен', 'вскрыл вен',
    'вскрыла вен', 'вскрываю вен', 'вскрываюсь',
    'режу вен', 'режу себ', 'режу руки', 'режу кожу', 'резать вен',
    'резать себ', 'порезал себ', 'порезала себ', 'порежу себ',
    'порезы на', 'порез на руке', 'порез на запяст',
    'царапаю себ', 'царапать себ', 'царапины на',
    'делаю себе больно', 'делать себе больно', 'причинять себе боль',
    'причиняю себе боль', 'самоповреждение', 'селфхарм',
    // Pills / overdose
    'наглотаюсь таблеток', 'наглотаться таблеток', 'наглоталась таблеток',
    'наглотался таблеток', 'передозировк',
    // Settling accounts
    'свести счёты с жизн', 'свести счеты с жизн',
    'свожу счёты', 'свожу счеты',
    // Burden / worthlessness — common cognitive markers
    'всем будет лучше без меня', 'мир без меня лучше',
    'без меня всем будет лучше', 'я обуза', 'я бремя', 'я лишний',
    'никому не нужен', 'никому не нужна', 'никому не нужны мои',
    // Existential
    'жизнь не имеет смысла', 'нет смысла существовать',
    'хочу исчезнуть навсегда', 'хочу пропасть навсегда',
    'устал от всего', 'устала от всего',
    // Direct intent
    'я в кризисе', 'у меня кризис', 'мне очень плохо', 'мне совсем плохо',
    'я не справля', 'не могу больше', 'не выдерживаю', 'не вытяну',
  ];

  static MoodAnalysis? _detectCrisis(String text) {
    final lower = text.toLowerCase().replaceAll('ё', 'е');
    for (final p in _crisisPatterns) {
      if (lower.contains(p.replaceAll('ё', 'е'))) {
        return const MoodAnalysis(
          emoji: '🆘',
          score: 1,
          keywords: ['кризисное состояние', 'нужна помощь'],
          brief:
              'Обнаружены признаки кризисного состояния. Пожалуйста, обратитесь за помощью: 8-800-2000-122 (бесплатно, круглосуточно).',
        );
      }
    }
    return null;
  }

  static MoodAnalysis _buildResult(
    double pos,
    double neg,
    Set<String> foundPos,
    Set<String> foundNeg,
    int totalTokens,
  ) {
    // Normalize against text length so very long entries don't always max out.
    final norm = (totalTokens.clamp(1, 200)) / 10.0;
    final posN = pos / norm;
    final negN = neg / norm;
    final balance = posN - negN; // > 0 positive, < 0 negative
    final magnitude = posN + negN;

    // Map balance + magnitude → 1..10 score.
    int score;
    String emoji;
    String brief;
    List<String> keywords;

    if (magnitude < 0.3) {
      // Almost no signal.
      score = 5;
      emoji = '😐';
      brief = 'Нейтральное состояние без выраженных эмоций.';
      keywords = ['нейтрально', 'спокойно'];
    } else if (balance > 1.5) {
      score = 9;
      emoji = '😄';
      brief = 'Выраженное позитивное настроение.';
      keywords = _topN(foundPos, 4, fallback: ['радость', 'позитив']);
    } else if (balance > 0.5) {
      score = 8;
      emoji = '😊';
      brief = 'Преобладают положительные эмоции.';
      keywords = _topN(foundPos, 4, fallback: ['радость']);
    } else if (balance > 0.1) {
      score = 7;
      emoji = '🙂';
      brief = 'Лёгкий позитивный фон.';
      keywords = _topN(foundPos, 4, fallback: ['позитив']);
    } else if (balance < -1.5) {
      score = 2;
      emoji = '😢';
      brief = 'Выражено сильное негативное состояние.';
      keywords = _topN(foundNeg, 4, fallback: ['грусть', 'тяжесть']);
    } else if (balance < -0.5) {
      score = 3;
      emoji = '😔';
      brief = 'Преобладает подавленное настроение.';
      keywords = _topN(foundNeg, 4, fallback: ['грусть']);
    } else if (balance < -0.1) {
      score = 4;
      emoji = '😕';
      brief = 'Лёгкий негативный фон.';
      keywords = _topN(foundNeg, 4, fallback: ['напряжение']);
    } else {
      // Mixed feelings — pos and neg cancel out but both present.
      score = 5;
      emoji = '😶';
      brief = 'Смешанные чувства — есть и положительные, и отрицательные эмоции.';
      keywords = [
        ..._topN(foundPos, 2, fallback: []),
        ..._topN(foundNeg, 2, fallback: []),
      ];
      if (keywords.isEmpty) keywords = ['смешанные чувства'];
    }

    return MoodAnalysis(
      emoji: emoji,
      score: score,
      keywords: keywords,
      brief: brief,
    );
  }

  static List<String> _topN(Set<String> words, int n, {required List<String> fallback}) {
    if (words.isEmpty) return fallback;
    return words.take(n).toList();
  }
}
