import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/custody_lifecycle.dart';
import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/delivery_proof.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/order_state.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/rider_assignment.dart';
import 'package:meta/meta.dart';

/// What a trusted verifier concluded about the referenced proof policy.
///
/// **Two values, and deliberately only two.** Absence of a current assessment
/// already means *not assessed yet* — see [DeliveryProofAssessmentFacts.absent]
/// — so a `pending` value would be a second, contradictory way to say the same
/// thing, and the two would drift. A queue that has not run yet is **backend
/// operational state**, not a commerce-domain verdict, and modelling it here
/// would put job scheduling into the wire contract.
///
/// `expired`, `approvedByCustomer`, `disputed`, `overridden` and `delivered`
/// are absent for a stronger reason: each would decide something no slice has
/// decided — a retention or validity window, whether customer participation is
/// sufficient, how a dispute resolves, who may override a verifier, and whether
/// an order was delivered.
enum DeliveryProofAssessmentVerdict {
  /// The trusted verifier concluded the referenced policy **was** satisfied by
  /// the referenced protected evidence, for this assessment.
  ///
  /// **It does not deliver the order.** It is a prerequisite *result* that a
  /// later, separate delivery transaction may consume — see
  /// `docs/contracts/delivery-proof-assessment.md`. On its own it moves no
  /// order state, no custody, no assignment, no stock and no money.
  satisfied,

  /// The trusted verifier concluded the referenced policy **was not** satisfied
  /// by the referenced protected evidence, for this assessment.
  ///
  /// **That is the entire meaning.** It is emphatically *not* a finding of
  /// fraud, customer refusal, cancellation, delivery failure, a lost dispute,
  /// fee liability, a refund, or financial default. Every one of those is a
  /// separate decision owned by a slice that has not run:
  ///
  /// - refusal, failure and returns — FND-003B3B;
  /// - the fallback dispute workflow — FND-003D2B;
  /// - any money at all — FND-003C, itself blocked on owner decision **O6**.
  ///
  /// A backend must not derive a cancellation, a fee or a liability from this
  /// value, and `CONSTRAINTS.md` invariant 11 stands: delivery failure does not
  /// automatically justify a customer fee.
  notSatisfied;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    DeliveryProofAssessmentVerdict.satisfied => 'satisfied',
    DeliveryProofAssessmentVerdict.notSatisfied => 'not_satisfied',
  };

  static DeliveryProofAssessmentVerdict? byId(String id) {
    for (final DeliveryProofAssessmentVerdict v
        in DeliveryProofAssessmentVerdict.values) {
      if (v.id == id) {
        return v;
      }
    }
    return null;
  }
}

/// Principal kinds that may produce a **normal** proof assessment.
///
/// Exactly one: [PrincipalKind.systemWorker]. A proof assessment is the output
/// of a trusted policy evaluator running server-side, never a claim a human
/// client makes about their own delivery. There is deliberately **no command
/// and no permission** for it — see [evaluateDeliveryProofAssessment] — so no
/// customer, rider, picker, agent or admin can self-declare `satisfied`.
///
/// A future *manual* assessment path, if one is ever needed, is a separate
/// audited workflow with its own permission, scoped authority, a recorded
/// reason and immutable history. **It is not invented here**, and this set is
/// what a later task would have to widen deliberately rather than by accident.
const Set<PrincipalKind> executableProofAssessorKinds = <PrincipalKind>{
  PrincipalKind.systemWorker,
};

/// Why a delivery-proof assessment was refused.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial`,
/// `AssignmentDenial`, `CustodyDenial` and `DeliveryProofDenial` are not.
///
/// There is deliberately no value meaning "the proof was not satisfied":
/// that is a **verdict**, not a denial. A refused assessment records nothing at
/// all; a `notSatisfied` assessment is a successful transition that recorded a
/// negative result. Collapsing the two would make "we could not evaluate this"
/// indistinguishable from "we evaluated it and it failed" — which is exactly
/// the confusion a dispute workflow later has to resolve.
enum DeliveryProofAssessmentDenial {
  /// The canonical resource context is unusable, or an aggregate describes a
  /// different order than the one being assessed.
  resourceBindingMismatch,

