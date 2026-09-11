/// Delivery-attempt and return evaluators for the bounded **non-success** path.
///
/// Pure: no I/O, no clock, no storage, no randomness. Wall-clock time and
/// client arrival order are not concurrency control — server transaction and
/// revision ordering decide races.
///
/// ## One evaluator per operation, and why
///
/// These are separate functions rather than one `evaluateAttemptReturn` with a
/// command argument, because **a shared read-set silently becomes a shared
/// precondition**. FND-003D2B shipped exactly that mistake: a review operation
/// took the assessment and order aggregates it never read, and a torn read of
/// either could freeze a valid dispute out of review. FND-003D2B-FIX-001 split
/// them, and this slice starts split.
///
/// The split is enforced by the type system, not by comment. Recording a
/// **failure** has no return parameter at all, so it cannot open a return even
/// if someone later added the code — the facts are simply not in scope.
///
/// ## What every executable operation requires
///
/// ```text
/// canonical resource context is well formed
/// an unforgeable AuthorizationGrant, checked against actor + permission + resource
/// the acting principal is a human principal
/// the recorded timestamp is UTC
/// every aggregate in the read-set validates
/// every aggregate in the read-set names the SAME canonical resource
/// compare-and-set on every aggregate the operation reads or writes
/// ```
library;

import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/custody_lifecycle.dart';
import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/delivery_attempt_command.dart';
import 'package:cp_contracts/src/delivery_attempt_return_authorization.dart';
import 'package:cp_contracts/src/delivery_attempt_return_denial.dart';
import 'package:cp_contracts/src/delivery_attempt_return_effect.dart';
import 'package:cp_contracts/src/delivery_attempt_return_facts.dart';
import 'package:cp_contracts/src/delivery_attempt_return_request.dart';
import 'package:cp_contracts/src/delivery_attempt_return_transition.dart';
import 'package:cp_contracts/src/delivery_attempt_return_validation.dart';
import 'package:cp_contracts/src/delivery_attempt_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/return_command.dart';
import 'package:cp_contracts/src/return_state.dart';
import 'package:cp_contracts/src/rider_assignment.dart';

// ---------------------------------------------------------------------------
// shared guards
// ---------------------------------------------------------------------------

/// Actor and timestamp, checked identically for every operation.
///
/// A `systemWorker` is refused: every operation here records a **human**
/// physical assertion — a rider set out, a customer refused, a shop received,
/// an inspector looked. A background process cannot witness any of those, and
/// letting one through would create unattributable custody and stock history.
AttemptReturnDenial? _checkActorAndTime(
  Principal actor,
  DateTime recordedAtUtc,
) {
  if (!actor.isUser || !isValidOpaqueId(actor.id)) {
    return AttemptReturnDenial.actorNotHumanPrincipal;
  }
  if (!recordedAtUtc.isUtc) {
    return AttemptReturnDenial.timestampNotUtc;
  }
  return null;
}

/// The order read, validated and bound to the canonical resource.
AttemptReturnDenial? _checkOrderRead(
  AttemptReturnOrderRead orderRead,
  String resourceId, {
  required int expectedOrderRevision,
  required bool requireCommittedReservation,
}) {
  if (!orderRead.belongsToResource(resourceId)) {
    return AttemptReturnDenial.resourceBindingMismatch;
  }
  if (validateAggregate(orderRead.order) != null) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  final OrderLifecycleFacts order = orderRead.order;
  if (order.state != OrderState.inDelivery) {
    return AttemptReturnDenial.orderNotInDelivery;
  }
  if (expectedOrderRevision != order.revision) {
    return AttemptReturnDenial.orderRevisionConflict;
  }
  if (requireCommittedReservation &&
      order.reservationState != ReservationState.committed) {
    return AttemptReturnDenial.reservationNotCommitted;
  }
  return null;
}

