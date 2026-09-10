import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('stale, duplicate, reordered and concurrent safety', () {
    test('a stale expected assessment revision is refused', () {
      final DeliveryProofAssessmentOutcome stale = run(
        assessmentId: asmtB,
        assessment: applyAssessment(allowed(run())),
        expectedAssessmentRevision: 0,
      );
      expect(
        stale.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(stale.transition, isNull);
    });

    test('a delayed reassessment from an old revision writes nothing', () {
      DeliveryProofAssessmentFacts facts = absentAssessment;
      facts = applyAssessment(allowed(run(assessment: facts)));
      facts = applyAssessment(
        allowed(run(assessmentId: asmtB, assessment: facts)),
      );
      expect(facts.assessmentRevision, 2);

      final DeliveryProofAssessmentOutcome delayed = run(
        assessmentId: asmtC,
        assessment: facts,
        expectedAssessmentRevision: 1,
      );
      expect(
        delayed.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(delayed.transition, isNull);
    });

    test('two concurrent reassessments from one revision: only one wins', () {
      final DeliveryProofAssessmentFacts shared = applyAssessment(
        allowed(run()),
      );
      final DeliveryProofAssessmentTransition a = allowed(
        run(assessmentId: asmtB, assessment: shared),
      );
      final DeliveryProofAssessmentTransition b = allowed(
        run(assessmentId: asmtC, assessment: shared),
      );
      // Both evaluate to the same next revision — the contract cannot serialise
      // them and does not pretend to.
      expect(a.resultingAssessmentRevision, 2);
      expect(b.resultingAssessmentRevision, 2);

      // Whichever commits first advances the aggregate; the loser's expected
      // revision is then stale. Serialisation itself is the backend's
      // transaction — DPA8, NOT RUN.
      final DeliveryProofAssessmentOutcome loser = run(
        assessmentId: asmtC,
        assessment: applyAssessment(a),
        expectedAssessmentRevision: 1,
      );
      expect(
        loser.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(loser.transition, isNull);
    });

    test('a duplicate request advances nothing through this contract', () {
      // The same request against the SAME facts produces the same proposal. Real
      // replay-versus-reuse is FND-003A idempotency plus backend storage
      // (DPA10), NOT RUN. An assessmentId is NOT a command id.
      final DeliveryProofAssessmentTransition one = allowed(
        run(assessment: absentAssessment),
      );
      final DeliveryProofAssessmentTransition two = allowed(
        run(assessment: absentAssessment),
      );
      expect(one.record, two.record);
      expect(one.resultingAssessmentRevision, 1);
      expect(two.resultingAssessmentRevision, 1);
    });

    test('stale order, custody and rider slot revisions are each refused', () {
      expect(
        run(expectedOrderRevision: 4).denial,
        DeliveryProofAssessmentDenial.orderRevisionConflict,
      );
      expect(
        run(expectedCustodyRevision: 2).denial,
        DeliveryProofAssessmentDenial.custodyRevisionConflict,
      );
      expect(
        run(expectedRiderSlotRevision: 1).denial,
        DeliveryProofAssessmentDenial.riderSlotRevisionConflict,
      );
      for (final DeliveryProofAssessmentOutcome o
          in <DeliveryProofAssessmentOutcome>[
            run(expectedOrderRevision: 4),
            run(expectedCustodyRevision: 2),
            run(expectedRiderSlotRevision: 1),
          ]) {
        expect(o.transition, isNull);
      }
    });

    test('correct revisions never bypass the identity checks', () {
      // Every expected revision is right; the rider named is wrong.
      final DeliveryProofAssessmentOutcome o = run(rider: riderB);
      expect(o.denial, DeliveryProofAssessmentDenial.notCurrentAcceptedRider);
      expect(o.transition, isNull);
    });

    test('correct revisions never bypass the authority check', () {
      final DeliveryProofAssessmentOutcome o = run(assessor: otherWorker());
      expect(o.denial, DeliveryProofAssessmentDenial.assessorAuthorityMismatch);
      expect(o.transition, isNull);
    });
  });

}
