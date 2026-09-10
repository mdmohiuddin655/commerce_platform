import 'package:cp_contracts/src/permission.dart';

/// Named custody operations.
///
/// Both are **records of a physical event that already happened**, not
/// instructions to move goods. There is no `setCustody`, no
/// `transferCustodyTo`, no custodian patch: a custody change is caused by the
/// exact worker who took possession recording that they did, against the
/// canonical current facts.
///
/// **`picker.custody.record_handoff` is deliberately absent from this enum.**
/// It keeps its permission id and is not re-scoped, but a picker-side record
/// alone does not transfer custody in this slice — see
/// `docs/contracts/custody-lifecycle.md`. Making it executable would require a
/// sender/receiver proof protocol, and inventing one (a token, a QR, an OTP, a
/// signature, a photo) is exactly what this task must not do.
enum CustodyCommand {
  /// The order's current accepted picker records collecting the goods from the
  /// shop. Custody `shop → picker`.
  ///
  /// Physical acquisition, **not** dispatch: the order stays `ready`.
  recordShopPickup(
    'custody.record_shop_pickup',
    Permission.pickerRecordShopPickup,
  ),

  /// The order's accepted rider records receiving the goods from the picker.
  /// Custody `picker → rider`.
  ///
  /// Receiver-side by design. The rider is the party who can attest they are
  /// holding the goods, and making receipt the authoritative edge means custody
  /// never sits in a claimed-but-unconfirmed limbo between two workers.
  ///
  /// This is the **dispatch boundary**: it is the one command in this slice
  /// that moves the order to `in_delivery` and completes the picker assignment.
  recordRiderReceipt(
    'custody.record_rider_receipt',
    Permission.riderRecordCustodyReceipt,
  );

  const CustodyCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require. Both custody commands
  /// in this slice are actor-driven; neither is worker-driven, because only a
  /// person can attest to holding goods.
  final Permission requiredPermission;

  static CustodyCommand? byCommandType(String commandType) {
    for (final CustodyCommand c in CustodyCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical custody event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing — a client
/// re-reads authorized server state. Server-assigned event ids only; a
/// transport message id is never the business event id.
///
/// Payloads carry routing and identity only: resource id, custody revision,
/// assignment identity, server UTC. **No customer address, phone number, order
/// contents, money amount or proof material.**
class CustodyEventType {
  const CustodyEventType._();

  /// Custody `shop → picker`.
  static const String acquiredByPicker = 'custody.acquired_by_picker';

  /// Custody `picker → rider`. The dispatch boundary.
  static const String transferredToRider = 'custody.transferred_to_rider';

  static const List<String> all = <String>[
    acquiredByPicker,
    transferredToRider,
  ];
}
