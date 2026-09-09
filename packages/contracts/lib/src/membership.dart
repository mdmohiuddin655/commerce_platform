import 'package:cp_contracts/src/role.dart';
import 'package:meta/meta.dart';

/// Lifecycle of a person's right to act in a role.
///
/// Authentication proves *identity*. Membership proves *standing*. A valid
/// token from a suspended rider is still a valid token — and still must not
/// start new work.
enum MembershipStatus {
  /// Applied, not yet approved. May not act.
  pending,

  /// Approved and in good standing. The only status that may start new work.
  active,

  /// Temporarily stopped, e.g. under investigation. Reversible.
  suspended,

  /// Permanently ended. Not reversible without a new membership.
  revoked;

  String get id => switch (this) {
    MembershipStatus.pending => 'pending',
    MembershipStatus.active => 'active',
    MembershipStatus.suspended => 'suspended',
    MembershipStatus.revoked => 'revoked',
  };

  /// Whether this status may **begin** new commerce work.
  ///
  /// Deliberately narrow. Whether a suspended worker may *finish* something
  /// already in their custody is a controlled-resolution question owned by the
  /// lifecycle slice of FND-003, not decided here. The permission contract
  /// keeps the two separable via [PermissionRule.acceptableStatuses], so a
  /// later slice can grant a specific wind-down permission to a suspended
  /// member without loosening this rule.
  bool get canStartNewWork => this == MembershipStatus.active;
}

/// A person's standing in one role, with the scopes that role is limited to.
///
/// Built server-side from trusted records. Like [Principal] it has no
/// `fromJson`: a client-supplied membership would be a client-supplied
/// authority.
@immutable
class Membership {
  const Membership({
    required this.principalId,
    required this.role,
    required this.status,
    this.regionId,
    this.shopIds = const <String>{},
  });

  /// The [Principal.id] this membership belongs to.
  final String principalId;

  final CommerceRole role;
  final MembershipStatus status;

  /// Region this membership operates in. Null means unscoped by region, which
  /// only some platform-wide admin permissions accept.
  final String? regionId;

  /// Shops this membership may act for. Meaningful for [CommerceRole.agent].
  /// Empty means "no shop authority", never "all shops".
  final Set<String> shopIds;

  bool get canStartNewWork => status.canStartNewWork;

  bool operatesShop(String shopId) => shopIds.contains(shopId);

  @override
  bool operator ==(Object other) =>
      other is Membership &&
      other.principalId == principalId &&
      other.role == role &&
      other.status == status &&
      other.regionId == regionId &&
      other.shopIds.length == shopIds.length &&
      other.shopIds.containsAll(shopIds);

  @override
  int get hashCode => Object.hash(
    principalId,
    role,
    status,
    regionId,
    Object.hashAllUnordered(shopIds),
  );

  @override
  String toString() =>
      'Membership($principalId, ${role.id}, ${status.id}, region=$regionId, '
      'shops=${shopIds.length})';
}
