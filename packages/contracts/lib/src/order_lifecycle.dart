import 'package:cp_contracts/src/lifecycle_command.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:meta/meta.dart';

/// Why a lifecycle transition was refused.
///
/// **Internal.** These are for backend logs, tests and audit. They are not
/// returned verbatim to an untrusted caller, for the same reason
/// `DenyReason` is not: distinguishing "wrong state" from "revision conflict"
/// tells a prober that the resource exists and roughly what is happening to
/// it.
enum LifecycleDenial {
  /// The order is not in a state this command can act from.
  wrongSourceState,

  /// `expectedRevision` does not match the order's current revision. Another
  /// writer got there first.
  revisionConflict,

  /// The reservation's units were already given back ([ReservationState.released]
  /// or [ReservationState.expired]). Acting again would restore twice.
  reservationAlreadyFinal,

  /// The trusted facts do not form a canonical aggregate: the order state and
  /// reservation state are a combination this lifecycle can never produce, the
  /// revision is impossible, or a reservation record holds a non-positive unit
  /// count.
  ///
  /// This is **corruption, not a race**. The transition graph cannot create
  /// such a pair, so seeing one means the aggregate was partially loaded,
  /// mid-migration, or written outside the transaction boundary. It fails
  /// closed: no state machine can safely reason about facts it knows to be
  /// impossible, and guessing would mean mutating inventory on bad data.
  ///
  /// The evaluator deliberately does **not** repair anything — repair belongs
  /// to reconciliation or admin tooling, with an audit trail.
  aggregateInconsistent,

  /// The order is already `rejected` or `cancelled`. Nothing leaves those.
  alreadyTerminal,

  /// The edge is real but its **business policy is not yet decided**, so it is
  /// deliberately not executable. Not a bug and not a permanent refusal — see
  /// [policyDeferredCancellationSources].
  policyDeferred,

  /// Stock could not be reserved, so the order must not reach `placed`.
  reservationUnavailable,

  /// No such edge is enumerated. **Fail closed** — an unlisted transition is
  /// refused, never inferred.
  unknownTransition,
}

/// Trusted, server-loaded facts about the order and its reservation.
///
/// Every field is read from authoritative storage inside the same transaction
/// that will apply the transition. None of it comes from a command payload:
/// a caller that could state its own order's state could state that the state
/// permits what it wants.
@immutable
class OrderLifecycleFacts {
  const OrderLifecycleFacts({
    required this.state,
    required this.revision,
    required this.reservationState,
    required this.reservedUnits,
  });

  /// The order does not exist yet. Used only by [LifecycleCommand.placeOrder].
  const OrderLifecycleFacts.absent()
    : state = null,
      revision = 0,
      reservationState = null,
      reservedUnits = 0;

  /// Null when the order does not exist yet.
  final OrderState? state;

  /// Current order revision. Zero when the order does not exist.
  final int revision;

  /// Null when no reservation record exists.
  final ReservationState? reservationState;

  /// Whole units held by the reservation.
  final int reservedUnits;

  bool get exists => state != null;
}

/// One lifecycle transition request.
///
/// Authorization, idempotency and command→permission mapping have **already
/// happened** by the time this is evaluated — see the integration order in
/// `docs/contracts/order-reservation-lifecycle.md`. This type deliberately
/// carries no principal, no grant and no payload: it is the state machine's
/// input, not a security boundary, and duplicating FND-003A's checks here
/// would create a second place for them to drift.
@immutable
class LifecycleRequest {
  const LifecycleRequest({
    required this.command,
    required this.expectedRevision,
    this.requestedUnits = 0,
    this.reservationSecured = false,
  });

  final LifecycleCommand command;

  /// Revision the caller believes the order is at. For
  /// [LifecycleCommand.placeOrder] this is 0, meaning "expected not to exist".
  final int expectedRevision;

  /// Units to reserve. Meaningful only for placement.
  final int requestedUnits;

