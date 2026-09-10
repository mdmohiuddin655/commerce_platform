/// Shared wire contract: command and event envelopes, identity and
/// authorization vocabulary.
///
/// **Contract version 0.2** (FND-003A). What this package now defines:
///
/// - [CommandEnvelope] — the one shape every trusted command arrives in, with
///   no actor field by design.
/// - [CommandFingerprint], [evaluateIdempotency] — replay-versus-key-reuse.
/// - [EventEnvelope] — server-assigned facts; a transport id is never the
///   business event id.
/// - [Principal], [CommerceRole], [Membership], [ResourceScope] — identity
///   kept separate from standing, role and scope.
/// - [Permission], [permissionMatrix], [evaluateAuthorization] — one canonical
///   least-privilege matrix and a pure decision function.
///
/// What it deliberately does **not** define yet — later FND-003 slices own
/// these, and no feature may guess them:
///
/// - order, assignment, custody, delivery-attempt and return lifecycles;
/// - inventory effects;
/// - payment and COD lifecycles;
/// - the cash journal, fees, refusal policy, commissions and settlement
///   (blocked on owner decision O6).
library;

export 'package:cp_contracts/src/assignment_command.dart';
export 'package:cp_contracts/src/assignment_effect.dart';
export 'package:cp_contracts/src/assignment_integrity.dart';
export 'package:cp_contracts/src/assignment_state.dart';
export 'package:cp_contracts/src/authorization.dart';
export 'package:cp_contracts/src/command_envelope.dart';
export 'package:cp_contracts/src/contract_version.dart';
export 'package:cp_contracts/src/custody_command.dart';
export 'package:cp_contracts/src/custody_effect.dart';
export 'package:cp_contracts/src/custody_lifecycle.dart';
export 'package:cp_contracts/src/custody_state.dart';
export 'package:cp_contracts/src/event_envelope.dart';
export 'package:cp_contracts/src/idempotency.dart';
export 'package:cp_contracts/src/ids.dart';
export 'package:cp_contracts/src/lifecycle_command.dart';
export 'package:cp_contracts/src/lifecycle_effect.dart';
export 'package:cp_contracts/src/membership.dart';
export 'package:cp_contracts/src/order_lifecycle.dart';
export 'package:cp_contracts/src/order_state.dart';
export 'package:cp_contracts/src/permission.dart';
export 'package:cp_contracts/src/permission_matrix.dart';
export 'package:cp_contracts/src/picker_assignment.dart';
export 'package:cp_contracts/src/principal.dart';
export 'package:cp_contracts/src/reservation_state.dart';
export 'package:cp_contracts/src/rider_assignment.dart';
export 'package:cp_contracts/src/role.dart';
export 'package:cp_contracts/src/scope.dart';
