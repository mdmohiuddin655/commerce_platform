import 'package:cp_contracts/src/assignment_effect.dart';
import 'package:cp_contracts/src/delivery_proof.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_denial.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_event.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/lifecycle_effect.dart';
import 'package:meta/meta.dart';

/// A permitted assessment: the immutable record to append, and nothing else.
///
/// **Every commercial effect is NONE, structurally.** There is no order effect
/// field, no custody effect field and no assignment effect field on this class,
/// so a transition *cannot* be constructed that moves any of them — that is a
/// stronger statement than a runtime check, and it is why they are getters
/// returning constants rather than constructor parameters.
///
/// A `satisfied` assessment therefore does **not**: move `in_delivery →
/// delivered`, move rider custody to the customer, complete the rider
/// assignment, restore inventory, settle COD, or open or close a dispute. It is
/// only a prerequisite result that a later atomic delivery transaction may
/// consume — see `docs/contracts/delivery-proof-assessment.md`.
@immutable
class DeliveryProofAssessmentTransition {
  /// The record is the **only** input.
  ///
  /// *(Narrowed by FND-003D2A-FIX-001.)* [events] used to be a constructor
  /// parameter, which let a caller construct an assessment transition carrying
  /// arbitrary, extra or zero event ids — including a fabricated
  /// `delivery.proof_satisfied` that no vocabulary defines. The contract says
  /// exactly one event exists, so that is now a property of the type rather
  /// than a value a caller supplies.
  const DeliveryProofAssessmentTransition({required this.record});

  /// The immutable record to append. Its own revision is the aggregate's
  /// resulting revision.
  final DeliveryProofAssessmentRecord record;

  /// Every domain fact this assessment causes, in order. **Exactly one, always,
  /// and not selectable by any caller.**
  ///
  /// `const`, so the returned list is deeply immutable: an attempt to add to it
  /// throws `UnsupportedError` rather than silently extending the vocabulary.
  ///
  /// It **must commit atomically with** the assessment record and the dedupe
  /// result — criterion **DPA14**. Notification delivery is not part of that
  /// transaction: a push is a hint, never authorization or proof, and it may
  /// simply be missed.
  List<String> get events =>
      const <String>[DeliveryProofAssessmentEventType.proofAssessed];

  /// Always the previous revision + 1.
  int get resultingAssessmentRevision => record.assessmentRevision;

  /// The assessment this one supersedes, or null when it is the first.
  String? get supersededAssessmentId => record.supersedesAssessmentId;

  /// Whether this is a reassessment rather than a first assessment.
  bool get isReassessment => record.supersedesAssessmentId != null;

  DeliveryProofAssessmentVerdict get verdict => record.verdict;

  /// Assessment never touches stock. Concluding something about evidence
  /// creates and destroys no units, in either verdict.
  InventoryEffect get inventoryEffect => const InventoryEffect.none();

  /// Recording a verdict posts no money and never will.
  ///
  /// **This classifies the recording, not the consequence.** Whether a
  /// `notSatisfied` outcome eventually has a financial consequence — a fee, a
  /// liability, a refund, a settlement effect — is **UNKNOWN and deferred to
  /// FND-003C**, itself blocked on owner decision **O6**. It must never be read
  /// as zero, and nothing here permits deriving an amount.
  FinancialClassification get financialClassification =>
      FinancialClassification.noneInThisSlice;

  /// Assessment grants no authorization projection change. **Being assessed is
  /// not permission**, in either direction.
  ScopeProjectionEffect get scopeEffect => const ScopeProjectionEffect.none();

  /// The order is untouched — no state, no revision.
  bool get changesOrderState => false;

  /// Custody is untouched. A verdict does not move goods.
  bool get changesCustody => false;

  /// The rider assignment is untouched. In particular, `satisfied` does **not**
  /// complete it: rider `AssignmentState.completed` remains unreachable and no
  /// revision cost for it was invented — criterion **B3-C2**, FUTURE.
  bool get changesRiderAssignment => false;

  /// A **debug representation, and never a validity claim.**
  ///
  /// *(Hardened by FND-003D2A-FIX-001.)* A transition wrapping a malformed
  /// record renders nothing of it. The record's own `toString` is already fail
  /// safe, and this method additionally refuses to emit the derived revision or
  /// supersession pointer, so no untrusted fragment escapes through the wrapper
  /// either.
  @override
  String toString() => record.isWellFormed
      ? 'DeliveryProofAssessmentTransition(${record.verdict.id}, '
            'rev=$resultingAssessmentRevision, id=${record.assessmentId}, '
            'supersedes=${supersededAssessmentId ?? '-'})'
      : 'DeliveryProofAssessmentTransition(invalid)';
}

/// Result of evaluating one request: exactly one of allowed or denied.
@immutable
class DeliveryProofAssessmentOutcome {
  const DeliveryProofAssessmentOutcome._(
    this.transition,
    this.denial,
    this.structuralDenial,
  );

  const DeliveryProofAssessmentOutcome.allow(
    DeliveryProofAssessmentTransition transition,
  ) : this._(transition, null, null);

  const DeliveryProofAssessmentOutcome.deny(
    DeliveryProofAssessmentDenial denial, {
    DeliveryProofDenial? structural,
  }) : this._(null, denial, structural);

  /// Null for **every** denial. A denied assessment mutates nothing, emits no
  /// event, and produces no order, reservation, inventory, financial, custody
  /// or assignment effect.
  final DeliveryProofAssessmentTransition? transition;

  final DeliveryProofAssessmentDenial? denial;

  /// The exact FND-003D1 structural reason, when the denial came from a
  /// reference validator.
  ///
  /// Carried rather than collapsed so a log does not have to guess whether a
  /// policy reference was blank or over-long, or whether an evidence reference
  /// had a broken id or simply named another order. The D1 validators remain
  /// the single source of that judgement — nothing is reimplemented here.
  final DeliveryProofDenial? structuralDenial;

  bool get allowed => transition != null;

  /// Renders through the transition's own fail-safe `toString`, so a malformed
  /// record cannot reach a log through this wrapper. Denials render enum names
  /// only — never caller-supplied content.
  @override
  String toString() => allowed
      ? 'Allow(${transition!})'
      : 'Deny(${denial!.name}'
            '${structuralDenial == null ? '' : '/${structuralDenial!.name}'})';
}
