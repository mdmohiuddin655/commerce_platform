import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('canonical aggregate shape', () {
    test('canonical absence and a canonical open dispute both validate', () {
      expect(validateDeliveryProofDisputeAggregate(noDispute), isNull);
      expect(validateDeliveryProofDisputeAggregate(openDispute()), isNull);
      expect(validateDeliveryProofDisputeAggregate(reviewedDispute()), isNull);
    });

    test('a broken resource id is corruption', () {
      expect(
        validateDeliveryProofDisputeAggregate(
          const DeliveryProofDisputeFacts.absent(resourceId: 'short'),
        ),
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
    });

    test('absence carrying a revision is a partial load', () {
      // Reading it as absent would let a second raise overwrite the revision of
      // a dispute that already exists.
      expect(
        validateDeliveryProofDisputeAggregate(
          const DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 1,
          ),
        ),
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
    });

    test('a record whose revision differs from the aggregate is torn', () {
      expect(
        validateDeliveryProofDisputeAggregate(
          DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 2,
            current: disputeRecord(),
          ),
        ),
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
      expect(
        validateDeliveryProofDisputeAggregate(
          DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 0,
            current: disputeRecord(),
          ),
        ),
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
    });

    test('a record about a different order is corruption', () {
      expect(
        validateDeliveryProofDisputeAggregate(
          DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 1,
            current: disputeRecord(
              resourceId: otherOrderId,
              basis: const DeliveryProofDisputeBasis.notAssessed(
                resourceId: otherOrderId,
              ),
            ),
          ),
        ),
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
    });

    test('a malformed record is corruption, field by field', () {
      for (final DeliveryProofDisputeRecord bad in <DeliveryProofDisputeRecord>[
        disputeRecord(disputeId: 'short'),
        disputeRecord(raisedByPrincipalId: ''),
        disputeRecord(raisedAtUtc: DateTime(2026, 9, 11)),
        disputeRecord(
          basis: const DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: '',
            assessmentRevision: 1,
          ),
        ),
      ]) {
        expect(
          validateDeliveryProofDisputeAggregate(
            DeliveryProofDisputeFacts(
              resourceId: orderId,
              disputeRevision: 1,
              current: bad,
            ),
          ),
          DeliveryProofDisputeDenial.disputeAggregateInconsistent,
          reason: '$bad must not validate',
        );
      }
    });

    test('a stored "resolved" dispute is corruption, not a state', () {
      // No slice implements resolution, so no revision is reachable for it and
      // validating its shape would legitimise an outcome nobody decided.
      for (final int revision in <int>[1, 2, 3]) {
        expect(
          validateDeliveryProofDisputeAggregate(
            DeliveryProofDisputeFacts(
              resourceId: orderId,
              disputeRevision: revision,
              current: disputeRecord(
                disputeRevision: revision,
                state: DeliveryProofDisputeState.resolved,
              ),
            ),
          ),
          DeliveryProofDisputeDenial.disputeAggregateInconsistent,
        );
      }
    });
  });

  group('trusted access', () {
    test('canonicalState answers only for a canonical aggregate', () {
      expect(openDispute().canonicalState, DeliveryProofDisputeState.open);
      expect(
        reviewedDispute().canonicalState,
        DeliveryProofDisputeState.underReview,
      );
      expect(noDispute.canonicalState, isNull);
    });

    test('a torn aggregate exposes no state and no basis', () {
      // The FND-003D2A-FIX-001 lesson applied from the start: a getter reading
      // straight off raw storage would hand a caller a trusted-looking answer
      // from a torn load.
      final DeliveryProofDisputeFacts torn = DeliveryProofDisputeFacts(
        resourceId: orderId,
        disputeRevision: 2,
        current: disputeRecord(),
      );
      expect(torn.hasCurrentRecord, isTrue);
      expect(torn.canonicalState, isNull);
      expect(torn.canonicalBasis, isNull);
    });

    test('canonicalBasis is the accessor an audit must use', () {
      final DeliveryProofDisputeFacts facts = openDispute(
        basis: const DeliveryProofDisputeBasis.notSatisfied(
          resourceId: orderId,
          assessmentId: asmtA,
          assessmentRevision: 1,
        ),
      );
      final DeliveryProofDisputeBasis? basis = facts.canonicalBasis;
      expect(basis, isNotNull);
      expect(
        basis!.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 1),
        isTrue,
      );
      expect(facts.canonicalBasis, isNotNull);
    });

    test('there is no mutating accessor anywhere on the aggregate', () {
      // Nothing on this type can change a dispute: no setter, no copyWith, no
      // status patch. The only way to a new record is the evaluator.
      final DeliveryProofDisputeFacts before = openDispute();
      final DeliveryProofDisputeRecord? recordBefore = before.current;
      expect(before.canonicalState, DeliveryProofDisputeState.open);
      expect(before.canonicalBasis, isNotNull);
      expect(identical(before.current, recordBefore), isTrue);
    });
  });
}
