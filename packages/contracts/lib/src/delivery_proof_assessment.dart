/// Delivery-proof **assessment**: the trusted-server-produced, immutable result
/// stating whether the referenced proof policy was satisfied.
///
/// FND-003D1 gave the platform a way to *refer to* a proof policy and to
/// protected evidence, and was deliberate that a reference is not a result:
///
/// ```text
/// reference != proof
/// structural validation != authorization
/// structural validation != satisfaction
/// ```
///
/// This module adds the missing half, and **only** that half. It selects no
/// proof mechanism, adds no command and no permission, and leaves successful
/// delivery unimplemented: `OrderState.delivered`, `CustodyHolderKind.customer`
/// and rider `AssignmentState.completed` all remain unreachable.
///
/// ## Stable barrel
///
/// This file is the assessment module's **public surface**. The implementation
/// is split by responsibility across the files it re-exports, so
/// `cp_contracts.dart` — and every consumer — keeps one import path regardless
/// of how the internals are organised:
///
/// | File | Responsibility |
/// |---|---|
/// | `…_verdict.dart` | the two-value verdict vocabulary |
/// | `…_record.dart` | one immutable assessment result |
/// | `…_facts.dart` | the aggregate as loaded from storage |
/// | `…_denial.dart` | refusal vocabulary (internal, never returned verbatim) |
/// | `…_authority.dart` | trusted assessor kinds, server-resolved context, request |
/// | `…_transition.dart` | the permitted transition and its outcome |
/// | `…_validation.dart` | canonical aggregate shape and trusted verdict access |
/// | `…_evaluator.dart` | the pure evaluator |
/// | `…_event.dart` | the single assessment event id |
///
/// The dependency graph is acyclic and flows one way: vocabulary → model →
/// shapes → validation → evaluator. No file imports an app or the backend, and
/// no validation rule is duplicated — identifier rules come from `ids.dart`,
/// proof/evidence rules from `delivery_proof.dart`, and the order, custody and
/// rider aggregate rules from their own canonical validators.
///
/// See `docs/contracts/delivery-proof-assessment.md` and
/// `docs/decisions/ADR-0009-trusted-immutable-proof-assessment.md`.
library;

export 'package:cp_contracts/src/delivery_proof_assessment_authority.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_denial.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_evaluator.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_event.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_facts.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_record.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_transition.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_validation.dart';
export 'package:cp_contracts/src/delivery_proof_assessment_verdict.dart';
