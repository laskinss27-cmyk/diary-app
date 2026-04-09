import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// Техника дыхания 4-7-8 (доктор Эндрю Вейл).
///
/// Последовательность:
///   1. Вдох через нос — 4 секунды
///   2. Задержка дыхания — 7 секунд
///   3. Выдох через рот — 8 секунд
///   Повторить 4 цикла.
///
/// Физиологически снижает частоту сердечного ритма и активирует
/// парасимпатическую нервную систему. Помогает при острой тревоге
/// и панических атаках.
///
/// Экран ведёт пользователя визуально (расширение/сжатие круга)
/// и текстом. Мягкая вибрация на смене фаз, чтобы можно было
/// выполнять с закрытыми глазами.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

enum _Phase { inhale, hold, exhale, idle }

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalCycles = 4;
  static const int _inhaleSeconds = 4;
  static const int _holdSeconds = 7;
  static const int _exhaleSeconds = 8;

  late AnimationController _animController;
  late Animation<double> _sizeAnim;
  _Phase _phase = _Phase.idle;
  int _currentCycle = 0;
  int _secondsLeft = 0;
  Timer? _tickTimer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _inhaleSeconds),
    );
    _sizeAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _currentCycle = 1;
    });
    _runCycle();
  }

  void _stop() {
    _tickTimer?.cancel();
    _animController.stop();
    setState(() {
      _running = false;
      _phase = _Phase.idle;
      _currentCycle = 0;
      _secondsLeft = 0;
    });
  }

  Future<void> _runCycle() async {
    if (!_running || !mounted) return;

    // Inhale
    await _runPhase(
      phase: _Phase.inhale,
      seconds: _inhaleSeconds,
      animateTo: 1.0,
      animDuration: const Duration(seconds: _inhaleSeconds),
    );
    if (!_running || !mounted) return;

    // Hold
    await _runPhase(
      phase: _Phase.hold,
      seconds: _holdSeconds,
      animateTo: null,
    );
    if (!_running || !mounted) return;

    // Exhale
    await _runPhase(
      phase: _Phase.exhale,
      seconds: _exhaleSeconds,
      animateTo: 0.4,
      animDuration: const Duration(seconds: _exhaleSeconds),
    );
    if (!_running || !mounted) return;

    // Next cycle or finish
    if (_currentCycle >= _totalCycles) {
      _finish();
    } else {
      setState(() => _currentCycle++);
      _runCycle();
    }
  }

  Future<void> _runPhase({
    required _Phase phase,
    required int seconds,
    double? animateTo,
    Duration? animDuration,
  }) async {
    setState(() {
      _phase = phase;
      _secondsLeft = seconds;
    });
    HapticFeedback.lightImpact();

    if (animateTo != null && animDuration != null) {
      _animController.duration = animDuration;
      _animController.animateTo(animateTo);
    }

    final completer = Completer<void>();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_running || !mounted) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future;
  }

  void _finish() {
    _tickTimer?.cancel();
    setState(() {
      _running = false;
      _phase = _Phase.idle;
      _currentCycle = 0;
      _secondsLeft = 0;
    });
    HapticFeedback.mediumImpact();
  }

  String get _phaseText {
    switch (_phase) {
      case _Phase.inhale:
        return 'Вдох';
      case _Phase.hold:
        return 'Задержи';
      case _Phase.exhale:
        return 'Выдох';
      case _Phase.idle:
        return 'Готов?';
    }
  }

  String get _phaseHint {
    switch (_phase) {
      case _Phase.inhale:
        return 'Медленно через нос';
      case _Phase.hold:
        return 'Не дыши';
      case _Phase.exhale:
        return 'Через рот, со звуком';
      case _Phase.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Дыхание 4-7-8',
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
          child: Column(
            children: [
              // Цикл
              Text(
                _running
                    ? 'Цикл $_currentCycle из $_totalCycles'
                    : '4 цикла по ~19 секунд',
                style: TextStyle(
                  fontSize: 14,
                  color: t.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),

              // Анимированный круг
              AnimatedBuilder(
                animation: _sizeAnim,
                builder: (context, child) {
                  final scale = _sizeAnim.value;
                  return SizedBox(
                    width: 280,
                    height: 280,
                    child: Center(
                      child: Container(
                        width: 280 * scale,
                        height: 280 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              t.primary.withValues(alpha: 0.45),
                              t.primary.withValues(alpha: 0.12),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.primary.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _phaseText,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                              if (_running) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$_secondsLeft',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w300,
                                    color: t.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),
              SizedBox(
                height: 24,
                child: Text(
                  _phaseHint,
                  style: TextStyle(
                    fontSize: 14,
                    color: t.textSecondary,
                  ),
                ),
              ),

              const Spacer(),

              // Кнопка
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _running ? _stop : _start,
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
                    _running ? 'Остановить' : 'Начать',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _running
                    ? 'Следуй за кругом'
                    : 'Сядь удобно. Можно закрыть глаза.',
                style: TextStyle(fontSize: 12, color: t.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
