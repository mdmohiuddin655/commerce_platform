// Shared fixtures for the FND-003B3B delivery-attempt and return contract.
//
// Every allow-path test travels the **real** authorization path: an
// `AuthorizationGrant` is `final` with a library-private constructor and can
// only come from a successful `evaluateAuthorization`, so a test can no more
// fabricate one than production can.
import 'package:cp_contracts/cp_contracts.dart';

// ------------------------------------------------------------------ identities
const String orderId = 'ord_B3B7xKq2mW9tLp4Z';
const String otherOrderId = 'ord_B3Bz91QQ0plW7rTt';
const String shopId = 'shop_alpha';
const String otherShopId = 'shop_bravo';
const String region = 'dhaka_north';

const String riderId = 'usr_rider3B7xKq2mW9t';
const String otherRiderId = 'usr_rider9Zz81QQ0plW';
const String agentId = 'usr_agent3B7xKq2mW9t';
const String adminId = 'usr_admin3B7xKq2mW9t';
const String pickerId = 'usr_pick3B7xKq2mW9tL';

const String attemptId = 'att_B3B7xKq2mW9tLp4Z';
const String riderAssignmentId = 'rasg_B3B7xKq2mW9tLp4';
const String pickerAssignmentId = 'pasg_B3B7xKq2mW9tLp4';

/// A server UTC timestamp. Tests that need a non-UTC one build it explicitly.
final DateTime utcNow = DateTime.utc(2026, 9, 11, 10, 30);

Principal user(String id) => Principal.fromVerifiedSubject(id);

/// A trusted worker. **Never** a valid actor for these operations: every one
/// records a human physical assertion.
Principal worker([String id = 'wrk_B3B7xKq2mW9tLp4Z']) =>
    Principal.systemWorker(id);

// -------------------------------------------------------------------- grants

/// A real grant, or a failure naming why the fixture could not produce one — a
/// silently-null grant would make a test pass for the wrong reason.
AuthorizationGrant attemptReturnGrant({
  required Permission permission,
  required String principalId,
  required CommerceRole role,
  String resourceId = orderId,
  String resourceShopId = shopId,
  String memberRegion = region,
  String resourceRegion = region,
  MembershipStatus status = MembershipStatus.active,
  String? reason = 'customer refused at the door',
  Set<String> assigned = const <String>{},

  /// Shops the membership may act for. Empty means **no** shop authority,
  /// never all shops — which is what an agent receipt grant needs populated.
  Set<String> memberShops = const <String>{},
}) {
  final AuthorizationDecision decision = evaluateAuthorization(
    AuthorizationRequest(
      permission: permission,
      scope: ResourceScope(
        resourceId: resourceId,
        ownerPrincipalId: 'usr_owner3B7xKq2mW9tL',
        shopId: resourceShopId,
        regionId: resourceRegion,
        assignedPrincipalIds: assigned,
      ),
      principal: Principal.fromVerifiedSubject(principalId),
      membership: Membership(
        principalId: principalId,
        role: role,
        status: status,
        regionId: memberRegion,
        shopIds: memberShops,
      ),
      reason: reason,
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

/// The accepted rider's grant for recording a delivery attempt.
AuthorizationGrant riderAttemptGrant({
  String principalId = riderId,
  String resourceId = orderId,
}) => attemptReturnGrant(
  permission: Permission.riderRecordDeliveryAttempt,
  principalId: principalId,
  role: CommerceRole.rider,
  resourceId: resourceId,
  assigned: <String>{principalId},
);

/// An in-region active administrator's grant for return administration.
AuthorizationGrant adminReturnGrant({
  String principalId = adminId,
  String resourceId = orderId,
}) => attemptReturnGrant(
  permission: Permission.adminAdministerReturn,
  principalId: principalId,
  role: CommerceRole.admin,
  resourceId: resourceId,
);

/// The shop agent's grant for recording receipt of returned goods.
AuthorizationGrant agentReceiptGrant({
  String principalId = agentId,
  String resourceId = orderId,
  String resourceShopId = shopId,
}) => attemptReturnGrant(
  permission: Permission.agentRecordReturnReceipt,
  principalId: principalId,
  role: CommerceRole.agent,
  resourceId: resourceId,
  resourceShopId: resourceShopId,
  memberShops: <String>{resourceShopId},
);

// --------------------------------------------------------------------- facts

CustodyResourceContext resourceContext({
  String resourceId = orderId,
  String shop = shopId,
}) => CustodyResourceContext(resourceId: resourceId, shopId: shop);

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

CustodyFacts shopCustody({
  String resourceId = orderId,
  int revision = 5,
  String shop = shopId,
}) => CustodyFacts(
  resourceId: resourceId,
  custodyRevision: revision,
  holder: CustodyHolder.atShop(shopId: shop),
);

RiderAssignmentFacts riderAssignment({
  String resourceId = orderId,
  // An accepted generation-1 rider attempt has slot revision exactly 2 —
  // `reachableSlotRevisionRange` pins it, so a fixture cannot invent a history
  // the lifecycle could not have produced.
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

DeliveryAttemptFacts attempt({
  String resourceId = orderId,
  String id = attemptId,
  int revision = 1,
  DeliveryAttemptState state = DeliveryAttemptState.pending,
}) => DeliveryAttemptFacts(
  resourceId: resourceId,
  attemptId: id,
  attemptRevision: revision,
  state: state,
);

ReturnFacts returnRecord({
  String resourceId = orderId,
  int revision = 1,
  ReturnState state = ReturnState.notRequired,
  ReturnRoute route = ReturnRoute.riderToShop,
  ReturnDisposition? disposition,
}) => ReturnFacts(
  resourceId: resourceId,
  returnRevision: revision,
  state: state,
  route: route,
  disposition: disposition,
);

// ------------------------------------------------------------------ requests

DeliveryAttemptRequest attemptRequest({
  int expectedAttemptRevision = 1,
  int expectedOrderRevision = 7,
  int expectedCustodyRevision = 4,
  int expectedRiderSlotRevision = 2,
  String assignmentId = riderAssignmentId,
  int generation = 1,
  DateTime? at,
}) => DeliveryAttemptRequest(
  expectedAttemptRevision: expectedAttemptRevision,
  expectedOrderRevision: expectedOrderRevision,
  expectedCustodyRevision: expectedCustodyRevision,
  expectedRiderSlotRevision: expectedRiderSlotRevision,
  assignmentId: assignmentId,
  generation: generation,
  recordedAtUtc: at ?? utcNow,
);
