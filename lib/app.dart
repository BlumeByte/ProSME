import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'app/router.dart';
import 'services/app_settings_controller.dart';
import 'services/notification_service.dart';
import 'services/push_token_service.dart';
import 'services/service_providers.dart';
import 'services/theme_mode_controller.dart';

class ProSMEApp extends ConsumerWidget {
  const ProSMEApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    ref.listen(authStateProvider, (_, next) {
      final user = next.valueOrNull;
      if (user == null) {
        unawaited(PushTokenService().unregister());
        return;
      }
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .applyRemoteProfileSettings(
              language: user.appLanguage,
              currencyCode: user.currencyCode,
              emailNotifications: user.emailNotifications,
              phoneNotifications: user.phoneNotifications,
              blockedEmailNotificationTypes: user.blockedEmailNotificationTypes,
              blockedPhoneNotificationTypes: user.blockedPhoneNotificationTypes,
            ),
      );
      unawaited(PushTokenService().registerForUser(user.id));
    });
    ref.watch(foregroundNotificationListenerProvider);
    return MaterialApp.router(
      title: 'ProSME',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      supportedLocales: const [
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
