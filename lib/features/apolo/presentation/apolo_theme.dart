import 'package:flutter/material.dart';

import '../domain/apolo_models.dart';

/// Space Cockpit color palette ported from `web/apolo/styles.css`,
/// with an optional pure-black / high-contrast cockpit mode.
@immutable
class ApoloPalette {
  const ApoloPalette._({
    required this.highContrast,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.elev,
    required this.border,
    required this.text,
    required this.text2,
    required this.lav,
    required this.lav2,
    required this.mint,
    required this.ok,
    required this.warn,
    required this.crit,
  });

  final bool highContrast;
  final Color bg;
  final Color bg2;
  final Color surface;
  final Color elev;
  final Color border;
  final Color text;
  final Color text2;
  final Color lav;
  final Color lav2;
  final Color mint;
  final Color ok;
  final Color warn;
  final Color crit;

  static const ApoloPalette standard = ApoloPalette._(
    highContrast: false,
    bg: Color(0xFF0B0C1E),
    bg2: Color(0xFF15173A),
    surface: Color(0xFF1E2050),
    elev: Color(0xFF2A2D66),
    border: Color(0xFF4A4878),
    text: Color(0xFFF0FFF1),
    text2: Color(0xFFB9B7D8),
    lav: Color(0xFF8367C7),
    lav2: Color(0xFFA994E0),
    mint: Color(0xFFC2F8CB),
    ok: Color(0xFF5BE38C),
    warn: Color(0xFFFFD23F),
    crit: Color(0xFFFF5A5F),
  );

  static const ApoloPalette highContrastMode = ApoloPalette._(
    highContrast: true,
    bg: Color(0xFF000000),
    bg2: Color(0xFF000000),
    surface: Color(0xFF111111),
    elev: Color(0xFF1D1D1D),
    border: Color(0xFFFFFFFF),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFE6E6E6),
    lav: Color(0xFF8367C7),
    lav2: Color(0xFFA994E0),
    mint: Color(0xFFC2F8CB),
    ok: Color(0xFF5BE38C),
    warn: Color(0xFFFFD23F),
    crit: Color(0xFFFF5A5F),
  );

  static ApoloPalette of(bool highContrast) =>
      highContrast ? highContrastMode : standard;

  Color forSeverity(ApoloSeverity severity) => switch (severity) {
    ApoloSeverity.ok => ok,
    ApoloSeverity.warn => warn,
    ApoloSeverity.crit => crit,
  };
}

/// Builds a Material 3 dark theme matching the APOLO Space Cockpit palette.
ThemeData buildApoloTheme({bool highContrast = false}) {
  final p = ApoloPalette.of(highContrast);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.dark(
      surface: p.surface,
      primary: p.lav2,
      secondary: p.mint,
      error: p.crit,
      onSurface: p.text,
      onPrimary: const Color(0xFF16142E),
      outline: p.border,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
    ),
    dividerColor: p.border,
    dialogTheme: DialogThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: p.border),
      ),
    ),
  );
}

IconData apoloModuleIcon(ApoloModuleId id) => switch (id) {
  ApoloModuleId.hidratacion => Icons.water_drop_outlined,
  ApoloModuleId.renal => Icons.biotech_outlined,
  ApoloModuleId.osea => Icons.fitness_center_outlined,
  ApoloModuleId.radiacion => Icons.wb_sunny_outlined,
  ApoloModuleId.inmunidad => Icons.shield_outlined,
  ApoloModuleId.cardio => Icons.favorite_border,
  ApoloModuleId.estres => Icons.bedtime_outlined,
  ApoloModuleId.metabolismo => Icons.bolt_outlined,
};

IconData apoloSeverityIcon(ApoloSeverity severity) => switch (severity) {
  ApoloSeverity.ok => Icons.check_circle_outline,
  ApoloSeverity.warn => Icons.warning_amber_rounded,
  ApoloSeverity.crit => Icons.error_outline,
};

/// Accessible severity pill: always displays BOTH icon and status word
/// (`Stable` / `Attention` / `Critical`), never color alone.
class ApoloStatusChip extends StatelessWidget {
  const ApoloStatusChip({
    super.key,
    required this.severity,
    this.highContrast = false,
    this.compact = false,
  });

  final ApoloSeverity severity;
  final bool highContrast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = ApoloPalette.of(highContrast);
    final Color bg;
    final Color fg;
    final Border? border;

    switch (severity) {
      case ApoloSeverity.ok:
        bg = highContrast
            ? const Color(0xFF000000)
            : palette.ok.withValues(alpha: 0.16);
        fg = palette.ok;
        border = highContrast
            ? Border.all(color: palette.ok, width: 1.5)
            : null;
      case ApoloSeverity.warn:
        bg = palette.warn;
        fg = const Color(0xFF1B1600);
        border = null;
      case ApoloSeverity.crit:
        bg = palette.crit;
        fg = Colors.white;
        border = null;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(apoloSeverityIcon(severity), size: compact ? 12 : 15, color: fg),
          SizedBox(width: compact ? 3 : 5),
          Text(
            severity.label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 10.5 : 12.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
