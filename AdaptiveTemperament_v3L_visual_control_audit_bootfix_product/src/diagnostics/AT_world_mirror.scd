(
// AT_world.scd
// Mirror-only world diagnostics for the legacy event-driven core.
// This file does not solve, slew, or install tuning. It only reflects st[\nodePhase]
// into world-shaped diagnostic state used by the held-context and stress batteries.
var build, at, cfg, st, api, diag, ui, pcNames;

build = ~atBuild;
if(build.isNil) {
    "[at-world] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pcNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    at[\makeWorld] = { |source=\unknown|
        (
            phaseByPc: st[\etPhase].copy,
            absPhaseByPc: st[\etPhase].copy,
            weightByPc: Array.fill(12, 0.0),
            pcSet: Array.fill(12, 0),
            anchorPc: nil,
            anchorAbsPhase: nil,
            confidence: 0.0,
            source: source,
            timestamp: Main.elapsedTime
        )
    };

    at[\copyWorld] = { |world|
        if(world.isNil) {
            nil
        } {
            (
                phaseByPc: (world[\phaseByPc] ? st[\etPhase]).copy,
                absPhaseByPc: (world[\absPhaseByPc] ? st[\etPhase]).copy,
                weightByPc: (world[\weightByPc] ? Array.fill(12, 0.0)).copy,
                pcSet: (world[\pcSet] ? Array.fill(12, 0)).copy,
                anchorPc: world[\anchorPc],
                anchorAbsPhase: world[\anchorAbsPhase],
                confidence: world[\confidence] ? 0.0,
                source: world[\source] ? \unknown,
                timestamp: world[\timestamp] ? Main.elapsedTime
            )
        }
    };

    at[\rebaseAbsNearReference] = { |absValue, referenceAbs|
        var k;
        if(referenceAbs.isNil) {
            absValue
        } {
            k = (referenceAbs - absValue).round(1.0);
            absValue + k
        }
    };

    at[\normalizeWorld] = { |world|
        var out;
        out = at[\copyWorld].(world) ? at[\makeWorld].(\normalized);
        12.do { |i|
            out[\absPhaseByPc][i] = out[\absPhaseByPc][i] ? st[\etPhase][i];
            out[\phaseByPc][i] = at[\wrap01].(out[\absPhaseByPc][i]);
            out[\weightByPc][i] = (out[\weightByPc][i] ? 0.0).clip(0.0, 2.0);
            out[\pcSet][i] = if((out[\pcSet][i] ? 0) > 0) { 1 } { 0 };
        };
        if(out[\anchorPc].notNil) {
            out[\anchorAbsPhase] = out[\absPhaseByPc][out[\anchorPc]];
        };
        out[\confidence] = (out[\confidence] ? 0.0).clip(0.0, 1.0);
        out[\timestamp] = Main.elapsedTime;
        out
    };

    at[\worldDistance] = { |a, b|
        var sum;
        if(a.isNil or: { b.isNil }) {
            1.0
        } {
            sum = 0.0;
            12.do { |i|
                sum = sum + at[\wrapSigned].((a[\phaseByPc] ? st[\etPhase])[i] - (b[\phaseByPc] ? st[\etPhase])[i]).abs;
            };
            sum / 12.0
        }
    };

    at[\buildSoundingState] = {
        var notes, pcGroups, pcRepresentatives, strongest, onsetOrdered, pcWeights;
        notes = Array.new;
        pcGroups = IdentityDictionary.new;
        pcRepresentatives = IdentityDictionary.new;
        strongest = nil;

        st[\activeNotes].keysValuesDo { |midi, note|
            notes = notes.add(note);
        };

        notes = notes.sort { |a, b| (a[\midi] ? 0) < (b[\midi] ? 0) };
        onsetOrdered = notes.sort { |a, b| (a[\onsetTime] ? a[\timestamp] ? 0.0) < (b[\onsetTime] ? b[\timestamp] ? 0.0) };
        pcWeights = at[\pcWeights].();

        notes.do { |note|
            var pc, list, rep, noteWeight, repWeight;
            pc = note[\pc];
            list = pcGroups[pc] ? Array.new;
            list = list.add(note);
            pcGroups[pc] = list;
            rep = pcRepresentatives[pc];
            noteWeight = at[\pcWeightForNote].(note);
            repWeight = if(rep.isNil) { -1.0 } { at[\pcWeightForNote].(rep) };

            if(rep.isNil or: { noteWeight > repWeight }) {
                pcRepresentatives[pc] = note;
            };

            if(strongest.isNil or: { noteWeight > at[\pcWeightForNote].(strongest) }) {
                strongest = note;
            };
        };

        st[\soundingState] = (
            notes: notes,
            noteCount: notes.size,
            activeMidis: notes.collect { |n| n[\midi] },
            activePcs: pcGroups.keys.asArray.sort,
            pcWeights: pcWeights,
            pcGroups: pcGroups,
            pcRepresentatives: pcRepresentatives,
            strongestNote: strongest,
            onsetOrderedNotes: onsetOrdered
        );
        st[\soundingState]
    };

    at[\diagnosticActiveSetKey] = { |activePcs|
        (activePcs ? Array.new).asArray.collect { |pc| pc.asInteger }.sort.asString
    };

    at[\stableDiagnosticRootPc] = { |activePcs, weights|
        var pcs, rootMemory, key, remembered, previous, chosen;
        pcs = (activePcs ? Array.new).asArray.collect { |pc| pc.asInteger }.sort;
        if(pcs.isEmpty) {
            nil
        } {
            rootMemory = st[\diagnosticRootByActiveSet];
            if(rootMemory.isNil) {
                rootMemory = Dictionary.new;
                st[\diagnosticRootByActiveSet] = rootMemory;
            };
            key = at[\diagnosticActiveSetKey].(pcs);
            remembered = rootMemory[key];
            previous = if(st[\currentWorld].notNil) { st[\currentWorld][\anchorPc] } { nil };
            chosen = nil;

            // Root-label hysteresis: the same active pitch-class set keeps the same
            // diagnostic root even if duplicate octaves temporarily change pc weight.
            if(remembered.notNil and: { pcs.includes(remembered) }) {
                chosen = remembered;
            };
            if(chosen.isNil and: { previous.notNil and: { pcs.includes(previous) } }) {
                chosen = previous;
            };
            if(chosen.isNil) {
                chosen = at[\strongestPc].(pcs, weights ? Array.fill(12, 0.0));
            };
            if(chosen.isNil) {
                chosen = pcs[0];
            };

            rootMemory[key] = chosen;
            st[\diagnosticRootLastPc] = chosen;
            chosen
        }
    };

    at[\worldFromLegacyField] = { |source=\legacyField, referenceWorld=nil, pcWeightsArg=nil, activePcsArg=nil|
        var world, weights, activePcs, ref, anchorPc, phase, abs;
        world = at[\makeWorld].(source);
        weights = pcWeightsArg ? at[\pcWeights].();
        activePcs = activePcsArg ? at[\activePcsFromWeights].(weights);
        ref = referenceWorld ? st[\currentWorld] ? st[\restWorld] ? st[\previousCurrentWorld];

        12.do { |i|
            phase = (st[\nodePhase] ? st[\etPhase])[i];
            abs = if(ref.notNil) {
                at[\rebaseAbsNearReference].(phase, (ref[\absPhaseByPc] ? st[\etPhase])[i])
            } {
                phase
            };
            world[\phaseByPc][i] = at[\wrap01].(phase);
            world[\absPhaseByPc][i] = abs;
            world[\weightByPc][i] = weights[i] ? 0.0;
            world[\pcSet][i] = 0;
        };

        activePcs.do { |pc|
            world[\pcSet][pc] = 1;
        };

        anchorPc = st[\soleAnchorPc];
        if(anchorPc.isNil and: { activePcs.notEmpty }) {
            anchorPc = at[\stableDiagnosticRootPc].(activePcs, weights);
        };
        world[\anchorPc] = anchorPc;
        if(anchorPc.notNil) {
            world[\anchorAbsPhase] = world[\absPhaseByPc][anchorPc];
        };
        world[\confidence] = if(activePcs.notEmpty) { 1.0 } { if(st[\frozenValid] == true) { 0.7 } { 0.0 } };
        at[\normalizeWorld].(world)
    };

    at[\activeAbsMapForWorld] = { |world, activePcs|
        var out;
        out = IdentityDictionary.new;
        if(world.notNil) {
            (activePcs ? Array.new).do { |pc|
                out[pc] = (world[\absPhaseByPc] ? st[\etPhase])[pc];
            };
        };
        out
    };

    at[\anchorDevCentsForWorld] = { |world|
        var pc;
        if(world.isNil) {
            nil
        } {
            pc = world[\anchorPc];
            if(pc.isNil) {
                nil
            } {
                at[\wrapSigned].((world[\phaseByPc] ? st[\etPhase])[pc] - st[\etPhase][pc]) * 1200.0
            }
        }
    };

    at[\pairDeviationListForWorld] = { |world, activePcs|
        var pcs, out;
        out = Array.new;
        pcs = (activePcs ? Array.new).asArray.collect { |pc| pc.asInteger }.sort;
        if(world.notNil) {
            pcs.do { |pcA, i|
                if(i < (pcs.size - 1)) {
                    ((i + 1) .. (pcs.size - 1)).do { |j|
                        var pcB, interval, actual, best, dev;
                        pcB = pcs[j];
                        interval = (pcB - pcA) % 12;
                        actual = at[\wrapSigned].((world[\phaseByPc] ? st[\etPhase])[pcB] - (world[\phaseByPc] ? st[\etPhase])[pcA]);
                        best = if(at[\bestChoiceFor].notNil) { at[\bestChoiceFor].(actual, interval) } { [interval / 12.0, 1.0] };
                        dev = at[\wrapSigned].(actual - best[0]) * 1200.0;
                        out = out.add(pcNames.wrapAt(pcA) ++ "->" ++ pcNames.wrapAt(pcB) ++ "=" ++ dev.round(0.01).asString);
                    };
                };
            };
        };
        out
    };

    at[\syncWorldMirrorsFromLegacy] = { |reason=\manual|
        var sounding, weights, activePcs, ref, current, previous, pairList, currentAbsMap, evidenceAbsMap, anchorPc, rootName, activeMidis;
        sounding = at[\buildSoundingState].();
        weights = sounding[\pcWeights] ? at[\pcWeights].();
        activePcs = sounding[\activePcs] ? at[\activePcsFromWeights].(weights);
        activeMidis = sounding[\activeMidis] ? Array.new;
        ref = st[\currentWorld] ? st[\restWorld] ? st[\previousCurrentWorld];
        previous = st[\currentWorld];
        current = at[\worldFromLegacyField].(reason, ref, weights, activePcs);

        if(previous.notNil) {
            st[\previousCurrentWorld] = at[\copyWorld].(previous);
        };
        st[\currentWorld] = at[\copyWorld].(current);
        st[\evidenceWorld] = at[\copyWorld].(current);
        st[\targetWorld] = at[\copyWorld].(current);
        if(activePcs.isEmpty) {
            st[\restWorld] = at[\copyWorld].(current);
        };

        st[\activeVoiceMidis] = activeMidis.copy;
        st[\renderedVoiceMidis] = activeMidis.copy;
        st[\runtimeRunning] = false;

        pairList = at[\pairDeviationListForWorld].(current, activePcs);
        currentAbsMap = at[\activeAbsMapForWorld].(current, activePcs);
        evidenceAbsMap = at[\activeAbsMapForWorld].(st[\evidenceWorld], activePcs);
        anchorPc = current[\anchorPc];
        rootName = if(anchorPc.isNil) { nil } { pcNames.wrapAt(anchorPc) };

        st[\legacyMirrorFields] = (
            runtimeRunning: false,
            currentAnchorAbsPhase: if(anchorPc.isNil) { nil } { current[\absPhaseByPc][anchorPc] },
            evidenceAnchorAbsPhase: if(anchorPc.isNil) { nil } { st[\evidenceWorld][\absPhaseByPc][anchorPc] },
            currentAnchorDevCents: at[\anchorDevCentsForWorld].(current),
            evidenceAnchorDevCents: at[\anchorDevCentsForWorld].(st[\evidenceWorld]),
            currentActivePcAbsPhases: currentAbsMap,
            evidenceActivePcAbsPhases: evidenceAbsMap,
            evidenceActivePairIntervals: pairList.copy,
            lastSolveMode: st[\stateLabel],
            lastSolveRootName: rootName,
            lastSolveChoiceLabels: pairList.copy,
            lastSolvePairCost: 0.0,
            lastSolveContinuityCost: 0.0,
            lastSolveTransportCost: 0.0,
            lastSolveRootTrailBonus: 0.0,
            lastSolveRelationalBonus: 0.0,
            lastSolvePseudoAbsCost: 0.0,
            lastSolvePseudoPairCost: 0.0,
            lastSolveActiveMaxDeviationCents: (pairList.collect { |item| item.asString.split($=).last.asFloat.abs }.maxItem) ? 0.0,
            lastSolveCoveredSolvePcs: activePcs.copy,
            lastSolveMissingActiveSolvePcs: Array.new,
            lastSolveFinalActivePairDeviationByPair: pairList.copy,
            lastSolveNewestActivePairDeviationByPair: pairList.copy,
            recentTrailPcs: nil,
            recentTrailWeights: nil,
            recentOnsetPcs: activePcs.copy,
            recentOnsetWeights: currentAbsMap.copy,
            recentOnsetPreferredAbs: currentAbsMap.copy,
            pseudoOnsetPcs: Array.new,
            lastGaugeCarry: st[\lastGaugeCarry],
            lastGaugeCarryCents: if(st[\lastGaugeCarry].isNil) { nil } { st[\lastGaugeCarry][\cents] },
            lastSolveTotal: 0.0,
            lastSolveCandidateCount: if(activePcs.isEmpty) { 0 } { 1 }
        );
        st[\legacyMirrorFields]
    };

    at[\syncWorldSnapshotFieldsInto] = { |snap|
        var fields;
        fields = st[\legacyMirrorFields] ? at[\syncWorldMirrorsFromLegacy].(\snapshot);
        fields.keysValuesDo { |k, v|
            snap[k] = v;
        };
        snap
    };

    "[at-world] mirror diagnostics loaded; legacy nodePhase remains authoritative".postln;
};
)
