import 'package:flutter/material.dart';

class DisclaimerDialog {
  static const _disclaimerText = '''
Отчёт формируется на основе анализа ваших записей с помощью выбранной вами нейросети (или встроенного механизма).

Анализ может содержать прямые формулировки о психическом состоянии, включая упоминания кризисных мыслей, дистресса или суицидальных рисков.

Важно:
\u2022 Это не медицинский диагноз
\u2022 Разработчик приложения не несёт ответственности за содержание отчёта
\u2022 Ответственность за интерпретацию отчёта лежит на вас и вашем лечащем враче

Отправляя отчёт, вы подтверждаете, что ознакомлены с этим предупреждением.''';

  static const userAgreementText = '''
Пользовательское соглашение

Приложение предоставляет инструмент для анализа текстовых записей с помощью нейросетей, выбранных пользователем. Разработчик:

\u2022 Не обрабатывает и не хранит ваши записи на своих серверах
\u2022 Не даёт медицинских рекомендаций
\u2022 Не несёт ответственности за интерпретацию результатов пользователем, врачом или третьими лицами

Используя приложение, вы соглашаетесь, что вся ответственность за использование анализа лежит на вас.''';

  /// Show disclaimer before sharing/exporting report.
  /// Returns true if user confirmed, false otherwise.
  static Future<bool> showBeforeShare(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Text(
              'Внимание',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _disclaimerText,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отправить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show user agreement (for onboarding / settings).
  static Future<void> showAgreement(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.description_outlined,
                color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Пользовательское соглашение',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            userAgreementText,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Понятно'),
            ),
          ),
        ],
      ),
    );
  }
}
