import 'dart:io';

/// Abstract interface for file picker operations.
///
/// This abstraction allows for platform-specific implementations and enables
/// testability by allowing mock implementations in tests.
///
/// Concrete implementations should handle platform-specific file dialog behavior
/// for save and open operations.
abstract class FilePickerAdapter {
  /// Shows a save file dialog and returns the selected path.
  ///
  /// Parameters:
  /// - [defaultName]: Suggested filename (e.g., "Untitled.wiretuner")
  /// - [suggestedDirectory]: Optional starting directory for the dialog
  ///
  /// Returns the selected file path, or null if the user cancelled.
  ///
  /// Example:
  /// ```dart
  /// final path = await picker.showSaveDialog(
  ///   defaultName: 'my-drawing.wiretuner',
  ///   suggestedDirectory: '/Users/alice/Documents',
  /// );
  /// ```
  Future<String?> showSaveDialog({
    required String defaultName,
    String? suggestedDirectory,
  });

  /// Shows an open file dialog and returns the selected path.
  ///
  /// Returns the selected file path, or null if the user cancelled.
  ///
  /// Example:
  /// ```dart
  /// final path = await picker.showOpenDialog();
  /// ```
  Future<String?> showOpenDialog();
}

/// Mock implementation of FilePickerAdapter for testing.
///
/// Returns predefined file paths without showing an actual file dialog.
/// This enables deterministic testing of save/load flows.
///
/// Example:
/// ```dart
/// final mockPicker = MockFilePickerAdapter();
/// mockPicker.nextSavePath = '/tmp/test.wiretuner';
///
/// final path = await mockPicker.showSaveDialog(
///   defaultName: 'test.wiretuner',
/// ); // Returns '/tmp/test.wiretuner'
/// ```
class MockFilePickerAdapter implements FilePickerAdapter {
  /// The path to return from the next showSaveDialog call.
  String? nextSavePath;

  /// The path to return from the next showOpenDialog call.
  String? nextOpenPath;

  /// If true, the next dialog call will return null (simulating user cancellation).
  bool simulateCancellation = false;

  @override
  Future<String?> showSaveDialog({
    required String defaultName,
    String? suggestedDirectory,
  }) async {
    if (simulateCancellation) {
      return null;
    }
    return nextSavePath;
  }

  @override
  Future<String?> showOpenDialog() async {
    if (simulateCancellation) {
      return null;
    }
    return nextOpenPath;
  }

  /// Resets the mock to its initial state.
  void reset() {
    nextSavePath = null;
    nextOpenPath = null;
    simulateCancellation = false;
  }
}

/// Platform-specific file picker implementation.
///
/// This is a stub implementation that will be replaced with actual
/// platform-specific file dialogs in future iterations.
///
/// For now, it uses a simple stdin/stdout approach for demonstration.
/// In production, this would integrate with native file dialogs via
/// platform channels or packages like file_selector.
class PlatformFilePickerAdapter implements FilePickerAdapter {
  @override
  Future<String?> showSaveDialog({
    required String defaultName,
    String? suggestedDirectory,
  }) async {
    // TODO(I5.T1): Implement native file dialog integration
    // For now, return a test path for demonstration
    // In production, use file_selector package or platform channels
    print(
        'Save dialog: defaultName=$defaultName, directory=$suggestedDirectory');
    return null; // Stub - returns null to simulate cancellation
  }

  @override
  Future<String?> showOpenDialog() async {
    // TODO(I5.T1): Implement native file dialog integration
    print('Open dialog requested');
    return null; // Stub - returns null to simulate cancellation
  }
}
