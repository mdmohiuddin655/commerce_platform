import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ContractVersion', () {
    test('reads a peer on the same major version', () {
      expect(
        const ContractVersion(1, 0).canRead(const ContractVersion(1, 9)),
        isTrue,
      );
    });

    test('refuses a peer on a different major version', () {
      expect(
        const ContractVersion(1, 0).canRead(const ContractVersion(2, 0)),
        isFalse,
      );
    });

    test('orders by major then minor', () {
      expect(
        const ContractVersion(1, 2).compareTo(const ContractVersion(1, 3)),
        lessThan(0),
      );
      expect(
        const ContractVersion(2, 0).compareTo(const ContractVersion(1, 9)),
        greaterThan(0),
      );
    });

    test('exposes the version this build was compiled against', () {
      // FND-003A bumped 0.1 -> 0.2 when the command, event and authorization
      // vocabulary was added. Additive, so the major stays 0.
      expect(ContractVersion.current.toString(), '0.2');
    });

    test('0.2 reads payloads written at 0.1', () {
      // Nothing defined at 0.1 changed meaning; everything in 0.2 is new.
      expect(
        ContractVersion.current.canRead(const ContractVersion(0, 1)),
        isTrue,
      );
    });

    test('a 0.1 reader still accepts 0.2 payloads by the same major rule', () {
      // Forward compatibility is by contract: a 0.1 build ignores fields it
      // does not know rather than refusing the payload.
      expect(
        const ContractVersion(0, 1).canRead(ContractVersion.current),
        isTrue,
      );
    });

    test('a future major break would be refused in both directions', () {
      expect(ContractVersion.current.canRead(const ContractVersion(1, 0)),
          isFalse);
      expect(const ContractVersion(1, 0).canRead(ContractVersion.current),
          isFalse);
    });
  });
}
