// AUTO-GENERATED - DO NOT EDIT
// Generated from docs/ui/tokens.md by design-token-exporter CLI
// To regenerate: dart tools/design-token-exporter/cli.dart

import 'package:flutter/material.dart';

/// WireTuner Design Token Registry
///
/// This file provides strongly-typed access to all design tokens used
/// throughout the WireTuner application. Tokens are organized into semantic
/// categories and exposed via ThemeExtension for type-safe access.
///
/// Usage:
/// ```dart
/// final tokens = Theme.of(context).extension<WireTunerTokens>()!;
/// final bgColor = tokens.surface.base;
/// final spacing = tokens.spacing.spacing8;
/// ```

// ============================================================
// Color Token Models
// ============================================================

/// Surface color tokens for window chrome and panel backgrounds
class SurfaceColors {
  const SurfaceColors({
    required this.base,
    required this.raised,
    required this.overlay,
  });

  /// Primary window chrome, Navigator background, inactive tool docks (13.8:1 contrast)
  final Color base;

  /// Elevated panels such as Inspector and Layer stacks (11.1:1 contrast)
  final Color raised;

  /// Modal scrims, quick actions, toast backgrounds (applies blur(8px) on macOS)
  final Color overlay;
}

/// Canvas and artboard color tokens
class CanvasColors {
  const CanvasColors({
    required this.infinite,
    required this.artboardDefault,
    required this.artboardBorder,
  });

  /// Root viewport background
  final Color infinite;

  /// Default artboard fill color
  final Color artboardDefault;

  /// Artboard border color for crisp separation against dark chrome
  final Color artboardBorder;
}

/// Grid color tokens for viewport
class GridColors {
  const GridColors({
    required this.minor,
    required this.major,
  });

  /// Minor grid lines
  final Color minor;

  /// Major grid intersections
  final Color major;
}

/// Accent color tokens with interaction states
class AccentColor {
  const AccentColor({
    required this.value,
    required this.hover,
    required this.pressed,
    this.focusRing,
  });

  final Color value;
  final Color hover;
  final Color pressed;
  final Color? focusRing;
}

/// All accent colors for primary interactions
class AccentColors {
  const AccentColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// Primary accent: buttons, tool activation, active tabs, event scrubber
  final AccentColor primary;

  /// Secondary actions, sampling toggle, idle collaboration presence
  final AccentColor secondary;

  /// Positive reinforcement, successful exports, saved state
  final AccentColor tertiary;
}

/// Semantic alert color with on-color text
class SemanticColor {
  const SemanticColor({
    required this.value,
    required this.onColor,
  });

  final Color value;
  final Color onColor;
}

/// Semantic alert colors
class SemanticColors {
  const SemanticColors({
    required this.warning,
    required this.error,
    required this.info,
  });

  /// Destructive previews, disk space warnings
  final SemanticColor warning;

  /// Failed exports, corrupted files, OT conflicts
  final SemanticColor error;

  /// Guidance toasts, intelligent zoom suggestions, help overlays
  final SemanticColor info;
}

/// Anchor visualization style
class AnchorStyle {
  const AnchorStyle({
    required this.fill,
    required this.stroke,
    required this.size,
  });

  final Color fill;
  final Color stroke;
  final double size;
}

/// Anchor visualization colors
class AnchorColors {
  const AnchorColors({
    required this.smooth,
    required this.corner,
    required this.tangent,
  });

  /// Smooth anchor point visualization (5px radius)
  final AnchorStyle smooth;

  /// Corner anchor point visualization (7px size)
  final AnchorStyle corner;

  /// Tangent anchor point visualization (7px size)
  final AnchorStyle tangent;
}

/// Collaboration presence palette (cycled for 10+ participants)
class PresenceColors {
  const PresenceColors({
    required this.palette,
  });

  final List<Color> palette;

  /// Get presence color by participant index
  Color forParticipant(int index) => palette[index % palette.length];
}

/// Overlay style with fill and stroke
class OverlayStyle {
  const OverlayStyle({
    required this.fill,
    required this.stroke,
  });

  final Color fill;
  final Color stroke;
}

/// Overlay colors for selections and visual feedback
class OverlayColors {
  const OverlayColors({
    required this.selection,
    required this.marquee,
    required this.performanceHeatmap,
    required this.eventPath,
    required this.eventSelection,
    required this.eventViewport,
    required this.eventDocument,
  });

