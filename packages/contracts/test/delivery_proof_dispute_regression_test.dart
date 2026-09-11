import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';
import 'support/delivery_proof_assessment_fixtures.dart';
import 'support/delivery_proof_dispute_fixtures.dart';

void main() {
  group('no proof mechanism became executable', () {
    test('no mechanism is declared in any dispute file', () {
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String mechanism in proofMechanisms) {
          expect(
            code,
            isNot(contains(mechanism)),
            reason: '"$mechanism" must not be declared by $path',
          );
        }
      }
    });

    test('the mechanism scanner actually detects a planted declaration', () {
      // Negative control. Without this, the guard above proves only that the
      // scan ran — not that it can fail. A planted declaration must be caught,
      // and prose in a doc comment must NOT be, or the guard would trip on the
      // very text that rules mechanisms out.
      const String planted = '''
/// This comment mentions otp and a signature and must not trip the scan.
class Sample {
  final String otpCode = 'x';
}
''';
      final String plantedCode = codeOnly(planted);
      expect(plantedCode, contains('otp'));
      expect(
        plantedCode,
        isNot(contains('signature')),
        reason: 'doc-comment prose is stripped, so only declarations count',
      );
    });

    test('the dispute contract holds no evidence or policy reference at all',
        () {
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'deliveryevidenceref',
          'deliveryproofpolicyref',
          'evidenceid',
          'policyref',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: 'a dispute points at an assessment; it copies nothing '
                'from it ($path)',
          );
        }
      }
    });
  });

  group('no financial consequence was decided', () {
    test('no money vocabulary is declared in any dispute file', () {
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in financialVocabulary) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '"$forbidden" would decide something FND-003C owns, and '
                'FND-003C is blocked on owner decision O6 ($path)',
          );
        }
      }
    });

    test('the money scanner actually detects a planted declaration', () {
      const String planted = '''
/// This comment mentions a refund and a commission.
class Sample {
  final int refundMinorUnits = 0;
}
''';
      final String code = codeOnly(planted);
      expect(code, contains('refund'));
      expect(code, isNot(contains('commission')));
    });

    test('O6 is untouched: the classification says recording, not zero', () {
      // `noneInThisSlice` classifies the *recording*. Whether a dispute or the
      // notSatisfied assessment under it ever costs anyone anything is UNKNOWN
      // and deferred, never zero.
      expect(
        allowedDispute(runRaise()).financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(FinancialClassification.values.length, 2);
      expect(
        FinancialClassification.values,
        contains(FinancialClassification.deferredToFinancialSlice),
      );
    });
  });

  group('no dispute outcome was decided', () {
    test('no outcome vocabulary is declared in any dispute file', () {
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in outcomeVocabulary) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '"$forbidden" would decide how a dispute resolves ($path)',
          );
        }
      }
    });

    test('no status setter, patch or copyWith exists', () {
      for (final String path in disputeSourceFiles) {
        final String code = codeOnly(File(path).readAsStringSync());
        for (final String forbidden in <String>[
          'setdisputestatus',
          'updatedispute',
          'patchdispute',
          'overridedispute',
          'closedispute',
          'copywith',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '"$forbidden" would make dispute history rewritable',
          );
        }
      }
    });

    test('no command takes a target state as an argument', () {
      // The prohibited-capability rule, checked where it would first be broken.
      for (final DeliveryProofDisputeCommand c
          in DeliveryProofDisputeCommand.values) {
        expect(c.commandType, isNot(contains('set')));
        expect(c.commandType, isNot(contains('status')));
        expect(c.commandType, isNot(contains('patch')));
      }
      for (final ProhibitedCapability p in ProhibitedCapability.all) {
        for (final String fragment in p.forbiddenIdFragments) {
          for (final DeliveryProofDisputeCommand c
              in DeliveryProofDisputeCommand.values) {
            expect(c.commandType, isNot(contains(fragment)));
          }
        }
      }
    });
  });

  group('nothing else became executable', () {
    test('the command sweep now covers the dispute vocabulary too', () {
      // **Widened by FND-003D2B.** The sweep must cover every command
      // vocabulary that exists, or it silently stops guarding the moment a new
      // one is introduced — it would keep passing while proving nothing about
      // the new surface. The three dispute commands are pinned **by name**
      // below, exactly the way `delivery.proof_assessed` is: pinning is
      // stronger than skipping the substring, because a new
      // `dispute.resolve_and_refund` still fails.
      final List<String> allCommandTypes = <String>[
        ...LifecycleCommand.values.map((LifecycleCommand c) => c.commandType),
        ...AssignmentCommand.values.map((AssignmentCommand c) => c.commandType),
        ...CustodyCommand.values.map((CustodyCommand c) => c.commandType),
        ...DeliveryProofDisputeCommand.values.map(
          (DeliveryProofDisputeCommand c) => c.commandType,
        ),
      ];
      const List<String> pinnedDisputeCommands = <String>[
        'dispute.raise_delivery_proof',
        'dispute.record_delivery_proof_review',
        'dispute.resolve_delivery_proof',
      ];
      for (final String type in allCommandTypes) {
        if (pinnedDisputeCommands.contains(type)) {
          continue;
        }
        for (final String forbidden in <String>[
          'deliver',
          'refus',
          'return',
          'proof',
          'assess',
          'attempt',
          'dispute',
        ]) {
          expect(
            type,
            isNot(contains(forbidden)),
            reason: '$type must not exist after FND-003D2B',
          );
        }
      }
      // The three pinned commands are present, and nothing beyond them.
      expect(
        DeliveryProofDisputeCommand.values
            .map((DeliveryProofDisputeCommand c) => c.commandType)
            .toList(),
        pinnedDisputeCommands,
      );
      expect(allCommandTypes, isNot(contains('order.deliver')));
      expect(allCommandTypes, isNot(contains('delivery.confirm')));
      expect(allCommandTypes, isNot(contains('custody.record_customer_receipt')));
      expect(LifecycleCommand.values.length, 7);
      expect(CustodyCommand.values.length, 2);
      expect(DeliveryProofDisputeCommand.values.length, 3);
    });

    test('the event sweep now covers the dispute vocabulary too', () {
      final List<String> allEvents = <String>[
        ...LifecycleEventType.all,
        ...AssignmentEventType.all,
        ...CustodyEventType.all,
        ...DeliveryProofAssessmentEventType.all,
        ...DeliveryProofDisputeEventType.all,
      ];
      const List<String> pinned = <String>[
        'order.in_delivery',
        'delivery.proof_assessed',
        'delivery.proof_dispute_raised',
        'delivery.proof_dispute_review_started',
      ];
      for (final String e in allEvents) {
        if (pinned.contains(e)) {
          continue;
        }
        for (final String forbidden in <String>[
          'deliver',
          'proof',
          'refus',
          'return',
          'dispute',
        ]) {
          expect(
            e,
            isNot(contains(forbidden)),
            reason: '$e must not exist after FND-003D2B',
          );
        }
      }
      expect(allEvents, isNot(contains('order.delivered')));
      expect(allEvents, isNot(contains('delivery.proof_dispute_resolved')));
      expect(allEvents, isNot(contains('delivery.proof_dispute_closed')));
      expect(allEvents, isNot(contains('delivery.proof_dispute_upheld')));
      expect(DeliveryProofDisputeEventType.all.length, 2);
      expect(DeliveryProofAssessmentEventType.all.length, 1);
      expect(LifecycleEventType.all.length, 8);
      expect(CustodyEventType.all.length, 2);
    });

    test('successful delivery is still not executable', () {
      expect(OrderState.notYetImplemented, <OrderState>{OrderState.delivered});
      expect(CustodyHolderKind.notYetImplemented, <CustodyHolderKind>{
        CustodyHolderKind.customer,
      });
      expect(
        AssignmentState.notYetImplementedForRole(AssignmentRole.rider),
        <AssignmentState>{AssignmentState.completed},
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
      );
      // Picker completion arithmetic is untouched by this slice.
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 3, max: 3),
      );
      expect(
        reachableSlotRevisionRange(
          2,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 5, max: 6),
      );
    });

    test('the custody dispatch boundary is unchanged', () {
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordRiderReceipt),
      );
      expect(t.orderEffect.toState, OrderState.inDelivery);
      expect(t.pickerCompletion, isNotNull);
      expect(t.inventoryEffect.availableStockDelta, 0);
    });
  });

  group('D1 and D2A behaviour is unchanged', () {
    test('the D1 references still refer, and still prove nothing', () {
      expect(maxDeliveryProofPolicyRefLength, maxIdLength);
      expect(
        const DeliveryProofPolicyRef('policy/delivery_proof@v1').toString(),
        'DeliveryProofPolicyRef(length=24)',
      );
      const DeliveryEvidenceRef ref = DeliveryEvidenceRef(
        resourceId: orderId,
        evidenceId: evidenceA,
      );
      expect(ref.belongsTo(orderId), isTrue);
      expect(ref.belongsTo(otherOrderId), isFalse);
      expect(
        const DeliveryEvidenceRef(
          resourceId: '',
          evidenceId: '',
        ).toString(),
        'DeliveryEvidenceRef(invalid)',
      );
      expect(DeliveryProofDenial.values.length, 6);
    });

    test('the D2A verdict vocabulary and its meanings are unchanged', () {
      expect(DeliveryProofAssessmentVerdict.values.length, 2);
      expect(DeliveryProofAssessmentVerdict.satisfied.id, 'satisfied');
      expect(DeliveryProofAssessmentVerdict.notSatisfied.id, 'not_satisfied');
      expect(DeliveryProofAssessmentVerdict.byId('pending'), isNull);
      expect(DeliveryProofAssessmentVerdict.byId('disputed'), isNull);
      expect(executableProofAssessorKinds, <PrincipalKind>{
        PrincipalKind.systemWorker,
      });
    });

    test('absence still means not assessed, and corruption still means null',
        () {
      expect(absentAssessment.canonicalVerdict, isNull);
      expect(absentAssessment.hasCurrentRecord, isFalse);
      expect(
        tornAssessment().canonicalVerdict,
        isNull,
        reason: 'corruption is never downgraded to notSatisfied',
      );
      expect(
        assessed().canonicalVerdict,
        DeliveryProofAssessmentVerdict.notSatisfied,
      );
    });

    test('a D2A assessment still evaluates exactly as before', () {
      // The accepted evaluator is untouched: a healthy first assessment is
      // allowed, and every effect is still NONE.
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.resultingAssessmentRevision, 1);
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
      expect(t.events, <String>['delivery.proof_assessed']);
      expect(
        run(assessor: otherWorker()).denial,
        DeliveryProofAssessmentDenial.assessorAuthorityMismatch,
      );
      expect(
        run(assessor: humanPrincipal()).denial,
        DeliveryProofAssessmentDenial.assessorNotSystemWorker,
      );
    });

    test('a dispute changes nothing about how an assessment is evaluated', () {
      // Raising a dispute first, then assessing, produces the identical
      // outcome: the assessment evaluator does not know disputes exist.
      allowedDispute(runRaise());
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.resultingAssessmentRevision, 1);
      expect(t.record.verdict, DeliveryProofAssessmentVerdict.satisfied);
    });
  });

  group('contract version', () {
    test('the build reports 0.10', () {
      // D2B shipped at 0.9. FND-003B3B then added the attempt and return
      // lifecycles additively, so the build now reports 0.10 — nothing D2B
      // defined changed meaning.
      expect(ContractVersion.current.toString(), '0.10');
      expect(ContractVersion.current, const ContractVersion(0, 10));
    });

    test('0.8 and 0.9 share a major, and no payload claim is made', () {
      expect(
        ContractVersion.current.isVersionCompatibleWith(
          const ContractVersion(0, 8),
        ),
        isTrue,
      );
      expect(
        const ContractVersion(
          0,
          8,
        ).isVersionCompatibleWith(ContractVersion.current),
        isTrue,
      );
      expect(
        ContractVersion.current.isVersionCompatibleWith(
          const ContractVersion(1, 0),
        ),
        isFalse,
      );
    });

    test('no serialization was added by this slice', () {
      for (final String path in disputeSourceFiles) {
        final String api = codeOnly(File(path).readAsStringSync());
        expect(api, isNot(contains('tojson')));
        expect(api, isNot(contains('fromjson')));
        expect(api, isNot(contains('jsonencode')));
      }
    });

    test('the public barrel exposes the whole dispute surface', () {
      // Reached through `package:cp_contracts/cp_contracts.dart` only — if the
      // split had dropped an export, this file would not compile.
      expect(DeliveryProofDisputeState.values.length, 3);
      expect(DeliveryProofDisputeBasisKind.values.length, 2);
      expect(DeliveryProofDisputeBasisStanding.values.length, 3);
      expect(DeliveryProofDisputeCommand.values.length, 3);
      // Pinned so `docs/contracts/delivery-proof-dispute.md` cannot drift from
      // the vocabulary it documents. 20 -> 19 at FND-003D2B-FIX-001, which
      // removed the invented `reviewerIsRaiser`; 19 -> **20** at
      // FND-003D2B-FIX-002, which added the generic
      // `authorizationGrantMismatch`.
      expect(DeliveryProofDisputeDenial.values.length, 20);
      expect(
        DeliveryProofDisputeDenial.values.map(
          (DeliveryProofDisputeDenial d) => d.name,
        ),
        isNot(contains('reviewerIsRaiser')),
      );
      expect(DeliveryProofDisputeEventType.all.length, 2);
      expect(reachableDisputeRevisionFor(DeliveryProofDisputeState.open), 1);
      expect(validateDeliveryProofDisputeAggregate(noDispute), isNull);
      expect(noDispute.canonicalState, isNull);
      expect(
        resolveDeliveryProofDisputeBasisStanding(
          basis: const DeliveryProofDisputeBasis.notAssessed(
            resourceId: orderId,
          ),
          assessment: absentAssessment,
        ),
        DeliveryProofDisputeBasisStanding.current,
      );
      expect(allowedDispute(runRaise()).resultingDisputeRevision, 1);
      expect(
        checkDisputeAuthorization(
          grant: customerRaiseGrant(),
          actor: customer(),
          command: DeliveryProofDisputeCommand.raise,
          expectedResourceId: orderId,
        ),
        isNull,
      );
    });
  });

  group('no backend evidence is claimed', () {
    test('a forged dispute record is structurally perfect, because it is', () {
      // The same honesty D2A records for assessments: a pure Dart value cannot
      // authenticate its own origin. Any client can build this locally, which
      // is exactly why the backend must ignore client-supplied records and
      // trust only what it loaded — DPD1 and DPD2, both NOT RUN.
      final DeliveryProofDisputeRecord forged =
          DeliveryProofDisputeRecord.raised(
            disputeId: disputeB,
            resourceId: orderId,
            basis: const DeliveryProofDisputeBasis.notAssessed(
              resourceId: orderId,
            ),
            raisedByPrincipalId: adminId,
            raisedAtUtc: raisedAt,
          );
      expect(forged.isWellFormed, isTrue);
      expect(
        validateDeliveryProofDisputeAggregate(
          DeliveryProofDisputeFacts(
            resourceId: orderId,
            disputeRevision: 1,
            current: forged,
          ),
        ),
        isNull,
        reason: 'structural validity is not provenance, and never was',
      );
    });
  });
}
