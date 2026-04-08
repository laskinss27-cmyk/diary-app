import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../widgets/avatar_picker.dart';
import 'database_service.dart';

class StorageService {
  static const _entriesKey = 'diary_entries';
  static const _apiKeyKey = 'gemini_api_key';
  static const _userNameKey = 'user_name';
  static const _userAgeKey = 'user_age';
  static const _userNoteKey = 'user_note';
  static const _userCityKey = 'user_city';
  static const _avatarKey = 'user_avatar';
  static const _themeKey = 'app_theme';
  static const _onboardedKey = 'onboarded';
  static const _migratedKey = 'migrated_to_db';
  static const _lastOpenKey = 'last_open_at';

  /// Migrate old SharedPreferences entries to SQLite (one-time)
  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final data = prefs.getString(_entriesKey);
    if (data != null && data.isNotEmpty) {
      try {
        final entries = DiaryEntry.decode(data);
        await DatabaseService.importEntries(entries);
        debugPrint('Migrated ${entries.length} entries to SQLite');
      } catch (e) {
        debugPrint('Migration error: $e');
      }
    }
    await prefs.setBool(_migratedKey, true);
  }

  // --- Entries (now via SQLite) ---

  static Future<List<DiaryEntry>> loadEntries() async {
    return DatabaseService.loadEntries();
  }

  static Future<void> saveEntry(DiaryEntry entry) async {
    await DatabaseService.insertEntry(entry);
  }

  static Future<void> deleteEntry(String id) async {
    await DatabaseService.deleteEntry(id);
  }

  // Keep for backward compat but unused
  static Future<void> saveEntries(List<DiaryEntry> entries) async {
    // No-op: individual saves via saveEntry now
  }

  // --- API Key ---

  static Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  // --- Profile ---

  static Future<Map<String, String>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_userNameKey) ?? '',
      'age': prefs.getString(_userAgeKey) ?? '',
      'note': prefs.getString(_userNoteKey) ?? '',
      'city': prefs.getString(_userCityKey) ?? '',
    };
  }

  static Future<void> saveProfile({
    required String name,
    required String age,
    required String note,
    String city = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userAgeKey, age);
    await prefs.setString(_userNoteKey, note);
    await prefs.setString(_userCityKey, city);
  }

  // --- Avatar ---

  static Future<AvatarData> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_avatarKey);
    if (data == null) return AvatarData.defaultAvatar;
    try {
      return AvatarData.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return AvatarData.defaultAvatar;
    }
  }

  static Future<void> saveAvatar(AvatarData avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, jsonEncode(avatar.toJson()));
  }

  // --- Theme ---

  static Future<String> loadThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'sakura';
  }

  static Future<void> saveThemeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, id);
  }

  // --- Onboarding ---

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  static Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  // --- Last open timestamp (for contextual greetings) ---

  /// Returns the last time the home screen was opened, or null if it's the
  /// very first launch after onboarding.
  static Future<DateTime?> loadLastOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastOpenKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> saveLastOpen(DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastOpenKey, when.millisecondsSinceEpoch);
  }
}
