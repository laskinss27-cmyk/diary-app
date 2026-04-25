import 'package:flutter/material.dart';
import '../main.dart';
import '../services/achievements_service.dart';
import '../widgets/achievement_unlock_dialog.dart';

/// Техника заземления 5-4-3-2-1.
///
/// Помогает вернуться в настоящий момент при тревоге, панике,
/// флешбэках, диссоциации. Последовательно задействует все пять
/// органов чувств:
///   5 вещей, которые видишь
///   4 вещи, которых можешь коснуться
///   3 звука, которые слышишь
///   2 запаха
///   1 вкус
///
/// Экран пассивный: показывает шаг, ждёт тап "Готово" — идёт дальше.
/// Никаких таймеров, никакого давления. Можно делать в своём темпе.
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _step = 0;

  static const _steps = [
    _Step(
      number: 5,
      sense: 'Зрение',
      instruction: 'Назови 5 вещей,\nкоторые ты видишь',
      hint: 'Оглядись вокруг. Это может быть что угодно — стена, рука, чашка.',
      icon: Icons.visibility_outlined,
    ),
    _Step(
      number: 4,
      sense: 'Осязание',
      instruction: 'Назови 4 вещи,\nкоторых ты касаешься',
      hint: 'Потрогай их. Почувствуй текстуру, температуру, вес.',
      icon: Icons.pan_tool_outlined,
    ),
    _Step(
      number: 3,
      sense: 'Слух',
      instruction: 'Назови 3 звука,\nкоторые ты слышишь',
      hint:
          'Прислушайся. Тиканье часов, шум машин, дыхание, гул холодильника.',
      icon: Icons.hearing_outlined,
    ),
    _Step(
      number: 2,
      sense: 'Обоняние',
      instruction: 'Назови 2 запаха',
      hint:
          'Вдохни медленно. Если не чувствуешь — вспомни два запаха, которые тебе нравятся.',
      icon: Icons.air_outlined,
    ),
    _Step(
      number: 1,
      sense: 'Вкус',
      instruction: 'Назови 1 вкус',
      hint:
          'Что ты ешь или пил недавно? Или просто вкус во рту прямо сейчас.',
      icon: Icons.restaurant_outlined,
    ),
  ];

  void _next() async {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      setState(() => _step = _steps.length);
      final unlocked = await AchievementsChecker.checkAfterGrounding();
      if (unlocked.isNotEmpty && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        await AchievementUnlockDialog.showQueue(context, unlocked);
      }
    }
  }

  void _restart() {
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final isFinished = _step >= _steps.length;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Заземление 5-4-3-2-1',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isFinished ? _buildFinished(t) : _buildStep(t, _steps[_step]),
        ),
      ),
    );
  }

  Widget _buildStep(dynamic t, _Step step) {
    return Column(
      children: [
        // Прогресс-точки
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_steps.length, (i) {
            final isActive = i == _step;
            final isDone = i < _step;
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? t.primary
                    : isDone
                        ? t.primary.withValues(alpha: 0.5)
                        : t.textHint.withValues(alpha: 0.3),
              ),
            );
          }),
        ),
        const Spacer(),

        // Большая цифра
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.primary.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              '${step.number}',
              style: TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w300,
                color: t.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Название органа чувств
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(step.icon, color: t.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              step.sense,
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Инструкция
        Text(
          step.instruction,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),

        // Подсказка
        Text(
          step.hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: t.textSecondary,
            height: 1.5,
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              _step < _steps.length - 1 ? 'Дальше' : 'Закончить',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'В своём темпе. Не торопись.',
          style: TextStyle(fontSize: 12, color: t.textHint),
        ),
      ],
    );
  }

  Widget _buildFinished(dynamic t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.primary.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.check_rounded, color: t.primary, size: 60),
        ),
        const SizedBox(height: 24),
        Text(
          'Ты здесь.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ты в настоящем моменте.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: t.textSecondary,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _restart,
            style: OutlinedButton.styleFrom(
              foregroundColor: t.primary,
              side: BorderSide(color: t.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Пройти ещё раз',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Вернуться',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step {
  final int number;
  final String sense;
  final String instruction;
  final String hint;
  final IconData icon;

  const _Step({
    required this.number,
    required this.sense,
    required this.instruction,
    required this.hint,
    required this.icon,
  });
}
