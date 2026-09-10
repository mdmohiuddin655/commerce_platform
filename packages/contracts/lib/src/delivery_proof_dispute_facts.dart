import 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// The fallback dispute aggregate for one order, as loaded from storage.
///
/// Its [disputeRevision] is **its own** concurrency control — deliberately
/// independent of the order revision, the custody revision, the rider
/// `slotRevision` and the assessment revision. Five aggregates change at
/// different rates; sharing one counter would make every unrelated write look
/// like a conflict and a genuine conflict undetectable. That reasoning is
/// ADR-0009's, applied unchanged.
///
/// **It carries only the current dispute record.** There is no history array,
/// for the same reason `DeliveryProofAssessmentFacts` has none: an unbounded
/// in-memory list on an aggregate a backend loads on every request is a memory
/// and payload hazard. Retaining each applied revision in bounded, paginated,
/// append-only form is criterion **DPD7**, NOT RUN.
///
/// > **There is deliberately no state or basis getter here.** Reading either
/// > off raw storage facts is only safe once those facts are known canonical,
/// > and this type cannot know that. The trusted accessors are `canonicalState`
/// > and `canonicalBasis`, defined next to the validator in
/// > `delivery_proof_dispute_validation.dart`.
@immutable
class DeliveryProofDisputeFacts {
  const DeliveryProofDisputeFacts({
    required this.resourceId,
    required this.disputeRevision,
    this.current,
  });

  /// Canonical absence: **no dispute has ever been raised for this order.**
  ///
  /// Revision 0 and no record, following the repository's existing convention
  /// that revision 0 means "never written". Absence means exactly that — it is
  /// **never** read as "a dispute was raised and closed", because nothing in
  /// this contract can close one.
  const DeliveryProofDisputeFacts.absent({required this.resourceId})
    : disputeRevision = 0,
      current = null;

  final String resourceId;

  /// Increments on **every** applied dispute operation.
  final int disputeRevision;

  /// The current dispute, or null when none was ever raised.
  final DeliveryProofDisputeRecord? current;

  /// Whether a current record is **present**.
  ///
  /// **A structural fact about the loaded aggregate, not a trust claim.** It
  /// says a record exists; it does not say the aggregate is canonical, and a
  /// torn load can be `true` here. Ask `canonicalState` for a trusted answer.
  bool get hasCurrentRecord => current != null;
}

/// Canonical identity of the delivery whose proof situation is being disputed,
/// resolved **server-side**.
///
/// ```text
/// order resource id
///   -> trusted current order / assessment / dispute read-set
///   -> DeliveryProofDisputeContext
/// ```
///
/// > **Not authority.** This is the shape the backend fills from canonical
/// > storage, and passing one proves nothing about trust. Fresh authorization
/// > on every request, including replays, remains FND-003A's and the backend's
/// > — this contract duplicates none of it.
///
/// It carries the resource and nothing else. In particular it does **not**
/// carry the customer's principal id: whether the actor owns the order is
/// `ScopeRequirement.ownResource`'s question, answered by
/// `evaluateAuthorization` against trusted scope, and answering it a second
/// time here would create a second place for it to drift.
@immutable
class DeliveryProofDisputeContext {
  const DeliveryProofDisputeContext({required this.resourceId});

  /// The order. Validated with the repository's canonical opaque-id rule.
  final String resourceId;

  /// Whether this context is itself usable. Nothing is trimmed or repaired.
  bool get isWellFormed => isValidOpaqueId(resourceId);

  /// A **debug representation, and never a validity claim.** A malformed
  /// context renders no field.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofDisputeContext($resourceId)'
      : 'DeliveryProofDisputeContext(invalid)';
}

/// What a **raise** consumes, beyond the facts themselves.
///
/// Authorization, idempotency, the reason requirement and the command →
/// permission mapping have **already happened** by the time this is evaluated.
/// It carries no principal, no grant, no reason and no payload: it is the state
/// machine's input, not a security boundary, and duplicating FND-003A's checks
/// here would create a second place for them to drift. The acting principal
/// arrives separately, server-derived, exactly as the assessor does in
/// FND-003D2A.
///
/// **Raising pins the whole read-set it depends on.** The basis is derived from
/// the current assessment and the operation is only meaningful for an in-flight
/// delivery, so a stale view of the assessment or the order is refused rather
/// than silently recorded against facts that have already moved.
@immutable
class DeliveryProofDisputeRaiseRequest {
  const DeliveryProofDisputeRaiseRequest({
    required this.disputeId,
    required this.atUtc,
    required this.expectedDisputeRevision,
    required this.expectedAssessmentRevision,
    required this.expectedOrderRevision,
  });

  /// The **new** server-generated opaque dispute id.
  final String disputeId;

  /// Server UTC time of the operation.
  final DateTime atUtc;

  /// Dispute revision the caller believes is current. **0** for a raise: a
  /// raise starts from an order that has no dispute.
  final int expectedDisputeRevision;

  /// Assessment revision the caller believes is current.
  ///
  /// The basis is derived from this aggregate, so raising against a stale view
  /// of it would record a basis the caller never actually saw.
  final int expectedAssessmentRevision;

  /// Order revision the caller believes is current.
  ///
  /// Checked even though a dispute leaves the order untouched: raising
  /// *depends* on the order still being `in_delivery`.
  final int expectedOrderRevision;
}

/// What **recording that review started** consumes, beyond the dispute itself.
///
/// > **Deliberately smaller than a raise.** *(Corrected by
/// > FND-003D2B-FIX-001.)* This operation used to travel in a shared request
/// > carrying `expectedOrderRevision`, and the shared evaluator additionally
/// > validated the current assessment aggregate, the current order aggregate,
/// > the order's revision, `in_delivery` and `committed` before it would run.
/// >
/// > **None of that is anything this operation reads or changes.** An open
/// > dispute is already canonical, and it already carries its immutable basis;
/// > beginning to review it moves no order, no custody, no assignment, no
/// > assessment, no stock and no money. Requiring the surrounding lifecycle to
/// > be unchanged created a hidden dependency that could **freeze review of a
/// > validly raised dispute** because something unrelated moved afterwards — a
/// > reassessment, or a torn assessment read. That is the opposite of what a
/// > fallback is for.
/// >
/// > 0.9 is an unaccepted, unreleased candidate with **no serialization**, so
/// > the shape was corrected in place rather than keeping a misleading field
/// > for a compatibility nobody could depend on.
///
/// **This independence infers nothing.** It says only that review may begin; it
/// implies no delivery, refusal, return or outcome, and grants no permission to
/// conclude one.
@immutable
class DeliveryProofDisputeReviewRequest {
  const DeliveryProofDisputeReviewRequest({
    required this.disputeId,
    required this.atUtc,
    required this.expectedDisputeRevision,
  });

  /// The dispute being acted on. Must match the order's current one exactly.
  final String disputeId;

  /// Server UTC time of the operation.
  final DateTime atUtc;

  /// Dispute revision the caller believes is current — the **only** aggregate
  /// this operation reads or writes, and therefore the only compare-and-set it
  /// can honestly perform.
  final int expectedDisputeRevision;
}