/// Custody held by exactly the currently accepted rider attempt.
///
/// Three separate facts have to agree — the custody holder is a rider, that
/// rider attempt is the accepted one, and the acting principal is that rider.
/// Checking fewer would let goods carried under attempt A be acted on as though
/// attempt B were carrying them, which is the reassignment hazard FND-003B3A
/// closed for handover and this closes again for return.
AttemptReturnDenial? _checkRiderCustodyBinding({
  required CustodyFacts custody,
  required RiderAssignmentFacts riderAssignment,
  required String actingPrincipalId,
  required String assignmentId,
  required int generation,
  required int expectedRiderSlotRevision,
}) {
  if (!custody.isWithRider) {
    return AttemptReturnDenial.custodyNotWithRider;
  }
  if (expectedRiderSlotRevision != riderAssignment.slotRevision) {
    return AttemptReturnDenial.riderSlotRevisionConflict;
  }
  final RiderAssignmentAttempt? attempt = riderAssignment.attempt;
  if (attempt == null || attempt.state != AssignmentState.accepted) {
    return AttemptReturnDenial.noAcceptedRiderAssignment;
  }
  if (attempt.acceptedAssigneePrincipalId != actingPrincipalId) {
    return AttemptReturnDenial.notCurrentAcceptedRider;
  }
  // Identity before generation, matching every other evaluator here.
  if (attempt.assignmentId != assignmentId) {
    return AttemptReturnDenial.assignmentIdMismatch;
  }
  if (attempt.generation != generation) {
    return AttemptReturnDenial.generationMismatch;
  }
  // Custody must name that exact attempt, not merely a rider with the same id.
  if (!custody.holder.isHeldBy(
    principalId: actingPrincipalId,
    assignmentId: attempt.assignmentId,
    generation: attempt.generation,
  )) {
    return AttemptReturnDenial.custodyHolderBindingMismatch;
  }
  return null;
}

/// Custody and the rider slot, validated and bound to the canonical resource.
AttemptReturnDenial? _checkCustodyRead(
  CustodyFacts? custody,
  RiderAssignmentFacts? riderAssignment,
  String resourceId, {
  required int expectedCustodyRevision,
}) {
  if (custody == null) {
    return AttemptReturnDenial.custodyNotInitialised;
  }
  if (validateCustodyAggregate(custody) != null) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  if (custody.resourceId != resourceId) {
    return AttemptReturnDenial.resourceBindingMismatch;
  }
  if (expectedCustodyRevision != custody.custodyRevision) {
    return AttemptReturnDenial.custodyRevisionConflict;
  }
  if (riderAssignment != null) {
    if (validateRiderAssignmentAggregate(riderAssignment) != null) {
      return AttemptReturnDenial.aggregateInconsistent;
    }
    if (riderAssignment.resourceId != resourceId) {
      return AttemptReturnDenial.resourceBindingMismatch;
    }
  }
  return null;
}

/// The attempt aggregate, validated, bound and pinned.
AttemptReturnDenial? _checkAttemptRead(
  DeliveryAttemptFacts? attempt,
  String resourceId, {
  required int expectedAttemptRevision,
}) {
  if (attempt == null) {
    return AttemptReturnDenial.attemptNotInitialised;
  }
  final AttemptReturnDenial? corruption = validateDeliveryAttemptAggregate(
    attempt,
  );
  if (corruption != null) {
    return corruption;
  }
  if (attempt.resourceId != resourceId) {
    return AttemptReturnDenial.resourceBindingMismatch;
  }
  if (expectedAttemptRevision != attempt.attemptRevision) {
    return AttemptReturnDenial.attemptRevisionConflict;
  }
  return null;
}

/// The return aggregate, validated, bound and pinned.
AttemptReturnDenial? _checkReturnRead(
  ReturnFacts? returnRecord,
  String resourceId, {
  required int expectedReturnRevision,
}) {
  if (returnRecord == null) {
    return AttemptReturnDenial.returnNotInitialised;
  }
  final AttemptReturnDenial? corruption = validateReturnAggregate(returnRecord);
  if (corruption != null) {
    return corruption;
  }
  if (returnRecord.resourceId != resourceId) {
    return AttemptReturnDenial.resourceBindingMismatch;
  }
  if (expectedReturnRevision != returnRecord.returnRevision) {
    return AttemptReturnDenial.returnRevisionConflict;
  }
  // Only the direct route is implemented. A stored aggregate naming another
  // route must not be executed as though it were the direct one.
  if (!ReturnRoute.executableInThisSlice.contains(returnRecord.route)) {
    return AttemptReturnDenial.returnRouteNotImplemented;
  }
  return null;
}

// ---------------------------------------------------------------------------
// initialisation
// ---------------------------------------------------------------------------

