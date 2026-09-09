import 'package:cp_contracts/cp_contracts.dart';
import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

CommandEnvelope envelope({
  String commandId = 'cmd_7Kd93ba-Qz18Xu2P',
  String commandType = 'order.place',
  int expectedRevision = 0,
  Map<String, Object?> payload = const <String, Object?>{'qty': 2},
}) => CommandEnvelope.create(
  commandId: commandId,
  commandType: commandType,
  resourceId: 'ord_Xa91ZZ0plQ7rTt4B',
  expectedRevision: expectedRevision,
  payload: payload,
).fold((CommandEnvelope e) => e, (Failure f) => throw StateError(f.message));

StoredCommandRecord stored(CommandEnvelope source) => StoredCommandRecord(
  commandId: source.commandId,
  fingerprint: CommandFingerprint.of(source),
  resultRevision: 1,
  recordedAtServerUtc: DateTime.utc(2026, 9, 9, 10),
);

void main() {
  group('CommandFingerprint', () {
    test('is stable for the same intent', () {
      expect(CommandFingerprint.of(envelope()),
          CommandFingerprint.of(envelope()));
    });

    test('ignores key order in the payload', () {
      final CommandFingerprint a = CommandFingerprint.of(
        envelope(payload: <String, Object?>{'a': 1, 'b': 2}),
      );
      final CommandFingerprint b = CommandFingerprint.of(
        envelope(payload: <String, Object?>{'b': 2, 'a': 1}),
      );

      expect(a, b);
    });

    test('does not ignore list order — it changes the request', () {
      final CommandFingerprint a = CommandFingerprint.of(
        envelope(payload: <String, Object?>{'items': <int>[1, 2]}),
      );
      final CommandFingerprint b = CommandFingerprint.of(
        envelope(payload: <String, Object?>{'items': <int>[2, 1]}),
      );

      expect(a, isNot(b));
    });

    test('changes when the payload, type or revision changes', () {
      final CommandFingerprint base = CommandFingerprint.of(envelope());

      expect(
        CommandFingerprint.of(envelope(payload: <String, Object?>{'qty': 3})),
        isNot(base),
      );
      expect(
        CommandFingerprint.of(envelope(commandType: 'order.cancel')),
        isNot(base),
      );
      expect(CommandFingerprint.of(envelope(expectedRevision: 1)), isNot(base));
    });

    test('does not depend on the command id', () {
      // The fingerprint describes the request; the id selects the record.
      expect(
        CommandFingerprint.of(envelope(commandId: 'cmd_aaaaaaaaaaaaaaaa')),
        CommandFingerprint.of(envelope(commandId: 'cmd_bbbbbbbbbbbbbbbb')),
      );
    });

    test('distinguishes a string from a number of the same text', () {
      expect(
        CommandFingerprint.of(envelope(payload: <String, Object?>{'q': '2'})),
        isNot(
          CommandFingerprint.of(envelope(payload: <String, Object?>{'q': 2})),
        ),
      );
    });
  });

  group('evaluateIdempotency', () {
    test('new command id executes', () {
      expect(
        evaluateIdempotency(incoming: envelope(), stored: null),
        IdempotencyOutcome.executeNew,
      );
    });

    test('same id + identical request replays the stored result', () {
      final CommandEnvelope first = envelope();

      expect(
        evaluateIdempotency(incoming: envelope(), stored: stored(first)),
        IdempotencyOutcome.replayStoredResult,
      );
    });

    test('same id + changed request is rejected as key reuse', () {
      final CommandEnvelope first = envelope();
      final CommandEnvelope changed = envelope(
        payload: <String, Object?>{'qty': 99},
      );

      expect(
        evaluateIdempotency(incoming: changed, stored: stored(first)),
        IdempotencyOutcome.rejectKeyReuse,
      );
    });

    test('replay identity does not depend on when the retry was sent', () {
      // A record written hours earlier still replays: no clock participates.
      final CommandEnvelope first = envelope();
      final StoredCommandRecord old = StoredCommandRecord(
        commandId: first.commandId,
        fingerprint: CommandFingerprint.of(first),
        resultRevision: 1,
        recordedAtServerUtc: DateTime.utc(2020),
      );

      expect(
        evaluateIdempotency(incoming: envelope(), stored: old),
        IdempotencyOutcome.replayStoredResult,
      );
    });
  });
}
