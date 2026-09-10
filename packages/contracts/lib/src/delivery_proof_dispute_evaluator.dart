/// Evaluators for the fallback delivery-proof dispute operations.
///
/// All are pure: no I/O, no clock, no storage. Wall-clock time and client
/// arrival order are not concurrency control — server transaction and revision
/// ordering decide races.
///
/// ## One evaluator per operation, and one read-set per evaluator
///
/// *(Restructured by FND-003D2B-FIX-001.)* These were originally a single
/// `evaluateDeliveryProofDispute` taking every aggregate for every operation,
/// and that is precisely why the correction matters: **a shared read-set
/// silently becomes a shared precondition.** Recording that review started
/// ended up requiring a canonical current assessment, a canonical current
/// order, the order's revision, `in_delivery` and `committed` — **none of which
/// that operation reads or changes**. A reassessment, or a torn assessment
/// read, occurring after a validly raised dispute could therefore freeze it out
/// of review. A fallback that stops working when the thing it is a fallback for
/// changes is not a fallback.
///
/// Each function now takes **only the facts its own operation depends on**, so
/// the read-set is part of the contract rather than a convention:
///
/// | Operation | Reads |
/// |---|---|
/// | [evaluateRaiseDeliveryProofDispute] | **grant**, dispute, **assessment**, **resource-bound order read** |
/// | [evaluateRecordDeliveryProofDisputeReview] | **grant**, dispute |
/// | [evaluateResolveDeliveryProofDispute] | **nothing at all** |
///
/// ## Authorization is required, and is still FND-003A's
///
/// *(Corrected by FND-003D2B-FIX-002.)* Both executable evaluators take an
/// [AuthorizationGrant] — the artifact FND-003A made **unforgeable** precisely
/// so downstream steps could rely on it, obtainable only from a successful
/// [evaluateAuthorization].
///
/// The previous signatures took a bare `Principal` and *documented* that
/// authorization had already run. **A pure function cannot assert that about
/// its caller**: nothing distinguished a properly authorized call from one that
/// skipped the check, so a non-owner customer could reach a raise transition
/// and a customer-only principal could reach a review transition.
///
/// These functions still do **not** evaluate policy. Role, membership status,
/// scope and reason live in `permissionMatrix` and are decided in exactly one
/// place; what is checked here is only that the grant in hand is bound to this
/// principal, this permission and this resource — see
/// `checkDisputeAuthorization`. **Freshness remains the backend's** (R33–R40,
/// NOT RUN).
///
/// The **canonical resource is the stored dispute aggregate's**, and every
/// other member of the read-set — the grant, the assessment and the order read
/// — must agree with it. There is no separate context parameter: a fifth
/// resource value could only disagree with the four that already have to match.
///
/// *(FND-003D2B-FIX-003.)* The order read is part of that comparison because
/// `OrderLifecycleFacts` carries no resource id of its own; see
/// [DeliveryProofDisputeOrderRead].
///
/// What these functions add beyond that is **fact integrity**: that the
/// aggregates describe that same order, that they are current, and that the
/// operation is coherent with them.
///
/// They are also **not** a resolution. No outcome, finding, fault, liability,
/// fee, refund, compensation, return route or delivery consequence is produced
/// by any path through any of them.
///
/// Any condition not enumerated fails closed.
library;

import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_validation.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_authorization.dart';
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

