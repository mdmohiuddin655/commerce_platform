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
/// expectedResourceId is a valid opaque id
/// grant.permission   == the operation's requiredPermission
/// grant.covers(principalId: actor.id, resourceId: expectedResourceId)
/// ```
///
/// Without the first, a broken identity could not be compared at all. Without
/// the second, a grant for `customer.order.view_own` would authorize a dispute.
/// Without the third, one principal's grant would authorize another's command,
/// or a grant for order X would authorize acting on order Y — the same three
/// bindings `ApprovalEvidence` needs, for the same reason.
///
/// ## [expectedResourceId] must come from the read-set, never from the grant
///
/// *(Corrected by FND-003D2B-FIX-003.)* This previously called
/// `grant.covers(principalId: actor.id, resourceId: grant.resourceId)`. The
/// resource half of that is **tautological** — the grant's own resource handed
/// back to itself always matches — so the call proved only the principal
/// binding while being documented as proving the resource binding too.
///
/// The caller now supplies the resource **independently**, from the stored
/// aggregate the operation is actually acting on, and every other member of the
/// read-set is compared against that same anchor by the operation evaluator.
/// Passing `grant.resourceId` here would restore the tautology and is exactly
/// what this parameter exists to prevent.
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
  required String expectedResourceId,
}) {
  // The resource this operation acts on, taken from the read-set rather than
  // from the grant, has to be usable before anything can be compared to it.
  if (!isValidOpaqueId(expectedResourceId)) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  if (grant.permission != command.requiredPermission) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  // `covers` is FND-003A's own binding check — principal and resource together
  // — reused rather than reimplemented, and now given a resource it did not
  // supply itself.
  if (!grant.covers(
    principalId: actor.id,
    resourceId: expectedResourceId,
  )) {
    return DeliveryProofDisputeDenial.authorizationGrantMismatch;
  }
  return null;
}
