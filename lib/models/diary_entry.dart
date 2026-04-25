import 'dart:convert';

/// Where the analysis came from. Used by the reanalysis service to decide
/// whether an entry should be re-evaluated by the AI when the network comes
/// back online.
enum AnalysisSource { fast, lexicon, ai }

class MoodAnalysis {
  final String emoji;
  final int score;
  final List<String> keywords;
  final String brief;
  final AnalysisSource source;

  const MoodAnalysis({
    required this.emoji,
    required this.score,
    required this.keywords,
    required this.brief,
    this.source = AnalysisSource.lexicon,
  });

  MoodAnalysis copyWith({AnalysisSource? source}) => MoodAnalysis(
        emoji: emoji,
        score: score,
        keywords: keywords,
        brief: brief,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'score': score,
        'keywords': keywords,
        'brief': brief,
        'source': source.name,
      };

  factory MoodAnalysis.fromJson(Map<String, dynamic> json) {
    final srcRaw = json['source'] as String?;
    final src = AnalysisSource.values.firstWhere(
      (e) => e.name == srcRaw,
      orElse: () => AnalysisSource.lexicon,
    );
    return MoodAnalysis(
      emoji: json['emoji'] as String,
      score: json['score'] as int,
      keywords: List<String>.from(json['keywords'] as List),
      brief: json['brief'] as String,
      source: src,
    );
  }
}

class DiaryEntry {
  final String id;
  final String text;
  final DateTime date;
  final String mood;
  final MoodAnalysis? analysis;
  final List<String> photoPaths;

  const DiaryEntry({
    required this.id,
    required this.text,
    required this.date,
    required this.mood,
    this.analysis,
    this.photoPaths = const [],
  });

  DiaryEntry copyWith({
    MoodAnalysis? analysis,
    String? mood,
    List<String>? photoPaths,
    DateTime? date,
  }) =>
      DiaryEntry(
        id: id,
        text: text,
        date: date ?? this.date,
        mood: mood ?? this.mood,
        analysis: analysis ?? this.analysis,
        photoPaths: photoPaths ?? this.photoPaths,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'date': date.toIso8601String(),
        'mood': mood,
        'analysis': analysis?.toJson(),
        'photoPaths': photoPaths,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        id: json['id'] as String,
        text: json['text'] as String,
        date: DateTime.parse(json['date'] as String),
        mood: json['mood'] as String,
        analysis: json['analysis'] != null
            ? MoodAnalysis.fromJson(json['analysis'] as Map<String, dynamic>)
            : null,
        photoPaths: json['photoPaths'] != null
            ? List<String>.from(json['photoPaths'] as List)
            : [],
      );

  static String encode(List<DiaryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<DiaryEntry> decode(String source) {
    final list = jsonDecode(source) as List;
    return list
        .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
