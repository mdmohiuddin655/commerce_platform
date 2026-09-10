import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

/// Every case goes through the **public** evaluator, not the validator
/// directly: a guard that can be bypassed by the real entry point proves
/// nothing.
LifecycleOutcome run(
  LifecycleCommand command, {
  OrderState? state,
  int revision = 1,
  ReservationState? reservation,
  int reservedUnits = 3,
  int? expectedRevision,
}) => evaluateOrderTransition(
  request: LifecycleRequest(
    command: command,
    expectedRevision: expectedRevision ?? revision,
    requestedUnits: 3,
    reservationSecured: true,
  ),
  facts: state == null
      ? OrderLifecycleFacts(
          state: null,
          revision: revision,
          reservationState: reservation,
          reservedUnits: reservedUnits,
        )
      : OrderLifecycleFacts(
          state: state,
          revision: revision,
          reservationState: reservation,
          reservedUnits: reservedUnits,
        ),
);

/// Commands that could otherwise produce an inventory effect.
const List<LifecycleCommand> effectProducing = <LifecycleCommand>[
  LifecycleCommand.acceptOrder,
  LifecycleCommand.rejectOrder,
  LifecycleCommand.cancelOrder,
  LifecycleCommand.startPreparing,
  LifecycleCommand.markReady,
  LifecycleCommand.expireReservation,
];

