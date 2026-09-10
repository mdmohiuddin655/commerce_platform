/// Fallback delivery-proof **dispute**: what happens when the proof assessment
/// a delivery would need is missing, superseded or `notSatisfied`.
///
/// FND-003D1 gave the platform a way to *refer to* a proof policy and to
/// protected evidence. FND-003D2A added the trusted, immutable *result* of
/// evaluating one. Both were deliberate that:
///
/// ```text
/// reference   != proof
/// absence     != notSatisfied
/// corruption  != notSatisfied
/// notSatisfied != fraud, refusal, failure, liability, fee or refund
/// ```
///
/// Something still had to define what happens **when the result is not one a
/// delivery could ever consume** — `CONSTRAINTS.md` invariant 13 requires the
/// fallback dispute workflow to exist *before* delivery confirmation is coded,
/// and ADR-0009 promised that a dispute would be able to point at "the
/// assessment that was current when X happened" and have that mean something.
///
/// This module is that fallback, and **only** that fallback.
///
/// ## What it does
///
/// - One customer-raised dispute per order, bound to the canonical resource.
/// - An **immutable basis** recording which proof situation was contested —
///   canonical absence, or the exact assessment id and revision that concluded
///   `notSatisfied` — pinned when the dispute is raised and never rewritten.
/// - A **standing** calculation that reports whether that recorded basis is
///   still current, has been **superseded**, or cannot be compared at all,
///   without ever mutating, relabelling or reassessing anything.
/// - One administrator operation: recording that review started, which depends
///   on the dispute aggregate **alone** — a reassessment or a torn assessment
///   read cannot freeze a validly raised dispute out of review.
///
/// ## What it deliberately does not do
///
/// **It resolves nothing.** `DeliveryProofDisputeCommand.resolve` is enumerated
/// and always refused `resolutionPolicyDeferred`, and
/// `DeliveryProofDisputeState.resolved` is unreachable with no revision cost
/// invented, because resolving a dispute would mean deciding who prevails,
/// whether the order is delivered, refused or returned, whether a fee, refund,
/// compensation or liability follows, and whether customer participation is
/// optional, mandatory, sufficient or a veto. **Owner decision O6, FND-003C and
/// FND-003B3B own those, and none has run.**
///
/// It selects no proof mechanism, adds no permission, and leaves successful
/// delivery unimplemented: `OrderState.delivered`, `CustodyHolderKind.customer`
/// and rider `AssignmentState.completed` all remain unreachable.
///
/// ## Stable barrel
///
/// This file is the dispute module's **public surface**. The implementation is
/// split by responsibility across the files it re-exports, so
/// `cp_contracts.dart` — and every consumer — keeps one import path regardless
/// of how the internals are organised:
///
/// | File | Responsibility |
/// |---|---|
/// | `…_state.dart` | handling states and the reachable revision per state |
/// | `…_authorization.dart` | binding an operation to a canonical authorization success |
/// | `…_basis.dart` | what was disputed, and how that basis stands today |
/// | `…_command.dart` | named operations, their permissions, and the events |
/// | `…_denial.dart` | refusal vocabulary (internal, never returned verbatim) |
/// | `…_record.dart` | one dispute as currently recorded |
/// | `…_facts.dart` | the aggregate, the server-resolved context and the per-operation requests |
/// | `…_validation.dart` | canonical aggregate shape and trusted access |
/// | `…_transition.dart` | the permitted operation and its all-NONE effects |
/// | `…_evaluator.dart` | one pure evaluator per operation, each with its own read-set |
///
/// The dependency graph is acyclic and flows one way: vocabulary → model →
/// shapes → validation → authorization → evaluator. No file imports an app or the backend, and
/// no validation rule is duplicated — identifier rules come from `ids.dart`,
/// the assessment's canonical shape and verdict access from the FND-003D2A
/// module, and the order's from its own canonical validator.
///
/// See `docs/contracts/delivery-proof-dispute.md`.
library;

export 'package:cp_contracts/src/delivery_proof_dispute_authorization.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_basis.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_command.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_denial.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_evaluator.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_facts.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_record.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_state.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_transition.dart';
export 'package:cp_contracts/src/delivery_proof_dispute_validation.dart';
