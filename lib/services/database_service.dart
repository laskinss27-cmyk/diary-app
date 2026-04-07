import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/diary_entry.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'diary.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            date TEXT NOT NULL,
            mood TEXT NOT NULL,
            analysis TEXT,
            photo_paths TEXT
          )
        ''');
        debugPrint('Database created v$version');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE entries ADD COLUMN photo_paths TEXT');
          debugPrint('Database upgraded to v$newVersion');
        }
      },
    );
  }

  // --- Entries ---

  static Future<List<DiaryEntry>> loadEntries() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'date DESC');
    return maps.map((m) => _entryFromMap(m)).toList();
  }

  static Future<List<DiaryEntry>> loadEntriesForDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => _entryFromMap(m)).toList();
  }

  static Future<Map<DateTime, int>> loadEntryCounts(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'entries',
      columns: ['date'],
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
    );

    final counts = <DateTime, int>{};
    for (final m in maps) {
      final date = DateTime.parse(m['date'] as String);
      final day = DateTime(date.year, date.month, date.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  static Future<void> insertEntry(DiaryEntry entry) async {
    final db = await database;
    await db.insert('entries', _entryToMap(entry),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateEntry(DiaryEntry entry) async {
    final db = await database;
    await db.update('entries', _entryToMap(entry),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  static Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> importEntries(List<DiaryEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('entries', _entryToMap(entry),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
    debugPrint('Imported ${entries.length} entries');
  }

  // --- Helpers ---

  static Map<String, dynamic> _entryToMap(DiaryEntry entry) => {
        'id': entry.id,
        'text': entry.text,
        'date': entry.date.toIso8601String(),
        'mood': entry.mood,
        'analysis': entry.analysis != null ? jsonEncode(entry.analysis!.toJson()) : null,
        'photo_paths': entry.photoPaths.isNotEmpty ? jsonEncode(entry.photoPaths) : null,
      };

  static DiaryEntry _entryFromMap(Map<String, dynamic> map) {
    MoodAnalysis? analysis;
    if (map['analysis'] != null) {
      try {
        analysis = MoodAnalysis.fromJson(
            jsonDecode(map['analysis'] as String) as Map<String, dynamic>);
      } catch (_) {}
    }

    List<String> photoPaths = [];
    if (map['photo_paths'] != null) {
      try {
        photoPaths = List<String>.from(
            jsonDecode(map['photo_paths'] as String) as List);
      } catch (_) {}
    }

    return DiaryEntry(
      id: map['id'] as String,
      text: map['text'] as String,
      date: DateTime.parse(map['date'] as String),
      mood: map['mood'] as String,
      analysis: analysis,
      photoPaths: photoPaths,
    );
  }
}
