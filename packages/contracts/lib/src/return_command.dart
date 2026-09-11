import 'package:cp_contracts/src/permission.dart';

/// Named return operations for the direct `rider -> shop` route.
///
/// ## Why these permissions, and only one new one
///
/// - [beginTransit], [recordInspection] and [closeReturn] use the accepted
///   `admin.return.administer`. Its existing rule is already written for
///   exactly this — it is `reasonRequired`, and its restriction text already
///   says *"Stock cannot become available again until shop receipt and
///   inspection; this permission does not shortcut that"*. Return
///   administration is what it is for.
/// - [recordShopReceipt] needs **shop-side** authority, which no accepted
///   permission carried, so FND-003B3B adds the smallest one:
///   `agent.return.record_receipt`.
///
/// `agent.fulfillment.record_progress` was deliberately not widened into a
/// custody or stock lever, and no arbitrary admin custody override was added.
enum ReturnCommand {
  /// The return starts travelling back. `required -> in_transit`.
  ///
  /// **Custody does not move**: the rider already holds the goods and keeps
  /// holding them. Only the return's own state changes.
  beginTransit('return.begin_transit', Permission.adminAdministerReturn),

  /// The shop records that the goods physically arrived back.
  /// `in_transit -> received`, and custody `rider -> shop`.
  ///
  /// Receiver-side, following FND-003B3A: the party who can attest to holding
  /// the goods is the party who records it. This is an **authorized business
  /// assertion**, not cryptographic proof — no OTP, QR, signature, photo, GPS
  /// or biometric mechanism exists here, and inventing one is out of scope.
  recordShopReceipt(
    'return.record_shop_receipt',
    Permission.agentRecordReturnReceipt,
  ),

  /// The shop's inspection outcome is recorded. `received -> inspected`.
  ///
  /// **The only boundary in this contract where available stock may change**,
  /// and it can do so only once, only for a `restockable` disposition, and only
  /// because both shop receipt and inspection are now established.
  recordInspection(
    'return.record_inspection',
    Permission.adminAdministerReturn,
  ),

  /// The return is closed for audit. `inspected -> closed`.
  ///
  /// Restores nothing — the disposition already decided that — and infers no
  /// money, liability or settlement.
  closeReturn('return.close', Permission.adminAdministerReturn);

  const ReturnCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require.
  final Permission requiredPermission;

  static ReturnCommand? byCommandType(String commandType) {
    for (final ReturnCommand c in ReturnCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical return event identifiers.
///
/// Minimal facts only: resource id, return revision, custody revision where it
/// changed, disposition where one was recorded, server UTC. **No address,
/// phone, order contents, inspection free-text, photo, money amount or
/// liability attribution.**
class ReturnEventType {
  const ReturnEventType._();

  /// A refusal opened a required return. Caused by the attempt refusal
  /// command, never by a return command.
  static const String required = 'return.required';

  /// `required -> in_transit`.
  static const String inTransit = 'return.in_transit';

  /// `in_transit -> received`. Custody `rider -> shop`.
  static const String receivedAtShop = 'return.received_at_shop';

  /// `received -> inspected`, carrying the disposition id.
  static const String inspected = 'return.inspected';

  /// The reserved units went back to available stock. Emitted **only** for a
  /// `restockable` disposition, so a reader never has to infer a stock change
  /// from the inspection event alone.
  static const String stockRestored = 'return.stock_restored';

  /// `inspected -> closed`.
  static const String closed = 'return.closed';

  static const List<String> all = <String>[
    required,
    inTransit,
    receivedAtShop,
    inspected,
    stockRestored,
    closed,
  ];
}
