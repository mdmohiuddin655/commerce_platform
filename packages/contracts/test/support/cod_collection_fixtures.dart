// Shared fixtures for the FND-003C1 COD collection contract.
//
// Every allow-path test travels the **real** authorization path: an
// `AuthorizationGrant` is `final` with a library-private constructor and can
// only come from a successful `evaluateAuthorization`, so a test can no more
// fabricate one than production can.
import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';

// ------------------------------------------------------------- identities
const String orderId = 'ord_C1a7xKq2mW9tLp4Z';
const String otherOrderId = 'ord_C1z91QQ0plW7rTtB';
const String shopId = 'shop_alpha';
const String region = 'dhaka_north';

const String riderId = 'usr_riderC1a7xKq2mW9';
const String otherRiderId = 'usr_riderC1z81QQ0plW';
const String pickerId = 'usr_pickC1a7xKq2mW9tL';

const String attemptId = 'att_C1a7xKq2mW9tLp4Z';
const String riderAssignmentId = 'rasg_C1a7xKq2mW9tLp4';
const String pickerAssignmentId = 'pasg_C1a7xKq2mW9tLp4';
const String journalEntryId = 'jrn_C1a7xKq2mW9tLp4Z';
const String journalRef = 'jref_C1a7xKq2mW9tLp4';

const String feePolicyId = 'fpol_C1a7xKq2mW9tLp4';
const String commissionPolicyId = 'cpol_C1a7xKq2mW9tLp';

/// Server UTC. Tests needing a non-UTC value build it explicitly.
final DateTime utcNow = DateTime.utc(2026, 9, 11, 14, 5);

Principal user(String id) => Principal.fromVerifiedSubject(id);
Principal worker([String id = 'wrk_C1a7xKq2mW9tLp4Z']) =>
    Principal.systemWorker(id);

Money bdt(int minorUnits) => Money(minorUnits, CurrencyPolicy.bdt);

// ------------------------------------------------------------------ grants

AuthorizationGrant codGrant({
  Permission permission = Permission.riderReportCodCollection,
  String principalId = riderId,
  CommerceRole role = CommerceRole.rider,
  String resourceId = orderId,
  MembershipStatus status = MembershipStatus.active,
  String memberRegion = region,
  Set<String> assigned = const <String>{riderId},
}) {
  final AuthorizationDecision decision = evaluateAuthorization(
    AuthorizationRequest(
      permission: permission,
      scope: ResourceScope(
        resourceId: resourceId,
        ownerPrincipalId: 'usr_ownerC1a7xKq2mW9t',
        shopId: shopId,
        regionId: region,
        assignedPrincipalIds: assigned,
      ),
      principal: Principal.fromVerifiedSubject(principalId),
      membership: Membership(
        principalId: principalId,
        role: role,
        status: status,
        regionId: memberRegion,
      ),
      reason: 'cash received at the door',
    ),
  );
  final AuthorizationGrant? grant = decision.grant;
  if (grant == null) {
    throw StateError(
      'fixture expected an allow but got ${decision.reason?.name}',
    );
  }
  return grant;
}

// ------------------------------------------------------------------- facts

CustodyResourceContext resourceContext({
  String resourceId = orderId,
  String shop = shopId,
}) => CustodyResourceContext(resourceId: resourceId, shopId: shop);

FinancialPolicyRef feePolicy({int version = 1}) =>
    FinancialPolicyRef(policyId: feePolicyId, version: version);

FinancialPolicyRef commissionPolicy({int version = 1}) =>
    FinancialPolicyRef(policyId: commissionPolicyId, version: version);

/// Merchandise 1200.00, delivery 60.00, commission 120.00 (in poisha).
/// COD due = 1260.00 = 126000 poisha.
OrderFinancialSnapshot snapshot({
  String resourceId = orderId,
  Money? merchandise,
  Money? delivery,
  Money? commission,
  FinancialPolicyRef? fee,
  FinancialPolicyRef? comm,
}) => OrderFinancialSnapshot(
  resourceId: resourceId,
  merchandiseSubtotal: merchandise ?? bdt(120000),
  deliveryCharge: delivery ?? bdt(6000),
  platformCommission: commission ?? bdt(12000),
  feePolicy: fee ?? feePolicy(),
  commissionPolicy: comm ?? commissionPolicy(),
);

PaymentFacts payment({
  String resourceId = orderId,
  int revision = 1,
  PaymentState state = PaymentState.due,
  Money? collected,
}) => PaymentFacts(
  resourceId: resourceId,
  paymentRevision: revision,
  state: state,
  collectedToDate: collected ?? bdt(0),
);

