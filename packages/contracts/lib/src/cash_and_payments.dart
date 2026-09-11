/// Money: the normal-path **COD collection** contract and its balanced
/// cash-journal effects.
///
/// The first executable slice of FND-003C, and deliberately the smallest one
/// that is safe. It exists because `CONSTRAINTS.md` and the blueprint both
/// require money to be modelled as integer minor units with balanced postings
/// and a unique business reference — and because until something records cash
/// honestly, every other slice has to keep saying *"financial consequence
/// deferred"*.
///
/// ## What it makes executable
///
/// ```text
/// rider reports cash actually received  ->  payment due | partially_collected
///                                                    -> partially_collected | collected
///                                       ->  ONE balanced journal entry
/// ```
///
/// Backed by the **accepted, unchanged** `rider.cash.report_collection`
/// permission. **No permission was added.**
///
/// ## The distinctions it refuses to blur
///
/// ```text
/// delivered   != collected     nothing here marks a delivery successful
/// collected   != remitted      the cash is in a rider's hands, not the platform's
/// remitted    != reconciled    nobody has agreed the books match
/// custody     != ownership     a rider holds the platform's cash, and owns none of it
/// commission  != a customer charge   it is an allocation out of merchandise proceeds
/// absence     != zero          a missing fee policy is missing, not free
/// ```
///
/// ## What it deliberately does not do
///
/// **Successful delivery stays non-executable.** No proof assessment is read or
/// written, `OrderState.delivered`, `CustodyHolderKind.customer` and rider
/// `AssignmentState.completed` remain unreachable, and `CONSTRAINTS.md`
/// invariant 13 is **not** discharged. Remittance, settlement, reconciliation,
/// refusal-fee collection, refunds, compensation, commission payout, worker
/// pay, dispute resolution and FX conversion are all **absent** — not stubbed,
/// not defaulted, simply not expressible.
///
/// There is no balance setter, no journal editor or deleter, no generic
/// payment-state setter and no caller-selected journal account. Balances are
/// derived from postings; corrections are reversal entries that reference the
/// original.
///
/// See `docs/contracts/cash-and-payments.md` and **ADR-0011**.
library;

export 'package:cp_contracts/src/cash_journal_entry.dart';
export 'package:cp_contracts/src/cod_collection_authorization.dart';
export 'package:cp_contracts/src/cod_collection_command.dart';
export 'package:cp_contracts/src/cod_collection_denial.dart';
export 'package:cp_contracts/src/cod_collection_evaluator.dart';
export 'package:cp_contracts/src/cod_collection_request.dart';
export 'package:cp_contracts/src/cod_collection_transition.dart';
export 'package:cp_contracts/src/money_policy.dart';
export 'package:cp_contracts/src/order_financial_snapshot.dart';
export 'package:cp_contracts/src/payment_facts.dart';
export 'package:cp_contracts/src/payment_state.dart';
