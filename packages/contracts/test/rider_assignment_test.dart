import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/rider_assignment_fixtures.dart';

void main() {
  group('picker authority is the prerequisite for offering rider work', () {
    test('the order\'s current accepted picker may offer rider work', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ),
      );

      expect(t.toState, AssignmentState.offered);
      expect(t.offerRecipientPrincipalId, riderA);
      expect(t.source.pickerPrincipalId, pickerA);
      expect(t.source.pickerAssignmentId, pickAsgA);
      expect(t.source.pickerGeneration, 1);
    });

    test('no picker assignment at all is denied', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          pickerAuthority: pickerSlot(state: null),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.noAcceptedPickerAssignment,
      );
    });

    test('a picker attempt that is not accepted is denied', () {
      for (final AssignmentState s in <AssignmentState>[
        AssignmentState.offered,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: riderFacts(),
            pickerAuthority: pickerSlot(state: s),
            newAssignmentId: rideAsgA,
            target: riderEligible(riderA),
          ).denial,
          AssignmentDenial.noAcceptedPickerAssignment,
          reason: 'a ${s.id} picker attempt is not current authority',
        );
      }
    });

    test('a different picker than the accepted one is denied', () {
      // Picker B holds no assignment on this order. Holding the picker role is
      // not authority over somebody else's order.
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          acting: pickerB,
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.notCurrentAcceptedPicker,
      );
    });

    test('an agent cannot offer rider work through this flow', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          acting: agentId,
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.notCurrentAcceptedPicker,
      );
    });

    test('picker authority for a different resource is denied', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          pickerAuthority: pickerSlot(resourceId: otherOrderId),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.pickerAuthorityInconsistent,
      );
    });

    test('picker authority disagreeing about the order is denied', () {
      // Both aggregates are supposed to come from one consistent read-set.
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          pickerAuthority: pickerSlot(orderRegion: otherRegion),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.pickerAuthorityInconsistent,
      );
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          pickerAuthority: pickerSlot(orderState: OrderState.ready),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.pickerAuthorityInconsistent,
      );
    });

    test('malformed picker authority facts are denied', () {
      // Generation 2 at revision 2 is a picker history that cannot exist.
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          pickerAuthority: pickerSlot(generation: 2, slotRevision: 2),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.pickerAuthorityInconsistent,
      );
    });

    test('omitting picker authority fails closed', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          omitPickerAuthority: true,
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ).denial,
        AssignmentDenial.pickerAuthorityInconsistent,
      );
    });

    test('offering needs no physical custody — only an accepted picker', () {
      // "Accepted picker" and "picker is holding the goods" are different
      // facts. Custody does not exist in this contract at all, and the offer
      // above succeeded without any custody input.
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ),
      );
      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
    });
  });

  group('rider target eligibility', () {
    RiderAssignmentOutcome offerTo(RiderEligibility target) => runRider(
      AssignmentCommand.offerRiderAssignment,
      on: riderFacts(),
      newAssignmentId: rideAsgA,
      target: target,
    );

    test('an active human rider in the order region qualifies', () {
      expect(offerTo(riderEligible(riderA)).allowed, isTrue);
    });

    test('every other role is denied', () {
      for (final CommerceRole r in <CommerceRole>[
        CommerceRole.picker,
        CommerceRole.agent,
        CommerceRole.customer,
        CommerceRole.admin,
      ]) {
        expect(
          offerTo(riderEligible(riderA, role: r)).denial,
          AssignmentDenial.targetNotEligible,
          reason: '${r.name} must not receive rider work',
        );
      }
    });

    test('a non-active membership is denied', () {
      for (final MembershipStatus s in MembershipStatus.values) {
        if (s == MembershipStatus.active) {
          continue;
        }
        expect(
          offerTo(riderEligible(riderA, status: s)).denial,
          AssignmentDenial.targetNotEligible,
          reason: '${s.name} must not receive new work',
        );
      }
    });

    test('a non-human principal is denied', () {
      expect(
        offerTo(riderEligible(riderA, human: false)).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    test('a membership naming somebody else grants nothing', () {
      expect(
        offerTo(riderEligible(riderA, membershipOf: riderB)).denial,
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
          riderEligible(id).qualifiesAsActiveRider,
          isFalse,
          reason: '$label must not qualify',
        );
      });
    });

    test('a malformed target principal id produces no transition', () {
      malformedIds.forEach((String label, String id) {
        final RiderAssignmentOutcome o = offerTo(riderEligible(id));
        expect(o.denial, AssignmentDenial.targetNotEligible, reason: label);
        expect(o.transition, isNull, reason: label);
      });
    });

    test('a malformed membership principal id cannot qualify', () {
      for (final String bad in <String>['', 'usr_short', '1234567890123456']) {
        final RiderAssignmentOutcome o =
            offerTo(riderEligible(riderA, membershipOf: bad));
        expect(o.denial, AssignmentDenial.targetNotEligible, reason: bad);
        expect(o.transition, isNull, reason: bad);
      }
    });

    test('a well-formed active target still qualifies', () {
      expect(riderEligible(riderA).qualifiesAsActiveRider, isTrue);
      expect(offerTo(riderEligible(riderA)).allowed, isTrue);
    });

    test('a missing target is denied', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          newAssignmentId: rideAsgA,
        ).denial,
        AssignmentDenial.targetNotEligible,
      );
    });

    test('a different region is denied', () {
      expect(
        offerTo(riderEligible(riderA, regionId: otherRegion)).denial,
        AssignmentDenial.regionMismatch,
      );
    });

    test('a missing region is not a match on either side', () {
      expect(
        offerTo(riderEligible(riderA, regionId: null)).denial,
        AssignmentDenial.regionMismatch,
      );
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(orderRegion: null),
          pickerAuthority: pickerSlot(orderRegion: null),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA, regionId: null),
        ).denial,
        AssignmentDenial.regionMismatch,
      );
    });

    test('no dispatch-policy input exists to invent', () {
      // Workload, rating, distance, vehicle and shift are deliberately absent
      // from the eligibility shape. If one is ever added it must arrive with
      // an owner decision, not as a lifecycle guess.
      const RiderEligibility e = RiderEligibility(
        principalId: riderA,
        isHumanPrincipal: true,
        membershipPrincipalId: riderA,
        role: CommerceRole.rider,
        status: MembershipStatus.active,
        regionId: region,
      );
      expect(e.qualifiesAsActiveRider, isTrue);
    });
  });

  group('order eligibility', () {
    test('accepted, preparing and ready may carry rider work', () {
      for (final OrderState s in <OrderState>[
        OrderState.accepted,
        OrderState.preparing,
        OrderState.ready,
      ]) {
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: riderFacts(orderState: s),
            newAssignmentId: rideAsgA,
            target: riderEligible(riderA),
          ).allowed,
          isTrue,
          reason: '${s.id} should carry rider work',
        );
      }
    });

    test('every other order state is denied', () {
      for (final OrderState s in OrderState.values) {
        if (assignmentEligibleOrderStates.contains(s)) {
          continue;
        }
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: riderFacts(orderState: s),
            newAssignmentId: rideAsgA,
            target: riderEligible(riderA),
          ).denial,
          AssignmentDenial.orderNotAssignmentEligible,
          reason: '${s.id} must not carry rider work',
        );
      }
    });

    test('rider eligibility reuses the picker set, unchanged', () {
      expect(assignmentEligibleOrderStates, <OrderState>{
        OrderState.accepted,
        OrderState.preparing,
        OrderState.ready,
      });
    });

    test('no rider transition changes the order state', () {
      // The evaluator reads order state and never returns one.
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(),
          newAssignmentId: rideAsgA,
          target: riderEligible(riderA),
        ),
      );
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
    });
  });

  group('offer', () {
    RiderAssignmentTransition offer() => allowedRider(
      runRider(
        AssignmentCommand.offerRiderAssignment,
        on: riderFacts(),
        newAssignmentId: rideAsgA,
        target: riderEligible(riderA),
      ),
    );

    test('records the targeted rider and no assignee', () {
      final RiderAssignmentTransition t = offer();
      expect(t.offerRecipientPrincipalId, riderA);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.generation, 1);
      expect(t.resultingSlotRevision, 1);
      expect(t.eventType, 'rider.assignment.offered');
    });

    test('grants offered scope only, never assigned', () {
      final ScopeProjectionEffect e = offer().scopeEffect;
      expect(e.addToOffered, <String>{riderA});
      expect(e.addToAssigned, isEmpty);
      expect(e.removeFromAssigned, isEmpty);
    });

    test('has no inventory, financial or custody effect', () {
      final RiderAssignmentTransition t = offer();
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
    });

    test('requires a non-blank timeout policy reference', () {
      for (final String? ref in <String?>[null, '', '   ']) {
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: riderFacts(),
            newAssignmentId: rideAsgA,
            target: riderEligible(riderA),
            timeoutRef: ref,
          ).denial,
          AssignmentDenial.timeoutPolicyMissing,
        );
      }
    });

    test('carries a policy reference and no numeric duration', () {
      // The whole rider surface is searched for a duration type in the
      // integrity suite; here the offer simply carries the reference forward.
      expect(policyRef, contains('@v'));
      expect(offer().toString(), isNot(contains('Duration')));
    });

    test('requires a valid opaque assignment id', () {
      for (final String bad in <String>['', 'short', '1234567890123456']) {
        expect(
          runRider(
            AssignmentCommand.offerRiderAssignment,
            on: riderFacts(),
            newAssignmentId: bad,
            target: riderEligible(riderA),
          ).denial,
          AssignmentDenial.assignmentIdInvalid,
          reason: '"$bad" is not an opaque id',
        );
      }
    });

    test('a second live offer is denied', () {
      expect(
        runRider(
          AssignmentCommand.offerRiderAssignment,
          on: riderFacts(slotRevision: 1, current: riderAttempt()),
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
          on: riderFacts(
            slotRevision: 2,
            current: riderAttempt(
              state: AssignmentState.accepted,
              assignee: riderA,
            ),
          ),
          newAssignmentId: rideAsgB,
          target: riderEligible(riderB),
        ).denial,
        AssignmentDenial.activeAcceptedAssignmentExists,
      );
    });
  });

  group('accept', () {
    RiderAssignmentFacts offered() =>
        riderFacts(slotRevision: 1, current: riderAttempt());

    test('the exact recipient accepts and becomes the assignee', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
        ),
      );

      expect(t.fromState, AssignmentState.offered);
      expect(t.toState, AssignmentState.accepted);
      expect(t.offerRecipientPrincipalId, riderA);
      expect(t.acceptedAssigneePrincipalId, riderA);
      expect(t.resultingSlotRevision, 2);
      expect(t.eventType, 'rider.assignment.accepted');
    });

    test('offered scope becomes assigned scope', () {
      final ScopeProjectionEffect e = allowedRider(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
        ),
      ).scopeEffect;

      expect(e.removeFromOffered, <String>{riderA});
      expect(e.addToAssigned, <String>{riderA});
    });

    test('a same-region rider who is not the recipient is denied', () {
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderB,
        ).denial,
        AssignmentDenial.notOfferRecipient,
      );
    });

    test('accepting does not require an existing assignment', () {
      // The offer grants offeredResource, not assignedResource. Requiring an
      // accepted assignment in order to accept one would be circular.
      expect(offered().activeAcceptedCount, 0);
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
        ).allowed,
        isTrue,
      );
    });

    test('the source picker assignment must still be current', () {
      // Picker A offered; picker A was revoked and picker B now holds the
      // order. The stale offer must not be accepted as though B created it.
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(
            pickerId: pickerB,
            assignmentId: pickAsgB,
            generation: 2,
          ),
        ).denial,
        AssignmentDenial.sourcePickerAssignmentMismatch,
      );
    });

    test('each part of the source binding is checked', () {
      // A replacement attempt takes a new id AND a new generation; comparing
      // only one of them would accept a different attempt that lined up.
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(assignmentId: pickAsgB),
        ).denial,
        AssignmentDenial.sourcePickerAssignmentMismatch,
        reason: 'different picker assignment id',
      );
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(generation: 2, slotRevision: 4),
        ).denial,
        AssignmentDenial.sourcePickerAssignmentMismatch,
        reason: 'different picker generation',
      );
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(pickerId: pickerB),
        ).denial,
        AssignmentDenial.sourcePickerAssignmentMismatch,
        reason: 'different picker principal',
      );
    });

    test('a picker no longer accepted denies acceptance', () {
      expect(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(state: AssignmentState.revoked),
        ).denial,
        AssignmentDenial.noAcceptedPickerAssignment,
      );
    });

    test('accepting is not custody and moves nothing', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.acceptRiderAssignment,
          on: offered(),
          acting: riderA,
        ),
      );
      expect(t.custodyClassification, CustodyClassification.noneInThisSlice);
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
    });
  });

  group('decline', () {
    RiderAssignmentFacts offered() =>
        riderFacts(slotRevision: 1, current: riderAttempt());

    test('the exact recipient declines', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: offered(),
          acting: riderA,
        ),
      );

      expect(t.toState, AssignmentState.declined);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.offerRecipientPrincipalId, riderA);
      expect(t.scopeEffect.removeFromOffered, <String>{riderA});
      expect(t.scopeEffect.addToAssigned, isEmpty);
      expect(t.eventType, 'rider.assignment.declined');
    });

    test('a same-region rider who is not the recipient is denied', () {
      expect(
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: offered(),
          acting: riderB,
        ).denial,
        AssignmentDenial.notOfferRecipient,
      );
    });

    test('the source picker record survives the decline', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: offered(),
          acting: riderA,
        ),
      );
      expect(t.source.pickerPrincipalId, pickerA);
      expect(t.source.pickerAssignmentId, pickAsgA);
    });

    test('a replaced source picker does not trap the rider', () {
      // Deliberate asymmetry with accept: declining grants the rider nothing,
      // so requiring a current source picker would only strand an offer the
      // rider is refusing anyway.
      expect(
        runRider(
          AssignmentCommand.declineRiderAssignment,
          on: offered(),
          acting: riderA,
          pickerAuthority: pickerSlot(
            pickerId: pickerB,
            assignmentId: pickAsgB,
            generation: 2,
          ),
        ).allowed,
        isTrue,
      );
    });
  });

  group('offer expiry', () {
    RiderAssignmentFacts offered() =>
        riderFacts(slotRevision: 1, current: riderAttempt());

    test('a due offer expires', () {
      final RiderAssignmentTransition t = allowedRider(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: offered(),
          expiryDue: true,
        ),
      );

      expect(t.toState, AssignmentState.expired);
      expect(t.acceptedAssigneePrincipalId, isNull);
      expect(t.scopeEffect.removeFromOffered, <String>{riderA});
      expect(t.eventType, 'rider.assignment.expired');
    });

    test('an offer that is not due cannot be expired', () {
      expect(
        runRider(AssignmentCommand.expireRiderOffer, on: offered()).denial,
        AssignmentDenial.expiryNotDue,
      );
    });

    test('expiryDue defaults to false, so expiry fails closed', () {
      const RiderAssignmentRequest r = RiderAssignmentRequest(
        command: AssignmentCommand.expireRiderOffer,
        expectedSlotRevision: 1,
        actingPrincipalId: riderA,
      );
      expect(r.expiryDue, isFalse);
    });

    test('rider expiry is worker-driven and borrows no human permission', () {
      expect(AssignmentCommand.expireRiderOffer.isWorkerDriven, isTrue);
      expect(AssignmentCommand.expireRiderOffer.requiredPermission, isNull);
      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.rider)) {
        if (c != AssignmentCommand.expireRiderOffer) {
          expect(c.requiredPermission, isNotNull, reason: c.commandType);
        }
      }
    });

    test('an accepted assignment cannot be expired', () {
      expect(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: riderFacts(
            slotRevision: 2,
            current: riderAttempt(
              state: AssignmentState.accepted,
              assignee: riderA,
            ),
          ),
          expiryDue: true,
        ).denial,
        AssignmentDenial.wrongAssignmentState,
      );
    });

    test('expiry needs no picker authority', () {
      // A worker sweeping lapsed offers has no picker to consult.
      expect(
        runRider(
          AssignmentCommand.expireRiderOffer,
          on: offered(),
          omitPickerAuthority: true,
          expiryDue: true,
        ).allowed,
        isTrue,
      );
    });
  });
}
