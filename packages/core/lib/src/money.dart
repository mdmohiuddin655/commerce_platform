import 'package:meta/meta.dart';

/// A monetary amount held as an **integer number of minor units**.
///
/// The blueprint requires integer minor units, an explicit currency and
/// balanced postings for every ledger entry. Floating point is therefore not
/// representable by construction: there is no `double` constructor and no
/// `double` accessor on this type.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency)
    : assert(currency.length == 3, 'currency must be an ISO-4217 alpha code');

  /// Zero in [currency].
  const Money.zero(this.currency) : minorUnits = 0;

  /// Signed amount in minor units (paisa, cent, ...). Negative is allowed so
  /// that reversal postings can be represented; corrections are reversals,
  /// never edits of history.
  final int minorUnits;

  /// ISO-4217 alpha-3 code, upper case, e.g. `BDT`.
  final String currency;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) =>
      Money(minorUnits + _checked(other).minorUnits, currency);

  Money operator -(Money other) =>
      Money(minorUnits - _checked(other).minorUnits, currency);

  /// Whole-number scaling only (quantity x unit price). Percentage or rate
  /// maths must state its own rounding policy and is deliberately not
  /// provided here; see FND-003.
  Money operator *(int factor) => Money(minorUnits * factor, currency);

  Money operator -() => Money(-minorUnits, currency);

  Money _checked(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'currency mismatch: $currency vs ${other.currency}; '
        'cross-currency arithmetic needs an explicit conversion policy',
      );
    }
    return other;
  }

  @override
  int compareTo(Money other) =>
      minorUnits.compareTo(_checked(other).minorUnits);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '$currency $minorUnits (minor units)';
}