/// Decide whether the attempt and return aggregates may be created for a
/// freshly dispatched order.
///
/// **Create-once, server-side, and deliberately not a command.** There is no
/// `DeliveryAttemptCommand` and no permission for initialisation, for the same
/// reason `initialiseCustodyAtShop` has none: a pending attempt is not
/// something a caller asserts, it is what is true once a rider is carrying the
/// goods. A client command whose only purpose is to manufacture trusted server
/// state is exactly the arbitrary status patch this contract forbids.
///
/// Both aggregates are created together — the attempt in `pending`, the return
/// in `not_required` — so that "no return is needed" is a **written fact** from
/// the first moment rather than a missing record another reader has to
/// interpret.
///
/// > **Backend obligation, NOT RUN.** The backend must create these with a
/// > create-if-absent storage precondition, **atomically with or causally bound
/// > to** the accepted dispatch boundary (rider custody receipt). That is
/// > criterion **ATT1** and it is **NOT RUN**: a Dart fixture cannot prove a
/// > storage transaction, and this function returning `allow` proves only that
/// > the facts handed in permit creation.
DeliveryAttemptInitialisationOutcome initialiseDeliveryAttempt({
  required CustodyResourceContext resource,
  required String attemptId,
  required DeliveryAttemptFacts? existingAttempt,
  required ReturnFacts? existingReturn,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
}) {
  if (!resource.isWellFormed) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  // The attempt id anchors every future event and audit row for this attempt.
  if (!isValidOpaqueId(attemptId)) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.aggregateInconsistent,
    );
  }
  // Create-once. Never resets an existing attempt, and never re-opens a
  // terminal one: a second `pending` attempt written over a `refused` one would
  // erase the refusal that opened a return.
  if (existingAttempt != null) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.attemptAlreadyInitialised,
    );
  }
  if (existingReturn != null) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.attemptAlreadyInitialised,
    );
  }

  // Dispatch must actually have happened. This is the causal binding: an
  // attempt cannot exist for an order no rider is carrying.
  if (!orderRead.belongsToResource(resource.resourceId)) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  if (validateAggregate(orderRead.order) != null) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.aggregateInconsistent,
    );
  }
  if (orderRead.order.state != OrderState.inDelivery) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.orderNotInDelivery,
    );
  }
  if (orderRead.order.reservationState != ReservationState.committed) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.reservationNotCommitted,
    );
  }
  if (custody == null) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.custodyNotInitialised,
    );
  }
  if (validateCustodyAggregate(custody) != null) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.aggregateInconsistent,
    );
  }
  if (custody.resourceId != resource.resourceId) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  if (!custody.isWithRider) {
    return const DeliveryAttemptInitialisationOutcome.deny(
      AttemptReturnDenial.custodyNotWithRider,
    );
  }

  return DeliveryAttemptInitialisationOutcome.allow(
    attempt: DeliveryAttemptFacts.initial(
      resourceId: resource.resourceId,
      attemptId: attemptId,
    ),
    returnRecord: ReturnFacts.initial(resourceId: resource.resourceId),
  );
}

// ---------------------------------------------------------------------------
// attempt operations
// ---------------------------------------------------------------------------

