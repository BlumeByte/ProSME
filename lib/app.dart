import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'app/router.dart';
import 'services/app_settings_controller.dart';
import 'services/theme_mode_controller.dart';

class ProSMEApp extends ConsumerWidget {
  const ProSMEApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      title: 'ProSME',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('bn'),
        Locale('zh'),
        Locale('nl'),
        Locale('fr'),
        Locale('de'),
        Locale('el'),
        Locale('ha'),
        Locale('hi'),
        Locale('id'),
        Locale('it'),
        Locale('ja'),
        Locale('ko'),
        Locale('ms'),
        Locale('es'),
        Locale('pt'),
        Locale('ru'),
        Locale('sw'),
        Locale('ta'),
        Locale('th'),
        Locale('tr'),
        Locale('uk'),
        Locale('ur'),
        Locale('vi'),
        Locale('yo'),
        Locale('zu'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
