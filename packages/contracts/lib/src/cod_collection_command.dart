import 'package:cp_contracts/src/permission.dart';

/// Named COD operations.
///
/// One operation, and it is a **record of cash that has already changed
/// hands** — not an instruction to charge anyone. There is no `setPaymentState`
/// and no target-state argument anywhere: the only way a payment moves is a
/// rider reporting what they actually received.
enum CodCollectionCommand {
  /// The order's accepted rider reports cash actually received from the
  /// customer on the normal delivery path.
  ///
  /// Uses the **accepted, unchanged** `rider.cash.report_collection`, whose
  /// rule already says exactly this: *"Reports what was actually received.
  /// Reporting is not settlement, and it never writes a balance: the server
  /// derives postings. Delivered is not equivalent to rider cash settled."*
  /// **No permission was added by FND-003C1.**
  reportCodCollection(
    'cash.report_cod_collection',
    Permission.riderReportCodCollection,
  );

  const CodCollectionCommand(this.commandType, this.requiredPermission);

  /// Stable wire identifier, matching `CommandEnvelope.commandType`.
  final String commandType;

  /// Permission the trusted backend router must require **before**
  /// authorization is evaluated.
  final Permission requiredPermission;

  static CodCollectionCommand? byCommandType(String commandType) {
    for (final CodCollectionCommand c in CodCollectionCommand.values) {
      if (c.commandType == commandType) {
        return c;
      }
    }
    return null;
  }
}

/// Canonical COD event identifiers.
///
/// Facts the server recorded. **An event is never authorization and never a
/// journal source of truth** — the journal entry is, and a client re-reads
/// authorized server state rather than trusting a push.
///
/// Payloads carry routing and money metadata only: resource id, payment
/// revision, journal business reference, collected amount and currency, server
/// UTC. **No customer address, phone number, order contents, proof material,
/// rider location or secret.**
class CodCollectionEventType {
  const CodCollectionEventType._();

  /// Part of the amount due was received; more remains outstanding.
  static const String partiallyCollected = 'cash.cod_partially_collected';

  /// The full amount due has now been received. **Not remitted, not settled.**
  static const String collected = 'cash.cod_collected';

  /// A balanced journal entry was recorded for the movement.
  static const String journalEntryRecorded = 'cash.journal_entry_recorded';

  static const List<String> all = <String>[
    partiallyCollected,
    collected,
    journalEntryRecorded,
  ];
}
