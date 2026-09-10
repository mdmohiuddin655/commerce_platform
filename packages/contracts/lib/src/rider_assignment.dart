import 'package:cp_contracts/src/assignment_command.dart';
import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/assignment_integrity.dart';
import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/membership.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/picker_assignment.dart';
import 'package:cp_contracts/src/role.dart';
import 'package:meta/meta.dart';

/// The picker assignment an offer of rider work originated from.
///
/// **Immutable history, carried on the rider attempt itself.** Rider work is
/// not offered by the shop in this lifecycle — it is offered by the picker who
/// currently holds the order's accepted picker assignment. That makes a rider
/// attempt meaningless except relative to a *specific* picker assignment, so
/// the binding is recorded rather than re-derived.
///
/// It is deliberately not read back from
/// `ResourceScope.assignedPrincipalIds`. That projection says who is assigned
/// **now**; it cannot say which picker assignment created an offer, and a
/// projection rebuilt after a picker was replaced would silently answer with
/// the replacement. Historical proof has to be stored as history.
@immutable
class SourcePickerBinding {
  const SourcePickerBinding({
    required this.pickerPrincipalId,
    required this.pickerAssignmentId,
    required this.pickerGeneration,
  });

  /// Picker who made the offer — the accepted assignee of
  /// [pickerAssignmentId] at the time.
  final String pickerPrincipalId;

  /// Opaque id of the picker assignment attempt that authorised the offer.
  final String pickerAssignmentId;

  /// Generation of that picker attempt.
  final int pickerGeneration;

  /// Whether [attempt] is still the picker assignment this binding names.
  ///
  /// All three facts must match. The generation alone is not enough — a
  /// replacement attempt takes a new generation *and* a new id, and comparing
  /// only one of them would accept a different attempt that happened to line
  /// up.
  bool matchesCurrentPicker(PickerAssignmentAttempt attempt) =>
      attempt.assignmentId == pickerAssignmentId &&
      attempt.generation == pickerGeneration &&
      attempt.acceptedAssigneePrincipalId == pickerPrincipalId;

  @override
  String toString() => 'SourcePickerBinding($pickerPrincipalId via '
      '$pickerAssignmentId gen=$pickerGeneration)';
}

/// One rider-assignment **attempt**.
///
/// An attempt is immutable history. Re-offering after a terminal attempt
/// creates a *new* attempt with a new [assignmentId] and the next
/// [generation]; the previous one is never edited or resurrected.
@immutable
class RiderAssignmentAttempt {
  const RiderAssignmentAttempt({
    required this.assignmentId,
    required this.generation,
    required this.state,
    required this.offerRecipientPrincipalId,
    required this.timeoutPolicyRef,
    required this.source,
    this.acceptedAssigneePrincipalId,
  });

  /// Opaque, server-generated, unique to this attempt. **Never a global
  /// sequential counter** — [generation] carries ordering, this carries
  /// identity.
  final String assignmentId;

  /// Per-order version of the rider assignment slot. Increases only when a
  /// **new attempt** is created, which is what makes a delayed command from an
  /// older attempt detectable.
  final int generation;

  final AssignmentState state;

  /// Rider the offer was addressed to. **Immutable history** — it stays
  /// recorded after decline, expiry, acceptance and revocation.
  final String offerRecipientPrincipalId;

  /// Rider who accepted, or null before acceptance. Distinct from
  /// [offerRecipientPrincipalId] on purpose: being offered work is not holding
  /// it, and after revocation the historical assignee remains recorded while
  /// ceasing to be *active*.
  final String? acceptedAssigneePrincipalId;

  /// Reference to the immutable, versioned timeout policy this offer lapses
  /// under. **No duration lives in this contract.**
  final String timeoutPolicyRef;

  /// The picker assignment this offer came from. Retained through every
  /// terminal state.
  final SourcePickerBinding source;

  /// True while this attempt occupies the slot.
  bool get isActive => state.occupiesSlot;

