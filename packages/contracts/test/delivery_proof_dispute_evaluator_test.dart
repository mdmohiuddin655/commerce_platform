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

      // Recording review must still be possible. Since FND-003D2B-FIX-001 the
      // operation does not read the assessment at all, so a reassessment
      // cannot freeze a dispute out of review — there is no assessment
      // argument left to pass.
      final DeliveryProofDisputeTransition reviewT = allowedDispute(
        runReview(dispute: afterRaise),
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
          order: orderRead(reservation: ReservationState.released),
        ).denial,
        DeliveryProofDisputeDenial.orderAggregateInconsistent,
        reason: 'in_delivery pairs only with committed — this is corruption',
      );
    });
  });

  group('resource binding', () {
    test('a grant naming a malformed resource fails closed', () {
      // *(Comment corrected by FND-003D2B-FIX-006; the assertions are
      // unchanged.)* The **stored dispute aggregate remains the operation
      // resource anchor** — the grant is never the source used to choose it.
      //
      // A grant may perfectly well name a different, or a malformed,
      // authorized resource: that is a fact about what the actor was
      // authorized for, not about which order is being acted on. Such a grant
      // simply cannot satisfy `covers` against the independently anchored
      // stored-dispute resource, so it is refused — here, before any fact is
      // read, because a resource that is not a canonical opaque id could not
      // be compared at all.
      for (final String bad in <String>['short', '']) {
        final AuthorizationGrant badGrant = disputeGrant(
          permission: Permission.customerRaiseDispute,
          principalId: raiserId,
          role: CommerceRole.customer,
          resourceId: bad,
        );
        expect(badGrant.resourceId, bad);
        expect(
          runRaise(grant: badGrant).denial,
          DeliveryProofDisputeDenial.authorizationGrantMismatch,
        );
      }
    });

    test('a dispute aggregate for another order is refused', () {
      // *(Denial updated by FND-003D2B-FIX-003.)* The canonical resource is now
      // the stored dispute's, and the grant must **cover** it — so presenting
      // order B's dispute under order A's grant is caught at the authorization
      // boundary rather than one step later. Earlier, not later, and generic.
      expect(
        runRaise(
          dispute: const DeliveryProofDisputeFacts.absent(
            resourceId: otherOrderId,
          ),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
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

    test('an order read from another resource is refused — FIX-003', () {
      // **The defect this closes.** `OrderLifecycleFacts` carries no resource
      // id, so before FND-003D2B-FIX-003 an order-B read was indistinguishable
      // from order A's own facts and a dispute could be recorded against A on
      // the strength of B's lifecycle.
      //
      // Grant A + dispute A + assessment A + order read **B**, with B's
      // lifecycle scalars **identical** to A's, so numeric equality cannot hide
      // the missing binding.
      final DeliveryProofDisputeOrderRead readOfA = orderRead(
        resourceId: orderId,
        revision: 5,
      );
      final DeliveryProofDisputeOrderRead readOfB = orderRead(
        resourceId: otherOrderId,
        revision: 5,
      );
      // The two reads differ in exactly one thing: which order they are for.
      expect(readOfA.order.state, readOfB.order.state);
      expect(readOfA.order.revision, readOfB.order.revision);
      expect(readOfA.order.reservationState, readOfB.order.reservationState);
      expect(readOfA.resourceId, isNot(readOfB.resourceId));

      final DeliveryProofDisputeOutcome outcome = runRaise(order: readOfB);
      expect(
        outcome.denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
      expect(
        outcome.transition,
        isNull,
        reason: 'denied before any transition is constructed',
      );

      // ...and the otherwise identical read of A is allowed, so the refusal is
      // the binding and not the facts.
      expect(
        allowedDispute(runRaise(order: readOfA)).record.resourceId,
        orderId,
      );
    });

    test('a malformed order-read resource fails closed', () {
      for (final String bad in <String>['', 'short', '1234567890123456']) {
        final DeliveryProofDisputeOutcome outcome = runRaise(
          order: orderRead(resourceId: bad),
        );
        expect(
          outcome.denial,
          DeliveryProofDisputeDenial.resourceBindingMismatch,
          reason: '"$bad" is not a canonical opaque id',
        );
        expect(outcome.transition, isNull);
      }
      // Two identically-malformed values must not match their way to a bind.
      expect(
        DeliveryProofDisputeOrderRead(
          resourceId: '',
          order: inDelivery(),
        ).belongsToResource(''),
        isFalse,
      );
    });

    test('a wrong grant resource is not rescued by matching order scalars', () {
      // Every scalar the order carries matches, and the dispute is canonical —
      // but the actor was authorized for a different order.
      expect(
        runRaise(
          grant: customerRaiseGrant(resourceId: otherOrderId),
          order: orderRead(revision: 5),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
    });

    test('a whole read-set agreeing with itself is not enough', () {
      // Dispute, assessment and order read all describe order B, and they are
      // internally consistent. The **grant** is for order A, so the actor was
      // never authorized to act on the order these facts are about.
      expect(
        evaluateRaiseDeliveryProofDispute(
          request: DeliveryProofDisputeRaiseRequest(
            disputeId: disputeA,
            atUtc: raisedAt,
            expectedDisputeRevision: 0,
            expectedAssessmentRevision: 0,
            expectedOrderRevision: 5,
          ),
          actor: customer(),
          grant: customerRaiseGrant(),
          dispute: const DeliveryProofDisputeFacts.absent(
            resourceId: otherOrderId,
          ),
          assessment: const DeliveryProofAssessmentFacts.absent(
            resourceId: otherOrderId,
          ),
          order: orderRead(resourceId: otherOrderId),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
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
          runRaise(order: orderRead(order: facts)).denial,
          DeliveryProofDisputeDenial.orderNotInDelivery,
          reason: 'no dispute may be raised from $s',
        );
      }
    });

    test('an absent order is refused, never treated as dispatched', () {
      expect(
        runRaise(order: orderRead(order: const OrderLifecycleFacts.absent())).denial,
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

  group('review depends on the dispute alone — FND-003D2B-FIX-001', () {
    /// A dispute raised against a healthy read-set, then applied.
    DeliveryProofDisputeFacts validlyRaised() =>
        applyDispute(allowedDispute(runRaise(assessment: assessed())));

    test('the operation cannot read the assessment or the order at all', () {
      // Structural, not behavioural: `evaluateRecordDeliveryProofDisputeReview`
      // has no assessment or order parameter, so no state of either can gate
      // it. This is the shape the correction is really about.
      final DeliveryProofDisputeFacts open = validlyRaised();
      final DeliveryProofDisputeOutcome outcome =
          evaluateRecordDeliveryProofDisputeReview(
            request: DeliveryProofDisputeReviewRequest(
              disputeId: disputeA,
              atUtc: reviewedAt,
              expectedDisputeRevision: 1,
            ),
            actor: admin(),
            grant: adminAdministerGrant(),
            dispute: open,
          );
      expect(allowedDispute(outcome).resultingState,
          DeliveryProofDisputeState.underReview);
    });

    test('a reassessment after the raise cannot freeze review', () {
      final DeliveryProofDisputeFacts open = validlyRaised();
      // The world moved: the verifier appended a new assessment, and it even
      // concluded `satisfied`. The dispute is still reviewable — deciding
      // otherwise would be deciding the outcome.
      final DeliveryProofAssessmentFacts reassessed = assessed(
        assessmentId: asmtB,
        revision: 2,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
        supersedes: asmtA,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: open.canonicalBasis!,
          assessment: reassessed,
        ),
        DeliveryProofDisputeBasisStanding.superseded,
      );
      expect(allowedDispute(runReview(dispute: open)).resultingState,
          DeliveryProofDisputeState.underReview);
    });

    test('a torn assessment read after the raise cannot freeze review', () {
      // The case the shared read-set got wrong: the assessment aggregate is
      // unusable, so a raise would rightly be refused — but an ALREADY VALID
      // dispute must still be reviewable. A fallback that stops working when
      // the thing it is a fallback for breaks is not a fallback.
      final DeliveryProofDisputeFacts open = validlyRaised();
      expect(
        runRaise(assessment: tornAssessment()).denial,
        DeliveryProofDisputeDenial.assessmentAggregateInconsistent,
        reason: 'raising still depends on a readable assessment',
      );
      expect(allowedDispute(runReview(dispute: open)).resultingState,
          DeliveryProofDisputeState.underReview);
    });

    test('unrelated order movement after the raise cannot freeze review', () {
      // A raise from these order facts would be refused; review is unaffected,
      // because it neither reads nor changes the order.
      final DeliveryProofDisputeFacts open = validlyRaised();
      expect(
        runRaise(order: orderRead(revision: 99), expectedOrderRevision: 5)
            .denial,
        DeliveryProofDisputeDenial.orderRevisionConflict,
      );
      expect(
        runRaise(order: orderRead(order: const OrderLifecycleFacts.absent())).denial,
        DeliveryProofDisputeDenial.orderNotInDelivery,
      );
      expect(allowedDispute(runReview(dispute: open)).resultingState,
          DeliveryProofDisputeState.underReview);
    });

    test('a torn or missing assessment after the raise cannot freeze review',
        () {
      // Re-pinned under FIX-002's grant requirement: the operation still takes
      // no assessment argument, so no state of it — reassessed, torn, or gone
      // — can gate review of an already valid dispute.
      final DeliveryProofDisputeFacts open = validlyRaised();
      for (final DeliveryProofAssessmentFacts _ in <DeliveryProofAssessmentFacts>[
        tornAssessment(),
        absentAssessment,
        assessed(assessmentId: asmtB, revision: 2, supersedes: asmtA),
      ]) {
        expect(
          allowedDispute(runReview(dispute: open)).resultingState,
          DeliveryProofDisputeState.underReview,
        );
      }
    });

    test('the review transition still changes only the dispute', () {
      final DeliveryProofDisputeFacts open = validlyRaised();
      final DeliveryProofDisputeTransition t = allowedDispute(
        runReview(dispute: open),
      );
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
      expect(t.changesAssessment, isFalse);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(t.resultingDisputeRevision, 2);
      // The basis and the raiser survive the edge untouched.
      expect(t.record.basis, open.current!.basis);
      expect(t.record.raisedByPrincipalId, open.current!.raisedByPrincipalId);
      expect(t.record.raisedAtUtc, open.current!.raisedAtUtc);
    });

    test('independence infers no delivery, refusal or return', () {
      // Being reviewable says only that review may begin.
      final DeliveryProofDisputeFacts open = validlyRaised();
      final DeliveryProofDisputeTransition t = allowedDispute(
        runReview(dispute: open),
      );
      expect(t.resultingState.isOpenForReview, isTrue);
      expect(t.resultingState, isNot(DeliveryProofDisputeState.resolved));
      expect(OrderState.notYetImplemented, <OrderState>{OrderState.delivered});
    });

    test('raise remains strictly pinned to the full read-set', () {
      // The correction must not loosen the operation that genuinely depends on
      // current facts.
      expect(
        runRaise(expectedAssessmentRevision: 7).denial,
        DeliveryProofDisputeDenial.assessmentRevisionConflict,
      );
      expect(
        runRaise(expectedOrderRevision: 7).denial,
        DeliveryProofDisputeDenial.orderRevisionConflict,
      );
      expect(
        runRaise(order: orderRead(reservation: ReservationState.released))
            .denial,
        DeliveryProofDisputeDenial.orderAggregateInconsistent,
      );
      expect(
        runRaise(assessment: tornAssessment()).denial,
        DeliveryProofDisputeDenial.assessmentAggregateInconsistent,
      );
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

    test('it cannot read a fact, because it takes none', () {
      // *(Strengthened by FND-003D2B-FIX-001.)* This used to assert that the
      // denial was identical whatever facts were supplied. The evaluator now
      // accepts **no arguments at all**, so a deferred edge cannot partially
      // evaluate anything even in principle — a structural statement rather
      // than a behavioural one.
      for (int i = 0; i < 3; i++) {
        final DeliveryProofDisputeOutcome outcome = runResolve();
        expect(
          outcome.denial,
          DeliveryProofDisputeDenial.resolutionPolicyDeferred,
        );
        expect(outcome.transition, isNull);
        expect(outcome.isPolicyDeferred, isTrue);
      }
      // The same call, reached directly through the public surface.
      expect(
        evaluateResolveDeliveryProofDispute().denial,
        DeliveryProofDisputeDenial.resolutionPolicyDeferred,
      );
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
        runRaise(order: orderRead(order: const OrderLifecycleFacts.absent())),
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
