import 'package:cp_contracts/src/assignment_command.dart';
import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/custody_command.dart';
import 'package:cp_contracts/src/custody_effect.dart';
import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/lifecycle_command.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/picker_assignment.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/rider_assignment.dart';
import 'package:meta/meta.dart';

/// Why a custody transition was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial` and
/// `AssignmentDenial` are not.
enum CustodyDenial {
  /// The order has no custody aggregate. **Absence is not "the shop has it".**
  /// A ready order must have had custody initialised explicitly.
  custodyNotInitialised,

  /// `expectedCustodyRevision` does not match. Another writer got there first.
  custodyRevisionConflict,

  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// Custody is not with the party this command acts from.
  wrongCustodyHolder,

  /// The order is not in a state this custody transition may act from.
  orderNotInRequiredState,

  /// The reservation is not in the state this transition requires.
  reservationNotCommitted,

  /// There is no accepted picker assignment for this order.
  noAcceptedPickerAssignment,

  /// The acting principal is not the order's current accepted picker.
  notCurrentAcceptedPicker,

  /// There is no accepted rider assignment for this order.
  noAcceptedRiderAssignment,

  /// The acting principal is not the order's accepted rider.
  notCurrentAcceptedRider,

  /// The command names a different assignment attempt than the current one.
  assignmentIdMismatch,

  /// The command names a different generation than the current attempt's.
  generationMismatch,

  /// The custody holder is bound to a different picker assignment attempt than
  /// the one currently accepted, or than the rider's `SourcePickerBinding`.
  custodyHolderBindingMismatch,

  /// The rider attempt's `SourcePickerBinding` no longer identifies the picker
  /// assignment that currently holds custody.
  sourcePickerAssignmentMismatch,

  /// Two aggregates that must describe the same order disagree.
  resourceBindingMismatch,

  /// A stored aggregate is a combination this lifecycle can never produce.
  /// **Corruption, not a race.**
  aggregateInconsistent,

  /// No such edge is enumerated. Fail closed.
  unknownTransition,
}

/// The custody aggregate for one order, as loaded from storage.
///
/// Its [custodyRevision] is **its own** concurrency control — deliberately
/// independent of the order revision, the picker `slotRevision` and the rider
/// `slotRevision`. Four aggregates change at different rates; sharing one
/// counter would make every unrelated write look like a conflict, and would
/// make a genuine conflict undetectable.
@immutable
class CustodyFacts {
  const CustodyFacts({
    required this.resourceId,
    required this.custodyRevision,
    required this.holder,
  });

  /// The canonical starting custody for an order that has reached `ready`.
  ///
  /// **The typed representation of initialisation.** There is deliberately no
  /// client command for it: custody at the shop is not something a caller
  /// asserts, it is what is true once the shop has assembled the goods. The
  /// backend must create this record **atomically with** the transition that
  /// establishes the ready-for-collection boundary — criterion **CA1**.
  ///
  /// Revision starts at 1, following the repository's existing convention that
  /// a written aggregate begins at revision 1 and that revision 0 means "never
  /// written".
  factory CustodyFacts.initialAtShop({
    required String resourceId,
    required String shopId,
  }) => CustodyFacts(
    resourceId: resourceId,
    custodyRevision: 1,
    holder: CustodyHolder.atShop(shopId: shopId),
  );

  final String resourceId;

  /// Increments on **every** applied custody mutation.
  final int custodyRevision;

  /// The single current custodian. Never null once the aggregate exists — the
  /// aggregate's existence *is* the claim that someone holds the goods.
  final CustodyHolder holder;

  bool get isAtShop => holder.kind == CustodyHolderKind.shop;
  bool get isWithPicker => holder.kind == CustodyHolderKind.picker;
  bool get isWithRider => holder.kind == CustodyHolderKind.rider;
}

/// One custody transition request.
///
/// Authorization, idempotency and command→permission mapping have **already
/// happened**. This carries no grant and no payload: duplicating FND-003A's
/// checks here would create a second place for them to drift, and FND-003A's
/// rule stands — **fresh authorization on every request, including replays**.
@immutable
class CustodyRequest {
  const CustodyRequest({
    required this.command,
    required this.actingPrincipalId,
    required this.expectedCustodyRevision,
    required this.expectedOrderRevision,
    required this.assignmentId,
    required this.generation,
  });

