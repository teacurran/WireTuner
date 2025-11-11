# WireTuner Design Token Registry

This document serves as the single source of truth for all design tokens used throughout the WireTuner application. Tokens are organized into semantic categories and can be automatically exported to Flutter theme extensions via the design-token-exporter CLI tool.

## Usage

To regenerate the Dart theme extensions from these tokens:

```bash
dart tools/design-token-exporter/cli.dart
```

This will parse the YAML token definitions below and generate:
- `packages/app/lib/theme/tokens.dart` - Strongly-typed Dart token models
- `packages/app/lib/theme/theme_data.dart` - Flutter ThemeData builder

---

## Token Definitions

```yaml
# Design Token Registry
# Format: category.subcategory.token
# Each token specifies: value, usage, and optional metadata (contrast, notes, etc.)

tokens:
  # ============================================================
  # Surface Colors
  # ============================================================
  surface:
    base:
      value: "#0D1015"
      description: "Primary window chrome, Navigator background, inactive tool docks"
      usage: ["window.chrome", "dock.background", "navigator"]
      contrast: "13.8:1 vs text/primary"
    raised:
      value: "#141920"
      description: "Elevated panels such as Inspector and Layer stacks"
      usage: ["inspector.panel", "timeline.toolbar"]
      contrast: "11.1:1 vs text/primary"
    overlay:
      value: "rgba(28,34,44,0.88)"
      description: "Modal scrims, quick actions, toast backgrounds"
      usage: ["modals", "context.menu"]
      notes: "applies blur(8px) on macOS only"

  # ============================================================
  # Canvas & Artboard Colors
  # ============================================================
  canvas:
    infinite:
      value: "#1A1D22"
      description: "Root viewport background"
      usage: ["root.viewport"]
      notes: "gradient tinted to guide focus without moiré artifacts at high zoom"
    artboard_default:
      value: "#F7F8FA"
      description: "Default artboard fill color"
      usage: ["artboard.fill"]
      border: "#E1E3E8"
      notes: "provides crisp separation against dark chrome"

  # ============================================================
  # Viewport Grid Colors
  # ============================================================
  grid:
    minor:
      value: "rgba(58,63,73,0.6)"
      description: "Minor grid lines"
      usage: ["viewport.grid.minor"]
    major:
      value: "rgba(79,85,98,0.9)"
      description: "Major grid intersections"
      usage: ["viewport.grid.major"]

  # ============================================================
  # Primary Interaction Colors (Accent)
  # ============================================================
  accent:
    primary:
      value: "#4FB2FF"
      description: "Primary accent color for buttons, tool activation, active tabs"
      usage: ["buttons", "tool.activation", "tab.active", "event.scrubber"]
      hover: "#6DC2FF"
      pressed: "#3D94D6"
      focus_ring: "#87D2FF"
    secondary:
      value: "#6F7CFF"
      description: "Secondary actions, sampling toggle, idle collaboration presence"
      usage: ["secondary.actions", "sampling.toggle", "presence.idle"]
      hover: "#93A1FF"
    tertiary:
      value: "#5CFFCE"
      description: "Positive reinforcement, successful exports, saved state"
      usage: ["success.badge", "export.success", "snapshot.toast"]

  # ============================================================
  # Semantic Alert Colors
  # ============================================================
  semantic:
    warning:
      value: "#FFB347"
      description: "Destructive previews, disk space warnings"
      usage: ["destructive.preview", "disk.warning"]
      on_color: "#0D1015"
    error:
      value: "#FF5C73"
      description: "Failed exports, corrupted files, OT conflicts"
      usage: ["export.failure", "file.corrupted", "ot.conflict"]
      on_color: "#0D1015"
    info:
      value: "#53D3FF"
      description: "Guidance toasts, intelligent zoom suggestions, help overlays"
      usage: ["guidance.toast", "zoom.suggestion", "help.overlay"]
      on_color: "#0D1015"

  # ============================================================
  # Anchor Visualization Colors
  # ============================================================
  anchor:
    smooth:
      fill: "#FF5C5C"
      stroke: "#080A0E"
      radius_px: 5
      description: "Smooth anchor point visualization"
    corner:
      fill: "#080A0E"
      stroke: "#F7F8FA"
      size_px: 7
      description: "Corner anchor point visualization"
    tangent:
      fill: "#FFA345"
      stroke: "#080A0E"
      size_px: 7
      description: "Tangent anchor point visualization"

  # ============================================================
  # Collaboration Presence Colors
  # ============================================================
  presence:
    palette:
      description: "Cycled palette to handle 10+ participants"
      colors:
        - "#FF9BAE"
        - "#FFD66F"
        - "#5DFFB1"
        - "#7FE2FF"
        - "#B18CFF"
        - "#FF7F5E"
        - "#6FE5FF"
        - "#9FED72"
        - "#FFCFEC"
        - "#8DF0FF"

  # ============================================================
  # Overlay Colors
  # ============================================================
  overlays:
    selection:
      fill: "rgba(79,178,255,0.08)"
      stroke: "rgba(79,178,255,0.6)"
      description: "Selection overlay for selected objects"
    marquee:
      dash: "6 4"
      stroke: "rgba(111,124,255,0.9)"
      description: "Marquee selection box"
    performance_heatmap:
      description: "Performance heatmap gradient for sampling density"
      gradient:
        - "#1D91F0"
        - "#70F1C6"
        - "#F8EB6B"
    event_category:
      path: "#FF6F91"
      selection: "#FFC75F"
      viewport: "#9CFFFA"
      document: "#C087F9"
      description: "Event category overlay colors aligned with event logs"

  # ============================================================
  # Focus Ring
  # ============================================================
  focus:
    default:
      outer: "#4FB2FF"
      inner: "#0D1015"
      width_px: 2
      description: "Default focus ring styling"

  # ============================================================
  # Metrics Overlay Colors
  # ============================================================
  metrics_overlay:
    fps:
      idle: "#5CFFCE"
      warning: "#FFB347"
      error: "#FF5C73"
      description: "FPS indicator colors based on performance"

  # ============================================================
  # Typography Scale
  # ============================================================
  typography:
    xxs:
      font_family: "IBM Plex Sans"
      font_size: 10
      line_height: 14
      font_weight: 400
      usage: ["metadata.badges", "tooltip.footers"]
    xs:
      font_family: "IBM Plex Sans"
      font_size: 12
      line_height: 16
      font_weight: 400
      usage: ["secondary.labels", "navigator.counts"]
    sm:
      font_family: "IBM Plex Sans"
      font_size: 13
      line_height: 18
      font_weight: 400
      usage: ["layer.list", "artboard.names"]
    md:
      font_family: "IBM Plex Sans"
      font_size: 14
      line_height: 20
      font_weight: 400
      usage: ["inspector.labels", "status.bar"]
    lg:
      font_family: "IBM Plex Sans"
      font_size: 16
      line_height: 22
      font_weight: 400
      usage: ["window.titles", "major.callouts"]
    xl:
      font_family: "IBM Plex Sans"
      font_size: 20
      line_height: 26
      font_weight: 600
      usage: ["section.headers"]
    xxl:
      font_family: "IBM Plex Sans"
      font_size: 24
      line_height: 30
      font_weight: 600
      usage: ["onboarding.panels", "marketing.modals"]
    mono_sm:
      font_family: "IBM Plex Mono"
      font_size: 12
      line_height: 16
      font_weight: 400
      usage: ["coordinate.readouts", "event.log.sequences"]
    mono_md:
      font_family: "IBM Plex Mono"
      font_size: 14
      line_height: 20
      font_weight: 400
      usage: ["sampling.inspector", "json.viewer"]

  # ============================================================
  # Spacing Scale (4px baseline grid)
  # ============================================================
  spacing:
    2:
      value: 2
      description: "Micro gaps for icon stacking"
    4:
      value: 4
      description: "Default gap between icon and label inside toolbar buttons"
    6:
      value: 6
      description: "Dense table rows (event log)"
    8:
      value: 8
      description: "Inspector field groups, toast padding, inline error callouts"
    12:
      value: 12
      description: "Card-level padding (Navigator thumbnails, sampling cards)"
    16:
      value: 16
      description: "Baseline margin for windows and modals"
    20:
      value: 20
      description: "Artboard boundary gutters at 100% zoom"
    24:
      value: 24
      description: "Cross-panel spacing between docked columns"
    32:
      value: 32
      description: "Onboarding hero sections or empty state illustrations"
    48:
      value: 48
      description: "Large-scale marketing overlays (rarely used in production)"

  # ============================================================
  # Component Sizing Tokens
  # ============================================================
  sizing:
    button:
      compact:
        height: 28
        padding_horizontal: 8
        description: "Compact button size for dense toolbars"
      default:
        height: 32
        padding_horizontal: 12
        description: "Default button size for standard actions"
    input:
      slot:
        height: 36
        padding: 12
        icon_width: 20
        description: "Standard input field dimensions"
    icon:
      sm: 12
      md: 16
      lg: 20
      xl: 32
      description: "Icon sizes for various contexts (tool previews, history timeline, thumbnails)"
    thumbnail:
      sm:
        width: 120
        height: 90
        description: "Small thumbnail size (renders at 2x on retina)"
      lg:
        width: 208
        height: 156
        description: "Large thumbnail size (renders at 2x on retina)"
    focus_ring:
      outer_width: 2
      inner_width: 1
      description: "Focus ring dimensions for dark surfaces"

  # ============================================================
  # Border Radius
  # ============================================================
  radius:
    sm: 2
    md: 4
    lg: 8
    xl: 12
    full: 999
    description: "Border radius scale for UI components"

  # ============================================================
  # Shadows & Elevation
  # ============================================================
  shadow:
    sm:
      offset_x: 0
      offset_y: 1
      blur_radius: 2
      color: "rgba(0,0,0,0.08)"
      description: "Subtle elevation for input fields"
    md:
      offset_x: 0
      offset_y: 2
      blur_radius: 8
      color: "rgba(0,0,0,0.16)"
      description: "Standard card elevation"
    lg:
      offset_x: 0
      offset_y: 4
      blur_radius: 16
      color: "rgba(0,0,0,0.24)"
      description: "Modal and floating panel elevation"
    xl:
      offset_x: 0
      offset_y: 8
      blur_radius: 32
      color: "rgba(0,0,0,0.32)"
      description: "Maximum elevation for overlays"

# ============================================================
# Text Tokens (derived from typography + color)
# ============================================================
text:
  primary:
    value: "#F7F8FA"
    description: "Primary text color on dark surfaces"
  secondary:
    value: "rgba(247,248,250,0.72)"
    description: "Secondary text color for less prominent content"
  tertiary:
    value: "rgba(247,248,250,0.48)"
    description: "Tertiary text color for disabled or hint text"
  on_accent:
    value: "#0D1015"
    description: "Text color on accent backgrounds"
```

