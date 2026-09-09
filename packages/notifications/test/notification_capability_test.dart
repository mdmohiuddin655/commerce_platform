import 'package:cp_core/cp_core.dart';
import 'package:cp_notifications/cp_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capability table', () {
    test('covers every platform exactly once', () {
      expect(
        notificationCapabilities.keys.toSet(),
        CapabilityPlatform.values.toSet(),
      );
    });

    test('Windows has no supported push transport', () {
      final NotificationCapabilities windows =
          notificationCapabilities[CapabilityPlatform.windows]!;

      expect(windows.pushTransport, PushTransportSupport.unsupportedByPlugin);
      expect(windows.mustNotInitializePush, isTrue);
      expect(windows.closedAppDelivery, isFalse);
      // Local toast display is still available; losing push must not be
      // described as losing notifications entirely.
      expect(windows.localDisplay, isTrue);
    });

    test('web requires a service worker and a VAPID key', () {
      final NotificationCapabilities web =
          notificationCapabilities[CapabilityPlatform.web]!;

      expect(web.requiresServiceWorker, isTrue);
      expect(web.requiresVapidKey, isTrue);
      expect(web.terminatedLaunch, isFalse);
    });

    test('no platform displays foreground messages automatically', () {
      // Firebase documents this for Android and iOS; the app must show a
      // local notification itself. Encoded so no adapter assumes otherwise.
      for (final NotificationCapabilities caps
          in notificationCapabilities.values) {
        expect(
          caps.foregroundAutoDisplay,
          isFalse,
          reason: '${caps.platform.name} must not assume auto-display',
        );
      }
    });

    test('device-dependent platforms are not claimed as proven', () {
      for (final CapabilityPlatform p in <CapabilityPlatform>[
        CapabilityPlatform.android,
        CapabilityPlatform.ios,
      ]) {
        expect(
          notificationCapabilities[p]!.evidence,
          EvidenceLevel.requiresDevice,
          reason: 'push on ${p.name} has not been run on a device',
        );
      }
    });
  });

  group('assertPushTransportSupported', () {
    test('throws on Windows so no unsupported plugin is initialized', () {
      expect(
        () => assertPushTransportSupported(CapabilityPlatform.windows),
        throwsA(isA<UnsupportedPushTransport>()),
      );
    });

    test('throws on Linux', () {
      expect(
        () => assertPushTransportSupported(CapabilityPlatform.linux),
        throwsA(isA<UnsupportedPushTransport>()),
      );
    });

    test('permits Android, iOS and web', () {
      for (final CapabilityPlatform p in <CapabilityPlatform>[
        CapabilityPlatform.android,
        CapabilityPlatform.ios,
        CapabilityPlatform.web,
      ]) {
        expect(() => assertPushTransportSupported(p), returnsNormally);
      }
    });
  });
}
