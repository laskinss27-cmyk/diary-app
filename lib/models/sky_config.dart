/// Tunable parameters for one weather state of the mood sky. Clouds are
/// generated procedurally from these (count + size/height ranges) so the
/// Sky Studio needs only a handful of sliders instead of per-cloud knobs.
class SkyWeatherConfig {
  final int cloudCount;
  final double sizeMin;
  final double sizeMax;
  final double topMin; // fraction of card height
  final double topMax;
  final double cloudOpacity;
  final double sunOpacity; // ignored for rain-vs-clear by caller if needed
  final int rainDrops; // 0 = no rain
  final double gloom; // 0..1 sky darkening

  const SkyWeatherConfig({
    required this.cloudCount,
    required this.sizeMin,
    required this.sizeMax,
    required this.topMin,
    required this.topMax,
    this.cloudOpacity = 0.92,
    this.sunOpacity = 1.0,
    this.rainDrops = 0,
    this.gloom = 0.0,
  });

  SkyWeatherConfig copyWith({
    int? cloudCount,
    double? sizeMin,
    double? sizeMax,
    double? topMin,
    double? topMax,
    double? cloudOpacity,
    double? sunOpacity,
    int? rainDrops,
    double? gloom,
  }) =>
      SkyWeatherConfig(
        cloudCount: cloudCount ?? this.cloudCount,
        sizeMin: sizeMin ?? this.sizeMin,
        sizeMax: sizeMax ?? this.sizeMax,
        topMin: topMin ?? this.topMin,
        topMax: topMax ?? this.topMax,
        cloudOpacity: cloudOpacity ?? this.cloudOpacity,
        sunOpacity: sunOpacity ?? this.sunOpacity,
        rainDrops: rainDrops ?? this.rainDrops,
        gloom: gloom ?? this.gloom,
      );

  /// Dart-source line for pasting back as a new default.
  String toDartLiteral() => 'SkyWeatherConfig('
      'cloudCount: $cloudCount, '
      'sizeMin: ${sizeMin.round()}, sizeMax: ${sizeMax.round()}, '
      'topMin: ${topMin.toStringAsFixed(2)}, topMax: ${topMax.toStringAsFixed(2)}, '
      'cloudOpacity: ${cloudOpacity.toStringAsFixed(2)}, '
      'sunOpacity: ${sunOpacity.toStringAsFixed(2)}, '
      'rainDrops: $rainDrops, gloom: ${gloom.toStringAsFixed(2)})';
}

/// Defaults per weather. The Sky Studio edits copies of these; once Sergey
/// is happy he reads off the numbers and they get pasted here as the new
/// baked-in baseline.
class SkyDefaults {
  // The "first variant" Sergey liked — his art, sensible sizes. (We tried
  // wide-spread clouds + doubled sun + rain 43; too much. Reverted here.)
  static const sunny = SkyWeatherConfig(
    cloudCount: 1,
    sizeMin: 110,
    sizeMax: 130,
    topMin: 0.25,
    topMax: 0.35,
    cloudOpacity: 0.75,
    sunOpacity: 1.0,
  );

  static const partly = SkyWeatherConfig(
    cloudCount: 2,
    sizeMin: 116,
    sizeMax: 134,
    topMin: 0.14,
    topMax: 0.48,
    cloudOpacity: 0.9,
    sunOpacity: 0.95,
  );

  static const cloudy = SkyWeatherConfig(
    cloudCount: 5,
    sizeMin: 128,
    sizeMax: 170,
    topMin: 0.05,
    topMax: 0.52,
    cloudOpacity: 0.93,
    sunOpacity: 0.85,
    gloom: 0.18,
  );

  static const rain = SkyWeatherConfig(
    cloudCount: 4,
    sizeMin: 138,
    sizeMax: 178,
    topMin: 0.04,
    topMax: 0.40,
    cloudOpacity: 0.95,
    sunOpacity: 0.6,
    rainDrops: 34,
    gloom: 0.34,
  );

  /// Seconds for a cloud to cross the card once.
  static const cycleSeconds = 240;

  /// Sun diameter in px.
  static const celestialSize = 92.0;

  /// Moon diameter in px.
  static const moonSize = 56.0;
}
