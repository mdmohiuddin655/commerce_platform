# module: fulfillment

Owner: FND-003 (contracts) → FND-004 (implementation). Empty at FND-001.

This module exposes **ports** for other modules to call. It never writes
another module's collections directly, and no other module writes its own.

Add to this file, before writing code: the module's owned entities, the
commands it accepts, the events it emits, the ports it exposes, and the ports
it consumes.
