/// Flutter UI shell and window management for WireTuner.
///
/// This package provides the main application shell, window management,
/// and top-level UI structure for the WireTuner vector editor.
///
/// ## State Management
///
/// - [ToolProvider]: Tool system provider configuration
/// - [UndoProvider]: Undo/redo navigator Flutter adapter
library app_shell;

export 'src/app_shell_base.dart';
export 'src/state/tool_provider.dart';
export 'src/state/undo_provider.dart';
