import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/constants.dart';
import '../../services/app_launch_service.dart';

/// A Google AdMob banner styled as one slide inside the home opening
/// carousel (see `_BannerSlider` in user_home_screen.dart) — same rounded
/// card shape as the other slides, with a clearly-labelled "Advertisement"
/// tag. The carousel's own auto-advance timer keeps rotating past it on the
/// same schedule as every other slide, so nothing extra is needed to "skip
/// to the next" slide once it has shown.
class AdMobCarouselSlide extends StatefulWidget {
  const AdMobCarouselSlide({super.key, this.height = 196});

  final double height;

  @override
  State<AdMobCarouselSlide> createState() => _AdMobCarouselSlideState();
}

class _AdMobCarouselSlideState extends State<AdMobCarouselSlide> {
  static const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!AppLaunchService.canShowAds) return;
    _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: kReleaseMode ? kAdMobBannerAdUnitId : _testBannerAdUnitId,
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final theme = Theme.of(context);
    return Container(
      height: widget.height,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isLoaded && ad != null)
            SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            )
          else
            Icon(
              Icons.campaign_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          Positioned(
            left: 10,
            top: 10,
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
        ],
      ),
    );
  }
}

class AdMobBannerSlot extends StatefulWidget {
  const AdMobBannerSlot({super.key});

  @override
  State<AdMobBannerSlot> createState() => _AdMobBannerSlotState();
}

class _AdMobBannerSlotState extends State<AdMobBannerSlot> {
  static const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _ad;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!AppLaunchService.canShowAds) return;
    _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: kReleaseMode ? kAdMobBannerAdUnitId : _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: Center(child: AdWidget(ad: ad)),
        ),
      ),
    );
  }
}