  @override
  String toString() =>
      'RiderAssignmentAttempt($assignmentId, gen=$generation, ${state.id}, '
      'offeredTo=$offerRecipientPrincipalId, '
      'accepted=${acceptedAssigneePrincipalId ?? '-'}, from=$source)';
}

/// Trusted facts about a target rider, loaded from **authoritative membership
/// storage** for this request.
///
/// > This object is **not proof of trust**. It is the shape the backend fills
/// > from current membership records. A caller cannot make a rider eligible by
/// > constructing one, because a caller never reaches this evaluator — the
/// > backend does, having loaded the facts itself.
///
/// Deliberately absent: workload limits, availability scores, ratings, route
/// distance, vehicle type, shift schedules. Those are **dispatch policy**, not
/// lifecycle, and none was invented here.
@immutable
class RiderEligibility {
  const RiderEligibility({
    required this.principalId,
    required this.isHumanPrincipal,
    required this.membershipPrincipalId,
    required this.role,
    required this.status,
    required this.regionId,
  });

  final String principalId;

  /// False for a system worker. Delivery work is offered to people.
  final bool isHumanPrincipal;

  /// Principal the loaded membership actually belongs to. A membership naming
  /// somebody else grants nothing.
  final String membershipPrincipalId;

  final CommerceRole role;
  final MembershipStatus status;

  /// Region the rider's membership covers.
  final String? regionId;

  /// Whether these facts qualify the worker to receive rider work at all.
  /// Region matching is checked separately, against the order.
  bool get qualifiesAsActiveRider =>
      isHumanPrincipal &&
      membershipPrincipalId == principalId &&
      role == CommerceRole.rider &&
      status == MembershipStatus.active;
}

/// The rider-assignment **slot** for one order, as loaded from storage.
///
/// One logical rider position per order, separate from the picker slot and
/// with its own [slotRevision]. It holds at most one attempt at a time.
@immutable
class RiderAssignmentFacts {
  const RiderAssignmentFacts({
    required this.resourceId,
    required this.slotRevision,
    required this.orderState,
    required this.orderRegionId,
    this.attempt,
  });

  final String resourceId;

  /// Increments on **every** applied rider-assignment mutation. Distinct from
  /// [RiderAssignmentAttempt.generation], which changes only on a new offer,
  /// and independent of the picker slot's revision.
  final int slotRevision;

  /// Current trusted order state, re-read for this request. A stale offer must
  /// not be accepted after the order became ineligible, and a client-cached
  /// order state is never used.
  final OrderState orderState;

  /// Region the order belongs to.
  final String? orderRegionId;

  /// Current attempt, or null when the order has never had one.
  final RiderAssignmentAttempt? attempt;

  bool get hasAttempt => attempt != null;

  /// Number of rider offers currently live. Structurally 0 or 1.
  int get liveOfferCount => attempt?.state == AssignmentState.offered ? 1 : 0;

  /// Number of rider assignments currently active. Structurally 0 or 1: the
  /// slot holds one attempt, and only an `accepted` one counts.
  int get activeAcceptedCount =>
      attempt?.state == AssignmentState.accepted ? 1 : 0;
}