  final CustodyCommand command;

  /// Principal the backend derived from **verified authentication**.
  final String actingPrincipalId;

  /// Custody revision the caller believes is current.
  final int expectedCustodyRevision;

  /// Order revision the caller believes is current. Checked for every custody
  /// command, including the one that leaves the order untouched, so a caller
  /// acting on a stale view of the order is refused either way.
  final int expectedOrderRevision;

  /// The acting worker's own assignment attempt.
  final String assignmentId;

  /// That attempt's generation.
  final int generation;
}

/// A permitted custody transition, fully specified across every aggregate it
/// touches.
@immutable
class CustodyTransition {
  const CustodyTransition({
    required this.command,
    required this.fromHolder,
    required this.toHolder,
    required this.resultingCustodyRevision,
    required this.orderEffect,
    required this.scopeEffect,
    required this.events,
    this.pickerCompletion,
    this.inventoryEffect = const InventoryEffect.none(),
    this.financialClassification = FinancialClassification.noneInThisSlice,
  });

  final CustodyCommand command;
  final CustodyHolder fromHolder;
  final CustodyHolder toHolder;

  /// Always `custodyRevision + 1`.
  final int resultingCustodyRevision;

  /// What happens to the order. `unchanged` for shop pickup.
  final CustodyOrderEffect orderEffect;

  /// Set only when custody reaches the rider: the picker's work is finished.
  final PickerAssignmentCompletionEffect? pickerCompletion;

  /// Authorization projection changes. Completion removes the picker's
  /// `assignedResource`; the rider keeps theirs.
  final ScopeProjectionEffect scopeEffect;

  /// Every domain fact this one command causes, in order.
  ///
  /// A rider receipt causes several. They share one `causedByCommandId` and
  /// **must commit atomically with the state change** — criterion **CA9**.
  /// Notification delivery is not part of that transaction: a push is a hint,
  /// never authorization, and it may simply be missed.
  final List<String> events;

  /// Custody never touches stock. Moving goods between the shop, a picker and a
  /// rider does not create or destroy any, and dispatch does **not** restore
  /// the reservation.
  final InventoryEffect inventoryEffect;

  /// Custody moves no money. Pickup and handoff create no COD liability, no
  /// commission and no settlement.
  final FinancialClassification financialClassification;

  @override
  String toString() =>
      'CustodyTransition(${command.commandType}: ${fromHolder.kind.id} -> '
      '${toHolder.kind.id}, custodyRev=$resultingCustodyRevision, '
      'order=$orderEffect)';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class CustodyOutcome {
  const CustodyOutcome._(this.transition, this.denial);

  const CustodyOutcome.allow(CustodyTransition transition)
    : this._(transition, null);

  const CustodyOutcome.deny(CustodyDenial denial) : this._(null, denial);

  final CustodyTransition? transition;
  final CustodyDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Canonical custody aggregate shape.
///
/// Same lesson as FND-003B1, FND-003B2A and FND-003B2B: the transition graph
/// never *creates* an impossible aggregate, but facts arrive from **storage**.
/// Validation runs before any effect.
///
/// Returns null when the facts are canonical. **Never repairs anything** —
/// repair without an audit trail is indistinguishable from a bug, and belongs
/// to reconciliation tooling (**CA16**).
CustodyDenial? validateCustodyAggregate(CustodyFacts facts) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return CustodyDenial.aggregateInconsistent;
  }
  // An existing custody aggregate has been written at least once. Revision 0
  // would mean "never written", which contradicts holding a custodian.
  if (facts.custodyRevision < 1) {
    return CustodyDenial.aggregateInconsistent;
  }
  if (!CustodyHolderKind.executableInThisSlice.contains(facts.holder.kind)) {
    // `customer` has no defined shape here; validating one would invent it.
    return CustodyDenial.aggregateInconsistent;
  }
  if (!facts.holder.isWellFormed) {
    return CustodyDenial.aggregateInconsistent;
  }
  return null;
}

