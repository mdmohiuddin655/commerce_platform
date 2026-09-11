import 'package:cp_contracts/src/cash_journal_entry.dart';
import 'package:cp_contracts/src/cod_collection_command.dart';
import 'package:cp_contracts/src/cod_collection_denial.dart';
import 'package:cp_contracts/src/payment_state.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// The payment aggregate advancing because cash was received.
@immutable
class PaymentCollectionEffect {
  const PaymentCollectionEffect({
    required this.fromState,
    required this.toState,
    required this.resultingPaymentRevision,
    required this.collectedAmount,
    required this.resultingCollectedToDate,
    required this.outstandingAfter,
  });

  final PaymentState fromState;

  /// Always `partiallyCollected` or `collected` — derived from canonical
  /// totals, never chosen by a caller.
  final PaymentState toState;

  /// Always `paymentRevision + 1`.
  final int resultingPaymentRevision;

  /// **Only what was actually received.**
  final Money collectedAmount;

  final Money resultingCollectedToDate;

  /// What the customer still owes afterwards. Zero exactly when [toState] is
  /// `collected`.
  final Money outstandingAfter;

  bool get isFullyCollected => toState == PaymentState.collected;

  @override
  String toString() =>
      'PaymentCollectionEffect(${fromState.id} -> ${toState.id}, '
      'rev=$resultingPaymentRevision, took=$collectedAmount, '
      'outstanding=$outstandingAfter)';
}

/// A permitted COD collection, fully specified across everything it touches.
///
/// Note what has **no field here and therefore cannot be expressed**: no order
/// state change, no inventory effect, no custody movement, no rider-completion
/// effect, no assignment change, no proof assessment, no remittance, no
/// settlement and no commission payout. A collection cannot produce one by
/// mistake, because there is nowhere to put it.
@immutable
class CodCollectionTransition {
  const CodCollectionTransition({
    required this.command,
    required this.resourceId,
    required this.payment,
    required this.journalEntry,
    required this.recordedAtUtc,
    required this.events,
  });

  final CodCollectionCommand command;
  final String resourceId;

  /// What happens to the payment aggregate.
  final PaymentCollectionEffect payment;

  /// **Exactly one balanced entry**, for exactly the amount received.
  final CashJournalEntry journalEntry;

  /// Server UTC of the recorded collection.
  final DateTime recordedAtUtc;

  /// Domain facts this command causes, in order. They share one
  /// `causedByCommandId` and **must commit atomically with the payment write
  /// and the journal entry** — criterion **CJ3**.
  final List<String> events;

  /// Always false. No COD collection moves goods.
  bool get changesCustody => false;

  /// Always false. **Collecting cash is not delivering**, and this contract
  /// cannot say otherwise.
  bool get changesOrder => false;

  /// Always false. Collection does not finish a rider's assignment.
  bool get completesRider => false;

  @override
  String toString() =>
      'CodCollectionTransition(${command.commandType}: $payment, '
      'journal=${journalEntry.businessReference})';
}

/// Result of evaluating one collection: exactly one of allowed or denied.
@immutable
class CodCollectionOutcome {
  const CodCollectionOutcome._(this.transition, this.denial);

  const CodCollectionOutcome.allow(CodCollectionTransition transition)
    : this._(transition, null);

  const CodCollectionOutcome.deny(CodCollectionDenial denial)
    : this._(null, denial);

  final CodCollectionTransition? transition;
  final CodCollectionDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}
