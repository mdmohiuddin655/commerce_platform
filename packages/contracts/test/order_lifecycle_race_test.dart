import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

const int units = 3;

OrderLifecycleFacts facts({
  OrderState state = OrderState.placed,
  int revision = 1,
  ReservationState? reservation = ReservationState.active,
}) => OrderLifecycleFacts(
  state: state,
  revision: revision,
  reservationState: reservation,
  reservedUnits: units,
);

LifecycleOutcome run(
  LifecycleCommand command, {
  OrderLifecycleFacts? on,
  int? expectedRevision,
}) {
  final OrderLifecycleFacts f = on ?? facts();
  return evaluateOrderTransition(
    request: LifecycleRequest(
      command: command,
      expectedRevision: expectedRevision ?? f.revision,
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

/// Applies a transition to produce the next trusted facts, the way a backend
/// would after committing.
OrderLifecycleFacts apply(LifecycleTransition t) => OrderLifecycleFacts(
  state: t.toState,
  revision: t.resultingRevision,
  reservationState: t.toReservation,
  reservedUnits: units,
);

void main() {
  group('cancellation — executable sources', () {
    test('placed cancels and restores stock exactly once', () {
      final LifecycleTransition t = allowed(run(LifecycleCommand.cancelOrder));

      expect(t.toState, OrderState.cancelled);
      expect(t.fromReservation, ReservationState.active);
      expect(t.toReservation, ReservationState.released);
      expect(t.inventoryEffect.kind, InventoryEffectKind.restoreReservedUnits);
      expect(t.inventoryEffect.availableStockDelta, units);
      expect(t.eventType, LifecycleEventType.orderCancelled);
    });

    test('accepted cancels and restores its committed allocation once', () {
      final LifecycleTransition t = allowed(
        run(
          LifecycleCommand.cancelOrder,
          on: facts(
            state: OrderState.accepted,
            revision: 2,
            reservation: ReservationState.committed,
          ),
        ),
      );

      expect(t.toState, OrderState.cancelled);
      expect(t.fromReservation, ReservationState.committed);
      expect(t.toReservation, ReservationState.released);
      expect(t.inventoryEffect.availableStockDelta, units);
    });

    test('no cancellation fee is invented — deferred, not zero', () {
      for (final OrderLifecycleFacts f in <OrderLifecycleFacts>[
        facts(),
        facts(
          state: OrderState.accepted,
          revision: 2,
          reservation: ReservationState.committed,
        ),
      ]) {
        expect(
          allowed(run(LifecycleCommand.cancelOrder, on: f))
              .financialClassification,
          FinancialClassification.deferredToFinancialSlice,
        );
      }
    });

    test('a duplicate cancellation cannot restore twice', () {
      final LifecycleTransition first = allowed(
        run(LifecycleCommand.cancelOrder),
      );
      final LifecycleOutcome second = run(
        LifecycleCommand.cancelOrder,
        on: apply(first),
      );

      expect(second.allowed, isFalse);
      expect(second.denial, LifecycleDenial.alreadyTerminal);
      expect(second.transition, isNull);
    });
  });

  group('cancellation — policy-deferred sources', () {
    test('preparing is policy-deferred, not silently allowed or denied', () {
      final LifecycleOutcome o = run(
        LifecycleCommand.cancelOrder,
        on: facts(
          state: OrderState.preparing,
          revision: 3,
          reservation: ReservationState.committed,
        ),
      );

      expect(o.allowed, isFalse);
      expect(
        o.denial,
        LifecycleDenial.policyDeferred,
        reason: 'distinguishable from "never allowed" so nobody guesses it',
      );
    });

    test('ready is policy-deferred', () {
      expect(
        run(
          LifecycleCommand.cancelOrder,
          on: facts(
            state: OrderState.ready,
            revision: 4,
            reservation: ReservationState.committed,
          ),
        ).denial,
        LifecycleDenial.policyDeferred,
      );
    });

    test('the two source sets are disjoint and cover the pre-dispatch path', () {
      expect(
        executableCancellationSources
            .intersection(policyDeferredCancellationSources),
        isEmpty,
      );
      expect(
        <OrderState>{
          ...executableCancellationSources,
          ...policyDeferredCancellationSources,
        },
        <OrderState>{
          OrderState.placed,
          OrderState.accepted,
          OrderState.preparing,
          OrderState.ready,
        },
      );
    });

    test('a policy-deferred denial produces no inventory effect', () {
      expect(
        run(
          LifecycleCommand.cancelOrder,
          on: facts(
            state: OrderState.ready,
            revision: 4,
            reservation: ReservationState.committed,
          ),
        ).transition,
        isNull,
      );
    });
  });

  group('reservation expiry', () {
    test('an active reservation expires and restores stock once', () {
      final LifecycleTransition t = allowed(
        run(LifecycleCommand.expireReservation),
      );

      expect(t.fromReservation, ReservationState.active);
      expect(t.toReservation, ReservationState.expired);
      expect(t.inventoryEffect.availableStockDelta, units);
      expect(t.eventType, LifecycleEventType.reservationExpired);
      expect(
        t.toState,
        OrderState.placed,
        reason: 'the reservation ends; the order simply becomes unacceptable',
      );
    });

    test('expiry is worker-driven and borrows no human permission', () {
      expect(LifecycleCommand.expireReservation.isWorkerDriven, isTrue);
      expect(LifecycleCommand.expireReservation.requiredPermission, isNull);
      for (final LifecycleCommand c in LifecycleCommand.values) {
        if (c != LifecycleCommand.expireReservation) {
          expect(c.requiredPermission, isNotNull, reason: c.commandType);
        }
      }
    });

    test('a retried expiry worker cannot restore again', () {
      final LifecycleTransition first = allowed(
        run(LifecycleCommand.expireReservation),
      );
      final LifecycleOutcome retry = run(
        LifecycleCommand.expireReservation,
        on: apply(first),
      );

      expect(retry.allowed, isFalse);
      expect(retry.denial, LifecycleDenial.reservationAlreadyFinal);
      expect(retry.transition, isNull);
    });

    test('expiry cannot touch an already released reservation', () {
      expect(
        run(
          LifecycleCommand.expireReservation,
          on: facts(reservation: ReservationState.released),
        ).denial,
        LifecycleDenial.reservationAlreadyFinal,
      );
    });
  });

  group('acceptance versus expiry race', () {
    test('CASE 1 — acceptance commits first, later expiry restores nothing', () {
      final LifecycleTransition accept = allowed(
        run(LifecycleCommand.acceptOrder),
      );
      expect(accept.toReservation, ReservationState.committed);

      final LifecycleOutcome lateExpiry = run(
        LifecycleCommand.expireReservation,
        on: apply(accept),
      );

      expect(lateExpiry.allowed, isFalse);
      expect(
        lateExpiry.denial,
        LifecycleDenial.wrongSourceState,
        reason: 'the order is accepted, so expiry has no placed order to act on',
      );
      expect(lateExpiry.transition, isNull);
    });

    test('CASE 2 — expiry wins first, later acceptance is denied', () {
      final LifecycleTransition expiry = allowed(
        run(LifecycleCommand.expireReservation),
      );
      expect(expiry.inventoryEffect.availableStockDelta, units);

      final LifecycleOutcome lateAccept = run(
        LifecycleCommand.acceptOrder,
        on: apply(expiry),
      );

      expect(lateAccept.allowed, isFalse);
      expect(lateAccept.denial, LifecycleDenial.reservationAlreadyFinal);
    });

    test('stock is conserved in both orderings — never restored twice', () {
      int deltaOf(List<LifecycleTransition> ts) =>
          ts.fold(0, (int a, LifecycleTransition t) =>
              a + t.inventoryEffect.availableStockDelta);

      // Ordering A: accept then attempt expiry.
      final LifecycleTransition a1 = allowed(run(LifecycleCommand.acceptOrder));
      final LifecycleOutcome a2 = run(
        LifecycleCommand.expireReservation,
        on: apply(a1),
      );
      final List<LifecycleTransition> orderingA = <LifecycleTransition>[
        a1,
        if (a2.transition != null) a2.transition!,
      ];

      // Ordering B: expire then attempt accept.
      final LifecycleTransition b1 = allowed(
        run(LifecycleCommand.expireReservation),
      );
      final LifecycleOutcome b2 = run(
        LifecycleCommand.acceptOrder,
        on: apply(b1),
      );
      final List<LifecycleTransition> orderingB = <LifecycleTransition>[
        b1,
        if (b2.transition != null) b2.transition!,
      ];

      // Exactly one side effect each: accepted keeps the units held (0),
      // expired gives them back once (+units). Never both.
      expect(deltaOf(orderingA), 0, reason: 'accepted order keeps its stock');
      expect(deltaOf(orderingB), units, reason: 'restored exactly once');
      expect(orderingA.length, 1);
      expect(orderingB.length, 1);
    });

    test('an accepted order and a restored reservation cannot coexist', () {
      // The structural guarantee: reaching `accepted` requires an `active`
      // reservation, and acceptance moves it to `committed`, which is not
      // expirable. There is no path producing both.
      final LifecycleTransition accept = allowed(
        run(LifecycleCommand.acceptOrder),
      );
      final OrderLifecycleFacts after = apply(accept);

      expect(after.state, OrderState.accepted);
      expect(after.reservationState, ReservationState.committed);
      expect(after.reservationState!.isExpirable, isFalse);
      expect(after.reservationState!.holdsUnits, isTrue);
    });
  });
}
