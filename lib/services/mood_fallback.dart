import '../models/diary_entry.dart';

class MoodFallback {
  static MoodAnalysis analyze(String text) {
    final lower = ' ${text.toLowerCase()} '; // pad with spaces for word boundary

    // === PHASE 1: Score each category ===
    final scores = <String, double>{};

    // Crisis — absolute priority
    scores['crisis'] = _scoreCategory(lower, _crisis) * 5.0;

    // Negative categories
    scores['despair'] = _scoreCategory(lower, _despair) * 3.0;
    scores['angry'] = _scoreCategory(lower, _angry) * 2.0;
    scores['anxious'] = _scoreCategory(lower, _anxious) * 2.0;
    scores['sad'] = _scoreCategory(lower, _sad) * 2.0;
    scores['tired'] = _scoreCategory(lower, _tired) * 1.5;
    scores['lonely'] = _scoreCategory(lower, _lonely) * 2.0;

    // Positive categories
    scores['happy'] = _scoreCategory(lower, _happy) * 2.0;
    scores['calm'] = _scoreCategory(lower, _calm) * 1.5;
    scores['grateful'] = _scoreCategory(lower, _grateful) * 2.0;

    // === PHASE 2: Check for negation ===
    // If "не" + positive word → reduce happy, boost sad
    final hasNegatedPositive = _hasNegation(lower, _happy);
    if (hasNegatedPositive) {
      scores['happy'] = (scores['happy']! * 0.1); // almost zero out
      scores['sad'] = (scores['sad']! + 2.0);
    }

    // If "не" + negative word → could be positive ("не грущу")
    final hasNegatedNegative = _hasNegation(lower, [..._sad, ..._anxious, ..._angry]);
    if (hasNegatedNegative) {
      scores['sad'] = (scores['sad']! * 0.3);
      scores['anxious'] = (scores['anxious']! * 0.3);
    }

    // === PHASE 3: Determine dominant emotion ===

    // CRISIS always wins if detected
    if (scores['crisis']! > 0) {
      return MoodAnalysis(
        emoji: '🆘',
        score: 1,
        keywords: _findMatching(lower, _crisisWords),
        brief: 'Обнаружены признаки кризисного состояния. Пожалуйста, обратитесь за помощью.',
      );
    }

    // DESPAIR
    if (scores['despair']! > 0) {
      return MoodAnalysis(
        emoji: '😭',
        score: 2,
        keywords: _findMatching(lower, _despairWords),
        brief: 'Выражено сильное отчаяние и эмоциональная боль.',
      );
    }

    // Calculate total negative and positive
    final totalNeg = scores['angry']! + scores['anxious']! +
                     scores['sad']! + scores['tired']! + scores['lonely']!;
    final totalPos = scores['happy']! + scores['calm']! + scores['grateful']!;

    // Find dominant negative category
    String dominantNeg = 'sad';
    double maxNeg = 0;
    for (final cat in ['angry', 'anxious', 'sad', 'tired', 'lonely']) {
      if (scores[cat]! > maxNeg) {
        maxNeg = scores[cat]!;
        dominantNeg = cat;
      }
    }

    // Find dominant positive category
    String dominantPos = 'happy';
    double maxPos = 0;
    for (final cat in ['happy', 'calm', 'grateful']) {
      if (scores[cat]! > maxPos) {
        maxPos = scores[cat]!;
        dominantPos = cat;
      }
    }

    // === PHASE 4: Return result based on balance ===

    // Strong negative
    if (totalNeg > 0 && totalNeg > totalPos * 1.5) {
      return _negativeResult(dominantNeg, lower, totalNeg);
    }

    // Strong positive
    if (totalPos > 0 && totalPos > totalNeg * 1.5) {
      return _positiveResult(dominantPos, lower, totalPos);
    }

    // Mixed feelings
    if (totalNeg > 0 && totalPos > 0) {
      return MoodAnalysis(
        emoji: '😶',
        score: 5,
        keywords: [
          ..._findMatching(lower, _allNegWords).take(2),
          ..._findMatching(lower, _allPosWords).take(2),
        ],
        brief: 'Смешанные чувства — присутствуют и положительные, и отрицательные эмоции.',
      );
    }

    // Slight negative
    if (totalNeg > 0) {
      return _negativeResult(dominantNeg, lower, totalNeg);
    }

    // Slight positive
    if (totalPos > 0) {
      return _positiveResult(dominantPos, lower, totalPos);
    }

    // Truly neutral
    return const MoodAnalysis(
      emoji: '😐',
      score: 5,
      keywords: ['спокойствие', 'нейтральность', 'обыденность'],
      brief: 'Нейтральное эмоциональное состояние без выраженных эмоций.',
    );
  }

