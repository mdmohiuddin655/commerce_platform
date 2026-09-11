import 'package:cp_contracts/src/return_state.dart';
import 'package:meta/meta.dart';

/// Compare-and-set expectations shared by every attempt operation.
///
/// Each expectation is the caller's belief about **one** aggregate's current
/// revision. They are separate fields, never one number, because the attempt,
/// the order, custody and the rider slot advance at different rates: sharing a
/// counter would report a conflict for every unrelated write and hide the real
/// one.
@immutable
class DeliveryAttemptRequest {
  const DeliveryAttemptRequest({
    required this.expectedAttemptRevision,
    required this.expectedOrderRevision,
    required this.expectedCustodyRevision,
    required this.expectedRiderSlotRevision,
    required this.assignmentId,
    required this.generation,
    required this.recordedAtUtc,
  });

  final int expectedAttemptRevision;
  final int expectedOrderRevision;
  final int expectedCustodyRevision;

  /// The rider slot is read by every attempt operation — the acting rider must
  /// still be the accepted one — so every attempt operation pins it.
  final int expectedRiderSlotRevision;

  /// The acting rider's own assignment attempt.
  final String assignmentId;

  /// That attempt's generation. A replacement attempt takes a new id **and** a
  /// new generation, so both are checked.
  final int generation;

  /// Server UTC. A non-UTC value fails closed and is never converted: a
  /// local-time timestamp written into stored history cannot be recovered
  /// later, because the offset is not recorded anywhere.
  final DateTime recordedAtUtc;
}

/// A refusal, which additionally pins the **return** aggregate.
///
/// Separate from [DeliveryAttemptRequest] because refusal is the one attempt
/// operation that writes the return, and it must compare-and-set what it
/// writes. Going out for delivery and failing do not carry this field at all,
/// so neither can move the return even by mistake.
@immutable
class DeliveryAttemptRefusalRequest {
  const DeliveryAttemptRefusalRequest({
    required this.attempt,
    required this.expectedReturnRevision,
  });

  final DeliveryAttemptRequest attempt;

  /// Return revision the caller believes is current.
  final int expectedReturnRevision;
}

/// `required -> in_transit`. Reads and writes the return only.
@immutable
class ReturnBeginTransitRequest {
  const ReturnBeginTransitRequest({
    required this.expectedReturnRevision,
    required this.expectedOrderRevision,
    required this.recordedAtUtc,
  });

  final int expectedReturnRevision;
  final int expectedOrderRevision;
  final DateTime recordedAtUtc;
}

/// `in_transit -> received`, moving custody `rider -> shop`.
@immutable
class ReturnShopReceiptRequest {
  const ReturnShopReceiptRequest({
    required this.expectedReturnRevision,
    required this.expectedOrderRevision,
    required this.expectedCustodyRevision,
    required this.expectedRiderSlotRevision,
    required this.recordedAtUtc,
  });

  final int expectedReturnRevision;
  final int expectedOrderRevision;

  /// Custody is written by this operation, so it is pinned.
  final int expectedCustodyRevision;

  /// The rider slot is read — custody must still be bound to the **currently
  /// accepted** rider attempt — so it is pinned too.
  final int expectedRiderSlotRevision;

  final DateTime recordedAtUtc;
}

/// `received -> inspected`, ending the reservation and possibly restoring
/// stock.
@immutable
class ReturnInspectionRequest {
  const ReturnInspectionRequest({
    required this.expectedReturnRevision,
    required this.expectedOrderRevision,
    required this.disposition,
    required this.recordedAtUtc,
  });

  final int expectedReturnRevision;

  /// The order aggregate carries the reservation this operation terminates, so
  /// it is pinned.
  final int expectedOrderRevision;

  /// Exactly one inventory disposition. **Required, with no default** — a
  /// defaulted disposition would decide the stock consequence by omission, and
  /// the safe-looking default (`restockable`) is the dangerous one.
  final ReturnDisposition disposition;

  final DateTime recordedAtUtc;
}

/// `inspected -> closed`. Audit only.
@immutable
class ReturnCloseRequest {
  const ReturnCloseRequest({
    required this.expectedReturnRevision,
    required this.expectedOrderRevision,
    required this.recordedAtUtc,
  });

  final int expectedReturnRevision;
  final int expectedOrderRevision;
  final DateTime recordedAtUtc;
}
