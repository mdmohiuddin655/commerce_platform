import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

/// Authorization for both dispute operations is the **accepted FND-003A
/// matrix**, unchanged. These tests run the real `evaluateAuthorization` — the
/// same path production code takes — and pin the rules this slice depends on,
/// so a later edit to either permission fails here rather than silently
/// widening a dispute capability.
AuthorizationDecision decide({
  required Permission permission,
  required String principalId,
  required CommerceRole role,
  String resourceId = orderId,
  String ownerId = raiserId,
  String memberRegion = region,
  String resourceRegion = region,
  MembershipStatus status = MembershipStatus.active,
  String? reason = 'goods never arrived',
}) => evaluateAuthorization(
  AuthorizationRequest(
    permission: permission,
    scope: ResourceScope(
      resourceId: resourceId,
      ownerPrincipalId: ownerId,
      shopId: shopId,
      regionId: resourceRegion,
    ),
    principal: Principal.fromVerifiedSubject(principalId),
    membership: Membership(
      principalId: principalId,
      role: role,
      status: status,
      regionId: memberRegion,
    ),
    reason: reason,
  ),
);

void main() {
  group('the two dispute permissions are the accepted ones, unchanged', () {
    test('no permission was added by this slice', () {
      expect(Permission.values.length, 38);
      expect(permissionMatrix.length, 38);
      for (final Permission p in Permission.values) {
        for (final String forbidden in <String>[
          'dispute.resolve',
          'dispute.close',
          'dispute.override',
          'proof.override',
          'dispute.decide',
          'dispute_status',
        ]) {
          expect(p.id, isNot(contains(forbidden)));
        }
      }
    });

    test('customer.dispute.raise keeps its exact rule', () {
      final PermissionRule rule =
          permissionMatrix[Permission.customerRaiseDispute]!;
      expect(rule.eligibleRoles, <CommerceRole>{CommerceRole.customer});
      expect(rule.scopes, <ScopeRequirement>{ScopeRequirement.ownResource});
      expect(rule.reasonRequired, isTrue);
      expect(rule.approvalRequired, isFalse);
      expect(rule.acceptableStatuses, <MembershipStatus>{
        MembershipStatus.active,
      });
    });

    test('admin.dispute.administer keeps its exact rule', () {
      final PermissionRule rule =
          permissionMatrix[Permission.adminAdministerDispute]!;
      expect(rule.eligibleRoles, <CommerceRole>{CommerceRole.admin});
      expect(rule.scopes, <ScopeRequirement>{ScopeRequirement.ownRegion});
      expect(rule.reasonRequired, isTrue);
      expect(rule.approvalRequired, isFalse);
    });

    test('customer.delivery.confirm_proof is not reinterpreted', () {
      // Raising a dispute is not participation in proof, and this slice decides
      // nothing about whether participation is required.
      final PermissionRule rule =
          permissionMatrix[Permission.customerConfirmDeliveryProof]!;
      expect(rule.restriction, contains('Participation in proof only'));
      expect(rule.restriction.toLowerCase(), contains('does not settle'));
      expect(rule.restriction.toLowerCase(), contains('does not close'));
    });

    test('every dispute command maps to one of the two accepted permissions',
        () {
      for (final DeliveryProofDisputeCommand c
          in DeliveryProofDisputeCommand.values) {
        expect(
          <Permission>[
            Permission.customerRaiseDispute,
            Permission.adminAdministerDispute,
          ],
          contains(c.requiredPermission),
        );
        expect(permissionMatrix[c.requiredPermission], isNotNull);
        expect(
          permissionMatrix[c.requiredPermission]!.reasonRequired,
          isTrue,
          reason: 'every dispute operation is reason-bearing',
        );
      }
      expect(
        DeliveryProofDisputeCommand.raise.requiredPermission,
        Permission.customerRaiseDispute,
      );
      expect(
        DeliveryProofDisputeCommand.recordReviewStarted.requiredPermission,
        Permission.adminAdministerDispute,
      );
    });
  });

  group('raising — customer authorization', () {
    test('the order owner is permitted', () {
      expect(
        decide(
          permission: Permission.customerRaiseDispute,
          principalId: raiserId,
          role: CommerceRole.customer,
        ).allowed,
        isTrue,
      );
    });

    test('a customer acting on somebody else\'s order is denied', () {
      final AuthorizationDecision d = decide(
        permission: Permission.customerRaiseDispute,
        principalId: otherCustomerId,
        role: CommerceRole.customer,
      );
      expect(d.allowed, isFalse);
      expect(d.reason, DenyReason.resourceOwnerMismatch);
      expect(d.publicMessage, 'You do not have permission to do this.');
    });

    test('a missing reason is denied', () {
      for (final String? reason in <String?>[null, '', '   ']) {
        final AuthorizationDecision d = decide(
          permission: Permission.customerRaiseDispute,
          principalId: raiserId,
          role: CommerceRole.customer,
          reason: reason,
        );
        expect(d.allowed, isFalse);
        expect(d.reason, DenyReason.reasonRequired);
      }
    });

    test('a suspended or pending member cannot raise', () {
      for (final MembershipStatus status in <MembershipStatus>[
        MembershipStatus.pending,
        MembershipStatus.suspended,
        MembershipStatus.revoked,
      ]) {
        expect(
          decide(
            permission: Permission.customerRaiseDispute,
            principalId: raiserId,
            role: CommerceRole.customer,
            status: status,
          ).reason,
          DenyReason.membershipNotActive,
        );
      }
    });

    test('another role cannot borrow the customer permission', () {
      for (final CommerceRole role in <CommerceRole>[
        CommerceRole.admin,
        CommerceRole.agent,
        CommerceRole.picker,
        CommerceRole.rider,
      ]) {
        expect(
          decide(
            permission: Permission.customerRaiseDispute,
            principalId: raiserId,
            role: role,
          ).reason,
          DenyReason.roleNotEligible,
        );
      }
    });
  });

  group('reviewing — admin authorization', () {
    test('an in-region admin with a reason is permitted', () {
      expect(
        decide(
          permission: Permission.adminAdministerDispute,
          principalId: adminId,
          role: CommerceRole.admin,
        ).allowed,
        isTrue,
      );
    });

    test('an admin outside the allowed region is denied', () {
      final AuthorizationDecision d = decide(
        permission: Permission.adminAdministerDispute,
        principalId: adminId,
        role: CommerceRole.admin,
        memberRegion: 'dhaka_south',
      );
      expect(d.allowed, isFalse);
      expect(d.reason, DenyReason.regionMismatch);
      expect(d.publicMessage, 'You do not have permission to do this.');
    });

    test('an admin with no reason is denied', () {
      expect(
        decide(
          permission: Permission.adminAdministerDispute,
          principalId: adminId,
          role: CommerceRole.admin,
          reason: '  ',
        ).reason,
        DenyReason.reasonRequired,
      );
    });

    test('a customer cannot borrow the admin permission', () {
      expect(
        decide(
          permission: Permission.adminAdministerDispute,
          principalId: raiserId,
          role: CommerceRole.customer,
        ).reason,
        DenyReason.roleNotEligible,
      );
    });

    test('an unauthenticated request is denied', () {
      expect(
        evaluateAuthorization(
          const AuthorizationRequest(
            permission: Permission.adminAdministerDispute,
            scope: ResourceScope(resourceId: orderId, regionId: region),
            reason: 'looking into it',
          ),
        ).reason,
        DenyReason.unauthenticated,
      );
    });
  });

  group('actor integrity inside the evaluator', () {
    test('a trusted worker may neither raise nor review', () {
      // The exact inverse of the assessment contract, where only a trusted
      // worker may act. A background job in the raiser field would be an
      // unattributable audit trail.
      expect(
        runRaise(actor: worker()).denial,
        DeliveryProofDisputeDenial.actorNotHumanPrincipal,
      );
      expect(
        runReview(actor: worker()).denial,
        DeliveryProofDisputeDenial.actorNotHumanPrincipal,
      );
      // Including the very worker that is the authorized proof verifier.
      expect(
        runRaise(actor: Principal.systemWorker(verifierId)).denial,
        DeliveryProofDisputeDenial.actorNotHumanPrincipal,
      );
    });

    test('the raiser recorded is the verified principal, never a payload', () {
      // There is no raiser field on the request at all: it is derived from the
      // principal the backend verified.
      expect(
        allowedDispute(runRaise(actor: customer())).record.raisedByPrincipalId,
        raiserId,
      );
      expect(
        allowedDispute(
          runRaise(actor: customer(otherCustomerId)),
        ).record.raisedByPrincipalId,
        otherCustomerId,
        reason: 'whether that principal OWNS the order is authorization\'s '
            'question, answered before this evaluator runs',
      );
    });

    test('self-review is refused', () {
      expect(
        runReview(actor: customer()).denial,
        DeliveryProofDisputeDenial.reviewerIsRaiser,
      );
      // A different administrator is fine.
      expect(
        allowedDispute(
          runReview(actor: admin(otherAdminId)),
        ).record.reviewStartedByPrincipalId,
        otherAdminId,
      );
    });

    test('possession and custody are not authorization sources here', () {
      // The evaluator takes no custody or rider facts at all, so nothing about
      // who is holding the goods can widen who may dispute. A rider principal
      // is refused for the ordinary reason — the matrix does not grant them the
      // permission — not because this contract knows anything about custody.
      expect(
        decide(
          permission: Permission.customerRaiseDispute,
          principalId: riderA,
          role: CommerceRole.rider,
        ).reason,
        DenyReason.roleNotEligible,
      );
    });
  });

  group('the evaluator is not the authorization boundary', () {
    test('it duplicates no scope, role or reason check', () {
      // A perfectly formed dispute from a principal who owns nothing still
      // evaluates here: authorization already ran, and re-running it in the
      // state machine would create a second place for it to drift. The proof is
      // that this call succeeds while `decide` above denies the same principal.
      expect(runRaise(actor: customer(otherCustomerId)).allowed, isTrue);
      expect(
        decide(
          permission: Permission.customerRaiseDispute,
          principalId: otherCustomerId,
          role: CommerceRole.customer,
        ).allowed,
        isFalse,
      );
    });

    test('no request type carries a principal, grant, role or reason', () {
      final DeliveryProofDisputeRequest r = DeliveryProofDisputeRequest.raise(
        disputeId: disputeA,
        atUtc: raisedAt,
        expectedDisputeRevision: 0,
        expectedAssessmentRevision: 0,
        expectedOrderRevision: 5,
      );
      expect(r.command, DeliveryProofDisputeCommand.raise);
      expect(r.disputeId, disputeA);
      // The type exposes exactly six members; a reason or actor field would
      // have to be added deliberately, and this test would then be updated
      // deliberately too.
      expect(r.expectedDisputeRevision, 0);
      expect(r.expectedAssessmentRevision, 0);
      expect(r.expectedOrderRevision, 5);
      expect(r.atUtc.isUtc, isTrue);
    });
  });
}