  // === Scoring ===

  static double _scoreCategory(String text, List<String> patterns) {
    double score = 0;
    for (final p in patterns) {
      if (text.contains(p)) score += 1.0;
    }
    return score;
  }

  static bool _hasNegation(String text, List<String> words) {
    for (final w in words) {
      // Check "не X", "ни X", "нет X"
      if (text.contains('не $w') || text.contains('ни $w') ||
          text.contains('нет $w') || text.contains('без $w')) {
        return true;
      }
    }
    return false;
  }

  static List<String> _findMatching(String text, Map<String, String> wordMap) {
    final found = <String>[];
    for (final entry in wordMap.entries) {
      if (text.contains(entry.key)) found.add(entry.value);
      if (found.length >= 4) break;
    }
    if (found.isEmpty) return wordMap.values.take(3).toList();
    return found;
  }

  // === Result builders ===

  static MoodAnalysis _negativeResult(String category, String text, double intensity) {
    final int score;
    if (intensity > 6) {
      score = 2;
    } else if (intensity > 3) {
      score = 3;
    } else {
      score = 4;
    }

    switch (category) {
      case 'angry':
        return MoodAnalysis(
          emoji: '😤',
          score: score,
          keywords: _findMatching(text, _angryWords),
          brief: 'Выражены раздражение, злость и негативные эмоции.',
        );
      case 'anxious':
        return MoodAnalysis(
          emoji: '😰',
          score: score,
          keywords: _findMatching(text, _anxiousWords),
          brief: 'Чувствуется тревога и внутреннее напряжение.',
        );
      case 'tired':
        return MoodAnalysis(
          emoji: '😴',
          score: score.clamp(4, 5),
          keywords: _findMatching(text, _tiredWords),
          brief: 'Ощущается усталость и нехватка ресурсов.',
        );
      case 'lonely':
        return MoodAnalysis(
          emoji: '🥺',
          score: score,
          keywords: _findMatching(text, _lonelyWords),
          brief: 'Чувство одиночества и потребность в поддержке.',
        );
      default: // sad
        return MoodAnalysis(
          emoji: '😔',
          score: score,
          keywords: _findMatching(text, _sadWords),
          brief: 'Преобладает грустное, подавленное настроение.',
        );
    }
  }

  static MoodAnalysis _positiveResult(String category, String text, double intensity) {
    final int score;
    if (intensity > 6) {
      score = 9;
    } else if (intensity > 3) {
      score = 8;
    } else {
      score = 7;
    }

    switch (category) {
      case 'calm':
        return MoodAnalysis(
          emoji: '😌',
          score: score.clamp(6, 8),
          keywords: _findMatching(text, _calmWords),
          brief: 'Спокойное, умиротворённое состояние.',
        );
      case 'grateful':
        return MoodAnalysis(
          emoji: '🙏',
          score: score,
          keywords: _findMatching(text, _gratefulWords),
          brief: 'Чувство благодарности и тепла.',
        );
      default: // happy
        return MoodAnalysis(
          emoji: '😊',
          score: score,
          keywords: _findMatching(text, _happyWords),
          brief: 'Позитивное настроение, радость и удовольствие.',
        );
    }
  }

  // ============================
  //  WORD LISTS
  // ============================

  // --- CRISIS (score 1) ---
  static const _crisis = [
    'суицид', 'покончить с собой', 'покончу с собой', 'убить себя', 'убью себя',
    'повеситься', 'повешусь', 'вешаться', 'прыгну с', 'выброшусь',
    'хочу умереть', 'хочется умереть', 'лучше бы я умер', 'лучше б умер',
    'не хочу жить', 'нет смысла жить', 'зачем жить', 'незачем жить',
    'хочу сдохнуть', 'хочется сдохнуть', 'лучше сдохнуть',
    'перерезать вен', 'вскрою вен', 'вскрыть вен', 'порежу себ',
    'наглотаться таблеток', 'наглотаюсь таблеток', 'выпить таблеток',
    'выйти в окно', 'выйду в окно', 'прыгнуть с крыш', 'прыгну с крыш',
    'конец всему', 'пора заканчивать', 'больше не могу так жить',
    'самоубийств', 'суицидальн', 'свести счёты', 'свести счеты',
    'жизнь не имеет смысла', 'всё бессмысленно', 'все бессмысленно',
    'никому не нужен', 'никому не нужна', 'всем будет лучше без меня',
    'мир без меня', 'устал жить', 'устала жить',
  ];
  static const _crisisWords = {
    'суицид': 'суицидальные мысли', 'умереть': 'желание смерти',
    'убить себя': 'самоповреждение', 'не хочу жить': 'нежелание жить',
    'покончить': 'суицидальные мысли', 'повеситься': 'суицидальные мысли',
    'окно': 'кризис', 'таблеток': 'кризис', 'вен': 'самоповреждение',
    'смысл': 'потеря смысла', 'не нужен': 'ощущение ненужности',
    'бессмысленн': 'экзистенциальный кризис', 'устал жить': 'истощение',
  };