/// One rider-assignment transition request.
///
/// Authorization, idempotency and command→permission mapping have **already
/// happened**. This carries no grant and no payload: duplicating FND-003A's
/// checks here would create a second place for them to drift.
@immutable
class RiderAssignmentRequest {
  const RiderAssignmentRequest({
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

  /// Rider slot revision the caller believes is current.
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
  final RiderEligibility? targetEligibility;

  /// Immutable, versioned timeout policy the new offer lapses under.
  final String? timeoutPolicyRef;

  /// Trusted determination that the offer's timeout has elapsed.
  ///
  /// The backend computes this by resolving the attempt's
  /// [RiderAssignmentAttempt.timeoutPolicyRef] against **server UTC**. It is
  /// never taken from a client payload, and this boolean is not itself proof
  /// of trust — it is the shape the backend fills. Defaults to false so expiry
  /// fails closed.
  final bool expiryDue;

  /// Trusted custody-safety determination for controlled reassignment.
  /// Defaults to [ReassignmentSafety.blockedOrUnknown] so revocation fails
  /// closed when the backend says nothing.
  final ReassignmentSafety reassignmentSafety;
}

/// A permitted rider-assignment transition, fully specified.
@immutable
class RiderAssignmentTransition {
  const RiderAssignmentTransition({
    required this.command,
    required this.fromState,
    required this.toState,
    required this.assignmentId,
    required this.generation,
    required this.resultingSlotRevision,
    required this.offerRecipientPrincipalId,
    required this.acceptedAssigneePrincipalId,
    required this.source,
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

  /// Preserved unchanged by every transition after the offer.
  final SourcePickerBinding source;

  final ScopeProjectionEffect scopeEffect;
  final String eventType;

  /// Rider assignment never touches stock. The FND-003B1 reservation is not
  /// read or written here.
  final InventoryEffect inventoryEffect;

  /// Rider assignment moves no money. Offering or accepting a rider creates no
  /// COD liability, commission or settlement.
  final FinancialClassification financialClassification;

  /// Rider assignment is not custody. Accepting delivery work is not
  /// receiving goods.
  final CustodyClassification custodyClassification;

  @override
  String toString() =>
      'RiderAssignmentTransition(${command.commandType}: '
      '${fromState?.id ?? '-'} -> ${toState.id}, id=$assignmentId, '
      'gen=$generation, rev=$resultingSlotRevision)';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class RiderAssignmentOutcome {
  const RiderAssignmentOutcome._(this.transition, this.denial);

  const RiderAssignmentOutcome.allow(RiderAssignmentTransition transition)
    : this._(transition, null);

  const RiderAssignmentOutcome.deny(AssignmentDenial denial)
    : this._(null, denial);

  final RiderAssignmentTransition? transition;
  final AssignmentDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Canonical rider assignment-state → aggregate shape.
///
/// Same lesson as FND-003B1 and the picker slot: the transition graph never
/// *creates* an impossible aggregate, but facts arrive from **storage**. A
/// partially loaded, mid-migration or externally-written attempt must not
/// drive a projection change or an event.
///
/// Returns null when the facts are canonical. Never repairs anything — repair
/// without an audit trail is indistinguishable from a bug, and belongs to
/// reconciliation tooling.
AssignmentDenial? validateRiderAssignmentAggregate(RiderAssignmentFacts facts) {
  if (facts.slotRevision < 0) {
    return AssignmentDenial.aggregateInconsistent;
  }
  if (facts.resourceId.isEmpty) {
    return AssignmentDenial.aggregateInconsistent;
  }

  final RiderAssignmentAttempt? attempt = facts.attempt;
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
  // The generation and the slot revision must describe a history this
  // lifecycle could actually have produced — not merely two positive numbers.
  // Shared arithmetic: picker and rider have identical mutation costs.
  final ({int min, int max})? reachable = reachableSlotRevisionRange(
    attempt.generation,
    attempt.state,
  );
  if (reachable == null ||
      facts.slotRevision < reachable.min ||
      facts.slotRevision > reachable.max) {
    return AssignmentDenial.aggregateInconsistent;
  }
  if (attempt.offerRecipientPrincipalId.isEmpty) {
    // The recipient is immutable history and is never erased.
    return AssignmentDenial.aggregateInconsistent;
  }
  if (attempt.timeoutPolicyRef.trim().isEmpty) {
    return AssignmentDenial.aggregateInconsistent;
  }

  // Source picker history is required in **every** state, not just while the
  // offer is live: an attempt that lost its origin can no longer be checked
  // against the current picker assignment, which is the whole protection
  // against a replaced picker inheriting another picker's offer.
  final SourcePickerBinding source = attempt.source;
  if (source.pickerPrincipalId.isEmpty ||
      !isValidOpaqueId(source.pickerAssignmentId) ||
      source.pickerGeneration < 1) {
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
      // been the rider the offer was addressed to.
      if (assignee == null || assignee != attempt.offerRecipientPrincipalId) {
        return AssignmentDenial.aggregateInconsistent;
      }
    case AssignmentState.completed:
      return null;
  }
  return null;
}

/// Evaluate one rider-assignment transition.
///
/// Pure: no I/O, no clock, no storage. Wall-clock time and client arrival
/// order are not concurrency control — server transaction and slot-revision
/// ordering decide races.
///
/// [pickerAuthority] is the order's **canonical picker assignment slot**, read
/// in the same trusted transaction as [facts]. It is required-named and
/// nullable so a caller has to state, at every call site, whether they are
/// supplying it — a command that needs it and receives null fails closed
/// rather than proceeding on a default. Commands that do not need it
/// (`decline`, `expire`) ignore it.
///
/// Passing this object is **not** proof that the picker facts were trusted;
/// it is the shape the backend fills from canonical storage. FND-003A's rule
/// stands: authorization is established freshly on every request, including
/// replays.
///
/// Any edge not enumerated fails closed.
RiderAssignmentOutcome evaluateRiderAssignment({
  required RiderAssignmentRequest request,
  required RiderAssignmentFacts facts,
  required PickerAssignmentFacts? pickerAuthority,
}) {
  // 1. Aggregate integrity, before anything can produce an effect.
  final AssignmentDenial? corruption = validateRiderAssignmentAggregate(facts);
  if (corruption != null) {
    return RiderAssignmentOutcome.deny(corruption);
  }

  // 2. An attempt in a state this lifecycle does not own is refused outright.
  final RiderAssignmentAttempt? attempt = facts.attempt;
  if (attempt != null &&
      !AssignmentState.executableInThisSlice.contains(attempt.state)) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.unknownTransition,
    );
  }

  // 3. Concurrency. Checked before command dispatch so every mutating command
  //    is protected identically.
  if (request.expectedSlotRevision != facts.slotRevision) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.slotRevisionConflict,
    );
  }

  // 4. The order must currently be able to carry assignment work. Re-checked
  //    for every command, including acceptance of an older offer. Same
  //    eligible set as picker assignment — no new order-stage policy was
  //    invented for rider work.
  if (!assignmentEligibleOrderStates.contains(facts.orderState)) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.orderNotAssignmentEligible,
    );
  }

