import 'package:cp_contracts/src/permission.dart';

/// Named delivery-attempt operations.
///
/// Every one is a **record of a physical event that already happened**, not an
/// instruction. There is no `setAttemptState`, no `patchAttempt` and no
/// target-state argument anywhere: the only way to move an attempt is to name
/// an operation the evaluator recognises, against canonical current facts.
enum DeliveryAttemptCommand {
  /// The order's accepted rider records setting out with the goods.
  /// `pending -> out_for_delivery`.
  recordOutForDelivery(
    'delivery.record_out_for_delivery',
    Permission.riderRecordDeliveryAttempt,
  ),

  /// The rider records that the customer declined the goods.
  /// `out_for_delivery -> refused`, atomically opening a required return.
  recordRefusal(
    'delivery.record_refusal',
    Permission.riderRecordDeliveryAttempt,
  ),

  /// The rider records that the attempt could not be completed.
  /// `out_for_delivery -> failed`.
  ///
  /// Records the fact and **nothing else** — no retry, no return, no fault, no
  /// fee.
  recordFailure(
    'delivery.record_failure',
    Permission.riderRecordDeliveryAttempt,
  ),

  /// **ENUMERATED AND NEVER EXECUTABLE.**
  ///
  /// The command a delivery would use, declared so that its absence is
  /// explicit and testable rather than an oversight a later slice might "fix"
  /// by adding an unreviewed edge.
  ///
  /// It is always refused with
  /// `AttemptReturnDenial.deliveryProofPolicyDeferred`, **before** it can
  /// produce any delivery, custody, assignment, inventory or financial effect.
  /// The precedent is `DeliveryProofDisputeCommand.resolve`, which is
  /// enumerated and always refused for the same reason: naming the operation
  /// is not deciding it.
  ///
  /// The missing piece is the **proof-satisfaction policy**. A `satisfied`
  /// `DeliveryProofAssessmentRecord` is not consumed as authority for it,
  /// because what the policy requires — how many of which evidence kinds,
  /// under which policy version, with what customer participation — is defined
  /// nowhere.
  recordDelivered(
    'delivery.record_delivered',
    Permission.riderRecordDeliveryAttempt,
  );

  const DeliveryAttemptCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require **before**
  /// authorization is evaluated.
  ///
  /// All four are the rider's own `rider.delivery.record_attempt`, whose rule
  /// already requires an **accepted** assignment on the resource
  /// (`ScopeRequirement.assignedResource`). No permission was added for the
  /// attempt dimension: recording what happened at the door is exactly what
  /// that permission was written for.
  final Permission requiredPermission;

  /// Commands this slice can actually execute. [recordDelivered] is excluded,
  /// and a test pins that.
  static const Set<DeliveryAttemptCommand> executableInThisSlice =
      <DeliveryAttemptCommand>{
        DeliveryAttemptCommand.recordOutForDelivery,
        DeliveryAttemptCommand.recordRefusal,
        DeliveryAttemptCommand.recordFailure,
      };

  static DeliveryAttemptCommand? byCommandType(String commandType) {
    for (final DeliveryAttemptCommand c in DeliveryAttemptCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical delivery-attempt event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing — a client
/// re-reads authorized server state, and a push notification proves nothing.
///
/// Payloads carry routing and identity only: resource id, attempt id, attempt
/// revision, server UTC. **No customer address, phone number, order contents,
/// refusal free-text, evidence, money amount or proof material.**
class DeliveryAttemptEventType {
  const DeliveryAttemptEventType._();

  /// `pending -> out_for_delivery`.
  static const String outForDelivery = 'delivery.attempt_out_for_delivery';

  /// `out_for_delivery -> refused`.
  static const String refused = 'delivery.attempt_refused';

  /// `out_for_delivery -> failed`.
  static const String failed = 'delivery.attempt_failed';

  static const List<String> all = <String>[outForDelivery, refused, failed];
}
