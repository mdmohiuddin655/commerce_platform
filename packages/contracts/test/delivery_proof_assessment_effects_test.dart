import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';

void main() {
  group('every commercial effect is NONE', () {
    test('satisfied moves nothing', () {
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
      expect(t.inventoryEffect, const InventoryEffect.none());
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.financialClassification,
          FinancialClassification.noneInThisSlice);
      expect(t.scopeEffect.isEmpty, isTrue);
    });

    test('notSatisfied moves exactly as little', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(t.financialClassification,
          FinancialClassification.noneInThisSlice);
      expect(t.scopeEffect.isEmpty, isTrue);
    });

    test('the surrounding aggregates are untouched', () {
      final OrderLifecycleFacts order = inDelivery();
      final CustodyFacts custody = withRider();
      final RiderAssignmentFacts rider = riderInDelivery();
      allowed(run(order: order, custody: custody, riderFacts: rider));

      expect(order.state, OrderState.inDelivery);
      expect(order.revision, 5);
      expect(order.reservationState, ReservationState.committed);
      expect(custody.holder.kind, CustodyHolderKind.rider);
      expect(custody.custodyRevision, 3);
      expect(rider.attempt!.state, AssignmentState.accepted);
      expect(rider.slotRevision, 2);
    });

    test('a satisfied assessment does not deliver the order', () {
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.toString(), isNot(contains('delivered')));
      expect(
        OrderState.notYetImplemented.contains(OrderState.delivered),
        isTrue,
      );
      expect(
        OrderState.aggregateShapeKnown.contains(OrderState.delivered),
        isFalse,
      );
      expect(canonicalAggregatePairs.containsKey(OrderState.delivered), isFalse);
    });

    test('notSatisfied opens no dispute, cancellation, return or charge', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      for (final String forbidden in <String>[
        'dispute',
        'cancel',
        'refus',
        'return',
        'fee',
        'charge',
        'refund',
        'cod',
        'settle',
      ]) {
        expect(t.events.single, isNot(contains(forbidden)));
      }
      expect(t.inventoryEffect.availableStockDelta, 0,
          reason: 'failure never restores inventory');
    });

    test('no money vocabulary exists anywhere in the assessment module', () {
      for (final String path in assessmentSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'money',
          'amount',
          'currency',
          'fee',
          'refund',
          'commission',
          'liability',
          'posting',
          'settlement',
          'remittance',
          'cod',
        ]) {
          // Whole-word, so `concurrency` does not read as `currency`.
          expect(
            RegExp('\\b$forbidden\\b').hasMatch(api),
            isFalse,
            reason: '"$forbidden" in $path is FND-003C\'s, blocked on O6',
          );
        }
      }
    });
  });

}