  return switch (request.command) {
    AssignmentCommand.offerRiderAssignment =>
      _evaluateOffer(request, facts, pickerAuthority),
    AssignmentCommand.acceptRiderAssignment =>
      _evaluateAccept(request, facts, pickerAuthority),
    AssignmentCommand.declineRiderAssignment =>
      _evaluateDecline(request, facts),
    AssignmentCommand.expireRiderOffer => _evaluateExpiry(request, facts),
    AssignmentCommand.revokeRiderAssignment =>
      _evaluateRevoke(request, facts, pickerAuthority),
    // Every picker command. The rider evaluator never handles them: routing a
    // picker command here would apply picker rules to the rider slot.
    AssignmentCommand.offerPickerAssignment ||
    AssignmentCommand.acceptPickerAssignment ||
    AssignmentCommand.declinePickerAssignment ||
    AssignmentCommand.expirePickerOffer ||
    AssignmentCommand.revokePickerAssignment =>
      const RiderAssignmentOutcome.deny(AssignmentDenial.unknownTransition),
  };
}

/// The picker slot must be usable as authority at all: canonical, and about
/// **this** order.
///
/// The order facts are compared rather than assumed equal because the two
/// aggregates are supposed to come from one consistent read-set. If they
/// disagree, the read-set was not consistent, and continuing would mean
/// deciding rider authority from a different view of the order than the one
/// the rider slot was checked against.
AssignmentDenial? _validatePickerAuthorityShape(
  PickerAssignmentFacts? pickerAuthority,
  RiderAssignmentFacts facts,
) {
  if (pickerAuthority == null) {
    return AssignmentDenial.pickerAuthorityInconsistent;
  }
  if (validatePickerAssignmentAggregate(pickerAuthority) != null) {
    return AssignmentDenial.pickerAuthorityInconsistent;
  }
  if (pickerAuthority.resourceId != facts.resourceId) {
    return AssignmentDenial.pickerAuthorityInconsistent;
  }
  if (pickerAuthority.orderRegionId != facts.orderRegionId ||
      pickerAuthority.orderState != facts.orderState) {
    return AssignmentDenial.pickerAuthorityInconsistent;
  }
  return null;
}

