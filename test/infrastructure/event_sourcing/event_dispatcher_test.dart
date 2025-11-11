import 'package:flutter_test/flutter_test.dart';
import 'package:wiretuner/domain/events/event_base.dart';
import 'package:wiretuner/domain/events/path_events.dart';
import 'package:wiretuner/infrastructure/event_sourcing/event_dispatcher.dart'
    as event_dispatcher;
import 'package:wiretuner/infrastructure/event_sourcing/event_handler_registry.dart';

void main() {
  group('EventHandlerRegistry', () {
    late EventHandlerRegistry registry;

    setUp(() {
      registry = EventHandlerRegistry();
    });

    test('registerHandler stores handler for event type', () {
      // Arrange
      handler(state, event) => 'new state';

      // Act
      registry.registerHandler('TestEvent', handler);

      // Assert
      expect(registry.hasHandler('TestEvent'), true);
      expect(registry.getHandler('TestEvent'), handler);
      expect(registry.handlerCount, 1);
    });

    test('getHandler returns null for unregistered event type', () {
      // Act & Assert
      expect(registry.getHandler('UnknownEvent'), null);
      expect(registry.hasHandler('UnknownEvent'), false);
    });

    test('registerHandler overwrites existing handler', () {
      // Arrange
      handler1(state, event) => 'state1';
      handler2(state, event) => 'state2';

      // Act
      registry.registerHandler('TestEvent', handler1);
      registry.registerHandler('TestEvent', handler2);

      // Assert
      expect(registry.getHandler('TestEvent'), handler2);
      expect(registry.handlerCount, 1);
    });

    test('removeHandler removes registered handler', () {
      // Arrange
      registry.registerHandler('TestEvent', (state, event) => 'state');

      // Act
      final removed = registry.removeHandler('TestEvent');

      // Assert
      expect(removed, true);
      expect(registry.hasHandler('TestEvent'), false);
      expect(registry.handlerCount, 0);
    });

    test('removeHandler returns false for unregistered event type', () {
      // Act
      final removed = registry.removeHandler('UnknownEvent');

      // Assert
      expect(removed, false);
    });

    test('clear removes all handlers', () {
      // Arrange
      registry.registerHandler('Event1', (state, event) => 'state1');
      registry.registerHandler('Event2', (state, event) => 'state2');
      registry.registerHandler('Event3', (state, event) => 'state3');
      expect(registry.handlerCount, 3);

      // Act
      registry.clear();

      // Assert
      expect(registry.handlerCount, 0);
      expect(registry.hasHandler('Event1'), false);
      expect(registry.hasHandler('Event2'), false);
      expect(registry.hasHandler('Event3'), false);
    });

    test('can register multiple handlers for different event types', () {
      // Arrange & Act
      registry.registerHandler('CreatePathEvent', (state, event) => 'path');
      registry.registerHandler('AddAnchorEvent', (state, event) => 'anchor');
      registry.registerHandler('FinishPathEvent', (state, event) => 'finish');

      // Assert
      expect(registry.handlerCount, 3);
      expect(registry.hasHandler('CreatePathEvent'), true);
      expect(registry.hasHandler('AddAnchorEvent'), true);
      expect(registry.hasHandler('FinishPathEvent'), true);
    });
  });

  group('EventDispatcher', () {
    late EventHandlerRegistry registry;
    late event_dispatcher.EventDispatcher dispatcher;

    setUp(() {
      registry = EventHandlerRegistry();
      dispatcher = event_dispatcher.EventDispatcher(registry);
    });

    test('dispatch routes event to correct handler', () {
      // Arrange
      bool handlerCalled = false;
      dynamic receivedState;
      EventBase? receivedEvent;

      registry.registerHandler('CreatePathEvent', (state, event) {
        handlerCalled = true;
        receivedState = state;
        receivedEvent = event;
        return 'new state';
      });

      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      final newState = dispatcher.dispatch('initial state', event);

      // Assert
      expect(handlerCalled, true);
      expect(receivedState, 'initial state');
      expect(receivedEvent, event);
      expect(newState, 'new state');
    });

    test('dispatch throws UnhandledEventException for unregistered event', () {
      // Arrange
      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act & Assert
      expect(
        () => dispatcher.dispatch('state', event),
        throwsA(isA<event_dispatcher.UnhandledEventException>()),
      );
    });

    test('UnhandledEventException contains event type information', () {
      // Arrange
      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act & Assert
      try {
        dispatcher.dispatch('state', event);
        fail('Should have thrown UnhandledEventException');
      } on event_dispatcher.UnhandledEventException catch (e) {
        expect(e.eventType, 'CreatePathEvent');
        expect(e.message, contains('CreatePathEvent'));
        expect(e.toString(), contains('UnhandledEventException'));
        expect(e.toString(), contains('CreatePathEvent'));
      }
    });

    test('dispatch supports multiple handlers for different event types', () {
      // Arrange
      int createPathCalls = 0;
      int addAnchorCalls = 0;

      registry.registerHandler('CreatePathEvent', (state, event) {
        createPathCalls++;
        return 'state after create';
      });

      registry.registerHandler('AddAnchorEvent', (state, event) {
        addAnchorCalls++;
        return 'state after add';
      });

      final createEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      final addEvent = AddAnchorEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        position: const Point(x: 150, y: 250),
      );

      // Act
      dispatcher.dispatch('state', createEvent);
      dispatcher.dispatch('state', addEvent);

      // Assert
      expect(createPathCalls, 1);
      expect(addAnchorCalls, 1);
    });

    test('dispatch returns handler return value', () {
      // Arrange
      registry.registerHandler(
          'CreatePathEvent', (state, event) => 'transformed state');

      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act
      final result = dispatcher.dispatch('initial', event);

      // Assert
      expect(result, 'transformed state');
    });

    test('dispatch propagates handler exceptions', () {
      // Arrange
      registry.registerHandler('CreatePathEvent', (state, event) {
        throw Exception('Handler error');
      });

      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 100, y: 200),
      );

      // Act & Assert
      expect(
        () => dispatcher.dispatch('state', event),
        throwsException,
      );
    });

    test('dispatch works with complex event data', () {
      // Arrange
      CreatePathEvent? capturedEvent;

      registry.registerHandler('CreatePathEvent', (state, event) {
        capturedEvent = event as CreatePathEvent;
        return 'new state';
      });

      const event = CreatePathEvent(
        eventId: 'evt-complex-123',
        timestamp: 1234567890,
        pathId: 'path-abc',
        startAnchor: Point(x: 123.45, y: 678.90),
        fillColor: '#FF0000',
        strokeColor: '#00FF00',
        strokeWidth: 2.5,
        opacity: 0.8,
      );

      // Act
      dispatcher.dispatch('state', event);

      // Assert
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.eventId, 'evt-complex-123');
      expect(capturedEvent!.timestamp, 1234567890);
      expect(capturedEvent!.pathId, 'path-abc');
      expect(capturedEvent!.startAnchor.x, 123.45);
      expect(capturedEvent!.startAnchor.y, 678.90);
      expect(capturedEvent!.fillColor, '#FF0000');
      expect(capturedEvent!.strokeColor, '#00FF00');
      expect(capturedEvent!.strokeWidth, 2.5);
      expect(capturedEvent!.opacity, 0.8);
    });

    test('dispatch handles different event types with polymorphism', () {
      // Arrange
      final results = <String>[];

      registry.registerHandler('CreatePathEvent', (state, event) {
        results.add('create');
        return state;
      });

      registry.registerHandler('AddAnchorEvent', (state, event) {
        results.add('add');
        return state;
      });

      registry.registerHandler('FinishPathEvent', (state, event) {
        results.add('finish');
        return state;
      });

      final createEvent = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 0, y: 0),
      );

      final addEvent = AddAnchorEvent(
        eventId: 'evt-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        position: const Point(x: 100, y: 100),
      );

      final finishEvent = FinishPathEvent(
        eventId: 'evt-3',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        closed: true,
      );

      // Act
      dispatcher.dispatch('state', createEvent);
      dispatcher.dispatch('state', addEvent);
      dispatcher.dispatch('state', finishEvent);

      // Assert
      expect(results, ['create', 'add', 'finish']);
    });

    test('dispatch maintains state immutability contract', () {
      // Arrange
      final initialState = {'counter': 0};

      registry.registerHandler('CreatePathEvent', (state, event) {
        // Return NEW state, don't mutate input
        final oldState = state as Map<String, int>;
        return {'counter': oldState['counter']! + 1};
      });

      final event = CreatePathEvent(
        eventId: 'evt-1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pathId: 'path-1',
        startAnchor: const Point(x: 0, y: 0),
      );

      // Act
      final newState = dispatcher.dispatch(initialState, event);

      // Assert
      expect(initialState['counter'], 0); // Original unchanged
      expect(newState['counter'], 1); // New state updated
      expect(identical(initialState, newState), false); // Different instances
    });

    group('dispatchAll', () {
      test('dispatches multiple events in sequence', () {
        // Arrange
        registry.registerHandler(
            'CreatePathEvent', (state, event) => (state as int) + 1);

        registry.registerHandler(
            'AddAnchorEvent', (state, event) => (state as int) + 10);

        final events = [
          CreatePathEvent(
            eventId: 'evt-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            startAnchor: const Point(x: 0, y: 0),
          ),
          AddAnchorEvent(
            eventId: 'evt-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            position: const Point(x: 100, y: 100),
          ),
          CreatePathEvent(
            eventId: 'evt-3',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-2',
            startAnchor: const Point(x: 0, y: 0),
          ),
        ];

        // Act
        final finalState = dispatcher.dispatchAll(0, events);

        // Assert
        // 0 + 1 (CreatePath) + 10 (AddAnchor) + 1 (CreatePath) = 12
        expect(finalState, 12);
      });

      test('dispatchAll with empty list returns initial state', () {
        // Act
        final finalState = dispatcher.dispatchAll('initial', []);

        // Assert
        expect(finalState, 'initial');
      });

      test('dispatchAll stops on unhandled event', () {
        // Arrange
        registry.registerHandler(
            'CreatePathEvent', (state, event) => (state as int) + 1);

        final events = [
          CreatePathEvent(
            eventId: 'evt-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            startAnchor: const Point(x: 0, y: 0),
          ),
          AddAnchorEvent(
            // No handler registered for this
            eventId: 'evt-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            position: const Point(x: 100, y: 100),
          ),
        ];

        // Act & Assert
        expect(
          () => dispatcher.dispatchAll(0, events),
          throwsA(isA<event_dispatcher.UnhandledEventException>()),
        );
      });

      test('dispatchAll accumulates state changes', () {
        // Arrange
        registry.registerHandler('CreatePathEvent', (state, event) {
          final list = state as List<String>;
          return [...list, 'create'];
        });

        registry.registerHandler('AddAnchorEvent', (state, event) {
          final list = state as List<String>;
          return [...list, 'add'];
        });

        final events = [
          CreatePathEvent(
            eventId: 'evt-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            startAnchor: const Point(x: 0, y: 0),
          ),
          AddAnchorEvent(
            eventId: 'evt-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            position: const Point(x: 100, y: 100),
          ),
          AddAnchorEvent(
            eventId: 'evt-3',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pathId: 'path-1',
            position: const Point(x: 200, y: 200),
          ),
        ];

        // Act
        final finalState = dispatcher.dispatchAll(<String>[], events);

        // Assert
        expect(finalState, ['create', 'add', 'add']);
      });
    });
  });

  group('Integration Tests', () {
    test('dispatcher works with real event types from domain', () {
      // Arrange
      final registry = EventHandlerRegistry();
      final dispatcher = event_dispatcher.EventDispatcher(registry);

      // Mock state (placeholder until Document model exists)
      final mockDocument = {
        'paths': <String, dynamic>{},
        'version': 1,
      };

      // Register handlers for real event types
      registry.registerHandler('CreatePathEvent', (state, event) {
        final doc = state as Map<String, dynamic>;
        final evt = event as CreatePathEvent;
        final paths = Map<String, dynamic>.from(doc['paths'] as Map);
        paths[evt.pathId] = {'anchors': []};
        return {'paths': paths, 'version': doc['version']};
      });

      registry.registerHandler('AddAnchorEvent', (state, event) {
        final doc = state as Map<String, dynamic>;
        final evt = event as AddAnchorEvent;
        final paths = Map<String, dynamic>.from(doc['paths'] as Map);
        final path = paths[evt.pathId] as Map<String, dynamic>;
        final anchors = List.from(path['anchors'] as List);
        anchors.add({'x': evt.position.x, 'y': evt.position.y});
        paths[evt.pathId] = {'anchors': anchors};
        return {'paths': paths, 'version': doc['version']};
      });

      final events = [
        CreatePathEvent(
          eventId: 'evt-1',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          startAnchor: const Point(x: 0, y: 0),
        ),
        AddAnchorEvent(
          eventId: 'evt-2',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          position: const Point(x: 100, y: 100),
        ),
        AddAnchorEvent(
          eventId: 'evt-3',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pathId: 'path-1',
          position: const Point(x: 200, y: 200),
        ),
      ];

      // Act
      final finalState = dispatcher.dispatchAll(mockDocument, events);

      // Assert
      final paths = finalState['paths'] as Map<String, dynamic>;
      expect(paths.containsKey('path-1'), true);
      final path = paths['path-1'] as Map<String, dynamic>;
      final anchors = path['anchors'] as List;
      expect(anchors.length, 2); // AddAnchor events add anchors
      expect(anchors[0]['x'], 100);
      expect(anchors[0]['y'], 100);
      expect(anchors[1]['x'], 200);
      expect(anchors[1]['y'], 200);
    });
  });
}
