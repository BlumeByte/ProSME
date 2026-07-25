import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.cardBackground,
    required this.navigationBackground,
    required this.selectedNavigationItem,
    required this.selectedNavigationContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabledBackground,
    required this.disabledText,
    required this.inputFill,
    required this.shadow,
    required this.overlay,
    required this.gradientStart,
    required this.gradientEnd,
    required this.verified,
    required this.pending,
    required this.inProgress,
    required this.cancelled,
    required this.paid,
    required this.refunded,
    required this.disputed,
    required this.neutralStatus,
  });

  static const mint = Color(0xFFE6F2E8);
  static const sage = Color(0xFFBFCBB5);
  static const pistachio = Color(0xFFC9D59A);
  static const olive = Color(0xFF8A9462);
  static const fern = Color(0xFF5F7F4A);
  static const emerald = Color(0xFF0F6B4A);
  static const jade = Color(0xFF147A67);
  static const forest = Color(0xFF1E4D36);
  static const pine = Color(0xFF123C2C);
  static const evergreen = Color(0xFF0B2E22);

  static const light = AppColors(
    primary: emerald,
    primaryDark: forest,
    primaryLight: mint,
    secondary: jade,
    accent: olive,
    background: Color(0xFFF8FBF8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: mint,
    surfaceElevated: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    navigationBackground: Color(0xFFFFFFFF),
    selectedNavigationItem: emerald,
    selectedNavigationContainer: mint,
    textPrimary: pine,
    textSecondary: Color(0xFF486356),
    textMuted: Color(0xFF6F8177),
    border: Color(0xFFD7E2D9),
    divider: Color(0xFFE4EBE5),
    success: emerald,
    warning: Color(0xFF8A6D1D),
    error: Color(0xFFB3261E),
    info: jade,
    disabledBackground: Color(0xFFE3E8E4),
    disabledText: Color(0xFF8C9990),
    inputFill: Color(0xFFF2F7F3),
    shadow: Color(0x1A123C2C),
    overlay: Color(0x660B2E22),
    gradientStart: emerald,
    gradientEnd: jade,
    verified: emerald,
    pending: Color(0xFF8A6D1D),
    inProgress: jade,
    cancelled: Color(0xFFB3261E),
    paid: emerald,
    refunded: Color(0xFF486F66),
    disputed: Color(0xFFC56A1A),
    neutralStatus: Color(0xFF6F8177),
  );

  static const dark = AppColors(
    primary: Color(0xFF7BC5A0),
    primaryDark: emerald,
    primaryLight: forest,
    secondary: Color(0xFF73C9B4),
    accent: pistachio,
    background: Color(0xFF07110C),
    surface: Color(0xFF0B1B13),
    surfaceAlt: Color(0xFF10271B),
    surfaceElevated: Color(0xFF153322),
    cardBackground: Color(0xFF10271B),
    navigationBackground: Color(0xFF09170F),
    selectedNavigationItem: Color(0xFF9AD8B5),
    selectedNavigationContainer: forest,
    textPrimary: Color(0xFFF2F8F3),
    textSecondary: Color(0xFFC5D5C9),
    textMuted: Color(0xFF91A698),
    border: Color(0xFF284936),
    divider: Color(0xFF1D3829),
    success: Color(0xFF7BC5A0),
    warning: Color(0xFFE1C66A),
    error: Color(0xFFFFB4AB),
    info: Color(0xFF73C9B4),
    disabledBackground: Color(0xFF1B2B21),
    disabledText: Color(0xFF6F8177),
    inputFill: Color(0xFF13281C),
    shadow: Color(0x66000000),
    overlay: Color(0x9907110C),
    gradientStart: pine,
    gradientEnd: evergreen,
    verified: Color(0xFF7BC5A0),
    pending: Color(0xFFE1C66A),
    inProgress: Color(0xFF73C9B4),
    cancelled: Color(0xFFFFB4AB),
    paid: Color(0xFF7BC5A0),
    refunded: Color(0xFF91BFB4),
    disputed: Color(0xFFFFB86B),
    neutralStatus: Color(0xFF91A698),
  );

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceElevated;
  final Color cardBackground;
  final Color navigationBackground;
  final Color selectedNavigationItem;
  final Color selectedNavigationContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabledBackground;
  final Color disabledText;
  final Color inputFill;
  final Color shadow;
  final Color overlay;
  final Color gradientStart;
  final Color gradientEnd;
  final Color verified;
  final Color pending;
  final Color inProgress;
  final Color cancelled;
  final Color paid;
  final Color refunded;
  final Color disputed;
  final Color neutralStatus;

  LinearGradient get brandGradient => LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? cardBackground,
    Color? navigationBackground,
    Color? selectedNavigationItem,
    Color? selectedNavigationContainer,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? disabledBackground,
    Color? disabledText,
    Color? inputFill,
    Color? shadow,
    Color? overlay,
    Color? gradientStart,
    Color? gradientEnd,
    Color? verified,
    Color? pending,
    Color? inProgress,
    Color? cancelled,
    Color? paid,
    Color? refunded,
    Color? disputed,
    Color? neutralStatus,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      cardBackground: cardBackground ?? this.cardBackground,
      navigationBackground: navigationBackground ?? this.navigationBackground,
      selectedNavigationItem:
          selectedNavigationItem ?? this.selectedNavigationItem,
      selectedNavigationContainer:
          selectedNavigationContainer ?? this.selectedNavigationContainer,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledText: disabledText ?? this.disabledText,
      inputFill: inputFill ?? this.inputFill,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      verified: verified ?? this.verified,
      pending: pending ?? this.pending,
      inProgress: inProgress ?? this.inProgress,
      cancelled: cancelled ?? this.cancelled,
      paid: paid ?? this.paid,
      refunded: refunded ?? this.refunded,
      disputed: disputed ?? this.disputed,
      neutralStatus: neutralStatus ?? this.neutralStatus,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      navigationBackground:
          Color.lerp(navigationBackground, other.navigationBackground, t)!,
      selectedNavigationItem:
          Color.lerp(selectedNavigationItem, other.selectedNavigationItem, t)!,
      selectedNavigationContainer: Color.lerp(
          selectedNavigationContainer, other.selectedNavigationContainer, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      disabledBackground:
          Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      inProgress: Color.lerp(inProgress, other.inProgress, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      paid: Color.lerp(paid, other.paid, t)!,
      refunded: Color.lerp(refunded, other.refunded, t)!,
      disputed: Color.lerp(disputed, other.disputed, t)!,
      neutralStatus: Color.lerp(neutralStatus, other.neutralStatus, t)!,
    );
  }
}

extension AppColorLookup on ThemeData {
  AppColors get appColors => extension<AppColors>() ?? AppColors.light;
}

extension AppColorsBuildContext on BuildContext {
  AppColors get appColors => Theme.of(this).appColors;
}