/// The acting principal must be the picker **currently** holding the accepted
/// picker assignment for this order.
///
/// Not "a picker", not "a picker in this region", not "the picker id the
/// client sent" — the one the canonical picker slot names right now.
AssignmentDenial? _requireCurrentAcceptedPicker(
  PickerAssignmentFacts? pickerAuthority,
  RiderAssignmentFacts facts,
  String actingPrincipalId,
) {
  final AssignmentDenial? shape = _validatePickerAuthorityShape(
    pickerAuthority,
    facts,
  );
  if (shape != null) {
    return shape;
  }
  final PickerAssignmentAttempt? picker = pickerAuthority!.attempt;
  if (picker == null || picker.state != AssignmentState.accepted) {
    return AssignmentDenial.noAcceptedPickerAssignment;
  }
  if (picker.acceptedAssigneePrincipalId != actingPrincipalId) {
    return AssignmentDenial.notCurrentAcceptedPicker;
  }
  return null;
}

RiderAssignmentOutcome _evaluateOffer(
  RiderAssignmentRequest request,
  RiderAssignmentFacts facts,
  PickerAssignmentFacts? pickerAuthority,
) {
  final RiderAssignmentAttempt? current = facts.attempt;

  // One live offer and one active accepted rider per order. Distinguished so
  // the denial says which invariant blocked it.
  if (current != null && current.state == AssignmentState.offered) {
    return const RiderAssignmentOutcome.deny(AssignmentDenial.liveOfferExists);
  }
  if (current != null && current.state == AssignmentState.accepted) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.activeAcceptedAssignmentExists,
    );
  }

  // Authority before payload shape: whether this actor may offer rider work at
  // all is decided before what they are proposing is inspected.
  final AssignmentDenial? authority = _requireCurrentAcceptedPicker(
    pickerAuthority,
    facts,
    request.actingPrincipalId,
  );
  if (authority != null) {
    return RiderAssignmentOutcome.deny(authority);
  }
  // Non-null and accepted, established by the check above.
  final PickerAssignmentAttempt picker = pickerAuthority!.attempt!;

  final String? newId = request.newAssignmentId;
  if (newId == null || !isValidOpaqueId(newId)) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.assignmentIdInvalid,
    );
  }
  // A new attempt needs a new identity. Advancing the generation is not
  // enough: reusing the terminal attempt's id would make the two attempts
  // indistinguishable in events, audit and storage.
  //
  // The evaluator sees only the attempt currently in the slot, so it cannot
  // prove the id was never used by an older archived attempt. That is a
  // storage guarantee — server-generated ids and create-if-absent attempt
  // records — recorded as backend criterion RA11.
  if (current != null && newId == current.assignmentId) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.assignmentIdReuse,
    );
  }
  final String policyRef = request.timeoutPolicyRef?.trim() ?? '';
  if (policyRef.isEmpty) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.timeoutPolicyMissing,
    );
  }

  final RiderEligibility? target = request.targetEligibility;
  if (target == null || !target.qualifiesAsActiveRider) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.targetNotEligible,
    );
  }
  // Absence is not a match on either side.
  if (target.regionId == null ||
      facts.orderRegionId == null ||
      target.regionId != facts.orderRegionId) {
    return const RiderAssignmentOutcome.deny(AssignmentDenial.regionMismatch);
  }

  // A new attempt always takes the next generation. Re-offering never reuses
  // an id or a generation, so a delayed command from the old attempt cannot
  // match the new one.
  final int nextGeneration = (current?.generation ?? 0) + 1;

  return RiderAssignmentOutcome.allow(
    RiderAssignmentTransition(
      command: AssignmentCommand.offerRiderAssignment,
      fromState: null,
      toState: AssignmentState.offered,
      assignmentId: newId,
      generation: nextGeneration,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: target.principalId,
      // Offering is not assigning.
      acceptedAssigneePrincipalId: null,
      // Bound to the picker assignment that authorised it, as it stands now.
      source: SourcePickerBinding(
        pickerPrincipalId: request.actingPrincipalId,
        pickerAssignmentId: picker.assignmentId,
        pickerGeneration: picker.generation,
      ),
      scopeEffect: ScopeProjectionEffect(
        addToOffered: <String>{target.principalId},
      ),
      eventType: AssignmentEventType.riderOffered,
    ),
  );
}