  /// Selection overlay for selected objects
  final OverlayStyle selection;

  /// Marquee selection box
  final Color marquee;

  /// Performance heatmap gradient colors (low to high density)
  final List<Color> performanceHeatmap;

  /// Event category: path operations
  final Color eventPath;

  /// Event category: selection changes
  final Color eventSelection;

  /// Event category: viewport changes
  final Color eventViewport;

  /// Event category: document changes
  final Color eventDocument;
}

/// Focus ring style
class FocusRingStyle {
  const FocusRingStyle({
    required this.outer,
    required this.inner,
    required this.width,
  });

  final Color outer;
  final Color inner;
  final double width;
}

/// FPS indicator colors based on performance
class FpsColors {
  const FpsColors({
    required this.idle,
    required this.warning,
    required this.error,
  });

  final Color idle;
  final Color warning;
  final Color error;
}

/// Text color tokens
class TextColors {
  const TextColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.onAccent,
  });

  /// Primary text color on dark surfaces
  final Color primary;

  /// Secondary text for less prominent content (72% opacity)
  final Color secondary;

  /// Tertiary text for disabled or hint text (48% opacity)
  final Color tertiary;

  /// Text color on accent backgrounds
  final Color onAccent;
}

// ============================================================
// Typography Token Models
// ============================================================

/// Typography token with font properties
class TypographyToken {
  const TypographyToken({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
  });

  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final FontWeight fontWeight;

