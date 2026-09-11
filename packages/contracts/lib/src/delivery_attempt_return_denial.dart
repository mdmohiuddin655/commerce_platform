/// Why a delivery-attempt or return transition was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial`,
/// `AssignmentDenial`, `CustodyDenial` and `DeliveryProofDisputeDenial` are
/// not. A caller learning *which* precondition failed can probe for the
/// existence and state of resources it has no right to see.
///
/// A denial says only that an operation was **not applied**. The attempt, the
/// return, the order, custody, the assignment and the reservation are all left
/// exactly as they were.
enum AttemptReturnDenial {
  // ------------------------------------------------------------- binding
  /// Two aggregates that must describe the same order disagree, or one of them
  /// disagrees with the canonical resource context.
  resourceBindingMismatch,

  /// Shop custody, or the receiving shop, names a different shop than the
  /// order's canonical one. Both ids can be individually valid and still be
  /// different shops.
  shopBindingMismatch,

  /// The supplied `AuthorizationGrant` is not the right grant: wrong
  /// permission for the operation, wrong principal, or wrong resource.
  ///
  /// Deliberately one value rather than three. Distinguishing them would let a
  /// caller probe which half of the binding failed.
  authorizationGrantMismatch,

  /// The acting principal is not a human principal, or its identity is
  /// malformed.
  actorNotHumanPrincipal,

  /// A recorded timestamp is not UTC. Never normalised or converted —
  /// a local-time timestamp in stored history is unrecoverable.
  timestampNotUtc,

  // ------------------------------------------------------------- attempt
  /// The order has no delivery-attempt aggregate. **Absence is not
  /// `pending`.** A missing attempt means dispatch-time initialisation never
  /// ran or the record was not loaded.
  attemptNotInitialised,

  /// Attempt initialisation is **create-once** and this order already has one.
  attemptAlreadyInitialised,

  /// `expectedAttemptRevision` does not match. Another writer got there first.
  attemptRevisionConflict,

  /// The attempt is not in a state this transition may act from — including a
  /// replay against an already-terminal attempt.
  attemptNotInRequiredState,

  // -------------------------------------------------------------- return
  /// The order has no return aggregate. **Absence is not `not_required`.**
  returnNotInitialised,

  /// `expectedReturnRevision` does not match.
  returnRevisionConflict,

  /// The return is not in a state this transition may act from — including a
  /// replayed receipt, inspection or close.
  returnNotInRequiredState,

  /// The inspection did not name exactly one disposition, or a command that
  /// records no disposition supplied one.
  returnDispositionMissing,

  // -------------------------------------------------- order / reservation
  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// The order is not `in_delivery`. Nothing in this slice acts before
  /// dispatch or after a state no slice defines.
  orderNotInDelivery,

  /// The reservation is not `committed`. A return cannot terminate a
  /// reservation that already ended, which is what stops a replayed inspection
  /// from restoring stock twice.
  reservationNotCommitted,

  /// The reservation has not been terminated by an inspection yet, or was
  /// terminated when this operation required it still live.
  reservationNotReturned,

  // ------------------------------------------------------------- custody
  /// `expectedCustodyRevision` does not match.
  custodyRevisionConflict,

  /// The order has no custody aggregate. **Absence is never read as "the shop
  /// still has it".**
  custodyNotInitialised,

  /// Custody is not with the rider this operation acts from.
  custodyNotWithRider,

  /// Custody is not at the canonical shop.
  custodyNotAtShop,

  /// Custody is bound to a different rider assignment attempt than the one
  /// currently accepted. Goods carried under attempt A must not be returned as
  /// though attempt B had carried them.
  custodyHolderBindingMismatch,

  // ---------------------------------------------------------- assignment
  /// There is no accepted rider assignment for this order.
  noAcceptedRiderAssignment,

  /// The acting principal is not the order's accepted rider.
  notCurrentAcceptedRider,

  /// The command names a different assignment attempt than the current one.
  assignmentIdMismatch,

  /// The command names a different generation than the current attempt's.
  generationMismatch,

  /// `expectedRiderSlotRevision` does not match the rider slot.
  riderSlotRevisionConflict,

  // ---------------------------------------------------------- corruption
  /// A stored aggregate is a combination this lifecycle can never produce.
  /// **Corruption, not a race.**
  aggregateInconsistent,

  // ------------------------------------------------------ deferred policy
  /// **Delivery is not decidable yet.** Returned by the enumerated,
  /// never-executable `recordDelivered` command.
  ///
  /// Distinct from every "not allowed" value above, and the distinction is the
  /// whole point: this is *"nobody has decided what proof the policy
  /// requires"*, not *"this actor may not"*. The precedent is
  /// `DeliveryProofDisputeDenial.resolutionPolicyDeferred` and
  /// `LifecycleDenial.policyDeferred`.
  ///
  /// It is returned **before** any effect is computed, so no delivery, custody,
  /// assignment, inventory or financial consequence can escape through it.
  deliveryProofPolicyDeferred,

  /// **What follows a failed attempt is not decided.** Returned by the
  /// enumerated, never-executable post-failure return decision.
  ///
  /// The blueprint says a failed attempt *may* require a return. No accepted
  /// contract says when, who decides, how many retries are allowed, or who
  /// bears the cost — so this slice records the failure and refuses to
  /// manufacture the consequence. Depends on the delivery retry/failure policy,
  /// FND-003C and **O6**.
  failureReturnPolicyDeferred,

  /// **The via-picker return route is not implemented.** Returned by the
  /// enumerated, never-executable `rider -> picker -> shop` route.
  ///
  /// Not a policy gap but an **authority** gap: the accepted picker assignment
  /// is `completed` at dispatch and its `assignedResource` scope removed, so no
  /// picker holds post-dispatch return authority and none was invented. See
  /// ADR-0010.
  returnRouteNotImplemented,

  /// No such edge is enumerated. Fail closed.
  unknownTransition,
}