/// Shared guard for every command that acts on the current attempt.
AssignmentDenial? _requireCurrentAttempt(
  RiderAssignmentRequest request,
  RiderAssignmentAttempt? attempt,
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

RiderAssignmentOutcome _evaluateAccept(
  RiderAssignmentRequest request,
  RiderAssignmentFacts facts,
  PickerAssignmentFacts? pickerAuthority,
) {
  final RiderAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return RiderAssignmentOutcome.deny(mismatch);
  }
  final RiderAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  // Only the rider the offer was addressed to. Being a rider in the right
  // region is not enough — otherwise any nearby rider could take another's
  // offer.
  if (request.actingPrincipalId != current.offerRecipientPrincipalId) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.notOfferRecipient,
    );
  }

  // The offer is only meaningful while the picker assignment that created it
  // is still the order's current accepted picker assignment.
  //
  // Without this, the following sequence would let a rider slip in under a
  // picker who never offered them anything:
  //
  //   picker A offers rider R -> A is revoked -> picker B accepts ->
  //   R's stale offer is accepted as though B had created it.
  final AssignmentDenial? shape = _validatePickerAuthorityShape(
    pickerAuthority,
    facts,
  );
  if (shape != null) {
    return RiderAssignmentOutcome.deny(shape);
  }
  final PickerAssignmentAttempt? picker = pickerAuthority!.attempt;
  if (picker == null || picker.state != AssignmentState.accepted) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.noAcceptedPickerAssignment,
    );
  }
  if (!current.source.matchesCurrentPicker(picker)) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.sourcePickerAssignmentMismatch,
    );
  }

  // Structurally guaranteed by the single-attempt slot — the current attempt
  // is `offered`, so nothing is accepted — but asserted rather than assumed,
  // because the invariant is the point.
  if (facts.activeAcceptedCount != 0) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.activeAcceptedAssignmentExists,
    );
  }

  return RiderAssignmentOutcome.allow(
    RiderAssignmentTransition(
      command: AssignmentCommand.acceptRiderAssignment,
      fromState: AssignmentState.offered,
      toState: AssignmentState.accepted,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      // History keeps the recipient; the assignee now names the same rider.
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: request.actingPrincipalId,
      source: current.source,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
        addToAssigned: <String>{request.actingPrincipalId},
      ),
      eventType: AssignmentEventType.riderAccepted,
    ),
  );
}

RiderAssignmentOutcome _evaluateDecline(
  RiderAssignmentRequest request,
  RiderAssignmentFacts facts,
) {
  final RiderAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return RiderAssignmentOutcome.deny(mismatch);
  }
  final RiderAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  if (request.actingPrincipalId != current.offerRecipientPrincipalId) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.notOfferRecipient,
    );
  }

  // Deliberately **no** source-picker currency requirement, unlike accept.
  // Declining only releases the offer: it grants the rider nothing, moves no
  // goods and creates no assignment. Requiring a current source picker here
  // would trap a rider under a replaced picker — unable to refuse work they
  // were never going to do — with no safety gained.

  return RiderAssignmentOutcome.allow(
    RiderAssignmentTransition(
      command: AssignmentCommand.declineRiderAssignment,
      fromState: AssignmentState.offered,
      toState: AssignmentState.declined,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: null,
      source: current.source,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
      ),
      eventType: AssignmentEventType.riderDeclined,
    ),
  );
}

