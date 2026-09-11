/// The normal-path COD collection evaluator.
///
/// Pure: no I/O, no clock, no storage, no randomness. Wall-clock time and
/// client arrival order are not concurrency control — server transaction and
/// revision ordering decide races.
///
/// ## What a successful collection does, and all it does
///
/// ```text
/// payment   due | partially_collected  ->  partially_collected | collected
/// journal   ONE balanced entry for exactly the amount received
/// order              unchanged        custody        unchanged
/// reservation        unchanged        rider slot     unchanged
/// delivery attempt   unchanged        inventory      unchanged
/// ```
///
/// **Collecting cash is not delivering.** No proof assessment is read or
/// written, `OrderState.delivered` is untouched, the rider is not completed,
/// and nothing here is remittance or settlement.
library;

import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/cash_journal_entry.dart';
import 'package:cp_contracts/src/cod_collection_authorization.dart';
import 'package:cp_contracts/src/cod_collection_command.dart';
import 'package:cp_contracts/src/cod_collection_denial.dart';
import 'package:cp_contracts/src/cod_collection_request.dart';
import 'package:cp_contracts/src/cod_collection_transition.dart';
import 'package:cp_contracts/src/custody_lifecycle.dart';
import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/delivery_attempt_return_facts.dart';
import 'package:cp_contracts/src/delivery_attempt_return_validation.dart';
import 'package:cp_contracts/src/delivery_attempt_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/money_policy.dart';
import 'package:cp_contracts/src/order_financial_snapshot.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/payment_facts.dart';
import 'package:cp_contracts/src/payment_state.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/rider_assignment.dart';
import 'package:cp_core/cp_core.dart';

