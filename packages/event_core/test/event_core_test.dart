import 'package:event_core/event_core.dart';
import 'package:test/test.dart';

void main() {
  group('EventRecorder', () {
    test('can be instantiated', () {
      const recorder = EventRecorder();
      expect(recorder, isNotNull);
    });

    test('has correct sampling interval', () {
      const recorder = EventRecorder();
      expect(recorder.samplingIntervalMs, equals(50));
    });
  });

  group('EventReplayer', () {
    test('can be instantiated', () {
      const replayer = EventReplayer();
      expect(replayer, isNotNull);
    });

    test('initial state is not replaying', () {
      const replayer = EventReplayer();
      expect(replayer.isReplaying, isFalse);
    });
  });

  group('SnapshotService', () {
    test('can be instantiated', () {
      const service = SnapshotService();
      expect(service, isNotNull);
    });

    test('has correct snapshot interval', () {
      const service = SnapshotService();
      expect(service.snapshotInterval, equals(1000));
    });
  });
}