  /// `expectedAssessmentRevision` does not match. Another writer got there
  /// first.
  assessmentRevisionConflict,

  /// `expectedOrderRevision` does not match.
  orderRevisionConflict,

  /// `expectedCustodyRevision` does not match.
  custodyRevisionConflict,

  /// `expectedRiderSlotRevision` does not match the rider slot.
  riderSlotRevisionConflict,

  /// The supplied assessment identifier is not a valid opaque id.
  assessmentIdInvalid,

  /// A new assessment tried to reuse the **current** assessment's own id.
  ///
  /// A reassessment is a new immutable fact, not an edit of the old one.
  /// Reusing the identifier would collapse two assessments into one in every
  /// audit trail and event stream, and would make the previous verdict
  /// unfindable — which is precisely what append-only history exists to
  /// prevent. Advancing the revision is not a substitute for a distinct
  /// identity.
  assessmentIdReuse,

  /// The order is not `in_delivery`. Proof of delivery cannot be assessed for
  /// an order that has not been dispatched.
  orderNotInDelivery,

  /// The reservation is not `committed`.
  reservationNotCommitted,

  /// The order has no custody aggregate. **Absence is never read as "a rider
  /// must have it".**
  custodyNotInitialised,

  /// Custody is not held by a rider.
  custodyNotWithRider,

  /// There is no accepted rider assignment for this order.
  noAcceptedRiderAssignment,

  /// The request names a different rider than the order's accepted one.
  notCurrentAcceptedRider,

  /// The request names a different rider assignment attempt than the current
  /// one.
  assignmentIdMismatch,

  /// The request names a different generation than the current attempt's.
  generationMismatch,

  /// Custody is bound to a different rider assignment attempt than the one
  /// currently accepted. **Corruption or a mid-flight reassignment, not a
  /// simple mismatch.**
  custodyHolderBindingMismatch,

  /// The authoritative policy reference is not structurally usable. The exact
  /// structural reason is on [DeliveryProofAssessmentOutcome.structuralDenial].
  policyRefInvalid,

  /// The authoritative evidence reference is not structurally usable.
  evidenceRefInvalid,

  /// The evidence reference belongs to a different order. **Evidence is not
  /// portable between orders.**
  evidenceResourceMismatch,

  /// The assessor is not a trusted server worker. A human client may not
  /// declare their own proof satisfied.
  assessorNotSystemWorker,

  /// The assessor's principal id is not a valid opaque id.
  assessorPrincipalIdInvalid,

  /// `assessedAtUtc` is not UTC. A local-zone timestamp is ambiguous, and a
  /// client clock is never commercial truth.
  assessedAtNotUtc,

  /// A stored aggregate is a combination this contract can never produce.
  /// **Corruption, not a race.**
  aggregateInconsistent,
}

/// One immutable assessment result.
///
/// **Never mutated, never relabelled, never erased.** There is no setter, no
/// `copyWith`, and no method anywhere in this contract that changes a
/// [verdict]. A reassessment produces a *new* record with a new
/// [assessmentId] and the next [assessmentRevision]; the previous record stays
/// exactly as it was written. That is what makes a later dispute able to point
/// at "the assessment that was current when X happened" instead of at a value
/// somebody has since overwritten.
///
/// > **Constructing one proves nothing.** This is a pure Dart value: any client
/// > can build an identical object locally, including one that says
/// > `satisfied`. It carries no signature, no attestation and no provenance,
/// > and it cannot authenticate its own origin. **The backend must ignore any
/// > client-supplied assessment record** and treat only a record loaded from
/// > trusted server state as authoritative — criteria **DPA1** and **DPA2**,
/// > both NOT RUN.
@immutable
class DeliveryProofAssessmentRecord {
  const DeliveryProofAssessmentRecord({
    required this.assessmentId,
    required this.resourceId,
    required this.assessmentRevision,
    required this.policyRef,
    required this.evidenceRef,
    required this.riderPrincipalId,
    required this.riderAssignmentId,
    required this.riderAssignmentGeneration,
    required this.assessedByPrincipalId,
    required this.assessedByKind,
    required this.assessedAtUtc,
    required this.verdict,
    this.supersedesAssessmentId,
  });

