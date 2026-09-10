/// Why a delivery-proof assessment was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial`,
/// `AssignmentDenial`, `CustodyDenial` and `DeliveryProofDenial` are not.
///
/// There is deliberately no value meaning "the proof was not satisfied": that
/// is a **verdict**, not a denial. A refused assessment records nothing at all;
/// a `notSatisfied` assessment is a successful transition that recorded a
/// negative result. Collapsing the two would make "we could not evaluate this"
/// indistinguishable from "we evaluated it and it failed" — which is exactly
/// the confusion a dispute workflow later has to resolve.
enum DeliveryProofAssessmentDenial {
  /// The canonical resource context is unusable, or an aggregate describes a
  /// different order than the one being assessed.
  resourceBindingMismatch,

  /// `expectedAssessmentRevision` does not match. Another writer got there
  /// first.
  assessmentRevisionConflict,

  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// `expectedCustodyRevision` does not match.
  custodyRevisionConflict,

  /// `expectedRiderSlotRevision` does not match the rider slot.
  riderSlotRevisionConflict,

  /// The supplied assessment identifier is not a valid opaque id.
  assessmentIdInvalid,

  /// A new assessment tried to reuse the **current** assessment's own id.
  ///
  /// A reassessment is a new immutable fact, not an edit of the old one.
  /// Reusing the identifier would collapse two assessments into one in every
  /// audit trail and event stream, and would make the previous verdict
  /// unfindable — which is precisely what append-only history exists to
  /// prevent. Advancing the revision is not a substitute for a distinct
  /// identity.
  assessmentIdReuse,

  /// The order is not `in_delivery`. Proof of delivery cannot be assessed for
  /// an order that has not been dispatched.
  orderNotInDelivery,

  /// The reservation is not `committed`.
  reservationNotCommitted,

  /// The order has no custody aggregate. **Absence is never read as "a rider
  /// must have it".**
  custodyNotInitialised,

  /// Custody is not held by a rider.
  custodyNotWithRider,

  /// There is no accepted rider assignment for this order.
  noAcceptedRiderAssignment,

  /// The request names a different rider than the order's accepted one.
  notCurrentAcceptedRider,

  /// The request names a different rider assignment attempt than the current
  /// one.
  assignmentIdMismatch,

  /// The request names a different generation than the current attempt's.
  generationMismatch,

  /// Custody is bound to a different rider assignment attempt than the one
  /// currently accepted. **Corruption or a mid-flight reassignment, not a
  /// simple mismatch.**
  custodyHolderBindingMismatch,

  /// The authoritative policy reference is not structurally usable. The exact
  /// structural reason is on `DeliveryProofAssessmentOutcome.structuralDenial`.
  policyRefInvalid,

  /// The authoritative evidence reference is not structurally usable.
  evidenceRefInvalid,

  /// The evidence reference belongs to a different order. **Evidence is not
  /// portable between orders.**
  evidenceResourceMismatch,

  /// The assessor is not a trusted server worker at all — a human client, say.
  /// A human may not declare their own proof satisfied.
  ///
  /// Deliberately distinct from [assessorAuthorityMismatch]: "this is not a
  /// server process" and "this is the wrong server process" are different
  /// failures, and collapsing them would hide which one occurred.
  assessorNotSystemWorker,

  /// The assessor **is** a trusted server worker, but not the proof verifier
  /// this resource's policy authorizes.
  ///
  /// *(FND-003D2A-FIX-001.)* `PrincipalKind.systemWorker` is a broad
  /// infrastructure class covering the outbox drain, reservation expiry,
  /// scheduled reconciliation and every other trusted job. Accepting any of
  /// them would let an unrelated worker mint the verdict that later gates
  /// delivery. Kind alone is **not** authority — the exact authorized verifier
  /// identity must match.
  assessorAuthorityMismatch,

  /// The authoritative verifier principal id resolved into the context is not
  /// a valid opaque id, so no exact authority comparison is possible.
  ///
  /// Fails closed rather than falling back to a kind check.
  assessorPrincipalIdInvalid,

  /// `assessedAtUtc` is not UTC. A local-zone timestamp is ambiguous, and a
  /// client clock is never commercial truth.
  assessedAtNotUtc,

  /// A stored aggregate is a combination this contract can never produce.
  /// **Corruption, not a race.**
  aggregateInconsistent,
}
