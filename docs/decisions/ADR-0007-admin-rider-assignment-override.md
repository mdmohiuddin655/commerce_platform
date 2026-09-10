# ADR-0007 — Admin rider intervention is a separate audited override

- **Status:** **Accepted**
- **Date:** 2026-09-10
- **Task:** FND-003B2B
- **Contract baseline:** SHARED-BASELINE-v1.0
- **Extends:** [ADR-0006](ADR-0006-admin-picker-assignment-override.md)

## Context

FND-003B2B introduced `picker.assignment.revoke_rider`: picker-only, active
membership, `assignedResource + ownRegion` scope, reason required, and gated on
`ReassignmentSafety.provenNoCustody`. The actor must be the picker currently
holding the order's accepted picker assignment.

The same question ADR-0006 answered for pickers arrives again, one level down:
should platform governance be able to intervene when a rider is stuck and the
picker is unresponsive?

And the same shortcut is available: add `CommerceRole.admin` to the picker
permission's `eligibleRoles`. One line.

**It is wrong for the same reasons, plus one that is new here.**

| | Picker revokes rider | Admin intervention |
|---|---|---|
| Who acts | The worker who arranged the delivery | Platform governance, outside the order |
| Scope | `assignedResource + ownRegion` — the order they hold | Necessarily crosses order, shop and region boundaries |
| Normal or exceptional | Routine reassignment | Exceptional; someone else failed to act |
| Oversight | Reason recorded | Reason **and** approval; a second principal |
| Risk if abused | Bounded to one order the actor already holds | Unbounded across the platform |

The new reason: `picker.assignment.offer_rider` and
`picker.assignment.revoke_rider` are scoped by `assignedResource`, which for a
picker means *"you hold the accepted picker assignment on this order"*. An
admin never holds one. Adding `admin` to the role set would therefore either be
inert — the scope check would still fail — or would force `assignedResource` to
be loosened for admins, which would silently weaken it for **every** permission
that uses it, including `picker.custody.record_pickup` and
`rider.custody.record_receipt`. A one-line widening here reaches much further
than the line suggests.

## Decision

**`picker.assignment.offer_rider` and `picker.assignment.revoke_rider` stay
picker-only. `CommerceRole.admin` is not added to either, now or later.**

Administrative intervention in rider assignment, if it is ever needed, is a
**separate audited override workflow** in its own permission family.

### Constraints on that future workflow

Binding on whoever implements it — the same list ADR-0006 binds for pickers,
with the rider-specific additions at 9 and 10:

1. **A separate permission and command family.** Not a role added to an
   existing rule, and not a reuse of the picker override family either: the
   two aggregates have different dependants.
2. **Scoped admin authority.** Region-scoped at minimum; never unscoped.
3. **Reason required**, stored with the command.
4. **Approval / dual control required.** A second, different principal.
5. **An audit record**: actor, command id, reason, approval evidence, server
   time, and the rider assignment attempt affected.
6. **Not an arbitrary assignment or status patch.** No target state as an
   argument.
7. **Rider assignee history is never silently overwritten.** Override follows
   the same revoke-then-new-attempt shape.
8. **Custody safety is preserved.** An override may not bypass
   `ReassignmentSafety`; reassigning goods a rider is already carrying stays
   refused.
9. **The source picker binding is never rewritten.** An override may end a
   rider attempt, but it must not make the record claim a different picker
   offered the work. The binding is history, not a pointer to be repaired.
10. **The picker slot is not silently mutated as a side effect.** If an
    intervention needs both aggregates to change, both changes are explicit,
    separately authorized and separately audited — see backend criterion RA17.

### A name, reserved but not implemented

`admin.assignment.override_rider` is **RESERVED / PROPOSED**. It is
deliberately **not** in `Permission.values`, **not** in `permissionMatrix` and
**not** in `AssignmentCommand`; naming it here reserves the identifier and
prevents the shortcut, nothing more. Tests pin its absence in all three places.

## Consequences

- A future implementer who reaches for "just add admin to the picker
  permission" finds this ADR saying no, and why the `assignedResource`
  consequence makes it worse than it looks.
- Admin intervention costs more to build than a one-line widening. That is the
  point.
- Until such a workflow exists, a stuck rider assignment is resolved by the
  order's current accepted picker — including a *replacement* picker, which the
  rider evaluator deliberately permits so the slot is never unresolvable. If
  operational experience shows that is insufficient, the answer is a bounded
  ADMIN governance task implementing the constraints above.

## Scope

FND-003B2B records this decision only. **No admin override permission, command,
evaluator or test path is added**, and no existing permission changed.

## Revisit trigger

Reopen when the owner commissions the admin governance workflow. This ADR then
becomes its rider-side requirements list, alongside ADR-0006's picker-side one,
superseded by the ADR that records what was actually built.
