import 'package:cp_contracts/src/assignment_command.dart';
import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/membership.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/role.dart';
import 'package:meta/meta.dart';

/// Why a picker-assignment transition was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason` and
/// `LifecycleDenial` are not.
enum AssignmentDenial {
  /// The attempt is not in a state this command can act from.
  wrongAssignmentState,

  /// There is no assignment attempt at all, and this command needs one.
  noAssignmentAttempt,

  /// `expectedSlotRevision` does not match. Another writer got there first.
  slotRevisionConflict,

  /// The command names a different attempt than the one currently in the slot.
  /// This is what stops a delayed command from an older attempt.
  assignmentIdMismatch,

  /// The command names a different generation than the current attempt's.
  generationMismatch,

  /// The acting principal is not the worker the offer was addressed to.
  notOfferRecipient,

  /// The order is not in a state that may carry picker assignment work.
  orderNotAssignmentEligible,

  /// A live offer already occupies the slot.
  liveOfferExists,

  /// An accepted assignment already occupies the slot. It must be
  /// controlled-revoked before the work can be re-offered.
  activeAcceptedAssignmentExists,

  /// The target worker's trusted membership does not qualify them: wrong role,
  /// not active, not a human principal, or the membership names someone else.
  targetNotEligible,

  /// The target worker's region does not match the order's.
  regionMismatch,

  /// Expiry was attempted but the backend did not determine the offer due.
  /// A client cannot cause an early expiry.
  expiryNotDue,

  /// Controlled reassignment was refused because custody has started, or
  /// because custody state could not be proven. **Unknown is not safe.**
  reassignmentUnsafe,

  /// An offer must carry a non-blank timeout policy reference.
  timeoutPolicyMissing,

  /// A supplied assignment identifier is not a valid opaque id.
  assignmentIdInvalid,

  /// The stored aggregate is a combination this lifecycle can never produce.
  /// **Corruption, not a race** — see `validatePickerAssignmentAggregate`.
  aggregateInconsistent,

  /// No such edge is enumerated. Fail closed.
  unknownTransition,
}

/// One picker-assignment **attempt**.
///
/// An attempt is immutable history. Re-offering after a terminal attempt
/// creates a *new* attempt with a new [assignmentId] and the next
/// [generation]; the previous one is never edited or resurrected.
@immutable
class PickerAssignmentAttempt {
  const PickerAssignmentAttempt({
    required this.assignmentId,
    required this.generation,
    required this.state,
    required this.offerRecipientPrincipalId,
    required this.timeoutPolicyRef,
    this.acceptedAssigneePrincipalId,
  });

  /// Opaque, server-generated, unique to this attempt. **Never a global
  /// sequential counter** — [generation] carries ordering, this carries
  /// identity.
  final String assignmentId;

  /// Per-order version of the assignment slot. Increases only when a **new
  /// attempt** is created, which is what makes a delayed command from an older
  /// attempt detectable.
  final int generation;

  final AssignmentState state;

  /// Worker the offer was addressed to. **Immutable history** — it stays
  /// recorded after decline, expiry, acceptance and revocation. It is not
  /// erased because an attempt ended.
  final String offerRecipientPrincipalId;

  /// Worker who accepted, or null before acceptance. Distinct from
  /// [offerRecipientPrincipalId] on purpose: being offered work is not holding
  /// it, and after revocation the historical assignee remains recorded while
  /// ceasing to be *active*.
  final String? acceptedAssigneePrincipalId;

  /// Reference to the immutable, versioned timeout policy this offer lapses
  /// under. **No duration lives in this contract.** The backend resolves the
  /// reference against server time; see `docs/contracts/picker-assignment-lifecycle.md`.
  final String timeoutPolicyRef;

  /// True while this attempt occupies the slot.
  bool get isActive => state.occupiesSlot;

  @override
  String toString() => 'PickerAssignmentAttempt($assignmentId, gen=$generation, '
      '${state.id}, offeredTo=$offerRecipientPrincipalId, '
      'accepted=${acceptedAssigneePrincipalId ?? '-'})';
}

/// Trusted facts about a target worker, loaded from **authoritative
/// membership storage** for this request.
///
/// > This object is **not proof of trust**. It is the shape the backend fills
/// > from current membership records. A caller cannot make a worker eligible by
/// > constructing one, because a caller never reaches this evaluator — the
/// > backend does, having loaded the facts itself.
///
/// Deliberately absent: workload limits, ratings, distance, availability
/// scoring, shift rules. Those are **dispatch policy**, not lifecycle, and none
/// was invented here.
@immutable
class PickerEligibility {
  const PickerEligibility({
    required this.principalId,
    required this.isHumanPrincipal,
    required this.membershipPrincipalId,
    required this.role,
    required this.status,
    required this.regionId,
  });

