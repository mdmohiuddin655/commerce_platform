import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';

void main() {
  group('custody vocabulary and initialisation', () {
    test('the four canonical holders are declared, customer unreachable', () {
      expect(CustodyHolderKind.values.map((CustodyHolderKind k) => k.id), <String>[
        'shop',
        'picker',
        'rider',
        'customer',
      ]);
      expect(CustodyHolderKind.executableInThisSlice, <CustodyHolderKind>{
        CustodyHolderKind.shop,
        CustodyHolderKind.picker,
        CustodyHolderKind.rider,
      });
      expect(CustodyHolderKind.notYetImplemented, <CustodyHolderKind>{
        CustodyHolderKind.customer,
      });
    });

    test('there is no none/unknown holder to mean "probably the shop"', () {
      for (final CustodyHolderKind k in CustodyHolderKind.values) {
        expect(k.id, isNot(anyOf('none', 'unknown', 'unassigned', '')));
      }
    });

    test('initialisation at shop is explicit and starts at revision 1', () {
      final CustodyFacts f = CustodyFacts.initialAtShop(
        resourceId: orderId,
        shopId: shopId,
      );
      expect(f.holder.kind, CustodyHolderKind.shop);
      expect(f.holder.shopId, shopId);
      expect(f.custodyRevision, 1);
      expect(validateCustodyAggregate(f), isNull);
      expect(f.isAtShop, isTrue);
    });

    test('absent custody is not treated as shop custody', () {
      // The whole point of the aggregate: missing means missing.
      final CustodyOutcome o = runCustody(
        CustodyCommand.recordShopPickup,
        omitCustody: true,
      );
      expect(o.denial, CustodyDenial.custodyNotInitialised);
      expect(o.transition, isNull);
    });

    test('there is no custody-initialisation client command', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        expect(c.commandType, isNot(contains('init')));
        expect(c.commandType, isNot(contains('create')));
      }
      expect(CustodyCommand.values.length, 2);
    });

    test('no command can patch a custodian or a status', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        for (final String forbidden in <String>[
          'set_',
          'status',
          'patch',
          'force',
          'transfer_to',
          'assign',
        ]) {
          expect(c.commandType, isNot(contains(forbidden)),
              reason: '${c.commandType} looks like an overwrite');
        }
      }
    });

    test('custody revision is independent of every other revision', () {
      // Order rev 4, picker slot rev 2, rider slot rev 2, custody rev 1.
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordShopPickup),
      );
      expect(t.resultingCustodyRevision, 2, reason: 'custody 1 -> 2');
      expect(t.orderEffect.changesOrder, isFalse, reason: 'order untouched');
      expect(t.pickerCompletion, isNull, reason: 'picker slot untouched');
    });
  });

  group('canonical resource and shop binding (FIX-001)', () {
    test('custody for a different resource is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          custody: atShop(resourceId: otherOrderId),
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
    });

    test('a picker slot for a different resource is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          picker: pickerSlot(resourceId: otherOrderId),
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
    });

    test('a rider slot for a different resource is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          rider: riderSlot(resourceId: otherOrderId),
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
    });

    test('shop custody naming a different shop is refused', () {
      // Both ids are individually non-blank and perfectly well formed. They
      // are simply not the same shop, and that is the whole point.
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          custody: atShop(shop: 'shop_beta'),
        ).denial,
        CustodyDenial.shopBindingMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          resource: resourceContext(shop: 'shop_beta'),
        ).denial,
        CustodyDenial.shopBindingMismatch,
      );
    });

    test('the existing non-opaque shop id is still accepted', () {
      // No ShopId grammar was invented: `shop_alpha` would fail the opaque-id
      // rule, and imposing that rule here would invent a contract the
      // repository does not have.
      expect(isValidOpaqueId(shopId), isFalse);
      expect(
        runCustody(CustodyCommand.recordShopPickup).allowed,
        isTrue,
      );
    });

    test('a blank or whitespace-only shop id is refused', () {
      for (final String bad in <String>['', '   ']) {
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            resource: resourceContext(shop: bad),
          ).denial,
          CustodyDenial.resourceBindingMismatch,
          reason: 'context shop "$bad"',
        );
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            custody: atShop(shop: bad),
          ).transition,
          isNull,
          reason: 'custody shop "$bad"',
        );
      }
    });

    test('a malformed context resource id is refused', () {
      for (final String bad in <String>['', 'ord_short', '1234567890123456']) {
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            resource: resourceContext(resourceId: bad),
          ).denial,
          CustodyDenial.resourceBindingMismatch,
          reason: 'resourceId "$bad"',
        );
      }
    });

    test('identities are compared exactly, never trimmed into equality', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          custody: atShop(shop: ' shop_alpha '),
        ).denial,
        CustodyDenial.shopBindingMismatch,
        reason: 'a padded shop id is a different shop id',
      );
    });
  });

  group('custody initialisation is create-once (FIX-001)', () {
    test('absent custody initialises at the shop, revision 1', () {
      final CustodyInitialisationOutcome o = initialiseCustodyAtShop(
        resource: resourceContext(),
        existingCustody: null,
      );
      expect(o.allowed, isTrue);
      expect(o.created!.custodyRevision, 1);
      expect(o.created!.holder.kind, CustodyHolderKind.shop);
      expect(o.created!.holder.shopId, shopId);
      expect(o.created!.resourceId, orderId);
      expect(validateCustodyAggregate(o.created!), isNull);
    });

    test('initialising again while at the shop is refused', () {
      final CustodyInitialisationOutcome o = initialiseCustodyAtShop(
        resource: resourceContext(),
        existingCustody: atShop(revision: 7),
      );
      expect(o.denial, CustodyDenial.custodyAlreadyInitialised);
      expect(o.created, isNull, reason: 'revision 7 must not reset to 1');
    });

    test('initialisation cannot undo a pickup', () {
      final CustodyInitialisationOutcome o = initialiseCustodyAtShop(
        resource: resourceContext(),
        existingCustody: withPicker(),
      );
      expect(o.denial, CustodyDenial.custodyAlreadyInitialised);
      expect(o.created, isNull);
    });

    test('initialisation cannot undo a rider receipt', () {
      final CustodyInitialisationOutcome o = initialiseCustodyAtShop(
        resource: resourceContext(),
        existingCustody: withRider(),
      );
      expect(o.denial, CustodyDenial.custodyAlreadyInitialised);
      expect(o.created, isNull);
    });

    test('a malformed resource context cannot initialise', () {
      expect(
        initialiseCustodyAtShop(
          resource: resourceContext(shop: '  '),
          existingCustody: null,
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
      expect(
        initialiseCustodyAtShop(
          resource: resourceContext(resourceId: 'ord_short'),
          existingCustody: null,
        ).denial,
        CustodyDenial.resourceBindingMismatch,
      );
    });

    test('there is still no client command or permission for it', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        expect(c.commandType, isNot(contains('init')));
        expect(c.commandType, isNot(contains('create')));
      }
      expect(CustodyCommand.values.length, 2);
      for (final Permission p in Permission.values) {
        expect(p.id, isNot(contains('custody.initial')));
      }
    });
  });

  group('assignment slot revision CAS (FIX-001)', () {
    test('pickup with a stale picker slot revision is refused', () {
      final CustodyOutcome o = runCustody(
        CustodyCommand.recordShopPickup,
        expectedPickerSlotRevision: 1,
      );
      expect(o.denial, CustodyDenial.pickerSlotRevisionConflict);
      expect(o.transition, isNull);
    });

    test('receipt with a stale picker slot revision is refused', () {
      final CustodyOutcome o = runCustody(
        CustodyCommand.recordRiderReceipt,
        expectedPickerSlotRevision: 1,
      );
      expect(o.denial, CustodyDenial.pickerSlotRevisionConflict);
      expect(o.transition, isNull);
    });

    test('receipt with a stale rider slot revision is refused', () {
      final CustodyOutcome o = runCustody(
        CustodyCommand.recordRiderReceipt,
        expectedRiderSlotRevision: 1,
      );
      expect(o.denial, CustodyDenial.riderSlotRevisionConflict);
      expect(o.transition, isNull);
    });

    test('receipt omitting the rider slot expectation fails closed', () {
      final CustodyOutcome o = runCustody(
        CustodyCommand.recordRiderReceipt,
        omitRiderSlotRevision: true,
      );
      expect(o.denial, CustodyDenial.riderSlotRevisionConflict);
      expect(o.transition, isNull);
    });

    test('current slot revisions still allow the valid flow', () {
      expect(runCustody(CustodyCommand.recordShopPickup).allowed, isTrue);
      expect(runCustody(CustodyCommand.recordRiderReceipt).allowed, isTrue);
    });

    test('revision CAS does not replace the identity checks', () {
      // Correct revisions, wrong attempt: still refused.
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          assignmentId: pickAsgB,
        ).denial,
        CustodyDenial.assignmentIdMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          acting: riderB,
        ).denial,
        CustodyDenial.notCurrentAcceptedRider,
      );
    });
  });

  group('shop -> picker pickup', () {
    test('the current accepted picker collects the goods', () {
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordShopPickup),
      );

      expect(t.command, CustodyCommand.recordShopPickup);
      expect(t.fromHolder.kind, CustodyHolderKind.shop);
      expect(t.toHolder.kind, CustodyHolderKind.picker);
      expect(t.toHolder.principalId, pickerA);
      expect(t.toHolder.assignmentId, pickAsgA);
      expect(t.toHolder.assignmentGeneration, 1);
      expect(t.events, <String>['custody.acquired_by_picker']);
    });

    test('pickup uses the existing picker.custody.record_pickup permission', () {
      expect(
        CustodyCommand.recordShopPickup.requiredPermission,
        Permission.pickerRecordShopPickup,
      );
      final PermissionRule r =
          permissionMatrix[Permission.pickerRecordShopPickup]!;
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.picker});
      expect(r.scopes, contains(ScopeRequirement.assignedResource));
    });

    test('pickup is NOT dispatch: the order stays ready', () {
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordShopPickup),
      );
      expect(t.orderEffect.changesOrder, isFalse);
      expect(t.orderEffect.toState, isNull);
      expect(t.orderEffect.resultingOrderRevision, isNull);
    });

    test('pickup has no inventory or financial effect', () {
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordShopPickup),
      );
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
    });

    test('pickup grants no new authorization scope', () {
      // Possession is not permission. The picker already holds
      // assignedResource from accepting the assignment.
      expect(
        allowedCustody(
          runCustody(CustodyCommand.recordShopPickup),
        ).scopeEffect.isEmpty,
        isTrue,
      );
    });

    test('the order must be ready', () {
      for (final OrderState s in <OrderState>[
        OrderState.placed,
        OrderState.accepted,
        OrderState.preparing,
      ]) {
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            order: orderFacts(
              state: s,
              reservation: s == OrderState.placed
                  ? ReservationState.active
                  : ReservationState.committed,
            ),
            picker: pickerSlot(orderState: s),
          ).denial,
          anyOf(
            CustodyDenial.orderNotInRequiredState,
            CustodyDenial.reservationNotCommitted,
          ),
          reason: '${s.id} is not ready for collection',
        );
      }
    });

    test('the reservation must still be committed', () {
      for (final ReservationState r in <ReservationState>[
        ReservationState.active,
        ReservationState.released,
        ReservationState.expired,
      ]) {
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            order: orderFacts(reservation: r),
          ).denial,
          anyOf(
            CustodyDenial.reservationNotCommitted,
            CustodyDenial.aggregateInconsistent,
          ),
          reason: 'reservation ${r.id}',
        );
      }
    });

    test('there must be an accepted picker assignment', () {
      for (final AssignmentState? s in <AssignmentState?>[
        null,
        AssignmentState.offered,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        expect(
          runCustody(
            CustodyCommand.recordShopPickup,
            picker: pickerSlot(state: s),
          ).denial,
          CustodyDenial.noAcceptedPickerAssignment,
          reason: 'picker ${s?.id ?? 'absent'}',
        );
      }
    });

    test('another same-region picker cannot collect', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          acting: pickerB,
        ).denial,
        CustodyDenial.notCurrentAcceptedPicker,
      );
    });

    test('a rider cannot collect from the shop', () {
      // There is no shop -> rider route in this slice.
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          acting: riderA,
        ).denial,
        CustodyDenial.notCurrentAcceptedPicker,
      );
    });

    test('a stale picker assignmentId or generation is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          assignmentId: pickAsgB,
        ).denial,
        CustodyDenial.assignmentIdMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          generation: 2,
        ).denial,
        CustodyDenial.generationMismatch,
      );
    });

    test('pickup after a picker revoke is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordShopPickup,
          picker: pickerSlot(state: AssignmentState.revoked),
        ).denial,
        CustodyDenial.noAcceptedPickerAssignment,
      );
    });
  });

  group('picker -> rider receipt', () {
    CustodyTransition receipt() =>
        allowedCustody(runCustody(CustodyCommand.recordRiderReceipt));

    test('the accepted rider records receipt', () {
      final CustodyTransition t = receipt();
      expect(t.fromHolder.kind, CustodyHolderKind.picker);
      expect(t.toHolder.kind, CustodyHolderKind.rider);
      expect(t.toHolder.principalId, riderA);
      expect(t.toHolder.assignmentId, rideAsgA);
      expect(t.resultingCustodyRevision, 3);
    });

    test('receipt uses the existing rider.custody.record_receipt permission', () {
      expect(
        CustodyCommand.recordRiderReceipt.requiredPermission,
        Permission.riderRecordCustodyReceipt,
      );
      final PermissionRule r =
          permissionMatrix[Permission.riderRecordCustodyReceipt]!;
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.rider});
      expect(r.scopes, contains(ScopeRequirement.assignedResource));
    });

    test('receipt is the dispatch boundary: ready -> in_delivery', () {
      final CustodyTransition t = receipt();
      expect(t.orderEffect.changesOrder, isTrue);
      expect(t.orderEffect.toState, OrderState.inDelivery);
      expect(t.orderEffect.resultingOrderRevision, 5, reason: 'order 4 -> 5');
    });

    test('receipt completes the picker assignment', () {
      final PickerAssignmentCompletionEffect c = receipt().pickerCompletion!;
      expect(c.assignmentId, pickAsgA);
      expect(c.generation, 1);
      expect(c.resultingSlotRevision, 3, reason: 'picker slot 2 -> 3');
      expect(c.offerRecipientPrincipalId, pickerA);
      expect(c.acceptedAssigneePrincipalId, pickerA);
    });

    test('picker assigned scope is removed, rider keeps theirs', () {
      final ScopeProjectionEffect e = receipt().scopeEffect;
      expect(e.removeFromAssigned, <String>{pickerA});
      expect(e.addToAssigned, isEmpty);
      expect(e.removeFromOffered, isEmpty);
      expect(e.addToOffered, isEmpty);
    });

    test('the rider assignment stays accepted and active', () {
      // Nothing in the transition touches the rider slot.
      final CustodyTransition t = receipt();
      expect(t.toHolder.kind, CustodyHolderKind.rider);
      final RiderAssignmentFacts rider = riderSlot();
      expect(rider.attempt!.state, AssignmentState.accepted);
      expect(rider.activeAcceptedCount, 1);
    });

    test('all three facts share one command causation', () {
      expect(receipt().events, <String>[
        'custody.transferred_to_rider',
        'picker.assignment.completed',
        'order.in_delivery',
      ]);
    });

    test('receipt has no inventory or financial effect', () {
      final CustodyTransition t = receipt();
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
    });

    test('the reservation stays committed — dispatch restores no stock', () {
      final OrderLifecycleFacts before = orderFacts();
      final OrderLifecycleFacts after = applyOrder(receipt(), before);
      expect(after.state, OrderState.inDelivery);
      expect(after.reservationState, ReservationState.committed);
      expect(after.reservedUnits, before.reservedUnits);
    });

    test('receipt before pickup is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: atShop(),
          expectedCustodyRevision: 1,
        ).denial,
        CustodyDenial.wrongCustodyHolder,
      );
    });

    test('a different rider cannot receive', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          acting: riderB,
        ).denial,
        CustodyDenial.notCurrentAcceptedRider,
      );
    });

    test('there must be an accepted rider assignment', () {
      for (final AssignmentState? s in <AssignmentState?>[
        null,
        AssignmentState.offered,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        expect(
          runCustody(
            CustodyCommand.recordRiderReceipt,
            rider: riderSlot(state: s),
          ).denial,
          CustodyDenial.noAcceptedRiderAssignment,
          reason: 'rider ${s?.id ?? 'absent'}',
        );
      }
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          omitRider: true,
        ).denial,
        CustodyDenial.noAcceptedRiderAssignment,
      );
    });

    test('a stale rider assignmentId or generation is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          assignmentId: rideAsgB,
        ).denial,
        CustodyDenial.assignmentIdMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          generation: 2,
        ).denial,
        CustodyDenial.generationMismatch,
      );
    });

    test('receipt after a rider revoke is refused', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          rider: riderSlot(state: AssignmentState.revoked),
        ).denial,
        CustodyDenial.noAcceptedRiderAssignment,
      );
    });

    test('custody bound to a replaced picker attempt is refused', () {
      // Goods collected under picker attempt A must not be handed over as
      // though attempt B had collected them.
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withPicker(assignmentId: pickAsgB),
          picker: pickerSlot(),
        ).denial,
        CustodyDenial.custodyHolderBindingMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withPicker(principalId: pickerB),
          picker: pickerSlot(),
        ).denial,
        CustodyDenial.custodyHolderBindingMismatch,
      );
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withPicker(generation: 2),
          picker: pickerSlot(),
        ).denial,
        CustodyDenial.custodyHolderBindingMismatch,
      );
    });

    test('a stale SourcePickerBinding is refused', () {
      // The rider was offered by picker A; custody and the picker slot now name
      // attempt B. The rider must not take delivery as though B had arranged it.
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: withPicker(
            principalId: pickerB,
            assignmentId: pickAsgB,
            generation: 2,
          ),
          picker: pickerSlot(
            principalId: pickerB,
            assignmentId: pickAsgB,
            generation: 2,
          ),
          rider: riderSlot(),
        ).denial,
        CustodyDenial.sourcePickerAssignmentMismatch,
      );
    });

    test('the picker assignment must still be accepted', () {
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          picker: pickerSlot(state: AssignmentState.revoked),
        ).denial,
        CustodyDenial.noAcceptedPickerAssignment,
      );
    });
  });

  group('no route this slice does not own', () {
    test('there is no shop -> rider custody transition', () {
      // A rider acting on shop custody has nothing to receive from a picker.
      expect(
        runCustody(
          CustodyCommand.recordRiderReceipt,
          custody: atShop(),
          expectedCustodyRevision: 1,
          acting: riderA,
        ).denial,
        CustodyDenial.wrongCustodyHolder,
      );
    });

    test('agent.assignment.offer_rider authorizes no custody command', () {
      for (final CustodyCommand c in CustodyCommand.values) {
        expect(
          c.requiredPermission,
          isNot(Permission.agentOfferRiderAssignment),
        );
      }
      // ...and it is still reserved, still mapped by nothing executable.
      expect(
        Permission.byId('agent.assignment.offer_rider'),
        Permission.agentOfferRiderAssignment,
      );
      expect(
        AssignmentCommand.values
            .where((AssignmentCommand a) =>
                a.requiredPermission == Permission.agentOfferRiderAssignment)
            .length,
        0,
      );
    });

    test('picker.custody.record_handoff exists but is not executable', () {
      // It keeps its id and scope. Making it transfer custody would need a
      // sender/receiver proof protocol, and none was invented.
      expect(
        Permission.byId('picker.custody.record_handoff'),
        Permission.pickerRecordHandoffToRider,
      );
      expect(
        permissionMatrix.containsKey(Permission.pickerRecordHandoffToRider),
        isTrue,
      );
      for (final CustodyCommand c in CustodyCommand.values) {
        expect(
          c.requiredPermission,
          isNot(Permission.pickerRecordHandoffToRider),
        );
      }
    });

    test('no admin permission touches custody', () {
      for (final Permission p in Permission.values) {
        if (!p.id.startsWith('admin.')) {
          continue;
        }
        expect(p.id, isNot(contains('custody')));
      }
      const String reserved = 'admin.custody.override';
      expect(Permission.byId(reserved), isNull);
    });

    test('customer custody is unreachable', () {
      final Set<CustodyHolderKind> produced = <CustodyHolderKind>{};
      for (final CustodyCommand c in CustodyCommand.values) {
        final CustodyOutcome o = runCustody(c);
        if (o.transition != null) {
          produced.add(o.transition!.toHolder.kind);
        }
      }
      expect(produced.contains(CustodyHolderKind.customer), isFalse);
      expect(produced, isNotEmpty);
    });

    test('no numeric timeout or proof mechanism was invented', () {
      // Custody acquisition is not time-driven and carries no proof material.
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordShopPickup),
      );
      final String s = t.toString();
      for (final String forbidden in <String>[
        'Duration',
        'DateTime',
        'otp',
        'qr',
        'signature',
        'photo',
      ]) {
        expect(s.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
      }
    });
  });
}
