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
      expect(ContractVersion.current.toString(), '0.1');
    });
  });
}
