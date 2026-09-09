import 'package:cp_contracts/src/membership.dart';
import 'package:cp_contracts/src/permission.dart';
import 'package:cp_contracts/src/role.dart';
import 'package:cp_contracts/src/scope.dart';
import 'package:meta/meta.dart';

/// One row of the canonical permission matrix.
@immutable
class PermissionRule {
  const PermissionRule({
    required this.permission,
    required this.eligibleRoles,
    required this.scope,
    this.acceptableStatuses = const <MembershipStatus>{
      MembershipStatus.active,
    },
    this.reasonRequired = false,
    this.approvalRequired = false,
    this.restriction = '',
  });

  final Permission permission;

  /// Roles that may ever hold this permission. A role outside this set is
  /// denied even with a perfect scope match.
  final Set<CommerceRole> eligibleRoles;

  /// Relationship the actor must have to the resource.
  final ScopeRequirement scope;

  /// Membership statuses that may exercise it. Defaults to active only, so a
  /// suspended member cannot start new work. A later lifecycle slice may add a
  /// narrow wind-down permission that also accepts `suspended`; the field
  /// exists so that can happen without loosening anything else.
  final Set<MembershipStatus> acceptableStatuses;

  /// A human-supplied reason must accompany the command and is stored.
  final bool reasonRequired;

  /// A second, different principal must have approved it (dual control).
  final bool approvalRequired;

  /// Free-text limit recorded in the generated documentation.
  final String restriction;
}

