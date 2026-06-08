import 'package:flutter/material.dart';

class ServiceCategory {
  const ServiceCategory({
    required this.name,
    required this.icon,
    required this.keywords,
  });

  final String name;
  final IconData icon;
  final List<String> keywords;
}

const kServiceCategories = <ServiceCategory>[
  ServiceCategory(
      name: 'Plumbing',
      icon: Icons.plumbing,
      keywords: ['plumb', 'pipe', 'sink', 'toilet', 'water', 'drain']),
  ServiceCategory(
      name: 'Electrical',
      icon: Icons.electrical_services,
      keywords: ['electric', 'wiring', 'light', 'socket', 'power']),
  ServiceCategory(
      name: 'Cleaning',
      icon: Icons.cleaning_services,
      keywords: ['clean', 'laundry', 'wash', 'sanitation']),
  ServiceCategory(
      name: 'Painting',
      icon: Icons.format_paint,
      keywords: ['paint', 'decor', 'wall']),
  ServiceCategory(
      name: 'Gardening',
      icon: Icons.yard,
      keywords: ['garden', 'landscape', 'lawn', 'plants']),
  ServiceCategory(
      name: 'Carpentry',
      icon: Icons.handyman,
      keywords: ['carpenter', 'wood', 'furniture', 'cabinet']),
  ServiceCategory(
      name: 'Masonry',
      icon: Icons.foundation,
      keywords: ['mason', 'brick', 'block', 'concrete', 'tiling']),
  ServiceCategory(
      name: 'Roofing',
      icon: Icons.roofing,
      keywords: ['roof', 'ceiling', 'leak']),
  ServiceCategory(
      name: 'Welding',
      icon: Icons.construction,
      keywords: ['weld', 'metal', 'gate', 'fabrication']),
  ServiceCategory(
      name: 'Auto Repair',
      icon: Icons.car_repair,
      keywords: ['car', 'auto', 'mechanic', 'vehicle']),
  ServiceCategory(
      name: 'Appliance Repair',
      icon: Icons.home_repair_service,
      keywords: ['appliance', 'fridge', 'washing', 'cooker', 'tv']),
  ServiceCategory(
      name: 'IT Services',
      icon: Icons.computer,
      keywords: ['website', 'computer', 'network', 'software', 'it']),
  ServiceCategory(
      name: 'Beauty',
      icon: Icons.spa,
      keywords: ['hair', 'makeup', 'barber', 'beauty']),
  ServiceCategory(
      name: 'Catering',
      icon: Icons.restaurant,
      keywords: ['food', 'cater', 'bake', 'chef']),
  ServiceCategory(
      name: 'Tailoring',
      icon: Icons.content_cut,
      keywords: ['tailor', 'fashion', 'sew', 'dress']),
  ServiceCategory(
      name: 'Photography',
      icon: Icons.camera_alt,
      keywords: ['photo', 'video', 'camera']),
  ServiceCategory(
      name: 'Transport',
      icon: Icons.local_shipping,
      keywords: ['delivery', 'transport', 'driver', 'moving']),
  ServiceCategory(name: 'Other', icon: Icons.more_horiz, keywords: []),
];

String normalizeServiceCategory(String input) {
  final value = input.trim().toLowerCase();
  if (value.isEmpty) return 'Other';
  for (final category in kServiceCategories) {
    if (category.name.toLowerCase() == value) return category.name;
    if (category.keywords.any(value.contains)) return category.name;
  }
  return 'Other';
}

bool fuzzyContains(String text, String query) {
  final normalizedText = text.toLowerCase();
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'[\s,.-]+'))
      .where((token) => token.length > 1)
      .toList(growable: false);
  if (tokens.isEmpty) return true;
  return tokens.any((token) {
    if (normalizedText.contains(token)) return true;
    for (final word in normalizedText.split(RegExp(r'[\s,.-]+'))) {
      if (word.length < 3) continue;
      if (word.startsWith(token) || token.startsWith(word)) return true;
      if (_levenshtein(word, token) <= 1) return true;
    }
    return false;
  });
}

int _levenshtein(String a, String b) {
  final costs = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    var previous = i;
    for (var j = 1; j <= b.length; j++) {
      final current = costs[j];
      costs[j] = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? costs[j - 1]
          : 1 +
              [costs[j - 1], previous, current].reduce((x, y) => x < y ? x : y);
      previous = current;
    }
    costs[0] = i;
  }
  return costs[b.length];
}
