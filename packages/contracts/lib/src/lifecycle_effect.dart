import 'package:meta/meta.dart';

/// What a transition does to **available stock**.
///
/// Typed rather than described in prose, so the future backend maps a value
/// instead of re-deriving intent from a comment. Every allowed transition
/// carries exactly one of these; a denied transition produces none at all.
///
/// There is deliberately **no money field anywhere in this file's inventory
/// types** — and no floating-point quantity either. Units are whole integers.
enum InventoryEffectKind {
  /// Decrement available stock and hold the units for this order. Applied
  /// atomically with order creation: an order cannot reach `placed` without
  /// it.
  reserveUnits,

  /// The order now owns its existing reservation. **Available stock does not
  /// change** — the decrement already happened at [reserveUnits], and doing it
  /// again would double-count.
  commitReservedUnits,

  /// Give the held units back to available stock. Applied exactly once, on
  /// the transition into a terminal reservation state.
  restoreReservedUnits,

  /// This transition does not touch stock. Used by the preparation edges: an
  /// order becoming `ready` must **not** release anything.
  none,
}

/// A transition's inventory effect, with the unit count it applies to.
@immutable
class InventoryEffect {
  const InventoryEffect._(this.kind, this.units);

  const InventoryEffect.reserve(int units)
    : this._(InventoryEffectKind.reserveUnits, units);

  const InventoryEffect.commit(int units)
    : this._(InventoryEffectKind.commitReservedUnits, units);

  const InventoryEffect.restore(int units)
    : this._(InventoryEffectKind.restoreReservedUnits, units);

  const InventoryEffect.none() : this._(InventoryEffectKind.none, 0);

  final InventoryEffectKind kind;

  /// Whole units. Zero for [InventoryEffectKind.none].
  final int units;

  /// Signed change to **available** stock, for a backend to apply directly.
  ///
  /// Note [InventoryEffectKind.commitReservedUnits] is `0`: committing moves
  /// a reservation's ownership, it does not move stock.
  int get availableStockDelta => switch (kind) {
    InventoryEffectKind.reserveUnits => -units,
    InventoryEffectKind.restoreReservedUnits => units,
    InventoryEffectKind.commitReservedUnits => 0,
    InventoryEffectKind.none => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is InventoryEffect && other.kind == kind && other.units == units;

  @override
  int get hashCode => Object.hash(kind, units);

  @override
  String toString() => 'InventoryEffect(${kind.name}, units=$units, '
      'availableDelta=$availableStockDelta)';
}

/// What a transition does to **money** — or, in this slice, what it
/// deliberately does not say.
///
/// ## Why this is an enum and not a number
///
/// The dangerous failure mode is a later implementer reading "no fee recorded"
/// as "the fee is zero". A cancellation whose fee policy has not been decided
/// is **not** a free cancellation. Encoding the difference as a type makes
/// that misreading a compile-time choice rather than an accident.
///
/// No amount, currency, rate, refund, commission or posting appears in this
/// slice. Money is owned by **FND-003C**, which is itself blocked on owner
/// decision **O6** (currency, fee policy, commission ownership).
enum FinancialClassification {
  /// This transition moves no money and never will. Placement, acceptance and
  /// the preparation edges: an order changing shop-side state does not post to
  /// any ledger.
  noneInThisSlice,

  /// This transition **may** have a financial consequence, and that
  /// consequence is **not yet defined**.
  ///
  /// Read this as "unknown", never as "zero". A backend must refuse to derive
  /// an amount from it. Rejection and cancellation carry this: whether a fee
  /// is due, who owes it and under which policy version is FND-003C's to
  /// decide.
  deferredToFinancialSlice,
}
