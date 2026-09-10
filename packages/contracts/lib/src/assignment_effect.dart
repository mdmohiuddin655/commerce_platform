import 'package:meta/meta.dart';

/// How an assignment transition changes the **authorization projections** on
/// `ResourceScope`.
///
/// The canonical assignment record is the business truth. `offeredPrincipalIds`
/// and `assignedPrincipalIds` are *derived* facts that let
/// `evaluateAuthorization` answer "is this actor the offer recipient / the
/// assignee" cheaply. A stale projection must never be allowed to redefine
/// assignment history — it is rebuilt from the record, not the other way round.
///
/// Typed rather than described in prose so the backend applies a value instead
/// of re-deriving intent from a comment, and so a test can assert that an offer
/// never grants assigned scope.
@immutable
class ScopeProjectionEffect {
  const ScopeProjectionEffect({
    this.addToOffered = const <String>{},
    this.removeFromOffered = const <String>{},
    this.addToAssigned = const <String>{},
    this.removeFromAssigned = const <String>{},
  });

  /// A transition that changes no authorization projection.
  const ScopeProjectionEffect.none()
    : addToOffered = const <String>{},
      removeFromOffered = const <String>{},
      addToAssigned = const <String>{},
      removeFromAssigned = const <String>{};

  /// Principals gaining `offeredResource` scope.
  final Set<String> addToOffered;

  /// Principals losing `offeredResource` scope.
  final Set<String> removeFromOffered;

  /// Principals gaining `assignedResource` scope — i.e. an **accepted**
  /// assignment. An offer never populates this.
  final Set<String> addToAssigned;

  /// Principals losing `assignedResource` scope.
  final Set<String> removeFromAssigned;

  bool get isEmpty =>
      addToOffered.isEmpty &&
      removeFromOffered.isEmpty &&
      addToAssigned.isEmpty &&
      removeFromAssigned.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ScopeProjectionEffect &&
      _sameSet(other.addToOffered, addToOffered) &&
      _sameSet(other.removeFromOffered, removeFromOffered) &&
      _sameSet(other.addToAssigned, addToAssigned) &&
      _sameSet(other.removeFromAssigned, removeFromAssigned);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(addToOffered),
    Object.hashAllUnordered(removeFromOffered),
    Object.hashAllUnordered(addToAssigned),
    Object.hashAllUnordered(removeFromAssigned),
  );

  @override
  String toString() =>
      'ScopeProjectionEffect(+offered=$addToOffered, -offered=$removeFromOffered, '
      '+assigned=$addToAssigned, -assigned=$removeFromAssigned)';
}

/// What a transition does to **physical custody**.
///
/// Custody is not implemented in FND-003B2A at all — it is FND-003B3's. This
/// classification exists so every assignment transition states the answer
/// rather than leaving it to inference, and so no later reader concludes that
/// an accepted assignment means goods have moved.
enum CustodyClassification {
  /// This transition does not start, transfer or end custody. Every picker
  /// assignment transition in this slice carries this.
  noneInThisSlice,
}

/// Whether an accepted assignment may be withdrawn for reassignment.
///
/// **Fails closed.** Controlled revocation is permitted only when the backend
/// can *prove* the worker never took physical custody. If custody has started,
/// or if custody state cannot yet be determined, reassignment is refused:
/// silently reassigning goods somebody is already carrying is how inventory and
/// accountability are lost.
///
/// FND-003B2A does not implement custody, so nothing here computes this — the
/// backend supplies it, and FND-003B3 will map real custody state onto it.
enum ReassignmentSafety {
  /// The backend established, from trusted custody facts, that this worker
  /// holds nothing.
  provenNoCustody,

  /// Custody has started, or its state is unknown. **Unknown is not safe.**
  blockedOrUnknown;

  bool get permitsRevocation => this == ReassignmentSafety.provenNoCustody;
}
