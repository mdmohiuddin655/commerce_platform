import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

const int units = 3;

OrderLifecycleFacts facts({
  OrderState state = OrderState.placed,
  int revision = 1,
  ReservationState? reservation = ReservationState.active,
  int reserved = units,
}) => OrderLifecycleFacts(
  state: state,
  revision: revision,
  reservationState: reservation,
  reservedUnits: reserved,
);

LifecycleOutcome run(
  LifecycleCommand command, {
  OrderLifecycleFacts? on,
  int? expectedRevision,
  int requestedUnits = units,
  bool reservationSecured = true,
}) {
  final OrderLifecycleFacts f = on ?? facts();
  return evaluateOrderTransition(
    request: LifecycleRequest(
      command: command,
      expectedRevision: expectedRevision ?? f.revision,
      requestedUnits: requestedUnits,
      reservationSecured: reservationSecured,
    ),
    facts: f,
  );
}

LifecycleTransition allowed(LifecycleOutcome o) {
  final LifecycleTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

void main() {
  group('placement', () {
    test('creates a placed order and reserves stock once', () {
      final LifecycleTransition t = allowed(
        run(
          LifecycleCommand.placeOrder,
          on: const OrderLifecycleFacts.absent(),
          expectedRevision: 0,
        ),
      );

      expect(t.fromState, isNull);
      expect(t.toState, OrderState.placed);
      expect(t.resultingRevision, 1);
      expect(t.toReservation, ReservationState.active);
      expect(t.inventoryEffect.kind, InventoryEffectKind.reserveUnits);
      expect(t.inventoryEffect.units, units);
      expect(t.inventoryEffect.availableStockDelta, -units);
      expect(t.eventType, LifecycleEventType.orderPlaced);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
    });

    test('cannot reach placed when stock could not be reserved', () {
      // The invariant: no "placed but unreserved" state exists.
      final LifecycleOutcome o = run(
        LifecycleCommand.placeOrder,
        on: const OrderLifecycleFacts.absent(),
        expectedRevision: 0,
        reservationSecured: false,
      );

      expect(o.allowed, isFalse);
      expect(o.denial, LifecycleDenial.reservationUnavailable);
    });

    test('rejects a non-positive unit count', () {
      expect(
        run(
          LifecycleCommand.placeOrder,
          on: const OrderLifecycleFacts.absent(),
          expectedRevision: 0,
          requestedUnits: 0,
        ).denial,
        LifecycleDenial.reservationUnavailable,
      );
    });

    test('placing over an existing order is a revision conflict', () {
      expect(
        run(LifecycleCommand.placeOrder, expectedRevision: 0).denial,
        LifecycleDenial.revisionConflict,
      );
    });

    test('a stale expected revision for creation is refused', () {
      expect(
        run(
          LifecycleCommand.placeOrder,
          on: const OrderLifecycleFacts.absent(),
          expectedRevision: 7,
        ).denial,
        LifecycleDenial.revisionConflict,
      );
    });
  });

  group('acceptance', () {
    test('placed with an active reservation becomes accepted', () {
      final LifecycleTransition t = allowed(run(LifecycleCommand.acceptOrder));

      expect(t.fromState, OrderState.placed);
      expect(t.toState, OrderState.accepted);
      expect(t.resultingRevision, 2);
      expect(t.fromReservation, ReservationState.active);
      expect(t.toReservation, ReservationState.committed);
      expect(t.eventType, LifecycleEventType.orderAccepted);
    });

    test('does not decrement available stock a second time', () {
      final LifecycleTransition t = allowed(run(LifecycleCommand.acceptOrder));

      expect(t.inventoryEffect.kind, InventoryEffectKind.commitReservedUnits);
      expect(
        t.inventoryEffect.availableStockDelta,
        0,
        reason: 'the decrement already happened at placement',
      );
    });

    test('a stale expected revision is refused', () {
      expect(
        run(LifecycleCommand.acceptOrder, expectedRevision: 99).denial,
        LifecycleDenial.revisionConflict,
      );
    });

    test('an expired reservation cannot be accepted', () {
      expect(
        run(
          LifecycleCommand.acceptOrder,
          on: facts(reservation: ReservationState.expired),
        ).denial,
        LifecycleDenial.reservationAlreadyFinal,
      );
    });

    test('a released reservation cannot be accepted', () {
      expect(
        run(
          LifecycleCommand.acceptOrder,
          on: facts(reservation: ReservationState.released),
        ).denial,
        LifecycleDenial.reservationAlreadyFinal,
      );
    });

    test('a missing reservation cannot be accepted', () {
      expect(
        run(LifecycleCommand.acceptOrder, on: facts(reservation: null)).denial,
        LifecycleDenial.reservationMissing,
      );
    });

    test('accepting twice is refused — the source state is gone', () {
      expect(
        run(
          LifecycleCommand.acceptOrder,
          on: facts(
            state: OrderState.accepted,
            revision: 2,
            reservation: ReservationState.committed,
          ),
        ).denial,
        LifecycleDenial.wrongSourceState,
      );
    });
  });

  group('rejection', () {
    test('placed becomes rejected and restores stock exactly once', () {
      final LifecycleTransition t = allowed(run(LifecycleCommand.rejectOrder));

      expect(t.toState, OrderState.rejected);
      expect(t.toReservation, ReservationState.released);
      expect(t.inventoryEffect.kind, InventoryEffectKind.restoreReservedUnits);
      expect(t.inventoryEffect.availableStockDelta, units);
      expect(t.eventType, LifecycleEventType.orderRejected);
    });

    test('financial effect is deferred, never zero', () {
      expect(
        allowed(run(LifecycleCommand.rejectOrder)).financialClassification,
        FinancialClassification.deferredToFinancialSlice,
      );
    });

    test('a second rejection cannot restore stock again', () {
      // First rejection left the order terminal and the reservation released.
      final LifecycleOutcome second = run(
        LifecycleCommand.rejectOrder,
        on: facts(
          state: OrderState.rejected,
          revision: 2,
          reservation: ReservationState.released,
        ),
      );

      expect(second.allowed, isFalse);
      expect(second.denial, LifecycleDenial.alreadyTerminal);
      expect(second.transition, isNull, reason: 'no inventory effect at all');
    });

    test('an accepted order cannot be rejected', () {
      expect(
        run(
          LifecycleCommand.rejectOrder,
          on: facts(
            state: OrderState.accepted,
            revision: 2,
            reservation: ReservationState.committed,
          ),
        ).denial,
        LifecycleDenial.wrongSourceState,
      );
    });
  });

  group('preparation', () {
    OrderLifecycleFacts acceptedOrder({OrderState state = OrderState.accepted}) =>
        facts(
          state: state,
          revision: 2,
          reservation: ReservationState.committed,
        );

    test('accepted becomes preparing, touching no stock', () {
      final LifecycleTransition t = allowed(
        run(LifecycleCommand.startPreparing, on: acceptedOrder()),
      );

      expect(t.toState, OrderState.preparing);
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.toReservation, ReservationState.committed);
      expect(t.eventType, LifecycleEventType.orderPreparing);
    });

    test('preparing becomes ready, and ready does NOT release stock', () {
      final LifecycleTransition t = allowed(
        run(
          LifecycleCommand.markReady,
          on: acceptedOrder(state: OrderState.preparing),
        ),
      );

      expect(t.toState, OrderState.ready);
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.toReservation, ReservationState.committed);
    });

    test('placed cannot jump straight to ready', () {
      expect(
        run(LifecycleCommand.markReady).denial,
        LifecycleDenial.wrongSourceState,
      );
    });

    test('placed cannot start preparing before acceptance', () {
      expect(
        run(LifecycleCommand.startPreparing).denial,
        LifecycleDenial.wrongSourceState,
      );
    });

    test('ready cannot go backwards to preparing', () {
      expect(
        run(
          LifecycleCommand.startPreparing,
          on: acceptedOrder(state: OrderState.ready),
        ).denial,
        LifecycleDenial.wrongSourceState,
      );
    });

    test('preparation requires the allocation still to belong to the order', () {
      expect(
        run(
          LifecycleCommand.startPreparing,
          on: facts(
            state: OrderState.accepted,
            revision: 2,
            reservation: ReservationState.released,
          ),
        ).denial,
        LifecycleDenial.reservationAlreadyFinal,
      );
    });
  });
}