  // --- DESPAIR (score 2) ---
  static const _despair = [
    'безнадёж', 'безнадеж', 'безысходн', 'невыносим',
    'отчаяни', 'в отчаяни', 'больше не могу', 'нет выхода',
    'ненавижу себя', 'ненавижу свою жизнь', 'я ничтожеств',
    'я никчёмн', 'я никчемн', 'я ничего не стою', 'я никому не нужн',
    'хочу исчезнуть', 'хочу пропасть', 'хочу раствориться',
    'темнота внутри', 'пустота внутри', 'внутри пусто',
    'всё рухнуло', 'все рухнуло', 'жизнь кончена', 'нет будущего',
    'не вижу смысла', 'не вижу выхода', 'тупик',
    'задыхаюсь', 'тону', 'утопаю', 'разваливаюсь',
  ];
  static const _despairWords = {
    'безнадёж': 'безнадёжность', 'безнадеж': 'безнадёжность',
    'отчаяни': 'отчаяние', 'невыносим': 'невыносимость',
    'больше не могу': 'истощение', 'нет выхода': 'тупик',
    'ненавижу себя': 'самоненависть', 'пустота': 'пустота',
    'исчезнуть': 'избегание', 'рухнуло': 'крах', 'тупик': 'безвыходность',
  };

  // --- ANGRY ---
  static const _angry = [
    'злой', 'злая', 'злюсь', 'раздраж', 'бесит', 'бешу',
    'ненавиж', 'злость', 'орал', 'кричал', 'кричала', 'орала',
    'ярость', 'гнев', 'агресс', 'взбеш', 'разъяр',
    'убил бы', 'убила бы', 'задолбал', 'достал', 'достали',
    'заколебал', 'заебал', 'пиздец', 'сука', 'блять', 'бляд',
    'ненависть', 'презира', 'отвращен', 'мерзк',
    'хочу ударить', 'хочу разбить', 'сломать', 'разнести',
    'несправедлив', 'предательств', 'предал',
  ];
  static const _angryWords = {
    'злой': 'злость', 'злюсь': 'гнев', 'раздраж': 'раздражение',
    'бесит': 'раздражение', 'ненавиж': 'ненависть', 'ярость': 'ярость',
    'гнев': 'гнев', 'агресс': 'агрессия', 'достал': 'раздражение',
    'несправедлив': 'несправедливость', 'предал': 'предательство',
  };

  // --- ANXIOUS ---
  static const _anxious = [
    'боюсь', 'страшн', 'тревог', 'тревож', 'волнуюсь', 'паник',
    'переживаю', 'нервнича', 'нервн', 'беспоко',
    'не могу успокоиться', 'трясёт', 'трясет', 'трясусь',
    'сердце колотится', 'не могу дышать', 'задыхаюсь от страха',
    'ужас', 'кошмар', 'фобия', 'приступ',
    'что если', 'а вдруг', 'всё плохо будет', 'все плохо будет',
    'не справлюсь', 'не смогу', 'провалюсь', 'облажаюсь',
    'неопределённость', 'неопределенность', 'неизвестность',
  ];
  static const _anxiousWords = {
    'боюсь': 'страх', 'страшн': 'страх', 'тревог': 'тревога',
    'волнуюсь': 'волнение', 'паник': 'паника', 'переживаю': 'переживание',
    'нервн': 'нервозность', 'беспоко': 'беспокойство',
    'кошмар': 'кошмар', 'не справлюсь': 'неуверенность',
  };

