import 'package:cp_contracts/src/permission.dart';

/// Named picker-assignment operations.
///
/// Every one is a **named operation**. There is no `setAssignmentState`, no
/// assignee-replacement command and no patch: reassigning a picker is
/// `revoke` followed by a **new** offer, so the history survives.
enum AssignmentCommand {
  /// Agent offers the picker work to one worker.
  offerPickerAssignment(
    'assignment.offer_picker',
    Permission.agentOfferPickerAssignment,
  ),

  /// The offer recipient accepts.
  acceptPickerAssignment(
    'assignment.accept_picker',
    Permission.pickerAcceptAssignment,
  ),

  /// The offer recipient refuses.
  declinePickerAssignment(
    'assignment.decline_picker',
    Permission.pickerDeclineAssignment,
  ),

  /// Agent withdraws an accepted assignment so the work can be re-offered.
  /// Reason-bearing, and gated on proven-no-custody.
  revokePickerAssignment(
    'assignment.revoke_picker',
    Permission.agentRevokePickerAssignment,
  ),

  /// **Trusted worker transition — not a client command.**
  ///
  /// `requiredPermission` is null: `evaluateAuthorization` denies a
  /// `PrincipalKind.systemWorker` every human-role permission, so a worker
  /// cannot borrow one. It runs its own audited path.
  ///
  /// Not a mobile timer, not a notification callback, not a TTL deletion.
  expirePickerOffer('assignment.expire_picker_offer', null);

  const AssignmentCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require, or null for a
  /// worker-driven transition no human role may invoke.
  final Permission? requiredPermission;

  bool get isWorkerDriven => requiredPermission == null;

  static AssignmentCommand? byCommandType(String commandType) {
    for (final AssignmentCommand c in AssignmentCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical picker-assignment event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing — a client
/// re-reads server state. Server-assigned event ids only; a transport message
/// id is never the business event id. Payloads carry the assignment id,
/// generation and resulting revision, and **no customer personal data**.
class AssignmentEventType {
  const AssignmentEventType._();

  static const String pickerOffered = 'picker.assignment.offered';
  static const String pickerAccepted = 'picker.assignment.accepted';
  static const String pickerDeclined = 'picker.assignment.declined';
  static const String pickerExpired = 'picker.assignment.expired';
  static const String pickerRevoked = 'picker.assignment.revoked';

  static const List<String> all = <String>[
    pickerOffered,
    pickerAccepted,
    pickerDeclined,
    pickerExpired,
    pickerRevoked,
  ];
}