  final String principalId;

  /// False for a system worker. Assignment work is offered to people.
  final bool isHumanPrincipal;

  /// Principal the loaded membership actually belongs to. A membership naming
  /// somebody else grants nothing.
  final String membershipPrincipalId;

  final CommerceRole role;
  final MembershipStatus status;

  /// Region the worker's membership covers.
  final String? regionId;

  /// Whether these facts qualify the worker to receive picker work at all.
  /// Region matching is checked separately, against the order.
  bool get qualifiesAsActivePicker =>
      isHumanPrincipal &&
      membershipPrincipalId == principalId &&
      role == CommerceRole.picker &&
      status == MembershipStatus.active;
}

/// The picker-assignment **slot** for one order, as loaded from storage.
///
/// One logical picker position per order. It holds at most one attempt at a
/// time, and its [slotRevision] is the concurrency control for every mutation.
@immutable
class PickerAssignmentFacts {
  const PickerAssignmentFacts({
    required this.resourceId,
    required this.slotRevision,
    required this.orderState,
    required this.orderRegionId,
    this.attempt,
  });

  final String resourceId;

  /// Increments on **every** applied picker-assignment mutation. Distinct from
  /// [PickerAssignmentAttempt.generation], which changes only on a new offer.
  final int slotRevision;

  /// Current trusted order state, re-read for this request. A stale offer must
  /// not be accepted after the order became ineligible, and a client-cached
  /// order state is never used.
  final OrderState orderState;

  /// Region the order belongs to.
  final String? orderRegionId;

  /// Current attempt, or null when the order has never had one.
  final PickerAssignmentAttempt? attempt;

  bool get hasAttempt => attempt != null;

  /// Number of picker assignments currently active. Structurally 0 or 1: the
  /// slot holds one attempt, and only an `accepted` one counts.
  int get activeAcceptedCount =>
      attempt?.state == AssignmentState.accepted ? 1 : 0;
}

/// Order states that may carry picker assignment work.
///
/// Offering before acceptance would assign work the shop has not agreed to do.
/// `placed`, `rejected` and `cancelled` are excluded, and `inDelivery` /
/// `delivered` are not implemented anywhere yet.
const Set<OrderState> assignmentEligibleOrderStates = <OrderState>{
  OrderState.accepted,
  OrderState.preparing,
  OrderState.ready,
};

/// One picker-assignment transition request.
///
/// Authorization, idempotency and command→permission mapping have **already
/// happened**. This carries no grant and no payload: duplicating FND-003A's
/// checks here would create a second place for them to drift.
@immutable
class PickerAssignmentRequest {
  const PickerAssignmentRequest({
    required this.command,
    required this.expectedSlotRevision,
    required this.actingPrincipalId,
    this.assignmentId,
    this.generation,
    this.newAssignmentId,
    this.targetEligibility,
    this.timeoutPolicyRef,
    this.expiryDue = false,
    this.reassignmentSafety = ReassignmentSafety.blockedOrUnknown,
  });

  final AssignmentCommand command;

  /// Slot revision the caller believes is current.
  final int expectedSlotRevision;

  /// Principal the backend derived from **verified authentication**.
  final String actingPrincipalId;

  /// Attempt the command targets. Must match the attempt in the slot.
  final String? assignmentId;

  /// Generation the command targets. Must match the attempt's.
  final int? generation;

  /// Server-generated opaque id for a **new** offer attempt.
  final String? newAssignmentId;

  /// Trusted membership facts for the offer target.
  final PickerEligibility? targetEligibility;

  /// Immutable, versioned timeout policy the new offer lapses under.
  final String? timeoutPolicyRef;

  /// Trusted determination that the offer's timeout has elapsed.
  ///
  /// The backend computes this by resolving the attempt's
  /// [PickerAssignmentAttempt.timeoutPolicyRef] against **server UTC**. It is
  /// never taken from a client payload, and this boolean is not itself proof of
  /// trust — it is the shape the backend fills. Defaults to false so expiry
  /// fails closed.
  final bool expiryDue;

