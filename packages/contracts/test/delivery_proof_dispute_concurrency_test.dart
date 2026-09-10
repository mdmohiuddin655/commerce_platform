import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('compare-and-set on every aggregate the decision reads', () {
    test('a stale dispute revision is refused', () {
      expect(
        runRaise(expectedDisputeRevision: 1).denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
      expect(
        runReview(expectedDisputeRevision: 0).denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
      expect(
        runReview(expectedDisputeRevision: 2).denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
    });

    test('a stale order revision is refused on RAISE', () {
      // Raising *depends* on the order still being in flight, so acting on a
      // stale view of it is refused rather than silently recorded.
      expect(
        runRaise(expectedOrderRevision: 4).denial,
        DeliveryProofDisputeDenial.orderRevisionConflict,
      );
    });

    test('a stale assessment revision is refused on raise', () {
      expect(
        runRaise(
          assessment: assessed(revision: 2, assessmentId: asmtB),
          expectedAssessmentRevision: 1,
        ).denial,
        DeliveryProofDisputeDenial.assessmentRevisionConflict,
      );
      expect(
        runRaise(assessment: absentAssessment, expectedAssessmentRevision: 1)
            .denial,
        DeliveryProofDisputeDenial.assessmentRevisionConflict,
      );
    });

    test('review carries only the revision it can honestly compare', () {
      // *(Corrected by FND-003D2B-FIX-001.)* The review request no longer has
      // an assessment revision **or an order revision** to pin: the operation
      // reads neither aggregate, so a compare-and-set on either would be
      // meaningless. The fields are absent from the type rather than ignored.
      final DeliveryProofDisputeReviewRequest review =
          DeliveryProofDisputeReviewRequest(
            disputeId: disputeA,
            atUtc: reviewedAt,
            expectedDisputeRevision: 1,
          );
      expect(review.expectedDisputeRevision, 1);
      expect(review.disputeId, disputeA);
      expect(review.atUtc.isUtc, isTrue);

      // Raising still pins everything it depends on.
      final DeliveryProofDisputeRaiseRequest raiseRequest =
          DeliveryProofDisputeRaiseRequest(
            disputeId: disputeA,
            atUtc: raisedAt,
            expectedDisputeRevision: 0,
            expectedAssessmentRevision: 0,
            expectedOrderRevision: 5,
          );
      expect(raiseRequest.expectedAssessmentRevision, 0);
      expect(raiseRequest.expectedOrderRevision, 5);
    });

    test('correct revisions never bypass an identity or eligibility check', () {
      // Every expectation matches current facts, and the operation is still
      // refused. Revisions run in addition to the other checks, not instead.
      expect(
        runRaise(
          assessment: assessed(
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          ),
        ).denial,
        DeliveryProofDisputeDenial.assessmentSatisfied,
      );
      expect(
        runReview(disputeId: disputeB).denial,
        DeliveryProofDisputeDenial.disputeIdMismatch,
      );
      expect(
        runReview(dispute: reviewedDispute(), expectedDisputeRevision: 2).denial,
        DeliveryProofDisputeDenial.disputeNotOpen,
      );
    });
  });

  group('duplicate and reordered intent', () {
    test('a replayed raise against fresh facts conflicts, and writes nothing',
        () {
      final DeliveryProofDisputeTransition first = allowedDispute(runRaise());
      final DeliveryProofDisputeFacts after = applyDispute(first);

      // The same request arriving twice: the caller still believes revision 0.
      final DeliveryProofDisputeOutcome replay = runRaise(
        dispute: after,
        expectedDisputeRevision: 0,
      );
      expect(
        replay.denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
      expect(replay.transition, isNull);

      // A retry that re-reads first is refused for the honest reason.
      expect(
        runRaise(dispute: after, expectedDisputeRevision: 1).denial,
        DeliveryProofDisputeDenial.disputeAlreadyOpen,
      );

      // The stored dispute is untouched by either attempt.
      expect(after.disputeRevision, 1);
      expect(after.current, first.record);
    });

    test('a replayed review conflicts once the first has been applied', () {
      final DeliveryProofDisputeFacts open = applyDispute(
        allowedDispute(runRaise()),
      );
      final DeliveryProofDisputeTransition reviewed = allowedDispute(
        runReview(dispute: open),
      );
      final DeliveryProofDisputeFacts after = applyDispute(reviewed);

      expect(
        runReview(dispute: after, expectedDisputeRevision: 1).denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
      expect(
        runReview(dispute: after, expectedDisputeRevision: 2).denial,
        DeliveryProofDisputeDenial.disputeNotOpen,
      );
      expect(after.disputeRevision, 2);
      expect(after.current, reviewed.record);
    });

    test('reordered arrival cannot review a dispute that does not exist yet',
        () {
      expect(
        runReview(dispute: noDispute, expectedDisputeRevision: 0).denial,
        DeliveryProofDisputeDenial.disputeNotFound,
      );
    });

    test('two concurrent raises from revision 0 cannot both commit', () {
      // Both callers read the same absent aggregate. The first wins; the second
      // is refused by compare-and-set — the pure contract's half of DPD4.
      final DeliveryProofDisputeTransition winner = allowedDispute(
        runRaise(disputeId: disputeA),
      );
      final DeliveryProofDisputeFacts after = applyDispute(winner);
      expect(
        runRaise(
          disputeId: disputeB,
          dispute: after,
          expectedDisputeRevision: 0,
        ).denial,
        DeliveryProofDisputeDenial.disputeRevisionConflict,
      );
    });

    test('the revision walk is exactly 0 -> 1 -> 2, with no gaps', () {
      final DeliveryProofDisputeTransition raiseT = allowedDispute(runRaise());
      expect(raiseT.resultingDisputeRevision, 1);
      expect(
        raiseT.resultingDisputeRevision,
        reachableDisputeRevisionFor(raiseT.resultingState),
      );
      final DeliveryProofDisputeTransition reviewT = allowedDispute(
        runReview(dispute: applyDispute(raiseT)),
      );
      expect(reviewT.resultingDisputeRevision, 2);
      expect(
        reviewT.resultingDisputeRevision,
        reachableDisputeRevisionFor(reviewT.resultingState),
      );
    });
  });

  group('the dispute revision is its own counter', () {
    test('unrelated assessment writes do not disturb the dispute revision', () {
      final DeliveryProofDisputeFacts open = applyDispute(
        allowedDispute(runRaise(assessment: assessed())),
      );
      // Three reassessments later, the dispute is still at revision 1 — and
      // since FND-003D2B-FIX-001 review does not even read the assessment, so
      // there is no reassessment to supply.
      final DeliveryProofDisputeOutcome outcome = runReview(dispute: open);
      expect(allowedDispute(outcome).resultingDisputeRevision, 2);
      expect(open.disputeRevision, 1);
    });

    test('the order revision is neither read into nor written by a dispute',
        () {
      final DeliveryProofDisputeTransition t = allowedDispute(
        runRaise(order: inDelivery(revision: 42), expectedOrderRevision: 42),
      );
      expect(t.resultingDisputeRevision, 1);
      expect(t.changesOrderState, isFalse);
    });
  });
}
