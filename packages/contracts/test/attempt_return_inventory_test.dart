import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/attempt_return_fixtures.dart';

/// Every executable transition this slice can produce, as a flat list, so an
/// invariant can be asserted over **all** of them rather than the ones a test
/// author happened to think of.
List<({String label, InventoryEffect inv, bool custody})> allTransitions() {
  final List<({String label, InventoryEffect inv, bool custody})> out =
      <({String label, InventoryEffect inv, bool custody})>[];

  void addAttempt(String label, DeliveryAttemptOutcome o) {
    final DeliveryAttemptTransition? t = o.transition;
    if (t != null) {
      out.add((
        label: label,
        inv: t.inventoryEffect,
        custody: t.changesCustody,
      ));
    }
  }

  void addReturn(String label, ReturnOutcome o) {
    final ReturnTransition? t = o.transition;
    if (t != null) {
      out.add((
        label: label,
        inv: t.inventoryEffect,
        custody: t.changesCustody,
      ));
    }
  }

  addAttempt(
    'out_for_delivery',
    evaluateRecordOutForDelivery(
      request: attemptRequest(),
      grant: riderAttemptGrant(),
      actor: user(riderId),
      resource: resourceContext(),
      attempt: attempt(),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    ),
  );
  addAttempt(
    'refused',
    evaluateRecordDeliveryRefusal(
      request: DeliveryAttemptRefusalRequest(
        attempt: attemptRequest(expectedAttemptRevision: 2),
        expectedReturnRevision: 1,
      ),
      grant: riderAttemptGrant(),
      actor: user(riderId),
      resource: resourceContext(),
      attempt: attempt(revision: 2, state: DeliveryAttemptState.outForDelivery),
      returnRecord: returnRecord(),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    ),
  );
  addAttempt(
    'failed',
    evaluateRecordDeliveryFailure(
      request: attemptRequest(expectedAttemptRevision: 2),
      grant: riderAttemptGrant(),
      actor: user(riderId),
      resource: resourceContext(),
      attempt: attempt(revision: 2, state: DeliveryAttemptState.outForDelivery),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    ),
  );
  addReturn(
    'begin_transit',
    evaluateBeginReturnTransit(
      request: ReturnBeginTransitRequest(
        expectedReturnRevision: 2,
        expectedOrderRevision: 7,
        recordedAtUtc: utcNow,
      ),
      grant: adminReturnGrant(),
      actor: user(adminId),
      resource: resourceContext(),
      attempt: attempt(revision: 3, state: DeliveryAttemptState.refused),
      returnRecord: returnRecord(revision: 2, state: ReturnState.required),
      orderRead: orderRead(),
      custody: riderCustody(),
    ),
  );
  addReturn(
    'shop_receipt',
    evaluateRecordReturnShopReceipt(
      request: ReturnShopReceiptRequest(
        expectedReturnRevision: 3,
        expectedOrderRevision: 7,
        expectedCustodyRevision: 4,
        expectedRiderSlotRevision: 2,
        recordedAtUtc: utcNow,
      ),
      grant: agentReceiptGrant(),
      actor: user(agentId),
      resource: resourceContext(),
      returnRecord: returnRecord(revision: 3, state: ReturnState.inTransit),
      orderRead: orderRead(),
      custody: riderCustody(),
      riderAssignment: riderAssignment(),
    ),
  );
  for (final ReturnDisposition d in ReturnDisposition.values) {
    addReturn(
      'inspected_${d.id}',
      evaluateRecordReturnInspection(
        request: ReturnInspectionRequest(
          expectedReturnRevision: 4,
          expectedOrderRevision: 7,
          disposition: d,
          recordedAtUtc: utcNow,
        ),
        grant: adminReturnGrant(),
        actor: user(adminId),
        resource: resourceContext(),
        returnRecord: returnRecord(revision: 4, state: ReturnState.received),
        orderRead: orderRead(),
        custody: shopCustody(),
      ),
    );
  }
  addReturn(
    'closed',
    evaluateCloseReturn(
      request: ReturnCloseRequest(
        expectedReturnRevision: 5,
        expectedOrderRevision: 8,
        recordedAtUtc: utcNow,
      ),
      grant: adminReturnGrant(),
      actor: user(adminId),
      resource: resourceContext(),
      returnRecord: returnRecord(
        revision: 5,
        state: ReturnState.inspected,
        disposition: ReturnDisposition.restockable,
      ),
      orderRead: orderRead(revision: 8, reservation: ReservationState.returned),
    ),
  );
  return out;
}

