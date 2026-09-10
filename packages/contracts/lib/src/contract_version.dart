import 'package:meta/meta.dart';

/// Version of the shared wire contract that a build was compiled against.
///
/// The blueprint lists "older app reading newer schema" as required failure
/// evidence, so compatibility is an explicit, testable decision rather than an
/// assumption.
///
/// ## This type is a version *policy*, not a compatibility proof
///
/// [isVersionCompatibleWith] answers one narrow question: *does the version
/// policy permit attempting to decode this peer's payload at all?* A `true`
/// result is permission to try. It is **not** evidence that any particular
/// payload decodes, that a field is understood, or that an unknown field is
/// safely ignored.
///
/// Those are properties of a **decoder**, and are proven by that decoder's own
/// tests against real encoded payloads. No serialization exists in the
/// contract yet, so no such claim is made anywhere. See
/// `docs/contracts/version-history.md`.
@immutable
class ContractVersion implements Comparable<ContractVersion> {
  const ContractVersion(this.major, this.minor);

  /// Contract shipped by this build.
  ///
  /// History — see `docs/contracts/version-history.md`:
  ///
  /// - **0.1** (FND-001) — this type only. No vocabulary.
  /// - **0.2** (FND-003A) — additive: command envelope, idempotency,
  ///   event envelope, principal/role/membership/scope, permissions and the
  ///   authorization decision model.
  /// - **0.3** (FND-003B1) — additive: pre-dispatch order and reservation
  ///   lifecycle — states, named commands, transition evaluator, typed
  ///   inventory effects and financial classification.
  /// - **0.4** (FND-003B2A) — additive: picker assignment lifecycle — shared
  ///   assignment states and roles, assignment commands and events, the
  ///   `agent.assignment.revoke_picker` permission, scope-projection and
  ///   custody classifications, and the picker assignment evaluator.
  /// - **0.5** (FND-003B2B) — additive: rider assignment lifecycle — rider
  ///   commands and events, the source-picker binding, the rider assignment
  ///   evaluator and aggregate validator, and the
  ///   `picker.assignment.offer_rider` / `picker.assignment.revoke_rider`
  ///   permissions. The role-neutral `reachableSlotRevisionRange` and
  ///   `AssignmentDenial` moved to a shared assignment file; both keep their
  ///   names, behaviour and export path.
  ///
  /// Each bump so far is a **minor** one at the version-policy level: the
  /// major is unchanged, no earlier definition changed meaning, and every
  /// addition is new surface.
  ///
  /// **No payload-compatibility claim accompanies any of them.** There is
  /// still no serialization in this package — no envelope or lifecycle type
  /// has a `toJson`/`fromJson` — so no build can decode another's payload at
  /// all, and no such claim could be tested honestly. No client has ever been
  /// released against any version.
  static const ContractVersion current = ContractVersion(0, 5);

  final int major;
  final int minor;

  /// Whether the **version policy** permits this build to attempt to decode a
  /// payload produced under [other].
  ///
  /// Same major → attempt permitted. Different major → refuse, and surface an
  /// upgrade prompt rather than partially parsing.
  ///
  /// Renamed from `canRead`, which read as a guarantee that a payload *would*
  /// be readable. It never was: this compares two integers and knows nothing
  /// about any schema. Whether a specific payload decodes is established by
  /// the decoder that owns it.
  bool isVersionCompatibleWith(ContractVersion other) => other.major == major;

  /// True when [other] shares this version's major.
  ///
  /// Identical to [isVersionCompatibleWith] and provided because the policy
  /// *is* the major comparison; use whichever name reads more honestly at the
  /// call site.
  bool isSameMajor(ContractVersion other) => other.major == major;

  @override
  int compareTo(ContractVersion other) => major == other.major
      ? minor.compareTo(other.minor)
      : major.compareTo(other.major);

  @override
  bool operator ==(Object other) =>
      other is ContractVersion &&
      other.major == major &&
      other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}
