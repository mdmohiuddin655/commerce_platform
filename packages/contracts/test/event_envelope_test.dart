import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

const String eventId = 'evt_9Lm22cz-Rw07Yy5C';
const String resourceId = 'ord_Xa91ZZ0plQ7rTt4B';
const String commandId = 'cmd_7Kd93ba-Qz18Xu2P';

Result<EventEnvelope> build({
  String id = eventId,
  DateTime? serverTime,
  int? revision = 4,
  String? cause = commandId,
}) => EventEnvelope.create(
  eventId: id,
  eventType: 'order.accepted',
  resourceId: resourceId,
  serverTimeUtc: serverTime ?? DateTime.utc(2026, 9, 9, 12, 30),
  resourceRevision: revision,
  causedByCommandId: cause,
);

String? codeOf(Result<EventEnvelope> r) =>
    r.fold((EventEnvelope _) => null, (Failure f) => f.code);

void main() {
  group('valid event', () {
    test('carries id, server time, revision and command linkage', () {
      final EventEnvelope event = build().fold(
        (EventEnvelope e) => e,
        (Failure f) => throw StateError(f.message),
      );

      expect(event.eventId, eventId);
      expect(event.resourceRevision, 4);
      expect(event.causedByCommandId, commandId);
      expect(event.serverTimeUtc.isUtc, isTrue);
      expect(event.contractVersion, ContractVersion.current);
    });

    test('allows a worker-raised event with no causing command', () {
      // Reservation expiry has no client command behind it.
      expect(build(cause: null, revision: null).isOk, isTrue);
    });

    test('identity is the event id alone', () {
      final EventEnvelope a = build().fold(
        (EventEnvelope e) => e,
        (Failure f) => throw StateError('n/a'),
      );
      final EventEnvelope b = build(revision: 9).fold(
        (EventEnvelope e) => e,
        (Failure f) => throw StateError('n/a'),
      );

      expect(a, b, reason: 'same eventId is the same fact');
    });
  });

  group('invalid event input', () {
    test('rejects a non-UTC server time', () {
      expect(
        codeOf(build(serverTime: DateTime(2026, 9, 9, 12, 30))),
        'EVENT_TIME_NOT_UTC',
      );
    });

    test('rejects a negative revision', () {
      expect(codeOf(build(revision: -1)), 'EVENT_REVISION_INVALID');
    });

    test('rejects a malformed causing command id', () {
      expect(codeOf(build(cause: '7')), 'EVENT_CAUSE_INVALID');
    });
  });

  group('transport separation', () {
    test('an FCM-style transport id cannot be used as the event id', () {
      // The business event id is server-assigned. A transport id fails the
      // opaque-id rules, so it cannot be substituted even by accident.
      expect(
        codeOf(build(id: '0:1699999999999999%abcdef12abcdef12')),
        'EVENT_ID_INVALID',
      );
    });

    test('a UUID is a legal opaque id — shape is not the guarantee', () {
      // Stated plainly so the previous test is not over-read: plenty of
      // transport ids are well formed. Rejecting malformed ones is a
      // backstop, not the mechanism.
      expect(build(id: 'B7A1F3C2-9D4E-4A11-8C22-5E6F70A1B2C3').isOk, isTrue);
    });

    test('the real guarantee is structural: no transport field exists', () {
      // EventEnvelope.create requires a server-assigned eventId and offers no
      // transportMessageId parameter at all, so an adapter must map its
      // transport id to the business id rather than substitute it. If a
      // transport field is ever added, this test's premise breaks in review.
      final EventEnvelope event = build().fold(
        (EventEnvelope e) => e,
        (Failure f) => throw StateError('n/a'),
      );

      expect(event.eventId, eventId);
      expect(
        event.toString(),
        allOf(isNot(contains('transport')), isNot(contains('fcm'))),
      );
    });
  });
}
