import 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_validation.dart';
import 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// Which proof-assessment situation a fallback dispute was raised against.
///
/// **Exactly the two situations the FND-003D2B boundary names as fallback
/// grounds**, and deliberately no others:
///
/// ```text
/// "Fallback dispute workflow for a missing, superseded or
///  `notSatisfied` assessment."
/// ```
///
/// *Superseded* is not a third kind here, and that is the point: supersession
/// is something that happens to a basis **after** it is recorded, not a state a
/// dispute can be raised against. A dispute is always raised against the
/// **current canonical** situation, and
/// [resolveDeliveryProofDisputeBasisStanding] reports afterwards whether that
/// recorded basis is still current or has since been superseded. Modelling
/// supersession as a basis *kind* would have frozen a moving fact into
/// immutable history.
///
/// Four situations are deliberately **absent**, each for its own reason:
///
/// | Situation | Why it is not a basis kind |
/// |---|---|
/// | current canonical `satisfied` | not a fallback ground; disputing a satisfied assessment is a different, undefined workflow — denied `assessmentSatisfied` |
/// | malformed or torn assessment facts | corruption is a reconciliation case, never a negative result — denied `assessmentAggregateInconsistent` |
/// | superseded | a *standing*, not a kind — see above |
/// | anything about delivery, refusal or return | no slice defines them |
enum DeliveryProofDisputeBasisKind {
  /// **No usable assessment existed** for the order: canonical absence,
  /// assessment revision `0` with no record.
  ///
  /// This is *not assessed*, and it is **never** the same as `notSatisfied`.
  /// Collapsing the two would let "nobody has looked at this yet" be read as
  /// "a trusted verifier concluded the policy failed", which is precisely the
  /// confusion `DeliveryProofAssessmentFacts.absent` exists to prevent.
  notAssessed,

  /// The **current canonical** assessment carried
  /// [DeliveryProofAssessmentVerdict.notSatisfied].
  ///
  /// It means only what D2A says it means: the trusted verifier concluded the
  /// referenced policy was not satisfied by the referenced evidence. It is not
  /// fraud, refusal, cancellation, delivery failure, fee liability, a refund or
  /// financial default, and raising a dispute on it decides none of those
  /// either.
  notSatisfied;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    DeliveryProofDisputeBasisKind.notAssessed => 'not_assessed',
    DeliveryProofDisputeBasisKind.notSatisfied => 'not_satisfied',
  };

  static DeliveryProofDisputeBasisKind? byId(String id) {
    for (final DeliveryProofDisputeBasisKind k
        in DeliveryProofDisputeBasisKind.values) {
      if (k.id == id) {
        return k;
      }
    }
    return null;
  }
}

/// The immutable audit identity of **what was being disputed**.
///
/// This is the reason ADR-0009 made assessment history append-only. A dispute
/// has to be able to say *"the assessment that was current when this was
/// raised"* and have that still mean something after three reassessments —
/// which is only possible if the earlier record is neither rewritten nor
/// erased, and if the dispute pins the exact identity it was raised against.
///
/// **It is a pointer, never a copy.** It carries an assessment id and revision,
/// and deliberately **no** policy reference, evidence reference, verdict copy,
/// rider identity, verifier identity or timestamp of the assessment:
///
/// - **no raw proof material can be here, because none is here at all** — not
///   even the D1 references, let alone anything they point at;
/// - a copied field is a projection that can drift from the record that owns
///   it, and the append-only record remains the single source of every one of
///   those values. That is the same reason `CustodyHolder` binds an assignment
///   *attempt* rather than projecting who is assigned now.
///
/// The verdict is the one apparent exception, and it is not a copy: [kind]
/// records which **fallback ground** applied, and for
/// [DeliveryProofDisputeBasisKind.notAssessed] there is no record to copy
/// anything from.
@immutable
class DeliveryProofDisputeBasis {
  const DeliveryProofDisputeBasis._({
    required this.resourceId,
    required this.kind,
    required this.assessmentId,
    required this.assessmentRevision,
  });

