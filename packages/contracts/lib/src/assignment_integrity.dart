import 'package:cp_contracts/src/assignment_state.dart';

/// Why an assignment transition was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason` and
/// `LifecycleDenial` are not.
///
/// One vocabulary for both assignment roles. Picker and rider run the same
/// pre-custody attempt lifecycle, so forking the denial vocabulary would mean
/// two sets of near-identical names drifting apart. The four
/// `…Picker…`-flavoured values at the end are the *cross-aggregate* reasons
/// only the rider lifecycle can produce, because only it depends on a second
/// aggregate.
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

  /// The order is not in a state that may carry assignment work.
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

  /// A new offer tried to reuse the current terminal attempt's own
  /// `assignmentId`.
  ///
  /// A new attempt is a **new fact**, not a resurrection of the old one.
  /// Reusing the identifier would collapse two attempts into one in every
  /// audit trail, event stream and stored record — a later generation would be
  /// indistinguishable from the earlier one that failed. Advancing the
  /// generation is not a substitute for a distinct identity.
  assignmentIdReuse,

  /// The stored aggregate is a combination this lifecycle can never produce.
  /// **Corruption, not a race.**
  aggregateInconsistent,

  /// No such edge is enumerated. Fail closed.
  unknownTransition,

  // ------------------------------------------------- rider cross-aggregate
  //
  // Rider assignment is the first lifecycle that depends on a *second*
  // aggregate — the picker assignment slot for the same order. These four say
  // which part of that dependency failed, so a log does not have to guess
  // whether the rider slot or the picker slot was the problem.

  /// The order has no currently **accepted** picker assignment, so there is no
  /// picker with the authority to offer rider work on it.
  noAcceptedPickerAssignment,

  /// The acting principal is not the picker currently holding the accepted
  /// picker assignment for this order. Holding the picker role, or an
  /// assignment on some *other* order, is not authority over this one.
  notCurrentAcceptedPicker,

  /// The rider attempt's recorded source picker assignment is no longer the
  /// order's current accepted picker assignment.
  ///
  /// This is what stops a rider offer created by picker A being accepted as
  /// though picker B — who replaced A — had created it.
  sourcePickerAssignmentMismatch,

  /// The supplied picker-assignment facts are unusable as authority: they fail
  /// picker aggregate validation, or they describe a different resource or a
  /// conflicting region.
  pickerAuthorityInconsistent,
}

/// The `slotRevision` values a `(generation, state)` pair can actually have
/// been reached by, given the transitions the assignment lifecycles implement.
///
/// **Role-neutral by construction.** Picker and rider run the same pre-custody
/// attempt transitions — `offered`, `accepted`, `declined`, `expired`,
/// `revoked` — with the same mutation costs, so this is one canonical helper
/// used by both evaluators rather than two formulas that can disagree.
///
/// Every attempt costs at least two mutations — the offer and one terminal
/// outcome (decline or expiry) — and at most three, when it was accepted and
/// then revoked. So the `generation - 1` attempts before the current one
/// consumed between `2(g-1)` and `3(g-1)` revisions, and the current attempt
/// adds one, two or three depending on how far it has got.
///
/// | State | Reachable revisions |
/// |---|---|
/// | `offered` | `2g-1` … `3g-2` |
/// | `accepted` / `declined` / `expired` | `2g` … `3g-1` |
/// | `revoked` | `2g+1` … `3g` |
///
/// A stored pair outside its range describes a history this state machine
/// cannot produce — generation 2 at revision 1, say, or generation 1 at
/// revision 99. Checking only `slotRevision >= 1` would accept both.
///
/// Returns null when no range can be stated: a non-positive generation, or a
/// state whose mutation cost is not defined for [role].
///
/// ## `completed` and [role] — added additively by FND-003B3A
///
/// The five pre-custody ranges above are **identical for both roles and do not
/// depend on [role] at all**. Only `completed` does.
///
/// [role] is optional and defaults to null, which preserves this function's
/// pre-B3A behaviour **exactly**: `completed` returns null. Existing callers
/// that ask a purely pre-custody question keep the answer they always had.
///
/// - `role: AssignmentRole.picker` — FND-003B3A makes picker completion
///   reachable, caused by rider custody receipt. An offer, an acceptance and a
///   completion is **three** mutations for that generation, the same
///   per-generation cost as the accept-then-revoke path.
/// - `role: AssignmentRole.rider` — still null. Rider completion depends on
///   delivery, which no slice implements, and **no cost for it was invented**.
///   That is contract criterion **B3-C2**, and it stays FUTURE.
///
/// **Maintenance invariant.** This is arithmetic over the currently executable
/// transitions, not an independent rule. Adding an executable state, changing
/// a per-generation mutation cost, or changing whether a transition increments
/// `slotRevision` must update this helper in the same change — otherwise
/// *valid* histories start failing closed as `aggregateInconsistent`. See
/// contract criteria B3-C1 (picker) and B3-C2 (rider).
({int min, int max})? reachableSlotRevisionRange(
  int generation,
  AssignmentState state, {
  AssignmentRole? role,
}) {
  if (generation < 1) {
    return null;
  }
  final int priorMinimum = 2 * (generation - 1);
  final int priorMaximum = 3 * (generation - 1);

  return switch (state) {
    // offer
    AssignmentState.offered => (min: priorMinimum + 1, max: priorMaximum + 1),
    // offer + outcome
    AssignmentState.accepted ||
    AssignmentState.declined ||
    AssignmentState.expired => (min: priorMinimum + 2, max: priorMaximum + 2),
    // offer + accept + revoke
    AssignmentState.revoked => (min: priorMinimum + 3, max: priorMaximum + 3),
    // offer + accept + completion, for the picker only.
    AssignmentState.completed => role == AssignmentRole.picker
        ? (min: priorMinimum + 3, max: priorMaximum + 3)
        : null,
  };
}
