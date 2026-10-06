import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/safe_back_button.dart';
import '../../../services/app_settings_controller.dart';
import '../../../services/service_providers.dart';

const _broadcastBucket = 'broadcast-images';

class _LinkDraft {
  _LinkDraft() : label = TextEditingController(), url = TextEditingController();

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

/// Admin screen for writing an announcement with an optional image and links,
/// then sending it to everyone (or one role) in the app, by email, or both.
class BroadcastComposerScreen extends ConsumerStatefulWidget {
  const BroadcastComposerScreen({super.key});

  @override
  ConsumerState<BroadcastComposerScreen> createState() =>
      _BroadcastComposerScreenState();
}

class _BroadcastComposerScreenState extends ConsumerState<BroadcastComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _imageUrl = TextEditingController();
  final List<_LinkDraft> _links = [];

  String _audience = 'all';
  String _channel = 'both';
  String _category = 'broadcast';
  bool _uploading = false;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    for (final link in _links) {
      link.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _message = 'The image could not be read. Try another file.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() => _message = 'Choose an image under 5 MB.');
      return;
    }
    setState(() {
      _uploading = true;
      _message = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final extension = (file.extension ?? 'jpg').toLowerCase();
      final path = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      await client.storage.from(_broadcastBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );
      _imageUrl.text = client.storage.from(_broadcastBucket).getPublicUrl(path);
    } catch (error) {
      setState(() => _message = 'Image upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<Map<String, String>> _cleanLinks() {
    return [
      for (final link in _links)
        if (link.url.text.trim().isNotEmpty)
          {'label': link.label.text.trim(), 'url': link.url.text.trim()},
    ];
  }

  String? _validateLinks() {
    for (final link in _links) {
      final url = link.url.text.trim();
      if (url.isEmpty) continue;
      if (!url.startsWith('https://')) {
        return 'Links must start with https://';
      }
    }
    return null;
  }

  Future<void> _send() async {
    final settings = ref.read(appSettingsControllerProvider);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final linkError = _validateLinks();
    if (linkError != null) {
      setState(() => _message = linkError);
      return;
    }
    final image = _imageUrl.text.trim();
    if (image.isNotEmpty && !image.startsWith('https://')) {
      setState(() => _message = 'The image link must start with https://');
      return;
    }

    final audienceLabel = switch (_audience) {
      'customer' => settings.t('users'),
      'artisan' => settings.t('artisans'),
      _ => settings.t('everyone'),
    };
    final channelLabel = switch (_channel) {
      'app' => settings.t('in the app'),
      'email' => settings.t('by email'),
      _ => settings.t('in the app and by email'),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Send this announcement?')),
        content: Text(
          '${settings.t('It will be sent to')} $audienceLabel $channelLabel. ${settings.t('People who turned this category off in their settings will not receive it.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.t('Send')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      final inserted = await client
          .from('broadcasts')
          .insert({
            'title': _title.text.trim(),
            'body': _body.text.trim(),
            'image_url': image.isEmpty ? null : image,
            'links': _cleanLinks(),
            'category': _category,
            'channel': _channel,
            'audience': _audience,
            'created_by': user?.id,
          })
          .select('id')
          .single();
      final stats = await client
          .from('broadcasts')
          .select('recipient_count')
          .eq('id', inserted['id'] as Object)
          .single();
      if (!mounted) return;
      setState(() {
        _message =
            '${settings.t('Sent. Recipients')}: ${stats['recipient_count']}.';
        _title.clear();
        _body.clear();
        _imageUrl.clear();
        for (final link in _links) {
          link.dispose();
        }
        _links.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not send: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final theme = Theme.of(context);
    final image = _imageUrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Send announcement')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 150,
              decoration: InputDecoration(labelText: settings.t('Title')),
              validator: (value) => (value ?? '').trim().length < 3
                  ? settings.t('Enter a title (at least 3 characters).')
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              minLines: 4,
              maxLines: 10,
              maxLength: 5000,
              decoration: InputDecoration(
                labelText: settings.t('Message'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _imageUrl,
                    decoration: InputDecoration(
                      labelText: settings.t('Image link (https)'),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(settings.t(_uploading ? 'Uploading...' : 'Upload')),
                ),
              ],
            ),
            if (image.startsWith('https://')) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  image,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Text(settings.t('The image could not be previewed.')),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(settings.t('Links'), style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _links.add(_LinkDraft())),
                  icon: const Icon(Icons.add_link),
                  label: Text(settings.t('Add link')),
                ),
              ],
            ),
            for (var i = 0; i < _links.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _links[i].label,
                        decoration: InputDecoration(labelText: settings.t('Label')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _links[i].url,
                        decoration: const InputDecoration(labelText: 'https://'),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _links[i].dispose();
                        _links.removeAt(i);
                      }),
                      icon: const Icon(Icons.close),
                      tooltip: settings.t('Remove'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: InputDecoration(labelText: settings.t('Send to')),
              items: [
                DropdownMenuItem(value: 'all', child: Text(settings.t('Everyone'))),
                DropdownMenuItem(value: 'customer', child: Text(settings.t('Users only'))),
                DropdownMenuItem(value: 'artisan', child: Text(settings.t('Artisans only'))),
              ],
              onChanged: (value) => setState(() => _audience = value ?? 'all'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _channel,
              decoration: InputDecoration(labelText: settings.t('Deliver through')),
              items: [
                DropdownMenuItem(value: 'app', child: Text(settings.t('In the app only'))),
                DropdownMenuItem(value: 'email', child: Text(settings.t('Email only'))),
                DropdownMenuItem(value: 'both', child: Text(settings.t('In the app and email'))),
              ],
              onChanged: (value) => setState(() => _channel = value ?? 'both'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: settings.t('Type')),
              items: [
                DropdownMenuItem(value: 'broadcast', child: Text(settings.t('Announcement'))),
                DropdownMenuItem(value: 'app_update', child: Text(settings.t('App update'))),
              ],
              onChanged: (value) => setState(() => _category = value ?? 'broadcast'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settings.t('Preview'), style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      _title.text.trim().isEmpty ? settings.t('Title') : _title.text.trim(),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(_body.text.trim()),
                    for (final link in _cleanLinks())
                      Text(
                        link['label']!.isEmpty ? link['url']! : link['label']!,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(settings.t(_sending ? 'Sending...' : 'Send announcement')),
            ),
          ],
        ),
      ),
    );
  }
}
