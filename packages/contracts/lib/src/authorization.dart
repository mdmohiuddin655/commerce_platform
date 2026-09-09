import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/membership.dart';
import 'package:cp_contracts/src/permission.dart';
import 'package:cp_contracts/src/permission_matrix.dart';
import 'package:cp_contracts/src/principal.dart';
import 'package:cp_contracts/src/scope.dart';
import 'package:meta/meta.dart';

/// Why a request was refused.
///
/// These are **internal** values for server logs, tests and audit. They are
/// not returned to an untrusted caller: telling a stranger "wrong region"
/// rather than "not permitted" confirms the resource exists and leaks where.
/// See [AuthorizationDecision.publicMessage].
enum DenyReason {
  /// No verified principal at all.
  unauthenticated,

  /// A system worker attempted a permission reserved for human roles.
  systemPrincipalNotEligible,

  /// The principal has no membership for the required role.
  membershipMissing,

  /// Membership exists but its status may not exercise this permission —
  /// pending, suspended or revoked.
  membershipNotActive,

  /// The membership's role is not eligible for this permission.
  roleNotEligible,

  /// Membership region does not match the resource region.
  regionMismatch,

  /// The resource's shop is not one this membership operates.
  shopMismatch,

  /// The principal does not own the resource.
  resourceOwnerMismatch,

  /// The work was not offered to this principal. Distinct from
  /// [assignmentMismatch]: this is "the offer was not addressed to you",
  /// not "you have not accepted it".
  offerMismatch,

  /// The principal holds no accepted assignment on the resource.
  assignmentMismatch,

  /// The permission requires a stored reason and none was supplied.
  reasonRequired,

  /// The permission requires dual-control approval and none was supplied.
  approvalRequired,

  /// Approval evidence was supplied but is not bound to this request — it
  /// names a different requester, permission or resource, or the approver is
  /// the requester.
  approvalMismatch,
}

/// A **server-resolved** record that a second principal approved this exact
/// action.
///
/// ## Trust boundary
///
/// This is not a thing a client sends. The flow is:
///
/// 1. A command contract may later allow a client to submit an approval
///    *reference* — an opaque id and nothing else.
/// 2. The backend **resolves that reference from trusted storage**.
/// 3. The backend verifies the stored approval record and the approver's own
///    authority and scope.
/// 4. Only then does it construct this object and pass it to the pure
///    evaluator.
///
/// Hence the constructor name [ApprovalEvidence.resolved]: every call site has
/// to state that a trusted lookup produced it. There is deliberately **no
/// `fromJson`**, and no caller-controlled `approverIsAuthorized` flag — a
/// boolean an attacker can set is not a check.
///
/// ## What this type guarantees, and what it does not
///
/// The evaluator verifies the approval is **bound to this request**: same
/// requester, same permission, same resource, and an approver who is not the
/// requester. That is enough to stop an unrelated approval record — for a
/// different action, or someone else's — from satisfying the current command.
///
/// It does **not** verify that the approver held the right permission. That is
/// a full authorization evaluation of a second principal, and it belongs to
/// the approval workflow that issues the record (a later backend slice). The
/// backend must perform it at step 3 above.
///
/// **Expiry is not specified here.** No arbitrary lifetime is invented. If
/// approvals expire, the owning approval workflow defines and enforces the
/// policy, and [approvedAtServerUtc] is what it will evaluate against.
@immutable
class ApprovalEvidence {
  /// Construct from a trusted, already-resolved approval record.
  const ApprovalEvidence.resolved({
    required this.approvalRef,
    required this.requesterPrincipalId,
    required this.approverPrincipalId,
    required this.permission,
    required this.resourceId,
    required this.approvedAtServerUtc,
  });

  /// Opaque reference to the stored approval record, for audit.
  final String approvalRef;

  /// Principal the approval was granted **to**. Must be the actor.
  final String requesterPrincipalId;

  /// Principal who granted it. Must not be the actor.
  final String approverPrincipalId;

  /// The exact action approved. An approval for one permission does not
  /// authorize another.
  final Permission permission;

  /// The exact resource approved. An approval for one order does not
  /// authorize acting on a different one.
  final String resourceId;

  /// Server time the approval was recorded.
  final DateTime approvedAtServerUtc;
}

/// Everything the evaluator is allowed to look at.
///
/// Note what is **not** here: the command payload. Authorization never reads
/// caller-supplied content, so an actor or role asserted in a payload cannot
/// influence the outcome. [principal], [membership] and [scope] are all built
/// by the server from verified authentication and trusted storage.
@immutable
class AuthorizationRequest {
  const AuthorizationRequest({
    required this.permission,
    required this.scope,
    this.principal,
    this.membership,
    this.reason,
    this.approval,
  });

