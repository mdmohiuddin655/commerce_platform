import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/attempt_return_fixtures.dart';

ReturnOutcome beginTransit({
  int expectedReturnRevision = 2,
  int expectedOrderRevision = 7,
  AuthorizationGrant? grant,
  Principal? actor,
  CustodyResourceContext? resource,
  DeliveryAttemptFacts? attemptFacts,
  ReturnFacts? returnFacts,
  AttemptReturnOrderRead? order,
  CustodyFacts? custody,
  bool custodyPresent = true,
  DateTime? at,
}) => evaluateBeginReturnTransit(
  request: ReturnBeginTransitRequest(
    expectedReturnRevision: expectedReturnRevision,
    expectedOrderRevision: expectedOrderRevision,
    recordedAtUtc: at ?? utcNow,
  ),
  grant: grant ?? adminReturnGrant(),
  actor: actor ?? user(adminId),
  resource: resource ?? resourceContext(),
  attempt:
      attemptFacts ?? attempt(revision: 3, state: DeliveryAttemptState.refused),
  returnRecord:
      returnFacts ?? returnRecord(revision: 2, state: ReturnState.required),
  orderRead: order ?? orderRead(),
  custody: custodyPresent ? (custody ?? riderCustody()) : null,
);

ReturnOutcome shopReceipt({
  int expectedReturnRevision = 3,
  int expectedCustodyRevision = 4,
  int expectedRiderSlotRevision = 2,
  int expectedOrderRevision = 7,
  AuthorizationGrant? grant,
  Principal? actor,
  CustodyResourceContext? resource,
  ReturnFacts? returnFacts,
  AttemptReturnOrderRead? order,
  CustodyFacts? custody,
  RiderAssignmentFacts? rider,
  bool riderPresent = true,
  DateTime? at,
}) => evaluateRecordReturnShopReceipt(
  request: ReturnShopReceiptRequest(
    expectedReturnRevision: expectedReturnRevision,
    expectedOrderRevision: expectedOrderRevision,
    expectedCustodyRevision: expectedCustodyRevision,
    expectedRiderSlotRevision: expectedRiderSlotRevision,
    recordedAtUtc: at ?? utcNow,
  ),
  grant: grant ?? agentReceiptGrant(),
  actor: actor ?? user(agentId),
  resource: resource ?? resourceContext(),
  returnRecord:
      returnFacts ?? returnRecord(revision: 3, state: ReturnState.inTransit),
  orderRead: order ?? orderRead(),
  custody: custody ?? riderCustody(),
  riderAssignment: riderPresent ? (rider ?? riderAssignment()) : null,
);

ReturnOutcome inspect({
  ReturnDisposition disposition = ReturnDisposition.restockable,
  int expectedReturnRevision = 4,
  int expectedOrderRevision = 7,
  AuthorizationGrant? grant,
  Principal? actor,
  ReturnFacts? returnFacts,
  AttemptReturnOrderRead? order,
  CustodyFacts? custody,
  CustodyResourceContext? resource,
}) => evaluateRecordReturnInspection(
  request: ReturnInspectionRequest(
    expectedReturnRevision: expectedReturnRevision,
    expectedOrderRevision: expectedOrderRevision,
    disposition: disposition,
    recordedAtUtc: utcNow,
  ),
  grant: grant ?? adminReturnGrant(),
  actor: actor ?? user(adminId),
  resource: resource ?? resourceContext(),
  returnRecord:
      returnFacts ?? returnRecord(revision: 4, state: ReturnState.received),
  orderRead: order ?? orderRead(),
  custody: custody ?? shopCustody(),
);

ReturnOutcome close({
  int expectedReturnRevision = 5,
  int expectedOrderRevision = 8,
  ReturnFacts? returnFacts,
  AttemptReturnOrderRead? order,
}) => evaluateCloseReturn(
  request: ReturnCloseRequest(
    expectedReturnRevision: expectedReturnRevision,
    expectedOrderRevision: expectedOrderRevision,
    recordedAtUtc: utcNow,
  ),
  grant: adminReturnGrant(),
  actor: user(adminId),
  resource: resourceContext(),
  returnRecord:
      returnFacts ??
      returnRecord(
        revision: 5,
        state: ReturnState.inspected,
        disposition: ReturnDisposition.restockable,
      ),
  orderRead:
      order ?? orderRead(revision: 8, reservation: ReservationState.returned),
);

