import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/attempt_return_fixtures.dart';

DeliveryAttemptOutcome outForDelivery({
  DeliveryAttemptRequest? request,
  AuthorizationGrant? grant,
  Principal? actor,
  CustodyResourceContext? resource,
  DeliveryAttemptFacts? attemptFacts,
  AttemptReturnOrderRead? order,
  CustodyFacts? custody,
  RiderAssignmentFacts? rider,
  bool custodyPresent = true,
  bool riderPresent = true,
}) => evaluateRecordOutForDelivery(
  request: request ?? attemptRequest(),
  grant: grant ?? riderAttemptGrant(),
  actor: actor ?? user(riderId),
  resource: resource ?? resourceContext(),
  attempt: attemptFacts ?? attempt(),
  orderRead: order ?? orderRead(),
  custody: custodyPresent ? (custody ?? riderCustody()) : null,
  riderAssignment: riderPresent ? (rider ?? riderAssignment()) : null,
);

DeliveryAttemptOutcome refuse({
  DeliveryAttemptRefusalRequest? request,
  AuthorizationGrant? grant,
  Principal? actor,
  CustodyResourceContext? resource,
  DeliveryAttemptFacts? attemptFacts,
  ReturnFacts? returnFacts,
  AttemptReturnOrderRead? order,
  CustodyFacts? custody,
  RiderAssignmentFacts? rider,
  bool returnPresent = true,
}) => evaluateRecordDeliveryRefusal(
  request:
      request ??
      DeliveryAttemptRefusalRequest(
        attempt: attemptRequest(expectedAttemptRevision: 2),
        expectedReturnRevision: 1,
      ),
  grant: grant ?? riderAttemptGrant(),
  actor: actor ?? user(riderId),
  resource: resource ?? resourceContext(),
  attempt:
      attemptFacts ??
      attempt(revision: 2, state: DeliveryAttemptState.outForDelivery),
  returnRecord: returnPresent ? (returnFacts ?? returnRecord()) : null,
  orderRead: order ?? orderRead(),
  custody: custody ?? riderCustody(),
  riderAssignment: rider ?? riderAssignment(),
);

DeliveryAttemptOutcome fail({
  DeliveryAttemptRequest? request,
  DeliveryAttemptFacts? attemptFacts,
  AttemptReturnOrderRead? order,
}) => evaluateRecordDeliveryFailure(
  request: request ?? attemptRequest(expectedAttemptRevision: 2),
  grant: riderAttemptGrant(),
  actor: user(riderId),
  resource: resourceContext(),
  attempt:
      attemptFacts ??
      attempt(revision: 2, state: DeliveryAttemptState.outForDelivery),
  orderRead: order ?? orderRead(),
  custody: riderCustody(),
  riderAssignment: riderAssignment(),
);

