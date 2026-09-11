# ADR-0011 — O6 resolved: BDT-only v1, quoted customer price, commission as an allocation, and rider cash as custody

- **Status:** Accepted
- **Date:** 2026-09-11
- **Task:** FND-003C1, under the ADMIN standing delegation for **owner action O6**
- **Contract:** 0.10 → 0.11 (additive)
- **Resolves:** **O6** — currency, fee policy and commission ownership
- **Supersedes:** nothing. **Extends:**
  [ADR-0010](ADR-0010-direct-rider-to-shop-return-route.md)

## Context

Every slice since FND-003B1 has carried the same placeholder:
`FinancialClassification.deferredToFinancialSlice` — *unknown, never zero* —
because **O6 was unresolved**. Order cancellation, refusal, the fallback
dispute and the whole return lifecycle all stop at the same sentence: *"whether
money moves, and whose it is, is not decided anywhere in this repository."*

That is no longer a safe place to stand. `CONSTRAINTS.md` and the blueprint
both require integer minor units, balanced postings, a unique business
reference and reversal-only correction — and none of that can be built while
the four questions underneath it are open:

1. **Which currency**, and what happens to any other one?
2. **What does the customer owe**, and who owns each part of it?
3. **What does a refusal cost**, by default?
4. **Whose money is the cash in a rider's hand?**

Getting any of these wrong is expensive in a specific way: the answer gets
baked into stored ledger history, and a ledger cannot be edited — only reversed.

## Decision 1 — BDT only in v1, with the currency still explicit on every value

The initial marketplace commercial currency is **BDT**, and the v1 financial
policy accepts **BDT only**. A non-BDT order snapshot, payment or journal entry
**fails closed**; there is no conversion.

**The currency stays explicit on every amount.** `cp_core.Money` already
carries an ISO-4217 code alongside integer minor units, and this decision does
**not** replace it with a bare integer "because everything is taka anyway".

### Why not collapse to a bare integer

Because the collapse is irreversible in the data. Once amounts are stored
without a currency, adding a second one means guessing what every historical
row meant — and the guess would be applied to money. Keeping the code costs a
field and buys the ability to widen `CurrencyPolicy.acceptedInV1` later under
its own ADR and migration.

### Why there is no FX

No rate source, no rounding policy and no as-of-when rule exists. `Money`
already throws on cross-currency arithmetic; this contract refuses **earlier**,
with a denial, so a mixed-currency read never reaches an arithmetic site at
all. Inventing a conversion would be inventing a price.

## Decision 2 — the customer price is a quoted snapshot; commission is an allocation, not a charge

```text
customerQuotedTotal = merchandiseSubtotal + deliveryCharge
codAmountDue        = customerQuotedTotal            (normal path, v1)
platformCommission  <= merchandiseSubtotal           (ALLOCATION)
```

Merchandise subtotal, delivery charge and any other customer-facing charge are
**immutable quoted snapshots** taken at checkout, each with a reference to the
published policy version that produced it.

**Platform commission is never added on top of the customer price.** It is a
settlement allocation out of merchandise proceeds the shop economically owns.

### Why this one matters most

Adding commission to `customerQuotedTotal` would silently overcharge every
customer by the platform's own margin, and it would look like arithmetic rather
than a pricing decision. The failure would be invisible in code review and
obvious only on a receipt. A regression test pins it, and a negative control
proves the test catches the inflation.

### Absence is never zero

Every amount and both policy references are **required and non-nullable** on
`OrderFinancialSnapshot`. A missing commission policy is therefore impossible
to construct — because the dangerous reading is a later implementer treating
*"no commission recorded"* as *"commission is zero"*. An explicitly published
zero-value promotion is representable: `Money.zero` **under a real policy
reference**. Silence and zero are different facts, and only one of them is
auditable.

## Decision 3 — refusal default, and the fault cases that must not be defaulted

For a **voluntary customer refusal after dispatch**, the default customer
obligation is the order's **immutable quoted delivery charge**, under the
order's versioned refusal-fee policy.

Bounded by three rules that matter more than the default:

- **Nonpayment stays representable.** A refusal where the customer pays nothing
  is a real outcome — recorded as outstanding or disputed. **Never fabricate a
  collection to let a refusal or return proceed.**
- **Delivery failure alone creates no customer fee.** Nobody home is not a
  purchase.
