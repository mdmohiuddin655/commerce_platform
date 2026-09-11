import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/money_policy.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// Accounts this contract can post to.
///
/// ## A closed enum, chosen by the server, never by a caller
///
/// A client-selectable account string is a balance-edit primitive wearing a
/// different hat: whoever picks the account picks where the money appears. The
/// set is therefore closed, and only the accounts an **implemented** operation
/// actually needs exist. Settlement, commission payout, worker compensation
/// and refund accounts are deliberately **absent** — declaring them would
/// invite a later slice to post to them before any policy says what they mean.
enum JournalAccount {
  /// What the **customer** still owes on the normal delivery path. An asset:
  /// positive means money is owed to the platform.
  customerCodReceivable,

  /// Physical cash a **rider** is carrying on the platform's behalf. An asset:
  /// positive means cash exists in the rider's hands.
  ///
  /// **Custody, not ownership.** A positive balance here says the rider holds
  /// the platform's cash for reconciliation — it is not rider income, not
  /// rider compensation, and not settled. See ADR-0011.
  riderCashInTransit;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    JournalAccount.customerCodReceivable => 'customer_cod_receivable',
    JournalAccount.riderCashInTransit => 'rider_cash_in_transit',
  };

  static JournalAccount? byId(String id) {
    for (final JournalAccount a in JournalAccount.values) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }
}

/// One signed movement against one account.
///
/// ## The sign convention, fixed once
///
/// **A posting's amount is the change to that account's balance.** Both
/// accounts here are assets, so collecting COD converts one asset into
/// another:
///
/// ```text
/// customerCodReceivable   -A     the customer owes A less
/// riderCashInTransit      +A     the rider now holds A more
///                         ────
///                          0     balanced
/// ```
///
/// This convention is pinned by tests. Changing it later would silently
/// reinterpret every stored posting, so it is a contract, not a style choice.
@immutable
class JournalPosting {
  const JournalPosting({required this.account, required this.amount});

  final JournalAccount account;

  /// Signed change to [account]. Negative is legitimate — that is how one side
  /// of a balanced entry and every reversal are expressed.
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is JournalPosting &&
      other.account == account &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(account, amount);

  @override
  String toString() => 'JournalPosting(${account.id}, $amount)';
}

/// One immutable, balanced journal entry.
///
/// ## What cannot be expressed here
///
/// There is **no** mutable balance, **no** edit and **no** delete. A
/// correction is a **new reversal entry** that names the entry it reverses —
/// so history only ever grows, and a balance is always the sum of postings
/// rather than a number somebody set.
@immutable
class CashJournalEntry {
  const CashJournalEntry({
    required this.entryId,
    required this.businessReference,
    required this.resourceId,
    required this.postings,
    required this.recordedAtUtc,
    this.reversesEntryId,
  });

  /// Opaque, server-generated, unique to this entry.
  final String entryId;

  /// The **unique business reference** that ties this entry to the operation
  /// that caused it.
  ///
  /// This is the idempotency anchor: a backend must reject a second entry
  /// carrying a reference it has already stored, which is what stops a retried
  /// command from posting the same cash twice — criterion **CJ4**.
  final String businessReference;

  /// The order this entry belongs to.
  final String resourceId;

  /// Signed movements. Must be at least two, share one currency, and sum to
  /// **exactly** zero.
  final List<JournalPosting> postings;

  /// Server UTC. Never a client clock and never a local time.
  final DateTime recordedAtUtc;

  /// Set only on a reversal: the entry this one reverses. Null otherwise.
  final String? reversesEntryId;

  bool get isReversal => reversesEntryId != null;

  /// The single currency of this entry, or null when it has no postings.
  String? get currency =>
      postings.isEmpty ? null : postings.first.amount.currency;

  /// Sum of the signed postings. Zero for every canonical entry.
  ///
  /// Returns null when the postings do not share one currency — the sum is
  /// then not a number this contract will compute, rather than an exception.
  Money? get balance {
    if (postings.isEmpty) {
      return null;
    }
    final String c = postings.first.amount.currency;
    int total = 0;
    for (final JournalPosting p in postings) {
      if (p.amount.currency != c) {
        return null;
      }
      total += p.amount.minorUnits;
    }
    return Money(total, c);
  }

  @override
  String toString() =>
      'CashJournalEntry($entryId, ref=$businessReference, '
      '${postings.length} postings'
      '${isReversal ? ', reverses $reversesEntryId' : ''})';
}

/// Why a journal entry is not canonical.
enum JournalDefect {
  /// The entry id, business reference or resource id is not a canonical
  /// opaque id.
  referenceInvalid,

  /// Fewer than two postings. A single-sided entry cannot balance, and an
  /// empty one records nothing.
  tooFewPostings,

  /// Postings do not share one currency. **No mixed-currency entry exists**,
  /// and no conversion policy could repair one.
  mixedCurrency,

  /// The currency is not accepted by the v1 financial policy.
  currencyNotAccepted,

  /// Signed postings do not sum to exactly zero. **The load-bearing check**:
  /// an unbalanced entry means money appeared or vanished.
  unbalanced,

  /// A posting moves nothing. A zero posting is noise in an audit trail and
  /// usually means a caller meant something it did not say.
  zeroPosting,

  /// Two postings hit the same account. Net them into one movement instead —
  /// an entry that debits and credits the same account hides its own effect.
  duplicateAccount,

  /// The timestamp is not UTC. Never normalised: a local time in stored
  /// financial history cannot be recovered, because the offset is gone.
  timestampNotUtc,

  /// A reversal names an invalid entry, or names itself.
  reversalReferenceInvalid,
}

/// Rejects any entry that is not canonical, **before** it can be applied.
///
/// Returns null when the entry is sound. Never repairs anything.
JournalDefect? validateCashJournalEntry(CashJournalEntry e) {
  if (!isValidOpaqueId(e.entryId) ||
      !isValidOpaqueId(e.businessReference) ||
      !isValidOpaqueId(e.resourceId)) {
    return JournalDefect.referenceInvalid;
  }
  if (!e.recordedAtUtc.isUtc) {
    return JournalDefect.timestampNotUtc;
  }
  if (e.postings.length < 2) {
    return JournalDefect.tooFewPostings;
  }

  final String c = e.postings.first.amount.currency;
  final Set<JournalAccount> seen = <JournalAccount>{};
  for (final JournalPosting p in e.postings) {
    if (p.amount.currency != c) {
      return JournalDefect.mixedCurrency;
    }
    if (p.amount.isZero) {
      return JournalDefect.zeroPosting;
    }
    if (!seen.add(p.account)) {
      return JournalDefect.duplicateAccount;
    }
  }
  if (!CurrencyPolicy.isAccepted(c)) {
    return JournalDefect.currencyNotAccepted;
  }

  // Balance last: it is the invariant the rest exists to make computable.
  final Money? balance = e.balance;
  if (balance == null || !balance.isZero) {
    return JournalDefect.unbalanced;
  }

  final String? reverses = e.reversesEntryId;
  if (reverses != null &&
      (!isValidOpaqueId(reverses) || reverses == e.entryId)) {
    return JournalDefect.reversalReferenceInvalid;
  }
  return null;
}
