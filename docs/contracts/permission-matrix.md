# Permission matrix

**Contract version 0.2** (FND-003A). This table is **generated from
`packages/contracts/lib/src/permission_matrix.dart`** — the single source of
truth that all five apps and the backend consume. Regenerate with:

```bash
cd packages/contracts && dart run tool/print_permission_matrix.dart
```

No application keeps its own role table. Code asks *"does this actor hold
`agent.order.accept`"*, never *"is this actor an agent"*: role checks scattered
across five apps drift apart, a permission vocabulary does not.

## Reading the table

- **Role** — the only role eligible. Every permission belongs to exactly one
  role family, asserted by a test.
- **Membership** — statuses that may exercise it. Currently `active` for every
  permission; see the wind-down note below.
- **Scope** — required relationships to the resource, joined by `+` when a
  rule needs more than one. **All listed requirements must hold.** See
  `docs/contracts/identity-membership-and-scope.md`.
- **Reason** — a non-blank, stored justification must accompany the command.
- **Approval** — dual control: a **different** principal must have approved.

| Permission id | Role | Membership | Scope | Reason | Approval | Restriction |
|---|---|---|---|---|---|---|
| `customer.checkout.submit` | customer | active | `ownResource` | no | no | Submits an intent only. Prices, stock and fees are resolved server-side; a client-quoted amount is never trusted. |
| `customer.order.view_own` | customer | active | `ownResource` | no | no | Own orders only. No listing of other customers exists. |
| `customer.order.request_cancellation` | customer | active | `ownResource` | **yes** | no | Requests only. The server decides from the current stage whether cancellation is permitted; the client never cancels. |
| `customer.delivery.confirm_proof` | customer | active | `ownResource` | no | no | Participation in proof only. Confirming does not settle cash and does not close a dispute. |
| `customer.dispute.raise` | customer | active | `ownResource` | **yes** | no | — |
| `agent.order.view_shop` | agent | active | `ownShop` | no | no | Only shops in the membership. Never a platform-wide feed. |
| `agent.order.accept` | agent | active | `ownShop` | no | no | — |
| `agent.order.reject` | agent | active | `ownShop` | **yes** | no | — |
| `agent.fulfillment.record_progress` | agent | active | `ownShop` | no | no | Records shop-side progress. Never writes trusted stock, order status or cash fields directly. |
| `agent.assignment.offer_picker` | agent | active | `ownShop` | no | no | Offers work. An offer is not an assignment and never implies custody. |
| `agent.assignment.offer_rider` | agent | active | `ownShop` | no | no | Offers work only, within the agent's own shops. |
| `agent.assignment.revoke_picker` | agent | active | `ownShop` | **yes** | no | Controlled reassignment only: withdraws one accepted picker assignment so the work can be re-offered as a NEW attempt. It cannot replace an assignee, cannot overwrite assignment state, and cannot override custody safety — revocation is refused unless the backend proves the worker never took custody. |
| `picker.assignment.view_assigned` | picker | active | `assignedResource` | no | no | Only what the active assignment needs. Not a customer directory and not a browsable order list. |
| `picker.assignment.accept` | picker | active | `ownRegion` + `offeredResource` | no | no | The offer must have been addressed to this picker: a same-region picker cannot accept another picker's offer. Does NOT require an already accepted assignment. Whether the offer is still live is lifecycle state (FND-003B), not authorization. |
| `picker.assignment.decline` | picker | active | `ownRegion` + `offeredResource` | no | no | Same target isolation as accepting: only the picker the offer was addressed to may decline it. |
| `picker.custody.record_pickup` | picker | active | `assignedResource` | no | no | — |
| `picker.custody.record_handoff` | picker | active | `assignedResource` | no | no | Records a custody handoff. Custody changes only on a proven handoff, never on a notification or an elapsed timer. |
| `rider.assignment.view_assigned` | rider | active | `assignedResource` | no | no | Only what the active assignment needs, including the delivery address for that assignment alone. |
| `rider.assignment.accept` | rider | active | `ownRegion` + `offeredResource` | no | no | The offer must have been addressed to this rider. Does NOT require an already accepted assignment. |
| `rider.assignment.decline` | rider | active | `ownRegion` + `offeredResource` | no | no | Same target isolation as accepting. |
| `rider.custody.record_receipt` | rider | active | `assignedResource` | no | no | — |
| `rider.delivery.record_attempt` | rider | active | `assignedResource` | no | no | — |
| `rider.delivery.submit_proof` | rider | active | `assignedResource` | no | no | — |
| `rider.cash.report_collection` | rider | active | `assignedResource` | no | no | Reports what was actually received. Reporting is not settlement, and it never writes a balance: the server derives postings. Delivered is not equivalent to rider cash settled. |
| `rider.cash.submit_remittance` | rider | active | `assignedResource` | no | no | Submits a remittance for a receiving party to confirm. The rider never edits settlement history or their own balance. |
| `admin.worker.approve` | admin | active | `ownRegion` | **yes** | **yes** | Dual control: the approver must be a different principal from the requester. |
| `admin.worker.suspend` | admin | active | `ownRegion` | **yes** | no | Audited. Stops new work; controlled resolution of work already in custody is owned by the lifecycle slice. |
| `admin.worker.reinstate` | admin | active | `ownRegion` | **yes** | **yes** | — |
| `admin.shop.moderate` | admin | active | `ownRegion` | **yes** | no | — |
| `admin.zone.administer` | admin | active | `ownRegion` | **yes** | no | — |
| `admin.policy.publish_version` | admin | active | `none` | **yes** | **yes** | Publishes a new immutable policy version. Never edits a published one: orders keep the policy version they were quoted under. |
| `admin.support.view_order` | admin | active | `ownRegion` | **yes** | no | Read-only, region-scoped, reason-bearing and logged. Confers no mutation authority of any kind. |
| `admin.dispute.administer` | admin | active | `ownRegion` | **yes** | no | — |
| `admin.return.administer` | admin | active | `ownRegion` | **yes** | no | Stock cannot become available again until shop receipt and inspection; this permission does not shortcut that. |
| `admin.cash.record_reconciliation` | admin | active | `ownRegion` | **yes** | **yes** | Records a reconciliation as new balanced postings under dual control. It is NOT a balance edit and NOT a journal edit: corrections are reversals, history is never rewritten. |
| `admin.release.view_health` | admin | active | `none` | no | no | Aggregate operational metrics only. No personal data. |
## Offer scope versus assignment scope

