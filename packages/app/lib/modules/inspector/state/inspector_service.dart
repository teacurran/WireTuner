import 'dart:async';

/// Inspector command types.
enum InspectorCommand {
  updateObjectProperties,
  selectLayer,
  addLayer,
  removeLayer,
  renameLayer,
  toggleLayerVisibility,
  toggleLayerLock,
  moveLayerUp,
  moveLayerDown,
  moveLayerToFront,
  moveLayerToBack,
}

/// Inspector command event.
class InspectorCommandEvent {
  final InspectorCommand command;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  InspectorCommandEvent({
    required this.command,
    required this.data,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'InspectorCommandEvent($command, $data)';
}

/// Service for managing Inspector commands and integration with domain layer.
///
/// This service provides:
/// - Command dispatch abstraction
/// - Telemetry hooks
/// - Future integration with InteractionEngine/EventStore
///
/// ## Architecture
///
/// Follows the NavigatorService pattern:
/// - Exposes command stream for listeners
/// - Provides typed command dispatch methods
/// - Routes commands through single abstraction point
///
/// ## Usage
///
/// ```dart
/// final service = InspectorService(
///   telemetryCallback: (metric, data) => telemetry.record(metric, data),
/// );
///
/// service.commandStream.listen((event) {
///   // Wire to InteractionEngine/EventStore
///   eventStore.dispatch(event.command, event.data);
/// });
/// ```
///
/// Related: FR-045, InteractionEngine integration
class InspectorService {
  final StreamController<InspectorCommandEvent> _commandController =
      StreamController<InspectorCommandEvent>.broadcast();

  /// Callback for telemetry metrics.
  final void Function(String metric, Map<String, dynamic> data)? telemetryCallback;

  InspectorService({
    this.telemetryCallback,
  });

  /// Stream of command events.
  Stream<InspectorCommandEvent> get commandStream => _commandController.stream;

  /// Dispatch a command to the domain layer.
  void dispatch(InspectorCommand command, Map<String, dynamic> data) {
    final event = InspectorCommandEvent(
      command: command,
      data: data,
    );

    _commandController.add(event);

    // Record telemetry
    telemetryCallback?.call('inspector.command', {
      'command': command.name,
      'timestamp': event.timestamp.toIso8601String(),
      ...data,
    });
  }

  /// Update object properties.
  void updateObjectProperties(String objectId, Map<String, dynamic> properties) {
    dispatch(InspectorCommand.updateObjectProperties, {
      'objectId': objectId,
      'properties': properties,
    });
  }

  /// Select layers.
  void selectLayers(List<String> layerIds) {
    dispatch(InspectorCommand.selectLayer, {
      'layerIds': layerIds,
    });
  }

  /// Add a new layer.
  void addLayer(String layerId, String type, {String? parentId}) {
    dispatch(InspectorCommand.addLayer, {
      'layerId': layerId,
      'type': type,
      'parentId': parentId,
    });
  }

  /// Remove a layer.
  void removeLayer(String layerId) {
    dispatch(InspectorCommand.removeLayer, {
      'layerId': layerId,
    });
  }

  /// Rename a layer.
  void renameLayer(String layerId, String newName) {
    dispatch(InspectorCommand.renameLayer, {
      'layerId': layerId,
      'name': newName,
    });
  }

  /// Toggle layer visibility.
  void toggleLayerVisibility(String layerId, bool isVisible) {
    dispatch(InspectorCommand.toggleLayerVisibility, {
      'layerId': layerId,
      'isVisible': isVisible,
    });
  }

  /// Toggle layer lock.
  void toggleLayerLock(String layerId, bool isLocked) {
    dispatch(InspectorCommand.toggleLayerLock, {
      'layerId': layerId,
      'isLocked': isLocked,
    });
  }

  /// Move layer up (forward in z-order).
  void moveLayerUp(String layerId) {
    dispatch(InspectorCommand.moveLayerUp, {
      'layerId': layerId,
    });
  }

  /// Move layer down (backward in z-order).
  void moveLayerDown(String layerId) {
    dispatch(InspectorCommand.moveLayerDown, {
      'layerId': layerId,
    });
  }

  /// Move layer to front.
  void moveLayerToFront(String layerId) {
    dispatch(InspectorCommand.moveLayerToFront, {
      'layerId': layerId,
    });
  }

  /// Move layer to back.
  void moveLayerToBack(String layerId) {
    dispatch(InspectorCommand.moveLayerToBack, {
      'layerId': layerId,
    });
  }

  void dispose() {
    _commandController.close();
  }
}
