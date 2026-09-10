import 'package:cp_contracts/cp_contracts.dart';

import 'custody_fixtures.dart';
import 'delivery_proof_assessment_fixtures.dart';

/// Shared builders for the FND-003D2B fallback dispute suites.
///
/// **TEST INFRASTRUCTURE ONLY.** Nothing here is evidence that real persistence
/// is correct. [applyDispute] in particular imitates a backend write: the
/// dispute record, the current pointer, the dedupe result and the outbox event
/// must commit in ONE transaction — criterion **DPD6** — which remains **NOT
/// RUN**, as do **DPD1–DPD10** in full.

// ---------------------------------------------------------------- identities

const String disputeA = 'dsp_Aa11Bb22Cc33Dd44';
const String disputeB = 'dsp_Bb22Cc33Dd44Ee55';

/// The order's customer. The same identity the assessment suites use.
const String raiserId = customerId;

/// A different customer, for "acting on somebody else's order" cases.
const String otherCustomerId = 'usr_cust02Aa-Bb22Cc';

/// An administrator with dispute authority.
const String adminId = 'usr_admn01Aa-Bb22Cc';

/// A second administrator, for two-party cases.
const String otherAdminId = 'usr_admn02Aa-Bb22Cc';

final DateTime raisedAt = DateTime.utc(2026, 9, 11, 9, 15);
final DateTime reviewedAt = DateTime.utc(2026, 9, 11, 11, 45);

/// The order's customer, as the backend would derive them.
Principal customer([String id = raiserId]) => Principal.fromVerifiedSubject(id);

/// An administrator, as the backend would derive them.
Principal admin([String id = adminId]) => Principal.fromVerifiedSubject(id);

/// A trusted worker. **Never** a valid dispute actor — the exact inverse of the
/// assessment contract, where only a trusted worker may act.
Principal worker([String id = outboxWorkerId]) => Principal.systemWorker(id);

// ------------------------------------------------------------------- builders

/// A **real** `AuthorizationGrant`, produced by running the canonical
/// `evaluateAuthorization` — the only way one can be obtained.
///
/// *(Added by FND-003D2B-FIX-002.)* There is no shortcut here on purpose: the
/// grant is `final` with a library-private constructor, so a test cannot
/// fabricate one any more than production can. Every allow-path test therefore
/// travels the same authorization path a backend would.
AuthorizationGrant disputeGrant({
  required Permission permission,
  required String principalId,
  required CommerceRole role,
  String resourceId = orderId,
  String ownerId = raiserId,
  String memberRegion = region,
  String resourceRegion = region,
  MembershipStatus status = MembershipStatus.active,
  String? reason = 'goods never arrived',
}) {
  final AuthorizationDecision decision = evaluateAuthorization(
    AuthorizationRequest(
      permission: permission,
      scope: ResourceScope(
        resourceId: resourceId,
        ownerPrincipalId: ownerId,
        shopId: shopId,
        regionId: resourceRegion,
      ),
      principal: Principal.fromVerifiedSubject(principalId),
      membership: Membership(
        principalId: principalId,
        role: role,
        status: status,
        regionId: memberRegion,
      ),
      reason: reason,
    ),
  );
  final AuthorizationGrant? grant = decision.grant;
  if (grant == null) {
    throw StateError(
      'fixture expected an allow but got ${decision.reason?.name}',
    );
  }
  return grant;
}

/// The order owner's canonical grant for raising a dispute.
AuthorizationGrant customerRaiseGrant({
  String principalId = raiserId,
  String resourceId = orderId,
}) => disputeGrant(
  permission: Permission.customerRaiseDispute,
  principalId: principalId,
  role: CommerceRole.customer,
  resourceId: resourceId,
  ownerId: principalId,
);

/// An in-region active administrator's canonical grant for administering a
/// dispute, with the required reason.
AuthorizationGrant adminAdministerGrant({
  String principalId = adminId,
  String resourceId = orderId,
}) => disputeGrant(
  permission: Permission.adminAdministerDispute,
  principalId: principalId,
  role: CommerceRole.admin,
  resourceId: resourceId,
);

/// Canonical absence for one order: never disputed.
const DeliveryProofDisputeFacts noDispute = DeliveryProofDisputeFacts.absent(
  resourceId: orderId,
);

/// An assessment aggregate holding one canonical record.
///
/// A revision above 1 supersedes something, because
/// `validateDeliveryProofAssessmentAggregate` requires the backward pointer and
/// the revision to agree.
DeliveryProofAssessmentFacts assessed({
  DeliveryProofAssessmentVerdict verdict =
      DeliveryProofAssessmentVerdict.notSatisfied,
  String assessmentId = asmtA,
  int revision = 1,
  String resourceId = orderId,
  String? supersedes,
}) => DeliveryProofAssessmentFacts(
  resourceId: resourceId,
  assessmentRevision: revision,
  current: record(
    assessmentId: assessmentId,
    resourceId: resourceId,
    assessmentRevision: revision,
    verdict: verdict,
    supersedesAssessmentId: supersedes ?? (revision > 1 ? asmtA : null),
  ),
);

