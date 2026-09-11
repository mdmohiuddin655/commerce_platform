/// Collection state of one order's customer payment.
///
/// The blueprint's vocabulary, unchanged. **Derived from trusted facts, never
/// supplied by a caller**: there is no `setPaymentState`, and no request in
/// this contract carries a target state. A state is what the recorded
/// collections add up to.
enum PaymentState {
  /// Nothing has been collected yet.
  due,

  /// Some, but not all, of the amount due has been collected. Real: a customer
  /// can hand over part of the cash, and pretending otherwise would force a
  /// rider to either refuse legal tender or fabricate a full collection.
  partiallyCollected,

  /// The full amount due has been collected.
  ///
  /// **Collected is not remitted, and not reconciled.** The cash is in a
  /// rider's hands; it has not reached the platform and nobody has agreed the
  /// books match. See ADR-0011.
  collected,

  /// The amount owed is contested.
  ///
  /// **NOT PRODUCIBLE BY FND-003C1.** No operation here writes it, because
  /// deciding that a payment is disputed means deciding who is right — and no
  /// accepted contract does. It is enumerated because the blueprint names it
  /// and a later slice will write it, and because **nonpayment must stay
  /// representable**: a refusal where the customer does not pay is a real
  /// outcome, not a reason to fabricate a collection.
  ///
  /// A stored `disputed` payment is **refused for collection** rather than
  /// treated as corruption — unlike `OrderState.delivered`, this is a state the
  /// platform genuinely expects to reach, so failing closed on it is the
  /// fail-safe reading, not an error.
  disputed;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    PaymentState.due => 'due',
    PaymentState.partiallyCollected => 'partially_collected',
    PaymentState.collected => 'collected',
    PaymentState.disputed => 'disputed',
  };

  /// States a COD collection may act **from**.
  static const Set<PaymentState> collectableFrom = <PaymentState>{
    PaymentState.due,
    PaymentState.partiallyCollected,
  };

  /// States this slice's evaluator may **produce**.
  static const Set<PaymentState> producibleInThisSlice = <PaymentState>{
    PaymentState.partiallyCollected,
    PaymentState.collected,
  };

  /// Whether any further collection is possible from this state.
  bool get isTerminalForCollection =>
      this == PaymentState.collected || this == PaymentState.disputed;

  static PaymentState? byId(String id) {
    for (final PaymentState s in PaymentState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}