void main() {
  group('RET — the restock invariant, swept over every transition', () {
    test('every executable transition was produced', () {
      // Seven distinct edges — three attempt, four return — with inspection
      // sampled once per disposition, so nine transitions in total. If an edge
      // stops being reachable this sweep would silently weaken, so the count
      // and the labels are both pinned.
      final List<String> labels = allTransitions()
          .map(
            (({String label, InventoryEffect inv, bool custody}) t) => t.label,
          )
          .toList();
      expect(labels, <String>[
        'out_for_delivery',
        'refused',
        'failed',
        'begin_transit',
        'shop_receipt',
        'inspected_restockable',
        'inspected_damaged',
        'inspected_quarantined',
        'closed',
      ]);
      expect(labels.length, 9);
    });

    test('exactly one transition increases available stock', () {
      final List<String> restoring = allTransitions()
          .where(
            (({String label, InventoryEffect inv, bool custody}) t) =>
                t.inv.availableStockDelta > 0,
          )
          .map(
            (({String label, InventoryEffect inv, bool custody}) t) => t.label,
          )
          .toList();
      expect(restoring, <String>['inspected_restockable']);
    });

    test('nothing anywhere decreases available stock', () {
      // This slice restores; it never reserves. A negative delta here would
      // mean the return path had started consuming stock.
      for (final ({String label, InventoryEffect inv, bool custody}) t
          in allTransitions()) {
        expect(
          t.inv.availableStockDelta,
          greaterThanOrEqualTo(0),
          reason: t.label,
        );
      }
    });

    test('refusal, failure, transit and receipt all restore nothing', () {
      const Set<String> mustNotRestore = <String>{
        'out_for_delivery',
        'refused',
        'failed',
        'begin_transit',
        'shop_receipt',
        'inspected_damaged',
        'inspected_quarantined',
        'closed',
      };
      for (final ({String label, InventoryEffect inv, bool custody}) t
          in allTransitions()) {
        if (mustNotRestore.contains(t.label)) {
          expect(t.inv.kind, InventoryEffectKind.none, reason: t.label);
          expect(t.inv.availableStockDelta, 0, reason: t.label);
        }
      }
    });

    test('exactly one transition moves custody', () {
      final List<String> moving = allTransitions()
          .where(
            (({String label, InventoryEffect inv, bool custody}) t) =>
                t.custody,
          )
          .map(
            (({String label, InventoryEffect inv, bool custody}) t) => t.label,
          )
          .toList();
      expect(moving, <String>['shop_receipt']);
    });

    test('a restoring effect always moves a positive whole unit count', () {
      for (final ({String label, InventoryEffect inv, bool custody}) t
          in allTransitions()) {
        if (t.inv.kind == InventoryEffectKind.none) {
          expect(t.inv.units, 0, reason: t.label);
        } else {
          expect(t.inv.units, greaterThan(0), reason: t.label);
        }
      }
    });
  });

  group('ReservationState.returned is distinct from released', () {
    test('it is terminal, holds no units and cannot expire', () {
      const ReservationState r = ReservationState.returned;
      expect(r.holdsUnits, isFalse);
      expect(r.isFinal, isTrue);
      expect(r.isExpirable, isFalse);
      expect(r.id, 'returned');
      expect(ReservationState.byId('returned'), ReservationState.returned);
    });

    test('it is not released, and released keeps its own meaning', () {
      expect(ReservationState.returned, isNot(ReservationState.released));
      // `released` still promises the units went back to available stock.
      expect(ReservationState.released.holdsUnits, isFalse);
      // The four pre-existing values are untouched.
      expect(ReservationState.values.length, 5);
    });

    test('in_delivery pairs with both committed and returned', () {
      // After a refused delivery whose goods came back and were inspected, the
      // order is still `in_delivery` while its reservation has ended.
      expect(canonicalAggregatePairs[OrderState.inDelivery], <ReservationState>{
        ReservationState.committed,
        ReservationState.returned,
      });
      expect(
        validateAggregate(
          const OrderLifecycleFacts(
            state: OrderState.inDelivery,
            revision: 9,
            reservationState: ReservationState.returned,
            reservedUnits: 3,
          ),
        ),
        isNull,
      );
    });

    test('returned is not canonical for any pre-dispatch state', () {
      for (final OrderState s in OrderState.executableInThisSlice) {
        expect(
          canonicalAggregatePairs[s],
          isNot(contains(ReservationState.returned)),
          reason: s.id,
        );
      }
    });

    test('no pre-dispatch command can produce a returned reservation', () {
      final Set<ReservationState> reached = <ReservationState>{};
      for (final OrderState from in OrderState.executableInThisSlice) {
        for (final ReservationState r in ReservationState.values) {
          for (final LifecycleCommand c in LifecycleCommand.values) {
            final LifecycleOutcome o = evaluateOrderTransition(
              request: LifecycleRequest(
                command: c,
                expectedRevision: 3,
                requestedUnits: 2,
                reservationSecured: true,
              ),
              facts: OrderLifecycleFacts(
                state: from,
                revision: 3,
                reservationState: r,
                reservedUnits: 2,
              ),
            );
            final ReservationState? to = o.transition?.toReservation;
            if (to != null) {
              reached.add(to);
            }
          }
        }
      }
      expect(reached, isNot(contains(ReservationState.returned)));
    });
  });

  group('RET — the return is WHOLE-ORDER only (FND-003B3B-FIX-001)', () {
    test('restockable restores exactly the canonical reservedUnits', () {
      // The quantity must come from the validated order aggregate and nowhere
      // else. Swept across several values so a hardcoded constant that happened
      // to match one fixture cannot pass.
      for (final int n in <int>[1, 3, 7, 42]) {
        final ReturnTransition t = evaluateRecordReturnInspection(
          request: ReturnInspectionRequest(
            expectedReturnRevision: 4,
            expectedOrderRevision: 7,
            disposition: ReturnDisposition.restockable,
            recordedAtUtc: utcNow,
          ),
          grant: adminReturnGrant(),
          actor: user(adminId),
          resource: resourceContext(),
          returnRecord: returnRecord(revision: 4, state: ReturnState.received),
          orderRead: orderRead(units: n),
          custody: shopCustody(),
        ).transition!;

        expect(t.inventoryEffect.units, n, reason: 'reservedUnits=$n');
        expect(
          t.inventoryEffect.availableStockDelta,
          n,
          reason: 'reservedUnits=$n',
        );
        expect(t.reservationEffect!.units, n, reason: 'reservedUnits=$n');
      }
    });

    test(
      'damaged and quarantined restore zero whatever the reserved count',
      () {
        for (final int n in <int>[1, 7, 42]) {
          for (final ReturnDisposition d in <ReturnDisposition>[
            ReturnDisposition.damaged,
            ReturnDisposition.quarantined,
          ]) {
            final ReturnTransition t = evaluateRecordReturnInspection(
              request: ReturnInspectionRequest(
                expectedReturnRevision: 4,
                expectedOrderRevision: 7,
                disposition: d,
                recordedAtUtc: utcNow,
              ),
              grant: adminReturnGrant(),
              actor: user(adminId),
              resource: resourceContext(),
              returnRecord: returnRecord(
                revision: 4,
                state: ReturnState.received,
              ),
              orderRead: orderRead(units: n),
              custody: shopCustody(),
            ).transition!;

            expect(
              t.inventoryEffect.availableStockDelta,
              0,
              reason: '${d.id} with reservedUnits=$n',
            );
            // The reservation still ends, and still records the full count it
            // held — the goods are not coming back to this order either way.
            expect(t.reservationEffect!.units, n, reason: d.id);
            expect(t.reservationEffect!.restoresAvailableStock, isFalse);
          }
        }
      },
    );

    test('no public request type carries a caller-controlled quantity', () {
      // A STATIC TYPE assertion, not a string match: the constructor tear-off
      // must remain assignable to exactly this signature. Adding a required
      // `units`/`quantity` parameter, or changing any existing parameter's
      // type, stops this compiling.
      //
      // (`dart:mirrors` would have enumerated the declared fields directly and
      // was tried first — it runs on the VM but the analyzer rejects the import
      // in this package, which would have failed the clean-analyze gate. The
      // type pin below plus the field-declaration scan are the analyzer-clean
      // equivalent.)
      const ReturnInspectionRequest Function({
        required int expectedReturnRevision,
        required int expectedOrderRevision,
        required ReturnDisposition disposition,
        required DateTime recordedAtUtc,
      })
      inspectionCtor = ReturnInspectionRequest.new;
      expect(inspectionCtor, isNotNull);

      const ReturnShopReceiptRequest Function({
        required int expectedReturnRevision,
        required int expectedOrderRevision,
        required int expectedCustodyRevision,
        required int expectedRiderSlotRevision,
        required DateTime recordedAtUtc,
      })
      receiptCtor = ReturnShopReceiptRequest.new;
      expect(receiptCtor, isNotNull);

      // And a structural scan of the DECLARED FIELDS only — the `final X y;`
      // lines of the request source — so prose in a doc comment can neither
      // trigger nor mask this. An added optional field is caught here even
      // though function subtyping would let it past the tear-off pins above.
      final List<String> declaredFields =
          File('lib/src/delivery_attempt_return_request.dart')
              .readAsLinesSync()
              .map((String l) => l.trim())
              .where((String l) => l.startsWith('final ') && l.endsWith(';'))
              .map((String l) => l.substring(6, l.length - 1).trim())
              .map((String d) => d.split(RegExp(r'\s+')).last)
              .toList();

      expect(
        declaredFields,
        isNotEmpty,
        reason: 'the probe found no fields — check the extraction',
      );
      for (final String f in declaredFields) {
        final String lower = f.toLowerCase();
        for (final String bad in <String>[
          'units',
          'quantity',
          'qty',
          'count',
          'amount',
          'items',
          'lines',
        ]) {
          expect(
            lower,
            isNot(contains(bad)),
            reason: 'request field "$f" looks caller-controlled',
          );
        }
      }
    });

    test('exactly one disposition covers the whole reservation', () {
      // Mixed outcomes ("three fine, two broken") are NOT representable, by
      // design. This pins the shape rather than inventing a partial-return type
      // in order to assert its absence.
      //
      // The inspection request takes a single non-null `ReturnDisposition`,
      // pinned statically by the tear-off above; the stored return aggregate
      // holds a single nullable one, never a collection.
      final List<String> returnFactsFields =
          File('lib/src/delivery_attempt_return_facts.dart')
              .readAsLinesSync()
              .map((String l) => l.trim())
              .where((String l) => l.startsWith('final ') && l.endsWith(';'))
              .toList();

      final Iterable<String> dispositionFields = returnFactsFields.where(
        (String l) => l.toLowerCase().contains('disposition'),
      );
      expect(dispositionFields, <String>[
        'final ReturnDisposition? disposition;',
      ], reason: 'one nullable disposition per return, never a collection');

      // A single value reaches the effect, and it covers the whole reservation.
      final ReturnTransition t = evaluateRecordReturnInspection(
        request: ReturnInspectionRequest(
          expectedReturnRevision: 4,
          expectedOrderRevision: 7,
          disposition: ReturnDisposition.damaged,
          recordedAtUtc: utcNow,
        ),
        grant: adminReturnGrant(),
        actor: user(adminId),
        resource: resourceContext(),
        returnRecord: returnRecord(revision: 4, state: ReturnState.received),
        orderRead: orderRead(units: 5),
        custody: shopCustody(),
      ).transition!;
      expect(t.reservationEffect!.disposition, ReturnDisposition.damaged);
      expect(
        t.reservationEffect!.units,
        5,
        reason: 'the single disposition covers all five reserved units',
      );
    });
  });
}
