import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../core/widgets/safe_back_button.dart';
import '../../../routes/route_names.dart';
import '../../../services/admin_service.dart';
import '../../../services/app_settings_controller.dart';
import '../../../services/service_providers.dart';
import 'account_import_parser.dart';

class AccountImportScreen extends ConsumerStatefulWidget {
  const AccountImportScreen({super.key});

  @override
  ConsumerState<AccountImportScreen> createState() => _AccountImportScreenState();
}

class _AccountImportScreenState extends ConsumerState<AccountImportScreen> {
  static const _previewLimit = 200;

  ImportAccountSheet? _sheet;
  String? _fileName;
  String? _parseError;
  bool _importing = false;
  int _done = 0;
  int _total = 0;
  BulkImportResult? _result;

  Future<void> _pickFile() async {
    setState(() {
      _parseError = null;
      _result = null;
    });
    // Picking with FileType.custom + allowedExtensions relies on the OS
    // reporting a MIME type for the file. Many Android storage providers
    // (Downloads, Drive, WhatsApp, etc.) tag .xlsx files as the generic
    // application/octet-stream, so the system picker's filter hides them
    // entirely and nothing can be selected. FileType.any avoids that; the
    // extension is checked here instead, after the pick.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.xlsx')) {
      setState(() {
        _sheet = null;
        _fileName = file.name;
        _parseError = 'Choose a .xlsx file. "${file.name}" is not one.';
      });
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'The file could not be opened. Try again.');
      return;
    }
    try {
      final sheet = parseAccountSheet(bytes);
      setState(() {
        _sheet = sheet;
        _fileName = file.name;
      });
    } on FormatException catch (error) {
      setState(() {
        _sheet = null;
        _fileName = file.name;
        _parseError = error.message;
      });
    }
  }

  Future<void> _confirmAndImport() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final settings = ref.read(appSettingsControllerProvider);
    final valid = sheet.valid;
    if (valid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Create ${valid.length} accounts?')),
        content: Text(
          settings.t(
            'Each account gets a random password. The person receives an email at the address in the sheet to choose their own password. ${sheet.invalid.length} row(s) that need fixing will be skipped.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.t('Create accounts')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _importing = true;
      _done = 0;
      _total = valid.length;
      _result = null;
    });
    try {
      final result = await ref.read(adminServiceProvider).importAccounts(
            valid.map((row) => row.toPayload()).toList(growable: false),
            redirectTo: kIsWeb
                ? Uri.base.resolve(RouteNames.resetPassword).toString()
                : kPasswordRecoveryRedirectUrl,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _done = done;
                _total = total;
              });
            },
          );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _parseError = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final sheet = _sheet;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Import accounts')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.t('Excel columns (first sheet, row 1 is the header)'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.t(
                      'Required: email, full_name, role (artisan or user), country, date_of_birth (YYYY-MM-DD).\nOptional: phone (with or without country code), gender (female, male, non_binary, prefer_not_to_say), location.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.t(
                      'Every person must be 18 or older. Phone numbers are checked against the chosen country.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _importing ? null : _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(settings.t('Choose Excel file (.xlsx)')),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Text(_fileName!, style: theme.textTheme.bodySmall),
          ],
          if (_parseError != null) ...[
            const SizedBox(height: 12),
            Text(
              _parseError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (sheet != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${settings.t('Rows')}: ${sheet.rows.length}')),
                Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('${settings.t('Ready')}: ${sheet.valid.length}'),
                ),
                Chip(
                  avatar: Icon(
                    Icons.error_outline,
                    size: 18,
                    color: sheet.invalid.isEmpty ? null : theme.colorScheme.error,
                  ),
                  label: Text('${settings.t('Need fixing')}: ${sheet.invalid.length}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  (_importing || sheet.valid.isEmpty) ? null : _confirmAndImport,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: Text(
                '${settings.t('Create accounts')} (${sheet.valid.length})',
              ),
            ),
            if (_importing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              const SizedBox(height: 4),
              Text('$_done / $_total'),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(result: _result!, settings: settings),
            ],
            const SizedBox(height: 16),
            Text(settings.t('Rows'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sheet.rows.take(_previewLimit).map(
                  (row) => _RowTile(row: row, settings: settings),
                ),
            if (sheet.rows.length > _previewLimit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${settings.t('Showing the first')} $_previewLimit ${settings.t('rows.')}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.settings});

  final ImportAccountRow row;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final ok = row.isValid;
    final color = ok ? null : Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: color,
        ),
        title: Text('${row.fullName.isEmpty ? row.email : row.fullName} · ${row.role}'),
        subtitle: Text(
          ok
              ? '${row.email} · ${row.country}'
              : '${settings.t('Row')} ${row.line}: ${row.errors.join(' ')}',
          style: color == null ? null : TextStyle(color: color),
        ),
        isThreeLine: false,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.settings});

  final BulkImportResult result;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.t('Import finished'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${settings.t('Accounts created')}: ${result.created.length}'),
            Text('${settings.t('Password emails sent')}: ${result.emailsSent}'),
            Text(
              '${settings.t('Failed')}: ${result.failed.length}',
              style: result.failed.isEmpty
                  ? null
                  : TextStyle(color: theme.colorScheme.error),
            ),
            for (final failure in result.failed.take(50))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${failure['email']}: ${failure['error']}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
