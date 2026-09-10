import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_command.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_denial.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_state.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:meta/meta.dart';

/// A permitted dispute operation: the record to store, and nothing else.
///
/// **Every commercial effect is NONE, structurally.** There is no order effect
/// field, no custody effect field, no assignment effect field and **no
/// assessment field** on this class, so a transition that moves any of them
/// *cannot be constructed*. That is a stronger statement than a runtime check,
/// and it is why they are getters returning constants rather than constructor
/// parameters.
///
/// A dispute therefore does **not**: move `in_delivery → delivered`, move rider
/// custody to the customer, complete the rider assignment, restore inventory,
/// start or route a return, settle COD, charge a fee, issue a refund or
/// compensation, assign liability, or change, relabel or supersede any
/// delivery-proof assessment.
///
/// **Nor is the reverse true.** Raising a dispute is not a finding against
/// anyone, and recording that review started is not a finding either. Whatever
/// an eventual resolution slice decides, **nothing in this contract may be read
/// as permission to deliver, to transfer custody, to complete an assignment, to
/// restore stock or to move money.**
@immutable
class DeliveryProofDisputeTransition {
  /// The record and the operation that produced it are the **only** inputs.
  ///
  /// [events] is deliberately not a parameter, applying FND-003D2A-FIX-001's
  /// correction from the start: a caller-supplied event list would let a
  /// transition carry arbitrary, extra or fabricated event ids — a
  /// `delivery.proof_dispute_resolved` that no vocabulary defines, say. The
  /// contract says which events each operation emits, so that is a property of
  /// the type rather than a value a caller supplies.
  const DeliveryProofDisputeTransition({
    required this.record,
    required this.command,
  });

  /// The dispute record to store. Its own revision is the aggregate's resulting
  /// revision.
  final DeliveryProofDisputeRecord record;

  /// The named operation applied. Never a target state a caller selected.
  final DeliveryProofDisputeCommand command;

  /// Every domain fact this operation causes, in order. **Fixed per operation
  /// and not selectable by any caller.**
  ///
  /// `const`, so each returned list is deeply immutable: an attempt to add to
  /// one throws `UnsupportedError` rather than silently extending the
  /// vocabulary.
  ///
  /// Events **must commit atomically with** the dispute record and the dedupe
  /// result — criterion **DPD6**. Notification delivery is not part of that
  /// transaction: a push is a hint, never authorization, proof or an outcome,
  /// and it may simply be missed.
  List<String> get events => switch (command) {
    DeliveryProofDisputeCommand.raise => const <String>[
      DeliveryProofDisputeEventType.disputeRaised,
    ],
    DeliveryProofDisputeCommand.recordReviewStarted => const <String>[
      DeliveryProofDisputeEventType.disputeReviewStarted,
    ],
    // Unreachable: the evaluator refuses `resolve` before reading any fact, so
    // no transition is ever produced for it. There is deliberately no
    // resolution event to return — inventing one would name an outcome no slice
    // has defined.
    DeliveryProofDisputeCommand.resolve => const <String>[],
  };

  /// Always the previous revision + 1.
  int get resultingDisputeRevision => record.disputeRevision;

  /// The handling state the dispute is now in. **Never an outcome.**
  DeliveryProofDisputeState get resultingState => record.state;

  /// Whether this operation created the dispute rather than advancing one.
  bool get isRaise => command == DeliveryProofDisputeCommand.raise;

  /// A dispute never touches stock. Contesting a proof situation creates and
  /// destroys no units, and **no failed, refused or disputed delivery restores
  /// stock**: `CONSTRAINTS.md` invariant 12 stands, and units cannot become
  /// available again until the return lifecycle proves shop receipt **and**
  /// inspection.
  InventoryEffect get inventoryEffect => const InventoryEffect.none();

  /// Recording a dispute posts no money.
  ///
  /// **This classifies the recording, not the consequence.** Whether a dispute
  /// — or the `notSatisfied` assessment underneath one — eventually has a
  /// financial consequence in the form of a fee, a refund, compensation, a
  /// liability or a settlement effect is **UNKNOWN and deferred to FND-003C**,
  /// itself blocked on owner decision **O6**. It must never be read as zero,
  /// and nothing here permits deriving an amount. `CONSTRAINTS.md` invariant 11
  /// stands: delivery failure does not automatically justify a customer fee,
  /// and nonpayment must remain representable.
  FinancialClassification get financialClassification =>
      FinancialClassification.noneInThisSlice;

  /// A dispute grants no authorization projection change. **Being in dispute is
  /// not permission**, in either direction — it opens no new read access, and
  /// it withdraws none.
  ScopeProjectionEffect get scopeEffect => const ScopeProjectionEffect.none();

  /// The order is untouched — no state, no revision.
  bool get changesOrderState => false;

  /// Custody is untouched. A dispute does not move goods.
  bool get changesCustody => false;

  /// The rider assignment is untouched. Rider `AssignmentState.completed`
  /// remains unreachable and no revision cost for it was invented — criterion
  /// **B3-C2**, FUTURE.
  bool get changesRiderAssignment => false;

  /// **The delivery-proof assessment is untouched.**
  ///
  /// A dispute never mutates, relabels, erases, supersedes or reassesses the
  /// record it points at. ADR-0009's append-only history is what makes the
  /// dispute basis meaningful in the first place; a dispute that could edit its
  /// own basis would destroy exactly the audit trail it exists to rely on.
  bool get changesAssessment => false;

  /// A **debug representation, and never a validity claim.**
  ///
  /// A transition wrapping a malformed record renders nothing of it. The
  /// record's own `toString` is already fail safe, and this method additionally
  /// refuses to emit the derived revision or state, so no untrusted fragment
  /// escapes through the wrapper either.
  @override
  String toString() => record.isWellFormed
      ? 'DeliveryProofDisputeTransition(${command.name}, '
            '${record.state.id}, rev=$resultingDisputeRevision, '
            'id=${record.disputeId})'
      : 'DeliveryProofDisputeTransition(invalid)';
}

/// Result of evaluating one dispute request: exactly one of allowed or denied.
@immutable
class DeliveryProofDisputeOutcome {
  const DeliveryProofDisputeOutcome._(this.transition, this.denial);

  const DeliveryProofDisputeOutcome.allow(
    DeliveryProofDisputeTransition transition,
  ) : this._(transition, null);

  const DeliveryProofDisputeOutcome.deny(DeliveryProofDisputeDenial denial)
    : this._(null, denial);

  /// Null for **every** denial. A denied operation stores nothing, emits no
  /// event, leaves any existing dispute record exactly as it was, and produces
  /// no order, reservation, inventory, financial, custody, assignment or
  /// assessment effect.
  final DeliveryProofDisputeTransition? transition;

  final DeliveryProofDisputeDenial? denial;

  bool get allowed => transition != null;

  /// Whether this denial is a **deferred policy decision** rather than a
  /// refusal.
  ///
  /// A backend must be able to tell "not decided yet" from "not permitted", so
  /// that nobody fills the gap with a guessed rule — the same distinction
  /// `LifecycleDenial.policyDeferred` draws for pre-dispatch cancellation.
  bool get isPolicyDeferred =>
      denial == DeliveryProofDisputeDenial.resolutionPolicyDeferred;

  /// Renders through the transition's own fail-safe `toString`, so a malformed
  /// record cannot reach a log through this wrapper. Denials render enum names
  /// only — never caller-supplied content.
  @override
  String toString() =>
      allowed ? 'Allow(${transition!})' : 'Deny(${denial!.name})';
}
