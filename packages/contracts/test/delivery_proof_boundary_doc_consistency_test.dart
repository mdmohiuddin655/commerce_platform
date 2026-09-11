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

/// The document under test, relative to the repository root.
const String kDocumentPath = 'docs/contracts/delivery-proof-boundary.md';

/// The document's single canonical, machine-readable count claim, written in
/// §5 as `**Permission count: 39**`.
///
/// A fixed form is used rather than free prose so that "the claim is missing",
/// "the claim is malformed" and "there are two disagreeing claims" are three
/// distinguishable failures instead of one vague one.
final RegExp kCountDeclaration = RegExp(r'\*\*Permission count:\s*(\d+)\*\*');

/// Present-tense phrasings that assert a permission count in running prose.
///
/// These are the exact shapes that went stale: the document said
/// "`Permission.values` remains **38**" and "a test pins the count at 38" long
/// after FND-003B3B took the vocabulary to 39 at contract 0.10. Any number
/// captured here is a live claim and must equal the live count. Historical
/// prose ("moved **38 → 39** at 0.10") is deliberately not matched — it is
/// true and must stay.
final List<RegExp> kPresentTenseClaims = <RegExp>[
  RegExp(r'`Permission\.values`\s+(?:is|are|remains|remain|stays|stay)\s+'
      r'\*{0,2}(\d+)\*{0,2}'),
  RegExp(r'`permissionMatrix`\s+(?:is|are|remains|remain|stays|stay)\s+'
      r'\*{0,2}(\d+)\*{0,2}'),
  RegExp(r'(?:pins|pin|pinned|pinning)\s+the\s+count\s+at\s+'
      r'\*{0,2}(\d+)\*{0,2}'),
  RegExp(r'(?:live\s+)?count\s+(?:is|remains|stays)\s+\*{0,2}(\d+)\*{0,2}'),
];

/// Reads the document, failing with a specific message for each distinct fault.
String readDocument() {
  final Directory? root = findRepositoryRoot();
  expect(
    root,
    isNotNull,
    reason: 'could not locate the repository root from ${Directory.current.path}; '
        'expected an ancestor containing both AGENTS.md and packages/contracts',
  );

  final File doc = File('${root!.path}/$kDocumentPath');
  expect(
    doc.existsSync(),
    isTrue,
    reason: 'document missing: expected the delivery-proof boundary document at '
        '${doc.path}. The repository root WAS found, so this is a missing or '
        'moved document, not a broken root search. If it was renamed, update '
        'kDocumentPath in this test and say so in the task report.',
  );

  return doc.readAsStringSync();
}

void main() {
  group('delivery-proof-boundary.md states the live permission count', () {
    test('its canonical count claim equals Permission.values.length', () {
      // The expectation is DERIVED, never duplicated as a literal. There is no
      // numeric count anywhere in this file, so a future 40th permission fails
      // this test until the document follows — which is precisely what did not
      // happen when the count moved 38 -> 39 at contract 0.10 and this
      // document kept asserting the old figure in the present tense.
      final int expected = Permission.values.length;
      final String text = readDocument();

      final List<RegExpMatch> matches =
          kCountDeclaration.allMatches(text).toList();

      expect(
        matches.length,
        1,
        reason: matches.isEmpty
            ? 'malformed claim: no "**Permission count: <n>**" declaration found '
                'in $kDocumentPath. The guard cannot verify a count it cannot '
                'locate, and silently passing would recreate the exact drift '
                'this test exists to prevent. Restore the canonical form in §5.'
            : 'ambiguous claim: found ${matches.length} "**Permission count: '
                '<n>**" declarations in $kDocumentPath '
                '(${matches.map((RegExpMatch m) => m.group(1)).join(', ')}). '
                'Exactly one authoritative count claim is allowed — two claims '
                'can disagree, and a reader cannot tell which is canonical.',
      );

      final int declared = int.parse(matches.first.group(1)!);
      expect(
        declared,
        expected,
        reason: '$kDocumentPath declares a permission count of $declared, but '
            'Permission.values.length is $expected. Update the document when '
            'the permission vocabulary changes.',
      );

      // The document claims the figure for BOTH vocabularies, so both must
      // actually agree before the claim can be called true.
      expect(
        permissionMatrix.length,
        expected,
        reason: 'permissionMatrix.length (${permissionMatrix.length}) and '
            'Permission.values.length ($expected) disagree, so the document '
            'cannot state one number for both.',
      );
    });

    test('no stale present-tense count claim survives in the prose', () {
      // The canonical claim above could be correct while a leftover sentence
      // elsewhere still asserts the old number. That is the state this task
      // found the document in, so it gets its own guard.
      final int expected = Permission.values.length;
      final String text = readDocument();
      final List<String> lines = text.split('\n');

      final List<String> stale = <String>[];
      for (final RegExp claim in kPresentTenseClaims) {
        for (final RegExpMatch match in claim.allMatches(text)) {
          final int claimed = int.parse(match.group(1)!);
          if (claimed == expected) {
            continue;
          }
          final int lineNumber =
              '\n'.allMatches(text.substring(0, match.start)).length + 1;
          final String line = lineNumber <= lines.length
              ? lines[lineNumber - 1].trim()
              : '(line unavailable)';
          stale.add('line $lineNumber claims $claimed: "$line"');
        }
      }

      expect(
        stale,
        isEmpty,
        reason: 'stale present-tense permission-count claim in $kDocumentPath — '
            'Permission.values.length is $expected, but:\n  '
            '${stale.join('\n  ')}\n'
            'Historical prose describing a past transition is fine and is not '
            'matched; a present-tense assertion of a dead number is not.',
      );
    });
  });
}
