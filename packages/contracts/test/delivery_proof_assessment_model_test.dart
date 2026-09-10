import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('verdict vocabulary', () {
    test('there are exactly two verdicts', () {
      expect(DeliveryProofAssessmentVerdict.values, <
        DeliveryProofAssessmentVerdict
      >[
        DeliveryProofAssessmentVerdict.satisfied,
        DeliveryProofAssessmentVerdict.notSatisfied,
      ]);
    });

    test('no pending, processing or expired verdict is invented', () {
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        for (final String forbidden in <String>[
          'pending',
          'processing',
          'expired',
          'approved',
          'disputed',
          'overridden',
          'delivered',
          'unknown',
        ]) {
          expect(v.name.toLowerCase(), isNot(contains(forbidden)));
          expect(v.id, isNot(contains(forbidden)));
        }
      }
    });

    test('wire ids are stable and round-trip', () {
      expect(DeliveryProofAssessmentVerdict.satisfied.id, 'satisfied');
      expect(DeliveryProofAssessmentVerdict.notSatisfied.id, 'not_satisfied');
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(DeliveryProofAssessmentVerdict.byId(v.id), v);
      }
      expect(DeliveryProofAssessmentVerdict.byId('pending'), isNull);
    });
  });

  group('absence means NOT ASSESSED', () {
    test('canonical absence is revision 0 with no record', () {
      expect(absentAssessment.assessmentRevision, 0);
      expect(absentAssessment.current, isNull);
      expect(absentAssessment.hasCurrentRecord, isFalse);
      expect(validateDeliveryProofAssessmentAggregate(absentAssessment), isNull);
    });

    test('canonical absence exposes no verdict', () {
      expect(
        absentAssessment.canonicalVerdict,
        isNull,
        reason: 'null means not assessed — never "not satisfied"',
      );
    });
  });

  group('canonicalVerdict fails closed (FIX-001)', () {
    test('a canonical satisfied aggregate exposes satisfied', () {
      final DeliveryProofAssessmentFacts f = applyAssessment(allowed(run()));
      expect(validateDeliveryProofAssessmentAggregate(f), isNull);
      expect(
        f.canonicalVerdict,
        DeliveryProofAssessmentVerdict.satisfied,
      );
    });

    test('a canonical notSatisfied aggregate exposes notSatisfied', () {
      final DeliveryProofAssessmentFacts f = applyAssessment(
        allowed(run(verdict: DeliveryProofAssessmentVerdict.notSatisfied)),
      );
      expect(validateDeliveryProofAssessmentAggregate(f), isNull);
      expect(
        f.canonicalVerdict,
        DeliveryProofAssessmentVerdict.notSatisfied,
      );
    });

    test('a TORN aggregate carrying satisfied exposes no verdict', () {
      // Record says revision 1, aggregate says 2: a torn write. The raw record
      // still says `satisfied`, and that must not reach a caller.
      final DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 2,
        current: record(),
      );
      expect(
        validateDeliveryProofAssessmentAggregate(torn),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
      expect(torn.current!.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(
        torn.canonicalVerdict,
        isNull,
        reason: 'a corrupt aggregate must not expose a trusted-looking verdict',
      );
    });

    test('a malformed record carrying satisfied exposes no verdict', () {
      final DeliveryProofAssessmentFacts broken = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 1,
        current: record(assessmentId: 'asm_short'),
      );
      expect(broken.current!.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(broken.canonicalVerdict, isNull);
    });

    test('corruption is NEVER converted into notSatisfied', () {
      final DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 2,
        current: record(),
      );
      expect(
        torn.canonicalVerdict,
        isNot(DeliveryProofAssessmentVerdict.notSatisfied),
        reason: 'corruption is a denial and a reconciliation case, not a '
            'negative proof result',
      );
      expect(torn.canonicalVerdict, isNull);
    });

    test('hasCurrentRecord is structural only, and says so', () {
      // A torn aggregate genuinely has a record present. That is an honest
      // structural fact, and precisely why it is not the trusted accessor.
      final DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 2,
        current: record(),
      );
      expect(torn.hasCurrentRecord, isTrue);
      expect(torn.canonicalVerdict, isNull);
    });
  });

  group('bindsRiderAttempt fails closed (FIX-001)', () {
    test('a valid record and the exact attempt binds', () {
      expect(
        record().bindsRiderAttempt(
          principalId: riderA,
          assignmentId: rideAsgA,
          generation: 1,
        ),
        isTrue,
      );
    });

    test('a different valid principal does not bind', () {
      expect(
        record().bindsRiderAttempt(
          principalId: riderB,
          assignmentId: rideAsgA,
          generation: 1,
        ),
        isFalse,
      );
    });

    test('a different valid assignment does not bind', () {
      expect(
        record().bindsRiderAttempt(
          principalId: riderA,
          assignmentId: rideAsgB,
          generation: 1,
        ),
        isFalse,
      );
    });

    test('a different generation does not bind', () {
      expect(
        record().bindsRiderAttempt(
          principalId: riderA,
          assignmentId: rideAsgA,
          generation: 2,
        ),
        isFalse,
      );
    });

    test('a MALFORMED record cannot bind its own malformed values', () {
      // The pre-fix failure: raw equality let an empty stored principal match
      // an empty argument and certify a binding the validator refuses.
      final DeliveryProofAssessmentRecord broken = record(
        riderPrincipalId: '',
        riderAssignmentId: '',
      );
      expect(broken.isWellFormed, isFalse);
      expect(
        broken.bindsRiderAttempt(
          principalId: '',
          assignmentId: '',
          generation: 1,
        ),
        isFalse,
        reason: 'identically-malformed values must never match their way to '
            'true',
      );
    });

    test('a valid record rejects a malformed principal argument', () {
      for (final String bad in <String>['', 'usr_short', '1234567890123456']) {
        expect(
          record().bindsRiderAttempt(
            principalId: bad,
            assignmentId: rideAsgA,
            generation: 1,
          ),
          isFalse,
          reason: '"$bad" is not a canonical opaque id',
        );
      }
    });

    test('a valid record rejects a malformed assignment argument', () {
      for (final String bad in <String>['', 'asg_short', r'asg_bad!id0000001']) {
        expect(
          record().bindsRiderAttempt(
            principalId: riderA,
            assignmentId: bad,
            generation: 1,
          ),
          isFalse,
        );
      }
    });

    test('a non-positive generation never binds', () {
      for (final int g in <int>[0, -1, -99]) {
        expect(
          record(riderAssignmentGeneration: g).bindsRiderAttempt(
            principalId: riderA,
            assignmentId: rideAsgA,
            generation: g,
          ),
          isFalse,
          reason: 'generation $g is not a reachable attempt',
        );
      }
    });

    test('nothing is trimmed or normalised into a match', () {
      expect(
        record().bindsRiderAttempt(
          principalId: ' $riderA ',
          assignmentId: rideAsgA,
          generation: 1,
        ),
        isFalse,
      );
    });
  });

  group('belongsToResource stays fail-closed', () {
    test('valid record and its own resource', () {
      expect(record().belongsToResource(orderId), isTrue);
    });

    test('another order does not match', () {
      expect(record().belongsToResource(otherOrderId), isFalse);
    });

    test('a malformed record cannot certify a malformed resource', () {
      expect(record(resourceId: '').belongsToResource(''), isFalse);
    });
  });
}
