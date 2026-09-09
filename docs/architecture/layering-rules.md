# Layering rules (FND-001)

Enforced mechanically by `tools/check_layering.sh` where a grep can see it, and
by review where it cannot. A grep-level guard is not a type-system guarantee —
it exists so a violation is caught in CI instead of after a feature ships.

## Rule 1 — packages never import apps

`packages/**` must not contain `package:<app>_app/`. Shared code cannot depend
on any single role's application. **Checked.**

## Rule 2 — client code never imports backend

`apps/**` and `packages/**` must not reach into `backend/`. The backend is a
separate deployable with its own runtime. **Checked.**

## Rule 3 — feature layers

```text
presentation  ->  application  ->  domain
data          ->  domain
```

| Layer | May import | Must never import |
|---|---|---|
| `domain` | `cp_core`, `cp_contracts`, `dart:*` | `package:flutter/*`, `application`, `data`, `presentation` |
| `application` | `domain`, `cp_*` | `presentation` |
| `data` | `domain`, `cp_networking`, `cp_local_store` | `presentation`, `application` |
| `presentation` | `application`, `domain`, `cp_design_system` | `data` |

`domain` declares repository *interfaces*; `data` implements them. The
dependency therefore points inward. Binding an implementation to a port happens
in `lib/bootstrap`, never inside a feature. Three of these edges are
**checked** (`domain`→Flutter, `presentation`→`data`, `application`→
`presentation`); the rest are review-enforced.

## Rule 4 — no secrets in tracked source

Google API-key-shaped strings and PEM private-key headers fail the check.
`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`,
`.env` and service-account JSON are git-ignored. **Checked.**

## Rules that a grep cannot enforce

These are review gates, listed so they are not silently forgotten:

- **The server is the only authority.** A `domain` transition table mirrored on
  the client is for UX affordance only. Inventory is checked and reserved by the
  backend, never by cached display; a local transaction cannot establish final
  commercial truth.
- **No arbitrary status patching.** Client code calls named commands with an
  idempotent command id and an order revision. It never PATCHes a status field.
- **Money is integer minor units.** `Money` has no `double` constructor and no
  `double` accessor. Corrections are reversal postings, not edits of history.
- **Three distinct facts.** Assignment notification, assignment acceptance and
  physical custody are separate; an offer timeout never implies pickup.
- **Optional capabilities stay optional.** Business functionality must work with
  GPS or notification permission denied. A foreground-only notification
  fallback is not push parity.

## Verifying the guard

`tools/check_layering.sh` was validated on 9 September 2026 by planting a
deliberate violation of each of the six rules and confirming a non-zero exit,
then confirming a clean pass after removal. Re-do this if the script changes:
a guard that cannot fail proves nothing.