  /// Trusted custody-safety determination for controlled reassignment.
  /// Defaults to [ReassignmentSafety.blockedOrUnknown] so revocation fails
  /// closed when the backend says nothing.
  final ReassignmentSafety reassignmentSafety;
}

/// A permitted picker-assignment transition, fully specified.
@immutable
class PickerAssignmentTransition {
  const PickerAssignmentTransition({
    required this.command,
    required this.fromState,
    required this.toState,
    required this.assignmentId,
    required this.generation,
    required this.resultingSlotRevision,
    required this.offerRecipientPrincipalId,
    required this.acceptedAssigneePrincipalId,
    required this.scopeEffect,
    required this.eventType,
    this.inventoryEffect = const InventoryEffect.none(),
    this.financialClassification = FinancialClassification.noneInThisSlice,
    this.custodyClassification = CustodyClassification.noneInThisSlice,
  });

  final AssignmentCommand command;

  /// Null when this transition creates the attempt.
  final AssignmentState? fromState;
  final AssignmentState toState;

  final String assignmentId;
  final int generation;

  /// Always `slotRevision + 1`: every applied mutation advances it, which is
  /// what makes a stale `expectedSlotRevision` detectable.
  final int resultingSlotRevision;

  final String offerRecipientPrincipalId;
  final String? acceptedAssigneePrincipalId;

  final ScopeProjectionEffect scopeEffect;
  final String eventType;

  /// Assignment never touches stock.
  final InventoryEffect inventoryEffect;

  /// Assignment moves no money. Offering or accepting a worker creates no COD
  /// liability, commission or settlement.
  final FinancialClassification financialClassification;

  /// Assignment is not custody.
  final CustodyClassification custodyClassification;

  @override
  String toString() =>
      'PickerAssignmentTransition(${command.commandType}: '
      '${fromState?.id ?? '-'} -> ${toState.id}, id=$assignmentId, '
      'gen=$generation, rev=$resultingSlotRevision)';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class PickerAssignmentOutcome {
  const PickerAssignmentOutcome._(this.transition, this.denial);

  const PickerAssignmentOutcome.allow(PickerAssignmentTransition transition)
    : this._(transition, null);

  const PickerAssignmentOutcome.deny(AssignmentDenial denial)
    : this._(null, denial);

  final PickerAssignmentTransition? transition;
  final AssignmentDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Canonical assignment-state → aggregate shape.
///
/// Learned from FND-003B1: the transition graph never *creates* an impossible
/// aggregate, but facts arrive from **storage**. A partially loaded,
/// mid-migration or externally-written attempt must not drive a projection
/// change or an event.
///
/// Returns null when the facts are canonical. Never repairs anything — repair
/// without an audit trail is indistinguishable from a bug, and belongs to
/// reconciliation tooling.
AssignmentDenial? validatePickerAssignmentAggregate(
  PickerAssignmentFacts facts,
) {
  if (facts.slotRevision < 0) {
    return AssignmentDenial.aggregateInconsistent;
  }

  final PickerAssignmentAttempt? attempt = facts.attempt;
  if (attempt == null) {
    // No attempt yet: the slot must not have been mutated.
    return facts.slotRevision == 0
        ? null
        : AssignmentDenial.aggregateInconsistent;
  }

  // A slot holding an attempt has been written at least once.
  if (facts.slotRevision < 1) {
    return AssignmentDenial.aggregateInconsistent;
  }
  if (!AssignmentState.executableInThisSlice.contains(attempt.state)) {
    // `completed` is declared but not implemented; validating its shape would
    // mean inventing one. Reported as unknownTransition by the evaluator.
    return null;
  }
  if (!isValidOpaqueId(attempt.assignmentId)) {
    return AssignmentDenial.aggregateInconsistent;
  }
  if (attempt.generation < 1) {
    return AssignmentDenial.aggregateInconsistent;
  }
  if (attempt.offerRecipientPrincipalId.isEmpty) {
    // The recipient is immutable history and is never erased.
    return AssignmentDenial.aggregateInconsistent;
  }
  if (attempt.timeoutPolicyRef.trim().isEmpty) {
    return AssignmentDenial.aggregateInconsistent;
  }

  final String? assignee = attempt.acceptedAssigneePrincipalId;
  switch (attempt.state) {
    case AssignmentState.offered:
    case AssignmentState.declined:
    case AssignmentState.expired:
      // Never accepted, so no assignee may exist.
      if (assignee != null) {
        return AssignmentDenial.aggregateInconsistent;
      }
    case AssignmentState.accepted:
    case AssignmentState.revoked:
      // Was accepted, so the assignee is recorded — and it can only ever have
      // been the worker the offer was addressed to.
      if (assignee == null ||
          assignee != attempt.offerRecipientPrincipalId) {
        return AssignmentDenial.aggregateInconsistent;
      }
    case AssignmentState.completed:
      return null;
  }
  return null;
}

/// Evaluate one picker-assignment transition.
///
/// Pure: no I/O, no clock, no storage. Wall-clock time and client arrival order
/// are not concurrency control — server transaction and slot-revision ordering
/// decide races.
///
/// Any edge not enumerated fails closed.
PickerAssignmentOutcome evaluatePickerAssignment({
  required PickerAssignmentRequest request,
  required PickerAssignmentFacts facts,
}) {
  // 1. Aggregate integrity, before anything can produce an effect.
  final AssignmentDenial? corruption = validatePickerAssignmentAggregate(facts);
  if (corruption != null) {
    return PickerAssignmentOutcome.deny(corruption);
  }

  // 2. An attempt in a state this slice does not own is refused outright.
  final PickerAssignmentAttempt? attempt = facts.attempt;
  if (attempt != null &&
      !AssignmentState.executableInThisSlice.contains(attempt.state)) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.unknownTransition,
    );
  }

