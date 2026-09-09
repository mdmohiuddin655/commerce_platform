import 'package:cp_auth/cp_auth.dart';
import 'package:cp_core/cp_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth capability table', () {
    test('covers every platform exactly once', () {
      expect(authCapabilities.keys.toSet(), CapabilityPlatform.values.toSet());
    });

    test('Windows uses REST with a system browser and PKCE', () {
      final AuthCapabilities windows =
          authCapabilities[CapabilityPlatform.windows]!;

      expect(windows.strategy, AuthStrategy.restWithSystemBrowserPkce);
      expect(windows.requiresSystemBrowser, isTrue);
      expect(windows.requiresPkce, isTrue);
      expect(windows.tokenStorage, TokenStorage.platformSecureStore);
    });

    test('mobile uses the Firebase plugin, web uses the JS SDK', () {
      expect(
        authCapabilities[CapabilityPlatform.android]!.strategy,
        AuthStrategy.firebaseNativePlugin,
      );
      expect(
        authCapabilities[CapabilityPlatform.ios]!.strategy,
        AuthStrategy.firebaseNativePlugin,
      );
      expect(
        authCapabilities[CapabilityPlatform.web]!.strategy,
        AuthStrategy.firebaseWebSdk,
      );
    });

    test('every strategy requiring a browser also requires PKCE', () {
      for (final AuthCapabilities caps in authCapabilities.values) {
        if (caps.requiresSystemBrowser) {
          expect(
            caps.requiresPkce,
            isTrue,
            reason: '${caps.platform.name}: RFC 8252 requires PKCE for '
                'public native clients',
          );
        }
      }
    });
  });

  group('invariants that must hold on every platform', () {
    test('no client build embeds an OAuth client secret', () {
      for (final AuthCapabilities caps in authCapabilities.values) {
        expect(
          caps.embedsClientSecret,
          isFalse,
          reason: '${caps.platform.name} must ship no client secret',
        );
      }
    });

    test('server authorization is required even without App Check', () {
      // Windows has no App Check path. That must reduce attestation only —
      // never authorization.
      final AuthCapabilities windows =
          authCapabilities[CapabilityPlatform.windows]!;
      expect(windows.appCheckAvailable, isFalse);
      expect(windows.serverAuthorizationRequired, isTrue);

      for (final AuthCapabilities caps in authCapabilities.values) {
        expect(
          caps.serverAuthorizationRequired,
          isTrue,
          reason: '${caps.platform.name} must not bypass server authorization',
        );
      }
    });
  });
}
