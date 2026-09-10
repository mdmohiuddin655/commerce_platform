import 'package:cp_contracts/src/delivery_proof_dispute_basis.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// One fallback delivery-proof dispute, as currently recorded.
///
/// ## What it holds, and what it refuses to hold
///
/// It holds **identity and audit facts only**: which dispute, about which
/// order, raised by whom, when, against which assessment basis, and — once an
/// administrator takes it up — by whom and when.
///
/// It holds **no free text**. There is no `reason`, `note`, `comment`,
/// `description`, `message` or `attachment` field anywhere in this module, and
/// that is deliberate:
///
/// - the reason is **already captured**. `customer.dispute.raise` and
///   `admin.dispute.administer` both carry `reasonRequired: true`, and FND-003A
///   stores that justification with the audited command. Adding a second copy
///   here would create a second place for it to drift, exactly as duplicating
///   any other authorization check would;
/// - a customer-supplied string on a **wire-facing value object** is an
///   amplification and log-injection surface, and it is the one field through
///   which a description of proof material could reach an event payload. This
///   contract carries no proof material of any kind, and a free-text field
///   would be the hole in that claim.
///
/// It also holds **no outcome**. There is no `upheld`, `rejected`, `resolution`,
/// `fault`, `liable`, `refund`, `compensation` or `charge` field, because no
/// slice decides any of them — see [DeliveryProofDisputeState.resolved].
///
/// ## Immutability
///
/// Every field is final and there is no setter and no `copyWith`. The one
/// defined forward edge is [DeliveryProofDisputeRecord.reviewStarted], which
/// **carries the basis, the raiser and the raise time forward by
/// construction**, so the audit identity of what was disputed and who raised it
/// cannot be rewritten by the operation that advances the dispute.
///
/// > **Constructing one proves nothing.** This is a pure Dart value: any client
/// > can build an identical object locally. It carries no signature, no
/// > attestation and no provenance, and cannot authenticate its own origin. The
/// > backend must ignore client-supplied dispute records and treat only records
/// > loaded from trusted state as authoritative — criteria **DPD1** and
/// > **DPD2**, both NOT RUN.
@immutable
class DeliveryProofDisputeRecord {
  /// The general constructor, kept public and `const` **so that malformed
  /// instances are representable** — that is what lets
  /// `validateDeliveryProofDisputeAggregate` and the fail-safe renderings be
  /// tested at all. It is not the evaluator's path: the evaluator uses the two
  /// named constructors below, which cannot produce an incoherent record.
  const DeliveryProofDisputeRecord({
    required this.disputeId,
    required this.resourceId,
    required this.disputeRevision,
    required this.basis,
    required this.raisedByPrincipalId,
    required this.raisedAtUtc,
    required this.state,
    this.reviewStartedByPrincipalId,
    this.reviewStartedAtUtc,
  });

  /// A newly raised dispute: revision **1**, state `open`, nobody reviewing.
  const DeliveryProofDisputeRecord.raised({
    required this.disputeId,
    required this.resourceId,
    required this.basis,
    required this.raisedByPrincipalId,
    required this.raisedAtUtc,
  }) : disputeRevision = 1,
       state = DeliveryProofDisputeState.open,
       reviewStartedByPrincipalId = null,
       reviewStartedAtUtc = null;

  /// The **only** forward edge: an administrator recorded that review started.
  ///
  /// [previous] supplies the dispute identity, the resource, the raiser, the
  /// raise time and — above all — the [basis], none of which this constructor
  /// accepts as an argument. A caller therefore **cannot** advance a dispute
  /// while quietly changing what it was about or who raised it. That is a
  /// structural guarantee rather than a rule a reviewer has to notice, and it
  /// is the same reasoning that made `DeliveryProofAssessmentTransition` take
  /// only its record.
  DeliveryProofDisputeRecord.reviewStarted({
    required DeliveryProofDisputeRecord previous,
    required String reviewerPrincipalId,
    required DateTime atUtc,
  }) : disputeId = previous.disputeId,
       resourceId = previous.resourceId,
       disputeRevision = previous.disputeRevision + 1,
       basis = previous.basis,
       raisedByPrincipalId = previous.raisedByPrincipalId,
       raisedAtUtc = previous.raisedAtUtc,
       state = DeliveryProofDisputeState.underReview,
       reviewStartedByPrincipalId = reviewerPrincipalId,
       reviewStartedAtUtc = atUtc;

  /// Server-generated, opaque and immutable.
  ///
  /// Validated with the repository's canonical opaque-id rule, which already
  /// rejects sequential-looking values: a counter would let one actor guess
  /// another order's dispute ids and would make a stolen id useful. **Not a
  /// command id** — idempotency keys belong to `CommandEnvelope`.
  final String disputeId;

  /// The order this dispute is about.
  final String resourceId;

  /// The dispute aggregate's own revision at the moment this record became
  /// current. Deliberately independent of the order, custody, rider-slot and
  /// assessment revisions — see `DeliveryProofDisputeFacts`.
  final int disputeRevision;

