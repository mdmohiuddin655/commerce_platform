import 'package:cp_contracts/src/order_state.dart';
import 'package:meta/meta.dart';

/// What a custody transition does to the **order aggregate**.
///
/// Typed rather than described in prose, so a backend applies a value instead
/// of re-deriving intent from a comment — and so a test can assert that shop
/// pickup leaves the order exactly where it was.
///
/// Custody transitions are the *only* thing in this contract that may move an
/// order into `in_delivery`. The pre-dispatch evaluator does not know that edge
/// and must never invent it.
@immutable
class CustodyOrderEffect {
  const CustodyOrderEffect._(this.toState, this.resultingOrderRevision);

  /// The order is untouched: same state, same revision.
  ///
  /// Shop pickup carries this. Physical possession changed hands, but the shop
  /// has still not dispatched, so the order stays `ready`.
  const CustodyOrderEffect.unchanged() : this._(null, null);

  /// The order advances, and its revision advances with it.
  const CustodyOrderEffect.transition({
    required OrderState toState,
    required int resultingOrderRevision,
  }) : this._(toState, resultingOrderRevision);

  /// Null when the order does not change.
  final OrderState? toState;

  /// Null when the order does not change.
  final int? resultingOrderRevision;

  bool get changesOrder => toState != null;

  @override
  String toString() => changesOrder
      ? 'CustodyOrderEffect(-> ${toState!.id} @rev $resultingOrderRevision)'
      : 'CustodyOrderEffect(unchanged)';
}

/// The picker assignment finishing as a **consequence** of custody reaching
/// the rider.
///
/// There is deliberately no `completePickerAssignment` command. Completion is
/// not a target state a client may select; it is what it *means* for the goods
/// to have left the picker's hands. Modelling it as a command would create
/// exactly the arbitrary status-patch this contract forbids.
///
/// The attempt's identities are carried through unchanged so a backend applies
/// them rather than re-deriving them: a completed attempt stays attributable.
@immutable
class PickerAssignmentCompletionEffect {
  const PickerAssignmentCompletionEffect({
    required this.assignmentId,
    required this.generation,
    required this.resultingSlotRevision,
    required this.offerRecipientPrincipalId,
    required this.acceptedAssigneePrincipalId,
  });

  final String assignmentId;
  final int generation;

  /// The picker slot's own revision, advanced by exactly one. Independent of
  /// the order revision, the rider slot revision and the custody revision.
  final int resultingSlotRevision;

  /// Retained history — never erased by completion.
  final String offerRecipientPrincipalId;

  /// Retained history — never erased by completion.
  final String acceptedAssigneePrincipalId;

  @override
  String toString() =>
      'PickerAssignmentCompletionEffect($assignmentId, gen=$generation, '
      'rev=$resultingSlotRevision, by=$acceptedAssigneePrincipalId)';
}
