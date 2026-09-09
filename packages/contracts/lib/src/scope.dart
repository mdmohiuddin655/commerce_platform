import 'package:meta/meta.dart';

/// Facts about the thing being acted on, as the **server** knows them.
///
/// This is read from trusted storage, never from the command payload. If the
/// caller could state the resource's owner, the caller could state that they
/// own it.
@immutable
class ResourceScope {
  const ResourceScope({
    required this.resourceId,
    this.ownerPrincipalId,
    this.shopId,
    this.regionId,
    this.assignedPrincipalIds = const <String>{},
  });

  final String resourceId;

  /// Principal who owns the resource — for an order, the customer.
  final String? ownerPrincipalId;

  /// Shop the resource belongs to, where applicable.
  final String? shopId;

  /// Region the resource belongs to, where applicable.
  final String? regionId;

  /// Principals currently holding an **accepted** assignment on this resource.
  ///
  /// Being offered work is not being assigned it: an offer that has not been
  /// accepted must not appear here. Assignment notification, assignment
  /// acceptance and physical custody are three different facts.
  final Set<String> assignedPrincipalIds;

  bool isOwnedBy(String principalId) => ownerPrincipalId == principalId;

  bool isAssignedTo(String principalId) =>
      assignedPrincipalIds.contains(principalId);

  @override
  bool operator ==(Object other) =>
      other is ResourceScope &&
      other.resourceId == resourceId &&
      other.ownerPrincipalId == ownerPrincipalId &&
      other.shopId == shopId &&
      other.regionId == regionId &&
      other.assignedPrincipalIds.length == assignedPrincipalIds.length &&
      other.assignedPrincipalIds.containsAll(assignedPrincipalIds);

  @override
  int get hashCode => Object.hash(
    resourceId,
    ownerPrincipalId,
    shopId,
    regionId,
    Object.hashAllUnordered(assignedPrincipalIds),
  );

  @override
  String toString() => 'ResourceScope($resourceId, owner=$ownerPrincipalId, '
      'shop=$shopId, region=$regionId)';
}

/// What a permission requires of the relationship between the actor and the
/// resource. Least privilege is expressed here rather than in ad-hoc checks.
enum ScopeRequirement {
  /// No resource relationship required beyond role and membership. Used only
  /// for genuinely unscoped reads such as release health.
  none,

  /// The actor must own the resource (customer ↔ their own order).
  ownResource,

  /// The resource's shop must be one the actor's membership covers.
  ownShop,

  /// The resource's region must match the actor's membership region.
  ownRegion,

  /// The actor must hold an accepted assignment on the resource.
  assignedResource,
}
