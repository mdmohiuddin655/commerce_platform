import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/attempt_return_fixtures.dart';

DeliveryAttemptOutcome attemptWith(AuthorizationGrant grant, Principal actor) =>
    evaluateRecordOutForDelivery(
      request: attemptRequest(),
      grant: grant,
      actor: actor,
      resource: resourceContext(),
      attempt: attempt(),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    );

ReturnOutcome receiptWith(AuthorizationGrant grant, Principal actor) =>
    evaluateRecordReturnShopReceipt(
      request: ReturnShopReceiptRequest(
        expectedReturnRevision: 3,
        expectedOrderRevision: 7,
        expectedCustodyRevision: 4,
        expectedRiderSlotRevision: 2,
        recordedAtUtc: utcNow,
      ),
      grant: grant,
      actor: actor,
      resource: resourceContext(),
      returnRecord: returnRecord(revision: 3, state: ReturnState.inTransit),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    );

void main() {
  group('authorization cannot be bypassed', () {
    test('a grant for the wrong permission reaches nothing', () {
      // A view grant is a real, canonical grant — it simply is not this
      // operation's permission.
      final AuthorizationGrant wrong = attemptReturnGrant(
        permission: Permission.riderViewAssignedWork,
        principalId: riderId,
        role: CommerceRole.rider,
        assigned: <String>{riderId},
      );
      final DeliveryAttemptOutcome o = attemptWith(wrong, user(riderId));
      expect(o.allowed, isFalse);
      expect(o.denial, AttemptReturnDenial.authorizationGrantMismatch);
      expect(o.transition, isNull);
    });

    test('one principal\'s grant cannot authorize another\'s command', () {
      final AuthorizationGrant other = riderAttemptGrant(
        principalId: otherRiderId,
      );
      expect(
        attemptWith(other, user(riderId)).denial,
        AttemptReturnDenial.authorizationGrantMismatch,
      );
    });

    test('a grant for another order cannot authorize this one', () {
      final AuthorizationGrant elsewhere = riderAttemptGrant(
        resourceId: otherOrderId,
      );
      expect(
        attemptWith(elsewhere, user(riderId)).denial,
        AttemptReturnDenial.authorizationGrantMismatch,
      );
    });

    test('the shop receipt needs the shop permission, not the rider one', () {
      // The rider's own attempt grant must not open a shop-side custody move.
      expect(
        receiptWith(riderAttemptGrant(), user(riderId)).denial,
        AttemptReturnDenial.authorizationGrantMismatch,
      );
      // Nor does an admin return grant satisfy it: receipt is shop-side.
      expect(
        receiptWith(adminReturnGrant(), user(adminId)).denial,
        AttemptReturnDenial.authorizationGrantMismatch,
      );
    });

    test('agent.fulfillment.record_progress is not a custody shortcut', () {
      final AuthorizationGrant progress = attemptReturnGrant(
        permission: Permission.agentRecordShopFulfillment,
        principalId: agentId,
        role: CommerceRole.agent,
        memberShops: <String>{shopId},
      );
      expect(
        receiptWith(progress, user(agentId)).denial,
        AttemptReturnDenial.authorizationGrantMismatch,
      );
    });

    test('a suspended member cannot obtain a grant at all', () {
      expect(
        () => attemptReturnGrant(
          permission: Permission.riderRecordDeliveryAttempt,
          principalId: riderId,
          role: CommerceRole.rider,
          status: MembershipStatus.suspended,
          assigned: <String>{riderId},
        ),
        throwsStateError,
      );
    });

    test('an out-of-region admin cannot obtain a return grant', () {
      expect(
        () => attemptReturnGrant(
          permission: Permission.adminAdministerReturn,
          principalId: adminId,
          role: CommerceRole.admin,
          memberRegion: 'chittagong',
        ),
        throwsStateError,
      );
    });

    test('an agent with no shop authority cannot obtain a receipt grant', () {
      // Empty membership shops mean **no** shop authority, never all shops.
      expect(
        () => attemptReturnGrant(
          permission: Permission.agentRecordReturnReceipt,
          principalId: agentId,
          role: CommerceRole.agent,
        ),
        throwsStateError,
      );
    });

    test(
      'a grant cannot be fabricated — only evaluateAuthorization makes one',
      () {
        // If this ever compiles with a public constructor, the whole binding is
        // worthless. The type is `final` with a library-private constructor.
        final AuthorizationGrant g = riderAttemptGrant();
        expect(g.permission, Permission.riderRecordDeliveryAttempt);
        expect(g.principalId, riderId);
        expect(g.resourceId, orderId);
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

  group('the new permission is the smallest one that works', () {
    test('exactly one permission was added, and it is the receipt one', () {
      expect(Permission.values.length, 39);
      expect(permissionMatrix.length, 39);
      final Permission? p = Permission.byId('agent.return.record_receipt');
      expect(p, isNotNull);
      expect(p, Permission.agentRecordReturnReceipt);
      expect(p!.family, 'agent');
    });

    test('its rule is shop-scoped, agent-only and reason-bearing', () {
      final PermissionRule r =
          permissionMatrix[Permission.agentRecordReturnReceipt]!;
      expect(r.eligibleRoles, <CommerceRole>{CommerceRole.agent});
      expect(r.scopes, contains(ScopeRequirement.ownShop));
      expect(r.reasonRequired, isTrue);
      expect(r.acceptableStatuses, <MembershipStatus>{MembershipStatus.active});
      // It must not read as a stock or status lever.
      expect(r.restriction.toLowerCase(), contains('restores no stock'));
    });

    test('no arbitrary custody or status override permission was added', () {
      for (final Permission p in Permission.values) {
        for (final String forbidden in <String>[
          'custody.override',
          'custody.force',
          'return.override',
          'return.force_close',
          'stock.adjust',
          'stock.restore',
          'inventory.set',
          'attempt.set_state',
          'delivery.mark_delivered',
        ]) {
          expect(p.id, isNot(contains(forbidden)));
        }
      }
      // And the repository's standing prohibitions still hold.
      for (final ProhibitedCapability c in ProhibitedCapability.all) {
        for (final String fragment in c.forbiddenIdFragments) {
          for (final Permission p in Permission.values) {
            expect(p.id, isNot(contains(fragment)), reason: c.label);
          }
        }
      }
    });

    test('the accepted permissions this slice reuses were not widened', () {
      // Reused as-is: the rider attempt permission and admin return
      // administration. Their rules must still be exactly what was accepted.
      final PermissionRule rider =
          permissionMatrix[Permission.riderRecordDeliveryAttempt]!;
      expect(rider.eligibleRoles, <CommerceRole>{CommerceRole.rider});
      expect(rider.scopes, <ScopeRequirement>{
        ScopeRequirement.assignedResource,
      });

      final PermissionRule admin =
          permissionMatrix[Permission.adminAdministerReturn]!;
      expect(admin.eligibleRoles, <CommerceRole>{CommerceRole.admin});
      expect(admin.reasonRequired, isTrue);
    });

    test('every command maps to a permission that exists in the matrix', () {
      for (final DeliveryAttemptCommand c in DeliveryAttemptCommand.values) {
        expect(permissionMatrix.containsKey(c.requiredPermission), isTrue);
      }
      for (final ReturnCommand c in ReturnCommand.values) {
        expect(permissionMatrix.containsKey(c.requiredPermission), isTrue);
      }
    });
  });
}
