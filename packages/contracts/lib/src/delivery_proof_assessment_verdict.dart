/// What a trusted verifier concluded about the referenced proof policy.
///
/// **Two values, and deliberately only two.** Absence of a current assessment
/// already means *not assessed yet* — see `DeliveryProofAssessmentFacts.absent`
/// — so a `pending` value would be a second, contradictory way to say the same
/// thing, and the two would drift. A queue that has not run yet is **backend
/// operational state**, not a commerce-domain verdict, and modelling it here
/// would put job scheduling into the wire contract.
///
/// `expired`, `approvedByCustomer`, `disputed`, `overridden` and `delivered`
/// are absent for a stronger reason: each would decide something no slice has
/// decided — a retention or validity window, whether customer participation is
/// sufficient, how a dispute resolves, who may override a verifier, and whether
/// an order was delivered.
enum DeliveryProofAssessmentVerdict {
  /// The trusted verifier concluded the referenced policy **was** satisfied by
  /// the referenced protected evidence, for this assessment.
  ///
  /// **It does not deliver the order.** It is a prerequisite *result* that a
  /// later, separate delivery transaction may consume — see
  /// `docs/contracts/delivery-proof-assessment.md`. On its own it moves no
  /// order state, no custody, no assignment, no stock and no money.
  satisfied,

  /// The trusted verifier concluded the referenced policy **was not** satisfied
  /// by the referenced protected evidence, for this assessment.
  ///
  /// **That is the entire meaning.** It is emphatically *not* a finding of
  /// fraud, customer refusal, cancellation, delivery failure, a lost dispute,
  /// fee liability, a refund, or financial default. Every one of those is a
  /// separate decision owned by a slice that has not run:
  ///
  /// - refusal, failure and returns — FND-003B3B;
  /// - the fallback dispute workflow — FND-003D2B;
  /// - any money at all — FND-003C, itself blocked on owner decision **O6**.
  ///
  /// A backend must not derive a cancellation, a fee, a liability or a return
  /// route from this value, and `CONSTRAINTS.md` invariant 11 stands: delivery
  /// failure does not automatically justify a customer fee.
  notSatisfied;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    DeliveryProofAssessmentVerdict.satisfied => 'satisfied',
    DeliveryProofAssessmentVerdict.notSatisfied => 'not_satisfied',
  };

  static DeliveryProofAssessmentVerdict? byId(String id) {
    for (final DeliveryProofAssessmentVerdict v
        in DeliveryProofAssessmentVerdict.values) {
      if (v.id == id) {
        return v;
      }
    }
    return null;
  }
}
