/// Commerce roles a **human** membership can hold.
///
/// These are the five user-facing roles of the shared baseline. A trusted
/// server worker is not listed here on purpose — see [PrincipalKind].
///
/// A role name on its own authorizes nothing. See `docs/contracts/authorization-invariants.md`.
enum CommerceRole {
  /// Buys. Owns their own orders and nobody else's.
  customer,

  /// Operates one or more shops they are a member of.
  agent,

  /// Collects goods from a shop and hands them to a rider.
  picker,

  /// Carries goods to the customer, may collect cash on delivery.
  rider,

  /// Platform governance. Explicitly **not** unrestricted write access.
  admin;

  /// Stable wire identifier. Never serialize `Enum.index` — reordering this
  /// enum would silently change every stored value.
  String get id => switch (this) {
    CommerceRole.customer => 'customer',
    CommerceRole.agent => 'agent',
    CommerceRole.picker => 'picker',
    CommerceRole.rider => 'rider',
    CommerceRole.admin => 'admin',
  };

  /// Roles that perform field work under assignment.
  static const Set<CommerceRole> fieldWorkers = <CommerceRole>{
    CommerceRole.picker,
    CommerceRole.rider,
  };
}
