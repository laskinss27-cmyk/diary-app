import 'package:flutter/material.dart';
import '../main.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Animated splash shown right after the native splash hands off to Flutter.
/// Reuses the same icon + background colour as the native splash so the
/// transition is seamless. Adds the slogan, a soft progress indicator,
/// and preloads data while the user reads.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _sloganFade;
  late final Animation<double> _progressFade;

  // Keeps the splash visible at least this long, even on a fast device,
  // so the user actually has a moment to read the slogan.
  static const Duration _minVisible = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Logo: fade + tiny scale-up (almost imperceptible, just "breath")
    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.00, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // Title appears next
    _titleFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.30, 0.70, curve: Curves.easeOut),
    );

    // Slogan last — softest fade so it feels gentle, not punchy
    _sloganFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );

    // Progress indicator follows the slogan
    _progressFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.70, 1.00, curve: Curves.easeOut),
    );

    _entryCtrl.forward();
    _start();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final stopwatch = Stopwatch()..start();

    // Preload everything the home screen will need so the transition
    // afterwards feels instant.
    bool onboarded = false;
    try {
      await StorageService.migrateIfNeeded();
      onboarded = await StorageService.isOnboarded();
      // Touch the database/profile/avatar so the OS file caches are warm.
      await StorageService.loadProfile();
      await StorageService.loadAvatar();
      await StorageService.loadEntries();
    } catch (_) {
      // Errors here aren't fatal — let the home screen handle them.
    }

    // Hold the splash for at least _minVisible total.
    final elapsed = stopwatch.elapsed;
    if (elapsed < _minVisible) {
      await Future.delayed(_minVisible - elapsed);
    }

    if (!mounted) return;

    // Fade out into the next screen with a soft cross-fade.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, a, b) => onboarded
            ? const HomeScreen()
            : OnboardingScreen(
                onComplete: () {
                  // After onboarding, replace with home.
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),
        transitionsBuilder: (_, animation, a, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final isDark = t.brightness == Brightness.dark;

    // Same colours the native splash uses, so the handoff is seamless.
    final bg = isDark ? const Color(0xFF1A1520) : const Color(0xFFFFF0F5);
    final titleColor = isDark ? Colors.white : const Color(0xFF3A2A35);
    final sloganColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF7A6470);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Logo with fade + soft scale
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: t.primary.withValues(alpha: 0.18),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'flat/Иконка.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Title
              FadeTransition(
                opacity: _titleFade,
                child: Text(
                  'Дневник',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Slogan — gentle, with extra letter spacing so it doesn't read
              // as a legal disclaimer
              FadeTransition(
                opacity: _sloganFade,
                child: Text(
                  'Твои мысли — только твои',
                  style: TextStyle(
                    color: sloganColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.6,
                    height: 1.3,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              // Soft progress indicator
              FadeTransition(
                opacity: _progressFade,
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: t.primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      t.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
