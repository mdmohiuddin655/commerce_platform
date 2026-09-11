import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

import 'support/cod_collection_fixtures.dart';

CashJournalEntry entry({
  String id = journalEntryId,
  String reference = journalRef,
  String resource = orderId,
  List<JournalPosting>? postings,
  DateTime? at,
  String? reverses,
}) => CashJournalEntry(
  entryId: id,
  businessReference: reference,
  resourceId: resource,
  recordedAtUtc: at ?? utcNow,
  reversesEntryId: reverses,
  postings:
      postings ??
      <JournalPosting>[
        JournalPosting(
          account: JournalAccount.customerCodReceivable,
          amount: bdt(-50000),
        ),
        JournalPosting(
          account: JournalAccount.riderCashInTransit,
          amount: bdt(50000),
        ),
      ],
);

void main() {
  group('journal — the balance invariant', () {
    test('a canonical balanced entry validates', () {
      expect(validateCashJournalEntry(entry()), isNull);
      expect(entry().balance, bdt(0));
    });

    test('an unbalanced entry is rejected', () {
      expect(
        validateCashJournalEntry(
          entry(
            postings: <JournalPosting>[
              JournalPosting(
                account: JournalAccount.customerCodReceivable,
                amount: bdt(-50000),
              ),
              JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: bdt(49999),
              ),
            ],
          ),
        ),
        JournalDefect.unbalanced,
      );
    });

    test('a mixed-currency entry is rejected and its balance is undefined', () {
      final CashJournalEntry e = entry(
        postings: <JournalPosting>[
          JournalPosting(
            account: JournalAccount.customerCodReceivable,
            amount: bdt(-50000),
          ),
          const JournalPosting(
            account: JournalAccount.riderCashInTransit,
            amount: Money(50000, 'USD'),
          ),
        ],
      );
      expect(validateCashJournalEntry(e), JournalDefect.mixedCurrency);
      expect(e.balance, isNull, reason: 'no cross-currency sum is computed');
    });

    test('a non-BDT but internally consistent entry is refused in v1', () {
      expect(
        validateCashJournalEntry(
          entry(
            postings: <JournalPosting>[
              const JournalPosting(
                account: JournalAccount.customerCodReceivable,
                amount: Money(-50000, 'USD'),
              ),
              const JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: Money(50000, 'USD'),
              ),
            ],
          ),
        ),
        JournalDefect.currencyNotAccepted,
      );
    });

    test('single-sided, empty, zero and duplicate-account entries fail', () {
      expect(
        validateCashJournalEntry(
          entry(
            postings: <JournalPosting>[
              JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: bdt(50000),
              ),
            ],
          ),
        ),
        JournalDefect.tooFewPostings,
      );
      expect(
        validateCashJournalEntry(entry(postings: <JournalPosting>[])),
        JournalDefect.tooFewPostings,
      );
      expect(
        validateCashJournalEntry(
          entry(
            postings: <JournalPosting>[
              JournalPosting(
                account: JournalAccount.customerCodReceivable,
                amount: bdt(0),
              ),
              JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: bdt(0),
              ),
            ],
          ),
        ),
        JournalDefect.zeroPosting,
      );
      expect(
        validateCashJournalEntry(
          entry(
            postings: <JournalPosting>[
              JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: bdt(-50000),
              ),
              JournalPosting(
                account: JournalAccount.riderCashInTransit,
                amount: bdt(50000),
              ),
            ],
          ),
        ),
        JournalDefect.duplicateAccount,
      );
    });

    test('malformed references and non-UTC timestamps fail', () {
      expect(
        validateCashJournalEntry(entry(id: 'short')),
        JournalDefect.referenceInvalid,
      );
      expect(
        validateCashJournalEntry(entry(reference: '123456789012345678')),
        JournalDefect.referenceInvalid,
      );
      expect(
        validateCashJournalEntry(entry(resource: 'x')),
        JournalDefect.referenceInvalid,
      );
      expect(
        validateCashJournalEntry(entry(at: DateTime(2026, 9, 11))),
        JournalDefect.timestampNotUtc,
      );
    });
  });

  group('journal — corrections are reversals, never edits', () {
    test('a valid reversal references another entry and still balances', () {
      final CashJournalEntry r = entry(
        id: 'jrn_C1REVERSALmW9tLp4',
        reference: 'jref_C1REVERSAL9tLp',
        reverses: journalEntryId,
        postings: <JournalPosting>[
          JournalPosting(
            account: JournalAccount.customerCodReceivable,
            amount: bdt(50000),
          ),
          JournalPosting(
            account: JournalAccount.riderCashInTransit,
            amount: bdt(-50000),
          ),
        ],
      );
      expect(validateCashJournalEntry(r), isNull);
      expect(r.isReversal, isTrue);
      expect(r.reversesEntryId, journalEntryId);
      expect(r.balance, bdt(0));
    });

    test('a self-referencing or malformed reversal is rejected', () {
      expect(
        validateCashJournalEntry(entry(reverses: journalEntryId)),
        JournalDefect.reversalReferenceInvalid,
        reason: 'an entry cannot reverse itself',
      );
      expect(
        validateCashJournalEntry(entry(reverses: 'nope')),
        JournalDefect.reversalReferenceInvalid,
      );
    });

    test('no edit, delete or balance-set primitive exists on the API', () {
      // The type is immutable and exposes no mutator: balances are derived
      // from postings, and history only grows.
      final CashJournalEntry e = entry();
      expect(e.postings, isA<List<JournalPosting>>());
      expect(e.balance, bdt(0));
      expect(
        JournalAccount.values.length,
        2,
        reason: 'only accounts an implemented operation needs exist',
      );
      expect(
        JournalAccount.values.map((JournalAccount a) => a.id).toSet(),
        <String>{'customer_cod_receivable', 'rider_cash_in_transit'},
      );
    });
  });

  group('financial snapshot — absence is never zero', () {
    test('a canonical snapshot validates and derives the customer total', () {
      final OrderFinancialSnapshot s = snapshot();
      expect(validateOrderFinancialSnapshot(s), isNull);
      expect(s.merchandiseSubtotal, bdt(120000));
      expect(s.deliveryCharge, bdt(6000));
      expect(s.customerQuotedTotal, bdt(126000));
      expect(s.codAmountDue, bdt(126000));
      expect(s.currency, CurrencyPolicy.bdt);
    });

    test('commission is NOT added to what the customer pays', () {
      final OrderFinancialSnapshot s = snapshot();
      expect(
        s.customerQuotedTotal,
        s.merchandiseSubtotal + s.deliveryCharge,
        reason: 'commission is an allocation, not a customer charge',
      );
      expect(
        s.codAmountDue.minorUnits,
        126000,
        reason: 'adding the 12000 commission would overcharge the customer',
      );
    });

    test('an explicitly published zero fee is representable', () {
      // Zero-with-a-policy is a fact; absence is not. Both policy references
      // are required by the constructor, so silence cannot be constructed.
      final OrderFinancialSnapshot s = snapshot(delivery: bdt(0));
      expect(validateOrderFinancialSnapshot(s), isNull);
      expect(s.deliveryCharge, bdt(0));
      expect(s.feePolicy.isWellFormed, isTrue);
    });

    test('malformed policy references are rejected', () {
      expect(
        validateOrderFinancialSnapshot(
          snapshot(fee: const FinancialPolicyRef(policyId: 'x', version: 1)),
        ),
        FinancialSnapshotDefect.policyReferenceInvalid,
      );
      expect(
        validateOrderFinancialSnapshot(
          snapshot(
            comm: FinancialPolicyRef(policyId: commissionPolicyId, version: 0),
          ),
        ),
        FinancialSnapshotDefect.policyReferenceInvalid,
      );
    });

    test('negative, zero-total and over-commission snapshots are rejected', () {
      expect(
        validateOrderFinancialSnapshot(snapshot(delivery: bdt(-1))),
        FinancialSnapshotDefect.negativeAmount,
      );
      expect(
        validateOrderFinancialSnapshot(
          snapshot(merchandise: bdt(0), delivery: bdt(0), commission: bdt(0)),
        ),
        FinancialSnapshotDefect.nonPositiveOrderTotal,
      );
      expect(
        validateOrderFinancialSnapshot(snapshot(commission: bdt(120001))),
        FinancialSnapshotDefect.commissionExceedsMerchandise,
      );
    });
  });

  group('payment aggregate — state must match the money', () {
    test('canonical combinations validate', () {
      final OrderFinancialSnapshot s = snapshot();
      expect(validatePaymentAggregate(payment(), s), isNull);
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.partiallyCollected, collected: bdt(1)),
          s,
        ),
        isNull,
      );
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.collected, collected: bdt(126000)),
          s,
        ),
        isNull,
      );
    });

    test('incoherent state/amount pairs are corruption', () {
      final OrderFinancialSnapshot s = snapshot();
      expect(
        validatePaymentAggregate(payment(collected: bdt(1)), s),
        PaymentDefect.stateAmountMismatch,
        reason: 'due with money collected',
      );
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.collected, collected: bdt(1)),
          s,
        ),
        PaymentDefect.stateAmountMismatch,
      );
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.partiallyCollected, collected: bdt(0)),
          s,
        ),
        PaymentDefect.stateAmountMismatch,
      );
      expect(
        validatePaymentAggregate(
          payment(
            state: PaymentState.partiallyCollected,
            collected: bdt(126000),
          ),
          s,
        ),
        PaymentDefect.stateAmountMismatch,
      );
    });

    test('nonpayment stays representable on a disputed payment', () {
      // A refusal where the customer paid nothing is a real outcome, and the
      // contract must be able to hold it without fabricating a collection.
      final OrderFinancialSnapshot s = snapshot();
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.disputed, collected: bdt(0)),
          s,
        ),
        isNull,
      );
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.disputed, collected: bdt(40000)),
          s,
        ),
        isNull,
      );
      // But never more than was ever owed.
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.disputed, collected: bdt(126001)),
          s,
        ),
        PaymentDefect.stateAmountMismatch,
      );
    });

    test('malformed revision, currency and negatives are rejected', () {
      final OrderFinancialSnapshot s = snapshot();
      expect(
        validatePaymentAggregate(payment(revision: 0), s),
        PaymentDefect.revisionInvalid,
      );
      expect(
        validatePaymentAggregate(payment(resourceId: 'x'), s),
        PaymentDefect.resourceIdInvalid,
      );
      expect(
        validatePaymentAggregate(payment(collected: const Money(0, 'USD')), s),
        PaymentDefect.currencyNotAccepted,
      );
      expect(
        validatePaymentAggregate(
          payment(state: PaymentState.partiallyCollected, collected: bdt(-1)),
          s,
        ),
        PaymentDefect.negativeCollected,
      );
    });
  });

  group('currency policy — BDT only, no FX', () {
    test('accepts BDT and rejects everything else in v1', () {
      expect(CurrencyPolicy.isAccepted('BDT'), isTrue);
      expect(CurrencyPolicy.isAccepted('USD'), isFalse);
      expect(CurrencyPolicy.acceptedInV1, <String>{'BDT'});
    });

    test('a lower-case code is not smuggled through', () {
      // `cp_core.Money` already refuses a non-three-character code with a
      // const assert, so `Money(1, 'BD')` will not even compile. What it does
      // NOT check is case, which is why `isUsable` does.
      expect(CurrencyPolicy.isUsable(const Money(1, 'bdt')), isFalse);
      expect(CurrencyPolicy.isUsable(const Money(1, 'Bdt')), isFalse);
      expect(CurrencyPolicy.isUsable(bdt(1)), isTrue);
    });

    test('no conversion helper exists anywhere in the surface', () {
      expect(
        CurrencyPolicy.sameUsableCurrency(bdt(1), const Money(1, 'USD')),
        isFalse,
      );
      expect(CurrencyPolicy.sameUsableCurrency(bdt(1), bdt(2)), isTrue);
    });
  });
}
