# ADR-0006 — Admin assignment intervention is a separate audited override

- **Status:** **Accepted**
- **Date:** 2026-09-10
- **Task:** FND-003B2A-FIX-001
- **Contract baseline:** SHARED-BASELINE-v1.0
- **Decided by:** repository owner, on review of FND-003B2A

## Context

FND-003B2A introduced `agent.assignment.revoke_picker`: agent-only, active
membership, `ownShop` scope, reason required, and gated on
`ReassignmentSafety.provenNoCustody`.

A reasonable question followed: should platform governance also be able to
intervene — an admin unsticking a stalled order, for instance, where the shop's
agent is unresponsive?

The tempting shortcut is to add `CommerceRole.admin` to that permission's
`eligibleRoles`. It is one line, and it appears to solve the problem.

**It does not.** The two operations differ in every dimension that matters:

| | Agent revoke | Admin intervention |
|---|---|---|
| Who acts | The shop that owns the work | Platform governance, outside the shop |
| Scope | `ownShop` — their own orders | Necessarily crosses shop boundaries |
| Normal or exceptional | Routine reassignment | Exceptional; someone else failed to act |
| Oversight | Reason recorded | Reason **and** approval; a second principal |
| Risk if abused | Bounded to one shop's own work | Unbounded across the platform |

Widening the agent permission would silently grant platform-wide reach through
a rule written for a shop-scoped operation, and the matrix would no longer
describe what the permission actually permits.

## Decision

**`agent.assignment.revoke_picker` stays agent-only. `CommerceRole.admin` is
not added to it, now or later.**

Administrative intervention in picker assignment, if it is ever needed, is a
**separate audited override workflow** in its own permission family.

### Constraints on that future workflow

Binding on whoever implements it:

1. **A separate permission and command family** from agent revoke. Not a role
   added to an existing rule.
2. **Scoped admin authority.** Region-scoped at minimum; never unscoped.
3. **Reason required**, stored with the command.
4. **Approval / dual control required.** A second, different principal — this
   is an exceptional privileged action, and `admin.cash.record_reconciliation`
   is the precedent.
5. **An audit record**: actor, command id, reason, approval evidence, server
   time, and the assignment attempt affected.
6. **Not an arbitrary assignment or status patch.** No target state as an
   argument, consistent with the prohibited-capability rules in
   `docs/contracts/permission-matrix.md`.
7. **Assignee history is never silently overwritten.** Override follows the
   same revoke-then-new-attempt shape, so the record shows what happened.
8. **Custody safety is preserved.** An override may not bypass
   `ReassignmentSafety`; reassigning goods a worker is already carrying stays
   refused. Controlled resolution of an in-flight order is FND-003B3's and
   later policy's, not something an override may shortcut.

### A name, reserved but not implemented

`admin.assignment.override_picker` is **RESERVED / PROPOSED**. It is
deliberately **not** in `Permission.values` and **not** in `permissionMatrix`;
naming it here reserves the identifier and prevents the shortcut, nothing more.

## Consequences

- A future implementer who reaches for "just add admin to the agent
  permission" finds this ADR saying no, and why.
- Admin intervention costs more to build than a one-line widening. That is the
  point: it is a higher-consequence action and should carry approval and audit.
- Until such a workflow exists, a stalled assignment is resolved by the shop's
  own agent. If operational experience shows that is insufficient, the answer
  is a bounded ADMIN governance task implementing the constraints above — not a
  change to this permission.

## Scope

FND-003B2A-FIX-001 records this decision only. **No admin override permission,
command, evaluator or test is added**, and no existing permission changed. A
test asserts `agent.assignment.revoke_picker` remains agent-only.

## Revisit trigger

Reopen when the owner commissions the admin governance workflow. This ADR then
becomes its requirements list, superseded by the ADR that records what was
actually built.