/// Raise the fallback dispute against the **current canonical** proof
/// situation.
///
/// Raising is the operation that *derives* a basis, so it pins the whole
/// read-set that basis comes from: the assessment it is recorded against, and
/// the order whose delivery is in flight. A stale view of either is refused.
///
/// [actor] is the principal the backend derived from **verified**
/// authentication, and it arrives separately from [request] on purpose: a
/// request that could name its own actor would not be attributing anything.
/// This is the exact inverse of `evaluateDeliveryProofAssessment`, which
/// refuses everything that is not a trusted verifier — here only a **person**
/// may act, because a dispute is a claim someone makes.
///
/// Custody and the rider assignment are deliberately **not** in the read-set: a
/// dispute asserts nothing about a rider, the audit identity of the rider
/// attempt that *was* assessed already lives on the assessment record the basis
/// points at, and requiring current custody would make the fallback unavailable
/// exactly when custody has gone wrong.
DeliveryProofDisputeOutcome evaluateRaiseDeliveryProofDispute({
  required DeliveryProofDisputeRaiseRequest request,
  required Principal actor,
  required AuthorizationGrant grant,
  required DeliveryProofDisputeFacts dispute,
  required DeliveryProofAssessmentFacts assessment,
  required DeliveryProofDisputeOrderRead order,
}) {
  // 1. The canonical resource is the one the **stored dispute aggregate** is
  //    about — taken from the read-set, never from the grant, so the check
  //    below is a real comparison rather than the grant agreeing with itself.
  final String resourceId = dispute.resourceId;

  // 2. Canonical authorization success, bound to this principal, this
  //    permission and that resource. Nothing below runs without it.
  final DeliveryProofDisputeDenial? unauthorized = checkDisputeAuthorization(
    grant: grant,
    actor: actor,
    command: DeliveryProofDisputeCommand.raise,
    expectedResourceId: resourceId,
  );
  if (unauthorized != null) {
    return DeliveryProofDisputeOutcome.deny(unauthorized);
  }

  // 2. Aggregate integrity for every aggregate this operation reads, before
  //    anything can produce a record. Each validator is the canonical one for
  //    its own aggregate — none is reimplemented here, and each keeps its own
  //    denial so a log never has to guess which aggregate was torn.
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
  if (validateAggregate(order.order) != null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderAggregateInconsistent,
    );
  }

  // 3. Every aggregate must describe the same order, and that order must be the
  //    canonical one the backend resolved the request against. Two aggregates
  //    agreeing with each other is not the same as both being about the right
  //    order.
  //    *(Completed by FND-003D2B-FIX-003.)* The order read is included. It
  //    used to be a bare `OrderLifecycleFacts`, which carries **no resource
  //    id**, so an order-B read whose scalars matched order A was
  //    indistinguishable from A's own facts — numeric equality is not identity.
  if (assessment.resourceId != resourceId ||
      !order.belongsToResource(resourceId)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resourceBindingMismatch,
    );
  }

  // 4. Concurrency, before any record is constructed. Every aggregate this
  //    decision reads is compare-and-set, including the two it leaves
  //    untouched: the decision *depends* on them, so acting on a stale view of
  //    either is refused.
  //
  //    Correct revisions are never a substitute for the identity, state and
  //    eligibility checks below — they run in addition, not instead.
  if (request.expectedDisputeRevision != dispute.disputeRevision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeRevisionConflict,
    );
  }
  if (request.expectedAssessmentRevision != assessment.assessmentRevision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.assessmentRevisionConflict,
    );
  }
  if (request.expectedOrderRevision != order.order.revision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderRevisionConflict,
    );
  }

  // 5. Actor shape and server time.
  final DeliveryProofDisputeDenial? actorOrTime = _checkActorAndTime(
    actor,
    request.atUtc,
  );
  if (actorOrTime != null) {
    return DeliveryProofDisputeOutcome.deny(actorOrTime);
  }

  // 6. The delivery whose proof is contested must actually be in flight. Any
  //    other order state is outside what any accepted slice defines, and
  //    guessing the answer would be inventing the lifecycle.
  if (order.order.state != OrderState.inDelivery) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.orderNotInDelivery,
    );
  }
  if (order.order.reservationState != ReservationState.committed) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.reservationNotCommitted,
    );
  }

  // 7. Dispute identity.
  if (!isValidOpaqueId(request.disputeId)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeIdInvalid,
    );
  }

  // 8. At most one live fallback dispute per order. Every state this contract
  //    can store is open or under review, so any existing record is a live one;
  //    a future resolution slice must decide **deliberately** whether a new
  //    dispute may follow a resolved one, rather than inheriting an answer
  //    from here.
  if (dispute.current != null) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeAlreadyOpen,
    );
  }

  // 9. The basis is derived from trusted state through the canonical accessor,
  //    never from request content: a caller does not get to choose what it is
  //    disputing. The aggregate was validated above, so a null verdict here is
  //    canonical absence rather than corruption — corruption already denied.
  final DeliveryProofAssessmentVerdict? verdict = assessment.canonicalVerdict;
  final DeliveryProofDisputeBasis basis;
  switch (verdict) {
    case null:
      basis = DeliveryProofDisputeBasis.notAssessed(resourceId: resourceId);
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
        resourceId: resourceId,
        assessmentId: current.assessmentId,
        assessmentRevision: current.assessmentRevision,
      );
  }

  return DeliveryProofDisputeOutcome.allow(
    DeliveryProofDisputeTransition(
      command: DeliveryProofDisputeCommand.raise,
      record: DeliveryProofDisputeRecord.raised(
        disputeId: request.disputeId,
        resourceId: resourceId,
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
/// ## The read-set is the dispute, and nothing else
///
/// *(Corrected by FND-003D2B-FIX-001.)* This takes **no assessment facts and no
/// order facts**, because it reads and changes neither. An open dispute is
/// already canonical and already carries its immutable basis; beginning to
/// review it moves no order, no custody, no assignment, no assessment, no stock
/// and no money.
///
/// Requiring the surrounding lifecycle to still be intact would mean a
/// reassessment, a torn assessment read, or an unrelated order write after a
/// **validly raised** dispute could freeze it out of review — the opposite of
/// what a fallback is for.
///
/// **Nothing about a delivery, refusal or return may be inferred from that
/// independence.** It says only that review may begin.
///
/// ## What it does check
///
/// The authorization grant, the canonical stored dispute, the exact dispute id,
/// the dispute revision (compare-and-set), that the dispute is still `open`,
/// that the actor is a verified human principal, that the timestamp is server
/// UTC, and that review does not precede the raise.
///
/// **The canonical resource is anchored by the stored dispute aggregate**; the
/// grant must **cover** that independently selected resource. It does not
/// choose, supply or name it — comparing a grant against a value the grant
/// itself provided would prove nothing, which is the tautology
/// FND-003D2B-FIX-003 removed.
///
/// ## Authorization
///
/// *(Added by FND-003D2B-FIX-002.)* An [AuthorizationGrant] for
/// `admin.dispute.administer`, bound to this principal and this resource, is
/// **required**. A customer-only principal cannot obtain one, so
/// `customer.dispute.raise` no longer reaches this transition; nor does an
/// inactive or out-of-region admin, nor an admin who supplied no reason —
/// `evaluateAuthorization` refuses each of them, and without its success
/// artifact there is nothing to pass here.
///
/// **There is deliberately no separation-of-duties rule.** An administrator who
/// holds a valid current grant is not refused merely because the same principal
/// earlier raised this dispute: the accepted matrix requires an active admin
/// membership, `ownRegion` scope and a stored reason, and sets
/// `approvalRequired: false`. A private second authorization policy here would
/// be an invented one. If separation of duties is ever wanted, it needs its own
/// permission and ADR.
///
/// **Raising confers no admin authority.** The historical raiser reaches this
/// transition only by independently holding an admin grant of their own.
DeliveryProofDisputeOutcome evaluateRecordDeliveryProofDisputeReview({
  required DeliveryProofDisputeReviewRequest request,
  required Principal actor,
  required AuthorizationGrant grant,
  required DeliveryProofDisputeFacts dispute,
}) {
  // 1. The canonical resource is the stored dispute's, taken from the read-set.
  final String resourceId = dispute.resourceId;

  // 2. Canonical authorization success for `admin.dispute.administer`, bound to
  //    this principal and that resource. A customer-only principal cannot
  //    obtain this grant, and therefore cannot reach the transition.
  final DeliveryProofDisputeDenial? unauthorized = checkDisputeAuthorization(
    grant: grant,
    actor: actor,
    command: DeliveryProofDisputeCommand.recordReviewStarted,
    expectedResourceId: resourceId,
  );
  if (unauthorized != null) {
    return DeliveryProofDisputeOutcome.deny(unauthorized);
  }

  // 2. The dispute aggregate must be canonical before anything reads it.
  final DeliveryProofDisputeDenial? disputeCorruption =
      validateDeliveryProofDisputeAggregate(dispute);
  if (disputeCorruption != null) {
    return DeliveryProofDisputeOutcome.deny(disputeCorruption);
  }

  //    The resource binding for review is `grant.covers` above: the stored
  //    dispute supplies the resource and the grant must cover exactly it, so
  //    there is no second comparison to make here — and no second source of
  //    resource truth that could disagree.

  // 4. Compare-and-set on the one aggregate this operation writes.
  if (request.expectedDisputeRevision != dispute.disputeRevision) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeRevisionConflict,
    );
  }

  // 5. Actor shape and server time.
  final DeliveryProofDisputeDenial? actorOrTime = _checkActorAndTime(
    actor,
    request.atUtc,
  );
  if (actorOrTime != null) {
    return DeliveryProofDisputeOutcome.deny(actorOrTime);
  }

  // 6. Dispute identity.
  if (!isValidOpaqueId(request.disputeId)) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeIdInvalid,
    );
  }
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

  // 7. Only an open dispute can start being reviewed. A repeat of the same
  //    operation is refused rather than silently advancing the revision again.
  if (current.state != DeliveryProofDisputeState.open) {
    return const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.disputeNotOpen,
    );
  }

  // 8. Two server-supplied UTC values that cannot be ordered are incoherent,
  //    and storing them would produce a record the validator refuses. No
  //    window, deadline or duration is derived from either.
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

