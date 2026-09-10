import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// Why a delivery-proof reference was rejected.
///
/// **Internal.** For backend logs, tests and audit — not returned verbatim to
/// an untrusted caller, for the same reason `DenyReason`, `LifecycleDenial`,
/// `AssignmentDenial` and `CustodyDenial` are not.
///
/// Every value here is **structural**. There is deliberately no value meaning
/// "the proof was not satisfied": whether a policy is satisfied is a decision
/// no slice has made, and inventing a denial for it would be inventing the
/// decision.
enum DeliveryProofDenial {
  /// The policy reference is blank or whitespace-only.
  policyRefBlank,

  /// The evidence reference names a resource that is not a valid opaque id.
  evidenceResourceIdInvalid,

  /// The evidence identifier is not a valid opaque id.
  evidenceIdInvalid,

  /// The evidence reference belongs to a different resource than the one being
  /// acted on. **Evidence is not portable between orders.**
  evidenceResourceMismatch,
}

/// Which immutable delivery-proof policy applies to an order.
///
/// **A reference, never a result.** It says *which policy governs*, not that
/// the policy has been satisfied, and it says nothing at all about *how* proof
/// would be captured.
///
/// **No mechanism is selected here.** OTP, QR, barcode, signature, photograph,
/// video, GPS, biometric, customer confirmation, device attestation and
/// notification acknowledgement are all absent, and none is implied by holding
/// one of these. Choosing among them is a later bounded task's decision, made
/// with `CONSTRAINTS.md` invariant 13 in front of it — not something this
/// contract may pre-empt by naming one.
///
/// **No grammar is imposed.** The repository has no delivery-proof policy
/// vocabulary to reuse, and inventing one — a prefix, a version suffix, a
/// namespace — would be inventing a contract rather than referring to it. The
/// only structural rule is that the reference is not blank.
///
/// > **Not client authority.** A caller does not choose which policy applies by
/// > sending one of these. The backend resolves the authoritative policy from
/// > trusted order and policy state; this is the shape that resolution fills.
/// > Constructing one authenticates nobody and authorizes nothing.
///
/// The exact value is preserved. It is **never trimmed, normalised or repaired
/// into equality** — `' policy/x '` and `'policy/x'` are different references,
/// because silently equating them would let a corrupt stored value pass as a
/// good one.
@immutable
class DeliveryProofPolicyRef {
  const DeliveryProofPolicyRef(this.value);

  /// The opaque policy reference, exactly as the backend resolved it.
  final String value;

  /// Structurally usable: present and not whitespace-only.
  ///
  /// `trim()` is used **only to reject blank values**. The stored [value] is
  /// untouched.
  bool get isWellFormed => value.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is DeliveryProofPolicyRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'DeliveryProofPolicyRef($value)';
}

/// A pointer to protected delivery evidence held for one order.
///
/// **A reference, never the material.** This carries an identifier and the
/// resource it belongs to. It carries **no proof bytes or text**: no
/// photograph, no signature, no OTP or code, no QR payload, no biometric
/// template, no GPS coordinate, no address, no phone number, no order contents
/// and no money amount. A copy of this object can travel anywhere an id may
/// travel and leak nothing beyond the fact that evidence exists.
///
/// **It proves nothing.** It does not assert the evidence is authentic, that it
/// was captured by the right person, that it satisfies any policy, or that
/// delivery happened. Holding one authorizes nobody: the evidence itself is
/// fetched later over an authenticated, authorized protected path that **this
/// task does not implement**.
///
/// **Bound to its resource.** [belongsTo] compares the resource **exactly**, so
/// an evidence reference from one order cannot be presented against another.
/// That is the whole reason the resource travels with the id instead of being
/// supplied alongside it at the call site, where the two could drift apart.
@immutable
class DeliveryEvidenceRef {
  const DeliveryEvidenceRef({
    required this.resourceId,
    required this.evidenceId,
  });

  /// The order this evidence belongs to. Validated with the repository's
  /// canonical opaque-id rule — the same one `Principal`, `CommandEnvelope` and
  /// `EventEnvelope` apply.
  final String resourceId;

  /// Server-assigned, opaque identifier for the stored evidence.
  ///
  /// **Not a storage path, URL or signed URL**, and deliberately not shaped
  /// like one: a locator would imply a retrieval and access design that no
  /// slice has made.
  final String evidenceId;

  /// Structurally usable: both identities satisfy the canonical opaque-id rule.
  bool get isWellFormed =>
      isValidOpaqueId(resourceId) && isValidOpaqueId(evidenceId);

  /// Whether this evidence belongs to [resourceId], compared **exactly**.
  /// Nothing is trimmed or normalised into a match.
  bool belongsTo(String resourceId) => this.resourceId == resourceId;

  @override
  bool operator ==(Object other) =>
      other is DeliveryEvidenceRef &&
      other.resourceId == resourceId &&
      other.evidenceId == evidenceId;

  @override
  int get hashCode => Object.hash(resourceId, evidenceId);

  /// Deliberately identifier-only, so a log line or a crash report cannot
  /// become an evidence leak.
  @override
  String toString() =>
      'DeliveryEvidenceRef($evidenceId for $resourceId)';
}

/// Structural validation for a policy reference. Returns null when usable.
///
/// **Structural only.** It cannot say whether the policy is satisfied, because
/// no slice defines satisfaction. Fails closed; repairs nothing.
DeliveryProofDenial? validateDeliveryProofPolicyRef(
  DeliveryProofPolicyRef ref,
) => ref.isWellFormed ? null : DeliveryProofDenial.policyRefBlank;

/// Structural validation for an evidence reference against the resource being
/// acted on. Returns null when usable.
///
/// **Structural only.** A null result means "this reference is well formed and
/// belongs to this order" — **not** that the evidence is authentic, sufficient,
/// or that anything was delivered. Fails closed; repairs nothing.
DeliveryProofDenial? validateDeliveryEvidenceRef(
  DeliveryEvidenceRef ref, {
  required String resourceId,
}) {
  if (!isValidOpaqueId(ref.resourceId)) {
    return DeliveryProofDenial.evidenceResourceIdInvalid;
  }
  if (!isValidOpaqueId(ref.evidenceId)) {
    return DeliveryProofDenial.evidenceIdInvalid;
  }
  if (!ref.belongsTo(resourceId)) {
    return DeliveryProofDenial.evidenceResourceMismatch;
  }
  return null;
}
