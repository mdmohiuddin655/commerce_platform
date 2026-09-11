import 'package:cp_contracts/src/delivery_attempt_return_denial.dart';
import 'package:cp_contracts/src/delivery_attempt_return_facts.dart';
import 'package:cp_contracts/src/delivery_attempt_state.dart';
import 'package:cp_contracts/src/ids.dart';
import 'package:cp_contracts/src/return_state.dart';

/// Canonical delivery-attempt aggregate shape.
///
/// Same lesson as every slice before it: the transition graph never *creates*
/// an impossible aggregate, but facts arrive from **storage** — partially
/// loaded, mid-migration, or written by something outside this contract.
/// Validation runs before any effect can be produced.
///
/// Returns null when the facts are canonical. **Never repairs anything** —
/// repair without an audit trail is indistinguishable from a bug.
AttemptReturnDenial? validateDeliveryAttemptAggregate(
  DeliveryAttemptFacts facts,
) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  // The attempt id is what an event, an audit row or a future dispute points
  // at. A sequential or malformed one is not a usable anchor.
  if (!isValidOpaqueId(facts.attemptId)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  // An existing aggregate has been written at least once. Revision 0 would
  // mean "never written", which contradicts holding a state.
  if (facts.attemptRevision < 1) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  // `delivered` is declared for enum stability and implemented by nothing. A
  // stored attempt holding it is corruption, not a state this contract reads —
  // and treating it as readable is exactly how an unimplemented delivery would
  // leak into effects.
  if (!DeliveryAttemptState.executableInThisSlice.contains(facts.state)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  return null;
}

/// Canonical return aggregate shape.
///
/// The disposition rule is the load-bearing part: a disposition exists
/// **exactly** in the states at or after inspection. A `received` return
/// carrying a disposition would mean an inspection outcome was recorded before
/// the inspection, and an `inspected` return without one would leave the stock
/// consequence underivable.
AttemptReturnDenial? validateReturnAggregate(ReturnFacts facts) {
  if (!isValidOpaqueId(facts.resourceId)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  if (facts.returnRevision < 1) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  if (!ReturnState.executableInThisSlice.contains(facts.state)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  final bool dispositionExpected =
      facts.state == ReturnState.inspected || facts.state == ReturnState.closed;
  if (dispositionExpected != (facts.disposition != null)) {
    return AttemptReturnDenial.aggregateInconsistent;
  }
  return null;
}
