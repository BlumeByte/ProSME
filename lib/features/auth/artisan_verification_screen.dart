import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArtisanVerificationScreen extends ConsumerStatefulWidget {
  const ArtisanVerificationScreen({super.key});

  @override
  ConsumerState<ArtisanVerificationScreen> createState() =>
      _ArtisanVerificationScreenState();
}

class _ArtisanVerificationScreenState
    extends ConsumerState<ArtisanVerificationScreen> {
  static const _maxBytes = 1024 * 1024;
  PlatformFile? _frontId;
  PlatformFile? _backId;
  final List<PlatformFile> _certificates = [];
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  bool _hasSubmittedDocuments = false;
  DateTime? _retryAfter;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || !shouldUseSupabase()) {
      setState(() => _isLoadingStatus = false);
      return;
    }
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .select(
            'national_id_front_url,national_id_back_url,verification_retry_after',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _hasSubmittedDocuments =
            ((row?['national_id_front_url'] ?? '') as String).isNotEmpty ||
                ((row?['national_id_back_url'] ?? '') as String).isNotEmpty;
        _retryAfter = DateTime.tryParse(
          (row?['verification_retry_after'] ?? '').toString(),
        );
        _isLoadingStatus = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _pickRequired({required bool front}) async {
    final file = await _pickFile();
    if (file == null) return;
    setState(() {
      if (front) {
        _frontId = file;
      } else {
        _backId = file;
      }
    });
  }

  Future<void> _pickCertificate() async {
    final file = await _pickFile();
    if (file == null) return;
    setState(() => _certificates.add(file));
  }

  Future<PlatformFile?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final isAllowed = {'jpg', 'jpeg', 'png', 'pdf'}.contains(extension);
    if (!isAllowed) {
      _showMessage('Only PDF, JPG, JPEG, or PNG files are allowed.');
      return null;
    }
    if (file.size > _maxBytes) {
      _showMessage('File must be 1 MB or smaller.');
      return null;
    }
    if (file.bytes == null) {
      _showMessage('Could not read the selected file.');
      return null;
    }
    return file;
  }

  Future<String> _uploadFile({
    required String userId,
    required String label,
    required PlatformFile file,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final extension = (file.extension ?? 'bin').toLowerCase();
    final path =
        '$userId/${DateTime.now().microsecondsSinceEpoch}_$label.$extension';
    await client.storage.from('artisan-verification').uploadBinary(
        path, file.bytes!,
        fileOptions: const FileOptions(upsert: true));
    return client.storage.from('artisan-verification').getPublicUrl(path);
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go(RouteNames.auth);
      return;
    }
    if (_frontId == null || _backId == null) {
      _showMessage('Front and back of National ID are required.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final frontUrl = await _uploadFile(
        userId: user.id,
        label: 'national_id_front',
        file: _frontId!,
      );
      final backUrl = await _uploadFile(
        userId: user.id,
        label: 'national_id_back',
        file: _backId!,
      );
      final certificateUrls = <String>[];
      for (var i = 0; i < _certificates.length; i++) {
        certificateUrls.add(
          await _uploadFile(
            userId: user.id,
            label: 'business_certificate_$i',
            file: _certificates[i],
          ),
        );
      }
      await ref.read(adminServiceProvider).submitArtisanVerification(
            userId: user.id,
            nationalIdFrontUrl: frontUrl,
            nationalIdBackUrl: backUrl,
            businessCertificateUrls: certificateUrls,
          );
      if (!mounted) return;
      setState(() => _hasSubmittedDocuments = true);
      _showMessage('Verification sent to Support for review.');
      context.go(RouteNames.artisanHome);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
          'Could not submit verification. Check Supabase storage setup.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final retryAfter = _retryAfter;
    final isRetryLocked =
        retryAfter != null && retryAfter.isAfter(DateTime.now());
    final remainingDays =
        isRetryLocked ? retryAfter.difference(DateTime.now()).inDays + 1 : 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artisan verification'),
        leading:
            BackButton(onPressed: () => context.go(RouteNames.artisanHome)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_isLoadingStatus)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (user?.verificationStatus == VerificationStatus.verified)
            const _StatusPanel(
              icon: Icons.verified,
              title: 'Verification approved',
              message: 'Your artisan profile now shows a verified checkmark.',
            )
          else if (_hasSubmittedDocuments &&
              user?.verificationStatus == VerificationStatus.pending)
            const _StatusPanel(
              icon: Icons.pending_actions,
              title: 'Submitted and under review',
              message:
                  'Your documents are with Support. You cannot submit again until review is complete.',
            )
          else if (isRetryLocked)
            _StatusPanel(
              icon: Icons.lock_clock,
              title: 'Verification paused',
              message:
                  'Your documents were not accepted. You can upload again in $remainingDays day(s). Use clear front/back National ID images and valid business certificates where available.',
            )
          else ...[
            Text(
              'Upload verification documents',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'PDF or image only. Each file must be 1 MB or smaller.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _FileTile(
              title: 'National ID front',
              required: true,
              file: _frontId,
              onTap: () => _pickRequired(front: true),
            ),
            const SizedBox(height: 10),
            _FileTile(
              title: 'National ID back',
              required: true,
              file: _backId,
              onTap: () => _pickRequired(front: false),
            ),
            const SizedBox(height: 10),
            ..._certificates.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FileTile(
                  title: 'Business certificate',
                  file: file,
                  onTap: () {},
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickCertificate,
              icon: const Icon(Icons.add),
              label: const Text('Add business certificate'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit for review',
              icon: Icons.upload_file,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.title,
    required this.file,
    required this.onTap,
    this.required = false,
  });

  final String title;
  final PlatformFile? file;
  final VoidCallback onTap;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      leading: const Icon(Icons.attach_file),
      title: Text(required ? '$title *' : title),
      subtitle:
          Text(file == null ? 'PDF, JPG, JPEG, PNG. Max 1 MB.' : file!.name),
      trailing: const Icon(Icons.upload_file),
      onTap: onTap,
    );
  }
}
