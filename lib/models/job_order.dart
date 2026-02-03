import '../config/constants.dart';

class JobProgress {
  const JobProgress({required this.title, required this.detail});

  final String title;
  final String detail;
}

class JobOrder {
  const JobOrder({
    required this.id,
    required this.invoiceId,
    required this.artisanId,
    required this.userId,
    required this.status,
    required this.meetingType,
    required this.schedule,
    required this.progress,
    required this.eta,
  });

  final String id;
  final String invoiceId;
  final String artisanId;
  final String userId;
  final JobStatus status;
  final String meetingType;
  final DateTime schedule;
  final List<JobProgress> progress;
  final String eta;

  factory JobOrder.fromJson(Map<String, dynamic> json) {
    return JobOrder(
      id: json['id'] as String,
      invoiceId: json['invoiceId'] as String,
      artisanId: json['artisanId'] as String,
      userId: json['userId'] as String,
      status: JobStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => JobStatus.active,
      ),
      meetingType: json['meetingType'] as String,
      schedule: DateTime.parse(json['schedule'] as String),
      progress: (json['progress'] as List<dynamic>)
          .map((progress) => JobProgress(
                title: progress['title'] as String,
                detail: progress['detail'] as String,
              ))
          .toList(),
      eta: json['eta'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'artisanId': artisanId,
      'userId': userId,
      'status': status.name,
      'meetingType': meetingType,
      'schedule': schedule.toIso8601String(),
      'progress': progress
          .map((item) => {
                'title': item.title,
                'detail': item.detail,
              })
          .toList(),
      'eta': eta,
    };
  }
}
