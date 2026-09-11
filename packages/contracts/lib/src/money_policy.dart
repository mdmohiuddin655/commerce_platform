import 'package:cp_core/cp_core.dart';

/// The marketplace's accepted commercial currencies.
///
/// ## Why this is a set and not a constant
///
/// **ADR-0011** records the delegated **O6** decision: the initial commercial
/// currency is **BDT**, and the initial financial policy accepts **BDT only**.
/// That is a *policy* decision, not a property of money — so it lives here as
/// data a later ADR can extend, rather than as a hard-coded literal scattered
/// through business logic.
///
/// `cp_core.Money` still carries an **explicit ISO-4217 currency on every
/// value**. This set narrows which of those values the v1 financial policy will
/// act on; it does not replace the currency with a bare integer, and nothing
/// downstream may assume "the amount is BDT" without checking.
///
/// ## There is no FX in v1
///
/// No conversion rate, no rounding rule and no reference-rate source exists.
/// `Money` already throws on cross-currency arithmetic; this contract refuses
/// **earlier**, with a denial rather than an exception, so a mixed-currency
/// read can never reach an arithmetic site at all.
class CurrencyPolicy {
  const CurrencyPolicy._();

  /// Bangladeshi taka. Minor unit: poisha, 100 to the taka.
  static const String bdt = 'BDT';

  /// Currencies the v1 financial policy accepts.
  ///
  /// Extending this set is an **ADR + contract migration**, not an edit: stored
  /// history written under a one-currency policy cannot be reinterpreted by
  /// widening a set.
  static const Set<String> acceptedInV1 = <String>{bdt};

  /// Whether the v1 policy may act on this currency at all.
  static bool isAccepted(String currency) => acceptedInV1.contains(currency);

  /// Whether this amount is usable by the v1 financial policy.
  ///
  /// Rejects a non-accepted currency **and** a malformed code, so a caller
  /// cannot smuggle `'bdt'` or `'BD'` past a case-sensitive comparison.
  static bool isUsable(Money amount) =>
      amount.currency.length == 3 &&
      amount.currency == amount.currency.toUpperCase() &&
      isAccepted(amount.currency);

  /// Whether two amounts may be combined at all.
  ///
  /// Checked **before** any `Money` operator runs: `Money` throws on a
  /// currency mismatch, and an exception escaping a pure evaluator would be a
  /// crash where this contract owes a denial.
  static bool sameUsableCurrency(Money a, Money b) =>
      isUsable(a) && isUsable(b) && a.currency == b.currency;
}
