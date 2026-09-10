import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('assessor authority — kind is necessary, not sufficient (FIX-001)', () {
    test('the authorized proof verifier succeeds', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(assessor: verifier()),
      );
      expect(t.record.assessedByPrincipalId, verifierId);
      expect(t.record.assessedByKind, PrincipalKind.systemWorker);
    });

    test('a human principal cannot assess', () {
      final DeliveryProofAssessmentOutcome o = run(assessor: humanPrincipal());
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.assessorNotSystemWorker,
      );
      expect(o.transition, isNull);
    });

    test('an UNRELATED trusted worker cannot assess', () {
      // The core FIX-001 defect: `systemWorker` is a broad infrastructure
      // class. These are all perfectly valid trusted principals doing real
      // jobs, and none of them is the proof verifier.
      for (final String workerId in <String>[
        outboxWorkerId,
        expiryWorkerId,
        reconcileWorkerId,
      ]) {
        final DeliveryProofAssessmentOutcome o = run(
          assessor: otherWorker(workerId),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.assessorAuthorityMismatch,
          reason: '$workerId shares the kind but is not the verifier',
        );
        expect(o.transition, isNull);
      }
    });

    test('wrong-kind and wrong-identity keep distinct denials', () {
      expect(
        run(assessor: humanPrincipal()).denial,
        DeliveryProofAssessmentDenial.assessorNotSystemWorker,
      );
      expect(
        run(assessor: otherWorker()).denial,
        DeliveryProofAssessmentDenial.assessorAuthorityMismatch,
      );
      expect(
        DeliveryProofAssessmentDenial.assessorNotSystemWorker,
        isNot(DeliveryProofAssessmentDenial.assessorAuthorityMismatch),
      );
    });

    test('a malformed authorized verifier id fails closed', () {
      // The policy/routing lookup produced something unusable. It must not fall
      // back to "any system worker will do".
      for (final String bad in <String>['', 'svc_short', '1234567890123456']) {
        final DeliveryProofAssessmentOutcome o = run(
          context: ctx(authorizedAssessor: bad),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.assessorPrincipalIdInvalid,
          reason: '"$bad" cannot support an exact authority comparison',
        );
        expect(o.transition, isNull);
      }
    });

    test('a malformed worker identity cannot even be constructed', () {
      // Principal validates its own id, so a malformed trusted identity is not
      // representable at all — the guarantee this contract reuses rather than
      // reimplements.
      expect(
        () => Principal.systemWorker('svc_short'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Principal.systemWorker(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('the request cannot select or substitute its own assessor', () {
      // Structural: the request type carries no assessor field at all, so
      // there is nothing for a caller to set. The identity written to the
      // record comes from the verified principal.
      final String api = codeOnly(
        File(
          'lib/src/delivery_proof_assessment_authority.dart',
        ).readAsStringSync(),
      );
      for (final String forbidden in <String>[
        'this.assessedbyprincipalid',
        'this.assessedbykind',
      ]) {
        expect(
          api,
          isNot(contains(forbidden)),
          reason: 'a request field that names its own authorizer is not a '
              'check',
        );
      }
      // ...and the recorded identity tracks the principal, not the request.
      final DeliveryProofAssessmentTransition t = allowed(
        run(assessor: verifier()),
      );
      expect(t.record.assessedByPrincipalId, verifier().id);
    });

    test('the exact authorized identity is stored for audit', () {
      // A different resource may authorize a different verifier; whichever one
      // acted is named on the record.
      const String otherVerifier = 'svc_proofVerifier02';
      final DeliveryProofAssessmentTransition t = allowed(
        run(
          assessor: Principal.systemWorker(otherVerifier),
          context: ctx(authorizedAssessor: otherVerifier),
        ),
      );
      expect(t.record.assessedByPrincipalId, otherVerifier);
    });

    test('context.authorizes needs BOTH kind and exact identity', () {
      final DeliveryProofAssessmentContext c = ctx();
      expect(c.authorizes(verifier()), isTrue);
      expect(c.authorizes(otherWorker()), isFalse);
      expect(c.authorizes(humanPrincipal()), isFalse);
      // A malformed context authorizes nobody, whatever it names.
      expect(
        ctx(authorizedAssessor: '').authorizes(verifier()),
        isFalse,
      );
    });

    test('constructing a Principal is still not runtime provenance', () {
      // Anyone can build the authorized verifier principal locally and an
      // identical satisfied record. Both are structurally perfect, and neither
      // proves anything about who actually ran — DPA2/DPA17, NOT RUN.
      final Principal forged = Principal.systemWorker(verifierId);
      expect(forged.kind, PrincipalKind.systemWorker);
      expect(forged.id, verifierId);
      expect(ctx().authorizes(forged), isTrue);

      final DeliveryProofAssessmentRecord forgedRecord = record();
      expect(forgedRecord.isWellFormed, isTrue);
      expect(
        forgedRecord.verdict,
        DeliveryProofAssessmentVerdict.satisfied,
      );
      // ...and it still delivers nothing.
      expect(
        OrderState.notYetImplemented.contains(OrderState.delivered),
        isTrue,
      );
    });

    test('executableProofAssessorKinds is exactly the worker kind', () {
      expect(executableProofAssessorKinds, <PrincipalKind>{
        PrincipalKind.systemWorker,
      });
    });
  });

  group('server time boundary is unchanged', () {
    test('a non-UTC assessment time is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        at: DateTime(2026, 9, 10, 12, 30),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.assessedAtNotUtc);
      expect(o.transition, isNull);
    });

    test('no expiry, TTL or maximum age is invented', () {
      for (final DateTime t in <DateTime>[
        DateTime.utc(2000),
        DateTime.utc(2099, 12, 31),
      ]) {
        expect(allowed(run(at: t)).record.assessedAtUtc, t);
      }
    });

    test('no clock is read and no time window is derived', () {
      for (final String path in assessmentSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'ttl',
          'expiresat',
          'maxage',
          'retryinterval',
          'isbefore',
          'isafter',
          'difference(',
          'datetime.now',
        ]) {
          expect(
            api,
            isNot(contains(forbidden)),
            reason: '"$forbidden" in $path would invent a time policy or read '
                'a clock',
          );
        }
      }
    });
  });

}
