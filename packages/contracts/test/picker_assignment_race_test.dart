import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/picker_assignment_fixtures.dart';

PickerAssignmentFacts offeredSlot() => facts(slotRevision: 1, current: attempt());

PickerAssignmentFacts acceptedSlot() => facts(
  slotRevision: 2,
  current: attempt(state: AssignmentState.accepted, assignee: pickerA),
);

void main() {
  group('offer expiry', () {
    test('a due offer expires and releases offered scope', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.expirePickerOffer,
          on: offeredSlot(),
          expiryDue: true,
        ),
      );

      expect(t.toState, AssignmentState.expired);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.scopeEffect.removeFromOffered, <String>{pickerA});
      expect(t.scopeEffect.addToAssigned, isEmpty);
      expect(t.eventType, AssignmentEventType.pickerExpired);
    });

    test('expiry that is not due is refused — no early expiry', () {
      final PickerAssignmentOutcome o = run(
        AssignmentCommand.expirePickerOffer,
        on: offeredSlot(),
      );

      expect(o.transition, isNull);
      expect(o.denial, AssignmentDenial.expiryNotDue);
    });

    test('expiryDue defaults to false, so expiry fails closed', () {
      const PickerAssignmentRequest r = PickerAssignmentRequest(
        command: AssignmentCommand.expirePickerOffer,
        expectedSlotRevision: 1,
        actingPrincipalId: pickerA,
      );

      expect(r.expiryDue, isFalse);
    });

    test('expiry is worker-driven and borrows no human permission', () {
      expect(AssignmentCommand.expirePickerOffer.isWorkerDriven, isTrue);
      expect(AssignmentCommand.expirePickerOffer.requiredPermission, isNull);
      // Every other PICKER command carries a permission. Scoped to the picker
      // role: the rider lifecycle has its own worker-driven expiry, and its
      // own suite asserts the same property for rider commands.
      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.picker)) {
        if (c != AssignmentCommand.expirePickerOffer) {
          expect(c.requiredPermission, isNotNull, reason: c.commandType);
        }
      }
    });

    test('an accepted assignment cannot be expired', () {
      expect(
        run(
          AssignmentCommand.expirePickerOffer,
          on: acceptedSlot(),
          expiryDue: true,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
    });
  });

  group('accept versus expiry race', () {
    test('CASE 1 — accept wins; later expiry is denied', () {
      final PickerAssignmentTransition accept = allowed(
        run(AssignmentCommand.acceptPickerAssignment, on: offeredSlot()),
      );
      expect(accept.toState, AssignmentState.accepted);

      final PickerAssignmentFacts after = apply(accept);
      final PickerAssignmentOutcome lateExpiry = run(
        AssignmentCommand.expirePickerOffer,
        on: after,
        expiryDue: true,
      );

      expect(lateExpiry.transition, isNull);
      expect(lateExpiry.denial, AssignmentDenial.wrongAssignmentState);
      expect(after.attempt!.state, AssignmentState.accepted);
      expect(after.activeAcceptedCount, 1);
    });

    test('CASE 2 — expiry wins; later accept is denied', () {
      final PickerAssignmentTransition expiry = allowed(
        run(
          AssignmentCommand.expirePickerOffer,
          on: offeredSlot(),
          expiryDue: true,
        ),
      );

      final PickerAssignmentFacts after = apply(expiry);
      final PickerAssignmentOutcome lateAccept = run(
        AssignmentCommand.acceptPickerAssignment,
        on: after,
      );

      expect(lateAccept.transition, isNull);
      expect(lateAccept.denial, AssignmentDenial.wrongAssignmentState);
      expect(after.activeAcceptedCount, 0);
    });

    test('the loser using a stale slot revision is refused', () {
      final PickerAssignmentTransition accept = allowed(
        run(AssignmentCommand.acceptPickerAssignment, on: offeredSlot()),
      );
      final PickerAssignmentFacts after = apply(accept);

      // Worker still holding the pre-race revision.
      expect(
        run(
          AssignmentCommand.expirePickerOffer,
          on: after,
          expectedSlotRevision: 1,
          expiryDue: true,
        ).denial,
        AssignmentDenial.slotRevisionConflict,
      );
    });

    test('exactly one outcome wins in either ordering', () {
      for (final bool acceptFirst in <bool>[true, false]) {
        final PickerAssignmentFacts start = offeredSlot();
        final PickerAssignmentTransition first = allowed(
          acceptFirst
              ? run(AssignmentCommand.acceptPickerAssignment, on: start)
              : run(
                  AssignmentCommand.expirePickerOffer,
                  on: start,
                  expiryDue: true,
                ),
        );
        final PickerAssignmentFacts after = apply(first);
        final PickerAssignmentOutcome second = acceptFirst
            ? run(
                AssignmentCommand.expirePickerOffer,
                on: after,
                expiryDue: true,
              )
            : run(AssignmentCommand.acceptPickerAssignment, on: after);

        expect(second.transition, isNull, reason: 'second must not apply');
        expect(after.activeAcceptedCount, acceptFirst ? 1 : 0);
      }
    });
  });

  group('controlled reassignment', () {
    test('revoke requires proven-no-custody', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.revokePickerAssignment,
          on: acceptedSlot(),
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );

      expect(t.fromState, AssignmentState.accepted);
      expect(t.toState, AssignmentState.revoked);
      expect(t.eventType, AssignmentEventType.pickerRevoked);
    });

    test('unknown custody safety fails closed', () {
      final PickerAssignmentOutcome o = run(
        AssignmentCommand.revokePickerAssignment,
        on: acceptedSlot(),
        acting: agentId,
        safety: ReassignmentSafety.blockedOrUnknown,
      );

      expect(o.transition, isNull);
      expect(o.denial, AssignmentDenial.reassignmentUnsafe);
    });

    test('safety defaults to blockedOrUnknown', () {
      const PickerAssignmentRequest r = PickerAssignmentRequest(
        command: AssignmentCommand.revokePickerAssignment,
        expectedSlotRevision: 2,
        actingPrincipalId: agentId,
      );

      expect(r.reassignmentSafety, ReassignmentSafety.blockedOrUnknown);
      expect(r.reassignmentSafety.permitsRevocation, isFalse);
      expect(ReassignmentSafety.provenNoCustody.permitsRevocation, isTrue);
    });

    test('revoking clears assigned scope but keeps both identities', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.revokePickerAssignment,
          on: acceptedSlot(),
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );

      expect(t.scopeEffect.removeFromAssigned, <String>{pickerA});
      expect(t.scopeEffect.addToOffered, isEmpty);
      // History is preserved, not erased.
      expect(t.offerRecipientPrincipalId, pickerA);
      expect(t.acceptedAssigneePrincipalId, pickerA);
    });

    test('an offered assignment cannot be revoked — it declines or expires', () {
      expect(
        run(
          AssignmentCommand.revokePickerAssignment,
          on: offeredSlot(),
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
    });

    test('revoke then NEW offer: new id, next generation, history kept', () {
      final PickerAssignmentTransition revoke = allowed(
        run(
          AssignmentCommand.revokePickerAssignment,
          on: acceptedSlot(),
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
      final PickerAssignmentFacts afterRevoke = apply(revoke);

      expect(afterRevoke.activeAcceptedCount, 0);
      // The revoked attempt still records who held it.
      expect(afterRevoke.attempt!.acceptedAssigneePrincipalId, pickerA);

      final PickerAssignmentTransition reoffer = allowed(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: afterRevoke,
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
        ),
      );

      expect(reoffer.assignmentId, assignB);
      expect(reoffer.assignmentId, isNot(assignA));
      expect(reoffer.generation, 2);
      expect(reoffer.offerRecipientPrincipalId, pickerB);
      expect(reoffer.acceptedAssigneePrincipalId, isNull);
      expect(reoffer.eventType, AssignmentEventType.pickerOffered);
    });

    test('there is no assignee-replacement or status-patch command', () {
      for (final AssignmentCommand c in AssignmentCommand.values) {
        expect(c.commandType, isNot(contains('set_')));
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('replace')));
        expect(c.commandType, isNot(contains('assignee')));
      }
    });
  });

  group('exactly-one invariants', () {
    test('a second offer while one is live is denied', () {
      expect(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: offeredSlot(),
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
        ).denial,
        AssignmentDenial.liveOfferExists,
      );
    });

    test('an offer while an accepted assignment exists is denied', () {
      expect(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: acceptedSlot(),
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
        ).denial,
        AssignmentDenial.activeAcceptedAssignmentExists,
      );
    });

    test('activeAcceptedCount never exceeds one across a full cycle', () {
      PickerAssignmentFacts f = facts();
      expect(f.activeAcceptedCount, 0);

      f = apply(
        allowed(
          run(
            AssignmentCommand.offerPickerAssignment,
            on: f,
            acting: agentId,
            newAssignmentId: assignA,
            target: eligible(pickerA),
          ),
        ),
      );
      expect(f.activeAcceptedCount, 0, reason: 'offered is not accepted');

      f = apply(
        allowed(run(AssignmentCommand.acceptPickerAssignment, on: f)),
      );
      expect(f.activeAcceptedCount, 1);

      // A second accept cannot create another.
      expect(
        run(AssignmentCommand.acceptPickerAssignment, on: f).transition,
        isNull,
      );
      expect(f.activeAcceptedCount, 1);

      f = apply(
        allowed(
          run(
            AssignmentCommand.revokePickerAssignment,
            on: f,
            acting: agentId,
            safety: ReassignmentSafety.provenNoCustody,
          ),
        ),
      );
      expect(f.activeAcceptedCount, 0);
    });

    test('after decline a new offer may be made with the next generation', () {
      final PickerAssignmentFacts declined = apply(
        allowed(
          run(AssignmentCommand.declinePickerAssignment, on: offeredSlot()),
        ),
      );

      final PickerAssignmentTransition reoffer = allowed(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: declined,
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
        ),
      );

      expect(reoffer.generation, 2);
      expect(reoffer.assignmentId, assignB);
    });
  });
}
