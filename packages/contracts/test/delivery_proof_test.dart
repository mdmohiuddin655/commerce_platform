import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

const String orderA = 'ord_Xa91ZZ0plQ7rTt4B';
const String orderB = 'ord_Zz42QQ8mmW1xVv7C';
const String evidenceA = 'evd_Aa11Bb22Cc33Dd44';

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

    test('there is no satisfaction, status or success concept', () {
      // A reference says WHICH policy applies, never that it was met.
      expect(DeliveryProofDenial.values, <DeliveryProofDenial>[
        DeliveryProofDenial.policyRefBlank,
        DeliveryProofDenial.evidenceResourceIdInvalid,
        DeliveryProofDenial.evidenceIdInvalid,
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
