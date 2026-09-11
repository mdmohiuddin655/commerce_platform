import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/attempt_return_fixtures.dart';

/// Every FND-003B3B production source, read as text. Source scanning is how
/// this repository proves a *negative* — that a vocabulary does not exist —
/// which no amount of behavioural testing can show.
List<File> b3bSources() => <String>[
  'delivery_attempt_state.dart',
  'delivery_attempt_command.dart',
  'delivery_attempt_return_authorization.dart',
  'delivery_attempt_return_denial.dart',
  'delivery_attempt_return_effect.dart',
  'delivery_attempt_return_evaluator.dart',
  'delivery_attempt_return_facts.dart',
  'delivery_attempt_return_request.dart',
  'delivery_attempt_return_transition.dart',
  'delivery_attempt_return_validation.dart',
  'delivery_attempt_return.dart',
  'return_command.dart',
  'return_state.dart',
].map((String f) => File('lib/src/$f')).toList();

/// Code only: comments are stripped, so prose *describing* what was not built
/// cannot be mistaken for the thing itself.
String codeOf(File f) => f
    .readAsLinesSync()
    .where((String l) {
      final String t = l.trimLeft();
      return !t.startsWith('///') && !t.startsWith('//');
    })
    .join('\n');

void main() {
  group('successful delivery is still not executable', () {
    test('recordDelivered is enumerated and always refused', () {
      final DeliveryAttemptOutcome o = evaluateRecordDelivered();
      expect(o.allowed, isFalse);
      expect(o.transition, isNull);
      expect(o.denial, AttemptReturnDenial.deliveryProofPolicyDeferred);
    });

    test('the delivered evaluator takes no facts at all', () {
      // Zero arguments is the structural point: there is no read-set, because
      // there is no decision to make. A signature accepting facts would invite
      // "just add the obvious edge" using them.
      expect(evaluateRecordDelivered(), isA<DeliveryAttemptOutcome>());
    });

    test('delivered is excluded from the executable command set', () {
      expect(
        DeliveryAttemptCommand.executableInThisSlice,
        isNot(contains(DeliveryAttemptCommand.recordDelivered)),
      );
      expect(DeliveryAttemptCommand.executableInThisSlice.length, 3);
    });

    test('no attempt transition can produce delivered', () {
      // Sweep every executable attempt edge over every canonical source state
      // and assert `delivered` is never reached.
      final Set<DeliveryAttemptState> reached = <DeliveryAttemptState>{};
      for (final DeliveryAttemptState from
          in DeliveryAttemptState.executableInThisSlice) {
        final List<DeliveryAttemptOutcome> outcomes = <DeliveryAttemptOutcome>[
          evaluateRecordOutForDelivery(
            request: attemptRequest(),
            grant: riderAttemptGrant(),
            actor: user(riderId),
            resource: resourceContext(),
            attempt: attempt(state: from),
            orderRead: orderRead(),
            custody: riderCustody(),
            riderAssignment: riderAssignment(),
          ),
          evaluateRecordDeliveryFailure(
            request: attemptRequest(),
            grant: riderAttemptGrant(),
            actor: user(riderId),
            resource: resourceContext(),
            attempt: attempt(state: from),
            orderRead: orderRead(),
            custody: riderCustody(),
            riderAssignment: riderAssignment(),
          ),
          evaluateRecordDeliveryRefusal(
            request: DeliveryAttemptRefusalRequest(
              attempt: attemptRequest(),
              expectedReturnRevision: 1,
            ),
            grant: riderAttemptGrant(),
            actor: user(riderId),
            resource: resourceContext(),
            attempt: attempt(state: from),
            returnRecord: returnRecord(),
            orderRead: orderRead(),
            custody: riderCustody(),
            riderAssignment: riderAssignment(),
          ),
          evaluateRecordDelivered(),
        ];
        for (final DeliveryAttemptOutcome o in outcomes) {
          if (o.transition != null) {
            reached.add(o.transition!.toState);
          }
        }
      }
      expect(reached, isNot(contains(DeliveryAttemptState.delivered)));
      expect(DeliveryAttemptState.notYetImplemented, <DeliveryAttemptState>{
        DeliveryAttemptState.delivered,
      });
    });

    test('a stored delivered attempt is corruption, not a readable state', () {
      expect(
        validateDeliveryAttemptAggregate(
          attempt(state: DeliveryAttemptState.delivered),
        ),
        AttemptReturnDenial.aggregateInconsistent,
      );
    });

    test('OrderState.delivered is still unreachable and unpaired', () {
      expect(OrderState.notYetImplemented, contains(OrderState.delivered));
      expect(
        canonicalAggregatePairs.containsKey(OrderState.delivered),
        isFalse,
      );
    });

    test('a satisfied assessment is not consumed as delivery authority', () {
      // No B3B source references the assessment verdict at all: "a proof
      // result exists" and "the policy is satisfied" are different claims.
      for (final File f in b3bSources()) {
        final String code = codeOf(f);
        expect(
          code,
          isNot(contains('DeliveryProofAssessmentVerdict')),
          reason: f.path,
        );
        expect(code, isNot(contains('satisfied')), reason: f.path);
      }
    });
  });

  group('customer custody and rider completion stay unreachable', () {
    test('no B3B code references customer custody', () {
      for (final File f in b3bSources()) {
        expect(
          codeOf(f),
          isNot(contains('CustodyHolderKind.customer')),
          reason: f.path,
        );
      }
      expect(
        CustodyHolderKind.notYetImplemented,
        contains(CustodyHolderKind.customer),
      );
    });

    test('no B3B code completes a rider assignment — B3-C2 stays FUTURE', () {
      for (final File f in b3bSources()) {
        final String code = codeOf(f);
        expect(
          code,
          isNot(contains('AssignmentState.completed')),
          reason: f.path,
        );
      }
      // And the cost of that state is still not invented.
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
      );
    });

    test('no return transition can move custody anywhere but the shop', () {
      final ReturnOutcome o = evaluateRecordReturnShopReceipt(
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
      );
      expect(
        o.transition!.custodyEffect!.toHolder.kind,
        CustodyHolderKind.shop,
      );
    });
  });

  group('undecided policy is refused, never defaulted', () {
    test('the via-picker route is enumerated and always refused', () {
      final ReturnOutcome o = evaluateReturnViaPicker();
      expect(o.allowed, isFalse);
      expect(o.transition, isNull);
      expect(o.denial, AttemptReturnDenial.returnRouteNotImplemented);
      expect(
        ReturnRoute.executableInThisSlice,
        isNot(contains(ReturnRoute.riderToPickerToShop)),
      );
    });

    test('a stored via-picker return cannot be walked as a direct one', () {
      final ReturnOutcome o = evaluateBeginReturnTransit(
        request: ReturnBeginTransitRequest(
          expectedReturnRevision: 2,
          expectedOrderRevision: 7,
          recordedAtUtc: utcNow,
        ),
        grant: adminReturnGrant(),
        actor: user(adminId),
        resource: resourceContext(),
        attempt: attempt(revision: 3, state: DeliveryAttemptState.refused),
        returnRecord: returnRecord(
          revision: 2,
          state: ReturnState.required,
          route: ReturnRoute.riderToPickerToShop,
        ),
        orderRead: orderRead(),
        custody: riderCustody(),
      );
      expect(o.denial, AttemptReturnDenial.returnRouteNotImplemented);
    });

    test('the post-failure consequence is refused, not guessed', () {
      expect(
        evaluateFailedAttemptReturnDecision().denial,
        AttemptReturnDenial.failureReturnPolicyDeferred,
      );
    });

    test(
      'the three deferred denials are distinct from every "not allowed"',
      () {
        // "Nobody has decided" and "you may not" must never collapse into one
        // value — the precedent is LifecycleDenial.policyDeferred.
        final Set<AttemptReturnDenial> deferred = <AttemptReturnDenial>{
          AttemptReturnDenial.deliveryProofPolicyDeferred,
          AttemptReturnDenial.failureReturnPolicyDeferred,
          AttemptReturnDenial.returnRouteNotImplemented,
        };
        expect(deferred.length, 3);
        expect(
          deferred,
          isNot(contains(AttemptReturnDenial.unknownTransition)),
        );
      },
    );
  });

  group('no money, fault or liability vocabulary was invented', () {
    test('no B3B source contains a money or liability token', () {
      // `minorunits` rather than `currency`: an earlier slice learned that
      // scanning for "currency" also matches "concurrency" in its own prose.
      const List<String> forbidden = <String>[
        'minorunits',
        'amount',
        'refund',
        'fee',
        'commission',
        'settlement',
        'liable',
        'liability',
        'compensat',
        'penalt',
        'charge',
        'invoice',
        'payout',
      ];
      for (final File f in b3bSources()) {
        final String code = codeOf(f).toLowerCase();
        for (final String token in forbidden) {
          expect(
            code,
            isNot(contains(token)),
            reason: '${f.path} contains "$token"',
          );
        }
      }
    });

    test('refusal and failure classify money as UNKNOWN, never zero', () {
      final DeliveryAttemptTransition refusal = evaluateRecordDeliveryRefusal(
        request: DeliveryAttemptRefusalRequest(
          attempt: attemptRequest(expectedAttemptRevision: 2),
          expectedReturnRevision: 1,
        ),
        grant: riderAttemptGrant(),
        actor: user(riderId),
        resource: resourceContext(),
        attempt: attempt(
          revision: 2,
          state: DeliveryAttemptState.outForDelivery,
        ),
        returnRecord: returnRecord(),
        orderRead: orderRead(),
        custody: riderCustody(),
        riderAssignment: riderAssignment(),
      ).transition!;
      expect(
        refusal.financialClassification,
        FinancialClassification.deferredToFinancialSlice,
      );
    });

    test('disposition decides inventory only, never fault', () {
      // Three values, and the only question any of them answers.
      expect(ReturnDisposition.values.length, 3);
      expect(ReturnDisposition.restockable.restoresAvailableStock, isTrue);
      expect(ReturnDisposition.damaged.restoresAvailableStock, isFalse);
      expect(ReturnDisposition.quarantined.restoresAvailableStock, isFalse);
      for (final ReturnDisposition d in ReturnDisposition.values) {
        expect(d.id, isNot(contains('fault')));
        expect(d.id, isNot(contains('customer')));
        expect(d.id, isNot(contains('rider')));
      }
    });
  });

  group('no proof mechanism was invented', () {
    test('no B3B source mentions any evidence mechanism', () {
      const List<String> mechanisms = <String>[
        'otp',
        'qrcode',
        'qr_code',
        'signature',
        'photo',
        'gps',
        'latitude',
        'longitude',
        'biometric',
        'fingerprint',
        'selfie',
        'barcode',
        'pincode',
      ];
      for (final File f in b3bSources()) {
        final String code = codeOf(f).toLowerCase();
        for (final String m in mechanisms) {
          expect(code, isNot(contains(m)), reason: '${f.path} contains "$m"');
        }
      }
    });
  });

  group('no arbitrary status setter exists', () {
    test('every command is a named operation, not a state argument', () {
      for (final DeliveryAttemptCommand c in DeliveryAttemptCommand.values) {
        expect(
          c.commandType,
          matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
        );
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('set_state')));
        expect(c.commandType, isNot(contains('patch')));
      }
      for (final ReturnCommand c in ReturnCommand.values) {
        expect(
          c.commandType,
          matches(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
        );
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('set_state')));
        expect(c.commandType, isNot(contains('patch')));
      }
    });

    test('no request type carries a target state', () {
      // A caller names an operation; it never supplies the state it wants.
      for (final File f in <File>[
        File('lib/src/delivery_attempt_return_request.dart'),
      ]) {
        final String code = codeOf(f);
        expect(code, isNot(contains('DeliveryAttemptState ')));
        expect(code, isNot(contains('ReturnState ')));
      }
    });
  });

  group('no serialization and no persistence was added', () {
    test('no B3B source has toJson, fromJson or a Firebase reference', () {
      for (final File f in b3bSources()) {
        final String code = codeOf(f);
        for (final String token in <String>[
          'toJson',
          'fromJson',
          'Firebase',
          'Firestore',
          'cloud_firestore',
          'http',
        ]) {
          expect(code, isNot(contains(token)), reason: '${f.path}: $token');
        }
      }
    });

    test('the contract version is 0.11 and the major did not move', () {
      // B3B shipped at 0.10; FND-003C1 then added the COD collection contract
      // additively, so the build reports 0.11 and nothing B3B defined moved.
      expect(ContractVersion.current, const ContractVersion(0, 11));
      expect(ContractVersion.current.major, 0);
      expect(
        ContractVersion.current.isVersionCompatibleWith(
          const ContractVersion(0, 9),
        ),
        isTrue,
      );
    });
  });
}
