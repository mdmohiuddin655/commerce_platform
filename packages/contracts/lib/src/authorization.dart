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

  /// The principal holds no accepted assignment on the resource.
  assignmentMismatch,

  /// The permission requires a stored reason and none was supplied.
  reasonRequired,

  /// The permission requires dual-control approval that was absent or invalid.
  approvalRequired,
}

/// Evidence that a second principal approved a privileged action.
@immutable
class ApprovalEvidence {
  const ApprovalEvidence({
    required this.approverPrincipalId,
    required this.approvedAtServerUtc,
    required this.approvalRef,
  });

  final String approverPrincipalId;

  /// Server time. A client clock never establishes when approval happened.
  final DateTime approvedAtServerUtc;

  /// Opaque reference to the stored approval record, for audit.
  final String approvalRef;
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

/// Outcome of a deterministic, side-effect-free policy evaluation.
@immutable
class AuthorizationDecision {
  const AuthorizationDecision._(this.allowed, this.reason);

  const AuthorizationDecision.allow() : this._(true, null);

  const AuthorizationDecision.deny(DenyReason reason) : this._(false, reason);

  final bool allowed;

  /// Internal detail. Log it, test it, audit it — do not return it verbatim to
  /// an untrusted caller.
  final DenyReason? reason;

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
    return const AuthorizationDecision.deny(DenyReason.roleNotEligible);
  }

  // 1. Identity.
  final Principal? principal = request.principal;
  if (principal == null) {
    return const AuthorizationDecision.deny(DenyReason.unauthenticated);
  }
  if (principal.isSystemWorker) {
    // Trusted workers act through their own audited paths, never by borrowing
    // a human role's permission.
    return const AuthorizationDecision.deny(
      DenyReason.systemPrincipalNotEligible,
    );
  }

  // 2. Standing. A valid token from a suspended member is still a valid token.
  final Membership? membership = request.membership;
  if (membership == null || membership.principalId != principal.id) {
    return const AuthorizationDecision.deny(DenyReason.membershipMissing);
  }
  if (!rule.acceptableStatuses.contains(membership.status)) {
    return const AuthorizationDecision.deny(DenyReason.membershipNotActive);
  }

  // 3. Role eligibility. Role alone never authorizes, but the wrong role
  //    always denies.
  if (!rule.eligibleRoles.contains(membership.role)) {
    return const AuthorizationDecision.deny(DenyReason.roleNotEligible);
  }

  // 4. Scope.
  final AuthorizationDecision? scopeDenial = _checkScope(
    rule.scope,
    principal,
    membership,
    request.scope,
  );
  if (scopeDenial != null) {
    return scopeDenial;
  }

  // 5. Procedural requirements for privileged actions.
  if (rule.reasonRequired) {
    final String reason = request.reason?.trim() ?? '';
    if (reason.isEmpty) {
      return const AuthorizationDecision.deny(DenyReason.reasonRequired);
    }
  }
  if (rule.approvalRequired) {
    final ApprovalEvidence? approval = request.approval;
    if (approval == null || approval.approvalRef.isEmpty) {
      return const AuthorizationDecision.deny(DenyReason.approvalRequired);
    }
    // Dual control: self-approval is no control at all.
    if (approval.approverPrincipalId == principal.id) {
      return const AuthorizationDecision.deny(DenyReason.approvalRequired);
    }
  }

  return const AuthorizationDecision.allow();
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
          : const AuthorizationDecision.deny(
              DenyReason.resourceOwnerMismatch,
            );

    case ScopeRequirement.ownShop:
      final String? shopId = scope.shopId;
      // A resource with no shop cannot satisfy a shop-scoped permission, and
      // an empty membership shop set means no shop authority — never all.
      if (shopId == null || !membership.operatesShop(shopId)) {
        return const AuthorizationDecision.deny(DenyReason.shopMismatch);
      }
      return null;

    case ScopeRequirement.ownRegion:
      final String? memberRegion = membership.regionId;
      final String? resourceRegion = scope.regionId;
      if (memberRegion == null ||
          resourceRegion == null ||
          memberRegion != resourceRegion) {
        return const AuthorizationDecision.deny(DenyReason.regionMismatch);
      }
      return null;

    case ScopeRequirement.assignedResource:
      return scope.isAssignedTo(principal.id)
          ? null
          : const AuthorizationDecision.deny(DenyReason.assignmentMismatch);
  }
}
