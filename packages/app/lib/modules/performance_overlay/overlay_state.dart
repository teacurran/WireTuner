/// State management for the performance overlay.
///
/// This module provides state models and persistence for overlay position,
/// docking, and visibility preferences.
library;

import 'package:flutter/material.dart';

/// Docking location for the performance overlay.
enum DockLocation {
  topLeft('Top Left'),
  topRight('Top Right'),
  bottomLeft('Bottom Left'),
  bottomRight('Bottom Right'),
  floating('Floating');

  const DockLocation(this.displayName);
  final String displayName;

  /// Converts dock location to JSON string.
  String toJson() => name;

  /// Creates dock location from JSON string.
  static DockLocation fromJson(String json) {
    return DockLocation.values.firstWhere(
      (location) => location.name == json,
      orElse: () => DockLocation.topRight,
    );
  }
}

/// State of the performance overlay.
///
/// This class represents the persistent state of the overlay including
/// position, visibility, and docking preferences.
class PerformanceOverlayState {
  /// Creates an overlay state.
  const PerformanceOverlayState({
    this.isVisible = false,
    this.dockLocation = DockLocation.topRight,
    this.position = const Offset(16, 16),
  });

  /// Default state (top-right, hidden).
  factory PerformanceOverlayState.defaultState() => const PerformanceOverlayState();

  /// Creates state from JSON map.
  factory PerformanceOverlayState.fromJson(Map<String, dynamic> json) {
    return PerformanceOverlayState(
      isVisible: json['isVisible'] as bool? ?? false,
      dockLocation: DockLocation.fromJson(
        json['dockLocation'] as String? ?? 'topRight',
      ),
      position: json['position'] != null
          ? Offset(
              (json['position']['dx'] as num).toDouble(),
              (json['position']['dy'] as num).toDouble(),
            )
          : const Offset(16, 16),
    );
  }

  /// Whether the overlay is visible.
  final bool isVisible;

  /// Current dock location (or floating).
  final DockLocation dockLocation;

  /// Position when floating (offset from top-left).
  final Offset position;

  /// Whether the overlay is docked (not floating).
  bool get isDocked => dockLocation != DockLocation.floating;

  /// Creates a copy with updated fields.
  PerformanceOverlayState copyWith({
    bool? isVisible,
    DockLocation? dockLocation,
    Offset? position,
  }) {
    return PerformanceOverlayState(
      isVisible: isVisible ?? this.isVisible,
      dockLocation: dockLocation ?? this.dockLocation,
      position: position ?? this.position,
    );
  }

  /// Converts state to JSON map for persistence.
  Map<String, dynamic> toJson() {
    return {
      'isVisible': isVisible,
      'dockLocation': dockLocation.toJson(),
      'position': {
        'dx': position.dx,
        'dy': position.dy,
      },
    };
  }

  /// Calculates the overlay position based on dock location and canvas size.
  ///
  /// If docked, returns the appropriate corner position with margin.
  /// If floating, returns the stored position clamped to canvas bounds.
  Offset calculatePosition(Size canvasSize, Size overlaySize) {
    const margin = 16.0;

    switch (dockLocation) {
      case DockLocation.topLeft:
        return const Offset(margin, margin);

      case DockLocation.topRight:
        return Offset(canvasSize.width - overlaySize.width - margin, margin);

      case DockLocation.bottomLeft:
        return Offset(margin, canvasSize.height - overlaySize.height - margin);

      case DockLocation.bottomRight:
        return Offset(
          canvasSize.width - overlaySize.width - margin,
          canvasSize.height - overlaySize.height - margin,
        );

      case DockLocation.floating:
        // Clamp position to ensure overlay stays within bounds
        final clampedX = position.dx.clamp(
          0.0,
          (canvasSize.width - overlaySize.width).clamp(0.0, double.infinity),
        );
        final clampedY = position.dy.clamp(
          0.0,
          (canvasSize.height - overlaySize.height).clamp(0.0, double.infinity),
        );
        return Offset(clampedX, clampedY);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceOverlayState &&
          runtimeType == other.runtimeType &&
          isVisible == other.isVisible &&
          dockLocation == other.dockLocation &&
          position == other.position;

  @override
  int get hashCode =>
      isVisible.hashCode ^ dockLocation.hashCode ^ position.hashCode;

  @override
  String toString() =>
      'PerformanceOverlayState(isVisible: $isVisible, dockLocation: $dockLocation, position: $position)';
}
