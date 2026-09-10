import 'package:cp_contracts/src/delivery_proof_dispute_basis.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_denial.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_facts.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
import 'package:cp_contracts/src/delivery_proof_dispute_state.dart';
import 'package:cp_contracts/src/ids.dart';

/// Canonical dispute-aggregate shape.
///
/// Same lesson as every slice before it: the evaluator never *creates* an
/// impossible aggregate, but facts arrive from **storage**. Validation runs
/// before any transition is constructed.
///
/// Returns null when the facts are canonical. **Never repairs anything** —
/// repair without an audit trail is indistinguishable from a bug.
DeliveryProofDisputeDenial? validateDeliveryProofDisputeAggregate(
  DeliveryProofDisputeFacts facts,
) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  final DeliveryProofDisputeRecord? current = facts.current;
  if (current == null) {
    // Canonical absence is exact. A "never disputed" aggregate carrying a
    // revision is a partial load, and reading it as absent would let a second
    // raise overwrite the revision of a dispute that already exists.
    if (facts.disputeRevision != 0) {
      return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
    }
    return null;
  }
  // An existing dispute has been written at least once.
  if (facts.disputeRevision < 1) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  // The current pointer and the aggregate revision must agree. A record whose
  // own revision differs from the aggregate's is a torn write.
  if (current.disputeRevision != facts.disputeRevision) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  if (current.resourceId != facts.resourceId) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  // `isWellFormed` already enforces state/revision/field coherence and rejects
  // a stored `resolved` record, because `reachableDisputeRevisionFor` defines
  // no revision for a state no slice implements. A stored dispute claiming to
  // be resolved is therefore corruption here rather than a state to act on —
  // validating its shape would legitimise an outcome nobody decided.
  if (!current.isWellFormed) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  // Belt and braces on the same claim, stated where a future resolution slice
  // will look first: only states this slice implements may be stored.
  if (!DeliveryProofDisputeState.executableInThisSlice.contains(current.state)) {
    return DeliveryProofDisputeDenial.disputeAggregateInconsistent;
  }
  return null;
}

/// Trusted read access to the current dispute.
///
/// `DeliveryProofDisputeFacts` deliberately exposes no state or basis getter of
/// its own, for exactly the reason FND-003D2A-FIX-001 replaced the assessment's
/// convenience getter with `canonicalVerdict`: a getter that reads straight off
/// raw storage facts hands a caller a trusted-looking answer from a **torn or
/// corrupt** aggregate. On records that gate audit reasoning, that is the wrong
/// direction to fail.
extension DeliveryProofDisputeCanonicalAccess on DeliveryProofDisputeFacts {
  /// The current dispute state **only when the aggregate is canonical**.
  ///
  /// | Aggregate | Result |
  /// |---|---|
  /// | canonical, absent | `null` — *never disputed* |
  /// | canonical, open | `open` |
  /// | canonical, under review | `underReview` |
  /// | malformed or torn | `null` |
  ///
  /// **Corruption is never converted into a state.** `null` means *no usable
  /// dispute state*, which a caller must not read as "there is no dispute"
  /// either — a torn aggregate may well be hiding one.
  DeliveryProofDisputeState? get canonicalState =>
      validateDeliveryProofDisputeAggregate(this) == null ? current?.state : null;

  /// What the current dispute is about, **only when the aggregate is
  /// canonical**.
  ///
  /// This is the accessor a later resolution slice, a support view or an audit
  /// export must use to answer *"which assessment was being disputed?"* — never
  /// `facts.current!.basis`, which answers from unvalidated storage.
  DeliveryProofDisputeBasis? get canonicalBasis =>
      validateDeliveryProofDisputeAggregate(this) == null ? current?.basis : null;
}
