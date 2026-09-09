/// Local persistence capability description.
///
/// FND-002A delivers the documented tier model only. No Drift dependency, no
/// schema and no offline command queue is implemented here: the web WASM
/// backend cannot be exercised without generated web platform folders, and the
/// durable queue is later foundation work.
library;

export 'package:cp_local_store/src/persistence_capability.dart';
