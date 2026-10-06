import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Image shown on the full-page search ad. Set with
/// `--dart-define=SEARCH_AD_IMAGE_URL=https://...` at build time.
const String kSearchAdImageUrl = String.fromEnvironment('SEARCH_AD_IMAGE_URL');

/// Optional video (MP4, about 10 seconds) played instead of the image. Set with
/// `--dart-define=SEARCH_AD_VIDEO_URL=https://...`. Falls back to the image if
/// the video cannot be loaded.
const String kSearchAdVideoUrl = String.fromEnvironment('SEARCH_AD_VIDEO_URL');

const _adDuration = Duration(seconds: 10);
const _skipAfter = Duration(seconds: 2);
const _cooldown = Duration(seconds: 60);

DateTime? _lastShownAt;

/// Shows a full-page ad for up to 10 seconds. It can be skipped after 2 seconds.
/// Only called when a search is submitted, and not again within [_cooldown].
/// Resolves when the ad closes, or immediately if the cooldown is active.
Future<void> showSearchAd(BuildContext context) async {
  final now = DateTime.now();
  if (_lastShownAt != null && now.difference(_lastShownAt!) < _cooldown) {
    return;
  }
  _lastShownAt = now;
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => const _SearchAdPage(),
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _SearchAdPage extends StatefulWidget {
  const _SearchAdPage();

  @override
  State<_SearchAdPage> createState() => _SearchAdPageState();
}

class _SearchAdPageState extends State<_SearchAdPage> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  VideoPlayerController? _video;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (kSearchAdVideoUrl.isNotEmpty) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(kSearchAdVideoUrl));
      _video = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.play();
        setState(() => _videoReady = true);
      }).catchError((_) {
        // Keep the image or gradient if the video fails to load.
        if (mounted) setState(() => _videoReady = false);
      });
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 250));
      if (_elapsed >= _adDuration) _close();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Widget _background() {
    final video = _video;
    if (_videoReady && video != null && video.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }
    if (kSearchAdImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: kSearchAdImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1B3D), Color(0xFF1F6F5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          'ProSME',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _close() {
    _ticker?.cancel();
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSkip = _elapsed >= _skipAfter;
    final skipIn = (_skipAfter - _elapsed).inSeconds + 1;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _background(),
            Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Advertisement',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: canSkip
                      ? FilledButton.tonalIcon(
                          onPressed: _close,
                          icon: const Icon(Icons.close),
                          label: const Text('Skip'),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              'Skip in $skipIn s',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
