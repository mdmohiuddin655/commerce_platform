import 'package:cp_contracts/cp_contracts.dart';

const String orderId = 'ord_Xa91ZZ0plQ7rTt4B';
const String otherOrderId = 'ord_Zz42QQ8mmW1xVv7C';
const String shopId = 'shop_alpha';

const String pickerA = 'usr_pickA01Aa-Bb22C';
const String pickerB = 'usr_pickB01Aa-Bb22C';
const String riderA = 'usr_ridrA01Aa-Bb22C';
const String riderB = 'usr_ridrB01Aa-Bb22C';

const String pickAsgA = 'asg_Pp11Bb22Cc33Dd44';
const String pickAsgB = 'asg_Pp99Ee55Ff66Gg77';
const String rideAsgA = 'asg_Rr11Bb22Cc33Dd44';
const String rideAsgB = 'asg_Rr22Cc33Dd44Ee55';

const String region = 'dhaka_north';
const String policyRef = 'policy/assignment_offer_timeout@v1';

/// The canonical order/shop identity the backend resolved the command against.
CustodyResourceContext resourceContext({
  String resourceId = orderId,
  String shop = shopId,
}) => CustodyResourceContext(resourceId: resourceId, shopId: shop);

/// Custody at the shop — the canonical state of a ready order.
CustodyFacts atShop({
  int revision = 1,
  String resourceId = orderId,
  String shop = shopId,
}) => CustodyFacts(
  resourceId: resourceId,
  custodyRevision: revision,
  holder: CustodyHolder.atShop(shopId: shop),
);

/// Custody held by a field worker, bound to one assignment attempt.
CustodyFacts withWorker({
  required CustodyHolderKind kind,
  String? principalId,
  String? assignmentId,
  int generation = 1,
  int revision = 2,
  String resourceId = orderId,
}) => CustodyFacts(
  resourceId: resourceId,
  custodyRevision: revision,
  holder: CustodyHolder.worker(
    kind: kind,
    principalId:
        principalId ?? (kind == CustodyHolderKind.picker ? pickerA : riderA),
    assignmentId:
        assignmentId ?? (kind == CustodyHolderKind.picker ? pickAsgA : rideAsgA),
    assignmentGeneration: generation,
  ),
);

CustodyFacts withPicker({
  String? principalId,
  String? assignmentId,
  int generation = 1,
  int revision = 2,
}) => withWorker(
  kind: CustodyHolderKind.picker,
  principalId: principalId,
  assignmentId: assignmentId,
  generation: generation,
  revision: revision,
);

CustodyFacts withRider({
  String? principalId,
  String? assignmentId,
  int generation = 1,
  int revision = 3,
}) => withWorker(
  kind: CustodyHolderKind.rider,
  principalId: principalId,
  assignmentId: assignmentId,
  generation: generation,
  revision: revision,
);

/// A ready order with a committed reservation.
OrderLifecycleFacts orderFacts({
  OrderState state = OrderState.ready,
  int revision = 4,
  ReservationState reservation = ReservationState.committed,
  int units = 3,
}) => OrderLifecycleFacts(
  state: state,
  revision: revision,
  reservationState: reservation,
  reservedUnits: units,
);

/// The order's picker slot.
PickerAssignmentFacts pickerSlot({
  AssignmentState? state = AssignmentState.accepted,
  String principalId = pickerA,
  String assignmentId = pickAsgA,
  int generation = 1,
  int? slotRevision,
  OrderState orderState = OrderState.ready,
  String resourceId = orderId,
}) {
  if (state == null) {
    return PickerAssignmentFacts(
      resourceId: resourceId,
      slotRevision: 0,
      orderState: orderState,
      orderRegionId: region,
    );
  }
  final int defaultRevision = switch (state) {
    AssignmentState.offered => 2 * generation - 1,
    AssignmentState.revoked || AssignmentState.completed => 2 * generation + 1,
    _ => 2 * generation,
  };
  final bool wasAccepted = state != AssignmentState.offered &&
      state != AssignmentState.declined &&
      state != AssignmentState.expired;
  return PickerAssignmentFacts(
    resourceId: resourceId,
    slotRevision: slotRevision ?? defaultRevision,
    orderState: orderState,
    orderRegionId: region,
    attempt: PickerAssignmentAttempt(
      assignmentId: assignmentId,
      generation: generation,
      state: state,
      offerRecipientPrincipalId: principalId,
      acceptedAssigneePrincipalId: wasAccepted ? principalId : null,
      timeoutPolicyRef: policyRef,
    ),
  );
}