  /// Trusted server fact: the requested units **can be** reserved atomically
  /// within this transaction.
  ///
  /// False denies placement. This is what makes "order placed but reservation
  /// failed" unrepresentable rather than merely discouraged. It is never a
  /// cached client-side stock reading.
  final bool reservationSecured;
}

/// A permitted transition, fully specified for the backend to apply.
@immutable
class LifecycleTransition {
  const LifecycleTransition({
    required this.command,
    required this.fromState,
    required this.toState,
    required this.resultingRevision,
    required this.fromReservation,
    required this.toReservation,
    required this.inventoryEffect,
    required this.financialClassification,
    required this.eventType,
  });

  final LifecycleCommand command;

  /// Null for placement — there was no prior state.
  final OrderState? fromState;
  final OrderState toState;

  /// Order revision after applying. Always `facts.revision + 1`: every applied
  /// transition advances the revision, which is what makes a stale
  /// `expectedRevision` detectable.
  final int resultingRevision;

  final ReservationState? fromReservation;
  final ReservationState toReservation;

  final InventoryEffect inventoryEffect;
  final FinancialClassification financialClassification;

  /// Event the backend emits through the outbox, inside the same transaction.
  final String eventType;

  @override
  String toString() =>
      'LifecycleTransition(${command.commandType}: '
      '${fromState?.id ?? '-'} -> ${toState.id}, rev=$resultingRevision, '
      'res=${fromReservation?.id ?? '-'} -> ${toReservation.id}, '
      '${inventoryEffect.kind.name}, ${financialClassification.name})';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class LifecycleOutcome {
  const LifecycleOutcome._(this.transition, this.denial);

  const LifecycleOutcome.allow(LifecycleTransition transition)
    : this._(transition, null);

  const LifecycleOutcome.deny(LifecycleDenial denial) : this._(null, denial);

  /// Non-null exactly when permitted.
  final LifecycleTransition? transition;

  /// Internal reason. Do not return verbatim to an untrusted caller.
  final LifecycleDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Order states from which customer cancellation is **executable** in this
/// slice.
///
/// Up to and including acceptance, no physical shop work has been committed:
/// releasing the reservation is the whole effect, and the blueprint's rule —
/// *"Before dispatch, a permitted cancellation releases reservation once"* —
/// covers it without needing a policy that does not exist yet.
const Set<OrderState> executableCancellationSources = <OrderState>{
  OrderState.placed,
  OrderState.accepted,
};

/// Order states where cancellation is a **real edge whose policy is not
/// decided**, so it is deliberately not executable.
///
/// From `preparing` onward the shop is assembling or has assembled goods.
/// Whether a customer may cancel unilaterally, whether shop or admin approval
/// is required, and who bears the cost are business questions this repository
/// does not answer. They need owner decision **O6** and the fee policy in
/// **FND-003C**.
///
/// These deny with [LifecycleDenial.policyDeferred] rather than
/// [LifecycleDenial.unknownTransition], so a backend can tell "not decided
/// yet" from "never allowed" — and so nobody is tempted to fill the gap with
/// a guessed rule or a zero fee.
const Set<OrderState> policyDeferredCancellationSources = <OrderState>{
  OrderState.preparing,
  OrderState.ready,
};

/// The only order↔reservation combinations this lifecycle can produce.
///
/// Every existing order has exactly one reservation record, and its state is
/// determined by the order's. Two entries deserve comment:
///
/// - `placed` pairs with **either** `active` or `expired`. `placed + expired`
///   is canonical and is precisely the expiry-wins outcome: the units were
///   restored, the order stays `placed`, and it simply can no longer be
///   accepted. Treating it as corruption would break that race outcome.
/// - `rejected` and `cancelled` pair only with `released`, never `expired`:
///   the units were given back because someone acted, not because time passed.
const Map<OrderState, Set<ReservationState>> canonicalAggregatePairs =
    <OrderState, Set<ReservationState>>{
  OrderState.placed: <ReservationState>{
    ReservationState.active,
    ReservationState.expired,
  },
  OrderState.accepted: <ReservationState>{ReservationState.committed},
  OrderState.preparing: <ReservationState>{ReservationState.committed},
  OrderState.ready: <ReservationState>{ReservationState.committed},
  OrderState.rejected: <ReservationState>{ReservationState.released},
  OrderState.cancelled: <ReservationState>{ReservationState.released},
};

/// Rejects trusted facts that cannot be a real aggregate, before any
/// transition helper can produce an inventory effect.
///
/// The transition graph is internally consistent — it never *creates* an
/// impossible pair. This guards the other direction: facts arriving from
/// storage. A partially loaded, mid-migration or externally written aggregate
/// must not drive a stock mutation.
///
/// Returns null when the facts are canonical.
LifecycleDenial? validateAggregate(OrderLifecycleFacts facts) {
  if (!facts.exists) {
    // Canonical absence is exact: no revision, no reservation, no units.
    // A "non-existent" order carrying a revision or a reservation record is a
    // partial load, and treating it as absent would place a duplicate order.
    if (facts.revision != 0 ||
        facts.reservationState != null ||
        facts.reservedUnits != 0) {
      return LifecycleDenial.aggregateInconsistent;
    }
    return null;
  }

  final OrderState state = facts.state!;

  // States this slice does not own are reported as unknownTransition by the
  // evaluator; validating their pairing would mean inventing one.
  if (!OrderState.executableInThisSlice.contains(state)) {
    return null;
  }

  // An existing order has been written at least once.
  if (facts.revision < 1) {
    return LifecycleDenial.aggregateInconsistent;
  }

  final ReservationState? reservation = facts.reservationState;
  if (reservation == null) {
    // Every canonical pair includes a reservation. Its absence means the
    // record was not loaded, not that the order never had one.
    return LifecycleDenial.aggregateInconsistent;
  }

  // A reservation for zero units is meaningless; for negative units it would
  // produce an inventory mutation that *destroys* stock. Never clamp or take
  // an absolute value — deny the aggregate.
  if (facts.reservedUnits <= 0) {
    return LifecycleDenial.aggregateInconsistent;
  }

  if (!canonicalAggregatePairs[state]!.contains(reservation)) {
    return LifecycleDenial.aggregateInconsistent;
  }

  return null;
}

/// Evaluate one pre-dispatch lifecycle transition.
///
/// Pure: no I/O, no clock, no storage, no randomness. Wall-clock time plays no
/// part — **server transaction and revision ordering decide races**, not the
/// order in which client requests happened to arrive.
///
/// Any edge not enumerated below fails closed with
/// [LifecycleDenial.unknownTransition].
LifecycleOutcome evaluateOrderTransition({
  required LifecycleRequest request,
  required OrderLifecycleFacts facts,
}) {
  // ---- aggregate integrity, before anything can produce an effect --------
  final LifecycleDenial? corruption = validateAggregate(facts);
  if (corruption != null) {
    return LifecycleOutcome.deny(corruption);
  }

  // ---- placement is the only command acting on a non-existent order -------
  if (request.command == LifecycleCommand.placeOrder) {
    return _evaluatePlacement(request, facts);
  }

  if (!facts.exists) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }

  final OrderState from = facts.state!;

  // A state this slice does not own must never be transitioned from, even if
  // a future slice adds it to the enum.
  if (!OrderState.executableInThisSlice.contains(from)) {
    return const LifecycleOutcome.deny(LifecycleDenial.unknownTransition);
  }

  // Terminal states are closed in every direction. Checked before the
  // revision so a cancelled order reports the honest reason.
  if (from.isTerminalPreDispatch) {
    return const LifecycleOutcome.deny(LifecycleDenial.alreadyTerminal);
  }

  if (request.expectedRevision != facts.revision) {
    return const LifecycleOutcome.deny(LifecycleDenial.revisionConflict);
  }

  return switch (request.command) {
    LifecycleCommand.acceptOrder => _evaluateAccept(from, facts),
    LifecycleCommand.rejectOrder => _evaluateReject(from, facts),
    LifecycleCommand.startPreparing => _evaluatePreparation(
      from,
      facts,
      required: OrderState.accepted,
      to: OrderState.preparing,
      command: LifecycleCommand.startPreparing,
      eventType: LifecycleEventType.orderPreparing,
    ),
    LifecycleCommand.markReady => _evaluatePreparation(
      from,
      facts,
      required: OrderState.preparing,
      to: OrderState.ready,
      command: LifecycleCommand.markReady,
      eventType: LifecycleEventType.orderReady,
    ),
    LifecycleCommand.cancelOrder => _evaluateCancel(from, facts),
    LifecycleCommand.expireReservation => _evaluateExpiry(from, facts),
    LifecycleCommand.placeOrder => const LifecycleOutcome.deny(
      LifecycleDenial.unknownTransition,
    ),
  };
}

LifecycleOutcome _evaluatePlacement(
  LifecycleRequest request,
  OrderLifecycleFacts facts,
) {
  if (facts.exists) {
    // Creating something that already exists is a revision conflict, not a
    // new order.
    return const LifecycleOutcome.deny(LifecycleDenial.revisionConflict);
  }
  if (request.expectedRevision != 0) {
    return const LifecycleOutcome.deny(LifecycleDenial.revisionConflict);
  }
  if (request.requestedUnits <= 0) {
    return const LifecycleOutcome.deny(LifecycleDenial.reservationUnavailable);
  }
  if (!request.reservationSecured) {
    // No stock, no order. "Placed but not reserved" is not a state this
    // contract can produce.
    return const LifecycleOutcome.deny(LifecycleDenial.reservationUnavailable);
  }

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: LifecycleCommand.placeOrder,
      fromState: null,
      toState: OrderState.placed,
      resultingRevision: 1,
      fromReservation: null,
      toReservation: ReservationState.active,
      inventoryEffect: InventoryEffect.reserve(request.requestedUnits),
      financialClassification: FinancialClassification.noneInThisSlice,
      eventType: LifecycleEventType.orderPlaced,
    ),
  );
}

