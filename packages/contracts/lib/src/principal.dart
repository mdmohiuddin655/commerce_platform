import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// What kind of thing is acting.
///
/// A trusted worker is **not** a user with a role. Modelling it separately
/// keeps human role membership honest: no background job is ever "an admin",
/// and no audit record has to pretend a cron run was a person.
enum PrincipalKind {
  /// A human, authenticated through the auth provider.
  user,

  /// A trusted server-side process: outbox drain, reservation expiry,
  /// scheduled reconciliation. Never authenticated from a client.
  systemWorker,
}

/// The **authenticated identity** of whoever issued a command.
///
/// A `Principal` is constructed by the server from a *verified* authentication
/// context and never from request content. There is deliberately no
/// `Principal.fromJson`: if a client could deserialize one, a client could
/// assert one.
///
/// A principal carries **no role**. Identity answers "who is this"; authority
/// comes from [Membership] plus a permission plus a scope.
@immutable
class Principal {
  const Principal._(this.kind, this.id);

  /// Build from a verified auth subject (e.g. a validated token's `sub`).
  ///
  /// The name is deliberately explicit: every call site has to state that the
  /// subject was verified, which makes an unverified one visible in review.
  factory Principal.fromVerifiedSubject(String subjectId) {
    final IdRejection? rejection = validateOpaqueId(subjectId);
    if (rejection != null) {
      throw ArgumentError.value(
        subjectId,
        'subjectId',
        'not a valid opaque subject id: ${rejection.name}',
      );
    }
    return Principal._(PrincipalKind.user, subjectId);
  }

  /// Build for a trusted server-side worker. Only reachable in backend code;
  /// a client request can never produce one.
  factory Principal.systemWorker(String workerId) {
    final IdRejection? rejection = validateOpaqueId(workerId);
    if (rejection != null) {
      throw ArgumentError.value(
        workerId,
        'workerId',
        'not a valid opaque worker id: ${rejection.name}',
      );
    }
    return Principal._(PrincipalKind.systemWorker, workerId);
  }

  final PrincipalKind kind;

  /// Stable, opaque. For a user this is the auth subject id.
  final String id;

  bool get isUser => kind == PrincipalKind.user;
  bool get isSystemWorker => kind == PrincipalKind.systemWorker;

  @override
  bool operator ==(Object other) =>
      other is Principal && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'Principal(${kind.name}, $id)';
}
