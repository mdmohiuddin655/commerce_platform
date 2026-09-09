import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('adds and subtracts within one currency', () {
      const a = Money(1250, 'BDT');
      const b = Money(750, 'BDT');

      expect(a + b, const Money(2000, 'BDT'));
      expect(a - b, const Money(500, 'BDT'));
    });

    test('scales by a whole quantity', () {
      expect(const Money(199, 'BDT') * 3, const Money(597, 'BDT'));
    });

    test('represents a reversal as a negative amount', () {
      const posting = Money(500, 'BDT');
      expect((-posting).minorUnits, -500);
      expect((posting + -posting).isZero, isTrue);
    });

    test('refuses cross-currency arithmetic', () {
      expect(
        () => const Money(100, 'BDT') + const Money(100, 'USD'),
        throwsArgumentError,
      );
    });

    test('rejects a non ISO-4217 alpha-3 currency code', () {
      expect(() => Money(100, 'BDTX'), throwsA(isA<AssertionError>()));
    });

    test('orders amounts', () {
      expect(const Money(100, 'BDT') < const Money(200, 'BDT'), isTrue);
      expect(const Money(200, 'BDT') >= const Money(200, 'BDT'), isTrue);
    });
  });
}
