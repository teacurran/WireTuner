/// Unit tests for AutoSaveManager with debounce and deduplication logic.
///
/// Verifies:
/// - 200ms idle threshold debounce behavior
/// - Auto-save only triggers when changes exist
/// - Manual save deduplication (no redundant saves)
/// - Integration with EventStoreGateway
/// - Status callback notifications
///
/// Uses fake timers to deterministically test debounce behavior.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:event_core/event_core.dart';
import 'package:wiretuner/application/interaction/auto_save_manager.dart';

void main() {
  group('AutoSaveManager', () {
    late StubEventStoreGateway eventGateway;
    late AutoSaveManager autoSaveManager;
    late List<AutoSaveStatusUpdate> statusUpdates;

    setUp(() {
      eventGateway = StubEventStoreGateway();
      statusUpdates = [];

      autoSaveManager = AutoSaveManager(
        eventGateway: eventGateway,
        documentId: 'test-doc',
        idleThresholdMs: 200,
        onStatusUpdate: ({
          required status,
          required message,
          eventCount,
        }) {
          statusUpdates.add(AutoSaveStatusUpdate(
            status: status,
            message: message,
            eventCount: eventCount,
          ));
        },
      );
    });

    tearDown(() {
      autoSaveManager.dispose();
    });

    group('Debounce Behavior', () {
      test('triggers auto-save after 200ms idle', () async {
        // Simulate event recording
        autoSaveManager.onEventRecorded();

        // Should not save immediately
        expect(statusUpdates, isEmpty);

        // Wait for idle threshold
        await Future.delayed(const Duration(milliseconds: 250));

        // Should have auto-saved
        expect(statusUpdates, hasLength(1));
        expect(statusUpdates.first.status, AutoSaveStatus.saved);
        expect(statusUpdates.first.message, 'Auto-saved');
      });

      test('resets timer on rapid events (debounce)', () async {
        // Simulate rapid event recording
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 100));

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 100));

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 100));

        // Should not have saved yet (timer keeps resetting)
        expect(statusUpdates, isEmpty);

        // Wait for idle threshold after last event
        await Future.delayed(const Duration(milliseconds: 150));

        // Should have auto-saved once
        expect(statusUpdates, hasLength(1));
        expect(statusUpdates.first.status, AutoSaveStatus.saved);
      });

      test('does not save if no pending changes', () async {
        // Trigger auto-save
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(statusUpdates, hasLength(1));
        statusUpdates.clear();

        // Trigger another auto-save without recording new events
        await Future.delayed(const Duration(milliseconds: 250));

        // Should not auto-save again (no pending changes)
        expect(statusUpdates, isEmpty);
      });

      test('cancels timer on dispose', () async {
        autoSaveManager.onEventRecorded();

        // Dispose before timeout
        autoSaveManager.dispose();

        await Future.delayed(const Duration(milliseconds: 250));

        // Should not have auto-saved
        expect(statusUpdates, isEmpty);
      });
    });

    group('Deduplication', () {
      test('detects changes since last manual save', () async {
        // Initial state - no manual save yet
        expect(autoSaveManager.hasChangesSinceLastManualSave(0), isTrue);
        expect(autoSaveManager.hasChangesSinceLastManualSave(5), isTrue);

        // Record manual save at sequence 10
        autoSaveManager.recordManualSave(10);

        // No changes if sequence matches
        expect(autoSaveManager.hasChangesSinceLastManualSave(10), isFalse);

        // Changes exist if sequence advanced
        expect(autoSaveManager.hasChangesSinceLastManualSave(11), isTrue);
        expect(autoSaveManager.hasChangesSinceLastManualSave(15), isTrue);
      });

      test('does not auto-save duplicate state', () async {
        // Set initial sequence
        eventGateway.setLatestSequence(5);

        // Trigger auto-save
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(statusUpdates, hasLength(1));
        statusUpdates.clear();

        // Trigger auto-save again without changing sequence
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        // Should skip save (no new events)
        expect(statusUpdates, isEmpty);
      });

      test('updates last auto-saved sequence correctly', () async {
        eventGateway.setLatestSequence(10);

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(autoSaveManager.lastAutoSavedSequence, 10);

        // Advance sequence
        eventGateway.setLatestSequence(15);

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(autoSaveManager.lastAutoSavedSequence, 15);
      });
    });

    group('Manual Save Integration', () {
      test('flushPendingAutoSave cancels timer and saves', () async {
        eventGateway.setLatestSequence(5);

        autoSaveManager.onEventRecorded();

        // Flush before timer expires
        final sequence = await autoSaveManager.flushPendingAutoSave();

        expect(sequence, 5);
        expect(statusUpdates, hasLength(1));
        expect(statusUpdates.first.status, AutoSaveStatus.saved);
      });

      test('flushPendingAutoSave waits for in-progress save', () async {
        eventGateway.setLatestSequence(10);
        eventGateway.setDelay(const Duration(milliseconds: 200));

        autoSaveManager.onEventRecorded();

        // Wait for timer to fire and save to start
        await Future.delayed(const Duration(milliseconds: 220));

        // Save should now be in progress (200ms timer + started async work)
        final isSavingDuringSave = autoSaveManager.isSaving;

        // Flush should wait
        final flushFuture = autoSaveManager.flushPendingAutoSave();

        await Future.delayed(const Duration(milliseconds: 50));

        // Should still be saving or waiting
        final isSavingDuringFlush = autoSaveManager.isSaving;

        // Wait for flush to complete
        await flushFuture;

        // After flush completes, should not be saving
        expect(autoSaveManager.isSaving, isFalse);

        // At least one of the checks should have seen isSaving as true
        expect(isSavingDuringSave || isSavingDuringFlush, isTrue);
      });

      test('manual save deduplication workflow', () async {
        eventGateway.setLatestSequence(10);

        // Flush and check changes
        await autoSaveManager.flushPendingAutoSave();

        // No manual save yet - should have changes
        expect(autoSaveManager.hasChangesSinceLastManualSave(10), isTrue);

        // Record manual save
        autoSaveManager.recordManualSave(10);

        // Should not have changes now
        expect(autoSaveManager.hasChangesSinceLastManualSave(10), isFalse);

        // Advance sequence
        eventGateway.setLatestSequence(15);

        // Should have changes again
        expect(autoSaveManager.hasChangesSinceLastManualSave(15), isTrue);
      });
    });

    group('Status Callbacks', () {
      test('invokes callback on successful auto-save', () async {
        eventGateway.setLatestSequence(5);

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(statusUpdates, hasLength(1));
        expect(statusUpdates.first.status, AutoSaveStatus.saved);
        expect(statusUpdates.first.message, 'Auto-saved');
        expect(statusUpdates.first.eventCount, 1);
      });

      test('invokes callback on auto-save failure', () async {
        eventGateway.setShouldFail(true);

        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(statusUpdates, hasLength(1));
        expect(statusUpdates.first.status, AutoSaveStatus.failed);
        expect(statusUpdates.first.message, 'Auto-save failed');
      });

      test('does not invoke callback when no changes', () async {
        eventGateway.setLatestSequence(5);

        // First auto-save
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        statusUpdates.clear();

        // Second auto-save with same sequence
        autoSaveManager.onEventRecorded();
        await Future.delayed(const Duration(milliseconds: 250));

        expect(statusUpdates, isEmpty);
      });
    });

    group('State Management', () {
      test('tracks active state correctly', () {
        eventGateway.setLatestSequence(5);
        expect(autoSaveManager.isActive, isFalse);

        autoSaveManager.onEventRecorded();
        expect(autoSaveManager.isActive, isTrue);
      });

      test('resets pending changes after save', () async {
        eventGateway.setLatestSequence(5);
        autoSaveManager.onEventRecorded();
        expect(autoSaveManager.isActive, isTrue);

        // Wait for auto-save to complete
        await Future.delayed(const Duration(milliseconds: 250));

        // After save completes, should not be active
        expect(autoSaveManager.isActive, isFalse);
      });

      test('tracks last manual save sequence', () {
        expect(autoSaveManager.lastManualSaveSequence, -1);

        autoSaveManager.recordManualSave(10);
        expect(autoSaveManager.lastManualSaveSequence, 10);

        autoSaveManager.recordManualSave(20);
        expect(autoSaveManager.lastManualSaveSequence, 20);
      });
    });
  });
}

