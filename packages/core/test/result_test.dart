import 'package:cp_core/cp_core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('folds the ok branch', () {
      const Result<int> r = Result<int>.ok(7);

      expect(r.isOk, isTrue);
      expect(r.fold((int v) => v * 2, (Failure f) => -1), 14);
    });

    test('folds the failure branch and keeps the command id', () {
      const failure = Failure(
        FailureKind.conflict,
        'stale order revision',
        code: 'ORDER_REVISION_STALE',
        commandId: 'cmd-1',
      );
      const Result<int> r = Result<int>.err(failure);

      expect(r.isOk, isFalse);
      expect(r.fold((int v) => 'ok', (Failure f) => f.commandId), 'cmd-1');
      expect(
        r.fold((int v) => null, (Failure f) => f.kind),
        FailureKind.conflict,
      );
    });
  });
}
