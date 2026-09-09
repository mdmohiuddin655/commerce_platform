import 'package:cp_contracts/src/contract_version.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// The one shape every trusted backend command arrives in.
///
/// ## The actor rule
///
/// There is **no actor, user, role or permission field on this envelope, and
/// there never will be.** The server derives the actor from the verified
/// authentication context and looks up membership from trusted storage. A
/// client-supplied identity is data, not authority.
///
/// This is not merely convention: a field that does not exist cannot be
/// trusted by mistake. Anything actor-shaped that a client puts in [payload]
/// is inert — `evaluateAuthorization` never reads the payload.
///
/// ## Named commands only
///
/// [commandType] names an operation ('order.place', 'assignment.accept'). It
/// is never a status to write. There is no patch-to-status endpoint: a client
/// asks for an operation and the server decides whether the transition is
/// permitted from the current state.
@immutable
class CommandEnvelope {
  const CommandEnvelope._({
    required this.commandId,
    required this.commandType,
    required this.resourceId,
    required this.expectedRevision,
    required this.payload,
    required this.contractVersion,
  });

  /// Validating constructor. Returns [Err] rather than throwing so a transport
  /// layer can reject a malformed command without an exception path.
  ///
  /// Validation here is **structural only**. Whether the command is allowed,
  /// and whether the state permits it, are decided later by authorization and
  /// by the lifecycle rules that FND-003's later slices own.
  static Result<CommandEnvelope> create({
    required String commandId,
    required String commandType,
    required String resourceId,
    required int expectedRevision,
    Map<String, Object?> payload = const <String, Object?>{},
    ContractVersion contractVersion = ContractVersion.current,
  }) {
    final IdRejection? commandIdIssue = validateOpaqueId(commandId);
    if (commandIdIssue != null) {
      return Result<CommandEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'commandId is not a valid opaque id: ${commandIdIssue.name}',
          code: 'ENVELOPE_COMMAND_ID_INVALID',
        ),
      );
    }
    final IdRejection? resourceIdIssue = validateOpaqueId(resourceId);
    if (resourceIdIssue != null) {
      return Result<CommandEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'resourceId is not a valid opaque id: ${resourceIdIssue.name}',
          code: 'ENVELOPE_RESOURCE_ID_INVALID',
          commandId: commandId,
        ),
      );
    }
    if (!_isValidCommandType(commandType)) {
      return Result<CommandEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'commandType must be dot-separated lower_snake segments',
          code: 'ENVELOPE_COMMAND_TYPE_INVALID',
          commandId: commandId,
        ),
      );
    }
    if (expectedRevision < 0) {
      return Result<CommandEnvelope>.err(
        Failure(
          FailureKind.rejectedByPolicy,
          'expectedRevision must be >= 0',
          code: 'ENVELOPE_REVISION_INVALID',
          commandId: commandId,
        ),
      );
    }
    return Result<CommandEnvelope>.ok(
      CommandEnvelope._(
        commandId: commandId,
        commandType: commandType,
        resourceId: resourceId,
        expectedRevision: expectedRevision,
        payload: Map<String, Object?>.unmodifiable(payload),
        contractVersion: contractVersion,
      ),
    );
  }

  /// Client-generated, opaque, unique per intent. The idempotency key.
  final String commandId;

  /// Named operation, e.g. `order.place`. Never a status value.
  final String commandType;

  /// Resource the command targets.
  final String resourceId;

  /// Revision the client believes the resource is at. The server rejects a
  /// mismatch, which is how incompatible concurrent actions are serialized.
  /// Zero means "expected not to exist yet" for creating commands.
  final int expectedRevision;

  /// Operation arguments. Small and structural. **Never authoritative for
  /// identity, role, permission, price or stock** — the server reads those
  /// from trusted storage.
  final Map<String, Object?> payload;

  /// Contract version the sender compiled against.
  final ContractVersion contractVersion;

  static bool _isValidCommandType(String value) {
    if (value.isEmpty || value.length > 64) {
      return false;
    }
    final RegExp pattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
    return pattern.hasMatch(value);
  }

  @override
  String toString() =>
      'CommandEnvelope($commandType, cmd=$commandId, res=$resourceId, '
      'rev=$expectedRevision, v$contractVersion)';
}
