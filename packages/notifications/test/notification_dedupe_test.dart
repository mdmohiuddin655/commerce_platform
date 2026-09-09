import 'package:cp_notifications/cp_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

InboxEvent event(String id, {String kind = 'order.accepted', int minute = 0}) =>
    InboxEvent(
      eventId: id,
      kind: kind,
      serverTime: DateTime.utc(2026, 9, 9, 12, minute),
    );

void main() {
  group('NotificationDeduplicator', () {
    test('accepts a new eventId once', () {
      final NotificationDeduplicator d = NotificationDeduplicator();

      expect(d.accept(event('e1')), isTrue);
      expect(d.hasSeen('e1'), isTrue);
    });

    test('drops a duplicate delivery of the same eventId', () {
      final NotificationDeduplicator d = NotificationDeduplicator();
      d.accept(event('e1'));

      expect(d.accept(event('e1')), isFalse);
      expect(d.trackedCount, 1);
    });

    test('same event delivered by two transports collapses to one', () {
      // A push copy and a polled inbox copy of one business event differ in
      // payload detail but carry the same server-assigned eventId.
      final NotificationDeduplicator d = NotificationDeduplicator();
      final InboxEvent push = InboxEvent(
        eventId: 'evt-42',
        kind: 'assignment.offered',
        serverTime: DateTime.utc(2026, 9, 9, 12),
        data: const <String, String>{'via': 'push'},
      );
      final InboxEvent polled = InboxEvent(
        eventId: 'evt-42',
        kind: 'assignment.offered',
        serverTime: DateTime.utc(2026, 9, 9, 12),
        data: const <String, String>{'via': 'inbox', 'extra': 'detail'},
      );

      expect(d.accept(push), isTrue);
      expect(d.accept(polled), isFalse);
    });

    test('reordered arrival is harmless — order is never depended on', () {
      final NotificationDeduplicator a = NotificationDeduplicator();
      final NotificationDeduplicator b = NotificationDeduplicator();

      final List<InboxEvent> forwards = <InboxEvent>[
        event('e1', minute: 1),
        event('e2', minute: 2),
        event('e3', minute: 3),
      ];
      final List<InboxEvent> backwards = forwards.reversed.toList();

      final List<String> acceptedA = <String>[
        for (final InboxEvent e in forwards)
          if (a.accept(e)) e.eventId,
      ];
      final List<String> acceptedB = <String>[
        for (final InboxEvent e in backwards)
          if (b.accept(e)) e.eventId,
      ];

      expect(acceptedA.toSet(), acceptedB.toSet());
      expect(acceptedA.length, 3);
    });

    test('distinct ids are all accepted', () {
      final NotificationDeduplicator d = NotificationDeduplicator();

      expect(d.accept(event('a')), isTrue);
      expect(d.accept(event('b')), isTrue);
      expect(d.trackedCount, 2);
    });

    test('memory stays bounded, evicting oldest first', () {
      final NotificationDeduplicator d = NotificationDeduplicator(capacity: 3);

      for (final String id in <String>['a', 'b', 'c', 'd']) {
        d.accept(event(id));
      }

      expect(d.trackedCount, 3);
      expect(d.hasSeen('a'), isFalse, reason: 'oldest evicted');
      expect(d.hasSeen('d'), isTrue);
    });

    test('rejects a non-positive capacity', () {
      expect(
        () => NotificationDeduplicator(capacity: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
