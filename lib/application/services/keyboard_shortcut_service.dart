import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// Keyboard shortcut intents for document operations.
///
/// These intents are used with Flutter's Shortcuts and Actions framework
/// to provide cross-platform keyboard shortcuts for common operations.

/// Intent for undo operation (Cmd+Z on macOS, Ctrl+Z on Windows).
class UndoIntent extends Intent {
  /// Creates an undo intent.
  const UndoIntent();
}

/// Intent for redo operation (Cmd+Shift+Z on macOS, Ctrl+Shift+Z on Windows).
class RedoIntent extends Intent {
  /// Creates a redo intent.
  const RedoIntent();
}

/// Provides keyboard shortcut mappings for document operations.
///
/// This service encapsulates platform-specific keyboard shortcut definitions
/// for use with Flutter's Shortcuts widget. It automatically selects the
/// appropriate modifier keys (Command on macOS, Control on Windows/Linux).
///
/// **Usage Example:**
/// ```dart
/// Shortcuts(
///   shortcuts: KeyboardShortcutService.getShortcuts(),
///   child: Actions(
///     actions: KeyboardShortcutService.getActions(context),
///     child: child,
///   ),
/// )
/// ```
class KeyboardShortcutService {
  /// Returns the platform-specific keyboard shortcuts map.
  ///
  /// This map defines the keyboard combinations that trigger specific intents:
  /// - Undo: Cmd+Z (macOS) or Ctrl+Z (Windows/Linux)
  /// - Redo: Cmd+Shift+Z (macOS) or Ctrl+Shift+Z (Windows/Linux)
  static Map<ShortcutActivator, Intent> getShortcuts() {
    final isMacOS = Platform.isMacOS;
    final modifier =
        isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return {
      // Undo: Cmd/Ctrl+Z
      LogicalKeySet(modifier, LogicalKeyboardKey.keyZ): const UndoIntent(),

      // Redo: Cmd/Ctrl+Shift+Z
      LogicalKeySet(
        modifier,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyZ,
      ): const RedoIntent(),
    };
  }

  /// Returns a map of actions for handling keyboard shortcuts.
  ///
  /// This method creates action handlers that invoke the appropriate methods
  /// on UndoProvider when keyboard shortcuts are triggered.
  ///
  /// **Parameters:**
  /// - [onUndo]: Callback to invoke when undo is triggered
  /// - [onRedo]: Callback to invoke when redo is triggered
  ///
  /// **Returns:** Map of Intent types to Action handlers
  static Map<Type, Action<Intent>> getActions({
    required VoidCallback onUndo,
    required VoidCallback onRedo,
  }) =>
      {
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (_) {
            onUndo();
            return null;
          },
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (_) {
            onRedo();
            return null;
          },
        ),
      };
}
