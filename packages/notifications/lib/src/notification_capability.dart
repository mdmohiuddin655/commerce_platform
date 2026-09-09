import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// How a remote push transport stands on a given platform.
enum PushTransportSupport {
  /// A supported plugin path exists and is documented by its vendor.
  supported,

  /// No supported plugin path exists for this platform.
  unsupportedByPlugin,

  /// A transport could exist but selecting it needs an owner decision
  /// (account registration, cost, or vendor lock-in), not just code.
  decisionRequired,
}

/// Evidence class behind a capability claim. Never collapse these into a
/// single "supported" boolean: the whole point is that a documented claim and
/// a device-proven claim are different things.
enum EvidenceLevel {
  /// Read from current primary vendor documentation on a stated date.
  verifiedDoc,

  /// Observed locally on the bootstrap host (resolution, analysis, tests).
  verifiedLocal,

  /// Observed in a browser on this host.
  verifiedHostRuntime,

  /// Requires a physical device; not available here.
  requiresDevice,

  /// Requires a runner (e.g. Windows) not available here.
  requiresRunner,

  /// Needs an owner decision before it can be evidenced at all.
  decisionRequired,
}

/// What the notification stack can and cannot do on one platform.
///
/// Populated from dated primary-source research recorded in
/// `docs/platform-matrix/FND-002A-capability-evidence.md`. Nothing here is a
/// runtime probe: these are the documented expectations that the device test
/// plan must later confirm or refute.
@immutable
class NotificationCapabilities {
  const NotificationCapabilities({
    required this.platform,
    required this.pushTransport,
    required this.localDisplay,
    required this.backgroundDelivery,
    required this.terminatedLaunch,
    required this.closedAppDelivery,
    required this.requiresServiceWorker,
    required this.requiresVapidKey,
    required this.foregroundAutoDisplay,
    required this.evidence,
    required this.note,
  });

  final CapabilityPlatform platform;
  final PushTransportSupport pushTransport;

  /// Whether a local (non-push) notification can be shown by the app.
  final bool localDisplay;

  /// Whether the platform can deliver a message while the app is backgrounded.
  final bool backgroundDelivery;

  /// Whether tapping a notification can launch a terminated app and hand the
  /// message to it.
  final bool terminatedLaunch;

  /// Whether a message can reach the user with the app **not running at all**.
  /// This is the expensive one: on Windows it needs a push service account.
  final bool closedAppDelivery;

  final bool requiresServiceWorker;
  final bool requiresVapidKey;

  /// Whether the OS shows a notification automatically while the app is in the
  /// foreground. Firebase documents that it does **not**, on Android or iOS.
  final bool foregroundAutoDisplay;

  final EvidenceLevel evidence;
  final String note;

  /// True when this platform must not attempt to initialize a push transport.
  bool get mustNotInitializePush =>
      pushTransport != PushTransportSupport.supported;
}

/// Documented capability table. Sources and dates:
/// `docs/platform-matrix/FND-002A-capability-evidence.md` (checked 2026-09-09).
const Map<CapabilityPlatform, NotificationCapabilities>
notificationCapabilities = <CapabilityPlatform, NotificationCapabilities>{
  CapabilityPlatform.android: NotificationCapabilities(
    platform: CapabilityPlatform.android,
    pushTransport: PushTransportSupport.supported,
    localDisplay: true,
    backgroundDelivery: true,
    terminatedLaunch: true,
    closedAppDelivery: true,
    requiresServiceWorker: false,
    requiresVapidKey: false,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.requiresDevice,
    note: 'firebase_messaging lists Android. Foreground messages are not '
        'displayed automatically. Delivery is unproven without a device.',
  ),
  CapabilityPlatform.ios: NotificationCapabilities(
    platform: CapabilityPlatform.ios,
    pushTransport: PushTransportSupport.supported,
    localDisplay: true,
    backgroundDelivery: true,
    terminatedLaunch: true,
    closedAppDelivery: true,
    requiresServiceWorker: false,
    requiresVapidKey: false,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.requiresDevice,
    note: 'Needs an APNs key, push + background-mode capabilities and method '
        'swizzling. Simulators are not evidence for push.',
  ),
  CapabilityPlatform.web: NotificationCapabilities(
    platform: CapabilityPlatform.web,
    pushTransport: PushTransportSupport.supported,
    localDisplay: true,
    backgroundDelivery: true,
    terminatedLaunch: false,
    closedAppDelivery: false,
    requiresServiceWorker: true,
    requiresVapidKey: true,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.verifiedDoc,
    note: 'Requires firebase-messaging-sw.js and a VAPID key passed to '
        'getToken. Background delivery depends on the browser running.',
  ),
  CapabilityPlatform.windows: NotificationCapabilities(
    platform: CapabilityPlatform.windows,
    pushTransport: PushTransportSupport.unsupportedByPlugin,
    localDisplay: true,
    backgroundDelivery: false,
    terminatedLaunch: false,
    closedAppDelivery: false,
    requiresServiceWorker: false,
    requiresVapidKey: false,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.requiresRunner,
    note: 'firebase_messaging does not list Windows. Local toast display is '
        'available via a Windows-capable local notification plugin. '
        'Closed-app push would need WNS, which requires an Azure/Entra or '
        'Store registration — an owner decision, not only code.',
  ),
  CapabilityPlatform.macos: NotificationCapabilities(
    platform: CapabilityPlatform.macos,
    pushTransport: PushTransportSupport.supported,
    localDisplay: true,
    backgroundDelivery: true,
    terminatedLaunch: true,
    closedAppDelivery: true,
    requiresServiceWorker: false,
    requiresVapidKey: false,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.verifiedDoc,
    note: 'Listed by firebase_messaging. Not a target platform for this '
        'product; recorded only to keep the table complete.',
  ),
  CapabilityPlatform.linux: NotificationCapabilities(
    platform: CapabilityPlatform.linux,
    pushTransport: PushTransportSupport.unsupportedByPlugin,
    localDisplay: true,
    backgroundDelivery: false,
    terminatedLaunch: false,
    closedAppDelivery: false,
    requiresServiceWorker: false,
    requiresVapidKey: false,
    foregroundAutoDisplay: false,
    evidence: EvidenceLevel.verifiedDoc,
    note: 'Not a target platform. firebase_messaging does not list Linux.',
  ),
};

/// Thrown when code tries to start a push transport on a platform where no
/// supported transport exists. Failing loudly here is deliberate: silently
/// doing nothing would let a Windows build look like it had push.
class UnsupportedPushTransport implements Exception {
  const UnsupportedPushTransport(this.platform, this.reason);

  final CapabilityPlatform platform;
  final String reason;

  @override
  String toString() =>
      'UnsupportedPushTransport(${platform.name}): $reason';
}

/// Guard every push-transport adapter must call before initializing.
///
/// This is how "unsupported plugins are not initialized on Windows" is
/// enforced in code rather than in a comment.
void assertPushTransportSupported(CapabilityPlatform platform) {
  final NotificationCapabilities caps = notificationCapabilities[platform]!;
  if (caps.mustNotInitializePush) {
    throw UnsupportedPushTransport(platform, caps.note);
  }
}
