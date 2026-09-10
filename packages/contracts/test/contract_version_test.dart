import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ContractVersion', () {
    test('version policy permits a decode attempt on the same major', () {
      // Permission to *try*, not proof that anything decodes.
      expect(
        const ContractVersion(1, 0)
            .isVersionCompatibleWith(const ContractVersion(1, 9)),
        isTrue,
      );
      expect(
        const ContractVersion(1, 0).isSameMajor(const ContractVersion(1, 9)),
        isTrue,
      );
    });

    test('version policy refuses a different major', () {
      expect(
        const ContractVersion(1, 0)
            .isVersionCompatibleWith(const ContractVersion(2, 0)),
        isFalse,
      );
    });

    test('orders by major then minor', () {
      expect(
        const ContractVersion(1, 2).compareTo(const ContractVersion(1, 3)),
        lessThan(0),
      );
      expect(
        const ContractVersion(2, 0).compareTo(const ContractVersion(1, 9)),
        greaterThan(0),
      );
    });

    test('exposes the version this build was compiled against', () {
      // 0.1 -> 0.2 command/event/authorization vocabulary (FND-003A);
      // 0.2 -> 0.3 pre-dispatch order and reservation lifecycle (FND-003B1);
      // 0.3 -> 0.4 picker assignment lifecycle (FND-003B2A);
      // 0.4 -> 0.5 rider assignment lifecycle (FND-003B2B);
      // 0.5 -> 0.6 custody and picker->rider handoff (FND-003B3A). All
      // additive, so the major stays 0.
      expect(ContractVersion.current.toString(), '0.6');
    });

    test('0.3 and 0.4 share a major, so the policy permits an attempt', () {
      // Two integers only. 0.3 defined no assignment types, so it could not
      // decode a 0.4 assignment payload even if one existed — and none does.
      expect(
        const ContractVersion(0, 4)
            .isVersionCompatibleWith(const ContractVersion(0, 3)),
        isTrue,
      );
      expect(
        const ContractVersion(0, 3)
            .isVersionCompatibleWith(const ContractVersion(0, 4)),
        isTrue,
      );
    });

    test('0.5 and 0.6 share a major, so the policy permits an attempt', () {
      // Same policy, same non-claim. 0.5 defined no custody types, so it could
      // not decode a 0.6 custody payload even if one existed. The role-aware
      // `reachableSlotRevisionRange` parameter is additive and defaults to the
      // pre-0.6 answer, but that is a statement about the source, not decoding.
      expect(
        ContractVersion.current
            .isVersionCompatibleWith(const ContractVersion(0, 5)),
        isTrue,
      );
      expect(
        const ContractVersion(0, 5)
            .isVersionCompatibleWith(ContractVersion.current),
        isTrue,
      );
    });

    test('0.4 and 0.5 share a major, so the policy permits an attempt', () {
      // Same policy, same non-claim. 0.4 defined no rider assignment types, so
      // it could not decode a 0.5 rider payload even if one existed. The
      // shared-file move of AssignmentDenial and reachableSlotRevisionRange
      // changed no name, value or behaviour, and there is no wire form for
      // either — but neither fact is offered as decode evidence.
      expect(
        const ContractVersion(0, 5)
            .isVersionCompatibleWith(const ContractVersion(0, 4)),
        isTrue,
      );
      expect(
        const ContractVersion(0, 4)
            .isVersionCompatibleWith(const ContractVersion(0, 5)),
        isTrue,
      );
    });

    test('0.2 and 0.3 share a major, so the policy permits an attempt', () {
      // Again a statement about two integers only. 0.2 defined no lifecycle
      // types, so it could not decode a 0.3 lifecycle payload even if one
      // existed — and none does, because there is still no serialization.
      expect(
        ContractVersion.current
            .isVersionCompatibleWith(const ContractVersion(0, 2)),
        isTrue,
      );
      expect(
        const ContractVersion(0, 2)
            .isVersionCompatibleWith(ContractVersion.current),
        isTrue,
      );
    });

    test('0.1 and 0.2 share a major, so the policy permits an attempt', () {
      // This is a statement about two integers. It is deliberately NOT a
      // claim that a 0.1 build can decode a 0.2 payload: 0.1 defined no
      // command envelope, event envelope or permission decoder, so it has
      // nothing to decode one with. No such test exists because no such
      // capability exists.
      expect(
        ContractVersion.current
            .isVersionCompatibleWith(const ContractVersion(0, 1)),
        isTrue,
      );
      expect(
        const ContractVersion(0, 1)
            .isVersionCompatibleWith(ContractVersion.current),
        isTrue,
      );
    });

    test('a future major break is refused in both directions', () {
      expect(
        ContractVersion.current
            .isVersionCompatibleWith(const ContractVersion(1, 0)),
        isFalse,
      );
      expect(
        const ContractVersion(1, 0)
            .isVersionCompatibleWith(ContractVersion.current),
        isFalse,
      );
    });

    test('no decoder exists yet, so no payload claim can be made', () {
      // Guard against the claim creeping back. The contract has no
      // serialization: there is no toJson/fromJson on any envelope, so a
      // payload-compatibility test is not merely absent, it is impossible to
      // write honestly today. When serialization lands, its own tests must
      // use a real encoded payload and a real decoder.
      const ContractVersion v = ContractVersion.current;

      expect(v.isVersionCompatibleWith(const ContractVersion(0, 1)), isTrue);
      expect(
        v.toString(),
        '0.6',
        reason: 'version policy only; decode behaviour is a decoder property',
      );
    });
  });
}
