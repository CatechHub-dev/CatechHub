import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintStudentData {
  final String fullName;
  final int present;
  final int absent;
  final int consecutiveAbsences;

  PrintStudentData({
    required this.fullName,
    required this.present,
    required this.absent,
    required this.consecutiveAbsences,
  });
}

class PrintService {
  static Future<void> printAttendanceReport({
    required String className,
    required List<PrintStudentData> students,
  }) async {
    final pdf = pw.Document();

    // ORDINA ALFABETICAMENTE (FIX IMPORTANTE)
    final sortedStudents = [...students]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              /// =========================
              /// HEADER GRUPPO
              /// =========================
              pw.Text(
                className,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              /// =========================
              /// TABELLA
              /// =========================
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3), // nome
                    1: const pw.FlexColumnWidth(1), // presenze
                    2: const pw.FlexColumnWidth(1), // assenze
                    3: const pw.FlexColumnWidth(3), // incontri (future expansion)
                  },
                  children: [
                    /// HEADER RIGA
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Nome e Cognome',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'P',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'A',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Stato incontri',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    /// DATI STUDENTI
                    ...sortedStudents.map((s) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(s.fullName),
                          ),

                          /// PRESENZE
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '${s.present}',
                              textAlign: pw.TextAlign.center,
                            ),
                          ),

                          /// ASSENZE
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '${s.absent}',
                              textAlign: pw.TextAlign.center,
                            ),
                          ),

                          /// STATO (placeholder logico richiesto)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              s.absent > 0 ? 'a' : '',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                color: s.absent > 0
                                    ? PdfColors.red
                                    : PdfColors.green,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}