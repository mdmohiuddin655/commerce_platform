import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('current delivery context must describe the same delivery', () {
    test('an order that is not in delivery is refused', () {
      const Map<OrderState, ReservationState> canonical =
          <OrderState, ReservationState>{
            OrderState.placed: ReservationState.active,
            OrderState.accepted: ReservationState.committed,
            OrderState.preparing: ReservationState.committed,
            OrderState.ready: ReservationState.committed,
          };
      for (final OrderState s in canonical.keys) {
        final DeliveryProofAssessmentOutcome o = run(
          order: orderFacts(state: s, revision: 4, reservation: canonical[s]!),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.orderNotInDelivery,
          reason: 'proof cannot be assessed for a ${s.id} order',
        );
        expect(o.transition, isNull);
      }
    });

    test('a non-committed reservation is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        order: inDelivery(reservation: ReservationState.released),
      );
      expect(
        o.denial,
        anyOf(
          DeliveryProofAssessmentDenial.reservationNotCommitted,
          DeliveryProofAssessmentDenial.aggregateInconsistent,
        ),
      );
      expect(o.transition, isNull);
    });

    test('missing custody is never read as "a rider must have it"', () {
      final DeliveryProofAssessmentOutcome o = run(omitCustody: true);
      expect(o.denial, DeliveryProofAssessmentDenial.custodyNotInitialised);
      expect(o.transition, isNull);
    });

    test('custody not held by a rider is refused', () {
      expect(
        run(custody: atShop()).denial,
        DeliveryProofAssessmentDenial.custodyNotWithRider,
      );
      expect(
        run(custody: withPicker()).denial,
        DeliveryProofAssessmentDenial.custodyNotWithRider,
      );
    });

    test('a missing rider assignment is refused', () {
      final DeliveryProofAssessmentOutcome o = run(omitRider: true);
      expect(o.denial, DeliveryProofAssessmentDenial.noAcceptedRiderAssignment);
      expect(o.transition, isNull);
    });

    test('a rider assignment that is not accepted is refused', () {
      for (final AssignmentState s in <AssignmentState>[
        AssignmentState.offered,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        final DeliveryProofAssessmentOutcome o = run(
          riderFacts: riderInDelivery(state: s),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.noAcceptedRiderAssignment,
          reason: 'a ${s.id} rider attempt is not carrying anything',
        );
        expect(o.transition, isNull);
      }
    });

    test('an empty rider slot is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        riderFacts: riderInDelivery(state: null),
        expectedRiderSlotRevision: 0,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.noAcceptedRiderAssignment);
      expect(o.transition, isNull);
    });

    test('the wrong rider principal, assignment or generation is refused', () {
      expect(
        run(rider: riderB).denial,
        DeliveryProofAssessmentDenial.notCurrentAcceptedRider,
      );
      expect(
        run(riderAssignment: rideAsgB).denial,
        DeliveryProofAssessmentDenial.assignmentIdMismatch,
      );
      expect(
        run(riderGeneration: 2).denial,
        DeliveryProofAssessmentDenial.generationMismatch,
      );
    });

    test('custody bound to a different rider attempt is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        custody: withRider(assignmentId: rideAsgB),
      );
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.custodyHolderBindingMismatch,
      );
      expect(o.transition, isNull);
    });

    test('possession alone is not authorization', () {
      // Custody with the right rider is a context fact. It does not make that
      // rider an assessor.
      final DeliveryProofAssessmentOutcome o = run(
        assessor: humanPrincipal(riderA),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.assessorNotSystemWorker);
      expect(o.transition, isNull);
    });
  });

  group('resource, policy and evidence binding is exact', () {
    test('aggregates about a different order are refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          resourceId: otherOrderId,
          evidence: const DeliveryEvidenceRef(
            resourceId: otherOrderId,
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('an assessment aggregate for another order is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        assessment: const DeliveryProofAssessmentFacts.absent(
          resourceId: otherOrderId,
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('a malformed canonical resource is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          resourceId: 'short',
          evidence: const DeliveryEvidenceRef(
            resourceId: 'short',
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('a malformed policy reference is refused, with the D1 reason', () {
      final DeliveryProofAssessmentOutcome blank = run(
        context: ctx(policy: const DeliveryProofPolicyRef('   ')),
      );
      expect(blank.denial, DeliveryProofAssessmentDenial.policyRefInvalid);
      expect(blank.structuralDenial, DeliveryProofDenial.policyRefBlank);

      final DeliveryProofAssessmentOutcome long = run(
        context: ctx(
          policy: DeliveryProofPolicyRef(
            'p' * (maxDeliveryProofPolicyRefLength + 1),
          ),
        ),
      );
      expect(long.denial, DeliveryProofAssessmentDenial.policyRefInvalid);
      expect(long.structuralDenial, DeliveryProofDenial.policyRefTooLong);
      expect(blank.transition, isNull);
      expect(long.transition, isNull);
    });

    test('the D1 policy bound is reused, not re-stated', () {
      final DeliveryProofAssessmentOutcome atLimit = run(
        context: ctx(
          policy: DeliveryProofPolicyRef('p' * maxDeliveryProofPolicyRefLength),
        ),
      );
      expect(atLimit.allowed, isTrue);
      expect(maxDeliveryProofPolicyRefLength, maxIdLength);
    });

    test('a malformed evidence reference is refused, with the D1 reason', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          evidence: const DeliveryEvidenceRef(
            resourceId: orderId,
            evidenceId: 'evd_short',
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.evidenceRefInvalid);
      expect(o.structuralDenial, DeliveryProofDenial.evidenceIdInvalid);
      expect(o.transition, isNull);
    });

    test('cross-resource evidence is refused and stays distinguishable', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          evidence: const DeliveryEvidenceRef(
            resourceId: otherOrderId,
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.evidenceResourceMismatch,
        reason: 'evidence is not portable between orders',
      );
      expect(o.structuralDenial, DeliveryProofDenial.evidenceResourceMismatch);
      expect(o.transition, isNull);
    });

    test('D1 remains the single source of structural judgement', () {
      const DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: otherOrderId,
        evidenceId: evidenceA,
      );
      expect(
        run(context: ctx(evidence: bad)).structuralDenial,
        validateDeliveryEvidenceRef(bad, resourceId: orderId),
      );
    });
  });
}
