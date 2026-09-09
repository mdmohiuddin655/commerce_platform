import 'package:meta/meta.dart';

/// Version of the shared wire contract that a build was compiled against.
///
/// The blueprint lists "older app reading newer schema" as required failure
/// evidence, so compatibility is an explicit, testable decision rather than an
/// assumption. Rule: same [major] means the peer is readable; unknown fields
/// are ignored, a higher [major] is refused and surfaced as an upgrade prompt.
@immutable
class ContractVersion implements Comparable<ContractVersion> {
  const ContractVersion(this.major, this.minor);

  /// Contract shipped by this build. Bumped by FND-003 and later tasks.
  static const ContractVersion current = ContractVersion(0, 1);

  final int major;
  final int minor;

  /// Whether a payload produced under [other] can be read by this build.
  bool canRead(ContractVersion other) => other.major == major;

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