/// A **torn** assessment aggregate: the record's own revision disagrees with
/// the aggregate's. The validator refuses it, and it must never become a
/// dispute basis.
DeliveryProofAssessmentFacts tornAssessment({
  DeliveryProofAssessmentVerdict verdict =
      DeliveryProofAssessmentVerdict.notSatisfied,
}) => DeliveryProofAssessmentFacts(
  resourceId: orderId,
  assessmentRevision: 2,
  current: record(assessmentRevision: 1, verdict: verdict),
);

/// The basis an **actual raise** produced against [assessment].
///
/// *(Replaces `basisFrom`, removed by FND-003D2B-FIX-001.)* The old helper
/// mirrored production eligibility logic in the test tree and would happily
/// manufacture a `notSatisfied` basis from a **satisfied** assessment — a state
/// the evaluator can never produce. A helper that can build something
/// production refuses is not a fixture, it is a second implementation, and it
/// hid exactly the contradiction the standing calculation now rejects.
///
/// Canonical positive bases therefore come from a real evaluator-produced raise
/// transition. Deliberately malformed or contradictory bases are still
/// constructed directly, inline, where the test can show what is wrong with
/// them.
DeliveryProofDisputeBasis raisedBasis({
  DeliveryProofAssessmentFacts? assessment,
}) => allowedDispute(runRaise(assessment: assessment)).record.basis;

/// Build one dispute record directly, for validator and rendering tests.
///
/// Every field is overridable **because malformed instances must be
/// representable** — that is what lets the validator and the fail-safe
/// renderings be tested at all.
DeliveryProofDisputeRecord disputeRecord({
  String disputeId = disputeA,
  String resourceId = orderId,
  int disputeRevision = 1,
  DeliveryProofDisputeBasis? basis,
  String raisedByPrincipalId = raiserId,
  DateTime? raisedAtUtc,
  DeliveryProofDisputeState state = DeliveryProofDisputeState.open,
  String? reviewStartedByPrincipalId,
  DateTime? reviewStartedAtUtc,
}) => DeliveryProofDisputeRecord(
  disputeId: disputeId,
  resourceId: resourceId,
  disputeRevision: disputeRevision,
  basis:
      basis ?? DeliveryProofDisputeBasis.notAssessed(resourceId: resourceId),
  raisedByPrincipalId: raisedByPrincipalId,
  raisedAtUtc: raisedAtUtc ?? raisedAt,
  state: state,
  reviewStartedByPrincipalId: reviewStartedByPrincipalId,
  reviewStartedAtUtc: reviewStartedAtUtc,
);

/// An aggregate holding one open dispute.
DeliveryProofDisputeFacts openDispute({
  String disputeId = disputeA,
  String resourceId = orderId,
  DeliveryProofDisputeBasis? basis,
  String raisedByPrincipalId = raiserId,
}) => DeliveryProofDisputeFacts(
  resourceId: resourceId,
  disputeRevision: 1,
  current: disputeRecord(
    disputeId: disputeId,
    resourceId: resourceId,
    basis: basis,
    raisedByPrincipalId: raisedByPrincipalId,
  ),
);

/// An aggregate holding one dispute already under review.
DeliveryProofDisputeFacts reviewedDispute({
  String disputeId = disputeA,
  String reviewer = adminId,
}) => DeliveryProofDisputeFacts(
  resourceId: orderId,
  disputeRevision: 2,
  current: disputeRecord(
    disputeId: disputeId,
    disputeRevision: 2,
    state: DeliveryProofDisputeState.underReview,
    reviewStartedByPrincipalId: reviewer,
    reviewStartedAtUtc: reviewedAt,
  ),
);

// ----------------------------------------------------------------- evaluation

