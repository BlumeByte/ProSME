import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildLightTheme() => _buildTheme(
      brightness: Brightness.light,
      colors: AppColors.light,
    );

ThemeData buildDarkTheme() => _buildTheme(
      brightness: Brightness.dark,
      colors: AppColors.dark,
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: isDark ? AppColors.evergreen : Colors.white,
    primaryContainer: colors.primaryLight,
    onPrimaryContainer: isDark ? colors.textPrimary : colors.primaryDark,
    secondary: colors.secondary,
    onSecondary: isDark ? AppColors.evergreen : Colors.white,
    secondaryContainer: colors.surfaceAlt,
    onSecondaryContainer: colors.textPrimary,
    tertiary: colors.accent,
    onTertiary: isDark ? AppColors.evergreen : Colors.white,
    tertiaryContainer: isDark ? colors.surfaceElevated : AppColors.pistachio,
    onTertiaryContainer: colors.textPrimary,
    error: colors.error,
    onError: isDark ? AppColors.evergreen : Colors.white,
    errorContainer: isDark ? const Color(0xFF5D211D) : const Color(0xFFFFEDEB),
    onErrorContainer: colors.error,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceContainerLowest: colors.background,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surfaceAlt,
    surfaceContainerHigh: colors.surfaceElevated,
    surfaceContainerHighest: colors.cardBackground,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.border,
    outlineVariant: colors.divider,
    inverseSurface: isDark ? AppColors.mint : AppColors.evergreen,
    onInverseSurface: isDark ? AppColors.evergreen : AppColors.mint,
    inversePrimary: isDark ? AppColors.emerald : const Color(0xFF9AD8B5),
    scrim: colors.overlay,
    shadow: colors.shadow,
  );

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    extensions: [colors],
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerColor: colors.divider,
    disabledColor: colors.disabledText,
    splashColor: colors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
    highlightColor: colors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
    focusColor: colors.primary.withValues(alpha: isDark ? 0.30 : 0.18),
  );

  final textTheme = _buildTextTheme(base.textTheme, colors);
  final roundedRectangle = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: colors.border),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.navigationBackground,
      foregroundColor: colors.textPrimary,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: colors.textPrimary),
      actionsIconTheme: IconThemeData(color: colors.primary),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: colors.error,
      textColor: isDark ? AppColors.evergreen : Colors.white,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: colors.navigationBackground,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.navigationBackground,
      selectedItemColor: colors.selectedNavigationItem,
      unselectedItemColor: colors.textMuted,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: isDark ? 0 : 8,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.surfaceElevated,
      modalBarrierColor: colors.overlay,
      dragHandleColor: colors.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 0 : 1,
      shadowColor: colors.shadow,
      shape: cardShape,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceElevated,
      ),
      checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceAlt,
      selectedColor: colors.selectedNavigationContainer,
      disabledColor: colors.disabledBackground,
      labelStyle: TextStyle(color: colors.textSecondary),
      secondaryLabelStyle: TextStyle(color: colors.selectedNavigationItem),
      iconTheme: IconThemeData(color: colors.textSecondary),
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: colors.primary,
      headerForegroundColor: colorScheme.onPrimary,
      todayBorder: BorderSide(color: colors.primary),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colors.textPrimary,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.primary : null,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colors.navigationBackground,
      surfaceTintColor: Colors.transparent,
      scrimColor: colors.overlay,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledBackground
              : colors.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledText
              : colorScheme.onPrimary,
        ),
        overlayColor: WidgetStatePropertyAll(
          colorScheme.onPrimary.withValues(alpha: 0.12),
        ),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? 0 : 1,
        ),
        shape: WidgetStatePropertyAll(roundedRectangle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledBackground
              : colors.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledText
              : colorScheme.onPrimary,
        ),
        overlayColor: WidgetStatePropertyAll(
          colorScheme.onPrimary.withValues(alpha: 0.12),
        ),
        shape: WidgetStatePropertyAll(roundedRectangle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colorScheme.onPrimary,
      focusColor: colors.primaryLight,
      hoverColor: colors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledText
              : colors.primary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? colors.primaryLight
              : Colors.transparent,
        ),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    iconTheme: IconThemeData(color: colors.textSecondary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: colors.textSecondary),
      hintStyle: TextStyle(color: colors.textMuted),
      helperStyle: TextStyle(color: colors.textMuted),
      errorStyle: TextStyle(color: colors.error),
      prefixIconColor: colors.textMuted,
      suffixIconColor: colors.primary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.error, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.disabledBackground),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.primary,
      textColor: colors.textPrimary,
      subtitleTextStyle:
          textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      selectedColor: colors.selectedNavigationItem,
      selectedTileColor: colors.selectedNavigationContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minVerticalPadding: 12,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navigationBackground,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.selectedNavigationContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.selectedNavigationItem
              : colors.textMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.selectedNavigationItem
              : colors.textMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.navigationBackground,
      indicatorColor: colors.selectedNavigationContainer,
      selectedIconTheme: IconThemeData(color: colors.selectedNavigationItem),
      unselectedIconTheme: IconThemeData(color: colors.textMuted),
      selectedLabelTextStyle: TextStyle(color: colors.selectedNavigationItem),
      unselectedLabelTextStyle: TextStyle(color: colors.textMuted),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledText
              : colors.primary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? colors.disabledBackground
                : colors.border,
          ),
        ),
        overlayColor:
            WidgetStatePropertyAll(colors.primary.withValues(alpha: 0.10)),
        shape: WidgetStatePropertyAll(roundedRectangle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: colors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.disabledBackground,
      circularTrackColor: colors.disabledBackground,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.textMuted,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(colors.inputFill),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor:
          WidgetStatePropertyAll(colors.primary.withValues(alpha: 0.08)),
      shadowColor: WidgetStatePropertyAll(colors.shadow),
      hintStyle: WidgetStatePropertyAll(TextStyle(color: colors.textMuted)),
      textStyle: WidgetStatePropertyAll(TextStyle(color: colors.textPrimary)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.selectedNavigationContainer
              : colors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.selectedNavigationItem
              : colors.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? colors.surfaceElevated : AppColors.evergreen,
      contentTextStyle:
          TextStyle(color: isDark ? colors.textPrimary : Colors.white),
      actionTextColor: isDark ? colors.primary : AppColors.pistachio,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.disabledBackground,
      ),
      trackOutlineColor: WidgetStatePropertyAll(colors.border),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.selectedNavigationItem,
      unselectedLabelColor: colors.textMuted,
      indicatorColor: colors.primary,
      dividerColor: colors.divider,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledText
              : colors.primary,
        ),
        overlayColor:
            WidgetStatePropertyAll(colors.primary.withValues(alpha: 0.10)),
        shape: WidgetStatePropertyAll(roundedRectangle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.primary.withValues(alpha: 0.22),
      selectionHandleColor: colors.primary,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colors.surfaceElevated,
      hourMinuteColor: colors.surfaceAlt,
      hourMinuteTextColor: colors.textPrimary,
      dialBackgroundColor: colors.surfaceAlt,
      dialHandColor: colors.primary,
      dialTextColor: colors.textPrimary,
      entryModeIconColor: colors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? AppColors.mint : AppColors.evergreen,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        color: isDark ? AppColors.evergreen : Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base, AppColors colors) {
  return base
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(color: colors.textPrimary),
        displayMedium: base.displayMedium?.copyWith(color: colors.textPrimary),
        displaySmall: base.displaySmall?.copyWith(color: colors.textPrimary),
        headlineLarge: base.headlineLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.titleMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: base.titleSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.bodyLarge?.copyWith(color: colors.textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: colors.textSecondary),
        bodySmall: base.bodySmall?.copyWith(color: colors.textMuted),
        labelLarge: base.labelLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: base.labelMedium?.copyWith(color: colors.textSecondary),
        labelSmall: base.labelSmall?.copyWith(color: colors.textMuted),
      )
      .apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      );
}