  // --- SAD ---
  static const _sad = [
    'груст', 'грущу', 'печаль', 'печальн', 'тоск', 'тоскую',
    'плох', 'плач', 'рыдаю', 'рыдала', 'слёзы', 'слезы',
    'обидн', 'обижен', 'обижена', 'обида',
    'разочаров', 'расстроен', 'расстроил', 'расстроена',
    'подавлен', 'угнетён', 'угнетен', 'депресс', 'депрессия',
    'опустошён', 'опустошена', 'опустошен', 'выгоран',
    'хандра', 'меланхол', 'уныни', 'унылый', 'унылая',
    'больно', 'душевная боль', 'сердце болит',
    'потеря', 'утрата', 'скорбь', 'горе', 'горюю',
    'скучаю', 'не хватает',
  ];
  static const _sadWords = {
    'груст': 'грусть', 'печаль': 'печаль', 'тоск': 'тоска',
    'плох': 'подавленность', 'слёзы': 'слёзы', 'слезы': 'слёзы',
    'обид': 'обида', 'разочаров': 'разочарование',
    'депресс': 'депрессия', 'подавлен': 'подавленность',
    'выгоран': 'выгорание', 'потеря': 'потеря', 'горе': 'горе',
  };

  // --- LONELY ---
  static const _lonely = [
    'одинок', 'одна', 'один ', 'никто не понимает',
    'никому не нужн', 'некому позвонить', 'не с кем поговорить',
    'изолир', 'отвергну', 'брошен', 'брошена',
    'покинут', 'забыт', 'забыли', 'никто не звонит',
    'пусто вокруг', 'пустой дом', 'пустая квартира',
  ];
  static const _lonelyWords = {
    'одинок': 'одиночество', 'никому не нужн': 'ненужность',
    'некому': 'изоляция', 'отвергну': 'отвержение',
    'брошен': 'покинутость', 'забыт': 'забытость',
  };

  // --- TIRED ---
  static const _tired = [
    'устал', 'устала', 'утомлён', 'утомлена', 'утомлен',
    'сонн', 'хочу спать', 'нет сил', 'нету сил',
    'вымотал', 'вымотан', 'измотан', 'измотала',
    'выдохся', 'выдохлась', 'обессилен', 'обессилена',
    'перегруз', 'перегорел', 'перегорела',
    'еле стою', 'еле хожу', 'ноги не держат',
    'сил нет', 'нет энергии', 'энергии нет',
  ];
  static const _tiredWords = {
    'устал': 'усталость', 'сонн': 'сонливость',
    'нет сил': 'бессилие', 'вымотал': 'истощение',
    'перегруз': 'перегрузка', 'перегорел': 'выгорание',
    'обессилен': 'обессиленность',
  };

  // --- HAPPY ---
  static const _happy = [
    'счастлив', 'радост', 'радуюсь', 'рад ', 'рада ',
    'отличн', 'хорош', 'весел', 'веселюсь',
    'люблю', 'влюблён', 'влюблен', 'влюблена',
    'прекрасн', 'замечательн', 'супер', 'класс',
    'восторг', 'восхищ', 'кайф', 'эйфори',
    'ура', 'наконец-то', 'мечта сбылась',
    'улыбаюсь', 'смеюсь', 'хохочу',
    'удовольстви', 'наслаждаюсь', 'наслаждение',
  ];
  static const _happyWords = {
    'счастлив': 'счастье', 'радост': 'радость', 'рад': 'радость',
    'хорош': 'позитив', 'весел': 'веселье', 'люблю': 'любовь',
    'влюблён': 'влюблённость', 'прекрасн': 'восхищение',
    'восторг': 'восторг', 'кайф': 'удовольствие',
    'наслаждаюсь': 'наслаждение',
  };

  // --- CALM ---
  static const _calm = [
    'спокойн', 'умиротвор', 'гармони', 'баланс',
    'тихо', 'тишина', 'покой', 'релакс',
    'отдыхаю', 'расслабл', 'медитир', 'медитаци',
    'в мире с собой', 'душевный покой', 'безмятежн',
  ];
  static const _calmWords = {
    'спокойн': 'спокойствие', 'умиротвор': 'умиротворение',
    'гармони': 'гармония', 'покой': 'покой',
    'расслабл': 'расслабление', 'тишина': 'тишина',
  };

  // --- GRATEFUL ---
  static const _grateful = [
    'благодар', 'спасибо', 'признател', 'ценю',
    'повезло', 'как мне повезло', 'благослов',
    'дорожу', 'благо',
  ];
  static const _gratefulWords = {
    'благодар': 'благодарность', 'спасибо': 'благодарность',
    'признател': 'признательность', 'ценю': 'ценность',
    'повезло': 'везение', 'дорожу': 'ценность',
  };

  // Aggregate maps for mixed emotions
  static final Map<String, String> _allNegWords = {
    ..._angryWords, ..._anxiousWords, ..._sadWords,
    ..._tiredWords, ..._lonelyWords,
  };
  static final Map<String, String> _allPosWords = {
    ..._happyWords, ..._calmWords, ..._gratefulWords,
  };
}
