import 'package:flutter/material.dart';
import '../main.dart';
import '../models/diary_entry.dart';
import '../services/achievements_service.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../widgets/achievement_unlock_dialog.dart';
import 'dart:ui';
import '../widgets/avatar_picker.dart';
import '../widgets/entry_section.dart';
import '../widgets/frosted_background.dart';
import '../widgets/gentle_crisis_dialog.dart';
import '../widgets/mood_vase.dart';
import '../widgets/welcome_banner.dart';
import '../services/update_service.dart';
import 'entry_screen.dart';
import 'settings_screen.dart';
import 'report_screen.dart';
import 'calendar_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DiaryEntry> _entries = [];

  String _userName = '';
  AvatarData _avatar = AvatarData.defaultAvatar;
  WelcomeContext? _welcomeContext;
  late final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loaded = await StorageService.loadEntries();
    final profile = await StorageService.loadProfile();
    final avatar = await StorageService.loadAvatar();
    WelcomeContext? ctx = _welcomeContext;
    final firstLoad = ctx == null;
    if (firstLoad) {
      final lastOpen = await StorageService.loadLastOpen();
      ctx = computeWelcomeContext(lastOpen, _openedAt);
      await StorageService.saveLastOpen(_openedAt);
    }
    setState(() {
      _entries = loaded;
      _userName = profile['name'] ?? '';
      _avatar = avatar;
      _welcomeContext = ctx;
    });
    if (firstLoad) _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update == null || !mounted) return;
    final t = DiaryApp.themeNotifier.theme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Доступно обновление',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Новая версия: ${update.version}\n\nТекущая: $kCurrentVersion',
          style: TextStyle(color: t.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Позже', style: TextStyle(color: t.textHint)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              UpdateService.openDownload(update.downloadUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewEntry() async {
    final result = await Navigator.push<DiaryEntry?>(
      context,
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
    if (result != null && mounted) {
      setState(() => _entries.insert(0, result));
      final unlocked =
          await AchievementsChecker.checkAfterEntry(result, _entries);
      if (_isCrisis(result) && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await GentleCrisisDialog.show(context);
      }
      if (unlocked.isNotEmpty && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        await AchievementUnlockDialog.showQueue(context, unlocked);
      }
    }
  }

  bool _isCrisis(DiaryEntry entry) {
    final a = entry.analysis;
    if (a == null) return false;
    if (a.score <= 1) return true;
    for (final k in a.keywords) {
      final low = k.toLowerCase();
      if (low.contains('кризис') ||
          low.contains('суицид') ||
          low.contains('самоповрежд')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteEntry(String id) async {
    await DatabaseService.deleteEntry(id);
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final grouped = _groupEntries(_entries);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
        backgroundColor: t.primary.withValues(alpha: 0.55),
        title: const Text(
          'Дневник',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded,
                color: Colors.white),
            tooltip: 'Если тебе тяжело',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Календарь',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Отчёт за неделю',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportScreen(entries: _entries),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Настройки',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
          ),
        ),
      ),
      body: FrostedBackground(
        theme: t,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              bottom: 100,
            ),
            children: [
              if (_welcomeContext != null)
                WelcomeBanner(
                  userName: _userName,
                  avatar: _avatar,
                  context: _welcomeContext!,
                  now: _openedAt,
                ),
              MoodVase(entries: _entries),
              const SizedBox(height: 8),
              if (_entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Здесь появятся твои записи',
                        style: TextStyle(color: t.textHint, fontSize: 15),
                      ),
                    ],
                  ),
                )
              else ...[
                if (grouped.today.isNotEmpty)
                  EntrySection(
                    title: 'Сегодня',
                    entries: grouped.today,
                    onDelete: _deleteEntry,
                  ),
                if (grouped.yesterday.isNotEmpty)
                  EntrySection(
                    title: 'Вчера',
                    entries: grouped.yesterday,
                    onDelete: _deleteEntry,
                  ),
                if (grouped.earlier.isNotEmpty)
                  EntrySection(
                    title: 'Ранее',
                    entries: grouped.earlier,
                    onDelete: _deleteEntry,
                  ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _WriteButton(onPressed: _openNewEntry, theme: t),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  _GroupedEntries _groupEntries(List<DiaryEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final List<DiaryEntry> t = [];
    final List<DiaryEntry> y = [];
    final List<DiaryEntry> e = [];
    for (final entry in entries) {
      final d = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (d == today) {
        t.add(entry);
      } else if (d == yesterday) {
        y.add(entry);
      } else {
        e.add(entry);
      }
    }
    return _GroupedEntries(today: t, yesterday: y, earlier: e);
  }
}

class _GroupedEntries {
  final List<DiaryEntry> today;
  final List<DiaryEntry> yesterday;
  final List<DiaryEntry> earlier;
  _GroupedEntries({
    required this.today,
    required this.yesterday,
    required this.earlier,
  });
}

class _WriteButton extends StatelessWidget {
  final VoidCallback onPressed;
  final dynamic theme;
  const _WriteButton({required this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final p = t.primary as Color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Material(
          color: Colors.transparent,
          shadowColor: p.withValues(alpha: 0.55),
          elevation: 10,
          borderRadius: BorderRadius.circular(29),
          child: InkWell(
            borderRadius: BorderRadius.circular(29),
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(p, Colors.white, 0.18)!,
                    p,
                  ],
                ),
                borderRadius: BorderRadius.circular(29),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Написать',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
