Use cases and BLoC/Cubit orchestration. Depends on `domain` only. Emits states
consumed by `presentation`. Every command carries an idempotent command id so a
retry cannot double-apply; see docs/contracts (FND-003).
