// Renders the canonical permission matrix as Markdown from the live code, so
// docs/contracts/permission-matrix.md cannot drift from
// lib/src/permission_matrix.dart.
//
//   dart run tool/print_permission_matrix.dart
import 'dart:io';

import 'package:cp_contracts/cp_contracts.dart';

String yn(bool value) => value ? '**yes**' : 'no';

void main() {
  final StringBuffer out = StringBuffer()
    ..writeln('| Permission id | Role | Membership | Scope | Reason | '
        'Approval | Restriction |')
    ..writeln('|---|---|---|---|---|---|---|');

  for (final Permission permission in Permission.values) {
    final PermissionRule rule = permissionMatrix[permission]!;
    final String roles =
        rule.eligibleRoles.map((CommerceRole r) => r.id).join(', ');
    final String statuses =
        rule.acceptableStatuses.map((MembershipStatus s) => s.id).join(', ');
    out.writeln(
      '| `${permission.id}` | $roles | $statuses | `${rule.scope.name}` | '
      '${yn(rule.reasonRequired)} | ${yn(rule.approvalRequired)} | '
      '${rule.restriction.isEmpty ? '—' : rule.restriction} |',
    );
  }
  // stdout, not print(): this is a CLI whose output is the artefact.
  stdout.writeln(out.toString().trimRight());
}
