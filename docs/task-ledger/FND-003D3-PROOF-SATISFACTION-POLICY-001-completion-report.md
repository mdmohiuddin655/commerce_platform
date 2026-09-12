# FND-003D3-PROOF-SATISFACTION-POLICY-001 completion report

- **Task:** define and record the authoritative delivery proof-satisfaction
  policy required by `CONSTRAINTS.md` invariant 13, as an accepted ADR. **Policy
  only** — no implementation.
- **Owner:** ADMIN / shared delivery contracts, under the **explicit owner
  delegation** granted in this task's brief, which authorized ADMIN to resolve
  the previously undefined proof-satisfaction policy within conservative
  boundaries without returning options to the owner.
- **Baseline `origin/main`:** `81c623ec1537b99a86e57b6572f9d6cce3a06c3b`,
  verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`, and unchanged by this task.
- **Branch:** `fnd/FND-003D3-proof-satisfaction-policy-001`, created from that
  exact commit.
- **Scope:** documentation and decision record only. **Zero executable change.**
- **Escalation:** none required. No repository evidence revealed a
  legal/regulatory decision that could not be expressed neutrally; the ADR
  carries an explicit legal-neutrality section instead of a compliance claim.

---

## 1. Preconditions

```text
$ git status --short          # before any edit
(empty — clean)

$ git rev-parse origin/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
$ git ls-remote origin refs/heads/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b        refs/heads/main
                                        ↑ both agree

