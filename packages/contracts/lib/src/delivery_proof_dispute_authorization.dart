import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_command.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_denial.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/principal.dart';

/// Binding an executable dispute operation to a **canonical authorization
/// success**.
///
/// ## Why this exists
///
/// *(Added by FND-003D2B-FIX-002.)* The dispute evaluators used to take only a
/// server-derived [Principal] and a resource, and their documentation asserted
/// that "authorization has already happened". **A pure function cannot assert
/// that about its caller.** Nothing in the signature distinguished a call made
/// after a successful `evaluateAuthorization` from a direct call that skipped
/// it entirely, so a non-owner customer could reach a raise transition and a
/// customer-only principal could reach a review transition.
///
/// FND-003A already built the artifact that closes this, and built it for
/// exactly this purpose: [AuthorizationGrant] is `final`, has only a
/// library-private constructor, and **can only be obtained from a successful
/// [evaluateAuthorization]**. Requiring one is therefore not a second policy —
/// it is proof that the single canonical policy ran and allowed this request.
///
/// ## What this does not do
///
/// It does **not** re-check role, membership status, scope or reason. Those
/// live in `permissionMatrix` and are evaluated in exactly one place; copying
/// any of them here would create the second source of truth this repository
/// forbids. What is verified is only that the grant in hand **is the right
/// grant**:
///
/// ```text
/// grant.permission  == the operation's requiredPermission
/// grant.principalId == the acting principal
/// grant.resourceId  == the canonical resource, and a valid opaque id
/// ```
///
/// Without the first, a grant for `customer.order.view_own` would authorize a
/// dispute. Without the second, one principal's grant would authorize another's
/// command. Without the third, a grant for order X would authorize acting on
/// order Y — the same three bindings `ApprovalEvidence` needs, for the same
/// reason.
///
/// > **Freshness is still the backend's.** FND-003A-FIX-003 requires fresh
/// > authorization on **every** request including replays, and forbids caching
/// > or reusing a grant. A grant proves that `evaluateAuthorization` allowed
/// > *these inputs*; that the inputs were current and the actor was not since
/// > revoked is criteria **R33–R40**, NOT RUN. This contract cannot and does
/// > not claim otherwise.
///
/// > **There is deliberately no boolean.** An `isAuthorized` flag, a role field
/// > or a permission name on the request would all be forgeable by the caller
/// > they are meant to constrain. Nothing here is taken from a command payload.
DeliveryProofDisputeDenial? checkDisputeAuthorization({
  required AuthorizationGrant grant,
  required Principal actor,
  required DeliveryProofDisputeCommand command,
}) {
  // The resource the grant was issued for is the canonical resource this
  // operation acts on, so it has to be usable in its own right.
  if (!isValidOpaqueId(grant.resourceId)) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  if (grant.permission != command.requiredPermission) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  // `covers` is FND-003A's own binding check — principal and resource together
  // — reused rather than reimplemented.
  if (!grant.covers(
    principalId: actor.id,
    resourceId: grant.resourceId,
  )) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  return null;
}