/// Whether an accepted assignment may be withdrawn, derived from **real
/// custody facts**.
///
/// This is what finally connects `ReassignmentSafety` — which FND-003B2A and
/// FND-003B2B could only accept from the backend — to something the contract
/// can compute. Its fail-closed meaning is unchanged and is not weakened:
///
/// - custody **missing or corrupt** → `blockedOrUnknown`. "The aggregate does
///   not name this worker" is **not** proof they hold nothing. Unknown is not
///   safe, and a missing record is unknown.
/// - custody at the **shop** → nobody has taken possession, so either worker
///   may still be reassigned.
/// - custody with the **picker** → picker reassignment is unsafe. A rider may
///   still be revoked: an accepted rider who has not received anything is
///   holding nothing.
/// - custody with the **rider** → rider reassignment is unsafe. It is also
///   refused for the picker, whose assignment is `completed` by then and so is
///   no longer an active assignment to revoke at all.
ReassignmentSafety reassignmentSafetyFor({
  required AssignmentRole role,
  required CustodyFacts? custody,
}) {
  if (custody == null || validateCustodyAggregate(custody) != null) {
    return ReassignmentSafety.blockedOrUnknown;
  }
  return switch (custody.holder.kind) {
    CustodyHolderKind.shop => ReassignmentSafety.provenNoCustody,
    CustodyHolderKind.picker => role == AssignmentRole.rider
        ? ReassignmentSafety.provenNoCustody
        : ReassignmentSafety.blockedOrUnknown,
    CustodyHolderKind.rider => ReassignmentSafety.blockedOrUnknown,
    // Not reachable in this slice; fail closed rather than guess.
    CustodyHolderKind.customer => ReassignmentSafety.blockedOrUnknown,
  };
}

/// Evaluate one custody transition.
///
/// Pure: no I/O, no clock, no storage. Wall-clock time and client arrival order
/// are not concurrency control — server transaction and revision ordering
/// decide races.
///
/// Every aggregate is supplied as trusted current facts read in **one
/// consistent transaction**. Passing them proves nothing about trust; they are
/// the shapes the backend fills from canonical storage.
///
/// Any edge not enumerated fails closed.
CustodyOutcome evaluateCustodyTransition({
  required CustodyRequest request,
  required CustodyFacts? custody,
  required OrderLifecycleFacts order,
  required PickerAssignmentFacts pickerAssignment,
  required RiderAssignmentFacts? riderAssignment,
}) {
  // 1. Custody must exist. Absence is never read as "the shop still has it".
  if (custody == null) {
    return const CustodyOutcome.deny(CustodyDenial.custodyNotInitialised);
  }

  // 2. Aggregate integrity for every aggregate, before anything can produce an
  //    effect. Each validator is the canonical one for its own aggregate —
  //    none is reimplemented here.
  final CustodyDenial? custodyCorruption = validateCustodyAggregate(custody);
  if (custodyCorruption != null) {
    return CustodyOutcome.deny(custodyCorruption);
  }
  if (validateAggregate(order) != null ||
      validatePickerAssignmentAggregate(pickerAssignment) != null) {
    return const CustodyOutcome.deny(CustodyDenial.aggregateInconsistent);
  }
  if (riderAssignment != null &&
      validateRiderAssignmentAggregate(riderAssignment) != null) {
    return const CustodyOutcome.deny(CustodyDenial.aggregateInconsistent);
  }

  // 3. Every aggregate must describe the same order. If they disagree, the
  //    read-set was not consistent, and deciding custody from a mixed view of
  //    two orders is exactly how goods get attributed to the wrong one.
  if (pickerAssignment.resourceId != custody.resourceId ||
      (riderAssignment != null &&
          riderAssignment.resourceId != custody.resourceId)) {
    return const CustodyOutcome.deny(CustodyDenial.resourceBindingMismatch);
  }

  // 4. Concurrency, before command dispatch so every command is protected
  //    identically. Both revisions are checked even when a command leaves the
  //    order untouched.
  if (request.expectedCustodyRevision != custody.custodyRevision) {
    return const CustodyOutcome.deny(CustodyDenial.custodyRevisionConflict);
  }
  if (request.expectedOrderRevision != order.revision) {
    return const CustodyOutcome.deny(CustodyDenial.orderRevisionConflict);
  }

  // 5. The reservation must still be committed. Custody cannot advance on an
  //    order whose stock was released or expired.
  if (order.reservationState != ReservationState.committed) {
    return const CustodyOutcome.deny(CustodyDenial.reservationNotCommitted);
  }

  return switch (request.command) {
    CustodyCommand.recordShopPickup => _evaluateShopPickup(
      request,
      custody,
      order,
      pickerAssignment,
    ),
    CustodyCommand.recordRiderReceipt => _evaluateRiderReceipt(
      request,
      custody,
      order,
      pickerAssignment,
      riderAssignment,
    ),
  };
}

