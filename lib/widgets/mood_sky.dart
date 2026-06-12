import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';

/// Animated sky card built from Sergey's art (assets/sky): the weather
/// mirrors the latest entry's mood, the palette follows the real time of
/// day. Clouds drift seamlessly, the sun breathes, rain falls softly,
/// stars twinkle at night. Gradient, stars and rain are painted; sun,
/// moon and clouds are images.
enum SkyWeather { dawn, sunny, partly, cloudy, rain }

enum DayPhase { morning, day, evening, night }

SkyWeather computeWeather(List<DiaryEntry> entries) {
  if (entries.isEmpty) return SkyWeather.dawn;
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

/// (asset, laps per master cycle, vertical position, width, opacity)
typedef _CloudSpec = (String, int, double, double, double);

class MoodSky extends StatefulWidget {
  final List<DiaryEntry> entries;
  const MoodSky({super.key, required this.entries});

  @override
  State<MoodSky> createState() => _MoodSkyState();
}

class _MoodSkyState extends State<MoodSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // One long master cycle; every periodic motion inside uses an INTEGER
    // number of laps per cycle, otherwise it teleports on loop wrap.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 240),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _title(SkyWeather w, bool night) => switch (w) {
        SkyWeather.dawn => night ? 'Ночь перед рассветом' : 'Рассвет',
        SkyWeather.sunny => night ? 'Ясная ночь' : 'Солнечно',
        SkyWeather.partly =>
          night ? 'Луна за облачком' : 'Солнце за облачком',
        SkyWeather.cloudy => night ? 'Облачная ночь' : 'Облачно',
        SkyWeather.rain => night ? 'Ночной дождь' : 'Тихий дождь',
      };

  String _subtitle(SkyWeather w, bool night) => switch (w) {
        SkyWeather.dawn => 'Первая запись — первый луч.',
        SkyWeather.sunny => night
            ? 'Тихо, спокойно. Звёзды на месте.'
            : 'Внутри светло — пусть подольше.',
        SkyWeather.partly =>
          night ? 'Мягкая ночь.' : 'Спокойный, ровный день.',
        SkyWeather.cloudy => 'Небо ждёт, когда развиднеется.',
        SkyWeather.rain => 'Дождь заканчивается. Всегда.',
      };

  List<_CloudSpec> _cloudSpecs(SkyWeather w) => switch (w) {
        SkyWeather.sunny ||
        SkyWeather.dawn =>
          const [('cloud1', 1, 0.20, 104.0, 0.85)],
        SkyWeather.partly => const [
            ('cloud2', 1, 0.06, 148.0, 0.92),
            ('cloud1', 2, 0.44, 112.0, 0.95),
          ],
        SkyWeather.cloudy => const [
            ('cloud2', 1, 0.02, 168.0, 0.95),
            ('dark2', 2, 0.30, 150.0, 0.85),
            ('cloud1', 3, 0.52, 116.0, 0.92),
          ],
        SkyWeather.rain => const [
            ('dark2', 1, 0.02, 168.0, 0.92),
            ('dark1', 2, 0.18, 150.0, 0.95),
            ('dark2', 3, 0.42, 128.0, 0.80),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final weather = computeWeather(widget.entries);
    final phase = phaseForHour(DateTime.now().hour);
    final night = phase == DayPhase.night;
    final textColor = night ? Colors.white : const Color(0xFF3A4A5A);
    final subColor = night
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF3A4A5A).withValues(alpha: 0.7);
    // At night the white clouds get dimmed to grey by a dark tint.
    final nightTint = night ? Colors.black.withValues(alpha: 0.38) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 122,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: night ? 0.18 : 0.55),
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
                          weather: weather,
                          phase: phase,
                          t: t,
                        ),
                      ),
                      ..._celestial(weather, night, t, h),
                      ..._clouds(weather, night, nightTint, t, w, h),
                      if (weather == SkyWeather.rain)
                        CustomPaint(
                          painter: _RainPainter(t: t, night: night),
                        ),
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        right: 104,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(weather, night),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle(weather, night),
                              style: TextStyle(
                                color: subColor,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _celestial(
      SkyWeather weather, bool night, double t, double h) {
    final hasCelestial = weather == SkyWeather.sunny ||
        weather == SkyWeather.partly ||
        weather == SkyWeather.dawn;
    if (!hasCelestial) return const [];

    if (night) {
      // The moon floats very slightly (2 laps per cycle = 120 s period).
      final bob = 2.5 * math.sin(t * 2 * math.pi * 2);
      return [
        Positioned(
          right: 22,
          top: (weather == SkyWeather.dawn ? h - 38 : 12) + bob,
          child: Image.asset(
            'assets/sky/moon.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
          ),
        ),
      ];
    }

    // 24 laps per cycle = one soft breath every 10 seconds.
    final pulse = 1 + 0.04 * math.sin(t * 2 * math.pi * 24);
    final dawn = weather == SkyWeather.dawn;
    return [
      Positioned(
        right: dawn ? 28 : 14,
        top: dawn ? h - 46 : 4,
        child: Transform.scale(
          scale: pulse,
          child: Image.asset(
            'assets/sky/sun.png',
            width: dawn ? 96 : 88,
            height: dawn ? 96 : 88,
            fit: BoxFit.contain,
          ),
        ),
      ),
    ];
  }

  List<Widget> _clouds(SkyWeather weather, bool night, Color? nightTint,
      double t, double w, double h) {
    final specs = _cloudSpecs(weather);
    final clouds = <Widget>[];
    for (final (i, (asset, laps, topFrac, cw, opacity))
        in specs.indexed) {
      // INTEGER laps per master cycle — seamless loop, no teleports.
      final x = ((t * laps + i * 0.37) % 1.0) * (w + cw * 2) - cw;
      clouds.add(Positioned(
        left: x,
        top: h * topFrac,
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/sky/$asset.png',
            width: cw,
            color: nightTint,
            colorBlendMode: nightTint != null ? BlendMode.srcATop : null,
          ),
        ),
      ));
    }
    // Partly: one cloud parked over the sun/moon.
    if (weather == SkyWeather.partly) {
      clouds.add(Positioned(
        right: -8,
        top: h * 0.34,
        child: Opacity(
          opacity: 0.96,
          child: Image.asset(
            'assets/sky/cloud1.png',
            width: 116,
            color: nightTint,
            colorBlendMode: nightTint != null ? BlendMode.srcATop : null,
          ),
        ),
      ));
    }
    return clouds;
  }
}