/// Resolve a fallback dispute — **enumerated, and never executable.**
///
/// Always refuses with [DeliveryProofDisputeDenial.resolutionPolicyDeferred],
/// and takes **no arguments at all**, because a deferred edge consumes nothing:
/// there is no request, no read-set and no fact it could partially evaluate.
/// That is a stronger statement than "refused before any fact is read", and it
/// is why the signature is empty rather than mirroring the others.
///
/// This follows `LifecycleDenial.policyDeferred`'s precedent: a backend must be
/// able to tell **"not decided yet"** from **"never allowed"** — see
/// [DeliveryProofDisputeOutcome.isPolicyDeferred] — so nobody fills the gap
/// with a guessed rule, a zero fee or an automatic cancellation.
///
/// Resolving a dispute would require deciding who prevails; whether the order
/// becomes delivered, refused or returned, and where a return goes; whether a
/// fee, refund, compensation or liability follows and who bears it; whether
/// stock is restored; and whether customer participation is optional,
/// mandatory, sufficient or a veto. **Not one of those is decided anywhere in
/// this repository** — they need owner decision **O6**, **FND-003C** and
/// **FND-003B3B**.
DeliveryProofDisputeOutcome evaluateResolveDeliveryProofDispute() =>
    const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resolutionPolicyDeferred,
    );

/// The two checks both executable operations share, in one place so they cannot
/// drift apart.
///
/// A trusted worker may neither raise nor review: a background job recorded as
/// the raiser or the reviewer is an unattributable audit trail. This is an
/// integrity check on what gets recorded, **not** the authorization gate — that
/// already ran.
DeliveryProofDisputeDenial? _checkActorAndTime(
  Principal actor,
  DateTime atUtc,
) {
  if (!actor.isUser) {
    return DeliveryProofDisputeDenial.actorNotHumanPrincipal;
  }
  if (!atUtc.isUtc) {
    return DeliveryProofDisputeDenial.timestampNotUtc;
  }
  return null;
}