/// The picker attempt currently holding the order, or a denial.
({PickerAssignmentAttempt? attempt, CustodyDenial? denial})
_currentAcceptedPicker(
  PickerAssignmentFacts facts,
  String actingPrincipalId,
  String assignmentId,
  int generation,
) {
  final PickerAssignmentAttempt? attempt = facts.attempt;
  if (attempt == null || attempt.state != AssignmentState.accepted) {
    return (
      attempt: null,
      denial: CustodyDenial.noAcceptedPickerAssignment,
    );
  }
  if (attempt.acceptedAssigneePrincipalId != actingPrincipalId) {
    return (attempt: null, denial: CustodyDenial.notCurrentAcceptedPicker);
  }
  // Identity before generation, matching the assignment evaluators.
  if (attempt.assignmentId != assignmentId) {
    return (attempt: null, denial: CustodyDenial.assignmentIdMismatch);
  }
  if (attempt.generation != generation) {
    return (attempt: null, denial: CustodyDenial.generationMismatch);
  }
  return (attempt: attempt, denial: null);
}

CustodyOutcome _evaluateShopPickup(
  CustodyRequest request,
  CustodyFacts custody,
  OrderLifecycleFacts order,
  PickerAssignmentFacts pickerAssignment,
) {
  // Goods must still be at the shop. A second pickup, or a pickup after the
  // rider already has them, has nothing to collect.
  if (!custody.isAtShop) {
    return const CustodyOutcome.deny(CustodyDenial.wrongCustodyHolder);
  }
  // Collection happens from a shop that has finished assembling.
  if (order.state != OrderState.ready) {
    return const CustodyOutcome.deny(CustodyDenial.orderNotInRequiredState);
  }

  final ({PickerAssignmentAttempt? attempt, CustodyDenial? denial}) picker =
      _currentAcceptedPicker(
        pickerAssignment,
        request.actingPrincipalId,
        request.assignmentId,
        request.generation,
      );
  if (picker.denial != null) {
    return CustodyOutcome.deny(picker.denial!);
  }
  final PickerAssignmentAttempt attempt = picker.attempt!;

  return CustodyOutcome.allow(
    CustodyTransition(
      command: CustodyCommand.recordShopPickup,
      fromHolder: custody.holder,
      toHolder: CustodyHolder.worker(
        kind: CustodyHolderKind.picker,
        principalId: request.actingPrincipalId,
        assignmentId: attempt.assignmentId,
        assignmentGeneration: attempt.generation,
      ),
      resultingCustodyRevision: custody.custodyRevision + 1,
      // Pickup is physical acquisition, NOT dispatch. The order stays `ready`
      // until a rider holds the goods, so nothing downstream may read a
      // collected order as an out-for-delivery one.
      orderEffect: const CustodyOrderEffect.unchanged(),
      // The picker already holds `assignedResource` from accepting. Custody
      // grants no new authorization scope: possession is not permission.
      scopeEffect: const ScopeProjectionEffect.none(),
      events: const <String>[CustodyEventType.acquiredByPicker],
    ),
  );
}

