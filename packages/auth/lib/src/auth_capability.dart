import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// How a platform obtains a Firebase-verifiable identity.
enum AuthStrategy {
  /// Firebase Auth Flutter plugin on the platform's native SDK.
  firebaseNativePlugin,

  /// Firebase Auth JS SDK in the browser.
  firebaseWebSdk,

  /// No production-supported Firebase native path: authenticate over HTTPS
  /// REST, obtaining the authorization code through the **system browser**
  /// with PKCE, then exchange for a Firebase token.
  restWithSystemBrowserPkce,
}

/// Where refresh credentials may be kept.
enum TokenStorage {
  /// OS-provided secure storage (Keychain, Keystore, DPAPI/credential locker).
  platformSecureStore,

  /// Browser-managed storage owned by the Firebase JS SDK.
  browserManaged,
}

/// Auth architecture facts for one platform.
///
/// Invariants encoded here rather than left to reviewer memory:
///
/// - [serverAuthorizationRequired] is **always true**. The server authorizes
///   every command regardless of platform, and regardless of whether App Check
///   is available. A platform lacking App Check gets *less attestation*, never
///   *less authorization*.
/// - [embedsClientSecret] is **always false**. A secret shipped to many users
///   is not a secret (RFC 8252 §8.5), so no client build carries one.
@immutable
class AuthCapabilities {
  const AuthCapabilities({
    required this.platform,
    required this.strategy,
    required this.requiresSystemBrowser,
    required this.requiresPkce,
    required this.appCheckAvailable,
    required this.tokenStorage,
    required this.note,
  });

  final CapabilityPlatform platform;
  final AuthStrategy strategy;

  /// RFC 8252 §5: a native app MUST use an external user-agent, not an
  /// embedded web view, for the authorization request.
  final bool requiresSystemBrowser;

  /// RFC 8252 §6: public native clients MUST implement PKCE.
  final bool requiresPkce;

  /// Whether Firebase App Check has a supported path here. Informational only
  /// — see [serverAuthorizationRequired].
  final bool appCheckAvailable;

  final TokenStorage tokenStorage;
  final String note;

  /// Never false. Present as a field so a test can assert it platform by
  /// platform, including where [appCheckAvailable] is false.
  bool get serverAuthorizationRequired => true;

  /// Never true. No client build embeds an OAuth client secret.
  bool get embedsClientSecret => false;
}

/// Documented auth strategy per platform. Sources and dates:
/// `docs/platform-matrix/FND-002A-capability-evidence.md` (checked 2026-09-09).
const Map<CapabilityPlatform, AuthCapabilities> authCapabilities =
    <CapabilityPlatform, AuthCapabilities>{
  CapabilityPlatform.android: AuthCapabilities(
    platform: CapabilityPlatform.android,
    strategy: AuthStrategy.firebaseNativePlugin,
    requiresSystemBrowser: false,
    requiresPkce: false,
    appCheckAvailable: true,
    tokenStorage: TokenStorage.platformSecureStore,
    note: 'firebase_auth lists Android. Provider setup and device validation '
        'are outstanding.',
  ),
  CapabilityPlatform.ios: AuthCapabilities(
    platform: CapabilityPlatform.ios,
    strategy: AuthStrategy.firebaseNativePlugin,
    requiresSystemBrowser: false,
    requiresPkce: false,
    appCheckAvailable: true,
    tokenStorage: TokenStorage.platformSecureStore,
    note: 'firebase_auth lists iOS. Provider setup and device validation are '
        'outstanding.',
  ),
  CapabilityPlatform.web: AuthCapabilities(
    platform: CapabilityPlatform.web,
    strategy: AuthStrategy.firebaseWebSdk,
    requiresSystemBrowser: false,
    requiresPkce: false,
    appCheckAvailable: true,
    tokenStorage: TokenStorage.browserManaged,
    note: 'Browser popup and redirect flows differ under third-party cookie '
        'and storage partitioning rules; both need runtime testing.',
  ),
  CapabilityPlatform.windows: AuthCapabilities(
    platform: CapabilityPlatform.windows,
    strategy: AuthStrategy.restWithSystemBrowserPkce,
    requiresSystemBrowser: true,
    requiresPkce: true,
    appCheckAvailable: false,
    tokenStorage: TokenStorage.platformSecureStore,
    note: 'Firebase documents Windows as local development only, so the '
        'native plugin path is not production-eligible. Authorization code '
        'via the system browser with PKCE and a loopback redirect '
        '(RFC 8252 §7.3), exchanged for a Firebase token over HTTPS. No '
        'client secret ships. App Check is unavailable, which changes '
        'attestation only — the server still authorizes every command.',
  ),
  CapabilityPlatform.macos: AuthCapabilities(
    platform: CapabilityPlatform.macos,
    strategy: AuthStrategy.firebaseNativePlugin,
    requiresSystemBrowser: false,
    requiresPkce: false,
    appCheckAvailable: true,
    tokenStorage: TokenStorage.platformSecureStore,
    note: 'Not a target platform; recorded for completeness.',
  ),
  CapabilityPlatform.linux: AuthCapabilities(
    platform: CapabilityPlatform.linux,
    strategy: AuthStrategy.restWithSystemBrowserPkce,
    requiresSystemBrowser: true,
    requiresPkce: true,
    appCheckAvailable: false,
    tokenStorage: TokenStorage.platformSecureStore,
    note: 'Not a target platform; recorded for completeness.',
  ),
};
