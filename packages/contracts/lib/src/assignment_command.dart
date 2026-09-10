import 'package:cp_contracts/src/assignment_state.dart';
import 'package:cp_contracts/src/permission.dart';

/// Named assignment operations, for both assignment roles.
///
/// Every one is a **named operation**. There is no `setAssignmentState`, no
/// assignee-replacement command and no patch: reassigning a worker is
/// `revoke` followed by a **new** offer, so the history survives.
///
/// Each command carries its [role]. That is not decoration — it is what lets a
/// test assert *per role* that every command has transition-closure coverage,
/// so adding a rider command cannot be absorbed by a picker test (or the
/// reverse) and silently escape.
enum AssignmentCommand {
  // ------------------------------------------------------------------ picker
  /// Agent offers the picker work to one worker.
  offerPickerAssignment(
    'assignment.offer_picker',
    Permission.agentOfferPickerAssignment,
    AssignmentRole.picker,
  ),

  /// The offer recipient accepts.
  acceptPickerAssignment(
    'assignment.accept_picker',
    Permission.pickerAcceptAssignment,
    AssignmentRole.picker,
  ),

  /// The offer recipient refuses.
  declinePickerAssignment(
    'assignment.decline_picker',
    Permission.pickerDeclineAssignment,
    AssignmentRole.picker,
  ),

  /// Agent withdraws an accepted assignment so the work can be re-offered.
  /// Reason-bearing, and gated on proven-no-custody.
  revokePickerAssignment(
    'assignment.revoke_picker',
    Permission.agentRevokePickerAssignment,
    AssignmentRole.picker,
  ),

  /// **Trusted worker transition — not a client command.**
  ///
  /// `requiredPermission` is null: `evaluateAuthorization` denies a
  /// `PrincipalKind.systemWorker` every human-role permission, so a worker
  /// cannot borrow one. It runs its own audited path.
  ///
  /// Not a mobile timer, not a notification callback, not a TTL deletion.
  expirePickerOffer(
    'assignment.expire_picker_offer',
    null,
    AssignmentRole.picker,
  ),

  // ------------------------------------------------------------------- rider
  /// The order's **current accepted picker** offers the delivery work to one
  /// rider.
  ///
  /// Deliberately **not** [Permission.agentOfferRiderAssignment]. That
  /// permission describes a future direct shop→rider pickup, whose custody
  /// source is the shop rather than a picker; routing this command through it
  /// would let a flow with no picker at all reuse a rule written for a
  /// picker-originated offer. See `docs/contracts/rider-assignment-lifecycle.md`.
  offerRiderAssignment(
    'assignment.offer_rider',
    Permission.pickerOfferRiderAssignment,
    AssignmentRole.rider,
  ),

  /// The offer recipient accepts.
  acceptRiderAssignment(
    'assignment.accept_rider',
    Permission.riderAcceptAssignment,
    AssignmentRole.rider,
  ),

  /// The offer recipient refuses.
  declineRiderAssignment(
    'assignment.decline_rider',
    Permission.riderDeclineAssignment,
    AssignmentRole.rider,
  ),

  /// The current accepted picker withdraws an accepted rider assignment so the
  /// delivery work can be re-offered. Reason-bearing, and gated on
  /// proven-no-custody.
  revokeRiderAssignment(
    'assignment.revoke_rider',
    Permission.pickerRevokeRiderAssignment,
    AssignmentRole.rider,
  ),

  /// **Trusted worker transition — not a client command.** Same reasoning as
  /// [expirePickerOffer].
  expireRiderOffer(
    'assignment.expire_rider_offer',
    null,
    AssignmentRole.rider,
  );

  const AssignmentCommand(this.commandType, this.requiredPermission, this.role);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require, or null for a
  /// worker-driven transition no human role may invoke.
  final Permission? requiredPermission;

  /// Which assignment lifecycle this command belongs to.
  final AssignmentRole role;

  bool get isWorkerDriven => requiredPermission == null;

  /// Commands belonging to one assignment lifecycle.
  ///
  /// Used by the per-role transition-closure coverage guards: a new command
  /// appears in exactly one role's set, so that role's coverage test fails
  /// until its successful transition is actually exercised.
  static Set<AssignmentCommand> forRole(AssignmentRole role) =>
      AssignmentCommand.values
          .where((AssignmentCommand c) => c.role == role)
          .toSet();

  static AssignmentCommand? byCommandType(String commandType) {
    for (final AssignmentCommand c in AssignmentCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical assignment event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing — a client
/// re-reads server state. Server-assigned event ids only; a transport message
/// id is never the business event id. Payloads carry the assignment id,
/// generation and resulting revision, and **no customer personal data**.
///
/// A rider event additionally carries the source picker assignment reference,
/// because a rider attempt is only meaningful relative to the picker
/// assignment that created it.
class AssignmentEventType {
  const AssignmentEventType._();

  static const String pickerOffered = 'picker.assignment.offered';
  static const String pickerAccepted = 'picker.assignment.accepted';
  static const String pickerDeclined = 'picker.assignment.declined';
  static const String pickerExpired = 'picker.assignment.expired';
  static const String pickerRevoked = 'picker.assignment.revoked';

  static const String riderOffered = 'rider.assignment.offered';
  static const String riderAccepted = 'rider.assignment.accepted';
  static const String riderDeclined = 'rider.assignment.declined';
  static const String riderExpired = 'rider.assignment.expired';
  static const String riderRevoked = 'rider.assignment.revoked';

  /// Picker-assignment events only.
  static const List<String> picker = <String>[
    pickerOffered,
    pickerAccepted,
    pickerDeclined,
    pickerExpired,
    pickerRevoked,
  ];

  /// Rider-assignment events only.
  static const List<String> rider = <String>[
    riderOffered,
    riderAccepted,
    riderDeclined,
    riderExpired,
    riderRevoked,
  ];

  static const List<String> all = <String>[...picker, ...rider];
}
