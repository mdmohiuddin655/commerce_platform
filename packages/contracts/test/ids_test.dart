import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('opaque id validation', () {
    test('accepts a URL-safe random-looking id', () {
      expect(isValidOpaqueId('cmd_7Kd93ba-Qz18Xu2P'), isTrue);
    });

    test('rejects empty and short ids', () {
      expect(validateOpaqueId(''), IdRejection.empty);
      expect(validateOpaqueId('abc123'), IdRejection.tooShort);
    });

    test('rejects an over-long id', () {
      expect(validateOpaqueId('a' * (maxIdLength + 1)), IdRejection.tooLong);
    });

    test('rejects a sequential business counter', () {
      // Long enough, legal characters — still a counter, still rejected.
      expect(
        validateOpaqueId('00000000000012345'),
        IdRejection.looksSequential,
      );
    });

    test('rejects transport-style ids containing illegal characters', () {
      // An FCM-style message id. This is the mechanical reason a transport id
      // cannot quietly become a business event id.
      expect(
        validateOpaqueId('0:1699999999999999%abcdef12abcdef12'),
        IdRejection.illegalCharacter,
      );
    });
  });
}
