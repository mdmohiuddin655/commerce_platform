import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/cod_collection_command.dart';
import 'package:cp_contracts/src/cod_collection_denial.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/principal.dart';

/// Binds an executable COD operation to a **canonical authorization success**.
///
/// A pure function cannot assert that its caller already authorized the
/// request. FND-003D2B shipped evaluators that took a bare [Principal] and
/// merely *documented* that authorization had happened; FND-003D2B-FIX-002
/// found that nothing in the signature distinguished a call made after
/// `evaluateAuthorization` from one that skipped it, and a non-owner reached an
/// executable transition. That lesson is load-bearing here, where the
/// transition moves money.
///
/// [AuthorizationGrant] is `final`, has only a library-private constructor and
/// **can only be obtained from a successful `evaluateAuthorization`**.
/// Requiring one is not a second policy — it is proof the single canonical
/// policy ran and allowed this request.
///
/// What is verified is only that the grant in hand is the **right** grant:
///
/// ```text
/// expectedResourceId is a valid opaque id
/// grant.permission   == command.requiredPermission
/// grant.covers(principalId: actor.id, resourceId: expectedResourceId)
/// ```
///
/// Role, membership status, scope and reason are **not** re-checked: they live
/// in `permissionMatrix` and are evaluated in exactly one place.
///
/// ## [expectedResourceId] comes from the read-set, never from the grant
///
/// Passing `grant.resourceId` would make the resource half tautological — a
/// grant's own resource always matches itself — proving only the principal
/// binding while reading as though it proved both. That exact tautology was
/// shipped and removed by FND-003D2B-FIX-003.
///
/// > **Freshness remains the backend's.** A grant proves `evaluateAuthorization`
/// > allowed *these inputs*. That the inputs were current, and the rider was
/// > not since unassigned or suspended, is criteria **R33–R40** — **NOT RUN**.
CodCollectionDenial? checkCodCollectionAuthorization({
  required AuthorizationGrant grant,
  required Principal actor,
  required CodCollectionCommand command,
  required String expectedResourceId,
}) {
  if (!isValidOpaqueId(expectedResourceId)) {
    return CodCollectionDenial.authorizationGrantMismatch;
  }
  if (grant.permission != command.requiredPermission) {
    return CodCollectionDenial.authorizationGrantMismatch;
  }
  if (!grant.covers(principalId: actor.id, resourceId: expectedResourceId)) {
    return CodCollectionDenial.authorizationGrantMismatch;
  }
  return null;
}
