import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';

const String agentId = 'usr_agent01Aa-Bb22C';

PickerEligibility pickerEligible(String id) => PickerEligibility(
  principalId: id,
  isHumanPrincipal: true,
  membershipPrincipalId: id,
  role: CommerceRole.picker,
  status: MembershipStatus.active,
  regionId: region,
);

RiderEligibility riderEligible(String id) => RiderEligibility(
  principalId: id,
  isHumanPrincipal: true,
  membershipPrincipalId: id,
  role: CommerceRole.rider,
  status: MembershipStatus.active,
  regionId: region,
);

void main() {
  group('custody aggregate integrity', () {
    test('canonical shapes validate', () {
      expect(validateCustodyAggregate(atShop()), isNull);
      expect(validateCustodyAggregate(withPicker()), isNull);
      expect(validateCustodyAggregate(withRider()), isNull);
    });

    test('revision zero is corruption — a written aggregate starts at 1', () {
      expect(
        validateCustodyAggregate(atShop(revision: 0)),
        CustodyDenial.aggregateInconsistent,
      );
      expect(
        validateCustodyAggregate(atShop(revision: -2)),
        CustodyDenial.aggregateInconsistent,
      );
    });

    test('a malformed resource id is corruption', () {
      for (final String bad in <String>['', 'ord_short', '1234567890123456']) {
        expect(
          validateCustodyAggregate(atShop(resourceId: bad)),
          CustodyDenial.aggregateInconsistent,
          reason: 'resourceId "$bad"',
        );
      }
    });

    test('a blank shop id is corruption', () {
      for (final String bad in <String>['', '   ']) {
        expect(
          validateCustodyAggregate(atShop(shop: bad)),
          CustodyDenial.aggregateInconsistent,
        );
      }
    });

    test('a malformed worker identity is corruption', () {
      for (final String bad in <String>[
        '',
        'usr_short',
        '1234567890123456',
        r'usr_bad!principal01',
      ]) {
        expect(
          validateCustodyAggregate(withPicker(principalId: bad)),
          CustodyDenial.aggregateInconsistent,
          reason: 'principal "$bad"',
        );
        expect(
          validateCustodyAggregate(withPicker(assignmentId: bad)),
          CustodyDenial.aggregateInconsistent,
          reason: 'assignmentId "$bad"',
        );
      }
      for (final int g in <int>[0, -1]) {
        expect(
          validateCustodyAggregate(withPicker(generation: g)),
          CustodyDenial.aggregateInconsistent,
          reason: 'generation $g',
        );
      }
    });

    test('a customer holder has no defined shape here', () {
      expect(
        validateCustodyAggregate(
          withWorker(kind: CustodyHolderKind.customer),
        ),
        CustodyDenial.aggregateInconsistent,
      );
    });

    test('the validator never repairs', () {
      final CustodyFacts bad = withPicker(principalId: 'usr_short');
      expect(
        validateCustodyAggregate(bad),
        CustodyDenial.aggregateInconsistent,
      );
      expect(bad.holder.principalId, 'usr_short');
      expect(bad.custodyRevision, 2);
    });

    test('corrupt custody produces no transition for any command', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        final CustodyOutcome o = runCustody(
          c,
          custody: withPicker(principalId: 'usr_short'),
        );
        expect(o.denial, CustodyDenial.aggregateInconsistent,
            reason: c.commandType);
        expect(o.transition, isNull, reason: c.commandType);
      }
    });

    test('a corrupt ORDER aggregate blocks custody', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          order: orderFacts(units: 0),
        ).denial,
        CustodyDenial.aggregateInconsistent,
      );
    });

    test('a corrupt PICKER aggregate blocks custody', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          picker: pickerSlot(generation: 2, slotRevision: 2),
        ).denial,
        CustodyDenial.aggregateInconsistent,
      );
    });

    test('cross-aggregate resource mismatch fails closed', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          picker: pickerSlot(resourceId: otherOrderId),
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          rider: riderSlot(resourceId: otherOrderId),
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
    });

    test('in_delivery + released is corruption, not merely unowned', () {
      // Before B3A the order validator skipped any state its evaluator did not
      // own, so this would have passed. Dispatch does not release stock.
      expect(
        validateAggregate(
          OrderLifecycleFacts(
            state: OrderState.inDelivery,
            revision: 5,
            reservationState: ReservationState.released,
            reservedUnits: 3,
          ),
        ),
        LifecycleDenial.aggregateInconsistent,
      );
      expect(
        validateAggregate(
          OrderLifecycleFacts(
            state: OrderState.inDelivery,
            revision: 5,
            reservationState: ReservationState.expired,
            reservedUnits: 3,
          ),
        ),
        LifecycleDenial.aggregateInconsistent,
      );
      // The canonical pair does validate.
      expect(
        validateAggregate(
          OrderLifecycleFacts(
            state: OrderState.inDelivery,
            revision: 5,
            reservationState: ReservationState.committed,
            reservedUnits: 3,
          ),
        ),
        isNull,
      );
    });

    test('no pre-dispatch command may act from in_delivery', () {
      const OrderLifecycleFacts dispatched = OrderLifecycleFacts(
        state: OrderState.inDelivery,
        revision: 5,
        reservationState: ReservationState.committed,
        reservedUnits: 3,
      );

      for (final LifecycleCommand c in LifecycleCommand.values) {
        final LifecycleOutcome o = evaluateOrderTransition(
          request: LifecycleRequest(
            command: c,
            expectedRevision: 5,
            requestedUnits: 3,
          ),
          facts: dispatched,
        );
        expect(o.transition, isNull, reason: c.commandType);
        expect(o.denial, isNotNull, reason: c.commandType);

        // `placeOrder` is refused earlier, by the revision check: it requires
        // an absent order, so it never reaches the state gate. Every command
        // that does reach the gate is refused *because of the state*.
        if (c != LifecycleCommand.placeOrder) {
          expect(o.denial, LifecycleDenial.unknownTransition,
              reason: c.commandType);
        }
      }

      // The gate itself: `in_delivery` is not a state this evaluator owns.
      expect(
        OrderState.executableInThisSlice.contains(OrderState.inDelivery),
        isFalse,
      );
      // ...even though its aggregate shape is now known.
      expect(
        OrderState.aggregateShapeKnown.contains(OrderState.inDelivery),
        isTrue,
      );
    });
  });

  group('stale, duplicate and reordered custody commands', () {
    void denied(String label, CustodyOutcome o, [CustodyDenial? expected]) {
      expect(o.transition, isNull, reason: label);
      expect(o.denial, isNotNull, reason: label);
      if (expected != null) {
        expect(o.denial, expected, reason: label);
      }
    }

    test('duplicate shop pickup', () {
      denied(
        'pickup twice',
        runCustody(
          CustodyCommand.recordShopPickup,
          custody: withPicker(),
        ),
        CustodyDenial.wrongCustodyHolder,
      );
    });

    test('duplicate rider receipt', () {
      denied(
        'receipt twice',
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withRider(),
        ),
        CustodyDenial.wrongCustodyHolder,
      );
    });

    test('stale custody revision on every command', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        denied(
          'stale custody rev for ${c.commandType}',
          runCustody(c, expectedCustodyRevision: 99),
          CustodyDenial.custodyRevisionConflict,
        );
      }
    });

    test('stale order revision on every command', () {
      // Checked even for pickup, which leaves the order untouched: a caller
      // acting on a stale view of the order is refused either way.
      for (final CustodyCommand c in CustodyCommand.values) {
        denied(
          'stale order rev for ${c.commandType}',
          runCustody(c, expectedOrderRevision: 1),
          CustodyDenial.orderRevisionConflict,
        );
      }
    });

    test('reordered old receipt after picker reassignment', () {
      // Picker A collected; A was replaced by B. A delayed receipt naming the
      // old attempt must not complete B's assignment.
      denied(
        'receipt against a replaced picker',
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withPicker(),
          picker: pickerSlot(
            principalId: pickerB,
            assignmentId: pickAsgB,
            generation: 2,
          ),
        ),
        CustodyDenial.custodyHolderBindingMismatch,
      );
    });

    test('every denial leaves the facts untouched and effect-free', () {
      final CustodyFacts before = withPicker();
      for (final CustodyCommand c in CustodyCommand.values) {
        final CustodyOutcome o = runCustody(
          c,
          custody: before,
          expectedCustodyRevision: 99,
        );
        expect(o.transition, isNull, reason: c.commandType);
      }
      expect(before.custodyRevision, 2);
      expect(before.holder.kind, CustodyHolderKind.picker);
      expect(before.holder.assignmentId, pickAsgA);
    });
  });

  group('reassignment safety derived from real custody', () {
    test('missing custody is unsafe for both roles', () {
      for (final AssignmentRole r in AssignmentRole.values) {
        expect(
          reassignmentSafetyFor(role: r, custody: null),
          ReassignmentSafety.blockedOrUnknown,
          reason: '${r.id}: unknown is not safe',
        );
      }
    });

    test('corrupt custody is unsafe — absence of proof is not proof', () {
      // "The aggregate does not name this worker" must never become evidence
      // that they hold nothing.
      for (final AssignmentRole r in AssignmentRole.values) {
        expect(
          reassignmentSafetyFor(
            role: r,
            custody: withPicker(principalId: 'usr_short'),
          ),
          ReassignmentSafety.blockedOrUnknown,
          reason: r.id,
        );
      }
    });

    test('before pickup, neither worker holds anything', () {
      for (final AssignmentRole r in AssignmentRole.values) {
        expect(
          reassignmentSafetyFor(role: r, custody: atShop()),
          ReassignmentSafety.provenNoCustody,
          reason: r.id,
        );
      }
    });

    test('with the picker: picker unsafe, rider still revocable', () {
      expect(
        reassignmentSafetyFor(
          role: AssignmentRole.picker,
          custody: withPicker(),
        ),
        ReassignmentSafety.blockedOrUnknown,
      );
      // An accepted rider who has received nothing is holding nothing.
      expect(
        reassignmentSafetyFor(
          role: AssignmentRole.rider,
          custody: withPicker(),
        ),
        ReassignmentSafety.provenNoCustody,
      );
    });

    test('with the rider: both unsafe', () {
      for (final AssignmentRole r in AssignmentRole.values) {
        expect(
          reassignmentSafetyFor(role: r, custody: withRider()),
          ReassignmentSafety.blockedOrUnknown,
          reason: r.id,
        );
      }
    });

    test('the derived safety actually gates the assignment evaluators', () {
      // Picker revoke while the picker holds the goods.
      final PickerAssignmentFacts picker = pickerSlot();
      expect(
        evaluatePickerAssignment(
          request: PickerAssignmentRequest(
            command: AssignmentCommand.revokePickerAssignment,
            expectedSlotRevision: picker.slotRevision,
            actingPrincipalId: agentId,
            assignmentId: pickAsgA,
            generation: 1,
            reassignmentSafety: reassignmentSafetyFor(
              role: AssignmentRole.picker,
              custody: withPicker(),
            ),
          ),
          facts: picker,
        ).denial,
        AssignmentDenial.reassignmentUnsafe,
      );
      // ...and is permitted while the goods are still at the shop.
      expect(
        evaluatePickerAssignment(
          request: PickerAssignmentRequest(
            command: AssignmentCommand.revokePickerAssignment,
            expectedSlotRevision: picker.slotRevision,
            actingPrincipalId: agentId,
            assignmentId: pickAsgA,
            generation: 1,
            reassignmentSafety: reassignmentSafetyFor(
              role: AssignmentRole.picker,
              custody: atShop(),
            ),
          ),
          facts: picker,
        ).allowed,
        isTrue,
      );
    });
  });

  group('B3-C1 — picker completion closes over the validator', () {
    // The invariant, proven from REAL evaluator output rather than arithmetic
    // asserted against itself:
    //
    //   picker offer -> accept   (picker evaluator)
    //   shop pickup              (custody evaluator)
    //   rider offer -> accept    (rider evaluator)
    //   rider receipt            (custody evaluator)
    //     -> apply completion -> validatePickerAssignmentAggregate == null
    //
    // `applyPickerCompletion` is TEST INFRASTRUCTURE. It is not evidence that
    // real persistence is correct: the custody record, the order, the picker
    // slot, the projections and the outbox must commit in one transaction —
    // criterion CA9 — which remains NOT RUN.

    /// Drives a real picker slot to `accepted` at the given generation.
    PickerAssignmentFacts acceptedPickerAt(int generation) {
      PickerAssignmentFacts f = PickerAssignmentFacts(
        resourceId: orderId,
        slotRevision: 0,
        orderState: OrderState.ready,
        orderRegionId: region,
      );
      const List<String> ids = <String>[
        'asg_G1aaBbCcDdEeFf11',
        'asg_G2aaBbCcDdEeFf22',
        'asg_G3aaBbCcDdEeFf33',
      ];
      for (int g = 1; g <= generation; g++) {
        // Offer.
        final PickerAssignmentTransition offer = evaluatePickerAssignment(
          request: PickerAssignmentRequest(
            command: AssignmentCommand.offerPickerAssignment,
            expectedSlotRevision: f.slotRevision,
            actingPrincipalId: agentId,
            newAssignmentId: ids[g - 1],
            targetEligibility: pickerEligible(pickerA),
            timeoutPolicyRef: policyRef,
          ),
          facts: f,
        ).transition!;
        f = _applyPicker(f, offer);
        // Accept.
        final PickerAssignmentTransition accept = evaluatePickerAssignment(
          request: PickerAssignmentRequest(
            command: AssignmentCommand.acceptPickerAssignment,
            expectedSlotRevision: f.slotRevision,
            actingPrincipalId: pickerA,
            assignmentId: f.attempt!.assignmentId,
            generation: f.attempt!.generation,
          ),
          facts: f,
        ).transition!;
        f = _applyPicker(f, accept);
        expect(validatePickerAssignmentAggregate(f), isNull);

        if (g < generation) {
          // Revoke so the next generation can be offered: 3 mutations.
          final PickerAssignmentTransition revoke = evaluatePickerAssignment(
            request: PickerAssignmentRequest(
              command: AssignmentCommand.revokePickerAssignment,
              expectedSlotRevision: f.slotRevision,
              actingPrincipalId: agentId,
              assignmentId: f.attempt!.assignmentId,
              generation: f.attempt!.generation,
              reassignmentSafety: ReassignmentSafety.provenNoCustody,
            ),
            facts: f,
          ).transition!;
          f = _applyPicker(f, revoke);
          expect(validatePickerAssignmentAggregate(f), isNull);
        }
      }
      return f;
    }

    /// Runs the full custody path and returns the completed picker slot.
    PickerAssignmentFacts completeVia(PickerAssignmentFacts picker) {
      final PickerAssignmentAttempt pa = picker.attempt!;

      // Shop pickup.
      final CustodyTransition pickup = allowedCustody(
        evaluateCustodyTransition(
          request: CustodyRequest(
            command: CustodyCommand.recordShopPickup,
            actingPrincipalId: pickerA,
            expectedCustodyRevision: 1,
            expectedOrderRevision: 4,
            assignmentId: pa.assignmentId,
            generation: pa.generation,
          ),
          custody: atShop(),
          order: orderFacts(),
          pickerAssignment: picker,
          riderAssignment: null,
        ),
      );
      final CustodyFacts held = applyCustody(pickup);
      expect(validateCustodyAggregate(held), isNull);
      expect(held.holder.kind, CustodyHolderKind.picker);

      // Rider offer + accept, from the real rider evaluator.
      RiderAssignmentFacts rider = RiderAssignmentFacts(
        resourceId: orderId,
        slotRevision: 0,
        orderState: OrderState.ready,
        orderRegionId: region,
      );
      final RiderAssignmentTransition rOffer = evaluateRiderAssignment(
        request: RiderAssignmentRequest(
          command: AssignmentCommand.offerRiderAssignment,
          expectedSlotRevision: 0,
          actingPrincipalId: pickerA,
          newAssignmentId: rideAsgA,
          targetEligibility: riderEligible(riderA),
          timeoutPolicyRef: policyRef,
        ),
        facts: rider,
        pickerAuthority: picker,
      ).transition!;
      rider = _applyRider(rider, rOffer);
      final RiderAssignmentTransition rAccept = evaluateRiderAssignment(
        request: RiderAssignmentRequest(
          command: AssignmentCommand.acceptRiderAssignment,
          expectedSlotRevision: rider.slotRevision,
          actingPrincipalId: riderA,
          assignmentId: rider.attempt!.assignmentId,
          generation: rider.attempt!.generation,
        ),
        facts: rider,
        pickerAuthority: picker,
      ).transition!;
      rider = _applyRider(rider, rAccept);

      // Rider receipt — the edge that completes the picker.
      final CustodyTransition receipt = allowedCustody(
        evaluateCustodyTransition(
          request: CustodyRequest(
            command: CustodyCommand.recordRiderReceipt,
            actingPrincipalId: riderA,
            expectedCustodyRevision: held.custodyRevision,
            expectedOrderRevision: 4,
            assignmentId: rider.attempt!.assignmentId,
            generation: rider.attempt!.generation,
          ),
          custody: held,
          order: orderFacts(),
          pickerAssignment: picker,
          riderAssignment: rider,
        ),
      );
      expect(validateCustodyAggregate(applyCustody(receipt)), isNull);
      expect(
        validateAggregate(applyOrder(receipt, orderFacts())),
        isNull,
        reason: 'in_delivery + committed must be canonical',
      );
      return applyPickerCompletion(receipt, picker);
    }

    test('generation 1: completion closes at revision 3', () {
      final PickerAssignmentFacts accepted = acceptedPickerAt(1);
      expect(accepted.slotRevision, 2);

      final PickerAssignmentFacts done = completeVia(accepted);
      expect(done.attempt!.state, AssignmentState.completed);
      expect(done.slotRevision, 3, reason: 'offer + accept + completion');
      expect(
        validatePickerAssignmentAggregate(done),
        isNull,
        reason: 'B3-C1: a real completed history must validate — the role-aware '
            'reachableSlotRevisionRange and the completion effect have drifted '
            'apart if this fails',
      );
    });

    test('generation 2: completion closes inside the reachable range', () {
      final PickerAssignmentFacts accepted = acceptedPickerAt(2);
      final PickerAssignmentFacts done = completeVia(accepted);
      expect(done.attempt!.generation, 2);
      expect(done.slotRevision, 6, reason: 'g1 revoked (3) + 3');
      expect(validatePickerAssignmentAggregate(done), isNull);
    });

    test('generation 3: completion closes inside the reachable range', () {
      final PickerAssignmentFacts accepted = acceptedPickerAt(3);
      final PickerAssignmentFacts done = completeVia(accepted);
      expect(done.attempt!.generation, 3);
      expect(done.slotRevision, 9, reason: '3 + 3 + 3 — the maximum');
      expect(validatePickerAssignmentAggregate(done), isNull);
    });

    test('completion retains every identity', () {
      final PickerAssignmentFacts done = completeVia(acceptedPickerAt(1));
      expect(done.attempt!.offerRecipientPrincipalId, pickerA);
      expect(done.attempt!.acceptedAssigneePrincipalId, pickerA);
      expect(done.attempt!.assignmentId, isNotEmpty);
      expect(done.attempt!.generation, 1);
    });

    test('a completed attempt no longer occupies the slot', () {
      expect(AssignmentState.completed.occupiesSlot, isFalse);
      expect(AssignmentState.completed.isTerminal, isTrue);
      final PickerAssignmentFacts done = completeVia(acceptedPickerAt(1));
      expect(done.activeAcceptedCount, 0);
    });
  });

  group('role-aware revision model', () {
    test('picker completed has a defined range, rider does not', () {
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed,
            role: AssignmentRole.picker),
        (min: 3, max: 3),
      );
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed,
            role: AssignmentRole.rider),
        isNull,
        reason: 'B3-C2 stays FUTURE; no rider completion cost was invented',
      );
    });

    test('omitting the role preserves the pre-B3A answer exactly', () {
      // Existing callers that ask a purely pre-custody question keep the
      // answer they always had.
      expect(reachableSlotRevisionRange(1, AssignmentState.completed), isNull);
      expect(reachableSlotRevisionRange(5, AssignmentState.completed), isNull);
    });

    test('the five pre-custody ranges do not depend on role at all', () {
      for (final AssignmentState s in AssignmentState.executableInThisSlice) {
        for (int g = 1; g <= 4; g++) {
          final ({int min, int max})? neutral =
              reachableSlotRevisionRange(g, s);
          expect(
            reachableSlotRevisionRange(g, s, role: AssignmentRole.picker),
            neutral,
            reason: 'picker ${s.id} g$g',
          );
          expect(
            reachableSlotRevisionRange(g, s, role: AssignmentRole.rider),
            neutral,
            reason: 'rider ${s.id} g$g',
          );
        }
      }
    });

    test('picker completed costs the same per generation as revoked', () {
      for (int g = 1; g <= 4; g++) {
        expect(
          reachableSlotRevisionRange(g, AssignmentState.completed,
              role: AssignmentRole.picker),
          reachableSlotRevisionRange(g, AssignmentState.revoked),
          reason: 'generation $g: offer+accept+completion == offer+accept+revoke',
        );
      }
    });

    test('impossible completed pairs fail closed', () {
      for (final (int gen, int rev) in <(int, int)>[
        (1, 1),
        (1, 2),
        (1, 4),
        (2, 4),
        (2, 7),
        (3, 6),
        (3, 10),
      ]) {
        expect(
          validatePickerAssignmentAggregate(
            pickerSlot(
              state: AssignmentState.completed,
              generation: gen,
              slotRevision: rev,
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: 'gen$gen completed at rev$rev is unreachable',
        );
      }
    });

    test('rider completed remains shape-undefined and unreachable', () {
      expect(
        AssignmentState.executableForRole(AssignmentRole.rider)
            .contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        AssignmentState.executableForRole(AssignmentRole.picker)
            .contains(AssignmentState.completed),
        isTrue,
      );
      // The rider evaluator still refuses to act on one.
      expect(
        evaluateRiderAssignment(
          request: const RiderAssignmentRequest(
            command: AssignmentCommand.acceptRiderAssignment,
            expectedSlotRevision: 2,
            actingPrincipalId: riderA,
            assignmentId: rideAsgA,
            generation: 1,
          ),
          facts: riderSlot(state: AssignmentState.completed, slotRevision: 2),
          pickerAuthority: pickerSlot(),
        ).denial,
        AssignmentDenial.unknownTransition,
      );
    });

    test('the pre-custody executable set is unchanged', () {
      expect(AssignmentState.executableInThisSlice, <AssignmentState>{
        AssignmentState.offered,
        AssignmentState.accepted,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      });
    });
  });
}

