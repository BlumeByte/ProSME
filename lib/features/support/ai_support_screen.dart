import 'package:flutter/material.dart';

class AiSupportScreen extends StatelessWidget {
  const AiSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.smart_toy),
            title: Text('How to book a job?'),
            subtitle: Text('Select a listing, chat, and request invoice.'),
          ),
          const ListTile(
            leading: Icon(Icons.smart_toy),
            title: Text('How to pay with MoMo?'),
            subtitle: Text('Choose Paystack MoMo on invoice checkout.'),
          ),
          const Divider(),
          TextField(
            decoration: InputDecoration(
              hintText: 'Ask a question',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
