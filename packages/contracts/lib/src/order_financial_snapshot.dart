import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/money_policy.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// A reference to an **immutable, versioned published policy**.
///
/// ## Why a reference and not an amount
///
/// A fee or commission is only auditable if you can say *which published rule*
/// produced it. Storing the number alone makes a later dispute unanswerable:
/// nobody can tell whether 60 taka was the rule at the time or a typo.
///
/// The same shape as `DeliveryProofPolicyRef` from FND-003D1, and for the same
/// reason: the contract carries the **handle**, never the rule's contents.
@immutable
class FinancialPolicyRef {
  const FinancialPolicyRef({required this.policyId, required this.version});

  /// Opaque, server-generated. Never a guessable counter.
  final String policyId;

  /// Monotonic published version of that policy. Starts at 1.
  final int version;

  /// Whether this reference is usable at all.
  bool get isWellFormed => isValidOpaqueId(policyId) && version >= 1;

  @override
  bool operator ==(Object other) =>
      other is FinancialPolicyRef &&
      other.policyId == policyId &&
      other.version == version;

  @override
  int get hashCode => Object.hash(policyId, version);

  @override
  String toString() => isWellFormed
      ? 'FinancialPolicyRef($policyId v$version)'
      : 'FinancialPolicyRef(invalid)';
}

/// The **immutable quoted money** for one order, as it was at checkout.
///
/// ## Absence is never zero
///
/// Every amount here is required and non-nullable, and every policy reference
/// is required. That is the whole design: a missing fee policy must be
/// impossible to construct, because the dangerous failure is a later reader
/// treating *"no commission recorded"* as *"commission is zero"*. A published
/// zero-value promotion is representable — as an explicit `Money.zero` under a
/// real policy reference — and is a different fact from silence.
///
/// ## What the customer owes, and what the platform allocates
///
/// ```text
/// customerQuotedTotal = merchandiseSubtotal + deliveryCharge
/// codAmountDue        = customerQuotedTotal      (normal delivery path, v1)
/// platformCommission  <= merchandiseSubtotal     (an ALLOCATION, not a charge)
/// ```
///
/// **Commission is not added on top of the customer price.** It is a
/// settlement allocation out of merchandise proceeds the shop economically
/// owns. Adding it to `customerQuotedTotal` would silently overcharge the
/// customer by the platform's own margin — see ADR-0011.
///
/// The **delivery charge** is a platform service-charge receivable. It is not
/// the rider's money merely because the rider's hand touches the cash.
@immutable
class OrderFinancialSnapshot {
  const OrderFinancialSnapshot({
    required this.resourceId,
    required this.merchandiseSubtotal,
    required this.deliveryCharge,
    required this.platformCommission,
    required this.feePolicy,
    required this.commissionPolicy,
  });

  /// The order this snapshot is for. Every other read in a financial operation
  /// is bound to this same canonical id.
  final String resourceId;

  /// Goods only, excluding delivery.
  final Money merchandiseSubtotal;

  /// The quoted customer-facing delivery charge. Also the default customer
  /// obligation on a voluntary refusal — see ADR-0011 — though **this slice
  /// does not collect it**.
  final Money deliveryCharge;

  /// The platform's snapshotted share of merchandise proceeds. An
  /// **allocation**, never an additional customer charge.
  final Money platformCommission;

  /// Which published fee policy quoted [deliveryCharge].
  final FinancialPolicyRef feePolicy;

  /// Which published commission policy produced [platformCommission].
  final FinancialPolicyRef commissionPolicy;

  /// What the customer agreed to pay.
  Money get customerQuotedTotal => merchandiseSubtotal + deliveryCharge;

  /// What a rider must collect on the normal delivery path.
  ///
  /// Identical to [customerQuotedTotal] in v1. Kept as its own name because a
  /// later slice may introduce prepaid or partly-prepaid orders, where the two
  /// stop being the same number.
  Money get codAmountDue => customerQuotedTotal;

  /// The currency of this snapshot. Every amount shares it — enforced by
  /// [validateOrderFinancialSnapshot].
  String get currency => merchandiseSubtotal.currency;
}

/// Why a financial snapshot cannot be used.
enum FinancialSnapshotDefect {
  /// The order id is not a canonical opaque id.
  resourceIdInvalid,

  /// A fee or commission policy reference is missing its id or version.
  policyReferenceInvalid,

  /// Amounts do not all share one currency. **No mixed-currency snapshot**,
  /// and no conversion exists to repair one.
  currencyMismatch,

  /// The currency is not accepted by the v1 financial policy.
  currencyNotAccepted,

  /// An amount is negative. A negative subtotal, delivery charge or commission
  /// is not a discount — it is corruption, and clamping it would invent one.
  negativeAmount,

  /// The order is worth nothing at all. A zero-total order has nothing to
  /// collect and must not reach a collection path.
  nonPositiveOrderTotal,

  /// Commission exceeds the merchandise proceeds it is allocated from. That
  /// would make the shop owe the platform for selling, which no accepted
  /// policy says.
  commissionExceedsMerchandise,
}

/// Rejects a snapshot that cannot be a real quote.
///
/// Returns null when canonical. **Never repairs, clamps or converts anything**
/// — a repaired financial record is indistinguishable from a bug, and this one
/// decides what a customer owes.
FinancialSnapshotDefect? validateOrderFinancialSnapshot(
  OrderFinancialSnapshot s,
) {
  if (!isValidOpaqueId(s.resourceId)) {
    return FinancialSnapshotDefect.resourceIdInvalid;
  }
  if (!s.feePolicy.isWellFormed || !s.commissionPolicy.isWellFormed) {
    return FinancialSnapshotDefect.policyReferenceInvalid;
  }

  // Currency coherence FIRST: every check below does arithmetic, and `Money`
  // throws on a currency mismatch. A pure evaluator owes a denial, not an
  // exception.
  final String c = s.merchandiseSubtotal.currency;
  if (s.deliveryCharge.currency != c || s.platformCommission.currency != c) {
    return FinancialSnapshotDefect.currencyMismatch;
  }
  if (!CurrencyPolicy.isUsable(s.merchandiseSubtotal)) {
    return FinancialSnapshotDefect.currencyNotAccepted;
  }

  if (s.merchandiseSubtotal.isNegative ||
      s.deliveryCharge.isNegative ||
      s.platformCommission.isNegative) {
    return FinancialSnapshotDefect.negativeAmount;
  }
  if (s.customerQuotedTotal.minorUnits <= 0) {
    return FinancialSnapshotDefect.nonPositiveOrderTotal;
  }
  // Commission is an allocation OUT OF merchandise proceeds, so it cannot
  // exceed them.
  if (s.platformCommission > s.merchandiseSubtotal) {
    return FinancialSnapshotDefect.commissionExceedsMerchandise;
  }
  return null;
}
