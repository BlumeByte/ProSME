class DiscountOffer {
  const DiscountOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.percent,
    required this.active,
    required this.start,
    required this.end,
  });

  final String id;
  final String title;
  final String description;
  final double? percent;
  final bool active;
  final DateTime start;
  final DateTime end;

  factory DiscountOffer.fromJson(Map<String, dynamic> json) {
    return DiscountOffer(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      percent: json['percent'] == null
          ? null
          : (json['percent'] as num).toDouble(),
      active: json['active'] as bool,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'percent': percent,
      'active': active,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }
}
