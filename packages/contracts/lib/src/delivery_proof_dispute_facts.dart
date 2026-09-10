import 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
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

/// **The canonical resource comes from the authorization grant.**
///
/// *(FND-003D2B-FIX-002 removed `DeliveryProofDisputeContext`.)* It carried a
/// resource id and nothing else, and once the executable evaluators began
/// requiring an `AuthorizationGrant` — which already names the exact resource
/// `evaluateAuthorization` allowed the actor to act on — keeping it would have
/// meant **two sources of canonical resource truth that could disagree**. The
/// one bound to the authorization decision is the one that must win, so the
/// other was deleted rather than left as a second shape to keep in step.

/// One order lifecycle read, **bound to the resource it was read from**.
///
/// *(Added by FND-003D2B-FIX-003.)* The accepted `OrderLifecycleFacts` carries
/// a state, a revision, a reservation state and a unit count — and **no
/// resource id**. That is correct for the pre-dispatch evaluator, which is
/// handed one order and asked about that order; it is not sufficient here,
/// where a raise must prove that *four* independently supplied things describe
/// the **same** delivery.
///
/// Without this binding, an order-B read whose scalars happen to match order A
/// — `in_delivery`, revision 5, reservation `committed` — was
/// **indistinguishable** from order A's own facts, so a dispute could be
/// recorded against A on the strength of B's lifecycle. Numeric equality is not
/// identity.
///
/// This is a **read**, not a second order aggregate: it adds no state, no
/// transition, no revision arithmetic and no lifecycle rule. The accepted
/// `OrderLifecycleFacts` contract is untouched and continues to be the single
/// definition of what an order's lifecycle facts are — this only says *which
/// order they were loaded for*.
///
/// > **Binding is not provenance.** Saying which resource a read claims to be
/// > for does not prove the read came from trusted storage, was consistent with
/// > the rest of the read-set, or was current. That the backend loads all
/// > aggregates for one canonical resource in **one consistent transaction**
/// > remains criterion **DPD3**, and revalidation inside the transaction
/// > **DPD4** — both **NOT RUN**.
@immutable
class DeliveryProofDisputeOrderRead {
  const DeliveryProofDisputeOrderRead({
    required this.resourceId,
    required this.order,
  });

  /// The order these facts were read for. Validated with the repository's
  /// canonical opaque-id rule.
  final String resourceId;

  /// The accepted lifecycle facts, exactly as `OrderLifecycleFacts` defines
  /// them. Nothing is copied out, reinterpreted or re-validated here.
  final OrderLifecycleFacts order;

  /// Structurally usable. Fails closed; repairs nothing.
  bool get isWellFormed => isValidOpaqueId(resourceId);

  /// Whether this read is **structurally valid and for** [resourceId].
  ///
  /// Both halves are required. Raw equality alone would fail open: two
  /// identically-malformed values would match and certify a read that belongs
  /// to no identifiable order — the same lesson `DeliveryEvidenceRef.belongsTo`
  /// learned in FND-003D1.
  bool belongsToResource(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  /// A **debug representation, and never a validity claim.**
  ///
  /// A well-formed read renders a bounded canonical id and enum names; a
  /// malformed one renders no field at all. It carries no actor, role,
  /// permission, membership, reason, approval, money or proof material — there
  /// is nothing else here to leak.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofDisputeOrderRead($resourceId, '
            '${order.state?.id ?? '-'}, rev=${order.revision})'
      : 'DeliveryProofDisputeOrderRead(invalid)';
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
