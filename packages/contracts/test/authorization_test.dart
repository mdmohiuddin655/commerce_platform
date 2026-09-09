import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

const String customerId = 'usr_cust01Aa-Bb22Cc33';
const String otherCustomerId = 'usr_cust99Zz-Yy88Xx77';
const String agentId = 'usr_agent01Aa-Bb22Cc3';
const String pickerId = 'usr_pick01Aa-Bb22Cc33';
const String riderId = 'usr_ride01Aa-Bb22Cc33';
const String adminId = 'usr_admin01Aa-Bb22Cc3';
const String approverId = 'usr_appr01Aa-Bb22Cc33';
const String orderId = 'ord_Xa91ZZ0plQ7rTt4B';

Principal user(String id) => Principal.fromVerifiedSubject(id);

Membership member(
  String id,
  CommerceRole role, {
  MembershipStatus status = MembershipStatus.active,
  String? region = 'dhaka_north',
  Set<String> shops = const <String>{},
}) => Membership(
  principalId: id,
  role: role,
  status: status,
  regionId: region,
  shopIds: shops,
);

ResourceScope order({
  String? owner = customerId,
  String? shop = 'shop_alpha',
  String? region = 'dhaka_north',
  Set<String> assigned = const <String>{},
}) => ResourceScope(
  resourceId: orderId,
  ownerPrincipalId: owner,
  shopId: shop,
  regionId: region,
  assignedPrincipalIds: assigned,
);

AuthorizationDecision decide(
  Permission permission, {
  Principal? principal,
  Membership? membership,
  ResourceScope? scope,
  String? reason,
  ApprovalEvidence? approval,
}) => evaluateAuthorization(
  AuthorizationRequest(
    permission: permission,
    scope: scope ?? order(),
    principal: principal,
    membership: membership,
    reason: reason,
    approval: approval,
  ),
);

ApprovalEvidence approvalBy(String id) => ApprovalEvidence(
  approverPrincipalId: id,
  approvedAtServerUtc: DateTime.utc(2026, 9, 9),
  approvalRef: 'apr_11aa22bb33cc44dd',
);

