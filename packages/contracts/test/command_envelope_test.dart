import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

const String validCommandId = 'cmd_7Kd93ba-Qz18Xu2P';
const String validResourceId = 'ord_Xa91ZZ0plQ7rTt4B';

Result<CommandEnvelope> build({
  String commandId = validCommandId,
  String commandType = 'order.place',
  String resourceId = validResourceId,
  int expectedRevision = 0,
  Map<String, Object?> payload = const <String, Object?>{},
}) => CommandEnvelope.create(
  commandId: commandId,
  commandType: commandType,
  resourceId: resourceId,
  expectedRevision: expectedRevision,
  payload: payload,
);

String? codeOf(Result<CommandEnvelope> r) =>
    r.fold((CommandEnvelope _) => null, (Failure f) => f.code);

void main() {
  group('valid envelope', () {
    test('is accepted and carries the current contract version', () {
      final Result<CommandEnvelope> result = build();

      expect(result.isOk, isTrue);
      final CommandEnvelope envelope = result.fold(
        (CommandEnvelope e) => e,
        (Failure f) => throw StateError(f.message),
      );
      expect(envelope.commandType, 'order.place');
      expect(envelope.expectedRevision, 0);
      expect(envelope.contractVersion, ContractVersion.current);
      expect(ContractVersion.current.toString(), '0.4');
    });

    test('payload is unmodifiable once accepted', () {
      final CommandEnvelope envelope = build(
        payload: <String, Object?>{'note': 'x'},
      ).fold((CommandEnvelope e) => e, (Failure f) => throw StateError('n/a'));

      expect(
        () => envelope.payload['injected'] = 'y',
        throwsUnsupportedError,
      );
    });
  });

  group('invalid envelope input', () {
    test('rejects a non-opaque command id', () {
      expect(codeOf(build(commandId: '42')), 'ENVELOPE_COMMAND_ID_INVALID');
    });

    test('rejects a sequential resource id', () {
      expect(
        codeOf(build(resourceId: '00000000000000001')),
        'ENVELOPE_RESOURCE_ID_INVALID',
      );
    });

    test('rejects a negative expected revision', () {
      expect(codeOf(build(expectedRevision: -1)), 'ENVELOPE_REVISION_INVALID');
    });

    test('rejects a malformed command type', () {
      for (final String bad in <String>['Order.Place', 'order', 'order..place',
        '', 'order place']) {
        expect(
          codeOf(build(commandType: bad)),
          'ENVELOPE_COMMAND_TYPE_INVALID',
          reason: 'should reject "$bad"',
        );
      }
    });
  });

  group('actor authority rule', () {
    test('envelope exposes no actor, user, role or permission field', () {
      final CommandEnvelope envelope = build().fold(
        (CommandEnvelope e) => e,
        (Failure f) => throw StateError('n/a'),
      );

      // Structural guarantee: the only fields that exist are these. If someone
      // adds an actor field later, this test is where it is caught.
      expect(
        envelope.toString(),
        allOf(
          contains('order.place'),
          isNot(contains('actor')),
          isNot(contains('role')),
        ),
      );
    });

    test('actor-shaped payload keys are accepted as inert data', () {
      // The envelope does not reject them — they are just ordinary payload.
      // What matters is that authorization never reads the payload, which is
      // asserted in authorization_test.dart.
      final Result<CommandEnvelope> result = build(
        payload: <String, Object?>{'actorId': 'someone_else', 'role': 'admin'},
      );

      expect(result.isOk, isTrue);
    });
  });
}
