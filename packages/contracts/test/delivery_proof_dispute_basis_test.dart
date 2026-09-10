import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

/// How a recorded dispute basis stands against the assessment aggregate as it
/// is **now** — the calculation that makes "superseded" observable without
/// anything having been rewritten.
void main() {
  group('a basis raised against canonical absence', () {
    const DeliveryProofDisputeBasis absent =
        DeliveryProofDisputeBasis.notAssessed(resourceId: orderId);

    test('is current while nothing has been assessed', () {
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: absent,
          assessment: absentAssessment,
        ),
        DeliveryProofDisputeBasisStanding.current,
      );
    });

    test('is superseded once any assessment exists', () {
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(
          resolveDeliveryProofDisputeBasisStanding(
            basis: absent,
            assessment: assessed(verdict: v),
          ),
          DeliveryProofDisputeBasisStanding.superseded,
          reason: 'a first $v assessment supersedes "not assessed"',
        );
      }
    });
  });

  group('a basis raised against notSatisfied', () {
    test('is current while it is still the assessment on record', () {
      final DeliveryProofAssessmentFacts a = assessed();
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: raisedBasis(assessment: a),
          assessment: a,
        ),
        DeliveryProofDisputeBasisStanding.current,
      );
    });

    test('becomes superseded when reassessment advances the aggregate', () {
      // The dispute was raised against assessment A at revision 1. A trusted
      // verifier later reassessed, appending B at revision 2.
      final DeliveryProofDisputeBasis basis = raisedBasis(assessment: assessed());
      final DeliveryProofAssessmentFacts after = assessed(
        assessmentId: asmtB,
        revision: 2,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
        supersedes: asmtA,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: basis,
          assessment: after,
        ),
        DeliveryProofDisputeBasisStanding.superseded,
      );
      // ...and the basis still identifies exactly what was disputed. That is
      // the whole point of ADR-0009's append-only history.
      expect(
        basis.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 1),
        isTrue,
      );
      expect(basis.assessmentId, asmtA);
      expect(basis.kind, DeliveryProofDisputeBasisKind.notSatisfied);
    });

    test('a later satisfied assessment does not dismiss the basis', () {
      // Supersession is a fact about the assessment history, not a resolution.
      // Nothing here closes, weakens or validates the dispute.
      final DeliveryProofDisputeBasis basis = raisedBasis(assessment: assessed());
      final DeliveryProofAssessmentFacts after = assessed(
        assessmentId: asmtB,
        revision: 2,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
        supersedes: asmtA,
      );
      final DeliveryProofDisputeBasisStanding standing =
          resolveDeliveryProofDisputeBasisStanding(
            basis: basis,
            assessment: after,
          );
      expect(standing, DeliveryProofDisputeBasisStanding.superseded);
      expect(
        DeliveryProofDisputeBasisStanding.values.map(
          (DeliveryProofDisputeBasisStanding s) => s.name,
        ),
        isNot(contains('resolved')),
      );
    });
  });

  group('identity is not meaning — FND-003D2B-FIX-001', () {
    test('same id + same revision + opposite verdict is indeterminate', () {
      // The defect this corrects. ADR-0009 gives every reassessment a NEW id
      // and the NEXT revision, so assessment A revision 1 can never
      // legitimately change verdict. A basis recorded as `notSatisfied`
      // against A/1, compared with a *canonical* A/1 that now reads
      // `satisfied`, is a self-contradictory history — and was previously
      // certified as `current`.
      const DeliveryProofDisputeBasis basis =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 1,
          );
      final DeliveryProofAssessmentFacts contradictory = assessed(
        assessmentId: asmtA,
        revision: 1,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
      );
      // The contradiction is not corruption of *shape*: the aggregate is
      // perfectly canonical, which is exactly why identity alone was not
      // enough to detect it.
      expect(
        validateDeliveryProofAssessmentAggregate(contradictory),
        isNull,
        reason: 'the aggregate is well formed; only the pairing is impossible',
      );
      expect(
        basis.identifiesAssessment(assessmentId: asmtA, assessmentRevision: 1),
        isTrue,
        reason: 'identity still matches — meaning is what disagrees',
      );

      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: basis,
          assessment: contradictory,
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });

    test('the contradiction becomes neither superseded nor notSatisfied', () {
      const DeliveryProofDisputeBasis basis =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 1,
          );
      final DeliveryProofAssessmentFacts contradictory = assessed(
        assessmentId: asmtA,
        revision: 1,
        verdict: DeliveryProofAssessmentVerdict.satisfied,
      );
      final DeliveryProofDisputeBasisStanding standing =
          resolveDeliveryProofDisputeBasisStanding(
            basis: basis,
            assessment: contradictory,
          );
      // Not `superseded`: nothing superseded it — the revision never moved.
      expect(standing, isNot(DeliveryProofDisputeBasisStanding.superseded));
      expect(standing, isNot(DeliveryProofDisputeBasisStanding.current));
      // The assessment is not relabelled, and the basis is not rewritten.
      expect(
        contradictory.canonicalVerdict,
        DeliveryProofAssessmentVerdict.satisfied,
      );
      expect(basis.kind, DeliveryProofDisputeBasisKind.notSatisfied);
      expect(basis.assessmentId, asmtA);
      expect(basis.assessmentRevision, 1);
    });

    test('the ordinary matching notSatisfied case is still current', () {
      // Re-pinned alongside the correction so the fix cannot over-reach into
      // refusing the case it exists to allow.
      final DeliveryProofAssessmentFacts a = assessed(
        assessmentId: asmtA,
        revision: 1,
      );
      expect(
        a.canonicalVerdict,
        DeliveryProofAssessmentVerdict.notSatisfied,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: raisedBasis(assessment: a),
          assessment: a,
        ),
        DeliveryProofDisputeBasisStanding.current,
      );
    });

    test('a higher revision is still superseded, whatever the verdict', () {
      final DeliveryProofDisputeBasis basis = raisedBasis(
        assessment: assessed(),
      );
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(
          resolveDeliveryProofDisputeBasisStanding(
            basis: basis,
            assessment: assessed(
              assessmentId: asmtB,
              revision: 2,
              verdict: v,
              supersedes: asmtA,
            ),
          ),
          DeliveryProofDisputeBasisStanding.superseded,
          reason: 'the verdict check applies only at the SAME revision',
        );
      }
    });
  });

  group('indeterminate — corruption is never a confident answer', () {
    test('a torn assessment aggregate is never current or superseded', () {
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(
          resolveDeliveryProofDisputeBasisStanding(
            basis: raisedBasis(assessment: assessed()),
            assessment: tornAssessment(verdict: v),
          ),
          DeliveryProofDisputeBasisStanding.indeterminate,
          reason: 'a torn aggregate carrying $v proves nothing',
        );
      }
    });

    test('a malformed basis answers indeterminate', () {
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notAssessed(resourceId: ''),
          assessment: absentAssessment,
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: 'short',
            assessmentRevision: 1,
          ),
          assessment: assessed(),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });

    test('mixed resources never compare', () {
      // A basis about order A against order B's assessment history.
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notAssessed(
            resourceId: orderId,
          ),
          assessment: const DeliveryProofAssessmentFacts.absent(
            resourceId: otherOrderId,
          ),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: raisedBasis(assessment: assessed()),
          assessment: assessed(resourceId: otherOrderId),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });

    test('an aggregate behind the basis is a stale load, not a rewind', () {
      // History only moves forward, so this cannot be a supersession in
      // reverse — it is a partial or stale read.
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtB,
            assessmentRevision: 5,
          ),
          assessment: assessed(),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });

    test('same revision but a different assessment id is corruption', () {
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtB,
            assessmentRevision: 1,
          ),
          assessment: assessed(),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });

    test('an absence basis against a same-revision record cannot happen', () {
      // Revision 0 with a record is itself a torn aggregate, and the validator
      // catches it first — the standing stays indeterminate either way.
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notAssessed(
            resourceId: orderId,
          ),
          assessment: DeliveryProofAssessmentFacts(
            resourceId: orderId,
            assessmentRevision: 0,
            current: record(),
          ),
        ),
        DeliveryProofDisputeBasisStanding.indeterminate,
      );
    });
  });

  group('the standing calculation changes nothing', () {
    test('resolving a standing leaves both aggregates untouched', () {
      final DeliveryProofAssessmentFacts before = assessed();
      final DeliveryProofAssessmentRecord? recordBefore = before.current;
      final DeliveryProofDisputeBasis basis = raisedBasis(assessment: before);

      resolveDeliveryProofDisputeBasisStanding(
        basis: basis,
        assessment: before,
      );
      resolveDeliveryProofDisputeBasisStanding(
        basis: basis,
        assessment: assessed(assessmentId: asmtB, revision: 2),
      );

      expect(identical(before.current, recordBefore), isTrue);
      expect(before.assessmentRevision, 1);
      expect(before.current!.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(basis.assessmentId, asmtA);
      expect(basis.assessmentRevision, 1);
    });

    test('every standing value is accounted for by a test above', () {
      expect(DeliveryProofDisputeBasisStanding.values.length, 3);
      expect(
        DeliveryProofDisputeBasisStanding.values.map(
          (DeliveryProofDisputeBasisStanding s) => s.name,
        ),
        <String>['current', 'superseded', 'indeterminate'],
      );
    });
  });
}
