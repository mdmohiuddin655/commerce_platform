import 'package:cp_core/cp_core.dart';
import 'package:meta/meta.dart';

/// Storage backends Drift can end up using, named after the implementations
/// Drift itself reports through `WasmDatabaseResult.chosenImplementation`.
///
/// Order of declaration is Drift's documented order of preference on the web,
/// most preferred first, followed by the native backend.
enum PersistenceTier {
  /// Origin-Private FileSystem via a shared worker.
  webOpfsShared,

  /// OPFS without a shared worker; needs COOP/COEP headers.
  webOpfsLocks,

  /// IndexedDB coordinated by a shared worker.
  webSharedIndexedDb,

  /// IndexedDB with no cross-tab coordination. Drift documents that it is
  /// *not* safe for multiple tabs to use the same database in this mode.
  webUnsafeIndexedDb,

  /// Nothing persistent was available. Data is lost on reload.
  webInMemory,

  /// `NativeDatabase` over dart:ffi on Android, iOS, macOS, Windows, Linux.
  nativeSqlite,
}

/// What a tier actually guarantees.
@immutable
class PersistenceCapabilities {
  const PersistenceCapabilities({
    required this.tier,
    required this.durable,
    required this.crossTabSafe,
    required this.requiresUserWarning,
    required this.note,
  });

  final PersistenceTier tier;

  /// Survives a reload. False means the tier must never be treated as a cache
  /// that anything depends on.
  final bool durable;

  /// Safe when two tabs of the app are open at once.
  final bool crossTabSafe;

  /// The app must tell the user their data may be lost or corrupted.
  final bool requiresUserWarning;

  final String note;

  /// No tier may hold anything the business depends on. Local state is a
  /// cache and an outbox; commercial truth is server-side, always.
  bool get mayHoldAuthoritativeState => false;
}

/// Documented behaviour per tier. Sources and dates:
/// `docs/platform-matrix/FND-002A-capability-evidence.md` (checked 2026-09-09).
const Map<PersistenceTier, PersistenceCapabilities> persistenceCapabilities =
    <PersistenceTier, PersistenceCapabilities>{
  PersistenceTier.webOpfsShared: PersistenceCapabilities(
    tier: PersistenceTier.webOpfsShared,
    durable: true,
    crossTabSafe: true,
    requiresUserWarning: false,
    note: 'Preferred web backend. Drift documents shared-worker OPFS as '
        'available on Firefox.',
  ),
  PersistenceTier.webOpfsLocks: PersistenceCapabilities(
    tier: PersistenceTier.webOpfsLocks,
    durable: true,
    crossTabSafe: true,
    requiresUserWarning: false,
    note: 'OPFS without a shared worker; requires COOP/COEP response headers, '
        'which the hosting setup must actually send.',
  ),
  PersistenceTier.webSharedIndexedDb: PersistenceCapabilities(
    tier: PersistenceTier.webSharedIndexedDb,
    durable: true,
    crossTabSafe: true,
    requiresUserWarning: false,
    note: 'IndexedDB coordinated by a shared worker.',
  ),
  PersistenceTier.webUnsafeIndexedDb: PersistenceCapabilities(
    tier: PersistenceTier.webUnsafeIndexedDb,
    durable: true,
    crossTabSafe: false,
    requiresUserWarning: true,
    note: 'Drift documents that multiple tabs sharing this database is not '
        'safe. Chrome on Android has no shared workers, so without the '
        'required headers there is no way to prevent cross-tab data races.',
  ),
  PersistenceTier.webInMemory: PersistenceCapabilities(
    tier: PersistenceTier.webInMemory,
    durable: false,
    crossTabSafe: false,
    requiresUserWarning: true,
    note: 'Fallback when no persistence is available, e.g. restrictive '
        'private-browsing modes. Everything is lost on reload.',
  ),
  PersistenceTier.nativeSqlite: PersistenceCapabilities(
    tier: PersistenceTier.nativeSqlite,
    durable: true,
    crossTabSafe: true,
    requiresUserWarning: false,
    note: 'NativeDatabase over dart:ffi. From Drift 2.32.0 with sqlite3 3.x '
        'no extra native setup is required.',
  ),
};

/// Web tiers in Drift's documented order of preference, most preferred first.
const List<PersistenceTier> webTierPreference = <PersistenceTier>[
  PersistenceTier.webOpfsShared,
  PersistenceTier.webOpfsLocks,
  PersistenceTier.webSharedIndexedDb,
  PersistenceTier.webUnsafeIndexedDb,
  PersistenceTier.webInMemory,
];

/// Tier a platform is expected to use before any runtime feature detection.
/// On the web the real tier is only known after `WasmDatabase.open` reports
/// `chosenImplementation`, so this returns the *best case* and callers must
/// re-check at runtime.
PersistenceTier expectedTierFor(CapabilityPlatform platform) =>
    switch (platform) {
      CapabilityPlatform.web => PersistenceTier.webOpfsShared,
      CapabilityPlatform.android ||
      CapabilityPlatform.ios ||
      CapabilityPlatform.windows ||
      CapabilityPlatform.macos ||
      CapabilityPlatform.linux => PersistenceTier.nativeSqlite,
    };
