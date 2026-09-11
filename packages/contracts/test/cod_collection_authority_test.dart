import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

import 'support/cod_collection_fixtures.dart';

/// Every FND-003C1 production source, read as text. Source scanning is how this
/// repository proves a *negative* — that a vocabulary does not exist.
List<File> c1Sources() => <String>[
  'money_policy.dart',
  'order_financial_snapshot.dart',
  'payment_state.dart',
  'payment_facts.dart',
  'cash_journal_entry.dart',
  'cod_collection_command.dart',
  'cod_collection_denial.dart',
  'cod_collection_authorization.dart',
  'cod_collection_request.dart',
  'cod_collection_transition.dart',
  'cod_collection_evaluator.dart',
  'cash_and_payments.dart',
].map((String f) => File('lib/src/$f')).toList();

/// Code only: comments stripped, so prose *describing* what was not built
/// cannot be mistaken for the thing itself.
String codeOf(File f) => f
    .readAsLinesSync()
    .where((String l) {
      final String t = l.trimLeft();
      return !t.startsWith('///') && !t.startsWith('//');
    })
    .join('\n');

void main() {
  group('authorization cannot be bypassed', () {
    test('a grant for the wrong permission reaches nothing', () {
      final AuthorizationGrant wrong = codGrant(
        permission: Permission.riderViewAssignedWork,
      );
      final CodCollectionOutcome o = collect(grant: wrong);
      expect(o.allowed, isFalse);
      expect(o.denial, CodCollectionDenial.authorizationGrantMismatch);
      expect(o.transition, isNull);
    });

    test("one principal's grant cannot authorize another's collection", () {
      expect(
        collect(
          grant: codGrant(
            principalId: otherRiderId,
            assigned: <String>{otherRiderId},
          ),
        ).denial,
        CodCollectionDenial.authorizationGrantMismatch,
      );
    });

    test('a grant for another order cannot authorize this one', () {
      expect(
        collect(grant: codGrant(resourceId: otherOrderId)).denial,
        CodCollectionDenial.authorizationGrantMismatch,
      );
    });

    test('a system worker cannot witness cash changing hands', () {
      final CodCollectionOutcome o = collect(actor: worker());
      expect(o.allowed, isFalse);
      expect(
        o.denial,
        anyOf(
          CodCollectionDenial.authorizationGrantMismatch,
          CodCollectionDenial.actorNotHumanPrincipal,
        ),
      );
    });

    test('a suspended or unassigned rider cannot obtain a grant at all', () {
      expect(
        () => codGrant(status: MembershipStatus.suspended),
        throwsStateError,
      );
      expect(
        () => codGrant(assigned: const <String>{}),
        throwsStateError,
        reason: 'the rule requires an accepted assignment on the resource',
      );
    });

    test(
      'a grant cannot be fabricated — only evaluateAuthorization makes one',
      () {
        final AuthorizationGrant g = codGrant();
        expect(g.permission, Permission.riderReportCodCollection);
        expect(g.covers(principalId: riderId, resourceId: orderId), isTrue);
        expect(
          g.covers(principalId: otherRiderId, resourceId: orderId),
          isFalse,
        );
        expect(
          g.covers(principalId: riderId, resourceId: otherOrderId),
          isFalse,
        );
      },
    );
  });

  group('no permission was added, and none was widened', () {
    test('the count is unchanged at 39', () {
      expect(Permission.values.length, 39);
      expect(permissionMatrix.length, 39);
    });

    test('the operation uses the accepted rider cash permission unchanged', () {
      expect(
        CodCollectionCommand.reportCodCollection.requiredPermission,
        Permission.riderReportCodCollection,
      );
      final PermissionRule r =
          permissionMatrix[Permission.riderReportCodCollection]!;
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.rider});
      expect(r.scopes, <ScopeRequirement>{ScopeRequirement.assignedResource});
      expect(r.acceptableStatuses, <MembershipStatus>{MembershipStatus.active});
      // Its accepted restriction text still says reporting is not settlement.
      expect(r.restriction.toLowerCase(), contains('not settlement'));
      expect(r.restriction.toLowerCase(), contains('never writes a balance'));
    });

    test(
      'admin.cash.record_reconciliation is untouched and dual-control-ish',
      () {
        final PermissionRule r =
            permissionMatrix[Permission.adminRecordCashReconciliation]!;
        expect(r.eligibleRoles, <CommerceRole>{CommerceRole.admin});
        expect(r.reasonRequired, isTrue);
      },
    );

    test('no balance-edit or status-patch permission exists', () {
      for (final Permission p in Permission.values) {
        for (final String forbidden in <String>[
          'balance.set',
          'balance.edit',
          'journal.edit',
          'journal.delete',
          'payment.set_state',
          'cash.override',
          'cash.settle',
          'cash.remit_confirm',
        ]) {
          expect(p.id, isNot(contains(forbidden)));
        }
      }
      for (final ProhibitedCapability c in ProhibitedCapability.all) {
        for (final String fragment in c.forbiddenIdFragments) {
          for (final Permission p in Permission.values) {
            expect(p.id, isNot(contains(fragment)), reason: c.label);
          }
        }
      }
    });
  });

  group('non-goals stay non-executable', () {
    test('collecting cash does not deliver, complete or move custody', () {
      final CodCollectionTransition t = collect().transition!;
      expect(t.changesOrder, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.completesRider, isFalse);
      expect(OrderState.notYetImplemented, contains(OrderState.delivered));
      expect(
        CustodyHolderKind.notYetImplemented,
        contains(CustodyHolderKind.customer),
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
      );
    });

    test('no C1 source references delivery success or proof', () {
      for (final File f in c1Sources()) {
        final String code = codeOf(f);
        for (final String token in <String>[
          'OrderState.delivered',
          'CustodyHolderKind.customer',
          'AssignmentState.completed',
          'DeliveryProofAssessment',
          'satisfied',
        ]) {
          expect(code, isNot(contains(token)), reason: '${f.path}: $token');
        }
      }
    });

    test('no remittance, settlement, payout or refund vocabulary exists', () {
      const List<String> forbidden = <String>[
        'remit',
        'settle',
        'payout',
        'refund',
        'compensat',
        'commissionpayout',
        'reconcil',
        'disburse',
        'withdraw',
        'fxrate',
        'exchangerate',
        'convertcurrency',
      ];
      for (final File f in c1Sources()) {
        final String code = codeOf(f).toLowerCase();
        for (final String t in forbidden) {
          expect(code, isNot(contains(t)), reason: '${f.path}: "$t"');
        }
      }
    });

    test(
      'no balance setter, journal editor or payment-state setter exists',
      () {
        for (final File f in c1Sources()) {
          final String code = codeOf(f);
          for (final String t in <String>[
            'setBalance',
            'updateBalance',
            'editEntry',
            'deleteEntry',
            'setPaymentState',
            'setState',
            'forceState',
          ]) {
            expect(code, isNot(contains(t)), reason: '${f.path}: $t');
          }
        }
      },
    );

    test('no request type lets a caller choose a state or an account', () {
      final String req = codeOf(File('lib/src/cod_collection_request.dart'));
      expect(req, isNot(contains('PaymentState')));
      expect(req, isNot(contains('JournalAccount')));
    });

    test('commands are named operations, not state arguments', () {
      for (final CodCollectionCommand c in CodCollectionCommand.values) {
        expect(
          c.commandType,
          matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
        );
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('set_')));
        expect(c.commandType, isNot(contains('patch')));
      }
      expect(CodCollectionCommand.values.length, 1);
    });

    test('no serialization or persistence was added', () {
      for (final File f in c1Sources()) {
        final String code = codeOf(f);
        for (final String t in <String>[
          'toJson',
          'fromJson',
          'Firebase',
          'Firestore',
          'cloud_firestore',
          'http',
        ]) {
          expect(code, isNot(contains(t)), reason: '${f.path}: $t');
        }
      }
    });

    test('the contract version is 0.11 and the major did not move', () {
      expect(ContractVersion.current, const ContractVersion(0, 11));
      expect(ContractVersion.current.major, 0);
      expect(
        ContractVersion.current.isVersionCompatibleWith(
          const ContractVersion(0, 10),
        ),
        isTrue,
      );
    });

    test('disputed is enumerated but this slice can never produce it', () {
      expect(PaymentState.values.length, 4);
      expect(PaymentState.producibleInThisSlice, <PaymentState>{
        PaymentState.partiallyCollected,
        PaymentState.collected,
      });
      expect(
        PaymentState.producibleInThisSlice,
        isNot(contains(PaymentState.disputed)),
      );
      // Sweep every collectable start state; `disputed` is never reached.
      final Set<PaymentState> produced = <PaymentState>{};
      for (final Money amount in <Money>[bdt(1), bdt(126000)]) {
        final CodCollectionOutcome o = collect(req: request(amount: amount));
        if (o.transition != null) {
          produced.add(o.transition!.payment.toState);
        }
      }
      expect(produced, isNot(contains(PaymentState.disputed)));
      expect(produced, <PaymentState>{
        PaymentState.partiallyCollected,
        PaymentState.collected,
      });
    });
  });
}
