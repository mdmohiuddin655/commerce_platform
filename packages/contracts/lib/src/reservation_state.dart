/// Lifecycle of the stock reserved for one order.
///
/// Modelled explicitly rather than as a boolean, because "is this stock
/// reserved?" cannot distinguish the **five** situations that matter for
/// inventory correctness — and conflating them is how units get restored
/// twice or never.
///
/// ## The invariant this enum exists to protect
///
/// **The same reserved units may become available stock again at most once.**
///
/// ## Where restoration can happen — all three sites
///
/// *(Corrected by FND-003B3B-FIX-001. Before FND-003B3B there were four states
/// and two restoration sites, and this block still said so — a completeness
/// claim the return lifecycle had already falsified.)*
///
/// ```text
/// -> released   pre-dispatch: rejected or cancelled     stock IS restored
/// -> expired    pre-dispatch: the expiry worker acted   stock IS restored
/// -> returned   post-dispatch: the goods came back and were inspected
///                              stock is restored ONLY for a restockable
///                              disposition; damaged and quarantined restore
///                              NOTHING
/// ```
///
/// All three are **terminal**, and there is no path out of any of them, so a
/// repeated release, a retried expiry worker, a duplicate cancellation or a
/// replayed inspection cannot restore a second time.
///
/// ## Terminal is not the same claim as restored
///
/// [released] and [expired] each carry both facts: the reservation ended **and**
/// the units went back on the shelf. [returned] carries only the first. Whether
/// the units became available again depends on the inspection's
/// `ReturnDisposition`, which is recorded on the return aggregate and travels
/// separately in the transition's `InventoryEffect`.
///
/// **So "this reservation is final" must never be read as "available stock
/// increased".** For a damaged or quarantined return those are opposite
/// answers, and reading a state name instead of the effect is how breakage
/// becomes sellable stock. See
/// `docs/contracts/delivery-attempt-return-lifecycle.md`.
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
  expired,

  /// The goods came back after dispatch, the shop received them, and an
  /// inspection recorded a disposition. **Terminal.**
  ///
  /// ## Why this is not [released]
  ///
  /// [released] carries a promise: *its units were restored to available
  /// stock*. That promise is true for every path into it, and code and audit
  /// both rely on it — `holdsUnits` false plus "released" has always meant the
  /// shelf count went back up.
  ///
  /// A returned reservation cannot make that promise. Whether the units became
  /// available again depends on the inspection's `ReturnDisposition`:
  /// `restockable` restores them, while `damaged` and `quarantined` restore
  /// **nothing** and must not. Overloading [released] would either make its
  /// promise false for damaged goods — silently turning breakage into sellable
  /// stock in every downstream reader — or force every reader to re-derive the
  /// disposition before trusting a state name.
  ///
  /// So this state says only: *the reservation is over and the goods are
  /// physically back*. The stock consequence is carried explicitly by the
  /// transition's `InventoryEffect`, which is `restore(units)` exactly once for
  /// a restockable disposition and `none()` otherwise.
  ///
  /// Like the other terminal states it is reached exactly once, on the
  /// inspection transition, so a replayed inspection or a later close cannot
  /// restore a second time.
  returned;

  /// Stable wire identifier.
  String get id => switch (this) {
    ReservationState.active => 'active',
    ReservationState.committed => 'committed',
    ReservationState.released => 'released',
    ReservationState.expired => 'expired',
    ReservationState.returned => 'returned',
  };

  /// Whether the reservation still holds units that available stock is
  /// missing. True for [active] and [committed].
  bool get holdsUnits =>
      this == ReservationState.active || this == ReservationState.committed;

  /// Whether the reservation is over and no further restoration may happen.
  /// True for [released], [expired] and [returned] — the states in which a
  /// further restoration would be a double restore.
  ///
  /// **Not a claim that stock went back up.** [released] and [expired] do carry
  /// that; [returned] deliberately does not, because a damaged or quarantined
  /// return restores nothing. Read the transition's `InventoryEffect` for the
  /// stock consequence, never a state name.
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
