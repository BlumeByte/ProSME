import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'service_categories.dart';

/// The built-in Material icon for one of [kServiceCategories], or null when
/// [name] is a custom category an artisan typed that isn't one of them.
IconData? staticCategoryIcon(String name) {
  final lower = name.trim().toLowerCase();
  for (final category in kServiceCategories) {
    if (category.name.toLowerCase() == lower) return category.icon;
  }
  return null;
}

const _cachePrefix = 'category_icon_svg_v1_';
const _missSentinel = '__none__';

final Map<String, Future<String?>> _inFlight = {};

/// Fetches (and caches on-device after the first lookup) a simple line-art
/// SVG icon for a category name that isn't one of the built-in categories,
/// via Iconify's free, keyless search API (iconify.design). Returns null
/// when no reasonable icon could be found, so callers can fall back to a
/// generic icon instead of leaving the tile blank.
Future<String?> fetchOnlineCategoryIconSvg(String name) {
  final key = name.trim().toLowerCase();
  if (key.isEmpty) return Future.value(null);
  return _inFlight[key] ??= _resolve(key).whenComplete(() {
    _inFlight.remove(key);
  });
}

Future<String?> _resolve(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$key';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return cached == _missSentinel ? null : cached;
    }
    final svg = await _fetchFromIconify(key);
    await prefs.setString(cacheKey, svg ?? _missSentinel);
    return svg;
  } catch (_) {
    return null;
  }
}

Future<String?> _fetchFromIconify(String query) async {
  final searchUri = Uri.https('api.iconify.design', '/search', {
    'query': query,
    'limit': '1',
  });
  final searchResponse =
      await http.get(searchUri).timeout(const Duration(seconds: 6));
  if (searchResponse.statusCode != 200) return null;
  final decoded = jsonDecode(searchResponse.body);
  final icons =
      decoded is Map<String, dynamic> ? decoded['icons'] as List<dynamic>? : null;
  if (icons == null || icons.isEmpty) return null;
  final iconId = icons.first.toString();
  final separator = iconId.indexOf(':');
  if (separator <= 0) return null;
  final prefix = iconId.substring(0, separator);
  final name = iconId.substring(separator + 1);
  final svgUri = Uri.https('api.iconify.design', '/$prefix/$name.svg');
  final svgResponse =
      await http.get(svgUri).timeout(const Duration(seconds: 6));
  if (svgResponse.statusCode != 200 || !svgResponse.body.contains('<svg')) {
    return null;
  }
  return svgResponse.body;
}

/// An icon for a listing/job category: the matching built-in Material icon
/// when there is one, otherwise an auto-fetched online icon (cached on
/// device after the first lookup) for a category an artisan typed that
/// isn't one of the built-in ones — falling back to a generic icon while
/// that lookup is in flight, or if it fails.
class CategoryIcon extends StatefulWidget {
  const CategoryIcon({
    super.key,
    required this.categoryName,
    this.size = 24,
    this.color,
  });

  final String categoryName;
  final double size;
  final Color? color;

  @override
  State<CategoryIcon> createState() => _CategoryIconState();
}

class _CategoryIconState extends State<CategoryIcon> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _maybeFetch();
  }

  @override
  void didUpdateWidget(covariant CategoryIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryName != widget.categoryName) _maybeFetch();
  }

  void _maybeFetch() {
    _future = staticCategoryIcon(widget.categoryName) == null
        ? fetchOnlineCategoryIconSvg(widget.categoryName)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final staticIcon = staticCategoryIcon(widget.categoryName);
    if (staticIcon != null) {
      return Icon(staticIcon, size: widget.size, color: widget.color);
    }
    final fallback =
        Icon(Icons.category_outlined, size: widget.size, color: widget.color);
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        final svg = snapshot.data;
        if (svg == null) return fallback;
        return SvgPicture.string(
          svg,
          width: widget.size,
          height: widget.size,
          colorFilter: widget.color == null
              ? null
              : ColorFilter.mode(widget.color!, BlendMode.srcIn),
        );
      },
    );
  }
}
