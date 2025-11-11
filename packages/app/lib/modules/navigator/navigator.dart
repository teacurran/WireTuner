/// Navigator Module
///
/// Multi-artboard document management UI for WireTuner.
///
/// ## Overview
///
/// The Navigator provides a bird's-eye view of all artboards in open documents,
/// allowing users to:
/// - Switch between multiple open documents via tabs
/// - Browse artboards in a virtualized grid (supports up to 1000 artboards)
/// - Select, rename, duplicate, and delete artboards
/// - View live thumbnail previews with auto-refresh
/// - Access context menus for artboard operations
///
/// ## Architecture
///
/// The module follows Clean Architecture principles with clear layer separation:
///
/// ```
/// ┌─────────────────────────────────────────────────────────┐
/// │  UI Layer (Widgets)                                     │
/// │  - NavigatorWindow (main shell)                         │
/// │  - NavigatorTabs (document tabs)                        │
/// │  - ArtboardGrid (virtualized grid)                      │
/// │  - ArtboardCard (individual cards)                      │
/// │  - ArtboardContextMenu (actions)                        │
/// └──────────────────┬──────────────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────────────┐
/// │  Presentation Layer (State Management)                  │
/// │  - NavigatorProvider (state + UI logic)                 │
/// │  - NavigatorService (orchestration)                     │
/// └──────────────────┬──────────────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────────────┐
/// │  Infrastructure Layer (External Services)               │
/// │  - EventStore (event sourcing)                          │
/// │  - RenderingPipeline (thumbnail generation)             │
/// │  - SettingsService (viewport persistence)               │
/// │  - TelemetryService (performance tracking)              │
/// └─────────────────────────────────────────────────────────┘
/// ```
///
/// ## Usage
///
/// ### Basic Setup
///
/// ```dart
/// import 'package:app/modules/navigator/navigator.dart';
///
/// // Open Navigator window
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => NavigatorWindow(
///       onClose: () => Navigator.of(context).pop(),
///     ),
///   ),
/// );
/// ```
///
/// ### Opening a Document
///
/// ```dart
/// final provider = context.read<NavigatorProvider>();
///
/// final tab = DocumentTab(
///   documentId: 'doc-uuid',
///   name: 'My Design.wire',
///   path: '/Users/designer/Documents/My Design.wire',
///   artboardIds: ['art1', 'art2', 'art3'],
/// );
///
/// provider.openDocument(tab);
/// ```
///
/// ### Listening to Actions
///
/// ```dart
/// final service = NavigatorService();
///
/// service.actionStream.listen((event) {
///   switch (event.action) {
///     case ArtboardAction.rename:
///       // Handle rename in EventStore
///       break;
///     case ArtboardAction.duplicate:
///       // Handle duplicate in EventStore
///       break;
///     // ... other actions
///   }
/// });
/// ```
///
/// ## Performance
///
/// The Navigator is optimized for large documents:
///
/// - **Virtualization**: GridView.builder renders only visible artboards
/// - **Lazy Loading**: Thumbnails load on-demand as cards become visible
/// - **Auto-Refresh**: 10-second interval with save-trigger override
/// - **LRU Cache**: Thumbnail cache with automatic eviction
///
/// Acceptance criteria:
/// - Handles 1000 artboards with smooth scrolling (60 FPS)
/// - Thumbnail refresh respects 10s interval or save trigger
/// - Context menu actions dispatch events to EventStore
///
/// ## Related Documentation
///
/// - Architecture: `.codemachine/artifacts/architecture/06_UI_UX_Architecture.md`
/// - Flow C: Multi-Artboard Document Load and Navigator Activation
/// - Journey H: Manage Artboards in Navigator
/// - FR-029–FR-044: Functional Requirements
///
/// ## Package Exports

library navigator;

// State Management
export 'state/navigator_provider.dart';
export 'state/navigator_service.dart';

// UI Components
export 'navigator_window.dart';
export 'widgets/navigator_tabs.dart';
export 'widgets/artboard_grid.dart';
export 'widgets/artboard_card.dart';
export 'widgets/context_menu.dart';
