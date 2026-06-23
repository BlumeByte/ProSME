class WorkHistory {
  const WorkHistory({required this.bids, required this.requests});

  final List<BidHistoryItem> bids;
  final List<RequestHistoryItem> requests;
}

class BidHistoryItem {
  const BidHistoryItem({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.artisanName,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String artisanName;
  final double amount;
  final String status;
  final DateTime createdAt;
}

class RequestHistoryItem {
  const RequestHistoryItem({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.budget,
    required this.acceptedAmount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String location;
  final String status;
  final double budget;
  final double? acceptedAmount;
  final DateTime createdAt;
}
