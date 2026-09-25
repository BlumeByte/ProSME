import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_service.dart';

/// Turns admin console lists (accounts, reports) into a PDF or a CSV that
/// opens directly in Excel/Sheets. Mirrors the pattern already used for
/// wallet invoices in InvoicePdfService, without pulling in a new dependency
/// for spreadsheet export.
class AdminExportService {
  const AdminExportService();

  // ---------------------------------------------------------------- CSV ---

  String _csvRow(List<Object?> cells) {
    return cells.map((cell) {
      final value = (cell ?? '').toString();
      if (value.contains(',') || value.contains('"') || value.contains('\n')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }).join(',');
  }

  Uint8List accountsCsvBytes(List<PlatformAccount> accounts) {
    final buffer = StringBuffer();
    buffer.writeln(_csvRow([
      'Name',
      'Full name',
      'Email',
      'Phone',
      'Role',
      'Tenant',
      'Verification status',
      'Country',
      'Currency',
      'Email verified',
      'Phone verified',
      'Created at',
    ]));
    for (final account in accounts) {
      buffer.writeln(_csvRow([
        account.name,
        account.fullName,
        account.email,
        account.phone,
        account.role.name,
        account.tenantId,
        account.verificationStatus.name,
        account.country,
        account.currencyCode,
        account.emailVerified,
        account.phoneVerified,
        account.createdAt.toIso8601String(),
      ]));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Uint8List reportsCsvBytes(List<PlatformReport> reports) {
    final buffer = StringBuffer();
    buffer.writeln(_csvRow([
      'Type',
      'Category',
      'Title',
      'Status',
      'Body',
      'Related table',
      'Related id',
      'Reporter id',
      'Reported user id',
      'Created at',
    ]));
    for (final report in reports) {
      buffer.writeln(_csvRow([
        report.type,
        report.category,
        report.title,
        report.status,
        report.body,
        report.relatedTable,
        report.relatedId,
        report.reporterId,
        report.reportedUserId,
        report.createdAt.toIso8601String(),
      ]));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<void> shareCsv(Uint8List bytes, String filename) async {
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
      fileNameOverrides: [filename],
    );
  }

  // ---------------------------------------------------------------- PDF ---

  Future<pw.MemoryImage?> _logo() async {
    try {
      final data = await rootBundle.load('assets/images/prosme_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(pw.MemoryImage? logo, String title) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ProSME',
              style: const pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
          ],
        ),
        if (logo != null) pw.Image(logo, width: 42, height: 42),
      ],
    );
  }

  Future<Uint8List> accountsPdfBytes(List<PlatformAccount> accounts) async {
    final document = pw.Document(title: 'ProSME accounts export', author: 'ProSME');
    final logo = await _logo();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _header(logo, 'Accounts export'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${DateFormat('MMM d, y h:mm a').format(DateTime.now())} · ${accounts.length} accounts',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Name', 'Email', 'Phone', 'Role', 'Tenant', 'Verification', 'Country'],
            data: accounts
                .map((a) => [
                      a.name,
                      a.email,
                      a.phone,
                      a.role.name,
                      a.tenantId,
                      a.verificationStatus.name,
                      a.country,
                    ])
                .toList(growable: false),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 22,
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> reportsPdfBytes(List<PlatformReport> reports) async {
    final document = pw.Document(title: 'ProSME reports export', author: 'ProSME');
    final logo = await _logo();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _header(logo, 'Reports export'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${DateFormat('MMM d, y h:mm a').format(DateTime.now())} · ${reports.length} reports',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Type', 'Category', 'Title', 'Status', 'Body', 'Created'],
            data: reports
                .map((r) => [
                      r.type,
                      r.category,
                      r.title.isEmpty ? '-' : r.title,
                      r.status,
                      r.body,
                      DateFormat('MMM d, y').format(r.createdAt),
                    ])
                .toList(growable: false),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 22,
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