  /// Convert to Flutter TextStyle
  TextStyle toTextStyle({Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// All typography tokens
class TypographyTokens {
  const TypographyTokens({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.monoSm,
    required this.monoMd,
  });

  /// Metadata badges, tooltip footers (10px)
  final TypographyToken xxs;

  /// Secondary labels, Navigator counts (12px)
  final TypographyToken xs;

  /// Layer list, artboard names (13px)
  final TypographyToken sm;

  /// Inspector labels, status bar (14px)
  final TypographyToken md;

  /// Window titles, major callouts (16px)
  final TypographyToken lg;

  /// Section headers (20px, SemiBold)
  final TypographyToken xl;

  /// Onboarding panels, marketing modals (24px, SemiBold)
  final TypographyToken xxl;

  /// Coordinate readouts, event log sequences (12px mono)
  final TypographyToken monoSm;

  /// Sampling inspector, JSON viewer (14px mono)
  final TypographyToken monoMd;
}

// ============================================================
// Spacing Token Models
// ============================================================

/// Spacing tokens on 4px baseline grid
class SpacingTokens {
  const SpacingTokens({
    required this.spacing2,
    required this.spacing4,
    required this.spacing6,
    required this.spacing8,
    required this.spacing12,
    required this.spacing16,
    required this.spacing20,
    required this.spacing24,
    required this.spacing32,
    required this.spacing48,
  });

  /// 2px - Micro gaps for icon stacking
  final double spacing2;

  /// 4px - Icon-to-label gap in toolbar buttons
  final double spacing4;

  /// 6px - Dense table rows (event log)
  final double spacing6;

  /// 8px - Inspector field groups, toast padding
  final double spacing8;

  /// 12px - Card padding (thumbnails, sampling cards)
  final double spacing12;

  /// 16px - Window and modal margins
  final double spacing16;

  /// 20px - Artboard boundary gutters at 100% zoom
  final double spacing20;

  /// 24px - Cross-panel spacing between docked columns
  final double spacing24;

  /// 32px - Onboarding hero sections, empty states
  final double spacing32;

  /// 48px - Large marketing overlays (rare in production)
  final double spacing48;
}

// ============================================================
// Sizing Token Models
// ============================================================

/// Button sizing token
class ButtonSize {
  const ButtonSize({
    required this.height,
    required this.paddingHorizontal,
  });

  final double height;
  final double paddingHorizontal;
}

/// Input field sizing token
class InputSize {
  const InputSize({
    required this.height,
    required this.padding,
    required this.iconWidth,
  });

  final double height;
  final double padding;
  final double iconWidth;
}

/// Thumbnail sizing token
class ThumbnailSize {
  const ThumbnailSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}

/// All component sizing tokens
class SizingTokens {
  const SizingTokens({
    required this.buttonCompact,
    required this.buttonDefault,
    required this.inputSlot,
    required this.iconSm,
    required this.iconMd,
    required this.iconLg,
    required this.iconXl,
    required this.thumbnailSm,
    required this.thumbnailLg,
    required this.focusRingOuter,
    required this.focusRingInner,
  });

  /// Compact button: 28px h × 8px padding
  final ButtonSize buttonCompact;

  /// Default button: 32px h × 12px padding
  final ButtonSize buttonDefault;

  /// Input field: 36px h × 12px padding, 20px icon
  final InputSize inputSlot;

  /// Small icon: 12px
  final double iconSm;

  /// Medium icon: 16px
  final double iconMd;

  /// Large icon: 20px
  final double iconLg;

  /// Extra-large icon: 32px
  final double iconXl;

  /// Small thumbnail: 120×90px
  final ThumbnailSize thumbnailSm;

  /// Large thumbnail: 208×156px
  final ThumbnailSize thumbnailLg;

  /// Focus ring outer width: 2px
  final double focusRingOuter;

  /// Focus ring inner width: 1px
  final double focusRingInner;
}

// ============================================================
// Border Radius Token Models
// ============================================================

/// Border radius tokens
class RadiusTokens {
  const RadiusTokens({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.full,
  });

  /// 2px - Subtle rounding
  final double sm;

  /// 4px - Standard buttons, inputs
  final double md;

  /// 8px - Cards, panels
  final double lg;

  /// 12px - Large containers
  final double xl;

  /// 999px - Circular elements
  final double full;
}

// ============================================================
// Shadow Token Models
// ============================================================

/// Shadow token
class ShadowToken {
  const ShadowToken({
    required this.offsetX,
    required this.offsetY,
    required this.blurRadius,
    required this.color,
  });

  final double offsetX;
  final double offsetY;
  final double blurRadius;
  final Color color;

  /// Convert to Flutter BoxShadow
  BoxShadow toBoxShadow() {
    return BoxShadow(
      offset: Offset(offsetX, offsetY),
      blurRadius: blurRadius,
      color: color,
    );
  }
}

/// All shadow tokens
class ShadowTokens {
  const ShadowTokens({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  /// Subtle elevation for input fields
  final ShadowToken sm;

  /// Standard card elevation
  final ShadowToken md;

  /// Modal and floating panel elevation
  final ShadowToken lg;

  /// Maximum elevation for overlays
  final ShadowToken xl;
}

// ============================================================
// Main Theme Extension
// ============================================================

/// WireTuner Design Token Theme Extension
///
/// Provides strongly-typed access to all design tokens through Flutter's
/// ThemeExtension system. Access via:
/// ```dart
/// final tokens = Theme.of(context).extension<WireTunerTokens>()!;
/// ```
class WireTunerTokens extends ThemeExtension<WireTunerTokens> {
  const WireTunerTokens({
    required this.surface,
    required this.canvas,
    required this.grid,
    required this.accent,
    required this.semantic,
    required this.anchor,
    required this.presence,
    required this.overlays,
    required this.focus,
    required this.fps,
    required this.text,
    required this.typography,
    required this.spacing,
    required this.sizing,
    required this.radius,
    required this.shadow,
  });

  final SurfaceColors surface;
  final CanvasColors canvas;
  final GridColors grid;
  final AccentColors accent;
  final SemanticColors semantic;
  final AnchorColors anchor;
  final PresenceColors presence;
  final OverlayColors overlays;
  final FocusRingStyle focus;
  final FpsColors fps;
  final TextColors text;
  final TypographyTokens typography;
  final SpacingTokens spacing;
  final SizingTokens sizing;
  final RadiusTokens radius;
  final ShadowTokens shadow;

  /// Default light theme tokens (WireTuner uses dark-default UI)
  static WireTunerTokens get light => _defaultTokens;

  /// Default dark theme tokens (primary theme)
  static WireTunerTokens get dark => _defaultTokens;

  /// Default token values
  static const WireTunerTokens _defaultTokens = WireTunerTokens(
    surface: SurfaceColors(
      base: Color(0xFF0D1015),
      raised: Color(0xFF141920),
      overlay: Color(0xE01C222C),
    ),
    canvas: CanvasColors(
      infinite: Color(0xFF1A1D22),
      artboardDefault: Color(0xFFF7F8FA),
      artboardBorder: Color(0xFFE1E3E8),
    ),
    grid: GridColors(
      minor: Color(0x993A3F49),
      major: Color(0xE64F5562),
    ),
    accent: AccentColors(
      primary: AccentColor(
        value: Color(0xFF4FB2FF),
        hover: Color(0xFF6DC2FF),
        pressed: Color(0xFF3D94D6),
        focusRing: Color(0xFF87D2FF),
      ),
      secondary: AccentColor(
        value: Color(0xFF6F7CFF),
        hover: Color(0xFF93A1FF),
        pressed: Color(0xFF6F7CFF),
      ),
      tertiary: AccentColor(
        value: Color(0xFF5CFFCE),
        hover: Color(0xFF5CFFCE),
        pressed: Color(0xFF5CFFCE),
      ),
    ),
    semantic: SemanticColors(
      warning: SemanticColor(
        value: Color(0xFFFFB347),
        onColor: Color(0xFF0D1015),
      ),
      error: SemanticColor(
        value: Color(0xFFFF5C73),
        onColor: Color(0xFF0D1015),
      ),
      info: SemanticColor(
        value: Color(0xFF53D3FF),
        onColor: Color(0xFF0D1015),
      ),
    ),
    anchor: AnchorColors(
      smooth: AnchorStyle(
        fill: Color(0xFFFF5C5C),
        stroke: Color(0xFF080A0E),
        size: 5.0,
      ),
      corner: AnchorStyle(
        fill: Color(0xFF080A0E),
        stroke: Color(0xFFF7F8FA),
        size: 7.0,
      ),
      tangent: AnchorStyle(
        fill: Color(0xFFFFA345),
        stroke: Color(0xFF080A0E),
        size: 7.0,
      ),
    ),
    presence: PresenceColors(
      palette: [
        Color(0xFFFF9BAE),
        Color(0xFFFFD66F),
        Color(0xFF5DFFB1),
        Color(0xFF7FE2FF),
        Color(0xFFB18CFF),
        Color(0xFFFF7F5E),
        Color(0xFF6FE5FF),
        Color(0xFF9FED72),
        Color(0xFFFFCFEC),
        Color(0xFF8DF0FF),
      ],
    ),
    overlays: OverlayColors(
      selection: OverlayStyle(
        fill: Color(0x144FB2FF),
        stroke: Color(0x994FB2FF),
      ),
      marquee: Color(0xE66F7CFF),
      performanceHeatmap: [
        Color(0xFF1D91F0),
        Color(0xFF70F1C6),
        Color(0xFFF8EB6B),
      ],
      eventPath: Color(0xFFFF6F91),
      eventSelection: Color(0xFFFFC75F),
      eventViewport: Color(0xFF9CFFFA),
      eventDocument: Color(0xFFC087F9),
    ),
    focus: FocusRingStyle(
      outer: Color(0xFF4FB2FF),
      inner: Color(0xFF0D1015),
      width: 2.0,
    ),
    fps: FpsColors(
      idle: Color(0xFF5CFFCE),
      warning: Color(0xFFFFB347),
      error: Color(0xFFFF5C73),
    ),
    text: TextColors(
      primary: Color(0xFFF7F8FA),
      secondary: Color(0xB8F7F8FA),
      tertiary: Color(0x7AF7F8FA),
      onAccent: Color(0xFF0D1015),
    ),
    typography: TypographyTokens(
      xxs: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 10.0,
        lineHeight: 14.0,
        fontWeight: FontWeight.w400,
      ),
      xs: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 12.0,
        lineHeight: 16.0,
        fontWeight: FontWeight.w400,
      ),
      sm: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13.0,
        lineHeight: 18.0,
        fontWeight: FontWeight.w400,
      ),
      md: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 14.0,
        lineHeight: 20.0,
        fontWeight: FontWeight.w400,
      ),
      lg: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 16.0,
        lineHeight: 22.0,
        fontWeight: FontWeight.w400,
      ),
      xl: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 20.0,
        lineHeight: 26.0,
        fontWeight: FontWeight.w600,
      ),
      xxl: TypographyToken(
        fontFamily: 'IBM Plex Sans',
        fontSize: 24.0,
        lineHeight: 30.0,
        fontWeight: FontWeight.w600,
      ),
      monoSm: TypographyToken(
        fontFamily: 'IBM Plex Mono',
        fontSize: 12.0,
        lineHeight: 16.0,
        fontWeight: FontWeight.w400,
      ),
      monoMd: TypographyToken(
        fontFamily: 'IBM Plex Mono',
        fontSize: 14.0,
        lineHeight: 20.0,
        fontWeight: FontWeight.w400,
      ),
    ),
    spacing: SpacingTokens(
      spacing2: 2.0,
      spacing4: 4.0,
      spacing6: 6.0,
      spacing8: 8.0,
      spacing12: 12.0,
      spacing16: 16.0,
      spacing20: 20.0,
      spacing24: 24.0,
      spacing32: 32.0,
      spacing48: 48.0,
    ),
    sizing: SizingTokens(
      buttonCompact: ButtonSize(height: 28.0, paddingHorizontal: 8.0),
      buttonDefault: ButtonSize(height: 32.0, paddingHorizontal: 12.0),
      inputSlot: InputSize(height: 36.0, padding: 12.0, iconWidth: 20.0),
      iconSm: 12.0,
      iconMd: 16.0,
      iconLg: 20.0,
      iconXl: 32.0,
      thumbnailSm: ThumbnailSize(width: 120.0, height: 90.0),
      thumbnailLg: ThumbnailSize(width: 208.0, height: 156.0),
      focusRingOuter: 2.0,
      focusRingInner: 1.0,
    ),
    radius: RadiusTokens(
      sm: 2.0,
      md: 4.0,
      lg: 8.0,
      xl: 12.0,
      full: 999.0,
    ),
    shadow: ShadowTokens(
      sm: ShadowToken(
        offsetX: 0,
        offsetY: 1,
        blurRadius: 2,
        color: Color(0x14000000),
      ),
      md: ShadowToken(
        offsetX: 0,
        offsetY: 2,
        blurRadius: 8,
        color: Color(0x29000000),
      ),
      lg: ShadowToken(
        offsetX: 0,
        offsetY: 4,
        blurRadius: 16,
        color: Color(0x3D000000),
      ),
      xl: ShadowToken(
        offsetX: 0,
        offsetY: 8,
        blurRadius: 32,
        color: Color(0x52000000),
      ),
    ),
  );

  @override
  ThemeExtension<WireTunerTokens> copyWith({
    SurfaceColors? surface,
    CanvasColors? canvas,
    GridColors? grid,
    AccentColors? accent,
    SemanticColors? semantic,
    AnchorColors? anchor,
    PresenceColors? presence,
    OverlayColors? overlays,
    FocusRingStyle? focus,
    FpsColors? fps,
    TextColors? text,
    TypographyTokens? typography,
    SpacingTokens? spacing,
    SizingTokens? sizing,
    RadiusTokens? radius,
    ShadowTokens? shadow,
  }) {
    return WireTunerTokens(
      surface: surface ?? this.surface,
      canvas: canvas ?? this.canvas,
      grid: grid ?? this.grid,
      accent: accent ?? this.accent,
      semantic: semantic ?? this.semantic,
      anchor: anchor ?? this.anchor,
      presence: presence ?? this.presence,
      overlays: overlays ?? this.overlays,
      focus: focus ?? this.focus,
      fps: fps ?? this.fps,
      text: text ?? this.text,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      sizing: sizing ?? this.sizing,
      radius: radius ?? this.radius,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ThemeExtension<WireTunerTokens> lerp(
    covariant ThemeExtension<WireTunerTokens>? other,
    double t,
  ) {
    if (other is! WireTunerTokens) {
      return this;
    }
    // For simplicity, return the other theme when t > 0.5
    // In production, you could interpolate individual color/spacing values
    return t < 0.5 ? this : other;
  }
}

// ============================================================
// Convenience Extension
// ============================================================

/// Convenience extension to access tokens from BuildContext
extension WireTunerTokensContext on BuildContext {
  /// Access design tokens from context
  ///
  /// Usage:
  /// ```dart
  /// final bgColor = context.tokens.surface.base;
  /// ```
  WireTunerTokens get tokens {
    final tokens = Theme.of(this).extension<WireTunerTokens>();
    assert(
      tokens != null,
      'WireTunerTokens not found in theme. '
      'Make sure to add it to your ThemeData via .extensions',
    );
    return tokens!;
  }
}
