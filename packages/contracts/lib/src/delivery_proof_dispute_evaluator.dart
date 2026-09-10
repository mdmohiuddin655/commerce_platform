import 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_validation.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_basis.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_command.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_denial.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_facts.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_state.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_transition.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_validation.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/reservation_state.dart';

/// Evaluate one fallback delivery-proof dispute operation.
///
/// Pure: no I/O, no clock, no storage. Wall-clock time and client arrival order
/// are not concurrency control — server transaction and revision ordering
/// decide races.
///
/// Every aggregate is supplied as trusted current facts read in **one
/// consistent transaction** (**DPD3**). Passing them proves nothing about
/// trust; they are the shapes the backend fills from canonical storage.
///
/// [actor] is the principal the backend derived from **verified**
/// authentication, and it arrives separately from [request] on purpose: a
/// request that could name its own actor would not be attributing anything.
/// This is the exact inverse of `evaluateDeliveryProofAssessment`, which
/// refuses everything that is not a trusted verifier — here only a **person**
/// may act, because a dispute is a claim someone makes.
///
/// ## What this function is not
///
/// It is **not** the authorization boundary. `evaluateAuthorization` has
/// already run against the canonical matrix, with `customer.dispute.raise`'s
/// `ownResource` scope, `admin.dispute.administer`'s `ownRegion` scope and both
/// permissions' `reasonRequired`. Repeating any of that here would create a
/// second place for it to drift. What this function adds is **context
/// integrity**: that the facts describe one canonical order, that they are
/// current, and that the operation is coherent with them.
///
/// It is also **not** a resolution. No outcome, finding, fault, liability, fee,
/// refund, compensation, return route or delivery consequence is produced by
/// any path through it, and `DeliveryProofDisputeCommand.resolve` is refused
/// before a single fact is read.
///
/// ## What is deliberately not in the read-set
///
/// **Custody and the rider assignment.** They are central to
/// `evaluateDeliveryProofAssessment`, which decides something *about* a rider's
/// delivery, and they are absent here on purpose:
///
/// - the dispute never asserts anything about a rider, so it needs no rider
///   binding — and the immutable audit identity of the rider attempt that *was*
///   assessed already lives on the assessment record the basis points at, where
///   FND-003D2A put it. Copying it onto the dispute would create a projection
///   free to drift from the record that owns it;
/// - requiring current custody would make the fallback **unavailable exactly
///   when something has gone wrong with custody** — a rider reassignment
///   mid-flight, a corrupt holder record — which is the opposite of a fallback.
///
/// Any condition not enumerated fails closed.
DeliveryProofDisputeOutcome evaluateDeliveryProofDispute({
  required DeliveryProofDisputeRequest request,
  required Principal actor,
  required DeliveryProofDisputeContext context,
  required DeliveryProofDisputeFacts dispute,
  required DeliveryProofAssessmentFacts assessment,
  required OrderLifecycleFacts order,
}) {
  // 0. Policy-deferred operations are refused **before any fact is read**, so
  //    no partial evaluation of an undecided edge can happen and the denial is
  //    identical whatever the facts look like.
  if (DeliveryProofDisputeCommand.policyDeferredInThisSlice.contains(
    request.command,
  )) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resolutionPolicyDeferred,
    );
  }

  // 1. The canonical resource identity must itself be usable.
  if (!context.isWellFormed) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resourceBindingMismatch,
    );
  }

  // 2. Aggregate integrity for every aggregate, before anything can produce a
  //    record. Each validator is the canonical one for its own aggregate —
  //    none is reimplemented here, and each keeps its own denial so a log never
  //    has to guess which aggregate was torn.
  final DeliveryProofDisputeDenial? disputeCorruption =
      validateDeliveryProofDisputeAggregate(dispute);
  if (disputeCorruption != null) {
    return DeliveryProofDisputeOutcome.deny(disputeCorruption);
  }
  // A torn assessment is never read as `notSatisfied` and never becomes a
  // fallback ground: corruption is a reconciliation case, not a negative
  // result.
  if (validateDeliveryProofAssessmentAggregate(assessment) != null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.assessmentAggregateInconsistent,
    );
  }
  if (validateAggregate(order) != null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderAggregateInconsistent,
    );
  }

  // 3. Every aggregate must describe the same order, and that order must be the
  //    canonical one the backend resolved the request against. Two aggregates
  //    agreeing with each other is not the same as both being about the right
  //    order.
  if (dispute.resourceId != context.resourceId ||
      assessment.resourceId != context.resourceId) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resourceBindingMismatch,
    );
  }

  // 4. Concurrency, before any record is constructed. Every aggregate the
  //    decision reads is compare-and-set, including the two this operation
  //    leaves untouched: the decision *depends* on them, so acting on a stale
  //    view of either is refused.
  //
  //    Correct revisions are never a substitute for the identity, state and
  //    eligibility checks below — they run in addition, not instead.
  if (request.expectedDisputeRevision != dispute.disputeRevision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeRevisionConflict,
    );
  }
  if (request.expectedOrderRevision != order.revision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderRevisionConflict,
    );
  }
  // Present only for a raise, structurally — recording that review started must
  // keep working after the basis has been superseded, which is exactly the
  // situation this slice exists to handle.
  final int? expectedAssessmentRevision = request.expectedAssessmentRevision;
  if (expectedAssessmentRevision != null &&
      expectedAssessmentRevision != assessment.assessmentRevision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.assessmentRevisionConflict,
    );
  }

  // 5. Actor shape. A trusted worker may not raise or review a dispute: a
  //    background job in the raiser field is an unattributable audit trail.
  //    This is an integrity check on what gets recorded, **not** the
  //    authorization gate — that already ran.
  if (!actor.isUser) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.actorNotHumanPrincipal,
    );
  }
  if (!request.atUtc.isUtc) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.timestampNotUtc,
    );
  }

  // 6. The delivery whose proof is contested must actually be in flight. Any
  //    other order state is outside what any accepted slice defines, and
  //    guessing the answer would be inventing the lifecycle.
  if (order.state != OrderState.inDelivery) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderNotInDelivery,
    );
  }
  if (order.reservationState != ReservationState.committed) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.reservationNotCommitted,
    );
  }

  // 7. Dispute identity, for every operation.
  if (!isValidOpaqueId(request.disputeId)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeIdInvalid,
    );
  }

  return switch (request.command) {
    DeliveryProofDisputeCommand.raise => _raise(
      request: request,
      actor: actor,
      context: context,
      dispute: dispute,
      assessment: assessment,
    ),
    DeliveryProofDisputeCommand.recordReviewStarted => _recordReviewStarted(
      request: request,
      actor: actor,
      dispute: dispute,
    ),
    // Unreachable: refused at step 0, before any fact was read. Stated so the
    // switch is exhaustive and a future resolution slice has to make a
    // deliberate decision here rather than inherit one.
    DeliveryProofDisputeCommand.resolve => const DeliveryProofDisputeOutcome
        .deny(DeliveryProofDisputeDenial.resolutionPolicyDeferred),
  };
}

