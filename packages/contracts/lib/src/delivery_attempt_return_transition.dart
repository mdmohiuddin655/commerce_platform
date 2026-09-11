import 'package:cp_contracts/src/delivery_attempt_command.dart';
import 'package:cp_contracts/src/delivery_attempt_return_denial.dart';
import 'package:cp_contracts/src/delivery_attempt_return_effect.dart';
import 'package:cp_contracts/src/delivery_attempt_return_facts.dart';
import 'package:cp_contracts/src/delivery_attempt_state.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:cp_contracts/src/return_command.dart';
import 'package:cp_contracts/src/return_state.dart';
import 'package:meta/meta.dart';

/// A permitted delivery-attempt transition, fully specified across every
/// aggregate it touches.
///
/// Note what is **absent and cannot be expressed**: no order-state change, no
/// rider-completion effect, no scope-projection change, no money amount. None
/// of those has a field here, so no attempt transition can produce one even by
/// mistake.
@immutable
class DeliveryAttemptTransition {
  const DeliveryAttemptTransition({
    required this.command,
    required this.attemptId,
    required this.fromState,
    required this.toState,
    required this.resultingAttemptRevision,
    required this.recordedAtUtc,
    required this.events,
    this.returnRequirement,
    this.inventoryEffect = const InventoryEffect.none(),
    this.financialClassification = FinancialClassification.noneInThisSlice,
  });

  final DeliveryAttemptCommand command;

  /// The attempt this applies to, carried through so the applied write and its
  /// events stay attributable to one attempt.
  final String attemptId;

  final DeliveryAttemptState fromState;
  final DeliveryAttemptState toState;

  /// Always `attemptRevision + 1`.
  final int resultingAttemptRevision;

  /// Server UTC of the recorded event. Validated as UTC before the transition
  /// is built; never normalised from a local time.
  final DateTime recordedAtUtc;

  /// Set **only** by a refusal: the return requirement it opens atomically.
  /// Null for going out for delivery and for a failure.
  final ReturnRequirementEffect? returnRequirement;

  /// Always `none` for every attempt transition. **Refusal restores no stock**,
  /// and neither does failure: the goods are in a rider's hands, not on a
  /// shelf. Stock can move only after shop receipt **and** inspection.
  final InventoryEffect inventoryEffect;

  /// Refusal and failure are `deferredToFinancialSlice` — **unknown, never
  /// zero**. Whether a refusal fee, a redelivery charge, a refund or any
  /// liability follows is FND-003C's, which is blocked on **O6**. Going out for
  /// delivery moves no money and never will.
  final FinancialClassification financialClassification;

  /// Every domain fact this one command causes, in order. They share one
  /// `causedByCommandId` and **must commit atomically with the state change**.
  final List<String> events;

  /// Whether custody changed. Always false — no attempt transition moves goods.
  bool get changesCustody => false;

  /// Whether the order changed. Always false.
  bool get changesOrder => false;

  @override
  String toString() =>
      'DeliveryAttemptTransition(${command.commandType}: ${fromState.id} -> '
      '${toState.id}, attemptRev=$resultingAttemptRevision, '
      'return=${returnRequirement?.toState.id ?? 'unchanged'})';
}

/// A permitted return transition, fully specified across every aggregate it
/// touches.
@immutable
class ReturnTransition {
  const ReturnTransition({
    required this.command,
    required this.fromState,
    required this.toState,
    required this.resultingReturnRevision,
    required this.recordedAtUtc,
    required this.events,
    this.custodyEffect,
    this.reservationEffect,
    this.inventoryEffect = const InventoryEffect.none(),
    this.financialClassification = FinancialClassification.noneInThisSlice,
  });

  final ReturnCommand command;
  final ReturnState fromState;
  final ReturnState toState;

  /// Always `returnRevision + 1`.
  final int resultingReturnRevision;

  /// Server UTC of the recorded event.
  final DateTime recordedAtUtc;

  /// Set **only** by the shop receipt. Null for transit, inspection and close.
  final ReturnCustodyEffect? custodyEffect;

  /// Set **only** by inspection: the committed reservation ending.
  final ReservationReturnEffect? reservationEffect;

  /// `restore(units)` **only** on an inspection recording a `restockable`
  /// disposition. `none()` everywhere else — including a damaged or quarantined
  /// inspection, where the reservation still ends but available stock does not
  /// move.
  final InventoryEffect inventoryEffect;

  /// Every return transition here is `noneInThisSlice` **for the goods'
  /// commercial consequence**, which is a deliberate and narrow claim: moving
  /// goods back and recording whether they are sellable posts to no ledger.
  ///
  /// It does **not** say the refusal that caused the return was free. That
  /// classification lives on the refusal transition, where it is
  /// `deferredToFinancialSlice`.
  final FinancialClassification financialClassification;

  final List<String> events;

  bool get changesCustody => custodyEffect != null;

  /// Whether available stock actually moves. False for damaged and quarantined.
  bool get restoresStock => inventoryEffect.availableStockDelta > 0;

  @override
  String toString() =>
      'ReturnTransition(${command.commandType}: ${fromState.id} -> '
      '${toState.id}, returnRev=$resultingReturnRevision, '
      'custody=${custodyEffect == null ? 'unchanged' : 'moved'}, '
      'stockDelta=${inventoryEffect.availableStockDelta})';
}

/// Result of evaluating one attempt request: exactly one of allowed or denied.
@immutable
class DeliveryAttemptOutcome {
  const DeliveryAttemptOutcome._(this.transition, this.denial);

  const DeliveryAttemptOutcome.allow(DeliveryAttemptTransition transition)
    : this._(transition, null);

  const DeliveryAttemptOutcome.deny(AttemptReturnDenial denial)
    : this._(null, denial);

  final DeliveryAttemptTransition? transition;
  final AttemptReturnDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Result of evaluating one return request.
@immutable
class ReturnOutcome {
  const ReturnOutcome._(this.transition, this.denial);

  const ReturnOutcome.allow(ReturnTransition transition)
    : this._(transition, null);

  const ReturnOutcome.deny(AttemptReturnDenial denial) : this._(null, denial);

  final ReturnTransition? transition;
  final AttemptReturnDenial? denial;

  bool get allowed => transition != null;

  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}

/// Result of deciding whether the attempt and return aggregates may be
/// created for a freshly dispatched order.
@immutable
class DeliveryAttemptInitialisationOutcome {
  const DeliveryAttemptInitialisationOutcome._(
    this.attempt,
    this.returnRecord,
    this.denial,
  );

  const DeliveryAttemptInitialisationOutcome.allow({
    required DeliveryAttemptFacts attempt,
    required ReturnFacts returnRecord,
  }) : this._(attempt, returnRecord, null);

  const DeliveryAttemptInitialisationOutcome.deny(AttemptReturnDenial denial)
    : this._(null, null, denial);

  /// The attempt aggregate to create, or null when refused.
  final DeliveryAttemptFacts? attempt;

  /// The return aggregate to create, or null when refused. Created in
  /// `not_required` so that "no return is needed" is a written fact rather than
  /// a missing record.
  final ReturnFacts? returnRecord;

  final AttemptReturnDenial? denial;

  bool get allowed => attempt != null;

  @override
  String toString() => allowed
      ? 'Allow(attempt=${attempt!.attemptId} ${attempt!.state.id}, '
            'return=${returnRecord!.state.id})'
      : 'Deny(${denial!.name})';
}
