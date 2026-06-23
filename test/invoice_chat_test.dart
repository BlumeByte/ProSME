import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/models/chat_models.dart';
import 'package:prosme/models/wallet_transaction.dart';

void main() {
  test('invoice chat payload round-trips and has a readable preview', () {
    final transaction = WalletTransaction(
      id: 'wallet-1',
      jobId: 'job-1',
      bidId: 'bid-1',
      customerId: 'customer-1',
      artisanId: 'artisan-1',
      amount: 850,
      currency: 'GHS',
      eventType: 'bid_accepted',
      invoiceNumber: 'PSME-BID1',
      jobTitle: 'Kitchen plumbing',
      jobLocation: 'Accra',
      customerName: 'Customer',
      customerEmail: 'customer@example.com',
      artisanName: 'Artisan',
      artisanEmail: 'artisan@example.com',
      paymentStatus: 'agreed',
      workStatus: 'accepted',
      completedAt: null,
      createdAt: DateTime.utc(2026, 6, 23),
    );
    final content = jsonEncode(transaction.toJson());
    final message = ChatMessage(
      id: 'message-1',
      threadId: 'thread-1',
      senderId: 'artisan-1',
      type: MessageType.invoice,
      content: content,
      createdAt: DateTime.utc(2026, 6, 23),
    );

    final restored = WalletTransaction.fromJson(
      Map<String, dynamic>.from(jsonDecode(content) as Map),
    );

    expect(message.threadPreview, 'Invoice PSME-BID1');
    expect(restored.amount, 850);
    expect(restored.customerId, 'customer-1');
    expect(restored.artisanId, 'artisan-1');
  });
}
