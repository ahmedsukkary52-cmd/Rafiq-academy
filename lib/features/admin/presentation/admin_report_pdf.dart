import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/academy_branding.dart';
import '../domain/admin_reports.dart';

typedef ReportFonts = ({pw.Font base, pw.Font bold});
typedef ReportFontLoader = Future<ReportFonts> Function();

const reportFontUnavailableMessage =
    'تعذر تجهيز الخط العربي لملف PDF، فلم يُنشأ الملف. أعد المحاولة، '
    'أو صدّر التقرير بصيغة CSV.';

const reportFontRegularAsset = 'assets/fonts/NotoNaskhArabic-Regular.ttf';
const reportFontBoldAsset = 'assets/fonts/NotoNaskhArabic-Bold.ttf';

Future<ReportFonts>? _bundledFonts;

/// Noto Naskh Arabic bundled with the app (no download). Loaded once; a
/// failed load is not cached, so a retry reads the assets again.
Future<ReportFonts> loadReportFonts({AssetBundle? bundle}) {
  if (bundle != null) return _readFonts(bundle);
  return _bundledFonts ??= _readFonts(rootBundle).catchError((Object e) {
    _bundledFonts = null;
    throw e;
  });
}

Future<ReportFonts> _readFonts(AssetBundle bundle) async => (
  base: pw.Font.ttf(await bundle.load(reportFontRegularAsset)),
  bold: pw.Font.ttf(await bundle.load(reportFontBoldAsset)),
);

/// RTL Arabic report. `pw.Table` lays columns out left-to-right, so the
/// column order is mirrored to put the first column on the right.
Future<Uint8List> buildReportPdf(
  ReportTable table, {
  required ReportFonts fonts,
  required DateTime generatedAt,
}) {
  final wide = table.headers.length > 6;
  List<String> rtl(List<String> row) =>
      row.reversed.map(reportPdfText).toList();
  final doc = pw.Document(
    title: table.title,
    // Naskh has no Latin punctuation (dates, "/", parentheses); the PDF
    // standard Helvetica covers them without embedding or downloading.
    theme: pw.ThemeData.withFont(
      base: fonts.base,
      bold: fonts.bold,
      fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            reportPdfText('${AcademyBranding.displayName} - ${table.title}'),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(reportPdfText('الفترة: ${table.range.label}')),
          for (final f in table.filters) pw.Text(reportPdfText('التصفية: $f')),
          pw.Text(
            'تاريخ الإنشاء: ${reportYmd(generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          if (table.truncated)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                ReportTable.truncatedNotice,
                style: const pw.TextStyle(color: PdfColors.red800),
              ),
            ),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        if (table.rows.isEmpty)
          pw.Text('لا توجد بيانات في هذه الفترة')
        else
          pw.TableHelper.fromTextArray(
            headers: rtl(table.headers),
            data: [for (final r in table.rows) rtl(r)],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1B7A4B),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F7F3),
            ),
          ),
        if (table.summary.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            'الملخص',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          for (final (k, v) in table.summary) pw.Text(reportPdfText('$k: $v')),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Neither embedded font has a glyph for the em dash, which would vanish
/// from the PDF (empty-value cells included); a hyphen keeps it visible.
String reportPdfText(String value) => value.replaceAll('—', '-');
