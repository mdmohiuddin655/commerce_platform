import 'package:cp_core/cp_core.dart';
import 'package:cp_local_store/cp_local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persistence tiers', () {
    test('every tier has documented capabilities', () {
      expect(
        persistenceCapabilities.keys.toSet(),
        PersistenceTier.values.toSet(),
      );
    });

    test('web preference order matches Drift documentation', () {
      expect(webTierPreference, <PersistenceTier>[
        PersistenceTier.webOpfsShared,
        PersistenceTier.webOpfsLocks,
        PersistenceTier.webSharedIndexedDb,
        PersistenceTier.webUnsafeIndexedDb,
        PersistenceTier.webInMemory,
      ]);
    });

    test('unsafe IndexedDB is durable but not cross-tab safe', () {
      final PersistenceCapabilities caps =
          persistenceCapabilities[PersistenceTier.webUnsafeIndexedDb]!;

      expect(caps.durable, isTrue);
      expect(caps.crossTabSafe, isFalse);
      expect(caps.requiresUserWarning, isTrue);
    });

    test('in-memory fallback is not durable and must warn the user', () {
      final PersistenceCapabilities caps =
          persistenceCapabilities[PersistenceTier.webInMemory]!;

      expect(caps.durable, isFalse);
      expect(caps.requiresUserWarning, isTrue);
    });

    test('any tier that is not cross-tab safe warns the user', () {
      for (final PersistenceCapabilities caps
          in persistenceCapabilities.values) {
        if (!caps.crossTabSafe) {
          expect(
            caps.requiresUserWarning,
            isTrue,
            reason: '${caps.tier.name} risks data races without a warning',
          );
        }
      }
    });

    test('no tier may hold authoritative state', () {
      // Inventory, order status and money are server truth. A local cache
      // never becomes the source of record, whatever tier is selected.
      for (final PersistenceCapabilities caps
          in persistenceCapabilities.values) {
        expect(caps.mayHoldAuthoritativeState, isFalse);
      }
    });

    test('non-web platforms expect the native backend', () {
      for (final CapabilityPlatform p in CapabilityPlatform.values) {
        final PersistenceTier tier = expectedTierFor(p);
        if (p == CapabilityPlatform.web) {
          expect(tier, PersistenceTier.webOpfsShared);
        } else {
          expect(tier, PersistenceTier.nativeSqlite);
        }
      }
    });
  });
}
