/// Canonical delivery-proof assessment event identifiers.
///
/// Facts the server recorded. Receiving one authorizes nothing and **proves
/// nothing** — a client re-reads authorized server state. Server-assigned event
/// ids only; a transport message id is never the business event id.
///
/// Payloads carry routing and identity only: resource id, assessment revision,
/// assessment id, server UTC. **No raw proof, no policy contents, no
/// photograph, signature, OTP or QR material, no GPS or location, no address,
/// no phone number, no order contents, no money and no storage path or signed
/// URL.** Authorized clients re-read protected state; a notification is a hint,
/// never proof or authority.
class DeliveryProofAssessmentEventType {
  const DeliveryProofAssessmentEventType._();

  /// A trusted assessment record was created for an order.
  ///
  /// It reports **that an assessment happened**, not that delivery succeeded,
  /// that the customer accepted, that a dispute resolved or that money settled.
  /// Whether the verdict itself belongs in the payload is a **privacy and
  /// policy decision that is deliberately not made here** — a routing id is
  /// always sufficient, because an authorized client re-reads the record.
  static const String proofAssessed = 'delivery.proof_assessed';

  /// Every assessment event this contract defines. Exactly one.
  ///
  /// `const`, so it is deeply immutable: a caller that tries to add to it gets
  /// an `UnsupportedError` rather than silently extending the vocabulary.
  static const List<String> all = <String>[proofAssessed];
}
