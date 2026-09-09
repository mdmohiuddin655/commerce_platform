import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

const String principalA = 'usr_alpha01Aa-Bb22Cc3';
const String principalB = 'usr_bravo01Aa-Bb22Cc3';
const String resourceId = 'ord_Xa91ZZ0plQ7rTt4B';

Principal user(String id) => Principal.fromVerifiedSubject(id);

const AuthorizationDecision allowed = AuthorizationDecision.allow();
const AuthorizationDecision denied =
    AuthorizationDecision.deny(DenyReason.membershipNotActive);

CommandEnvelope envelope({
  String commandId = 'cmd_7Kd93ba-Qz18Xu2P',
  String commandType = 'order.place',
  int expectedRevision = 0,
  Map<String, Object?> payload = const <String, Object?>{'qty': 2},
}) => CommandEnvelope.create(
  commandId: commandId,
  commandType: commandType,
  resourceId: resourceId,
  expectedRevision: expectedRevision,
  payload: payload,
).fold((CommandEnvelope e) => e, (Failure f) => throw StateError(f.message));

StoredCommandRecord stored(
  CommandEnvelope source, {
  String owner = principalA,
  DateTime? at,
}) => StoredCommandRecord(
  namespace: IdempotencyNamespace.forPrincipal(owner),
  commandId: source.commandId,
  fingerprint: CommandFingerprint.of(source),
  resultRevision: 1,
  recordedAtServerUtc: at ?? DateTime.utc(2026, 9, 9, 10),
);

IdempotencyOutcome evaluate({
  required String actingPrincipal,
  StoredCommandRecord? record,
  CommandEnvelope? incoming,
  AuthorizationDecision authorization = allowed,
}) => evaluateIdempotency(
  authorization: authorization,
  principal: user(actingPrincipal),
  incoming: incoming ?? envelope(),
  stored: record,
);

