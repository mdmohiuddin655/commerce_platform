import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('no proof mechanism became executable', () {
    test('no mechanism is declared in any assessment file', () {
      for (final String path in assessmentSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String mechanism in proofMechanisms) {
          expect(
            code,
            isNot(contains(mechanism)),
            reason: '"$mechanism" must not be declared by $path',
          );
        }
      }
    });

    test('the mechanism scanner actually detects a planted declaration', () {
      // Negative control. Without this, the guard above proves only that the
      // scan ran — not that it can fail. A planted declaration must be caught,
      // and prose in a doc comment must NOT be, or the guard would trip on the
      // very text that rules mechanisms out.
      const String planted = '''
/// This comment mentions otp and a signature and must not trip the scan.
class Sample {
  final String otpCode = 'x';
}
''';
      final String plantedCode = codeOnly(planted);
      expect(plantedCode, contains('otp'));
      expect(
        plantedCode,
        isNot(contains('signature')),
        reason: 'doc-comment prose is stripped, so only declarations count',
      );
      expect(
        codeOnly('/// No otp, qr, signature, photo or gps here.\n').trim(),
        isEmpty,
      );
    });

    test('no client-facing command or permission is declared', () {
      for (final String path in assessmentSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'commandtype',
          'requiredpermission',
          'permission.',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: 'a normal assessment has no client command and no '
                'permission ($path)',
          );
        }
      }
    });

    test('no verdict overwrite or status setter exists', () {
      for (final String path in assessmentSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'setassessmentstatus',
          'changesatisfiedto',
          'overrideverdict',
          'patchassessment',
          'copywith',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '"$forbidden" would make assessment history rewritable',
          );
        }
      }
    });
  });

  group('nothing else became executable', () {
    test('no command anywhere maps to proof assessment', () {
      final List<String> allCommandTypes = <String>[
        ...LifecycleCommand.values.map((LifecycleCommand c) => c.commandType),
        ...AssignmentCommand.values.map((AssignmentCommand c) => c.commandType),
        ...CustodyCommand.values.map((CustodyCommand c) => c.commandType),
      ];
      for (final String type in allCommandTypes) {
        for (final String forbidden in <String>[
          'proof',
          'assess',
          'deliver',
          'refus',
          'return',
          'attempt',
          'dispute',
        ]) {
          expect(type, isNot(contains(forbidden)));
        }
      }
      expect(CustodyCommand.values.length, 2);
    });

    test('Permission.values and permissionMatrix remain 38', () {
      expect(Permission.values.length, 38);
      expect(permissionMatrix.length, 38);
      for (final Permission p in Permission.values) {
        for (final String forbidden in <String>[
          'proof.accept',
          'mark_satisfied',
          'proof.override',
          'assessment',
          'proof_status',
        ]) {
          expect(p.id, isNot(contains(forbidden)));
        }
      }
    });

    test('customer confirmation stays participation-only', () {
      expect(
        Permission.byId('customer.delivery.confirm_proof'),
        Permission.customerConfirmDeliveryProof,
      );
      final PermissionRule rule =
          permissionMatrix[Permission.customerConfirmDeliveryProof]!;
      expect(rule.eligibleRoles, <CommerceRole>{CommerceRole.customer});
      expect(rule.restriction, contains('Participation in proof only'));
      expect(rule.restriction.toLowerCase(), contains('does not settle'));

      // D2A decides nothing about whether participation is required, and adds
      // no flag that would default the answer.
      for (final String path in assessmentSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'customerconfirmed',
          'requirescustomer',
          'customerparticipation',
          'customerapproved',
        ]) {
          expect(
            api,
            isNot(contains(forbidden)),
            reason: '"$forbidden" would silently choose a policy default',
          );
        }
      }
    });

    test('customer custody remains unreachable', () {
      expect(CustodyHolderKind.notYetImplemented, <CustodyHolderKind>{
        CustodyHolderKind.customer,
      });
      expect(
        CustodyHolderKind.executableInThisSlice.contains(
          CustodyHolderKind.customer,
        ),
        isFalse,
      );
    });

    test('rider completion remains future — B3-C2 unchanged', () {
      expect(
        AssignmentState.notYetImplementedForRole(AssignmentRole.rider),
        <AssignmentState>{AssignmentState.completed},
      );
      expect(
        AssignmentState.executableForRole(
          AssignmentRole.rider,
        ).contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
        reason: 'no rider completion cost was invented by D2A or its fix',
      );
    });

    test('picker completion arithmetic is untouched', () {
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 3, max: 3),
      );
      expect(
        reachableSlotRevisionRange(
          2,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 5, max: 6),
      );
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed),
        isNull,
        reason: 'the role-less default answer is unchanged',
      );
    });

    test('the custody dispatch boundary is unchanged', () {
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordRiderReceipt),
      );
      expect(t.orderEffect.toState, OrderState.inDelivery);
      expect(t.pickerCompletion, isNotNull);
      expect(t.inventoryEffect.availableStockDelta, 0);
    });
  });

  group('contract version', () {
    test('the build still reports 0.8 — this is a fix, not a bump', () {
      expect(ContractVersion.current.toString(), '0.8');
    });

    test('no serialization was added by this slice', () {
      for (final String path in assessmentSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        expect(api, isNot(contains('tojson')));
        expect(api, isNot(contains('fromjson')));
        expect(api, isNot(contains('jsonencode')));
      }
    });

    test('the public barrel still exposes the whole assessment surface', () {
      // Reached through `package:cp_contracts/cp_contracts.dart` only — if the
      // split had dropped an export, this file would not compile.
      expect(DeliveryProofAssessmentVerdict.values.length, 2);
      expect(DeliveryProofAssessmentDenial.values, isNotEmpty);
      expect(executableProofAssessorKinds, isNotEmpty);
      expect(DeliveryProofAssessmentEventType.all.length, 1);
      expect(record().isWellFormed, isTrue);
      expect(absentAssessment.canonicalVerdict, isNull);
      expect(ctx().isWellFormed, isTrue);
      expect(validateDeliveryProofAssessmentAggregate(absentAssessment), isNull);
      expect(allowed(run()).resultingAssessmentRevision, 1);
    });
  });
}
