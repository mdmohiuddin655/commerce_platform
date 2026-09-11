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

/// The document's **prose**, with the generated table and fenced code removed.
///
/// The ordinal guard below must read the narrative header — where the
/// vocabulary's count history is told — and must not read the generated table,
/// whose `Restriction` cells are free prose owned by
/// `permission_matrix.dart` rather than by this document.
String permissionMatrixProse(String markdown) {
  final StringBuffer prose = StringBuffer();
  bool insideFence = false;
  for (final String line in markdown.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      insideFence = !insideFence;
      continue;
    }
    if (insideFence || line.trimLeft().startsWith('|')) {
      continue;
    }
    prose.writeln(line);
  }
  return prose.toString();
}

/// Every **declaration ordinal** in [prose] — `the 39th`, `13th`, `1st`.
///
/// An ordinal is a claim about a value's *position in `Permission.values`*.
/// This document neither derives nor regenerates declaration positions, so it
/// has no way to keep such a claim true: FND-003C1-FIX-002 called
/// `agent.return.record_receipt` "the 39th" because it took the permission that
/// moved the **count** to 39 for the value **declared** 39th. They are
/// different facts — that permission sits at zero-based index 12 — and the
/// wording survived three tasks before anything caught it.
///
/// Counts belong here as cardinals (`39 permissions`) and changes as
/// transitions (`38 → 39`); neither form can be read as a position, so neither
/// is matched.
List<String> declarationOrdinalsIn(String prose) => RegExp(r'\b\d+(?:st|nd|rd|th)\b')
    .allMatches(prose)
    .map((RegExpMatch m) => m.group(0)!)
    .toList();

/// Every **total-count transition** in [prose] as `[from, to]` — `38 → 39`,
/// `38 -> 39`, `38 to 39`.
///
/// Markdown emphasis is stripped first so a bolded `**38 → 39**` counts. The
/// lookbehind rejects a dotted neighbour so a version range such as
/// `0.10 to 0.11` is never mistaken for a count transition, while the lookahead
/// rejects only a decimal continuation — a sentence-final `38 → 39.` still
/// counts.
List<List<int>> countTransitionsIn(String prose) {
  final String plain = prose.replaceAll(RegExp(r'[*`]'), '');
  return RegExp(r'(?<![\d.])(\d+)\s*(?:→|-+>|to)\s*(\d+)(?!\.?\d)')
      .allMatches(plain)
      .map((RegExpMatch m) =>
          <int>[int.parse(m.group(1)!), int.parse(m.group(2)!)])
      .toList();
}

void main() {
  group('permission-matrix.md states counts without declaration ordinals', () {
    late String prose;

    setUp(() {
      final Directory? root = findRepositoryRoot();
      expect(root, isNotNull);
      prose = permissionMatrixProse(
        File('${root!.path}/docs/contracts/permission-matrix.md')
            .readAsStringSync(),
      );
    });

    test('its prose attaches no declaration ordinal to the vocabulary', () {
      final List<String> ordinals = declarationOrdinalsIn(prose);
      expect(
        ordinals,
        isEmpty,
        reason:
            'docs/contracts/permission-matrix.md prose contains the declaration '
            'ordinal(s) ${ordinals.join(', ')}. An ordinal claims a position in '
            'Permission.values, which this document never derives, so it cannot '
            'stay true — "the 39th" here meant the permission that moved the '
            'COUNT to 39, which is declared 13th. State the size as a cardinal '
            '("39 permissions") and a change as a transition ("38 -> 39").',
      );
    });

    test('a count change is recorded as a transition to the live total', () {
      // Derived from the vocabulary, never a literal: the document must show
      // the size it reached, whatever that size becomes. A slice that replaces
      // the transition with a positional claim fails here as well as above.
      final int live = Permission.values.length;
      final List<List<int>> transitions = countTransitionsIn(prose);
      expect(
        transitions.any((List<int> t) => t[1] == live && t[0] < live),
        isTrue,
        reason:
            'docs/contracts/permission-matrix.md prose records no total-count '
            'transition ending at the live Permission.values.length ($live); '
            'found ${transitions.map((List<int> t) => '${t[0]} -> ${t[1]}').toList()}. '
            'Express a vocabulary change as the total moving from its previous '
            'size to its new one, not as the position of the value added.',
      );
    });
  });

  group('the ordinal guard, proved against material outside the worktree', () {
    // Negative and positive controls. A guard that has never been shown to
    // fail proves nothing (AGENTS.md section 6), and it must fail on the real
    // historical defect rather than on a pattern invented to match it. The
    // fixtures are written to the system temp directory, never into the
    // repository tree.
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('permission_matrix_guard');
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    String proseOfFixture(String name, String body) {
      final File fixture = File('${sandbox.path}/$name.md')
        ..writeAsStringSync(body);
      return permissionMatrixProse(fixture.readAsStringSync());
    }

    test('the published pre-fix wording is rejected', () {
      // Verbatim from permission-matrix.md line 8 at 4b22173, the last commit
      // that carried it. Quoted, not paraphrased, so the control cannot drift
      // into testing a defect that never shipped.
      final String prose = proseOfFixture(
        'pre_fix',
        'FND-003B3B (`agent.return.record_receipt`, the 39th) '
            '— **39 permissions**.\n',
      );
      expect(declarationOrdinalsIn(prose), <String>['39th']);
    });

    test('the corrected wording is accepted', () {
      final int live = Permission.values.length;
      final String prose = proseOfFixture(
        'corrected',
        'FND-003B3B (`agent.return.record_receipt`, which took the total from\n'
            '**${live - 1} → $live**) — **$live permissions**.\n',
      );
      expect(declarationOrdinalsIn(prose), isEmpty);
      expect(
        countTransitionsIn(prose)
            .any((List<int> t) => t[1] == live && t[0] < live),
        isTrue,
      );
    });

    test('historical count-transition wording is not an ordinal error', () {
      final String prose = proseOfFixture(
        'transitions',
        '`Permission.values` and `permissionMatrix` go **38 → 39**.\n'
            'FND-003B3B took the total permission count from 38 to 39.\n'
            'That slice added one permission, so the total rose 38 -> 39.\n',
      );
      expect(declarationOrdinalsIn(prose), isEmpty);
      expect(
        countTransitionsIn(prose),
        <List<int>>[
          <int>[38, 39],
          <int>[38, 39],
          <int>[38, 39],
        ],
      );
    });

    test('a version range is not read as a count transition', () {
      final String prose = proseOfFixture(
        'versions',
        'The contract moved 0.10 to 0.11 without touching the vocabulary.\n',
      );
      expect(countTransitionsIn(prose), isEmpty);
    });

    test('the generated table is not searched for ordinals', () {
      // Restriction cells are prose owned by permission_matrix.dart. A future
      // rule legitimately describing, say, "the 1st attempt" must not fail a
      // guard aimed at this document's own header.
      final String prose = proseOfFixture(
        'table',
        '| Permission id | Role |\n'
            '|---|---|\n'
            '| `delivery.attempt.record` | rider | Only the 1st attempt. |\n',
      );
      expect(declarationOrdinalsIn(prose), isEmpty);
    });
  });

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
