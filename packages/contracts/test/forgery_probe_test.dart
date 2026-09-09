import 'dart:io';

import 'package:test/test.dart';

/// Compile-time regression guard for FND-003A-FIX-002.
///
/// At commit `228409d` the documentation claimed idempotency could not be
/// called without real authorization, while `AuthorizationDecision.allow()`
/// was a public constructor — so any caller could fabricate success. The fix
/// is a type-system boundary, and a type-system boundary is proven by asking a
/// compiler, not by grepping source text.
///
/// `test/support/forgery_probe.dart.txt` contains six forgery attempts. It is
/// deliberately not a `.dart` file, so the repository gate never analyzes it —
/// every line in it is supposed to fail. This test copies it to a temporary
/// `.dart` file, runs `dart analyze` on it, and asserts each attempt is
/// rejected.
void main() {
  group('a successful authorization artifact cannot be forged', () {
    late String output;
    late int exitCode;

    setUpAll(() {
      final File fixture = File('test/support/forgery_probe.dart.txt');
      expect(
        fixture.existsSync(),
        isTrue,
        reason: 'forgery fixture missing; the guard would silently pass',
      );

      final File probe = File('test/_forgery_probe_generated.dart');
      try {
        probe.writeAsStringSync(fixture.readAsStringSync());
        final ProcessResult result = Process.runSync('dart', <String>[
          'analyze',
          probe.path,
        ]);
        output = '${result.stdout}${result.stderr}';
        exitCode = result.exitCode;
      } finally {
        if (probe.existsSync()) {
          probe.deleteSync();
        }
      }
    });

    test('the probe does not compile', () {
      expect(
        exitCode,
        isNot(0),
        reason: 'every forgery attempt must be a compile error:\n$output',
      );
    });

    test('AuthorizationGrant has no public constructor', () {
      expect(output, contains('new_with_undefined_constructor_default'));
    });

    test('its private constructor is unreachable from another library', () {
      expect(output, contains('new_with_undefined_constructor'));
    });

    test('AuthorizationGrant cannot be implemented or extended', () {
      // `final class` — this is what stops a look-alike being handed to
      // evaluateIdempotency.
      expect(
        output,
        contains(
          "The class 'AuthorizationGrant' can't be implemented outside of "
          'its library',
        ),
      );
      expect(
        output,
        contains(
          "The class 'AuthorizationGrant' can't be extended outside of its "
          'library',
        ),
      );
    });

    test('AuthorizationDecision.allow() no longer exists', () {
      expect(
        output,
        contains("The method 'allow' isn't defined for the type "
            "'AuthorizationDecision'"),
      );
    });

    test('AuthorizationDecision cannot be implemented either', () {
      expect(
        output,
        contains(
          "The class 'AuthorizationDecision' can't be implemented outside of "
          'its library',
        ),
      );
    });

    test('all six attempts are rejected, not merely some', () {
      final RegExp issues = RegExp(r'(\d+) issues? found');
      final Match? match = issues.firstMatch(output);

      expect(match, isNotNull, reason: 'could not read the issue count');
      expect(
        int.parse(match!.group(1)!),
        greaterThanOrEqualTo(6),
        reason: 'one attempt per forgery route, plus knock-on errors',
      );
    });

    tearDownAll(() {
      final File leftover = File('test/_forgery_probe_generated.dart');
      if (leftover.existsSync()) {
        leftover.deleteSync();
      }
    });
  });
}
