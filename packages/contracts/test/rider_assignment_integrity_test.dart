import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/rider_assignment_fixtures.dart';

/// Every rider command that mutates the slot.
const List<AssignmentCommand> mutating = <AssignmentCommand>[
  AssignmentCommand.offerRiderAssignment,
  AssignmentCommand.acceptRiderAssignment,
  AssignmentCommand.declineRiderAssignment,
  AssignmentCommand.expireRiderOffer,
  AssignmentCommand.revokeRiderAssignment,
];

void main() {
  group('stale generation and assignment id', () {
    RiderAssignmentFacts gen2Offered() => riderFacts(
      slotRevision: 3,
      current: riderAttempt(id: rideAsgB, generation: 2),
    );

    test('a command naming an older attempt id mutates nothing', () {
      for (final AssignmentCommand c in <AssignmentCommand>[
        AssignmentCommand.acceptRiderAssignment,
        AssignmentCommand.declineRiderAssignment,
        AssignmentCommand.expireRiderOffer,
        AssignmentCommand.revokeRiderAssignment,
      ]) {
        expect(
          runRider(
            c,
            on: gen2Offered(),
            acting: riderA,
            assignmentId: rideAsgA,
            generation: 2,
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          ).denial,
          AssignmentDenial.assignmentIdMismatch,
          reason: c.commandType,
        );
      }
    });

    test('the worked case: delayed "accept generation 1" after a re-offer', () {
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: gen2Offered(),
          acting: riderA,
          assignmentId: rideAsgA,
          generation: 1,
        ).denial,
        AssignmentDenial.assignmentIdMismatch,
      );
    });

    test('a delayed "decline generation 1" after a re-offer is denied', () {
      expect(
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: gen2Offered(),
          acting: riderA,
          assignmentId: rideAsgA,
          generation: 1,
        ).denial,
        AssignmentDenial.assignmentIdMismatch,
      );
    });

    test('the right id with the wrong generation is denied', () {
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: gen2Offered(),
          acting: riderA,
          assignmentId: rideAsgB,
          generation: 1,
        ).denial,
        AssignmentDenial.generationMismatch,
      );
    });

    test('identity is checked before generation', () {
      // Old id carrying the NEW generation still reports the id mismatch: a
      // command is never applied to whatever is in the slot merely because
      // the order matched.
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: gen2Offered(),
          acting: riderA,
          assignmentId: rideAsgA,
          generation: 2,
        ).denial,
        AssignmentDenial.assignmentIdMismatch,
      );
    });

    test('a stale slot revision is refused for every mutating command', () {
      for (final AssignmentCommand c in mutating) {
        expect(
          runRider(
            c,
            on: gen2Offered(),
            acting: riderA,
            expectedSlotRevision: 1,
            newAssignmentId: rideAsgC,
            target: riderEligible(riderB),
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          ).denial,
          AssignmentDenial.slotRevisionConflict,
          reason: c.commandType,
        );
      }
    });

    test('a command with no attempt present is refused', () {
      for (final AssignmentCommand c in <AssignmentCommand>[
        AssignmentCommand.acceptRiderAssignment,
        AssignmentCommand.declineRiderAssignment,
        AssignmentCommand.expireRiderOffer,
        AssignmentCommand.revokeRiderAssignment,
      ]) {
        expect(
          runRider(
            c,
            on: riderFacts(),
            acting: riderA,
            assignmentId: rideAsgA,
            generation: 1,
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          ).denial,
          AssignmentDenial.noAssignmentAttempt,
          reason: c.commandType,
        );
      }
    });
  });

  group('duplicate and reordered commands produce no effect', () {
    RiderAssignmentFacts inState(AssignmentState s) {
      final bool wasAccepted =
          s == AssignmentState.accepted || s == AssignmentState.revoked;
      final int rev = switch (s) {
        AssignmentState.offered => 1,
        AssignmentState.revoked => 3,
        _ => 2,
      };
      return riderFacts(
        slotRevision: rev,
        current: riderAttempt(
          state: s,
          assignee: wasAccepted ? riderA : null,
        ),
      );
    }

    void denied(String label, RiderAssignmentOutcome o) {
      expect(o.transition, isNull, reason: label);
      expect(o.denial, isNotNull, reason: label);
    }

    test('duplicate accept', () {
      denied(
        'accept twice',
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: inState(AssignmentState.accepted),
          acting: riderA,
        ),
      );
    });

    test('duplicate decline', () {
      denied(
        'decline twice',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: inState(AssignmentState.declined),
          acting: riderA,
        ),
      );
    });

    test('duplicate expiry', () {
      denied(
        'expire twice',
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: inState(AssignmentState.expired),
          expiryDue: true,
        ),
      );
    });

    test('duplicate revoke', () {
      denied(
        'revoke twice',
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: inState(AssignmentState.revoked),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
    });

    test('decline after accept', () {
      denied(
        'decline after accept',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: inState(AssignmentState.accepted),
          acting: riderA,
        ),
      );
    });

    test('accept after decline', () {
      denied(
        'accept after decline',
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: inState(AssignmentState.declined),
          acting: riderA,
        ),
      );
    });

    test('accept after expiry', () {
      denied(
        'accept after expiry',
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: inState(AssignmentState.expired),
          acting: riderA,
        ),
      );
    });

    test('expiry after accept', () {
      denied(
        'expire after accept',
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: inState(AssignmentState.accepted),
          expiryDue: true,
        ),
      );
    });

    test('expiry after decline', () {
      denied(
        'expire after decline',
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: inState(AssignmentState.declined),
          expiryDue: true,
        ),
      );
    });

    test('revoke before accept', () {
      denied(
        'revoke an offer',
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: inState(AssignmentState.offered),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
    });

    test('reordered revoke versus re-offer', () {
      // The re-offer committed first; the revoke arrives against a slot whose
      // attempt is a different one entirely.
      final RiderAssignmentFacts reoffered = riderFacts(
        slotRevision: 3,
        current: riderAttempt(id: rideAsgB, generation: 2),
      );
      denied(
        'revoke naming the old attempt',
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: reoffered,
          assignmentId: rideAsgA,
          generation: 1,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
    });

    test('every denial leaves the facts untouched and effect-free', () {
      final RiderAssignmentFacts before = inState(AssignmentState.declined);
      for (final AssignmentCommand c in mutating) {
        final RiderAssignmentOutcome o = runRider(
          c,
          on: before,
          acting: riderA,
          newAssignmentId: rideAsgA, // reuse — denied
          target: riderEligible(riderB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );
        expect(o.transition, isNull, reason: c.commandType);
      }
      // The evaluator is pure; the facts it was handed are unchanged.
      expect(before.slotRevision, 2);
      expect(before.attempt!.state, AssignmentState.declined);
      expect(before.attempt!.assignmentId, rideAsgA);
    });
  });

  group('rider aggregate integrity', () {
    test('canonical shapes validate', () {
      expect(validateRiderAssignmentAggregate(riderFacts()), isNull);
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(slotRevision: 1, current: riderAttempt()),
        ),
        isNull,
      );
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 2,
            current: riderAttempt(
              state: AssignmentState.accepted,
              assignee: riderA,
            ),
          ),
        ),
        isNull,
      );
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 3,
            current: riderAttempt(
              state: AssignmentState.revoked,
              assignee: riderA,
            ),
          ),
        ),
        isNull,
      );
    });

    test('an offered attempt with an assignee is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 1,
            current: riderAttempt(assignee: riderA),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('an accepted attempt with no assignee is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 2,
            current: riderAttempt(state: AssignmentState.accepted),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('an assignee who was never the recipient is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 2,
            current: riderAttempt(
              state: AssignmentState.accepted,
              assignee: riderB,
            ),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('declined or expired with an assignee is corruption', () {
      for (final AssignmentState s in <AssignmentState>[
        AssignmentState.declined,
        AssignmentState.expired,
      ]) {
        expect(
          validateRiderAssignmentAggregate(
            riderFacts(
              slotRevision: 2,
              current: riderAttempt(state: s, assignee: riderA),
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: s.id,
        );
      }
    });

    test('an empty recipient is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 1,
            current: riderAttempt(recipient: ''),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('a blank timeout policy reference is corruption', () {
      for (final String ref in <String>['', '   ']) {
        expect(
          validateRiderAssignmentAggregate(
            riderFacts(
              slotRevision: 1,
              current: riderAttempt(timeoutRef: ref),
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
        );
      }
    });

    test('a non-opaque assignment id is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(
            slotRevision: 1,
            current: riderAttempt(id: 'short'),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('an attempt at revision zero is corruption', () {
      expect(
        validateRiderAssignmentAggregate(
          riderFacts(current: riderAttempt()),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('a mutated slot with no attempt is corruption', () {
      expect(
        validateRiderAssignmentAggregate(riderFacts(slotRevision: 4)),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('a negative revision is corruption', () {
      expect(
        validateRiderAssignmentAggregate(riderFacts(slotRevision: -1)),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('an empty resource id is corruption', () {
      expect(
        validateRiderAssignmentAggregate(riderFacts(resourceId: '')),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    group('source picker binding', () {
      RiderAssignmentFacts withSource(SourcePickerBinding b, {int rev = 1}) =>
          riderFacts(slotRevision: rev, current: riderAttempt(from: b));

      test('an empty picker principal is corruption', () {
        expect(
          validateRiderAssignmentAggregate(
            withSource(source(pickerId: '')),
          ),
          AssignmentDenial.aggregateInconsistent,
        );
      });

      test('a non-opaque picker assignment id is corruption', () {
        expect(
          validateRiderAssignmentAggregate(
            withSource(source(assignmentId: 'nope')),
          ),
          AssignmentDenial.aggregateInconsistent,
        );
      });

      test('a picker generation below one is corruption', () {
        for (final int g in <int>[0, -3]) {
          expect(
            validateRiderAssignmentAggregate(
              withSource(source(generation: g)),
            ),
            AssignmentDenial.aggregateInconsistent,
            reason: 'generation $g',
          );
        }
      });

      test('source history is required in every terminal state too', () {
        // An attempt that lost its origin can no longer be checked against the
        // current picker assignment, which is the whole protection against a
        // replaced picker inheriting another picker's offer.
        for (final AssignmentState s in AssignmentState.executableInThisSlice) {
          final bool wasAccepted =
              s == AssignmentState.accepted || s == AssignmentState.revoked;
          final int rev = switch (s) {
            AssignmentState.offered => 1,
            AssignmentState.revoked => 3,
            _ => 2,
          };
          expect(
            validateRiderAssignmentAggregate(
              riderFacts(
                slotRevision: rev,
                current: riderAttempt(
                  state: s,
                  assignee: wasAccepted ? riderA : null,
                  from: source(pickerId: ''),
                ),
              ),
            ),
            AssignmentDenial.aggregateInconsistent,
            reason: '${s.id} must retain its source picker',
          );
        }
      });
    });

    test('impossible generation/revision pairs fail closed', () {
      final List<({int gen, int rev, AssignmentState state})> impossible =
          <({int gen, int rev, AssignmentState state})>[
            (gen: 2, rev: 1, state: AssignmentState.offered),
            (gen: 2, rev: 2, state: AssignmentState.offered),
            (gen: 1, rev: 2, state: AssignmentState.offered),
            (gen: 1, rev: 99, state: AssignmentState.offered),
            (gen: 1, rev: 5, state: AssignmentState.accepted),
            (gen: 1, rev: 1, state: AssignmentState.accepted),
            (gen: 1, rev: 2, state: AssignmentState.revoked),
            (gen: 3, rev: 4, state: AssignmentState.offered),
            (gen: 3, rev: 8, state: AssignmentState.offered),
            (gen: 0, rev: 1, state: AssignmentState.offered),
          ];

      for (final ({int gen, int rev, AssignmentState state}) c in impossible) {
        final bool wasAccepted =
            c.state == AssignmentState.accepted ||
            c.state == AssignmentState.revoked;
        expect(
          validateRiderAssignmentAggregate(
            riderFacts(
              slotRevision: c.rev,
              current: riderAttempt(
                generation: c.gen,
                state: c.state,
                assignee: wasAccepted ? riderA : null,
              ),
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: 'gen${c.gen} ${c.state.id} at rev${c.rev} is unreachable',
        );
      }
    });

    test('the validator never repairs', () {
      final RiderAssignmentAttempt bad = riderAttempt(assignee: riderB);
      final RiderAssignmentFacts f = riderFacts(
        slotRevision: 1,
        current: bad,
      );
      expect(
        validateRiderAssignmentAggregate(f),
        AssignmentDenial.aggregateInconsistent,
      );
      expect(f.attempt!.acceptedAssigneePrincipalId, riderB);
      expect(f.attempt!.state, AssignmentState.offered);
      expect(identical(f.attempt, bad), isTrue);
    });

    test('corrupt facts produce no transition for any command', () {
      final RiderAssignmentFacts corrupt = riderFacts(
        slotRevision: 1,
        current: riderAttempt(assignee: riderA),
      );
      for (final AssignmentCommand c in mutating) {
        final RiderAssignmentOutcome o = runRider(
          c,
          on: corrupt,
          acting: riderA,
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );
        expect(o.denial, AssignmentDenial.aggregateInconsistent, reason: c.commandType);
        expect(o.transition, isNull, reason: c.commandType);
      }
    });

    test('an attempt already in completed fails closed', () {
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: riderFacts(
            slotRevision: 2,
            current: riderAttempt(state: AssignmentState.completed),
          ),
          acting: riderA,
        ).denial,
        AssignmentDenial.unknownTransition,
      );
    });
  });

  group('transition closure — every rider success validates', () {
    // The invariant this group exists for:
    //
    //   applyRider(successful transition)
    //     -> validateRiderAssignmentAggregate == null
    //
    // Testing `reachableSlotRevisionRange` directly would only prove the
    // helper agrees with itself. This ties the actual evaluator output to the
    // validator, so a change to either that drifts from the other fails here.
    //
    // Every fact below comes from a real evaluator transition — nothing is
    // hand-fabricated, because a fabricated pair could accidentally satisfy a
    // rule the lifecycle no longer produces.
    //
    // `applyRider` is TEST INFRASTRUCTURE. It is not evidence that real
    // persistence is correct: the canonical record, scope projection, outbox
    // event and revision must commit in one transaction (RA14), and stored
    // aggregates must be reconciled (RA15). Both remain NOT RUN.

    RiderAssignmentFacts closes(String label, RiderAssignmentOutcome outcome) {
      final RiderAssignmentTransition? t = outcome.transition;
      expect(
        t,
        isNotNull,
        reason: '$label should be allowed, got ${outcome.denial?.name}',
      );
      final RiderAssignmentFacts next = applyRider(t!);
      expect(
        validateRiderAssignmentAggregate(next),
        isNull,
        reason: '$label produced gen=${t.generation} rev='
            '${t.resultingSlotRevision} state=${t.toState.id}, which the '
            'rider aggregate validator rejects — reachableSlotRevisionRange '
            'and the rider evaluator have drifted apart',
      );
      return next;
    }

    RiderAssignmentOutcome offerOn(
      RiderAssignmentFacts f,
      String newId,
      String target,
    ) => runRider(
      AssignmentCommand.offerRiderAssignment,
      on: f,
      newAssignmentId: newId,
      target: riderEligible(target),
    );

    RiderAssignmentOutcome acceptOn(RiderAssignmentFacts f, String who) =>
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: f,
          acting: who,
        );

    RiderAssignmentOutcome revokeOn(RiderAssignmentFacts f) => runRider(
      AssignmentCommand.revokeRiderAssignment,
      on: f,
      safety: ReassignmentSafety.provenNoCustody,
    );

    test('initial offer closes', () {
      final RiderAssignmentFacts f = closes(
        'initial offer',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      expect(f.attempt!.generation, 1);
      expect(f.slotRevision, 1);
      expect(f.attempt!.state, AssignmentState.offered);
    });

    test('accept closes', () {
      final RiderAssignmentFacts offered = closes(
        'offer',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      final RiderAssignmentFacts accepted = closes(
        'accept',
        acceptOn(offered, riderA),
      );
      expect(accepted.slotRevision, 2);
      expect(accepted.attempt!.state, AssignmentState.accepted);
    });

    test('decline closes', () {
      final RiderAssignmentFacts offered = closes(
        'offer',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      final RiderAssignmentFacts declined = closes(
        'decline',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: offered,
          acting: riderA,
        ),
      );
      expect(declined.slotRevision, 2);
    });

    test('expiry closes', () {
      final RiderAssignmentFacts offered = closes(
        'offer',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      final RiderAssignmentFacts expired = closes(
        'expire',
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: offered,
          expiryDue: true,
        ),
      );
      expect(expired.slotRevision, 2);
    });

    test('revoke closes', () {
      RiderAssignmentFacts f = closes(
        'offer',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes('accept', acceptOn(f, riderA));
      f = closes('revoke', revokeOn(f));
      expect(f.slotRevision, 3);
      expect(f.attempt!.state, AssignmentState.revoked);
    });

    test('re-offer after decline closes (previous attempt cost 2)', () {
      RiderAssignmentFacts f = closes(
        'offer g1',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes(
        'decline g1',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: f,
          acting: riderA,
        ),
      );
      f = closes('offer g2', offerOn(f, rideAsgB, riderB));
      expect(f.attempt!.generation, 2);
      expect(f.slotRevision, 3);
    });

    test('re-offer after expiry closes (previous attempt cost 2)', () {
      RiderAssignmentFacts f = closes(
        'offer g1',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes(
        'expire g1',
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: f,
          expiryDue: true,
        ),
      );
      f = closes('offer g2', offerOn(f, rideAsgB, riderB));
      expect(f.attempt!.generation, 2);
      expect(f.slotRevision, 3);
    });

    test('re-offer after revoke closes (previous attempt cost 3)', () {
      RiderAssignmentFacts f = closes(
        'offer g1',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes('accept g1', acceptOn(f, riderA));
      f = closes('revoke g1', revokeOn(f));
      f = closes('offer g2', offerOn(f, rideAsgB, riderB));
      expect(f.attempt!.generation, 2);
      expect(f.slotRevision, 4);
    });

    test('generation 3 at the MINIMUM offered revision (5) closes', () {
      // g1 declined (2 mutations) + g2 declined (2) + the g3 offer = 5.
      RiderAssignmentFacts f = closes(
        'offer g1',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes(
        'decline g1',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: f,
          acting: riderA,
        ),
      );
      f = closes('offer g2', offerOn(f, rideAsgB, riderB));
      f = closes(
        'decline g2',
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: f,
          acting: riderB,
        ),
      );
      f = closes('offer g3', offerOn(f, rideAsgC, riderA));

      expect(f.attempt!.generation, 3);
      expect(f.slotRevision, 5, reason: '2 + 2 + 1 mutations — the minimum');
      expect(
        reachableSlotRevisionRange(3, AssignmentState.offered)!.min,
        5,
      );
    });

    test('generation 3 at the MAXIMUM offered revision (7) closes', () {
      // g1 accepted then revoked (3 mutations) + g2 the same (3) + the g3
      // offer = 7. This is the most expensive history the lifecycle can
      // produce, and it is built from real transitions rather than asserted.
      RiderAssignmentFacts f = closes(
        'offer g1',
        offerOn(riderFacts(), rideAsgA, riderA),
      );
      f = closes('accept g1', acceptOn(f, riderA));
      f = closes('revoke g1', revokeOn(f));
      f = closes('offer g2', offerOn(f, rideAsgB, riderB));
      f = closes('accept g2', acceptOn(f, riderB));
      f = closes('revoke g2', revokeOn(f));
      f = closes('offer g3', offerOn(f, rideAsgC, riderA));

      expect(f.attempt!.generation, 3);
      expect(f.slotRevision, 7, reason: '3 + 3 + 1 mutations — the maximum');
      expect(
        reachableSlotRevisionRange(3, AssignmentState.offered)!.max,
        7,
      );
    });

    test('every executable RIDER transition kind is represented above', () {
      // Guards against a future rider command being added without closure
      // coverage. Scoped to the rider role, so a new rider command cannot be
      // absorbed by the picker suite's guard and escape.
      expect(
        AssignmentCommand.forRole(AssignmentRole.rider),
        <AssignmentCommand>{
          AssignmentCommand.offerRiderAssignment,
          AssignmentCommand.acceptRiderAssignment,
          AssignmentCommand.declineRiderAssignment,
          AssignmentCommand.expireRiderOffer,
          AssignmentCommand.revokeRiderAssignment,
        },
        reason: 'a new rider command needs a transition-closure case here',
      );
    });
  });

  group('command and state coverage guards', () {
    test('every executable state has a reachable revision range', () {
      for (final AssignmentState s in AssignmentState.executableInThisSlice) {
        expect(
          reachableSlotRevisionRange(1, s),
          isNotNull,
          reason: 'No reachable slot-revision range is defined for '
              '"${s.id}". If a state becomes executable, '
              'reachableSlotRevisionRange and transition-cost tests must be '
              'updated in the same contract change — otherwise every '
              'aggregate in that state fails closed as inconsistent.',
        );
      }
    });

    test('completed stays non-executable and has no invented cost', () {
      // B3-C2: when rider `completed` becomes executable, FND-003B3 must
      // update the shared revision model if required and prove every new rider
      // transition closes over aggregate validation. NOT RUN / FUTURE.
      expect(
        AssignmentState.executableInThisSlice
            .contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed),
        isNull,
        reason: 'its mutation cost is unknown until FND-003B3 defines it; '
            'guessing one would corrupt the model',
      );
    });

    test('no rider transition can produce completed', () {
      final Set<AssignmentState> reachable = <AssignmentState>{};
      for (final AssignmentState s in AssignmentState.executableInThisSlice) {
        final bool wasAccepted =
            s == AssignmentState.accepted || s == AssignmentState.revoked;
        final int rev = switch (s) {
          AssignmentState.offered => 1,
          AssignmentState.revoked => 3,
          _ => 2,
        };
        for (final AssignmentCommand c in mutating) {
          final RiderAssignmentOutcome o = runRider(
            c,
            on: riderFacts(
              slotRevision: rev,
              current: riderAttempt(
                state: s,
                assignee: wasAccepted ? riderA : null,
              ),
            ),
            acting: s == AssignmentState.offered ? riderA : pickerA,
            newAssignmentId: rideAsgB,
            target: riderEligible(riderB),
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          );
          if (o.transition != null) {
            reachable.add(o.transition!.toState);
          }
        }
      }
      expect(reachable.contains(AssignmentState.completed), isFalse);
      expect(reachable, isNotEmpty, reason: 'the sweep must exercise something');
    });

    test('the rider event surface is exactly five rider ids', () {
      expect(AssignmentEventType.rider, <String>[
        'rider.assignment.offered',
        'rider.assignment.accepted',
        'rider.assignment.declined',
        'rider.assignment.expired',
        'rider.assignment.revoked',
      ]);
      for (final String e in AssignmentEventType.rider) {
        expect(e, startsWith('rider.'));
      }
      expect(AssignmentEventType.all.length, 10);
      expect(AssignmentEventType.all.toSet().length, 10);
    });

    test('the rider evaluator refuses every picker command', () {
      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.picker)) {
        expect(
          runRider(
            c,
            on: riderFacts(slotRevision: 1, current: riderAttempt()),
            acting: riderA,
            newAssignmentId: rideAsgB,
            target: riderEligible(riderB),
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          ).denial,
          AssignmentDenial.unknownTransition,
          reason: '${c.commandType} must not be evaluated as rider work',
        );
      }
    });

    test('no numeric timeout exists anywhere in the rider contract', () {
      // A source-level check, because the hazard is a duration being written
      // into the contract rather than resolved from a versioned policy.
      final String src =
          File('lib/src/rider_assignment.dart').readAsStringSync();
      for (final String forbidden in <String>[
        'Duration(',
        'inSeconds',
        'inMinutes',
        'DateTime',
      ]) {
        expect(
          src,
          isNot(contains(forbidden)),
          reason: '$forbidden would put a clock or a duration in the contract',
        );
      }
      expect(src, contains('timeoutPolicyRef'));
    });
  });

  group('permissions and governance', () {
    PermissionRule rule(Permission p) => permissionMatrix[p]!;

    test('picker.assignment.offer_rider is picker-only and scoped', () {
      final PermissionRule r = rule(Permission.pickerOfferRiderAssignment);
      expect(Permission.pickerOfferRiderAssignment.id,
          'picker.assignment.offer_rider');
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.picker});
      expect(r.scopes, <ScopeRequirement>{
        ScopeRequirement.assignedResource,
        ScopeRequirement.ownRegion,
      });
      expect(r.acceptableStatuses, <MembershipStatus>{
        MembershipStatus.active,
      });
    });

    test('picker.assignment.revoke_rider is picker-only, scoped, reasoned', () {
      final PermissionRule r = rule(Permission.pickerRevokeRiderAssignment);
      expect(Permission.pickerRevokeRiderAssignment.id,
          'picker.assignment.revoke_rider');
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.picker});
      expect(r.scopes, <ScopeRequirement>{
        ScopeRequirement.assignedResource,
        ScopeRequirement.ownRegion,
      });
      expect(r.reasonRequired, isTrue);
      expect(r.acceptableStatuses, <MembershipStatus>{
        MembershipStatus.active,
      });
    });

    test('neither new permission is granted to any other role', () {
      for (final Permission p in <Permission>[
        Permission.pickerOfferRiderAssignment,
        Permission.pickerRevokeRiderAssignment,
      ]) {
        for (final CommerceRole r in <CommerceRole>[
          CommerceRole.admin,
          CommerceRole.agent,
          CommerceRole.rider,
          CommerceRole.customer,
        ]) {
          expect(
            rule(p).eligibleRoles.contains(r),
            isFalse,
            reason: '${p.id} must not be held by ${r.name}',
          );
        }
      }
    });

    test('rider accept and decline keep their FND-003A rules', () {
      for (final Permission p in <Permission>[
        Permission.riderAcceptAssignment,
        Permission.riderDeclineAssignment,
      ]) {
        expect(rule(p).eligibleRoles, <CommerceRole>{CommerceRole.rider});
        expect(rule(p).scopes, <ScopeRequirement>{
          ScopeRequirement.offeredResource,
          ScopeRequirement.ownRegion,
        });
      }
    });

    test('no B2B rider command maps to agent.assignment.offer_rider', () {
      // The future direct shop-to-rider pickup is a different flow with a
      // different custody source. Routing this one through it would let a flow
      // with no picker reuse a rule written for a picker-originated offer.
      for (final AssignmentCommand c in AssignmentCommand.values) {
        expect(
          c.requiredPermission,
          isNot(Permission.agentOfferRiderAssignment),
          reason: '${c.commandType} must not use the agent rider-offer rule',
        );
      }
      expect(
        AssignmentCommand.offerRiderAssignment.requiredPermission,
        Permission.pickerOfferRiderAssignment,
      );
    });

    test('agent.assignment.offer_rider still exists but is not executable', () {
      // Not deleted, not renamed — it stays a stable identifier reserved for
      // the future direct pickup flow.
      expect(Permission.byId('agent.assignment.offer_rider'),
          Permission.agentOfferRiderAssignment);
      expect(permissionMatrix.containsKey(Permission.agentOfferRiderAssignment),
          isTrue);
      expect(
        AssignmentCommand.values
            .where((AssignmentCommand c) =>
                c.requiredPermission == Permission.agentOfferRiderAssignment)
            .length,
        0,
      );
    });

    test('rider commands map to exactly the intended permissions', () {
      expect(AssignmentCommand.acceptRiderAssignment.requiredPermission,
          Permission.riderAcceptAssignment);
      expect(AssignmentCommand.declineRiderAssignment.requiredPermission,
          Permission.riderDeclineAssignment);
      expect(AssignmentCommand.revokeRiderAssignment.requiredPermission,
          Permission.pickerRevokeRiderAssignment);
      expect(AssignmentCommand.expireRiderOffer.requiredPermission, isNull);
    });

    test('the reserved admin rider override stays unimplemented', () {
      // ADR-0007. Naming it reserves the identifier; it must not exist as a
      // permission, a matrix row or a command.
      const String reserved = 'admin.assignment.override_rider';
      expect(Permission.byId(reserved), isNull);
      expect(
        Permission.values.where((Permission p) => p.id == reserved).length,
        0,
      );
      expect(
        permissionMatrix.keys.where((Permission p) => p.id == reserved).length,
        0,
      );
      expect(AssignmentCommand.byCommandType(reserved), isNull);
      for (final AssignmentCommand c in AssignmentCommand.values) {
        expect(c.commandType, isNot(contains('override')));
      }
    });

    test('no admin permission touches rider assignment lifecycle', () {
      for (final Permission p in Permission.values) {
        if (!p.id.startsWith('admin.')) {
          continue;
        }
        expect(
          p.id,
          isNot(contains('assignment')),
          reason: '${p.id} would be an unaudited assignment override',
        );
      }
    });
  });
}
