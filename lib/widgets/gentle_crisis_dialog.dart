import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/help_screen.dart';

/// Мягкий диалог, который предлагает контакты помощи, когда в записи
/// обнаружены признаки кризисного состояния.
///
/// Принципы:
/// - НЕ алармистский. Никаких "ВНИМАНИЕ! КРИЗИС!".
/// - Тёплый и безоценочный. Признаёт, а не диагностирует.
/// - Легко закрыть. Не блокирует поток — человек сам решает,
///   нужна ли ему помощь прямо сейчас.
/// - Одно действие-предложение, одно действие-отказ. Без списков.
class GentleCrisisDialog {
  static Future<void> show(BuildContext context) async {
    final t = DiaryApp.themeNotifier.theme;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: t.cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: t.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Прочитал то, что ты написал.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Иногда помогает услышать другой голос.\n'
                'Здесь есть люди, готовые выслушать прямо сейчас.',
                style: TextStyle(
                  fontSize: 14,
                  color: t.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Показать контакты',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: t.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Не сейчас',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
