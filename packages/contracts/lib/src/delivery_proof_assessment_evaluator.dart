import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/custody_lifecycle.dart';
import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/delivery_proof.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_authority.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_denial.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_transition.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_validation.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/rider_assignment.dart';

/// Evaluate one delivery-proof assessment.
///
/// Pure: no I/O, no clock, no storage. Wall-clock time and client arrival order
/// are not concurrency control — server transaction and revision ordering
/// decide races.
///
/// Every aggregate is supplied as trusted current facts read in **one
/// consistent transaction** (**DPA5**). Passing them proves nothing about
/// trust; they are the shapes the backend fills from canonical storage.
///
/// [assessor] is the principal the backend derived from **verified** internal
/// service authentication, and it arrives separately from [request] on purpose:
/// a request that could name its own assessor would not be authorizing
/// anything. It must be the exact verifier
/// [DeliveryProofAssessmentContext.authorizedAssessorPrincipalId] names —
/// holding `PrincipalKind.systemWorker` is necessary and **not sufficient**.
///
/// **There is deliberately no `CustodyCommand`-style command and no
/// `Permission` for this.** A normal assessment is not something a caller
/// asserts — it is what a trusted policy evaluator concluded, in the same way
/// `initialiseCustodyAtShop` is what is true once the shop has assembled the
/// goods rather than a claim a client makes. Adding a client-selectable
/// "declare proof satisfied" operation would be the arbitrary status patch this
/// contract forbids, aimed at the single most valuable status in the system.
///
/// Any condition not enumerated fails closed.
DeliveryProofAssessmentOutcome evaluateDeliveryProofAssessment({
  required DeliveryProofAssessmentRequest request,
  required Principal assessor,
  required DeliveryProofAssessmentContext context,
  required DeliveryProofAssessmentFacts assessment,
  required OrderLifecycleFacts order,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) {
  // 0. The canonical resource identity must itself be usable, and the
  //    authoritative references must be structurally sound. The D1 validators
  //    are the single source of that judgement.
  if (!isValidOpaqueId(context.resourceId)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.resourceBindingMismatch,
    );
  }
  final DeliveryProofDenial? policyIssue = validateDeliveryProofPolicyRef(
    context.policyRef,
  );
  if (policyIssue != null) {
    return DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.policyRefInvalid,
      structural: policyIssue,
    );
  }
  final DeliveryProofDenial? evidenceIssue = validateDeliveryEvidenceRef(
    context.evidenceRef,
    resourceId: context.resourceId,
  );
  if (evidenceIssue != null) {
    return DeliveryProofAssessmentOutcome.deny(
      evidenceIssue == DeliveryProofDenial.evidenceResourceMismatch
          ? DeliveryProofAssessmentDenial.evidenceResourceMismatch
          : DeliveryProofAssessmentDenial.evidenceRefInvalid,
      structural: evidenceIssue,
    );
  }

  // 1. Custody and the rider assignment must exist. Absence of custody is never
  //    read as "a rider must be carrying it".
  if (custody == null) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.custodyNotInitialised,
    );
  }
  if (riderAssignment == null) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.noAcceptedRiderAssignment,
    );
  }

  // 2. Aggregate integrity for every aggregate, before anything can produce an
  //    effect. Each validator is the canonical one for its own aggregate —
  //    none is reimplemented here.
  final DeliveryProofAssessmentDenial? assessmentCorruption =
      validateDeliveryProofAssessmentAggregate(assessment);
  if (assessmentCorruption != null) {
    return DeliveryProofAssessmentOutcome.deny(assessmentCorruption);
  }
  if (validateAggregate(order) != null ||
      validateCustodyAggregate(custody) != null ||
      validateRiderAssignmentAggregate(riderAssignment) != null) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.aggregateInconsistent,
    );
  }

  // 3. Every aggregate must describe the same order, and that order must be the
  //    canonical one the backend resolved the request against. Three aggregates
  //    agreeing with each other is not the same as three aggregates being about
  //    the right order.
  if (assessment.resourceId != context.resourceId ||
      custody.resourceId != context.resourceId ||
      riderAssignment.resourceId != context.resourceId) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.resourceBindingMismatch,
    );
  }

  // 4. Concurrency, before any transition is constructed. Every aggregate the
  //    decision reads is compare-and-set, including the three this transition
  //    leaves untouched: the verdict *depends* on them, so acting on a stale
  //    view of any one is refused.
  //
  //    Correct revisions are never a substitute for the identity, state,
  //    reference and binding checks below — they run in addition, not instead.
  if (request.expectedAssessmentRevision != assessment.assessmentRevision) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessmentRevisionConflict,
    );
  }
  if (request.expectedOrderRevision != order.revision) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.orderRevisionConflict,
    );
  }
  if (request.expectedCustodyRevision != custody.custodyRevision) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.custodyRevisionConflict,
    );
  }
  if (request.expectedRiderSlotRevision != riderAssignment.slotRevision) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.riderSlotRevisionConflict,
    );
  }

  // 5. Assessor authority — kind, then exact authorized identity.
  //
  //    Order matters for diagnosis: "not a server process" and "the wrong
  //    server process" are different failures and keep different denials.
  //
  //    A pure Dart value cannot prove runtime trust, so this establishes the
  //    *claimed* authority; the backend is responsible for the claim being true
  //    (DPA2, DPA17).
  if (!executableProofAssessorKinds.contains(assessor.kind)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessorNotSystemWorker,
    );
  }
  // The authorized verifier id is resolved from trusted state, so a malformed
  // one means the policy/routing lookup produced something unusable. Fail
  // closed rather than falling back to the kind check alone.
  if (!isValidOpaqueId(context.authorizedAssessorPrincipalId)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessorPrincipalIdInvalid,
    );
  }
  // Being *a* trusted worker is not being *the* proof verifier. Without this,
  // the outbox drain, reservation expiry or reconciliation worker could mint
  // the verdict that later gates delivery.
  if (!context.authorizes(assessor)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessorAuthorityMismatch,
    );
  }
  if (!request.assessedAtUtc.isUtc) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessedAtNotUtc,
    );
  }

  // 6. The delivery being assessed must actually be in flight.
  if (order.state != OrderState.inDelivery) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.orderNotInDelivery,
    );
  }
  if (order.reservationState != ReservationState.committed) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.reservationNotCommitted,
    );
  }
  if (custody.holder.kind != CustodyHolderKind.rider) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.custodyNotWithRider,
    );
  }

  // 7. The rider binding must name the exact current attempt, in the accepted
  //    assignment *and* in custody. Identity before generation, matching the
  //    assignment and custody evaluators.
  final RiderAssignmentAttempt? attempt = riderAssignment.attempt;
  if (attempt == null || attempt.state != AssignmentState.accepted) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.noAcceptedRiderAssignment,
    );
  }
  if (attempt.acceptedAssigneePrincipalId != request.riderPrincipalId) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.notCurrentAcceptedRider,
    );
  }
  if (attempt.assignmentId != request.riderAssignmentId) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assignmentIdMismatch,
    );
  }
  if (attempt.generation != request.riderAssignmentGeneration) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.generationMismatch,
    );
  }
  // Custody must be held by that very attempt. Goods carried under attempt A
  // must not be assessed as though attempt B were carrying them.
  if (!custody.holder.isHeldBy(
    principalId: request.riderPrincipalId,
    assignmentId: request.riderAssignmentId,
    generation: request.riderAssignmentGeneration,
  )) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.custodyHolderBindingMismatch,
    );
  }

  // 8. Assessment identity. A reassessment is a new fact and needs a new id.
  if (!isValidOpaqueId(request.assessmentId)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessmentIdInvalid,
    );
  }
  final DeliveryProofAssessmentRecord? previous = assessment.current;
  if (previous != null && previous.assessmentId == request.assessmentId) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessmentIdReuse,
    );
  }

  return DeliveryProofAssessmentOutcome.allow(
    DeliveryProofAssessmentTransition(
      record: DeliveryProofAssessmentRecord(
        assessmentId: request.assessmentId,
        resourceId: context.resourceId,
        // 0 -> 1 for a first assessment; r -> r + 1 for every reassessment.
        assessmentRevision: assessment.assessmentRevision + 1,
        // Resolved server-side, never chosen by the verifier.
        policyRef: context.policyRef,
        evidenceRef: context.evidenceRef,
        riderPrincipalId: request.riderPrincipalId,
        riderAssignmentId: request.riderAssignmentId,
        riderAssignmentGeneration: request.riderAssignmentGeneration,
        // Derived from the verified principal that just matched the resource's
        // authorized verifier — never from request content.
        assessedByPrincipalId: assessor.id,
        assessedByKind: assessor.kind,
        assessedAtUtc: request.assessedAtUtc,
        verdict: request.verdict,
        // A backward pointer into immutable history. The previous record is
        // not touched, not relabelled and not erased.
        supersedesAssessmentId: previous?.assessmentId,
      ),
    ),
  );
}
