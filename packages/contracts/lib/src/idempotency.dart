import 'package:cp_contracts/src/authorization.dart';
import 'package:cp_contracts/src/command_envelope.dart';
import 'package:cp_contracts/src/principal.dart';
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

  /// The stored record belongs to a **different principal**. Never replay it:
  /// returning it would hand one user another user's command result.
  ///
  /// With the documented lookup key of `(principalId, commandId)` this is
  /// unreachable in correct code. It exists as defence in depth, so a lookup
  /// bug surfaces as an explicit rejection rather than a data leak.
  rejectNamespaceMismatch,

  /// The supplied [AuthorizationGrant] does not cover this request — it was
  /// issued for a different principal or a different resource.
  ///
  /// Unreachable when the backend passes the grant produced for the command it
  /// is serving. Kept as defence in depth so a wiring mistake surfaces as a
  /// rejection instead of authorizing the wrong thing.
  rejectAuthorizationMismatch,
}

/// The idempotency namespace a command is deduplicated within.
///
/// **The lookup key is the pair `(principalId, commandId)`, not the command id
/// alone.** A command id is client-generated, so two principals can produce the
/// same one by accident or on purpose; a global key would let the second
/// caller receive the first caller's stored result.
///
/// The principal here is the one the backend derived from **verified
/// authentication** — never a field from the wire envelope. `CommandEnvelope`
/// still carries no actor, so a client cannot choose the namespace it is
/// deduplicated in, and payload spoofing cannot move a lookup.
///
/// ## Why principal, and not shop, region or tenant
///
/// Resource isolation is already enforced by authorization: shop, region,
/// ownership and assignment scope are checked on every command, replays
/// included (see [IdempotencyOutcome.rejectNotAuthorized]). Partitioning by
/// principal is therefore sufficient *and* the narrowest correct choice — one
/// principal's retries are the only thing that may ever collapse together.
///
/// No `tenantId` wire field is invented here: this architecture has not
/// defined a tenant dimension. If one is introduced later, it extends this
/// type — which is why the namespace is a type rather than a bare string.
@immutable
class IdempotencyNamespace {
  const IdempotencyNamespace.forPrincipal(this.principalId);

  /// Trusted principal id, derived from verified authentication.
  final String principalId;

  @override
  bool operator ==(Object other) =>
      other is IdempotencyNamespace && other.principalId == principalId;

  @override
  int get hashCode => principalId.hashCode;

  @override
  String toString() => 'IdempotencyNamespace($principalId)';
}

/// What the backend remembers about a command id it has already handled.
@immutable
class StoredCommandRecord {
  const StoredCommandRecord({
    required this.namespace,
    required this.commandId,
    required this.fingerprint,
    required this.resultRevision,
    required this.recordedAtServerUtc,
  });

  /// Namespace the record was written in. Half of its lookup key.
  final IdempotencyNamespace namespace;

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
/// ## Authorization cannot be skipped, and this time the type system says so
///
/// [grant] is an [AuthorizationGrant]: `final`, privately constructed, and
/// obtainable **only** from a successful [evaluateAuthorization]. A denied
/// evaluation produces no grant, so "call idempotency while denied" is not a
/// state that can be expressed — there is nothing to pass.
///
/// This replaces the earlier design, which took an `AuthorizationDecision`
/// whose `allow()` constructor was public. That documented the guarantee
/// without providing it: any caller could manufacture success. See
/// FND-003A-FIX-002.
///
/// Because a denial cannot reach this function, there is no
/// "not authorized" outcome. That is not an omission — it is the point.
///
/// ## The grant must cover *this* request
///
/// Holding *a* grant is not enough; it must be the grant for the command being
/// served. A grant issued for principal A on resource X must not be presented
/// while handling principal B's command on resource Y, so both bindings are
/// re-checked against [principal] and [incoming].
///
/// The grant's [AuthorizationGrant.permission] is **not** checked here. No
/// command-type → permission mapping exists in the contract yet, so such a
/// check would be theatre. The trusted backend router maps command type to
/// required permission *before* authorization is evaluated; the binding is
/// retained on the grant for that dispatch and for audit.
///
/// ## Replay stays principal-scoped
///
/// The caller loads [stored] with the key `(namespace, commandId)` and passes
/// null when there is no record. A record from another namespace is rejected
/// rather than replayed.
///
/// No storage access and no clock: the backend loads the record and applies
/// this rule inside the same transaction as the write.
IdempotencyOutcome evaluateIdempotency({
  required AuthorizationGrant grant,
  required Principal principal,
  required CommandEnvelope incoming,
  StoredCommandRecord? stored,
}) {
  // 1. The grant must cover the principal and resource actually being served.
  if (!grant.covers(
    principalId: principal.id,
    resourceId: incoming.resourceId,
  )) {
    return IdempotencyOutcome.rejectAuthorizationMismatch;
  }

  final IdempotencyNamespace namespace = IdempotencyNamespace.forPrincipal(
    principal.id,
  );

  // 2. Nothing stored for this (principal, commandId): execute.
  if (stored == null) {
    return IdempotencyOutcome.executeNew;
  }

  // 3. Defence in depth against a lookup that ignored the namespace.
  if (stored.namespace != namespace || stored.commandId != incoming.commandId) {
    return IdempotencyOutcome.rejectNamespaceMismatch;
  }

  // 4. Same key: replay only if the request means the same thing.
  final CommandFingerprint incomingFingerprint = CommandFingerprint.of(
    incoming,
  );
  return stored.fingerprint == incomingFingerprint
      ? IdempotencyOutcome.replayStoredResult
      : IdempotencyOutcome.rejectKeyReuse;
}