/// Raise the fallback dispute against the **current canonical** proof
/// situation.
DeliveryProofDisputeOutcome _raise({
  required DeliveryProofDisputeRequest request,
  required Principal actor,
  required DeliveryProofDisputeContext context,
  required DeliveryProofDisputeFacts dispute,
  required DeliveryProofAssessmentFacts assessment,
}) {
  // At most one live fallback dispute per order. Every state this contract can
  // store is open or under review, so any existing record is a live one; a
  // future resolution slice must decide **deliberately** whether a new dispute
  // may follow a resolved one, rather than inheriting an answer from here.
  if (dispute.current != null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeAlreadyOpen,
    );
  }

  // The basis is derived from trusted state through the canonical accessor,
  // never from request content: a caller does not get to choose what it is
  // disputing. The aggregate was validated above, so a null verdict here is
  // canonical absence rather than corruption — corruption already denied.
  final DeliveryProofAssessmentVerdict? verdict = assessment.canonicalVerdict;
  final DeliveryProofDisputeBasis basis;
  switch (verdict) {
    case null:
      basis = DeliveryProofDisputeBasis.notAssessed(
        resourceId: context.resourceId,
      );
    case DeliveryProofAssessmentVerdict.satisfied:
      // Not a fallback ground. Contesting a satisfied assessment is a
      // different, undefined workflow — see `assessmentSatisfied`.
      return const DeliveryProofDisputeOutcome.deny(
        DeliveryProofDisputeDenial.assessmentSatisfied,
      );
    case DeliveryProofAssessmentVerdict.notSatisfied:
      // A canonical verdict implies a canonical current record.
      final DeliveryProofAssessmentRecord current = assessment.current!;
      basis = DeliveryProofDisputeBasis.notSatisfied(
        resourceId: context.resourceId,
        assessmentId: current.assessmentId,
        assessmentRevision: current.assessmentRevision,
      );
  }

  return DeliveryProofDisputeOutcome.allow(
    DeliveryProofDisputeTransition(
      command: DeliveryProofDisputeCommand.raise,
      record: DeliveryProofDisputeRecord.raised(
        disputeId: request.disputeId,
        resourceId: context.resourceId,
        basis: basis,
        // Derived from the verified principal, never from request content.
        raisedByPrincipalId: actor.id,
        raisedAtUtc: request.atUtc,
      ),
    ),
  );
}

/// Record that an authorized administrator started reviewing the dispute.
///
/// **Deliberately independent of the basis's standing.** A dispute whose basis
/// has been superseded is still a dispute, and a reassessment must not be able
/// to freeze one out of review — that is the whole reason the request cannot
/// pin an assessment revision.
DeliveryProofDisputeOutcome _recordReviewStarted({
  required DeliveryProofDisputeRequest request,
  required Principal actor,
  required DeliveryProofDisputeFacts dispute,
}) {
  final DeliveryProofDisputeRecord? current = dispute.current;
  if (current == null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeNotFound,
    );
  }
  if (!current.hasDisputeId(request.disputeId)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeIdMismatch,
    );
  }
  // Only an open dispute can start being reviewed. A repeat of the same
  // operation is refused rather than silently advancing the revision again.
  if (current.state != DeliveryProofDisputeState.open) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeNotOpen,
    );
  }
  // Self-review is no review — the same reasoning `evaluateAuthorization`
  // applies to self-approval.
  if (current.raisedByPrincipalId == actor.id) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.reviewerIsRaiser,
    );
  }
  // Two server-supplied UTC values that cannot be ordered are incoherent, and
  // storing them would produce a record the validator refuses. No window,
  // deadline or duration is derived from either.
  if (request.atUtc.isBefore(current.raisedAtUtc)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.reviewTimestampPrecedesRaise,
    );
  }

  return DeliveryProofDisputeOutcome.allow(
    DeliveryProofDisputeTransition(
      command: DeliveryProofDisputeCommand.recordReviewStarted,
      // The basis, the raiser and the raise time are carried forward **by
      // construction** — this constructor does not accept them — so advancing a
      // dispute cannot rewrite what it was about or who raised it.
      record: DeliveryProofDisputeRecord.reviewStarted(
        previous: current,
        reviewerPrincipalId: actor.id,
        atUtc: request.atUtc,
      ),
    ),
  );
}