void main() {
  group('ATT — attempt initialisation', () {
    test('creates a pending attempt and a not_required return together', () {
      final DeliveryAttemptInitialisationOutcome o = initialiseDeliveryAttempt(
        resource: resourceContext(),
        attemptId: attemptId,
        existingAttempt: null,
        existingReturn: null,
        orderRead: orderRead(),
        custody: riderCustody(),
      );
      expect(o.allowed, isTrue);
      expect(o.attempt!.state, DeliveryAttemptState.pending);
      expect(o.attempt!.attemptRevision, 1);
      expect(o.attempt!.attemptId, attemptId);
      expect(o.attempt!.resourceId, orderId);
      // "No return is needed" is a written fact, never a missing record.
      expect(o.returnRecord!.state, ReturnState.notRequired);
      expect(o.returnRecord!.returnRevision, 1);
      expect(o.returnRecord!.route, ReturnRoute.riderToShop);
    });

    test('is create-once — an existing attempt is never reset', () {
      // A second `pending` written over a `refused` attempt would erase the
      // refusal that opened a return.
      for (final DeliveryAttemptState s
          in DeliveryAttemptState.executableInThisSlice) {
        final DeliveryAttemptInitialisationOutcome o =
            initialiseDeliveryAttempt(
              resource: resourceContext(),
              attemptId: attemptId,
              existingAttempt: attempt(state: s),
              existingReturn: null,
              orderRead: orderRead(),
              custody: riderCustody(),
            );
        expect(o.allowed, isFalse, reason: 'existing ${s.id}');
        expect(o.denial, AttemptReturnDenial.attemptAlreadyInitialised);
      }
    });

    test('an existing return also blocks initialisation', () {
      final DeliveryAttemptInitialisationOutcome o = initialiseDeliveryAttempt(
        resource: resourceContext(),
        attemptId: attemptId,
        existingAttempt: null,
        existingReturn: returnRecord(),
        orderRead: orderRead(),
        custody: riderCustody(),
      );
      expect(o.denial, AttemptReturnDenial.attemptAlreadyInitialised);
    });

    test('requires dispatch to have actually happened', () {
      // Order not in delivery.
      expect(
        initialiseDeliveryAttempt(
          resource: resourceContext(),
          attemptId: attemptId,
          existingAttempt: null,
          existingReturn: null,
          orderRead: orderRead(state: OrderState.ready),
          custody: riderCustody(),
        ).denial,
        AttemptReturnDenial.orderNotInDelivery,
      );
      // Custody still at the shop: nobody is carrying anything.
      expect(
        initialiseDeliveryAttempt(
          resource: resourceContext(),
          attemptId: attemptId,
          existingAttempt: null,
          existingReturn: null,
          orderRead: orderRead(),
          custody: shopCustody(),
        ).denial,
        AttemptReturnDenial.custodyNotWithRider,
      );
      // Absence is never read as "the shop still has it".
      expect(
        initialiseDeliveryAttempt(
          resource: resourceContext(),
          attemptId: attemptId,
          existingAttempt: null,
          existingReturn: null,
          orderRead: orderRead(),
          custody: null,
        ).denial,
        AttemptReturnDenial.custodyNotInitialised,
      );
    });

    test('a sequential or malformed attempt id is refused', () {
      for (final String bad in <String>['', 'short', '1234567890123456789']) {
        expect(
          initialiseDeliveryAttempt(
            resource: resourceContext(),
            attemptId: bad,
            existingAttempt: null,
            existingReturn: null,
            orderRead: orderRead(),
            custody: riderCustody(),
          ).denial,
          AttemptReturnDenial.aggregateInconsistent,
          reason: 'attemptId "$bad"',
        );
      }
    });

    test('there is no command and no permission for initialisation', () {
      // A client command whose only purpose is to manufacture trusted server
      // state is exactly the arbitrary status patch this contract forbids.
      for (final DeliveryAttemptCommand c in DeliveryAttemptCommand.values) {
        expect(c.commandType, isNot(contains('init')));
        expect(c.commandType, isNot(contains('create')));
      }
      for (final Permission p in Permission.values) {
        expect(p.id, isNot(contains('attempt.create')));
        expect(p.id, isNot(contains('attempt.init')));
      }
    });
  });

  group('ATT — pending -> out_for_delivery', () {
    test('is allowed and advances only the attempt revision', () {
      final DeliveryAttemptOutcome o = outForDelivery();
      expect(o.allowed, isTrue);
      final DeliveryAttemptTransition t = o.transition!;
      expect(t.fromState, DeliveryAttemptState.pending);
      expect(t.toState, DeliveryAttemptState.outForDelivery);
      expect(t.resultingAttemptRevision, 2);
      expect(t.attemptId, attemptId);
      // Nothing else moves.
      expect(t.changesOrder, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.returnRequirement, isNull);
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(t.events, <String>[DeliveryAttemptEventType.outForDelivery]);
    });

    test('cannot act from any state but pending', () {
      for (final DeliveryAttemptState s
          in DeliveryAttemptState.executableInThisSlice) {
        if (s == DeliveryAttemptState.pending) {
          continue;
        }
        final DeliveryAttemptOutcome o = outForDelivery(
          attemptFacts: attempt(state: s),
        );
        expect(o.allowed, isFalse, reason: s.id);
        expect(o.denial, AttemptReturnDenial.attemptNotInRequiredState);
      }
    });
  });

  group('ATT — out_for_delivery -> refused opens the return', () {
    test('both halves happen in one transition', () {
      final DeliveryAttemptOutcome o = refuse();
      expect(o.allowed, isTrue);
      final DeliveryAttemptTransition t = o.transition!;
      expect(t.toState, DeliveryAttemptState.refused);
      expect(t.resultingAttemptRevision, 3);
      // The return requirement is opened atomically.
      final ReturnRequirementEffect r = t.returnRequirement!;
      expect(r.fromState, ReturnState.notRequired);
      expect(r.toState, ReturnState.required);
      expect(r.resultingReturnRevision, 2);
      expect(r.route, ReturnRoute.riderToShop);
      expect(t.events, <String>[
        DeliveryAttemptEventType.refused,
        ReturnEventType.required,
      ]);
    });

    test('refusal touches nothing else at all', () {
      final DeliveryAttemptTransition t = refuse().transition!;
      // The order is not delivered and not cancelled.
      expect(t.changesOrder, isFalse);
      // Custody stays with the rider.
      expect(t.changesCustody, isFalse);
      // No stock is restored — the goods are in a bag, not on a shelf.
      expect(t.inventoryEffect.kind, InventoryEffectKind.none);
      expect(t.inventoryEffect.availableStockDelta, 0);
      // Money is UNKNOWN, never zero.
      expect(
        t.financialClassification,
        FinancialClassification.deferredToFinancialSlice,
      );
      // No rider-completion effect can even be expressed on this type.
      expect(t.toString(), isNot(contains('completed')));
    });

    test('a replayed refusal cannot advance the return twice', () {
      // The attempt is already refused and the return already required.
      final DeliveryAttemptOutcome o = refuse(
        attemptFacts: attempt(revision: 3, state: DeliveryAttemptState.refused),
        request: DeliveryAttemptRefusalRequest(
          attempt: attemptRequest(expectedAttemptRevision: 3),
          expectedReturnRevision: 2,
        ),
        returnFacts: returnRecord(revision: 2, state: ReturnState.required),
      );
      expect(o.allowed, isFalse);
      expect(o.denial, AttemptReturnDenial.attemptNotInRequiredState);
    });

    test('a stale return revision refuses the whole transition', () {
      final DeliveryAttemptOutcome o = refuse(
        request: DeliveryAttemptRefusalRequest(
          attempt: attemptRequest(expectedAttemptRevision: 2),
          expectedReturnRevision: 99,
        ),
      );
      expect(o.denial, AttemptReturnDenial.returnRevisionConflict);
    });

    test('a missing return record fails closed, never defaulted', () {
      expect(
        refuse(returnPresent: false).denial,
        AttemptReturnDenial.returnNotInitialised,
      );
    });

    test('a return already past not_required cannot be re-opened', () {
      for (final ReturnState s in <ReturnState>[
        ReturnState.required,
        ReturnState.inTransit,
        ReturnState.received,
      ]) {
        final DeliveryAttemptOutcome o = refuse(
          returnFacts: returnRecord(revision: 1, state: s),
        );
        expect(
          o.denial,
          AttemptReturnDenial.returnNotInRequiredState,
          reason: s.id,
        );
      }
    });
  });

  group('ATT — out_for_delivery -> failed invents no policy', () {
    test('records the fact and nothing else', () {
      final DeliveryAttemptOutcome o = fail();
      expect(o.allowed, isTrue);
      final DeliveryAttemptTransition t = o.transition!;
      expect(t.toState, DeliveryAttemptState.failed);
      expect(t.returnRequirement, isNull, reason: 'no return was fabricated');
      expect(t.changesOrder, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.inventoryEffect.availableStockDelta, 0);
      // Unknown, never zero.
      expect(
        t.financialClassification,
        FinancialClassification.deferredToFinancialSlice,
      );
      expect(t.events, <String>[DeliveryAttemptEventType.failed]);
    });

    test('the failure evaluator cannot even see the return facts', () {
      // Structural, not documentary: `evaluateRecordDeliveryFailure` has no
      // return parameter, so no future edit can open a return from it without
      // changing the signature — which is a reviewable event.
      final DeliveryAttemptTransition t = fail().transition!;
      expect(t.returnRequirement, isNull);
    });

    test('the post-failure consequence is enumerated and always refused', () {
      final DeliveryAttemptOutcome o = evaluateFailedAttemptReturnDecision();
      expect(o.allowed, isFalse);
      expect(o.transition, isNull);
      expect(o.denial, AttemptReturnDenial.failureReturnPolicyDeferred);
    });
  });

  group('ATT — concurrency and binding', () {
    test('every read aggregate is compare-and-set', () {
      expect(
        outForDelivery(request: attemptRequest(expectedAttemptRevision: 99))
            .denial,
        AttemptReturnDenial.attemptRevisionConflict,
      );
      expect(
        outForDelivery(request: attemptRequest(expectedOrderRevision: 99))
            .denial,
        AttemptReturnDenial.orderRevisionConflict,
      );
      expect(
        outForDelivery(request: attemptRequest(expectedCustodyRevision: 99))
            .denial,
        AttemptReturnDenial.custodyRevisionConflict,
      );
      expect(
        outForDelivery(request: attemptRequest(expectedRiderSlotRevision: 99))
            .denial,
        AttemptReturnDenial.riderSlotRevisionConflict,
      );
    });

    test('a cross-resource read fails closed on every aggregate', () {
      expect(
        outForDelivery(attemptFacts: attempt(resourceId: otherOrderId)).denial,
        AttemptReturnDenial.resourceBindingMismatch,
      );
      expect(
        outForDelivery(order: orderRead(resourceId: otherOrderId)).denial,
        AttemptReturnDenial.resourceBindingMismatch,
      );
      expect(
        outForDelivery(custody: riderCustody(resourceId: otherOrderId)).denial,
        AttemptReturnDenial.resourceBindingMismatch,
      );
      expect(
        outForDelivery(rider: riderAssignment(resourceId: otherOrderId)).denial,
        AttemptReturnDenial.resourceBindingMismatch,
      );
    });

    test('a different rider cannot act on this order', () {
      expect(
        outForDelivery(
          grant: riderAttemptGrant(principalId: otherRiderId),
          actor: user(otherRiderId),
        ).denial,
        AttemptReturnDenial.notCurrentAcceptedRider,
      );
    });

    test('custody bound to another attempt fails closed', () {
      // Goods carried under attempt A must not be acted on as though attempt B
      // were carrying them.
      expect(
        outForDelivery(
          custody: riderCustody(assignmentId: 'rasg_OTHER7xKq2mW9tLp'),
        ).denial,
        AttemptReturnDenial.custodyHolderBindingMismatch,
      );
      expect(
        outForDelivery(custody: riderCustody(generation: 2)).denial,
        AttemptReturnDenial.custodyHolderBindingMismatch,
      );
    });

    test('the order must be in delivery with a committed reservation', () {
      expect(
        outForDelivery(order: orderRead(state: OrderState.ready)).denial,
        AttemptReturnDenial.orderNotInDelivery,
      );
      expect(
        outForDelivery(order: orderRead(reservation: ReservationState.returned))
            .denial,
        AttemptReturnDenial.reservationNotCommitted,
      );
    });

    test('a non-UTC timestamp is refused, never converted', () {
      final DeliveryAttemptOutcome o = outForDelivery(
        request: attemptRequest(at: DateTime(2026, 9, 11, 10, 30)),
      );
      expect(o.denial, AttemptReturnDenial.timestampNotUtc);
    });

    test('a system worker cannot witness a physical event', () {
      // The grant is real but names the worker, so the binding is intact and
      // the refusal is about the *kind* of principal.
      final DeliveryAttemptOutcome o = outForDelivery(
        actor: worker(),
        grant: riderAttemptGrant(),
      );
      expect(o.allowed, isFalse);
      expect(
        o.denial,
        anyOf(
          AttemptReturnDenial.authorizationGrantMismatch,
          AttemptReturnDenial.actorNotHumanPrincipal,
        ),
      );
    });

    test('missing custody or rider assignment fails closed', () {
      expect(
        outForDelivery(custodyPresent: false).denial,
        AttemptReturnDenial.custodyNotInitialised,
      );
      expect(
        outForDelivery(riderPresent: false).denial,
        AttemptReturnDenial.noAcceptedRiderAssignment,
      );
    });

    test('a denied attempt produces no transition at all', () {
      for (final DeliveryAttemptOutcome o in <DeliveryAttemptOutcome>[
        outForDelivery(request: attemptRequest(expectedAttemptRevision: 99)),
        outForDelivery(attemptFacts: attempt(resourceId: otherOrderId)),
        outForDelivery(custodyPresent: false),
        refuse(returnPresent: false),
        evaluateRecordDelivered(),
      ]) {
        expect(o.allowed, isFalse);
        expect(o.transition, isNull);
      }
    });
  });
}
