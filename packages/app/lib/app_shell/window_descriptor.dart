import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Type of window in the application.
enum WindowType {
  /// Navigator window (root window for a document)
  navigator,

  /// Artboard editing window
  artboard,

  /// Inspector panel window
  inspector,

  /// History replay window
  history,
}

/// Describes a window instance in the window lifecycle system.
///
/// WindowDescriptor tracks all metadata needed to manage a window's lifecycle:
/// - Identity (windowId, type, associated document/artboard)
/// - State (viewport, dirty flag, focus time)
/// - Lifecycle (creation time, last interaction)
///
/// ## Usage
///
/// ```dart
/// final descriptor = WindowDescriptor(
///   windowId: 'nav-doc123',
///   type: WindowType.navigator,
///   documentId: 'doc123',
/// );
///
/// // For artboard windows
/// final artboardDesc = WindowDescriptor(
///   windowId: 'art-doc123-art456',
///   type: WindowType.artboard,
///   documentId: 'doc123',
///   artboardId: 'art456',
///   lastViewportState: ViewportSnapshot(
///     panOffset: Offset(100, 50),
///     zoom: 1.5,
///   ),
/// );
/// ```
///
/// Related: FR-040 (Window Lifecycle), Journey 18
@immutable
class WindowDescriptor {
  /// Creates a window descriptor.
  const WindowDescriptor({
    required this.windowId,
    required this.type,
    required this.documentId,
    this.artboardId,
    this.lastViewportState,
    this.isDirty = false,
    DateTime? createdAt,
    DateTime? lastFocusTime,
  })  : createdAt = createdAt ?? const _DefaultDateTime(),
        lastFocusTime = lastFocusTime ?? const _DefaultDateTime();

  /// Unique identifier for this window instance.
  ///
  /// Convention:
  /// - Navigator: `nav-{documentId}`
  /// - Artboard: `art-{documentId}-{artboardId}`
  /// - Inspector: `insp-{documentId}-{artboardId}`
  final String windowId;

  /// Type of window.
  final WindowType type;

  /// Document this window belongs to.
  final String documentId;

  /// Artboard this window is associated with (null for Navigator/History).
  final String? artboardId;

  /// Last known viewport state for this window.
  ///
  /// Saved on blur/close, restored on reopen.
  /// Per Journey 15: each artboard remembers its viewport independently.
  final ViewportSnapshot? lastViewportState;

  /// Whether this window has unsaved changes.
  ///
  /// Used to determine if close confirmation is needed.
  final bool isDirty;

  /// When this window was created.
  final DateTime createdAt;

  /// Last time this window received focus.
  ///
  /// Used to restore focus order after app relaunch.
  final DateTime lastFocusTime;

