import 'package:cp_contracts/src/delivery_proof.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:meta/meta.dart';

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
/// > `satisfied` and names the authorized verifier. It carries no signature, no
/// > attestation and no provenance, and it cannot authenticate its own origin.
/// > **The backend must ignore any client-supplied assessment record** and
/// > treat only a record loaded from trusted server state as authoritative —
/// > criteria **DPA1**, **DPA2** and **DPA17**, all NOT RUN.
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
  /// **Not a command id.** Idempotency keys belong to `CommandEnvelope`;
  /// conflating the two would make a retry look like a new assessment.
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

  /// The **exact authorized proof verifier** that produced this verdict.
  ///
  /// *(Hardened by FND-003D2A-FIX-001.)* Derived from the server-verified
  /// `Principal` the evaluator was given, after that principal was matched
  /// against the resource's authorized verifier identity. It is **never**
  /// selected by request content, and being *some* system worker is not enough
  /// to reach this field — see `DeliveryProofAssessmentContext`.
  ///
  /// Stored rather than inferred so an audit can name which verifier reached a
  /// verdict, which is what makes a superseding reassessment explicable.
  final String assessedByPrincipalId;

  /// The assessor's kind. Always [PrincipalKind.systemWorker] for a normal
  /// assessment. Stored so a record carries its own authority class rather than
  /// having it inferred later.
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

  /// Whether this assessment is **structurally valid and bound to** exactly the
  /// named rider attempt.
  ///
  /// *(Hardened by FND-003D2A-FIX-001.)* A `true` here is a four-part claim,
  /// and all four must hold:
  ///
  /// 1. this record is well formed;
  /// 2. every supplied identity is itself a valid canonical opaque id, and the
  ///    supplied generation is a reachable one (`>= 1`);
  /// 3. all three identities compare **exactly**;
  /// 4. nothing is trimmed, normalised or repaired into a match.
  ///
  /// Raw equality alone failed **open**: a malformed record whose
  /// `riderPrincipalId` was `''` matched a caller passing `''`, and this
  /// convenience method certified a binding that the aggregate validator would
  /// refuse. It cannot now.
  ///
  /// All three identities are required for the same reason
  /// `CustodyHolder.isHeldBy` requires all three: a replacement attempt takes a
  /// new id **and** a new generation, so comparing one alone could match a
  /// different attempt by the same rider.
  bool bindsRiderAttempt({
    required String principalId,
    required String assignmentId,
    required int generation,
  }) =>
      isWellFormed &&
      isValidOpaqueId(principalId) &&
      isValidOpaqueId(assignmentId) &&
      generation >= 1 &&
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
  /// *(Hardened by FND-003D2A-FIX-001, applying the FND-003D1 lesson.)*
  ///
  /// A well-formed record renders canonical opaque identifiers and a verdict —
  /// all bounded at [maxIdLength] and drawn from a restricted alphabet. The
  /// policy reference renders through its own non-disclosing `toString` and the
  /// evidence reference through its own fail-safe one, so neither can leak here
  /// what it refuses to leak there. **No proof material can appear, because
  /// this type holds none.**
  ///
  /// A **malformed** record renders no field at all — not even the fields that
  /// happen to be sound. The constructor is public and `const`, so malformed
  /// instances are deliberately representable (that is what lets the validator
  /// be tested), and until validation has passed these are just untrusted
  /// strings. Echoing even one of them would make any `print`, crash report or
  /// error message an amplification and log-injection surface reachable
  /// *before* validation — precisely the window that matters.
  ///
  /// Nothing is thrown, trimmed, hashed or repaired: this method reports, it
  /// does not fix.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofAssessmentRecord($assessmentId for $resourceId, '
            'rev=$assessmentRevision, ${verdict.id}, rider=$riderPrincipalId '
            'via $riderAssignmentId gen=$riderAssignmentGeneration, '
            'by=$assessedByPrincipalId)'
      : 'DeliveryProofAssessmentRecord(invalid)';
}