LifecycleOutcome _evaluateAccept(OrderState from, OrderLifecycleFacts facts) {
  if (from != OrderState.placed) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }
  // Pair-specific: acceptance needs exactly `placed + active`. After
  // aggregate validation the only other possibility is `placed + expired`,
  // which means expiry already won and the units are back.
  if (facts.reservationState != ReservationState.active) {
    return const LifecycleOutcome.deny(LifecycleDenial.reservationAlreadyFinal);
  }

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: LifecycleCommand.acceptOrder,
      fromState: from,
      toState: OrderState.accepted,
      resultingRevision: facts.revision + 1,
      fromReservation: ReservationState.active,
      // Committing makes the reservation non-expirable. This single move is
      // what settles the acceptance-versus-expiry race in acceptance's favour
      // once it commits first.
      toReservation: ReservationState.committed,
      // Available stock is untouched: the decrement happened at placement.
      inventoryEffect: InventoryEffect.commit(facts.reservedUnits),
      financialClassification: FinancialClassification.noneInThisSlice,
      eventType: LifecycleEventType.orderAccepted,
    ),
  );
}

LifecycleOutcome _evaluateReject(OrderState from, OrderLifecycleFacts facts) {
  // Only an unaccepted order may be rejected. There is no accepted -> rejected
  // edge and no un-reject command.
  if (from != OrderState.placed) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }
  // Pair-specific: `placed + active` only. `placed + expired` already gave
  // the units back, and restoring again would be a double restore.
  if (facts.reservationState != ReservationState.active) {
    return const LifecycleOutcome.deny(LifecycleDenial.reservationAlreadyFinal);
  }

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: LifecycleCommand.rejectOrder,
      fromState: from,
      toState: OrderState.rejected,
      resultingRevision: facts.revision + 1,
      fromReservation: ReservationState.active,
      toReservation: ReservationState.released,
      inventoryEffect: InventoryEffect.restore(facts.reservedUnits),
      // Whether a rejection carries any financial consequence is FND-003C's.
      // Not zero — undecided.
      financialClassification: FinancialClassification.deferredToFinancialSlice,
      eventType: LifecycleEventType.orderRejected,
    ),
  );
}

