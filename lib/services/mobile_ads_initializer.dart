import 'mobile_ads_initializer_stub.dart'
    if (dart.library.io) 'mobile_ads_initializer_io.dart' as implementation;

Future<void> initializeMobileAds() => implementation.initializeMobileAds();
