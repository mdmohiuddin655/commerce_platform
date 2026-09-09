// Shared fixtures for tests that need a *real* AuthorizationGrant.
//
// Since FND-003A-FIX-002 a grant cannot be fabricated: it is `final`, has only
// a library-private constructor, and is produced solely by a successful
// `evaluateAuthorization`. Tests therefore build trusted inputs and run the
// real evaluator, which is the same path production code takes.
import 'package:cp_contracts/cp_contracts.dart';

const String customerA = 'usr_alpha01Aa-Bb22Cc3';
const String customerB = 'usr_bravo01Aa-Bb22Cc3';
const String resourceX = 'ord_Xa91ZZ0plQ7rTt4B';
const String resourceY = 'ord_Yb82WW1qmR8sUu5C';

Principal user(String id) => Principal.fromVerifiedSubject(id);

Membership customerMembership(
  String id, {
  MembershipStatus status = MembershipStatus.active,
}) => Membership(
  principalId: id,
  role: CommerceRole.customer,
  status: status,
  regionId: 'dhaka_north',
);

ResourceScope ownedOrder(String resourceId, String ownerId) => ResourceScope(
  resourceId: resourceId,
  ownerPrincipalId: ownerId,
  shopId: 'shop_alpha',
  regionId: 'dhaka_north',
);

/// Runs the real evaluator and returns its decision.
AuthorizationDecision decideFor(
  String principalId,
  String resourceId, {
  MembershipStatus status = MembershipStatus.active,
  Permission permission = Permission.customerViewOwnOrder,
  String? ownerId,
}) => evaluateAuthorization(
  AuthorizationRequest(
    permission: permission,
    scope: ownedOrder(resourceId, ownerId ?? principalId),
    principal: user(principalId),
    membership: customerMembership(principalId, status: status),
  ),
);

/// A genuine grant, or a failure that names why the fixture could not produce
/// one — a silently-null grant would make a test pass for the wrong reason.
AuthorizationGrant grantFor(
  String principalId,
  String resourceId, {
  Permission permission = Permission.customerViewOwnOrder,
}) {
  final AuthorizationDecision decision = decideFor(
    principalId,
    resourceId,
    permission: permission,
  );
  final AuthorizationGrant? grant = decision.grant;
  if (grant == null) {
    throw StateError(
      'fixture expected an allow but got ${decision.reason?.name}',
    );
  }
  return grant;
}