/// `pending -> out_for_delivery`.
///
/// **Read-set: attempt, order, custody, rider assignment.** The return is
/// deliberately absent — setting out decides nothing about a return, so these
/// facts cannot make it a precondition or a consequence.
DeliveryAttemptOutcome evaluateRecordOutForDelivery({
  required DeliveryAttemptRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required DeliveryAttemptFacts? attempt,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) => _evaluateAttemptEdge(
  command: DeliveryAttemptCommand.recordOutForDelivery,
  from: DeliveryAttemptState.pending,
  to: DeliveryAttemptState.outForDelivery,
  event: DeliveryAttemptEventType.outForDelivery,
  financial: FinancialClassification.noneInThisSlice,
  request: request,
  grant: grant,
  actor: actor,
  resource: resource,
  attempt: attempt,
  orderRead: orderRead,
  custody: custody,
  riderAssignment: riderAssignment,
);

/// `out_for_delivery -> failed`.
///
/// **Read-set: attempt, order, custody, rider assignment — no return facts at
/// all.** That absence is the contract: a failed attempt must not create a
/// return, and here it structurally cannot.
///
/// The blueprint says a failed attempt *may* require a return. Nothing accepted
/// says when, who decides, how many retries are allowed, or who bears the cost,
/// so this records the fact and stops. See
/// [evaluateFailedAttemptReturnDecision].
///
/// The financial classification is `deferredToFinancialSlice` — **unknown,
/// never zero**.
DeliveryAttemptOutcome evaluateRecordDeliveryFailure({
  required DeliveryAttemptRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required DeliveryAttemptFacts? attempt,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) => _evaluateAttemptEdge(
  command: DeliveryAttemptCommand.recordFailure,
  from: DeliveryAttemptState.outForDelivery,
  to: DeliveryAttemptState.failed,
  event: DeliveryAttemptEventType.failed,
  financial: FinancialClassification.deferredToFinancialSlice,
  request: request,
  grant: grant,
  actor: actor,
  resource: resource,
  attempt: attempt,
  orderRead: orderRead,
  custody: custody,
  riderAssignment: riderAssignment,
);

/// `out_for_delivery -> refused`, **atomically opening a required return**.
///
/// The two halves are one transition on purpose. A refusal without a return
/// requirement leaves goods in a rider's bag with nothing saying they must come
/// back; a return requirement without a refusal is a return nobody asked for.
///
/// What it does **not** do, and cannot express:
///
/// - the order is untouched — not delivered, not cancelled;
/// - custody stays exactly where it is, with the rider;
/// - the rider assignment is untouched and is **not** completed;
/// - the reservation stays `committed`;
/// - the inventory effect is `none` — **refusal restores no stock**;
/// - the financial classification is `deferredToFinancialSlice` — a refusal fee,
///   a refund, a liability or a redelivery charge are all **undecided**, and
///   reading this as "free" is the misreading the type exists to prevent.
DeliveryAttemptOutcome evaluateRecordDeliveryRefusal({
  required DeliveryAttemptRefusalRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required DeliveryAttemptFacts? attempt,
  required ReturnFacts? returnRecord,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) {
  final DeliveryAttemptOutcome base = _evaluateAttemptEdge(
    command: DeliveryAttemptCommand.recordRefusal,
    from: DeliveryAttemptState.outForDelivery,
    to: DeliveryAttemptState.refused,
    event: DeliveryAttemptEventType.refused,
    financial: FinancialClassification.deferredToFinancialSlice,
    request: request.attempt,
    grant: grant,
    actor: actor,
    resource: resource,
    attempt: attempt,
    orderRead: orderRead,
    custody: custody,
    riderAssignment: riderAssignment,
  );
  if (!base.allowed) {
    return base;
  }

  // The return half. Checked only after the attempt half passed, so a refused
  // attempt is never recorded without its return requirement.
  final AttemptReturnDenial? returnDenial = _checkReturnRead(
    returnRecord,
    resource.resourceId,
    expectedReturnRevision: request.expectedReturnRevision,
  );
  if (returnDenial != null) {
    return DeliveryAttemptOutcome.deny(returnDenial);
  }
  final ReturnFacts current = returnRecord!;
  // A return may be opened only from `not_required`. A replayed refusal finds
  // `required` and is refused, so it cannot advance the return revision twice.
  if (current.state != ReturnState.notRequired) {
    return const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.returnNotInRequiredState,
    );
  }

  final DeliveryAttemptTransition t = base.transition!;
  return DeliveryAttemptOutcome.allow(
    DeliveryAttemptTransition(
      command: t.command,
      attemptId: t.attemptId,
      fromState: t.fromState,
      toState: t.toState,
      resultingAttemptRevision: t.resultingAttemptRevision,
      recordedAtUtc: t.recordedAtUtc,
      returnRequirement: ReturnRequirementEffect(
        fromState: current.state,
        resultingReturnRevision: current.returnRevision + 1,
        route: current.route,
      ),
      financialClassification: t.financialClassification,
      events: const <String>[
        DeliveryAttemptEventType.refused,
        ReturnEventType.required,
      ],
    ),
  );
}

/// **ENUMERATED AND NEVER EXECUTABLE.** Always refuses with
/// [AttemptReturnDenial.deliveryProofPolicyDeferred].
///
/// Takes **no arguments at all**, for the same reason
/// `evaluateResolveDeliveryProofDispute` takes none: there is no read-set,
/// because there is no decision to make. A signature accepting facts would
/// invite a later reader to add "just the obvious edge" using them, and would
/// suggest the inputs matter. They do not — the missing piece is the
/// proof-satisfaction policy, not data.
///
/// It cannot produce a delivery, custody, assignment, inventory or financial
/// effect because it produces no transition at all.
DeliveryAttemptOutcome evaluateRecordDelivered() =>
    const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.deliveryProofPolicyDeferred,
    );

/// **ENUMERATED AND NEVER EXECUTABLE.** Always refuses with
/// [AttemptReturnDenial.failureReturnPolicyDeferred].
///
/// The place a future slice will decide what follows a failed attempt — retry,
/// return, cancellation, or nothing — once a delivery retry/failure policy
/// exists. Today nothing accepted decides it, so this refuses rather than
/// letting a default emerge from silence.
DeliveryAttemptOutcome evaluateFailedAttemptReturnDecision() =>
    const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.failureReturnPolicyDeferred,
    );

