import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

OrderLifecycleFacts at(
  OrderState state, {
  int revision = 5,
  ReservationState? reservation = ReservationState.committed,
}) => OrderLifecycleFacts(
  state: state,
  revision: revision,
  reservationState: reservation,
  reservedUnits: 2,
);

LifecycleOutcome run(LifecycleCommand command, OrderLifecycleFacts facts) =>
    evaluateOrderTransition(
      request: LifecycleRequest(
        command: command,
        expectedRevision: facts.revision,
        requestedUnits: 2,
        reservationSecured: true,
      ),
      facts: facts,
    );

void main() {
  group('forbidden edges fail closed', () {
    final Map<String, LifecycleOutcome> forbidden = <String, LifecycleOutcome>{
      'rejected -> accepted': run(
        LifecycleCommand.acceptOrder,
        at(OrderState.rejected, reservation: ReservationState.released),
      ),
      'cancelled -> accepted': run(
        LifecycleCommand.acceptOrder,
        at(OrderState.cancelled, reservation: ReservationState.released),
      ),
      'cancelled -> preparing': run(
        LifecycleCommand.startPreparing,
        at(OrderState.cancelled, reservation: ReservationState.released),
      ),
      'rejected -> ready': run(
        LifecycleCommand.markReady,
        at(OrderState.rejected, reservation: ReservationState.released),
      ),
      'preparing -> accepted': run(
        LifecycleCommand.acceptOrder,
        at(OrderState.preparing),
      ),
      'ready -> accepted': run(
        LifecycleCommand.acceptOrder,
        at(OrderState.ready),
      ),
      'accepted -> rejected': run(
        LifecycleCommand.rejectOrder,
        at(OrderState.accepted),
      ),
      'ready -> preparing (backwards)': run(
        LifecycleCommand.startPreparing,
        at(OrderState.ready),
      ),
      'rejected -> cancelled': run(
        LifecycleCommand.cancelOrder,
        at(OrderState.rejected, reservation: ReservationState.released),
      ),
      'cancelled -> rejected': run(
        LifecycleCommand.rejectOrder,
        at(OrderState.cancelled, reservation: ReservationState.released),
      ),
      'expire an accepted order': run(
        LifecycleCommand.expireReservation,
        at(OrderState.accepted),
      ),
    };

    for (final MapEntry<String, LifecycleOutcome> e in forbidden.entries) {
      test('${e.key} is denied and produces no effect', () {
        expect(e.value.allowed, isFalse, reason: e.key);
        expect(e.value.transition, isNull, reason: 'no inventory effect');
        expect(e.value.denial, isNotNull);
      });
    }

    test('terminal states report alreadyTerminal, not a vaguer reason', () {
      for (final OrderState terminal in <OrderState>[
        OrderState.rejected,
        OrderState.cancelled,
      ]) {
        for (final LifecycleCommand c in <LifecycleCommand>[
          LifecycleCommand.acceptOrder,
          LifecycleCommand.rejectOrder,
          LifecycleCommand.startPreparing,
          LifecycleCommand.markReady,
          LifecycleCommand.cancelOrder,
          LifecycleCommand.expireReservation,
        ]) {
          expect(
            run(c, at(terminal, reservation: ReservationState.released)).denial,
            LifecycleDenial.alreadyTerminal,
            reason: '${c.commandType} from ${terminal.id}',
          );
        }
      }
    });
  });

  group('states this slice does not own', () {
    test('states outside this evaluator are declared but not executable', () {
      // Uses `outsideThisSliceEvaluator`, not `notYetImplemented`: since
      // FND-003B3A `in_delivery` IS implemented — by the custody slice — while
      // still being a state no pre-dispatch command may act from. The two
      // claims are different, and only the first belongs here.
      expect(
        OrderState.executableInThisSlice
            .intersection(OrderState.outsideThisSliceEvaluator),
        isEmpty,
      );
      expect(
        <OrderState>{
          ...OrderState.executableInThisSlice,
          ...OrderState.outsideThisSliceEvaluator,
        },
        OrderState.values.toSet(),
      );
      // `notYetImplemented` now means exactly what it says.
      expect(OrderState.notYetImplemented, <OrderState>{OrderState.delivered});
      expect(
        OrderState.notYetImplemented.contains(OrderState.inDelivery),
        isFalse,
        reason: 'in_delivery is implemented by the custody slice',
      );
    });

    test('no transition can act from a future state', () {
      for (final OrderState future in OrderState.outsideThisSliceEvaluator) {
        for (final LifecycleCommand c in LifecycleCommand.values) {
          if (c == LifecycleCommand.placeOrder) {
            continue;
          }
          final LifecycleOutcome o = run(c, at(future));
          expect(o.allowed, isFalse, reason: '${c.commandType} from ${future.id}');
          expect(
            o.denial,
            LifecycleDenial.unknownTransition,
            reason: 'fail closed rather than guess a future edge',
          );
        }
      }
    });

    test('no transition can produce a future state', () {
      // Nothing in this slice may enter in_delivery or delivered.
      final Set<OrderState> reachable = <OrderState>{};
      for (final OrderState from in OrderState.executableInThisSlice) {
        for (final ReservationState? r in <ReservationState?>[
          null,
          ...ReservationState.values,
        ]) {
          for (final LifecycleCommand c in LifecycleCommand.values) {
            final LifecycleOutcome o = run(c, at(from, reservation: r));
            if (o.transition != null) {
              reachable.add(o.transition!.toState);
            }
          }
        }
      }

      expect(
        reachable.intersection(OrderState.outsideThisSliceEvaluator),
        isEmpty,
        reason: 'reached: ${reachable.map((OrderState s) => s.id).toList()}',
      );
    });
  });

  group('no generic status setter exists', () {
    test('every command is a named operation, not a state argument', () {
      // LifecycleRequest carries no target state: the only way to move the
      // order is to name an operation the evaluator recognises.
      for (final LifecycleCommand c in LifecycleCommand.values) {
        expect(c.commandType, matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'));
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('set_state')));
      }
    });

    test('command types are unique and resolvable', () {
      final Set<String> types =
          LifecycleCommand.values.map((LifecycleCommand c) => c.commandType)
              .toSet();
      expect(types.length, LifecycleCommand.values.length);
      for (final LifecycleCommand c in LifecycleCommand.values) {
        expect(LifecycleCommand.byCommandType(c.commandType), c);
      }
      expect(LifecycleCommand.byCommandType('order.set_status'), isNull);
    });

    test('every event type is declared and unique', () {
      expect(
        LifecycleEventType.all.toSet().length,
        LifecycleEventType.all.length,
      );
      for (final String e in LifecycleEventType.all) {
        expect(e, matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'));
      }
    });
  });
}
