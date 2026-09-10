import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('every commercial effect is NONE', () {
    test('for both executable operations, in every field', () {
      for (final DeliveryProofDisputeTransition t
          in <DeliveryProofDisputeTransition>[
        allowedDispute(runRaise()),
        allowedDispute(runRaise(assessment: assessed())),
        allowedDispute(runReview()),
      ]) {
        expect(t.inventoryEffect.kind, InventoryEffectKind.none);
        expect(t.inventoryEffect.availableStockDelta, 0);
        expect(t.inventoryEffect.units, 0);
        expect(
          t.financialClassification,
          FinancialClassification.noneInThisSlice,
        );
        expect(t.scopeEffect.addToOffered, isEmpty);
        expect(t.scopeEffect.removeFromOffered, isEmpty);
        expect(t.scopeEffect.addToAssigned, isEmpty);
        expect(t.scopeEffect.removeFromAssigned, isEmpty);
        expect(t.changesOrderState, isFalse);
        expect(t.changesCustody, isFalse);
        expect(t.changesRiderAssignment, isFalse);
        expect(t.changesAssessment, isFalse);
      }
    });

    test('a dispute restores no stock', () {
      // CONSTRAINTS invariant 12: stock cannot become available again until the
      // return lifecycle proves shop receipt AND inspection. A dispute is not
      // a return, and does not start one.
      expect(
        allowedDispute(runRaise()).inventoryEffect.availableStockDelta,
        0,
      );
      expect(allowedDispute(runReview()).inventoryEffect.availableStockDelta, 0);
    });

    test('being in dispute is not permission, in either direction', () {
      // No scope projection changes, so nothing gains or loses read access
      // because a dispute exists.
      final ScopeProjectionEffect e = allowedDispute(runRaise()).scopeEffect;
      expect(e.addToAssigned, isEmpty);
      expect(e.removeFromAssigned, isEmpty);
    });
  });

  group('nothing about the delivery moves', () {
    test('the order, custody and rider aggregates are not even read into an '
        'effect', () {
      final DeliveryProofDisputeTransition t = allowedDispute(runRaise());
      // There is no order/custody/assignment effect field to inspect, which is
      // the point: a transition that moved one could not be constructed. The
      // booleans below are the observable consequence of that absence.
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
    });

    test('delivered, customer custody and rider completion stay unreachable',
        () {
      expect(OrderState.notYetImplemented, <OrderState>{OrderState.delivered});
      expect(
        OrderState.executableInThisSlice.contains(OrderState.delivered),
        isFalse,
      );
      expect(
        OrderState.aggregateShapeKnown.contains(OrderState.delivered),
        isFalse,
      );
      expect(CustodyHolderKind.notYetImplemented, <CustodyHolderKind>{
        CustodyHolderKind.customer,
      });
      expect(
        CustodyHolderKind.executableInThisSlice.contains(
          CustodyHolderKind.customer,
        ),
        isFalse,
      );
      expect(
        AssignmentState.notYetImplementedForRole(AssignmentRole.rider),
        <AssignmentState>{AssignmentState.completed},
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
        reason: 'B3-C2 stays FUTURE — no rider completion cost was invented',
      );
    });

    test('no dispute outcome can be read as permission to deliver', () {
      // The strongest statement any transition here makes is "a dispute was
      // recorded", and the only states reachable are `open` and `underReview`.
      for (final DeliveryProofDisputeTransition t
          in <DeliveryProofDisputeTransition>[
        allowedDispute(runRaise()),
        allowedDispute(runReview()),
      ]) {
        expect(t.resultingState.isOpenForReview, isTrue);
        expect(t.resultingState, isNot(DeliveryProofDisputeState.resolved));
      }
    });
  });

  group('the assessment is untouched by every dispute action', () {
    test('raising and reviewing leave the assessment aggregate identical', () {
      final DeliveryProofAssessmentFacts before = assessed();
      final DeliveryProofAssessmentRecord? recordBefore = before.current;

      final DeliveryProofDisputeTransition raiseT = allowedDispute(
        runRaise(assessment: before),
      );
      // Review does not even receive the assessment since FND-003D2B-FIX-001,
      // which is the strongest form of "untouched" available.
      final DeliveryProofDisputeTransition reviewT = allowedDispute(
        runReview(dispute: applyDispute(raiseT)),
      );

      // Same object, same revision, same verdict, same everything.
      expect(identical(before.current, recordBefore), isTrue);
      expect(before.assessmentRevision, 1);
      expect(before.current!.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(before.canonicalVerdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(validateDeliveryProofAssessmentAggregate(before), isNull);
      expect(raiseT.changesAssessment, isFalse);
      expect(reviewT.changesAssessment, isFalse);
    });

    test('a dispute never supersedes, relabels or erases an assessment', () {
      final DeliveryProofAssessmentFacts before = assessed();
      final DeliveryProofDisputeTransition t = allowedDispute(
        runRaise(assessment: before),
      );
      // The dispute points AT the assessment; it does not contain or replace
      // it. The record on the dispute side carries an id and a revision, and no
      // verdict copy that could drift.
      expect(t.record.basis.assessmentId, before.current!.assessmentId);
      expect(t.record.basis.assessmentRevision, before.assessmentRevision);
      expect(before.current!.supersedesAssessmentId, isNull);
      expect(
        applyDispute(t).canonicalBasis!.identifiesAssessment(
          assessmentId: asmtA,
          assessmentRevision: 1,
        ),
        isTrue,
      );
    });
  });

  group('events', () {
    test('exactly two ids exist, and neither names an outcome', () {
      expect(DeliveryProofDisputeEventType.all.length, 2);
      expect(DeliveryProofDisputeEventType.all, <String>[
        'delivery.proof_dispute_raised',
        'delivery.proof_dispute_review_started',
      ]);
      for (final String e in DeliveryProofDisputeEventType.all) {
        for (final String forbidden in <String>[
          'resolved',
          'upheld',
          'closed',
          'refund',
          'settled',
          'delivered',
          'cancelled',
        ]) {
          expect(e, isNot(contains(forbidden)));
        }
      }
    });

    test('each operation emits exactly its own event, not selectable', () {
      expect(allowedDispute(runRaise()).events, <String>[
        DeliveryProofDisputeEventType.disputeRaised,
      ]);
      expect(allowedDispute(runReview()).events, <String>[
        DeliveryProofDisputeEventType.disputeReviewStarted,
      ]);
    });

    test('the event list is deeply immutable', () {
      expect(
        () => allowedDispute(runRaise()).events.add('delivery.proof_dispute_resolved'),
        throwsUnsupportedError,
      );
      expect(
        () => DeliveryProofDisputeEventType.all.add('anything'),
        throwsUnsupportedError,
      );
    });

    test('a denial emits nothing at all', () {
      for (final DeliveryProofDisputeOutcome o in <DeliveryProofDisputeOutcome>[
        runResolve(),
        runRaise(assessment: tornAssessment()),
        runReview(dispute: noDispute, expectedDisputeRevision: 0),
      ]) {
        expect(o.transition, isNull);
        expect(o.allowed, isFalse);
      }
    });
  });
}