void main() {
  group('allow paths', () {
    test('customer views their own order', () {
      final AuthorizationDecision d = decide(
        Permission.customerViewOwnOrder,
        principal: user(customerId),
        membership: member(customerId, CommerceRole.customer),
      );

      expect(d.allowed, isTrue);
      expect(d.publicMessage, 'Permitted.');
    });

    test('agent accepts an order for a shop they operate', () {
      expect(
        decide(
          Permission.agentAcceptOrder,
          principal: user(agentId),
          membership: member(
            agentId,
            CommerceRole.agent,
            shops: <String>{'shop_alpha'},
          ),
        ).allowed,
        isTrue,
      );
    });

    test('rider records an attempt on an assignment they accepted', () {
      expect(
        decide(
          Permission.riderRecordDeliveryAttempt,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider),
          scope: order(assigned: <String>{riderId}),
        ).allowed,
        isTrue,
      );
    });

    test('admin suspends a worker with a reason', () {
      expect(
        decide(
          Permission.adminSuspendWorker,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
          reason: 'repeated failed handoffs under investigation',
        ).allowed,
        isTrue,
      );
    });

    test('admin reconciles cash with reason and a second approver', () {
      expect(
        decide(
          Permission.adminRecordCashReconciliation,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
          reason: 'end of day variance',
          approval: approvalBy(approverId),
        ).allowed,
        isTrue,
      );
    });
  });

  group('identity and standing', () {
    test('unauthenticated is denied', () {
      final AuthorizationDecision d = decide(Permission.customerViewOwnOrder);

      expect(d.allowed, isFalse);
      expect(d.reason, DenyReason.unauthenticated);
    });

    test('a system worker cannot borrow a human role permission', () {
      expect(
        decide(
          Permission.adminSuspendWorker,
          principal: Principal.systemWorker('wrk_outbox01-Aa22Bb33'),
          membership: member(adminId, CommerceRole.admin),
          reason: 'automated',
        ).reason,
        DenyReason.systemPrincipalNotEligible,
      );
    });

    test('missing membership is denied', () {
      expect(
        decide(
          Permission.customerViewOwnOrder,
          principal: user(customerId),
        ).reason,
        DenyReason.membershipMissing,
      );
    });

    test("a membership belonging to someone else does not apply", () {
      expect(
        decide(
          Permission.customerViewOwnOrder,
          principal: user(customerId),
          membership: member(otherCustomerId, CommerceRole.customer),
        ).reason,
        DenyReason.membershipMissing,
      );
    });

    test('pending membership cannot act', () {
      expect(
        decide(
          Permission.pickerAcceptAssignment,
          principal: user(pickerId),
          membership: member(
            pickerId,
            CommerceRole.picker,
            status: MembershipStatus.pending,
          ),
        ).reason,
        DenyReason.membershipNotActive,
      );
    });

    test('suspended worker cannot start new assignment work', () {
      expect(
        decide(
          Permission.pickerAcceptAssignment,
          principal: user(pickerId),
          membership: member(
            pickerId,
            CommerceRole.picker,
            status: MembershipStatus.suspended,
          ),
        ).reason,
        DenyReason.membershipNotActive,
      );
    });

    test('revoked worker cannot start new work', () {
      expect(
        decide(
          Permission.riderAcceptAssignment,
          principal: user(riderId),
          membership: member(
            riderId,
            CommerceRole.rider,
            status: MembershipStatus.revoked,
          ),
        ).reason,
        DenyReason.membershipNotActive,
      );
    });
  });

  group('role eligibility', () {
    test('picker cannot use a rider-only permission', () {
      expect(
        decide(
          Permission.riderRecordDeliveryAttempt,
          principal: user(pickerId),
          membership: member(pickerId, CommerceRole.picker),
          scope: order(assigned: <String>{pickerId}),
        ).reason,
        DenyReason.roleNotEligible,
      );
    });

    test('rider cannot use an agent-only permission', () {
      expect(
        decide(
          Permission.agentAcceptOrder,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider),
        ).reason,
        DenyReason.roleNotEligible,
      );
    });

    test('customer cannot use an admin permission', () {
      expect(
        decide(
          Permission.adminSuspendWorker,
          principal: user(customerId),
          membership: member(customerId, CommerceRole.customer),
          reason: 'because I want to',
        ).reason,
        DenyReason.roleNotEligible,
      );
    });
  });

  group('scope', () {
    test("customer cannot act on another customer's order", () {
      expect(
        decide(
          Permission.customerViewOwnOrder,
          principal: user(otherCustomerId),
          membership: member(otherCustomerId, CommerceRole.customer),
          scope: order(),
        ).reason,
        DenyReason.resourceOwnerMismatch,
      );
    });

    test('agent cannot act for a shop outside their membership', () {
      expect(
        decide(
          Permission.agentAcceptOrder,
          principal: user(agentId),
          membership: member(
            agentId,
            CommerceRole.agent,
            shops: <String>{'shop_beta'},
          ),
          scope: order(shop: 'shop_alpha'),
        ).reason,
        DenyReason.shopMismatch,
      );
    });

    test('an empty shop set means no shops, never all shops', () {
      expect(
        decide(
          Permission.agentAcceptOrder,
          principal: user(agentId),
          membership: member(agentId, CommerceRole.agent),
        ).reason,
        DenyReason.shopMismatch,
      );
    });

    test('region mismatch is denied', () {
      expect(
        decide(
          Permission.riderAcceptAssignment,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider, region: 'chattogram'),
          scope: order(region: 'dhaka_north'),
        ).reason,
        DenyReason.regionMismatch,
      );
    });

    test('a null region on either side does not satisfy region scope', () {
      expect(
        decide(
          Permission.riderAcceptAssignment,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider, region: null),
        ).reason,
        DenyReason.regionMismatch,
      );
    });

    test('rider without an accepted assignment is denied', () {
      expect(
        decide(
          Permission.riderRecordDeliveryAttempt,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider),
          scope: order(),
        ).reason,
        DenyReason.assignmentMismatch,
      );
    });

    test('being offered work is not being assigned it', () {
      // assignedPrincipalIds holds accepted assignments only, so an offered
      // rider is simply absent — and denied.
      expect(
        decide(
          Permission.riderRecordCustodyReceipt,
          principal: user(riderId),
          membership: member(riderId, CommerceRole.rider),
          scope: order(assigned: <String>{pickerId}),
        ).reason,
        DenyReason.assignmentMismatch,
      );
    });
  });

  group('reason and approval', () {
    test('reason-required permission denies without a reason', () {
      expect(
        decide(
          Permission.adminSuspendWorker,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
        ).reason,
        DenyReason.reasonRequired,
      );
    });

    test('a blank reason does not count', () {
      expect(
        decide(
          Permission.adminSuspendWorker,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
          reason: '   ',
        ).reason,
        DenyReason.reasonRequired,
      );
    });

    test('approval-required permission denies without approval', () {
      expect(
        decide(
          Permission.adminRecordCashReconciliation,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
          reason: 'variance',
        ).reason,
        DenyReason.approvalRequired,
      );
    });

    test('self-approval is not dual control', () {
      expect(
        decide(
          Permission.adminRecordCashReconciliation,
          principal: user(adminId),
          membership: member(adminId, CommerceRole.admin),
          reason: 'variance',
          approval: approvalBy(adminId),
        ).reason,
        DenyReason.approvalRequired,
      );
    });
  });

  group('client-supplied data is never authority', () {
    test('authorization ignores the command payload entirely', () {
      // A client puts an admin role and someone else's actor id in the
      // payload. The evaluator has no payload parameter at all, so the
      // decision is identical to the same request with no such claim.
      final CommandEnvelope spoofed = CommandEnvelope.create(
        commandId: 'cmd_7Kd93ba-Qz18Xu2P',
        commandType: 'order.view',
        resourceId: orderId,
        expectedRevision: 1,
        payload: <String, Object?>{
          'actorId': customerId,
          'role': 'admin',
          'permissions': <String>['admin.cash.record_reconciliation'],
          'membershipStatus': 'active',
        },
      ).fold((CommandEnvelope e) => e, (_) => throw StateError('n/a'));

      // The spoofing attempt exists in the envelope...
      expect(spoofed.payload['role'], 'admin');

      // ...and changes nothing: this caller is another customer.
      final AuthorizationDecision d = decide(
        Permission.customerViewOwnOrder,
        principal: user(otherCustomerId),
        membership: member(otherCustomerId, CommerceRole.customer),
      );

      expect(d.allowed, isFalse);
      expect(d.reason, DenyReason.resourceOwnerMismatch);
    });

    test('a forged membership for a different principal is inert', () {
      // Even if a caller could inject a Membership object, it must name them.
      expect(
        decide(
          Permission.adminRecordCashReconciliation,
          principal: user(customerId),
          membership: member(adminId, CommerceRole.admin),
          reason: 'x',
          approval: approvalBy(approverId),
        ).reason,
        DenyReason.membershipMissing,
      );
    });

    test('deny messages do not leak why', () {
      final List<AuthorizationDecision> denials = <AuthorizationDecision>[
        decide(Permission.customerViewOwnOrder),
        decide(
          Permission.agentAcceptOrder,
          principal: user(agentId),
          membership: member(agentId, CommerceRole.agent),
        ),
        decide(
          Permission.customerViewOwnOrder,
          principal: user(otherCustomerId),
          membership: member(otherCustomerId, CommerceRole.customer),
        ),
      ];

      // Different internal reasons, one identical public message: a caller
      // cannot probe for a resource's existence, owner, shop or region.
      expect(denials.map((AuthorizationDecision d) => d.reason).toSet().length,
          greaterThan(1));
      expect(
        denials.map((AuthorizationDecision d) => d.publicMessage).toSet(),
        <String>{'You do not have permission to do this.'},
      );
    });
  });
}