DeliveryAttemptOutcome _evaluateAttemptEdge({
  required DeliveryAttemptCommand command,
  required DeliveryAttemptState from,
  required DeliveryAttemptState to,
  required String event,
  required FinancialClassification financial,
  required DeliveryAttemptRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required DeliveryAttemptFacts? attempt,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) {
  if (!resource.isWellFormed) {
    return const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  final AttemptReturnDenial? unauthorized = checkAttemptReturnAuthorization(
    grant: grant,
    actor: actor,
    requiredPermission: command.requiredPermission,
    expectedResourceId: resource.resourceId,
  );
  if (unauthorized != null) {
    return DeliveryAttemptOutcome.deny(unauthorized);
  }
  final AttemptReturnDenial? actorOrTime = _checkActorAndTime(
    actor,
    request.recordedAtUtc,
  );
  if (actorOrTime != null) {
    return DeliveryAttemptOutcome.deny(actorOrTime);
  }

  final AttemptReturnDenial? attemptDenial = _checkAttemptRead(
    attempt,
    resource.resourceId,
    expectedAttemptRevision: request.expectedAttemptRevision,
  );
  if (attemptDenial != null) {
    return DeliveryAttemptOutcome.deny(attemptDenial);
  }
  final AttemptReturnDenial? orderDenial = _checkOrderRead(
    orderRead,
    resource.resourceId,
    expectedOrderRevision: request.expectedOrderRevision,
    requireCommittedReservation: true,
  );
  if (orderDenial != null) {
    return DeliveryAttemptOutcome.deny(orderDenial);
  }
  final AttemptReturnDenial? custodyDenial = _checkCustodyRead(
    custody,
    riderAssignment,
    resource.resourceId,
    expectedCustodyRevision: request.expectedCustodyRevision,
  );
  if (custodyDenial != null) {
    return DeliveryAttemptOutcome.deny(custodyDenial);
  }
  if (riderAssignment == null) {
    return const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.noAcceptedRiderAssignment,
    );
  }
  final AttemptReturnDenial? binding = _checkRiderCustodyBinding(
    custody: custody!,
    riderAssignment: riderAssignment,
    actingPrincipalId: actor.id,
    assignmentId: request.assignmentId,
    generation: request.generation,
    expectedRiderSlotRevision: request.expectedRiderSlotRevision,
  );
  if (binding != null) {
    return DeliveryAttemptOutcome.deny(binding);
  }

  // Source state last, so a stale or replayed command reports the honest
  // reason rather than a state error caused by an earlier applied write.
  if (attempt!.state != from) {
    return const DeliveryAttemptOutcome.deny(
      AttemptReturnDenial.attemptNotInRequiredState,
    );
  }

  return DeliveryAttemptOutcome.allow(
    DeliveryAttemptTransition(
      command: command,
      attemptId: attempt.attemptId,
      fromState: from,
      toState: to,
      resultingAttemptRevision: attempt.attemptRevision + 1,
      recordedAtUtc: request.recordedAtUtc,
      financialClassification: financial,
      events: <String>[event],
    ),
  );
}

// ---------------------------------------------------------------------------
// return operations — direct rider -> shop route
// ---------------------------------------------------------------------------

/// `required -> in_transit`.
///
/// **Read-set: attempt, return, order, custody.** No rider assignment: nothing
/// changes hands, so the accepted-attempt binding that a receipt needs is not a
/// precondition here.
///
/// Custody does **not** move — the rider already holds the goods — and no
/// inventory or financial effect is produced.
ReturnOutcome evaluateBeginReturnTransit({
  required ReturnBeginTransitRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required DeliveryAttemptFacts? attempt,
  required ReturnFacts? returnRecord,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
}) {
  final AttemptReturnDenial? preface = _returnPreface(
    grant: grant,
    actor: actor,
    command: ReturnCommand.beginTransit,
    resource: resource,
    recordedAtUtc: request.recordedAtUtc,
    returnRecord: returnRecord,
    expectedReturnRevision: request.expectedReturnRevision,
  );
  if (preface != null) {
    return ReturnOutcome.deny(preface);
  }
  final AttemptReturnDenial? orderDenial = _checkOrderRead(
    orderRead,
    resource.resourceId,
    expectedOrderRevision: request.expectedOrderRevision,
    requireCommittedReservation: true,
  );
  if (orderDenial != null) {
    return ReturnOutcome.deny(orderDenial);
  }
  // The goods must still be in the rider's hands for a rider-to-shop leg to
  // begin. Custody revision is not pinned: this operation does not write it.
  if (custody == null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.custodyNotInitialised);
  }
  if (validateCustodyAggregate(custody) != null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.aggregateInconsistent);
  }
  if (custody.resourceId != resource.resourceId) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  if (!custody.isWithRider) {
    return const ReturnOutcome.deny(AttemptReturnDenial.custodyNotWithRider);
  }
  // Only a canonical refusal opens this route. Reading the attempt here is what
  // stops a return being walked forward for an order nobody refused.
  if (attempt == null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.attemptNotInitialised);
  }
  if (validateDeliveryAttemptAggregate(attempt) != null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.aggregateInconsistent);
  }
  if (attempt.resourceId != resource.resourceId) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  if (!attempt.isRefused) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.attemptNotInRequiredState,
    );
  }

  final ReturnFacts current = returnRecord!;
  if (current.state != ReturnState.required) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.returnNotInRequiredState,
    );
  }

  return ReturnOutcome.allow(
    ReturnTransition(
      command: ReturnCommand.beginTransit,
      fromState: current.state,
      toState: ReturnState.inTransit,
      resultingReturnRevision: current.returnRevision + 1,
      recordedAtUtc: request.recordedAtUtc,
      events: const <String>[ReturnEventType.inTransit],
    ),
  );
}

