import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/money_policy.dart';
import 'package:cp_contracts/src/order_financial_snapshot.dart';
import 'package:cp_contracts/src/payment_state.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// The payment aggregate for one order, as loaded from storage.
///
/// Its [paymentRevision] is **its own** concurrency control, independent of the
/// order, custody, attempt and rider-slot revisions. Two riders cannot both
/// collect against one revision — that is the compare-and-set this field
/// exists for, and criterion **CJ1**.
@immutable
class PaymentFacts {
  const PaymentFacts({
    required this.resourceId,
    required this.paymentRevision,
    required this.state,
    required this.collectedToDate,
  });

  /// The canonical starting payment record for an order with COD due.
  ///
  /// Revision starts at 1, following the repository convention that a written
  /// aggregate begins at 1 and that revision 0 means "never written".
  factory PaymentFacts.initial({
    required String resourceId,
    required String currency,
  }) => PaymentFacts(
    resourceId: resourceId,
    paymentRevision: 1,
    state: PaymentState.due,
    collectedToDate: Money.zero(currency),
  );

  final String resourceId;

  /// Increments on **every** applied payment mutation.
  final int paymentRevision;

  final PaymentState state;

  /// Total actually received so far. **Only what was really handed over** —
  /// never what was expected, quoted or promised.
  final Money collectedToDate;

  bool get isDue => state == PaymentState.due;
  bool get isPartiallyCollected => state == PaymentState.partiallyCollected;
  bool get isCollected => state == PaymentState.collected;
  bool get isDisputed => state == PaymentState.disputed;
}

/// Why a payment aggregate is not canonical.
enum PaymentDefect {
  resourceIdInvalid,

  /// Revision 0 would mean "never written", which contradicts holding a state.
  revisionInvalid,

  /// A negative total collected. Money was not un-received; this is
  /// corruption, and clamping it would hide a real accounting error.
  negativeCollected,

  /// The currency is not accepted by the v1 financial policy.
  currencyNotAccepted,

  /// The recorded state contradicts the recorded total — `due` with money
  /// collected, `collected` with nothing collected, and so on.
  stateAmountMismatch,
}

/// Rejects a payment aggregate that cannot be real, **before** any effect.
///
/// [snapshot] is required because the state/amount coherence rule is only
/// decidable against the canonical amount due: whether 500 means
/// `partiallyCollected` or `collected` depends entirely on the order.
///
/// Returns null when canonical. Never repairs anything.
PaymentDefect? validatePaymentAggregate(
  PaymentFacts facts,
  OrderFinancialSnapshot snapshot,
) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return PaymentDefect.resourceIdInvalid;
  }
  if (facts.paymentRevision < 1) {
    return PaymentDefect.revisionInvalid;
  }
  if (!CurrencyPolicy.isUsable(facts.collectedToDate)) {
    return PaymentDefect.currencyNotAccepted;
  }
  // Currency coherence before any comparison: `Money` throws across
  // currencies, and this validator owes a defect value, not an exception.
  if (facts.collectedToDate.currency != snapshot.currency) {
    return PaymentDefect.currencyNotAccepted;
  }
  if (facts.collectedToDate.isNegative) {
    return PaymentDefect.negativeCollected;
  }

  final Money due = snapshot.codAmountDue;
  switch (facts.state) {
    case PaymentState.due:
      if (!facts.collectedToDate.isZero) {
        return PaymentDefect.stateAmountMismatch;
      }
    case PaymentState.partiallyCollected:
      if (facts.collectedToDate.isZero || facts.collectedToDate >= due) {
        return PaymentDefect.stateAmountMismatch;
      }
    case PaymentState.collected:
      if (facts.collectedToDate != due) {
        return PaymentDefect.stateAmountMismatch;
      }
    case PaymentState.disputed:
      // A disputed payment may sit at any collected total between nothing and
      // the full amount — that is what makes nonpayment representable. Only
      // an impossible OVER-collection is corruption.
      if (facts.collectedToDate > due) {
        return PaymentDefect.stateAmountMismatch;
      }
  }
  return null;
}
