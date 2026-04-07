import 'package:flutter/material.dart';

class AppThemeData {
  final String id;
  final String name;
  final String emoji;
  final Color primary;
  final Color accent;
  final Color background;
  final Color cardColor;
  final Color cardShadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Brightness brightness;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primary,
    required this.accent,
    required this.background,
    required this.cardColor,
    required this.cardShadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    this.brightness = Brightness.light,
  });
}

class AppThemes {
  static const String defaultThemeId = 'sakura';

  static const List<AppThemeData> all = [
    // Сакура — текущая розовая
    AppThemeData(
      id: 'sakura',
      name: 'Сакура',
      emoji: '🌸',
      primary: Color(0xFFE8A0BF),
      accent: Color(0xFFE94560),
      background: Color(0xFFFFF0F5),
      cardColor: Colors.white,
      cardShadow: Color(0xFFE8A0BF),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFFB56576),
      textHint: Color(0xFF9E9E9E),
    ),
    // Лаванда
    AppThemeData(
      id: 'lavender',
      name: 'Лаванда',
      emoji: '💜',
      primary: Color(0xFF9B8EC1),
      accent: Color(0xFF7B68AE),
      background: Color(0xFFF3F0FF),
      cardColor: Colors.white,
      cardShadow: Color(0xFF9B8EC1),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFF7B68AE),
      textHint: Color(0xFF9E9E9E),
    ),
    // Мята
    AppThemeData(
      id: 'mint',
      name: 'Мята',
      emoji: '🍃',
      primary: Color(0xFF7EC8A8),
      accent: Color(0xFF4DA67E),
      background: Color(0xFFF0FFF7),
      cardColor: Colors.white,
      cardShadow: Color(0xFF7EC8A8),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFF4DA67E),
      textHint: Color(0xFF9E9E9E),
    ),
    // Закат
    AppThemeData(
      id: 'sunset',
      name: 'Закат',
      emoji: '🌅',
      primary: Color(0xFFE8956A),
      accent: Color(0xFFD4654A),
      background: Color(0xFFFFF5F0),
      cardColor: Colors.white,
      cardShadow: Color(0xFFE8956A),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFFD4654A),
      textHint: Color(0xFF9E9E9E),
    ),
    // Океан
    AppThemeData(
      id: 'ocean',
      name: 'Океан',
      emoji: '🌊',
      primary: Color(0xFF6BA3BE),
      accent: Color(0xFF3D7A99),
      background: Color(0xFFF0F7FF),
      cardColor: Colors.white,
      cardShadow: Color(0xFF6BA3BE),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFF3D7A99),
      textHint: Color(0xFF9E9E9E),
    ),
    // Роза
    AppThemeData(
      id: 'rose',
      name: 'Роза',
      emoji: '🌹',
      primary: Color(0xFFD4728C),
      accent: Color(0xFFC44569),
      background: Color(0xFFFFF0F3),
      cardColor: Colors.white,
      cardShadow: Color(0xFFD4728C),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFFC44569),
      textHint: Color(0xFF9E9E9E),
    ),
    // Ночь
    AppThemeData(
      id: 'night',
      name: 'Ночь',
      emoji: '🌙',
      primary: Color(0xFF5C6BC0),
      accent: Color(0xFFFFAB91),
      background: Color(0xFF1A1A2E),
      cardColor: Color(0xFF2A2A3E),
      cardShadow: Color(0xFF000000),
      textPrimary: Color(0xFFE0E0E0),
      textSecondary: Color(0xFFFFAB91),
      textHint: Color(0xFF757575),
      brightness: Brightness.dark,
    ),
    // Карамель
    AppThemeData(
      id: 'caramel',
      name: 'Карамель',
      emoji: '🍯',
      primary: Color(0xFFD4A574),
      accent: Color(0xFFB8834A),
      background: Color(0xFFFFF8F0),
      cardColor: Colors.white,
      cardShadow: Color(0xFFD4A574),
      textPrimary: Color(0xFF4A4A4A),
      textSecondary: Color(0xFFB8834A),
      textHint: Color(0xFF9E9E9E),
    ),
  ];

  static AppThemeData getById(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
