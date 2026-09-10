import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('the single event is structural (FIX-001)', () {
    test('a successful evaluation emits exactly one assessment event', () {
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.events, <String>['delivery.proof_assessed']);
      expect(t.events.length, 1);
    });

    test('a caller cannot select the events at all', () {
      // Structural: the constructor takes only the record, so there is no
      // parameter through which an arbitrary, extra or missing event id could
      // enter.
      final DeliveryProofAssessmentTransition t =
          DeliveryProofAssessmentTransition(record: record());
      expect(t.events, <String>[DeliveryProofAssessmentEventType.proofAssessed]);
      final String api = codeOnly(
        File(
          'lib/src/delivery_proof_assessment_transition.dart',
        ).readAsStringSync(),
      );
      expect(
        api,
        isNot(contains('required this.events')),
        reason: 'events must not be constructor supplied',
      );
      expect(api, isNot(contains('this.events')));
    });

    test('the event collection cannot be mutated', () {
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(() => t.events.add('delivery.proof_satisfied'),
          throwsUnsupportedError);
      expect(() => t.events.clear(), throwsUnsupportedError);
      expect(() => DeliveryProofAssessmentEventType.all.add('x'),
          throwsUnsupportedError);
      // ...and the vocabulary is unchanged afterwards.
      expect(t.events, <String>['delivery.proof_assessed']);
    });

    test('no fabricated proof event id exists anywhere', () {
      expect(DeliveryProofAssessmentEventType.all, <String>[
        'delivery.proof_assessed',
      ]);
      for (final String forbidden in <String>[
        'delivery.proof_satisfied',
        'delivery.proof_submitted',
        'order.delivered',
      ]) {
        expect(DeliveryProofAssessmentEventType.all, isNot(contains(forbidden)));
      }
    });

    test('the event does not name delivery completion', () {
      expect(
        DeliveryProofAssessmentEventType.proofAssessed,
        isNot(contains('delivered')),
      );
      for (final String mechanism in proofMechanisms) {
        expect(
          DeliveryProofAssessmentEventType.proofAssessed,
          isNot(contains(mechanism)),
        );
      }
    });
  });

}
