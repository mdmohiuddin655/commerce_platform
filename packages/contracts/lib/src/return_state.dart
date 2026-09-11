/// Lifecycle of the **return** of one order's goods.
///
/// A separate dimension again: an order can be `in_delivery` while its return
/// is `not_required`, `required` or `in_transit`. Folding any of this into
/// `OrderState` would mean inventing a post-dispatch order state, and would
/// make "these goods are physically in a rider's bag heading back to the shop"
/// indistinguishable from "this order was cancelled before it ever left".
///
/// ## The invariant this enum exists to protect
///
/// **Reserved units may become available stock again only after the shop has
/// the goods back AND has looked at them.** Neither fact alone is enough:
/// receipt without inspection cannot tell a sellable item from a broken one,
/// and inspection without receipt is a claim about goods nobody at the shop is
/// holding. The states are ordered so that no single transition can assert
/// both.
enum ReturnState {
  /// No return is required. The canonical starting state, written with the
  /// first delivery attempt.
  ///
  /// **Not the same as "no return record".** Absence means the aggregate was
  /// never written or was not loaded; this means it was written and says the
  /// goods are not coming back.
  notRequired,

  /// The goods must come back. Opened atomically by a canonical refusal after
  /// dispatch.
  ///
  /// Requiring a return restores no stock, moves no custody, completes no
  /// rider and decides no money.
  required,

  /// The goods are on their way back. Custody is still the rider's — nothing
  /// has changed hands, only intent.
  inTransit,

  /// The shop physically has the goods back. **The custody-changing fact**,
  /// following the receiver-side pattern FND-003B3A established: the party who
  /// can attest to holding the goods is the party who records it.
  ///
  /// Receipt alone restores **nothing**. A returned item may be damaged, and
  /// putting it back on the shelf because a box arrived is exactly how
  /// unsellable stock gets sold.
  received,

  /// The shop has examined the goods and recorded one inventory disposition.
  ///
  /// This is the boundary where available stock may change, and the only one.
  inspected,

  /// The return is finished and closed for audit. **Terminal.**
  ///
  /// Closing restores nothing — the disposition already decided that — and
  /// infers no money, liability or settlement.
  closed;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    ReturnState.notRequired => 'not_required',
    ReturnState.required => 'required',
    ReturnState.inTransit => 'in_transit',
    ReturnState.received => 'received',
    ReturnState.inspected => 'inspected',
    ReturnState.closed => 'closed',
  };

  /// States this slice's evaluators may read or produce. Every value is
  /// executable here; the set exists so a future addition is not silently
  /// assumed readable.
  static const Set<ReturnState> executableInThisSlice = <ReturnState>{
    ReturnState.notRequired,
    ReturnState.required,
    ReturnState.inTransit,
    ReturnState.received,
    ReturnState.inspected,
    ReturnState.closed,
  };

  /// Whether the goods are physically back at the shop in this state.
  bool get shopHoldsGoods =>
      this == ReturnState.received ||
      this == ReturnState.inspected ||
      this == ReturnState.closed;

  /// Terminal: no return transition may act from it.
  bool get isTerminal => this == ReturnState.closed;

  static ReturnState? byId(String id) {
    for (final ReturnState s in ReturnState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}

/// Physical route a return travels.
///
/// Both are in the blueprint. Only one is executable here, and the reason is a
/// missing **authority**, not a missing state machine.
enum ReturnRoute {
  /// The rider who holds the goods carries them back to the shop, and the shop
  /// receives them. The only route implemented by FND-003B3B.
  riderToShop,

  /// **NOT EXECUTABLE.** The rider hands the goods to a picker, who returns
  /// them to the shop.
  ///
  /// The accepted picker assignment is **`completed` at dispatch** — that is
  /// precisely what FND-003B3A made rider custody receipt do, and completion
  /// also removes the picker's `assignedResource` scope. So at the moment a
  /// return begins there is no picker with an active assignment on this order
  /// and no permission that would let one take custody back.
  ///
  /// Making this executable would require inventing post-dispatch picker
  /// return authority — a new assignment concept, a new permission, and a
  /// scope projection that re-grants a completed worker access to a resource.
  /// That is a durable architecture decision, not an implementation detail, so
  /// it is deferred to its own contract rather than guessed here. See
  /// ADR-0010.
  riderToPickerToShop;

  /// Stable wire identifier.
  String get id => switch (this) {
    ReturnRoute.riderToShop => 'rider_to_shop',
    ReturnRoute.riderToPickerToShop => 'rider_to_picker_to_shop',
  };

  /// Routes this slice can actually execute.
  static const Set<ReturnRoute> executableInThisSlice = <ReturnRoute>{
    ReturnRoute.riderToShop,
  };

  static ReturnRoute? byId(String id) {
    for (final ReturnRoute r in ReturnRoute.values) {
      if (r.id == id) {
        return r;
      }
    }
    return null;
  }
}

/// What inspection concluded about the **goods**, for inventory purposes only.
///
/// ## This is not a liability finding
///
/// The dangerous reading is "damaged ⇒ somebody pays". It does not. This enum
/// answers exactly one question — *may these units be sold again?* — and
/// deliberately cannot express who damaged them, who owes for them, whether a
/// refund is due, whether a replacement is owed, or what commission applies.
///
/// Those belong to **FND-003C**, which is blocked on owner decision **O6**, and
/// to a dispute-resolution slice that does not exist. Encoding a fault hint
/// here would bake a guess into stored inventory history.
enum ReturnDisposition {
  /// Sellable. The reserved units go back to available stock exactly once.
  restockable,

  /// Not sellable. The reservation ends, and **available stock does not
  /// change** — creating a damaged good as sellable stock is how a customer
  /// receives someone else's breakage.
  damaged,

  /// Held pending an out-of-band decision — suspected tampering, cold-chain
  /// break, recall. Inventory-identical to [damaged] here: the reservation
  /// ends and available stock does not change.
  ///
  /// Distinct from [damaged] so audit can tell "we know it is unsellable" from
  /// "we are not yet willing to say it is sellable". Merging them would lose
  /// that, and quarantine decisions are reviewed by different people.
  quarantined;

  /// Stable wire identifier.
  String get id => switch (this) {
    ReturnDisposition.restockable => 'restockable',
    ReturnDisposition.damaged => 'damaged',
    ReturnDisposition.quarantined => 'quarantined',
  };

  /// Whether this disposition returns the units to **available** stock.
  ///
  /// The single place that question is answered. A backend switches on this
  /// rather than re-deriving intent from a name.
  bool get restoresAvailableStock => this == ReturnDisposition.restockable;

  static ReturnDisposition? byId(String id) {
    for (final ReturnDisposition d in ReturnDisposition.values) {
      if (d.id == id) {
        return d;
      }
    }
    return null;
  }
}
