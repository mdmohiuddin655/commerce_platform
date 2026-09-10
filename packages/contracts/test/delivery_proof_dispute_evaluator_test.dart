import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('the three fallback situations', () {
    test('canonical absence: a dispute may be raised, basis notAssessed', () {
      final DeliveryProofDisputeTransition t = allowedDispute(
        runRaise(assessment: absentAssessment),
      );
      expect(t.command, DeliveryProofDisputeCommand.raise);
      expect(t.resultingState, DeliveryProofDisputeState.open);
      expect(t.resultingDisputeRevision, 1);
      expect(t.record.basis.kind, DeliveryProofDisputeBasisKind.notAssessed);
      expect(t.record.basis.assessmentId, isNull);
      expect(t.record.basis.assessmentRevision, 0);
      expect(t.record.raisedByPrincipalId, raiserId);
      expect(t.record.isWellFormed, isTrue);
    });

    test('current notSatisfied: the exact assessment is pinned', () {
      final DeliveryProofAssessmentFacts a = assessed(revision: 1);
      final DeliveryProofDisputeTransition t = allowedDispute(
        runRaise(assessment: a),
      );
      expect(t.record.basis.kind, DeliveryProofDisputeBasisKind.notSatisfied);
      expect(
        t.record.basis.identifiesAssessment(
          assessmentId: asmtA,
          assessmentRevision: 1,
        ),
        isTrue,
      );
    });

    test('superseded basis: review still works after reassessment', () {
      // Raised against A at revision 1...
      final DeliveryProofDisputeTransition raiseT = allowedDispute(
        runRaise(assessment: assessed()),
      );
      final DeliveryProofDisputeFacts afterRaise = applyDispute(raiseT);

      // ...then a trusted verifier appends B at revision 2.
      final DeliveryProofAssessmentFacts reassessed = assessed(
        assessmentId: asmtB,
        revision: 2,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
        supersedes: asmtA,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: afterRaise.canonicalBasis!,
          assessment: reassessed,
        ),
        DeliveryProofDisputeBasisStanding.superseded,
      );

      // Recording review must still be possible. The request cannot pin an
      // assessment revision, so a reassessment cannot freeze a dispute out of
      // review.
      final DeliveryProofDisputeTransition reviewT = allowedDispute(
        runReview(dispute: afterRaise, assessment: reassessed),
      );
      expect(reviewT.resultingState, DeliveryProofDisputeState.underReview);
      // ...and the basis is carried forward unchanged.
      expect(reviewT.record.basis, raiseT.record.basis);
      expect(
        reviewT.record.basis.identifiesAssessment(
          assessmentId: asmtA,
          assessmentRevision: 1,
        ),
        isTrue,
        reason: 'the superseded assessment stays historically identifiable',
      );
    });
  });

  group('the five situations stay distinct', () {
    test('satisfied is not a fallback ground', () {
      expect(
        runRaise(
          assessment: assessed(
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          ),
        ).denial,
        DeliveryProofDisputeDenial.assessmentSatisfied,
      );
    });

    test('a torn assessment never becomes a negative basis', () {
      // The single most important negative in this slice: corruption must not
      // be laundered into `notSatisfied` and then into a valid dispute.
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        final DeliveryProofDisputeOutcome outcome = runRaise(
          assessment: tornAssessment(verdict: v),
        );
        expect(
          outcome.denial,
          DeliveryProofDisputeDenial.assessmentAggregateInconsistent,
        );
        expect(outcome.transition, isNull);
      }
    });

    test('a torn assessment denial is distinct from every other', () {
      // "we could not read the assessment", "the assessment says satisfied",
      // "nothing was assessed" and "the dispute aggregate is broken" are four
      // different failures and keep four different denials.
      expect(
        runRaise(assessment: tornAssessment()).denial,
        DeliveryProofDisputeDenial.assessmentAggregateInconsistent,
      );
      expect(
        runRaise(
          assessment: assessed(
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          ),
        ).denial,
        DeliveryProofDisputeDenial.assessmentSatisfied,
      );
      expect(
        runRaise(
          dispute: DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 1,
            current: disputeRecord(disputeId: 'short'),
          ),
        ).denial,
        DeliveryProofDisputeDenial.disputeAggregateInconsistent,
      );
      expect(allowedDispute(runRaise()).record.basis.kind,
          DeliveryProofDisputeBasisKind.notAssessed);
    });

    test('a torn ORDER aggregate keeps its own denial', () {
      expect(
        runRaise(
          order: inDelivery(reservation: ReservationState.released),
        ).denial,
        DeliveryProofDisputeDenial.orderAggregateInconsistent,
        reason: 'in_delivery pairs only with committed — this is corruption',
      );
    });
  });

  group('resource binding', () {
    test('a malformed canonical resource fails closed', () {
      expect(
        runRaise(
          context: const DeliveryProofDisputeContext(resourceId: 'short'),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
      expect(
        runRaise(
          context: const DeliveryProofDisputeContext(resourceId: ''),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
    });

    test('a dispute aggregate for another order is refused', () {
      expect(
        runRaise(
          dispute: const DeliveryProofDisputeFacts.absent(
            resourceId: otherOrderId,
          ),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
    });

    test('mixed-resource assessment facts are refused', () {
      // Order A's dispute must never be raised against order B's assessment
      // history, even when that history is perfectly canonical.
      expect(
        runRaise(
          assessment: const DeliveryProofAssessmentFacts.absent(
            resourceId: otherOrderId,
          ),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
      expect(
        runRaise(assessment: assessed(resourceId: otherOrderId)).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
    });

    test('two aggregates agreeing with each other is not enough', () {
      // Both aggregates describe order B; the canonical context says order A.
      expect(
        evaluateDeliveryProofDispute(
          request: DeliveryProofDisputeRequest.raise(
            disputeId: disputeA,
            atUtc: raisedAt,
            expectedDisputeRevision: 0,
            expectedAssessmentRevision: 0,
            expectedOrderRevision: 5,
          ),
          actor: customer(),
          context: disputeContext,
          dispute: const DeliveryProofDisputeFacts.absent(
            resourceId: otherOrderId,
          ),
          assessment: const DeliveryProofAssessmentFacts.absent(
            resourceId: otherOrderId,
          ),
          order: inDelivery(),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
    });
  });

  group('the order must be in flight', () {
    test('every other reachable order state is refused', () {
      for (final OrderState s in <OrderState>[
        OrderState.placed,
        OrderState.accepted,
        OrderState.preparing,
        OrderState.ready,
        OrderState.rejected,
        OrderState.cancelled,
      ]) {
        final OrderLifecycleFacts facts = orderFacts(
          state: s,
          revision: 4,
          reservation: switch (s) {
            OrderState.placed => ReservationState.active,
            OrderState.rejected || OrderState.cancelled =>
              ReservationState.released,
            _ => ReservationState.committed,
          },
        );
        expect(
          runRaise(order: facts).denial,
          DeliveryProofDisputeDenial.orderNotInDelivery,
          reason: 'no dispute may be raised from $s',
        );
      }
    });

    test('an absent order is refused, never treated as dispatched', () {
      expect(
        runRaise(order: const OrderLifecycleFacts.absent()).denial,
        DeliveryProofDisputeDenial.orderNotInDelivery,
      );
    });
  });

  group('raise identity and uniqueness', () {
    test('a malformed dispute id is refused', () {
      for (final String bad in <String>['', 'short', '1234567890123456']) {
        expect(
          runRaise(disputeId: bad).denial,
          DeliveryProofDisputeDenial.disputeIdInvalid,
          reason: '"$bad" is not a canonical opaque id',
        );
      }
    });

    test('at most one live dispute per order', () {
      expect(
        runRaise(
          dispute: openDispute(),
          expectedDisputeRevision: 1,
        ).denial,
        DeliveryProofDisputeDenial.disputeAlreadyOpen,
      );
      expect(
        runRaise(
          dispute: reviewedDispute(),
          expectedDisputeRevision: 2,
        ).denial,
        DeliveryProofDisputeDenial.disputeAlreadyOpen,
      );
    });

    test('a second dispute cannot reuse or replace the first id', () {
      expect(
        runRaise(
          disputeId: disputeA,
          dispute: openDispute(),
          expectedDisputeRevision: 1,
        ).denial,
        DeliveryProofDisputeDenial.disputeAlreadyOpen,
      );
      expect(
        runRaise(
          disputeId: disputeB,
          dispute: openDispute(),
          expectedDisputeRevision: 1,
        ).denial,
        DeliveryProofDisputeDenial.disputeAlreadyOpen,
      );
    });
  });

  group('recording that review started', () {
    test('advances an open dispute and records who and when', () {
      final DeliveryProofDisputeTransition t = allowedDispute(runReview());
      expect(t.command, DeliveryProofDisputeCommand.recordReviewStarted);
      expect(t.resultingState, DeliveryProofDisputeState.underReview);
      expect(t.resultingDisputeRevision, 2);
      expect(t.record.reviewStartedByPrincipalId, adminId);
      expect(t.record.reviewStartedAtUtc, reviewedAt);
      expect(t.record.isWellFormed, isTrue);
      expect(t.isRaise, isFalse);
    });

    test('a missing dispute is never invented', () {
      expect(
        runReview(dispute: noDispute, expectedDisputeRevision: 0).denial,
        DeliveryProofDisputeDenial.disputeNotFound,
      );
    });

    test('a different dispute id is refused', () {
      expect(
        runReview(disputeId: disputeB).denial,
        DeliveryProofDisputeDenial.disputeIdMismatch,
      );
    });

    test('a malformed dispute id is refused before any comparison', () {
      expect(
        runReview(disputeId: 'short').denial,
        DeliveryProofDisputeDenial.disputeIdInvalid,
      );
    });

    test('an already reviewed dispute is not reviewed again', () {
      expect(
        runReview(
          dispute: reviewedDispute(),
          expectedDisputeRevision: 2,
        ).denial,
        DeliveryProofDisputeDenial.disputeNotOpen,
      );
    });

    test('review cannot be recorded before the raise', () {
      expect(
        runReview(at: raisedAt.subtract(const Duration(seconds: 1))).denial,
        DeliveryProofDisputeDenial.reviewTimestampPrecedesRaise,
      );
      // Simultaneous is accepted: this orders two values and invents no window.
      expect(allowedDispute(runReview(at: raisedAt)).record.isWellFormed, isTrue);
    });
  });

  group('resolution is a real edge with undecided policy', () {
    test('it is refused, and refused distinctly', () {
      final DeliveryProofDisputeOutcome outcome = runResolve();
      expect(
        outcome.denial,
        DeliveryProofDisputeDenial.resolutionPolicyDeferred,
      );
      expect(outcome.transition, isNull);
      expect(outcome.allowed, isFalse);
      expect(
        outcome.isPolicyDeferred,
        isTrue,
        reason: '"not decided yet" must be distinguishable from "not allowed"',
      );
      // Every other denial is a refusal, not a deferral.
      expect(runReview(disputeId: disputeB).isPolicyDeferred, isFalse);
    });

    test('it is refused before any fact is read', () {
      // Identical denial whatever the facts look like: perfect, absent, torn,
      // wrong resource, stale. A deferred edge must not leak a partial
      // evaluation of itself.
      for (final DeliveryProofDisputeOutcome outcome
          in <DeliveryProofDisputeOutcome>[
        runResolve(),
        runResolve(dispute: noDispute),
        runResolve(actor: worker()),
        runResolve(order: const OrderLifecycleFacts.absent()),
        runResolve(assessment: tornAssessment()),
        runResolve(
          context: const DeliveryProofDisputeContext(resourceId: 'short'),
        ),
        runResolve(dispute: reviewedDispute()),
      ]) {
        expect(
          outcome.denial,
          DeliveryProofDisputeDenial.resolutionPolicyDeferred,
        );
      }
    });

    test('no executable command can reach the resolved state', () {
      expect(
        DeliveryProofDisputeCommand.executableInThisSlice,
        <DeliveryProofDisputeCommand>{
          DeliveryProofDisputeCommand.raise,
          DeliveryProofDisputeCommand.recordReviewStarted,
        },
      );
      expect(
        DeliveryProofDisputeCommand.policyDeferredInThisSlice,
        <DeliveryProofDisputeCommand>{DeliveryProofDisputeCommand.resolve},
      );
      // The two sets partition the enum.
      expect(
        <DeliveryProofDisputeCommand>{
          ...DeliveryProofDisputeCommand.executableInThisSlice,
          ...DeliveryProofDisputeCommand.policyDeferredInThisSlice,
        },
        DeliveryProofDisputeCommand.values.toSet(),
      );
      for (final DeliveryProofDisputeOutcome outcome
          in <DeliveryProofDisputeOutcome>[runRaise(), runReview()]) {
        expect(
          allowedDispute(outcome).resultingState,
          isNot(DeliveryProofDisputeState.resolved),
        );
      }
    });
  });

  group('every allowed transition is coherent', () {
    test('an allow always wraps a well-formed record and one event', () {
      for (final DeliveryProofDisputeOutcome outcome
          in <DeliveryProofDisputeOutcome>[
        runRaise(),
        runRaise(assessment: assessed()),
        runReview(),
      ]) {
        final DeliveryProofDisputeTransition t = allowedDispute(outcome);
        expect(t.record.isWellFormed, isTrue);
        expect(t.record.belongsToResource(orderId), isTrue);
        expect(t.events.length, 1);
        expect(
          validateDeliveryProofDisputeAggregate(applyDispute(t)),
          isNull,
          reason: 'applying a transition must yield a canonical aggregate',
        );
      }
    });

    test('a denial produces no transition and no event, always', () {
      for (final DeliveryProofDisputeOutcome outcome
          in <DeliveryProofDisputeOutcome>[
        runRaise(disputeId: 'short'),
        runRaise(assessment: tornAssessment()),
        runRaise(
          assessment: assessed(
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          ),
        ),
        runRaise(order: const OrderLifecycleFacts.absent()),
        runRaise(actor: worker()),
        runReview(dispute: noDispute, expectedDisputeRevision: 0),
        runResolve(),
      ]) {
        expect(outcome.allowed, isFalse);
        expect(outcome.transition, isNull);
        expect(outcome.denial, isNotNull);
      }
    });
  });
}