  final Permission permission;

  /// Server-known facts about the target resource.
  final ResourceScope scope;

  /// Verified identity. Null means unauthenticated.
  final Principal? principal;

  /// Trusted membership record for [principal]. Null means none exists.
  final Membership? membership;

  /// Caller-supplied justification, stored with the audit record when the
  /// permission requires one.
  final String? reason;

  /// Dual-control approval, when the permission requires one.
  final ApprovalEvidence? approval;
}

/// Proof that [evaluateAuthorization] allowed a **specific** request.
///
/// ## Why this type exists
///
/// Downstream steps — idempotency replay above all — must be able to rely on
/// "this was authorized". A plain boolean, or a decision object anyone could
/// construct, cannot carry that weight: a caller could simply assert success.
///
/// So this class is unforgeable by construction:
///
/// - it is `final`, so no code outside this library may `extend` or
///   `implement` it and hand over a look-alike;
/// - its only constructor is private to this library, so no code outside may
///   create one;
/// - the sole way to obtain one is a successful [evaluateAuthorization].
///
/// That is a **type-system** guarantee, not a naming convention. Calling it
/// `trusted` or writing "server only" in a comment would stop nobody.
///
/// ## Why it carries bindings
///
/// An unbound "allowed" is still dangerous: a grant issued for principal A on
/// resource X could be presented while handling principal B's command on
/// resource Y. A grant therefore records exactly what was authorized, and
/// consumers re-check it against the request they are actually serving.
final class AuthorizationGrant {
  const AuthorizationGrant._({
    required this.principalId,
    required this.permission,
    required this.resourceId,
  });

  /// Principal that was authorized. From the evaluated [Principal], which the
  /// server derived from verified authentication.
  final String principalId;

  /// Permission that was evaluated. Retained for command dispatch and audit.
  ///
  /// Note what this does *not* yet enable: `evaluateIdempotency` cannot check
  /// that a command type requires this permission, because no command-type →
  /// permission mapping exists in the contract yet. Mapping the incoming
  /// command type to the required permission **before** authorization is
  /// evaluated is the trusted backend router's job. No registry was invented
  /// here to make the check look mechanical.
  final Permission permission;

  /// Resource that was authorized, from the evaluated [ResourceScope].
  final String resourceId;

  /// Whether this grant actually covers the request being served.
  bool covers({required String principalId, required String resourceId}) =>
      this.principalId == principalId && this.resourceId == resourceId;

  @override
  String toString() =>
      'AuthorizationGrant(${permission.id}, principal=$principalId, '
      'resource=$resourceId)';
}

/// Outcome of a deterministic, side-effect-free policy evaluation.
///
/// `final` and privately constructed for the same reason as
/// [AuthorizationGrant]: a decision that any caller could manufacture would
/// prove nothing. Obtain one from [evaluateAuthorization].
final class AuthorizationDecision {
  const AuthorizationDecision._allow(this.grant) : reason = null;

  const AuthorizationDecision._deny(this.reason) : grant = null;

  /// Non-null exactly when the request was allowed. This *is* the success
  /// artifact; there is no separate boolean to disagree with it.
  final AuthorizationGrant? grant;

  /// Internal detail. Log it, test it, audit it — do not return it verbatim to
  /// an untrusted caller.
  final DenyReason? reason;

  bool get allowed => grant != null;

  /// What an untrusted caller may be told. Deliberately uniform across every
  /// denial so a caller cannot probe for the existence, owner, shop or region
  /// of a resource by comparing messages.
  String get publicMessage =>
      allowed ? 'Permitted.' : 'You do not have permission to do this.';

  @override
  String toString() =>
      allowed ? 'Allow' : 'Deny(${reason?.name ?? 'unspecified'})';
}

