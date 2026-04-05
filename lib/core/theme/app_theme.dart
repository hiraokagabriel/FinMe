import 'package:flutter/material.dart';

/// Tokens visuais do FinMe — Modo Claro
/// Fonte da verdade: CLAUDE.md § Padrões visuais
/// NUNCA use valores hex diretamente nos widgets; importe este arquivo.
abstract final class AppColors {
  // ── Superfícies ──────────────────────────────────────────────
  static const Color background      = Color(0xFFF5F7FA);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color sidebar         = Color(0xFFE9EDF2);

  // ── Marca ────────────────────────────────────────────────────
  static const Color primary         = Color(0xFF42A5F5);
  static const Color primarySubtle   = Color(0xFFD3EAFD);

  // ── Conteúdo ─────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF202124);
  static const Color textSecondary   = Color(0xFF5F6368);

  // ── Gráfico ──────────────────────────────────────────────────
  static const Color chartBar        = Color(0xFF42A5F5); // alias de primary

  // ── Status ───────────────────────────────────────────────────
  static const Color warning         = Color(0xFFFF9800);
  static const Color danger          = Color(0xFFE53935);

  // ── Utilitários internos (não exportar como tokens de negócio) ─
  static const Color _divider        = Color(0x1F5F6368); // textSecondary @ 12 %
  static Color get divider => _divider;

  // Barra de limite: verde / laranja / vermelho
  static const Color limitLow        = Color(0xFF43A047);
  static const Color limitMid        = Color(0xFFFF9800);
  static const Color limitHigh       = Color(0xFFE53935);
  static const Color limitTrack      = Color(0xFFE0E0E0);
}

/// Raios de borda padrão
abstract final class AppRadius {
  static const double card    = 8;
  static const double chip    = 4;
  static const double full    = 999;
}

/// Espaçamentos (múltiplos de 4 px)
abstract final class AppSpacing {
  static const double xs  =  4;
  static const double sm  =  8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double h   = 32;
}

/// Estilos de texto reutilizáveis
abstract final class AppText {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

/// ThemeData do FinMe (Modo Claro)
ThemeData finMeLightTheme() {
  const scheme = ColorScheme.light(
    primary:          AppColors.primary,
    onPrimary:        Colors.white,
    secondary:        AppColors.primarySubtle,
    onSecondary:      AppColors.textPrimary,
    surface:          AppColors.surface,
    onSurface:        AppColors.textPrimary,
    error:            AppColors.danger,
    onError:          Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: AppText.screenTitle,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // ── Cards ───────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Color(0x145F6368),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Divider ─────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors._divider,
      thickness: 1,
      space: 1,
    ),

    // ── Drawer / Sidebar ─────────────────────────────────────────
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.sidebar,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    // ── NavigationRail ───────────────────────────────────────────
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.sidebar,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
      indicatorColor: AppColors.primarySubtle,
    ),

    // ── Botões ───────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),

    // ── Inputs ───────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: const BorderSide(color: AppColors._divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: const BorderSide(color: AppColors._divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    ),

    // ── Tipografia base ─────────────────────────────────────────
    textTheme: const TextTheme(
      titleLarge:   AppText.screenTitle,
      titleMedium:  AppText.sectionLabel,
      bodyLarge:    AppText.body,
      bodyMedium:   AppText.body,
      bodySmall:    AppText.secondary,
      labelSmall:   AppText.badge,
    ),

    // ── Snackbar ────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Dialog ──────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      titleTextStyle: AppText.screenTitle,
      contentTextStyle: AppText.body,
    ),

    // ── Switch / Checkbox ────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primarySubtle;
        return AppColors.sidebar;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors._divider, width: 1.5),
    ),

    // ── ListTile ─────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      tileColor: AppColors.surface,
      iconColor: AppColors.textSecondary,
      titleTextStyle: AppText.body,
      subtitleTextStyle: AppText.secondary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
    ),

    // ── ProgressIndicator ────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.limitTrack,
    ),

    // ── PopupMenu / DropdownMenu ──────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.divider),
      ),
      textStyle: AppText.body,
    ),
  );
}
