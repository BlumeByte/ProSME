import '../config/constants.dart';

class InvoiceLine {
  const InvoiceLine({
    required this.label,
    required this.quantity,
    required this.amount,
  });

  final String label;
  final int quantity;
  final double amount;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      label: json['label'] as String,
      quantity: json['quantity'] as int,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'quantity': quantity,
      'amount': amount,
    };
  }
}

class Invoice {
  const Invoice({
    required this.id,
    required this.threadId,
    required this.listingId,
    required this.artisanId,
    required this.userId,
    required this.lines,
    required this.subtotal,
    required this.fee,
    required this.total,
    required this.paymentMethod,
    required this.status,
  });

  final String id;
  final String threadId;
  final String listingId;
  final String artisanId;
  final String userId;
  final List<InvoiceLine> lines;
  final double subtotal;
  final double fee;
  final double total;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      listingId: json['listingId'] as String,
      artisanId: json['artisanId'] as String,
      userId: json['userId'] as String,
      lines: (json['lines'] as List<dynamic>)
          .map((line) => InvoiceLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      fee: (json['fee'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (method) => method.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      status: InvoiceStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => InvoiceStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'listingId': listingId,
      'artisanId': artisanId,
      'userId': userId,
      'lines': lines.map((line) => line.toJson()).toList(),
      'subtotal': subtotal,
      'fee': fee,
      'total': total,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
    };
  }
}
