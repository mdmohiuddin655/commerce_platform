import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// Maximum length of a [DeliveryProofPolicyRef].
///
/// **A transport and resource-safety ceiling, not a grammar.** It says nothing
/// about what a policy reference may contain — only that it cannot be
/// unbounded. An unbounded string on a wire-facing value object is an
/// amplification surface: it travels through commands, events, logs and audit
/// records, and every one of those multiplies whatever a caller or a corrupt
/// stored value put in it.
///
/// **It aliases [maxIdLength]** — the repository's canonical ceiling for bounded
/// wire strings — rather than repeating its value. Writing `64` here again
/// would create a second numeric source of truth that could silently drift from
/// the first; the whole point of reusing the ceiling is that there is only one
/// number to reason about. `CommandEnvelope.commandType` sharing the same limit
/// is *supporting precedent*, not a second source.
///
/// The alias is a **numeric** coupling only. A policy reference does **not**
/// adopt opaque-id grammar: no minimum length, no alphabet, no prefix,
/// namespace or URI requirement, and no sequential-looking rejection.
///
/// Making this ceiling diverge from [maxIdLength] would mean revisiting
/// ADR-0008 and replacing the alias with a separately justified bound — not
/// quietly editing a literal.
///
/// See `docs/decisions/ADR-0008-bounded-delivery-proof-policy-reference.md`.
const int maxDeliveryProofPolicyRefLength = maxIdLength;

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

  /// The policy reference exceeds [maxDeliveryProofPolicyRefLength].
  /// **A size bound, not a grammar** — see that constant.
  policyRefTooLong,

  /// The evidence reference names a resource that is not a valid opaque id.
  evidenceResourceIdInvalid,

  /// The evidence identifier is not a valid opaque id.
  evidenceIdInvalid,

  /// The **resource being acted on** is not a valid opaque id.
  ///
  /// Deliberately distinct from [evidenceResourceIdInvalid]: "the stored
  /// evidence names a broken resource" and "the caller asked about a broken
  /// resource" are different failures, and collapsing them would hide which
  /// side is corrupt.
  expectedResourceIdInvalid,

  /// The evidence reference belongs to a different resource than the one being
  /// acted on. **Evidence is not portable between orders.**
  ///
  /// Reached only when **both** resources are valid opaque ids and simply
  /// differ — never as a consequence of one of them being malformed.
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
/// namespace — would be inventing a contract rather than referring to it.
///
/// The only structural rules are that the reference is **not blank** and **not
/// longer than [maxDeliveryProofPolicyRefLength]**. The size ceiling is a
/// transport-safety bound, not a grammar: it constrains *how much*, never
/// *what*.
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

  /// Structurally usable: present, not whitespace-only, and within
  /// [maxDeliveryProofPolicyRefLength].
  ///
  /// `trim()` is used **only to reject blank values**. The stored [value] is
  /// untouched — never trimmed, case-folded, re-punctuated or repaired.
  bool get isWellFormed =>
      value.trim().isNotEmpty &&
      value.length <= maxDeliveryProofPolicyRefLength;

  @override
  bool operator ==(Object other) =>
      other is DeliveryProofPolicyRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// **Deliberately does not reproduce [value].**
  ///
  /// The reference has no character grammar by design, so its content is
  /// arbitrary — which makes a `toString` that echoes it a log-injection and
  /// content-leak surface reachable from any `print`, crash report or error
  /// message. A length is enough to debug a structural problem.
  ///
  /// The length is **not** a hash and **not** an identifier: it derives no new
  /// business value, and equality still uses the exact underlying value.
  @override
  String toString() => 'DeliveryProofPolicyRef(length=${value.length})';
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
/// **Bound to its resource.** [belongsTo] returns true only for a *structurally
/// valid* reference against a *valid* target resource, compared **exactly** — so
/// an evidence reference from one order cannot be presented against another,
/// and two identically-malformed values cannot match their way to a `true`.
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

  /// Whether this evidence is **structurally valid and bound to** [resourceId].
  ///
  /// A `true` here is a three-part claim, and all three must hold:
  ///
  /// 1. this reference is well formed;
  /// 2. [resourceId] is itself a valid canonical opaque id;
  /// 3. the two resources compare **exactly**.
  ///
  /// Raw equality alone would fail open: two identically-malformed strings — an
  /// empty stored resource and an empty target, say — would match and this
  /// convenience method would certify a broken reference. It cannot now.
  /// Nothing is trimmed or normalised into a match.
  bool belongsTo(String resourceId) =>
      isWellFormed &&
      isValidOpaqueId(resourceId) &&
      this.resourceId == resourceId;

  @override
  bool operator ==(Object other) =>
      other is DeliveryEvidenceRef &&
      other.resourceId == resourceId &&
      other.evidenceId == evidenceId;

  @override
  int get hashCode => Object.hash(resourceId, evidenceId);

  /// A **debug representation, and never a validity claim.**
  ///
  /// A well-formed reference renders its two identifiers, which are canonical
  /// opaque ids and therefore already bounded at [maxIdLength] and drawn from a
  /// restricted alphabet.
  ///
  /// A **malformed** one renders neither field. The constructor is public and
  /// `const`, so malformed instances are deliberately representable — that is
  /// what lets the validator be tested at all — and until
  /// `validateDeliveryEvidenceRef` has passed, these fields are just untrusted
  /// strings. Echoing them would make any `print`, crash report or error
  /// message an amplification and log-injection surface reachable *before*
  /// validation, which is precisely the window that matters.
  ///
  /// Nothing is thrown, trimmed, hashed or repaired: this method reports, it
  /// does not fix. `validateDeliveryEvidenceRef` remains the authoritative
  /// structural check, and a rendering is never a substitute for it.
  @override
  String toString() => isWellFormed
      ? 'DeliveryEvidenceRef($evidenceId for $resourceId)'
      : 'DeliveryEvidenceRef(invalid)';
}

/// Structural validation for a policy reference. Returns null when usable.
///
/// **Structural only.** It cannot say whether the policy is satisfied, because
/// no slice defines satisfaction. Fails closed; repairs nothing.
DeliveryProofDenial? validateDeliveryProofPolicyRef(
  DeliveryProofPolicyRef ref,
) {
  if (ref.value.trim().isEmpty) {
    return DeliveryProofDenial.policyRefBlank;
  }
  if (ref.value.length > maxDeliveryProofPolicyRefLength) {
    return DeliveryProofDenial.policyRefTooLong;
  }
  return null;
}

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
  // Deterministic precedence, so a malformed *stored* reference can never be
  // masked by a later check. The stored side is inspected first, because that
  // is the corruption a caller cannot see.
  if (!isValidOpaqueId(ref.resourceId)) {
    return DeliveryProofDenial.evidenceResourceIdInvalid;
  }
  if (!isValidOpaqueId(ref.evidenceId)) {
    return DeliveryProofDenial.evidenceIdInvalid;
  }
  if (!isValidOpaqueId(resourceId)) {
    return DeliveryProofDenial.expectedResourceIdInvalid;
  }
  // Both sides are valid opaque ids by here, so a difference is a genuine
  // cross-resource mismatch rather than a malformed value — compared exactly.
  if (ref.resourceId != resourceId) {
    return DeliveryProofDenial.evidenceResourceMismatch;
  }
  return null;
}
