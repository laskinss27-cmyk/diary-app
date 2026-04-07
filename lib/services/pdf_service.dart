import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/diary_entry.dart';

class PdfService {
  static Future<void> exportEntries({
    required List<DiaryEntry> entries,
    required Map<String, String> profile,
    required String title,
  }) async {
    final pdf = pw.Document();

    // Load Roboto fonts (supports Cyrillic)
    final fontData = await rootBundle.load('fonts/Roboto-Regular.ttf');
    final fontBoldData = await rootBundle.load('fonts/Roboto-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);
    debugPrint('PDF: fonts loaded OK');

    final baseStyle = pw.TextStyle(font: font, fontSize: 11);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 11);
    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 22);
    final smallStyle = pw.TextStyle(
        font: font, fontSize: 9, color: PdfColors.grey700);

    final name = _safe(profile['name'] ?? '');
    final age = _safe(profile['age'] ?? '');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_safe(title), style: titleStyle),
                if (name.isNotEmpty)
                  pw.Text(
                    '$name${age.isNotEmpty ? ', $age лет' : ''}',
                    style: boldStyle,
                  ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.pink200, thickness: 2),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Дневник настроения', style: smallStyle),
            pw.Text(
              'Стр. ${context.pageNumber}/${context.pagesCount}',
              style: smallStyle,
            ),
          ],
        ),
        build: (context) {
          return entries.map((entry) {
            final score = entry.analysis?.score ?? 5;
            final scoreColor = score >= 7
                ? PdfColors.green
                : score >= 4
                    ? PdfColors.amber
                    : PdfColors.red;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.pink100),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${_moodToText(score)}  ${_formatDate(entry.date)}',
                          style: boldStyle,
                        ),
                      ),
                      if (entry.analysis != null)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('F0F0F0'),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            '${entry.analysis!.score}/10',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: scoreColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(_safe(entry.text), style: baseStyle),
                  if (entry.analysis != null) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_safe(entry.analysis!.brief),
                              style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  fontStyle: pw.FontStyle.italic,
                                  color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            entry.analysis!.keywords
                                .map(_safe)
                                .join(', '),
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 9,
                                color: PdfColors.pink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList();
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'diary_export.pdf',
    );
  }

  /// Strip emoji and any non-BMP characters that crash PDF.
  /// Keeps ASCII, Latin Extended, Cyrillic, common punctuation.
  static String _safe(String text) {
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Skip UTF-16 surrogate pairs (emoji etc)
      if (code >= 0xD800 && code <= 0xDFFF) continue;
      // Skip private use area
      if (code >= 0xE000 && code <= 0xF8FF) continue;
      // Keep: Basic Latin + Latin-1 Supplement + Latin Extended (0000-024F)
      if (code <= 0x024F) {
        buf.writeCharCode(code);
        continue;
      }
      // Keep: Cyrillic (0400-04FF)
      if (code >= 0x0400 && code <= 0x04FF) {
        buf.writeCharCode(code);
        continue;
      }
      // Keep: General Punctuation (2000-206F) — dashes, quotes etc
      if (code >= 0x2000 && code <= 0x206F) {
        buf.writeCharCode(code);
        continue;
      }
      // Replace everything else with space
      buf.write(' ');
    }
    final result = buf.toString().trim();
    return result.isEmpty ? '-' : result;
  }

  static String _moodToText(int score) {
    if (score >= 9) return 'Отлично';
    if (score >= 7) return 'Хорошо';
    if (score >= 5) return 'Нормально';
    if (score >= 3) return 'Плохо';
    return 'Тяжело';
  }

  static String _formatDate(DateTime date) {
    const months = [
      '',
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
