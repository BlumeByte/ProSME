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
  final _searchController = TextEditingController();
  final _ticketTitleController = TextEditingController();
  final _ticketMessageController = TextEditingController();
  String _category = 'All';
  String _query = '';
  String? _answer;
  bool _submittingTicket = false;

  static const _faqs = <_FaqItem>[
    _FaqItem(
      category: 'Jobs and bids',
      question: 'How do I create a service request?',
      answer:
          'Open Upload, enter the work title, description, budget, and location, then submit the request. Artisans can bid while the request is open.',
      keywords: 'create job request upload budget location customer',
    ),
    _FaqItem(
      category: 'Jobs and bids',
      question: 'How does an artisan submit or edit a bid?',
      answer:
          'Open an available job, enter your amount and message, then send the bid. You can edit it until the customer accepts a bid.',
      keywords: 'artisan bid offer edit amount price',
    ),
    _FaqItem(
      category: 'Jobs and bids',
      question: 'What happens after a bid is accepted?',
      answer:
          'Chat opens for both parties, the agreed amount appears in Wallet, and Job tracking becomes available for ETA, start, and completion updates.',
      keywords: 'accepted won chat wallet tracking start completion',
    ),
    _FaqItem(
      category: 'Tracking',
      question: 'How do I update job progress or ETA?',
      answer:
          'Open the accepted job and use Job tracking. The accepted artisan requests work start and completion, then the customer confirms each step. After completion is confirmed, the customer can rate or comment on the work.',
      keywords: 'timeline eta progress started completed status schedule',
    ),
    _FaqItem(
      category: 'Invoices and wallet',
      question: 'Where is the invoice for accepted work?',
      answer:
          'Open Wallet and select the accepted job. The invoice contains the agreed bid amount, customer, artisan, work location, and invoice number.',
      keywords: 'invoice receipt wallet accepted amount money',
    ),
    _FaqItem(
      category: 'Invoices and wallet',
      question: 'How does an artisan send an invoice?',
      answer:
          'Open the invoice from Wallet and tap Send invoice to chat, or tap the invoice icon inside the customer chat and choose accepted work.',
      keywords: 'send share invoice artisan customer chat pdf',
    ),
    _FaqItem(
      category: 'Invoices and wallet',
      question: 'How do I print or share an invoice PDF?',
      answer:
          'Open an invoice from Wallet or chat, then use Print invoice or Share invoice. Share uses the phone sharing menu for email, messaging, storage, and other apps.',
      keywords: 'print pdf download share outside email whatsapp',
    ),
    _FaqItem(
      category: 'Chat',
      question: 'Why can an artisan not chat before bid acceptance?',
      answer:
          'Job chats stay locked until the customer accepts that artisan’s bid. This keeps negotiations connected to a confirmed job and protects both parties.',
      keywords: 'chat locked disabled before bid accepted',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I reset a forgotten password?',
      answer:
          'On the sign-in screen tap Forgot password, enter your account email, and open the secure link sent to your inbox. Check spam if it is not visible.',
      keywords: 'forgot password reset recovery email login',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I change language or follow phone dark mode?',
      answer:
          'Open Profile, then App settings. Choose a language and select System under Theme to follow the phone’s light or dark appearance automatically.',
      keywords: 'language translation dark mode theme system phone',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'How do I report or block a chat?',
      answer:
          'Open the chat menu and choose Report or Block. Include a clear reason so the admin support team can review the conversation.',
      keywords: 'report block abuse safety conversation',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'What should I verify before paying or visiting a site?',
      answer:
          'Confirm the artisan verification badge, agreed bid, job location, and invoice details. Keep important agreements in chat and never share passwords or verification codes.',
      keywords: 'verification payment safety site visit scam code',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _ticketTitleController.dispose();
    _ticketMessageController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqs {
    final terms = _terms(_query);
    return _faqs.where((faq) {
      if (_category != 'All' && faq.category != _category) return false;
      if (terms.isEmpty) return true;
      final haystack = faq.searchText;
      return terms.every(haystack.contains);
    }).toList(growable: false);
  }

  void _answerQuestion(String value) {
    final terms = _terms(value);
    if (terms.isEmpty) return;
    _FaqItem? best;
    var bestScore = 0;
    for (final faq in _faqs) {
      final score = terms.where(faq.searchText.contains).length;
      if (score > bestScore) {
        best = faq;
        bestScore = score;
      }
    }
    setState(() {
      _answer = bestScore == 0
          ? 'I could not find an exact answer. Search the FAQ categories or send a support ticket below.'
          : best!.answer;
    });
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
      setState(() {});
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
    final categories = <String>[
      'All',
      ..._faqs.map((faq) => faq.category).toSet()
    ];
    final filteredFaqs = _filteredFaqs;
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('AI Support')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            onSubmitted: _answerQuestion,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: settings.t('Search help or ask a question'),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: settings.t('Clear'),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(settings.t(category)),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredFaqs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                settings.t(
                    'No FAQ matched your search. Ask below or contact support.'),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredFaqs.map(
              (faq) => Card(
                child: ExpansionTile(
                  leading: Icon(_categoryIcon(faq.category)),
                  title: Text(settings.t(faq.question)),
                  subtitle: Text(settings.t(faq.category)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(settings.t(faq.answer))],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _query.isEmpty ? null : () => _answerQuestion(_query),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(settings.t('Answer my question')),
          ),
          if (_answer != null) ...[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(settings.t(_answer!))),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 36),
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

class _FaqItem {
  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
  });

  final String category;
  final String question;
  final String answer;
  final String keywords;

  String get searchText =>
      '$category $question $answer $keywords'.toLowerCase();
}

List<String> _terms(String value) => value
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((term) => term.length > 1)
    .toList(growable: false);

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Jobs and bids':
      return Icons.work_outline;
    case 'Tracking':
      return Icons.route_outlined;
    case 'Invoices and wallet':
      return Icons.receipt_long_outlined;
    case 'Chat':
      return Icons.chat_bubble_outline;
    case 'Account':
      return Icons.manage_accounts_outlined;
    case 'Safety':
      return Icons.shield_outlined;
    default:
      return Icons.help_outline;
  }
}
