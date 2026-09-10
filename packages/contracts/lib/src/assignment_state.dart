/// Lifecycle of one **assignment attempt**.
///
/// Shared by picker and rider assignment so the vocabulary does not fork, but
/// FND-003B2A implements the **picker** lifecycle only.
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

  /// **NOT EXECUTABLE IN FND-003B2A.** An accepted assignment finished its
  /// work. Declared for enum and wire stability only: completion depends on
  /// custody and handoff, which FND-003B3 owns. No transition enters it here,
  /// and none was guessed.
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

  /// States this slice's evaluator may read or produce.
  static const Set<AssignmentState> executableInThisSlice = <AssignmentState>{
    AssignmentState.offered,
    AssignmentState.accepted,
    AssignmentState.declined,
    AssignmentState.expired,
    AssignmentState.revoked,
  };

  /// Declared for stability, owned by a later slice.
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
/// `rider` is declared so the enum and its wire values are stable when
/// FND-003B2B lands. **No rider command or transition is executable here**, and
/// none was guessed.
enum AssignmentRole {
  picker,
  rider;

  String get id => switch (this) {
    AssignmentRole.picker => 'picker',
    AssignmentRole.rider => 'rider',
  };

  /// Only picker assignment is implemented in FND-003B2A.
  static const Set<AssignmentRole> executableInThisSlice = <AssignmentRole>{
    AssignmentRole.picker,
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
