/// Stable permission identifiers.
///
/// Code asks "does this actor hold `orderAcceptForShop`", never "is this actor
/// an agent". Role checks scattered through five apps drift apart; a
/// permission vocabulary does not.
///
/// The wire form is [Permission.id]. Never serialize `Enum.index`.
enum Permission {
  // ---------------------------------------------------------------- customer
  customerSubmitCheckout('customer.checkout.submit'),
  customerViewOwnOrder('customer.order.view_own'),
  customerRequestCancellation('customer.order.request_cancellation'),
  customerConfirmDeliveryProof('customer.delivery.confirm_proof'),
  customerRaiseDispute('customer.dispute.raise'),

  // ------------------------------------------------------------------- agent
  agentViewShopOrder('agent.order.view_shop'),
  agentAcceptOrder('agent.order.accept'),
  agentRejectOrder('agent.order.reject'),
  agentRecordShopFulfillment('agent.fulfillment.record_progress'),
  agentOfferPickerAssignment('agent.assignment.offer_picker'),
  agentOfferRiderAssignment('agent.assignment.offer_rider'),

  // ------------------------------------------------------------------ picker
  pickerViewAssignedWork('picker.assignment.view_assigned'),
  pickerAcceptAssignment('picker.assignment.accept'),
  pickerDeclineAssignment('picker.assignment.decline'),
  pickerRecordShopPickup('picker.custody.record_pickup'),
  pickerRecordHandoffToRider('picker.custody.record_handoff'),

  // ------------------------------------------------------------------- rider
  riderViewAssignedWork('rider.assignment.view_assigned'),
  riderAcceptAssignment('rider.assignment.accept'),
  riderDeclineAssignment('rider.assignment.decline'),
  riderRecordCustodyReceipt('rider.custody.record_receipt'),
  riderRecordDeliveryAttempt('rider.delivery.record_attempt'),
  riderSubmitDeliveryProof('rider.delivery.submit_proof'),
  riderReportCodCollection('rider.cash.report_collection'),
  riderSubmitRemittance('rider.cash.submit_remittance'),

  // ------------------------------------------------------------------- admin
  adminApproveWorker('admin.worker.approve'),
  adminSuspendWorker('admin.worker.suspend'),
  adminReinstateWorker('admin.worker.reinstate'),
  adminModerateShop('admin.shop.moderate'),
  adminAdministerServiceZone('admin.zone.administer'),
  adminPublishPolicyVersion('admin.policy.publish_version'),
  adminSupportViewOrder('admin.support.view_order'),
  adminAdministerDispute('admin.dispute.administer'),
  adminAdministerReturn('admin.return.administer'),
  adminRecordCashReconciliation('admin.cash.record_reconciliation'),
  adminViewReleaseHealth('admin.release.view_health');

  const Permission(this.id);

  /// Stable wire identifier.
  final String id;

  /// Family prefix, e.g. `customer`, used for grouping and documentation.
  String get family => id.split('.').first;

  static Permission? byId(String id) {
    for (final Permission p in Permission.values) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }
}

/// Capabilities that must **never** exist in this vocabulary.
///
/// Kept as data, and asserted by a test, so adding one is a build failure
/// rather than a code review someone was tired during. Each is a way the
/// platform could quietly stop being auditable.
class ProhibitedCapability {
  const ProhibitedCapability(this.label, this.why, this.forbiddenIdFragments);

  final String label;
  final String why;

  /// Substrings that would appear in a permission id implementing it.
  final List<String> forbiddenIdFragments;

  static const List<ProhibitedCapability> all = <ProhibitedCapability>[
    ProhibitedCapability(
      'arbitrary status overwrite',
      'A status is the result of a permitted transition, never an input. A '
          'patch-to-status permission would let any holder skip every '
          'precondition, inventory effect and financial effect.',
      <String>['status.set', 'status.overwrite', 'status.patch', 'state.force'],
    ),
    ProhibitedCapability(
      'arbitrary balance edit',
      'Balances are derived from balanced postings. Editing one directly '
          'breaks the invariant that the ledger explains the balance.',
      <String>['balance.edit', 'balance.set', 'balance.adjust_direct'],
    ),
    ProhibitedCapability(
      'historical journal edit',
      'Corrections are reversals, not edits. An editable history is not an '
          'audit trail.',
      <String>['journal.edit', 'journal.delete', 'ledger.edit', 'ledger.delete'],
    ),
    ProhibitedCapability(
      'unaudited impersonation',
      'Acting as another principal without an audited, reason-bearing, '
          'approved record destroys attribution for every downstream event.',
      <String>['impersonate', 'act_as', 'sudo'],
    ),
  ];
}
