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
    required this.scopes,
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

  /// Relationships the actor must have to the resource. **All must hold.**
  ///
  /// A set rather than a single value so a rule can require, for example, both
  /// `offeredResource` and `ownRegion`. Evaluated in [ScopeRequirement]
  /// declaration order, so the reported deny reason does not depend on how the
  /// set literal was written.
  final Set<ScopeRequirement> scopes;

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
    scopes: <ScopeRequirement>{ScopeRequirement.ownResource},
    restriction: 'Submits an intent only. Prices, stock and fees are resolved '
        'server-side; a client-quoted amount is never trusted.',
  ),
  Permission.customerViewOwnOrder: PermissionRule(
    permission: Permission.customerViewOwnOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scopes: <ScopeRequirement>{ScopeRequirement.ownResource},
    restriction: 'Own orders only. No listing of other customers exists.',
  ),
  Permission.customerRequestCancellation: PermissionRule(
    permission: Permission.customerRequestCancellation,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scopes: <ScopeRequirement>{ScopeRequirement.ownResource},
    reasonRequired: true,
    restriction: 'Requests only. The server decides from the current stage '
        'whether cancellation is permitted; the client never cancels.',
  ),
  Permission.customerConfirmDeliveryProof: PermissionRule(
    permission: Permission.customerConfirmDeliveryProof,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scopes: <ScopeRequirement>{ScopeRequirement.ownResource},
    restriction: 'Participation in proof only. Confirming does not settle '
        'cash and does not close a dispute.',
  ),
  Permission.customerRaiseDispute: PermissionRule(
    permission: Permission.customerRaiseDispute,
    eligibleRoles: <CommerceRole>{CommerceRole.customer},
    scopes: <ScopeRequirement>{ScopeRequirement.ownResource},
    reasonRequired: true,
  ),

  // --------------------------------------------------------------------- agent
  Permission.agentViewShopOrder: PermissionRule(
    permission: Permission.agentViewShopOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    restriction: 'Only shops in the membership. Never a platform-wide feed.',
  ),
  Permission.agentAcceptOrder: PermissionRule(
    permission: Permission.agentAcceptOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
  ),
  Permission.agentRejectOrder: PermissionRule(
    permission: Permission.agentRejectOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    reasonRequired: true,
  ),
  Permission.agentRecordShopFulfillment: PermissionRule(
    permission: Permission.agentRecordShopFulfillment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    restriction: 'Records shop-side progress. Never writes trusted stock, '
        'order status or cash fields directly.',
  ),
  Permission.agentOfferPickerAssignment: PermissionRule(
    permission: Permission.agentOfferPickerAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    restriction: 'Offers work. An offer is not an assignment and never '
        'implies custody.',
  ),
  Permission.agentRevokePickerAssignment: PermissionRule(
    permission: Permission.agentRevokePickerAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    reasonRequired: true,
    restriction: 'Controlled reassignment only: withdraws one accepted picker '
        'assignment so the work can be re-offered as a NEW attempt. It cannot '
        'replace an assignee, cannot overwrite assignment state, and cannot '
        'override custody safety — revocation is refused unless the backend '
        'proves the worker never took custody.',
  ),
  Permission.agentOfferRiderAssignment: PermissionRule(
    permission: Permission.agentOfferRiderAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    restriction: 'Offers work only, within the agent\'s own shops. RESERVED '
        'FOR A FUTURE DIRECT SHOP-TO-RIDER PICKUP FLOW and NOT executable: no '
        'implemented command maps to it. The rider lifecycle in FND-003B2B is '
        'picker-originated and uses picker.assignment.offer_rider instead, '
        'because a direct shop pickup takes custody from the shop rather than '
        'from a picker and needs its own lifecycle, order-stage prerequisites '
        'and handoff design.',
  ),

  // -------------------------------------------------------------------- picker
  Permission.pickerViewAssignedWork: PermissionRule(
    permission: Permission.pickerViewAssignedWork,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
    restriction: 'Only what the active assignment needs. Not a customer '
        'directory and not a browsable order list.',
  ),
  Permission.pickerAcceptAssignment: PermissionRule(
    permission: Permission.pickerAcceptAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{
      ScopeRequirement.offeredResource,
      ScopeRequirement.ownRegion,
    },
    restriction: 'The offer must have been addressed to this picker: a '
        'same-region picker cannot accept another picker\'s offer. Does NOT '
        'require an already accepted assignment. Whether the offer is still '
        'live is lifecycle state (FND-003B), not authorization.',
  ),
  Permission.pickerDeclineAssignment: PermissionRule(
    permission: Permission.pickerDeclineAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{
      ScopeRequirement.offeredResource,
      ScopeRequirement.ownRegion,
    },
    restriction: 'Same target isolation as accepting: only the picker the '
        'offer was addressed to may decline it.',
  ),
  Permission.pickerOfferRiderAssignment: PermissionRule(
    permission: Permission.pickerOfferRiderAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{
      ScopeRequirement.assignedResource,
      ScopeRequirement.ownRegion,
    },
    restriction: 'Only the picker currently holding the accepted picker '
        'assignment for this exact order may offer its delivery work, and '
        'only within their own region. Offers work: an offer is not rider '
        'acceptance and never implies custody. It is not a general worker '
        'assignment capability, and it is distinct from the future direct '
        'agent-to-rider shop pickup.',
  ),
  Permission.pickerRevokeRiderAssignment: PermissionRule(
    permission: Permission.pickerRevokeRiderAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{
      ScopeRequirement.assignedResource,
      ScopeRequirement.ownRegion,
    },
    reasonRequired: true,
    restriction: 'Controlled reassignment only: withdraws one accepted rider '
        'assignment so the delivery work can be re-offered as a NEW attempt. '
        'It cannot replace an assignee, cannot overwrite assignment state, '
        'and cannot override custody safety — revocation is refused unless '
        'the backend proves the rider never took custody.',
  ),
  Permission.agentRecordReturnReceipt: PermissionRule(
    permission: Permission.agentRecordReturnReceipt,
    eligibleRoles: <CommerceRole>{CommerceRole.agent},
    scopes: <ScopeRequirement>{ScopeRequirement.ownShop},
    reasonRequired: true,
    restriction: 'Records that returned goods physically arrived at this '
        'shop, moving custody rider -> shop. Receipt alone restores NO stock: '
        'available stock changes only on a separate inspection that records a '
        'restockable disposition. Confers no authority over order state, '
        'rider assignment, money or liability.',
  ),
  Permission.pickerRecordShopPickup: PermissionRule(
    permission: Permission.pickerRecordShopPickup,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
  ),
  Permission.pickerRecordHandoffToRider: PermissionRule(
    permission: Permission.pickerRecordHandoffToRider,
    eligibleRoles: <CommerceRole>{CommerceRole.picker},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
    restriction: 'Records a custody handoff. Custody changes only on a proven '
        'handoff, never on a notification or an elapsed timer.',
  ),

  // --------------------------------------------------------------------- rider
  Permission.riderViewAssignedWork: PermissionRule(
    permission: Permission.riderViewAssignedWork,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
    restriction: 'Only what the active assignment needs, including the '
        'delivery address for that assignment alone.',
  ),
  Permission.riderAcceptAssignment: PermissionRule(
    permission: Permission.riderAcceptAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{
      ScopeRequirement.offeredResource,
      ScopeRequirement.ownRegion,
    },
    restriction: 'The offer must have been addressed to this rider. Does NOT '
        'require an already accepted assignment.',
  ),
  Permission.riderDeclineAssignment: PermissionRule(
    permission: Permission.riderDeclineAssignment,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{
      ScopeRequirement.offeredResource,
      ScopeRequirement.ownRegion,
    },
    restriction: 'Same target isolation as accepting.',
  ),
  Permission.riderRecordCustodyReceipt: PermissionRule(
    permission: Permission.riderRecordCustodyReceipt,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
  ),
  Permission.riderRecordDeliveryAttempt: PermissionRule(
    permission: Permission.riderRecordDeliveryAttempt,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
  ),
  Permission.riderSubmitDeliveryProof: PermissionRule(
    permission: Permission.riderSubmitDeliveryProof,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
  ),
  Permission.riderReportCodCollection: PermissionRule(
    permission: Permission.riderReportCodCollection,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
    restriction: 'Reports what was actually received. Reporting is not '
        'settlement, and it never writes a balance: the server derives '
        'postings. Delivered is not equivalent to rider cash settled.',
  ),
  Permission.riderSubmitRemittance: PermissionRule(
    permission: Permission.riderSubmitRemittance,
    eligibleRoles: <CommerceRole>{CommerceRole.rider},
    scopes: <ScopeRequirement>{ScopeRequirement.assignedResource},
    restriction: 'Submits a remittance for a receiving party to confirm. The '
        'rider never edits settlement history or their own balance.',
  ),

  // --------------------------------------------------------------------- admin
  Permission.adminApproveWorker: PermissionRule(
    permission: Permission.adminApproveWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Dual control: the approver must be a different principal '
        'from the requester.',
  ),
  Permission.adminSuspendWorker: PermissionRule(
    permission: Permission.adminSuspendWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    restriction: 'Audited. Stops new work; controlled resolution of work '
        'already in custody is owned by the lifecycle slice.',
  ),
  Permission.adminReinstateWorker: PermissionRule(
    permission: Permission.adminReinstateWorker,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    approvalRequired: true,
  ),
  Permission.adminModerateShop: PermissionRule(
    permission: Permission.adminModerateShop,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
  ),
  Permission.adminAdministerServiceZone: PermissionRule(
    permission: Permission.adminAdministerServiceZone,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
  ),
  Permission.adminPublishPolicyVersion: PermissionRule(
    permission: Permission.adminPublishPolicyVersion,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.none},
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Publishes a new immutable policy version. Never edits a '
        'published one: orders keep the policy version they were quoted '
        'under.',
  ),
  Permission.adminSupportViewOrder: PermissionRule(
    permission: Permission.adminSupportViewOrder,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    restriction: 'Read-only, region-scoped, reason-bearing and logged. '
        'Confers no mutation authority of any kind.',
  ),
  Permission.adminAdministerDispute: PermissionRule(
    permission: Permission.adminAdministerDispute,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
  ),
  Permission.adminAdministerReturn: PermissionRule(
    permission: Permission.adminAdministerReturn,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    restriction: 'Stock cannot become available again until shop receipt and '
        'inspection; this permission does not shortcut that.',
  ),
  Permission.adminRecordCashReconciliation: PermissionRule(
    permission: Permission.adminRecordCashReconciliation,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.ownRegion},
    reasonRequired: true,
    approvalRequired: true,
    restriction: 'Records a reconciliation as new balanced postings under '
        'dual control. It is NOT a balance edit and NOT a journal edit: '
        'corrections are reversals, history is never rewritten.',
  ),
  Permission.adminViewReleaseHealth: PermissionRule(
    permission: Permission.adminViewReleaseHealth,
    eligibleRoles: <CommerceRole>{CommerceRole.admin},
    scopes: <ScopeRequirement>{ScopeRequirement.none},
    restriction: 'Aggregate operational metrics only. No personal data.',
  ),
};
