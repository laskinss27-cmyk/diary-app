import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/sky_config.dart';
import '../widgets/mood_sky.dart';

/// Sky Studio: live preview on top, sliders below. Pick a weather and a
/// time of day, tune the clouds/rain/gloom, then "Скопировать настройки" —
/// the numbers are shown and copied so they can be pasted into SkyDefaults
/// as the new baseline. Opened by long-pressing the sky card.
class SkyStudioScreen extends StatefulWidget {
  const SkyStudioScreen({super.key});

  @override
  State<SkyStudioScreen> createState() => _SkyStudioScreenState();
}

class _SkyStudioScreenState extends State<SkyStudioScreen> {
  SkyWeather _weather = SkyWeather.cloudy;
  DayPhase _phase = DayPhase.day;

  late final Map<SkyWeather, SkyWeatherConfig> _cfg = {
    for (final w in SkyWeather.values) w: defaultConfigFor(w),
  };

  SkyWeatherConfig get _current => _cfg[_weather]!;
  void _update(SkyWeatherConfig c) => setState(() => _cfg[_weather] = c);

  static const _weatherNames = {
    SkyWeather.sunny: 'Ясно',
    SkyWeather.partly: 'Малооблачно',
    SkyWeather.cloudy: 'Облачно',
    SkyWeather.rain: 'Дождь',
  };
  static const _phaseNames = {
    DayPhase.morning: 'Утро',
    DayPhase.day: 'День',
    DayPhase.evening: 'Вечер',
    DayPhase.night: 'Ночь',
  };

  void _copy() {
    final c = _current;
    final text =
        '${_weatherNames[_weather]}:\n${c.toDartLiteral()}';
    Clipboard.setData(ClipboardData(text: text));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Настройки «${_weatherNames[_weather]}»'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скопировано ✓'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final c = _current;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: const Text('Мастерская неба'),
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Скопировать настройки',
            onPressed: _copy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Live preview
          SkyView(
            key: ValueKey('$_weather-$_phase-${c.hashCode}'),
            weather: _weather,
            phase: _phase,
            config: c,
            height: 150,
          ),
          const SizedBox(height: 16),
          _chips<SkyWeather>(
            'Погода',
            SkyWeather.values,
            _weather,
            (v) => _weatherNames[v]!,
            (v) => setState(() => _weather = v),
            t,
          ),
          const SizedBox(height: 8),
          _chips<DayPhase>(
            'Время суток',
            DayPhase.values,
            _phase,
            (v) => _phaseNames[v]!,
            (v) => setState(() => _phase = v),
            t,
          ),
          const Divider(height: 28),
          _slider('Количество облаков', c.cloudCount.toDouble(), 0, 8,
              divisions: 8,
              label: '${c.cloudCount}',
              onChanged: (v) => _update(c.copyWith(cloudCount: v.round()))),
          _slider('Размер: минимум', c.sizeMin, 60, 220,
              label: c.sizeMin.round().toString(),
              onChanged: (v) => _update(c.copyWith(
                  sizeMin: v, sizeMax: v > c.sizeMax ? v : c.sizeMax))),
          _slider('Размер: максимум', c.sizeMax, 60, 240,
              label: c.sizeMax.round().toString(),
              onChanged: (v) => _update(c.copyWith(
                  sizeMax: v, sizeMin: v < c.sizeMin ? v : c.sizeMin))),
          _slider('Высота: верх', c.topMin, -0.1, 0.6,
              label: c.topMin.toStringAsFixed(2),
              onChanged: (v) => _update(c.copyWith(topMin: v))),
          _slider('Высота: низ', c.topMax, 0.0, 0.8,
              label: c.topMax.toStringAsFixed(2),
              onChanged: (v) => _update(c.copyWith(topMax: v))),
          _slider('Плотность облаков', c.cloudOpacity, 0.3, 1.0,
              label: c.cloudOpacity.toStringAsFixed(2),
              onChanged: (v) => _update(c.copyWith(cloudOpacity: v))),
          _slider('Яркость солнца', c.sunOpacity, 0.0, 1.0,
              label: c.sunOpacity.toStringAsFixed(2),
              onChanged: (v) => _update(c.copyWith(sunOpacity: v))),
          _slider('Пасмурность неба', c.gloom, 0.0, 0.7,
              label: c.gloom.toStringAsFixed(2),
              onChanged: (v) => _update(c.copyWith(gloom: v))),
          _slider('Капли дождя', c.rainDrops.toDouble(), 0, 80,
              divisions: 80,
              label: '${c.rainDrops}',
              onChanged: (v) => _update(c.copyWith(rainDrops: v.round()))),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('Показать / скопировать настройки'),
            style: FilledButton.styleFrom(backgroundColor: t.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Подбери для каждой погоды отдельно, нажми «Скопировать» и пришли '
            'мне числа — я вошью их как стандартные.',
            style: TextStyle(color: t.textHint, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chips<E>(String label, List<E> values, E selected,
      String Function(E) name, void Function(E) onTap, dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: t.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: values.map((v) {
            final sel = v == selected;
            return GestureDetector(
              onTap: () => onTap(v),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? t.primary
                      : t.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  name(v),
                  style: TextStyle(
                    color: sel ? Colors.white : t.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _slider(String title, double value, double min, double max,
      {required ValueChanged<double> onChanged,
      String? label,
      int? divisions}) {
    final t = DiaryApp.themeNotifier.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(color: t.textPrimary, fontSize: 13)),
            Text(label ?? value.toStringAsFixed(2),
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: t.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