  /// Creates a copy with updated fields.
  WindowDescriptor copyWith({
    String? windowId,
    WindowType? type,
    String? documentId,
    String? artboardId,
    ViewportSnapshot? lastViewportState,
    bool? isDirty,
    DateTime? createdAt,
    DateTime? lastFocusTime,
  }) {
    return WindowDescriptor(
      windowId: windowId ?? this.windowId,
      type: type ?? this.type,
      documentId: documentId ?? this.documentId,
      artboardId: artboardId ?? this.artboardId,
      lastViewportState: lastViewportState ?? this.lastViewportState,
      isDirty: isDirty ?? this.isDirty,
      createdAt: createdAt ?? this.createdAt,
      lastFocusTime: lastFocusTime ?? this.lastFocusTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowDescriptor &&
          runtimeType == other.runtimeType &&
          windowId == other.windowId &&
          type == other.type &&
          documentId == other.documentId &&
          artboardId == other.artboardId &&
          isDirty == other.isDirty;

  @override
  int get hashCode =>
      windowId.hashCode ^
      type.hashCode ^
      documentId.hashCode ^
      (artboardId?.hashCode ?? 0) ^
      isDirty.hashCode;

  @override
  String toString() {
    final buffer = StringBuffer('WindowDescriptor(');
    buffer.write('id: $windowId, ');
    buffer.write('type: $type, ');
    buffer.write('doc: $documentId');

    if (artboardId != null) {
      buffer.write(', artboard: $artboardId');
    }

    if (lastViewportState != null) {
      buffer.write(', viewport: $lastViewportState');
    }

    if (isDirty) {
      buffer.write(', dirty');
    }

    buffer.write(')');
    return buffer.toString();
  }
}

/// Snapshot of viewport state for a specific window.
///
/// Used to save and restore viewport transformations when switching between
/// artboards or reopening windows.
///
/// This is a lightweight copy of the viewport controller state that can be
/// persisted and restored without requiring the full rendering pipeline.
@immutable
class ViewportSnapshot {
  /// Creates a viewport snapshot.
  const ViewportSnapshot({
    required this.panOffset,
    required this.zoom,
  });

  /// The pan offset in screen pixels.
  ///
  /// Represents the translation of the world coordinate system relative
  /// to the screen origin.
  final Offset panOffset;

  /// The zoom level (1.0 = 100%).
  ///
  /// Must be within the range [0.05, 8.0] to match ViewportController limits.
  final double zoom;

  /// Creates a snapshot from JSON.
  factory ViewportSnapshot.fromJson(Map<String, dynamic> json) {
    return ViewportSnapshot(
      panOffset: Offset(
        (json['panX'] as num?)?.toDouble() ?? 0.0,
        (json['panY'] as num?)?.toDouble() ?? 0.0,
      ),
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Converts to JSON for persistence.
  Map<String, dynamic> toJson() {
    return {
      'panX': panOffset.dx,
      'panY': panOffset.dy,
      'zoom': zoom,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportSnapshot &&
          runtimeType == other.runtimeType &&
          panOffset == other.panOffset &&
          zoom == other.zoom;

  @override
  int get hashCode => panOffset.hashCode ^ zoom.hashCode;

  @override
  String toString() =>
      'ViewportSnapshot(pan: $panOffset, zoom: ${zoom.toStringAsFixed(2)})';
}

/// Placeholder for DateTime.now() that works in const constructors.
///
/// Will be replaced with actual DateTime.now() when the descriptor is created.
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  DateTime add(Duration duration) => DateTime.now().add(duration);

  @override
  int compareTo(DateTime other) => DateTime.now().compareTo(other);

  @override
  DateTime subtract(Duration duration) => DateTime.now().subtract(duration);

  @override
  Duration difference(DateTime other) => DateTime.now().difference(other);

  @override
  int get day => DateTime.now().day;

  @override
  int get hour => DateTime.now().hour;

  @override
  bool get isUtc => DateTime.now().isUtc;

  @override
  int get microsecond => DateTime.now().microsecond;

  @override
  int get microsecondsSinceEpoch => DateTime.now().microsecondsSinceEpoch;

  @override
  int get millisecond => DateTime.now().millisecond;

  @override
  int get millisecondsSinceEpoch => DateTime.now().millisecondsSinceEpoch;

  @override
  int get minute => DateTime.now().minute;

  @override
  int get month => DateTime.now().month;

  @override
  int get second => DateTime.now().second;

  @override
  String get timeZoneName => DateTime.now().timeZoneName;

  @override
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;

  @override
  int get weekday => DateTime.now().weekday;

  @override
  int get year => DateTime.now().year;

  @override
  bool isAfter(DateTime other) => DateTime.now().isAfter(other);

  @override
  bool isAtSameMomentAs(DateTime other) =>
      DateTime.now().isAtSameMomentAs(other);

  @override
  bool isBefore(DateTime other) => DateTime.now().isBefore(other);

  @override
  DateTime toLocal() => DateTime.now().toLocal();

  @override
  String toIso8601String() => DateTime.now().toIso8601String();

  @override
  DateTime toUtc() => DateTime.now().toUtc();
}
