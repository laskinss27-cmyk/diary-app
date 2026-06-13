import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/sky_config.dart';
import '../screens/sky_studio_screen.dart';

/// Animated sky card built from Sergey's art (assets/sky). Weather mirrors
/// the latest entry's mood; palette follows the real time of day. Clouds
/// are generated procedurally from a [SkyWeatherConfig] (count + size and
/// height ranges) so the Sky Studio can tune everything with a few sliders.
/// Long-press the card to open the studio.
enum SkyWeather { sunny, partly, cloudy, rain }

enum DayPhase { morning, day, evening, night }

SkyWeather computeWeather(List<DiaryEntry> entries) {
  if (entries.isEmpty) return SkyWeather.partly;
  final score = entries.first.analysis?.score ?? 5;
  if (score >= 8) return SkyWeather.sunny;
  if (score >= 6) return SkyWeather.partly;
  if (score >= 4) return SkyWeather.cloudy;
  return SkyWeather.rain;
}

DayPhase phaseForHour(int hour) {
  if (hour >= 6 && hour < 11) return DayPhase.morning;
  if (hour >= 11 && hour < 17) return DayPhase.day;
  if (hour >= 17 && hour < 22) return DayPhase.evening;
  return DayPhase.night;
}

SkyWeatherConfig defaultConfigFor(SkyWeather w) => switch (w) {
      SkyWeather.sunny => SkyDefaults.sunny,
      SkyWeather.partly => SkyDefaults.partly,
      SkyWeather.cloudy => SkyDefaults.cloudy,
      SkyWeather.rain => SkyDefaults.rain,
    };

class MoodSky extends StatefulWidget {
  final List<DiaryEntry> entries;
  const MoodSky({super.key, required this.entries});

  @override
  State<MoodSky> createState() => _MoodSkyState();
}

class _MoodSkyState extends State<MoodSky> {
  @override
  Widget build(BuildContext context) {
    final weather = computeWeather(widget.entries);
    final phase = phaseForHour(DateTime.now().hour);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SkyStudioScreen()),
        ),
        child: SkyView(
          weather: weather,
          phase: phase,
          config: defaultConfigFor(weather),
        ),
      ),
    );
  }
}

/// The actual rendered sky. Stateless w.r.t. its inputs so the Sky Studio
/// can drive it live with arbitrary weather/phase/config.
class SkyView extends StatefulWidget {
  final SkyWeather weather;
  final DayPhase phase;
  final SkyWeatherConfig config;
  final double height;
  const SkyView({
    super.key,
    required this.weather,
    required this.phase,
    required this.config,
    this.height = 124,
  });

