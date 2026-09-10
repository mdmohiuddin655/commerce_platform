import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

/// The FND-003D1 and FND-003D2A-FIX-001 lesson, applied to the dispute module
/// from the start: public `const` constructors make malformed instances
/// representable — that is what makes validators testable — so a `toString`
/// that echoed raw fields would be a log-injection and amplification surface
/// reachable **before** validation, which is exactly the window that matters.
void main() {
  group('renderings are fail safe', () {
    test('a well-formed basis renders bounded ids only', () {
      const DeliveryProofDisputeBasis basis =
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: asmtA,
            assessmentRevision: 2,
          );
      final String rendered = basis.toString();
      expect(rendered, contains(orderId));
      expect(rendered, contains(asmtA));
      expect(rendered, contains('not_satisfied'));
    });

    test('a malformed basis renders no field at all', () {
      for (final String hostile in hostileStrings) {
        expect(
          DeliveryProofDisputeBasis.notAssessed(resourceId: hostile).toString(),
          'DeliveryProofDisputeBasis(invalid)',
        );
        expect(
          DeliveryProofDisputeBasis.notSatisfied(
            resourceId: orderId,
            assessmentId: hostile,
            assessmentRevision: 1,
          ).toString(),
          'DeliveryProofDisputeBasis(invalid)',
        );
      }
    });

    test('one bad field suppresses the whole record rendering', () {
      // Including the fields that happen to be sound: until validation has
      // passed, all of them are untrusted strings.
      for (final String hostile in hostileStrings) {
        expect(
          disputeRecord(disputeId: hostile).toString(),
          'DeliveryProofDisputeRecord(invalid)',
        );
        expect(
          disputeRecord(raisedByPrincipalId: hostile).toString(),
          'DeliveryProofDisputeRecord(invalid)',
        );
        expect(
          disputeRecord(
            basis: DeliveryProofDisputeBasis.notSatisfied(
              resourceId: orderId,
              assessmentId: hostile,
              assessmentRevision: 1,
            ),
          ).toString(),
          'DeliveryProofDisputeRecord(invalid)',
        );
      }
    });

    test('no hostile fragment survives in any rendering', () {
      for (final String hostile in hostileStrings) {
        final List<String> renderings = <String>[
          DeliveryProofDisputeBasis.notAssessed(resourceId: hostile).toString(),
          disputeRecord(disputeId: hostile).toString(),
          disputeRecord(raisedByPrincipalId: hostile).toString(),
          DeliveryProofDisputeContext(resourceId: hostile).toString(),
          DeliveryProofDisputeTransition(
            command: DeliveryProofDisputeCommand.raise,
            record: disputeRecord(disputeId: hostile),
          ).toString(),
          DeliveryProofDisputeOutcome.allow(
            DeliveryProofDisputeTransition(
              command: DeliveryProofDisputeCommand.raise,
              record: disputeRecord(disputeId: hostile),
            ),
          ).toString(),
        ];
        for (final String rendered in renderings) {
          expect(rendered, isNot(contains(hostile)));
          expect(rendered, isNot(contains('\n')));
          expect(rendered, isNot(contains('\t')));
        }
      }
    });

    test('every hostile fixture really is malformed', () {
      // The guard that caught a fixture which was silently a *valid* id, and so
      // was testing the well-formed path while claiming to test the other one.
      for (final String hostile in hostileStrings) {
        expect(
          isValidOpaqueId(hostile),
          isFalse,
          reason: '"$hostile" must not be a valid opaque id',
        );
      }
    });

    test('a malformed transition and outcome render nothing of the record', () {
      final DeliveryProofDisputeTransition bad = DeliveryProofDisputeTransition(
        command: DeliveryProofDisputeCommand.raise,
        record: disputeRecord(disputeId: hostileUrl),
      );
      expect(bad.toString(), 'DeliveryProofDisputeTransition(invalid)');
      expect(
        DeliveryProofDisputeOutcome.allow(bad).toString(),
        'Allow(DeliveryProofDisputeTransition(invalid))',
      );
    });

    test('denials render enum names only', () {
      for (final DeliveryProofDisputeDenial d
          in DeliveryProofDisputeDenial.values) {
        expect(
          DeliveryProofDisputeOutcome.deny(d).toString(),
          'Deny(${d.name})',
        );
      }
      // A real denial from the evaluator, driven by hostile input, still
      // renders only the enum name.
      expect(
        runRaise(disputeId: hostileNewline).toString(),
        'Deny(disputeIdInvalid)',
      );
    });

    test('a well-formed transition renders bounded values only', () {
      final String rendered = allowedDispute(runRaise()).toString();
      expect(rendered, contains('raise'));
      expect(rendered, contains('open'));
      expect(rendered, contains(disputeA));
      expect(rendered, isNot(contains('\n')));
    });
  });

  group('privacy — nothing that is not an identifier is here to leak', () {
    test('no proof or evidence material can reach a dispute record', () {
      // The dispute holds no policy reference, no evidence reference and no
      // verdict copy — only an assessment id and revision. There is therefore
      // nothing here that could carry proof material even in principle.
      final DeliveryProofDisputeTransition t = allowedDispute(
        runRaise(assessment: assessed()),
      );
      final String rendered = t.record.toString();
      expect(rendered, isNot(contains(proofPolicy.value)));
      expect(rendered, isNot(contains(evidenceA)));
      expect(rendered, isNot(contains(verifierId)));
      expect(rendered, isNot(contains(riderA)));
      // What *does* render is the fallback ground and the assessment id: the
      // audit identity of what was disputed. That is a pointer into
      // append-only history, not a copy of the verdict — the record on the
      // dispute side has no verdict field to copy.
      expect(rendered, contains('not_satisfied'));
      expect(t.record.basis.assessmentId, asmtA);
    });

    test('every value a dispute record exposes is an opaque identifier', () {
      final DeliveryProofDisputeRecord r = allowedDispute(runRaise()).record;
      for (final String id in <String>[
        r.disputeId,
        r.resourceId,
        r.raisedByPrincipalId,
      ]) {
        expect(isValidOpaqueId(id), isTrue);
        expect(id, isNot(contains('@')));
        expect(id.length, lessThanOrEqualTo(maxIdLength));
      }
    });

    test('event ids carry no content, only routing names', () {
      for (final String e in DeliveryProofDisputeEventType.all) {
        expect(e, matches(RegExp(r'^[a-z0-9._]+$')));
        expect(e.length, lessThanOrEqualTo(maxIdLength));
      }
    });

    test('there is no free-text field anywhere on the public surface', () {
      // A customer-supplied string would be the one field through which a
      // description of proof material could reach an event payload. The reason
      // lives with the audited command, in FND-003A.
      final DeliveryProofDisputeRecord r = allowedDispute(runRaise()).record;
      final String rendered = r.toString();
      for (final String leak in <String>[
        'goods never arrived',
        'reason',
        'note',
        'comment',
      ]) {
        expect(rendered.toLowerCase(), isNot(contains(leak)));
      }
    });
  });
}