/// The order's rider slot.
RiderAssignmentFacts riderSlot({
  AssignmentState? state = AssignmentState.accepted,
  String principalId = riderA,
  String assignmentId = rideAsgA,
  int generation = 1,
  int? slotRevision,
  OrderState orderState = OrderState.ready,
  String resourceId = orderId,
  String sourcePicker = pickerA,
  String sourceAssignment = pickAsgA,
  int sourceGeneration = 1,
}) {
  if (state == null) {
    return RiderAssignmentFacts(
      resourceId: resourceId,
      slotRevision: 0,
      orderState: orderState,
      orderRegionId: region,
    );
  }
  final int defaultRevision = switch (state) {
    AssignmentState.offered => 2 * generation - 1,
    AssignmentState.revoked => 2 * generation + 1,
    _ => 2 * generation,
  };
  final bool wasAccepted =
      state == AssignmentState.accepted || state == AssignmentState.revoked;
  return RiderAssignmentFacts(
    resourceId: resourceId,
    slotRevision: slotRevision ?? defaultRevision,
    orderState: orderState,
    orderRegionId: region,
    attempt: RiderAssignmentAttempt(
      assignmentId: assignmentId,
      generation: generation,
      state: state,
      offerRecipientPrincipalId: principalId,
      acceptedAssigneePrincipalId: wasAccepted ? principalId : null,
      timeoutPolicyRef: policyRef,
      source: SourcePickerBinding(
        pickerPrincipalId: sourcePicker,
        pickerAssignmentId: sourceAssignment,
        pickerGeneration: sourceGeneration,
      ),
    ),
  );
}

/// Evaluate one custody command.
CustodyOutcome runCustody(
  CustodyCommand command, {
  CustodyFacts? custody,
  bool omitCustody = false,
  CustodyResourceContext? resource,
  OrderLifecycleFacts? order,
  PickerAssignmentFacts? picker,
  RiderAssignmentFacts? rider,
  bool omitRider = false,
  String? acting,
  int? expectedCustodyRevision,
  int? expectedOrderRevision,
  int? expectedPickerSlotRevision,
  int? expectedRiderSlotRevision,
  bool omitRiderSlotRevision = false,
  String? assignmentId,
  int? generation,
}) {
  final CustodyFacts? c = omitCustody
      ? null
      : custody ??
            (command == CustodyCommand.recordShopPickup
                ? atShop()
                : withPicker());
  final OrderLifecycleFacts o = order ?? orderFacts();
  final PickerAssignmentFacts p = picker ?? pickerSlot();
  final RiderAssignmentFacts? r = omitRider ? null : rider ?? riderSlot();
  final bool isPickup = command == CustodyCommand.recordShopPickup;
  return evaluateCustodyTransition(
    request: CustodyRequest(
      command: command,
      actingPrincipalId: acting ?? (isPickup ? pickerA : riderA),
      expectedCustodyRevision:
          expectedCustodyRevision ?? c?.custodyRevision ?? 0,
      expectedOrderRevision: expectedOrderRevision ?? o.revision,
      expectedPickerSlotRevision:
          expectedPickerSlotRevision ?? p.slotRevision,
      expectedRiderSlotRevision: omitRiderSlotRevision
          ? null
          : expectedRiderSlotRevision ?? r?.slotRevision,
      assignmentId: assignmentId ?? (isPickup ? pickAsgA : rideAsgA),
      generation: generation ?? 1,
    ),
    resource: resource ?? resourceContext(),
    custody: c,
    order: o,
    pickerAssignment: p,
    riderAssignment: r,
  );
}

CustodyTransition allowedCustody(CustodyOutcome o) {
  final CustodyTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

/// Applies a custody transition to produce the next trusted custody facts, as
/// a backend would.
///
/// **Test infrastructure only.** It is not evidence that real persistence is
/// correct: the custody record, the order, the picker slot, the projections and
/// the outbox events must commit in ONE transaction — criterion **CA9** — which
/// remains NOT RUN.
CustodyFacts applyCustody(CustodyTransition t, {String resourceId = orderId}) =>
    CustodyFacts(
      resourceId: resourceId,
      custodyRevision: t.resultingCustodyRevision,
      holder: t.toHolder,
    );

/// Applies the order half of a custody transition.
OrderLifecycleFacts applyOrder(
  CustodyTransition t,
  OrderLifecycleFacts before,
) => t.orderEffect.changesOrder
    ? OrderLifecycleFacts(
        state: t.orderEffect.toState,
        revision: t.orderEffect.resultingOrderRevision!,
        reservationState: before.reservationState,
        reservedUnits: before.reservedUnits,
      )
    : before;

/// Applies the picker-completion half of a custody transition.
PickerAssignmentFacts applyPickerCompletion(
  CustodyTransition t,
  PickerAssignmentFacts before, {
  OrderState orderState = OrderState.inDelivery,
}) {
  final PickerAssignmentCompletionEffect? c = t.pickerCompletion;
  if (c == null) {
    return before;
  }
  return PickerAssignmentFacts(
    resourceId: before.resourceId,
    slotRevision: c.resultingSlotRevision,
    orderState: orderState,
    orderRegionId: before.orderRegionId,
    attempt: PickerAssignmentAttempt(
      assignmentId: c.assignmentId,
      generation: c.generation,
      state: AssignmentState.completed,
      offerRecipientPrincipalId: c.offerRecipientPrincipalId,
      acceptedAssigneePrincipalId: c.acceptedAssigneePrincipalId,
      timeoutPolicyRef: policyRef,
    ),
  );
}