AttemptReturnOrderRead orderRead({
  String resourceId = orderId,
  OrderState state = OrderState.inDelivery,
  int revision = 7,
  ReservationState reservation = ReservationState.committed,
  int units = 3,
}) => AttemptReturnOrderRead(
  resourceId: resourceId,
  order: OrderLifecycleFacts(
    state: state,
    revision: revision,
    reservationState: reservation,
    reservedUnits: units,
  ),
);

DeliveryAttemptFacts attempt({
  String resourceId = orderId,
  String id = attemptId,
  int revision = 2,
  DeliveryAttemptState state = DeliveryAttemptState.outForDelivery,
}) => DeliveryAttemptFacts(
  resourceId: resourceId,
  attemptId: id,
  attemptRevision: revision,
  state: state,
);

CustodyFacts riderCustody({
  String resourceId = orderId,
  int revision = 4,
  String principalId = riderId,
  String assignmentId = riderAssignmentId,
  int generation = 1,
}) => CustodyFacts(
  resourceId: resourceId,
  custodyRevision: revision,
  holder: CustodyHolder.worker(
    kind: CustodyHolderKind.rider,
    principalId: principalId,
    assignmentId: assignmentId,
    assignmentGeneration: generation,
  ),
);

CustodyFacts shopCustody({String resourceId = orderId, int revision = 4}) =>
    CustodyFacts(
      resourceId: resourceId,
      custodyRevision: revision,
      holder: CustodyHolder.atShop(shopId: shopId),
    );

RiderAssignmentFacts riderAssignment({
  String resourceId = orderId,
  // An accepted generation-1 rider attempt has slot revision exactly 2 —
  // `reachableSlotRevisionRange` pins it.
  int slotRevision = 2,
  String assignmentId = riderAssignmentId,
  int generation = 1,
  AssignmentState state = AssignmentState.accepted,
  String assignee = riderId,
  bool accepted = true,
}) => RiderAssignmentFacts(
  resourceId: resourceId,
  slotRevision: slotRevision,
  orderState: OrderState.inDelivery,
  orderRegionId: region,
  attempt: RiderAssignmentAttempt(
    assignmentId: assignmentId,
    generation: generation,
    state: state,
    offerRecipientPrincipalId: assignee,
    acceptedAssigneePrincipalId: accepted ? assignee : null,
    timeoutPolicyRef: 'policy_rider_offer_v1',
    source: const SourcePickerBinding(
      pickerAssignmentId: pickerAssignmentId,
      pickerGeneration: 1,
      pickerPrincipalId: pickerId,
    ),
  ),
);

// ---------------------------------------------------------------- requests

CodCollectionRequest request({
  int expectedPaymentRevision = 1,
  int expectedOrderRevision = 7,
  int expectedCustodyRevision = 4,
  int expectedRiderSlotRevision = 2,
  int expectedAttemptRevision = 2,
  String assignmentId = riderAssignmentId,
  int generation = 1,
  Money? amount,
  String entryId = journalEntryId,
  String reference = journalRef,
  DateTime? at,
}) => CodCollectionRequest(
  expectedPaymentRevision: expectedPaymentRevision,
  expectedOrderRevision: expectedOrderRevision,
  expectedCustodyRevision: expectedCustodyRevision,
  expectedRiderSlotRevision: expectedRiderSlotRevision,
  expectedAttemptRevision: expectedAttemptRevision,
  assignmentId: assignmentId,
  generation: generation,
  collectedAmount: amount ?? bdt(126000),
  journalEntryId: entryId,
  journalBusinessReference: reference,
  recordedAtUtc: at ?? utcNow,
);

/// Runs the real evaluator with canonical defaults; override one piece per test.
CodCollectionOutcome collect({
  CodCollectionRequest? req,
  AuthorizationGrant? grant,
  Principal? actor,
  CustodyResourceContext? resource,
  OrderFinancialSnapshot? snap,
  PaymentFacts? pay,
  AttemptReturnOrderRead? order,
  DeliveryAttemptFacts? att,
  CustodyFacts? custody,
  RiderAssignmentFacts? rider,
  bool payPresent = true,
  bool attemptPresent = true,
  bool custodyPresent = true,
  bool riderPresent = true,
}) => evaluateReportCodCollection(
  request: req ?? request(),
  grant: grant ?? codGrant(),
  actor: actor ?? user(riderId),
  resource: resource ?? resourceContext(),
  snapshot: snap ?? snapshot(),
  payment: payPresent ? (pay ?? payment()) : null,
  orderRead: order ?? orderRead(),
  attempt: attemptPresent ? (att ?? attempt()) : null,
  custody: custodyPresent ? (custody ?? riderCustody()) : null,
  riderAssignment: riderPresent ? (rider ?? riderAssignment()) : null,
);