RiderAssignmentOutcome _evaluateExpiry(
  RiderAssignmentRequest request,
  RiderAssignmentFacts facts,
) {
  final RiderAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return RiderAssignmentOutcome.deny(mismatch);
  }
  final RiderAssignmentAttempt current = attempt!;

  if (current.state != AssignmentState.offered) {
    // Accepted, declined or already expired: nothing to lapse.
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }
  // The backend resolves the attempt's timeout policy against server UTC. No
  // duration exists in this contract, and a client cannot force an early
  // expiry.
  if (!request.expiryDue) {
    return const RiderAssignmentOutcome.deny(AssignmentDenial.expiryNotDue);
  }

  return RiderAssignmentOutcome.allow(
    RiderAssignmentTransition(
      command: AssignmentCommand.expireRiderOffer,
      fromState: AssignmentState.offered,
      toState: AssignmentState.expired,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: null,
      source: current.source,
      scopeEffect: ScopeProjectionEffect(
        removeFromOffered: <String>{current.offerRecipientPrincipalId},
      ),
      eventType: AssignmentEventType.riderExpired,
    ),
  );
}

RiderAssignmentOutcome _evaluateRevoke(
  RiderAssignmentRequest request,
  RiderAssignmentFacts facts,
  PickerAssignmentFacts? pickerAuthority,
) {
  final RiderAssignmentAttempt? attempt = facts.attempt;
  final AssignmentDenial? mismatch = _requireCurrentAttempt(request, attempt);
  if (mismatch != null) {
    return RiderAssignmentOutcome.deny(mismatch);
  }
  final RiderAssignmentAttempt current = attempt!;

  // Only an accepted assignment can be withdrawn. Revoking an offer is not a
  // thing: an unanswered offer declines or expires.
  if (current.state != AssignmentState.accepted) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.wrongAssignmentState,
    );
  }

  // The actor must be the order's **current** accepted picker.
  //
  // Deliberately *not* `source.matchesCurrentPicker`. A replacement picker is
  // the legitimate current authority over this order's delivery work, and
  // requiring the original picker would strand an accepted rider whose picker
  // has since been replaced — with no in-contract way to resolve it. The
  // asymmetry with accept is intentional: accept grants a rider new standing
  // and so demands the offer's own origin still be current, whereas revoke
  // only withdraws standing and is the path RA17's backend serialization uses
  // to resolve a dependent rider slot.
  final AssignmentDenial? authority = _requireCurrentAcceptedPicker(
    pickerAuthority,
    facts,
    request.actingPrincipalId,
  );
  if (authority != null) {
    return RiderAssignmentOutcome.deny(authority);
  }

  // Fails closed: unknown custody is not safe custody.
  if (!request.reassignmentSafety.permitsRevocation) {
    return const RiderAssignmentOutcome.deny(
      AssignmentDenial.reassignmentUnsafe,
    );
  }

  return RiderAssignmentOutcome.allow(
    RiderAssignmentTransition(
      command: AssignmentCommand.revokeRiderAssignment,
      fromState: AssignmentState.accepted,
      toState: AssignmentState.revoked,
      assignmentId: current.assignmentId,
      generation: current.generation,
      resultingSlotRevision: facts.slotRevision + 1,
      // Every identity is retained. Revocation ends the assignment; it does
      // not erase who held it, never overwrites an assignee with a different
      // principal, and does not rewrite which picker originally offered it.
      offerRecipientPrincipalId: current.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: current.acceptedAssigneePrincipalId,
      source: current.source,
      scopeEffect: ScopeProjectionEffect(
        removeFromAssigned: <String>{current.acceptedAssigneePrincipalId!},
      ),
      eventType: AssignmentEventType.riderRevoked,
    ),
  );
}
