import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/custody_fixtures.dart';

const String asmtA = 'asm_Aa11Bb22Cc33Dd44';
const String asmtB = 'asm_Bb22Cc33Dd44Ee55';
const String asmtC = 'asm_Cc33Dd44Ee55Ff66';
const String evidenceA = 'evd_Aa11Bb22Cc33Dd44';
const String evidenceB = 'evd_Bb22Cc33Dd44Ee55';
const String workerA = 'wrk_Sys01Aa-Bb22Cc3';
const String customerA = 'usr_cust01Aa-Bb22Cc';

const DeliveryProofPolicyRef proofPolicy = DeliveryProofPolicyRef(
  'policy/delivery_proof@v1',
);

final DateTime assessedAt = DateTime.utc(2026, 9, 10, 12, 30);

/// The canonical server-resolved delivery context.
DeliveryProofAssessmentContext ctx({
  String resourceId = orderId,
  DeliveryProofPolicyRef policy = proofPolicy,
  DeliveryEvidenceRef? evidence,
}) => DeliveryProofAssessmentContext(
  resourceId: resourceId,
  policyRef: policy,
  evidenceRef:
      evidence ??
      DeliveryEvidenceRef(resourceId: resourceId, evidenceId: evidenceA),
);

/// An order that has actually been dispatched.
OrderLifecycleFacts inDelivery({
  int revision = 5,
  ReservationState reservation = ReservationState.committed,
}) => orderFacts(
  state: OrderState.inDelivery,
  revision: revision,
  reservation: reservation,
);

/// The rider slot for a dispatched order.
RiderAssignmentFacts riderInDelivery({
  AssignmentState? state = AssignmentState.accepted,
  String principalId = riderA,
  String assignmentId = rideAsgA,
  int generation = 1,
  int? slotRevision,
  String resourceId = orderId,
}) => riderSlot(
  state: state,
  principalId: principalId,
  assignmentId: assignmentId,
  generation: generation,
  slotRevision: slotRevision,
  orderState: OrderState.inDelivery,
  resourceId: resourceId,
);

/// Evaluate one assessment, defaulting every fact to a healthy dispatched
/// delivery so each test changes exactly one thing.
DeliveryProofAssessmentOutcome run({
  String assessmentId = asmtA,
  DeliveryProofAssessmentVerdict verdict =
      DeliveryProofAssessmentVerdict.satisfied,
  String assessedBy = workerA,
  PrincipalKind assessorKind = PrincipalKind.systemWorker,
  DateTime? at,
  String rider = riderA,
  String riderAssignment = rideAsgA,
  int riderGeneration = 1,
  DeliveryProofAssessmentContext? context,
  DeliveryProofAssessmentFacts? assessment,
  OrderLifecycleFacts? order,
  CustodyFacts? custody,
  bool omitCustody = false,
  RiderAssignmentFacts? riderFacts,
  bool omitRider = false,
  int? expectedAssessmentRevision,
  int? expectedOrderRevision,
  int? expectedCustodyRevision,
  int? expectedRiderSlotRevision,
}) {
  final DeliveryProofAssessmentContext c = context ?? ctx();
  final DeliveryProofAssessmentFacts a =
      assessment ?? const DeliveryProofAssessmentFacts.absent(resourceId: orderId);
  final OrderLifecycleFacts o = order ?? inDelivery();
  final CustodyFacts? cu = omitCustody ? null : custody ?? withRider();
  final RiderAssignmentFacts? r = omitRider
      ? null
      : riderFacts ?? riderInDelivery();
  return evaluateDeliveryProofAssessment(
    request: DeliveryProofAssessmentRequest(
      assessmentId: assessmentId,
      verdict: verdict,
      assessedByPrincipalId: assessedBy,
      assessedByKind: assessorKind,
      assessedAtUtc: at ?? assessedAt,
      riderPrincipalId: rider,
      riderAssignmentId: riderAssignment,
      riderAssignmentGeneration: riderGeneration,
      expectedAssessmentRevision:
          expectedAssessmentRevision ?? a.assessmentRevision,
      expectedOrderRevision: expectedOrderRevision ?? o.revision,
      expectedCustodyRevision:
          expectedCustodyRevision ?? cu?.custodyRevision ?? 0,
      expectedRiderSlotRevision:
          expectedRiderSlotRevision ?? r?.slotRevision ?? 0,
    ),
    context: c,
    assessment: a,
    order: o,
    custody: cu,
    riderAssignment: r,
  );
}

DeliveryProofAssessmentTransition allowed(DeliveryProofAssessmentOutcome o) {
  final DeliveryProofAssessmentTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

/// Applies a transition to produce the next trusted facts, as a backend would.
///
/// **Test infrastructure only.** It is not evidence that real persistence is
/// correct: the assessment record, the current pointer, the dedupe result and
/// the outbox event must commit in ONE transaction — criterion **DPA14** —
/// which remains NOT RUN.
DeliveryProofAssessmentFacts applyAssessment(
  DeliveryProofAssessmentTransition t, {
  String resourceId = orderId,
}) => DeliveryProofAssessmentFacts(
  resourceId: resourceId,
  assessmentRevision: t.resultingAssessmentRevision,
  current: t.record,
);

/// Strips doc comments so prose ruling a token out cannot mask a declaration.
String codeOnly(String source) => source
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('///'))
    .join('\n')
    .toLowerCase();

const List<String> proofMechanisms = <String>[
  'otp',
  'qr',
  'barcode',
  'signature',
  'photo',
  'image',
  'video',
  'gps',
  'latitude',
  'longitude',
  'biometric',
  'attestation',
];

