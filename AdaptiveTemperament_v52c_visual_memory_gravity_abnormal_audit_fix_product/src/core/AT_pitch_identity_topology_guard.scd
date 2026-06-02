(
// AT_pitch_identity_topology_guard.scd
// v3D21b field-commit topology-preserving pitch-identity guard.
//
// This is not equal temperament, not a tone/sample change, and not a new mode.
// It rejects only solved targets that would make the named 12-pitch-class circle
// non-invertible or create a real close-pair identity collision. The first repair
// strategy is conservative: preserve the previous ordered field body. If the
// previous field is also invalid, a bounded canonical projection fallback is used.

var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[AT PITCH IDENTITY GUARD] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(st[\pitchIdentityTopology].isNil) { st[\pitchIdentityTopology] = IdentityDictionary.new; };
    if(st[\pitchIdentityTopologyGuardInterventionCount].isNil) { st[\pitchIdentityTopologyGuardInterventionCount] = 0; };

    at[\pitchIdentityGuardActivePcs] = {
        var forced;
        forced = st[\pitchIdentityGuardForcedActivePcs];
        if(forced.notNil) {
            forced.asArray.sort;
        } {
            if(at[\pitchIdentityActivePcs].notNil) {
                at[\pitchIdentityActivePcs].();
            } {
                (st[\activeNotes] ? IdentityDictionary.new).values.asArray.collect { |n| n[\pc] }.as(Set).asArray.sort;
            };
        };
    };

    at[\pitchIdentityGuardAssess] = { |phases, layer=\guardCandidate|
        var activePcs, order, closeRisk, activeRisk, trueOrderRisk, needsAction;
        activePcs = at[\pitchIdentityGuardActivePcs].();
        order = if(at[\pitchIdentityOrderForPhases].notNil) {
            at[\pitchIdentityOrderForPhases].(phases, layer, activePcs);
        } {
            (
                layer: layer,
                pcOrderPreserved: true,
                collisions: Array.new,
                closePairCollisions: Array.new,
                activeCollisions: Array.new,
                crossings: Array.new,
                orderCrossings: Array.new,
                orderWarningKind: \unknownNoTopologyReporter,
                minNeighborDistanceCents: 100.0,
                minAnyPairDistanceCents: 100.0
            );
        };
        closeRisk = (order[\closePairCollisions] ? (order[\collisions] ? Array.new)).notEmpty;
        activeRisk = (order[\activeCollisions] ? Array.new).notEmpty;
        trueOrderRisk = (order[\pcOrderPreserved] ? true).not;
        needsAction = closeRisk or: { activeRisk or: { trueOrderRisk } };
        (
            layer: layer,
            activePcs: activePcs,
            order: order,
            closeRisk: closeRisk,
            activeRisk: activeRisk,
            trueOrderRisk: trueOrderRisk,
            needsAction: needsAction,
            compact: "order=" ++ (order[\pcOrderPreserved] ? nil).asString
                ++ " close=" ++ ((order[\closePairCollisions] ? (order[\collisions] ? Array.new)).size).asString
                ++ " activeClose=" ++ ((order[\activeCollisions] ? Array.new).size).asString
                ++ " min=" ++ (order[\minNeighborDistanceCents] ? nil).asString
                ++ " kind=" ++ (order[\orderWarningKind] ? nil).asString
        )
    };

    at[\pitchIdentityGuardProjectCanonical] = { |phases, activePcs=nil|
        var activeSet, normalGap, activeGap, rawGaps, minGaps, adjusted, sumAdjusted, leftover, weights, weightSum, out, i;
        activePcs = activePcs ? at[\pitchIdentityGuardActivePcs].();
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc) };
        normalGap = (((cfg[\pitchIdentityGuard] ? ())[\warnCents] ? 25.0) / 1200.0).clip(0.0, 0.08);
        activeGap = (((cfg[\pitchIdentityGuard] ? ())[\activeWarnCents] ? 35.0) / 1200.0).clip(normalGap, 0.10);
        rawGaps = Array.fill(12, { |pc| at[\wrap01].((phases[(pc + 1) % 12] ? ((pc + 1) / 12.0)) - (phases[pc] ? (pc / 12.0))) });
        minGaps = Array.fill(12, { |pc|
            if(activeSet.includes(pc) or: { activeSet.includes((pc + 1) % 12) }) { activeGap } { normalGap }
        });
        adjusted = Array.fill(12, { |pc| (rawGaps[pc] ? (1.0 / 12.0)).max(minGaps[pc]) });
        sumAdjusted = adjusted.sum;
        if(sumAdjusted >= 0.995) {
            adjusted = Array.fill(12, { 1.0 / 12.0 });
        } {
            leftover = 1.0 - sumAdjusted;
            weights = rawGaps.collect { |g| (g ? 0.0).max(0.0001) };
            weightSum = weights.sum.max(0.0001);
            adjusted = Array.fill(12, { |pc| adjusted[pc] + (leftover * (weights[pc] / weightSum)) });
        };
        out = Array.fill(12, 0.0);
        out[0] = at[\wrap01].(phases[0] ? 0.0);
        i = 1;
        while { i < 12 } {
            out[i] = out[i - 1] + adjusted[i - 1];
            i = i + 1;
        };
        out.collect { |p| at[\wrap01].(p) };
    };

    at[\pitchIdentityGuardMaxDeltaCents] = { |a, b|
        Array.fill(12, { |i| at[\wrapSigned].((a[i] ? 0.0) - (b[i] ? 0.0)).abs * 1200.0 }).maxItem ? 0.0;
    };

    at[\applyPitchIdentityTopologyGuard] = { |oldPhase, solvedPhase, solvedUnwrapped=nil, reason=\resolve, oldUnwrapped=nil|
        var gcfg, enabled, candidateAssess, oldAssess, activePcs, action, strategy, outPhase, outUnwrapped, afterAssess, report, maxDelta;
        gcfg = cfg[\pitchIdentityGuard] ? (enabled: true);
        enabled = gcfg[\enabled] ? true;
        activePcs = at[\pitchIdentityGuardActivePcs].();
        outPhase = solvedPhase.copy;
        outUnwrapped = solvedUnwrapped;
        action = false;
        strategy = \none;
        candidateAssess = at[\pitchIdentityGuardAssess].(solvedPhase, \guardCandidate);
        oldAssess = at[\pitchIdentityGuardAssess].(oldPhase, \guardPreviousField);

        if(enabled and: { candidateAssess[\needsAction] == true }) {
            action = true;
            if(oldAssess[\needsAction] == false) {
                strategy = \preservePreviousOrderedField;
                outPhase = oldPhase.copy;
                outUnwrapped = (oldUnwrapped ? oldPhase).copy;
            } {
                strategy = \canonicalProjectionFallback;
                outPhase = at[\pitchIdentityGuardProjectCanonical].(solvedPhase, activePcs);
                outUnwrapped = outPhase.copy;
            };
        };

        afterAssess = at[\pitchIdentityGuardAssess].(outPhase, \guardOutput);
        maxDelta = at[\pitchIdentityGuardMaxDeltaCents].(outPhase, solvedPhase).round(0.01);
        if(action) { st[\pitchIdentityTopologyGuardInterventionCount] = (st[\pitchIdentityTopologyGuardInterventionCount] ? 0) + 1; };
        report = (
            branch: \v3D21b_field_commit_topology_guard,
            enabled: enabled,
            acted: action,
            strategy: strategy,
            reason: reason,
            activePcs: activePcs,
            activePcNames: activePcs.collect { |pc| if(at[\pitchIdentityPcName].notNil) { at[\pitchIdentityPcName].(pc) } { pc.asString } },
            candidateNeedsAction: candidateAssess[\needsAction],
            candidateCompact: candidateAssess[\compact],
            previousFieldUsable: oldAssess[\needsAction].not,
            previousCompact: oldAssess[\compact],
            outputNeedsAction: afterAssess[\needsAction],
            outputCompact: afterAssess[\compact],
            maxGuardDeltaCents: maxDelta,
            interventionCount: st[\pitchIdentityTopologyGuardInterventionCount] ? 0,
            pitchAuthority: false,
            topologyAuthority: action,
            note: if(action) { "Rejected a non-invertible pitch-identity field commit; preserved the previous ordered field body or projected canonically." } { "No topology guard intervention; field commit remained an ordered pitch-identity circle." }
        );
        st[\lastPitchIdentityTopologyGuard] = report;
        st[\pitchIdentityTopology][\lastGuardReport] = report;
        if(action) { st[\lastPitchIdentityTopologyGuardAction] = report; };
        if(action or: { gcfg[\debug] ? false }) {
            ("[AT PITCH IDENTITY GUARD] acted=" ++ action.asString
                ++ " strategy=" ++ strategy.asString
                ++ " reason=" ++ reason.asString
                ++ " candidate=" ++ candidateAssess[\compact].asString
                ++ " output=" ++ afterAssess[\compact].asString
                ++ " maxDelta=" ++ maxDelta.asString ++ "c").postln;
        };
        (phase: outPhase, unwrapped: outUnwrapped, changed: action, report: report)
    };

    at[\applyPitchIdentityFieldCommitGuard] = { |candidatePhase, candidateUnwrapped=nil, reason=\fieldCommit, previousPhase=nil, previousUnwrapped=nil, activePcsOverride=nil|
        var oldForced, oldPhase, oldUnwrapped, candidateP, candidateU, out, restoreForced;
        oldPhase = (previousPhase ? (st[\nodePhase] ? st[\etPhase])).copy;
        oldUnwrapped = (previousUnwrapped ? (st[\coreUnwrappedPhase] ? oldPhase)).copy;
        candidateP = (candidatePhase ? oldPhase).copy;
        candidateU = if(candidateUnwrapped.notNil) { candidateUnwrapped.copy } { candidateP.copy };
        restoreForced = false;
        if(activePcsOverride.notNil) {
            oldForced = st[\pitchIdentityGuardForcedActivePcs];
            st[\pitchIdentityGuardForcedActivePcs] = activePcsOverride.asArray;
            restoreForced = true;
        };
        out = at[\applyPitchIdentityTopologyGuard].(oldPhase, candidateP, candidateU, reason, oldUnwrapped);
        if(restoreForced) { st[\pitchIdentityGuardForcedActivePcs] = oldForced; };
        out
    };


    api[\pitchIdentityTopologyGuardReport] = {
        var rep;
        rep = st[\lastPitchIdentityTopologyGuard] ? (
            branch: \v3D21b_field_commit_topology_guard,
            enabled: (cfg[\pitchIdentityGuard] ? (enabled: true))[\enabled] ? true,
            acted: false,
            strategy: \none,
            interventionCount: st[\pitchIdentityTopologyGuardInterventionCount] ? 0,
            lastActionStrategy: if(st[\lastPitchIdentityTopologyGuardAction].notNil) { st[\lastPitchIdentityTopologyGuardAction][\strategy] } { nil },
            lastActionReason: if(st[\lastPitchIdentityTopologyGuardAction].notNil) { st[\lastPitchIdentityTopologyGuardAction][\reason] } { nil },
            pitchAuthority: false,
            topologyAuthority: false,
            note: "No topology guard report has been generated yet."
        );
        if(rep[\lastActionStrategy].isNil and: { st[\lastPitchIdentityTopologyGuardAction].notNil }) {
            rep[\lastActionStrategy] = st[\lastPitchIdentityTopologyGuardAction][\strategy];
            rep[\lastActionReason] = st[\lastPitchIdentityTopologyGuardAction][\reason];
        };
        "".postln;
        "[AT PITCH IDENTITY TOPOLOGY GUARD REPORT]".postln;
        ("enabled=" ++ (rep[\enabled] ? true).asString
            ++ " acted=" ++ (rep[\acted] ? false).asString
            ++ " strategy=" ++ (rep[\strategy] ? \none).asString
            ++ " interventions=" ++ (rep[\interventionCount] ? 0).asString
            ++ " lastAction=" ++ (rep[\lastActionStrategy] ? \none).asString
            ++ " topologyAuthority=" ++ (rep[\topologyAuthority] ? false).asString).postln;
        rep
    };

    // Track same-pitch-class and octave-return events for diagnostics. This is
    // report metadata only; it does not alter note handling, pitch, or render.
    if(((st[\pitchIdentityTopology][\noteOnWrapped] ? false).not) and: { at[\noteOn].notNil }) {
        st[\pitchIdentityTopology][\originalNoteOn] = at[\noteOn];
        at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
            var result, hist, pc, rec;
            pc = midi.asInteger % 12;
            result = st[\pitchIdentityTopology][\originalNoteOn].value(midi, velocity, explicitFreq, suppressVoice);
            hist = st[\pitchIdentityTopology][\onsetHistory] ? Array.new;
            rec = (timestamp: Main.elapsedTime, midi: midi, pc: pc);
            hist = hist.add(rec);
            if(hist.size > ((cfg[\pitchIdentityGuard] ? ())[\maxReportHistory] ? 64)) {
                hist = hist.copyRange(hist.size - ((cfg[\pitchIdentityGuard] ? ())[\maxReportHistory] ? 64), hist.size - 1);
            };
            st[\pitchIdentityTopology][\onsetHistory] = hist;
            result
        };
        st[\pitchIdentityTopology][\noteOnWrapped] = true;
    };

    if(((st[\pitchIdentityTopology][\resetWrapped] ? false).not) and: { at[\resetToET].notNil }) {
        st[\pitchIdentityTopology][\originalResetToET] = at[\resetToET];
        at[\resetToET] = {
            var result;
            result = st[\pitchIdentityTopology][\originalResetToET].value;
            st[\pitchIdentityTopology][\onsetHistory] = Array.new;
            st[\pitchIdentityTopology][\lastGuardReport] = nil;
            st[\lastPitchIdentityTopologyGuard] = nil;
            st[\lastPitchIdentityTopologyGuardAction] = nil;
            st[\pitchIdentityTopologyGuardInterventionCount] = 0;
            result
        };
        st[\pitchIdentityTopology][\resetWrapped] = true;
    };

    "[AT PITCH IDENTITY GUARD] Loaded v3D21b field-commit topology-preserving guard; no samples, tones, UI art, mic policy, or Sethares/cylinder authority changed.".postln;
};
)