/// `in_transit -> received`, moving custody `rider -> shop` **exactly once**.
///
/// **Read-set: return, order, custody, rider assignment.** The rider assignment
/// is required here and nowhere else in the return path: the goods are changing
/// hands, so custody must be proven to be held by the exact accepted rider
/// attempt before it is taken away from them.
///
/// A shop receipt is an **authorized business assertion**, not cryptographic
/// handoff proof. No OTP, QR code, signature, photo, GPS fix or biometric is
/// involved, and inventing one would be inventing a proof mechanism this
/// repository has deliberately refused to choose.
///
/// Restores **no stock**. That is the whole reason receipt and inspection are
/// separate states.
ReturnOutcome evaluateRecordReturnShopReceipt({
  required ReturnShopReceiptRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required ReturnFacts? returnRecord,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) {
  final AttemptReturnDenial? preface = _returnPreface(
    grant: grant,
    actor: actor,
    command: ReturnCommand.recordShopReceipt,
    resource: resource,
    recordedAtUtc: request.recordedAtUtc,
    returnRecord: returnRecord,
    expectedReturnRevision: request.expectedReturnRevision,
  );
  if (preface != null) {
    return ReturnOutcome.deny(preface);
  }
  final AttemptReturnDenial? orderDenial = _checkOrderRead(
    orderRead,
    resource.resourceId,
    expectedOrderRevision: request.expectedOrderRevision,
    requireCommittedReservation: true,
  );
  if (orderDenial != null) {
    return ReturnOutcome.deny(orderDenial);
  }
  final AttemptReturnDenial? custodyDenial = _checkCustodyRead(
    custody,
    riderAssignment,
    resource.resourceId,
    expectedCustodyRevision: request.expectedCustodyRevision,
  );
  if (custodyDenial != null) {
    return ReturnOutcome.deny(custodyDenial);
  }
  if (riderAssignment == null) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.noAcceptedRiderAssignment,
    );
  }
  final RiderAssignmentAttempt? riderAttempt = riderAssignment.attempt;
  if (riderAttempt == null ||
      riderAttempt.state != AssignmentState.accepted ||
      riderAttempt.acceptedAssigneePrincipalId == null) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.noAcceptedRiderAssignment,
    );
  }
  // The **shop** records this, so the acting principal is an agent, not the
  // rider. The custody binding is therefore checked against the accepted rider
  // attempt itself rather than against the actor.
  final AttemptReturnDenial? binding = _checkRiderCustodyBinding(
    custody: custody!,
    riderAssignment: riderAssignment,
    actingPrincipalId: riderAttempt.acceptedAssigneePrincipalId!,
    assignmentId: riderAttempt.assignmentId,
    generation: riderAttempt.generation,
    expectedRiderSlotRevision: request.expectedRiderSlotRevision,
  );
  if (binding != null) {
    return ReturnOutcome.deny(binding);
  }

  final ReturnFacts current = returnRecord!;
  if (current.state != ReturnState.inTransit) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.returnNotInRequiredState,
    );
  }

  return ReturnOutcome.allow(
    ReturnTransition(
      command: ReturnCommand.recordShopReceipt,
      fromState: current.state,
      toState: ReturnState.received,
      resultingReturnRevision: current.returnRevision + 1,
      recordedAtUtc: request.recordedAtUtc,
      custodyEffect: ReturnCustodyEffect(
        fromHolder: custody.holder,
        toHolder: CustodyHolder.atShop(shopId: resource.shopId),
        resultingCustodyRevision: custody.custodyRevision + 1,
      ),
      events: const <String>[ReturnEventType.receivedAtShop],
    ),
  );
}

