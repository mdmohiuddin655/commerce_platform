import 'package:cp_contracts/cp_contracts.dart';
import 'package:test/test.dart';

import 'support/picker_assignment_fixtures.dart';

PickerAssignmentFacts offeredSlot() => facts(slotRevision: 1, current: attempt());

PickerAssignmentFacts acceptedSlot() => facts(
  slotRevision: 2,
  current: attempt(state: AssignmentState.accepted, assignee: pickerA),
);

/// Commands that could otherwise produce an effect.
const List<AssignmentCommand> mutating = <AssignmentCommand>[
  AssignmentCommand.offerPickerAssignment,
  AssignmentCommand.acceptPickerAssignment,
  AssignmentCommand.declinePickerAssignment,
  AssignmentCommand.expirePickerOffer,
  AssignmentCommand.revokePickerAssignment,
];

void main() {
  group('stale generation and assignment id', () {
    test('a delayed accept from an older generation mutates nothing', () {
      // Generation 1 offered to A, expired. Generation 2 offered to B.
      final PickerAssignmentFacts gen2 = facts(
        slotRevision: 3,
        current: attempt(
          id: assignB,
          generation: 2,
          recipient: pickerB,
        ),
      );

      final PickerAssignmentOutcome delayed = run(
        AssignmentCommand.acceptPickerAssignment,
        on: gen2,
        acting: pickerA,
        assignmentId: assignA,
        generation: 1,
      );

      expect(delayed.transition, isNull);
      expect(
        delayed.denial,
        AssignmentDenial.assignmentIdMismatch,
        reason: 'never applied to the current attempt just because orderId '
            'matched',
      );
    });

    test('a delayed decline from an older generation mutates nothing', () {
      final PickerAssignmentFacts gen2 = facts(
        slotRevision: 3,
        current: attempt(id: assignB, generation: 2, recipient: pickerB),
      );

      expect(
        run(
          AssignmentCommand.declinePickerAssignment,
          on: gen2,
          acting: pickerA,
          assignmentId: assignA,
          generation: 1,
        ).transition,
        isNull,
      );
    });

    test('a matching id with the wrong generation is refused', () {
      expect(
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: offeredSlot(),
          generation: 99,
        ).denial,
        AssignmentDenial.generationMismatch,
      );
    });

    test('a stale slot revision refuses every mutating command', () {
      for (final AssignmentCommand c in mutating) {
        final PickerAssignmentOutcome o = run(
          c,
          on: offeredSlot(),
          expectedSlotRevision: 0,
          acting: c == AssignmentCommand.offerPickerAssignment ||
                  c == AssignmentCommand.revokePickerAssignment
              ? agentId
              : pickerA,
          newAssignmentId: assignB,
          target: eligible(pickerB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );

        expect(o.transition, isNull, reason: c.commandType);
        expect(o.denial, AssignmentDenial.slotRevisionConflict);
      }
    });

    test('a command naming no attempt when one is required is refused', () {
      for (final AssignmentCommand c in <AssignmentCommand>[
        AssignmentCommand.acceptPickerAssignment,
        AssignmentCommand.declinePickerAssignment,
        AssignmentCommand.expirePickerOffer,
        AssignmentCommand.revokePickerAssignment,
      ]) {
        expect(
          run(c, on: facts(), acting: agentId, expiryDue: true).denial,
          AssignmentDenial.noAssignmentAttempt,
          reason: c.commandType,
        );
      }
    });
  });

  group('duplicate and reordered commands produce no effect', () {
    final Map<String, PickerAssignmentOutcome> cases =
        <String, PickerAssignmentOutcome>{
      'duplicate accept': run(
        AssignmentCommand.acceptPickerAssignment,
        on: acceptedSlot(),
      ),
      'duplicate decline': run(
        AssignmentCommand.declinePickerAssignment,
        on: facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.declined),
        ),
      ),
      'decline after accept': run(
        AssignmentCommand.declinePickerAssignment,
        on: acceptedSlot(),
      ),
      'accept after decline': run(
        AssignmentCommand.acceptPickerAssignment,
        on: facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.declined),
        ),
      ),
      'accept after expiry': run(
        AssignmentCommand.acceptPickerAssignment,
        on: facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.expired),
        ),
      ),
      'expiry after accept': run(
        AssignmentCommand.expirePickerOffer,
        on: acceptedSlot(),
        expiryDue: true,
      ),
      'expiry after decline': run(
        AssignmentCommand.expirePickerOffer,
        on: facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.declined),
        ),
        expiryDue: true,
      ),
      'duplicate expiry': run(
        AssignmentCommand.expirePickerOffer,
        on: facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.expired),
        ),
        expiryDue: true,
      ),
      'revoke before accept': run(
        AssignmentCommand.revokePickerAssignment,
        on: offeredSlot(),
        acting: agentId,
        safety: ReassignmentSafety.provenNoCustody,
      ),
      'duplicate revoke': run(
        AssignmentCommand.revokePickerAssignment,
        on: facts(
          slotRevision: 3,
          current: attempt(
            state: AssignmentState.revoked,
            assignee: pickerA,
          ),
        ),
        acting: agentId,
        safety: ReassignmentSafety.provenNoCustody,
      ),
    };

    for (final MapEntry<String, PickerAssignmentOutcome> e in cases.entries) {
      test('${e.key} produces no transition', () {
        expect(e.value.transition, isNull, reason: e.key);
        expect(e.value.denial, AssignmentDenial.wrongAssignmentState);
      });
    }
  });

  group('aggregate integrity', () {
    PickerAssignmentOutcome probe(PickerAssignmentFacts f) => run(
      AssignmentCommand.acceptPickerAssignment,
      on: f,
      acting: pickerA,
      assignmentId: f.attempt?.assignmentId,
      generation: f.attempt?.generation,
    );

    final Map<String, PickerAssignmentFacts> malformed =
        <String, PickerAssignmentFacts>{
      'offered with an assignee': facts(
        slotRevision: 1,
        current: attempt(assignee: pickerA),
      ),
      'declined with an assignee': facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.declined, assignee: pickerA),
      ),
      'expired with an assignee': facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.expired, assignee: pickerA),
      ),
      'accepted with no assignee': facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.accepted),
      ),
      'accepted by someone other than the recipient': facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.accepted, assignee: pickerB),
      ),
      'revoked with no historical assignee': facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.revoked),
      ),
      'generation zero': facts(
        slotRevision: 1,
        current: attempt(generation: 0),
      ),
      'negative generation': facts(
        slotRevision: 1,
        current: attempt(generation: -1),
      ),
      'non-opaque assignment id': facts(
        slotRevision: 1,
        current: attempt(id: '42'),
      ),
      'empty offer recipient': facts(
        slotRevision: 1,
        current: attempt(recipient: ''),
      ),
      'blank timeout policy reference': facts(
        slotRevision: 1,
        current: attempt(timeoutRef: '   '),
      ),
      'attempt present but slot never written': facts(current: attempt()),
      'no attempt but slot revision advanced': facts(slotRevision: 3),
      'negative slot revision': facts(slotRevision: -1),
    };

    for (final MapEntry<String, PickerAssignmentFacts> e in malformed.entries) {
      test('${e.key} fails closed', () {
        final PickerAssignmentOutcome o = probe(e.value);

        expect(o.transition, isNull, reason: e.key);
        expect(o.denial, AssignmentDenial.aggregateInconsistent);
      });
    }

    test('malformed facts produce no effect for ANY command', () {
      final PickerAssignmentFacts corrupt = facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.accepted, assignee: pickerB),
      );

      for (final AssignmentCommand c in mutating) {
        final PickerAssignmentOutcome o = run(
          c,
          on: corrupt,
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );

        expect(o.transition, isNull, reason: c.commandType);
        expect(o.denial, AssignmentDenial.aggregateInconsistent);
      }
    });

    test('the validator does not repair — it only refuses', () {
      final PickerAssignmentFacts corrupt = facts(
        slotRevision: 1,
        current: attempt(state: AssignmentState.accepted),
      );

      expect(
        validatePickerAssignmentAggregate(corrupt),
        AssignmentDenial.aggregateInconsistent,
      );
      // Facts are unchanged: nothing was rewritten.
      expect(corrupt.attempt!.acceptedAssigneePrincipalId, isNull);
      expect(corrupt.attempt!.state, AssignmentState.accepted);
    });

    test('every canonical shape validates', () {
      final List<PickerAssignmentFacts> canonical = <PickerAssignmentFacts>[
        facts(),
        facts(slotRevision: 1, current: attempt()),
        facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.accepted, assignee: pickerA),
        ),
        facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.declined),
        ),
        facts(
          slotRevision: 2,
          current: attempt(state: AssignmentState.expired),
        ),
        facts(
          slotRevision: 3,
          current: attempt(state: AssignmentState.revoked, assignee: pickerA),
        ),
      ];

      for (final PickerAssignmentFacts f in canonical) {
        expect(validatePickerAssignmentAggregate(f), isNull);
      }
    });
  });

  group('states and roles this slice does not own', () {
    test('completed is declared but unreachable', () {
      expect(
        AssignmentState.executableInThisSlice
            .intersection(AssignmentState.notYetImplemented),
        isEmpty,
      );
      expect(AssignmentState.notYetImplemented, <AssignmentState>{
        AssignmentState.completed,
      });
    });

    test('no transition can produce completed', () {
      final Set<AssignmentState> reachable = <AssignmentState>{};
      for (final AssignmentState s in AssignmentState.executableInThisSlice) {
        for (final AssignmentCommand c in mutating) {
          final PickerAssignmentOutcome o = run(
            c,
            on: facts(
              slotRevision: 2,
              current: attempt(
                state: s,
                assignee: s == AssignmentState.accepted ||
                        s == AssignmentState.revoked
                    ? pickerA
                    : null,
              ),
            ),
            acting: agentId,
            newAssignmentId: assignB,
            target: eligible(pickerB),
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          );
          if (o.transition != null) {
            reachable.add(o.transition!.toState);
          }
        }
      }

      expect(reachable.contains(AssignmentState.completed), isFalse);
    });

    test('an attempt already in completed fails closed', () {
      expect(
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: facts(
            slotRevision: 2,
            current: attempt(state: AssignmentState.completed),
          ),
        ).denial,
        AssignmentDenial.unknownTransition,
      );
    });

    test('rider role is declared but not executable in this slice', () {
      expect(AssignmentRole.executableInThisSlice, <AssignmentRole>{
        AssignmentRole.picker,
      });
      expect(
        AssignmentRole.executableInThisSlice.contains(AssignmentRole.rider),
        isFalse,
      );
      // No command in this slice names a rider.
      for (final AssignmentCommand c in AssignmentCommand.values) {
        expect(c.commandType, isNot(contains('rider')));
      }
      for (final String e in AssignmentEventType.all) {
        expect(e, startsWith('picker.'));
      }
    });
  });
}
