# Feature template

Copy this directory to `apps/<app>/lib/features/<feature>/` and rename the
placeholder types. The four layers are mandatory and their import direction is
checked by `tools/check_layering.sh`.

| Layer | May import | Must never import |
|---|---|---|
| `domain` | `cp_core`, `cp_contracts`, dart:core | `package:flutter/*`, `application`, `data`, `presentation` |
| `application` | `domain`, `cp_*` packages | `presentation`, `package:flutter/material.dart` |
| `data` | `domain`, `cp_networking`, `cp_local_store` | `presentation`, `application` |
| `presentation` | `application`, `domain`, `cp_design_system` | `data` |

Repository interfaces are declared in `domain` and implemented in `data`, so
the dependency points inward. Wiring of a `data` implementation to a `domain`
port happens in the app's `lib/bootstrap`, not inside the feature.
