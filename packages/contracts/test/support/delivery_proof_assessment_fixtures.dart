import 'package:cp_contracts/cp_contracts.dart';

import 'custody_fixtures.dart';

/// Shared builders for the delivery-proof assessment suites.
///
/// **TEST INFRASTRUCTURE ONLY.** Nothing here is evidence that real persistence
/// is correct. [applyAssessment] in particular imitates a backend write: the
/// assessment record, the current pointer, the dedupe result and the outbox
/// event must commit in ONE transaction — criterion **DPA14** — which remains
/// **NOT RUN**, as do **DPA1–DPA18** in full. A fixture that names an
/// authorized verifier is likewise not proof that any backend authenticates or
/// authorizes one (**DPA2**, **DPA17**).

// ---------------------------------------------------------------- identities

const String asmtA = 'asm_Aa11Bb22Cc33Dd44';
const String asmtB = 'asm_Bb22Cc33Dd44Ee55';
const String asmtC = 'asm_Cc33Dd44Ee55Ff66';
const String evidenceA = 'evd_Aa11Bb22Cc33Dd44';
const String evidenceB = 'evd_Bb22Cc33Dd44Ee55';

/// The proof verifier this resource's policy authorizes.
const String verifierId = 'svc_proofVerifier01';

/// Other perfectly valid trusted workers that must NOT be able to assess.
const String outboxWorkerId = 'svc_outboxDrain0001';
const String expiryWorkerId = 'svc_reservationExp1';
const String reconcileWorkerId = 'svc_reconcileJob001';

const String customerId = 'usr_cust01Aa-Bb22Cc';

const DeliveryProofPolicyRef proofPolicy = DeliveryProofPolicyRef(
  'policy/delivery_proof@v1',
);

final DateTime assessedAt = DateTime.utc(2026, 9, 10, 12, 30);

/// The authorized proof verifier, as the backend would derive it.
Principal verifier([String id = verifierId]) => Principal.systemWorker(id);

/// A trusted worker that is not the proof verifier.
Principal otherWorker([String id = outboxWorkerId]) =>
    Principal.systemWorker(id);

/// A human principal. Never a valid assessor.
Principal humanPrincipal([String id = customerId]) =>
    Principal.fromVerifiedSubject(id);

// -------------------------------------------------------- hostile test inputs

/// Deliberately invalid strings used to prove debug renderings never echo raw
/// untrusted content. None is a valid opaque id.
const String hostileNewline = 'evil\nINJECTED-LOG-LINE\tTAB';
const String hostileUrl = 'https://attacker.example/steal?token=abc123456789';
const String hostilePath = '/var/secrets/../../etc/passwd';
// Note the `/` and `=`: both are outside the canonical opaque-id alphabet, so
// this really is malformed. A marker built only from `[A-Za-z0-9_-]` would be a
// *valid* id and would silently stop testing the malformed path.
const String hostileSecret = 'AKIA/FAKE+SECRET=MARKER/0123456789';
const String hostileOversized =
    'OVERSIZED_0123456789012345678901234567890123456789'
    '0123456789012345678901234567890123456789';

const List<String> hostileStrings = <String>[
  hostileNewline,
  hostileUrl,
  hostilePath,
  hostileSecret,
  hostileOversized,
];

// ------------------------------------------------------------------- builders