class _SkyBackPainter extends CustomPainter {
  final SkyWeather weather;
  final DayPhase phase;
  final double t;

  _SkyBackPainter({required this.weather, required this.phase, required this.t});

  static const _palettes = {
    DayPhase.morning: (Color(0xFFFFD9A8), Color(0xFFBFE8F5)),
    DayPhase.day: (Color(0xFF9ED4F2), Color(0xFFDCF1FB)),
    DayPhase.evening: (Color(0xFFC9A8E8), Color(0xFFFFC9A8)),
    DayPhase.night: (Color(0xFF2B2B52), Color(0xFF4A4A7A)),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final night = phase == DayPhase.night;

    var (top, bottom) = _palettes[phase]!;
    final gloom = switch (weather) {
      SkyWeather.cloudy => 0.22,
      SkyWeather.rain => 0.38,
      _ => 0.0,
    };
    if (gloom > 0) {
      final grey = night ? const Color(0xFF26263A) : const Color(0xFF9FAAB5);
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
      const stars = 16;
      for (int i = 0; i < stars; i++) {
        final x = (i * 137 % 100) / 100 * w;
        final y = (i * 71 % 60) / 100 * h;
        // 48 laps per cycle = a twinkle every 5 seconds.
        final tw = 0.45 + 0.45 * math.sin(t * 2 * math.pi * 48 + i * 1.7);
        canvas.drawCircle(
          Offset(x, y),
          i % 3 == 0 ? 1.5 : 1.0,
          Paint()..color = Colors.white.withValues(alpha: tw),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyBackPainter old) =>
      old.t != t || old.weather != weather || old.phase != phase;
}

class _RainPainter extends CustomPainter {
  final double t;
  final bool night;

  _RainPainter({required this.t, required this.night});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final drop = Paint()
      ..color = (night ? const Color(0xFF8FA8D8) : const Color(0xFF7C96B8))
          .withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const drops = 14;
    for (int i = 0; i < drops; i++) {
      final x = (i * 73 % 100) / 100 * w;
      // 120 laps per cycle = a drop falls through in 2 seconds.
      final fall = ((t * 120 + i * 0.13) % 1.0);
      final y = fall * (h + 20) - 10;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 7), drop);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => old.t != t;
}
