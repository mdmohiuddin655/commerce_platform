import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// One COD-collection request.
///
/// Carries **compare-and-set expectations, the amount actually received, and
/// the server-generated journal identifiers** — and nothing else. In
/// particular it carries **no target payment state** and **no journal account**:
/// a caller names an operation and reports a number; it never selects where the
/// money lands or what the payment becomes.
@immutable
class CodCollectionRequest {
  const CodCollectionRequest({
    required this.expectedPaymentRevision,
    required this.expectedOrderRevision,
    required this.expectedCustodyRevision,
    required this.expectedRiderSlotRevision,
    required this.expectedAttemptRevision,
    required this.assignmentId,
    required this.generation,
    required this.collectedAmount,
    required this.journalEntryId,
    required this.journalBusinessReference,
    required this.recordedAtUtc,
  });

  /// Payment revision the caller believes is current. **The concurrency
  /// control that stops two collections committing against one revision.**
  final int expectedPaymentRevision;

  /// Every other aggregate this operation reads is pinned too, so acting on a
  /// stale view of any of them is refused rather than silently tolerated.
  final int expectedOrderRevision;
  final int expectedCustodyRevision;
  final int expectedRiderSlotRevision;
  final int expectedAttemptRevision;

  /// The acting rider's own assignment attempt.
  final String assignmentId;

  /// That attempt's generation. A replacement attempt takes a new id **and** a
  /// new generation, so both are checked.
  final int generation;

  /// **Cash actually received.** Not the amount due, not the amount expected.
  final Money collectedAmount;

  /// Server-generated id for the journal entry this collection will produce.
  final String journalEntryId;

  /// Server-generated **unique business reference** tying that entry to this
  /// operation. A backend rejects a second entry carrying a reference it has
  /// already stored, which is what makes a retried command idempotent at the
  /// ledger — criterion **CJ4**.
  final String journalBusinessReference;

  /// Server UTC. A non-UTC value fails closed and is never converted: a
  /// local-time timestamp in stored financial history cannot be recovered,
  /// because the offset is not recorded anywhere.
  final DateTime recordedAtUtc;
}