void main() {
  group('canonical pairs are accepted', () {
    test('the table covers every state with a known shape exactly', () {
      // Since FND-003B3A this is `aggregateShapeKnown`, not
      // `executableInThisSlice`: `in_delivery` has a canonical pairing that
      // must be validated even though no pre-dispatch command may act from it.
      expect(
        canonicalAggregatePairs.keys.toSet(),
        OrderState.aggregateShapeKnown,
      );
      // Every executable state still has a pairing — none was dropped.
      expect(
        canonicalAggregatePairs.keys.toSet()
            .containsAll(OrderState.executableInThisSlice),
        isTrue,
      );
      // `delivered` has no defined pairing and must not have acquired one.
      expect(
        canonicalAggregatePairs.containsKey(OrderState.delivered),
        isFalse,
      );
    });

    test('placed + expired stays canonical — it is the expiry-wins outcome', () {
      // If this were treated as corruption, the expiry-first race outcome
      // would break.
      expect(
        validateAggregate(
          const OrderLifecycleFacts(
            state: OrderState.placed,
            revision: 2,
            reservationState: ReservationState.expired,
            reservedUnits: 3,
          ),
        ),
        isNull,
      );
    });

    test('every canonical pair validates', () {
      for (final MapEntry<OrderState, Set<ReservationState>> e
          in canonicalAggregatePairs.entries) {
        for (final ReservationState r in e.value) {
          expect(
            validateAggregate(
              OrderLifecycleFacts(
                state: e.key,
                revision: 1,
                reservationState: r,
                reservedUnits: 1,
              ),
            ),
            isNull,
            reason: '${e.key.id} + ${r.id} must be canonical',
          );
        }
      }
    });
  });

  group('impossible order/reservation pairs fail closed', () {
    final Map<String, List<Object>> malformed = <String, List<Object>>{
      'placed + committed': <Object>[OrderState.placed, ReservationState.committed],
      'placed + released': <Object>[OrderState.placed, ReservationState.released],
      'accepted + active': <Object>[OrderState.accepted, ReservationState.active],
      'accepted + expired': <Object>[OrderState.accepted, ReservationState.expired],
      'accepted + released': <Object>[OrderState.accepted, ReservationState.released],
      'preparing + active': <Object>[OrderState.preparing, ReservationState.active],
      'preparing + expired': <Object>[OrderState.preparing, ReservationState.expired],
      'preparing + released': <Object>[OrderState.preparing, ReservationState.released],
      'ready + active': <Object>[OrderState.ready, ReservationState.active],
      'ready + expired': <Object>[OrderState.ready, ReservationState.expired],
      'ready + released': <Object>[OrderState.ready, ReservationState.released],
      'rejected + active': <Object>[OrderState.rejected, ReservationState.active],
      'rejected + committed': <Object>[OrderState.rejected, ReservationState.committed],
      'rejected + expired': <Object>[OrderState.rejected, ReservationState.expired],
      'cancelled + active': <Object>[OrderState.cancelled, ReservationState.active],
      'cancelled + committed': <Object>[OrderState.cancelled, ReservationState.committed],
      'cancelled + expired': <Object>[OrderState.cancelled, ReservationState.expired],
    };

    for (final MapEntry<String, List<Object>> e in malformed.entries) {
      test('${e.key} produces no transition for any command', () {
        for (final LifecycleCommand c in effectProducing) {
          final LifecycleOutcome o = run(
            c,
            state: e.value[0] as OrderState,
            reservation: e.value[1] as ReservationState,
          );

          expect(
            o.transition,
            isNull,
            reason: '${c.commandType} on ${e.key} produced an effect',
          );
          expect(o.denial, LifecycleDenial.aggregateInconsistent);
        }
      });
    }

    test('an existing order with no reservation record fails closed', () {
      for (final LifecycleCommand c in effectProducing) {
        final LifecycleOutcome o = run(c, state: OrderState.placed);
        expect(o.transition, isNull);
        expect(o.denial, LifecycleDenial.aggregateInconsistent);
      }
    });
  });

  group('revision integrity', () {
    test('an existing order with revision 0 fails closed', () {
      final LifecycleOutcome o = run(
        LifecycleCommand.acceptOrder,
        state: OrderState.placed,
        revision: 0,
        reservation: ReservationState.active,
      );

      expect(o.transition, isNull);
      expect(o.denial, LifecycleDenial.aggregateInconsistent);
    });

    test('an existing order with a negative revision fails closed', () {
      expect(
        run(
          LifecycleCommand.acceptOrder,
          state: OrderState.placed,
          revision: -1,
          reservation: ReservationState.active,
        ).denial,
        LifecycleDenial.aggregateInconsistent,
      );
    });

    test('an absent order carrying a revision fails closed', () {
      // Treating this as absent would place a duplicate order.
      final LifecycleOutcome o = run(
        LifecycleCommand.placeOrder,
        revision: 4,
        reservedUnits: 0,
        expectedRevision: 0,
      );

      expect(o.transition, isNull);
      expect(o.denial, LifecycleDenial.aggregateInconsistent);
    });

    test('an absent order carrying a reservation fails closed', () {
      expect(
        run(
          LifecycleCommand.placeOrder,
          revision: 0,
          reservation: ReservationState.active,
          reservedUnits: 0,
          expectedRevision: 0,
        ).denial,
        LifecycleDenial.aggregateInconsistent,
      );
    });

    test('an absent order carrying reserved units fails closed', () {
      expect(
        run(
          LifecycleCommand.placeOrder,
          revision: 0,
          reservedUnits: 5,
          expectedRevision: 0,
        ).denial,
        LifecycleDenial.aggregateInconsistent,
      );
    });

    test('canonical absence still places normally', () {
      final LifecycleOutcome o = run(
        LifecycleCommand.placeOrder,
        revision: 0,
        reservedUnits: 0,
        expectedRevision: 0,
      );

      expect(o.allowed, isTrue);
      expect(o.transition!.inventoryEffect.availableStockDelta, -3);
    });
  });

  group('reserved-unit integrity — no zero or negative stock mutation', () {
    for (final ReservationState r in <ReservationState>[
      ReservationState.active,
      ReservationState.committed,
    ]) {
      for (final int units in <int>[0, -5]) {
        test('${r.id} reservation with $units units fails closed', () {
          final OrderState state = r == ReservationState.active
              ? OrderState.placed
              : OrderState.accepted;

          for (final LifecycleCommand c in effectProducing) {
            final LifecycleOutcome o = run(
              c,
              state: state,
              revision: 2,
              reservation: r,
              reservedUnits: units,
            );

            expect(
              o.transition,
              isNull,
              reason: '${c.commandType} produced an effect from $units units',
            );
            expect(o.denial, LifecycleDenial.aggregateInconsistent);
          }
        });
      }
    }

    test('a negative unit count never becomes a stock-destroying effect', () {
      // Before FND-003B1-FIX-001 this produced availableDelta = -5, silently
      // destroying stock. Nothing is clamped or absolute-valued: the aggregate
      // is denied outright.
      final LifecycleOutcome o = run(
        LifecycleCommand.rejectOrder,
        state: OrderState.placed,
        reservation: ReservationState.active,
        reservedUnits: -5,
      );

      expect(o.transition, isNull);
      expect(o.denial, LifecycleDenial.aggregateInconsistent);
    });

    test('no reachable transition can emit a non-positive unit effect', () {
      // Sweep every command over every canonical aggregate and assert that
      // any effect touching stock moves a positive number of units.
      for (final MapEntry<OrderState, Set<ReservationState>> e
          in canonicalAggregatePairs.entries) {
        for (final ReservationState r in e.value) {
          for (final LifecycleCommand c in LifecycleCommand.values) {
            final LifecycleOutcome o = run(
              c,
              state: e.key,
              revision: 3,
              reservation: r,
              reservedUnits: 2,
            );
            final LifecycleTransition? t = o.transition;
            if (t == null) {
              continue;
            }
            if (t.inventoryEffect.kind == InventoryEffectKind.none) {
              expect(t.inventoryEffect.availableStockDelta, 0);
            } else {
              expect(
                t.inventoryEffect.units,
                greaterThan(0),
                reason: '${c.commandType} from ${e.key.id}+${r.id}',
              );
            }
          }
        }
      }
    });
  });

  group('future states are corruption-checked, not pair-validated', () {
    test('inDelivery and delivered still report unknownTransition', () {
      // Validating their pairing would mean inventing one. They stay
      // fail-closed as not implemented.
      for (final OrderState future in OrderState.outsideThisSliceEvaluator) {
        for (final LifecycleCommand c in effectProducing) {
          final LifecycleOutcome o = run(
            c,
            state: future,
            revision: 5,
            reservation: ReservationState.committed,
          );

          expect(o.transition, isNull);
          expect(
            o.denial,
            LifecycleDenial.unknownTransition,
            reason: '${c.commandType} from ${future.id}',
          );
        }
      }
    });
  });

  group('denied operations never produce an effect', () {
    // Idempotency itself remains FND-003A's; this asserts only that a denied
    // lifecycle evaluation yields no transition, so nothing can be applied.
    OrderLifecycleFacts placedActive({int revision = 1}) => OrderLifecycleFacts(
      state: OrderState.placed,
      revision: revision,
      reservationState: ReservationState.active,
      reservedUnits: 3,
    );

    LifecycleOutcome evaluate(
      LifecycleCommand c,
      OrderLifecycleFacts f, {
      int? expectedRevision,
    }) => evaluateOrderTransition(
      request: LifecycleRequest(
        command: c,
        expectedRevision: expectedRevision ?? f.revision,
      ),
      facts: f,
    );

    OrderLifecycleFacts applied(LifecycleTransition t) => OrderLifecycleFacts(
      state: t.toState,
      revision: t.resultingRevision,
      reservationState: t.toReservation,
      reservedUnits: 3,
    );

    test('a stale expectedRevision produces no transition', () {
      final LifecycleOutcome o = evaluate(
        LifecycleCommand.acceptOrder,
        placedActive(revision: 4),
        expectedRevision: 3,
      );

      expect(o.transition, isNull);
      expect(o.denial, LifecycleDenial.revisionConflict);
    });

    test('duplicate reject produces no second transition', () {
      final LifecycleTransition first =
          evaluate(LifecycleCommand.rejectOrder, placedActive()).transition!;
      final LifecycleOutcome second =
          evaluate(LifecycleCommand.rejectOrder, applied(first));

      expect(second.transition, isNull);
      expect(second.denial, LifecycleDenial.alreadyTerminal);
    });

    test('duplicate cancel produces no second transition', () {
      final LifecycleTransition first =
          evaluate(LifecycleCommand.cancelOrder, placedActive()).transition!;
      final LifecycleOutcome second =
          evaluate(LifecycleCommand.cancelOrder, applied(first));

      expect(second.transition, isNull);
      expect(second.denial, LifecycleDenial.alreadyTerminal);
    });

    test('a retried expiry worker produces no second transition', () {
      final LifecycleTransition first = evaluate(
        LifecycleCommand.expireReservation,
        placedActive(),
      ).transition!;
      final LifecycleOutcome retry =
          evaluate(LifecycleCommand.expireReservation, applied(first));

      expect(retry.transition, isNull);
      expect(retry.denial, LifecycleDenial.reservationAlreadyFinal);
    });

    test('reject, cancel and accept after expiry all produce no effect', () {
      final OrderLifecycleFacts afterExpiry = applied(
        evaluate(
          LifecycleCommand.expireReservation,
          placedActive(),
        ).transition!,
      );

      for (final LifecycleCommand c in <LifecycleCommand>[
        LifecycleCommand.rejectOrder,
        LifecycleCommand.cancelOrder,
        LifecycleCommand.acceptOrder,
      ]) {
        final LifecycleOutcome o = evaluate(c, afterExpiry);
        expect(o.transition, isNull, reason: c.commandType);
        expect(o.denial, LifecycleDenial.reservationAlreadyFinal);
      }
    });

    test('reordered preparation commands produce no effect', () {
      // markReady arriving before startPreparing.
      final OrderLifecycleFacts accepted = applied(
        evaluate(LifecycleCommand.acceptOrder, placedActive()).transition!,
      );
      final LifecycleOutcome earlyReady =
          evaluate(LifecycleCommand.markReady, accepted);

      expect(earlyReady.transition, isNull);
      expect(earlyReady.denial, LifecycleDenial.wrongSourceState);

      // And startPreparing arriving again after ready.
      final OrderLifecycleFacts preparing = applied(
        evaluate(LifecycleCommand.startPreparing, accepted).transition!,
      );
      final OrderLifecycleFacts ready = applied(
        evaluate(LifecycleCommand.markReady, preparing).transition!,
      );
      final LifecycleOutcome late =
          evaluate(LifecycleCommand.startPreparing, ready);

      expect(late.transition, isNull);
      expect(late.denial, LifecycleDenial.wrongSourceState);
    });

    test('preparing and ready cancellation stay policy-deferred', () {
      // The approved split is unchanged by this fix, and a deferred denial
      // still yields no transition — therefore no financial amount at all.
      final OrderLifecycleFacts accepted = applied(
        evaluate(LifecycleCommand.acceptOrder, placedActive()).transition!,
      );
      final OrderLifecycleFacts preparing = applied(
        evaluate(LifecycleCommand.startPreparing, accepted).transition!,
      );
      final OrderLifecycleFacts ready = applied(
        evaluate(LifecycleCommand.markReady, preparing).transition!,
      );

      for (final OrderLifecycleFacts f in <OrderLifecycleFacts>[
        preparing,
        ready,
      ]) {
        final LifecycleOutcome o = evaluate(LifecycleCommand.cancelOrder, f);
        expect(o.denial, LifecycleDenial.policyDeferred);
        expect(o.transition, isNull);
      }
    });
  });
}