LifecycleOutcome _evaluatePreparation(
  OrderState from,
  OrderLifecycleFacts facts, {
  required OrderState required,
  required OrderState to,
  required LifecycleCommand command,
  required String eventType,
}) {
  if (from != required) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }
  // `accepted`, `preparing` and `ready` pair only with `committed`, which
  // aggregate validation has already established, so the allocation is known
  // to still belong to the order.

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: command,
      fromState: from,
      toState: to,
      resultingRevision: facts.revision + 1,
      fromReservation: ReservationState.committed,
      toReservation: ReservationState.committed,
      // An order becoming ready must never release stock.
      inventoryEffect: const InventoryEffect.none(),
      financialClassification: FinancialClassification.noneInThisSlice,
      eventType: eventType,
    ),
  );
}

LifecycleOutcome _evaluateCancel(OrderState from, OrderLifecycleFacts facts) {
  if (policyDeferredCancellationSources.contains(from)) {
    return const LifecycleOutcome.deny(LifecycleDenial.policyDeferred);
  }
  if (!executableCancellationSources.contains(from)) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }
  // Pair-specific per source state, rather than a generic "still holds units"
  // test: `placed` cancels only from `active`, `accepted` only from
  // `committed`. A generic check would let an impossible pair through.
  final ReservationState requiredReservation = from == OrderState.placed
      ? ReservationState.active
      : ReservationState.committed;
  if (facts.reservationState != requiredReservation) {
    return const LifecycleOutcome.deny(LifecycleDenial.reservationAlreadyFinal);
  }

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: LifecycleCommand.cancelOrder,
      fromState: from,
      toState: OrderState.cancelled,
      resultingRevision: facts.revision + 1,
      fromReservation: facts.reservationState,
      toReservation: ReservationState.released,
      // Exactly once: released is terminal, so a second cancellation finds
      // no held reservation.
      inventoryEffect: InventoryEffect.restore(facts.reservedUnits),
      // No cancellation fee is invented. Undefined, not zero.
      financialClassification: FinancialClassification.deferredToFinancialSlice,
      eventType: LifecycleEventType.orderCancelled,
    ),
  );
}

