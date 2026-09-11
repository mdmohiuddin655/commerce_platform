# Cash and payments — COD collection and the journal (FND-003C1)

**Contract 0.11. Additive.** Shared, pure Dart, in `packages/contracts`. No
Flutter, no Firebase, no serialization, no persistence.

The first executable slice of **FND-003C**, and deliberately the smallest one
that is safe: a rider recording cash actually received, and the balanced journal
entry that records it.

> **Successful delivery is still not executable.** Collecting cash is **not**
> delivering. `CONSTRAINTS.md` invariant 13 remains **not discharged**.

The delegated **O6** decision this rests on is **ADR-0011**.

## 1. What is executable

```text
rider reports cash actually received
  payment   due | partially_collected  ->  partially_collected | collected
  journal   ONE balanced entry for exactly the amount received
  order, custody, attempt, assignment, reservation, inventory   ALL UNCHANGED
```

One command, `cash.report_cod_collection`, under the **accepted, unchanged**
`rider.cash.report_collection` permission. **No permission was added** —
`Permission.values` and `permissionMatrix` stay at **39**.

## 2. The distinctions this contract exists to keep

```text
delivered   !=  collected      nothing here marks a delivery successful
collected   !=  remitted       the cash is in a rider's hands, not the platform's
remitted    !=  reconciled     nobody has agreed the books match
custody     !=  ownership      a rider holds the platform's cash and owns none of it
commission  !=  customer charge   it is an allocation out of merchandise proceeds
absence     !=  zero           a missing fee policy is missing, not free
```

## 3. Money

Every value is `cp_core.Money`: **integer minor units** with an **explicit
ISO-4217 currency**. There is no `double` constructor and no `double` accessor.

**v1 accepts BDT only** (`CurrencyPolicy.acceptedInV1`). A non-BDT snapshot,
payment or entry **fails closed** — there is **no FX**, no rate source and no
rounding policy. `Money` throws on cross-currency arithmetic; this contract
refuses *earlier*, with a denial, so a mixed-currency read never reaches an
arithmetic site.

Widening the accepted set is an **ADR plus contract migration**, never an edit:
history written under a one-currency policy cannot be reinterpreted by widening
a set.

## 4. The order financial snapshot

Immutable, quoted at checkout, bound to the order:

```text
customerQuotedTotal = merchandiseSubtotal + deliveryCharge
codAmountDue        = customerQuotedTotal          (normal path, v1)
platformCommission  <= merchandiseSubtotal         (ALLOCATION, not a charge)
```

Every amount **and both policy references** are required and non-nullable, so
**a snapshot with a missing fee or commission policy cannot be constructed**.
That is the point: the dangerous reading is *"no commission recorded"* meaning
*"commission is zero"*. A published zero-value promotion is representable —
`Money.zero` under a real `FinancialPolicyRef` — and is a different fact from
silence.

`validateOrderFinancialSnapshot` rejects: a malformed order id, a malformed
policy reference, mixed currency, a non-accepted currency, any negative amount,
a non-positive order total, and commission exceeding the merchandise it is
allocated from. It **never repairs, clamps or converts** anything.

## 5. Payment state

`due` → `partiallyCollected` → `collected`, plus `disputed`.

**Derived from trusted facts, never supplied.** There is no `setPaymentState`,
and no request carries a target state: a state is what the recorded collections
add up to, checked by `validatePaymentAggregate` against the canonical amount
due.

**`disputed` is enumerated and not producible here.** No operation writes it,
because deciding a payment is disputed means deciding who is right. It exists
because the blueprint names it, a later slice will write it, and **nonpayment
must stay representable** — a refusal where the customer pays nothing is a real
outcome, not a reason to fabricate a collection.

A stored `disputed` payment is **refused for collection**, not treated as
corruption: unlike `OrderState.delivered` this is a state the platform genuinely
expects to reach, so failing closed is the fail-safe reading.

## 6. The collection operation

`evaluateReportCodCollection` requires an unforgeable FND-003A
`AuthorizationGrant`, checked by `checkCodCollectionAuthorization` against the
actor, the operation's permission and the resource — with the expected resource
taken from the **read-set**, never from `grant.resourceId` (the tautology
FND-003D2B-FIX-003 removed).

It then requires, and fails closed without, **all** of:

| Read | Requirement |
|---|---|
| resource context | well-formed |
| actor | a **human** principal; a worker cannot witness cash changing hands |
| timestamp | **UTC**, never converted |
| journal ids | canonical opaque entry id and business reference |
| financial snapshot | bound to the resource, canonical, BDT |
| payment | bound, canonical, **CAS on `paymentRevision`**, not disputed, collectable |
| order | bound, canonical, `in_delivery`, **CAS**, reservation `committed` |
| attempt | bound, canonical, **CAS**, state **`out_for_delivery`** |
| custody | bound, canonical, **CAS**, with a rider |
| rider assignment | bound, canonical, **CAS**, accepted, actor is the assignee, id **and** generation match |
| custody ↔ attempt | custody names that **exact** accepted rider attempt |
| amount | positive, BDT, matching the snapshot, **≤ outstanding** |

Cash is collected at the door, so the attempt must be **out for delivery** —
not `pending` (the rider has not set out) and **not `refused` or `failed`**,
where any money question is a refusal-fee or dispute matter this slice does not
decide.

**Scalar equality is not identity.** Every independently supplied read is bound
to the same canonical resource, and custody must name the exact assignment
attempt — otherwise cash carried under attempt A could be recorded as though
attempt B collected it.

## 7. The journal

Every entry has **one currency**, a **unique business reference** and signed
postings summing to **exactly zero**. `validateCashJournalEntry` rejects:
malformed references, a non-UTC timestamp, fewer than two postings, mixed
currency, a non-accepted currency, a zero posting, a duplicate account, an
unbalanced total, and an invalid or self-referencing reversal.

### Sign convention, fixed once

Both accounts are assets; a collection converts one into the other.

```text
customerCodReceivable   -A      the customer owes A less
riderCashInTransit      +A      the rider holds A more
                        ────
                          0     balanced
```

Pinned by tests. Changing it later would silently reinterpret every stored
posting.

### Accounts are closed and server-chosen

Only `customerCodReceivable` and `riderCashInTransit` exist — the accounts an
implemented operation needs. Settlement, payout, refund and commission accounts
are **absent**: declaring them would invite posting to them before any policy
says what they mean. A caller-selected account string would be a balance-edit
primitive in disguise.

### Corrections are reversals

There is **no edit and no delete**, and **no public balance setter**. A
correction is a **new entry** naming the one it reverses, so history only grows
and a balance is always the sum of postings.

## 8. What a collection cannot do

The transition type has **no field** for an order-state change, inventory
effect, custody movement, rider completion, assignment change, proof
assessment, remittance or settlement — so it cannot produce one by mistake.
`changesOrder`, `changesCustody` and `completesRider` are all permanently
false, and are tested.

Still unreachable and untouched: `OrderState.delivered`,
`CustodyHolderKind.customer`, rider `AssignmentState.completed` (**B3-C2
FUTURE**), the proof-satisfaction policy, dispute resolution, refusal-fee
collection, refunds, compensation, commission payout, worker pay, reconciliation
and FX.

## 9. Events

Three privacy-minimal ids: `cash.cod_partially_collected`,
`cash.cod_collected`, `cash.journal_entry_recorded`. Payloads carry routing and
money metadata only — resource id, payment revision, journal business
reference, amount, currency, server UTC.

**No address, phone number, order contents, proof material, rider location or
secret.** An event is **never authorization** and **never a journal source of
truth**: the journal entry is, and a client re-reads authorized server state.

## 10. Backend criteria — all NOT RUN

Pure Dart tests are **contract** evidence, not persistence evidence. No backend
exists; FND-004 owns the API shell.

| ID | Criterion |
|---|---|
| **CJ1** | Two concurrent collections using the same `expectedPaymentRevision` cannot both commit |
| **CJ2** | Authoritative transaction read-set: payment, snapshot, order, attempt, custody and rider slot read consistently |
| **CJ3** | Payment write + journal entry + dedupe result + outbox event commit in **one** atomic transaction |
| **CJ4** | Journal **business reference is unique**; a replay stores no second entry |
| **CJ5** | Identical command id + identical payload replays the stored result without a new journal entry |
| **CJ6** | Same command id + **changed** payload is rejected as idempotency-key reuse |
| **CJ7** | Fresh authorization before new execution **and** before replay |
| **CJ8** | No push or other non-retryable side effect inside a retryable transaction |
| **CJ9** | Cross-resource isolation: a collection cannot touch another order's payment or journal |
| **CJ10** | Current membership and scope re-read at execution time |
| **CJ11** | Balances are computed from postings only; no stored mutable balance exists |
| **CJ12** | A reversal references an existing entry and is never an in-place edit |

**Migration: N/A — contract-only; no persistence exists yet. Firestore rules:
N/A — contract-only; no persistence exists yet. Indexes: N/A — contract-only;
no persistence exists yet. Deployment: NOT RUN. GitHub CI: NONE.**