/// **The** permission matrix. Five apps and the backend consume this one
/// table; none of them keeps its own copy.
const Map<Permission, PermissionRule> permissionMatrix =
    <Permission, PermissionRule>{
  // ------------------------------------------------------------------ customer
  Permission.customerSubmitCheckout: PermissionRule(
    permission: Permission.customerSubmitCheckout,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scope: ScopeRequirement.ownResource,
    restriction: 'Submits an intent only. Prices, stock and fees are resolved '
        'server-side; a client-quoted amount is never trusted.',
  ),
  Permission.customerViewOwnOrder: PermissionRule(
    permission: Permission.customerViewOwnOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scope: ScopeRequirement.ownResource,
    restriction: 'Own orders only. No listing of other customers exists.',
  ),
  Permission.customerRequestCancellation: PermissionRule(
    permission: Permission.customerRequestCancellation,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scope: ScopeRequirement.ownResource,
    reasonRequired: true,
    restriction: 'Requests only. The server decides from the current stage '
        'whether cancellation is permitted; the client never cancels.',
  ),
  Permission.customerConfirmDeliveryProof: PermissionRule(
    permission: Permission.customerConfirmDeliveryProof,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scope: ScopeRequirement.ownResource,
    restriction: 'Participation in proof only. Confirming does not settle '
        'cash and does not close a dispute.',
  ),
  Permission.customerRaiseDispute: PermissionRule(
    permission: Permission.customerRaiseDispute,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scope: ScopeRequirement.ownResource,
    reasonRequired: true,
  ),

  // --------------------------------------------------------------------- agent
  Permission.agentViewShopOrder: PermissionRule(
    permission: Permission.agentViewShopOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
    restriction: 'Only shops in the membership. Never a platform-wide feed.',
  ),
  Permission.agentAcceptOrder: PermissionRule(
    permission: Permission.agentAcceptOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
  ),
  Permission.agentRejectOrder: PermissionRule(
    permission: Permission.agentRejectOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
    reasonRequired: true,
  ),
  Permission.agentRecordShopFulfillment: PermissionRule(
    permission: Permission.agentRecordShopFulfillment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
    restriction: 'Records shop-side progress. Never writes trusted stock, '
        'order status or cash fields directly.',
  ),
  Permission.agentOfferPickerAssignment: PermissionRule(
    permission: Permission.agentOfferPickerAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
    restriction: 'Offers work. An offer is not an assignment and never '
        'implies custody.',
  ),
  Permission.agentOfferRiderAssignment: PermissionRule(
    permission: Permission.agentOfferRiderAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scope: ScopeRequirement.ownShop,
    restriction: 'Offers work only, within the agent\'s own shops.',
  ),

  // -------------------------------------------------------------------- picker
  Permission.pickerViewAssignedWork: PermissionRule(
    permission: Permission.pickerViewAssignedWork,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scope: ScopeRequirement.assignedResource,
    restriction: 'Only what the active assignment needs. Not a customer '
        'directory and not a browsable order list.',
  ),
  Permission.pickerAcceptAssignment: PermissionRule(
    permission: Permission.pickerAcceptAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scope: ScopeRequirement.ownRegion,
    restriction: 'Accepting an offer requires the offer to be live and in '
        'region; acceptance is decided server-side.',
  ),
  Permission.pickerDeclineAssignment: PermissionRule(
    permission: Permission.pickerDeclineAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scope: ScopeRequirement.ownRegion,
  ),
  Permission.pickerRecordShopPickup: PermissionRule(
    permission: Permission.pickerRecordShopPickup,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scope: ScopeRequirement.assignedResource,
  ),
  Permission.pickerRecordHandoffToRider: PermissionRule(
    permission: Permission.pickerRecordHandoffToRider,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scope: ScopeRequirement.assignedResource,
    restriction: 'Records a custody handoff. Custody changes only on a proven '
        'handoff, never on a notification or an elapsed timer.',
  ),

  // --------------------------------------------------------------------- rider
  Permission.riderViewAssignedWork: PermissionRule(
    permission: Permission.riderViewAssignedWork,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
    restriction: 'Only what the active assignment needs, including the '
        'delivery address for that assignment alone.',
  ),
  Permission.riderAcceptAssignment: PermissionRule(
    permission: Permission.riderAcceptAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.ownRegion,
  ),
  Permission.riderDeclineAssignment: PermissionRule(
    permission: Permission.riderDeclineAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.ownRegion,
  ),
  Permission.riderRecordCustodyReceipt: PermissionRule(
    permission: Permission.riderRecordCustodyReceipt,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
  ),
  Permission.riderRecordDeliveryAttempt: PermissionRule(
    permission: Permission.riderRecordDeliveryAttempt,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
  ),
  Permission.riderSubmitDeliveryProof: PermissionRule(
    permission: Permission.riderSubmitDeliveryProof,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
  ),
  Permission.riderReportCodCollection: PermissionRule(
    permission: Permission.riderReportCodCollection,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
    restriction: 'Reports what was actually received. Reporting is not '
        'settlement, and it never writes a balance: the server derives '
        'postings. Delivered is not equivalent to rider cash settled.',
  ),
  Permission.riderSubmitRemittance: PermissionRule(
    permission: Permission.riderSubmitRemittance,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scope: ScopeRequirement.assignedResource,
    restriction: 'Submits a remittance for a receiving party to confirm. The '
        'rider never edits settlement history or their own balance.',
  ),

  // --------------------------------------------------------------------- admin
  Permission.adminApproveWorker: PermissionRule(
    permission: Permission.adminApproveWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Dual control: the approver must be a different principal '
        'from the requester.',
  ),
  Permission.adminSuspendWorker: PermissionRule(
    permission: Permission.adminSuspendWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    restriction: 'Audited. Stops new work; controlled resolution of work '
        'already in custody is owned by the lifecycle slice.',
  ),
  Permission.adminReinstateWorker: PermissionRule(
    permission: Permission.adminReinstateWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    approvalRequired: true,
  ),
  Permission.adminModerateShop: PermissionRule(
    permission: Permission.adminModerateShop,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
  ),
  Permission.adminAdministerServiceZone: PermissionRule(
    permission: Permission.adminAdministerServiceZone,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
  ),
  Permission.adminPublishPolicyVersion: PermissionRule(
    permission: Permission.adminPublishPolicyVersion,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.none,
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Publishes a new immutable policy version. Never edits a '
        'published one: orders keep the policy version they were quoted '
        'under.',
  ),
  Permission.adminSupportViewOrder: PermissionRule(
    permission: Permission.adminSupportViewOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    restriction: 'Read-only, region-scoped, reason-bearing and logged. '
        'Confers no mutation authority of any kind.',
  ),
  Permission.adminAdministerDispute: PermissionRule(
    permission: Permission.adminAdministerDispute,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
  ),
  Permission.adminAdministerReturn: PermissionRule(
    permission: Permission.adminAdministerReturn,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    restriction: 'Stock cannot become available again until shop receipt and '
        'inspection; this permission does not shortcut that.',
  ),
  Permission.adminRecordCashReconciliation: PermissionRule(
    permission: Permission.adminRecordCashReconciliation,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.ownRegion,
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Records a reconciliation as new balanced postings under '
        'dual control. It is NOT a balance edit and NOT a journal edit: '
        'corrections are reversals, history is never rewritten.',
  ),
  Permission.adminViewReleaseHealth: PermissionRule(
    permission: Permission.adminViewReleaseHealth,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scope: ScopeRequirement.none,
    restriction: 'Aggregate operational metrics only. No personal data.',
  ),
};