  // 3. Concurrency. Checked before command dispatch so every mutating command
  //    is protected identically.
  if (request.expectedSlotRevision != facts.slotRevision) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.slotRevisionConflict,
    );
  }

  // 4. The order must currently be able to carry assignment work. Re-checked
  //    for every command, including acceptance of an older offer.
  if (!assignmentEligibleOrderStates.contains(facts.orderState)) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.orderNotAssignmentEligible,
    );
  }

  return switch (request.command) {
    AssignmentCommand.offerPickerAssignment => _evaluateOffer(request, facts),
    AssignmentCommand.acceptPickerAssignment => _evaluateAccept(request, facts),
    AssignmentCommand.declinePickerAssignment =>
      _evaluateDecline(request, facts),
    AssignmentCommand.expirePickerOffer => _evaluateExpiry(request, facts),
    AssignmentCommand.revokePickerAssignment => _evaluateRevoke(request, facts),
  };
}

PickerAssignmentOutcome _evaluateOffer(
  PickerAssignmentRequest request,
  PickerAssignmentFacts facts,
) {
  final PickerAssignmentAttempt? current = facts.attempt;

  // One live offer and one active accepted assignment per order. Distinguished
  // so the denial says which invariant blocked it.
  if (current != null && current.state == AssignmentState.offered) {
    return const PickerAssignmentOutcome.deny(AssignmentDenial.liveOfferExists);
  }
  if (current != null && current.state == AssignmentState.accepted) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.activeAcceptedAssignmentExists,
    );
  }

  final String? newId = request.newAssignmentId;
  if (newId == null || !isValidOpaqueId(newId)) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.assignmentIdInvalid,
    );
  }
  final String policyRef = request.timeoutPolicyRef?.trim() ?? '';
  if (policyRef.isEmpty) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.timeoutPolicyMissing,
    );
  }

  final PickerEligibility? target = request.targetEligibility;
  if (target == null || !target.qualifiesAsActivePicker) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.targetNotEligible,
    );
  }
  // Absence is not a match on either side.
  if (target.regionId == null ||
      facts.orderRegionId == null ||
      target.regionId != facts.orderRegionId) {
    return const PickerAssignmentOutcome.deny(AssignmentDenial.regionMismatch);
  }

  // A new attempt always takes the next generation. Re-offering never reuses
  // an id or a generation, so a delayed command from the old attempt cannot
  // match the new one.
  final int nextGeneration = (current?.generation ?? 0) + 1;

  return PickerAssignmentOutcome.allow(
    PickerAssignmentTransition(
      command: AssignmentCommand.offerPickerAssignment,
      fromState: null,
      toState: AssignmentState.offered,
      assignmentId: newId,
      generation: nextGeneration,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: target.principalId,
      // Offering is not assigning.
      acceptedAssigneePrincipalId: null,
      scopeEffect: ScopeProjectionEffect(
        addToOffered: <String>{target.principalId},
      ),
      eventType: AssignmentEventType.pickerOffered,
    ),
  );
}