PickerAssignmentFacts _applyPicker(
  PickerAssignmentFacts before,
  PickerAssignmentTransition t,
) => PickerAssignmentFacts(
  resourceId: before.resourceId,
  slotRevision: t.resultingSlotRevision,
  orderState: before.orderState,
  orderRegionId: before.orderRegionId,
  attempt: PickerAssignmentAttempt(
    assignmentId: t.assignmentId,
    generation: t.generation,
    state: t.toState,
    offerRecipientPrincipalId: t.offerRecipientPrincipalId,
    acceptedAssigneePrincipalId: t.acceptedAssigneePrincipalId,
    timeoutPolicyRef: policyRef,
  ),
);

RiderAssignmentFacts _applyRider(
  RiderAssignmentFacts before,
  RiderAssignmentTransition t,
) => RiderAssignmentFacts(
  resourceId: before.resourceId,
  slotRevision: t.resultingSlotRevision,
  orderState: before.orderState,
  orderRegionId: before.orderRegionId,
  attempt: RiderAssignmentAttempt(
    assignmentId: t.assignmentId,
    generation: t.generation,
    state: t.toState,
    offerRecipientPrincipalId: t.offerRecipientPrincipalId,
    acceptedAssigneePrincipalId: t.acceptedAssigneePrincipalId,
    timeoutPolicyRef: policyRef,
    source: t.source,
  ),
);