  /// Server-generated, opaque, immutable, and **never reused**.
  ///
  /// Validated with the repository's canonical opaque-id rule, which already
  /// rejects sequential-looking values: a counter would let one actor guess
  /// another order's assessment ids, and would make a stolen id useful.
  ///
  /// Uniqueness *across history* — including against assessments that are no
  /// longer current — is a **storage guarantee** this pure type cannot make.
  /// It is criterion **DPA11**, NOT RUN.
  final String assessmentId;

  /// The order this assessment is about.
  final String resourceId;

  /// The assessment aggregate's own revision at the moment this record became
  /// current. The first assessment is **1**.
  final int assessmentRevision;

  /// Which immutable proof policy was evaluated. Resolved server-side from
  /// trusted state — a caller does not choose it (**DPA3**).
  final DeliveryProofPolicyRef policyRef;

  /// The protected evidence that was evaluated, bound to [resourceId].
  ///
  /// **One handle, and no count.** Whether the protected record behind it holds
  /// one artifact, several, or a bundle — and by what mechanism any of it was
  /// captured — is private proof-policy and storage design that no slice has
  /// made. Adding a list here would invent a cardinality; adding a type would
  /// invent a mechanism.
  final DeliveryEvidenceRef evidenceRef;

  /// The rider whose custody was being assessed. Not the assessor.
  final String riderPrincipalId;

  /// The exact rider assignment attempt custody was bound to.
  final String riderAssignmentId;

  /// That attempt's generation. All three rider fields must agree with both
  /// custody and the accepted assignment — a principal id alone could match a
  /// different attempt by the same rider.
  final int riderAssignmentGeneration;

  /// The trusted server worker that produced this verdict.
  final String assessedByPrincipalId;

  /// Always [PrincipalKind.systemWorker] for a normal assessment. Stored so a
  /// record carries its own authority class rather than having it inferred.
  final PrincipalKind assessedByKind;

  /// **Server** time, supplied by trusted server execution.
  ///
  /// Never a client clock, a mobile clock, a notification timestamp or a device
  /// timezone. A pure Dart `DateTime` cannot prove it came from a server, so
  /// this type checks only that it is UTC; that it is *authoritative* is
  /// criterion **DPA13**, NOT RUN.
  ///
  /// No expiry, TTL, maximum age, validity duration or retry interval is
  /// derived from it, and none is invented — a proof policy that wanted one
  /// would have to define it.
  final DateTime assessedAtUtc;

  /// What the verifier concluded.
  final DeliveryProofAssessmentVerdict verdict;

  /// The assessment this one superseded, or null when it is the first.
  ///
  /// A **backward pointer into immutable history**, not a rewrite of it: the
  /// superseded record is untouched and stays readable.
  final String? supersedesAssessmentId;

  /// Structurally usable. Fails closed; repairs nothing.
  bool get isWellFormed =>
      isValidOpaqueId(assessmentId) &&
      isValidOpaqueId(resourceId) &&
      assessmentRevision >= 1 &&
      policyRef.isWellFormed &&
      evidenceRef.belongsTo(resourceId) &&
      isValidOpaqueId(riderPrincipalId) &&
      isValidOpaqueId(riderAssignmentId) &&
      riderAssignmentGeneration >= 1 &&
      isValidOpaqueId(assessedByPrincipalId) &&
      assessedAtUtc.isUtc &&
      (supersedesAssessmentId == null ||
          (isValidOpaqueId(supersedesAssessmentId!) &&
              supersedesAssessmentId != assessmentId));

  /// Whether this assessment is bound to exactly the named rider attempt.
  ///
  /// All three facts must agree, for the same reason [CustodyHolder.isHeldBy]
  /// requires all three: a replacement attempt takes a new id **and** a new
  /// generation, so comparing one alone could match a different attempt.
  bool bindsRiderAttempt({
    required String principalId,
    required String assignmentId,
    required int generation,
  }) =>
      riderPrincipalId == principalId &&
      riderAssignmentId == assignmentId &&
      riderAssignmentGeneration == generation;

