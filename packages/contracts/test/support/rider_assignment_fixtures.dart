import 'package:cp_contracts/cp_contracts.dart';

const String orderId = 'ord_Xa91ZZ0plQ7rTt4B';
const String otherOrderId = 'ord_Zz42QQ8mmW1xVv7C';

const String pickerA = 'usr_pickA01Aa-Bb22C';
const String pickerB = 'usr_pickB01Aa-Bb22C';
const String riderA = 'usr_ridrA01Aa-Bb22C';
const String riderB = 'usr_ridrB01Aa-Bb22C';
const String agentId = 'usr_agent01Aa-Bb22C';
const String customerId = 'usr_cust001Aa-Bb22C';

/// Picker assignment attempt ids.
const String pickAsgA = 'asg_Pp11Bb22Cc33Dd44';
const String pickAsgB = 'asg_Pp99Ee55Ff66Gg77';

/// Rider assignment attempt ids.
const String rideAsgA = 'asg_Rr11Bb22Cc33Dd44';
const String rideAsgB = 'asg_Rr22Cc33Dd44Ee55';
const String rideAsgC = 'asg_Rr33Dd44Ee55Ff66';

const String region = 'dhaka_north';
const String otherRegion = 'dhaka_south';
const String policyRef = 'policy/assignment_offer_timeout@v1';

/// Trusted membership facts for a rider target.
RiderEligibility riderEligible(
  String id, {
  CommerceRole role = CommerceRole.rider,
  MembershipStatus status = MembershipStatus.active,
  String? regionId = region,
  bool human = true,
  String? membershipOf,
}) => RiderEligibility(
  principalId: id,
  isHumanPrincipal: human,
  membershipPrincipalId: membershipOf ?? id,
  role: role,
  status: status,
  regionId: regionId,
);

/// The order's canonical picker slot, as the backend would load it.
///
/// Defaults to the situation the rider lifecycle requires: picker A holds an
/// accepted picker assignment. `slotRevision` defaults to a value inside the
/// reachable range for the state, so the picker aggregate validates.
PickerAssignmentFacts pickerSlot({
  AssignmentState? state = AssignmentState.accepted,
  String pickerId = pickerA,
  String assignmentId = pickAsgA,
  int generation = 1,
  int? slotRevision,
  OrderState orderState = OrderState.accepted,
  String? orderRegion = region,
  String resourceId = orderId,
}) {
  if (state == null) {
    return PickerAssignmentFacts(
      resourceId: resourceId,
      slotRevision: slotRevision ?? 0,
      orderState: orderState,
      orderRegionId: orderRegion,
    );
  }
  final int defaultRevision = switch (state) {
    AssignmentState.offered => 2 * generation - 1,
    AssignmentState.revoked => 2 * generation + 1,
    _ => 2 * generation,
  };
  final bool wasAccepted =
      state == AssignmentState.accepted || state == AssignmentState.revoked;
  return PickerAssignmentFacts(
    resourceId: resourceId,
    slotRevision: slotRevision ?? defaultRevision,
    orderState: orderState,
    orderRegionId: orderRegion,
    attempt: PickerAssignmentAttempt(
      assignmentId: assignmentId,
      generation: generation,
      state: state,
      offerRecipientPrincipalId: pickerId,
      acceptedAssigneePrincipalId: wasAccepted ? pickerId : null,
      timeoutPolicyRef: policyRef,
    ),
  );
}

/// The picker binding a rider attempt records.
SourcePickerBinding source({
  String pickerId = pickerA,
  String assignmentId = pickAsgA,
  int generation = 1,
}) => SourcePickerBinding(
  pickerPrincipalId: pickerId,
  pickerAssignmentId: assignmentId,
  pickerGeneration: generation,
);

RiderAssignmentAttempt riderAttempt({
  String id = rideAsgA,
  int generation = 1,
  AssignmentState state = AssignmentState.offered,
  String recipient = riderA,
  String? assignee,
  String timeoutRef = policyRef,
  SourcePickerBinding? from,
}) => RiderAssignmentAttempt(
  assignmentId: id,
  generation: generation,
  state: state,
  offerRecipientPrincipalId: recipient,
  acceptedAssigneePrincipalId: assignee,
  timeoutPolicyRef: timeoutRef,
  source: from ?? source(),
);

RiderAssignmentFacts riderFacts({
  int slotRevision = 0,
  OrderState orderState = OrderState.accepted,
  String? orderRegion = region,
  RiderAssignmentAttempt? current,
  String resourceId = orderId,
}) => RiderAssignmentFacts(
  resourceId: resourceId,
  slotRevision: slotRevision,
  orderState: orderState,
  orderRegionId: orderRegion,
  attempt: current,
);

/// Evaluate one rider command.
///
/// `pickerAuthority` defaults to the canonical accepted-picker slot for the
/// same order and order state, which is what the happy paths need; a test
/// that cares passes its own.
RiderAssignmentOutcome runRider(
  AssignmentCommand command, {
  required RiderAssignmentFacts on,
  PickerAssignmentFacts? pickerAuthority,
  bool omitPickerAuthority = false,
  String acting = pickerA,
  int? expectedSlotRevision,
  String? assignmentId,
  int? generation,
  String? newAssignmentId,
  RiderEligibility? target,
  String? timeoutRef = policyRef,
  bool expiryDue = false,
  ReassignmentSafety safety = ReassignmentSafety.blockedOrUnknown,
}) => evaluateRiderAssignment(
  request: RiderAssignmentRequest(
    command: command,
    expectedSlotRevision: expectedSlotRevision ?? on.slotRevision,
    actingPrincipalId: acting,
    assignmentId: assignmentId ?? on.attempt?.assignmentId,
    generation: generation ?? on.attempt?.generation,
    newAssignmentId: newAssignmentId,
    targetEligibility: target,
    timeoutPolicyRef: timeoutRef,
    expiryDue: expiryDue,
    reassignmentSafety: safety,
  ),
  facts: on,
  pickerAuthority: omitPickerAuthority
      ? null
      : pickerAuthority ??
            pickerSlot(
              orderState: on.orderState,
              orderRegion: on.orderRegionId,
              resourceId: on.resourceId,
            ),
);

RiderAssignmentTransition allowedRider(RiderAssignmentOutcome o) {
  final RiderAssignmentTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

/// Applies a transition to produce the next trusted facts, as a backend would.
///
/// **Test infrastructure only.** It is not evidence that real persistence is
/// correct: the canonical record, the scope projection, the outbox event and
/// the revision must commit atomically in one transaction, which is backend
/// acceptance criterion RA14 and remains NOT RUN.
RiderAssignmentFacts applyRider(
  RiderAssignmentTransition t, {
  OrderState orderState = OrderState.accepted,
}) => RiderAssignmentFacts(
  resourceId: orderId,
  slotRevision: t.resultingSlotRevision,
  orderState: orderState,
  orderRegionId: region,
  attempt: RiderAssignmentAttempt(
    assignmentId: t.assignmentId,
    generation: t.generation,
    state: t.toState,
    offerRecipientPrincipalId: t.offerRecipientPrincipalId,
    acceptedAssigneePrincipalId: t.acceptedAssigneePrincipalId,
    timeoutPolicyRef: policyRef,
    source: t.source,
  ),
);
