/// Shared wire contract: identity, authorization, and the order, assignment
/// and custody lifecycles.
///
/// **Contract version 0.7.** What this package defines today:
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
/// - [evaluateOrderTransition] — the pre-dispatch order and reservation
///   lifecycle, with typed [InventoryEffect] and [FinancialClassification].
/// - [evaluatePickerAssignment], [evaluateRiderAssignment] — the picker and
///   rider assignment lifecycles, sharing one revision model
///   ([reachableSlotRevisionRange]) and one denial vocabulary.
/// - [DeliveryProofPolicyRef], [DeliveryEvidenceRef] — **references only** for
///   a future delivery-proof policy and its protected evidence. They select no
///   proof mechanism, assert no satisfaction, and carry no proof material;
///   successful delivery is **not** executable.
/// - [evaluateCustodyTransition], [initialiseCustodyAtShop] — physical custody:
///   shop initialisation, `shop → picker` pickup, and `picker → rider` receipt,
///   which is the dispatch boundary that moves an order to `in_delivery` and
///   completes the picker assignment.
///
/// What it deliberately does **not** define yet — later slices own these, and
/// no feature may guess them:
///
/// - delivery attempts, customer delivery and delivery confirmation;
/// - refusal and failure handling;
/// - the return lifecycle and post-dispatch inventory restoration — stock
///   cannot become available again until shop receipt **and** inspection;
/// - customer custody and rider assignment completion;
/// - direct shop-to-rider pickup;
/// - a handoff-proof protocol — rider receipt is an *authorized assertion*,
///   not independent proof, and no OTP, QR, signature or photo mechanism
///   exists;
/// - delivery-proof **satisfaction** and the fallback dispute workflow, which
///   `CONSTRAINTS.md` invariant 13 requires **before** delivery confirmation
///   may be coded — FND-003D1 added the references only;
/// - payment and COD lifecycles;
/// - the cash journal, fees, refusal policy, commissions and settlement
///   (blocked on owner decision O6);
/// - proof and dispute workflows.
///
/// **There is no serialization in this package.** No type has a
/// `toJson`/`fromJson`, so no build can decode another's payload and no
/// payload-compatibility claim is made at any version.
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
export 'package:cp_contracts/src/delivery_proof.dart';
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