Two distinct relationships, and conflating them breaks authorization in
opposite directions.

| Requirement | Means | Used for |
|---|---|---|
| `offeredResource` | the work was **addressed to** this actor | accepting and declining an offer |
| `assignedResource` | this actor holds an **accepted** assignment | every post-acceptance action |

- Accepting an offer must **not** require an accepted assignment — that would
  be circular. `picker.assignment.accept`, `picker.assignment.decline`,
  `rider.assignment.accept` and `rider.assignment.decline` therefore require
  `offeredResource + ownRegion`, never `assignedResource`.
- An offer must **not** open post-acceptance work. A picker who was merely
  offered a job cannot record a pickup.
- Region alone is **not** sufficient for accept/decline. Before FND-003A-FIX-001
  it was, which let any active worker in the same region accept someone else's
  offer.

Authorization establishes *"this offer belongs to this actor and is inside
allowed scope"*. Whether the offer is **still live** — not expired, declined or
superseded — is assignment lifecycle state owned by **FND-003B**.

## Capabilities that must never exist

Encoded as data in `ProhibitedCapability.all` and asserted by a test, so
adding one is a build failure rather than a code review someone was tired
during.

| Forbidden | Why |
|---|---|
| Arbitrary status overwrite | A status is the *result* of a permitted transition, never an input. A patch-to-status permission would let any holder skip every precondition, inventory effect and financial effect. |
| Arbitrary balance edit | Balances are derived from balanced postings. Editing one directly breaks the invariant that the ledger explains the balance. |
| Historical journal edit | Corrections are reversals, not edits. An editable history is not an audit trail. |
| Unaudited impersonation | Acting as another principal without an audited, reason-bearing, approved record destroys attribution for every downstream event. |

**Admin does not mean unrestricted.** `admin.support.view_order` is a
region-scoped, reason-bearing, logged **read**. It confers no mutation
authority of any kind, and no admin permission grants direct financial
mutation: `admin.cash.record_reconciliation` records *new balanced postings*
under dual control — it is not a balance edit and not a journal edit.

## Explicit denials, all tested

| Attempt | Deny reason |
|---|---|
| Customer acts on another customer's order | `resourceOwnerMismatch` |
| Agent acts for a shop outside their membership | `shopMismatch` |
| Agent with an empty shop set acts on any shop | `shopMismatch` (empty means none, never all) |
| Picker uses a rider-only permission | `roleNotEligible` |
| Rider uses an agent-only permission | `roleNotEligible` |
| Customer uses an admin permission | `roleNotEligible` |
| Suspended or revoked worker starts new work | `membershipNotActive` |
| Pending worker acts | `membershipNotActive` |
| Worker acts outside their region | `regionMismatch` |
| Rider acts without an accepted assignment | `assignmentMismatch` |
| Rider who was only *offered* work performs a post-acceptance action | `assignmentMismatch` |
| A same-region worker accepts or declines **another worker's** offer | `offerMismatch` |
| A worker holding an assignment but no offer tries to accept | `offerMismatch` |
| Approval names a different requester, permission or resource | `approvalMismatch` |
| Privileged action without a reason | `reasonRequired` |
| Dual-control action with no approval at all | `approvalRequired` |
| Dual-control action self-approved | `approvalMismatch` |
| System worker borrows a human role permission | `systemPrincipalNotEligible` |
| Client asserts a role or actor id in the command payload | ignored entirely — the evaluator reads no payload |
| Membership record naming a different principal | `membershipMissing` |

## Wind-down permissions do not exist yet

Every rule accepts `active` membership only. Whether a suspended worker may
**finish** something already in their custody is a controlled-resolution
question owned by the **lifecycle slice**, not decided here.
`PermissionRule.acceptableStatuses` exists so that slice can add a narrow
wind-down permission accepting `suspended` **without loosening anything else**.
A test asserts the current default, so adding one is deliberate and visible.

## Not defined by this task

Lifecycle transitions, inventory effects, payment/COD, cash journal, fees,
refusal policy, commissions and settlement. This table says **who may ask**;
what the system then does is a later slice.
