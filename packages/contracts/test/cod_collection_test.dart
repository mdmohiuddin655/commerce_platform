import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

import 'support/cod_collection_fixtures.dart';

void main() {
  group('C1 — a full normal-path collection', () {
    test('is allowed and advances only the payment', () {
      final CodCollectionOutcome o = collect();
      expect(o.allowed, isTrue, reason: '${o.denial}');
      final CodCollectionTransition t = o.transition!;

      expect(t.command, CodCollectionCommand.reportCodCollection);
      expect(t.resourceId, orderId);
      expect(t.payment.fromState, PaymentState.due);
      expect(t.payment.toState, PaymentState.collected);
      expect(t.payment.resultingPaymentRevision, 2);
      expect(t.payment.collectedAmount, bdt(126000));
      expect(t.payment.resultingCollectedToDate, bdt(126000));
      expect(t.payment.outstandingAfter, bdt(0));
      expect(t.payment.isFullyCollected, isTrue);

      // Nothing else moves — and cannot.
      expect(t.changesOrder, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.completesRider, isFalse);
    });

    test('produces exactly one balanced journal entry for the amount', () {
      final CashJournalEntry e = collect().transition!.journalEntry;
      expect(validateCashJournalEntry(e), isNull);
      expect(e.entryId, journalEntryId);
      expect(e.businessReference, journalRef);
      expect(e.resourceId, orderId);
      expect(e.isReversal, isFalse);
      expect(e.currency, CurrencyPolicy.bdt);
      expect(e.balance, bdt(0));
      expect(e.postings.length, 2);
    });

    test('the accounting signs are the documented ones', () {
      // Fixed by contract: the customer owes A less, the rider holds A more.
      final CashJournalEntry e = collect().transition!.journalEntry;
      final JournalPosting receivable = e.postings.firstWhere(
        (JournalPosting p) => p.account == JournalAccount.customerCodReceivable,
      );
      final JournalPosting cash = e.postings.firstWhere(
        (JournalPosting p) => p.account == JournalAccount.riderCashInTransit,
      );
      expect(receivable.amount, bdt(-126000));
      expect(cash.amount, bdt(126000));
      expect(
        receivable.amount.minorUnits + cash.amount.minorUnits,
        0,
        reason: 'the entry must balance exactly',
      );
    });

    test('emits privacy-minimal events only', () {
      final CodCollectionTransition t = collect().transition!;
      expect(t.events, <String>[
        CodCollectionEventType.collected,
        CodCollectionEventType.journalEntryRecorded,
      ]);
      for (final String e in CodCollectionEventType.all) {
        expect(e, matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'));
      }
    });
  });

  group('C1 — partial collection', () {
    test(
      'a part payment yields partiallyCollected with the right remainder',
      () {
        final CodCollectionOutcome o = collect(
          req: request(amount: bdt(100000)),
        );
        final CodCollectionTransition t = o.transition!;
        expect(t.payment.toState, PaymentState.partiallyCollected);
        expect(t.payment.collectedAmount, bdt(100000));
        expect(t.payment.resultingCollectedToDate, bdt(100000));
        expect(t.payment.outstandingAfter, bdt(26000));
        expect(t.payment.isFullyCollected, isFalse);
        expect(t.events.first, CodCollectionEventType.partiallyCollected);
        expect(t.journalEntry.balance, bdt(0));
        expect(
          t.journalEntry.postings
              .firstWhere(
                (JournalPosting p) =>
                    p.account == JournalAccount.riderCashInTransit,
              )
              .amount,
          bdt(100000),
          reason: 'the journal records only what was received',
        );
      },
    );

    test('a second collection can complete it, threading real revisions', () {
      final CodCollectionTransition first = collect(
        req: request(amount: bdt(100000)),
      ).transition!;

      final CodCollectionOutcome second = collect(
        req: request(
          expectedPaymentRevision: first.payment.resultingPaymentRevision,
          amount: first.payment.outstandingAfter,
          entryId: 'jrn_C1SECOND2mW9tLp4Z',
          reference: 'jref_C1SECOND2mW9tLp',
        ),
        pay: payment(
          revision: first.payment.resultingPaymentRevision,
          state: first.payment.toState,
          collected: first.payment.resultingCollectedToDate,
        ),
      );
      final CodCollectionTransition t = second.transition!;
      expect(t.payment.fromState, PaymentState.partiallyCollected);
      expect(t.payment.toState, PaymentState.collected);
      expect(t.payment.resultingPaymentRevision, 3);
      expect(t.payment.resultingCollectedToDate, bdt(126000));
      expect(t.payment.outstandingAfter, bdt(0));

      // Two entries, two distinct business references, total moved == due.
      expect(
        t.journalEntry.businessReference,
        isNot(first.journalEntry.businessReference),
      );
      expect(
        first.payment.collectedAmount.minorUnits +
            t.payment.collectedAmount.minorUnits,
        126000,
      );
    });

    test(
      'over-collection is impossible, on the first or a later collection',
      () {
        expect(
          collect(req: request(amount: bdt(126001))).denial,
          CodCollectionDenial.collectionExceedsOutstanding,
        );
        // Already took 100000; only 26000 remains.
        expect(
          collect(
            req: request(expectedPaymentRevision: 2, amount: bdt(26001)),
            pay: payment(
              revision: 2,
              state: PaymentState.partiallyCollected,
              collected: bdt(100000),
            ),
          ).denial,
          CodCollectionDenial.collectionExceedsOutstanding,
        );
      },
    );

    test('a fully collected payment cannot be collected again', () {
      expect(
        collect(
          req: request(expectedPaymentRevision: 3, amount: bdt(1)),
          pay: payment(
            revision: 3,
            state: PaymentState.collected,
            collected: bdt(126000),
          ),
        ).denial,
        CodCollectionDenial.paymentNotCollectable,
      );
    });
  });

  group('C1 — amount and currency', () {
    test('zero and negative amounts are refused', () {
      expect(
        collect(req: request(amount: bdt(0))).denial,
        CodCollectionDenial.collectionAmountNotPositive,
      );
      expect(
        collect(req: request(amount: bdt(-5000))).denial,
        CodCollectionDenial.collectionAmountNotPositive,
      );
    });

    test('a non-BDT collection is refused, never converted', () {
      // No FX exists. The denial arrives before any Money arithmetic could
      // throw on the mismatch.
      expect(
        collect(req: request(amount: const Money(126000, 'USD'))).denial,
        CodCollectionDenial.currencyMismatch,
      );
    });

    test('a non-BDT order snapshot cannot be used at all', () {
      expect(
        collect(
          snap: snapshot(
            merchandise: const Money(120000, 'USD'),
            delivery: const Money(6000, 'USD'),
            commission: const Money(12000, 'USD'),
          ),
        ).denial,
        CodCollectionDenial.financialSnapshotInconsistent,
      );
    });

    test('a mixed-currency snapshot fails closed', () {
      expect(
        collect(snap: snapshot(delivery: const Money(6000, 'USD'))).denial,
        CodCollectionDenial.financialSnapshotInconsistent,
      );
    });
  });

  group('C1 — identity binding and concurrency', () {
    test('every read aggregate is compare-and-set', () {
      expect(
        collect(req: request(expectedPaymentRevision: 99)).denial,
        CodCollectionDenial.paymentRevisionConflict,
      );
      expect(
        collect(req: request(expectedOrderRevision: 99)).denial,
        CodCollectionDenial.orderRevisionConflict,
      );
      expect(
        collect(req: request(expectedAttemptRevision: 99)).denial,
        CodCollectionDenial.attemptRevisionConflict,
      );
      expect(
        collect(req: request(expectedCustodyRevision: 99)).denial,
        CodCollectionDenial.custodyRevisionConflict,
      );
      expect(
        collect(req: request(expectedRiderSlotRevision: 99)).denial,
        CodCollectionDenial.riderSlotRevisionConflict,
      );
    });

    test('two collections against one payment revision cannot both commit', () {
      // Both callers read revision 1 and try to take the full amount. The
      // first would apply and move the payment to revision 2; the second then
      // finds its expectation stale. Pure-Dart evidence of the CAS; the
      // storage-level guarantee is backend criterion CJ1 (NOT RUN).
      final CodCollectionOutcome a = collect(req: request(amount: bdt(60000)));
      expect(a.allowed, isTrue);
      final int applied = a.transition!.payment.resultingPaymentRevision;

      final CodCollectionOutcome b = collect(
        req: request(expectedPaymentRevision: 1, amount: bdt(60000)),
        pay: payment(
          revision: applied,
          state: PaymentState.partiallyCollected,
          collected: bdt(60000),
        ),
      );
      expect(b.allowed, isFalse);
      expect(b.denial, CodCollectionDenial.paymentRevisionConflict);
    });

    test('a cross-resource read fails closed on every aggregate', () {
      for (final CodCollectionOutcome o in <CodCollectionOutcome>[
        collect(snap: snapshot(resourceId: otherOrderId)),
        collect(pay: payment(resourceId: otherOrderId)),
        collect(order: orderRead(resourceId: otherOrderId)),
        collect(att: attempt(resourceId: otherOrderId)),
        collect(custody: riderCustody(resourceId: otherOrderId)),
        collect(rider: riderAssignment(resourceId: otherOrderId)),
      ]) {
        expect(o.denial, CodCollectionDenial.resourceBindingMismatch);
      }
    });

    test('a different rider cannot collect, despite matching scalars', () {
      expect(
        collect(
          grant: codGrant(
            principalId: otherRiderId,
            assigned: <String>{otherRiderId},
          ),
          actor: user(otherRiderId),
        ).denial,
        CodCollectionDenial.notCurrentAcceptedRider,
      );
    });

    test('custody bound to another attempt fails closed', () {
      expect(
        collect(custody: riderCustody(assignmentId: 'rasg_OTHERa7xKq2mW9tL'))
            .denial,
        CodCollectionDenial.custodyHolderBindingMismatch,
      );
      expect(
        collect(custody: riderCustody(generation: 2)).denial,
        CodCollectionDenial.custodyHolderBindingMismatch,
      );
      expect(
        collect(custody: riderCustody(principalId: otherRiderId)).denial,
        CodCollectionDenial.custodyHolderBindingMismatch,
      );
    });

    test('assignment id and generation are both checked', () {
      expect(
        collect(req: request(assignmentId: 'rasg_OTHERa7xKq2mW9tL')).denial,
        CodCollectionDenial.assignmentIdMismatch,
      );
      expect(
        collect(req: request(generation: 2)).denial,
        CodCollectionDenial.generationMismatch,
      );
    });

    test('missing aggregates fail closed, never defaulted', () {
      expect(
        collect(payPresent: false).denial,
        CodCollectionDenial.paymentAggregateInconsistent,
      );
      expect(
        collect(attemptPresent: false).denial,
        CodCollectionDenial.attemptNotInitialised,
      );
      expect(
        collect(custodyPresent: false).denial,
        CodCollectionDenial.custodyNotInitialised,
      );
      expect(
        collect(riderPresent: false).denial,
        CodCollectionDenial.noAcceptedRiderAssignment,
      );
    });

    test('malformed journal identifiers are refused', () {
      expect(
        collect(req: request(entryId: 'short')).denial,
        CodCollectionDenial.journalReferenceInvalid,
      );
      expect(
        collect(req: request(reference: '1234567890123456789')).denial,
        CodCollectionDenial.journalReferenceInvalid,
      );
    });

    test('a non-UTC timestamp is refused, never converted', () {
      expect(
        collect(req: request(at: DateTime(2026, 9, 11, 14, 5))).denial,
        CodCollectionDenial.timestampNotUtc,
      );
    });
  });

  group('C1 — delivery-state preconditions', () {
    test('cash may only be collected while out for delivery', () {
      for (final DeliveryAttemptState s in <DeliveryAttemptState>[
        DeliveryAttemptState.pending,
        DeliveryAttemptState.refused,
        DeliveryAttemptState.failed,
      ]) {
        expect(
          collect(att: attempt(state: s)).denial,
          CodCollectionDenial.attemptNotOutForDelivery,
          reason: s.id,
        );
      }
    });

    test('the order must be in delivery with a committed reservation', () {
      expect(
        collect(order: orderRead(state: OrderState.ready)).denial,
        CodCollectionDenial.orderNotInDelivery,
      );
      expect(
        collect(order: orderRead(reservation: ReservationState.returned))
            .denial,
        CodCollectionDenial.reservationNotCommitted,
      );
    });

    test('custody must be with a rider', () {
      expect(
        collect(custody: shopCustody()).denial,
        CodCollectionDenial.custodyNotWithRider,
      );
    });

    test('a disputed payment is refused, not collected against', () {
      expect(
        collect(
          pay: payment(state: PaymentState.disputed, collected: bdt(20000)),
        ).denial,
        CodCollectionDenial.paymentDisputed,
      );
    });

    test('a denied collection produces no transition and no journal entry', () {
      for (final CodCollectionOutcome o in <CodCollectionOutcome>[
        collect(req: request(amount: bdt(0))),
        collect(req: request(expectedPaymentRevision: 99)),
        collect(att: attempt(state: DeliveryAttemptState.refused)),
        collect(custodyPresent: false),
      ]) {
        expect(o.allowed, isFalse);
        expect(o.transition, isNull);
      }
    });
  });
}