void main() {
  group('CommandFingerprint', () {
    test('is stable for the same intent', () {
      expect(CommandFingerprint.of(envelope()),
          CommandFingerprint.of(envelope()));
    });

    test('ignores key order in the payload', () {
      expect(
        CommandFingerprint.of(
          envelope(payload: <String, Object?>{'a': 1, 'b': 2}),
        ),
        CommandFingerprint.of(
          envelope(payload: <String, Object?>{'b': 2, 'a': 1}),
        ),
      );
    });

    test('does not ignore list order — it changes the request', () {
      expect(
        CommandFingerprint.of(
          envelope(payload: <String, Object?>{'items': <int>[1, 2]}),
        ),
        isNot(
          CommandFingerprint.of(
            envelope(payload: <String, Object?>{'items': <int>[2, 1]}),
          ),
        ),
      );
    });

    test('changes when the payload, type or revision changes', () {
      final CommandFingerprint base = CommandFingerprint.of(envelope());

      expect(
        CommandFingerprint.of(envelope(payload: <String, Object?>{'qty': 3})),
        isNot(base),
      );
      expect(
        CommandFingerprint.of(envelope(commandType: 'order.cancel')),
        isNot(base),
      );
      expect(CommandFingerprint.of(envelope(expectedRevision: 1)), isNot(base));
    });

    test('does not depend on the command id', () {
      expect(
        CommandFingerprint.of(envelope(commandId: 'cmd_aaaaaaaaaaaaaaaa')),
        CommandFingerprint.of(envelope(commandId: 'cmd_bbbbbbbbbbbbbbbb')),
      );
    });

    test('distinguishes a string from a number of the same text', () {
      expect(
        CommandFingerprint.of(envelope(payload: <String, Object?>{'q': '2'})),
        isNot(
          CommandFingerprint.of(envelope(payload: <String, Object?>{'q': 2})),
        ),
      );
    });

    test('is unaffected by actor-shaped payload keys a client injects', () {
      // A spoofed actor changes the fingerprint only as ordinary payload
      // content would; it cannot move the record into another namespace,
      // because the namespace comes from verified auth, not the envelope.
      final CommandEnvelope spoofed = envelope(
        payload: <String, Object?>{'qty': 2, 'actorId': principalB},
      );

      expect(
        evaluate(
          actingPrincipal: principalA,
          record: stored(spoofed),
          incoming: spoofed,
        ),
        IdempotencyOutcome.replayStoredResult,
      );
      expect(
        evaluate(
          actingPrincipal: principalB,
          record: stored(spoofed),
          incoming: spoofed,
        ),
        IdempotencyOutcome.rejectNamespaceMismatch,
        reason: 'the payload claim did not make B the owner of the record',
      );
    });
  });

  group('namespace isolation', () {
    test('lookup key is (principalId, commandId)', () {
      const IdempotencyNamespace a = IdempotencyNamespace.forPrincipal(
        principalA,
      );

      expect(a, const IdempotencyNamespace.forPrincipal(principalA));
      expect(a, isNot(const IdempotencyNamespace.forPrincipal(principalB)));
    });

    test('a different principal cannot replay a stored result', () {
      // The whole point: B reuses A's command id, honestly or otherwise.
      expect(
        evaluate(actingPrincipal: principalB, record: stored(envelope())),
        IdempotencyOutcome.rejectNamespaceMismatch,
      );
    });

    test('a foreign collision never exposes the stored resultRevision', () {
      final StoredCommandRecord foreign = stored(envelope());
      final IdempotencyOutcome outcome = evaluate(
        actingPrincipal: principalB,
        record: foreign,
      );

      // Rejected outright — not replayStoredResult, so no result of A's is
      // returned to B, and not executeNew, which would hide the collision.
      expect(outcome, IdempotencyOutcome.rejectNamespaceMismatch);
      expect(outcome, isNot(IdempotencyOutcome.replayStoredResult));
    });

    test('a record whose command id does not match is rejected', () {
      expect(
        evaluate(
          actingPrincipal: principalA,
          record: stored(envelope(commandId: 'cmd_zzzzzzzzzzzzzzzz')),
        ),
        IdempotencyOutcome.rejectNamespaceMismatch,
      );
    });
  });

  group('authorization precedes replay', () {
    test('a denied caller cannot replay their own stored result', () {
      // Membership revoked since the original command succeeded.
      expect(
        evaluate(
          actingPrincipal: principalA,
          record: stored(envelope()),
          authorization: denied,
        ),
        IdempotencyOutcome.rejectNotAuthorized,
      );
    });

    test('a denied caller cannot execute a new command either', () {
      expect(
        evaluate(actingPrincipal: principalA, authorization: denied),
        IdempotencyOutcome.rejectNotAuthorized,
      );
    });

    test('authorization is checked before the namespace', () {
      // Denied and foreign: the authorization failure is reported, so a
      // stored record is never even consulted for an unauthorized caller.
      expect(
        evaluate(
          actingPrincipal: principalB,
          record: stored(envelope()),
          authorization: denied,
        ),
        IdempotencyOutcome.rejectNotAuthorized,
      );
    });
  });

  group('replay semantics within one namespace', () {
    test('new command id executes', () {
      expect(
        evaluate(actingPrincipal: principalA),
        IdempotencyOutcome.executeNew,
      );
    });

    test('same principal + same id + same fingerprint replays', () {
      expect(
        evaluate(actingPrincipal: principalA, record: stored(envelope())),
        IdempotencyOutcome.replayStoredResult,
      );
    });

    test('same principal + same id + changed fingerprint is key reuse', () {
      expect(
        evaluate(
          actingPrincipal: principalA,
          record: stored(envelope()),
          incoming: envelope(payload: <String, Object?>{'qty': 99}),
        ),
        IdempotencyOutcome.rejectKeyReuse,
      );
    });

    test('replay identity does not depend on when the retry was sent', () {
      expect(
        evaluate(
          actingPrincipal: principalA,
          record: stored(envelope(), at: DateTime.utc(2020)),
        ),
        IdempotencyOutcome.replayStoredResult,
      );
    });
  });
}
