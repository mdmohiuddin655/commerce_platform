/// Why a fallback delivery-proof dispute operation was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial`,
/// `AssignmentDenial`, `CustodyDenial`, `DeliveryProofDenial` and
/// `DeliveryProofAssessmentDenial` are not.
///
/// There is deliberately **no value meaning "the dispute failed"**, "the
/// customer was wrong", "the claim is unfounded" or "the dispute is closed".
/// Those would be *outcomes*, and this contract decides no outcome. Every value
/// here says only that an operation was not applied — the dispute record, where
/// one exists, is left exactly as it was.
///
/// > **`reviewerIsRaiser` was removed by FND-003D2B-FIX-001.** It refused an
/// > administrator who had earlier raised the dispute, which no accepted
/// > contract requires: `admin.dispute.administer` needs an active admin
/// > membership, `ownRegion` scope and a reason, and requires **no** approval
/// > and no second principal. A denial nobody asked for is an invented
/// > authorization policy. Separation of duties, if ever wanted, needs its own
/// > permission and ADR.
enum DeliveryProofDisputeDenial {
  /// The canonical resource context is unusable, or an aggregate describes a
  /// different order than the one being acted on.
  resourceBindingMismatch,

  /// The stored **dispute** aggregate is a combination this contract can never
  /// produce. **Corruption, not a race.**
  disputeAggregateInconsistent,

  /// The stored **assessment** aggregate is not canonical.
  ///
  /// Deliberately distinct from [disputeAggregateInconsistent] and from every
  /// verdict-shaped value: a torn assessment is a reconciliation case, and it
  /// is **never** read as `notSatisfied`, never a fallback ground, and never a
  /// valid dispute basis. Fabricating a negative result from corruption would
  /// invent a verdict nobody reached.
  assessmentAggregateInconsistent,

  /// The stored **order** aggregate is not canonical.
  orderAggregateInconsistent,

  /// `expectedDisputeRevision` does not match. Another writer got there first.
  disputeRevisionConflict,

  /// `expectedAssessmentRevision` does not match the assessment aggregate.
  ///
  /// A dispute is raised against the situation the caller actually saw, so a
  /// stale view of the assessment is refused rather than silently recorded
  /// against a basis that has already moved.
  assessmentRevisionConflict,

  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// The supplied dispute identifier is not a valid opaque id.
  disputeIdInvalid,

  /// The operation names a different dispute than the order's current one.
  disputeIdMismatch,

  /// The order already has a dispute that is open or under review.
  ///
  /// **At most one live fallback proof dispute per order.** A second one would
  /// fork the audit trail: two records, two bases, and no way to say which was
  /// *the* dispute when anything happened. Duplicate and reordered raises land
  /// here or on [disputeRevisionConflict], and neither writes anything.
  disputeAlreadyOpen,

  /// The order has no dispute to act on. **Absence is never read as "there
  /// must be one".**
  disputeNotFound,

  /// The dispute is not in a state this operation can act from — an already
  /// reviewed dispute being reviewed again, say.
  disputeNotOpen,

  /// The current canonical assessment is `satisfied`, which is **not** a
  /// fallback ground.
  ///
  /// The FND-003D2B boundary is a fallback for a *missing, superseded or
  /// `notSatisfied`* assessment. Contesting an assessment that a trusted
  /// verifier concluded **was** satisfied is a different workflow with
  /// different evidence, different authority and different consequences, and
  /// **no slice defines it**. Refusing here is what keeps this contract from
  /// quietly becoming general support-case infrastructure.
  assessmentSatisfied,

  /// The acting principal is not a human principal.
  ///
  /// A dispute is a **claim a person makes**, which is the exact inverse of a
  /// proof assessment: `DeliveryProofAssessmentDenial.assessorNotSystemWorker`
  /// refuses a human where only a trusted verifier belongs, and this refuses a
  /// trusted worker where only a person belongs. A background job that could
  /// raise or review disputes would be an unattributable audit trail.
  actorNotHumanPrincipal,

  /// The order is not `in_delivery`.
  ///
  /// Proof of delivery cannot be missing, superseded or unsatisfied for an
  /// order that was never dispatched. Whether a dispute may be raised **after**
  /// delivery, refusal, return or post-dispatch cancellation is **undecided**:
  /// none of those states is reachable, and inventing the answer would be
  /// inventing the lifecycle.
  orderNotInDelivery,

  /// The reservation is not `committed`.
  reservationNotCommitted,

  /// The timestamp supplied for the operation is not UTC. A local-zone value is
  /// ambiguous, and a client clock is never commercial truth.
  timestampNotUtc,

  /// The review timestamp precedes the moment the dispute was raised.
  ///
  /// Reviewing something before it was raised is not a race, a clock skew
  /// tolerance or a rounding question — it is an incoherent pair of
  /// server-supplied UTC values, and accepting it would store a record the
  /// aggregate validator refuses. **No window, deadline, SLA or duration is
  /// derived from either value**; this is an ordering check and nothing more.
  reviewTimestampPrecedesRaise,

  /// The operation is a **real edge whose business policy is not yet decided**,
  /// so it is deliberately not executable.
  ///
  /// Exactly [DeliveryProofDisputeCommand.resolve]. Resolving a dispute would
  /// mean deciding who prevails, whether the order is delivered, refused or
  /// returned, whether a fee, refund, compensation or liability follows, who
  /// bears it, and whether customer participation is optional, mandatory,
  /// sufficient or a veto. **Not one of those is decided anywhere in this
  /// repository** — they need owner decision **O6**, **FND-003C** and
  /// **FND-003B3B**.
  ///
  /// It is distinct from [disputeNotOpen] and from every other value here for
  /// the same reason `LifecycleDenial.policyDeferred` is distinct from
  /// `unknownTransition`: a backend must be able to tell **"not decided yet"**
  /// from **"never allowed"**, and nobody must be tempted to fill the gap with
  /// a guessed rule, a zero fee or an automatic cancellation.
  resolutionPolicyDeferred,
}
