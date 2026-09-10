import 'package:cp_contracts/src/delivery_proof_assessment_authority.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_denial.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/ids.dart';

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
  //
  // This is the *kind* check only. Whether the stored principal was the
  // authorized verifier for this resource is a question about backend policy
  // state that a pure aggregate cannot answer after the fact — that is
  // criterion DPA17, NOT RUN.
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

/// Trusted read access to the current verdict.
///
/// *(Added by FND-003D2A-FIX-001.)* `DeliveryProofAssessmentFacts` deliberately
/// exposes no verdict getter of its own. The convenience getter it used to
/// carry returned `current?.verdict` straight off raw storage facts, so a
/// **torn or corrupt** aggregate — one the validator refuses — could still hand
/// a caller a trusted-looking `satisfied`. On the value that gates delivery,
/// that is the wrong direction to fail.
extension DeliveryProofAssessmentCanonicalAccess
    on DeliveryProofAssessmentFacts {
  /// The current verdict **only when the aggregate is canonical**.
  ///
  /// | Aggregate | Result |
  /// |---|---|
  /// | canonical, absent | `null` — *not assessed* |
  /// | canonical, satisfied | `satisfied` |
  /// | canonical, notSatisfied | `notSatisfied` |
  /// | malformed or torn, carrying `satisfied` | `null` |
  ///
  /// **Corruption is never converted into `notSatisfied`.** A broken aggregate
  /// is a denial and a reconciliation case, not a negative proof result;
  /// silently downgrading it would fabricate a verdict nobody reached. `null`
  /// here therefore means *no usable verdict* — which a caller must not read as
  /// "the policy was not satisfied" either.
  DeliveryProofAssessmentVerdict? get canonicalVerdict =>
      validateDeliveryProofAssessmentAggregate(this) == null
      ? current?.verdict
      : null;
}
