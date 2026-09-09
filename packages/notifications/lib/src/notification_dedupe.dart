import 'package:cp_notifications/src/notification_service.dart';

/// Collapses repeated deliveries of the same business event.
///
/// The delivery contract this implements:
///
/// - **Stable eventId.** The server assigns it; every transport carries it.
/// - **One durable inbox entry per eventId.** A push copy and a polled copy of
///   the same event are the same entry, not two.
/// - **Duplicates are harmless.** Accepting the same eventId twice is a no-op,
///   so an at-least-once transport is safe.
/// - **Reordering is harmless.** Nothing here depends on arrival order,
///   because presentation never drives state — the server does.
///
/// Memory is bounded: only the most recent [capacity] ids are remembered.
/// Beyond that window a duplicate could be re-presented, which is a cosmetic
/// fault, never a correctness one — state still comes from the server.
class NotificationDeduplicator {
  NotificationDeduplicator({this.capacity = 512})
    : assert(capacity > 0, 'capacity must be positive');

  final int capacity;

  /// Insertion-ordered; oldest evicted first. `Set<String>` in Dart preserves
  /// insertion order, which is what makes the eviction below well defined.
  final Set<String> _seen = <String>{};

  /// Returns true if this is the first time [event]'s id has been seen, and
  /// records it. Returns false for a duplicate, which the caller drops.
  bool accept(InboxEvent event) {
    if (_seen.contains(event.eventId)) {
      return false;
    }
    _seen.add(event.eventId);
    if (_seen.length > capacity) {
      _seen.remove(_seen.first);
    }
    return true;
  }

  bool hasSeen(String eventId) => _seen.contains(eventId);

  int get trackedCount => _seen.length;

  void reset() => _seen.clear();
}
