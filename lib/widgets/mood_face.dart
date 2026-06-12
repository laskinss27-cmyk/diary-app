import 'package:flutter/material.dart';

/// Custom neon mood face (assets/mood_faces) instead of a system emoji.
///
/// The analyzer still stores a regular emoji character in the entry; this
/// widget maps it to the closest face from Sergey's sticker set, falling
/// back to the score bucket for emoji we don't recognize. The system
/// emoji is rendered only if the asset somehow fails to load.
class MoodFace extends StatelessWidget {
  final String emoji;
  final int score;
  final double size;

  const MoodFace({
    super.key,
    required this.emoji,
    required this.score,
    required this.size,
  });

  // Emotion names follow Sergey's reading of his sticker set (2026-06-13):
  // sad, calm (лёгкая улыбка), scared, angry, happy, joy, sly (что-то
  // задумал), grin (злая улыбка), disappointed, smirk, annoyed,
  // displeased (сильное недовольство), furious.
  static const _byEmoji = <String, String>{
    '😄': 'joy', '😀': 'joy', '😁': 'joy', '😃': 'joy',
    '🤩': 'joy', '🥳': 'joy', '😂': 'joy', '🤣': 'joy', '🎉': 'joy',
    '😊': 'happy', '🥰': 'happy', '😍': 'happy', '❤️': 'happy', '❤': 'happy',
    '🙂': 'calm', '😌': 'calm', '☺️': 'calm', '☺': 'calm', '🙏': 'calm',
    '😴': 'calm', '😐': 'calm', '😶': 'calm', '😑': 'calm', '📝': 'calm',
    '🤔': 'sly', '😎': 'sly', '🤨': 'sly',
    '😏': 'smirk', '😉': 'smirk', '😜': 'smirk',
    '😈': 'grin',
    '😢': 'sad', '😭': 'sad', '😔': 'sad', '😞': 'sad', '🙁': 'sad',
    '☹️': 'sad', '☹': 'sad', '😥': 'sad', '😪': 'sad', '🥺': 'sad',
    '😕': 'disappointed', '😟': 'disappointed', '😓': 'disappointed',
    '😩': 'disappointed', '😫': 'disappointed',
    '😨': 'scared', '😰': 'scared', '😱': 'scared', '😖': 'scared',
    '😒': 'annoyed', '😤': 'annoyed',
    '😠': 'angry',
    '😡': 'displeased',
    '🤬': 'furious',
  };

  static String _byScore(int s) {
    if (s >= 9) return 'joy';
    if (s >= 7) return 'happy';
    if (s >= 5) return 'calm';
    if (s == 4) return 'disappointed';
    if (s == 3) return 'sad';
    return 'scared';
  }

  @override
  Widget build(BuildContext context) {
    final face = _byEmoji[emoji.trim()] ?? _byScore(score);
    return Image.asset(
      'assets/mood_faces/$face.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Text(
        emoji,
        style: TextStyle(fontSize: size * 0.85),
      ),
    );
  }
}