LifecycleOutcome _evaluateExpiry(OrderState from, OrderLifecycleFacts facts) {
  // Expiry acts on the reservation of an order that was never accepted.
  if (from != OrderState.placed) {
    return const LifecycleOutcome.deny(LifecycleDenial.wrongSourceState);
  }
  // After aggregate validation a `placed` order is `active` or `expired`.
  // A retried worker finds the units already given back and does nothing.
  // (Acceptance having won the race is caught above: the order is no longer
  // `placed`, so expiry has no source state at all.)
  if (!facts.reservationState!.isExpirable) {
    return const LifecycleOutcome.deny(LifecycleDenial.reservationAlreadyFinal);
  }

  return LifecycleOutcome.allow(
    LifecycleTransition(
      command: LifecycleCommand.expireReservation,
      fromState: from,
      // The order stays `placed`; it is the reservation that ends. The order
      // simply can no longer be accepted, because acceptance needs an active
      // reservation.
      toState: OrderState.placed,
      resultingRevision: facts.revision + 1,
      fromReservation: ReservationState.active,
      toReservation: ReservationState.expired,
      inventoryEffect: InventoryEffect.restore(facts.reservedUnits),
      financialClassification: FinancialClassification.noneInThisSlice,
      eventType: LifecycleEventType.reservationExpired,
    ),
  );
}
