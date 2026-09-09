import 'package:cp_contracts/src/command_envelope.dart';
import 'package:meta/meta.dart';

/// A deterministic fingerprint of *what a command asked for*.
///
/// Computed from the command's meaning — type, resource, expected revision and
/// canonicalised payload — and from **nothing else**. In particular it does
/// not include a device clock, a request timestamp, a retry counter or a
/// transport id. Two honest retries of the same intent must fingerprint
/// identically however far apart they are sent, or replay detection breaks
/// exactly when the network is worst.
@immutable
class CommandFingerprint {
  const CommandFingerprint(this.value);

  /// Derive from an envelope. [CommandEnvelope.commandId] is deliberately
  /// excluded: the fingerprint describes the *request*, and is compared
  /// against a stored fingerprint that the command id selected.
  factory CommandFingerprint.of(CommandEnvelope envelope) {
    final StringBuffer buffer = StringBuffer()
      ..write(envelope.commandType)
      ..write('|')
      ..write(envelope.resourceId)
      ..write('|')
      ..write(envelope.expectedRevision)
      ..write('|')
      ..write(_canonical(envelope.payload));
    return CommandFingerprint(_hash(buffer.toString()));
  }

  final String value;

  /// Stable ordering and rendering so two equal payloads always agree, and a
  /// changed payload always disagrees.
  static String _canonical(Object? node) {
    if (node is Map) {
      final List<String> keys =
          node.keys.map((Object? k) => '$k').toList()..sort();
      return '{${keys.map((String k) => '$k:${_canonical(node[k])}').join(',')}}';
    }
    if (node is Iterable) {
      // Order is meaningful in a list: [a,b] is a different request from
      // [b,a], so it is not sorted.
      return '[${node.map(_canonical).join(',')}]';
    }
    if (node is String) {
      return 's:$node';
    }
    if (node == null) {
      return 'null';
    }
    return '${node.runtimeType}:$node';
  }

  /// FNV-1a 64-bit, rendered hex. Chosen so the contract package needs no
  /// dependency. It is a *collision-resistance-adequate* fingerprint for
  /// detecting an accidentally reused key, not a security primitive; a
  /// forged-collision threat model would need a cryptographic digest, which
  /// the backend may substitute as long as both sides agree.
  static String _hash(String input) {
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (final int unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  @override
  bool operator ==(Object other) =>
      other is CommandFingerprint && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CommandFingerprint($value)';
}

/// What the backend must do with an incoming command id.
enum IdempotencyOutcome {
  /// Never seen. Execute — but only after authorization, revision and state
  /// validation still pass.
  executeNew,

  /// Seen, and the request means the same thing. Return the **stored original
  /// result**. Do not re-execute: re-executing is how a COD receipt gets
  /// recorded twice.
  replayStoredResult,

  /// Seen, but the request means something different. Reject: the client
  /// reused an idempotency key for a new intent. Executing would silently
  /// overwrite the meaning of an earlier command.
  rejectKeyReuse,
}

/// What the backend remembers about a command id it has already handled.
@immutable
class StoredCommandRecord {
  const StoredCommandRecord({
    required this.commandId,
    required this.fingerprint,
    required this.resultRevision,
    required this.recordedAtServerUtc,
  });

  final String commandId;
  final CommandFingerprint fingerprint;

  /// Revision the resource reached. Replayed to the caller unchanged.
  final int resultRevision;

  /// **Server** time. A client clock is never the authority for replay
  /// identity, or a device with a wrong clock could shadow a real command.
  final DateTime recordedAtServerUtc;
}

/// Pure decision function for the idempotency contract.
///
/// [stored] is null when the command id has not been seen. Deliberately free
/// of storage access so it is testable without a database; the backend loads
/// the record and applies this rule inside the same transaction as the write.
IdempotencyOutcome evaluateIdempotency({
  required CommandEnvelope incoming,
  StoredCommandRecord? stored,
}) {
  if (stored == null) {
    return IdempotencyOutcome.executeNew;
  }
  final CommandFingerprint incomingFingerprint = CommandFingerprint.of(
    incoming,
  );
  return stored.fingerprint == incomingFingerprint
      ? IdempotencyOutcome.replayStoredResult
      : IdempotencyOutcome.rejectKeyReuse;
}
