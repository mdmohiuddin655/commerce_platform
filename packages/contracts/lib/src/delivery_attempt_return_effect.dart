import 'package:cp_contracts/src/custody_state.dart';
import 'package:cp_contracts/src/reservation_state.dart';
import 'package:cp_contracts/src/return_state.dart';
import 'package:meta/meta.dart';

/// A refusal opening the return requirement, as a **typed consequence**.
///
/// There is deliberately no `openReturn` command. Requiring a return is not a
/// target state a caller may select; it is what it *means* for a customer to
/// have refused goods a rider is already carrying. Modelling it as its own
/// command would allow a return to be required without a refusal, and a refusal
/// to happen without a return — the two halves this slice exists to keep
/// atomic.
@immutable
class ReturnRequirementEffect {
  const ReturnRequirementEffect({
    required this.fromState,
    required this.resultingReturnRevision,
    required this.route,
  });

  /// Always `ReturnState.notRequired` in this slice.
  final ReturnState fromState;

  /// The return's own revision, advanced by exactly one. Independent of the
  /// attempt, order, custody and rider-slot revisions.
  final int resultingReturnRevision;

  /// The route the goods will travel. Always `riderToShop` here.
  final ReturnRoute route;

  /// The state a return is opened into.
  ReturnState get toState => ReturnState.required;

  @override
  String toString() =>
      'ReturnRequirementEffect(${fromState.id} -> ${toState.id}, '
      'rev=$resultingReturnRevision, route=${route.id})';
}

/// Custody changing hands as part of a return.
///
/// Only the shop receipt carries one. Beginning transit does **not**: the rider
/// already holds the goods and keeps holding them, and a state change is not a
/// physical one.
@immutable
class ReturnCustodyEffect {
  const ReturnCustodyEffect({
    required this.fromHolder,
    required this.toHolder,
    required this.resultingCustodyRevision,
  });

  final CustodyHolder fromHolder;
  final CustodyHolder toHolder;

  /// Always `custodyRevision + 1` — **exactly once** per applied receipt.
  final int resultingCustodyRevision;

  @override
  String toString() =>
      'ReturnCustodyEffect(${fromHolder.kind.id} -> ${toHolder.kind.id}, '
      'custodyRev=$resultingCustodyRevision)';
}

/// The committed reservation ending because inspected goods are back.
///
/// Terminates into [ReservationState.returned] — **never** `released`. Those
/// are different claims: `released` promises the units went back to available
/// stock, and a damaged or quarantined return makes no such promise. The stock
/// consequence travels separately, in the transition's `InventoryEffect`, so no
/// reader has to infer it from a state name.
@immutable
class ReservationReturnEffect {
  const ReservationReturnEffect({
    required this.fromState,
    required this.disposition,
    required this.units,
  });

  /// Always `ReservationState.committed`.
  final ReservationState fromState;

  /// What inspection concluded about the goods. Inventory only.
  final ReturnDisposition disposition;

  /// Whole units the reservation held.
  final int units;

  /// The terminal state the reservation ends in.
  ReservationState get toState => ReservationState.returned;

  /// Whether these units go back to available stock. The single place that
  /// question is answered, delegated to the disposition itself.
  bool get restoresAvailableStock => disposition.restoresAvailableStock;

  @override
  String toString() =>
      'ReservationReturnEffect(${fromState.id} -> ${toState.id}, '
      '${disposition.id}, units=$units, restores=$restoresAvailableStock)';
}
