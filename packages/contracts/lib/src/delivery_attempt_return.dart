/// Delivery **attempt** and **return** lifecycles: the bounded non-success path
/// after dispatch.
///
/// FND-003B3A ended at the dispatch boundary — a rider holds the goods and the
/// order is `in_delivery`. Everything after that was undefined, and the two
/// questions it left open are not the same question:
///
/// ```text
/// what happened at the door?        -> DeliveryAttemptState
/// where did the goods end up?       -> ReturnState
/// ```
///
/// Both are **separate dimensions from the order**. Folding either into
/// `OrderState` would make "refused once, back at the shop, inspected and
/// unsellable" indistinguishable from "cancelled before it ever left", and
/// would force a post-dispatch order state to be invented — which would be
/// inventing the commercial outcome.
///
/// ## What this slice makes executable
///
/// ```text
/// attempt:  pending -> out_for_delivery -> refused
///                                       -> failed
/// return:   not_required --(refusal)--> required -> in_transit
///                                       -> received -> inspected -> closed
/// custody:  rider -> shop, exactly once, on shop receipt
/// stock:    restored exactly once, and ONLY on receipt + restockable inspection
/// ```
///
/// ## What it deliberately refuses to decide
///
/// **Successful delivery is still not executable.** `recordDelivered` is
/// enumerated and always refused with `deliveryProofPolicyDeferred`, because
/// the **proof-satisfaction policy** — what the policy actually requires —
/// is defined nowhere. A `satisfied` `DeliveryProofAssessmentRecord` is *not*
/// consumed as authority for it: "a proof result exists" and "the policy is
/// satisfied" are different claims, and `CONSTRAINTS.md` invariant 13 remains
/// undischarged. `OrderState.delivered`, `CustodyHolderKind.customer` and rider
/// `AssignmentState.completed` all stay unreachable, and **B3-C2 stays FUTURE**.
///
/// **What follows a failed attempt is not decided.** The blueprint says a
/// failed attempt *may* require a return; nothing accepted says when, who
/// decides, how many retries are permitted or who bears the cost. So
/// `evaluateRecordDeliveryFailure` records the fact and stops — it does not
/// even take the return facts as a parameter — and
/// `evaluateFailedAttemptReturnDecision` is enumerated and always refused.
///
/// **The via-picker return route is not implemented.** Not a missing state
/// machine but a missing **authority**: the accepted picker assignment is
/// `completed` at dispatch and its scope removed, so no picker holds
/// post-dispatch authority over the order and none was invented. See ADR-0010.
///
/// **No money, fault or liability.** A refusal carries
/// `FinancialClassification.deferredToFinancialSlice` — **unknown, never
/// zero** — and `ReturnDisposition` answers exactly one question, *may these
/// units be sold again?*. Who owes for a damaged return, whether a refusal fee
/// or refund applies, and what commission follows are **FND-003C**'s, blocked
/// on **O6**. Dispute resolution remains deferred.
///
/// **No proof mechanism.** A shop receipt is an authorized business assertion.
/// There is no OTP, QR code, signature, photo, GPS fix or biometric anywhere in
/// this slice, and choosing one is not this task's to make.
///
/// See `docs/contracts/delivery-attempt-return-lifecycle.md`.
library;

export 'package:cp_contracts/src/delivery_attempt_command.dart';
export 'package:cp_contracts/src/delivery_attempt_return_authorization.dart';
export 'package:cp_contracts/src/delivery_attempt_return_denial.dart';
export 'package:cp_contracts/src/delivery_attempt_return_effect.dart';
export 'package:cp_contracts/src/delivery_attempt_return_evaluator.dart';
export 'package:cp_contracts/src/delivery_attempt_return_facts.dart';
export 'package:cp_contracts/src/delivery_attempt_return_request.dart';
export 'package:cp_contracts/src/delivery_attempt_return_transition.dart';
export 'package:cp_contracts/src/delivery_attempt_return_validation.dart';
export 'package:cp_contracts/src/delivery_attempt_state.dart';
export 'package:cp_contracts/src/return_command.dart';
export 'package:cp_contracts/src/return_state.dart';
