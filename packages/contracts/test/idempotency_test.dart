import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

import 'support/authz_fixtures.dart';

const String principalA = customerA;
const String principalB = customerB;
const String resourceId = resourceX;

CommandEnvelope envelope({
  String commandId = 'cmd_7Kd93ba-Qz18Xu2P',
  String commandType = 'order.place',
  int expectedRevision = 0,
  String resource = resourceId,
  Map<String, Object?> payload = const <String, Object?>{'qty': 2},
}) => CommandEnvelope.create(
  commandId: commandId,
  commandType: commandType,
  resourceId: resource,
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
  AuthorizationGrant? grant,
}) {
  final CommandEnvelope command = incoming ?? envelope();
  return evaluateIdempotency(
    // A real grant from the real evaluator — it cannot be fabricated.
    grant: grant ?? grantFor(actingPrincipal, command.resourceId),
    principal: user(actingPrincipal),
    incoming: command,
    stored: record,
  );
}

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

  group('authorization evidence cannot be forged or borrowed', () {
    test('a genuine grant permits normal execution', () {
      expect(
        evaluate(actingPrincipal: principalA),
        IdempotencyOutcome.executeNew,
      );
    });

    test("principal A's grant cannot be used for principal B", () {
      // B holds a grant that was issued to A. Even though B is otherwise a
      // legitimate principal, the grant does not cover them.
      expect(
        evaluate(
          actingPrincipal: principalB,
          grant: grantFor(principalA, resourceId),
        ),
        IdempotencyOutcome.rejectAuthorizationMismatch,
      );
    });

    test('a grant for resource X cannot serve a command on resource Y', () {
      final CommandEnvelope onY = envelope(resource: resourceY);

      expect(
        evaluateIdempotency(
          grant: grantFor(principalA, resourceX),
          principal: user(principalA),
          incoming: onY,
        ),
        IdempotencyOutcome.rejectAuthorizationMismatch,
      );
    });

    test('a borrowed grant cannot replay the grant-holder stored result', () {
      // The attack this closes: B presents A's grant to read A's result.
      expect(
        evaluate(
          actingPrincipal: principalB,
          grant: grantFor(principalA, resourceId),
          record: stored(envelope()),
        ),
        IdempotencyOutcome.rejectAuthorizationMismatch,
      );
    });

    test('a denied evaluation yields no grant to pass at all', () {
      // Suspended membership: the evaluator refuses, so `grant` is null and
      // `evaluateIdempotency` simply cannot be called. "Replay while denied"
      // is not an expressible state — which is why there is no
      // `rejectNotAuthorized` outcome any more.
      final AuthorizationDecision decision = decideFor(
        principalA,
        resourceId,
        status: MembershipStatus.suspended,
      );

      expect(decision.allowed, isFalse);
      expect(decision.grant, isNull);
      expect(decision.reason, DenyReason.membershipNotActive);
    });

    test('fresh authorization after revocation yields no grant', () {
      // Renamed by FND-003A-FIX-003. This does NOT test reuse of an old
      // grant; it tests that re-authorizing a revoked actor produces nothing
      // to pass on. That is the whole mechanism by which a revoked actor is
      // stopped — provided the backend actually re-authorizes.
      final AuthorizationDecision decision = decideFor(
        principalA,
        resourceId,
        status: MembershipStatus.revoked,
      );

      expect(decision.grant, isNull);
      expect(decision.reason, DenyReason.membershipNotActive);
      expect(
        () => grantFor(principalA, resourceId),
        returnsNormally,
        reason: 'the same actor while active can still obtain one',
      );
    });

    test('a retained grant is NOT detected as stale by this pure function', () {
      // Documents the boundary honestly rather than implying a guarantee the
      // contract does not provide.
      //
      // A grant obtained while the actor was active still "covers" a later
      // request for the same principal and resource. evaluateIdempotency has
      // no clock, no storage and no freshness context, so it cannot know the
      // membership was revoked in between — and no fake expiry field was
      // added to make this look mechanical.
      final AuthorizationGrant grantWhileActive = grantFor(
        principalA,
        resourceId,
      );

      // Meanwhile the membership is revoked. Fresh evaluation refuses:
      expect(
        decideFor(principalA, resourceId,
                status: MembershipStatus.revoked)
            .grant,
        isNull,
      );

      // But the retained grant still passes the pure check. This is exactly
      // why the contract requires the BACKEND to re-authorize on every
      // request, including replays, and forbids caching or reusing a grant
      // across requests (see docs/contracts/authorization-invariants.md,
      // "request-lifetime boundary", and checklist items R37-R40).
      expect(
        evaluateIdempotency(
          grant: grantWhileActive,
          principal: user(principalA),
          incoming: envelope(),
          stored: stored(envelope()),
        ),
        IdempotencyOutcome.replayStoredResult,
        reason: 'stale-grant prevention is a backend integration duty, '
            'not something this pure function can enforce',
      );
    });

    test('a resource the actor does not own yields no grant', () {
      final AuthorizationDecision decision = evaluateAuthorization(
        AuthorizationRequest(
          permission: Permission.customerViewOwnOrder,
          scope: ownedOrder(resourceId, principalA),
          principal: user(principalB),
          membership: customerMembership(principalB),
        ),
      );

      expect(decision.grant, isNull);
      expect(decision.reason, DenyReason.resourceOwnerMismatch);
    });

    test('the grant records the permission it was issued for', () {
      // Retained for the backend router and for audit. It is deliberately not
      // checked here: no command-type -> permission mapping exists yet.
      expect(
        grantFor(principalA, resourceId).permission,
        Permission.customerViewOwnOrder,
      );
      expect(grantFor(principalA, resourceId).resourceId, resourceId);
      expect(grantFor(principalA, resourceId).principalId, principalA);
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
