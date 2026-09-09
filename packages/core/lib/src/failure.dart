import 'package:meta/meta.dart';

/// Reason a command or query did not succeed.
///
/// [FailureKind.conflict] and [FailureKind.rejectedByPolicy] are distinct on
/// purpose: a stale order revision is retryable after refresh, a policy
/// rejection is not.
enum FailureKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  rejectedByPolicy,
  serverError,
  unknown,
}

@immutable
class Failure {
  const Failure(this.kind, this.message, {this.code, this.commandId});

  final FailureKind kind;
  final String message;

  /// Stable machine-readable code from the shared contract (FND-003).
  final String? code;

  /// Correlates a failure with the idempotent command that produced it.
  final String? commandId;

  @override
  bool operator ==(Object other) =>
      other is Failure &&
      other.kind == kind &&
      other.message == message &&
      other.code == code &&
      other.commandId == commandId;

  @override
  int get hashCode => Object.hash(kind, message, code, commandId);

  @override
  String toString() => 'Failure(${kind.name}, ${code ?? '-'}, $message)';
}
