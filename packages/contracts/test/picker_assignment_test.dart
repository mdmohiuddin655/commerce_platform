import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/picker_assignment_fixtures.dart';

void main() {
  group('offer', () {
    test('agent offers picker work on an accepted order', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerA),
        ),
      );

      expect(t.toState, AssignmentState.offered);
      expect(t.assignmentId, assignA);
      expect(t.generation, 1);
      expect(t.resultingSlotRevision, 1);
      expect(t.offerRecipientPrincipalId, pickerA);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.eventType, AssignmentEventType.pickerOffered);
    });

    test('offering adds offered scope and NOT assigned scope', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerA),
        ),
      );

      expect(t.scopeEffect.addToOffered, <String>{pickerA});
      expect(t.scopeEffect.addToAssigned, isEmpty);
    });

    test('offer touches no stock, money or custody', () {
      final PickerAssignmentTransition t = allowed(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerA),
        ),
      );

      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.financialClassification, FinancialClassification.noneInThisSlice);
      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
    });

    test('offer is permitted from accepted, preparing and ready only', () {
      for (final OrderState s in OrderState.values) {
        final PickerAssignmentOutcome o = run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(orderState: s),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerA),
        );

        if (assignmentEligibleOrderStates.contains(s)) {
          expect(o.allowed, isTrue, reason: 'should allow from ${s.id}');
        } else {
          expect(o.allowed, isFalse, reason: 'must deny from ${s.id}');
          expect(
            o.denial,
            AssignmentDenial.orderNotAssignmentEligible,
            reason: s.id,
          );
        }
      }
    });

    test('placed, rejected, cancelled and future states are ineligible', () {
      expect(
        assignmentEligibleOrderStates,
        <OrderState>{
          OrderState.accepted,
          OrderState.preparing,
          OrderState.ready,
        },
      );
      for (final OrderState s in <OrderState>[
        OrderState.placed,
        OrderState.rejected,
        OrderState.cancelled,
        OrderState.inDelivery,
        OrderState.delivered,
      ]) {
        expect(assignmentEligibleOrderStates.contains(s), isFalse, reason: s.id);
      }
    });

    test('a non-opaque or missing assignment id is refused', () {
      for (final String? bad in <String?>[null, '', '42', 'short']) {
        expect(
          run(
            AssignmentCommand.offerPickerAssignment,
            on: facts(),
            acting: agentId,
            newAssignmentId: bad,
            target: eligible(pickerA),
          ).denial,
          AssignmentDenial.assignmentIdInvalid,
          reason: 'id "$bad"',
        );
      }
    });

    test('a missing or blank timeout policy reference is refused', () {
      for (final String? bad in <String?>[null, '', '   ']) {
        expect(
          run(
            AssignmentCommand.offerPickerAssignment,
            on: facts(),
            acting: agentId,
            newAssignmentId: assignA,
            target: eligible(pickerA),
            timeoutRef: bad,
          ).denial,
          AssignmentDenial.timeoutPolicyMissing,
        );
      }
    });

    test('no numeric timeout duration exists in the contract', () {
      // The offer carries a policy *reference*; the backend resolves it against
      // server time. Nothing here encodes 30s, 5m or any other guess.
      final PickerAssignmentAttempt a = attempt();
      expect(a.timeoutPolicyRef, policyRef);
      expect(a.timeoutPolicyRef, isNot(matches(r'^\d+$')));
    });
  });

  group('target eligibility', () {
    PickerAssignmentOutcome offerTo(PickerEligibility target) => run(
      AssignmentCommand.offerPickerAssignment,
      on: facts(),
      acting: agentId,
      newAssignmentId: assignA,
      target: target,
    );

    test('a rider cannot receive picker work', () {
      expect(
        offerTo(eligible(pickerA, role: CommerceRole.rider)).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    test('a customer or agent cannot receive picker work', () {
      for (final CommerceRole r in <CommerceRole>[
        CommerceRole.customer,
        CommerceRole.agent,
        CommerceRole.admin,
      ]) {
        expect(
          offerTo(eligible(pickerA, role: r)).denial,
          AssignmentDenial.targetNotEligible,
          reason: r.id,
        );
      }
    });

    test('a non-active membership cannot receive an offer', () {
      for (final MembershipStatus s in <MembershipStatus>[
        MembershipStatus.pending,
        MembershipStatus.suspended,
        MembershipStatus.revoked,
      ]) {
        expect(
          offerTo(eligible(pickerA, status: s)).denial,
          AssignmentDenial.targetNotEligible,
          reason: s.id,
        );
      }
    });

    test('a non-human principal cannot receive an offer', () {
      expect(
        offerTo(eligible(pickerA, human: false)).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    test('a membership naming someone else grants nothing', () {
      expect(
        offerTo(eligible(pickerA, membershipOf: pickerB)).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    // ---------------------------------------------------------------------
    // Principal identity. Added by FND-003B2B-FIX-001: qualification checked
    // presence and equality but never the canonical opaque-id rule, so a
    // malformed trusted target could produce a successful transition whose
    // resulting aggregate the validator refuses.
    // ---------------------------------------------------------------------

    const Map<String, String> malformedIds = <String, String>{
      'empty': '',
      'too short': 'usr_short',
      'overlong': 'usr_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'illegal character': r'usr_bad!principal01',
      'sequential-looking': '1234567890123456',
    };

    test('a malformed target principal id cannot qualify', () {
      malformedIds.forEach((String label, String id) {
        expect(
          isValidOpaqueId(id),
          isFalse,
          reason: '$label should be rejected by the canonical id rule',
        );
        expect(
          eligible(id).qualifiesAsActivePicker,
          isFalse,
          reason: '$label must not qualify',
        );
      });
    });

    test('a malformed target principal id produces no transition', () {
      malformedIds.forEach((String label, String id) {
        final PickerAssignmentOutcome o = offerTo(eligible(id));
        expect(o.denial, AssignmentDenial.targetNotEligible, reason: label);
        expect(o.transition, isNull, reason: label);
      });
    });

    test('a malformed membership principal id cannot qualify', () {
      for (final String bad in <String>['', 'usr_short', '1234567890123456']) {
        final PickerAssignmentOutcome o =
            offerTo(eligible(pickerA, membershipOf: bad));
        expect(o.denial, AssignmentDenial.targetNotEligible, reason: bad);
        expect(o.transition, isNull, reason: bad);
      }
    });

    test('a well-formed active target still qualifies', () {
      expect(eligible(pickerA).qualifiesAsActivePicker, isTrue);
      expect(offerTo(eligible(pickerA)).allowed, isTrue);
    });

    test('a missing target is refused', () {
      expect(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(),
          acting: agentId,
          newAssignmentId: assignA,
        ).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    test('region must match, and absence is not a match', () {
      expect(
        offerTo(eligible(pickerA, regionId: 'chattogram')).denial,
        AssignmentDenial.regionMismatch,
      );
      expect(
        offerTo(eligible(pickerA, regionId: null)).denial,
        AssignmentDenial.regionMismatch,
      );
      expect(
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(orderRegion: null),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerA),
        ).denial,
        AssignmentDenial.regionMismatch,
      );
    });
  });

  group('accept', () {
    PickerAssignmentFacts offered() =>
        facts(slotRevision: 1, current: attempt());

    test('the offer recipient accepts', () {
      final PickerAssignmentTransition t = allowed(
        run(AssignmentCommand.acceptPickerAssignment, on: offered()),
      );

      expect(t.fromState, AssignmentState.offered);
      expect(t.toState, AssignmentState.accepted);
      expect(t.acceptedAssigneePrincipalId, pickerA);
      expect(t.offerRecipientPrincipalId, pickerA);
      expect(t.resultingSlotRevision, 2);
      expect(t.eventType, AssignmentEventType.pickerAccepted);
    });

    test('accepting moves offered scope to assigned scope', () {
      final PickerAssignmentTransition t = allowed(
        run(AssignmentCommand.acceptPickerAssignment, on: offered()),
      );

      expect(t.scopeEffect.removeFromOffered, <String>{pickerA});
      expect(t.scopeEffect.addToAssigned, <String>{pickerA});
      expect(t.scopeEffect.addToOffered, isEmpty);
    });

    test('accepting does NOT require an already accepted assignment', () {
      // The attempt is `offered` with no assignee — that is the whole point.
      final PickerAssignmentFacts f = offered();
      expect(f.attempt!.acceptedAssigneePrincipalId, isNull);
      expect(f.activeAcceptedCount, 0);
      expect(
        run(AssignmentCommand.acceptPickerAssignment, on: f).allowed,
        isTrue,
      );
    });

    test('a same-region non-recipient picker cannot accept', () {
      expect(
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: offered(),
          acting: pickerB,
        ).denial,
        AssignmentDenial.notOfferRecipient,
      );
    });

    test('accepting is not custody, delivery or money', () {
      final PickerAssignmentTransition t = allowed(
        run(AssignmentCommand.acceptPickerAssignment, on: offered()),
      );

      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.financialClassification, FinancialClassification.noneInThisSlice);
      expect(t.toState, isNot(AssignmentState.completed));
    });

    test('the order state is re-checked at acceptance time', () {
      // A stale offer must not be accepted after the order became terminal.
      for (final OrderState s in <OrderState>[
        OrderState.cancelled,
        OrderState.rejected,
        OrderState.placed,
      ]) {
        expect(
          run(
            AssignmentCommand.acceptPickerAssignment,
            on: facts(slotRevision: 1, orderState: s, current: attempt()),
          ).denial,
          AssignmentDenial.orderNotAssignmentEligible,
          reason: s.id,
        );
      }
    });
  });

  group('decline', () {
    PickerAssignmentFacts offered() =>
        facts(slotRevision: 1, current: attempt());

    test('the recipient declines, releasing offered scope only', () {
      final PickerAssignmentTransition t = allowed(
        run(AssignmentCommand.declinePickerAssignment, on: offered()),
      );

      expect(t.toState, AssignmentState.declined);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.scopeEffect.removeFromOffered, <String>{pickerA});
      expect(t.scopeEffect.addToAssigned, isEmpty);
      expect(t.eventType, AssignmentEventType.pickerDeclined);
    });

    test('a non-recipient cannot decline', () {
      expect(
        run(
          AssignmentCommand.declinePickerAssignment,
          on: offered(),
          acting: pickerB,
        ).denial,
        AssignmentDenial.notOfferRecipient,
      );
    });

    test('the offer recipient is retained as history after decline', () {
      final PickerAssignmentTransition t = allowed(
        run(AssignmentCommand.declinePickerAssignment, on: offered()),
      );

      expect(t.offerRecipientPrincipalId, pickerA);
    });
  });
}
