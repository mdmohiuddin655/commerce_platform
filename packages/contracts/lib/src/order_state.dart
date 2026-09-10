/// States an order can hold.
///
/// FND-003B1 owns the **pre-dispatch** portion only. The later states are
/// declared here so that adding them is not a breaking enum change, but this
/// slice's evaluator **cannot enter them** and no transition into them is
/// enumerated. A state existing in this enum is not permission to use it.
enum OrderState {
  /// Customer's quote-confirmed checkout succeeded and stock is reserved.
  /// Executable in this slice.
  placed,

  /// The shop's agent accepted the order. Executable in this slice.
  accepted,

  /// The shop is assembling the goods. Executable in this slice.
  preparing,

  /// Goods are assembled and awaiting collection. Executable in this slice.
  ready,

  /// The agent refused the order. **Terminal** — no fulfilment transition
  /// follows, and there is no un-reject command.
  rejected,

  /// The order was cancelled before dispatch. **Terminal** — there is no
  /// reopening or reactivation, and none was invented.
  cancelled,

  /// Reached once a rider holds custody.
  ///
  /// **Not executable by the FND-003B1 pre-dispatch evaluator** — no command
  /// here enters it or acts from it, and none was invented. It is nonetheless
  /// **reachable since FND-003B3A**, produced by rider custody receipt, and its
  /// aggregate shape is known: `in_delivery` pairs with a `committed`
  /// reservation, because dispatch restores no stock.
  ///
  /// See [outsideThisSliceEvaluator] and [aggregateShapeKnown] — those two
  /// claims are different, and this state is the reason they had to be split.
  inDelivery,

  /// **NOT EXECUTABLE, and unimplemented by every slice.** Reaching it depends
  /// on delivery confirmation and proof, which no slice defines. Declared for
  /// enum stability only.
  delivered;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    OrderState.placed => 'placed',
    OrderState.accepted => 'accepted',
    OrderState.preparing => 'preparing',
    OrderState.ready => 'ready',
    OrderState.rejected => 'rejected',
    OrderState.cancelled => 'cancelled',
    OrderState.inDelivery => 'in_delivery',
    OrderState.delivered => 'delivered',
  };

  /// States this slice's evaluator may read or produce.
  ///
  /// A transition request naming a state outside this set fails closed rather
  /// than being guessed at.
  static const Set<OrderState> executableInThisSlice = <OrderState>{
    OrderState.placed,
    OrderState.accepted,
    OrderState.preparing,
    OrderState.ready,
    OrderState.rejected,
    OrderState.cancelled,
  };

  /// States **no slice implements at all**.
  ///
  /// Corrected by FND-003B3A-FIX-001. This previously also listed
  /// `inDelivery`, which stopped being true the moment FND-003B3A made rider
  /// custody receipt produce it: exported metadata that says a reachable state
  /// is unimplemented is a lie a later reader will believe.
  ///
  /// "This evaluator cannot act from it" is a **different** claim, and now has
  /// its own name — [outsideThisSliceEvaluator].
  static const Set<OrderState> notYetImplemented = <OrderState>{
    OrderState.delivered,
  };

  /// States the **pre-dispatch evaluator cannot act from**, whether or not
  /// another slice implements them.
  ///
  /// `inDelivery` is implemented — by the custody slice — and still belongs
  /// here, because no pre-dispatch command may transition from it and none was
  /// invented. `delivered` belongs here because nothing implements it.
  ///
  /// Together with [executableInThisSlice] this partitions `OrderState.values`.
  static const Set<OrderState> outsideThisSliceEvaluator = <OrderState>{
    OrderState.inDelivery,
    OrderState.delivered,
  };

  /// States whose order/reservation pairing is **defined**.
  ///
  /// Deliberately wider than [executableInThisSlice], and the distinction is
  /// the point: a state can have a known canonical shape long before the
  /// pre-dispatch evaluator may execute a command from it.
  ///
  /// Without this split, a malformed `in_delivery` aggregate — an
  /// `in_delivery` order whose reservation was `released` — would pass
  /// validation simply because the pre-dispatch evaluator does not own the
  /// state. It fails closed instead.
  ///
  /// `delivered` stays out: no slice defines it.
  static const Set<OrderState> aggregateShapeKnown = <OrderState>{
    OrderState.placed,
    OrderState.accepted,
    OrderState.preparing,
    OrderState.ready,
    OrderState.rejected,
    OrderState.cancelled,
    OrderState.inDelivery,
  };

  /// Terminal for the pre-dispatch lifecycle: nothing in this slice may leave
  /// these, in any direction.
  bool get isTerminalPreDispatch =>
      this == OrderState.rejected || this == OrderState.cancelled;

  static OrderState? byId(String id) {
    for (final OrderState s in OrderState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}
