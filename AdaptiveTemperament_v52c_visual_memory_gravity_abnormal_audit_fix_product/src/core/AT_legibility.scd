(
// AT_legibility.scd
// Advanced reports, performer gestures, authority presets, and demo diagnostics.
// This file does not alter the solver. It makes the existing instrument easier
// to inspect, control, compare, and demonstrate.
var build, at, cfg, st, api, diag, ui, pcNames;

build = ~atBuild;
if(build.isNil) {
    "[at-legibility] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pcNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    at[\pcName] = { |pc|
        pcNames.wrapAt((pc ? 0).asInteger % 12) ? (pc ? "?").asString
    };

    at[\pcFromName] = { |name|
        var s, idx;
        if(name.isKindOf(Number)) { name.asInteger.clip(0, 11) } {
            s = name.asString.toLower;
            idx = ["c", "c#", "d", "eb", "e", "f", "f#", "g", "ab", "a", "bb", "b"].indexOf(s);
            if(idx.isNil) {
                idx = ["c", "db", "d", "d#", "e", "f", "gb", "g", "g#", "a", "a#", "b"].indexOf(s);
            };
            if(idx.isNil) { 0 } { idx };
        }
    };

    at[\ratioLabelForChoice] = { |semitones, choiceIndex=0|
        var labels;
        labels = [
            ["1:1"],
            ["16:15", "25:24"],
            ["9:8", "10:9"],
            ["6:5", "7:6"],
            ["5:4", "81:64"],
            ["4:3"],
            ["45:32", "64:45", "tritone-alt"],
            ["3:2"],
            ["8:5", "5:3"],
            ["5:3", "27:16"],
            ["9:5", "16:9", "7:4"],
            ["15:8"]
        ];
        (labels.wrapAt(semitones.asInteger % 12) ? ["?"]).wrapAt(choiceIndex ? 0)
    };

    at[\bestHarmonicInterval] = { |pcA, pcB|
        var semis, choices, actual, best, bestIdx, bestDev, i, phase, dev;
        semis = ((pcB - pcA) % 12).asInteger;
        choices = at[\ratioChoices].wrapAt(semis) ? [[semis / 12.0, 0.1]];
        actual = at[\wrapSigned].(st[\nodePhase][pcB] - st[\nodePhase][pcA]);
        if(actual < 0.0) { actual = actual + 1.0; };
        best = choices[0];
        bestIdx = 0;
        bestDev = 9999.0;
        i = 0;
        choices.do { |ch|
            phase = ch[0];
            dev = at[\wrapSigned].(actual - phase).abs;
            if(dev < bestDev) {
                best = ch;
                bestIdx = i;
                bestDev = dev;
            };
            i = i + 1;
        };
        (
            fromPc: pcA,
            toPc: pcB,
            fromName: at[\pcName].(pcA),
            toName: at[\pcName].(pcB),
            semitones: semis,
            ratio: at[\ratioLabelForChoice].(semis, bestIdx),
            targetCents: (best[0] * 1200.0).round(0.01),
            actualCents: (actual * 1200.0).round(0.01),
            deviationCents: (at[\wrapSigned].(actual - best[0]) * 1200.0).round(0.01),
            simplicity: (best[1] ? 0.0).round(0.001)
        )
    };

    api[\harmonicLawReport] = {
        var weights, activePcs, notes, activeSources, intervalPressures, pcs, i, j, noteForPc, rep, transport;
        weights = at[\pcWeights].();
        activePcs = at[\activePcsFromWeights].(weights);
        notes = at[\notesArray].();
        activeSources = Array.new;
        activePcs.do { |pc|
            noteForPc = nil;
            notes.do { |n|
                if(n[\pc] == pc) {
                    if(noteForPc.isNil or: { (n[\midi] ? 999) < (noteForPc[\midi] ? 999) }) { noteForPc = n; };
                };
            };
            activeSources = activeSources.add((
                pc: pc,
                pcName: at[\pcName].(pc),
                midi: if(noteForPc.isNil) { nil } { noteForPc[\midi] },
                weight: (weights[pc] ? 0.0).round(0.001),
                bassAuthority: if(noteForPc.isNil) { 0.0 } { ((96.0 - (noteForPc[\midi] ? 60)) / 60.0).clip(0.05, 1.0).round(0.001) },
                currentDevCents: (at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0).round(0.01)
            ));
        };
        intervalPressures = Array.new;
        pcs = activePcs.sort;
        i = 0;
        while { i < pcs.size } {
            j = i + 1;
            while { j < pcs.size } {
                var pcA, pcB, best, strength;
                pcA = pcs[i];
                pcB = pcs[j];
                best = at[\bestHarmonicInterval].(pcA, pcB);
                strength = (((weights[pcA] ? 0.0) * (weights[pcB] ? 0.0)).sqrt * (best[\simplicity] ? 0.0)).clip(0.0, 1.0);
                best[\pressureStrength] = strength.round(0.001);
                intervalPressures = intervalPressures.add(best);
                j = j + 1;
            };
            i = i + 1;
        };
        transport = st[\lastCoreTransport];
        rep = (
            activePcs: activePcs,
            activeSources: activeSources,
            intervalPressures: intervalPressures,
            lastCoreTransport: transport,
            coreTransportHistorySize: (st[\coreTransportHistory] ? Array.new).size,
            principle: "active notes create pressure; silent notes respond; lower notes have more authority; simple ratios dominate; non-closing paths transport when stabilizers are absent"
        );
        "".postln;
        "[AT HARMONIC LAW REPORT]".postln;
        ("activeSources=" ++ activeSources.asString).postln;
        ("intervalPressures=" ++ intervalPressures.asString).postln;
        ("lastCoreTransport=" ++ transport.asString).postln;
        rep
    };

    api[\roughnessReport] = {
        var weights, pcs, pairReports, roughness, i, j, rep;
        weights = at[\pcWeights].();
        pcs = at[\activePcsFromWeights].(weights).sort;
        pairReports = Array.new;
        roughness = 0.0;
        i = 0;
        while { i < pcs.size } {
            j = i + 1;
            while { j < pcs.size } {
                var best, pairWeight, devNorm, complexity, estimate;
                best = at[\bestHarmonicInterval].(pcs[i], pcs[j]);
                pairWeight = (((weights[pcs[i]] ? 0.0) * (weights[pcs[j]] ? 0.0)).sqrt).clip(0.0, 1.0);
                devNorm = ((best[\deviationCents] ? 0.0).abs / 35.0).clip(0.0, 4.0);
                complexity = (1.0 - (best[\simplicity] ? 0.0)).clip(0.0, 1.0);
                estimate = pairWeight * (devNorm + (0.35 * complexity));
                best[\roughnessEstimate] = estimate.round(0.001);
                pairReports = pairReports.add(best);
                roughness = roughness + estimate;
                j = j + 1;
            };
            i = i + 1;
        };
        rep = (
            activePcs: pcs,
            roughnessEstimate: roughness.round(0.001),
            pairs: pairReports,
            note: "diagnostic proxy only: useful for comparison/ablation, not the master tuning law"
        );
        "".postln;
        "[AT ROUGHNESS REPORT]".postln;
        rep.postln;
        rep
    };

    api[\conflictReport] = {
        var harm, rough, authority, worst, rep;
        harm = api[\harmonicLawReport].();
        rough = api[\roughnessReport].();
        authority = if(api[\authorityReport].notNil) { api[\authorityReport].() } { (inhibition: 0.0, freedom: 1.0) };
        worst = nil;
        (harm[\intervalPressures] ? Array.new).do { |p|
            if(worst.isNil or: { (p[\deviationCents] ? 0.0).abs > (worst[\deviationCents] ? 0.0).abs }) { worst = p; };
        };
        rep = (
            worstInterval: worst,
            roughnessEstimate: rough[\roughnessEstimate],
            authority: authority,
            gravity: if(api[\gravityReport].notNil) { api[\gravityReport].() } { nil },
            memoryValid: st[\memoryValid] ? false,
            memoryConfidence: (st[\memoryConfidence] ? 0.0).round(0.001),
            memoryAmount: (st[\memoryAmount] ? 0.0).round(0.001),
            micPolicy: cfg[\mic][\influencePolicy] ? \externalOnly,
            externalCount: ((st[\externalSources] ? Array.new).size)
        );
        "".postln;
        "[AT CONFLICT REPORT]".postln;
        rep.postln;
        rep
    };

    api[\motionReport] = {
        var dev, targetDev, maxDev, maxTargetDev, maxDelta, maxMotion, cDev, cSheet, rep;
        dev = at[\devArray].().collect { |x| x * 1200.0 };
        targetDev = (st[\targetPhase] ? st[\nodePhase]).collect { |p, i| at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0 };
        maxDev = (dev.collect { |x| x.abs }.maxItem) ? 0.0;
        maxTargetDev = (targetDev.collect { |x| x.abs }.maxItem) ? 0.0;
        maxDelta = ((st[\lastDelta] ? Array.new).collect { |x| (x ? 0.0).abs }.maxItem ? 0.0) * 1200.0;
        maxMotion = ((st[\nodeMotion] ? Array.new).collect { |x| (x ? 0.0).abs }.maxItem ? 0.0) * 1200.0;
        cDev = at[\wrapSigned].(st[\nodePhase][0] - st[\etPhase][0]) * 1200.0;
        cSheet = (((st[\coreUnwrappedPhase] ? st[\nodePhase])[0] ? st[\nodePhase][0]) - st[\etPhase][0]) * 1200.0;
        rep = (
            maxCurrentDevCents: maxDev.round(0.01),
            maxTargetDevCents: maxTargetDev.round(0.01),
            maxLastDeltaCents: maxDelta.round(0.01),
            maxNodeMotionCents: maxMotion.round(0.01),
            currentCDeviationCents: cDev.round(0.01),
            currentCSheetCents: cSheet.round(0.01),
            motionActive: st[\motionActive] ? false,
            movementFreedom: st[\movement] ? 0.0,
            lastCoreTransport: st[\lastCoreTransport],
            lastGaugeCarry: st[\lastGaugeCarry],
            authority: if(at[\coreAuthoritySnapshot].notNil) { at[\coreAuthoritySnapshot].() } { nil }
        );
        "".postln;
        "[AT MOTION REPORT]".postln;
        rep.postln;
        rep
    };

    api[\memoryReport] = {
        var memDev, rep;
        memDev = (st[\memoryPhase] ? st[\etPhase]).collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) };
        rep = (
            enabled: cfg[\memory][\enabled] ? true,
            amount: (st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0)).round(0.001),
            learningRate: (cfg[\memory][\learningRate] ? 0.0).round(0.001),
            valid: st[\memoryValid] ? false,
            confidence: (st[\memoryConfidence] ? 0.0).round(0.001),
            lastDistanceCents: if(st[\memoryLastDistance].isNil) { nil } { (st[\memoryLastDistance] * 1200.0).round(0.01) },
            lastInfluence: (st[\memoryLastInfluence] ? 0.0).round(0.001),
            lastLearnRate: (st[\memoryLastLearnRate] ? 0.0).round(0.001),
            lastReason: st[\memoryLastReason],
            devCents: memDev,
            supportCounts: (st[\memorySupportCounts] ? Array.new).copy,
            note: "memory is earned stabilizing authority; clearing memory does not erase the current field body"
        );
        "".postln;
        "[AT MEMORY REPORT]".postln;
        rep.postln;
        rep
    };

    api[\seedMemoryFromCurrent] = { |confidence=1.0|
        st[\memoryPhase] = (st[\nodePhase] ? st[\etPhase]).copy;
        st[\memoryValid] = true;
        st[\memoryConfidence] = confidence.asFloat.clip(0.0, 1.0);
        st[\memoryLastReason] = \seedFromCurrent;
        st[\memoryLastUpdateAt] = Main.elapsedTime;
        api[\memoryReport].();
    };

    api[\resetField] = { api[\reset].(); };
    api[\clearMemory] = { api[\clearTonalMemory].(); api[\memoryReport].(); };
    api[\freezeWorld] = {
        if(at[\freezeCurrentField].notNil) { at[\freezeCurrentField].(); } { api[\freezeField].(); };
        api[\refreshUISnapshot].();
        api[\fieldReport].();
    };
    api[\releaseWorld] = {
        st[\fieldFrozen] = false;
        st[\lastFieldAction] = \releaseWorld;
        st[\targetValid] = false;
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\releaseWorld); };
        api[\refreshUISnapshot].();
        api[\fieldReport].();
    };

    api[\setAnchorToNote] = { |pc=0, cents=0.0, enable=true|
        var p;
        p = at[\pcFromName].(pc);
        if(api[\setGravityHome].notNil) { api[\setGravityHome].(p, cents.asFloat); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(enable.asBoolean); };
        if(api[\gravityReport].notNil) { api[\gravityReport].() } { (homePc: p, homeCents: cents) };
    };

    api[\setAnchorToCurrent] = { |pc=nil, enable=true|
        var p, weights, pcs, cents;
        weights = at[\pcWeights].();
        pcs = at[\activePcsFromWeights].(weights);
        p = if(pc.isNil) {
            if(pcs.isEmpty) { 0 } {
                var bestPc, bestWeight;
                bestPc = pcs[0];
                bestWeight = weights[bestPc] ? 0.0;
                pcs.do { |x| if((weights[x] ? 0.0) > bestWeight) { bestPc = x; bestWeight = weights[x] ? 0.0; }; };
                bestPc
            }
        } { at[\pcFromName].(pc) };
        cents = at[\wrapSigned].(st[\nodePhase][p] - st[\etPhase][p]) * 1200.0;
        api[\setAnchorToNote].(p, cents, enable);
    };

    api[\clearGravity] = {
        if(at[\clearGravity].notNil) { at[\clearGravity].(); };
        if(api[\gravityReport].notNil) { api[\gravityReport].() } { nil };
    };

    api[\applyAuthorityPreset] = { |preset=\humanStable|
        var p;
        p = preset.asSymbol;
        if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
        case
        { p == \fishCoreDiagnostic } {
            api[\setMicEnabled].(false);
            api[\setMemoryAmount].(0.0);
            cfg[\memory][\enabled] = false;
            api[\clearTonalMemory].();
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); };
            api[\setWorldScoringEnabled].(false);
            cfg[\phrase][\enabled] = false;
            cfg[\coreFreedom] = cfg[\coreFreedom] ? IdentityDictionary.new;
            cfg[\coreFreedom][\heldGuardsEnabled] = false;
            api[\setContextGaugeEnabled].(false);
            api[\setMovement].(1.0);
            api[\setTension].(0.55);
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.0); };
            if(api[\setPerceptualSpectrumAmount].notNil) { api[\setPerceptualSpectrumAmount].(0.0); };
        }
        { p == \humanStable } {
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(0.82);
            api[\setMemoryLearnRate].(0.035);
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
            if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(0.48); };
            if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(8.0); };
            api[\setWorldScoringEnabled].(true);
            api[\setWorldScoringBlend].(0.34);
            cfg[\phrase][\enabled] = true;
            cfg[\coreFreedom] = cfg[\coreFreedom] ? IdentityDictionary.new;
            cfg[\coreFreedom][\heldGuardsEnabled] = true;
            api[\setContextGaugeEnabled].(true);
            api[\setContextGaugeStrength].(0.42);
            api[\setContextGaugeMaxCents].(8.0);
            api[\setMovement].(0.34);
            api[\setTension].(0.38);
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\coherenceBloom); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.25); };
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.22); };
        }
        { p == \highInertia } {
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(1.0);
            api[\seedMemoryFromCurrent].(1.0);
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
            if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(1.0); };
            if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(20.0); };
            api[\setWorldScoringEnabled].(true);
            api[\setWorldScoringBlend].(0.55);
            cfg[\phrase][\enabled] = true;
            cfg[\coreFreedom] = cfg[\coreFreedom] ? IdentityDictionary.new;
            cfg[\coreFreedom][\heldGuardsEnabled] = true;
            api[\setContextGaugeEnabled].(false);
            api[\setMovement].(0.12);
            api[\setTension].(0.25);
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.12); };
        }
        { p == \pureReference } {
            api[\setMicEnabled].(false);
            api[\setMemoryAmount].(0.0);
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); };
            api[\setWorldScoringEnabled].(false);
            cfg[\phrase][\enabled] = false;
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\pure); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.0); };
            if(api[\setPerceptualSpectrumAmount].notNil) { api[\setPerceptualSpectrumAmount].(0.0); };
        }
        { p == \gravityOrgan } {
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\organ); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\coherenceBloom); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.4); };
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(0.48);
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
            if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(0.42); };
            if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(9.0); };
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.24); };
        }
        { p == \listeningPad } {
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\pad); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.55); };
            api[\setMicEnabled].(true);
            api[\setMicMode].(\polyPc);
            api[\setMicInfluencePolicy].(\duetSafe);
            api[\setMicWeight].(0.45);
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(0.50);
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.34); };
        }
        { p == \micDuet } {
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\electricPiano); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.45); };
            api[\setMicEnabled].(true);
            api[\setMicMode].(\polyPc);
            api[\setMicInfluencePolicy].(\duetSafe);
            api[\setMicWeight].(0.55);
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(0.58);
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.30); };
        }
        { p == \perceptualBlend } {
            // Practical mixed-world preset: useful when playing with equal-
            // tempered instruments. It does not blindly follow the loudest note;
            // it gives the whole-sonority perceptual layer moderate authority.
            cfg[\memory][\enabled] = true;
            api[\setMemoryAmount].(0.45);
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); };
            api[\setWorldScoringEnabled].(true);
            api[\setWorldScoringBlend].(0.24);
            cfg[\phrase][\enabled] = true;
            api[\setContextGaugeEnabled].(true);
            api[\setContextGaugeStrength].(0.32);
            api[\setMovement].(0.58);
            api[\setTension].(0.42);
            if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.42); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\coherenceBloom); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.32); };
        }
        { true } {
            p = \humanStable;
            api[\applyAuthorityPreset].(p);
        };
        st[\lastAuthorityPreset] = p;
        api[\refreshUISnapshot].();
        "".postln;
        ("[AT PRESET] applied " ++ p.asString).postln;
        api[\authorityReport].();
    };

    at[\demos] = at[\demos] ? IdentityDictionary.new;

    at[\demos][\fishDiminishedTransport] = { |audible=false|
        var path, cBefore, cAfter, rep;
        api[\applyAuthorityPreset].(\fishCoreDiagnostic);
        at[\resetToET].();
        at[\pushBuses].();
        path = [60, 63, 66, 69, 72];
        cBefore = at[\wrapSigned].(st[\nodePhase][0] - st[\etPhase][0]) * 1200.0;
        path.do { |m|
            at[\noteOn].(m, 0.9, nil, audible.not);
            api[\resolveNow].(\demoFishOn);
            at[\noteOff].(m);
            api[\resolveNow].(\demoFishOff);
        };
        cAfter = at[\wrapSigned].(st[\nodePhase][0] - st[\etPhase][0]) * 1200.0;
        rep = (demo: \fishDiminishedTransport, beforeCents: cBefore.round(0.01), afterCents: cAfter.round(0.01), expected: "+62.57c upward for one ascending diminished cycle", lastCoreTransport: st[\lastCoreTransport]);
        "".postln; "[AT DEMO] fishDiminishedTransport".postln; rep.postln; rep
    };

    at[\demos][\memoryVsNoMemory] = { |audible=false|
        var free, inhibited, rep;
        free = at[\demos][\fishDiminishedTransport].(audible);
        api[\applyAuthorityPreset].(\highInertia);
        at[\resetToET].();
        api[\seedMemoryFromCurrent].(1.0);
        [60, 63, 66, 69, 72].do { |m|
            at[\noteOn].(m, 0.9, nil, audible.not);
            api[\resolveNow].(\demoInhibitedOn);
            at[\noteOff].(m);
            api[\resolveNow].(\demoInhibitedOff);
        };
        inhibited = at[\wrapSigned].(st[\nodePhase][0] - st[\etPhase][0]) * 1200.0;
        rep = (demo: \memoryVsNoMemory, freeCents: free[\afterCents], highInertiaCents: inhibited.round(0.01), note: "high inertia intentionally inhibits the same raw path");
        "".postln; "[AT DEMO] memoryVsNoMemory".postln; rep.postln; rep
    };

    api[\runDemo] = { |name=\fishDiminishedTransport, audible=false|
        var n;
        n = name.asSymbol;
        if(at[\demos][n].isNil) {
            ("[AT DEMO] unknown demo " ++ n.asString ++ "; available=" ++ at[\demos].keys.asArray.asString).warn;
            nil
        } {
            at[\demos][n].(audible);
        }
    };

    at[\harmonicLawReport] = { api[\harmonicLawReport].() };
    at[\roughnessReport] = { api[\roughnessReport].() };
    at[\conflictReport] = { api[\conflictReport].() };
    at[\motionReport] = { api[\motionReport].() };
    at[\memoryReport] = { api[\memoryReport].() };
    at[\resetField] = { api[\resetField].() };
    at[\freezeWorld] = { api[\freezeWorld].() };
    at[\releaseWorld] = { api[\releaseWorld].() };
    at[\clearMemory] = { api[\clearMemory].() };
    at[\setAnchorToCurrent] = { |pc=nil, enable=true| api[\setAnchorToCurrent].(pc, enable) };
    at[\setAnchorToNote] = { |pc=0, cents=0.0, enable=true| api[\setAnchorToNote].(pc, cents, enable) };
    at[\applyAuthorityPreset] = { |preset=\humanStable| api[\applyAuthorityPreset].(preset) };
    at[\runDemo] = { |name=\fishDiminishedTransport, audible=false| api[\runDemo].(name, audible) };

    "[at-legibility] advanced reports, gestures, presets, and demos loaded".postln;
};
)