$ git checkout -b fnd/FND-003D3-proof-satisfaction-policy-001 81c623ec…
Switched to a new branch
```

**Decision inventory before editing** — `docs/decisions/` held exactly eleven
ADRs, `ADR-0001` … `ADR-0011`. **`ADR-0012` did not exist and no later ADR
existed**, so 0012 is genuinely the next identifier. No branch or remote ref
matching `FND-003D3` existed, and no ledger row claimed to resolve proof
satisfaction — the ledger's FND-003, FND-003B3 and FND-003D rows each recorded
the policy as outstanding, which is what this task closes.

---

## 2. The decision — ADR-0012, Accepted 2026-09-12

**Delivery proof satisfaction is a server-issued, short-lived, single-use
confirmation challenge, bound to one resource and attempt, fulfilled by the
customer side and verified server-side, fail-closed.**

| Principle required by the brief | How ADR-0012 meets it |
|---|---|
| **Server-authoritative** | Only ADR-0009's authorized proof verifier may record `DeliveryProofAssessmentVerdict.satisfied`. Rider and customer assertions are inputs, never authority. No status setter, no override verdict, no new permission. |
| **Fail-closed** | Missing, expired, replayed, mismatched, mis-bound, stale-revision or malformed input yields **no satisfaction**. Corruption is never downgraded to a verdict (ADR-0009's `canonicalVerdict` rule). **No timeout ripens into delivered.** |
| **Resource-bound** | Bound at issuance to the order's `resourceId`. One challenge can never be redeemed against a second order. |
| **Attempt-bound** | Bound to one specific delivery attempt; at most one live challenge per `(order, attempt)`. |
| **Assignment/custody-bound** | Bound to `riderPrincipalId`, `riderAssignmentId`, `riderAssignmentGeneration`, and checked against current order, custody and rider-slot revisions. A reassignment invalidates. |
| **Replay-resistant** | Single-use, consumed **atomically with the check**; regeneration invalidates superseded challenges; regeneration and submission are rate-limited; duplicate submissions are idempotent. |
| **Auditable** | Append-only reassessment (ADR-0009) unchanged; the verification outcome, safe references, assessor identity and revisions checked are recorded. Exception reviews carry reason, reference and deciding principal. |
| **Privacy-minimizing** | The raw challenge value never enters an event, payload, notification, log, crash report or audit record. Comparison is server-side. Photo/GPS capture is **not** made mandatory. |
| **Configurable without silently weakening** | A policy version may tune window, length, routes, rate limits and captured context. It may **not** make any insufficient signal sufficient, remove customer fulfilment, move verification to a client, disable single-use/binding/expiry, unaudit the exception path, or set a limit to unlimited — each needs a **superseding ADR**. |
| **Unreliable-network compatible** | Local capture permitted; **local satisfaction is not**. Absence stays `DeliveryProofAssessmentFacts.absent` — **no `pending` verdict was introduced**. Queued capture does not extend a challenge's life. |
| **Jurisdiction-neutral** | An explicit section states the ADR makes **no** compliance claim of any kind and forecloses no stricter requirement. |
| **Capture ≠ satisfaction** | Stated as the ADR's one-sentence core, and reinforced in the canonical definitions table. |

### The question ADR-0009 left open, answered

ADR-0009 recorded **POLICY-DEFINED / DEFERRED** for *"whether customer
participation is optional, mandatory, sufficient or a veto"*. ADR-0012 answers:
**MANDATORY and NOT SUFFICIENT**, and **not a veto that ends the order** —
non-participation yields no satisfaction and nothing else: no refusal, no fault,
no fee. `customer.delivery.confirm_proof` keeps its exact accepted meaning, and
**no `customerConfirmed` flag was added** — none exists.

### Insufficient alone, permanently

Rider photograph · GPS/location · timestamp · signature image without
authenticated binding · rider statement or "delivered" tap · cash collection ·
customer non-response · delivery-attempt completion · possession/custody
assertion. Each may be captured as supporting context; none substitutes for a
fulfilled challenge.

### Boundaries held separate

Cash collection neither satisfies proof nor is settled by it; a dispute does not
imply delivered; refusal and failure create no satisfaction; and satisfaction
triggers no remittance, settlement, reconciliation, fee, refund, compensation,
commission or fault finding. `CONSTRAINTS.md` invariants **7** and **11** stand
unchanged.

### Exception path — bounded, not created

An accessibility-safe ADMIN exception review must be separately authorized,
reason- and reference-bearing, audited, bound to the same resource and attempt,
append-only and **distinguishable afterwards**. **ADR-0012 does not create that
workflow and creates no permission for it**, consistent with ADR-0009's rule
that `executableProofAssessorKinds` is widened only deliberately.

---

## 3. Files changed — exactly eight

| # | File | Change |
|---|---|---|
| 1 | `docs/decisions/ADR-0012-delivery-proof-satisfaction-policy.md` | **NEW** — the decision |
| 2 | `AGENTS.md` | §11 ADR index only: ADR-0012 appended, *eleven* → *twelve* |
| 3 | `CONSTRAINTS.md` | invariant 13 only: decision reference + explicit **not discharged** status |
| 4 | `docs/contracts/delivery-proof-boundary.md` | stale *"policy undefined"* wording in the 0.11 box, §4, §7 and §8 |
| 5 | `docs/contracts/delivery-proof-assessment.md` | §13 deferred table: three rows re-stated |
| 6 | `docs/contracts/delivery-proof-dispute.md` | §1 status paragraph and four deferred-table rows |
| 7 | `docs/task-ledger/TASK_LEDGER.md` | one new task row, **O8** registered and resolved, five live summary rows re-tensed |
| 8 | `docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-completion-report.md` | **NEW** — this report |

**`SHARED_BLUEPRINT.md` was authorized but deliberately NOT changed.** It tracks
no proof-satisfaction decision or dependency — its only nearby sentence is the
generic ledger/invariant-7 line, which this decision does not touch. Editing it
would have been scope without justification.

**Not touched, and mechanically confirmed:** every Dart file, every test, every
`lib/` directory, `CONTRIBUTING.md`, every other ADR body, every other contract
document.

---

## 4. Semantic consistency sweep

Every occurrence of the brief's sweep terms was classified across the changed
files and the repository.

### Corrected — stale "policy undefined" claims

| Where | Was | Now |
|---|---|---|
| `delivery-proof-boundary.md` 0.11 box | *"invariant 13 is still undischarged"* (no mention of a policy decision) | still undischarged, **explicitly unchanged by ADR-0012**, which decides policy and implements none of it |
| `delivery-proof-boundary.md` §4 | *"Choosing a mechanism is a later bounded task's decision"* | decision **made at policy level**; the source sweep is explicitly unaffected because ADR-0012 adds no code |
| `delivery-proof-boundary.md` §7 | *"proof acceptance / satisfaction policy"* and *"whether customer participation is required"* both **DEFERRED** | both struck through and **DECIDED**, with executable form still DEFERRED; two genuinely-still-deferred items added (challenge parameters, exception permission) |
| `delivery-proof-boundary.md` §8 | *"What a policy requires is still undone"* | policy decided; **the executable contract is what is missing** |
| `delivery-proof-assessment.md` §13 | three rows **DEFERRED / POLICY-DEFINED** | **DECIDED**, each naming ADR-0012 and keeping *implementation DEFERRED* |
| `delivery-proof-dispute.md` §1 | *"The proof-satisfaction policy itself is still undefined"* | decided, **and explicitly still not discharged** |
| `delivery-proof-dispute.md` deferred table | four rows | re-stated the same way |
| `TASK_LEDGER.md` FND-003, FND-003B3, FND-003D rows and the two coverage-table rows | *"policy … remain outstanding / undefined / still undone"* | **DECIDED but not implemented**, each naming ADR-0012 |

### Verified accurate and deliberately left unchanged

| Claim | Verification |
|---|---|
| `OrderState.delivered`, `DeliveryAttemptState.delivered`, `CustodyHolderKind.customer`, rider `AssignmentState.completed` **unreachable** | no evaluator, transition, command or event added; every such statement in the contract documents still stands |
| `delivery-proof-boundary.md` §5 — **Permission count: 39**, the single canonical claim | untouched; its derived guard passes |
| `dispute.resolve_delivery_proof` enumerated and always refused `resolutionPolicyDeferred` | untouched |
| Contract-version table rows for 0.9 and 0.11 — *"No … proof-satisfaction policy … yet"* | **slice-scoped and still true**: neither version added a policy **to the contract**, and ADR-0012 adds nothing to the contract either |
| `O7` row | zero diff lines; still **OUTSTANDING** |
| Retention / visibility / deletion / legal-hold, dispute outcome, remittance and settlement | still DEFERRED, untouched |

### Flagged, not silently ignored

`TASK_LEDGER.md` lines ~277–284, ~346–349, ~391–393, ~443–445 and ~720–729 are
**pre-existing dated per-slice narratives** (*"FND-003D2A — DONE (2026-09-10)"*,
*"FND-003D2B — DONE (2026-09-11)"*, …) that describe what each slice meant **when
it landed**, and they still say the satisfaction policy is undone.

They were **left unchanged, deliberately**, on the repository's own established
precedent: when **O6** was resolved by ADR-0011 on 2026-09-11, these same
paragraphs were left saying *"blocked on O6"* — line 284 still does — and the
three accepted bookkeeping tasks that followed did not re-tense them either.
Treating them as historical slice records is the consistent reading; re-tensing
them now would both contradict that precedent and widen this task's scope.
**Recorded here so a reviewer sees a decision rather than an oversight.** If the
project would rather they carried explicit time-scope markers, that is a bounded
bookkeeping task of its own and is **not** a debt this decision created.

### New-term sweep

- **`ADR-0012`** — appears in the ADR itself, the `AGENTS.md` index, `CONSTRAINTS.md`
  invariant 13, all three delivery-proof contract documents, the ledger task row,
  the O8 row and five ledger summary rows. Every reference is a relative link
  that resolves.
- **`O8`** — appears only in the ADR front matter and body, the ledger O8 row, the
  ledger task row and this report. It did not exist anywhere before this task.
- **`proof satisfaction unavailable` / `successful delivery`** — every occurrence
  in the changed files states that successful delivery remains **not executable**.
  No changed sentence claims otherwise.

---

## 5. Validation

```text
$ git status --short          # before edits
(empty — clean)

