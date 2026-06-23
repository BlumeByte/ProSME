class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.jobId,
    required this.bidId,
    required this.customerId,
    required this.artisanId,
    required this.amount,
    required this.currency,
    required this.eventType,
    required this.invoiceNumber,
    required this.jobTitle,
    required this.jobLocation,
    required this.customerName,
    required this.customerEmail,
    required this.artisanName,
    required this.artisanEmail,
    required this.paymentStatus,
    required this.workStatus,
    required this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String bidId;
  final String customerId;
  final String artisanId;
  final double amount;
  final String currency;
  final String eventType;
  final String invoiceNumber;
  final String jobTitle;
  final String jobLocation;
  final String customerName;
  final String customerEmail;
  final String artisanName;
  final String artisanEmail;
  final String paymentStatus;
  final String workStatus;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final bidId = (json['bid_id'] ?? '').toString();
    return WalletTransaction(
      id: id,
      jobId: (json['job_id'] ?? '').toString(),
      bidId: bidId,
      customerId: (json['user_id'] ?? '').toString(),
      artisanId: (json['artisan_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] ?? 'GHS').toString(),
      eventType: (json['event_type'] ?? 'bid_accepted').toString(),
      invoiceNumber: (json['invoice_number'] ?? '').toString().isNotEmpty
          ? json['invoice_number'].toString()
          : 'PSME-${_shortId(bidId.isEmpty ? id : bidId)}',
      jobTitle: (json['job_title'] ?? '').toString(),
      jobLocation: (json['job_location'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerEmail: (json['customer_email'] ?? '').toString(),
      artisanName: (json['artisan_name'] ?? '').toString(),
      artisanEmail: (json['artisan_email'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? 'agreed').toString(),
      workStatus: (json['work_status'] ?? 'accepted').toString(),
      completedAt: DateTime.tryParse((json['completed_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  WalletTransaction copyWith({
    String? jobTitle,
    String? jobLocation,
    String? customerName,
    String? customerEmail,
    String? artisanName,
    String? artisanEmail,
  }) {
    return WalletTransaction(
      id: id,
      jobId: jobId,
      bidId: bidId,
      customerId: customerId,
      artisanId: artisanId,
      amount: amount,
      currency: currency,
      eventType: eventType,
      invoiceNumber: invoiceNumber,
      jobTitle: jobTitle ?? this.jobTitle,
      jobLocation: jobLocation ?? this.jobLocation,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      artisanName: artisanName ?? this.artisanName,
      artisanEmail: artisanEmail ?? this.artisanEmail,
      paymentStatus: paymentStatus,
      workStatus: workStatus,
      completedAt: completedAt,
      createdAt: createdAt,
    );
  }
}

String _shortId(String value) {
  final normalized = value.replaceAll('-', '').toUpperCase();
  if (normalized.isEmpty) return 'PENDING';
  final end = normalized.length < 12 ? normalized.length : 12;
  return normalized.substring(0, end);
}
