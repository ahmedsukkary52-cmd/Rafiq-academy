import 'package:injectable/injectable.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/award_entities.dart';

/// Service مسؤول بالكامل عن توليد ملف PDF للشهادة.
/// منفصل عن الـ Repository عشان:
/// 1. منطق الـ PDF بيانوي وطويل ومش علاقته بـ Firestore
/// 2. لو الأكاديمية طلبت تغيير شكل الشهادة، نعدّل هنا بس من غير ما نلمس
///    الـ data layer أو الـ domain
@lazySingleton
class CertificatePdfGenerator {
  Future<List<int>> generate(CertificateDataEntity data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildCertificateContent(context, data),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildCertificateContent(
    pw.Context context,
    CertificateDataEntity data,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF1B5E20), // أخضر إسلامي
          width: 8,
        ),
      ),
      child: pw.Container(
        margin: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFB8860B), // ذهبي
            width: 2,
          ),
        ),
        padding: const pw.EdgeInsets.all(30),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // ── اسم الأكاديمية ─────────────────────────────────────
            pw.Text(
              data.academyName,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1B5E20),
              ),
            ),
            pw.SizedBox(height: 8),

            // ── الفاصل الذهبي ──────────────────────────────────────
            pw.Container(
              height: 2,
              width: 300,
              color: const PdfColor.fromInt(0xFFB8860B),
            ),
            pw.SizedBox(height: 20),

            // ── شهادة تقدير ───────────────────────────────────────
            pw.Text(
              'شهادة تقدير',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1A1A1A),
              ),
            ),
            pw.SizedBox(height: 6),

            pw.Text(
              'تُمنح هذه الشهادة إلى',
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColor.fromInt(0xFF6B6B6B),
              ),
            ),
            pw.SizedBox(height: 14),

            // ── اسم الطالب ────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF0FAF0),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                data.studentName,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1B5E20),
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // ── نص الإنجاز ────────────────────────────────────────
            pw.Text(
              'تقديراً على',
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColor.fromInt(0xFF6B6B6B),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              data.achievement,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1A1A1A),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'في ${data.halaqaName}',
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColor.fromInt(0xFF6B6B6B),
              ),
            ),
            pw.SizedBox(height: 30),

            // ── التاريخ والمعلم ───────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // التاريخ
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 150,
                      height: 1,
                      color: const PdfColor.fromInt(0xFF1A1A1A),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatDate(data.date),
                      textDirection: pw.TextDirection.rtl,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'التاريخ',
                      textDirection: pw.TextDirection.rtl,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColor.fromInt(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),

                // شعار أو مساحة وسطى
                pw.Text('🌟', style: const pw.TextStyle(fontSize: 30)),

                // توقيع المعلم
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 150,
                      height: 1,
                      color: const PdfColor.fromInt(0xFF1A1A1A),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.teacherName,
                      textDirection: pw.TextDirection.rtl,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'المعلم',
                      textDirection: pw.TextDirection.rtl,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColor.fromInt(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
