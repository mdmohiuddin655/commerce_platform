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
          basis: basisFrom(a),
          assessment: a,
        ),
        DeliveryProofDisputeBasisStanding.current,
      );
    });

    test('becomes superseded when reassessment advances the aggregate', () {
      // The dispute was raised against assessment A at revision 1. A trusted
      // verifier later reassessed, appending B at revision 2.
      final DeliveryProofDisputeBasis basis = basisFrom(assessed());
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
      final DeliveryProofDisputeBasis basis = basisFrom(assessed());
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

  group('indeterminate — corruption is never a confident answer', () {
    test('a torn assessment aggregate is never current or superseded', () {
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(
          resolveDeliveryProofDisputeBasisStanding(
            basis: basisFrom(assessed()),
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
          basis: basisFrom(assessed()),
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
      final DeliveryProofDisputeBasis basis = basisFrom(before);

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
