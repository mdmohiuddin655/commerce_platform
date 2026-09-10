# ADR-0008 — A delivery-proof policy reference is bounded at 64 characters

- **Status:** **Accepted**
- **Date:** 2026-09-10
- **Task:** FND-003D1-FIX-001, **amended by FND-003D1-FIX-002**
- **Contract baseline:** SHARED-BASELINE-v1.0

## Context

FND-003D1 introduced `DeliveryProofPolicyRef` as a **mechanism-neutral**
reference: it says *which* immutable proof policy applies, never that the policy
was satisfied and never how proof would be captured. That neutrality was
deliberate — the repository has no delivery-proof policy vocabulary to reuse,
and inventing a prefix, version suffix or URI requirement would be inventing a
contract rather than referring to one.

Final review found that the neutrality had been over-applied. "No grammar" had
quietly become **"no bound at all"**: the only structural rule was that the
value was not blank, so a reference of any length was structurally valid.

That matters because this is a **wire-facing value object**. It travels through
commands, events, audit records and logs, and each of those multiplies whatever
was put in it — a caller, or a corrupt stored value, could turn one reference
into an amplification surface. The same review found the type's `toString`
echoed the raw value, which made every `print`, crash report and error message a
content-leak and log-injection route (fixed alongside this decision).

There is no third-party constraint forcing a particular number here, so the
question is which number, justified how.

## Decision

**A `DeliveryProofPolicyRef` is at most 64 characters**, exposed as
`maxDeliveryProofPolicyRefLength`. A longer value denies with
`DeliveryProofDenial.policyRefTooLong`.

**`maxIdLength` is the canonical numeric source of truth for this decision**,
and the constant **aliases** it rather than repeating its value:

```dart
const int maxDeliveryProofPolicyRefLength = maxIdLength;
```

The public name stays semantic — callers depend on the *proof-policy* concept,
not directly on an id rule — while the number has exactly one owner.

| Bound | Role |
|---|---|
| `maxIdLength` — every canonical opaque id | **the source of truth** for this decision |
| `CommandEnvelope.commandType` | **supporting precedent** that 64 is already the house ceiling — *not* a second source |

*(Amended by FND-003D1-FIX-002.)* The original decision reused the number but
wrote its own `64` literal, which recreated the very thing the decision was
meant to avoid: two places holding the same constant, free to drift, with no
runtime test able to tell them apart. A narrow source-shape regression now pins
the alias, because `= 64` and `= maxIdLength` are numerically indistinguishable
and only the declaration itself carries the property.

**Divergence requires revisiting this ADR.** If the proof-policy ceiling should
ever differ from `maxIdLength`, that means deliberately replacing the alias with
a separately justified bound and recording why — not quietly editing a literal.

### What this bound is not

**It is not a grammar, and it must never be read as the start of one.** It
constrains *how much*, never *what*. Every mechanism-neutral shape that fits
still passes:

```text
policy/delivery_proof@v1
dp-2026-01
a
urn:example:policy:7
```

Specifically, this decision does **not** introduce:

- a required prefix, suffix or namespace;
- a version-suffix convention;
- a URI or URN requirement;
- any allowed or reserved proof-mechanism name;
- case, punctuation or character-set rules.

**The opaque-id rules are deliberately not applied.** A policy reference is not
an identifier: it has no minimum length, no alphabet restriction and no
"looks sequential" rejection. **Only the ceiling is shared** — the alias is a
numeric coupling, never a grammatical one.

### What is unchanged

- **Blank and whitespace-only still deny** — `policyRefBlank`, and it takes
  precedence, so a 65-character run of spaces is reported as blank.
- **The exact value is preserved.** `trim()` is used *only* to reject blanks.
  Nothing is trimmed, case-folded, re-punctuated or repaired into another
  value, and equality and `hashCode` continue to use the exact underlying
  string.
- **No proof mechanism is selected**, and **no satisfaction rule exists**. The
  bound is not permission to add either. That decision belongs to a later
  bounded task, made against `CONSTRAINTS.md` invariant 13.

## Consequences

- A policy reference can no longer be used to amplify content through commands,
  events, audit records or logs.
- A future task that genuinely needs longer references must revisit this ADR and
  say why — rather than the limit silently not existing.
- If the repository ever adopts a real delivery-proof policy vocabulary, this
  ADR is superseded by the one that defines it. The bound would then be a
  consequence of that grammar rather than a standalone safety rule.
- 64 is not claimed to be optimal. It is claimed to be **consistent**, which for
  a safety ceiling with no external constraint is the more useful property.

## Scope

FND-003D1-FIX-001 records this decision and the bound; FND-003D1-FIX-002 makes
the constant alias `maxIdLength` rather than repeat it. **No proof mechanism,
satisfaction policy, permission, command, event or state was added by either**,
and successful delivery remains non-executable.

## Revisit trigger

Reopen when a delivery-proof policy vocabulary is actually defined, or if a
concrete reference legitimately needs more than 64 characters.