  /// Whether this assessment is **structurally valid and about** [resourceId].
  ///
  /// Both halves are required. Raw equality alone would fail open: two
  /// identically-malformed values would match and certify a broken record.
  bool belongsToResource(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  @override
  bool operator ==(Object other) =>
      other is DeliveryProofAssessmentRecord &&
      other.assessmentId == assessmentId &&
      other.resourceId == resourceId &&
      other.assessmentRevision == assessmentRevision &&
      other.policyRef == policyRef &&
      other.evidenceRef == evidenceRef &&
      other.riderPrincipalId == riderPrincipalId &&
      other.riderAssignmentId == riderAssignmentId &&
      other.riderAssignmentGeneration == riderAssignmentGeneration &&
      other.assessedByPrincipalId == assessedByPrincipalId &&
      other.assessedByKind == assessedByKind &&
      other.assessedAtUtc == assessedAtUtc &&
      other.verdict == verdict &&
      other.supersedesAssessmentId == supersedesAssessmentId;

  @override
  int get hashCode => Object.hash(
    assessmentId,
    resourceId,
    assessmentRevision,
    policyRef,
    evidenceRef,
    riderPrincipalId,
    riderAssignmentId,
    riderAssignmentGeneration,
    assessedByPrincipalId,
    assessedByKind,
    assessedAtUtc,
    verdict,
    supersedesAssessmentId,
  );

  /// A **debug representation, and never a validity claim.**
  ///
  /// Identifiers and a verdict only. The policy reference renders through its
  /// own non-disclosing `toString`, and the evidence reference through its own
  /// fail-safe one, so neither can leak here what it refuses to leak there.
  /// **No proof material can appear, because this type holds none.**
  @override
  String toString() =>
      'DeliveryProofAssessmentRecord($assessmentId for $resourceId, '
      'rev=$assessmentRevision, ${verdict.id}, rider=$riderPrincipalId via '
      '$riderAssignmentId gen=$riderAssignmentGeneration)';
}

/// The assessment aggregate for one order, as loaded from storage.
///
/// Its [assessmentRevision] is **its own** concurrency control — deliberately
/// independent of the order revision, the custody revision and the rider
/// `slotRevision`. Four aggregates change at different rates; sharing one
/// counter would make every unrelated write look like a conflict and a genuine
/// conflict undetectable.
///
/// **It carries only the current record.** There is no history array, because
/// an unbounded in-memory list of every past assessment is a memory and payload
/// hazard on an aggregate a backend loads on every request. History is retained
/// by storage in a bounded, paginated, append-only form — criterion **DPA12**,
/// NOT RUN.
@immutable
class DeliveryProofAssessmentFacts {
  const DeliveryProofAssessmentFacts({
    required this.resourceId,
    required this.assessmentRevision,
    this.current,
  });

  /// Canonical absence: **not assessed**.
  ///
  /// Revision 0 and no record, following the repository's existing convention
  /// that revision 0 means "never written". This is the *only* way to say "no
  /// assessment yet" — there is no `pending` verdict, so the two cannot
  /// disagree.
  const DeliveryProofAssessmentFacts.absent({required this.resourceId})
    : assessmentRevision = 0,
      current = null;

  final String resourceId;

  /// Increments on **every** applied assessment, first or repeat.
  final int assessmentRevision;

  /// The current assessment, or null when the order has never been assessed.
  final DeliveryProofAssessmentRecord? current;

  /// Whether an assessment exists at all. **Absence is not a verdict.**
  bool get isAssessed => current != null;

