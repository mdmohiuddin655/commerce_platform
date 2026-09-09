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
    this.offeredPrincipalIds = const <String>{},
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

  /// Principals this resource's work has been **offered** to and who have not
  /// yet accepted.
  ///
  /// Separate from [assignedPrincipalIds] on purpose. A worker must be able to
  /// accept or decline an offer *without* already holding an assignment —
  /// requiring an accepted assignment to accept one would be circular. Equally,
  /// an offer must not open post-acceptance actions: a picker who was merely
  /// offered work cannot record a pickup.
  ///
  /// Like every other field here this is read from **trusted server storage**,
  /// never from a command payload. If a caller could state who was offered the
  /// work, a caller could offer it to themselves.
  ///
  /// This set says only *who the offer was addressed to*. Whether the offer is
  /// still live, already declined, expired or superseded is **assignment
  /// lifecycle state, owned by FND-003B** — authorization establishes "this
  /// offer belongs to this actor and is inside allowed scope", and the
  /// lifecycle then establishes "this offer is still in a state that may
  /// transition".
  final Set<String> offeredPrincipalIds;

  bool isOwnedBy(String principalId) => ownerPrincipalId == principalId;

  bool isAssignedTo(String principalId) =>
      assignedPrincipalIds.contains(principalId);

  /// Whether the work was offered to [principalId]. Being offered is **not**
  /// being assigned; see [offeredPrincipalIds].
  bool isOfferedTo(String principalId) =>
      offeredPrincipalIds.contains(principalId);

  @override
  bool operator ==(Object other) =>
      other is ResourceScope &&
      other.resourceId == resourceId &&
      other.ownerPrincipalId == ownerPrincipalId &&
      other.shopId == shopId &&
      other.regionId == regionId &&
      other.assignedPrincipalIds.length == assignedPrincipalIds.length &&
      other.assignedPrincipalIds.containsAll(assignedPrincipalIds) &&
      other.offeredPrincipalIds.length == offeredPrincipalIds.length &&
      other.offeredPrincipalIds.containsAll(offeredPrincipalIds);

  @override
  int get hashCode => Object.hash(
    resourceId,
    ownerPrincipalId,
    shopId,
    regionId,
    Object.hashAllUnordered(assignedPrincipalIds),
    Object.hashAllUnordered(offeredPrincipalIds),
  );

  @override
  String toString() => 'ResourceScope($resourceId, owner=$ownerPrincipalId, '
      'shop=$shopId, region=$regionId)';
}

/// What a permission requires of the relationship between the actor and the
/// resource. Least privilege is expressed here rather than in ad-hoc checks.
///
/// A [PermissionRule] carries a **set** of these and **all of them must hold**.
/// That is what lets assignment acceptance require both "the offer was
/// addressed to you" *and* "you are in the right region" without dropping
/// either constraint.
///
/// Declaration order is the evaluation order, so the reported deny reason is
/// deterministic regardless of how a rule's set was written.
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

  /// The work must have been **offered to** the actor.
  ///
  /// Used for accepting and declining an offer. Deliberately not
  /// [assignedResource]: requiring an accepted assignment in order to accept
  /// one would be circular.
  offeredResource,

  /// The actor must hold an **accepted** assignment on the resource.
  ///
  /// Used for every post-acceptance action — viewing assigned work, custody,
  /// delivery attempts, proof, COD reporting. An offer alone never satisfies
  /// this.
  assignedResource,
}