- **Fault cases are not customer-paid by default.** Wrong, damaged or
  materially incorrect goods — anything potentially seller, platform or
  fulfilment fault — is classified **unresolved/disputed** until a trusted
  resolution decides liability. Not silently charged, and **not silently
  waived** either: waiving is also a decision, and it is not this ADR's.

**FND-003C1 records this boundary and implements none of it.** No refusal-fee
collection and no dispute resolution exists here.

## Decision 4 — who owns what

| Money | Economic owner | Notes |
|---|---|---|
| Merchandise proceeds | **Shop** | net of the snapshotted platform commission |
| Platform commission | **Platform** | explicit in an immutable snapshot; no hard-coded rate |
| Customer delivery charge | **Platform** | a service-charge receivable |
| Cash in a rider's hand | **Platform** | the rider is **custodian**, not owner |
| Rider/picker/agent pay | — | a **separate payable** under a future versioned compensation policy |

**Worker compensation is not inferred from the delivery charge or the
commission.** A rider carrying 60 taka of delivery charge has not earned 60
taka, and a contract that conflated the two would owe workers whatever the
pricing team happened to choose.

**No commission percentage is hard-coded.** The rate or amount lives in an
immutable policy snapshot, so a later rate change cannot retroactively
reinterpret a completed order.

## Decision 5 — cash custody is not ownership, and the four states are distinct

```text
delivered  !=  collected  !=  remitted  !=  reconciled
```

A rider who collects COD becomes **custodian of the platform's cash for
reconciliation**. Recording a collection and settling it are **separate
lifecycles**, and FND-003C1 implements only the first.

This is the same distinction FND-003B3A drew between assignment and custody —
*agreeing to do the work* is not *holding the goods* — applied to money.

## Decision 6 — the journal

- Values are **integer minor-unit `Money`**.
- Every entry has **one currency**, a **unique business reference** and signed
  postings summing to **exactly zero**.
- **No mixed-currency entry.**
- **No historical edit or delete.** Corrections are **new reversal entries**
  referencing the original.
- **No public "set balance" primitive exists.** Balances are derived from
  postings.
- Accounts are a **closed, server-chosen enum**. A caller-selected account
  string is a balance-edit primitive in disguise: whoever picks the account
  picks where the money lands.

Only accounts an implemented operation needs exist —
`customerCodReceivable` and `riderCashInTransit`. Settlement, payout, refund
and commission accounts are **absent**, because declaring them would invite a
later slice to post to them before any policy says what they mean.

### The sign convention, fixed once

A posting's amount is **the change to that account's balance**. Both accounts
are assets, so collecting COD converts one into the other:

```text
customerCodReceivable   -A      the customer owes A less
riderCashInTransit      +A      the rider holds A more
                        ────
                          0     balanced
```

Pinned by tests. Changing it later would silently reinterpret every stored
posting, so it is a contract, not a style choice.

## Consequences

- FND-003C moves from **BLOCKED on O6** to **PARTIAL**: C1 is executable, and
  the rest of the money slice now has decided ground to build on.
- Refusal, cancellation, dispute and return slices can stop saying *"unknown"*
  about ownership — though they still say it about **outcomes**, which remain
  undecided.
- **Successful delivery is still not executable.** The proof-satisfaction
  policy is untouched and `CONSTRAINTS.md` invariant 13 is **not discharged**.
  Collecting cash is not delivering.
- Adding a second currency, a partial-return model, a compensation policy or a
  settlement lifecycle each needs its **own ADR and contract migration**.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Drop the currency code; everything is BDT | Irreversible in stored data — a second currency would require guessing what historical rows meant |
| Add commission to the customer total | Silently overcharges every customer by the platform margin; looks like arithmetic, not a pricing decision |
| Treat a missing fee policy as zero | Makes silence indistinguishable from a published free-delivery promotion, and the safe-looking default is the expensive one |
| Hard-code a commission percentage | A later rate change would retroactively reinterpret completed orders |
| Let the rider own collected cash | Confuses custody with ownership and turns a reconciliation shortfall into a dispute about wages |
| Infer rider pay from the delivery charge | Ties compensation to a pricing lever nobody chose for that purpose |
| Mutable balances with an audit log beside them | The log and the balance drift; a derived balance cannot |
| Allow FX now | No rate source, rounding rule or as-of-when rule exists; inventing one invents a price |
| Charge the refusal fee for damaged/wrong goods | Charges the customer for the platform's or seller's fault before anyone has decided fault |