  /// The current verdict, or null when never assessed. Null here means *not
  /// assessed*, never "not satisfied" — callers must not collapse the two.
  DeliveryProofAssessmentVerdict? get currentVerdict => current?.verdict;
}

/// Canonical identity of the delivery being assessed, resolved **server-side**.
///
/// The backend derives this for the request:
///
/// ```text
/// order resource id
///   -> trusted current order / custody / rider assignment read-set
///   -> authoritative proof policy for that order        (DPA3)
///   -> protected evidence reference for that order      (DPA4)
///   -> DeliveryProofAssessmentContext
/// ```
///
/// > **Not authority.** This is the shape the backend fills from canonical
/// > storage. A caller never reaches the evaluator, and passing one proves
/// > nothing about trust. Fresh authorization on every request, including
/// > replays, remains FND-003A's and the backend's.
///
/// Putting the policy and evidence references **here** rather than on the
/// request is the point: a verifier reports a verdict, it does not get to
/// choose which policy it was judged against or which evidence it judged.
@immutable
class DeliveryProofAssessmentContext {
  const DeliveryProofAssessmentContext({
    required this.resourceId,
    required this.policyRef,
    required this.evidenceRef,
  });

  /// The order. Validated with the repository's canonical opaque-id rule.
  final String resourceId;

  /// The authoritative policy that applies, resolved from trusted state.
  final DeliveryProofPolicyRef policyRef;

  /// The protected evidence reference, loaded from trusted state and bound to
  /// [resourceId].
  final DeliveryEvidenceRef evidenceRef;

  /// Whether this context is itself usable. Nothing is trimmed or repaired.
  bool get isWellFormed =>
      isValidOpaqueId(resourceId) &&
      validateDeliveryProofPolicyRef(policyRef) == null &&
      validateDeliveryEvidenceRef(evidenceRef, resourceId: resourceId) == null;

  @override
  String toString() =>
      'DeliveryProofAssessmentContext($resourceId, $policyRef, $evidenceRef)';
}

/// One request to record a proof assessment.
///
/// Authorization, idempotency and any command→permission mapping have
/// **already happened** — and for a normal assessment there is no client
/// command to map, because the work is produced by a trusted worker. This
/// carries no grant and no payload: duplicating FND-003A's checks here would
/// create a second place for them to drift.
@immutable
class DeliveryProofAssessmentRequest {
  const DeliveryProofAssessmentRequest({
    required this.assessmentId,
    required this.verdict,
    required this.assessedByPrincipalId,
    required this.assessedByKind,
    required this.assessedAtUtc,
    required this.riderPrincipalId,
    required this.riderAssignmentId,
    required this.riderAssignmentGeneration,
    required this.expectedAssessmentRevision,
    required this.expectedOrderRevision,
    required this.expectedCustodyRevision,
    required this.expectedRiderSlotRevision,
  });

  /// The **new** opaque id for this assessment, server-generated.
  final String assessmentId;

  /// What the trusted verifier concluded.
  final DeliveryProofAssessmentVerdict verdict;

  /// The assessor's principal id, derived from trusted server execution.
  final String assessedByPrincipalId;

  /// The assessor's kind. Must be in [executableProofAssessorKinds].
  final PrincipalKind assessedByKind;

  /// Server UTC time of the assessment.
  final DateTime assessedAtUtc;

  /// The rider attempt the verifier believes it assessed. Checked against
  /// **both** custody and the accepted rider assignment, exactly.
  final String riderPrincipalId;
  final String riderAssignmentId;
  final int riderAssignmentGeneration;

  /// Assessment revision the caller believes is current. **0** for a first
  /// assessment.
  final int expectedAssessmentRevision;

  /// Order revision the caller believes is current.
  ///
  /// Checked even though an assessment leaves the order untouched: the decision
  /// *depends* on the order still being `in_delivery`, so acting on a stale
  /// view of it is refused rather than silently assessed against facts that
  /// have moved.
  final int expectedOrderRevision;

  /// Custody revision the caller believes is current.
  final int expectedCustodyRevision;

  /// Rider slot revision the caller believes is current.
  final int expectedRiderSlotRevision;
}

/// A permitted assessment: the immutable record to append, and nothing else.
///
/// **Every commercial effect is NONE, structurally.** There is no order effect
/// field, no custody effect field and no assignment effect field on this class,
/// so a transition *cannot* be constructed that moves any of them — that is a
/// stronger statement than a runtime check, and it is why they are getters
/// returning constants rather than constructor parameters.
///
/// A `satisfied` assessment therefore does **not**: move `in_delivery →
/// delivered`, move rider custody to the customer, complete the rider
/// assignment, restore inventory, settle COD, or open or close a dispute. It is
/// only a prerequisite result that a later atomic delivery transaction may
/// consume — see `docs/contracts/delivery-proof-assessment.md`.
@immutable
class DeliveryProofAssessmentTransition {
  const DeliveryProofAssessmentTransition({
    required this.record,
    required this.events,
  });