  /// **What was being disputed**, pinned immutably when the dispute was raised
  /// and never rewritten afterwards — including when the assessment it points
  /// at is later superseded.
  final DeliveryProofDisputeBasis basis;

  /// The customer who raised it, derived from the server-verified principal.
  /// Never taken from request content.
  final String raisedByPrincipalId;

  /// **Server** time the dispute was raised. Never a client or device clock.
  ///
  /// A pure Dart `DateTime` cannot prove it came from a server, so this type
  /// checks only that it is UTC; that it is *authoritative* is criterion
  /// **DPD9**, NOT RUN. **No expiry, deadline, SLA, escalation timer, response
  /// window or retry interval is derived from it, and none is invented.**
  final DateTime raisedAtUtc;

  /// Handling state — never an outcome.
  final DeliveryProofDisputeState state;

  /// The administrator who recorded that review started, or null while `open`.
  final String? reviewStartedByPrincipalId;

  /// Server time review started, or null while `open`.
  final DateTime? reviewStartedAtUtc;

  /// Structurally usable. Fails closed; repairs nothing.
  ///
  /// State and fields must agree in **both** directions, so neither "open but
  /// somebody is recorded as reviewing" nor "under review by nobody" can be
  /// represented as a valid record.
  bool get isWellFormed {
    if (!isValidOpaqueId(disputeId) ||
        !isValidOpaqueId(resourceId) ||
        !isValidOpaqueId(raisedByPrincipalId) ||
        !raisedAtUtc.isUtc ||
        !basis.belongsToResource(resourceId)) {
      return false;
    }
    // The revision is not free: each executable state has exactly one reachable
    // value, and `resolved` has none because no resolution cost was invented.
    if (disputeRevision != reachableDisputeRevisionFor(state)) {
      return false;
    }
    final String? reviewer = reviewStartedByPrincipalId;
    final DateTime? reviewedAt = reviewStartedAtUtc;
    switch (state) {
      case DeliveryProofDisputeState.open:
        return reviewer == null && reviewedAt == null;
      case DeliveryProofDisputeState.underReview:
        return reviewer != null &&
            reviewedAt != null &&
            isValidOpaqueId(reviewer) &&
            reviewedAt.isUtc &&
            // Self-review is no review, and a record claiming it is corrupt.
            reviewer != raisedByPrincipalId &&
            // Review cannot precede the raise. This orders two server-supplied
            // UTC values; it derives no window, deadline or duration from them.
            !reviewedAt.isBefore(raisedAtUtc);
      case DeliveryProofDisputeState.resolved:
        // Unreachable by construction — `reachableDisputeRevisionFor` already
        // returned null above. Stated explicitly so the switch stays exhaustive
        // and a future resolution slice has to make a deliberate decision here.
        return false;
    }
  }

  /// Whether this record is **structurally valid and about** [resourceId].
  ///
  /// Both halves are required: raw equality alone would let two
  /// identically-malformed values match and certify a broken record.
  bool belongsToResource(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  /// Whether this record **is structurally valid and** carries exactly
  /// [disputeId].
  bool hasDisputeId(String disputeId) =>
      isWellFormed && isValidOpaqueId(disputeId) && this.disputeId == disputeId;

  @override
  bool operator ==(Object other) =>
      other is DeliveryProofDisputeRecord &&
      other.disputeId == disputeId &&
      other.resourceId == resourceId &&
      other.disputeRevision == disputeRevision &&
      other.basis == basis &&
      other.raisedByPrincipalId == raisedByPrincipalId &&
      other.raisedAtUtc == raisedAtUtc &&
      other.state == state &&
      other.reviewStartedByPrincipalId == reviewStartedByPrincipalId &&
      other.reviewStartedAtUtc == reviewStartedAtUtc;

  @override
  int get hashCode => Object.hash(
    disputeId,
    resourceId,
    disputeRevision,
    basis,
    raisedByPrincipalId,
    raisedAtUtc,
    state,
    reviewStartedByPrincipalId,
    reviewStartedAtUtc,
  );

  /// A **debug representation, and never a validity claim.**
  ///
  /// A well-formed record renders canonical opaque identifiers and enum names,
  /// all bounded and alphabet-restricted, with the basis rendering through its
  /// own fail-safe `toString`. **No proof material can appear, because this
  /// type holds none** — and no free text can appear, because there is none.
  ///
  /// A **malformed** record renders no field at all, not even the ones that
  /// happen to be sound: until validation has passed they are untrusted
  /// strings, and echoing one would make any `print`, crash report or error
  /// message an amplification and log-injection surface reachable *before*
  /// validation.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofDisputeRecord($disputeId for $resourceId, '
            'rev=$disputeRevision, ${state.id}, by=$raisedByPrincipalId, '
            'basis=$basis, reviewer=${reviewStartedByPrincipalId ?? '-'})'
      : 'DeliveryProofDisputeRecord(invalid)';
}
