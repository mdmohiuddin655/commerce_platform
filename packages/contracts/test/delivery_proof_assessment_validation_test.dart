import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('canonical absence', () {
    test('revision 0 with no record validates', () {
      expect(validateDeliveryProofAssessmentAggregate(absentAssessment), isNull);
    });

    test('an absent aggregate carrying a revision is a torn load', () {
      const DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 3,
      );
      expect(
        validateDeliveryProofAssessmentAggregate(torn),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a malformed resource id is corruption', () {
      expect(
        validateDeliveryProofAssessmentAggregate(
          const DeliveryProofAssessmentFacts.absent(resourceId: 'short'),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });
  });

  group('a present record must be canonical', () {
    DeliveryProofAssessmentDenial? check(
      DeliveryProofAssessmentRecord r, {
      int revision = 1,
      String resourceId = orderId,
    }) => validateDeliveryProofAssessmentAggregate(
      DeliveryProofAssessmentFacts(
        resourceId: resourceId,
        assessmentRevision: revision,
        current: r,
      ),
    );

    test('a healthy first record validates', () {
      expect(check(record()), isNull);
    });

    test('revision 0 with a record is impossible', () {
      expect(
        check(record(), revision: 0),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('record and aggregate revisions must agree', () {
      expect(
        check(record(assessmentRevision: 1), revision: 2),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a record for another order is corruption', () {
      expect(
        check(record(resourceId: otherOrderId)),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a malformed record is corruption', () {
      for (final DeliveryProofAssessmentRecord r
          in <DeliveryProofAssessmentRecord>[
            record(assessmentId: 'asm_short'),
            record(riderPrincipalId: ''),
            record(riderAssignmentId: '1234567890123456'),
            record(riderAssignmentGeneration: 0),
            record(assessedByPrincipalId: 'svc_short'),
            record(policyRef: const DeliveryProofPolicyRef('  ')),
            record(assessedAtUtc: DateTime(2026, 9, 10)),
          ]) {
        expect(
          check(r),
          DeliveryProofAssessmentDenial.aggregateInconsistent,
          reason: 'malformed record: $r',
        );
      }
    });

    test('evidence for another order is corruption', () {
      expect(
        check(
          record(
            evidenceRef: const DeliveryEvidenceRef(
              resourceId: otherOrderId,
              evidenceId: evidenceA,
            ),
          ),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a record produced by a non-worker is corruption', () {
      expect(
        check(
          record(
            assessedByPrincipalId: customerId,
            assessedByKind: PrincipalKind.user,
          ),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
        reason: 'validating its shape would legitimise a self-declared proof',
      );
    });

    test('a first record must supersede nothing', () {
      expect(
        check(record(supersedesAssessmentId: asmtB)),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a later record must supersede something', () {
      expect(
        check(record(assessmentRevision: 2), revision: 2),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
      expect(
        check(
          record(assessmentRevision: 2, supersedesAssessmentId: asmtB),
          revision: 2,
        ),
        isNull,
      );
    });

    test('a record cannot supersede itself', () {
      expect(
        check(
          record(assessmentRevision: 2, supersedesAssessmentId: asmtA),
          revision: 2,
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('the validator repairs nothing', () {
      final DeliveryProofAssessmentRecord broken = record(
        riderPrincipalId: ' $riderA ',
      );
      check(broken);
      expect(broken.riderPrincipalId, ' $riderA ');
    });
  });

  group('validation runs before any transition is constructed', () {
    test('a corrupt stored assessment denies with no transition', () {
      final DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 2,
        current: record(),
      );
      final DeliveryProofAssessmentOutcome o = run(
        assessmentId: asmtB,
        assessment: torn,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.aggregateInconsistent);
      expect(o.transition, isNull);
    });

    test('a corrupt rider aggregate denies with no transition', () {
      final DeliveryProofAssessmentOutcome o = run(
        riderFacts: riderInDelivery(generation: 2, slotRevision: 1),
        expectedRiderSlotRevision: 1,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.aggregateInconsistent);
      expect(o.transition, isNull);
    });

    test('a malformed assessment id is refused', () {
      for (final String bad in <String>[
        '',
        'asm_short',
        '1234567890123456',
        r'asm_bad!identifier01',
      ]) {
        final DeliveryProofAssessmentOutcome o = run(assessmentId: bad);
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.assessmentIdInvalid,
          reason: '"$bad" is not a canonical opaque id',
        );
        expect(o.transition, isNull);
      }
    });
  });
}
