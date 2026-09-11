import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/delivery_attempt_return_denial.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/permission.dart';
import 'package:cp_contracts/src/principal.dart';

/// Binding an executable attempt or return operation to a **canonical
/// authorization success**.
///
/// ## Why a grant, and not a `Principal`
///
/// A pure function cannot assert that its caller already authorized the
/// request. FND-003D2B shipped evaluators that took a bare [Principal] and
/// *documented* that authorization had happened; FND-003D2B-FIX-002 found that
/// nothing in the signature distinguished a call made after a successful
/// `evaluateAuthorization` from one that skipped it entirely, and a non-owner
/// could reach an executable transition.
///
/// FND-003A already built the artifact that closes this: [AuthorizationGrant]
/// is `final`, has only a library-private constructor, and **can only be
/// obtained from a successful [evaluateAuthorization]**. Requiring one is not a
/// second policy — it is proof the single canonical policy ran and allowed
/// this request.
///
/// ## What this does not do
///
/// It does **not** re-check role, membership status, scope, reason or approval.
/// Those live in `permissionMatrix` and are evaluated in exactly one place;
/// copying any of them here would create the second source of truth this
/// repository forbids. What is verified is only that the grant in hand is the
/// **right** grant:
///
/// ```text
/// expectedResourceId is a valid opaque id
/// grant.permission   == the operation's requiredPermission
/// grant.covers(principalId: actor.id, resourceId: expectedResourceId)
/// ```
///
/// ## [expectedResourceId] must come from the read-set, never from the grant
///
/// Passing `grant.resourceId` here would make the resource half tautological —
/// a grant's own resource handed back to itself always matches — and would
/// prove only the principal binding while reading as though it proved both.
/// That exact tautology was shipped and removed by FND-003D2B-FIX-003. The
/// caller supplies the resource **independently**, from the stored aggregate
/// the operation is acting on, and every other read-set member is compared
/// against that same anchor.
///
/// > **Freshness remains the backend's.** A grant proves `evaluateAuthorization`
/// > allowed *these inputs*. That the inputs were current, and that the actor
/// > was not since suspended or unassigned, is criteria **R33–R40** — **NOT
/// > RUN**. This contract neither claims nor can claim otherwise.
AttemptReturnDenial? checkAttemptReturnAuthorization({
  required AuthorizationGrant grant,
  required Principal actor,
  required Permission requiredPermission,
  required String expectedResourceId,
}) {
  // The resource the operation acts on, taken from the read-set rather than
  // from the grant, has to be usable before anything can be compared to it.
  if (!isValidOpaqueId(expectedResourceId)) {
    return AttemptReturnDenial.authorizationGrantMismatch;
  }
  if (grant.permission != requiredPermission) {
    return AttemptReturnDenial.authorizationGrantMismatch;
  }
  // `covers` is FND-003A's own binding check — principal and resource together
  // — reused rather than reimplemented, and given a resource it did not supply.
  if (!grant.covers(principalId: actor.id, resourceId: expectedResourceId)) {
    return AttemptReturnDenial.authorizationGrantMismatch;
  }
  return null;
}