$ git diff --check
(clean, exit 0)
```

**ADR inventory, before → after**

```text
before : ADR-0001 … ADR-0011   (eleven files; ADR-0012 absent; no later ADR)
after  : ADR-0001 … ADR-0012   (twelve files)
```

**Index vs directory — exact comparison**

```text
$ diff <(AGENTS.md §11 ids, sorted unique) <(docs/decisions/ ids, sorted unique)
(empty) — INDEX MATCHES DIRECTORY EXACTLY

each id appears exactly once in the index: ADR-0001 … ADR-0012, count 1 each
```

**Live probe — not grepped**

```text
ContractVersion.current        = 0.11
Permission.values.length       = 39
permissionMatrix.length        = 39
matrix missing keys            = 0
```

**Executable surface**

```text
$ git diff --name-only -- '*.dart'        → (empty)
$ git diff --name-only -- '*/lib/*'       → (empty)
$ git diff --name-only -- 'packages/*/test/*' → (empty)
```

No enum value, evaluator, transition, command, event, permission or denial was
added, removed or re-meaninged, so **no executable transition becomes
reachable**.

**Repository gate**

```text
$ ./tools/run_checks.sh
… LAYERING CHECK: PASS …
ALL CHECKS PASSED
```

`packages/contracts` passes **1162** tests, unchanged — including
`delivery_proof_boundary_doc_consistency_test.dart`, which guards the very
document this task edited, and `delivery_proof_test.dart`, whose source sweep
would fail if any proof-mechanism term had reached the code.

---

## 6. Deferred implementation boundaries

**This task decided policy. It implemented nothing.** Explicitly still to do,
each in its own separately reviewed slice:

- the **executable challenge lifecycle** — issuance, storage, consumption, its
  types and events;
- the **verifier's evaluation** of a fulfilment against the policy;
- the **successful-delivery transaction** — order `in_delivery → delivered`,
  custody `rider → customer`, rider assignment completion and **B3-C2**, with
  fresh authorization, idempotency, atomic dedupe and outbox;
- the **exception-review workflow and its permission**;
- concrete challenge length, alphabet, window and rate-limit values;
- evidence retention, visibility, deletion and legal hold;
- dispute resolution, and any fee, refund, fault, compensation or liability;
- remittance, settlement, reconciliation, commission payout and worker pay.

**`CONSTRAINTS.md` invariant 13 is NOT discharged**, and the invariant text now
says so in terms: both halves are defined, no executable proof satisfaction
exists, delivery confirmation still may not be coded, and the implementing slice
**must conform to ADR-0012**.

**No later roadmap task was started.**

---

## 7. What this report does not claim

**Nothing here is self-certified.** This task ran no independent review of its
own work; acceptance is for a separate, fresh, read-only review session. This
report records what was done and what was verified, not that it was accepted.

**GitHub CI: NOT RUN / NONE** — no `.github` directory exists, so no hosted
workflow could run. **O7 remains OUTSTANDING**, untouched: verifying that CI is
absent is not configuring it, and the local gate is not CI.

---

## 8. Confirmation — no push occurred

One normal commit was created on
`fnd/FND-003D3-proof-satisfaction-policy-001`. **Nothing was pushed.** No amend,
rebase, merge, squash, cherry-pick, reset or force of any kind; no tag or
release; no deployment; no Firebase, backend or live-data access; no repository
setting, CI or branch-protection change. `origin/main` is still
`81c623ec1537b99a86e57b6572f9d6cce3a06c3b`.

The chain offered for one fresh independent read-only review before publication:

```text
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
→ <this commit>
```
