import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('debug renderings are fail safe (FIX-001)', () {
    test('every hostile fixture really is a malformed id', () {
      // Guards the guards. A "hostile" marker built only from `[A-Za-z0-9_-]`
      // would be a *valid* opaque id, every record built from it would be well
      // formed, and the malformed-rendering tests below would silently stop
      // testing anything. One such marker was caught this way.
      for (final String h in hostileStrings) {
        expect(
          isValidOpaqueId(h),
          isFalse,
          reason: 'hostile fixture ${h.hashCode} must not be a valid id',
        );
      }
    });

    test('a valid record renders bounded identifiers and a verdict', () {
      final String rendered = record().toString();
      expect(rendered, contains(asmtA));
      expect(rendered, contains(orderId));
      expect(rendered, contains('satisfied'));
      expect(rendered, contains(verifierId));
      // The policy reference's own non-disclosing toString is not bypassed.
      expect(rendered, isNot(contains(proofPolicy.value)));
      expect(rendered, isNot(contains('@')));
    });

    test('a malformed record renders generically, echoing no field', () {
      for (final String hostile in hostileStrings) {
        final DeliveryProofAssessmentRecord broken = record(
          assessmentId: hostile,
        );
        expect(broken.isWellFormed, isFalse);
        expect(broken.toString(), 'DeliveryProofAssessmentRecord(invalid)');
      }
    });

    test('ONE bad field suppresses the whole rendering', () {
      // The sound fields are still untrusted strings until validation passes,
      // so none of them is echoed either.
      final DeliveryProofAssessmentRecord broken = record(
        riderPrincipalId: hostileUrl,
      );
      final String rendered = broken.toString();
      expect(rendered, 'DeliveryProofAssessmentRecord(invalid)');
      expect(rendered, isNot(contains(asmtA)));
      expect(rendered, isNot(contains(orderId)));
      expect(rendered, isNot(contains('satisfied')));
    });

    test('no hostile fragment survives in any record rendering', () {
      for (final String hostile in hostileStrings) {
        for (final DeliveryProofAssessmentRecord broken
            in <DeliveryProofAssessmentRecord>[
              record(assessmentId: hostile),
              record(resourceId: hostile),
              record(riderPrincipalId: hostile),
              record(riderAssignmentId: hostile),
              record(assessedByPrincipalId: hostile),
              record(supersedesAssessmentId: hostile),
            ]) {
          final String rendered = broken.toString();
          expect(rendered, isNot(contains(hostile)));
          expect(rendered, isNot(contains('INJECTED')));
          expect(rendered, isNot(contains('attacker.example')));
          expect(rendered, isNot(contains('etc/passwd')));
          expect(rendered, isNot(contains('AKIA')));
          expect(rendered, isNot(contains('\n')));
          expect(rendered, isNot(contains('\t')));
        }
      }
    });

    test('a malformed context renders generically', () {
      for (final String hostile in hostileStrings) {
        for (final DeliveryProofAssessmentContext c
            in <DeliveryProofAssessmentContext>[
              ctx(resourceId: hostile),
              ctx(authorizedAssessor: hostile),
              ctx(policy: DeliveryProofPolicyRef(hostile * 3)),
            ]) {
          final String rendered = c.toString();
          expect(rendered, 'DeliveryProofAssessmentContext(invalid)');
          expect(rendered, isNot(contains(hostile)));
        }
      }
    });

    test('a valid context renders bounded identifiers only', () {
      final String rendered = ctx().toString();
      expect(rendered, contains(orderId));
      expect(rendered, contains(verifierId));
      expect(rendered, isNot(contains(proofPolicy.value)));
    });

    test('a transition wrapping a malformed record renders generically', () {
      final DeliveryProofAssessmentTransition t =
          DeliveryProofAssessmentTransition(
            record: record(assessmentId: hostileNewline),
          );
      expect(t.toString(), 'DeliveryProofAssessmentTransition(invalid)');
      expect(t.toString(), isNot(contains('INJECTED')));
      // The derived revision and supersession pointer do not escape either.
      expect(t.toString(), isNot(contains('rev=')));
    });

    test('Outcome cannot reintroduce a raw malformed transition', () {
      final DeliveryProofAssessmentOutcome o =
          DeliveryProofAssessmentOutcome.allow(
            DeliveryProofAssessmentTransition(
              record: record(resourceId: hostileSecret),
            ),
          );
      final String rendered = o.toString();
      expect(rendered, 'Allow(DeliveryProofAssessmentTransition(invalid))');
      expect(rendered, isNot(contains('AKIA')));
    });

    test('a denial renders enum names only', () {
      final DeliveryProofAssessmentOutcome o = run(assessor: otherWorker());
      expect(o.toString(), 'Deny(assessorAuthorityMismatch)');
      final DeliveryProofAssessmentOutcome structural = run(
        context: ctx(policy: const DeliveryProofPolicyRef('   ')),
      );
      expect(structural.toString(), 'Deny(policyRefInvalid/policyRefBlank)');
    });

    test('rendering never throws, trims, repairs or hashes', () {
      for (final String hostile in hostileStrings) {
        final DeliveryProofAssessmentRecord broken = record(
          assessmentId: hostile,
          resourceId: hostile,
        );
        expect(broken.toString, returnsNormally);
        // The stored values are untouched — reporting is not repairing.
        expect(broken.assessmentId, hostile);
        expect(broken.resourceId, hostile);
      }
    });

    test('an oversized field cannot produce an oversized rendering', () {
      final DeliveryProofAssessmentRecord broken = record(
        assessmentId: 'A' * 5000,
      );
      expect(broken.toString().length, lessThan(80));
    });
  });

  group('privacy boundary', () {
    test('no proof material or locator exists to leak', () {
      for (final String path in assessmentSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'bytes',
          'base64',
          'blob',
          'signedurl',
          'storagepath',
          'artifactcount',
          'artifacts',
          'list<deliveryevidenceref>',
        ]) {
          expect(
            api,
            isNot(contains(forbidden)),
            reason: '"$forbidden" in $path would invent material, a locator '
                'or a count',
          );
        }
      }
    });

    test('a malformed evidence reference is still not echoed', () {
      const DeliveryEvidenceRef broken = DeliveryEvidenceRef(
        resourceId: 'short',
        evidenceId: 'also_short',
      );
      expect(broken.toString(), 'DeliveryEvidenceRef(invalid)');
      expect(broken.toString(), isNot(contains('also_short')));
    });
  });
}
