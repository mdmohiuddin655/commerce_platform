# docs/contracts

Owner: **FND-003**. Empty by design at FND-001.

FND-003 must produce, in this directory, the artefacts that every role task
then codes against:

1. **Schemas** for order, assignment, custody, attempt, return, payment,
   ledger entry, command envelope and event envelope.
2. **Exhaustive transition tables** — every allowed edge with actor,
   precondition, inventory effect, financial effect and emitted event. The
   table in `SHARED_BLUEPRINT.md` lists states; it is not an executable state
   machine and is not sufficient.
3. **Permissions** per actor per command.
4. **Policies** — cancellation fee policy versioning, refusal liability,
   damaged-goods disposition, commission ownership before release.
5. **Money and custody invariants** — integer minor units, balanced postings,
   reversal-only corrections, one current custodian, per-handoff records.
6. **Proof and dispute workflow** — customer OTP/proof and the fallback path,
   defined *before* delivery confirmation is coded.
7. **Compatibility policy** — how an older app reads a newer schema, mapped to
   `ContractVersion` in `packages/contracts`.

Until these exist, no role feature may guess a field name, a status string or a
fee rule.
