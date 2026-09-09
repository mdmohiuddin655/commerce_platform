import 'package:meta/meta.dart';

/// A notification that reached the device, normalised away from any vendor
/// payload shape.
///
/// [eventId] is the **server-assigned** stable identifier. It is the only
/// thing deduplication may key on: a vendor message id changes between
/// transports and between a push copy and an inbox copy of the same event.
@immutable
class InboxEvent {
  const InboxEvent({
    required this.eventId,
    required this.kind,
    required this.serverTime,
    this.data = const <String, String>{},
  });

  /// Stable, server-assigned. Two deliveries of the same business event carry
  /// the same [eventId] regardless of which transport delivered them.
  final String eventId;

  /// Contract-defined event name (FND-003 owns the vocabulary).
  final String kind;

  /// Server time, not device time. Client clocks are not commercial truth.
  final DateTime serverTime;

  /// Small, non-authoritative payload used for routing and display only.
  final Map<String, String> data;

  @override
  bool operator ==(Object other) =>
      other is InboxEvent &&
      other.eventId == eventId &&
      other.kind == kind &&
      other.serverTime == serverTime;

  @override
  int get hashCode => Object.hash(eventId, kind, serverTime);

  @override
  String toString() => 'InboxEvent($eventId, $kind, $serverTime)';
}

/// Whether the user has granted permission to display notifications.
enum NotificationPermission { granted, denied, notDetermined, unsupported }

/// Platform-neutral notification boundary.
///
/// **Business code depends only on this.** No implementation of it may leak a
/// vendor type through this interface, so the FCM-versus-Awesome decision
/// (see `docs/decisions/ADR-0005-notification-stack-decision-required.md`)
/// can be made or reversed without touching feature code.
///
/// Three rules this interface exists to protect:
///
/// 1. A notification is a **hint**, never an authorization. Receiving one
///    never advances an order, an assignment or a custody record; the app
///    re-reads server state.
/// 2. Delivery is at-least-once and unordered. Duplicates and out-of-order
///    arrivals must be harmless — see [NotificationDeduplicator].
/// 3. The product must keep working when permission is denied or no transport
///    exists. A durable server-backed inbox, polled over the normal API, is
///    the floor; push only makes it timely.
abstract interface class NotificationService {
  /// Prepare transports available on this platform. Must be safe to call on a
  /// platform with no push transport: it configures local display and the
  /// durable inbox instead, and must not initialize an unsupported plugin.
  Future<void> initialize();

  Future<NotificationPermission> requestPermission();

  /// Current transport registration token, or null where none exists (no
  /// transport, permission denied, or not yet registered). Never fabricate a
  /// token to make a call site simpler.
  Future<String?> currentToken();

  /// Deduplicated stream of events, whatever transport delivered them.
  Stream<InboxEvent> get events;
}
