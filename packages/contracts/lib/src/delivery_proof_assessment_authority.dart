import 'package:cp_contracts/src/delivery_proof.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:meta/meta.dart';

/// Principal kinds that may produce a **normal** proof assessment.
///
/// Exactly one: [PrincipalKind.systemWorker]. A proof assessment is the output
/// of a trusted policy evaluator running server-side, never a claim a human
/// client makes about their own delivery.
///
/// > **Necessary, and deliberately not sufficient.** *(FND-003D2A-FIX-001.)*
/// > `systemWorker` is a broad infrastructure class: the outbox drain,
/// > reservation expiry and scheduled reconciliation all hold it. Accepting the
/// > kind alone would let any of them mint the verdict that later gates
/// > delivery. The exact authorized verifier identity is required as well — see
/// > [DeliveryProofAssessmentContext.authorizedAssessorPrincipalId].
///
/// A future *manual* assessment path, if one is ever needed, is a separate
/// audited workflow with its own permission, scoped authority, a recorded
/// reason and immutable history. **It is not invented here**, and this set is
/// what a later task would have to widen deliberately rather than by accident.
const Set<PrincipalKind> executableProofAssessorKinds = <PrincipalKind>{
  PrincipalKind.systemWorker,
};

/// Canonical identity of the delivery being assessed, resolved **server-side**.
///
/// The backend derives this for the request:
///
/// ```text
/// order resource id
///   -> trusted current order / custody / rider assignment read-set
///   -> authoritative proof policy for that order              (DPA3)
///   -> protected evidence reference for that order            (DPA4)
///   -> authorized proof-verifier service identity for that
///      resource and policy                                    (DPA17)
///   -> DeliveryProofAssessmentContext
/// ```
///
/// > **Not authority.** This is the shape the backend fills from canonical
/// > storage. A caller never reaches the evaluator, and passing one proves
/// > nothing about trust. Fresh authorization on every request, including
/// > replays, remains FND-003A's and the backend's.
///
/// Putting the policy reference, the evidence reference **and the authorized
/// verifier identity** here rather than on the request is the point: a verifier
/// reports a verdict, it does not get to choose which policy it was judged
/// against, which evidence it judged, or whether it was the verifier.
@immutable
class DeliveryProofAssessmentContext {
  const DeliveryProofAssessmentContext({
    required this.resourceId,
    required this.policyRef,
    required this.evidenceRef,
    required this.authorizedAssessorPrincipalId,
  });

  /// The order. Validated with the repository's canonical opaque-id rule.
  final String resourceId;

  /// The authoritative policy that applies, resolved from trusted state.
  final DeliveryProofPolicyRef policyRef;

  /// The protected evidence reference, loaded from trusted state and bound to
  /// [resourceId].
  final DeliveryEvidenceRef evidenceRef;

  /// The **exact** proof-verifier service principal the backend's policy and
  /// routing state authorizes for this resource.
  ///
  /// *(Added by FND-003D2A-FIX-001.)* The evaluator compares the server-derived
  /// assessor `Principal` against this value for exact equality. Without it,
  /// "is a trusted server process" was the whole authority check, and an
  /// outbox, expiry or reconciliation worker could have produced the verdict
  /// that gates delivery.
  ///
  /// Canonical opaque id, resolved from trusted backend state. **Never taken
  /// from request content** — a payload that could name its own authorizer is
  /// not an authorization check. That the value really is the authorized
  /// verifier for this resource is criterion **DPA17**, NOT RUN.
  final String authorizedAssessorPrincipalId;

  /// Whether this context is itself usable. Nothing is trimmed or repaired.
  bool get isWellFormed =>
      isValidOpaqueId(resourceId) &&
      isValidOpaqueId(authorizedAssessorPrincipalId) &&
      validateDeliveryProofPolicyRef(policyRef) == null &&
      validateDeliveryEvidenceRef(evidenceRef, resourceId: resourceId) == null;

  /// Whether [assessor] is the exact authorized proof verifier.
  ///
  /// Both halves are required and neither is sufficient alone: the principal
  /// must be a trusted server worker **and** must be the specific verifier this
  /// resource authorizes. A well-formed context is a precondition, so a
  /// malformed authorized id can never match its way to `true`.
  bool authorizes(Principal assessor) =>
      isWellFormed &&
      executableProofAssessorKinds.contains(assessor.kind) &&
      assessor.id == authorizedAssessorPrincipalId;

  /// A **debug representation, and never a validity claim.**
  ///
  /// *(Hardened by FND-003D2A-FIX-001.)* A well-formed context renders bounded
  /// canonical identifiers, delegating to the D1 references' own safe
  /// renderings. A malformed one renders no field at all — the constructor is
  /// public and `const`, so until validation passes these are untrusted
  /// strings, and echoing even the sound ones would make any log an
  /// amplification surface reachable before validation.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofAssessmentContext($resourceId, $policyRef, $evidenceRef, '
            'verifier=$authorizedAssessorPrincipalId)'
      : 'DeliveryProofAssessmentContext(invalid)';
}

/// One request to record a proof assessment.
///
/// Authorization, idempotency and any command→permission mapping have
/// **already happened** — and for a normal assessment there is no client
/// command to map, because the work is produced by a trusted worker. This
/// carries no grant and no payload: duplicating FND-003A's checks here would
/// create a second place for them to drift.
///
/// > **It cannot name its own assessor.** *(FND-003D2A-FIX-001.)* The
/// > `assessedByPrincipalId` and `assessedByKind` fields that used to live here
/// > were removed rather than kept for source compatibility: a request field
/// > that selects the authority checking it is not a check. The assessor now
/// > arrives as a separate server-derived `Principal`, and the identity written
/// > onto the record is derived from that principal after it matches the
/// > context's authorized verifier. 0.8 is unreleased and has no serialization,
/// > so nothing outside this package could depend on the old shape.
@immutable
class DeliveryProofAssessmentRequest {
  const DeliveryProofAssessmentRequest({
    required this.assessmentId,
    required this.verdict,
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
