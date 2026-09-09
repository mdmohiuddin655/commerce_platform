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

  /// **NOT EXECUTABLE IN FND-003B1.** Reached once a rider holds custody.
  /// Declared for enum stability only; no transition into it exists yet.
  /// Owned by a later FND-003B slice.
  inDelivery,

  /// **NOT EXECUTABLE IN FND-003B1.** Owned by a later FND-003B slice.
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

  /// Declared for enum stability, owned by a later slice.
  static const Set<OrderState> notYetImplemented = <OrderState>{
    OrderState.inDelivery,
    OrderState.delivered,
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
