import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

const String orderA = 'ord_Xa91ZZ0plQ7rTt4B';
const String orderB = 'ord_Zz42QQ8mmW1xVv7C';
const String evidenceA = 'evd_Aa11Bb22Cc33Dd44';
const String evidenceB = 'evd_Bb22Cc33Dd44Ee55';

const List<String> malformedIds = <String>[
  '',
  'evd_short',
  '1234567890123456',
  r'evd_bad!identifier01',
];

void main() {
  group('DeliveryProofPolicyRef — a reference, never a result', () {
    test('a non-blank reference is structurally usable', () {
      const DeliveryProofPolicyRef ref = DeliveryProofPolicyRef(
        'policy/delivery_proof@v1',
      );
      expect(ref.isWellFormed, isTrue);
      expect(validateDeliveryProofPolicyRef(ref), isNull);
    });

    test('blank and whitespace-only references fail closed', () {
      for (final String bad in <String>['', ' ', '   ', '\t', '\n']) {
        final DeliveryProofPolicyRef ref = DeliveryProofPolicyRef(bad);
        expect(ref.isWellFormed, isFalse, reason: 'value ${bad.codeUnits}');
        expect(
          validateDeliveryProofPolicyRef(ref),
          DeliveryProofDenial.policyRefBlank,
          reason: 'value ${bad.codeUnits}',
        );
      }
    });

    test('the exact value is preserved, never trimmed into equality', () {
      const DeliveryProofPolicyRef padded = DeliveryProofPolicyRef(' p/x@v1 ');
      const DeliveryProofPolicyRef bare = DeliveryProofPolicyRef('p/x@v1');
      expect(padded.value, ' p/x@v1 ', reason: 'stored value untouched');
      expect(padded, isNot(bare), reason: 'a padded ref is a different ref');
      expect(padded.isWellFormed, isTrue, reason: 'trim only rejects blanks');
    });

    test('no grammar is imposed on the reference', () {
      // The repository has no delivery-proof policy vocabulary to reuse, so
      // inventing a prefix, version suffix or namespace rule here would be
      // inventing a contract rather than referring to one.
      for (final String shape in <String>[
        'policy/delivery_proof@v1',
        'dp-2026-01',
        'a',
        'urn:example:policy:7',
      ]) {
        expect(
          validateDeliveryProofPolicyRef(DeliveryProofPolicyRef(shape)),
          isNull,
          reason: 'shape "$shape" must not be rejected by an invented grammar',
        );
      }
    });

    test('the bound is 64 — accepted at the limit, denied one past it', () {
      expect(maxDeliveryProofPolicyRefLength, 64);
      // Aligned with the repository's existing wire-string ceilings.
      expect(maxDeliveryProofPolicyRefLength, maxIdLength);
      // The declaration *aliases* maxIdLength rather than repeating 64; the
      // source-shape guard below is what actually protects that coupling,
      // because runtime equality cannot tell `= 64` from `= maxIdLength`.

      final String atLimit = 'p' * 64;
      final String overLimit = 'p' * 65;
      expect(atLimit.length, 64);
      expect(overLimit.length, 65);

      expect(
        validateDeliveryProofPolicyRef(DeliveryProofPolicyRef(atLimit)),
        isNull,
        reason: 'exactly 64 must be accepted',
      );
      expect(DeliveryProofPolicyRef(atLimit).isWellFormed, isTrue);

      expect(
        validateDeliveryProofPolicyRef(DeliveryProofPolicyRef(overLimit)),
        DeliveryProofDenial.policyRefTooLong,
        reason: '65 must deny deterministically',
      );
      expect(DeliveryProofPolicyRef(overLimit).isWellFormed, isFalse);
    });

    test('a single character is enough', () {
      expect(
        validateDeliveryProofPolicyRef(const DeliveryProofPolicyRef('a')),
        isNull,
      );
    });

    test('the bound constrains size, never shape', () {
      // Every mechanism-neutral shape that fits still passes; the ceiling
      // introduces no prefix, suffix, URI or vocabulary requirement.
      for (final String shape in <String>[
        'policy/delivery_proof@v1',
        'dp-2026-01',
        'urn:example:policy:7',
        'A_B.C~D',
        '123456',
      ]) {
        expect(
          validateDeliveryProofPolicyRef(DeliveryProofPolicyRef(shape)),
          isNull,
          reason: 'shape "\$shape" must not be rejected by the size bound',
        );
      }
    });

    test('blank still denies blank, not too-long', () {
      // Precedence: a blank value is reported as blank even at 65 characters.
      expect(
        validateDeliveryProofPolicyRef(DeliveryProofPolicyRef(' ' * 65)),
        DeliveryProofDenial.policyRefBlank,
      );
    });

    test('toString does not reproduce the raw value', () {
      // The reference has no character grammar, so echoing it would make any
      // print, crash report or error message a content-leak surface.
      const String secretish = 'policy/DO-NOT-ECHO-THIS-VALUE@v9';
      const DeliveryProofPolicyRef ref = DeliveryProofPolicyRef(secretish);

      expect(ref.toString(), isNot(contains(secretish)));
      expect(ref.toString(), isNot(contains('DO-NOT-ECHO')));
      expect(ref.toString(), 'DeliveryProofPolicyRef(length=32)');
      expect(ref.value, secretish, reason: 'the stored value is untouched');
    });

    test('control characters are not reproduced by toString', () {
      const DeliveryProofPolicyRef ref = DeliveryProofPolicyRef(
        'a\nFAKE LOG LINE\tb\r',
      );
      final String rendered = ref.toString();
      expect(rendered, isNot(contains('FAKE LOG LINE')));
      expect(rendered, isNot(contains('\n')));
      expect(rendered, isNot(contains('\t')));
      expect(rendered, isNot(contains('\r')));
      expect(rendered.split('\n').length, 1, reason: 'single line');
    });

    test('a maximum-length value cannot produce an oversized toString', () {
      final String atLimit = 'x' * maxDeliveryProofPolicyRefLength;
      final String rendered = DeliveryProofPolicyRef(atLimit).toString();
      expect(rendered, isNot(contains(atLimit)));
      expect(rendered.length, lessThan(64));
    });

    test('equality and hashCode stay exact-value based', () {
      const DeliveryProofPolicyRef a = DeliveryProofPolicyRef('policy/x@v1');
      const DeliveryProofPolicyRef b = DeliveryProofPolicyRef('policy/x@v1');
      const DeliveryProofPolicyRef padded =
          DeliveryProofPolicyRef(' policy/x@v1 ');
      const DeliveryProofPolicyRef cased = DeliveryProofPolicyRef('POLICY/X@V1');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(padded), reason: 'not trimmed into equality');
      expect(a, isNot(cased), reason: 'not case-folded into equality');
      // The safe toString is lossy by design: two DIFFERENT values of the same
      // length render identically. That is exactly why equality must not — and
      // does not — go through toString.
      const DeliveryProofPolicyRef sameLength =
          DeliveryProofPolicyRef('policy/y@v2');
      expect(sameLength.value.length, a.value.length);
      expect(sameLength.toString(), a.toString(),
          reason: 'lossy rendering collapses distinct values');
      expect(sameLength, isNot(a),
          reason: 'equality uses the exact value, never the rendering');
      expect(sameLength.hashCode, isNot(a.hashCode));
    });

    test('there is no satisfaction, status or success concept', () {
      // A reference says WHICH policy applies, never that it was met.
      expect(DeliveryProofDenial.values, <DeliveryProofDenial>[
        DeliveryProofDenial.policyRefBlank,
        DeliveryProofDenial.policyRefTooLong,
        DeliveryProofDenial.evidenceResourceIdInvalid,
        DeliveryProofDenial.evidenceIdInvalid,
        DeliveryProofDenial.expectedResourceIdInvalid,
        DeliveryProofDenial.evidenceResourceMismatch,
      ]);
      for (final DeliveryProofDenial d in DeliveryProofDenial.values) {
        for (final String forbidden in <String>[
          'satisf',
          'delivered',
          'success',
          'failed',
          'refused',
          'accepted',
        ]) {
          expect(d.name.toLowerCase(), isNot(contains(forbidden)));
        }
      }
    });
  });

  group('DeliveryEvidenceRef — bound to its resource', () {
    const DeliveryEvidenceRef ref = DeliveryEvidenceRef(
      resourceId: orderA,
      evidenceId: evidenceA,
    );

    test('a well-formed reference for its own order validates', () {
      expect(ref.isWellFormed, isTrue);
      expect(validateDeliveryEvidenceRef(ref, resourceId: orderA), isNull);
      expect(ref.belongsTo(orderA), isTrue);
    });

    test('cross-resource substitution fails closed', () {
      // Evidence is not portable between orders.
      expect(
        validateDeliveryEvidenceRef(ref, resourceId: orderB),
        DeliveryProofDenial.evidenceResourceMismatch,
      );
      expect(ref.belongsTo(orderB), isFalse);
    });

    test('a malformed evidence id fails closed', () {
      for (final String bad in malformedIds) {
        expect(
          validateDeliveryEvidenceRef(
            DeliveryEvidenceRef(resourceId: orderA, evidenceId: bad),
            resourceId: orderA,
          ),
          DeliveryProofDenial.evidenceIdInvalid,
          reason: 'evidenceId "$bad"',
        );
      }
    });

    test('a malformed resource id fails closed', () {
      for (final String bad in malformedIds) {
        expect(
          validateDeliveryEvidenceRef(
            DeliveryEvidenceRef(resourceId: bad, evidenceId: evidenceA),
            resourceId: bad,
          ),
          DeliveryProofDenial.evidenceResourceIdInvalid,
          reason: 'resourceId "$bad"',
        );
      }
    });

    test('resource identity is compared exactly, never normalised', () {
      const DeliveryEvidenceRef padded = DeliveryEvidenceRef(
        resourceId: ' $orderA ',
        evidenceId: evidenceA,
      );
      expect(padded.belongsTo(orderA), isFalse);
      expect(
        validateDeliveryEvidenceRef(padded, resourceId: orderA),
        DeliveryProofDenial.evidenceResourceIdInvalid,
        reason: 'a padded id is not silently repaired into a valid one',
      );
    });

    test('belongsTo cannot certify a malformed reference (FIX-001)', () {
      // Raw equality would have matched two identically-malformed values and
      // returned a misleading true through the public convenience API.
      const DeliveryEvidenceRef bothEmpty = DeliveryEvidenceRef(
        resourceId: '',
        evidenceId: '',
      );
      expect(bothEmpty.belongsTo(''), isFalse,
          reason: 'empty == empty must not certify');

      const DeliveryEvidenceRef badResource = DeliveryEvidenceRef(
        resourceId: 'ord_short',
        evidenceId: evidenceA,
      );
      expect(badResource.belongsTo('ord_short'), isFalse);

      const DeliveryEvidenceRef badEvidence = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: 'evd_short',
      );
      expect(badEvidence.belongsTo(orderA), isFalse,
          reason: 'an invalid evidenceId makes the whole ref uncertifiable');
    });

    test('belongsTo rejects a malformed target resource (FIX-001)', () {
      for (final String badTarget in malformedIds) {
        expect(
          ref.belongsTo(badTarget),
          isFalse,
          reason: 'target "\$badTarget"',
        );
      }
      expect(ref.belongsTo(' \$orderA '), isFalse, reason: 'padded target');
    });

    test('belongsTo still returns true for the valid exact case', () {
      expect(ref.belongsTo(orderA), isTrue);
      expect(ref.belongsTo(orderB), isFalse, reason: 'valid but different');
    });

    test('a malformed target resource has its own denial (FIX-001)', () {
      for (final String badTarget in malformedIds) {
        expect(
          validateDeliveryEvidenceRef(ref, resourceId: badTarget),
          DeliveryProofDenial.expectedResourceIdInvalid,
          reason: 'target "\$badTarget"',
        );
      }
    });

    test('denial precedence keeps the three failures distinguishable', () {
      // 1. stored resource invalid wins over everything, so a malformed stored
      //    reference is never masked by a later check.
      expect(
        validateDeliveryEvidenceRef(
          const DeliveryEvidenceRef(
            resourceId: 'ord_short',
            evidenceId: 'evd_short',
          ),
          resourceId: 'also_bad',
        ),
        DeliveryProofDenial.evidenceResourceIdInvalid,
      );
      // 2. then the evidence id.
      expect(
        validateDeliveryEvidenceRef(
          const DeliveryEvidenceRef(
            resourceId: orderA,
            evidenceId: 'evd_short',
          ),
          resourceId: 'also_bad',
        ),
        DeliveryProofDenial.evidenceIdInvalid,
      );
      // 3. then the target resource.
      expect(
        validateDeliveryEvidenceRef(ref, resourceId: 'also_bad'),
        DeliveryProofDenial.expectedResourceIdInvalid,
      );
      // 4. and only then a genuine mismatch, with both sides valid.
      expect(
        validateDeliveryEvidenceRef(ref, resourceId: orderB),
        DeliveryProofDenial.evidenceResourceMismatch,
      );
      // 5. otherwise null.
      expect(validateDeliveryEvidenceRef(ref, resourceId: orderA), isNull);
    });

    test('equality and hashCode include BOTH identities', () {
      const DeliveryEvidenceRef a = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceA,
      );
      const DeliveryEvidenceRef same = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceA,
      );
      const DeliveryEvidenceRef otherResource = DeliveryEvidenceRef(
        resourceId: orderB,
        evidenceId: evidenceA,
      );
      const DeliveryEvidenceRef otherEvidence = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceB,
      );

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(otherResource),
          reason: 'same evidence on a different order is a different ref');
      expect(a, isNot(otherEvidence),
          reason: 'different evidence on the same order is a different ref');
    });

    test('toString exposes only the bounded opaque identifiers', () {
      const DeliveryEvidenceRef a = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceA,
      );
      final String rendered = a.toString();
      expect(rendered, contains(orderA));
      expect(rendered, contains(evidenceA));
      // Both are opaque ids, so both are already bounded at 64.
      expect(orderA.length, lessThanOrEqualTo(maxIdLength));
      expect(evidenceA.length, lessThanOrEqualTo(maxIdLength));
      expect(rendered.length, lessThan(2 * maxIdLength + 40));
    });

    test('a valid reference renders both bounded identifiers (FIX-002)', () {
      final String rendered = ref.toString();
      expect(rendered, contains(orderA));
      expect(rendered, contains(evidenceA));
      expect(rendered.length, lessThan(2 * maxIdLength + 40));
      expect(rendered.split('\n').length, 1);
    });

    test('a malformed stored resource is never echoed (FIX-002)', () {
      // Synthetic hostile content, confined to this test.
      const String hostile =
          'https://evil.example/a/b?x=1\nFAKE LOG LINE\tPADDING'
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      final DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: hostile,
        evidenceId: evidenceA,
      );

      expect(bad.isWellFormed, isFalse);
      final String rendered = bad.toString();
      expect(rendered, 'DeliveryEvidenceRef(invalid)');
      expect(rendered, isNot(contains('evil.example')));
      expect(rendered, isNot(contains('FAKE LOG LINE')));
      expect(rendered, isNot(contains('PADDING')));
      expect(rendered, isNot(contains('\n')));
      expect(rendered, isNot(contains('\t')));
      expect(rendered.split('\n').length, 1, reason: 'single line');
      expect(rendered.length, lessThan(64), reason: 'bounded');
      // The fields themselves are untouched — rendering is not repair.
      expect(bad.resourceId, hostile);
    });

    test('a malformed evidence id is never echoed (FIX-002)', () {
      const String hostile = 'file:///etc/passwd\rSECRET-EVIDENCE-BLOB';
      final DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: hostile,
      );

      expect(bad.isWellFormed, isFalse);
      final String rendered = bad.toString();
      expect(rendered, 'DeliveryEvidenceRef(invalid)');
      expect(rendered, isNot(contains('passwd')));
      expect(rendered, isNot(contains('SECRET-EVIDENCE-BLOB')));
      expect(rendered, isNot(contains(orderA)),
          reason: 'a malformed instance reveals nothing, valid field or not');
      expect(rendered.length, lessThan(64));
      expect(bad.evidenceId, hostile);
    });

    test('both fields malformed are never echoed (FIX-002)', () {
      final DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: 'x' * 200,
        evidenceId: 'y' * 200,
      );
      expect(bad.isWellFormed, isFalse);
      final String rendered = bad.toString();
      expect(rendered, 'DeliveryEvidenceRef(invalid)');
      expect(rendered, isNot(contains('xxx')));
      expect(rendered, isNot(contains('yyy')));
      expect(rendered.length, lessThan(64));
    });

    test('a safe rendering does not certify the instance (FIX-002)', () {
      // toString reports; it never validates, repairs or promotes.
      const DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: 'ord_short',
        evidenceId: 'evd_short',
      );
      expect(bad.toString(), 'DeliveryEvidenceRef(invalid)');
      expect(bad.isWellFormed, isFalse, reason: 'still malformed');
      expect(bad.belongsTo(orderA), isFalse);
      expect(
        validateDeliveryEvidenceRef(bad, resourceId: orderA),
        DeliveryProofDenial.evidenceResourceIdInvalid,
        reason: 'the validator remains authoritative',
      );
      expect(bad.resourceId, 'ord_short', reason: 'unchanged');
      expect(bad.evidenceId, 'evd_short', reason: 'unchanged');
    });

    test('the validator repairs nothing', () {
      const DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: 'evd_short',
      );
      expect(
        validateDeliveryEvidenceRef(bad, resourceId: orderA),
        DeliveryProofDenial.evidenceIdInvalid,
      );
      expect(bad.evidenceId, 'evd_short', reason: 'unchanged after refusal');
    });

    test('toString carries identifiers only', () {
      // A log line or crash report must not become an evidence leak.
      expect(ref.toString(), contains(evidenceA));
      expect(ref.toString(), contains(orderA));
      expect(ref.toString().length, lessThan(120));
    });
  });

  group('the references carry no proof material and no mechanism', () {
    late String source;

    setUpAll(() {
      source = File('lib/src/delivery_proof.dart').readAsStringSync();
    });

    test('no proof mechanism is named as a field, type or value', () {
      // Documentation may *say* these are not selected; a declaration must not
      // exist. Comment lines are stripped so the prose that rules them out does
      // not mask a real declaration.
      final String code = source
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('///'))
          .join('\n')
          .toLowerCase();

      for (final String mechanism in <String>[
        'otp',
        'qr',
        'barcode',
        'signature',
        'photo',
        'image',
        'video',
        'gps',
        'latitude',
        'longitude',
        'biometric',
        'attestation',
      ]) {
        expect(
          code,
          isNot(contains(mechanism)),
          reason: '"$mechanism" must not be declared by this contract',
        );
      }
    });

    test('the policy bound aliases maxIdLength in source (FIX-002)', () {
      // Deliberately a source-shape assertion, and deliberately narrow.
      //
      // The property being protected here IS source coupling, not runtime
      // arithmetic: `= 64` and `= maxIdLength` are numerically identical today,
      // so no runtime test can distinguish them, and a second numeric literal
      // could drift from the canonical ceiling without any behavioural test
      // noticing. That is the one situation where reading the declaration is
      // the right instrument — it is supplementary everywhere else.
      final RegExp decl = RegExp(
        r'const\s+int\s+maxDeliveryProofPolicyRefLength\s*=\s*([^;]+);',
      );
      final RegExpMatch? m = decl.firstMatch(source);
      expect(m, isNotNull, reason: 'the constant declaration must be findable');

      final String rhs = m!.group(1)!.trim();
      expect(
        rhs,
        'maxIdLength',
        reason: 'the proof-policy ceiling must alias the canonical constant, '
            'not repeat its literal — see ADR-0008',
      );
      expect(
        rhs,
        isNot(contains('64')),
        reason: 'no duplicate numeric source of truth',
      );
    });

    test('no evidence material or storage locator is declared', () {
      final String code = source
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('///'))
          .join('\n')
          .toLowerCase();

      for (final String forbidden in <String>[
        'bytes',
        'base64',
        'blob',
        'url',
        'signedurl',
        'path',
        'address',
        'phone',
        'amount',
        'retention',
        'expires',
        'duration',
        'datetime',
      ]) {
        expect(
          code,
          isNot(contains(forbidden)),
          reason: '"$forbidden" would put material, a locator or a policy '
              'decision into a reference type',
        );
      }
    });

    test('no proof-status or success vocabulary is declared', () {
      final String code = source
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('///'))
          .join('\n')
          .toLowerCase();

      for (final String forbidden in <String>[
        'proofsatisfied',
        'proofstatus',
        'delivered',
        'issuccess',
        'visibility',
        'acl',
      ]) {
        expect(code, isNot(contains(forbidden)));
      }
    });
  });

  group('nothing became executable (regression)', () {
    test('OrderState.delivered remains unreachable', () {
      expect(
        OrderState.notYetImplemented.contains(OrderState.delivered),
        isTrue,
      );
      expect(
        OrderState.executableInThisSlice.contains(OrderState.delivered),
        isFalse,
      );
      expect(
        OrderState.aggregateShapeKnown.contains(OrderState.delivered),
        isFalse,
        reason: 'no order/reservation pairing was invented for delivered',
      );
      expect(
        canonicalAggregatePairs.containsKey(OrderState.delivered),
        isFalse,
      );
    });

    test('CustodyHolderKind.customer remains unreachable', () {
      expect(
        CustodyHolderKind.notYetImplemented,
        <CustodyHolderKind>{CustodyHolderKind.customer},
      );
      expect(
        CustodyHolderKind.executableInThisSlice
            .contains(CustodyHolderKind.customer),
        isFalse,
      );
      // ...and no custody command produces it.
      expect(CustodyCommand.values.length, 2);
      for (final CustodyCommand c in CustodyCommand.values) {
        expect(c.commandType, isNot(contains('customer')));
      }
    });

    test('rider AssignmentState.completed remains future — B3-C2', () {
      expect(
        AssignmentState.notYetImplementedForRole(AssignmentRole.rider),
        <AssignmentState>{AssignmentState.completed},
      );
      expect(
        AssignmentState.executableForRole(AssignmentRole.rider)
            .contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
        reason: 'no rider completion cost was invented',
      );
      // Picker completion is untouched by this task.
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 3, max: 3),
      );
    });

    test('no delivery, refusal or return command exists', () {
      final List<String> allCommandTypes = <String>[
        ...LifecycleCommand.values.map((LifecycleCommand c) => c.commandType),
        ...AssignmentCommand.values.map((AssignmentCommand c) => c.commandType),
        ...CustodyCommand.values.map((CustodyCommand c) => c.commandType),
      ];
      for (final String type in allCommandTypes) {
        for (final String forbidden in <String>[
          'deliver',
          'refus',
          'return',
          'proof',
          'attempt',
          'dispute',
        ]) {
          expect(
            type,
            isNot(contains(forbidden)),
            reason: '$type must not exist after FND-003D1',
          );
        }
      }
    });

    test('no delivery/proof event id was added', () {
      final List<String> allEvents = <String>[
        ...LifecycleEventType.all,
        ...AssignmentEventType.all,
        ...CustodyEventType.all,
      ];
      for (final String e in allEvents) {
        // `order.in_delivery` is the accepted FND-003B3A dispatch boundary and
        // is the ONLY delivery-adjacent event that may exist. Pinning it by
        // name is stronger than skipping the substring: a new
        // `order.delivered` or `delivery.proof_submitted` would still fail.
        if (e == LifecycleEventType.orderInDelivery) {
          continue;
        }
        for (final String forbidden in <String>[
          'deliver',
          'proof',
          'refus',
          'return',
          'dispute',
        ]) {
          expect(
            e,
            isNot(contains(forbidden)),
            reason: '$e must not exist after FND-003D1',
          );
        }
      }
      // The dispatch-boundary event is present and unchanged.
      expect(allEvents, contains('order.in_delivery'));
      // ...and nothing named for delivery *completion* exists.
      expect(allEvents, isNot(contains('order.delivered')));
      expect(LifecycleEventType.all.length, 8);
      expect(AssignmentEventType.all.length, 11);
      expect(CustodyEventType.all.length, 2);
    });
  });

  group('permissions are untouched', () {
    test('the three proof/dispute permissions keep their exact rules', () {
      expect(
        Permission.byId('rider.delivery.submit_proof'),
        Permission.riderSubmitDeliveryProof,
      );
      expect(
        Permission.byId('customer.delivery.confirm_proof'),
        Permission.customerConfirmDeliveryProof,
      );
      expect(
        Permission.byId('customer.dispute.raise'),
        Permission.customerRaiseDispute,
      );
      expect(
        permissionMatrix[Permission.riderSubmitDeliveryProof]!.eligibleRoles,
        <CommerceRole>{CommerceRole.rider},
      );
      expect(
        permissionMatrix[Permission.customerConfirmDeliveryProof]!
            .eligibleRoles,
        <CommerceRole>{CommerceRole.customer},
      );
    });

    test('customer confirmation is still participation, not settlement', () {
      // The accepted matrix says confirming does not settle cash and does not
      // close a dispute. FND-003D1 did not reinterpret that.
      final String restriction =
          permissionMatrix[Permission.customerConfirmDeliveryProof]!
              .restriction;
      expect(restriction, contains('Participation in proof only'));
      expect(restriction.toLowerCase(), contains('does not settle'));
    });

    test('no permission was added by this task', () {
      expect(Permission.values.length, 38);
      expect(permissionMatrix.length, 38);
      for (final Permission p in Permission.values) {
        expect(p.id, isNot(contains('evidence')));
        expect(p.id, isNot(contains('proof_policy')));
      }
    });
  });

  group('privacy boundary', () {
    test('an evidence reference is safe to route, unlike its material', () {
      // Everything the reference exposes is an identifier, which is exactly
      // what EventEnvelope.payload is already documented to carry.
      const DeliveryEvidenceRef ref = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceA,
      );
      expect(ref.resourceId, isNot(contains('@')));
      expect(ref.evidenceId, isNot(contains('@')));
      expect(isValidOpaqueId(ref.evidenceId), isTrue);
      expect(isValidOpaqueId(ref.resourceId), isTrue);
    });

    test('a reference authorizes nothing and proves nothing', () {
      // There is no method on either type that answers "may I?" or "is it
      // proven?" — the only questions they answer are structural.
      const DeliveryEvidenceRef ref = DeliveryEvidenceRef(
        resourceId: orderA,
        evidenceId: evidenceA,
      );
      expect(ref.isWellFormed, isTrue);
      expect(ref.belongsTo(orderA), isTrue);
      // Well-formed and correctly bound is the strongest statement available,
      // and it is not a claim about delivery.
      expect(validateDeliveryEvidenceRef(ref, resourceId: orderA), isNull);
    });
  });
}