  /// The immutable record to append. Its own [record] revision is the
  /// aggregate's resulting revision.
  final DeliveryProofAssessmentRecord record;

  /// Every domain fact this assessment causes, in order.
  ///
  /// Exactly one today. It **must commit atomically with** the assessment
  /// record and the dedupe result — criterion **DPA14**. Notification delivery
  /// is not part of that transaction: a push is a hint, never authorization or
  /// proof, and it may simply be missed.
  final List<String> events;

  /// Always the previous revision + 1.
  int get resultingAssessmentRevision => record.assessmentRevision;

  /// The assessment this one supersedes, or null when it is the first.
  String? get supersededAssessmentId => record.supersedesAssessmentId;

  /// Whether this is a reassessment rather than a first assessment.
  bool get isReassessment => record.supersedesAssessmentId != null;

  DeliveryProofAssessmentVerdict get verdict => record.verdict;

  /// Assessment never touches stock. Concluding something about evidence
  /// creates and destroys no units, in either verdict.
  InventoryEffect get inventoryEffect => const InventoryEffect.none();

  /// Recording a verdict posts no money and never will.
  ///
  /// **This classifies the recording, not the consequence.** Whether a
  /// `notSatisfied` outcome eventually has a financial consequence — a fee, a
  /// liability, a refund, a settlement effect — is **UNKNOWN and deferred to
  /// FND-003C**, itself blocked on owner decision **O6**. It must never be read
  /// as zero, and nothing here permits deriving an amount.
  FinancialClassification get financialClassification =>
      FinancialClassification.noneInThisSlice;

  /// Assessment grants no authorization projection change. **Being assessed is
  /// not permission**, in either direction.
  ScopeProjectionEffect get scopeEffect => const ScopeProjectionEffect.none();

  /// The order is untouched — no state, no revision.
  bool get changesOrderState => false;

  /// Custody is untouched. A verdict does not move goods.
  bool get changesCustody => false;

  /// The rider assignment is untouched. In particular, `satisfied` does **not**
  /// complete it: rider `AssignmentState.completed` remains unreachable and no
  /// revision cost for it was invented — criterion **B3-C2**, FUTURE.
  bool get changesRiderAssignment => false;

