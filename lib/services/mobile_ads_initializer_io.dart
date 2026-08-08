import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> initializeMobileAds() => MobileAds.instance.initialize().then((_) {});