/// The canonical server-resolved delivery context.
DeliveryProofAssessmentContext ctx({
  String resourceId = orderId,
  DeliveryProofPolicyRef policy = proofPolicy,
  DeliveryEvidenceRef? evidence,
  String authorizedAssessor = verifierId,
}) => DeliveryProofAssessmentContext(
  resourceId: resourceId,
  policyRef: policy,
  evidenceRef:
      evidence ??
      DeliveryEvidenceRef(resourceId: resourceId, evidenceId: evidenceA),
  authorizedAssessorPrincipalId: authorizedAssessor,
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

/// Canonical absence for one order.
const DeliveryProofAssessmentFacts absentAssessment =
    DeliveryProofAssessmentFacts.absent(resourceId: orderId);

/// Build one record directly, for validator and rendering tests.
///
/// Every field is overridable **because malformed instances must be
/// representable** — that is what lets the validator and the fail-safe
/// renderings be tested at all.
DeliveryProofAssessmentRecord record({
  String assessmentId = asmtA,
  String resourceId = orderId,
  int assessmentRevision = 1,
  DeliveryProofPolicyRef policyRef = proofPolicy,
  DeliveryEvidenceRef? evidenceRef,
  String riderPrincipalId = riderA,
  String riderAssignmentId = rideAsgA,
  int riderAssignmentGeneration = 1,
  String assessedByPrincipalId = verifierId,
  PrincipalKind assessedByKind = PrincipalKind.systemWorker,
  DateTime? assessedAtUtc,
  DeliveryProofAssessmentVerdict verdict =
      DeliveryProofAssessmentVerdict.satisfied,
  String? supersedesAssessmentId,
}) => DeliveryProofAssessmentRecord(
  assessmentId: assessmentId,
  resourceId: resourceId,
  assessmentRevision: assessmentRevision,
  policyRef: policyRef,
  evidenceRef:
      evidenceRef ??
      DeliveryEvidenceRef(resourceId: resourceId, evidenceId: evidenceA),
  riderPrincipalId: riderPrincipalId,
  riderAssignmentId: riderAssignmentId,
  riderAssignmentGeneration: riderAssignmentGeneration,
  assessedByPrincipalId: assessedByPrincipalId,
  assessedByKind: assessedByKind,
  assessedAtUtc: assessedAtUtc ?? assessedAt,
  verdict: verdict,
  supersedesAssessmentId: supersedesAssessmentId,
);

/// Evaluate one assessment, defaulting every fact to a healthy dispatched
/// delivery so each test changes exactly one thing.
DeliveryProofAssessmentOutcome run({
  String assessmentId = asmtA,
  DeliveryProofAssessmentVerdict verdict =
      DeliveryProofAssessmentVerdict.satisfied,
  Principal? assessor,
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
  final DeliveryProofAssessmentFacts a = assessment ?? absentAssessment;
  final OrderLifecycleFacts o = order ?? inDelivery();
  final CustodyFacts? cu = omitCustody ? null : custody ?? withRider();
  final RiderAssignmentFacts? r = omitRider
      ? null
      : riderFacts ?? riderInDelivery();
  return evaluateDeliveryProofAssessment(
    request: DeliveryProofAssessmentRequest(
      assessmentId: assessmentId,
      verdict: verdict,
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
    assessor: assessor ?? verifier(),
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
/// **Test infrastructure only — not persistence evidence.** See the file
/// header: real atomicity is **DPA14**, NOT RUN.
DeliveryProofAssessmentFacts applyAssessment(
  DeliveryProofAssessmentTransition t, {
  String resourceId = orderId,
}) => DeliveryProofAssessmentFacts(
  resourceId: resourceId,
  assessmentRevision: t.resultingAssessmentRevision,
  current: t.record,
);

// ------------------------------------------------------------ source scanning

/// Strips doc comments so prose ruling a token out cannot mask a declaration.
///
/// Source scanners built on this are **supplementary** to the behavioural
/// suites, never a replacement for them.
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

/// Every hand-written production file in the assessment module.
const List<String> assessmentSourceFiles = <String>[
  'lib/src/delivery_proof_assessment.dart',
  'lib/src/delivery_proof_assessment_authority.dart',
  'lib/src/delivery_proof_assessment_denial.dart',
  'lib/src/delivery_proof_assessment_evaluator.dart',
  'lib/src/delivery_proof_assessment_event.dart',
  'lib/src/delivery_proof_assessment_facts.dart',
  'lib/src/delivery_proof_assessment_record.dart',
  'lib/src/delivery_proof_assessment_transition.dart',
  'lib/src/delivery_proof_assessment_validation.dart',
  'lib/src/delivery_proof_assessment_verdict.dart',
];