  @override
  String toString() =>
      'DeliveryProofAssessmentTransition(${record.verdict.id}, '
      'rev=$resultingAssessmentRevision, id=${record.assessmentId}, '
      'supersedes=${supersededAssessmentId ?? '-'})';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class DeliveryProofAssessmentOutcome {
  const DeliveryProofAssessmentOutcome._(
    this.transition,
    this.denial,
    this.structuralDenial,
  );

  const DeliveryProofAssessmentOutcome.allow(
    DeliveryProofAssessmentTransition transition,
  ) : this._(transition, null, null);

  const DeliveryProofAssessmentOutcome.deny(
    DeliveryProofAssessmentDenial denial, {
    DeliveryProofDenial? structural,
  }) : this._(null, denial, structural);

  /// Null for **every** denial. A denied assessment mutates nothing, emits no
  /// event, and produces no order, reservation, inventory, financial, custody
  /// or assignment effect.
  final DeliveryProofAssessmentTransition? transition;

  final DeliveryProofAssessmentDenial? denial;

  /// The exact FND-003D1 structural reason, when the denial came from a
  /// reference validator.
  ///
  /// Carried rather than collapsed so a log does not have to guess whether a
  /// policy reference was blank or over-long, or whether an evidence reference
  /// had a broken id or simply named another order. The D1 validators remain
  /// the single source of that judgement — nothing is reimplemented here.
  final DeliveryProofDenial? structuralDenial;

  bool get allowed => transition != null;

  @override
  String toString() => allowed
      ? 'Allow(${transition!})'
      : 'Deny(${denial!.name}'
            '${structuralDenial == null ? '' : '/${structuralDenial!.name}'})';
}

/// Canonical assessment-aggregate shape.
///
/// Same lesson as every slice before it: the evaluator never *creates* an
/// impossible aggregate, but facts arrive from **storage**. Validation runs
/// before any transition is constructed.
///
/// Returns null when the facts are canonical. **Never repairs anything** —
/// repair without an audit trail is indistinguishable from a bug.
DeliveryProofAssessmentDenial? validateDeliveryProofAssessmentAggregate(
  DeliveryProofAssessmentFacts facts,
) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  final DeliveryProofAssessmentRecord? current = facts.current;
  if (current == null) {
    // Canonical absence is exact. A "never assessed" aggregate carrying a
    // revision is a partial load, and reading it as absent would let a second
    // first-assessment overwrite the revision of one that already exists.
    if (facts.assessmentRevision != 0) {
      return DeliveryProofAssessmentDenial.aggregateInconsistent;
    }
    return null;
  }
  // An existing assessment has been written at least once.
  if (facts.assessmentRevision < 1) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  // The current pointer and the aggregate revision must agree. A record whose
  // own revision differs from the aggregate's is a torn write.
  if (current.assessmentRevision != facts.assessmentRevision) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  if (current.resourceId != facts.resourceId) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  if (!current.isWellFormed) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  // A stored record whose assessor is not a trusted worker is a combination
  // this contract cannot produce; validating its shape would legitimise it.
  if (!executableProofAssessorKinds.contains(current.assessedByKind)) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  // A first assessment supersedes nothing; a later one must supersede
  // something. Either way the pointer has to agree with the revision.
  final bool isFirst = facts.assessmentRevision == 1;
  if (isFirst != (current.supersedesAssessmentId == null)) {
    return DeliveryProofAssessmentDenial.aggregateInconsistent;
  }
  return null;
}

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

  // 5. Assessor authority. A pure Dart value cannot prove runtime trust, so
  //    this is the *class* of authority the record claims — the backend is
  //    responsible for the claim being true (**DPA2**).
  if (!executableProofAssessorKinds.contains(request.assessedByKind)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessorNotSystemWorker,
    );
  }
  if (!isValidOpaqueId(request.assessedByPrincipalId)) {
    return const DeliveryProofAssessmentOutcome.deny(
      DeliveryProofAssessmentDenial.assessorPrincipalIdInvalid,
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
        assessedByPrincipalId: request.assessedByPrincipalId,
        assessedByKind: request.assessedByKind,
        assessedAtUtc: request.assessedAtUtc,
        verdict: request.verdict,
        // A backward pointer into immutable history. The previous record is
        // not touched, not relabelled and not erased.
        supersedesAssessmentId: previous?.assessmentId,
      ),
      events: const <String>[DeliveryProofAssessmentEventType.proofAssessed],
    ),
  );
}

/// Canonical delivery-proof assessment event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing and **proves
/// nothing** — a client re-reads authorized server state. Server-assigned event
/// ids only; a transport message id is never the business event id.
///
/// Payloads carry routing and identity only: resource id, assessment revision,
/// assessment id, server UTC. **No raw proof, no policy contents, no
/// photograph, signature, OTP or QR material, no GPS or location, no address,
/// no phone number, no order contents, no money and no storage path or signed
/// URL.** Authorized clients re-read protected state; a notification is a hint,
/// never proof or authority.
class DeliveryProofAssessmentEventType {
  const DeliveryProofAssessmentEventType._();

  /// A trusted assessment record was created for an order.
  ///
  /// It reports **that an assessment happened**, not that delivery succeeded,
  /// that the customer accepted, that a dispute resolved or that money settled.
  /// Whether the verdict itself belongs in the payload is a **privacy and
  /// policy decision that is deliberately not made here** — a routing id is
  /// always sufficient, because an authorized client re-reads the record.
  static const String proofAssessed = 'delivery.proof_assessed';

  static const List<String> all = <String>[proofAssessed];
}
