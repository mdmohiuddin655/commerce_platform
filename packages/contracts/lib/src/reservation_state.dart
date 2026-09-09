/// Lifecycle of the stock reserved for one order.
///
/// Modelled explicitly rather than as a boolean, because "is this stock
/// reserved?" cannot distinguish the four situations that matter for
/// inventory correctness — and conflating them is how units get restored
/// twice or never.
///
/// ## The invariant this enum exists to protect
///
/// **The same reserved units may be restored to available stock at most
/// once.** Restoration happens exactly on the transition *into* [released] or
/// [expired], both of which are terminal. There is no path out of them, so a
/// repeated release, a retried expiry worker, or a duplicate cancellation
/// cannot restore a second time.
enum ReservationState {
  /// Units are held for a `placed` order and the reservation is still
  /// **expirable**. Available stock has already been decremented.
  active,

  /// The order was accepted, so the allocation now belongs to it. Available
  /// stock is unchanged from [active] — acceptance does **not** decrement a
  /// second time. Crucially this is **not expirable**: once committed, an
  /// expiry worker can no longer restore these units.
  committed,

  /// Released back to available stock because the order was rejected or
  /// cancelled. **Terminal**, and the restoration already happened.
  released,

  /// Restored to available stock by the trusted expiry worker because the
  /// order was never accepted in time. **Terminal**, and the restoration
  /// already happened.
  ///
  /// Distinct from [released] so audit can tell "nobody acted" from "someone
  /// rejected or cancelled"; the inventory effect of both is identical.
  expired;

  /// Stable wire identifier.
  String get id => switch (this) {
    ReservationState.active => 'active',
    ReservationState.committed => 'committed',
    ReservationState.released => 'released',
    ReservationState.expired => 'expired',
  };

  /// Whether the reservation still holds units that available stock is
  /// missing. True for [active] and [committed].
  bool get holdsUnits =>
      this == ReservationState.active || this == ReservationState.committed;

  /// Whether the units have already been given back. True for [released] and
  /// [expired] — the states in which a further restoration would be a double
  /// restore.
  bool get isFinal => !holdsUnits;

  /// Only an [active] reservation can expire. This single rule is what makes
  /// the acceptance-versus-expiry race safe: acceptance moves the reservation
  /// to [committed], after which expiry has no source state to act from.
  bool get isExpirable => this == ReservationState.active;

  static ReservationState? byId(String id) {
    for (final ReservationState s in ReservationState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}