---

## Color Reference Tables

### Surface Colors

| Token | Hex Value | Usage | Contrast Ratio |
|-------|-----------|-------|----------------|
| `surface.base` | `#0D1015` | Window chrome, dock background, Navigator | 13.8:1 vs text/primary |
| `surface.raised` | `#141920` | Inspector panel, timeline toolbar | 11.1:1 vs text/primary |
| `surface.overlay` | `rgba(28,34,44,0.88)` | Modals, context menus | Applies blur(8px) on macOS |

### Canvas & Artboard

| Token | Hex Value | Usage |
|-------|-----------|-------|
| `canvas.infinite` | `#1A1D22` | Root viewport background |
| `canvas.artboard_default` | `#F7F8FA` | Default artboard fill (border: `#E1E3E8`) |

### Accent Colors

| Token | Hex Value | Hover | Pressed | Focus Ring |
|-------|-----------|-------|---------|------------|
| `accent.primary` | `#4FB2FF` | `#6DC2FF` | `#3D94D6` | `#87D2FF` |
| `accent.secondary` | `#6F7CFF` | `#93A1FF` | - | - |
| `accent.tertiary` | `#5CFFCE` | - | - | - |

### Semantic Colors

| Token | Hex Value | Usage | Text Color |
|-------|-----------|-------|------------|
| `semantic.warning` | `#FFB347` | Destructive previews, disk warnings | `#0D1015` |
| `semantic.error` | `#FF5C73` | Failed exports, corrupted files | `#0D1015` |
| `semantic.info` | `#53D3FF` | Guidance toasts, help overlays | `#0D1015` |

