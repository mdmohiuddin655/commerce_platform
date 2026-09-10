import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('first assessment — 0 -> 1', () {
    test('a first satisfied assessment binds everything', () {
      final DeliveryProofAssessmentTransition t = allowed(run());

      expect(t.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(t.resultingAssessmentRevision, 1);
      expect(t.isReassessment, isFalse);
      expect(t.supersededAssessmentId, isNull);

      final DeliveryProofAssessmentRecord r = t.record;
      expect(r.assessmentId, asmtA);
      expect(r.resourceId, orderId);
      expect(r.assessmentRevision, 1);
      expect(r.policyRef, proofPolicy);
      expect(r.evidenceRef.evidenceId, evidenceA);
      expect(r.evidenceRef.belongsTo(orderId), isTrue);
      expect(r.riderPrincipalId, riderA);
      expect(r.riderAssignmentId, rideAsgA);
      expect(r.riderAssignmentGeneration, 1);
      expect(r.assessedByPrincipalId, verifierId);
      expect(r.assessedByKind, PrincipalKind.systemWorker);
      expect(r.assessedAtUtc, assessedAt);
      expect(r.assessedAtUtc.isUtc, isTrue);
      expect(r.isWellFormed, isTrue);
      expect(
        r.bindsRiderAttempt(
          principalId: riderA,
          assignmentId: rideAsgA,
          generation: 1,
        ),
        isTrue,
      );
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(t)),
        isNull,
      );
    });

    test('a first notSatisfied assessment is equally allowed', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      expect(t.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(t.resultingAssessmentRevision, 1);
      expect(t.record.supersedesAssessmentId, isNull);
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(t)),
        isNull,
      );
    });

    test('the policy and evidence come from the context, not the caller', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(
          context: ctx(
            policy: const DeliveryProofPolicyRef('policy/other@v9'),
            evidence: const DeliveryEvidenceRef(
              resourceId: orderId,
              evidenceId: evidenceB,
            ),
          ),
        ),
      );
      expect(t.record.policyRef.value, 'policy/other@v9');
      expect(t.record.evidenceRef.evidenceId, evidenceB);
    });
  });

  group('reassessment is append-only', () {
    test('reassessment after satisfied increments and supersedes', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          verdict: DeliveryProofAssessmentVerdict.notSatisfied,
          assessment: applyAssessment(first),
        ),
      );

      expect(second.resultingAssessmentRevision, 2);
      expect(second.isReassessment, isTrue);
      expect(second.supersededAssessmentId, asmtA);
      expect(second.record.assessmentId, asmtB);
      expect(second.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(second)),
        isNull,
      );
    });

    test('reassessment after notSatisfied works the same way', () {
      final DeliveryProofAssessmentTransition first = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      final DeliveryProofAssessmentTransition second = allowed(
        run(assessmentId: asmtB, assessment: applyAssessment(first)),
      );
      expect(second.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(second.resultingAssessmentRevision, 2);
      expect(second.supersededAssessmentId, asmtA);
    });

    test('a third assessment keeps incrementing by exactly one', () {
      DeliveryProofAssessmentFacts facts = absentAssessment;
      final List<int> revisions = <int>[];
      for (final String id in <String>[asmtA, asmtB, asmtC]) {
        final DeliveryProofAssessmentTransition t = allowed(
          run(assessmentId: id, assessment: facts),
        );
        revisions.add(t.resultingAssessmentRevision);
        facts = applyAssessment(t);
      }
      expect(revisions, <int>[1, 2, 3]);
    });

    test('the previous record is never mutated, relabelled or erased', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentRecord before = first.record;
      final String beforeId = before.assessmentId;
      final int beforeRevision = before.assessmentRevision;
      final DeliveryProofAssessmentVerdict beforeVerdict = before.verdict;
      final DateTime beforeAt = before.assessedAtUtc;

      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          verdict: DeliveryProofAssessmentVerdict.notSatisfied,
          assessment: applyAssessment(first),
        ),
      );

      expect(before.assessmentId, beforeId);
      expect(before.assessmentRevision, beforeRevision);
      expect(before.verdict, beforeVerdict);
      expect(before.assessedAtUtc, beforeAt);
      expect(before.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(second.record, isNot(before));
      expect(second.record.supersedesAssessmentId, beforeId);
    });

    test('a verdict-changing reassessment keeps both audit identities', () {
      // The immutable basis DPA18 requires the backend to preserve: two
      // distinct assessment ids, the superseding pointer, the acting verifier
      // and the exact policy/evidence references on each record.
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          verdict: DeliveryProofAssessmentVerdict.notSatisfied,
          assessment: applyAssessment(first),
        ),
      );
      expect(first.record.assessmentId, isNot(second.record.assessmentId));
      expect(second.record.supersedesAssessmentId, first.record.assessmentId);
      expect(second.record.assessedByPrincipalId, verifierId);
      expect(second.record.policyRef, first.record.policyRef);
      expect(second.record.evidenceRef, first.record.evidenceRef);
    });

    test('a reassessment must carry a NEW assessment id', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentOutcome reuse = run(
        assessmentId: asmtA,
        assessment: applyAssessment(first),
      );
      expect(reuse.denial, DeliveryProofAssessmentDenial.assessmentIdReuse);
      expect(reuse.transition, isNull);
    });
  });

}