void main() {
  group('RET — required -> in_transit', () {
    test('is allowed and moves nothing physical', () {
      final ReturnOutcome o = beginTransit();
      expect(o.allowed, isTrue);
      final ReturnTransition t = o.transition!;
      expect(t.fromState, ReturnState.required);
      expect(t.toState, ReturnState.inTransit);
      expect(t.resultingReturnRevision, 3);
      // Custody stays with the rider — intent changed, not possession.
      expect(t.changesCustody, isFalse);
      expect(t.custodyEffect, isNull);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.reservationEffect, isNull);
      expect(t.events, <String>[ReturnEventType.inTransit]);
    });

    test('only a canonical refusal opens this route', () {
      for (final DeliveryAttemptState s in <DeliveryAttemptState>[
        DeliveryAttemptState.pending,
        DeliveryAttemptState.outForDelivery,
        DeliveryAttemptState.failed,
      ]) {
        final ReturnOutcome o = beginTransit(
          attemptFacts: attempt(revision: 3, state: s),
        );
        expect(o.allowed, isFalse, reason: s.id);
        expect(o.denial, AttemptReturnDenial.attemptNotInRequiredState);
      }
    });

    test('the goods must still be with the rider', () {
      expect(
        beginTransit(custody: shopCustody()).denial,
        AttemptReturnDenial.custodyNotWithRider,
      );
      expect(
        beginTransit(custodyPresent: false).denial,
        AttemptReturnDenial.custodyNotInitialised,
      );
    });

    test('cannot act from any return state but required', () {
      for (final ReturnState s in <ReturnState>[
        ReturnState.notRequired,
        ReturnState.inTransit,
        ReturnState.received,
      ]) {
        expect(
          beginTransit(returnFacts: returnRecord(revision: 2, state: s)).denial,
          AttemptReturnDenial.returnNotInRequiredState,
          reason: s.id,
        );
      }
    });
  });

  group('RET — in_transit -> received moves custody exactly once', () {
    test('custody goes rider -> shop, one revision', () {
      final ReturnOutcome o = shopReceipt();
      expect(o.allowed, isTrue);
      final ReturnTransition t = o.transition!;
      expect(t.toState, ReturnState.received);
      expect(t.resultingReturnRevision, 4);
      final ReturnCustodyEffect c = t.custodyEffect!;
      expect(c.fromHolder.kind, CustodyHolderKind.rider);
      expect(c.toHolder.kind, CustodyHolderKind.shop);
      expect(c.toHolder.shopId, shopId);
      // Exactly one increment — 4 -> 5.
      expect(c.resultingCustodyRevision, 5);
      expect(t.events, <String>[ReturnEventType.receivedAtShop]);
    });

    test('receipt restores NO stock — that is why inspection exists', () {
      final ReturnTransition t = shopReceipt().transition!;
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.reservationEffect, isNull);
      expect(t.restoresStock, isFalse);
    });

    test('custody must be held by the exact accepted rider attempt', () {
      expect(
        shopReceipt(
          custody: riderCustody(assignmentId: 'rasg_OTHER7xKq2mW9tLp'),
        ).denial,
        AttemptReturnDenial.custodyHolderBindingMismatch,
      );
      expect(
        shopReceipt(custody: riderCustody(generation: 2)).denial,
        AttemptReturnDenial.custodyHolderBindingMismatch,
      );
      expect(
        shopReceipt(custody: riderCustody(principalId: otherRiderId)).denial,
        AttemptReturnDenial.custodyHolderBindingMismatch,
      );
    });

    test('a revoked or unaccepted rider assignment fails closed', () {
      expect(
        shopReceipt(riderPresent: false).denial,
        AttemptReturnDenial.noAcceptedRiderAssignment,
      );
      // A genuinely canonical revoked attempt: generation 1 + `revoked` has
      // slot revision exactly 3, so this exercises the accepted-state check
      // rather than tripping the aggregate validator first.
      expect(
        shopReceipt(
          rider: riderAssignment(
            state: AssignmentState.revoked,
            slotRevision: 3,
            // The historical assignee stays recorded after revocation — that
            // is the canonical shape, and it is what makes this test prove the
            // *state* check rather than an aggregate error.
            accepted: true,
          ),
          expectedRiderSlotRevision: 3,
        ).denial,
        AttemptReturnDenial.noAcceptedRiderAssignment,
      );
      // An attempt merely offered is not an accepted one either.
      expect(
        shopReceipt(
          rider: riderAssignment(
            state: AssignmentState.offered,
            slotRevision: 1,
            accepted: false,
          ),
          expectedRiderSlotRevision: 1,
        ).denial,
        AttemptReturnDenial.noAcceptedRiderAssignment,
      );
    });

    test('a replayed receipt cannot move custody twice', () {
      // The return has already advanced past in_transit.
      final ReturnOutcome o = shopReceipt(
        returnFacts: returnRecord(revision: 4, state: ReturnState.received),
        expectedReturnRevision: 4,
      );
      expect(o.allowed, isFalse);
      expect(o.denial, AttemptReturnDenial.returnNotInRequiredState);
    });

    test('custody and return revisions are both compare-and-set', () {
      expect(
        shopReceipt(expectedCustodyRevision: 99).denial,
        AttemptReturnDenial.custodyRevisionConflict,
      );
      expect(
        shopReceipt(expectedReturnRevision: 99).denial,
        AttemptReturnDenial.returnRevisionConflict,
      );
      expect(
        shopReceipt(expectedRiderSlotRevision: 99).denial,
        AttemptReturnDenial.riderSlotRevisionConflict,
      );
    });
  });

  group('RET — received -> inspected is the only stock boundary', () {
    test('restockable restores the reserved units exactly once', () {
      final ReturnOutcome o = inspect();
      expect(o.allowed, isTrue);
      final ReturnTransition t = o.transition!;
      expect(t.toState, ReturnState.inspected);
      expect(t.inventoryEffect.kind, InventoryEffectKind.restoreReservedUnits);
      expect(t.inventoryEffect.units, 3);
      expect(t.inventoryEffect.availableStockDelta, 3);
      expect(t.restoresStock, isTrue);
      // The reservation ends as `returned`, never `released`.
      final ReservationReturnEffect r = t.reservationEffect!;
      expect(r.fromState, ReservationState.committed);
      expect(r.toState, ReservationState.returned);
      expect(r.disposition, ReturnDisposition.restockable);
      expect(r.units, 3);
      expect(t.events, <String>[
        ReturnEventType.inspected,
        ReturnEventType.stockRestored,
      ]);
    });

    test('damaged and quarantined never increase available stock', () {
      for (final ReturnDisposition d in <ReturnDisposition>[
        ReturnDisposition.damaged,
        ReturnDisposition.quarantined,
      ]) {
        final ReturnTransition t = inspect(disposition: d).transition!;
        expect(t.inventoryEffect.kind, InventoryEffectKind.none, reason: d.id);
        expect(t.inventoryEffect.availableStockDelta, 0, reason: d.id);
        expect(t.restoresStock, isFalse, reason: d.id);
        // The reservation still ends — the goods are not coming back to this
        // order — but no stock is created.
        expect(t.reservationEffect!.toState, ReservationState.returned);
        expect(t.reservationEffect!.restoresAvailableStock, isFalse);
        // No stock-restored event is emitted, so no reader can infer one.
        expect(t.events, <String>[ReturnEventType.inspected]);
      }
    });

    test('inspection requires the shop to actually hold the goods', () {
      // A `received` return whose custody is still with a rider is a torn
      // read; restoring from it would credit a shelf nobody filled.
      expect(
        inspect(custody: riderCustody()).denial,
        AttemptReturnDenial.custodyNotAtShop,
      );
      // And it must be *this* order's shop.
      expect(
        inspect(custody: shopCustody(shop: otherShopId)).denial,
        AttemptReturnDenial.shopBindingMismatch,
      );
    });

    test('inspection cannot precede receipt', () {
      for (final ReturnState s in <ReturnState>[
        ReturnState.notRequired,
        ReturnState.required,
        ReturnState.inTransit,
      ]) {
        expect(
          inspect(returnFacts: returnRecord(revision: 4, state: s)).denial,
          AttemptReturnDenial.returnNotInRequiredState,
          reason: s.id,
        );
      }
    });

    test('a replayed inspection cannot restore a second time', () {
      // Replay 1: the return has already moved past `received`.
      expect(
        inspect(
          returnFacts: returnRecord(
            revision: 5,
            state: ReturnState.inspected,
            disposition: ReturnDisposition.restockable,
          ),
          expectedReturnRevision: 5,
        ).denial,
        AttemptReturnDenial.returnNotInRequiredState,
      );
      // Replay 2: independently, the reservation is already terminal, so even
      // a forged `received` return cannot restore again.
      expect(
        inspect(order: orderRead(reservation: ReservationState.returned))
            .denial,
        AttemptReturnDenial.reservationNotCommitted,
      );
    });
  });

  group('RET — inspected -> closed', () {
    test('is allowed and restores nothing', () {
      final ReturnOutcome o = close();
      expect(o.allowed, isTrue);
      final ReturnTransition t = o.transition!;
      expect(t.toState, ReturnState.closed);
      expect(t.resultingReturnRevision, 6);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.reservationEffect, isNull);
      expect(t.custodyEffect, isNull);
      expect(t.restoresStock, isFalse);
      expect(t.events, <String>[ReturnEventType.closed]);
    });

    test('closing requires the reservation to be already returned', () {
      // The second guard against a double restore: closing can never be the
      // transition that ends a live reservation.
      expect(
        close(order: orderRead(revision: 8)).denial,
        AttemptReturnDenial.reservationNotReturned,
      );
    });

    test('cannot close twice', () {
      expect(
        close(
          returnFacts: returnRecord(
            revision: 5,
            state: ReturnState.closed,
            disposition: ReturnDisposition.restockable,
          ),
        ).denial,
        AttemptReturnDenial.returnNotInRequiredState,
      );
    });
  });

  group('RET — the full refused-order path end to end', () {
    test('required -> in_transit -> received -> inspected -> closed', () {
      // Walk the real evaluators, threading each transition's resulting
      // revisions into the next step exactly as a backend would.
      final ReturnTransition t1 = beginTransit().transition!;
      expect(t1.toState, ReturnState.inTransit);

      final ReturnTransition t2 = shopReceipt(
        expectedReturnRevision: t1.resultingReturnRevision,
        returnFacts: returnRecord(
          revision: t1.resultingReturnRevision,
          state: t1.toState,
        ),
      ).transition!;
      expect(t2.toState, ReturnState.received);
      expect(t2.custodyEffect!.resultingCustodyRevision, 5);

      final ReturnTransition t3 = inspect(
        expectedReturnRevision: t2.resultingReturnRevision,
        returnFacts: returnRecord(
          revision: t2.resultingReturnRevision,
          state: t2.toState,
        ),
        custody: shopCustody(
          revision: t2.custodyEffect!.resultingCustodyRevision,
        ),
      ).transition!;
      expect(t3.toState, ReturnState.inspected);
      expect(t3.inventoryEffect.availableStockDelta, 3);

      final ReturnTransition t4 = close(
        expectedReturnRevision: t3.resultingReturnRevision,
        returnFacts: returnRecord(
          revision: t3.resultingReturnRevision,
          state: t3.toState,
          disposition: ReturnDisposition.restockable,
        ),
        order: orderRead(revision: 7, reservation: ReservationState.returned),
        expectedOrderRevision: 7,
      ).transition!;
      expect(t4.toState, ReturnState.closed);

      // Stock moved exactly once across the whole path.
      final int totalDelta = <ReturnTransition>[t1, t2, t3, t4]
          .map((ReturnTransition t) => t.inventoryEffect.availableStockDelta)
          .reduce((int a, int b) => a + b);
      expect(totalDelta, 3, reason: 'three units restored, once');

      // Custody moved exactly once across the whole path.
      expect(
        <ReturnTransition>[
          t1,
          t2,
          t3,
          t4,
        ].where((ReturnTransition t) => t.changesCustody).length,
        1,
      );
    });
  });
}
