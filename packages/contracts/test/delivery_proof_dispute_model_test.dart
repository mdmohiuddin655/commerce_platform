import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('dispute state vocabulary', () {
    test('exactly three values, and only two are executable', () {
      expect(DeliveryProofDisputeState.values.length, 3);
      expect(DeliveryProofDisputeState.executableInThisSlice, <
        DeliveryProofDisputeState
      >{
        DeliveryProofDisputeState.open,
        DeliveryProofDisputeState.underReview,
      });
      expect(DeliveryProofDisputeState.notYetImplemented, <
        DeliveryProofDisputeState
      >{DeliveryProofDisputeState.resolved});
      // The two sets partition the enum: nothing is silently unclassified.
      expect(
        <DeliveryProofDisputeState>{
          ...DeliveryProofDisputeState.executableInThisSlice,
          ...DeliveryProofDisputeState.notYetImplemented,
        },
        DeliveryProofDisputeState.values.toSet(),
      );
    });

    test('no outcome value exists in the vocabulary', () {
      // `upheld`, `rejected`, `refunded`, `withdrawn`, `closed` and friends
      // would each decide something no slice has decided.
      final List<String> ids = DeliveryProofDisputeState.values
          .map((DeliveryProofDisputeState s) => s.id)
          .toList();
      expect(ids, <String>['open', 'under_review', 'resolved']);
      for (final String id in ids) {
        for (final String forbidden in outcomeVocabulary) {
          expect(id, isNot(contains(forbidden)));
        }
      }
    });

    test('wire ids round-trip and Enum.index is never the wire form', () {
      for (final DeliveryProofDisputeState s
          in DeliveryProofDisputeState.values) {
        expect(DeliveryProofDisputeState.byId(s.id), s);
      }
      expect(DeliveryProofDisputeState.byId('upheld'), isNull);
      expect(DeliveryProofDisputeState.byId('0'), isNull);
    });

    test('both executable states are still awaiting an outcome', () {
      expect(DeliveryProofDisputeState.open.isOpenForReview, isTrue);
      expect(DeliveryProofDisputeState.underReview.isOpenForReview, isTrue);
      expect(DeliveryProofDisputeState.resolved.isOpenForReview, isFalse);
    });
  });

  group('reachable dispute revision', () {
    test('each executable state has exactly one reachable revision', () {
      expect(reachableDisputeRevisionFor(DeliveryProofDisputeState.open), 1);
      expect(
        reachableDisputeRevisionFor(DeliveryProofDisputeState.underReview),
        2,
      );
    });

    test('resolution has no revision cost, and none was invented', () {
      // The same discipline as rider `AssignmentState.completed` (B3-C2): a
      // state nobody implements gets no arithmetic, so every aggregate holding
      // it fails closed rather than being guessed at.
      expect(
        reachableDisputeRevisionFor(DeliveryProofDisputeState.resolved),
        isNull,
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
        reason: 'the precedent this follows is unchanged',
      );
    });
  });

  group('basis kinds', () {
    test('exactly the two fallback grounds, and superseded is not one', () {
      expect(DeliveryProofDisputeBasisKind.values.length, 2);
      expect(
        DeliveryProofDisputeBasisKind.values
            .map((DeliveryProofDisputeBasisKind k) => k.id)
            .toList(),
        <String>['not_assessed', 'not_satisfied'],
      );
      // Supersession is a *standing* computed against current facts, never a
      // kind frozen into immutable history.
      expect(DeliveryProofDisputeBasisKind.byId('superseded'), isNull);
      expect(DeliveryProofDisputeBasisKind.byId('satisfied'), isNull);
      expect(DeliveryProofDisputeBasisKind.byId('malformed'), isNull);
      for (final DeliveryProofDisputeBasisKind k
          in DeliveryProofDisputeBasisKind.values) {
        expect(DeliveryProofDisputeBasisKind.byId(k.id), k);
      }
    });

    test('absence and notSatisfied stay distinct, and neither is the other', () {
      const DeliveryProofDisputeBasis absent =
          DeliveryProofDisputeBasis.notAssessed(resourceId: orderId);
      const DeliveryProofDisputeBasis negative =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 1,
          );
      expect(absent.kind, DeliveryProofDisputeBasisKind.notAssessed);
      expect(absent.assessmentId, isNull);
      expect(absent.assessmentRevision, 0);
      expect(negative.kind, DeliveryProofDisputeBasisKind.notSatisfied);
      expect(absent, isNot(negative));
    });
  });

  group('basis structural integrity', () {
    test('the canonical shapes are well formed', () {
      expect(
        const DeliveryProofDisputeBasis.notAssessed(
          resourceId: orderId,
        ).isWellFormed,
        isTrue,
      );
      expect(
        const DeliveryProofDisputeBasis.notSatisfied(
          resourceId: orderId,
          assessmentId: asmtA,
          assessmentRevision: 3,
        ).isWellFormed,
        isTrue,
      );
    });

    test('a malformed resource, id or revision fails closed', () {
      for (final DeliveryProofDisputeBasis bad in <DeliveryProofDisputeBasis>[
        const DeliveryProofDisputeBasis.notAssessed(resourceId: ''),
        const DeliveryProofDisputeBasis.notAssessed(resourceId: '12345678901234567'),
        const DeliveryProofDisputeBasis.notSatisfied(
          resourceId: orderId,
          assessmentId: 'short',
          assessmentRevision: 1,
        ),
        const DeliveryProofDisputeBasis.notSatisfied(
          resourceId: orderId,
          assessmentId: asmtA,
          assessmentRevision: 0,
        ),
        const DeliveryProofDisputeBasis.notSatisfied(
          resourceId: orderId,
          assessmentId: asmtA,
          assessmentRevision: -1,
        ),
      ]) {
        expect(bad.isWellFormed, isFalse, reason: '$bad must fail closed');
      }
    });

    test('belongsToResource cannot be satisfied by two malformed values', () {
      // Raw equality alone would fail open — the FND-003D1 lesson, applied.
      const DeliveryProofDisputeBasis broken =
          DeliveryProofDisputeBasis.notAssessed(resourceId: '');
      expect(broken.belongsToResource(''), isFalse);
      const DeliveryProofDisputeBasis good =
          DeliveryProofDisputeBasis.notAssessed(resourceId: orderId);
      expect(good.belongsToResource(orderId), isTrue);
      expect(good.belongsToResource(otherOrderId), isFalse);
      expect(good.belongsToResource(''), isFalse);
    });

    test('identifiesAssessment fails closed in every direction', () {
      const DeliveryProofDisputeBasis negative =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 2,
          );
      expect(
        negative.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 2),
        isTrue,
      );
      // Wrong assessment, right revision.
      expect(
        negative.identifiesAssessment(assessmentId: asmtB, assessmentRevision: 2),
        isFalse,
      );
      // Right assessment, wrong revision.
      expect(
        negative.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 3),
        isFalse,
      );
      // A malformed argument never matches, even against a malformed basis.
      expect(
        negative.identifiesAssessment(assessmentId: '', assessmentRevision: 2),
        isFalse,
      );
      // An absence basis identifies NO assessment at all.
      const DeliveryProofDisputeBasis absent =
          DeliveryProofDisputeBasis.notAssessed(resourceId: orderId);
      expect(
        absent.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 1),
        isFalse,
      );
      expect(
        absent.identifiesAssessment(assessmentId: '', assessmentRevision: 0),
        isFalse,
      );
    });

    test('two identically-malformed values cannot match their way to true', () {
      // The precise shape raw equality would get wrong, and the reason
      // `bindsRiderAttempt` was hardened by FND-003D2A-FIX-001: a broken stored
      // id compared against an equally broken argument.
      const DeliveryProofDisputeBasis brokenId =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: '',
            assessmentRevision: 1,
          );
      expect(brokenId.isWellFormed, isFalse);
      expect(
        brokenId.identifiesAssessment(assessmentId: '', assessmentRevision: 1),
        isFalse,
        reason: 'raw equality would certify a broken basis here',
      );

      // The same failure through the revision instead of the id.
      const DeliveryProofDisputeBasis brokenRevision =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 0,
          );
      expect(brokenRevision.isWellFormed, isFalse);
      expect(
        brokenRevision.identifiesAssessment(
          assessmentId: asmtA,
          assessmentRevision: 0,
        ),
        isFalse,
        reason: 'revision 0 is canonical absence, never a negative result',
      );

      // ...and through the resource, which every other check depends on.
      const DeliveryProofDisputeBasis brokenResource =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: '',
            assessmentId: asmtA,
            assessmentRevision: 1,
          );
      expect(
        brokenResource.identifiesAssessment(
          assessmentId: asmtA,
          assessmentRevision: 1,
        ),
        isFalse,
      );
    });
  });

  group('dispute record structural integrity', () {
    test('a raised record is well formed and carries no reviewer', () {
      final DeliveryProofDisputeRecord r = DeliveryProofDisputeRecord.raised(
        disputeId: disputeA,
        resourceId: orderId,
        basis: const DeliveryProofDisputeBasis.notAssessed(resourceId: orderId),
        raisedByPrincipalId: raiserId,
        raisedAtUtc: raisedAt,
      );
      expect(r.isWellFormed, isTrue);
      expect(r.state, DeliveryProofDisputeState.open);
      expect(r.disputeRevision, 1);
      expect(r.reviewStartedByPrincipalId, isNull);
      expect(r.reviewStartedAtUtc, isNull);
      expect(r.hasDisputeId(disputeA), isTrue);
      expect(r.hasDisputeId(disputeB), isFalse);
      expect(r.belongsToResource(orderId), isTrue);
      expect(r.belongsToResource(otherOrderId), isFalse);
    });

    test('the review edge carries basis, raiser and raise time forward', () {
      final DeliveryProofDisputeRecord raisedRecord =
          DeliveryProofDisputeRecord.raised(
            disputeId: disputeA,
            resourceId: orderId,
            basis: const DeliveryProofDisputeBasis.notSatisfied(
              resourceId: orderId,
              assessmentId: asmtA,
              assessmentRevision: 1,
            ),
            raisedByPrincipalId: raiserId,
            raisedAtUtc: raisedAt,
          );
      final DeliveryProofDisputeRecord reviewed =
          DeliveryProofDisputeRecord.reviewStarted(
            previous: raisedRecord,
            reviewerPrincipalId: adminId,
            atUtc: reviewedAt,
          );
      expect(reviewed.isWellFormed, isTrue);
      expect(reviewed.disputeId, raisedRecord.disputeId);
      expect(reviewed.basis, raisedRecord.basis);
      expect(reviewed.raisedByPrincipalId, raisedRecord.raisedByPrincipalId);
      expect(reviewed.raisedAtUtc, raisedRecord.raisedAtUtc);
      expect(reviewed.disputeRevision, 2);
      expect(reviewed.state, DeliveryProofDisputeState.underReview);
      expect(reviewed.reviewStartedByPrincipalId, adminId);
      // The previous record object is untouched.
      expect(raisedRecord.state, DeliveryProofDisputeState.open);
      expect(raisedRecord.disputeRevision, 1);
    });

    test('state and fields must agree in both directions', () {
      // Open, but somebody is recorded as reviewing.
      expect(
        disputeRecord(
          reviewStartedByPrincipalId: adminId,
          reviewStartedAtUtc: reviewedAt,
        ).isWellFormed,
        isFalse,
      );
      // Under review, by nobody.
      expect(
        disputeRecord(
          disputeRevision: 2,
          state: DeliveryProofDisputeState.underReview,
        ).isWellFormed,
        isFalse,
      );
      // Under review with a reviewer but no timestamp.
      expect(
        disputeRecord(
          disputeRevision: 2,
          state: DeliveryProofDisputeState.underReview,
          reviewStartedByPrincipalId: adminId,
        ).isWellFormed,
        isFalse,
      );
    });

    test('the revision is pinned to the state', () {
      expect(disputeRecord(disputeRevision: 2).isWellFormed, isFalse);
      expect(disputeRecord(disputeRevision: 0).isWellFormed, isFalse);
      expect(
        disputeRecord(
          disputeRevision: 3,
          state: DeliveryProofDisputeState.underReview,
          reviewStartedByPrincipalId: adminId,
          reviewStartedAtUtc: reviewedAt,
        ).isWellFormed,
        isFalse,
      );
    });

    test('a record claiming to be resolved is never well formed', () {
      expect(
        disputeRecord(state: DeliveryProofDisputeState.resolved).isWellFormed,
        isFalse,
      );
      expect(
        disputeRecord(
          disputeRevision: 3,
          state: DeliveryProofDisputeState.resolved,
        ).isWellFormed,
        isFalse,
      );
    });

    test('the reviewer may be the raiser — FND-003D2B-FIX-001', () {
      // The candidate treated a record whose reviewer equalled its raiser as
      // corrupt. That was an **invented separation-of-duties rule**: nothing in
      // the accepted contract requires it, and `admin.dispute.administer`
      // carries `approvalRequired: false`. A shape validator must not smuggle
      // in an authorization policy nobody decided.
      expect(
        disputeRecord(
          disputeRevision: 2,
          state: DeliveryProofDisputeState.underReview,
          reviewStartedByPrincipalId: raiserId,
          reviewStartedAtUtc: reviewedAt,
        ).isWellFormed,
        isTrue,
      );
    });

    test('out-of-order review is still refused', () {
      expect(
        disputeRecord(
          disputeRevision: 2,
          state: DeliveryProofDisputeState.underReview,
          reviewStartedByPrincipalId: adminId,
          reviewStartedAtUtc: raisedAt.subtract(const Duration(minutes: 1)),
        ).isWellFormed,
        isFalse,
        reason: 'review cannot precede the raise',
      );
      // Simultaneous is fine: this orders values, it invents no window.
      expect(
        disputeRecord(
          disputeRevision: 2,
          state: DeliveryProofDisputeState.underReview,
          reviewStartedByPrincipalId: adminId,
          reviewStartedAtUtc: raisedAt,
        ).isWellFormed,
        isTrue,
      );
    });

    test('non-UTC and mismatched-resource records fail closed', () {
      expect(
        disputeRecord(
          raisedAtUtc: DateTime(2026, 9, 11, 9, 15),
        ).isWellFormed,
        isFalse,
      );
      expect(
        disputeRecord(
          basis: const DeliveryProofDisputeBasis.notAssessed(
            resourceId: otherOrderId,
          ),
        ).isWellFormed,
        isFalse,
        reason: 'the basis must be about the same order as the record',
      );
      expect(disputeRecord(disputeId: 'short').isWellFormed, isFalse);
      expect(disputeRecord(raisedByPrincipalId: '').isWellFormed, isFalse);
    });

    test('no expiry, deadline or duration is derived from any timestamp', () {
      // A year-2000 and a year-2099 dispute are both well formed: the contract
      // checks that a value is UTC and ordered, and nothing more.
      expect(
        disputeRecord(raisedAtUtc: DateTime.utc(2000)).isWellFormed,
        isTrue,
      );
      expect(
        disputeRecord(raisedAtUtc: DateTime.utc(2099, 12, 31)).isWellFormed,
        isTrue,
      );
    });

    test('equality is by value across every field', () {
      expect(disputeRecord(), disputeRecord());
      expect(disputeRecord().hashCode, disputeRecord().hashCode);
      expect(disputeRecord(), isNot(disputeRecord(disputeId: disputeB)));
      expect(
        disputeRecord(),
        isNot(
          disputeRecord(
            basis: const DeliveryProofDisputeBasis.notSatisfied(
              resourceId: orderId,
              assessmentId: asmtA,
              assessmentRevision: 1,
            ),
          ),
        ),
      );
    });
  });

  group('the aggregate', () {
    test('absence is exact and is never read as "resolved"', () {
      expect(noDispute.disputeRevision, 0);
      expect(noDispute.current, isNull);
      expect(noDispute.hasCurrentRecord, isFalse);
      expect(noDispute.canonicalState, isNull);
      expect(noDispute.canonicalBasis, isNull);
    });

    test('hasCurrentRecord is structural, not a trust claim', () {
      final DeliveryProofDisputeFacts torn = DeliveryProofDisputeFacts(
        resourceId: orderId,
        disputeRevision: 2,
        current: disputeRecord(),
      );
      expect(torn.hasCurrentRecord, isTrue);
      expect(torn.canonicalState, isNull, reason: 'a torn load has no state');
    });
  });
}
