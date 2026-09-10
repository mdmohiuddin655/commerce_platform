/// Lifecycle of one **assignment attempt**.
///
/// Shared by picker (FND-003B2A) and rider (FND-003B2B) assignment so the
/// vocabulary does not fork. Both run the same pre-custody attempt
/// transitions, which is why one revision model serves both — see
/// `reachableSlotRevisionRange`.
enum AssignmentState {
  /// Work has been offered to one worker who has not yet answered. The offer
  /// is live and expirable.
  offered,

  /// The offer recipient accepted. The assignment is active.
  ///
  /// **Accepting is not custody.** No goods have moved, the order has not
  /// dispatched, and no cash responsibility exists. Assignment notification,
  /// assignment acceptance and physical custody are three different facts.
  accepted,

  /// The recipient refused. **Terminal** for this attempt.
  declined,

  /// The offer lapsed under its timeout policy before it was answered.
  /// **Terminal** for this attempt.
  expired,

  /// An accepted assignment was withdrawn under controlled reassignment.
  /// **Terminal** for this attempt; the historical assignee is retained.
  revoked,

  /// **NOT EXECUTABLE — neither picker nor rider.** An accepted assignment
  /// finished its work. Declared for enum and wire stability only: completion
  /// depends on custody and handoff, which FND-003B3 owns. No transition in
  /// either assignment lifecycle enters it, and no mutation cost for it was
  /// guessed. See contract criteria B3-C1 and B3-C2.
  completed;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    AssignmentState.offered => 'offered',
    AssignmentState.accepted => 'accepted',
    AssignmentState.declined => 'declined',
    AssignmentState.expired => 'expired',
    AssignmentState.revoked => 'revoked',
    AssignmentState.completed => 'completed',
  };

  /// States the **pre-custody assignment evaluators** may read or produce.
  ///
  /// Role-neutral: the picker and rider evaluators produce exactly this set,
  /// which is what makes one shared `reachableSlotRevisionRange` correct for
  /// both. A state added here without a mutation cost would make every
  /// aggregate in that state fail closed.
  static const Set<AssignmentState> executableInThisSlice = <AssignmentState>{
    AssignmentState.offered,
    AssignmentState.accepted,
    AssignmentState.declined,
    AssignmentState.expired,
    AssignmentState.revoked,
  };

  /// Declared for stability, owned by FND-003B3 (custody and handoff).
  static const Set<AssignmentState> notYetImplemented = <AssignmentState>{
    AssignmentState.completed,
  };

  /// The attempt is over. A new offer needs a **new attempt**, never a
  /// resurrection of this one.
  bool get isTerminal =>
      this == AssignmentState.declined ||
      this == AssignmentState.expired ||
      this == AssignmentState.revoked ||
      this == AssignmentState.completed;

  /// The attempt currently occupies the slot: no new offer may be made while
  /// this holds.
  bool get occupiesSlot =>
      this == AssignmentState.offered || this == AssignmentState.accepted;

  static AssignmentState? byId(String id) {
    for (final AssignmentState s in AssignmentState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}

/// Which kind of field work an assignment is for.
///
/// Both roles are now implemented: picker assignment by FND-003B2A, rider
/// assignment by FND-003B2B. They share the state vocabulary and the revision
/// model but keep separate evaluators, because their **authority** differs — a
/// picker offer comes from the shop's agent, a rider offer from the order's
/// current accepted picker.
enum AssignmentRole {
  picker,
  rider;

  String get id => switch (this) {
    AssignmentRole.picker => 'picker',
    AssignmentRole.rider => 'rider',
  };

  /// Assignment roles with an implemented lifecycle.
  ///
  /// Both, as of FND-003B2B. This says the role has an evaluator, named
  /// commands and events — **not** that custody, handoff or delivery exist for
  /// it. Those remain FND-003B3's.
  static const Set<AssignmentRole> executableInThisSlice = <AssignmentRole>{
    AssignmentRole.picker,
    AssignmentRole.rider,
  };

  static AssignmentRole? byId(String id) {
    for (final AssignmentRole r in AssignmentRole.values) {
      if (r.id == id) {
        return r;
      }
    }
    return null;
  }
}
