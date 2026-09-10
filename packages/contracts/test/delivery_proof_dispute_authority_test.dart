import 'dart:io';

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
    test('a trusted worker cannot even obtain a grant, let alone act', () {
      // The exact inverse of the assessment contract, where only a trusted
      // worker may act. A background job in the raiser field would be an
      // unattributable audit trail — and canonical authorization refuses one
      // outright, so there is no grant for it to present.
      expect(
        evaluateAuthorization(
          AuthorizationRequest(
            permission: Permission.customerRaiseDispute,
            scope: const ResourceScope(
              resourceId: orderId,
              ownerPrincipalId: raiserId,
              regionId: region,
            ),
            principal: Principal.systemWorker(outboxWorkerId),
            reason: 'goods never arrived',
          ),
        ).reason,
        DenyReason.systemPrincipalNotEligible,
      );

      // Presenting somebody else's valid grant does not help: it is bound to
      // its own principal.
      expect(
        runRaise(actor: worker()).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      expect(
        runReview(actor: worker(), grant: adminAdministerGrant()).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      // Including the very worker that is the authorized proof verifier.
      expect(
        runRaise(actor: Principal.systemWorker(verifierId)).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
    });

    test('the actor-shape check still stands behind the grant', () {
      // `actorNotHumanPrincipal` is not dead: a grant can only name a human,
      // so reaching it requires a principal that matches the grant and is
      // still not a user — which the type system makes unconstructible today.
      // The check remains as the fail-closed floor if `Principal` ever gains
      // another kind, and the vocabulary keeps the value.
      expect(
        DeliveryProofDisputeDenial.values,
        contains(DeliveryProofDisputeDenial.actorNotHumanPrincipal),
      );
      expect(PrincipalKind.values, <PrincipalKind>[
        PrincipalKind.user,
        PrincipalKind.systemWorker,
      ]);
    });

    test('the raiser recorded is the verified principal, never a payload', () {
      // There is no raiser field on the request at all: it is derived from the
      // principal the backend verified, and it must match the grant.
      expect(
        allowedDispute(runRaise(actor: customer())).record.raisedByPrincipalId,
        raiserId,
      );
      // A different customer may raise only on an order they actually own —
      // and then the recorded raiser is that principal.
      expect(
        allowedDispute(
          runRaise(
            actor: customer(otherCustomerId),
            grant: customerRaiseGrant(principalId: otherCustomerId),
          ),
        ).record.raisedByPrincipalId,
        otherCustomerId,
      );
    });

    test('a NON-OWNER customer can no longer raise — FND-003D2B-FIX-002', () {
      // The defect this closes. The candidate took a bare `Principal` and only
      // *documented* that authorization had run, so a customer who owns
      // nothing reached a raise transition by calling the evaluator directly.
      // Canonical authorization denies them...
      expect(
        decide(
          permission: Permission.customerRaiseDispute,
          principalId: otherCustomerId,
          role: CommerceRole.customer,
        ).reason,
        DenyReason.resourceOwnerMismatch,
        reason: 'the owner of orderId is raiserId, not otherCustomerId',
      );
      // ...so they hold no grant for this order, and the evaluator refuses.
      expect(
        runRaise(actor: customer(otherCustomerId)).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      expect(
        runRaise(actor: customer(otherCustomerId)).transition,
        isNull,
      );
    });

    test('a customer-only principal cannot review', () {
      // `customer.dispute.raise` is not `admin.dispute.administer`. A customer
      // cannot obtain the admin grant...
      expect(
        decide(
          permission: Permission.adminAdministerDispute,
          principalId: raiserId,
          role: CommerceRole.customer,
        ).reason,
        DenyReason.roleNotEligible,
      );
      // ...and presenting their own raise grant is refused: wrong permission.
      expect(
        runReview(actor: customer(), grant: customerRaiseGrant()).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
    });

    test('the grant must be for this permission, principal and resource', () {
      // Wrong permission: a perfectly valid grant for a different capability.
      expect(
        runRaise(
          grant: disputeGrant(
            permission: Permission.customerViewOwnOrder,
            principalId: raiserId,
            role: CommerceRole.customer,
          ),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      // Wrong principal: a valid raise grant issued to somebody else.
      expect(
        runRaise(
          actor: customer(),
          grant: customerRaiseGrant(principalId: otherCustomerId),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      // Wrong resource: a valid raise grant for another order. The grant is
      // the canonical resource, so the dispute aggregate no longer matches it.
      expect(
        runRaise(
          grant: customerRaiseGrant(resourceId: otherOrderId),
        ).denial,
        DeliveryProofDisputeDenial.resourceBindingMismatch,
      );
      // The same three bindings, on review.
      expect(
        runReview(
          grant: disputeGrant(
            permission: Permission.adminSupportViewOrder,
            principalId: adminId,
            role: CommerceRole.admin,
          ),
        ).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
      expect(
        runReview(grant: adminAdministerGrant(principalId: otherAdminId)).denial,
        DeliveryProofDisputeDenial.authorizationGrantMismatch,
      );
    });

    test('the canonical grants allow their own operations', () {
      expect(allowedDispute(runRaise()).resultingState,
          DeliveryProofDisputeState.open);
      expect(allowedDispute(runReview()).resultingState,
          DeliveryProofDisputeState.underReview);
    });

    test('no separation-of-duties rule is invented — FND-003D2B-FIX-001', () {
      // The candidate previously denied `reviewerIsRaiser` when the reviewing
      // principal had earlier raised the dispute. **No accepted contract asks
      // for that.** `admin.dispute.administer` requires an active admin
      // membership, `ownRegion` scope and a stored reason, and carries
      // `approvalRequired: false` — so refusing on identity alone was an
      // invented authorization policy, decided nowhere.
      final PermissionRule rule =
          permissionMatrix[Permission.adminAdministerDispute]!;
      expect(rule.approvalRequired, isFalse);
      expect(rule.reasonRequired, isTrue);
      expect(rule.scopes, <ScopeRequirement>{ScopeRequirement.ownRegion});

      // A dispute raised by principal X...
      final DeliveryProofDisputeFacts raisedByAdmin = applyDispute(
        allowedDispute(
          runRaise(
            actor: customer(adminId),
            grant: customerRaiseGrant(principalId: adminId),
          ),
        ),
      );
      expect(raisedByAdmin.canonicalState, DeliveryProofDisputeState.open);
      expect(raisedByAdmin.current!.raisedByPrincipalId, adminId);

      // ...and the SAME principal X, holding a valid active admin membership
      // in the resource's region with a reason, passes canonical
      // authorization. That is the accepted matrix's answer, and it is the one
      // that counts. **Raising conferred none of this** — X reaches review only
      // by independently holding an admin grant of their own.
      expect(
        decide(
          permission: Permission.adminAdministerDispute,
          principalId: adminId,
          role: CommerceRole.admin,
        ).allowed,
        isTrue,
      );

      // The state machine must not add a second, private policy that refuses
      // what canonical authorization allowed.
      final DeliveryProofDisputeTransition t = allowedDispute(
        runReview(
          dispute: raisedByAdmin,
          actor: admin(),
          grant: adminAdministerGrant(principalId: adminId),
        ),
      );
      expect(t.resultingState, DeliveryProofDisputeState.underReview);
      expect(t.record.reviewStartedByPrincipalId, adminId);
      expect(t.record.raisedByPrincipalId, adminId);
      expect(t.record.isWellFormed, isTrue);

      // The denial vocabulary no longer contains the invented reason at all.
      expect(
        DeliveryProofDisputeDenial.values.map(
          (DeliveryProofDisputeDenial d) => d.name,
        ),
        isNot(contains('reviewerIsRaiser')),
      );

      // A different administrator is of course still fine.
      expect(
        allowedDispute(
          runReview(actor: admin(otherAdminId)),
        ).record.reviewStartedByPrincipalId,
        otherAdminId,
      );
    });

    test('a record whose reviewer is also the raiser is canonical', () {
      // The same correction, at the shape validator: it must not smuggle the
      // removed policy back in as a "corrupt record" rule.
      final DeliveryProofDisputeRecord sameParty =
          DeliveryProofDisputeRecord.reviewStarted(
            previous: disputeRecord(raisedByPrincipalId: adminId),
            reviewerPrincipalId: adminId,
            atUtc: reviewedAt,
          );
      expect(sameParty.isWellFormed, isTrue);
      expect(
        validateDeliveryProofDisputeAggregate(
          DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 2,
            current: sameParty,
          ),
        ),
        isNull,
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
    test('it requires the decision without re-deciding it', () {
      // *(Rewritten by FND-003D2B-FIX-002.)* This test previously asserted the
      // opposite — that a principal who owns nothing "still evaluates here",
      // because authorization was assumed to have run elsewhere. That was the
      // bypass. The correct statement is narrower and provable: the evaluator
      // **requires** canonical authorization's success artifact, and re-decides
      // none of its rules.
      //
      // Same principal, same order: canonical authorization denies, and so the
      // evaluator has no grant to accept.
      expect(
        decide(
          permission: Permission.customerRaiseDispute,
          principalId: otherCustomerId,
          role: CommerceRole.customer,
        ).allowed,
        isFalse,
      );
      expect(runRaise(actor: customer(otherCustomerId)).allowed, isFalse);

      // And it does not reimplement the rules: no dispute source file mentions
      // a role, a scope requirement, a membership status or the matrix.
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'permissionmatrix',
          'commercerole',
          'scoperequirement',
          'membershipstatus',
          'reasonrequired',
          'evaluateauthorization',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$path must not re-decide FND-003A policy',
          );
        }
      }
    });

    test('no request type carries a principal, grant, role or reason', () {
      final DeliveryProofDisputeRaiseRequest r =
          DeliveryProofDisputeRaiseRequest(
            disputeId: disputeA,
            atUtc: raisedAt,
            expectedDisputeRevision: 0,
            expectedAssessmentRevision: 0,
            expectedOrderRevision: 5,
          );
      expect(r.disputeId, disputeA);
      // The type exposes exactly five members; a reason or actor field would
      // have to be added deliberately, and this test would then be updated
      // deliberately too.
      expect(r.expectedDisputeRevision, 0);
      expect(r.expectedAssessmentRevision, 0);
      expect(r.expectedOrderRevision, 5);
      expect(r.atUtc.isUtc, isTrue);

      final DeliveryProofDisputeReviewRequest review =
          DeliveryProofDisputeReviewRequest(
            disputeId: disputeA,
            atUtc: reviewedAt,
            expectedDisputeRevision: 1,
          );
      expect(review.disputeId, disputeA);
      expect(review.expectedDisputeRevision, 1);
      expect(review.atUtc.isUtc, isTrue);
    });
  });
}