### Anchor Visualization

| Token | Fill | Stroke | Size/Radius |
|-------|------|--------|-------------|
| `anchor.smooth` | `#FF5C5C` | `#080A0E` | 5px radius |
| `anchor.corner` | `#080A0E` | `#F7F8FA` | 7px size |
| `anchor.tangent` | `#FFA345` | `#080A0E` | 7px size |

### Collaboration Presence Palette

| Index | Color |
|-------|-------|
| 1 | `#FF9BAE` |
| 2 | `#FFD66F` |
| 3 | `#5DFFB1` |
| 4 | `#7FE2FF` |
| 5 | `#B18CFF` |
| 6 | `#FF7F5E` |
| 7 | `#6FE5FF` |
| 8 | `#9FED72` |
| 9 | `#FFCFEC` |
| 10 | `#8DF0FF` |

---

## Typography Reference

| Token | Font | Size | Line Height | Weight | Usage |
|-------|------|------|-------------|--------|-------|
| `typography.xxs` | IBM Plex Sans | 10px | 14px | 400 | Metadata badges, tooltip footers |
| `typography.xs` | IBM Plex Sans | 12px | 16px | 400 | Secondary labels, Navigator counts |
| `typography.sm` | IBM Plex Sans | 13px | 18px | 400 | Layer list, artboard names |
| `typography.md` | IBM Plex Sans | 14px | 20px | 400 | Inspector labels, status bar |
| `typography.lg` | IBM Plex Sans | 16px | 22px | 400 | Window titles, major callouts |
| `typography.xl` | IBM Plex Sans | 20px | 26px | 600 | Section headers |
| `typography.xxl` | IBM Plex Sans | 24px | 30px | 600 | Onboarding panels, marketing modals |
| `typography.mono_sm` | IBM Plex Mono | 12px | 16px | 400 | Coordinate readouts, event log sequences |
| `typography.mono_md` | IBM Plex Mono | 14px | 20px | 400 | Sampling inspector, JSON viewer |