  /// No usable assessment existed: canonical absence.
  ///
  /// There is no assessment id, because there is no assessment. The revision is
  /// `0`, following the repository's convention that revision 0 means "never
  /// written" — the same value `DeliveryProofAssessmentFacts.absent` carries,
  /// so the two cannot disagree.
  const DeliveryProofDisputeBasis.notAssessed({required String resourceId})
    : this._(
        resourceId: resourceId,
        kind: DeliveryProofDisputeBasisKind.notAssessed,
        assessmentId: null,
        assessmentRevision: 0,
      );

  /// The current canonical assessment concluded `notSatisfied`.
  ///
  /// Both the id **and** the revision are pinned. The id alone would not be
  /// enough to say *which* aggregate state was contested, and the revision
  /// alone would not survive being compared against a different assessment
  /// that happens to sit at the same number.
  const DeliveryProofDisputeBasis.notSatisfied({
    required String resourceId,
    required String assessmentId,
    required int assessmentRevision,
  }) : this._(
         resourceId: resourceId,
         kind: DeliveryProofDisputeBasisKind.notSatisfied,
         assessmentId: assessmentId,
         assessmentRevision: assessmentRevision,
       );

  /// The order this basis is about.
  final String resourceId;

  /// Which fallback ground applied when the dispute was raised.
  final DeliveryProofDisputeBasisKind kind;

  /// The disputed assessment, or null for [DeliveryProofDisputeBasisKind
  /// .notAssessed].
  final String? assessmentId;

  /// The assessment aggregate revision the dispute was raised against. `0`
  /// exactly when nothing had been assessed.
  final int assessmentRevision;

  /// Structurally usable. Fails closed; repairs nothing.
  ///
  /// The id and revision must agree with [kind] in **both** directions, so
  /// neither "absence carrying an assessment id" nor "a negative result with no
  /// id" can be represented as a valid basis.
  bool get isWellFormed {
    if (!isValidOpaqueId(resourceId)) {
      return false;
    }
    return switch (kind) {
      DeliveryProofDisputeBasisKind.notAssessed =>
        assessmentId == null && assessmentRevision == 0,
      DeliveryProofDisputeBasisKind.notSatisfied =>
        assessmentId != null &&
            isValidOpaqueId(assessmentId!) &&
            assessmentRevision >= 1,
    };
  }

  /// Whether this basis is **structurally valid and about** [resourceId].
  ///
  /// Both halves are required. Raw equality alone would fail open: two
  /// identically-malformed values would match and certify a broken basis.
  bool belongsToResource(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  /// Whether this basis **structurally identifies exactly** the named
  /// assessment.
  ///
  /// A `true` here is a four-part claim, and all four must hold:
  ///
  /// 1. this basis is well formed;
  /// 2. it names an assessment at all — a `notAssessed` basis identifies **no**
  ///    assessment and always answers false, including when a caller passes an
  ///    empty id;
  /// 3. the supplied id is itself a valid canonical opaque id and the supplied
  ///    revision is a reachable one (`>= 1`);
  /// 4. id and revision both compare **exactly**.
  ///
  /// Raw equality alone fails open, exactly as it did for
  /// `DeliveryProofAssessmentRecord.bindsRiderAttempt` before
  /// FND-003D2A-FIX-001: two identically-malformed ids would match and this
  /// convenience method would certify a binding the validator refuses.
  bool identifiesAssessment({
    required String assessmentId,
    required int assessmentRevision,
  }) =>
      isWellFormed &&
      this.assessmentId != null &&
      isValidOpaqueId(assessmentId) &&
      assessmentRevision >= 1 &&
      this.assessmentId == assessmentId &&
      this.assessmentRevision == assessmentRevision;

  @override
  bool operator ==(Object other) =>
      other is DeliveryProofDisputeBasis &&
      other.resourceId == resourceId &&
      other.kind == kind &&
      other.assessmentId == assessmentId &&
      other.assessmentRevision == assessmentRevision;

  @override
  int get hashCode =>
      Object.hash(resourceId, kind, assessmentId, assessmentRevision);

  /// A **debug representation, and never a validity claim.**
  ///
  /// Follows the FND-003D1 and FND-003D2A rule without exception: a well-formed
  /// basis renders canonical opaque identifiers, which are already bounded at
  /// [maxIdLength] and drawn from a restricted alphabet; a **malformed** one
  /// renders no field at all, not even the ones that happen to be sound.
  ///
  /// The constructors are public and `const`, so malformed instances are
  /// deliberately representable — that is what lets the validator be tested —
  /// and until validation has passed these are untrusted strings. Echoing even
  /// one would make any `print`, crash report or error message an amplification
  /// and log-injection surface reachable *before* validation.
  @override
  String toString() => isWellFormed
      ? 'DeliveryProofDisputeBasis(${kind.id} for $resourceId, '
            'assessment=${assessmentId ?? '-'}, rev=$assessmentRevision)'
      : 'DeliveryProofDisputeBasis(invalid)';
}

/// How a recorded dispute basis stands against the **current** assessment
/// aggregate.
///
/// This is the answer to *"is what we are disputing still what is true?"*, and
/// it is computed on demand rather than stored, because the stored basis is
/// immutable history and this is a moving fact about the present.
enum DeliveryProofDisputeBasisStanding {
  /// The recorded basis is still exactly the current canonical situation.
  current,

