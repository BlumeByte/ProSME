import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency.dart';
import '../models/wallet_transaction.dart';

class InvoicePdfService {
  const InvoicePdfService();

  Future<Uint8List> buildInvoice(
    WalletTransaction transaction, {
    String? currencyCode,
    String Function(String value)? translate,
  }) async {
    final t = translate ?? (value) => value;
    final document = pw.Document(
      title: 'ProSME ${t('Invoice')} ${transaction.invoiceNumber}',
      author: 'ProSME',
    );
    final logo = await _loadLogo();
    final date = DateFormat('MMM d, y').format(transaction.createdAt);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          _header(logo, t('Invoice').toUpperCase(), translate: t),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _partyBlock(
                  t('Customer').toUpperCase(),
                  transaction.customerName,
                  transaction.customerEmail,
                  translate: t,
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: _partyBlock(
                  t('Service provider').toUpperCase(),
                  transaction.artisanName,
                  transaction.artisanEmail,
                  translate: t,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${t('Invoice')}: ${transaction.invoiceNumber}'),
                pw.Text('${t('Date')}: $date'),
                pw.Text(
                    '${t('Status')}: ${t(transaction.paymentStatus).toUpperCase()}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [t('Work'), t('Location'), t('Amount')],
            data: [
              [
                transaction.jobTitle.isEmpty
                    ? t('Accepted work')
                    : transaction.jobTitle,
                transaction.jobLocation.isEmpty
                    ? t('Not specified')
                    : transaction.jobLocation,
                _money(
                    transaction.amount, currencyCode ?? transaction.currency),
              ],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellPadding: const pw.EdgeInsets.all(9),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 1.4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(t('Total').toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    _money(transaction.amount,
                        currencyCode ?? transaction.currency),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            t('This invoice records work agreed through ProSME. Confirm payment and completion with both parties.'),
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
        ],
        footer: _footer,
      ),
    );
    return document.save();
  }

  Future<Uint8List> buildWalletReport(
    List<WalletTransaction> transactions, {
    required String reportOwner,
    String Function(String value)? translate,
  }) async {
    final t = translate ?? (value) => value;
    final document = pw.Document(
      title: 'ProSME ${t('Wallet report')}',
      author: 'ProSME',
    );
    final logo = await _loadLogo();
    final total =
        transactions.fold<double>(0, (sum, item) => sum + item.amount);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (_) => [
          _header(logo, t('Wallet report').toUpperCase(), translate: t),
          pw.SizedBox(height: 12),
          pw.Text('${t('Prepared for')}: $reportOwner'),
          pw.Text(
              '${t('Generated')}: ${DateFormat('MMM d, y h:mm a').format(DateTime.now())}'),
          pw.SizedBox(height: 8),
          pw.Text(
            '${t('Accepted work total')}: ${_money(total, transactions.isEmpty ? 'GHS' : transactions.first.currency)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: [
              t('Invoice'),
              t('Date'),
              t('Work'),
              t('Customer'),
              t('Artisan'),
              t('Status'),
              t('Amount'),
            ],
            data: transactions
                .map(
                  (item) => [
                    item.invoiceNumber,
                    DateFormat('yyyy-MM-dd').format(item.createdAt),
                    item.jobTitle,
                    item.customerName,
                    item.artisanName,
                    item.paymentStatus,
                    _money(item.amount, item.currency),
                  ],
                )
                .toList(growable: false),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
        footer: _footer,
      ),
    );
    return document.save();
  }

  Future<void> printInvoice(
    WalletTransaction transaction, {
    String? currencyCode,
    String Function(String value)? translate,
  }) async {
    final bytes = await buildInvoice(
      transaction,
      currencyCode: currencyCode,
      translate: translate,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareInvoice(
    WalletTransaction transaction, {
    String? currencyCode,
    String Function(String value)? translate,
  }) async {
    final bytes = await buildInvoice(
      transaction,
      currencyCode: currencyCode,
      translate: translate,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${transaction.invoiceNumber}.pdf',
    );
  }

  Future<void> printWalletReport(
    List<WalletTransaction> transactions, {
    required String reportOwner,
    String Function(String value)? translate,
  }) async {
    final bytes = await buildWalletReport(
      transactions,
      reportOwner: reportOwner,
      translate: translate,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareWalletReport(
    List<WalletTransaction> transactions, {
    required String reportOwner,
    String Function(String value)? translate,
  }) async {
    final bytes = await buildWalletReport(
      transactions,
      reportOwner: reportOwner,
      translate: translate,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'prosme-wallet-report.pdf',
    );
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/prosme_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(
    pw.MemoryImage? logo,
    String title, {
    required String Function(String value) translate,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          children: [
            if (logo != null) pw.Image(logo, width: 46, height: 46),
            if (logo != null) pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ProSME',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(translate('Professional services marketplace')),
              ],
            ),
          ],
        ),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _partyBlock(
    String label,
    String name,
    String email, {
    required String Function(String value) translate,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.blue900,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(name.isEmpty ? translate('Not provided') : name),
        if (email.isNotEmpty) pw.Text(email),
      ],
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'ProSME | Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}

String _money(double amount, String currency) {
  return formatMoney(amount, currency);
}