CustodyOutcome _evaluateRiderReceipt(
  CustodyRequest request,
  CustodyFacts custody,
  OrderLifecycleFacts order,
  PickerAssignmentFacts pickerAssignment,
  RiderAssignmentFacts? riderAssignment,
) {
  // The picker must actually be holding the goods. A rider cannot receive what
  // was never collected.
  if (!custody.isWithPicker) {
    return const CustodyOutcome.deny(CustodyDenial.wrongCustodyHolder);
  }
  if (order.state != OrderState.ready) {
    return const CustodyOutcome.deny(CustodyDenial.orderNotInRequiredState);
  }

  // The picker assignment must still be the accepted one, and it must be the
  // very attempt custody is bound to.
  final PickerAssignmentAttempt? pickerAttempt = pickerAssignment.attempt;
  if (pickerAttempt == null ||
      pickerAttempt.state != AssignmentState.accepted) {
    return const CustodyOutcome.deny(
      CustodyDenial.noAcceptedPickerAssignment,
    );
  }
  final String? pickerAssignee = pickerAttempt.acceptedAssigneePrincipalId;
  if (pickerAssignee == null ||
      !custody.holder.isHeldBy(
        principalId: pickerAssignee,
        assignmentId: pickerAttempt.assignmentId,
        generation: pickerAttempt.generation,
      )) {
    // Custody names a picker attempt that is no longer the accepted one. That
    // is precisely the reassignment hazard: goods collected under attempt A
    // must not be handed over as though attempt B had collected them.
    return const CustodyOutcome.deny(
      CustodyDenial.custodyHolderBindingMismatch,
    );
  }

  // The acting rider must be the accepted one, named exactly.
  if (riderAssignment == null) {
    return const CustodyOutcome.deny(CustodyDenial.noAcceptedRiderAssignment);
  }
  final RiderAssignmentAttempt? riderAttempt = riderAssignment.attempt;
  if (riderAttempt == null || riderAttempt.state != AssignmentState.accepted) {
    return const CustodyOutcome.deny(CustodyDenial.noAcceptedRiderAssignment);
  }
  if (riderAttempt.acceptedAssigneePrincipalId != request.actingPrincipalId) {
    return const CustodyOutcome.deny(CustodyDenial.notCurrentAcceptedRider);
  }
  if (riderAttempt.assignmentId != request.assignmentId) {
    return const CustodyOutcome.deny(CustodyDenial.assignmentIdMismatch);
  }
  if (riderAttempt.generation != request.generation) {
    return const CustodyOutcome.deny(CustodyDenial.generationMismatch);
  }

  // The rider's offer must still trace to the picker who is holding the goods.
  // Without this, a rider offered work by picker A could take delivery from a
  // replacement picker B as though B had arranged it.
  if (!riderAttempt.source.matchesCurrentPicker(pickerAttempt)) {
    return const CustodyOutcome.deny(
      CustodyDenial.sourcePickerAssignmentMismatch,
    );
  }

  return CustodyOutcome.allow(
    CustodyTransition(
      command: CustodyCommand.recordRiderReceipt,
      fromHolder: custody.holder,
      toHolder: CustodyHolder.worker(
        kind: CustodyHolderKind.rider,
        principalId: request.actingPrincipalId,
        assignmentId: riderAttempt.assignmentId,
        assignmentGeneration: riderAttempt.generation,
      ),
      resultingCustodyRevision: custody.custodyRevision + 1,
      // The dispatch boundary. `OrderState.inDelivery` has always been
      // documented as "reached once a rider holds custody"; this is the edge
      // that finally produces it.
      orderEffect: CustodyOrderEffect.transition(
        toState: OrderState.inDelivery,
        resultingOrderRevision: order.revision + 1,
      ),
      // The picker's work is finished — a consequence, never a command.
      pickerCompletion: PickerAssignmentCompletionEffect(
        assignmentId: pickerAttempt.assignmentId,
        generation: pickerAttempt.generation,
        resultingSlotRevision: pickerAssignment.slotRevision + 1,
        offerRecipientPrincipalId: pickerAttempt.offerRecipientPrincipalId,
        acceptedAssigneePrincipalId: pickerAssignee,
      ),
      // The completed picker loses `assignedResource`: their work is done, and
      // a stale projection must not keep granting post-acceptance authority
      // (**CA14**). The rider keeps theirs — they are still delivering.
      scopeEffect: ScopeProjectionEffect(
        removeFromAssigned: <String>{pickerAssignee},
      ),
      // One command, several facts, one causation, one transaction.
      events: const <String>[
        CustodyEventType.transferredToRider,
        AssignmentEventType.pickerCompleted,
        LifecycleEventType.orderInDelivery,
      ],
    ),
  );
}