/// `received -> inspected`.
///
/// **The only transition in this contract that can increase available stock**,
/// and it can do so only because both halves of the invariant are now true: the
/// shop holds the goods (`received`, which moved custody) and someone has
/// looked at them (this operation, which records a disposition).
///
/// Both halves are checked independently rather than inferred from the state
/// name: the return must be `received` **and** custody must actually be at the
/// canonical shop.
///
/// - `restockable` → `InventoryEffect.restore(units)`, delta `+units`;
/// - `damaged` / `quarantined` → `InventoryEffect.none()`, delta `0`.
///
/// In **all three** cases the committed reservation ends, as
/// [ReservationState.returned] rather than `released` — see
/// [ReservationReturnEffect]. Because the reservation must be `committed` to
/// get here, a replayed inspection finds it already `returned` and is refused,
/// which is what makes a double restore impossible rather than merely unlikely.
ReturnOutcome evaluateRecordReturnInspection({
  required ReturnInspectionRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required ReturnFacts? returnRecord,
  required AttemptReturnOrderRead orderRead,
  required CustodyFacts? custody,
}) {
  final AttemptReturnDenial? preface = _returnPreface(
    grant: grant,
    actor: actor,
    command: ReturnCommand.recordInspection,
    resource: resource,
    recordedAtUtc: request.recordedAtUtc,
    returnRecord: returnRecord,
    expectedReturnRevision: request.expectedReturnRevision,
  );
  if (preface != null) {
    return ReturnOutcome.deny(preface);
  }
  final AttemptReturnDenial? orderDenial = _checkOrderRead(
    orderRead,
    resource.resourceId,
    expectedOrderRevision: request.expectedOrderRevision,
    requireCommittedReservation: true,
  );
  if (orderDenial != null) {
    return ReturnOutcome.deny(orderDenial);
  }
  // Custody must be at the shop, and at **this order's** shop. A `received`
  // return whose custody is still with a rider is a torn read, and restoring
  // stock from it would credit a shelf nobody put anything on.
  if (custody == null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.custodyNotInitialised);
  }
  if (validateCustodyAggregate(custody) != null) {
    return const ReturnOutcome.deny(AttemptReturnDenial.aggregateInconsistent);
  }
  if (custody.resourceId != resource.resourceId) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.resourceBindingMismatch,
    );
  }
  if (!custody.isAtShop) {
    return const ReturnOutcome.deny(AttemptReturnDenial.custodyNotAtShop);
  }
  if (custody.holder.shopId != resource.shopId) {
    return const ReturnOutcome.deny(AttemptReturnDenial.shopBindingMismatch);
  }

  final ReturnFacts current = returnRecord!;
  if (current.state != ReturnState.received) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.returnNotInRequiredState,
    );
  }

  final int units = orderRead.order.reservedUnits;
  final ReturnDisposition disposition = request.disposition;
  final bool restores = disposition.restoresAvailableStock;

  return ReturnOutcome.allow(
    ReturnTransition(
      command: ReturnCommand.recordInspection,
      fromState: current.state,
      toState: ReturnState.inspected,
      resultingReturnRevision: current.returnRevision + 1,
      recordedAtUtc: request.recordedAtUtc,
      reservationEffect: ReservationReturnEffect(
        fromState: ReservationState.committed,
        disposition: disposition,
        units: units,
      ),
      inventoryEffect: restores
          ? InventoryEffect.restore(units)
          : const InventoryEffect.none(),
      events: restores
          ? const <String>[
              ReturnEventType.inspected,
              ReturnEventType.stockRestored,
            ]
          : const <String>[ReturnEventType.inspected],
    ),
  );
}