**Typography Guidelines:**

1. Keep line lengths under 64 characters within inspector panels to maintain scannability.
2. Monospaced coordinates always display trailing zeros to enforce precision (e.g., `123.400 px`).
3. When localization expands strings, dynamic truncation adds ellipsis plus tooltip for full text.
4. Artboard Navigator names wrap to two lines for long device names; third line clamps with gradient mask.
5. System-level dialogues on macOS/Windows adopt native fonts but share size tokens to maintain rhythm.

---

## Spacing & Sizing Reference

### Spacing Scale (4px baseline grid)

| Token | Value | Usage |
|-------|-------|-------|
| `spacing.2` | 2px | Micro gaps for icon stacking |
| `spacing.4` | 4px | Icon-to-label gap in toolbar buttons |
| `spacing.6` | 6px | Dense table rows (event log) |
| `spacing.8` | 8px | Inspector field groups, toast padding |
| `spacing.12` | 12px | Card padding (thumbnails, sampling cards) |
| `spacing.16` | 16px | Window and modal margins |
| `spacing.20` | 20px | Artboard boundary gutters at 100% zoom |
| `spacing.24` | 24px | Cross-panel spacing between docked columns |
| `spacing.32` | 32px | Onboarding hero sections, empty states |
| `spacing.48` | 48px | Large marketing overlays (rare in production) |

### Component Sizing

| Token | Dimensions | Usage |
|-------|------------|-------|
| `sizing.button.compact` | 28px h × 8px padding | Dense toolbars |
| `sizing.button.default` | 32px h × 12px padding | Standard actions |
| `sizing.input.slot` | 36px h × 12px padding, 20px icon | Input fields |
| `sizing.icon.sm` | 12px | Small icons |
| `sizing.icon.md` | 16px | Medium icons |
| `sizing.icon.lg` | 20px | Large icons |
| `sizing.icon.xl` | 32px | Extra-large icons, thumbnails |
| `sizing.thumbnail.sm` | 120×90px | Small thumbnails (2x retina) |
| `sizing.thumbnail.lg` | 208×156px | Large thumbnails (2x retina) |
| `sizing.focus_ring` | 2px outer, 1px inner | Focus indicators |

### Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radius.sm` | 2px | Subtle rounding |
| `radius.md` | 4px | Standard buttons, inputs |
| `radius.lg` | 8px | Cards, panels |
| `radius.xl` | 12px | Large containers |
| `radius.full` | 999px | Circular elements |

---

## Contrast Policy

All interactive text or iconography must meet ≥4.5:1 contrast on `surface.base`. Use automatic fallback to `accent.tertiary` when color-coded semantic fails due to user-set high-contrast theme.

---

## Maintenance Notes

- This file is the single source of truth for all design tokens.
- When updating tokens, always run the exporter CLI to regenerate Dart code.
- Token changes should be reviewed for accessibility compliance (WCAG AA minimum).
- New tokens should follow the existing naming convention: `category.subcategory.property`.
- Document all usage contexts to help developers select the correct token.

---

**Last Updated:** Generated for Task I1.T4
**Version:** 1.0.0
**Maintained By:** Design System Team
