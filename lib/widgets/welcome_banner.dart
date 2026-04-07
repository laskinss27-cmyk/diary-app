import 'package:flutter/material.dart';
import '../main.dart';
import 'avatar_picker.dart';

/// How long ago the user was last seen — drives the subtitle phrasing.
enum WelcomeContext {
  firstTime, // never opened before (after onboarding)
  sameDay, // already opened earlier today
  yesterday, // opened yesterday
  fewDays, // 2-6 days ago
  weekPlus, // 7-29 days ago
  longAbsence, // 30+ days ago
}

WelcomeContext computeWelcomeContext(DateTime? lastOpen, DateTime now) {
  if (lastOpen == null) return WelcomeContext.firstTime;
  final lastDay = DateTime(lastOpen.year, lastOpen.month, lastOpen.day);
  final today = DateTime(now.year, now.month, now.day);
  final diffDays = today.difference(lastDay).inDays;
  if (diffDays <= 0) return WelcomeContext.sameDay;
  if (diffDays == 1) return WelcomeContext.yesterday;
  if (diffDays <= 6) return WelcomeContext.fewDays;
  if (diffDays <= 29) return WelcomeContext.weekPlus;
  return WelcomeContext.longAbsence;
}

/// Time-of-day part: "Доброе утро", "Добрый день", etc.
String _timeOfDayPart(int hour) {
  if (hour < 6) return 'Доброй ночи';
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  return 'Добрый вечер';
}

/// Pick a stable-per-day variant from a list, so the user sees the same
/// phrase if they open the app twice in one day, but a different one tomorrow.
String _stablePick(List<String> options, DateTime now, int salt) {
  final dayKey = now.year * 10000 + now.month * 100 + now.day;
  final idx = (dayKey + salt).abs() % options.length;
  return options[idx];
}

String buildGreetingHeadline(String userName, DateTime now) {
  final base = _timeOfDayPart(now.hour);
  if (userName.trim().isEmpty) return '$base!';
  return '$base, $userName';
}

String buildGreetingSubtitle(WelcomeContext ctx, DateTime now) {
  switch (ctx) {
    case WelcomeContext.firstTime:
      return _stablePick([
        'Это твоё пространство. Здесь можно говорить честно.',
        'Начнём с малого — одной записи.',
        'Здесь нет правильных ответов. Просто пиши, как есть.',
      ], now, 1);
    case WelcomeContext.sameDay:
      return _stablePick([
        'Снова здесь. Что-то ещё на душе?',
        'Ещё одна мысль? Я слушаю.',
        'Что изменилось с прошлого раза?',
        'Бывает, что одной записи на день мало.',
      ], now, 2);
    case WelcomeContext.yesterday:
      return _stablePick([
        'С возвращением. Как ты сегодня?',
        'Рад снова тебя видеть. Расскажешь, как дела?',
        'Новый день — новая страница.',
        'Хорошо, что зашёл. Как себя чувствуешь?',
      ], now, 3);
    case WelcomeContext.fewDays:
      return _stablePick([
        'Несколько дней тебя не было. Как ты?',
        'Рад, что ты снова здесь. Что хочешь рассказать?',
        'Многое могло измениться. Поделишься?',
      ], now, 4);
    case WelcomeContext.weekPlus:
      return _stablePick([
        'Давно не виделись. Я тебя помню.',
        'Прошла неделя. Как ты её прожил?',
        'Хорошо, что вернулся. Без оценок и спешки.',
      ], now, 5);
    case WelcomeContext.longAbsence:
      return _stablePick([
        'Давно тебя не было. Это нормально. Я здесь.',
        'С возвращением. Что бы ни было — место для тебя осталось.',
        'Месяц — это много. Как ты сейчас?',
      ], now, 6);
  }
}

/// A warm, animated welcome card that appears at the top of the home screen.
/// Slides down + fades in once on app launch, then stays as a permanent header.
class WelcomeBanner extends StatefulWidget {
  final String userName;
  final AvatarData avatar;
  final WelcomeContext context;
  final DateTime now;

  const WelcomeBanner({
    super.key,
    required this.userName,
    required this.avatar,
    required this.context,
    required this.now,
  });

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Tiny delay so the fade is noticeable on cold start.
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final headline = buildGreetingHeadline(widget.userName, widget.now);
    final subtitle = buildGreetingSubtitle(widget.context, widget.now);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                t.primary.withValues(alpha: 0.18),
                t.primary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: t.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarWidget(data: widget.avatar, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
