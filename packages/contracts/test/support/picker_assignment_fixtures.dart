import 'package:cp_contracts/cp_contracts.dart';

const String orderId = 'ord_Xa91ZZ0plQ7rTt4B';
const String pickerA = 'usr_pickA01Aa-Bb22C';
const String pickerB = 'usr_pickB01Aa-Bb22C';
const String agentId = 'usr_agent01Aa-Bb22C';
const String assignA = 'asg_Aa11Bb22Cc33Dd44';
const String assignB = 'asg_Bb11Cc22Dd33Ee44';
const String region = 'dhaka_north';
const String policyRef = 'policy/assignment_offer_timeout@v1';

PickerEligibility eligible(
  String id, {
  CommerceRole role = CommerceRole.picker,
  MembershipStatus status = MembershipStatus.active,
  String? regionId = region,
  bool human = true,
  String? membershipOf,
}) => PickerEligibility(
  principalId: id,
  isHumanPrincipal: human,
  membershipPrincipalId: membershipOf ?? id,
  role: role,
  status: status,
  regionId: regionId,
);

PickerAssignmentAttempt attempt({
  String id = assignA,
  int generation = 1,
  AssignmentState state = AssignmentState.offered,
  String recipient = pickerA,
  String? assignee,
  String timeoutRef = policyRef,
}) => PickerAssignmentAttempt(
  assignmentId: id,
  generation: generation,
  state: state,
  offerRecipientPrincipalId: recipient,
  acceptedAssigneePrincipalId: assignee,
  timeoutPolicyRef: timeoutRef,
);

PickerAssignmentFacts facts({
  int slotRevision = 0,
  OrderState orderState = OrderState.accepted,
  String? orderRegion = region,
  PickerAssignmentAttempt? current,
}) => PickerAssignmentFacts(
  resourceId: orderId,
  slotRevision: slotRevision,
  orderState: orderState,
  orderRegionId: orderRegion,
  attempt: current,
);

PickerAssignmentOutcome run(
  AssignmentCommand command, {
  required PickerAssignmentFacts on,
  String acting = pickerA,
  int? expectedSlotRevision,
  String? assignmentId,
  int? generation,
  String? newAssignmentId,
  PickerEligibility? target,
  String? timeoutRef = policyRef,
  bool expiryDue = false,
  ReassignmentSafety safety = ReassignmentSafety.blockedOrUnknown,
}) => evaluatePickerAssignment(
  request: PickerAssignmentRequest(
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
);

PickerAssignmentTransition allowed(PickerAssignmentOutcome o) {
  final PickerAssignmentTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

/// Applies a transition to produce the next trusted facts, as a backend would.
PickerAssignmentFacts apply(
  PickerAssignmentTransition t, {
  OrderState orderState = OrderState.accepted,
}) => PickerAssignmentFacts(
  resourceId: orderId,
  slotRevision: t.resultingSlotRevision,
  orderState: orderState,
  orderRegionId: region,
  attempt: PickerAssignmentAttempt(
    assignmentId: t.assignmentId,
    generation: t.generation,
    state: t.toState,
    offerRecipientPrincipalId: t.offerRecipientPrincipalId,
    acceptedAssigneePrincipalId: t.acceptedAssigneePrincipalId,
    timeoutPolicyRef: policyRef,
  ),
);
