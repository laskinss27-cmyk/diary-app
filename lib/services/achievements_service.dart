import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String condition;
  final String image;
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.condition,
    required this.image,
  });
}

class AchievementsCatalog {
  static const List<Achievement> all = [
    Achievement(
      id: 'first_step',
      name: 'Первый шаг',
      description: 'Ты начал. Это уже много.',
      condition: 'Сделать первую запись',
      image: 'assets/achievements/first_step.png',
    ),
    Achievement(
      id: 'night_owl',
      name: 'Сова',
      description: 'Ночь. Тихо. И ты пишешь.',
      condition: 'Запись между 00:00 и 04:00',
      image: 'assets/achievements/night_owl.png',
    ),
    Achievement(
      id: 'perfect_day',
      name: 'Идеальный день',
      description: 'Бывают и такие дни. Запомни этот.',
      condition: 'Три записи за один день с оценкой 8 и выше',
      image: 'assets/achievements/perfect_day.png',
    ),
    Achievement(
      id: 'consistency',
      name: 'Постоянство',
      description: 'Семь дней. Незаметно стало привычкой.',
      condition: 'Запись каждый день в течение 7 дней подряд',
      image: 'assets/achievements/consistency.png',
    ),
    Achievement(
      id: 'almost_tradition',
      name: 'Почти традиция',
      description: 'Месяц. Не каждый дневник столько живёт.',
      condition: 'Записи в 30 разных днях за последний месяц',
      image: 'assets/achievements/almost_tradition.png',
    ),
    Achievement(
      id: 'return',
      name: 'Молчание золото',
      description: 'Был перерыв. Хорошо, что ты вернулся.',
      condition: 'Запись после перерыва в 3 дня и больше',
      image: 'assets/achievements/return.png',
    ),
    Achievement(
      id: 'grounded',
      name: 'Земля под ногами',
      description: 'Ты сделал паузу и вернулся в тело. Этого достаточно.',
      condition: 'Полностью пройти практику заземления',
      image: 'assets/achievements/grounded.png',
    ),
  ];

  static Achievement byId(String id) => all.firstWhere((a) => a.id == id);
}

/// Tracks which achievements were unlocked and when (ISO date).
class AchievementsStorage {
  static const _prefix = 'achievement_';

  static Future<bool> isUnlocked(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix$id');
  }

  static Future<void> unlock(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$id',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<Map<String, DateTime>> getAllUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, DateTime>{};
    for (final a in AchievementsCatalog.all) {
      final s = prefs.getString('$_prefix${a.id}');
      if (s != null) {
        result[a.id] = DateTime.tryParse(s) ?? DateTime.now();
      }
    }
    return result;
  }
}

/// Pure logic: given the current state, returns the IDs that should be
/// unlocked (and aren't yet). The caller persists + shows the dialog.
class AchievementsChecker {
  /// Call after a new entry was inserted into [allEntries].
  /// [allEntries] must already include the new entry.
  static Future<List<String>> checkAfterEntry(
    DiaryEntry newEntry,
    List<DiaryEntry> allEntries,
  ) async {
    final unlocked = <String>[];

    Future<void> tryUnlock(String id, bool condition) async {
      if (!condition) return;
      if (await AchievementsStorage.isUnlocked(id)) return;
      unlocked.add(id);
    }

    // first_step
    await tryUnlock('first_step', allEntries.length == 1);

    // night_owl
    final h = newEntry.date.hour;
    await tryUnlock('night_owl', h >= 0 && h < 4);

    // perfect_day: 3 entries today with score >= 8
    final today = _dayKey(newEntry.date);
    final todayHigh = allEntries.where((e) {
      return _dayKey(e.date) == today && (e.analysis?.score ?? 0) >= 8;
    }).length;
    await tryUnlock('perfect_day', todayHigh >= 3);

    // consistency: entries on each of last 7 calendar days (incl. today)
    await tryUnlock('consistency', _hasStreak(allEntries, 7));

    // almost_tradition: 30 distinct days within the last 30 days
    await tryUnlock('almost_tradition', _distinctDaysInWindow(allEntries, 30) >= 30);

    // return: previous entry was 3+ days ago
    final prev = _previousEntry(newEntry, allEntries);
    if (prev != null) {
      final gap = newEntry.date.difference(prev.date).inDays;
      await tryUnlock('return', gap >= 3);
    }

    return unlocked;
  }

  static Future<List<String>> checkAfterGrounding() async {
    if (await AchievementsStorage.isUnlocked('grounded')) return [];
    return ['grounded'];
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _hasStreak(List<DiaryEntry> entries, int days) {
    final keys = entries.map((e) => _dayKey(e.date)).toSet();
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final d = today.subtract(Duration(days: i));
      if (!keys.contains(_dayKey(d))) return false;
    }
    return true;
  }

  static int _distinctDaysInWindow(List<DiaryEntry> entries, int windowDays) {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final keys = <String>{};
    for (final e in entries) {
      if (e.date.isAfter(cutoff)) keys.add(_dayKey(e.date));
    }
    return keys.length;
  }

  static DiaryEntry? _previousEntry(DiaryEntry current, List<DiaryEntry> all) {
    DiaryEntry? best;
    for (final e in all) {
      if (e.id == current.id) continue;
      if (e.date.isAfter(current.date)) continue;
      if (best == null || e.date.isAfter(best.date)) best = e;
    }
    return best;
  }
}
