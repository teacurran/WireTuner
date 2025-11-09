import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_sampler.dart';

void main() {
  group('EventSampler', () {
    group('Basic Sampling Behavior', () {
      test('rapid events < 50ms apart are buffered, only last emitted',
          () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Generate 5 events within 40ms (8ms apart)
        for (int i = 0; i < 5; i++) {
          sampler.recordEvent(_createTestEvent(i));
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }

        // Wait for potential delayed emissions
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Only 1 event should be emitted (the first one, index 0)
        // because it was the first event and triggered immediate emission
        expect(emitted.length, equals(1));
        expect((emitted[0] as CreatePathEvent).pathId, equals('path_0'));

        // Now flush to get the buffered event (index 4)
        sampler.flush();

        expect(emitted.length, equals(2));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_4'));
      });

      test('events >= 50ms apart are emitted immediately', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        sampler.recordEvent(_createTestEvent(1));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        sampler.recordEvent(_createTestEvent(2));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        sampler.recordEvent(_createTestEvent(3));

        // All 3 events should be emitted
        expect(emitted.length, equals(3));
        expect((emitted[0] as CreatePathEvent).pathId, equals('path_1'));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_2'));
        expect((emitted[2] as CreatePathEvent).pathId, equals('path_3'));
      });

      test('mixed rapid and spaced events emit correctly', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Event 0: immediate (first event)
        sampler.recordEvent(_createTestEvent(0));
        expect(emitted.length, equals(1));

        // Events 1-3: rapid (< 50ms), only buffer last
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sampler.recordEvent(_createTestEvent(1));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sampler.recordEvent(_createTestEvent(2));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sampler.recordEvent(_createTestEvent(3));

        expect(emitted.length, equals(1)); // Still only event 0

        // Event 4: wait 60ms, should emit buffered event 3, then event 4
        await Future<void>.delayed(const Duration(milliseconds: 60));
        sampler.recordEvent(_createTestEvent(4));

        expect(emitted.length, equals(2));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_4'));
      });
    });

    group('Flush Behavior', () {
      test('flush() emits buffered event immediately', () {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Record first event (emitted immediately)
        sampler.recordEvent(_createTestEvent(1));
        expect(emitted.length, equals(1));

        // Record second event immediately (buffered)
        sampler.recordEvent(_createTestEvent(2));
        expect(emitted.length, equals(1)); // Still only first event

        // Flush should emit buffered event
        sampler.flush();

        expect(emitted.length, equals(2));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_2'));
      });

      test('flush() on empty buffer does nothing', () {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        sampler.flush(); // Should not throw

        expect(emitted, isEmpty);
      });

      test('multiple consecutive flushes are idempotent', () {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        sampler.recordEvent(_createTestEvent(1));
        sampler.recordEvent(_createTestEvent(2)); // Buffered

        sampler.flush();
        expect(emitted.length, equals(2));

        // Multiple flushes should not duplicate emissions
        sampler.flush();
        sampler.flush();
        expect(emitted.length, equals(2));
      });

      test('flush() after elapsed time with buffered event', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        sampler.recordEvent(_createTestEvent(1));
        sampler.recordEvent(_createTestEvent(2)); // Buffered

        // Wait for interval to elapse
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Flush should still emit buffered event
        sampler.flush();

        expect(emitted.length, equals(2));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_2'));
      });
    });

    group('Configurable Sampling Interval', () {
      test('custom sampling interval is respected', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
          samplingInterval: const Duration(milliseconds: 100),
        );

        sampler.recordEvent(_createTestEvent(1));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Should be buffered (< 100ms)
        sampler.recordEvent(_createTestEvent(2));
        expect(emitted.length, equals(1));

        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Should emit (>= 100ms total)
        sampler.recordEvent(_createTestEvent(3));
        expect(emitted.length, equals(2));
      });

      test('setSamplingInterval() changes behavior', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
          samplingInterval: const Duration(milliseconds: 50),
        );

        sampler.recordEvent(_createTestEvent(1));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        sampler.recordEvent(_createTestEvent(2)); // Buffered

        // Change interval to 20ms
        sampler.setSamplingInterval(const Duration(milliseconds: 20));

        await Future<void>.delayed(const Duration(milliseconds: 25));

        // Should emit (>= 20ms from last emission)
        sampler.recordEvent(_createTestEvent(3));
        expect(emitted.length, equals(2));
      });

      test('zero interval disables sampling (emit all events)', () {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
          samplingInterval: Duration.zero,
        );

        // All events should be emitted immediately
        sampler.recordEvent(_createTestEvent(1));
        sampler.recordEvent(_createTestEvent(2));
        sampler.recordEvent(_createTestEvent(3));

        expect(emitted.length, equals(3));
      });

      test('samplingInterval getter returns current interval', () {
        final sampler = EventSampler(
          onEventEmit: (_) {},
          samplingInterval: const Duration(milliseconds: 75),
        );

        expect(
            sampler.samplingInterval, equals(const Duration(milliseconds: 75)));

        sampler.setSamplingInterval(const Duration(milliseconds: 100));
        expect(sampler.samplingInterval,
            equals(const Duration(milliseconds: 100)));
      });
    });

    group('Edge Cases', () {
      test('very rapid events (1ms apart) are properly buffered', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Emit 20 events at 1ms intervals (total ~20ms, well under 50ms)
        for (int i = 0; i < 20; i++) {
          sampler.recordEvent(_createTestEvent(i));
          if (i < 19)
            await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        // Should only have emitted very few events (first one, maybe one more)
        // Allow tolerance for timing variance
        final emittedBeforeFlush = emitted.length;
        expect(emittedBeforeFlush, lessThanOrEqualTo(3));

        sampler.flush();

        // After flush, should have one more event
        expect(emitted.length, equals(emittedBeforeFlush + 1));

        // First event should always be path_0
        expect((emitted.first as CreatePathEvent).pathId, equals('path_0'));

        // Last event should be one of the final events (path_18 or path_19)
        final lastPathId = (emitted.last as CreatePathEvent).pathId;
        expect(['path_18', 'path_19'].contains(lastPathId), isTrue);
      });

      test('single event is emitted immediately', () {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        sampler.recordEvent(_createTestEvent(1));

        expect(emitted.length, equals(1));
      });

      test('alternating rapid and flush maintains correctness', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Event 0: immediate
        sampler.recordEvent(_createTestEvent(0));
        expect(emitted.length, equals(1));

        // Event 1: buffered
        sampler.recordEvent(_createTestEvent(1));
        expect(emitted.length, equals(1));

        sampler.flush();
        expect(emitted.length, equals(2));

        // Wait for sampling interval to elapse
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Event 2: immediate (>= 50ms has elapsed)
        sampler.recordEvent(_createTestEvent(2));
        expect(emitted.length, equals(3));

        // Event 3: buffered
        sampler.recordEvent(_createTestEvent(3));
        expect(emitted.length, equals(3));

        sampler.flush();
        expect(emitted.length, equals(4));

        // Verify order
        expect((emitted[0] as CreatePathEvent).pathId, equals('path_0'));
        expect((emitted[1] as CreatePathEvent).pathId, equals('path_1'));
        expect((emitted[2] as CreatePathEvent).pathId, equals('path_2'));
        expect((emitted[3] as CreatePathEvent).pathId, equals('path_3'));
      });

      test('callback exception does not corrupt sampler state', () {
        var callCount = 0;
        final sampler = EventSampler(
          onEventEmit: (event) {
            callCount++;
            if (callCount == 1) {
              throw Exception('Test exception');
            }
          },
        );

        // First event throws
        expect(
          () => sampler.recordEvent(_createTestEvent(1)),
          throwsException,
        );

        // Sampler should still work after exception
        expect(
          () => sampler.recordEvent(_createTestEvent(2)),
          returnsNormally,
        );
        expect(callCount, equals(2));
      });
    });

    group('Real-World Scenarios', () {
      test('simulates mouse drag with 200 events over 2 seconds', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Simulate 200 events at 10ms intervals (2 seconds total)
        for (int i = 0; i < 200; i++) {
          sampler.recordEvent(_createTestEvent(i));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        sampler.flush();

        // With 50ms sampling, expect ~40 events (2000ms / 50ms)
        // Allow wider tolerance for timing imprecision in test environment
        expect(emitted.length, greaterThanOrEqualTo(30));
        expect(emitted.length, lessThanOrEqualTo(60));

        // Verify first and last events are present
        expect((emitted.first as CreatePathEvent).pathId, equals('path_0'));
        expect((emitted.last as CreatePathEvent).pathId, equals('path_199'));
      });

      test('simulates slow drag with 20 events over 2 seconds', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Simulate 20 events at 100ms intervals (2 seconds total)
        for (int i = 0; i < 20; i++) {
          sampler.recordEvent(_createTestEvent(i));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        sampler.flush();

        // All events should be emitted (100ms > 50ms sampling)
        expect(emitted.length, equals(20));
      });

      test('simulates burst-pause-burst pattern', () async {
        final emitted = <EventBase>[];
        final sampler = EventSampler(
          onEventEmit: (event) => emitted.add(event),
        );

        // Burst 1: 10 rapid events (2ms apart = 20ms total, well under 50ms)
        for (int i = 0; i < 10; i++) {
          sampler.recordEvent(_createTestEvent(i));
          if (i < 9)
            await Future<void>.delayed(const Duration(milliseconds: 2));
        }

        // At this point, only event 0 was emitted (first event)
        // Event 9 is buffered
        final emittedAfterBurst1 = emitted.length;
        expect(emittedAfterBurst1,
            lessThanOrEqualTo(2)); // Allow some timing variance

        // Pause for 100ms
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Burst 2: 10 rapid events
        // First event of burst 2 will trigger emission since >50ms elapsed
        for (int i = 10; i < 20; i++) {
          sampler.recordEvent(_createTestEvent(i));
          if (i < 19)
            await Future<void>.delayed(const Duration(milliseconds: 2));
        }

        // At this point: should have initial burst events + event 10
        // Event 19 is buffered
        final emittedAfterBurst2 = emitted.length;
        expect(emittedAfterBurst2, greaterThanOrEqualTo(2));

        sampler.flush();

        // After flush: should have all emitted events + the flushed one
        expect(emitted.length, equals(emittedAfterBurst2 + 1));

        // Verify first and last events are correct
        expect((emitted.first as CreatePathEvent).pathId, equals('path_0'));
        expect((emitted.last as CreatePathEvent).pathId, equals('path_19'));
      });
    });
  });
}

/// Helper function to create test events.
CreatePathEvent _createTestEvent(int id) => CreatePathEvent(
      eventId: 'test_event_$id',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      pathId: 'path_$id',
      startAnchor: Point(x: id.toDouble(), y: id.toDouble()),
    );