  /// The assessment aggregate has moved on since the dispute was raised.
  ///
  /// **The basis stays historically identifiable and is never rewritten.** A
  /// superseding assessment does not close, weaken, validate or invalidate the
  /// dispute, and — because no resolution exists — it certainly does not
  /// resolve it. In particular a later `satisfied` assessment does **not**
  /// dismiss the dispute: deciding that would be deciding the outcome.
  superseded,

  /// No trustworthy comparison is possible.
  ///
  /// Reached when the basis is malformed, when the assessment aggregate is
  /// **torn or corrupt**, when the two describe different orders, or when the
  /// current aggregate sits at a revision *earlier* than the basis — which the
  /// append-only model cannot produce and therefore means a partial or stale
  /// load.
  ///
  /// **Corruption is never reported as [current] or [superseded]**, for the
  /// same reason `canonicalVerdict` never downgrades a torn aggregate to
  /// `notSatisfied`: a fabricated comparison is worse than no comparison.
  indeterminate,
}

/// Whether [basis] is still the current canonical assessment situation.
///
/// Pure and fail closed. Reads the assessment aggregate through
/// `validateDeliveryProofAssessmentAggregate`, so a torn load can never produce
/// a confident answer, and **nothing here mutates, relabels or reinterprets any
/// assessment** — this function only compares.
DeliveryProofDisputeBasisStanding resolveDeliveryProofDisputeBasisStanding({
  required DeliveryProofDisputeBasis basis,
  required DeliveryProofAssessmentFacts assessment,
}) {
  if (!basis.isWellFormed) {
    return DeliveryProofDisputeBasisStanding.indeterminate;
  }
  // The canonical assessment validator is the single source of this judgement.
  // A torn aggregate is neither "still current" nor "superseded": it is a
  // reconciliation case.
  if (validateDeliveryProofAssessmentAggregate(assessment) != null) {
    return DeliveryProofDisputeBasisStanding.indeterminate;
  }
  if (!basis.belongsToResource(assessment.resourceId)) {
    return DeliveryProofDisputeBasisStanding.indeterminate;
  }
  // History only ever moves forward, so an aggregate behind the recorded basis
  // is a partial or stale read rather than a supersession in reverse.
  if (assessment.assessmentRevision < basis.assessmentRevision) {
    return DeliveryProofDisputeBasisStanding.indeterminate;
  }
  if (assessment.assessmentRevision > basis.assessmentRevision) {
    return DeliveryProofDisputeBasisStanding.superseded;
  }

  // Same revision: the identities must agree exactly, or the aggregate is not
  // the history this basis came from.
  final DeliveryProofAssessmentRecord? current = assessment.current;
  return switch (basis.kind) {
    DeliveryProofDisputeBasisKind.notAssessed =>
      current == null
          ? DeliveryProofDisputeBasisStanding.current
          : DeliveryProofDisputeBasisStanding.indeterminate,
    DeliveryProofDisputeBasisKind.notSatisfied =>
      current != null &&
              basis.identifiesAssessment(
                assessmentId: current.assessmentId,
                assessmentRevision: current.assessmentRevision,
              )
          ? DeliveryProofDisputeBasisStanding.current
          : DeliveryProofDisputeBasisStanding.indeterminate,
  };
}
