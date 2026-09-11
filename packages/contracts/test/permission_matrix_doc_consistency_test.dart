import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

/// Finds the repository root by walking up from the current directory.
///
/// Deliberately not a hard-coded absolute path and not a fixed number of
/// `..` hops: this test must work whether `dart test` is invoked from
/// `packages/contracts` (the usual case) or from the repository root, and on
/// any machine or CI checkout.
///
/// The markers are `AGENTS.md` plus the `packages/contracts` directory — two
/// facts that together identify this repository, and **neither of them is the
/// document under test**. That separation is deliberate: if the marker were the
/// document itself, a deleted document would surface as "repository root not
/// found" instead of "the document is missing", hiding the real fault behind a
/// misleading message.
Directory? findRepositoryRoot() {
  Directory dir = Directory.current.absolute;
  for (int hops = 0; hops < 8; hops++) {
    final bool hasMarker = File('${dir.path}/AGENTS.md').existsSync();
    final bool hasPackage =
        Directory('${dir.path}/packages/contracts').existsSync();
    if (hasMarker && hasPackage) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
  return null;
}

void main() {
  group('permission-matrix.md declares the current contract version', () {
    test('its declared version equals ContractVersion.current', () {
      // The expected value is DERIVED, never duplicated as a literal. A future
      // bump to 0.12 therefore fails this test until the document is updated —
      // which is the whole point: FND-003C1 moved the contract to 0.11 and left
      // this header saying 0.10, and nothing caught it.
      final String expected = ContractVersion.current.toString();

      final Directory? root = findRepositoryRoot();
      expect(
        root,
        isNotNull,
        reason:
            'could not locate the repository root from ${Directory.current.path}; '
            'expected an ancestor containing both AGENTS.md and packages/contracts',
      );

      final File doc =
          File('${root!.path}/docs/contracts/permission-matrix.md');
      expect(
        doc.existsSync(),
        isTrue,
        reason: 'canonical document not found at ${doc.path}',
      );

      final String text = doc.readAsStringSync();
      // Matches the document's own header form, e.g. "**Contract version 0.11.**".
      final RegExp declaration = RegExp(
        r'\*\*Contract version\s+(\d+\.\d+)\.?\*\*',
      );
      final Iterable<RegExpMatch> matches = declaration.allMatches(text);

      expect(
        matches.length,
        1,
        reason: matches.isEmpty
            ? 'no "**Contract version <major>.<minor>**" declaration found in '
                  '${doc.path}; the guard cannot verify a version it cannot locate'
            : 'expected exactly one current-version declaration in ${doc.path}, '
                  'found ${matches.length} — an ambiguous header cannot be checked',
      );

      final String declared = matches.first.group(1)!;
      expect(
        declared,
        expected,
        reason:
            '${doc.path} declares contract version $declared, but '
            'ContractVersion.current is $expected. Update the document header '
            'when the contract version changes.',
      );
    });

    test('the document still records the 39-permission vocabulary', () {
      // Guards the other half: the version header and the permission count are
      // separate facts, and C1 changed only the first. A doc that tracked the
      // version but lost the count would be no better.
      final Directory? root = findRepositoryRoot();
      expect(root, isNotNull);
      final String text =
          File('${root!.path}/docs/contracts/permission-matrix.md')
              .readAsStringSync();

      expect(Permission.values.length, 39);
      expect(permissionMatrix.length, 39);
      expect(
        text,
        contains('**${Permission.values.length} permissions**'),
        reason: 'the document must state the live permission count',
      );

      // And the generated table must still carry one row per permission.
      final int rows = RegExp(r'^\| `[a-z][a-z0-9_.]*` \|', multiLine: true)
          .allMatches(text)
          .length;
      expect(
        rows,
        permissionMatrix.length,
        reason: 'generated table rows must match permissionMatrix entries',
      );
    });
  });
}