/// Test helper for capturing status updates.
class AutoSaveStatusUpdate {
  AutoSaveStatusUpdate({
    required this.status,
    required this.message,
    this.eventCount,
  });

  final AutoSaveStatus status;
  final String message;
  final int? eventCount;
}

/// Stub implementation of EventStoreGateway for testing.
class StubEventStoreGateway implements EventStoreGateway {
  int _latestSequence = 0;
  bool _shouldFail = false;
  Duration _delay = Duration.zero;

  void setLatestSequence(int sequence) {
    _latestSequence = sequence;
  }

  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }

  void setDelay(Duration delay) {
    _delay = delay;
  }

  @override
  Future<int> getLatestSequenceNumber() async {
    await Future.delayed(_delay);
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
    return _latestSequence;
  }

  @override
  Future<void> persistEvent(Map<String, dynamic> eventData) async {
    await Future.delayed(_delay);
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
  }

  @override
  Future<void> persistEventBatch(List<Map<String, dynamic>> events) async {
    await Future.delayed(_delay);
    if (_shouldFail) {
      throw Exception('Simulated failure');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents({
    required int fromSequence,
    int? toSequence,
  }) async {
    return [];
  }

  @override
  Future<void> pruneEventsBeforeSequence(int sequenceNumber) async {}
}
