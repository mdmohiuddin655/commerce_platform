/// Rules for identifiers that cross the wire.
///
/// Command, resource and event identifiers are **opaque and unguessable**.
/// They are never sequential business counters: a counter leaks volume, lets
/// one actor guess another actor's resource ids, and makes a stolen id useful.
library;

/// Characters an opaque id may contain: URL-safe base64 alphabet.
const String _allowed =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

/// Minimum length. Short ids are guessable; 16 characters of this alphabet is
/// ~96 bits when randomly generated.
const int minIdLength = 16;

/// Upper bound so an id cannot be used as a payload smuggling channel.
const int maxIdLength = 64;

/// Why an identifier was rejected. Distinct values so tests and server logs
/// can be precise; the *caller-facing* message stays generic (see
/// `AuthorizationDecision.publicMessage`).
enum IdRejection {
  empty,
  tooShort,
  tooLong,
  illegalCharacter,

  /// All-digits: that is a counter, not an opaque identifier. Rejected even
  /// when long enough, because sequential ids are the actual hazard.
  looksSequential,
}

/// Returns null when [value] is a well-formed opaque id, else why not.
IdRejection? validateOpaqueId(String value) {
  if (value.isEmpty) {
    return IdRejection.empty;
  }
  if (value.length < minIdLength) {
    return IdRejection.tooShort;
  }
  if (value.length > maxIdLength) {
    return IdRejection.tooLong;
  }
  for (int i = 0; i < value.length; i++) {
    if (!_allowed.contains(value[i])) {
      return IdRejection.illegalCharacter;
    }
  }
  final bool allDigits = value.codeUnits.every(
    (int c) => c >= 0x30 && c <= 0x39,
  );
  if (allDigits) {
    return IdRejection.looksSequential;
  }
  return null;
}

/// Convenience predicate.
bool isValidOpaqueId(String value) => validateOpaqueId(value) == null;
