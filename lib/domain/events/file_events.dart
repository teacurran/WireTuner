import 'package:freezed_annotation/freezed_annotation.dart';
import 'event_base.dart';

part 'file_events.freezed.dart';
part 'file_events.g.dart';

/// Event representing a document save operation marker.
///
/// This event is dispatched when a user saves the document to disk.
/// It serves as a checkpoint marker in the event log, indicating
/// that all prior events have been persisted to the file system.
///
/// Related: T004 (Event Model Definition), T033 (Save Document)
@Freezed(toJson: true, fromJson: true)
class SaveDocumentEvent extends EventBase with _$SaveDocumentEvent {
  /// Creates a new save document event.
  const factory SaveDocumentEvent({
    required String eventId,
    required int timestamp,
    String? filePath,
  }) = _SaveDocumentEvent;

  const SaveDocumentEvent._();

  /// Creates a SaveDocumentEvent from a JSON map.
  factory SaveDocumentEvent.fromJson(Map<String, dynamic> json) =>
      _$SaveDocumentEventFromJson(json);

  @override
  String get eventType => 'SaveDocumentEvent';
}

/// Event representing the start of a document load operation.
///
/// This event is dispatched when a user initiates loading a document
/// from disk. It marks the beginning of the load sequence in the event log.
///
/// Related: T004 (Event Model Definition), T034 (Load Document)
@Freezed(toJson: true, fromJson: true)
class LoadDocumentEvent extends EventBase with _$LoadDocumentEvent {
  /// Creates a new load document event.
  const factory LoadDocumentEvent({
    required String eventId,
    required int timestamp,
    required String filePath,
  }) = _LoadDocumentEvent;

  const LoadDocumentEvent._();

  /// Creates a LoadDocumentEvent from a JSON map.
  factory LoadDocumentEvent.fromJson(Map<String, dynamic> json) =>
      _$LoadDocumentEventFromJson(json);

  @override
  String get eventType => 'LoadDocumentEvent';
}

/// Event representing the successful completion of a document load.
///
/// This event is dispatched after a document has been fully loaded
/// from disk and all events have been replayed. It confirms that
/// the document state has been fully reconstructed.
///
/// Related: T004 (Event Model Definition), T034 (Load Document)
@Freezed(toJson: true, fromJson: true)
class DocumentLoadedEvent extends EventBase with _$DocumentLoadedEvent {
  /// Creates a new document loaded event.
  const factory DocumentLoadedEvent({
    required String eventId,
    required int timestamp,
    required String filePath,
    required int eventCount,
  }) = _DocumentLoadedEvent;

  const DocumentLoadedEvent._();

  /// Creates a DocumentLoadedEvent from a JSON map.
  factory DocumentLoadedEvent.fromJson(Map<String, dynamic> json) =>
      _$DocumentLoadedEventFromJson(json);

  @override
  String get eventType => 'DocumentLoadedEvent';
}
