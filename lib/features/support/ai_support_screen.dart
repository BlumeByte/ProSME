import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../services/admin_service.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

class AiSupportScreen extends ConsumerStatefulWidget {
  const AiSupportScreen({super.key});

  @override
  ConsumerState<AiSupportScreen> createState() => _AiSupportScreenState();
}

class _AiSupportScreenState extends ConsumerState<AiSupportScreen> {
  final _controller = TextEditingController();
  final _ticketTitleController = TextEditingController();
  final _ticketMessageController = TextEditingController();
  final List<_SupportMessage> _messages = const [
    _SupportMessage(
      question: 'How do I create a service request?',
      answer:
          'Open Upload, add the service title, description, location, and budget, then tap Upload.',
    ),
    _SupportMessage(
      question: 'How do I find an artisan?',
      answer:
          'Use Home to search by service or location, open a listing, then start a chat or request an invoice.',
    ),
    _SupportMessage(
      question: 'How do artisans create listings?',
      answer:
          'Create or sign in to an artisan account, open Listings, and tap Create.',
    ),
    _SupportMessage(
      question: 'Why is Supabase not loading?',
      answer:
          'The app needs the correct Supabase URL, anon key, and migrated tables before live data can load.',
    ),
  ];
  String? _answer;
  bool _submittingTicket = false;

  @override
  void dispose() {
    _controller.dispose();
    _ticketTitleController.dispose();
    _ticketMessageController.dispose();
    super.dispose();
  }

  void _answerQuestion(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;
    _SupportMessage? match;
    for (final message in _messages) {
      final text = '${message.question} ${message.answer}'.toLowerCase();
      if (query.split(RegExp(r'\s+')).any(text.contains)) {
        match = message;
        break;
      }
    }
    setState(() {
      _answer = match?.answer ??
          'I can help with sign in, artisan listings, service requests, bookings, chats, payments, profile settings, and Supabase setup.';
    });
    _controller.clear();
  }

  Future<void> _submitSupportTicket() async {
    final settings = ref.read(appSettingsControllerProvider);
    final message = _ticketMessageController.text.trim();
    if (message.isEmpty || _submittingTicket) return;
    setState(() => _submittingTicket = true);
    try {
      await ref.read(adminServiceProvider).submitSupportReport(
            title: _ticketTitleController.text,
            message: message,
          );
      if (!mounted) return;
      _ticketTitleController.clear();
      _ticketMessageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t(
              'Support ticket sent. A Support response will appear as a no-reply notice.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${settings.t('Could not send support ticket')}: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingTicket = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('AI Support')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._messages.map(
            (message) => ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(settings.t(message.question)),
              subtitle: Text(settings.t(message.answer)),
              onTap: () => setState(() => _answer = settings.t(message.answer)),
            ),
          ),
          const Divider(),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: settings.t('Ask about Pro SME'),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _answerQuestion(_controller.text),
              ),
            ),
            onSubmitted: _answerQuestion,
          ),
          if (_answer != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(settings.t(_answer!)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            settings.t('Support responses'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<SupportNotice>>(
            future: ref.read(adminServiceProvider).fetchSupportNotices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              final notices = snapshot.data ?? const <SupportNotice>[];
              if (notices.isEmpty) {
                return Text(settings.t('No Support responses yet.'));
              }
              return Column(
                children: notices
                    .map(
                      (notice) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.mark_email_read_outlined),
                          title: Text(notice.title),
                          subtitle: Text(notice.body),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            settings.t('Contact support'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ticketTitleController,
            decoration: InputDecoration(
              labelText: settings.t('Subject'),
              hintText: settings.t('What do you need help with?'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ticketMessageController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: settings.t('Message'),
              hintText:
                  settings.t('Explain the issue so Support can review it.'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submittingTicket ? null : _submitSupportTicket,
            icon: const Icon(Icons.outgoing_mail),
            label: Text(
                settings.t(_submittingTicket ? 'Sending...' : 'Send report')),
          ),
        ],
      ),
    );
  }
}

class _SupportMessage {
  const _SupportMessage({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