/// Evaluate one authorization request against the canonical matrix.
///
/// Pure: no I/O, no clock, no database, no Firebase, no Flutter. The same
/// inputs always produce the same decision, which is what makes the deny paths
/// testable.
///
/// Order matters: identity, then standing, then role, then scope, then the
/// procedural requirements. Cheapest and most fundamental checks first, and no
/// later check can rescue an earlier failure.
AuthorizationDecision evaluateAuthorization(AuthorizationRequest request) {
  final PermissionRule? rule = permissionMatrix[request.permission];
  if (rule == null) {
    // An unknown permission fails closed. A newer client naming a permission
    // this build does not know must never be treated as permitted.
    return const AuthorizationDecision._deny(DenyReason.roleNotEligible);
  }

  // 1. Identity.
  final Principal? principal = request.principal;
  if (principal == null) {
    return const AuthorizationDecision._deny(DenyReason.unauthenticated);
  }
  if (principal.isSystemWorker) {
    // Trusted workers act through their own audited paths, never by borrowing
    // a human role's permission.
    return const AuthorizationDecision._deny(
      DenyReason.systemPrincipalNotEligible,
    );
  }

  // 2. Standing. A valid token from a suspended member is still a valid token.
  final Membership? membership = request.membership;
  if (membership == null || membership.principalId != principal.id) {
    return const AuthorizationDecision._deny(DenyReason.membershipMissing);
  }
  if (!rule.acceptableStatuses.contains(membership.status)) {
    return const AuthorizationDecision._deny(DenyReason.membershipNotActive);
  }

  // 3. Role eligibility. Role alone never authorizes, but the wrong role
  //    always denies.
  if (!rule.eligibleRoles.contains(membership.role)) {
    return const AuthorizationDecision._deny(DenyReason.roleNotEligible);
  }

  // 4. Scope. Every requirement in the rule must hold. Iterating the enum's
  //    declaration order rather than the rule's set makes the reported deny
  //    reason independent of how the set literal was written.
  for (final ScopeRequirement requirement in ScopeRequirement.values) {
    if (!rule.scopes.contains(requirement)) {
      continue;
    }
    final AuthorizationDecision? denial = _checkScope(
      requirement,
      principal,
      membership,
      request.scope,
    );
    if (denial != null) {
      return denial;
    }
  }

  // 5. Procedural requirements for privileged actions.
  if (rule.reasonRequired) {
    final String reason = request.reason?.trim() ?? '';
    if (reason.isEmpty) {
      return const AuthorizationDecision._deny(DenyReason.reasonRequired);
    }
  }
  if (rule.approvalRequired) {
    final ApprovalEvidence? approval = request.approval;
    if (approval == null) {
      return const AuthorizationDecision._deny(DenyReason.approvalRequired);
    }
    if (!isValidOpaqueId(approval.approvalRef)) {
      // An unusable reference cannot be audited back to a stored record.
      return const AuthorizationDecision._deny(DenyReason.approvalMismatch);
    }
    // The approval must be bound to *this* request. Without these four checks
    // any valid approval record would satisfy any privileged action.
    if (approval.requesterPrincipalId != principal.id ||
        approval.permission != request.permission ||
        approval.resourceId != request.scope.resourceId) {
      return const AuthorizationDecision._deny(DenyReason.approvalMismatch);
    }
    // Dual control: self-approval is no control at all.
    if (approval.approverPrincipalId == principal.id) {
      return const AuthorizationDecision._deny(DenyReason.approvalMismatch);
    }
  }

  return AuthorizationDecision._allow(
    AuthorizationGrant._(
      principalId: principal.id,
      permission: request.permission,
      resourceId: request.scope.resourceId,
    ),
  );
}

AuthorizationDecision? _checkScope(
  ScopeRequirement requirement,
  Principal principal,
  Membership membership,
  ResourceScope scope,
) {
  switch (requirement) {
    case ScopeRequirement.none:
      return null;

    case ScopeRequirement.ownResource:
      return scope.isOwnedBy(principal.id)
          ? null
          : const AuthorizationDecision._deny(
              DenyReason.resourceOwnerMismatch,
            );

    case ScopeRequirement.ownShop:
      final String? shopId = scope.shopId;
      // A resource with no shop cannot satisfy a shop-scoped permission, and
      // an empty membership shop set means no shop authority — never all.
      if (shopId == null || !membership.operatesShop(shopId)) {
        return const AuthorizationDecision._deny(DenyReason.shopMismatch);
      }
      return null;

    case ScopeRequirement.ownRegion:
      final String? memberRegion = membership.regionId;
      final String? resourceRegion = scope.regionId;
      if (memberRegion == null ||
          resourceRegion == null ||
          memberRegion != resourceRegion) {
        return const AuthorizationDecision._deny(DenyReason.regionMismatch);
      }
      return null;

    case ScopeRequirement.offeredResource:
      // The offer must have been addressed to this principal. Being in the
      // right region is not enough: otherwise any active worker nearby could
      // accept someone else's offer.
      return scope.isOfferedTo(principal.id)
          ? null
          : const AuthorizationDecision._deny(DenyReason.offerMismatch);

    case ScopeRequirement.assignedResource:
      // An accepted assignment. An offer alone never satisfies this, which is
      // what keeps post-acceptance actions closed to a merely-offered worker.
      return scope.isAssignedTo(principal.id)
          ? null
          : const AuthorizationDecision._deny(DenyReason.assignmentMismatch);
  }
}
