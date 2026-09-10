import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:meta/meta.dart';

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
///
/// > **There is deliberately no verdict getter here.** Reading a verdict off
/// > raw storage facts is only safe once those facts are known canonical, and
/// > this type cannot know that. The trusted accessor is `canonicalVerdict`,
/// > defined next to the validator in
/// > `delivery_proof_assessment_validation.dart`.
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

  /// Whether a current record is **present**.
  ///
  /// **A structural fact about the loaded aggregate, not a trust claim.** It
  /// says a record exists; it does not say the aggregate is canonical, and a
  /// torn load can be `true` here. Do not read it as "this order has a usable
  /// verdict" — ask `canonicalVerdict` for that.
  ///
  /// `false` means **not assessed**. It never means `notSatisfied`.
  bool get hasCurrentRecord => current != null;
}
