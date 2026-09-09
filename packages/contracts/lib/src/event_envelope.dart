import 'package:cp_contracts/src/contract_version.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// A fact the server recorded. Consumed by clients, the outbox drain, the
/// durable inbox and later audit.
///
/// ## The event id is the server's, not the transport's
///
/// [eventId] is assigned by the server inside the same transaction that
/// produced the fact. It is **never** an FCM message id, an APNs id, a push
/// payload key or any other transport identifier. Transport ids change per
/// delivery, differ between a push copy and a polled copy of the same fact,
/// and are absent entirely when a fact is read from the API — using one as the
/// business id would make deduplication silently fail.
///
/// There is no `transportMessageId` field here, by design. A transport adapter
/// maps its own id to this one; it never substitutes it. Transport ids also
/// fail [validateOpaqueId], so one cannot be passed in by accident.
///
/// ## An event is a hint, never an authorization
///
/// Receiving an event — by push or by poll — advances nothing on its own. A
/// client re-reads server state; the server alone decides transitions. This
/// keeps at-least-once, out-of-order delivery harmless.
@immutable
class EventEnvelope {
  const EventEnvelope._({
    required this.eventId,
    required this.eventType,
    required this.resourceId,
    required this.serverTimeUtc,
    required this.resourceRevision,
    required this.causedByCommandId,
    required this.payload,
    required this.contractVersion,
  });

  static Result<EventEnvelope> create({
    required String eventId,
    required String eventType,
    required String resourceId,
    required DateTime serverTimeUtc,
    int? resourceRevision,
    String? causedByCommandId,
    Map<String, Object?> payload = const <String, Object?>{},
    ContractVersion contractVersion = ContractVersion.current,
  }) {
    final IdRejection? eventIdIssue = validateOpaqueId(eventId);
    if (eventIdIssue != null) {
      return Result<EventEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'eventId is not a valid opaque id: ${eventIdIssue.name}. A '
          'transport message id is not a business event id.',
          code: 'EVENT_ID_INVALID',
        ),
      );
    }
    final IdRejection? resourceIdIssue = validateOpaqueId(resourceId);
    if (resourceIdIssue != null) {
      return Result<EventEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'resourceId is not a valid opaque id: ${resourceIdIssue.name}',
          code: 'EVENT_RESOURCE_ID_INVALID',
        ),
      );
    }
    if (!serverTimeUtc.isUtc) {
      return Result<EventEnvelope>.err(
        const Failure(
          FailureKind.rejectedByPolicy,
          'serverTimeUtc must be UTC; a local-zone timestamp is ambiguous',
          code: 'EVENT_TIME_NOT_UTC',
        ),
      );
    }
    if (resourceRevision != null && resourceRevision < 0) {
      return Result<EventEnvelope>.err(
        const Failure(
          FailureKind.rejectedByPolicy,
          'resourceRevision must be >= 0 when present',
          code: 'EVENT_REVISION_INVALID',
        ),
      );
    }
    if (causedByCommandId != null && !isValidOpaqueId(causedByCommandId)) {
      return Result<EventEnvelope>.err(
        const Failure(
          FailureKind.rejectedByPolicy,
          'causedByCommandId must be a valid opaque command id when present',
          code: 'EVENT_CAUSE_INVALID',
        ),
      );
    }
    return Result<EventEnvelope>.ok(
      EventEnvelope._(
        eventId: eventId,
        eventType: eventType,
        resourceId: resourceId,
        serverTimeUtc: serverTimeUtc,
        resourceRevision: resourceRevision,
        causedByCommandId: causedByCommandId,
        payload: Map<String, Object?>.unmodifiable(payload),
        contractVersion: contractVersion,
      ),
    );
  }

  /// Stable, server-assigned, opaque. The **only** deduplication key.
  final String eventId;

  /// Named fact, e.g. `order.accepted`.
  final String eventType;

  final String resourceId;

  /// Revision the resource reached because of this event. Null for events that
  /// do not advance a revision.
  final int? resourceRevision;

  /// Command that caused this event, when one did. Null for events raised by a
  /// trusted worker such as reservation expiry.
  final String? causedByCommandId;

  /// **Server** time. Client wall-clock time is never commercial truth.
  final DateTime serverTimeUtc;

  /// Small, routing-and-display-only payload. Must not carry more personal
  /// data than the recipient already has the right to see, because a copy of
  /// this may travel through a push transport.
  final Map<String, Object?> payload;

  final ContractVersion contractVersion;

  @override
  bool operator ==(Object other) =>
      other is EventEnvelope && other.eventId == eventId;

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() => 'EventEnvelope($eventType, id=$eventId, '
      'res=$resourceId, rev=$resourceRevision, $serverTimeUtc)';
}
