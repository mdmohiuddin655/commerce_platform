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

    test('a malformed stored offer recipient id is corruption', () {
      // FIX-001: emptiness alone was checked here, so a stored counter-like or
      // truncated recipient could drive a projection change. Principal ids are
      // opaque ids everywhere else in this contract.
      for (final String bad in <String>[
        '',
        'usr_short',
        '1234567890123456',
        r'usr_bad!principal01',
      ]) {
        expect(
          validatePickerAssignmentAggregate(
            facts(slotRevision: 1, current: attempt(recipient: bad)),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: 'recipient "$bad"',
        );
      }
    });

    test('an accepted assignee cannot bypass the recipient id rule', () {
      // assignee == recipient is already required, so an invalid assignee can
      // only appear by also being an invalid recipient. Both shapes pinned.
      for (final AssignmentState st in <AssignmentState>[
        AssignmentState.accepted,
        AssignmentState.revoked,
      ]) {
        final int rev = st == AssignmentState.revoked ? 3 : 2;
        expect(
          validatePickerAssignmentAggregate(
            facts(
              slotRevision: rev,
              current: attempt(
                state: st,
                recipient: '1234567890123456',
                assignee: '1234567890123456',
              ),
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: '${st.id} with a sequential-looking identity',
        );
      }
    });

    test('a malformed resource id is corruption', () {
      // Same opaque contract CommandEnvelope and EventEnvelope enforce.
      for (final String bad in <String>['', 'ord_short', '1234567890123456']) {
        expect(
          validatePickerAssignmentAggregate(
            PickerAssignmentFacts(
              resourceId: bad,
              slotRevision: 0,
              orderState: OrderState.accepted,
              orderRegionId: region,
            ),
          ),
          AssignmentDenial.aggregateInconsistent,
          reason: 'resourceId "$bad"',
        );
      }
    });

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

    test('a CANONICAL completed attempt still fails closed for commands', () {
      // FND-003B3A makes picker `completed` reachable, so its shape is now
      // validated. It is still not a state any command may act FROM: no client
      // may re-offer, accept or revoke finished work.
      final PickerAssignmentFacts done = facts(
        slotRevision: 3,
        current: attempt(state: AssignmentState.completed, assignee: pickerA),
      );
      expect(validatePickerAssignmentAggregate(done), isNull,
          reason: 'gen1 completed at rev3 is a real history');

      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.picker)) {
        final PickerAssignmentOutcome o = run(
          c,
          on: done,
          acting: agentId,
          newAssignmentId: assignB,
          target: eligible(pickerB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );
        expect(o.denial, AssignmentDenial.unknownTransition, reason: c.commandType);
        expect(o.transition, isNull, reason: c.commandType);
      }
    });

    test('a MALFORMED completed attempt is corruption', () {
      // Completion retains both identities. An attempt that lost its assignee
      // is not a finished job, it is a damaged record.
      expect(
        validatePickerAssignmentAggregate(
          facts(
            slotRevision: 3,
            current: attempt(state: AssignmentState.completed),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
      // ...and an unreachable revision for a completed generation.
      expect(
        validatePickerAssignmentAggregate(
          facts(
            slotRevision: 2,
            current: attempt(
              state: AssignmentState.completed,
              assignee: pickerA,
            ),
          ),
        ),
        AssignmentDenial.aggregateInconsistent,
      );
    });

    test('the picker command and event surface stays picker-only', () {
      // FND-003B2B made AssignmentRole.rider executable and added rider
      // commands to the shared enum. That must not leak into the picker
      // surface: every picker-role command still names a picker, and every
      // picker event id still starts `picker.`.
      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.picker)) {
        expect(c.commandType, contains('picker'));
        expect(c.commandType, isNot(contains('rider')));
      }
      for (final String e in AssignmentEventType.picker) {
        expect(e, startsWith('picker.'));
      }
      expect(AssignmentEventType.picker.length, 6);
    });

    test('the picker evaluator refuses every rider command', () {
      // Routing a rider command into this evaluator would apply picker rules
      // to a rider slot and skip the rider lifecycle's picker-authority
      // prerequisite entirely. It fails closed instead.
      for (final AssignmentCommand c
          in AssignmentCommand.forRole(AssignmentRole.rider)) {
        expect(
          run(
            c,
            on: facts(slotRevision: 1, current: attempt()),
            acting: pickerA,
            newAssignmentId: assignB,
            target: eligible(pickerB),
            expiryDue: true,
            safety: ReassignmentSafety.provenNoCustody,
          ).denial,
          AssignmentDenial.unknownTransition,
          reason: '${c.commandType} must not be evaluated as picker work',
        );
      }
    });

    test('both assignment roles are now implemented', () {
      expect(AssignmentRole.executableInThisSlice, <AssignmentRole>{
        AssignmentRole.picker,
        AssignmentRole.rider,
      });
    });
  });

  group('a new attempt needs a new identity', () {
    PickerAssignmentFacts terminal(AssignmentState state) => facts(
      slotRevision: state == AssignmentState.revoked ? 3 : 2,
      current: attempt(
        state: state,
        assignee: state == AssignmentState.revoked ? pickerA : null,
      ),
    );

    for (final AssignmentState s in <AssignmentState>[
      AssignmentState.declined,
      AssignmentState.expired,
      AssignmentState.revoked,
    ]) {
      test('re-offering with the ${s.id} attempt\'s own id is denied', () {
        final PickerAssignmentOutcome o = run(
          AssignmentCommand.offerPickerAssignment,
          on: terminal(s),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerB),
        );

        expect(o.transition, isNull, reason: 'no attempt may be resurrected');
        expect(o.denial, AssignmentDenial.assignmentIdReuse);
      });

      test('re-offering after ${s.id} with a NEW id is allowed', () {
        final PickerAssignmentTransition t = allowed(
          run(
            AssignmentCommand.offerPickerAssignment,
            on: terminal(s),
            acting: agentId,
            newAssignmentId: assignB,
            target: eligible(pickerB),
          ),
        );

        expect(t.assignmentId, assignB);
        expect(t.generation, 2);
      });
    }

    test('advancing the generation is not a substitute for a new id', () {
      // The generation would have advanced to 2 either way; the id must still
      // differ, or two attempts become indistinguishable in the audit trail.
      final PickerAssignmentOutcome reused = run(
        AssignmentCommand.offerPickerAssignment,
        on: terminal(AssignmentState.declined),
        acting: agentId,
        newAssignmentId: assignA,
        target: eligible(pickerB),
      );

      expect(reused.denial, AssignmentDenial.assignmentIdReuse);
      expect(reused.transition, isNull);
    });
  });

  group('generation and slot revision must describe a reachable history', () {
    ({int min, int max}) range(int g, AssignmentState s) =>
        reachableSlotRevisionRange(g, s)!;

    test('the documented ranges hold', () {
      expect(range(1, AssignmentState.offered), (min: 1, max: 1));
      expect(range(1, AssignmentState.accepted), (min: 2, max: 2));
      expect(range(1, AssignmentState.declined), (min: 2, max: 2));
      expect(range(1, AssignmentState.expired), (min: 2, max: 2));
      expect(range(1, AssignmentState.revoked), (min: 3, max: 3));
      expect(range(2, AssignmentState.offered), (min: 3, max: 4));
      expect(range(2, AssignmentState.accepted), (min: 4, max: 5));
      expect(range(2, AssignmentState.revoked), (min: 5, max: 6));
      expect(range(3, AssignmentState.offered), (min: 5, max: 7));
    });

    test('no range exists for a non-positive generation or completed', () {
      expect(reachableSlotRevisionRange(0, AssignmentState.offered), isNull);
      expect(reachableSlotRevisionRange(-1, AssignmentState.offered), isNull);
      expect(reachableSlotRevisionRange(1, AssignmentState.completed), isNull);
    });

    PickerAssignmentOutcome probeAt(
      int generation,
      AssignmentState state,
      int slotRevision,
    ) => run(
      AssignmentCommand.acceptPickerAssignment,
      on: facts(
        slotRevision: slotRevision,
        current: attempt(
          id: assignA,
          generation: generation,
          state: state,
          assignee: state == AssignmentState.accepted ||
                  state == AssignmentState.revoked
              ? pickerA
              : null,
        ),
      ),
      assignmentId: assignA,
      generation: generation,
    );

    final Map<String, List<Object>> impossible = <String, List<Object>>{
      'gen2 offered at rev1': <Object>[2, AssignmentState.offered, 1],
      'gen2 offered at rev2': <Object>[2, AssignmentState.offered, 2],
      'gen3 offered at rev1': <Object>[3, AssignmentState.offered, 1],
      'gen1 accepted at rev1': <Object>[1, AssignmentState.accepted, 1],
      'gen2 accepted at rev2': <Object>[2, AssignmentState.accepted, 2],
      'gen2 accepted at rev3': <Object>[2, AssignmentState.accepted, 3],
      'gen1 revoked at rev2': <Object>[1, AssignmentState.revoked, 2],
      'gen2 revoked at rev4': <Object>[2, AssignmentState.revoked, 4],
      // Above the reachable maximum, not merely below the minimum.
      'gen1 offered at rev2': <Object>[1, AssignmentState.offered, 2],
      'gen1 offered at rev99': <Object>[1, AssignmentState.offered, 99],
      'gen1 accepted at rev5': <Object>[1, AssignmentState.accepted, 5],
      'gen2 offered at rev5': <Object>[2, AssignmentState.offered, 5],
      'gen1 revoked at rev4': <Object>[1, AssignmentState.revoked, 4],
    };

    for (final MapEntry<String, List<Object>> e in impossible.entries) {
      test('${e.key} fails closed', () {
        final PickerAssignmentOutcome o = probeAt(
          e.value[0] as int,
          e.value[1] as AssignmentState,
          e.value[2] as int,
        );

        expect(o.transition, isNull, reason: e.key);
        expect(o.denial, AssignmentDenial.aggregateInconsistent);
      });
    }

    final Map<String, List<Object>> canonical = <String, List<Object>>{
      'gen1 offered at rev1': <Object>[1, AssignmentState.offered, 1],
      'gen1 accepted at rev2': <Object>[1, AssignmentState.accepted, 2],
      'gen1 declined at rev2': <Object>[1, AssignmentState.declined, 2],
      'gen1 expired at rev2': <Object>[1, AssignmentState.expired, 2],
      'gen1 revoked at rev3': <Object>[1, AssignmentState.revoked, 3],
      'gen2 offered at rev3 (after decline/expiry)': <Object>[
        2,
        AssignmentState.offered,
        3,
      ],
      'gen2 offered at rev4 (after revoke)': <Object>[
        2,
        AssignmentState.offered,
        4,
      ],
      'gen2 accepted at rev4': <Object>[2, AssignmentState.accepted, 4],
      'gen2 accepted at rev5': <Object>[2, AssignmentState.accepted, 5],
      'gen2 revoked at rev5': <Object>[2, AssignmentState.revoked, 5],
      'gen2 revoked at rev6': <Object>[2, AssignmentState.revoked, 6],
    };

    for (final MapEntry<String, List<Object>> e in canonical.entries) {
      test('${e.key} remains valid', () {
        expect(
          validatePickerAssignmentAggregate(
            facts(
              slotRevision: e.value[2] as int,
              current: attempt(
                generation: e.value[0] as int,
                state: e.value[1] as AssignmentState,
                assignee: e.value[1] == AssignmentState.accepted ||
                        e.value[1] == AssignmentState.revoked
                    ? pickerA
                    : null,
              ),
            ),
          ),
          isNull,
          reason: e.key,
        );
      });
    }

    test('an incoherent aggregate produces no effect for ANY command', () {
      final PickerAssignmentFacts bad = facts(
        slotRevision: 1,
        current: attempt(generation: 2, state: AssignmentState.offered),
      );

      for (final AssignmentCommand c in mutating) {
        final PickerAssignmentOutcome o = run(
          c,
          on: bad,
          acting: agentId,
          assignmentId: assignA,
          generation: 2,
          newAssignmentId: assignB,
          target: eligible(pickerB),
          expiryDue: true,
          safety: ReassignmentSafety.provenNoCustody,
        );

        expect(o.transition, isNull, reason: c.commandType);
        expect(o.denial, AssignmentDenial.aggregateInconsistent);
      }
    });

    test('generation stays distinct from slotRevision', () {
      // A full cycle: generation advances once, the revision three times.
      PickerAssignmentFacts f = facts();
      f = apply(
        allowed(
          run(
            AssignmentCommand.offerPickerAssignment,
            on: f,
            acting: agentId,
            newAssignmentId: assignA,
            target: eligible(pickerA),
          ),
        ),
      );
      f = apply(allowed(run(AssignmentCommand.acceptPickerAssignment, on: f)));
      f = apply(
        allowed(
          run(
            AssignmentCommand.revokePickerAssignment,
            on: f,
            acting: agentId,
            safety: ReassignmentSafety.provenNoCustody,
          ),
        ),
      );

      expect(f.attempt!.generation, 1, reason: 'one attempt');
      expect(f.slotRevision, 3, reason: 'three mutations');
    });
  });

  group('stale identity combined with a new attempt', () {
    // Generation 1 to picker A ended; generation 2 offered to picker B.
    PickerAssignmentFacts gen2Offered() => facts(
      slotRevision: 3,
      current: attempt(id: assignB, generation: 2, recipient: pickerB),
    );

    test('old id + old generation mutates nothing', () {
      final PickerAssignmentOutcome o = run(
        AssignmentCommand.acceptPickerAssignment,
        on: gen2Offered(),
        acting: pickerA,
        assignmentId: assignA,
        generation: 1,
      );

      expect(o.transition, isNull);
      expect(o.denial, AssignmentDenial.assignmentIdMismatch);
    });

    test('old id carrying the NEW generation is still denied', () {
      expect(
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: gen2Offered(),
          acting: pickerA,
          assignmentId: assignA,
          generation: 2,
        ).denial,
        AssignmentDenial.assignmentIdMismatch,
      );
    });

    test('new id carrying the OLD generation is denied', () {
      expect(
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: gen2Offered(),
          acting: pickerB,
          assignmentId: assignB,
          generation: 1,
        ).denial,
        AssignmentDenial.generationMismatch,
      );
    });

    test('no denied path produces any effect', () {
      for (final PickerAssignmentOutcome o in <PickerAssignmentOutcome>[
        run(
          AssignmentCommand.acceptPickerAssignment,
          on: gen2Offered(),
          acting: pickerA,
          assignmentId: assignA,
          generation: 1,
        ),
        run(
          AssignmentCommand.offerPickerAssignment,
          on: facts(
            slotRevision: 2,
            current: attempt(state: AssignmentState.declined),
          ),
          acting: agentId,
          newAssignmentId: assignA,
          target: eligible(pickerB),
        ),
      ]) {
        expect(o.transition, isNull);
        expect(o.allowed, isFalse);
      }
    });
  });

  group('transition closure — every success validates', () {
    // The invariant this group exists for:
    //
    //   apply(successful transition) -> validatePickerAssignmentAggregate == null
    //
    // The revision-range rule in `reachableSlotRevisionRange` is *derived* from
    // the evaluator's mutation costs. Testing the helper alone would only
    // prove it agrees with itself; this ties the actual transition
    // implementation to the validator, so a change to either that drifts from
    // the other fails here.
    //
    // Every fact below comes from a real evaluator transition — nothing is
    // hand-fabricated, because a fabricated pair could accidentally satisfy a
    // rule the lifecycle no longer produces.

    /// Asserts [outcome] succeeded, applies it, and requires the resulting
    /// aggregate to pass validation. Returns the next facts so callers can
    /// chain a real history.
    PickerAssignmentFacts closes(
      String label,
      PickerAssignmentOutcome outcome,
    ) {
      final PickerAssignmentTransition? t = outcome.transition;
      expect(
        t,
        isNotNull,
        reason: '$label should be allowed, got ${outcome.denial?.name}',
      );
      final PickerAssignmentFacts next = apply(t!);
      expect(
        validatePickerAssignmentAggregate(next),
        isNull,
        reason: '$label produced gen=${t.generation} rev='
            '${t.resultingSlotRevision} state=${t.toState.id}, which the '
            'aggregate validator rejects — reachableSlotRevisionRange and the '
            'evaluator have drifted apart',
      );
      return next;
    }

    PickerAssignmentOutcome offerOn(
      PickerAssignmentFacts f,
      String newId,
      String target,
    ) => run(
      AssignmentCommand.offerPickerAssignment,
      on: f,
      acting: agentId,
      newAssignmentId: newId,
      target: eligible(target),
    );

    const String assignC = 'asg_Cc11Dd22Ee33Ff44';

    test('initial offer closes', () {
      final PickerAssignmentFacts f = closes(
        'initial offer',
        offerOn(facts(), assignA, pickerA),
      );

      expect(f.attempt!.generation, 1);
      expect(f.slotRevision, 1);
      expect(f.attempt!.state, AssignmentState.offered);
    });

    test('accept closes', () {
      final PickerAssignmentFacts offered = closes(
        'offer',
        offerOn(facts(), assignA, pickerA),
      );

      final PickerAssignmentFacts accepted = closes(
        'accept',
        run(AssignmentCommand.acceptPickerAssignment, on: offered),
      );

      expect(accepted.attempt!.state, AssignmentState.accepted);
      expect(accepted.slotRevision, 2);
    });

    test('decline closes', () {
      final PickerAssignmentFacts offered = closes(
        'offer',
        offerOn(facts(), assignA, pickerA),
      );

      expect(
        closes(
          'decline',
          run(AssignmentCommand.declinePickerAssignment, on: offered),
        ).attempt!.state,
        AssignmentState.declined,
      );
    });

    test('expiry closes', () {
      final PickerAssignmentFacts offered = closes(
        'offer',
        offerOn(facts(), assignA, pickerA),
      );

      expect(
        closes(
          'expiry',
          run(
            AssignmentCommand.expirePickerOffer,
            on: offered,
            expiryDue: true,
          ),
        ).attempt!.state,
        AssignmentState.expired,
      );
    });

    test('revoke closes', () {
      PickerAssignmentFacts f = closes(
        'offer',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes('accept', run(AssignmentCommand.acceptPickerAssignment, on: f));
      f = closes(
        'revoke',
        run(
          AssignmentCommand.revokePickerAssignment,
          on: f,
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );

      expect(f.attempt!.state, AssignmentState.revoked);
      expect(f.slotRevision, 3);
    });

    test('re-offer after decline closes (previous attempt cost 2)', () {
      PickerAssignmentFacts f = closes(
        'offer g1',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes(
        'decline g1',
        run(AssignmentCommand.declinePickerAssignment, on: f),
      );
      f = closes('offer g2', offerOn(f, assignB, pickerB));

      expect(f.attempt!.generation, 2);
      expect(f.slotRevision, 3, reason: 'offer + decline + offer');
    });

    test('re-offer after expiry closes (previous attempt cost 2)', () {
      PickerAssignmentFacts f = closes(
        'offer g1',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes(
        'expire g1',
        run(AssignmentCommand.expirePickerOffer, on: f, expiryDue: true),
      );
      f = closes('offer g2', offerOn(f, assignB, pickerB));

      expect(f.attempt!.generation, 2);
      expect(f.slotRevision, 3);
    });

    test('re-offer after revoke closes (previous attempt cost 3)', () {
      PickerAssignmentFacts f = closes(
        'offer g1',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes('accept g1', run(AssignmentCommand.acceptPickerAssignment, on: f));
      f = closes(
        'revoke g1',
        run(
          AssignmentCommand.revokePickerAssignment,
          on: f,
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
      f = closes('offer g2', offerOn(f, assignB, pickerB));

      expect(f.attempt!.generation, 2);
      expect(
        f.slotRevision,
        4,
        reason: 'offer + accept + revoke + offer — a costlier history than a '
            'declined or expired generation',
      );
    });

    test('a generation-3 mixed history closes at every step', () {
      // g1 revoked (3 mutations), g2 declined (2), g3 offered.
      PickerAssignmentFacts f = closes(
        'offer g1',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes('accept g1', run(AssignmentCommand.acceptPickerAssignment, on: f));
      f = closes(
        'revoke g1',
        run(
          AssignmentCommand.revokePickerAssignment,
          on: f,
          acting: agentId,
          safety: ReassignmentSafety.provenNoCustody,
        ),
      );
      f = closes('offer g2', offerOn(f, assignB, pickerB));
      f = closes(
        'decline g2',
        run(
          AssignmentCommand.declinePickerAssignment,
          on: f,
          acting: pickerB,
        ),
      );
      f = closes('offer g3', offerOn(f, assignC, pickerA));

      expect(f.attempt!.generation, 3);
      expect(f.slotRevision, 6, reason: '3 + 2 + 1 mutations');
    });

    test('a generation-3 cheapest history closes at every step', () {
      // g1 declined (2), g2 expired (2), g3 offered — the low end of the range.
      PickerAssignmentFacts f = closes(
        'offer g1',
        offerOn(facts(), assignA, pickerA),
      );
      f = closes(
        'decline g1',
        run(AssignmentCommand.declinePickerAssignment, on: f),
      );
      f = closes('offer g2', offerOn(f, assignB, pickerB));
      f = closes(
        'expire g2',
        run(AssignmentCommand.expirePickerOffer, on: f, expiryDue: true),
      );
      f = closes('offer g3', offerOn(f, assignC, pickerA));

      expect(f.attempt!.generation, 3);
      expect(f.slotRevision, 5, reason: '2 + 2 + 1 mutations — the minimum');
    });

    test('no malformed target can produce a validator-invalid transition', () {
      // The picker half of the FIX-001 defect: PickerEligibility qualified on
      // presence and equality without the canonical opaque-id rule, so a
      // malformed trusted target could produce a successful offer whose
      // applied aggregate the validator refuses.
      for (final String bad in <String>[
        '',
        'usr_short',
        '1234567890123456',
        r'usr_bad!principal01',
      ]) {
        final PickerAssignmentOutcome o = offerOn(facts(), assignA, bad);
        if (o.transition == null) {
          expect(o.denial, AssignmentDenial.targetNotEligible, reason: bad);
          continue;
        }
        expect(
          validatePickerAssignmentAggregate(apply(o.transition!)),
          isNull,
          reason: 'malformed target "$bad" produced an aggregate the validator '
              'rejects - the FIX-001 defect has recurred',
        );
      }
    });

    test('every executable PICKER transition kind is represented above', () {
      // Guards against a future picker command being added without closure
      // coverage. Scoped to the picker role rather than the whole enum, so
      // that adding a rider command cannot be absorbed here and escape the
      // rider suite's own coverage guard — and so that adding a picker
      // command still fails here until it is covered.
      expect(
        AssignmentCommand.forRole(AssignmentRole.picker),
        <AssignmentCommand>{
          AssignmentCommand.offerPickerAssignment,
          AssignmentCommand.acceptPickerAssignment,
          AssignmentCommand.declinePickerAssignment,
          AssignmentCommand.expirePickerOffer,
          AssignmentCommand.revokePickerAssignment,
        },
        reason: 'a new picker command needs a transition-closure case here',
      );
    });
  });

  group('executable states and the revision model are coupled', () {
    test('every executable state has a reachable revision range', () {
      for (final AssignmentState s in AssignmentState.executableInThisSlice) {
        expect(
          reachableSlotRevisionRange(1, s),
          isNotNull,
          reason: 'No reachable slot-revision range is defined for '
              '"${s.id}". If a state becomes executable, '
              'reachableSlotRevisionRange and transition-cost tests must be '
              'updated in the same contract change — otherwise every '
              'aggregate in that state fails closed as inconsistent.',
        );
      }
    });

    test('the executable set is exactly the five states modelled today', () {
      expect(AssignmentState.executableInThisSlice, <AssignmentState>{
        AssignmentState.offered,
        AssignmentState.accepted,
        AssignmentState.declined,
        AssignmentState.expired,
        AssignmentState.revoked,
      });
    });

    test('completed stays non-executable and has no invented cost', () {
      expect(
        AssignmentState.executableInThisSlice
            .contains(AssignmentState.completed),
        isFalse,
      );
      expect(
        reachableSlotRevisionRange(1, AssignmentState.completed),
        isNull,
        reason: 'its mutation cost is unknown until FND-003B3 defines it; '
            'guessing one would corrupt the model',
      );
    });
  });
}
