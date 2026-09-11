import 'package:cp_contracts/src/delivery_attempt_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/order_lifecycle.dart';
import 'package:cp_contracts/src/return_state.dart';
import 'package:meta/meta.dart';

/// The delivery-attempt aggregate for one order, as loaded from storage.
///
/// Its [attemptRevision] is **its own** concurrency control, independent of the
/// order revision, the custody revision, the rider `slotRevision` and the
/// return revision. Five aggregates change at different rates; sharing one
/// counter would make every unrelated write look like a conflict and a genuine
/// conflict undetectable.
@immutable
class DeliveryAttemptFacts {
  const DeliveryAttemptFacts({
    required this.resourceId,
    required this.attemptId,
    required this.attemptRevision,
    required this.state,
  });

  /// The canonical first attempt for an order that has just been dispatched.
  ///
  /// **A shape, not authority.** Creating one is gated by
  /// `initialiseDeliveryAttempt`, which refuses when an attempt already
  /// exists. Revision starts at 1, following the repository convention that a
  /// written aggregate begins at 1 and that revision 0 means "never written".
  factory DeliveryAttemptFacts.initial({
    required String resourceId,
    required String attemptId,
  }) => DeliveryAttemptFacts(
    resourceId: resourceId,
    attemptId: attemptId,
    attemptRevision: 1,
    state: DeliveryAttemptState.pending,
  );

  /// The order this attempt belongs to.
  final String resourceId;

  /// Opaque, server-generated, stable for the life of this attempt.
  ///
  /// **Never a sequential counter** — the same rule every other identifier in
  /// this repository follows. It is what lets an event, an audit row or a
  /// future dispute point at *this* attempt rather than "the attempt the order
  /// has now".
  final String attemptId;

  /// Increments on **every** applied attempt mutation.
  final int attemptRevision;

  final DeliveryAttemptState state;

  bool get isPending => state == DeliveryAttemptState.pending;
  bool get isOutForDelivery => state == DeliveryAttemptState.outForDelivery;
  bool get isRefused => state == DeliveryAttemptState.refused;
  bool get isFailed => state == DeliveryAttemptState.failed;
}

/// The return aggregate for one order, as loaded from storage.
///
/// Written alongside the first attempt in `not_required`, so that "no return is
/// needed" is a **recorded fact** rather than the absence of a record. Absence
/// means the aggregate was never written or was not loaded, and this contract
/// never converts absence into a state.
@immutable
class ReturnFacts {
  const ReturnFacts({
    required this.resourceId,
    required this.returnRevision,
    required this.state,
    required this.route,
    this.disposition,
  });

  /// The canonical starting return record for a dispatched order.
  factory ReturnFacts.initial({required String resourceId}) => ReturnFacts(
    resourceId: resourceId,
    returnRevision: 1,
    state: ReturnState.notRequired,
    route: ReturnRoute.riderToShop,
  );

  /// The order this return belongs to.
  final String resourceId;

  /// Increments on **every** applied return mutation. Independent of the
  /// attempt revision.
  final int returnRevision;

  final ReturnState state;

  /// Route the goods travel. Only `riderToShop` is executable here; a stored
  /// aggregate naming another route fails closed rather than being run as if
  /// it were the direct one.
  final ReturnRoute route;

  /// Recorded exactly once, by inspection. Null before that.
  ///
  /// **Inventory disposition only** — it says whether the units may be sold
  /// again, and deliberately cannot express fault, liability, refund,
  /// compensation or fee.
  final ReturnDisposition? disposition;

  bool get isRequired => state == ReturnState.required;
  bool get isInTransit => state == ReturnState.inTransit;
  bool get isReceived => state == ReturnState.received;
  bool get isInspected => state == ReturnState.inspected;
  bool get isClosed => state == ReturnState.closed;
}

/// An `OrderLifecycleFacts` read that is **bound to a resource**.
///
/// ## Why this wrapper exists
///
/// `OrderLifecycleFacts` carries lifecycle state and nothing else — no
/// `resourceId`. That is correct for what it is, and it means a caller handing
/// an evaluator "the order" cannot prove *which* order it is. Two orders in the
/// same shop, both `in_delivery` with a `committed` reservation for the same
/// unit count, produce byte-identical facts.
///
/// FND-003D2B-FIX-003 hit exactly this and closed it with a resource-bound
/// wrapper; this is the same fix applied before the same defect can be shipped
/// again. Every other member of an operation's read-set already names its
/// resource, so the order was the one hole through which a cross-resource read
/// could pass.
@immutable
class AttemptReturnOrderRead {
  const AttemptReturnOrderRead({required this.resourceId, required this.order});

  /// The order these facts were loaded for. Supplied by the backend from the
  /// same read-set, not by a caller payload.
  final String resourceId;

  final OrderLifecycleFacts order;

  /// Whether the read itself is usable at all.
  bool get isWellFormed => isValidOpaqueId(resourceId);

  /// Whether this read is about exactly [resourceId].
  ///
  /// Both sides are validated, then compared **exactly**. A malformed id on
  /// either side can never match, so a broken read cannot pass by being equal
  /// to another broken read.
  bool belongsToResource(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  @override
  String toString() => isWellFormed
      ? 'AttemptReturnOrderRead($resourceId, ${order.state?.id ?? 'absent'})'
      : 'AttemptReturnOrderRead(invalid)';
}
