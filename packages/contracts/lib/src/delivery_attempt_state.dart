/// Outcome state of one delivery attempt.
///
/// An attempt is a **separate dimension from the order**. `OrderState` says
/// where the order is in its commercial life; an attempt says what happened
/// when a rider actually went to the door. Encoding "refused" into the order
/// state would destroy that distinction and would force every future reader to
/// guess whether a non-`delivered` order was never attempted, attempted once,
/// or attempted three times.
///
/// The vocabulary is the blueprint's, unchanged.
enum DeliveryAttemptState {
  /// The attempt exists but the rider has not set out. The canonical starting
  /// state of the first attempt, written by the trusted server at the dispatch
  /// boundary.
  pending,

  /// The rider is en route with the goods.
  outForDelivery,

  /// **NOT EXECUTABLE IN FND-003B3B, and unimplemented by every slice.**
  ///
  /// Declared so the enum and its wire values are stable, exactly as
  /// `OrderState.delivered` and `DeliveryProofDisputeState.resolved` are.
  ///
  /// Reaching it requires the **proof-satisfaction policy**, which no slice
  /// defines. FND-003D1 added a way to *refer* to a proof policy, FND-003D2A
  /// added the trusted *result* of evaluating one, and FND-003D2B added the
  /// fallback dispute for when that result is unusable — but **what the policy
  /// actually requires is still undefined**, and `CONSTRAINTS.md` invariant 13
  /// is not discharged.
  ///
  /// A `satisfied` assessment is therefore **not** consumed as authority for
  /// delivery here. "A proof result exists" and "the policy is satisfied" are
  /// different claims, and only the first one is true today.
  ///
  /// No transition in this contract enters it; the command that would is
  /// enumerated and always refused.
  delivered,

  /// The customer declined to take the goods. **Terminal for the attempt.**
  ///
  /// After dispatch this opens a required return — the goods are in a rider's
  /// hands and must go somewhere. It decides **nothing** about fault, fee,
  /// refund, compensation or liability.
  refused,

  /// The attempt could not be completed for some other reason — nobody home,
  /// address unreachable, access denied. **Terminal for the attempt.**
  ///
  /// Deliberately **does not** imply retry, return, cancellation, customer
  /// fault, rider fault, reassignment or a fee. The blueprint says a failed
  /// attempt *may* require a return; no accepted contract says **when**, so
  /// this slice records the fact and refuses to guess the consequence.
  failed;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    DeliveryAttemptState.pending => 'pending',
    DeliveryAttemptState.outForDelivery => 'out_for_delivery',
    DeliveryAttemptState.delivered => 'delivered',
    DeliveryAttemptState.refused => 'refused',
    DeliveryAttemptState.failed => 'failed',
  };

  /// States this slice's evaluators may read or produce.
  ///
  /// A stored attempt outside this set fails closed rather than being guessed
  /// at.
  static const Set<DeliveryAttemptState> executableInThisSlice =
      <DeliveryAttemptState>{
        DeliveryAttemptState.pending,
        DeliveryAttemptState.outForDelivery,
        DeliveryAttemptState.refused,
        DeliveryAttemptState.failed,
      };

  /// States **no slice implements at all**.
  static const Set<DeliveryAttemptState> notYetImplemented =
      <DeliveryAttemptState>{DeliveryAttemptState.delivered};

  /// Whether no further attempt transition may act from this state.
  ///
  /// [delivered] is included for completeness of meaning only; it is never
  /// reached, so nothing ever acts from it either.
  bool get isTerminal =>
      this == DeliveryAttemptState.refused ||
      this == DeliveryAttemptState.failed ||
      this == DeliveryAttemptState.delivered;

  static DeliveryAttemptState? byId(String id) {
    for (final DeliveryAttemptState s in DeliveryAttemptState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}
