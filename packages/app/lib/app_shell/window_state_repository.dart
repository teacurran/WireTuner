import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'window_descriptor.dart';

/// Repository for persisting and restoring window state.
///
/// WindowStateRepository handles:
/// - Saving viewport state per artboard (Journey 15)
/// - Restoring viewport state on window reopen
/// - Saving window focus order for multi-window restoration
/// - Clearing stale state for closed documents
///
/// ## Storage Strategy
///
/// Uses SharedPreferences for simple key-value storage:
/// - Key format: `window_viewport_{documentId}_{artboardId}`
/// - Value format: JSON with {panX, panY, zoom}
/// - Per-artboard isolation ensures independent viewport states
///
/// ## Usage
///
/// ```dart
/// final repo = WindowStateRepository();
///
/// // Save viewport state on blur/close
/// await repo.saveViewportState(
///   documentId: 'doc123',
///   artboardId: 'art456',
///   viewport: ViewportSnapshot(
///     panOffset: Offset(100, 50),
///     zoom: 1.5,
///   ),
/// );
///
/// // Restore viewport state on open
/// final viewport = await repo.loadViewportState(
///   documentId: 'doc123',
///   artboardId: 'art456',
/// );
/// ```
///
/// Related: Journey 15 (Per-Artboard Viewport Persistence)
class WindowStateRepository {
  /// Creates a window state repository.
  WindowStateRepository({SharedPreferences? prefs}) : _prefs = prefs;

  /// Shared preferences instance (lazy-loaded).
  SharedPreferences? _prefs;

  /// Ensures SharedPreferences is initialized.
  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Saves viewport state for an artboard.
  ///
  /// Per Journey 15: each artboard remembers its last viewport independently.
  /// State is saved on blur/close and restored on reopen.
  Future<void> saveViewportState({
    required String documentId,
    required String? artboardId,
    required ViewportSnapshot viewport,
  }) async {
    if (artboardId == null) {
      // Navigator windows don't persist viewport state
      return;
    }

    final prefs = await _ensurePrefs();
    final key = _makeViewportKey(documentId, artboardId);
    final json = jsonEncode(viewport.toJson());

    await prefs.setString(key, json);

    debugPrint('[WindowStateRepository] Saved viewport for $documentId/$artboardId: $viewport');
  }

  /// Loads viewport state for an artboard.
  ///
  /// Returns null if no saved state exists (first time opening).
  Future<ViewportSnapshot?> loadViewportState({
    required String documentId,
    required String artboardId,
  }) async {
    final prefs = await _ensurePrefs();
    final key = _makeViewportKey(documentId, artboardId);
    final json = prefs.getString(key);

    if (json == null) {
      return null; // No saved state, use defaults
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final viewport = ViewportSnapshot.fromJson(data);

      debugPrint('[WindowStateRepository] Loaded viewport for $documentId/$artboardId: $viewport');
      return viewport;
    } catch (e) {
      debugPrint('[WindowStateRepository] Failed to parse viewport state: $e');
      return null; // Corrupt data, use defaults
    }
  }

  /// Clears all viewport state for a document.
  ///
  /// Should be called when a document is permanently closed or deleted.
  Future<void> clearDocumentState(String documentId) async {
    final prefs = await _ensurePrefs();
    final prefix = 'window_viewport_${documentId}_';

    // Remove all keys starting with this document ID
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint('[WindowStateRepository] Cleared state for document $documentId ($keys.length keys)');
  }

  /// Clears all window state (for testing or reset).
  Future<void> clearAll() async {
    final prefs = await _ensurePrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith('window_')).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint('[WindowStateRepository] Cleared all window state');
  }

  /// Generates a storage key for viewport state.
  String _makeViewportKey(String documentId, String artboardId) {
    return 'window_viewport_${documentId}_$artboardId';
  }

  /// Saves window focus order for restoration after app restart.
  ///
  /// Future enhancement: restore windows in the order they were last focused.
  Future<void> saveFocusOrder(List<String> windowIds) async {
    final prefs = await _ensurePrefs();
    final json = jsonEncode(windowIds);
    await prefs.setString('window_focus_order', json);
  }

  /// Loads window focus order.
  ///
  /// Returns empty list if no saved order exists.
  Future<List<String>> loadFocusOrder() async {
    final prefs = await _ensurePrefs();
    final json = prefs.getString('window_focus_order');

    if (json == null) {
      return [];
    }

    try {
      final data = jsonDecode(json) as List<dynamic>;
      return data.cast<String>();
    } catch (e) {
      debugPrint('[WindowStateRepository] Failed to parse focus order: $e');
      return [];
    }
  }

  /// Saves window geometry (position, size) for a window.
  ///
  /// Future enhancement for multi-window desktop apps.
  /// macOS/Windows can restore window positions across launches.
  Future<void> saveWindowGeometry({
    required String windowId,
    required WindowGeometry geometry,
  }) async {
    final prefs = await _ensurePrefs();
    final key = 'window_geometry_$windowId';
    final json = jsonEncode(geometry.toJson());
    await prefs.setString(key, json);
  }

  /// Loads window geometry for a window.
  Future<WindowGeometry?> loadWindowGeometry(String windowId) async {
    final prefs = await _ensurePrefs();
    final key = 'window_geometry_$windowId';
    final json = prefs.getString(key);

    if (json == null) {
      return null;
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return WindowGeometry.fromJson(data);
    } catch (e) {
      debugPrint('[WindowStateRepository] Failed to parse window geometry: $e');
      return null;
    }
  }
}

/// Window geometry (position and size).
///
/// Future enhancement for multi-window desktop apps.
@immutable
class WindowGeometry {
  /// Creates window geometry.
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Window X position in screen coordinates.
  final double x;

  /// Window Y position in screen coordinates.
  final double y;

  /// Window width in pixels.
  final double width;

  /// Window height in pixels.
  final double height;

  /// Creates geometry from JSON.
  factory WindowGeometry.fromJson(Map<String, dynamic> json) {
    return WindowGeometry(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 800.0,
      height: (json['height'] as num?)?.toDouble() ?? 600.0,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() =>
      'WindowGeometry(x: $x, y: $y, width: $width, height: $height)';
}
