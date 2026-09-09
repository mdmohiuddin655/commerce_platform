import 'package:cp_contracts/src/permission.dart';

/// Named lifecycle operations for the pre-dispatch order slice.
///
/// Every one is a **named operation**, never a status to write. There is no
/// `setOrderStatus`, no patch endpoint and no command that takes a target
/// state as an argument: the caller asks to *do* something and the evaluator
/// decides whether the current state permits it.
///
/// [commandType] matches the envelope's `commandType` grammar
/// (dot-separated lower_snake), and [requiredPermission] is what the **trusted
/// backend router** must select before authorizing. A client never supplies
/// either — see `docs/contracts/authorization-invariants.md`.
enum LifecycleCommand {
  /// Customer's quote-confirmed checkout.
  placeOrder('order.place', Permission.customerSubmitCheckout),

  /// Shop agent accepts the order.
  acceptOrder('order.accept', Permission.agentAcceptOrder),

  /// Shop agent refuses the order. The permission requires a stored reason.
  rejectOrder('order.reject', Permission.agentRejectOrder),

  /// Shop begins assembling goods.
  startPreparing('order.start_preparing', Permission.agentRecordShopFulfillment),

  /// Goods assembled and awaiting collection.
  markReady('order.mark_ready', Permission.agentRecordShopFulfillment),

  /// Customer asks to cancel. The permission is named *request* deliberately:
  /// the lifecycle, not the client, decides whether cancellation is currently
  /// permitted.
  cancelOrder('order.cancel', Permission.customerRequestCancellation),

  /// **Trusted worker transition — not a client command.**
  ///
  /// [requiredPermission] is null on purpose. Expiry is performed by a
  /// server-side worker, and `evaluateAuthorization` denies a
  /// `PrincipalKind.systemWorker` every human-role permission. A worker
  /// therefore cannot and must not borrow one; it runs its own audited path.
  ///
  /// This is also **not** a TTL deletion, a mobile timer or a notification.
  /// See `docs/contracts/order-reservation-lifecycle.md`.
  expireReservation('reservation.expire', null);

  const LifecycleCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require, or null for a
  /// worker-driven transition that no human role may invoke.
  final Permission? requiredPermission;

  /// True when this transition is driven by a trusted server worker rather
  /// than an authenticated human.
  bool get isWorkerDriven => requiredPermission == null;

  static LifecycleCommand? byCommandType(String commandType) {
    for (final LifecycleCommand c in LifecycleCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical lifecycle event identifiers emitted by this slice.
///
/// These are **facts the server recorded**. Receiving one authorizes nothing;
/// a client re-reads server state. Event ids are server-assigned and are never
/// a transport message id — see `EventEnvelope`.
///
/// Payloads carry routing identifiers only. No customer address, contact
/// detail, order contents or amount belongs in a lifecycle event payload,
/// because a copy may travel through a push transport.
class LifecycleEventType {
  const LifecycleEventType._();

  static const String orderPlaced = 'order.placed';
  static const String orderAccepted = 'order.accepted';
  static const String orderRejected = 'order.rejected';
  static const String orderPreparing = 'order.preparing';
  static const String orderReady = 'order.ready';
  static const String orderCancelled = 'order.cancelled';
  static const String reservationExpired = 'reservation.expired';

  static const List<String> all = <String>[
    orderPlaced,
    orderAccepted,
    orderRejected,
    orderPreparing,
    orderReady,
    orderCancelled,
    reservationExpired,
  ];
}
