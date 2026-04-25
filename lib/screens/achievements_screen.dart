import 'package:flutter/material.dart';
import '../main.dart';
import '../services/achievements_service.dart';
import '../widgets/frosted_background.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Map<String, DateTime> _unlocked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await AchievementsStorage.getAllUnlocked();
    if (!mounted) return;
    setState(() {
      _unlocked = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final unlockedList = AchievementsCatalog.all
        .where((a) => _unlocked.containsKey(a.id))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: t.primary.withValues(alpha: 0.85),
        elevation: 0,
        title: const Text(
          'Мои достижения',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: FrostedBackground(
        theme: t,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : unlockedList.isEmpty
                ? _emptyState(t)
                : ListView.builder(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          12,
                      bottom: 24,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: unlockedList.length,
                    itemBuilder: (ctx, i) {
                      final a = unlockedList[i];
                      final date = _unlocked[a.id]!;
                      return _achievementTile(t, a, date);
                    },
                  ),
      ),
    );
  }

  Widget _emptyState(t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: t.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока пусто.\nДостижения появятся здесь, когда ты их получишь.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textHint,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementTile(t, Achievement a, DateTime date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: t.primary.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              a.image,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.condition,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Получено ${_formatDate(date)}',
                  style: TextStyle(
                    color: t.textHint,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}
