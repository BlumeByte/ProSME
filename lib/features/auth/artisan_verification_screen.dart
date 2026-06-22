import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../config/constants.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
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
  static const _maxUploadBytes = 1024 * 1024;
  static const _maxSourceImageBytes = 5 * 1024 * 1024;
  final _phoneController = TextEditingController();
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
    final user = ref.read(authStateProvider).valueOrNull;
    _phoneController.text = user?.phone ?? '';
    _loadVerificationStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
            'phone,national_id_front_url,national_id_back_url,verification_retry_after',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        final phone = (row?['phone'] ?? '').toString();
        if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
          _phoneController.text = phone;
        }
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
    if (extension == 'pdf' && file.size > _maxUploadBytes) {
      _showMessage('PDF files must be 1 MB or smaller.');
      return null;
    }
    if (extension != 'pdf' && file.size > _maxSourceImageBytes) {
      _showMessage('Images must be 5 MB or smaller before compression.');
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
    final upload = _prepareUpload(file);
    final path =
        '$userId/${DateTime.now().microsecondsSinceEpoch}_$label.${upload.extension}';
    await client.storage.from('artisan-verification').uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: upload.contentType,
          ),
        );
    return client.storage.from('artisan-verification').getPublicUrl(path);
  }

  _PreparedUpload _prepareUpload(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Could not read the selected file.');
    }
    if (extension == 'pdf') {
      if (bytes.length > _maxUploadBytes) {
        throw StateError('PDF files must be 1 MB or smaller.');
      }
      return _PreparedUpload(
        bytes: bytes,
        extension: 'pdf',
        contentType: 'application/pdf',
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not process the selected image.');
    }
    final largestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = largestSide > 1100
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1100 : null,
            height: decoded.height > decoded.width ? 1100 : null,
          )
        : decoded;

    var quality = 72;
    var compressed = img.encodeJpg(resized, quality: quality);
    while (compressed.length > _maxUploadBytes && quality > 38) {
      quality -= 8;
      compressed = img.encodeJpg(resized, quality: quality);
    }
    if (compressed.length > _maxUploadBytes) {
      throw StateError('Image is still larger than 1 MB after compression.');
    }
    return _PreparedUpload(
      bytes: Uint8List.fromList(compressed),
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
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
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Telephone number is required for verification.');
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
            phone: phone,
            nationalIdFrontUrl: frontUrl,
            nationalIdBackUrl: backUrl,
            businessCertificateUrls: certificateUrls,
          );
      if (!mounted) return;
      setState(() => _hasSubmittedDocuments = true);
      _showMessage('Verification sent to Support for review.');
      context.go(
        user.role == UserRole.artisan
            ? RouteNames.artisanHome
            : RouteNames.home,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error is StateError
          ? error.message
          : 'Could not submit verification. Check Supabase storage setup.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    final settings = ref.read(appSettingsControllerProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(settings.t(message))));
  }

  void _leaveVerification() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    context.go(
      user?.role == UserRole.artisan ? RouteNames.artisanHome : RouteNames.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final retryAfter = _retryAfter;
    final isRetryLocked =
        retryAfter != null && retryAfter.isAfter(DateTime.now());
    final remainingDays =
        isRetryLocked ? retryAfter.difference(DateTime.now()).inDays + 1 : 0;
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveVerification();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(settings.t(user?.role == UserRole.artisan
              ? 'Artisan verification'
              : 'Account verification')),
          leading: BackButton(onPressed: _leaveVerification),
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
              _StatusPanel(
                icon: Icons.verified,
                title: settings.t('Verification approved'),
                message: settings.t(user?.role == UserRole.artisan
                    ? 'Your artisan profile now shows a verified checkmark.'
                    : 'Your account now shows a verified checkmark.'),
              )
            else if (_hasSubmittedDocuments &&
                user?.verificationStatus == VerificationStatus.pending)
              _StatusPanel(
                icon: Icons.pending_actions,
                title: settings.t('Submitted and under review'),
                message: settings.t(
                  'Your documents are with Support. You cannot submit again until review is complete.',
                ),
              )
            else if (isRetryLocked)
              _StatusPanel(
                icon: Icons.lock_clock,
                title: settings.t('Verification paused'),
                message:
                    '${settings.t('Your documents were not accepted. You can upload again in')} $remainingDays ${settings.t('day(s). Use clear front/back National ID images and valid business certificates where available.')}',
              )
            else ...[
              Text(
                settings.t('Upload verification documents'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                settings.t(
                  'PDF up to 1 MB, or JPG/PNG up to 5 MB. Images are resized before review.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: settings.t('Telephone number *'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _FileTile(
                title: settings.t('National ID front'),
                required: true,
                file: _frontId,
                onTap: () => _pickRequired(front: true),
              ),
              const SizedBox(height: 10),
              _FileTile(
                title: settings.t('National ID back'),
                required: true,
                file: _backId,
                onTap: () => _pickRequired(front: false),
              ),
              const SizedBox(height: 10),
              ..._certificates.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FileTile(
                    title: settings.t('Business certificate'),
                    file: file,
                    onTap: () {},
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickCertificate,
                icon: const Icon(Icons.add),
                label: Text(settings.t('Add business certificate')),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: settings.t(
                  _isSubmitting ? 'Submitting...' : 'Submit for review',
                ),
                icon: Icons.upload_file,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ],
        ),
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

class _FileTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      leading: const Icon(Icons.attach_file),
      title: Text(required ? '$title *' : title),
      subtitle: Text(
        file == null
            ? settings.t('PDF max 1 MB. Images max 5 MB.')
            : file!.name,
      ),
      trailing: const Icon(Icons.upload_file),
      onTap: onTap,
    );
  }
}

class _PreparedUpload {
  const _PreparedUpload({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}
