import 'package:flutter/material.dart';
import '../../core/widgets/safe_back_button.dart';

class AiSupportScreen extends StatefulWidget {
  const AiSupportScreen({super.key});

  @override
  State<AiSupportScreen> createState() => _AiSupportScreenState();
}

class _AiSupportScreenState extends State<AiSupportScreen> {
  final _controller = TextEditingController();
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

  @override
  void dispose() {
    _controller.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('AI Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._messages.map(
            (message) => ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(message.question),
              subtitle: Text(message.answer),
              onTap: () => setState(() => _answer = message.answer),
            ),
          ),
          const Divider(),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Ask about Pro SME',
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
                child: Text(_answer!),
              ),
            ),
          ],
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
