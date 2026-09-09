import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('matrix integrity', () {
    test('every permission has exactly one rule', () {
      expect(permissionMatrix.keys.toSet(), Permission.values.toSet());
      for (final MapEntry<Permission, PermissionRule> e
          in permissionMatrix.entries) {
        expect(e.value.permission, e.key, reason: 'rule keyed by its own id');
      }
    });

    test('permission ids are unique and stable strings', () {
      final Set<String> ids =
          Permission.values.map((Permission p) => p.id).toSet();

      expect(ids.length, Permission.values.length);
      for (final Permission p in Permission.values) {
        expect(Permission.byId(p.id), p);
      }
    });

    test('an unknown permission id resolves to null, not a guess', () {
      expect(Permission.byId('admin.everything'), isNull);
    });

    test('no rule is granted to every role', () {
      for (final PermissionRule rule in permissionMatrix.values) {
        expect(
          rule.eligibleRoles.length,
          lessThan(CommerceRole.values.length),
          reason: '${rule.permission.id} is granted too widely',
        );
        expect(rule.eligibleRoles, isNotEmpty);
      }
    });

    test('permission family matches its eligible role', () {
      // Least privilege is legible: a customer.* permission is a customer's.
      const Map<String, CommerceRole> familyRole = <String, CommerceRole>{
        'customer': CommerceRole.customer,
        'agent': CommerceRole.agent,
        'picker': CommerceRole.picker,
        'rider': CommerceRole.rider,
        'admin': CommerceRole.admin,
      };

      for (final PermissionRule rule in permissionMatrix.values) {
        final CommerceRole? expected = familyRole[rule.permission.family];
        expect(expected, isNotNull,
            reason: 'unknown family ${rule.permission.family}');
        expect(
          rule.eligibleRoles,
          <CommerceRole>{expected!},
          reason: '${rule.permission.id} must belong to ${expected.id} only',
        );
      }
    });

    test('by default only an active membership may act', () {
      for (final PermissionRule rule in permissionMatrix.values) {
        expect(
          rule.acceptableStatuses,
          <MembershipStatus>{MembershipStatus.active},
          reason: '${rule.permission.id}: no wind-down permission exists yet; '
              'adding one is a deliberate lifecycle-slice decision',
        );
      }
    });
  });

  group('prohibited capabilities do not exist', () {
    test('no permission id implements a forbidden capability', () {
      for (final ProhibitedCapability forbidden in ProhibitedCapability.all) {
        for (final String fragment in forbidden.forbiddenIdFragments) {
          for (final Permission p in Permission.values) {
            expect(
              p.id.contains(fragment),
              isFalse,
              reason: '${p.id} looks like "${forbidden.label}" — '
                  '${forbidden.why}',
            );
          }
        }
      }
    });

    test('the forbidden list itself is populated and explained', () {
      expect(ProhibitedCapability.all.length, greaterThanOrEqualTo(4));
      for (final ProhibitedCapability f in ProhibitedCapability.all) {
        expect(f.why, isNotEmpty);
        expect(f.forbiddenIdFragments, isNotEmpty);
      }
    });
  });

  group('admin authority is bounded', () {
    test('every mutating admin permission requires a reason', () {
      const Set<Permission> adminReads = <Permission>{
        Permission.adminViewReleaseHealth,
      };

      for (final PermissionRule rule in permissionMatrix.values) {
        if (rule.permission.family != 'admin' ||
            adminReads.contains(rule.permission)) {
          continue;
        }
        expect(
          rule.reasonRequired,
          isTrue,
          reason: '${rule.permission.id} must be reason-bearing and audited',
        );
      }
    });

    test('the highest-consequence admin actions need dual control', () {
      for (final Permission p in <Permission>[
        Permission.adminApproveWorker,
        Permission.adminReinstateWorker,
        Permission.adminPublishPolicyVersion,
        Permission.adminRecordCashReconciliation,
      ]) {
        expect(permissionMatrix[p]!.approvalRequired, isTrue,
            reason: '${p.id} must require a second principal');
      }
    });

    test('support read confers no mutation authority', () {
      final PermissionRule support =
          permissionMatrix[Permission.adminSupportViewOrder]!;

      expect(support.reasonRequired, isTrue);
      expect(support.scopes, <ScopeRequirement>{ScopeRequirement.ownRegion});
      // It is one read permission; it does not appear in any mutating rule.
      expect(support.permission.id, contains('view'));
    });

    test('no admin permission is unscoped except audited exceptions', () {
      const Set<Permission> deliberatelyUnscoped = <Permission>{
        Permission.adminPublishPolicyVersion,
        Permission.adminViewReleaseHealth,
      };

      for (final PermissionRule rule in permissionMatrix.values) {
        if (rule.permission.family != 'admin') {
          continue;
        }
        if (rule.scopes.contains(ScopeRequirement.none)) {
          expect(
            deliberatelyUnscoped.contains(rule.permission),
            isTrue,
            reason: '${rule.permission.id} is unscoped without justification',
          );
        }
      }
    });
  });

  group('assignment offer scoping', () {
    const Set<Permission> acceptOrDecline = <Permission>{
      Permission.pickerAcceptAssignment,
      Permission.pickerDeclineAssignment,
      Permission.riderAcceptAssignment,
      Permission.riderDeclineAssignment,
    };

    test('accept/decline require the offer AND the region', () {
      for (final Permission p in acceptOrDecline) {
        expect(
          permissionMatrix[p]!.scopes,
          <ScopeRequirement>{
            ScopeRequirement.offeredResource,
            ScopeRequirement.ownRegion,
          },
          reason: '${p.id} must be target-isolated and region-scoped',
        );
      }
    });

    test('accept/decline never require an accepted assignment', () {
      // Requiring one in order to accept an offer would be circular.
      for (final Permission p in acceptOrDecline) {
        expect(
          permissionMatrix[p]!.scopes,
          isNot(contains(ScopeRequirement.assignedResource)),
          reason: '${p.id} must not need an assignment to create one',
        );
      }
    });

    test('offeredResource is used only for accept and decline', () {
      for (final MapEntry<Permission, PermissionRule> e
          in permissionMatrix.entries) {
        if (e.value.scopes.contains(ScopeRequirement.offeredResource)) {
          expect(
            acceptOrDecline.contains(e.key),
            isTrue,
            reason: '${e.key.id} must not be reachable from an offer alone',
          );
        }
      }
    });

    test('post-acceptance work requires an accepted assignment', () {
      for (final Permission p in <Permission>[
        Permission.pickerViewAssignedWork,
        Permission.pickerRecordShopPickup,
        Permission.pickerRecordHandoffToRider,
        Permission.riderViewAssignedWork,
        Permission.riderRecordCustodyReceipt,
        Permission.riderRecordDeliveryAttempt,
        Permission.riderSubmitDeliveryProof,
        Permission.riderReportCodCollection,
        Permission.riderSubmitRemittance,
      ]) {
        expect(
          permissionMatrix[p]!.scopes,
          contains(ScopeRequirement.assignedResource),
          reason: '${p.id} must not be reachable from an offer',
        );
      }
    });

    test('every rule declares at least one scope requirement', () {
      for (final PermissionRule rule in permissionMatrix.values) {
        expect(rule.scopes, isNotEmpty,
            reason: '${rule.permission.id} has no scope requirement');
      }
    });
  });

  group('field worker limits', () {
    test('rider and picker have no permission over money balances', () {
      for (final PermissionRule rule in permissionMatrix.values) {
        if (!CommerceRole.fieldWorkers
            .any(rule.eligibleRoles.contains)) {
          continue;
        }
        expect(
          rule.permission.id,
          allOf(
            isNot(contains('balance')),
            isNot(contains('settlement')),
            isNot(contains('journal')),
          ),
          reason: 'field workers report facts; they never mutate money',
        );
      }
    });

    test("rider cash permissions are reports, not settlement", () {
      expect(
        permissionMatrix[Permission.riderReportCodCollection]!.restriction,
        contains('not settlement'),
      );
      expect(
        permissionMatrix[Permission.riderSubmitRemittance]!.restriction,
        contains('never edits settlement history'),
      );
    });

    test('all five roles are represented', () {
      final Set<CommerceRole> covered = <CommerceRole>{
        for (final PermissionRule r in permissionMatrix.values)
          ...r.eligibleRoles,
      };

      expect(covered, CommerceRole.values.toSet());
    });
  });
}
