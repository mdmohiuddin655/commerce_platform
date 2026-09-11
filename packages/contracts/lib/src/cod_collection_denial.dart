/// Why a COD collection was refused.
///
/// **Internal.** For backend logs, tests and audit — never returned verbatim to
/// an untrusted caller, for the same reason every other denial enum in this
/// repository is not: a caller who learns *which* precondition failed can probe
/// for orders, riders and amounts it has no right to see.
///
/// A denial says only that the operation was **not applied**: no cash is
/// recorded, no journal entry exists, and the payment, order, custody, attempt
/// and assignment are all exactly as they were.
enum CodCollectionDenial {
  // ----------------------------------------------------------- binding
  /// Two reads that must describe the same order disagree, or one disagrees
  /// with the canonical resource context.
  resourceBindingMismatch,

  /// The grant is not the right grant: wrong permission, wrong principal or
  /// wrong resource. One value, deliberately — splitting it would let a caller
  /// probe which half failed.
  authorizationGrantMismatch,

  /// The acting principal is not a human principal, or its id is malformed.
  /// A background worker cannot witness cash changing hands.
  actorNotHumanPrincipal,

  /// A recorded timestamp is not UTC. Never converted.
  timestampNotUtc,

  // ------------------------------------------------------------ money
  /// The order's financial snapshot is not canonical.
  financialSnapshotInconsistent,

  /// The payment aggregate is not canonical. **Corruption, not a race.**
  paymentAggregateInconsistent,

  /// `expectedPaymentRevision` does not match. Another writer got there first
  /// — this is what stops two concurrent collections from both committing.
  paymentRevisionConflict,

  /// The payment is not in a state a collection may act from — already fully
  /// collected, or a replay.
  paymentNotCollectable,

  /// The payment is **disputed**. Fail closed: collecting against a contested
  /// amount would prejudge the dispute nobody has resolved.
  paymentDisputed,

  /// The reported amount is zero or negative. A collection of nothing is not a
  /// collection, and a negative one is a refund — which this slice does not
  /// implement.
  collectionAmountNotPositive,

  /// The reported currency is not the snapshot's, or is not accepted by the v1
  /// policy. **No FX exists**, so a mismatch cannot be converted away.
  currencyMismatch,

  /// The reported amount exceeds what is still outstanding. **Over-collection
  /// is impossible**: a rider cannot record taking more than the customer
  /// owes.
  collectionExceedsOutstanding,

  // --------------------------------------------------- order / delivery
  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// The order is not `in_delivery`. Nothing here acts before dispatch.
  orderNotInDelivery,

  /// The reservation is not `committed`.
  reservationNotCommitted,

  /// The order has no delivery attempt.
  attemptNotInitialised,

  /// `expectedAttemptRevision` does not match.
  attemptRevisionConflict,

  /// The attempt is not out for delivery. Cash is collected at the door: not
  /// before the rider sets out, and **not after a `refused` or `failed`
  /// attempt**, where any money question is a refusal-fee or dispute matter
  /// this slice does not decide.
  attemptNotOutForDelivery,

  // ----------------------------------------------------------- custody
  /// `expectedCustodyRevision` does not match.
  custodyRevisionConflict,

  /// The order has no custody aggregate. Absence is never read as "the shop
  /// still has it".
  custodyNotInitialised,

  /// Custody is not with a rider.
  custodyNotWithRider,

  /// Custody is bound to a different rider assignment attempt than the current
  /// one. Goods carried under attempt A must not have cash collected against
  /// them as though attempt B were carrying them.
  custodyHolderBindingMismatch,

  // -------------------------------------------------------- assignment
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

  // ------------------------------------------------------- journal
  /// The journal identifiers supplied for this operation are not canonical
  /// opaque ids.
  journalReferenceInvalid,

  /// No such operation is enumerated. Fail closed.
  unknownOperation,
}
