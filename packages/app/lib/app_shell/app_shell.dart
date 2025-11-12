/// App Shell - Window Lifecycle Management
///
/// This library provides window lifecycle management for WireTuner's
/// multi-window application architecture.
///
/// ## Core Components
///
/// - [WindowManager]: Central coordinator for all window instances
/// - [WindowDescriptor]: Immutable window metadata
/// - [NavigatorRoot]: Navigator window with lifecycle integration
/// - [ArtboardWindow]: Artboard editing window with state persistence
/// - [WindowStateRepository]: Persistence layer for viewport state
///
/// ## Usage
///
/// ```dart
/// // Setup in main app
/// final windowManager = WindowManager(
///   onPersistViewportState: (docId, artId, viewport) async {
///     await repo.saveViewportState(
///       documentId: docId,
///       artboardId: artId,
///       viewport: viewport,
///     );
///   },
///   onConfirmClose: (docId) async {
///     return await showNavigatorCloseConfirmation(...);
///   },
/// );
///
/// // Provide to widget tree
/// Provider.value(
///   value: windowManager,
///   child: MaterialApp(...),
/// );
///
/// // Open Navigator window
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => NavigatorRoot(
///       documentId: 'doc1',
///       documentName: 'example.wiretuner',
///     ),
///   ),
/// );
///
/// // Open artboard window
/// final viewport = await repo.loadViewportState(
///   documentId: 'doc1',
///   artboardId: 'art1',
/// );
///
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => ArtboardWindow(
///       documentId: 'doc1',
///       artboardId: 'art1',
///       documentName: 'example.wiretuner',
///       artboardName: 'Homepage',
///       initialViewportState: viewport,
///     ),
///   ),
/// );
/// ```
///
/// See [README.md] for full documentation.
library app_shell;

export 'window_descriptor.dart';
export 'window_manager.dart';
export 'navigator_root.dart';
export 'artboard_window.dart';
export 'window_state_repository.dart';
