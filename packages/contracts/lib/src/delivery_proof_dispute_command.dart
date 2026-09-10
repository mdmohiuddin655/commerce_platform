import 'package:cp_contracts/src/permission.dart';

/// Named fallback delivery-proof dispute operations.
///
/// Every one is a **named operation, never a status to write.** There is no
/// `setDisputeStatus`, no `updateDispute`, no patch endpoint, and no command
/// that takes a target state as an argument: the caller asks to *do* something
/// and the evaluator decides whether the current facts permit it. That is the
/// same rule the order, assignment and custody slices follow, and it matters
/// more here than anywhere, because a dispute is exactly the kind of record an
/// operator is tempted to "just correct".
///
/// **No permission was added by FND-003D2B.** Both executable operations map to
/// permissions the accepted FND-003A matrix already defines, unchanged in role,
/// scope, reason requirement or restriction:
///
/// ```text
/// customer.dispute.raise        ownResource,  reason required
/// admin.dispute.administer      ownRegion,    reason required
/// ```
///
/// `Permission.values` and `permissionMatrix` stay at **38**, and
/// `customer.delivery.confirm_proof` is **not** reinterpreted: whether customer
/// participation in proof is optional, mandatory, sufficient or a veto remains
/// **POLICY-DEFINED / DEFERRED**, and raising a dispute is not participation.
///
/// [commandType] matches the envelope's `commandType` grammar (dot-separated
/// lower_snake) and [requiredPermission] is what the **trusted backend router**
/// must select before authorizing. A client never supplies either — see
/// `docs/contracts/authorization-invariants.md`.
enum DeliveryProofDisputeCommand {
  /// The order's customer raises the fallback dispute.
  ///
  /// The permission requires a stored reason, which FND-003A captures and
  /// audits at the authorization boundary. **No free-text field exists on any
  /// type in this module** — see `DeliveryProofDisputeRecord`.
  raise('dispute.raise_delivery_proof', Permission.customerRaiseDispute),

  /// An authorized administrator records that review of the dispute started.
  ///
  /// **A record of who took it up, not a finding.** It moves the dispute from
  /// `open` to `underReview` and does nothing else: no order state, no custody,
  /// no assignment, no assessment, no money.
  recordReviewStarted(
    'dispute.record_delivery_proof_review',
    Permission.adminAdministerDispute,
  ),

  /// **ENUMERATED AND DELIBERATELY NOT EXECUTABLE.**
  ///
  /// Every call is refused with
  /// [DeliveryProofDisputeDenial.resolutionPolicyDeferred], before any fact is
  /// read, following `LifecycleDenial.policyDeferred`'s precedent: a real edge
  /// whose **business policy is not yet decided** is refused as *not decided
  /// yet*, never as *never allowed*, and never guessed.
  ///
  /// It is named here rather than omitted for the same reason
  /// `admin.assignment.override_rider` is named in ADR-0007: reserving the
  /// identifier prevents somebody inventing a private one, and it makes the
  /// gap testable instead of merely documented.
  ///
  /// Resolving a dispute requires deciding, at minimum: who prevails; whether
  /// the order becomes delivered, refused or returned; whether a fee, refund,
  /// compensation or liability follows and who bears it; whether stock is
  /// restored; and whether customer participation is optional, mandatory,
  /// sufficient or a veto. **Owner decision O6, FND-003C and FND-003B3B own
  /// those, and none has run.**
  resolve('dispute.resolve_delivery_proof', Permission.adminAdministerDispute);

  const DeliveryProofDisputeCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require.
  ///
  /// Non-null for all three: every dispute operation is actor-driven. There is
  /// no worker-driven dispute path, because a dispute is a claim a person
  /// makes — the exact inverse of a proof assessment, which has no client
  /// command at all.
  final Permission requiredPermission;

  /// Operations this slice's evaluator may apply.
  static const Set<DeliveryProofDisputeCommand> executableInThisSlice =
      <DeliveryProofDisputeCommand>{
        DeliveryProofDisputeCommand.raise,
        DeliveryProofDisputeCommand.recordReviewStarted,
      };

  /// Operations that are **real edges with undecided business policy**.
  ///
  /// Kept as data, and asserted by a test, so that making one executable is a
  /// deliberate act rather than an accident — the same shape as
  /// `policyDeferredCancellationSources`.
  static const Set<DeliveryProofDisputeCommand> policyDeferredInThisSlice =
      <DeliveryProofDisputeCommand>{DeliveryProofDisputeCommand.resolve};

  bool get isExecutable => executableInThisSlice.contains(this);

  static DeliveryProofDisputeCommand? byCommandType(String commandType) {
    for (final DeliveryProofDisputeCommand c
        in DeliveryProofDisputeCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical fallback delivery-proof dispute event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing and **proves
/// nothing** — a client re-reads authorized server state. Server-assigned event
/// ids only; a transport message id is never the business event id.
///
/// Payloads carry routing and identity only: resource id, dispute id, dispute
/// revision, server UTC. **No raw proof or evidence material, no policy
/// contents, no verdict copy, no reason text, no customer contact detail, no
/// address, no order contents, no money and no storage path or signed URL.**
/// Authorized clients re-read protected state; a notification is a hint, never
/// proof, authority or an outcome.
///
/// **Neither event says anything happened to the delivery.** Nothing here means
/// the order was delivered, refused, returned or cancelled, that custody moved,
/// that a rider finished, that an assessment changed, or that anyone owes
/// anyone anything.
class DeliveryProofDisputeEventType {
  const DeliveryProofDisputeEventType._();

  /// A customer raised a fallback dispute against the current proof-assessment
  /// situation.
  static const String disputeRaised = 'delivery.proof_dispute_raised';

  /// An administrator recorded that review of a dispute started.
  ///
  /// **Not a resolution event**, and no resolution event exists: there is no
  /// `delivery.proof_dispute_resolved`, `…_upheld`, `…_rejected`, `…_refunded`
  /// or `…_closed`, because no slice defines what any of them would mean.
  static const String disputeReviewStarted =
      'delivery.proof_dispute_review_started';

  /// Every dispute event this contract defines. Exactly two.
  ///
  /// `const`, so it is deeply immutable: a caller that tries to add to it gets
  /// an `UnsupportedError` rather than silently extending the vocabulary.
  static const List<String> all = <String>[disputeRaised, disputeReviewStarted];
}
