import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/rider_assignment_fixtures.dart';

/// A live rider offer at revision 1.
RiderAssignmentFacts offeredSlot() =>
    riderFacts(slotRevision: 1, current: riderAttempt());

/// An accepted rider assignment at revision 2.
RiderAssignmentFacts acceptedSlot() => riderFacts(
  slotRevision: 2,
  current: riderAttempt(state: AssignmentState.accepted, assignee: riderA),
);

void main() {
  group('accept versus expiry race', () {
    test('CASE 1 — accept wins; the later expiry is denied', () {
      final RiderAssignmentTransition accept = allowedRider(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offeredSlot(),
          acting: riderA,
        ),
      );
      expect(accept.toState, AssignmentState.accepted);
      expect(accept.resultingSlotRevision, 2);

      // The worker's expiry arrives afterwards, against the committed state.
      final RiderAssignmentFacts after = applyRider(accept);
      expect(after.activeAcceptedCount, 1);
      expect(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: after,
          expiryDue: true,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
      expect(after.activeAcceptedCount, 1, reason: 'the assignment stands');
    });

    test('CASE 2 — expiry wins; the later accept is denied', () {
      final RiderAssignmentTransition expiry = allowedRider(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: offeredSlot(),
          expiryDue: true,
        ),
      );
      expect(expiry.toState, AssignmentState.expired);
      expect(expiry.resultingSlotRevision, 2);

      final RiderAssignmentFacts after = applyRider(expiry);
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: after,
          acting: riderA,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
      expect(after.activeAcceptedCount, 0, reason: 'no rider holds the work');
    });

    test('the loser holding the pre-race revision is refused', () {
      final RiderAssignmentFacts after = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.acceptRiderAssignment,
            on: offeredSlot(),
            acting: riderA,
          ),
        ),
      );

      // The expiry worker still believes revision 1 is current.
      expect(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: after,
          expectedSlotRevision: 1,
          expiryDue: true,
        ).denial,
        AssignmentDenial.slotRevisionConflict,
      );
    });

    test('exactly one outcome wins in either ordering', () {
      for (final bool acceptFirst in <bool>[true, false]) {
        final RiderAssignmentFacts start = offeredSlot();
        final RiderAssignmentTransition winner = allowedRider(
          acceptFirst
              ? runRider(
                  AssignmentCommand.acceptRiderAssignment,
                  on: start,
                  acting: riderA,
                )
              : runRider(
                  AssignmentCommand.expireRiderOffer,
                  on: start,
                  expiryDue: true,
                ),
        );
        final RiderAssignmentFacts after = applyRider(winner);

        final RiderAssignmentOutcome loser = acceptFirst
            ? runRider(
                AssignmentCommand.expireRiderOffer,
                on: after,
                expiryDue: true,
              )
            : runRider(
                AssignmentCommand.acceptRiderAssignment,
                on: after,
                acting: riderA,
              );

        expect(loser.transition, isNull);
        expect(
          after.activeAcceptedCount,
          acceptFirst ? 1 : 0,
          reason: 'exactly one serialized result',
        );
      }
    });

    test('wall-clock order is not the concurrency control', () {
      // Both commands are evaluated against the same revision; only one can
      // hold it. Nothing in the request carries a timestamp.
      const RiderAssignmentRequest r = RiderAssignmentRequest(
        command: AssignmentCommand.acceptRiderAssignment,
        expectedSlotRevision: 1,
        actingPrincipalId: riderA,
      );
      expect(r.toString(), isNot(contains('DateTime')));
    });
  });

  group('controlled rider reassignment', () {
    test('the current accepted picker revokes with proven-no-custody', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );

      expect(t.fromState, AssignmentState.accepted);
      expect(t.toState, AssignmentState.revoked);
      expect(t.resultingSlotRevision, 3);
      expect(t.eventType, 'rider.assignment.revoked');
    });

    test('unknown custody fails closed', () {
      expect(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          safety: ReassignmentSafety.blockedOrUnknown,
        ).denial,
        AssignmentDenial.reassignmentUnsafe,
      );
    });

    test('safety defaults to blockedOrUnknown', () {
      const RiderAssignmentRequest r = RiderAssignmentRequest(
        command: AssignmentCommand.revokeRiderAssignment,
        expectedSlotRevision: 2,
        actingPrincipalId: pickerA,
      );
      expect(r.reassignmentSafety, ReassignmentSafety.blockedOrUnknown);
      expect(r.reassignmentSafety.permitsRevocation, isFalse);
    });

    test('a picker who is not the current accepted picker cannot revoke', () {
      expect(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          acting: pickerB,
          safety: ReassignmentSafety.provenNoCustody,
        ).denial,
        AssignmentDenial.notCurrentAcceptedPicker,
      );
    });

    test('an agent cannot revoke a rider assignment', () {
      expect(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ).denial,
        AssignmentDenial.notCurrentAcceptedPicker,
      );
    });

    test('a replacement picker may resolve an orphaned rider slot', () {
      // Deliberate asymmetry with accept. Picker A offered and rider A
      // accepted; A was then revoked and picker B took over. B is the order's
      // current authority, and requiring A here would leave the rider slot
      // permanently unresolvable — which is precisely the dependency the
      // backend has to serialize (RA17). Revoke only *withdraws* standing, so
      // it is the safe direction to allow.
      final RiderAssignmentOutcome o = runRider(
        AssignmentCommand.revokeRiderAssignment,
        on: acceptedSlot(),
        acting: pickerB,
        pickerAuthority: pickerSlot(
          pickerId: pickerB,
          assignmentId: pickAsgB,
          generation: 2,
        ),
        safety: ReassignmentSafety.provenNoCustody,
      );

      expect(o.allowed, isTrue);
      // The original picker's authorship is not rewritten.
      expect(o.transition!.source.pickerPrincipalId, pickerA);
      expect(o.transition!.source.pickerAssignmentId, pickAsgA);
    });

    test('revoking clears assigned scope but keeps every identity', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );

      expect(t.scopeEffect.removeFromAssigned, <String>{riderA});
      expect(t.scopeEffect.addToAssigned, isEmpty);
      expect(t.offerRecipientPrincipalId, riderA);
      expect(t.acceptedAssigneePrincipalId, riderA);
      expect(t.source.pickerPrincipalId, pickerA);
    });

    test('an offered assignment cannot be revoked — it declines or expires', () {
      expect(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: offeredSlot(),
          safety: ReassignmentSafety.provenNoCustody,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
    });

    test('revoke has no inventory, financial or custody effect', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
    });

    test('revoke then NEW offer: new id, next generation, history kept', () {
      final RiderAssignmentFacts revoked = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.revokeRiderAssignment,
            on: acceptedSlot(),
            safety: ReassignmentSafety.provenNoCustody,
          ),
        ),
      );
      expect(revoked.slotRevision, 3);
      expect(revoked.attempt!.acceptedAssigneePrincipalId, riderA);

      final RiderAssignmentTransition next = allowedRider(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: revoked,
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
        ),
      );

      expect(next.assignmentId, rideAsgB);
      expect(next.generation, 2);
      expect(next.resultingSlotRevision, 4);
      expect(next.offerRecipientPrincipalId, riderB);
      expect(next.acceptedAssigneePrincipalId, isNull);
    });

    test('reusing the terminal attempt id is denied', () {
      for (final AssignmentState terminal in <AssignmentState>[
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        final bool wasAccepted = terminal == AssignmentState.revoked;
        final RiderAssignmentFacts f = riderFacts(
          slotRevision: wasAccepted ? 3 : 2,
          current: riderAttempt(
            state: terminal,
            assignee: wasAccepted ? riderA : null,
          ),
        );

        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: f,
            newAssignmentId: rideAsgA,
            target: riderEligible(riderB),
          ).denial,
          AssignmentDenial.assignmentIdReuse,
          reason: 'after ${terminal.id}, the old id must not come back',
        );
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: f,
            newAssignmentId: rideAsgB,
            target: riderEligible(riderB),
          ).allowed,
          isTrue,
          reason: 'a genuinely new id is fine after ${terminal.id}',
        );
      }
    });

    test('there is no assignee-replacement or status-patch command', () {
      for (final AssignmentCommand c in AssignmentCommand.values) {
        for (final String forbidden in <String>[
          'set_',
          'status',
          'replace',
          'assignee',
          'patch',
          'force',
        ]) {
          expect(
            c.commandType,
            isNot(contains(forbidden)),
            reason: '${c.commandType} looks like an overwrite',
          );
        }
      }
    });

    test('a picker cannot silently substitute a different rider', () {
      // The only path from one rider to another is revoke + new offer, and
      // the revoke transition carries the original assignee unchanged.
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.revokeRiderAssignment,
          on: acceptedSlot(),
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
      expect(t.acceptedAssigneePrincipalId, riderA);
      expect(t.acceptedAssigneePrincipalId, isNot(riderB));
    });
  });

  group('exactly-one rider invariants', () {
    test('a second offer while one is live is denied', () {
      expect(offeredSlot().liveOfferCount, 1);
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: offeredSlot(),
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
        ).denial,
        AssignmentDenial.liveOfferExists,
      );
    });

    test('an offer while a rider is accepted is denied', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: acceptedSlot(),
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
        ).denial,
        AssignmentDenial.activeAcceptedAssignmentExists,
      );
    });

    test('a second accept creates no second active rider', () {
      final RiderAssignmentFacts accepted = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.acceptRiderAssignment,
            on: offeredSlot(),
            acting: riderA,
          ),
        ),
      );
      expect(accepted.activeAcceptedCount, 1);

      // The same rider again, and a different rider.
      for (final String who in <String>[riderA, riderB]) {
        expect(
          runRider(
            AssignmentCommand.acceptRiderAssignment,
            on: accepted,
            acting: who,
          ).transition,
          isNull,
        );
      }
      expect(accepted.activeAcceptedCount, 1);
    });

    test('counts never exceed one across a full cycle', () {
      RiderAssignmentFacts f = riderFacts();
      expect(f.liveOfferCount, 0);
      expect(f.activeAcceptedCount, 0);

      f = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: f,
            newAssignmentId: rideAsgA,
            target: riderEligible(riderA),
          ),
        ),
      );
      expect(f.liveOfferCount, 1);
      expect(f.activeAcceptedCount, 0);

      f = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.acceptRiderAssignment,
            on: f,
            acting: riderA,
          ),
        ),
      );
      expect(f.liveOfferCount, 0);
      expect(f.activeAcceptedCount, 1);

      f = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.revokeRiderAssignment,
            on: f,
            safety: ReassignmentSafety.provenNoCustody,
          ),
        ),
      );
      expect(f.liveOfferCount, 0);
      expect(f.activeAcceptedCount, 0);

      f = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: f,
            newAssignmentId: rideAsgB,
            target: riderEligible(riderB),
          ),
        ),
      );
      expect(f.liveOfferCount, 1);
      expect(f.activeAcceptedCount, 0);
    });

    test('after decline a new offer takes the next generation', () {
      final RiderAssignmentFacts declined = applyRider(
        allowedRider(
          runRider(
            AssignmentCommand.declineRiderAssignment,
            on: offeredSlot(),
            acting: riderA,
          ),
        ),
      );

      final RiderAssignmentTransition next = allowedRider(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: declined,
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
        ),
      );
      expect(next.generation, 2);
      expect(next.resultingSlotRevision, 3);
    });
  });
}
