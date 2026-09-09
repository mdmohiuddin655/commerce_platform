# apps/rider/lib/features

Every feature is one directory with exactly these four layers:

```text
lib/features/<feature>/
  domain/        # entities, value objects, transition rules — no I/O, no Flutter
  application/   # use cases / BLoC-Cubit orchestration — depends on domain only
  data/          # repository implementations, DTO mapping, adapters
  presentation/  # widgets, screens, routing — depends on application
```

Allowed import direction (enforced by `tools/check_layering.sh`):

`presentation -> application -> domain` and `data -> domain`.

`domain` imports nothing from the other three layers and never imports
`package:flutter`. `presentation` never imports `data` directly.

Copy `tools/templates/feature_template/` to start a feature.

No feature exists yet: FND-001 delivers the foundation only, and role
features are gated on FND-002, FND-003 and FND-004.
