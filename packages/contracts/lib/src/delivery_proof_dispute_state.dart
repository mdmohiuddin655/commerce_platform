/// Handling state of one fallback delivery-proof dispute.
///
/// **This is the state of the *handling*, never of the *outcome*.** Nothing
/// here says who was right, whether the goods arrived, whether anybody owes
/// anybody anything, or whether the order may now be delivered. A dispute is a
/// record that the proof situation is contested and is being looked at.
///
/// The vocabulary is deliberately small for the same reason
/// `DeliveryProofAssessmentVerdict` has exactly two values: every additional
/// value would decide something no slice has decided. `upheld`, `rejected`,
/// `refunded`, `compensated`, `returned`, `redelivered`, `chargedToCustomer`,
/// `chargedToRider` and `withdrawn` are all absent, and none is implied.
enum DeliveryProofDisputeState {
  /// Raised by the order's customer and awaiting administration.
  ///
  /// Being open blocks nothing and permits nothing: the order is untouched,
  /// custody is untouched, the assessment is untouched, and no money moves.
  open,

  /// An authorized administrator recorded that review of this dispute started.
  ///
  /// **Recording that review started is not a finding.** It captures who took
  /// the dispute up and when, which is the audit identity an eventual
  /// resolution slice will need — and nothing else.
  underReview,

  /// **NOT EXECUTABLE, and unimplemented by every slice.**
  ///
  /// Declared for enum stability only, exactly as `OrderState.delivered` is.
  /// Reaching it would require deciding what a resolution *means* — who
  /// prevails, whether the order is delivered, refused or returned, whether a
  /// fee, refund, compensation or liability follows, and whether customer
  /// participation is optional, mandatory, sufficient or a veto. **Not one of
  /// those questions is answered anywhere in this repository**, and answering
  /// one here would bake a guess into stored history.
  ///
  /// No command transitions into it ([DeliveryProofDisputeCommand.resolve] is
  /// enumerated and refused), no revision cost for it was invented
  /// ([reachableDisputeRevisionFor] returns null), and a stored record holding
  /// it is **corruption**, not a state this contract can read.
  resolved;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    DeliveryProofDisputeState.open => 'open',
    DeliveryProofDisputeState.underReview => 'under_review',
    DeliveryProofDisputeState.resolved => 'resolved',
  };

  /// States this slice's evaluator may read or produce.
  ///
  /// A stored record outside this set fails closed rather than being guessed
  /// at.
  static const Set<DeliveryProofDisputeState> executableInThisSlice =
      <DeliveryProofDisputeState>{
        DeliveryProofDisputeState.open,
        DeliveryProofDisputeState.underReview,
      };

  /// States **no slice implements at all**.
  static const Set<DeliveryProofDisputeState> notYetImplemented =
      <DeliveryProofDisputeState>{DeliveryProofDisputeState.resolved};

  /// The dispute is still awaiting an outcome that no slice defines.
  ///
  /// **True for both executable states**, which is the honest position: a
  /// dispute under review is no closer to resolved than one merely open,
  /// because resolution does not exist. It is emphatically **not** a claim
  /// that anything is blocked *on* the dispute — successful delivery is
  /// non-executable regardless.
  bool get isOpenForReview =>
      this == DeliveryProofDisputeState.open ||
      this == DeliveryProofDisputeState.underReview;

  static DeliveryProofDisputeState? byId(String id) {
    for (final DeliveryProofDisputeState s
        in DeliveryProofDisputeState.values) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}

/// The **exact** dispute revision a canonical record in [state] must carry.
///
/// The dispute aggregate's revision is not a free counter: this slice defines
/// exactly two applied operations, in exactly one order, so each executable
/// state has one reachable revision.
///
/// ```text
/// absent                     -> revision 0
/// raise            0 -> 1    -> open
/// record review    1 -> 2    -> underReview
/// ```
///
/// Returning a single value rather than a range is deliberate: unlike an
/// assignment slot, a dispute has no re-offer cycle, so there is nothing for a
/// range to express. It follows `reachableSlotRevisionRange`'s shape and its
/// discipline — **a state with no defined cost returns null**, and every
/// aggregate in that state then fails closed.
///
/// [DeliveryProofDisputeState.resolved] returns null because **no resolution
/// cost was invented**, in the same way rider `AssignmentState.completed` has
/// none (criterion **B3-C2**). That is what makes "resolution is deferred" a
/// structural property rather than a sentence in a comment.
int? reachableDisputeRevisionFor(DeliveryProofDisputeState state) =>
    switch (state) {
      DeliveryProofDisputeState.open => 1,
      DeliveryProofDisputeState.underReview => 2,
      DeliveryProofDisputeState.resolved => null,
    };
