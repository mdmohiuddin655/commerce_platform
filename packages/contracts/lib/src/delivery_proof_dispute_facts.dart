import 'package:cp_contracts/src/delivery_proof_dispute_command.dart';
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

/// One request to apply a named fallback dispute operation.
///
/// Authorization, idempotency, the reason requirement and the command →
/// permission mapping have **already happened** by the time this is evaluated.
/// It carries no principal, no grant, no reason and no payload: it is the state
/// machine's input, not a security boundary, and duplicating FND-003A's checks
/// here would create a second place for them to drift. The acting principal
/// arrives separately, server-derived, exactly as the assessor does in
/// FND-003D2A.
///
/// **The constructors are the contract.** There is no general public
/// constructor, so a caller cannot assemble a request whose expectations do not
/// match its operation:
///
/// | Constructor | Pins the assessment revision? |
/// |---|---|
/// | [DeliveryProofDisputeRequest.raise] | **yes** — the basis is derived from the assessment the caller actually saw |
/// | [DeliveryProofDisputeRequest.recordReviewStarted] | **no, and it must not** |
/// | [DeliveryProofDisputeRequest.resolve] | no — the operation is refused before any fact is read |
///
/// The middle row is the important one. Recording that review started must
/// **keep working after the basis has been superseded** — that is precisely the
/// situation this slice exists to handle — so requiring the assessment to be
/// unchanged would make a reassessment silently freeze the dispute. Making the
/// field structurally absent is stronger than documenting that it is ignored.
@immutable
class DeliveryProofDisputeRequest {
  const DeliveryProofDisputeRequest._({
    required this.command,
    required this.disputeId,
    required this.atUtc,
    required this.expectedDisputeRevision,
    required this.expectedAssessmentRevision,
    required this.expectedOrderRevision,
  });

  /// Raise the fallback dispute. [expectedDisputeRevision] is **0**: a raise
  /// starts from an order that has no dispute.
  const DeliveryProofDisputeRequest.raise({
    required String disputeId,
    required DateTime atUtc,
    required int expectedDisputeRevision,
    required int expectedAssessmentRevision,
    required int expectedOrderRevision,
  }) : this._(
         command: DeliveryProofDisputeCommand.raise,
         disputeId: disputeId,
         atUtc: atUtc,
         expectedDisputeRevision: expectedDisputeRevision,
         expectedAssessmentRevision: expectedAssessmentRevision,
         expectedOrderRevision: expectedOrderRevision,
       );

  /// Record that an administrator started reviewing the dispute.
  const DeliveryProofDisputeRequest.recordReviewStarted({
    required String disputeId,
    required DateTime atUtc,
    required int expectedDisputeRevision,
    required int expectedOrderRevision,
  }) : this._(
         command: DeliveryProofDisputeCommand.recordReviewStarted,
         disputeId: disputeId,
         atUtc: atUtc,
         expectedDisputeRevision: expectedDisputeRevision,
         expectedAssessmentRevision: null,
         expectedOrderRevision: expectedOrderRevision,
       );

  /// **Always refused** — [DeliveryProofDisputeCommand.resolve] is a real edge
  /// whose business policy is undecided. It is constructible so that the
  /// deferral is testable rather than merely documented.
  const DeliveryProofDisputeRequest.resolve({
    required String disputeId,
    required DateTime atUtc,
    required int expectedDisputeRevision,
    required int expectedOrderRevision,
  }) : this._(
         command: DeliveryProofDisputeCommand.resolve,
         disputeId: disputeId,
         atUtc: atUtc,
         expectedDisputeRevision: expectedDisputeRevision,
         expectedAssessmentRevision: null,
         expectedOrderRevision: expectedOrderRevision,
       );

  /// The named operation. Never a target state.
  final DeliveryProofDisputeCommand command;

  /// For a raise, the **new** server-generated opaque dispute id. For every
  /// other operation, the id of the dispute being acted on, which must match
  /// the order's current one exactly.
  final String disputeId;

  /// Server UTC time of the operation.
  final DateTime atUtc;

  /// Dispute revision the caller believes is current. **0** for a raise.
  final int expectedDisputeRevision;

  /// Assessment revision the caller believes is current, for a raise only.
  ///
  /// Null for every other operation, structurally — see the class comment.
  final int? expectedAssessmentRevision;

  /// Order revision the caller believes is current.
  ///
  /// Checked even though a dispute leaves the order untouched: the decision
  /// *depends* on the order still being `in_delivery`, so acting on a stale
  /// view of it is refused rather than silently recorded against facts that
  /// have moved.
  final int expectedOrderRevision;
}