/// Shared guard for every command that acts on the current attempt.
AssignmentDenial? _requireCurrentAttempt(
  PickerAssignmentRequest request,
  PickerAssignmentAttempt? attempt,
) {
  if (attempt == null) {
    return AssignmentDenial.noAssignmentAttempt;
  }
  // Identity before generation: a command naming a different attempt is never
  // applied to whatever happens to be in the slot just because the order
  // matches.
  if (request.assignmentId != attempt.assignmentId) {
    return AssignmentDenial.assignmentIdMismatch;
  }
  if (request.generation != attempt.generation) {
    return AssignmentDenial.generationMismatch;
  }
  return null;
}

PickerAssignmentOutcome _evaluateAccept(
  PickerAssignmentRequest request,
  PickerAssignmentFacts facts,
) {
  final PickerAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return PickerAssignmentOutcome.deny(mismatch);
  }
  final PickerAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  // Only the worker the offer was addressed to. Being a picker in the right
  // region is not enough — otherwise any nearby worker could take another's
  // offer.
  if (request.actingPrincipalId != current.offerRecipientPrincipalId) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.notOfferRecipient,
    );
  }

  return PickerAssignmentOutcome.allow(
    PickerAssignmentTransition(
      command: AssignmentCommand.acceptPickerAssignment,
      fromState: AssignmentState.offered,
      toState: AssignmentState.accepted,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      // History keeps the recipient; the assignee now names the same worker.
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: request.actingPrincipalId,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
        addToAssigned: <String>{request.actingPrincipalId},
      ),
      eventType: AssignmentEventType.pickerAccepted,
    ),
  );
}

PickerAssignmentOutcome _evaluateDecline(
  PickerAssignmentRequest request,
  PickerAssignmentFacts facts,
) {
  final PickerAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return PickerAssignmentOutcome.deny(mismatch);
  }
  final PickerAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  if (request.actingPrincipalId != current.offerRecipientPrincipalId) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.notOfferRecipient,
    );
  }

  return PickerAssignmentOutcome.allow(
    PickerAssignmentTransition(
      command: AssignmentCommand.declinePickerAssignment,
      fromState: AssignmentState.offered,
      toState: AssignmentState.declined,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: null,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
      ),
      eventType: AssignmentEventType.pickerDeclined,
    ),
  );
}

PickerAssignmentOutcome _evaluateExpiry(
  PickerAssignmentRequest request,
  PickerAssignmentFacts facts,
) {
  final PickerAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return PickerAssignmentOutcome.deny(mismatch);
  }
  final PickerAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    // Accepted, declined or already expired: nothing to lapse.
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  // The backend resolves the attempt's timeout policy against server UTC. No
  // duration exists in this contract, and a client cannot force an early
  // expiry.
  if (!request.expiryDue) {
    return const PickerAssignmentOutcome.deny(AssignmentDenial.expiryNotDue);
  }

  return PickerAssignmentOutcome.allow(
    PickerAssignmentTransition(
      command: AssignmentCommand.expirePickerOffer,
      fromState: AssignmentState.offered,
      toState: AssignmentState.expired,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: null,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
      ),
      eventType: AssignmentEventType.pickerExpired,
    ),
  );
}

PickerAssignmentOutcome _evaluateRevoke(
  PickerAssignmentRequest request,
  PickerAssignmentFacts facts,
) {
  final PickerAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return PickerAssignmentOutcome.deny(mismatch);
  }
  final PickerAssignmentAttempt current = attempt!;

  // Only an accepted assignment can be withdrawn. Revoking an offer is not a
  // thing: an unanswered offer declines or expires.
  if (current.state != AssignmentState.accepted) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  // Fails closed: unknown custody is not safe custody.
  if (!request.reassignmentSafety.permitsRevocation) {
    return const PickerAssignmentOutcome.deny(
      AssignmentDenial.reassignmentUnsafe,
    );
  }

  return PickerAssignmentOutcome.allow(
    PickerAssignmentTransition(
      command: AssignmentCommand.revokePickerAssignment,
      fromState: AssignmentState.accepted,
      toState: AssignmentState.revoked,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      // Both identities are retained. Revocation ends the assignment; it does
      // not erase who held it, and it never overwrites an assignee with a
      // different principal.
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: current.acceptedAssigneePrincipalId,
      scopeEffect: ScopeProjectionEffect(
        removeFromAssigned: <String>{current.acceptedAssigneePrincipalId!},
      ),
      eventType: AssignmentEventType.pickerRevoked,
    ),
  );
}
