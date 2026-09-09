/// Shared wire contract: schemas, exhaustive state transitions, permissions
/// and event names.
///
/// Only [ContractVersion] exists at FND-001. The schemas, the full transition
/// tables (order, assignment, custody, attempt, return, payment) and the
/// money/custody invariants are the deliverable of **FND-003** and must not be
/// guessed by feature tasks in the meantime.
library;

export 'package:cp_contracts/src/contract_version.dart';
