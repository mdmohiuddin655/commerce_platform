import 'package:cp_contracts/src/ids.dart';
import 'package:meta/meta.dart';

/// Who physically holds the goods.
///
/// **Custody is not assignment.** An accepted assignment says a worker agreed
/// to do the work; custody says the goods are in their hands. FND-003B2A and
/// FND-003B2B kept those apart deliberately, and this enum is what finally
/// makes the second one explicit.
///
/// There is **no `none` and no `unknown`**. Once an order has a custody
/// aggregate there is exactly one current custodian, and a missing aggregate
/// is *missing* — never silently read as "the shop still has it". That
/// shortcut is how goods go untracked between the shop counter and a rider's
/// bag.
enum CustodyHolderKind {
  /// The shop holds the goods. The canonical starting custodian for a `ready`
  /// order.
  shop,

  /// The order's accepted picker holds the goods.
  picker,

  /// The order's accepted rider holds the goods. The dispatch boundary.
  rider,

  /// **NOT REACHABLE IN FND-003B3A.** Declared so the enum and its wire values
  /// are stable when delivery lands. Reaching it depends on delivery
  /// confirmation and proof, which no slice defines; no transition here enters
  /// it, and none was guessed.
  customer;

  /// Stable wire identifier. Never serialize `Enum.index`.
  String get id => switch (this) {
    CustodyHolderKind.shop => 'shop',
    CustodyHolderKind.picker => 'picker',
    CustodyHolderKind.rider => 'rider',
    CustodyHolderKind.customer => 'customer',
  };

  /// Kinds this slice's evaluator may read or produce.
  static const Set<CustodyHolderKind> executableInThisSlice =
      <CustodyHolderKind>{
        CustodyHolderKind.shop,
        CustodyHolderKind.picker,
        CustodyHolderKind.rider,
      };

  /// Declared for stability, owned by the delivery slice.
  static const Set<CustodyHolderKind> notYetImplemented = <CustodyHolderKind>{
    CustodyHolderKind.customer,
  };

  /// Whether this custodian is a field worker bound to an assignment attempt.
  bool get isWorker =>
      this == CustodyHolderKind.picker || this == CustodyHolderKind.rider;

  static CustodyHolderKind? byId(String id) {
    for (final CustodyHolderKind k in CustodyHolderKind.values) {
      if (k.id == id) {
        return k;
      }
    }
    return null;
  }
}

/// The single current custodian of one order's goods.
///
/// A worker custodian is bound to **immutable assignment identity** — the
/// principal, the `assignmentId` and the generation — not merely to a
/// principal id. That matters because `ResourceScope.assignedPrincipalIds` is
/// a projection of who is assigned *now*: it cannot say which assignment
/// attempt was holding the goods, and after a reassignment it would answer
/// with the replacement. Custody has to name the attempt, for the same reason
/// `SourcePickerBinding` does.
@immutable
class CustodyHolder {
  const CustodyHolder._({
    required this.kind,
    this.shopId,
    this.principalId,
    this.assignmentId,
    this.assignmentGeneration,
  });

  /// The shop holds the goods.
  ///
  /// [shopId] is required and must be non-blank, but is **not** checked
  /// against the opaque-id rule: nothing in this repository governs shop ids
  /// that way — `ResourceScope.shopId` is unvalidated and existing fixtures
  /// use values like `shop_alpha` that the rule would reject. Applying it here
  /// would invent a contract. Recorded as deferred; see
  /// `docs/contracts/custody-lifecycle.md`.
  const CustodyHolder.atShop({required String shopId})
    : this._(kind: CustodyHolderKind.shop, shopId: shopId);

  /// A field worker holds the goods, bound to one assignment attempt.
  const CustodyHolder.worker({
    required CustodyHolderKind kind,
    required String principalId,
    required String assignmentId,
    required int assignmentGeneration,
  }) : this._(
         kind: kind,
         principalId: principalId,
         assignmentId: assignmentId,
         assignmentGeneration: assignmentGeneration,
       );

  final CustodyHolderKind kind;

  /// Set only when [kind] is `shop`.
  final String? shopId;

  /// Set only when [kind] is a worker kind.
  final String? principalId;

  /// Assignment attempt this custody is bound to. Worker kinds only.
  final String? assignmentId;

  /// Generation of that attempt. Worker kinds only.
  final int? assignmentGeneration;

  /// Whether this custody is held by exactly the named assignment attempt.
  ///
  /// All three facts must agree. A replacement attempt takes a new id **and** a
  /// new generation, so comparing one alone could match a different attempt
  /// that happened to line up.
  bool isHeldBy({
    required String principalId,
    required String assignmentId,
    required int generation,
  }) =>
      kind.isWorker &&
      this.principalId == principalId &&
      this.assignmentId == assignmentId &&
      assignmentGeneration == generation;

  /// Whether the shape is structurally sound for its kind.
  ///
  /// Worker identities are validated with the repository's canonical opaque-id
  /// rule — the same one `Principal`, `CommandEnvelope` and `EventEnvelope`
  /// apply. Fails closed; nothing is trimmed or repaired.
  bool get isWellFormed {
    if (kind == CustodyHolderKind.shop) {
      return (shopId?.trim().isNotEmpty ?? false) &&
          principalId == null &&
          assignmentId == null &&
          assignmentGeneration == null;
    }
    if (!kind.isWorker) {
      // `customer` has no defined holder shape in this slice.
      return false;
    }
    final String? p = principalId;
    final String? a = assignmentId;
    final int? g = assignmentGeneration;
    return shopId == null &&
        p != null &&
        a != null &&
        g != null &&
        isValidOpaqueId(p) &&
        isValidOpaqueId(a) &&
        g >= 1;
  }

  @override
  bool operator ==(Object other) =>
      other is CustodyHolder &&
      other.kind == kind &&
      other.shopId == shopId &&
      other.principalId == principalId &&
      other.assignmentId == assignmentId &&
      other.assignmentGeneration == assignmentGeneration;

  @override
  int get hashCode =>
      Object.hash(kind, shopId, principalId, assignmentId, assignmentGeneration);

  @override
  String toString() => kind == CustodyHolderKind.shop
      ? 'CustodyHolder(shop:$shopId)'
      : 'CustodyHolder(${kind.id}:$principalId via $assignmentId '
            'gen=$assignmentGeneration)';
}