/// Evaluate one rider-reported COD collection.
///
/// Every aggregate is supplied as trusted current facts read in **one
/// consistent transaction**. Passing them proves nothing about trust; they are
/// the shapes a backend fills from canonical storage, and every one is bound to
/// the same canonical resource before any money is computed.
CodCollectionOutcome evaluateReportCodCollection({
  required CodCollectionRequest request,
  required AuthorizationGrant grant,
  required Principal actor,
  required CustodyResourceContext resource,
  required OrderFinancialSnapshot snapshot,
  required PaymentFacts? payment,
  required AttemptReturnOrderRead orderRead,
  required DeliveryAttemptFacts? attempt,
  required CustodyFacts? custody,
  required RiderAssignmentFacts? riderAssignment,
}) {
  const CodCollectionCommand command = CodCollectionCommand.reportCodCollection;

  // 0. The canonical resource identity must itself be usable.
  if (!resource.isWellFormed) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }

  // 1. Authorization, before anything is read for effect.
  final CodCollectionDenial? unauthorized = checkCodCollectionAuthorization(
    grant: grant,
    actor: actor,
    command: command,
    expectedResourceId: resource.resourceId,
  );
  if (unauthorized != null) {
    return CodCollectionOutcome.deny(unauthorized);
  }
  if (!actor.isUser || !isValidOpaqueId(actor.id)) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.actorNotHumanPrincipal,
    );
  }
  if (!request.recordedAtUtc.isUtc) {
    return const CodCollectionOutcome.deny(CodCollectionDenial.timestampNotUtc);
  }
  // The journal identifiers anchor the entry and its idempotency reference.
  if (!isValidOpaqueId(request.journalEntryId) ||
      !isValidOpaqueId(request.journalBusinessReference)) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.journalReferenceInvalid,
    );
  }

  // 2. The money snapshot, bound and canonical. Checked before any arithmetic.
  if (snapshot.resourceId != resource.resourceId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (validateOrderFinancialSnapshot(snapshot) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.financialSnapshotInconsistent,
    );
  }

  // 3. The payment aggregate, bound, canonical and pinned.
  if (payment == null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  if (payment.resourceId != resource.resourceId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (validatePaymentAggregate(payment, snapshot) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  if (request.expectedPaymentRevision != payment.paymentRevision) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentRevisionConflict,
    );
  }
  // A contested amount is refused rather than collected against: collecting
  // would prejudge a dispute nobody has resolved.
  if (payment.isDisputed) {
    return const CodCollectionOutcome.deny(CodCollectionDenial.paymentDisputed);
  }
  if (!PaymentState.collectableFrom.contains(payment.state)) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentNotCollectable,
    );
  }

  // 4. The order, bound, canonical, in delivery and pinned.
  if (!orderRead.belongsToResource(resource.resourceId)) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (validateAggregate(orderRead.order) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  final OrderLifecycleFacts order = orderRead.order;
  if (order.state != OrderState.inDelivery) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.orderNotInDelivery,
    );
  }
  if (request.expectedOrderRevision != order.revision) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.orderRevisionConflict,
    );
  }
  if (order.reservationState != ReservationState.committed) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.reservationNotCommitted,
    );
  }

  // 5. The delivery attempt: cash is collected at the door, so the rider must
  //    actually be out for delivery — not still pending, and not after a
  //    refused or failed attempt, where any money question belongs to a
  //    refusal-fee or dispute slice this contract does not implement.
  if (attempt == null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.attemptNotInitialised,
    );
  }
  if (validateDeliveryAttemptAggregate(attempt) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  if (attempt.resourceId != resource.resourceId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (request.expectedAttemptRevision != attempt.attemptRevision) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.attemptRevisionConflict,
    );
  }
  if (attempt.state != DeliveryAttemptState.outForDelivery) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.attemptNotOutForDelivery,
    );
  }

  // 6. Custody and the rider assignment, bound and pinned.
  if (custody == null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.custodyNotInitialised,
    );
  }
  if (validateCustodyAggregate(custody) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  if (custody.resourceId != resource.resourceId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (request.expectedCustodyRevision != custody.custodyRevision) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.custodyRevisionConflict,
    );
  }
  if (!custody.isWithRider) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.custodyNotWithRider,
    );
  }

  if (riderAssignment == null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.noAcceptedRiderAssignment,
    );
  }
  if (validateRiderAssignmentAggregate(riderAssignment) != null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.paymentAggregateInconsistent,
    );
  }
  if (riderAssignment.resourceId != resource.resourceId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.resourceBindingMismatch,
    );
  }
  if (request.expectedRiderSlotRevision != riderAssignment.slotRevision) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.riderSlotRevisionConflict,
    );
  }
  final RiderAssignmentAttempt? riderAttempt = riderAssignment.attempt;
  if (riderAttempt == null ||
      riderAttempt.state != AssignmentState.accepted ||
      riderAttempt.acceptedAssigneePrincipalId == null) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.noAcceptedRiderAssignment,
    );
  }
  if (riderAttempt.acceptedAssigneePrincipalId != actor.id) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.notCurrentAcceptedRider,
    );
  }
  // Identity before generation, matching every other evaluator here.
  if (riderAttempt.assignmentId != request.assignmentId) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.assignmentIdMismatch,
    );
  }
  if (riderAttempt.generation != request.generation) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.generationMismatch,
    );
  }
  // Custody must name that exact attempt. Scalar equality is not identity:
  // without this, cash carried under attempt A could be recorded as though
  // attempt B had collected it.
  if (!custody.holder.isHeldBy(
    principalId: actor.id,
    assignmentId: riderAttempt.assignmentId,
    generation: riderAttempt.generation,
  )) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.custodyHolderBindingMismatch,
    );
  }

  // 7. The money itself, last, once every identity is proven.
  final Money taken = request.collectedAmount;
  if (!CurrencyPolicy.sameUsableCurrency(taken, snapshot.codAmountDue)) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.currencyMismatch,
    );
  }
  if (taken.minorUnits <= 0) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.collectionAmountNotPositive,
    );
  }
  final Money outstandingBefore =
      snapshot.codAmountDue - payment.collectedToDate;
  if (taken > outstandingBefore) {
    return const CodCollectionOutcome.deny(
      CodCollectionDenial.collectionExceedsOutstanding,
    );
  }

  final Money collectedAfter = payment.collectedToDate + taken;
  final Money outstandingAfter = snapshot.codAmountDue - collectedAfter;
  final bool fully = outstandingAfter.isZero;
  final PaymentState toState = fully
      ? PaymentState.collected
      : PaymentState.partiallyCollected;

  // The balanced entry. Signs are fixed by contract: the customer owes `taken`
  // less, and the rider now holds `taken` more. See `JournalPosting`.
  final CashJournalEntry entry = CashJournalEntry(
    entryId: request.journalEntryId,
    businessReference: request.journalBusinessReference,
    resourceId: resource.resourceId,
    recordedAtUtc: request.recordedAtUtc,
    postings: <JournalPosting>[
      JournalPosting(
        account: JournalAccount.customerCodReceivable,
        amount: -taken,
      ),
      JournalPosting(account: JournalAccount.riderCashInTransit, amount: taken),
    ],
  );

  return CodCollectionOutcome.allow(
    CodCollectionTransition(
      command: command,
      resourceId: resource.resourceId,
      recordedAtUtc: request.recordedAtUtc,
      payment: PaymentCollectionEffect(
        fromState: payment.state,
        toState: toState,
        resultingPaymentRevision: payment.paymentRevision + 1,
        collectedAmount: taken,
        resultingCollectedToDate: collectedAfter,
        outstandingAfter: outstandingAfter,
      ),
      journalEntry: entry,
      events: <String>[
        fully
            ? CodCollectionEventType.collected
            : CodCollectionEventType.partiallyCollected,
        CodCollectionEventType.journalEntryRecorded,
      ],
    ),
  );
}