void main() {
  group('absence means NOT ASSESSED, never a verdict', () {
    test('canonical absence is revision 0 with no record', () {
      const DeliveryProofAssessmentFacts absent =
          DeliveryProofAssessmentFacts.absent(resourceId: orderId);
      expect(absent.assessmentRevision, 0);
      expect(absent.current, isNull);
      expect(absent.isAssessed, isFalse);
      expect(
        absent.currentVerdict,
        isNull,
        reason: 'null means not assessed — never "not satisfied"',
      );
      expect(validateDeliveryProofAssessmentAggregate(absent), isNull);
    });

    test('there is no pending, processing or expired verdict', () {
      expect(DeliveryProofAssessmentVerdict.values, <
        DeliveryProofAssessmentVerdict
      >[
        DeliveryProofAssessmentVerdict.satisfied,
        DeliveryProofAssessmentVerdict.notSatisfied,
      ]);
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        for (final String forbidden in <String>[
          'pending',
          'processing',
          'expired',
          'approved',
          'disputed',
          'overridden',
          'delivered',
          'unknown',
        ]) {
          expect(v.name.toLowerCase(), isNot(contains(forbidden)));
          expect(v.id, isNot(contains(forbidden)));
        }
      }
    });

    test('verdict wire ids are stable and round-trip', () {
      expect(DeliveryProofAssessmentVerdict.satisfied.id, 'satisfied');
      expect(DeliveryProofAssessmentVerdict.notSatisfied.id, 'not_satisfied');
      for (final DeliveryProofAssessmentVerdict v
          in DeliveryProofAssessmentVerdict.values) {
        expect(DeliveryProofAssessmentVerdict.byId(v.id), v);
      }
      expect(DeliveryProofAssessmentVerdict.byId('pending'), isNull);
    });

    test('an absent aggregate carrying a revision is a torn load', () {
      const DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 3,
      );
      expect(
        validateDeliveryProofAssessmentAggregate(torn),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });
  });

  group('first assessment — 0 -> 1', () {
    test('a first satisfied assessment is allowed and binds everything', () {
      final DeliveryProofAssessmentTransition t = allowed(run());

      expect(t.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(t.resultingAssessmentRevision, 1);
      expect(t.isReassessment, isFalse);
      expect(t.supersededAssessmentId, isNull);

      final DeliveryProofAssessmentRecord r = t.record;
      expect(r.assessmentId, asmtA);
      expect(r.resourceId, orderId);
      expect(r.assessmentRevision, 1);
      expect(r.policyRef, proofPolicy);
      expect(r.evidenceRef.evidenceId, evidenceA);
      expect(r.evidenceRef.belongsTo(orderId), isTrue);
      expect(r.riderPrincipalId, riderA);
      expect(r.riderAssignmentId, rideAsgA);
      expect(r.riderAssignmentGeneration, 1);
      expect(r.assessedByPrincipalId, workerA);
      expect(r.assessedByKind, PrincipalKind.systemWorker);
      expect(r.assessedAtUtc, assessedAt);
      expect(r.assessedAtUtc.isUtc, isTrue);
      expect(r.isWellFormed, isTrue);
      expect(r.belongsToResource(orderId), isTrue);
      expect(r.belongsToResource(otherOrderId), isFalse);
      expect(
        r.bindsRiderAttempt(
          principalId: riderA,
          assignmentId: rideAsgA,
          generation: 1,
        ),
        isTrue,
      );
      expect(t.events, <String>['delivery.proof_assessed']);
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(t)),
        isNull,
      );
    });

    test('a first notSatisfied assessment is equally allowed', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      expect(t.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(t.resultingAssessmentRevision, 1);
      expect(t.record.supersedesAssessmentId, isNull);
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(t)),
        isNull,
      );
    });

    test('the policy and evidence come from the context, not the caller', () {
      // The request has no policy or evidence field at all — the verifier
      // reports a verdict, it does not choose what it was judged against.
      final DeliveryProofAssessmentTransition t = allowed(
        run(
          context: ctx(
            policy: const DeliveryProofPolicyRef('policy/other@v9'),
            evidence: const DeliveryEvidenceRef(
              resourceId: orderId,
              evidenceId: evidenceB,
            ),
          ),
        ),
      );
      expect(t.record.policyRef.value, 'policy/other@v9');
      expect(t.record.evidenceRef.evidenceId, evidenceB);
    });
  });

  group('reassessment is append-only', () {
    test('reassessment after satisfied increments and supersedes', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentFacts afterFirst = applyAssessment(first);

      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          verdict: DeliveryProofAssessmentVerdict.notSatisfied,
          assessment: afterFirst,
        ),
      );

      expect(second.resultingAssessmentRevision, 2);
      expect(second.isReassessment, isTrue);
      expect(second.supersededAssessmentId, asmtA);
      expect(second.record.assessmentId, asmtB);
      expect(second.verdict, DeliveryProofAssessmentVerdict.notSatisfied);
      expect(
        validateDeliveryProofAssessmentAggregate(applyAssessment(second)),
        isNull,
      );
    });

    test('reassessment after notSatisfied works the same way', () {
      final DeliveryProofAssessmentTransition first = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          assessment: applyAssessment(first),
        ),
      );
      expect(second.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(second.resultingAssessmentRevision, 2);
      expect(second.supersededAssessmentId, asmtA);
    });

    test('a third assessment keeps incrementing by exactly one', () {
      DeliveryProofAssessmentFacts facts =
          const DeliveryProofAssessmentFacts.absent(resourceId: orderId);
      final List<int> revisions = <int>[];
      for (final String id in <String>[asmtA, asmtB, asmtC]) {
        final DeliveryProofAssessmentTransition t = allowed(
          run(assessmentId: id, assessment: facts),
        );
        revisions.add(t.resultingAssessmentRevision);
        facts = applyAssessment(t);
      }
      expect(revisions, <int>[1, 2, 3]);
    });

    test('the previous record is never mutated, relabelled or erased', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentRecord before = first.record;
      // Capture every field of the earlier fact.
      final String beforeId = before.assessmentId;
      final int beforeRevision = before.assessmentRevision;
      final DeliveryProofAssessmentVerdict beforeVerdict = before.verdict;
      final DateTime beforeAt = before.assessedAtUtc;

      final DeliveryProofAssessmentTransition second = allowed(
        run(
          assessmentId: asmtB,
          verdict: DeliveryProofAssessmentVerdict.notSatisfied,
          assessment: applyAssessment(first),
        ),
      );

      // The earlier record is untouched by the later one.
      expect(before.assessmentId, beforeId);
      expect(before.assessmentRevision, beforeRevision);
      expect(before.verdict, beforeVerdict);
      expect(before.assessedAtUtc, beforeAt);
      expect(before.verdict, DeliveryProofAssessmentVerdict.satisfied);
      expect(second.record, isNot(before));
      // ...and the new one points back at it rather than over it.
      expect(second.record.supersedesAssessmentId, beforeId);
    });

    test('a reassessment must carry a NEW assessment id', () {
      final DeliveryProofAssessmentTransition first = allowed(run());
      final DeliveryProofAssessmentOutcome reuse = run(
        assessmentId: asmtA,
        assessment: applyAssessment(first),
      );
      expect(reuse.denial, DeliveryProofAssessmentDenial.assessmentIdReuse);
      expect(reuse.transition, isNull);
    });

    test('no verdict overwrite, status setter or patch API exists', () {
      // The record exposes no mutator and no copyWith; the only way to change
      // the current verdict is to append a new record through the evaluator.
      final DeliveryProofAssessmentTransition t = allowed(run());
      final String api = codeOnly(
        File('lib/src/delivery_proof_assessment.dart').readAsStringSync(),
      );
      for (final String forbidden in <String>[
        'setassessmentstatus',
        'changesatisfiedto',
        'overrideverdict',
        'patchassessment',
        'copywith',
        'set verdict',
        'void set',
      ]) {
        expect(
          api,
          isNot(contains(forbidden)),
          reason: '"$forbidden" would make assessment history rewritable',
        );
      }
      // The record's fields are final: reading one twice gives the same value
      // and there is no setter to call.
      expect(t.record.verdict, t.record.verdict);
    });
  });

  group('stale, duplicate, reordered and concurrent safety', () {
    test('a stale expected assessment revision is refused', () {
      final DeliveryProofAssessmentFacts afterFirst = applyAssessment(
        allowed(run()),
      );
      final DeliveryProofAssessmentOutcome stale = run(
        assessmentId: asmtB,
        assessment: afterFirst,
        expectedAssessmentRevision: 0,
      );
      expect(
        stale.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(stale.transition, isNull);
    });

    test('a delayed reassessment from an old revision writes nothing', () {
      // Two assessments have landed; a straggler still believes revision 1.
      DeliveryProofAssessmentFacts facts =
          const DeliveryProofAssessmentFacts.absent(resourceId: orderId);
      facts = applyAssessment(allowed(run(assessment: facts)));
      facts = applyAssessment(
        allowed(run(assessmentId: asmtB, assessment: facts)),
      );
      expect(facts.assessmentRevision, 2);

      final DeliveryProofAssessmentOutcome delayed = run(
        assessmentId: asmtC,
        assessment: facts,
        expectedAssessmentRevision: 1,
      );
      expect(
        delayed.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(delayed.transition, isNull);
    });

    test('two concurrent reassessments from one revision: only one wins', () {
      final DeliveryProofAssessmentFacts shared = applyAssessment(
        allowed(run()),
      );
      // Both writers read revision 1 and propose distinct new ids.
      final DeliveryProofAssessmentTransition a = allowed(
        run(assessmentId: asmtB, assessment: shared),
      );
      final DeliveryProofAssessmentTransition b = allowed(
        run(assessmentId: asmtC, assessment: shared),
      );
      // Both *evaluate* to the same next revision — the contract cannot
      // serialise them, and does not pretend to.
      expect(a.resultingAssessmentRevision, 2);
      expect(b.resultingAssessmentRevision, 2);

      // Whichever commits first advances the aggregate; the loser's expected
      // revision is then stale and it writes nothing. Serialisation itself is
      // the backend's transaction — criterion DPA8, NOT RUN.
      final DeliveryProofAssessmentFacts afterWinner = applyAssessment(a);
      final DeliveryProofAssessmentOutcome loser = run(
        assessmentId: asmtC,
        assessment: afterWinner,
        expectedAssessmentRevision: 1,
      );
      expect(
        loser.denial,
        DeliveryProofAssessmentDenial.assessmentRevisionConflict,
      );
      expect(loser.transition, isNull);
    });

    test('a duplicate request replays no state through this contract', () {
      // The same request evaluated twice against the SAME facts produces the
      // same proposal — it does not advance twice. Actual replay-versus-reuse
      // is FND-003A idempotency plus backend storage (DPA10), NOT RUN.
      final DeliveryProofAssessmentFacts facts =
          const DeliveryProofAssessmentFacts.absent(resourceId: orderId);
      final DeliveryProofAssessmentTransition one = allowed(
        run(assessment: facts),
      );
      final DeliveryProofAssessmentTransition two = allowed(
        run(assessment: facts),
      );
      expect(one.record, two.record);
      expect(one.resultingAssessmentRevision, 1);
      expect(two.resultingAssessmentRevision, 1);
    });

    test('a stale order revision is refused', () {
      final DeliveryProofAssessmentOutcome o = run(expectedOrderRevision: 4);
      expect(o.denial, DeliveryProofAssessmentDenial.orderRevisionConflict);
      expect(o.transition, isNull);
    });

    test('a stale custody revision is refused', () {
      final DeliveryProofAssessmentOutcome o = run(expectedCustodyRevision: 2);
      expect(o.denial, DeliveryProofAssessmentDenial.custodyRevisionConflict);
      expect(o.transition, isNull);
    });

    test('a stale rider slot revision is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        expectedRiderSlotRevision: 1,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.riderSlotRevisionConflict);
      expect(o.transition, isNull);
    });

    test('correct revisions never bypass the identity checks', () {
      // Every expected revision is right; the rider named is wrong. A CAS pass
      // is not a substitute for binding.
      final DeliveryProofAssessmentOutcome o = run(rider: riderB);
      expect(o.denial, DeliveryProofAssessmentDenial.notCurrentAcceptedRider);
      expect(o.transition, isNull);
    });
  });

  group('current delivery context must describe the same delivery', () {
    test('an order that is not in delivery is refused', () {
      // Each state is paired with its own canonical reservation, so the denial
      // is genuinely "not dispatched" and not an aggregate-integrity failure.
      const Map<OrderState, ReservationState> canonical =
          <OrderState, ReservationState>{
            OrderState.placed: ReservationState.active,
            OrderState.accepted: ReservationState.committed,
            OrderState.preparing: ReservationState.committed,
            OrderState.ready: ReservationState.committed,
          };
      for (final OrderState s in canonical.keys) {
        final DeliveryProofAssessmentOutcome o = run(
          order: orderFacts(
            state: s,
            revision: 4,
            reservation: canonical[s]!,
          ),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.orderNotInDelivery,
          reason: 'proof cannot be assessed for a ${s.id} order',
        );
        expect(o.transition, isNull);
      }
    });

    test('a non-committed reservation is refused', () {
      // `in_delivery` pairs only with `committed`, so a released one is a
      // corrupt aggregate and is caught as such — either way nothing is
      // written.
      final DeliveryProofAssessmentOutcome o = run(
        order: inDelivery(reservation: ReservationState.released),
      );
      expect(
        o.denial,
        anyOf(
          DeliveryProofAssessmentDenial.reservationNotCommitted,
          DeliveryProofAssessmentDenial.aggregateInconsistent,
        ),
      );
      expect(o.transition, isNull);
    });

    test('missing custody is never read as "a rider must have it"', () {
      final DeliveryProofAssessmentOutcome o = run(omitCustody: true);
      expect(o.denial, DeliveryProofAssessmentDenial.custodyNotInitialised);
      expect(o.transition, isNull);
    });

    test('custody not held by a rider is refused', () {
      final DeliveryProofAssessmentOutcome shop = run(custody: atShop());
      expect(shop.denial, DeliveryProofAssessmentDenial.custodyNotWithRider);
      final DeliveryProofAssessmentOutcome picker = run(custody: withPicker());
      expect(picker.denial, DeliveryProofAssessmentDenial.custodyNotWithRider);
      expect(shop.transition, isNull);
      expect(picker.transition, isNull);
    });

    test('a missing rider assignment is refused', () {
      final DeliveryProofAssessmentOutcome o = run(omitRider: true);
      expect(o.denial, DeliveryProofAssessmentDenial.noAcceptedRiderAssignment);
      expect(o.transition, isNull);
    });

    test('a rider assignment that is not accepted is refused', () {
      for (final AssignmentState s in <AssignmentState>[
        AssignmentState.offered,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      ]) {
        final DeliveryProofAssessmentOutcome o = run(
          riderFacts: riderInDelivery(state: s),
        );
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.noAcceptedRiderAssignment,
          reason: 'a ${s.id} rider attempt is not carrying anything',
        );
        expect(o.transition, isNull);
      }
    });

    test('an empty rider slot is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        riderFacts: riderInDelivery(state: null),
        expectedRiderSlotRevision: 0,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.noAcceptedRiderAssignment);
      expect(o.transition, isNull);
    });

    test('the wrong rider principal is refused', () {
      final DeliveryProofAssessmentOutcome o = run(rider: riderB);
      expect(o.denial, DeliveryProofAssessmentDenial.notCurrentAcceptedRider);
      expect(o.transition, isNull);
    });

    test('the wrong rider assignmentId is refused', () {
      final DeliveryProofAssessmentOutcome o = run(riderAssignment: rideAsgB);
      expect(o.denial, DeliveryProofAssessmentDenial.assignmentIdMismatch);
      expect(o.transition, isNull);
    });

    test('the wrong rider generation is refused', () {
      final DeliveryProofAssessmentOutcome o = run(riderGeneration: 2);
      expect(o.denial, DeliveryProofAssessmentDenial.generationMismatch);
      expect(o.transition, isNull);
    });

    test('custody bound to a different rider attempt is refused', () {
      // The assignment says attempt A is accepted and the request agrees, but
      // custody is bound to a different attempt: goods carried under one
      // attempt must not be assessed as though another were carrying them.
      final DeliveryProofAssessmentOutcome o = run(
        custody: withRider(assignmentId: rideAsgB),
      );
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.custodyHolderBindingMismatch,
      );
      expect(o.transition, isNull);
    });

    test('possession alone is not authorization', () {
      // Custody with the right rider is a *context* fact. It does not make the
      // rider an assessor: a rider-kind assessor is still refused.
      final DeliveryProofAssessmentOutcome o = run(
        assessedBy: riderA,
        assessorKind: PrincipalKind.user,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.assessorNotSystemWorker);
      expect(o.transition, isNull);
    });
  });

  group('resource, policy and evidence binding is exact', () {
    test('aggregates about a different order are refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          resourceId: otherOrderId,
          evidence: const DeliveryEvidenceRef(
            resourceId: otherOrderId,
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('an assessment aggregate for another order is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        assessment: const DeliveryProofAssessmentFacts.absent(
          resourceId: otherOrderId,
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('a malformed canonical resource is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          resourceId: 'short',
          evidence: const DeliveryEvidenceRef(
            resourceId: 'short',
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.resourceBindingMismatch);
      expect(o.transition, isNull);
    });

    test('a malformed policy reference is refused, with the D1 reason', () {
      final DeliveryProofAssessmentOutcome blank = run(
        context: ctx(policy: const DeliveryProofPolicyRef('   ')),
      );
      expect(blank.denial, DeliveryProofAssessmentDenial.policyRefInvalid);
      expect(blank.structuralDenial, DeliveryProofDenial.policyRefBlank);
      expect(blank.transition, isNull);

      final DeliveryProofAssessmentOutcome long = run(
        context: ctx(
          policy: DeliveryProofPolicyRef(
            'p' * (maxDeliveryProofPolicyRefLength + 1),
          ),
        ),
      );
      expect(long.denial, DeliveryProofAssessmentDenial.policyRefInvalid);
      expect(long.structuralDenial, DeliveryProofDenial.policyRefTooLong);
      expect(long.transition, isNull);
    });

    test('the D1 policy bound is reused, not re-stated', () {
      // Accepted exactly at the limit, refused one past it — the same boundary
      // D1 owns, not a second one.
      final DeliveryProofAssessmentOutcome atLimit = run(
        context: ctx(
          policy: DeliveryProofPolicyRef(
            'p' * maxDeliveryProofPolicyRefLength,
          ),
        ),
      );
      expect(atLimit.allowed, isTrue);
      expect(maxDeliveryProofPolicyRefLength, maxIdLength);
    });

    test('a malformed evidence reference is refused, with the D1 reason', () {
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          evidence: const DeliveryEvidenceRef(
            resourceId: orderId,
            evidenceId: 'evd_short',
          ),
        ),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.evidenceRefInvalid);
      expect(o.structuralDenial, DeliveryProofDenial.evidenceIdInvalid);
      expect(o.transition, isNull);
    });

    test('cross-resource evidence is refused and stays distinguishable', () {
      // Evidence belonging to another order, presented against this one.
      final DeliveryProofAssessmentOutcome o = run(
        context: ctx(
          evidence: const DeliveryEvidenceRef(
            resourceId: otherOrderId,
            evidenceId: evidenceA,
          ),
        ),
      );
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.evidenceResourceMismatch,
        reason: 'evidence is not portable between orders',
      );
      expect(o.structuralDenial, DeliveryProofDenial.evidenceResourceMismatch);
      expect(o.transition, isNull);
    });

    test('D1 remains the single source of structural judgement', () {
      // Every structural denial surfaced here is a value D1 produced; the
      // assessment contract maps, it does not re-derive.
      const DeliveryEvidenceRef bad = DeliveryEvidenceRef(
        resourceId: otherOrderId,
        evidenceId: evidenceA,
      );
      expect(
        validateDeliveryEvidenceRef(bad, resourceId: orderId),
        DeliveryProofDenial.evidenceResourceMismatch,
      );
      expect(
        run(context: ctx(evidence: bad)).structuralDenial,
        validateDeliveryEvidenceRef(bad, resourceId: orderId),
      );
    });
  });

  group('assessor authority and server time', () {
    test('only a system worker may produce a normal assessment', () {
      expect(executableProofAssessorKinds, <PrincipalKind>{
        PrincipalKind.systemWorker,
      });
      final DeliveryProofAssessmentOutcome human = run(
        assessedBy: customerA,
        assessorKind: PrincipalKind.user,
      );
      expect(
        human.denial,
        DeliveryProofAssessmentDenial.assessorNotSystemWorker,
      );
      expect(human.transition, isNull);
    });

    test('a malformed assessor principal id is refused', () {
      final DeliveryProofAssessmentOutcome o = run(assessedBy: 'wrk_short');
      expect(
        o.denial,
        DeliveryProofAssessmentDenial.assessorPrincipalIdInvalid,
      );
      expect(o.transition, isNull);
    });

    test('a non-UTC assessment time is refused', () {
      final DeliveryProofAssessmentOutcome o = run(
        at: DateTime(2026, 9, 10, 12, 30),
      );
      expect(o.denial, DeliveryProofAssessmentDenial.assessedAtNotUtc);
      expect(o.transition, isNull);
    });

    test('no expiry, TTL or maximum age is invented', () {
      // A very old and a far-future UTC time are both accepted: this contract
      // checks that the value is UTC, and derives no validity window from it.
      // Inventing one would be inventing a proof policy.
      for (final DateTime t in <DateTime>[
        DateTime.utc(2000),
        DateTime.utc(2099, 12, 31),
      ]) {
        final DeliveryProofAssessmentTransition tr = allowed(run(at: t));
        expect(tr.record.assessedAtUtc, t);
      }
      final String api = codeOnly(
        File('lib/src/delivery_proof_assessment.dart').readAsStringSync(),
      );
      for (final String forbidden in <String>[
        'duration(',
        'ttl',
        'expiresat',
        'maxage',
        'retryinterval',
        'isbefore',
        'isafter',
        'difference(',
        'datetime.now',
      ]) {
        expect(
          api,
          isNot(contains(forbidden)),
          reason: '"$forbidden" would invent a time policy or read a clock',
        );
      }
    });

    test('a pure Dart record cannot establish runtime trust', () {
      // Anyone can construct a satisfied record locally, including one naming
      // a system worker. That is exactly why the backend must ignore
      // client-supplied records (DPA1/DPA2) — the type authenticates nothing.
      final DeliveryProofAssessmentRecord forged =
          DeliveryProofAssessmentRecord(
            assessmentId: asmtA,
            resourceId: orderId,
            assessmentRevision: 1,
            policyRef: proofPolicy,
            evidenceRef: const DeliveryEvidenceRef(
              resourceId: orderId,
              evidenceId: evidenceA,
            ),
            riderPrincipalId: riderA,
            riderAssignmentId: rideAsgA,
            riderAssignmentGeneration: 1,
            assessedByPrincipalId: workerA,
            assessedByKind: PrincipalKind.systemWorker,
            assessedAtUtc: assessedAt,
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          );
      // It is structurally well formed — and that is *all* it is.
      expect(forged.isWellFormed, isTrue);
      // Nothing on it answers "is this authentic" or "may I proceed".
      expect(forged.verdict, DeliveryProofAssessmentVerdict.satisfied);
      // ...and it still delivers nothing: no order state changed anywhere.
      expect(OrderState.notYetImplemented, contains(OrderState.delivered));
    });
  });

  group('aggregate validation runs before any transition', () {
    test('a corrupt stored assessment is refused, not repaired', () {
      final DeliveryProofAssessmentRecord good = allowed(run()).record;
      // Revision on the record and on the aggregate disagree: a torn write.
      final DeliveryProofAssessmentFacts torn = DeliveryProofAssessmentFacts(
        resourceId: orderId,
        assessmentRevision: 2,
        current: good,
      );
      expect(
        validateDeliveryProofAssessmentAggregate(torn),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
      final DeliveryProofAssessmentOutcome o = run(
        assessmentId: asmtB,
        assessment: torn,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.aggregateInconsistent);
      expect(o.transition, isNull);
    });

    test('a stored record for another order is corruption', () {
      final DeliveryProofAssessmentRecord foreign = allowed(
        run(
          context: ctx(
            resourceId: otherOrderId,
            evidence: const DeliveryEvidenceRef(
              resourceId: otherOrderId,
              evidenceId: evidenceA,
            ),
          ),
          assessment: const DeliveryProofAssessmentFacts.absent(
            resourceId: otherOrderId,
          ),
          custody: withWorker(
            kind: CustodyHolderKind.rider,
            revision: 3,
            resourceId: otherOrderId,
          ),
          riderFacts: riderInDelivery(resourceId: otherOrderId),
        ),
      ).record;
      expect(
        validateDeliveryProofAssessmentAggregate(
          DeliveryProofAssessmentFacts(
            resourceId: orderId,
            assessmentRevision: 1,
            current: foreign,
          ),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a stored record produced by a non-worker is corruption', () {
      final DeliveryProofAssessmentRecord humanAssessed =
          DeliveryProofAssessmentRecord(
            assessmentId: asmtA,
            resourceId: orderId,
            assessmentRevision: 1,
            policyRef: proofPolicy,
            evidenceRef: const DeliveryEvidenceRef(
              resourceId: orderId,
              evidenceId: evidenceA,
            ),
            riderPrincipalId: riderA,
            riderAssignmentId: rideAsgA,
            riderAssignmentGeneration: 1,
            assessedByPrincipalId: customerA,
            assessedByKind: PrincipalKind.user,
            assessedAtUtc: assessedAt,
            verdict: DeliveryProofAssessmentVerdict.satisfied,
          );
      expect(
        validateDeliveryProofAssessmentAggregate(
          DeliveryProofAssessmentFacts(
            resourceId: orderId,
            assessmentRevision: 1,
            current: humanAssessed,
          ),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
        reason: 'validating its shape would legitimise a self-declared proof',
      );
    });

    test('a first record must supersede nothing, a later one something', () {
      final DeliveryProofAssessmentRecord first = allowed(run()).record;
      // Revision 1 claiming to supersede an earlier assessment is impossible.
      final DeliveryProofAssessmentRecord impossible =
          DeliveryProofAssessmentRecord(
            assessmentId: first.assessmentId,
            resourceId: first.resourceId,
            assessmentRevision: 1,
            policyRef: first.policyRef,
            evidenceRef: first.evidenceRef,
            riderPrincipalId: first.riderPrincipalId,
            riderAssignmentId: first.riderAssignmentId,
            riderAssignmentGeneration: first.riderAssignmentGeneration,
            assessedByPrincipalId: first.assessedByPrincipalId,
            assessedByKind: first.assessedByKind,
            assessedAtUtc: first.assessedAtUtc,
            verdict: first.verdict,
            supersedesAssessmentId: asmtB,
          );
      expect(
        validateDeliveryProofAssessmentAggregate(
          DeliveryProofAssessmentFacts(
            resourceId: orderId,
            assessmentRevision: 1,
            current: impossible,
          ),
        ),
        DeliveryProofAssessmentDenial.aggregateInconsistent,
      );
    });

    test('a malformed assessment id is refused', () {
      for (final String bad in <String>[
        '',
        'asm_short',
        '1234567890123456',
        r'asm_bad!identifier01',
      ]) {
        final DeliveryProofAssessmentOutcome o = run(assessmentId: bad);
        expect(
          o.denial,
          DeliveryProofAssessmentDenial.assessmentIdInvalid,
          reason: '"$bad" is not a canonical opaque id',
        );
        expect(o.transition, isNull);
      }
    });

    test('a corrupt order, custody or rider aggregate is refused', () {
      // A rider slot whose generation and revision describe an impossible
      // history.
      final DeliveryProofAssessmentOutcome o = run(
        riderFacts: riderInDelivery(generation: 2, slotRevision: 1),
        expectedRiderSlotRevision: 1,
      );
      expect(o.denial, DeliveryProofAssessmentDenial.aggregateInconsistent);
      expect(o.transition, isNull);
    });
  });

  group('every commercial effect is NONE', () {
    test('satisfied moves nothing', () {
      final DeliveryProofAssessmentTransition t = allowed(run());
      expect(t.changesOrderState, isFalse);
      expect(t.changesCustody, isFalse);
      expect(t.changesRiderAssignment, isFalse);
      expect(t.inventoryEffect, const InventoryEffect.none());
      expect(t.inventoryEffect.availableStockDelta, 0);
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
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
      expect(
        t.financialClassification,
        FinancialClassification.noneInThisSlice,
      );
      expect(t.scopeEffect.isEmpty, isTrue);
    });

    test('the surrounding aggregates are untouched by an assessment', () {
      final OrderLifecycleFacts order = inDelivery();
      final CustodyFacts custody = withRider();
      final RiderAssignmentFacts rider = riderInDelivery();
      allowed(run(order: order, custody: custody, riderFacts: rider));

      // Nothing the transition produces can be applied to them: the only
      // aggregate it describes is the assessment one.
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
      // No order state appears on the transition at all, and `delivered`
      // remains unimplemented everywhere.
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

    test('notSatisfied opens no dispute, cancellation or charge', () {
      final DeliveryProofAssessmentTransition t = allowed(
        run(verdict: DeliveryProofAssessmentVerdict.notSatisfied),
      );
      expect(t.events, <String>['delivery.proof_assessed']);
      // One event, and it is not a dispute, a cancellation or a posting.
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
    });

    test('no money vocabulary exists anywhere in the assessment API', () {
      final String api = codeOnly(
        File('lib/src/delivery_proof_assessment.dart').readAsStringSync(),
      );
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
        // Whole-word, so `concurrency` does not read as `currency` and
        // `decode` does not read as `cod`. A substring sweep here would fail
        // on honest code and teach the next reader to weaken the guard.
        expect(
          RegExp('\\b$forbidden\\b').hasMatch(api),
          isFalse,
          reason: '"$forbidden" is FND-003C\'s, blocked on O6',
        );
      }
    });
  });

  group('the assessment event is privacy-minimal', () {
    test('exactly one event id exists and it reports an assessment', () {
      expect(DeliveryProofAssessmentEventType.all, <String>[
        'delivery.proof_assessed',
      ]);
      expect(
        DeliveryProofAssessmentEventType.proofAssessed,
        'delivery.proof_assessed',
      );
      // It is not named for delivery success, acceptance or dispute.
      expect(
        DeliveryProofAssessmentEventType.proofAssessed,
        isNot(contains('delivered')),
      );
    });

    test('the event id carries no material and no mechanism', () {
      for (final String mechanism in proofMechanisms) {
        expect(
          DeliveryProofAssessmentEventType.proofAssessed,
          isNot(contains(mechanism)),
        );
      }
    });

    test('the record renders identifiers only, never material', () {
      final DeliveryProofAssessmentRecord r = allowed(run()).record;
      final String rendered = r.toString();
      expect(rendered, contains(asmtA));
      expect(rendered, contains(orderId));
      expect(rendered, contains('satisfied'));
      // The policy reference's own non-disclosing toString is not bypassed.
      expect(rendered, isNot(contains(proofPolicy.value)));
      expect(rendered, isNot(contains('@')));
    });

    test('a malformed evidence reference is still not echoed', () {
      // The record delegates to D1's fail-safe rendering rather than
      // reimplementing it.
      const DeliveryEvidenceRef broken = DeliveryEvidenceRef(
        resourceId: 'short',
        evidenceId: 'also_short',
      );
      expect(broken.toString(), 'DeliveryEvidenceRef(invalid)');
      expect(broken.toString(), isNot(contains('also_short')));
    });
  });

  group('no proof mechanism became executable', () {
    late String source;

    setUpAll(() {
      source = File('lib/src/delivery_proof_assessment.dart').readAsStringSync();
    });

    test('no proof mechanism is named as a field, type or value', () {
      final String code = codeOnly(source);
      for (final String mechanism in proofMechanisms) {
        expect(
          code,
          isNot(contains(mechanism)),
          reason: '"$mechanism" must not be declared by this contract',
        );
      }
    });

    test('the mechanism scanner actually detects a planted declaration', () {
      // Negative control. Without this, the guard above proves only that the
      // scan ran — not that it can fail. A planted declaration must be caught,
      // and a doc comment mentioning the same word must NOT be, otherwise the
      // guard would be tripped by the prose that rules mechanisms out.
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

      const String docOnly =
          '/// No otp, qr, signature, photo or gps is selected here.\n';
      expect(codeOnly(docOnly).trim(), isEmpty);
    });

    test('no evidence material, locator or cardinality is declared', () {
      final String code = codeOnly(source);
      for (final String forbidden in <String>[
        'bytes',
        'base64',
        'blob',
        'signedurl',
        'storagepath',
        'artifactcount',
        'artifacts',
        'list<deliveryevidenceref>',
      ]) {
        expect(
          code,
          isNot(contains(forbidden)),
          reason: '"$forbidden" would invent material, a locator or a count',
        );
      }
      // The evidence handle is exactly D1's, singular.
      expect(code, contains('deliveryevidenceref evidenceref'));
    });

    test('no client-facing proof command or status setter is declared', () {
      final String code = codeOnly(source);
      for (final String forbidden in <String>[
        'commandtype',
        'requiredpermission',
        'permission.',
      ]) {
        expect(
          code,
          isNot(contains(forbidden)),
          reason: 'a normal assessment has no client command and no permission',
        );
      }
    });
  });

  group('nothing else became executable (regression)', () {
    test('no command anywhere maps to proof assessment', () {
      final List<String> allCommandTypes = <String>[
        ...LifecycleCommand.values.map((LifecycleCommand c) => c.commandType),
        ...AssignmentCommand.values.map((AssignmentCommand c) => c.commandType),
        ...CustodyCommand.values.map((CustodyCommand c) => c.commandType),
      ];
      for (final String type in allCommandTypes) {
        for (final String forbidden in <String>[
          'proof',
          'assess',
          'deliver',
          'refus',
          'return',
          'attempt',
          'dispute',
        ]) {
          expect(
            type,
            isNot(contains(forbidden)),
            reason: '$type must not exist after FND-003D2A',
          );
        }
      }
      expect(CustodyCommand.values.length, 2);
    });

    test('Permission.values and permissionMatrix remain 38', () {
      expect(Permission.values.length, 38);
      expect(permissionMatrix.length, 38);
      for (final Permission p in Permission.values) {
        for (final String forbidden in <String>[
          'proof.accept',
          'mark_satisfied',
          'proof.override',
          'assessment',
          'proof_status',
        ]) {
          expect(p.id, isNot(contains(forbidden)));
        }
      }
    });

    test('customer confirmation stays participation-only', () {
      expect(
        Permission.byId('customer.delivery.confirm_proof'),
        Permission.customerConfirmDeliveryProof,
      );
      final PermissionRule rule =
          permissionMatrix[Permission.customerConfirmDeliveryProof]!;
      expect(rule.eligibleRoles, <CommerceRole>{CommerceRole.customer});
      expect(rule.restriction, contains('Participation in proof only'));
      expect(rule.restriction.toLowerCase(), contains('does not settle'));
      // D2A does not decide whether customer participation is required,
      // optional, sufficient or a veto — and adds no flag that would default
      // the answer.
      final String api = codeOnly(
        File('lib/src/delivery_proof_assessment.dart').readAsStringSync(),
      );
      for (final String forbidden in <String>[
        'customerconfirmed',
        'requirescustomer',
        'customerparticipation',
        'customerapproved',
      ]) {
        expect(
          api,
          isNot(contains(forbidden)),
          reason: '"$forbidden" would silently choose a policy default',
        );
      }
    });

    test('customer custody remains unreachable', () {
      expect(CustodyHolderKind.notYetImplemented, <CustodyHolderKind>{
        CustodyHolderKind.customer,
      });
      expect(
        CustodyHolderKind.executableInThisSlice.contains(
          CustodyHolderKind.customer,
        ),
        isFalse,
      );
    });

    test('rider completion remains future — B3-C2 unchanged', () {
      expect(
        AssignmentState.notYetImplementedForRole(AssignmentRole.rider),
        <AssignmentState>{AssignmentState.completed},
      );
      expect(
        AssignmentState.executableForRole(
          AssignmentRole.rider,
        ).contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.rider,
        ),
        isNull,
        reason: 'no rider completion cost was invented by D2A either',
      );
    });

    test('picker completion range is untouched', () {
      expect(
        reachableSlotRevisionRange(
          1,
          AssignmentState.completed,
          role: AssignmentRole.picker,
        ),
        (min: 3, max: 3),
      );
      expect(
        reachableSlotRevisionRange(2, AssignmentState.completed,
            role: AssignmentRole.picker),
        (min: 5, max: 6),
      );
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed),
        isNull,
        reason: 'the role-less default answer is unchanged',
      );
    });

    test('the custody and assignment evaluators are unchanged by D2A', () {
      // The dispatch boundary still behaves exactly as FND-003B3A accepted it.
      final CustodyTransition t = allowedCustody(
        runCustody(CustodyCommand.recordRiderReceipt),
      );
      expect(t.orderEffect.toState, OrderState.inDelivery);
      expect(t.pickerCompletion, isNotNull);
      expect(t.inventoryEffect.availableStockDelta, 0);
    });
  });

  group('contract version', () {
    test('the build reports 0.8', () {
      expect(ContractVersion.current.toString(), '0.8');
    });

    test('0.7 and 0.8 share a major, so the policy permits an attempt', () {
      // Two integers only. 0.7 defined no assessment types, so it could not
      // decode a 0.8 assessment payload even if one were serialized. None is:
      // cp_contracts still has no serialization, and no payload or
      // unknown-field compatibility is claimed at any version.
      expect(
        ContractVersion.current.isVersionCompatibleWith(
          const ContractVersion(0, 7),
        ),
        isTrue,
      );
      expect(
        const ContractVersion(0, 7)
            .isVersionCompatibleWith(ContractVersion.current),
        isTrue,
      );
    });

    test('no serialization was added by this slice', () {
      final String api = codeOnly(
        File('lib/src/delivery_proof_assessment.dart').readAsStringSync(),
      );
      expect(api, isNot(contains('tojson')));
      expect(api, isNot(contains('fromjson')));
      expect(api, isNot(contains('jsonencode')));
    });
  });
}