  @override
  State<SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<SkyView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: SkyDefaults.cycleSeconds),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Stable pseudo-random in 0..1 per (index, salt).
  double _rand(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.phase == DayPhase.night;
    final cfg = widget.config;

    final ColorFilter? cloudTint = widget.weather == SkyWeather.rain
        ? ColorFilter.mode(
            night ? const Color(0xFF4A4A5E) : const Color(0xFF8C97A6),
            BlendMode.modulate)
        : (night
            ? const ColorFilter.mode(Color(0xFF6E6E86), BlendMode.modulate)
            : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: night ? 0.18 : 0.5),
            width: 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = _ctrl.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _SkyBackPainter(
                          phase: widget.phase, gloom: cfg.gloom, t: t),
                    ),
                    _celestial(night, cfg, t, w, h),
                    ..._clouds(cfg, cloudTint, t, w, h),
                    if (cfg.rainDrops > 0)
                      CustomPaint(
                        painter: _RainPainter(
                            t: t, night: night, drops: cfg.rainDrops),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _celestial(bool night, SkyWeatherConfig cfg, double t, double w,
      double h) {
    final cx = w - 52;
    final cy = h * 0.34;
    if (night) {
      final bob = 2.5 * math.sin(t * 2 * math.pi * 2);
      final m = SkyDefaults.moonSize;
      return Positioned(
        left: cx - m / 2,
        top: cy - m / 2 + bob,
        child: Image.asset('assets/sky/moon.png',
            width: m, height: m, fit: BoxFit.contain),
      );
    }
    final pulse = 1 + 0.04 * math.sin(t * 2 * math.pi * 24);
    final size = SkyDefaults.celestialSize;
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      child: Opacity(
        opacity: cfg.sunOpacity,
        child: Transform.scale(
          scale: pulse,
          child: Image.asset('assets/sky/sun.png',
              width: size, height: size, fit: BoxFit.contain),
        ),
      ),
    );
  }

  List<Widget> _clouds(
      SkyWeatherConfig cfg, ColorFilter? tint, double t, double w, double h) {
    final n = cfg.cloudCount;
    final clouds = <Widget>[];
    for (int i = 0; i < n; i++) {
      final cw = cfg.sizeMin + _rand(i, 1) * (cfg.sizeMax - cfg.sizeMin);
      final topFrac = cfg.topMin + _rand(i, 2) * (cfg.topMax - cfg.topMin);
      final asset = i.isEven ? 'cloud1' : 'cloud2';
      // Evenly phased + shared speed = a steady caravan, never a gap.
      final ph = (t + (n == 0 ? 0 : i / n)) % 1.0;
      final x = ph * (w + cw * 2) - cw;
      Widget img = Image.asset('assets/sky/$asset.png', width: cw);
      if (tint != null) img = ColorFiltered(colorFilter: tint, child: img);
      clouds.add(Positioned(
        left: x,
        top: h * topFrac,
        child: Opacity(opacity: cfg.cloudOpacity, child: img),
      ));
    }
    return clouds;
  }
}

class _SkyBackPainter extends CustomPainter {
  final DayPhase phase;
  final double gloom;
  final double t;

  _SkyBackPainter({required this.phase, required this.gloom, required this.t});

  static const _palettes = {
    DayPhase.morning: (Color(0xFFFFD9A8), Color(0xFFBFE8F5)),
    DayPhase.day: (Color(0xFF8EC9F0), Color(0xFFDCF1FB)),
    DayPhase.evening: (Color(0xFFC9A8E8), Color(0xFFFFC9A8)),
    DayPhase.night: (Color(0xFF2B2B52), Color(0xFF4A4A7A)),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final night = phase == DayPhase.night;

    var (top, bottom) = _palettes[phase]!;
    if (gloom > 0) {
      final grey = night ? const Color(0xFF26263A) : const Color(0xFFA8B2BD);
      top = Color.lerp(top, grey, gloom)!;
      bottom = Color.lerp(bottom, grey, gloom)!;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    if (night) {
      const stars = 18;
      for (int i = 0; i < stars; i++) {
        final x = (i * 137 % 100) / 100 * w;
        final y = (i * 71 % 55) / 100 * h;
        final tw = 0.45 + 0.45 * math.sin(t * 2 * math.pi * 48 + i * 1.7);
        canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : 1.0,
            Paint()..color = Colors.white.withValues(alpha: tw));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyBackPainter old) =>
      old.t != t || old.phase != phase || old.gloom != gloom;
}

/// Soft scattered rain: each drop has its own column, length, speed and
/// opacity, so it reads as falling rain, not a marching row of dashes.
class _RainPainter extends CustomPainter {
  final double t;
  final bool night;
  final int drops;

  _RainPainter({required this.t, required this.night, required this.drops});

  double _rand(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = night ? const Color(0xFFAFC2E8) : const Color(0xFF8AA2C4);
    for (int i = 0; i < drops; i++) {
      final x = _rand(i, 1) * w;
      final len = 6 + _rand(i, 2) * 9;
      final speed = 60 + _rand(i, 3) * 80;
      final alpha = 0.25 + _rand(i, 4) * 0.4;
      final phase = (t * speed + _rand(i, 5)) % 1.0;
      final y = phase * (h + len * 2) - len;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.2, y + len),
        Paint()
          ..color = base.withValues(alpha: alpha)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => old.t != t;
}
