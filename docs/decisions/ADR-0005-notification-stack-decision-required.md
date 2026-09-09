# ADR-0005 — Notification stack: DECISION REQUIRED

- **Status:** **Proposed — blocked on an owner decision.** Not accepted.
- **Date:** 2026-09-09
- **Task:** FND-002A
- **Contract baseline:** SHARED-BASELINE-v1.0
- **Evidence:** `docs/platform-matrix/FND-002A-capability-evidence.md`

## Context

`SHARED_BLUEPRINT.md` lists a **"Mandatory FCM/Awesome coexistence spike"** and
treats `firebase_messaging` + `awesome_notifications` as a pairing to be
validated. FND-002A rechecked both packages against current upstream sources on
2026-09-09.

The finding is stronger than the blueprint anticipated. The pairing is not
merely unproven — **the vendor of `awesome_notifications` explicitly directs
users away from it.**

- `awesome_notifications` 0.12.1: *"The support for `firebase_messaging` plugin
  is now deprecated. You need to use the Awesome's FCM add-on plugin…"* and
  *"The `awesome_notifications` plugin is incompatible with
  `flutter_local_notifications` or any other notification plugin. These plugins
  may conflict with each other when trying to acquire global notification
  resources."*
- `awesome_notifications_fcm` 0.12.1: users **"MUST not use
  `firebase_messaging` with `awesome_notifications_fcm`."**

A local probe resolved `firebase_messaging` together with both Awesome
packages **successfully, exit 0**. That is a trap, not a green light: pub
cannot see the native-layer conflict (Android messaging-service registration,
iOS `UNUserNotificationCenter` delegate ownership). Resolution success is
recorded as evidence of *nothing* on this question.

## The two coherent stacks

They are mutually exclusive by vendor instruction. There is no supported third
option that combines them.

### Path A — Firebase Messaging + a local-display plugin

`firebase_messaging` 16.6.0 (BSD-3-Clause) + `flutter_local_notifications`
22.3.0 (BSD-3-Clause).

- Transport platforms: Android, iOS, macOS, **web**. No Windows.
- Local display platforms: Android, iOS, Linux, macOS, Web, **Windows**.
- Coexistence is **documented as supported**: the local-notifications README
  states the earlier `firebase_messaging` conflict "has been resolved since
  version 6.0.13".
- Needed because Firebase documents that foreground messages "won't display a
  visible notification by default, on both Android and iOS".
- Both licenses are permissive and verified.

### Path B — Awesome Notifications + its FCM add-on

`awesome_notifications` 0.12.1 (Apache-2.0) + `awesome_notifications_fcm`
0.12.1 (**license not stated on the package page — unresolved**).

- `awesome_notifications_fcm` platforms: **Android and iOS only**.
- Consequence: **web loses its push transport.** The blueprint's web
  notification row assumes one exists.
- Richer local notification features (actions, layouts, scheduling) in one
  vendor's model.
- Single-vendor ownership of the notification surface removes the class of
  conflict Path A has to manage, at the cost of narrower platform coverage and
  a smaller ecosystem (≈6.4k weekly downloads vs the official FlutterFire
  package).

## Why this is not decided here

Choosing between them is a **product and risk decision**, not a coding
preference:

1. **Is web push required at launch?** If yes, Path B cannot deliver it and the
   question is effectively settled. If web push is deferrable, Path B stays
   viable. Only the owner knows this.
2. **Unresolved license.** `awesome_notifications_fcm`'s license is not stated
   on its package page. Adding a dependency of unknown license is not
   acceptable, so Path B cannot even be trialled until that is resolved.
3. **Neither path has device evidence.** No physical Android or iOS device is
   available, so foreground/background/terminated behaviour is unproven for
   both.

The task instruction is explicit: where the mandated combination proves
structurally unsupported, document it and stop — do not silently substitute a
dependency. That is what this ADR does.

## Decision

**No notification dependency is added to this repository.** Instead:

1. `cp_notifications` defines a **platform-neutral `NotificationService`**, an
   `InboxEvent` with a server-assigned `eventId`, and a
   `NotificationDeduplicator`. No vendor SDK is imported.
2. `tools/check_layering.sh` **fails the build** on any direct import of
   `firebase_messaging`, `awesome_notifications`, `awesome_notifications_fcm`
   or `flutter_local_notifications` in `apps/` or `packages/`, so no feature
   can quietly couple itself to an undecided vendor.
3. A capability table records, per platform, what is supported and with what
   class of evidence, and `assertPushTransportSupported` **throws** on Windows
   and Linux so an unsupported plugin cannot be initialized there.
4. The blueprint's "mandatory coexistence" requirement is reclassified from
   *spike pending* to **DECISION REQUIRED**.

## Status of the mandated requirement

| Requirement | Classification |
|---|---|
| `firebase_messaging` + `awesome_notifications` coexistence | **DECISION REQUIRED** — vendor-prohibited, not merely untested. Do not implement. |
| Path A (FCM + `flutter_local_notifications`) | **PLAUSIBLE — DEVICE VALIDATION REQUIRED.** Documented as compatible; unproven here. |
| Path B (Awesome + Awesome FCM) | **BLOCKED** on the unresolved license, and loses web push. |

Nothing in this ADR permits a claim that the notification stack is ready.

## Owner decision needed

- **D1** Is web push required at launch? (Settles Path A vs Path B.)
- **D2** If Path B is still wanted: what is `awesome_notifications_fcm`'s
  license? Unknown-license dependencies are not adopted.
- **D3** Windows closed-app push: fund a WNS route (Azure/Entra or Store
  registration, with lead time) — or accept Windows as
  local-toast-plus-durable-inbox only?

## Consequences

- Feature work can proceed against `NotificationService` without waiting for
  D1–D3, because no feature may import a vendor SDK anyway.
- Whichever path is chosen, the adapter lands behind the existing interface;
  reversing the choice touches the adapter, not features.
- Until D1–D3 are answered and device tests run, every notification row in the
  platform matrix stays `NOT RUN`, `BLOCKED` or `DECISION REQUIRED`.

## Revisit trigger

Reopen when the owner answers D1–D3, or when either vendor changes its
coexistence guidance. Re-check both package pages at that time; this ADR
records a 2026-09-09 reading, not a permanent fact.