/// `inspected -> closed`. Audit only.
///
/// **Read-set: return and order.** Custody is not read: closing moves nothing.
///
/// Restores no stock — the reservation is already terminal by the time this can
/// run, which is asserted rather than assumed — and infers no money, liability
/// or settlement.
ReturnOutcome evaluateCloseReturn({
  required ReturnCloseRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required ReturnFacts? returnRecord,
  required AttemptReturnOrderRead orderRead,
}) {
  final AttemptReturnDenial? preface = _returnPreface(
    grant: grant,
    actor: actor,
    command: ReturnCommand.closeReturn,
    resource: resource,
    recordedAtUtc: request.recordedAtUtc,
    returnRecord: returnRecord,
    expectedReturnRevision: request.expectedReturnRevision,
  );
  if (preface != null) {
    return ReturnOutcome.deny(preface);
  }
  // Note `requireCommittedReservation: false` — by now the inspection has
  // ended the reservation, so requiring `committed` would make closing
  // impossible.
  final AttemptReturnDenial? orderDenial = _checkOrderRead(
    orderRead,
    resource.resourceId,
    expectedOrderRevision: request.expectedOrderRevision,
    requireCommittedReservation: false,
  );
  if (orderDenial != null) {
    return ReturnOutcome.deny(orderDenial);
  }
  // The reservation must already be terminal-by-return. This is the second
  // guard against a double restore: closing can never be the transition that
  // ends a live reservation, so it can never carry an inventory effect.
  if (orderRead.order.reservationState != ReservationState.returned) {
    return const ReturnOutcome.deny(AttemptReturnDenial.reservationNotReturned);
  }

  final ReturnFacts current = returnRecord!;
  if (current.state != ReturnState.inspected) {
    return const ReturnOutcome.deny(
      AttemptReturnDenial.returnNotInRequiredState,
    );
  }

  return ReturnOutcome.allow(
    ReturnTransition(
      command: ReturnCommand.closeReturn,
      fromState: current.state,
      toState: ReturnState.closed,
      resultingReturnRevision: current.returnRevision + 1,
      recordedAtUtc: request.recordedAtUtc,
      events: const <String>[ReturnEventType.closed],
    ),
  );
}

/// **ENUMERATED AND NEVER EXECUTABLE.** Always refuses with
/// [AttemptReturnDenial.returnRouteNotImplemented].
///
/// The `rider -> picker -> shop` route the blueprint allows. It is refused for
/// an **authority** reason, not a state-machine one: the accepted picker
/// assignment is `completed` at dispatch and its `assignedResource` scope
/// removed, so at the moment a return begins no picker holds any authority over
/// the order, and no accepted permission would give one back.
///
/// Implementing it means deciding post-dispatch picker return authority — a new
/// assignment concept, a permission, and a scope projection that re-grants a
/// completed worker access. That is a durable architecture decision with its
/// own contract and tests. See ADR-0010.
ReturnOutcome evaluateReturnViaPicker() =>
    const ReturnOutcome.deny(AttemptReturnDenial.returnRouteNotImplemented);

/// Checks every return operation performs identically, in one place.
AttemptReturnDenial? _returnPreface({
  required AuthorizationGrant grant,
  required Principal actor,
  required ReturnCommand command,
  required CustodyResourceContext resource,
  required DateTime recordedAtUtc,
  required ReturnFacts? returnRecord,
  required int expectedReturnRevision,
}) {
  if (!resource.isWellFormed) {
    return AttemptReturnDenial.resourceBindingMismatch;
  }
  final AttemptReturnDenial? unauthorized = checkAttemptReturnAuthorization(
    grant: grant,
    actor: actor,
    requiredPermission: command.requiredPermission,
    expectedResourceId: resource.resourceId,
  );
  if (unauthorized != null) {
    return unauthorized;
  }
  final AttemptReturnDenial? actorOrTime = _checkActorAndTime(
    actor,
    recordedAtUtc,
  );
  if (actorOrTime != null) {
    return actorOrTime;
  }
  return _checkReturnRead(
    returnRecord,
    resource.resourceId,
    expectedReturnRevision: expectedReturnRevision,
  );
}