/// Raise a dispute, defaulting every fact to a healthy dispatched delivery with
/// no assessment, so each test changes exactly one thing.
DeliveryProofDisputeOutcome runRaise({
  String disputeId = disputeA,
  Principal? actor,
  AuthorizationGrant? grant,
  DateTime? at,
  DeliveryProofDisputeFacts? dispute,
  DeliveryProofAssessmentFacts? assessment,
  OrderLifecycleFacts? order,
  int? expectedDisputeRevision,
  int? expectedAssessmentRevision,
  int? expectedOrderRevision,
}) {
  final DeliveryProofDisputeFacts d = dispute ?? noDispute;
  final DeliveryProofAssessmentFacts a = assessment ?? absentAssessment;
  final OrderLifecycleFacts o = order ?? inDelivery();
  return evaluateRaiseDeliveryProofDispute(
    request: DeliveryProofDisputeRaiseRequest(
      disputeId: disputeId,
      atUtc: at ?? raisedAt,
      expectedDisputeRevision: expectedDisputeRevision ?? d.disputeRevision,
      expectedAssessmentRevision:
          expectedAssessmentRevision ?? a.assessmentRevision,
      expectedOrderRevision: expectedOrderRevision ?? o.revision,
    ),
    actor: actor ?? customer(),
    grant: grant ?? customerRaiseGrant(),
    dispute: d,
    assessment: a,
    order: o,
  );
}

/// Record that review started, defaulting to one open dispute.
///
/// **Takes no assessment and no order facts**, because the corrected operation
/// reads neither — see `evaluateRecordDeliveryProofDisputeReview`. There is
/// nothing for a fixture to supply, which is the point: the independence is
/// structural rather than a value a test remembered to pass.
DeliveryProofDisputeOutcome runReview({
  String disputeId = disputeA,
  Principal? actor,
  AuthorizationGrant? grant,
  DateTime? at,
  DeliveryProofDisputeFacts? dispute,
  int? expectedDisputeRevision,
}) {
  final DeliveryProofDisputeFacts d = dispute ?? openDispute();
  final Principal a = actor ?? admin();
  return evaluateRecordDeliveryProofDisputeReview(
    request: DeliveryProofDisputeReviewRequest(
      disputeId: disputeId,
      atUtc: at ?? reviewedAt,
      expectedDisputeRevision: expectedDisputeRevision ?? d.disputeRevision,
    ),
    actor: a,
    grant: grant ?? adminAdministerGrant(principalId: a.id),
    dispute: d,
  );
}

/// Attempt the deliberately non-executable resolution edge.
///
/// It takes nothing, because `evaluateResolveDeliveryProofDispute` takes
/// nothing: a deferred edge consumes no request and no fact.
DeliveryProofDisputeOutcome runResolve() =>
    evaluateResolveDeliveryProofDispute();

DeliveryProofDisputeTransition allowedDispute(DeliveryProofDisputeOutcome o) {
  final DeliveryProofDisputeTransition? t = o.transition;
  if (t == null) {
    throw StateError('expected allow, got ${o.denial?.name}');
  }
  return t;
}

/// Applies a transition to produce the next trusted facts, as a backend would.
///
/// **Test infrastructure only — not persistence evidence.** See the file
/// header: real atomicity is **DPD6**, NOT RUN.
DeliveryProofDisputeFacts applyDispute(
  DeliveryProofDisputeTransition t, {
  String resourceId = orderId,
}) => DeliveryProofDisputeFacts(
  resourceId: resourceId,
  disputeRevision: t.resultingDisputeRevision,
  current: t.record,
);

// ------------------------------------------------------------ source scanning

/// Every hand-written production file in the dispute module.
const List<String> disputeSourceFiles = <String>[
  'lib/src/delivery_proof_dispute.dart',
  'lib/src/delivery_proof_dispute_basis.dart',
  'lib/src/delivery_proof_dispute_command.dart',
  'lib/src/delivery_proof_dispute_denial.dart',
  'lib/src/delivery_proof_dispute_evaluator.dart',
  'lib/src/delivery_proof_dispute_facts.dart',
  'lib/src/delivery_proof_dispute_record.dart',
  'lib/src/delivery_proof_dispute_state.dart',
  'lib/src/delivery_proof_dispute_transition.dart',
  'lib/src/delivery_proof_dispute_validation.dart',
];

/// Vocabulary that would mean this slice had decided a financial consequence.
///
/// Every token is chosen so it cannot appear incidentally in Dart. `return`,
/// `code` and `currency` are deliberately **absent**: the first two are
/// ordinary language in any source file, and `currency` is a substring of
/// `concurrency`, which this module discusses at length. A guard that trips on
/// ordinary prose is one somebody eventually weakens, so the money check is
/// anchored on `Money`'s own vocabulary — `minorUnits` — plus terms that have
/// no other meaning here.
const List<String> financialVocabulary = <String>[
  'money',
  'minorunits',
  'refund',
  'compensation',
  'liability',
  'commission',
  'settlement',
  'remittance',
  'journal',
  'ledger',
  'posting',
  'payable',
  'invoice',
  'penalty',
];

/// Outcome vocabulary that would mean this slice had decided how a dispute
/// resolves.
const List<String> outcomeVocabulary = <String>[
  'upheld',
  'rejected',
  'dismissed',
  'withdrawn',
  'closed',
  'fault',
  'blame',
  'winner',
  'verdictfor',
  'awarded',
];
