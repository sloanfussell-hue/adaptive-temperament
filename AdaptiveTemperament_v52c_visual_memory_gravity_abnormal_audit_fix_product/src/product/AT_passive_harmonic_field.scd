(
// AT_passive_harmonic_field.scd
// v3D41: register/velocity harmonic-chart authority + active-state-arbitrated playable surface.
//
// Fundamental rule:
//   active notes are pressure sources; silent notes are passive responders.
//   Every active evidence state generates a complete 12-note harmonic world.
//
// A single active note is not "no harmony". It is a harmonic origin. When a
// monophonic arpeggio returns to one note, the whole silent keyboard surface
// must reflect the harmonic world of that one remaining note, on its current
// transported sheet. Dyads settle as stable interval worlds; 3+ contexts keep
// weighted negotiation where register/velocity/age matter. v3D34 adds the
// missing invariant that the harmonic world itself must be an ordered, playable
// 12-note surface before the emergency spacing guard verifies it. v3D36 added
// one-chart polyphony. v3D41 makes the chart authority explicit: low register
// and high velocity can make a non-root active note become the chord-local
// harmonic chart anchor, like an inversion/slash-chord authority, without
// becoming key detection, global recentering, or pitch authority.

var build, at, cfg, st, api, names;

build = ~atBuild;
if(build.isNil) {
    "[AT PASSIVE HARMONIC FIELD] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    names = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    cfg[\passiveHarmonicField] = cfg[\passiveHarmonicField] ? IdentityDictionary.new;
    cfg[\passiveHarmonicField][\enabled] = cfg[\passiveHarmonicField][\enabled] ? true;
    cfg[\passiveHarmonicField][\singleOriginEnabled] = cfg[\passiveHarmonicField][\singleOriginEnabled] ? true;
    cfg[\passiveHarmonicField][\dyadLockEnabled] = cfg[\passiveHarmonicField][\dyadLockEnabled] ? true;
    cfg[\passiveHarmonicField][\polyCompletionEnabled] = cfg[\passiveHarmonicField][\polyCompletionEnabled] ? true;
    cfg[\passiveHarmonicField][\singleBlend] = cfg[\passiveHarmonicField][\singleBlend] ? 1.0;
    cfg[\passiveHarmonicField][\dyadBlend] = cfg[\passiveHarmonicField][\dyadBlend] ? 1.0;
    cfg[\passiveHarmonicField][\polyPassiveBlend] = cfg[\passiveHarmonicField][\polyPassiveBlend] ? 0.72;
    cfg[\passiveHarmonicField][\passiveMovedEpsCents] = cfg[\passiveHarmonicField][\passiveMovedEpsCents] ? 0.25;
    cfg[\passiveHarmonicField][\printReports] = cfg[\passiveHarmonicField][\printReports] ? true;
    cfg[\passiveHarmonicField][\completeWorldProjection] = true;
    cfg[\passiveHarmonicField][\authoritativeActiveStateWorld] = true;
    cfg[\passiveHarmonicField][\bypassFrozenSingleContinuity] = cfg[\passiveHarmonicField][\bypassFrozenSingleContinuity] ? true;
    cfg[\passiveHarmonicField][\orderedPlayableSurfaceEnabled] = cfg[\passiveHarmonicField][\orderedPlayableSurfaceEnabled] ? true;
    cfg[\passiveHarmonicField][\surfaceProjectionPostReports] = cfg[\passiveHarmonicField][\surfaceProjectionPostReports] ? true;
    cfg[\passiveHarmonicField][\suppressCorePathInHeldContexts] = cfg[\passiveHarmonicField][\suppressCorePathInHeldContexts] ? true;
    cfg[\passiveHarmonicField][\samePcReinforcementSuppressesPath] = cfg[\passiveHarmonicField][\samePcReinforcementSuppressesPath] ? true;
    cfg[\passiveHarmonicField][\polySheetCoherenceEnabled] = cfg[\passiveHarmonicField][\polySheetCoherenceEnabled] ? true;
    cfg[\passiveHarmonicField][\polySheetCoherenceMaxDeviationCents] = cfg[\passiveHarmonicField][\polySheetCoherenceMaxDeviationCents] ? 42.0;
    cfg[\passiveHarmonicField][\polyLargeRepairWarnCents] = cfg[\passiveHarmonicField][\polyLargeRepairWarnCents] ? 120.0;
    cfg[\passiveHarmonicField][\polyChartSelectionEnabled] = cfg[\passiveHarmonicField][\polyChartSelectionEnabled] ? true;
    cfg[\passiveHarmonicField][\polyActiveBlend] = cfg[\passiveHarmonicField][\polyActiveBlend] ? 0.34;
    cfg[\passiveHarmonicField][\polyChartUsesSingleAnchor] = cfg[\passiveHarmonicField][\polyChartUsesSingleAnchor] ? true;
    cfg[\passiveHarmonicField][\polyChartTieWeightBonus] = cfg[\passiveHarmonicField][\polyChartTieWeightBonus] ? 0.75;
    cfg[\passiveHarmonicField][\registerVelocityChartEnabled] = cfg[\passiveHarmonicField][\registerVelocityChartEnabled] ? true;
    cfg[\passiveHarmonicField][\registerAuthority] = cfg[\passiveHarmonicField][\registerAuthority] ? 0.85;
    cfg[\passiveHarmonicField][\velocityAuthority] = cfg[\passiveHarmonicField][\velocityAuthority] ? 0.85;
    cfg[\passiveHarmonicField][\salienceBaseWeight] = cfg[\passiveHarmonicField][\salienceBaseWeight] ? 0.50;
    cfg[\passiveHarmonicField][\salienceContinuityWeight] = cfg[\passiveHarmonicField][\salienceContinuityWeight] ? 0.10;
    cfg[\passiveHarmonicField][\polyChartFitCostScale] = cfg[\passiveHarmonicField][\polyChartFitCostScale] ? 0.35;
    cfg[\passiveHarmonicField][\polyChartSalienceBonusCents] = cfg[\passiveHarmonicField][\polyChartSalienceBonusCents] ? 8.0;
    cfg[\passiveHarmonicField][\registerVelocityDecisionNote] = "Register and velocity select chord-local harmonic chart authority only; they do not detect key, mutate gravity/memory, or add pitch authority.";

    at[\phfActiveSet] = { |activePcs|
        var set;
        set = IdentitySet.new;
        (activePcs ? Array.new).do { |pc| set.add(pc.asInteger % 12); };
        set;
    };

    at[\phfCanonicalRel] = { |pcDistance|
        var choices, k;
        k = pcDistance.asInteger % 12;
        choices = at[\ratioChoices].wrapAt(k) ? [[k / 12.0, 0.1]];
        choices[0][0] ? (k / 12.0);
    };

    at[\phfSourceList] = { |activePcs, pcWeights, externalSources=nil|
        var sources;
        sources = Array.new;
        if(at[\ensureCoreUnwrapped].notNil) { at[\ensureCoreUnwrapped].(); };
        (activePcs ? Array.new).do { |pc|
            pc = pc.asInteger % 12;
            sources = sources.add((
                pc: pc,
                phase: st[\nodePhase][pc],
                unwrapped: ((st[\coreUnwrappedPhase] ? st[\nodePhase])[pc] ? st[\nodePhase][pc]),
                weight: ((pcWeights[pc] ? 0.0).max(0.05)).clip(0.05, 2.2),
                kind: \active
            ));
        };
        (externalSources ? Array.new).do { |src|
            if(src.notNil and: { src[\pc].notNil and: { src[\phase].notNil } }) {
                sources = sources.add((
                    pc: src[\pc].asInteger % 12,
                    phase: src[\phase],
                    unwrapped: src[\unwrapped] ? src[\phase],
                    weight: (((src[\weight] ? 0.0) * (src[\confidence] ? 1.0)).max(0.0)).clip(0.0, 1.5),
                    kind: src[\kind] ? \external
                ));
            };
        };
        sources.select { |src| (src[\weight] ? 0.0) > 0.000001 };
    };

    at[\phfCanonicalTargetUnwrapped] = { |targetPc, src|
        var srcPc, srcU, k, rel;
        srcPc = src[\pc].asInteger % 12;
        srcU = src[\unwrapped] ? (src[\phase] ? st[\nodePhase][srcPc]);
        k = (targetPc.asInteger - srcPc) % 12;
        rel = at[\phfCanonicalRel].(k);
        srcU + rel;
    };

    at[\phfCompleteWorldTargetForNode] = { |i, oldUnwrapped, sources, activeSet, activeLock=true|
        var sum, total, first, eps;
        if(activeLock and: { activeSet.includes(i) }) {
            oldUnwrapped[i]
        } {
            sum = 0.0;
            total = 0.0;
            first = nil;
            eps = 0.0000001;
            (sources ? Array.new).do { |src|
                var w, u;
                w = (src[\weight] ? 0.0).max(0.0);
                if(w > eps) {
                    u = at[\phfCanonicalTargetUnwrapped].(i, src);
                    if(first.isNil) { first = u } { u = first + at[\wrapSigned].(u - first) };
                    sum = sum + (u * w);
                    total = total + w;
                };
            };
            if(total > eps) { sum / total } { oldUnwrapped[i] };
        }
    };


    at[\fltClip] = { |x, lo, hi|
        x.max(lo).min(hi);
    };

    at[\fieldActivePcAlreadyHeld] = { |pc|
        var found;
        found = false;
        (st[\activeNotes] ? IdentityDictionary.new).values.do { |note|
            if(note.notNil and: { (note[\pc] ? -1).asInteger == (pc.asInteger % 12) }) { found = true; };
        };
        found;
    };

    at[\fieldSuppressPathReasonForOnset] = { |midi, pc, prevCount=0|
        var samePcHeld;
        samePcHeld = if(at[\fieldActivePcAlreadyHeld].notNil) { at[\fieldActivePcAlreadyHeld].(pc) } { false };
        if(((cfg[\passiveHarmonicField][\samePcReinforcementSuppressesPath] ? true) == true) and: { samePcHeld }) {
            \samePcReinforcementNoTransport
        } {
            if(((cfg[\passiveHarmonicField][\suppressCorePathInHeldContexts] ? true) == true) and: { (prevCount ? 0) > 0 }) {
                \heldContextSuppressesCorePath
            } {
                nil
            }
        }
    };

    at[\fieldNoTransportOnsetRecord] = { |midi, pc, reason=\pathSuppressedByActiveState|
        var phase, desiredU, rec;
        if(at[\ensureCoreUnwrapped].notNil) { at[\ensureCoreUnwrapped].(); };
        phase = st[\nodePhase][pc];
        desiredU = (st[\coreUnwrappedPhase] ? st[\nodePhase])[pc] ? phase;
        rec = (
            timestamp: Main.elapsedTime,
            midi: midi,
            pc: pc,
            targetSigned: 0.0,
            audiblePhase: phase,
            desiredUnwrappedPhase: desiredU,
            audibleDevCents: at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0,
            sheetDevCents: (desiredU - st[\etPhase][pc]) * 1200.0,
            applied: false,
            reason: reason,
            note: "Path transport is a monophonic released-phrase behavior. Held contexts and same-PC reinforcement are active-state harmony, not transport."
        );
        st[\lastCoreTransport] = rec;
        st[\lastCorePathOnset] = (
            timestamp: Main.elapsedTime,
            midi: midi,
            pc: pc,
            phase: phase,
            unwrappedPhase: desiredU,
            pathSuppressedReason: reason
        );
        rec;
    };

    at[\phfWeightedActiveGauge] = { |phaseArr, activePcs, pcWeights|
        var sum, total, firstDev, eps;
        sum = 0.0;
        total = 0.0;
        firstDev = nil;
        eps = 0.0000001;
        (activePcs ? Array.new).do { |pc|
            var w, dev;
            pc = pc.asInteger % 12;
            w = ((pcWeights[pc] ? 0.0).max(0.05)).clip(0.05, 2.2);
            dev = at[\wrapSigned].((phaseArr[pc] ? st[\etPhase][pc]) - st[\etPhase][pc]);
            if(firstDev.isNil) { firstDev = dev } { dev = firstDev + at[\wrapSigned].(dev - firstDev) };
            sum = sum + (dev * w);
            total = total + w;
        };
        if(total > eps) { sum / total } { 0.0 };
    };


    at[\rvhcBuildWeightsForNotes] = { |notes|
        var weights, now;
        now = Main.elapsedTime;
        weights = Array.fill(cfg[\solver][\numNodes], { 0.0 });
        (notes ? Array.new).do { |note|
            var pc, n, w;
            pc = (note[\pc] ? (note[\midi] ? 0).asInteger).asInteger % 12;
            n = note.copy;
            n[\pc] = pc;
            n[\timestamp] = n[\timestamp] ? now;
            n[\onsetTime] = n[\onsetTime] ? now;
            w = if(at[\pcWeightForNote].notNil) { at[\pcWeightForNote].(n) } { (n[\velocity] ? 0.8).clip(0.05, 1.7) };
            weights[pc] = weights[pc] + w;
        };
        weights;
    };

    at[\rvhcActiveNoteStats] = { |activePcs=nil, pcWeights=nil, notesArg=nil|
        var notes, weights, pcs, rows, lowestMidi, highestMidi, highestVel, velSum, velCount, globalMeanVel;
        notes = if(notesArg.notNil) { notesArg } { at[\notesArray].() };
        weights = if(pcWeights.notNil) { pcWeights } { at[\pcWeights].() };
        pcs = if(activePcs.notNil) { activePcs } { at[\activePcsFromWeights].(weights) };
        rows = IdentityDictionary.new;
        lowestMidi = nil;
        highestMidi = nil;
        highestVel = 0.0;
        velSum = 0.0;
        velCount = 0;
        (pcs ? Array.new).do { |pc|
            pc = pc.asInteger % 12;
            rows[pc] = (
                pc: pc,
                pcName: names[pc],
                minMidi: nil,
                maxMidi: nil,
                maxVelocity: 0.0,
                velocitySum: 0.0,
                count: 0,
                baseWeight: ((weights[pc] ? 0.0).max(0.0)).round(0.001)
            );
        };
        (notes ? Array.new).do { |note|
            var pc, row, m, v;
            if(note.notNil) {
                pc = (note[\pc] ? (note[\midi] ? 0).asInteger).asInteger % 12;
                row = rows[pc];
                if(row.notNil) {
                    m = (note[\midi] ? 60).asFloat;
                    v = (note[\velocity] ? 0.0).asFloat.clip(0.0, 1.0);
                    if(row[\minMidi].isNil or: { m < row[\minMidi] }) { row[\minMidi] = m; };
                    if(row[\maxMidi].isNil or: { m > row[\maxMidi] }) { row[\maxMidi] = m; };
                    row[\maxVelocity] = (row[\maxVelocity] ? 0.0).max(v);
                    row[\velocitySum] = (row[\velocitySum] ? 0.0) + v;
                    row[\count] = (row[\count] ? 0) + 1;
                    if(lowestMidi.isNil or: { m < lowestMidi }) { lowestMidi = m; };
                    if(highestMidi.isNil or: { m > highestMidi }) { highestMidi = m; };
                    highestVel = highestVel.max(v);
                    velSum = velSum + v;
                    velCount = velCount + 1;
                };
            };
        };
        globalMeanVel = if(velCount > 0) { velSum / velCount } { 0.0 };
        (
            activePcs: pcs ? Array.new,
            rows: rows,
            lowestMidi: lowestMidi,
            highestMidi: highestMidi,
            highestVelocity: highestVel,
            meanVelocity: globalMeanVel
        )
    };

    at[\rvhcSalienceReport] = { |activePcs=nil, pcWeights=nil, notesArg=nil|
        var cfgp, weights, pcs, stats, rows, outRows, best, lowestMidi, highestMidi, highestVel, meanVel, report;
        cfgp = cfg[\passiveHarmonicField];
        weights = if(pcWeights.notNil) { pcWeights } { if(notesArg.notNil) { at[\rvhcBuildWeightsForNotes].(notesArg) } { at[\pcWeights].() } };
        pcs = if(activePcs.notNil) { activePcs } { at[\activePcsFromWeights].(weights) };
        stats = at[\rvhcActiveNoteStats].(pcs, weights, notesArg);
        rows = stats[\rows] ? IdentityDictionary.new;
        lowestMidi = stats[\lowestMidi];
        highestMidi = stats[\highestMidi];
        highestVel = stats[\highestVelocity] ? 0.0;
        meanVel = stats[\meanVelocity] ? 0.0;
        outRows = Array.new;
        (pcs ? Array.new).do { |pc|
            var row, minMidi, maxVel, baseWeight, registerComponent, velocityComponent, lowDepth, lowFlag, velLead, velExcess, continuity, salience;
            pc = pc.asInteger % 12;
            row = rows[pc] ? (pc: pc, pcName: names[pc], minMidi: nil, maxVelocity: 0.0, baseWeight: (weights[pc] ? 0.0));
            minMidi = row[\minMidi];
            maxVel = row[\maxVelocity] ? 0.0;
            baseWeight = row[\baseWeight] ? (weights[pc] ? 0.0);
            lowFlag = if(minMidi.notNil and: { lowestMidi.notNil and: { minMidi == lowestMidi } }) { 1.0 } { 0.0 };
            lowDepth = if(minMidi.notNil and: { highestMidi.notNil }) { ((highestMidi - minMidi) / 12.0).clip(0.0, 2.5) } { 0.0 };
            registerComponent = (lowFlag + lowDepth).clip(0.0, 3.0);
            velLead = if(highestVel > 0.000001) { (maxVel / highestVel).clip(0.0, 1.0) } { 0.0 };
            velExcess = ((maxVel - meanVel) / 0.35).clip(0.0, 1.0);
            velocityComponent = (velLead + velExcess + if(maxVel >= (highestVel - 0.000001) and: { highestVel > 0.000001 }) { 0.75 } { 0.0 }).clip(0.0, 2.75);
            continuity = if(st[\lastRegisterVelocityChartAnchorPc] == pc) { 1.0 } { 0.0 };
            salience = ((baseWeight * (cfgp[\salienceBaseWeight] ? 0.50))
                + (registerComponent * (cfgp[\registerAuthority] ? 0.85))
                + (velocityComponent * (cfgp[\velocityAuthority] ? 0.85))
                + (continuity * (cfgp[\salienceContinuityWeight] ? 0.10)));
            row[\registerComponent] = registerComponent.round(0.001);
            row[\velocityComponent] = velocityComponent.round(0.001);
            row[\salience] = salience.round(0.001);
            row[\isLowestRegister] = lowFlag > 0.5;
            row[\isHighestVelocity] = (maxVel >= (highestVel - 0.000001)) and: { highestVel > 0.000001 };
            outRows = outRows.add(row.copy);
        };
        outRows = outRows.sort { |a, b| (a[\salience] ? -999999.0) > (b[\salience] ? -999999.0) };
        best = if(outRows.isEmpty) { nil } { outRows[0] };
        report = (
            branch: \v3D41,
            enabled: cfgp[\registerVelocityChartEnabled] ? true,
            selectedAnchorPc: if(best.notNil) { best[\pc] } { nil },
            selectedAnchorName: if(best.notNil) { best[\pcName] } { nil },
            selectedSalience: if(best.notNil) { best[\salience] } { 0.0 },
            registerAuthority: cfgp[\registerAuthority] ? 0.85,
            velocityAuthority: cfgp[\velocityAuthority] ? 0.85,
            rows: outRows,
            chordLocalOnly: true,
            keyDetection: false,
            globalRecenter: false,
            pitchAuthorityAdded: false,
            note: cfgp[\registerVelocityDecisionNote]
        );
        st[\lastRegisterVelocityChartReport] = report;
        report;
    };

    at[\rvhcSalienceForPc] = { |pc, report=nil|
        var rows, found;
        rows = (report ? st[\lastRegisterVelocityChartReport] ? IdentityDictionary.new)[\rows] ? Array.new;
        found = nil;
        (rows ? Array.new).do { |row|
            if((row[\pc] ? -1).asInteger == (pc.asInteger % 12)) { found = row; };
        };
        if(found.notNil) { found[\salience] ? 0.0 } { 0.0 };
    };

    at[\rvhcPostReport] = { |report|
        var rows;
        rows = (report ? IdentityDictionary.new)[\rows] ? Array.new;
        "".postln;
        "[AT REGISTER/VELOCITY HARMONIC CHART]".postln;
        ("selected=" ++ ((report ? IdentityDictionary.new)[\selectedAnchorName] ? "nil").asString
            ++ " salience=" ++ ((report ? IdentityDictionary.new)[\selectedSalience] ? 0.0).asString
            ++ " registerAuthority=" ++ ((report ? IdentityDictionary.new)[\registerAuthority] ? 0.0).asString
            ++ " velocityAuthority=" ++ ((report ? IdentityDictionary.new)[\velocityAuthority] ? 0.0).asString
            ++ " chordLocalOnly=true keyDetection=false pitchAuthorityAdded=false").postln;
        rows.do { |row|
            ("pc=" ++ (row[\pcName] ? row[\pc]).asString
                ++ " salience=" ++ (row[\salience] ? 0.0).asString
                ++ " reg=" ++ (row[\registerComponent] ? 0.0).asString
                ++ " vel=" ++ (row[\velocityComponent] ? 0.0).asString
                ++ " minMidi=" ++ (row[\minMidi] ? "nil").asString
                ++ " maxVel=" ++ ((row[\maxVelocity] ? 0.0).round(0.001)).asString).postln;
        };
        report;
    };

    at[\rvhcSyntheticCase] = { |label, notes, expectedPc=nil, note=""|
        var weights, activePcs, report, selected, passed;
        notes = (notes ? Array.new).collect { |n|
            var nn;
            nn = n.copy;
            nn[\pc] = (nn[\pc] ? (nn[\midi] ? 0).asInteger).asInteger % 12;
            nn[\timestamp] = Main.elapsedTime;
            nn[\onsetTime] = Main.elapsedTime;
            nn;
        };
        weights = at[\rvhcBuildWeightsForNotes].(notes);
        activePcs = at[\activePcsFromWeights].(weights);
        report = at[\rvhcSalienceReport].(activePcs, weights, notes);
        selected = report[\selectedAnchorPc];
        passed = if(expectedPc.isNil) { true } { selected == expectedPc };
        (
            label: label,
            selectedAnchorPc: selected,
            selectedAnchorName: if(selected.notNil) { names[selected] } { nil },
            expectedAnchorPc: expectedPc,
            expectedAnchorName: if(expectedPc.notNil) { names[expectedPc] } { nil },
            passed: passed,
            report: report,
            note: note
        )
    };

    api[\registerVelocityHarmonicChartReport] = { |post=true|
        var weights, activePcs, report;
        weights = at[\pcWeights].();
        activePcs = at[\activePcsFromWeights].(weights);
        report = at[\rvhcSalienceReport].(activePcs, weights, nil);
        if(post) { at[\rvhcPostReport].(report); };
        report;
    };

    api[\simulateRegisterVelocityHarmonicCharts] = { |post=true|
        var cases, results, allPassed, lowSeventh, loudSeventh, summary;
        cases = [
            (label: \minorLowSeventh, expectedPc: 0, note: "D minor plus much lower C behaves like Dm/C: the seventh owns the chord-local chart.", notes: [(midi: 62, velocity: 0.48), (midi: 65, velocity: 0.48), (midi: 69, velocity: 0.48), (midi: 48, velocity: 0.48)]),
            (label: \minorLoudSeventh, expectedPc: 0, note: "D minor plus much louder C behaves like the same Dm/C chart even when C is not lower.", notes: [(midi: 62, velocity: 0.40), (midi: 65, velocity: 0.40), (midi: 69, velocity: 0.40), (midi: 72, velocity: 1.0)]),
            (label: \majorLowFifth, expectedPc: 7, note: "C major with low G behaves like C/G: fifth owns chart authority, mainly the third may change.", notes: [(midi: 60, velocity: 0.48), (midi: 64, velocity: 0.48), (midi: 43, velocity: 0.48)]),
            (label: \majorLoudThird, expectedPc: 4, note: "C major with loud E behaves like C/E: third owns chart authority, mainly the fifth may change.", notes: [(midi: 60, velocity: 0.38), (midi: 64, velocity: 1.0), (midi: 67, velocity: 0.38)]),
            (label: \dialDecisionLowFifthVsLoudThird, expectedPc: nil, note: "Split decision: low G and loud E are compared by registerAuthority vs velocityAuthority, not by key/root detection.", notes: [(midi: 60, velocity: 0.40), (midi: 64, velocity: 0.95), (midi: 43, velocity: 0.48)])
        ];
        results = Array.new;
        cases.do { |scenario|
            results = results.add(at[\rvhcSyntheticCase].(scenario[\label], scenario[\notes], scenario[\expectedPc], scenario[\note]));
        };
        allPassed = true;
        results.do { |r| if((r[\passed] ? true).not) { allPassed = false; }; };
        lowSeventh = results.detect { |r| r[\label] == \minorLowSeventh };
        loudSeventh = results.detect { |r| r[\label] == \minorLoudSeventh };
        summary = (
            branch: \v3D41,
            allExpectedCasesPassed: allPassed,
            equivalentSeventhCharts: if(lowSeventh.notNil and: { loudSeventh.notNil }) { lowSeventh[\selectedAnchorPc] == loudSeventh[\selectedAnchorPc] } { false },
            cases: results,
            registerAuthority: cfg[\passiveHarmonicField][\registerAuthority] ? 0.85,
            velocityAuthority: cfg[\passiveHarmonicField][\velocityAuthority] ? 0.85,
            chordLocalOnly: true,
            keyDetection: false,
            globalRecenter: false,
            pitchAuthorityAdded: false
        );
        st[\lastRegisterVelocitySimulation] = summary;
        if(post) {
            "".postln;
            "[AT REGISTER/VELOCITY HARMONIC CHART SIM]".postln;
            ("allExpectedCasesPassed=" ++ allPassed.asString
                ++ " equivalentSeventhCharts=" ++ summary[\equivalentSeventhCharts].asString
                ++ " registerAuthority=" ++ summary[\registerAuthority].asString
                ++ " velocityAuthority=" ++ summary[\velocityAuthority].asString
                ++ " chordLocalOnly=true keyDetection=false").postln;
            results.do { |r|
                ("case=" ++ r[\label].asString
                    ++ " selected=" ++ (r[\selectedAnchorName] ? "nil").asString
                    ++ " expected=" ++ (r[\expectedAnchorName] ? "dial").asString
                    ++ " passed=" ++ (r[\passed] ? true).asString
                    ++ " note=" ++ (r[\note] ? "").asString).postln;
            };
        };
        summary;
    };


    at[\phfChartTargetFromAnchor] = { |targetPc, anchorPc, anchorU|
        var k, rel;
        k = (targetPc.asInteger - anchorPc.asInteger) % 12;
        rel = at[\phfCanonicalRel].(k);
        anchorU + rel;
    };

    at[\phfAlignToOldSheet] = { |targetU, oldU|
        oldU + at[\wrapSigned].(targetU - oldU);
    };

    at[\phfActiveChartScore] = { |anchorPc, anchorU, activePcs, pcWeights, oldU|
        var score, total, maxErr, eps;
        score = 0.0;
        total = 0.0;
        maxErr = 0.0;
        eps = 0.0000001;
        (activePcs ? Array.new).do { |pc|
            var w, targetU, alignedU, errCents;
            pc = pc.asInteger % 12;
            w = ((pcWeights[pc] ? 0.0).max(0.05)).clip(0.05, 2.2);
            targetU = at[\phfChartTargetFromAnchor].(pc, anchorPc, anchorU);
            alignedU = at[\phfAlignToOldSheet].(targetU, oldU[pc] ? st[\nodePhase][pc]);
            errCents = ((alignedU - (oldU[pc] ? st[\nodePhase][pc])) * 1200.0).abs;
            score = score + (errCents * w);
            total = total + w;
            maxErr = maxErr.max(errCents);
        };
        (anchorPc: anchorPc, scoreCents: if(total > eps) { score / total } { 0.0 }, maxErrorCents: maxErr, anchorWeight: ((pcWeights[anchorPc] ? 0.0).max(0.05)).clip(0.05, 2.2));
    };

    at[\phfChoosePolyChart] = { |activePcs, pcWeights, oldU|
        var cfgp, best, eps, tieBonus, salienceReport, fitScale, salienceBonus;
        cfgp = cfg[\passiveHarmonicField];
        best = nil;
        eps = 0.0001;
        tieBonus = cfgp[\polyChartTieWeightBonus] ? 0.75;
        fitScale = cfgp[\polyChartFitCostScale] ? 0.35;
        salienceBonus = cfgp[\polyChartSalienceBonusCents] ? 8.0;
        salienceReport = if((cfgp[\registerVelocityChartEnabled] ? true) and: { at[\rvhcSalienceReport].notNil }) {
            at[\rvhcSalienceReport].(activePcs ? Array.new, pcWeights ? Array.fill(12, { 0.0 }), nil)
        } { nil };
        (activePcs ? Array.new).do { |pc|
            var anchorPc, anchorU, cand, adjustedScore, bestAdjusted, salience;
            anchorPc = pc.asInteger % 12;
            anchorU = oldU[anchorPc] ? st[\nodePhase][anchorPc];
            cand = at[\phfActiveChartScore].(anchorPc, anchorU, activePcs, pcWeights, oldU);
            salience = if(salienceReport.notNil and: { at[\rvhcSalienceForPc].notNil }) { at[\rvhcSalienceForPc].(anchorPc, salienceReport) } { 0.0 };
            adjustedScore = (((cand[\scoreCents] ? 0.0) * fitScale)
                - ((cand[\anchorWeight] ? 0.0) * tieBonus)
                - (salience * salienceBonus));
            bestAdjusted = if(best.notNil) { best[\adjustedScoreCents] ? 999999.0 } { 999999.0 };
            if(best.isNil or: { adjustedScore < (bestAdjusted - eps) }) {
                cand[\anchorUnwrapped] = anchorU;
                cand[\adjustedScoreCents] = adjustedScore;
                cand[\registerVelocitySalience] = salience.round(0.001);
                cand[\registerVelocityReport] = salienceReport;
                best = cand;
            };
        };
        if(best.notNil and: { best[\anchorPc].notNil }) { st[\lastRegisterVelocityChartAnchorPc] = best[\anchorPc]; };
        best ? (anchorPc: ((activePcs ? [0])[0] ? 0), anchorUnwrapped: oldU[((activePcs ? [0])[0] ? 0).asInteger % 12], scoreCents: 0.0, maxErrorCents: 0.0, anchorWeight: 1.0, adjustedScoreCents: 0.0, registerVelocitySalience: 0.0, registerVelocityReport: salienceReport);
    };

    at[\phfPolyChartCandidate] = { |before, beforeU, activePcs, pcWeights, sources, blend=0.72, reason=\polyWeightedCompleteHarmonicWorld|
        var cfgp, activeSet, anchor, anchorPc, anchorU, outPhase, outU, activeBlend, passiveBlend, activeMax, passiveMax, rawAssess, report;
        cfgp = cfg[\passiveHarmonicField];
        activeSet = at[\phfActiveSet].(activePcs);
        anchor = at[\phfChoosePolyChart].(activePcs ? Array.new, pcWeights ? Array.fill(12, { 0.0 }), beforeU);
        anchorPc = (anchor[\anchorPc] ? ((activePcs ? [0])[0] ? 0)).asInteger % 12;
        anchorU = anchor[\anchorUnwrapped] ? (beforeU[anchorPc] ? before[anchorPc]);
        outPhase = before.copy;
        outU = beforeU.copy;
        activeBlend = (cfgp[\polyActiveBlend] ? 0.34).clip(0.0, 1.0);
        passiveBlend = (blend ? (cfgp[\polyPassiveBlend] ? 0.72)).clip(0.0, 1.0);
        activeMax = 0.0;
        passiveMax = 0.0;
        cfg[\solver][\numNodes].do { |i|
            var targetU, alignedU, amount, nextU, corrCents;
            targetU = at[\phfChartTargetFromAnchor].(i, anchorPc, anchorU);
            alignedU = at[\phfAlignToOldSheet].(targetU, beforeU[i] ? before[i]);
            amount = if(activeSet.includes(i)) { activeBlend } { passiveBlend };
            nextU = (beforeU[i] ? before[i]) + ((alignedU - (beforeU[i] ? before[i])) * amount);
            outU[i] = nextU;
            outPhase[i] = at[\wrap01].(nextU);
            corrCents = ((nextU - (beforeU[i] ? before[i])) * 1200.0).abs;
            if(activeSet.includes(i)) { activeMax = activeMax.max(corrCents) } { passiveMax = passiveMax.max(corrCents) };
        };
        rawAssess = if(at[\pitchIdentitySpacingGuardAssess].notNil) {
            at[\pitchIdentitySpacingGuardAssess].(outPhase, \phfPolyChartCandidate, activePcs ? Array.new)
        } { nil };
        report = (
            branch: \v3D41,
            reason: reason,
            selectedAnchorPc: anchorPc,
            selectedAnchorName: names[anchorPc],
            selectedAnchorWeight: (anchor[\anchorWeight] ? 0.0).round(0.001),
            registerVelocitySalience: (anchor[\registerVelocitySalience] ? 0.0).round(0.001),
            registerVelocityReport: anchor[\registerVelocityReport],
            adjustedScoreCents: (anchor[\adjustedScoreCents] ? 0.0).round(0.01),
            activeScoreCents: (anchor[\scoreCents] ? 0.0).round(0.01),
            activeMaxErrorCents: (anchor[\maxErrorCents] ? 0.0).round(0.01),
            activeBlend: activeBlend,
            passiveBlend: passiveBlend,
            activeMaxAppliedCents: activeMax.round(0.01),
            passiveMaxAppliedCents: passiveMax.round(0.01),
            rawCompact: if(rawAssess.notNil) { rawAssess[\compact] } { nil },
            rawNeedsAction: if(rawAssess.notNil) { rawAssess[\needsAction] ? false } { false },
            sourceCount: (sources ? Array.new).size,
            note: "3+ notes choose one weighted harmonic chart before passive completion. This avoids averaging multiple incompatible single-origin worlds, which caused 980c sheet gaps and 300c repair moves."
        );
        st[\lastPHFPolyChartReport] = report;
        if((cfgp[\printReports] ? true) == true) {
            ("[AT POLY HARMONIC CHART] reason=" ++ reason.asString
                ++ " anchor=" ++ names[anchorPc].asString
                ++ " score=" ++ report[\activeScoreCents].asString ++ "c"
                ++ " salience=" ++ report[\registerVelocitySalience].asString
                ++ " adjusted=" ++ report[\adjustedScoreCents].asString ++ "c"
                ++ " activeMax=" ++ report[\activeMaxAppliedCents].asString ++ "c"
                ++ " passiveMax=" ++ report[\passiveMaxAppliedCents].asString ++ "c"
                ++ " raw=" ++ (report[\rawCompact] ? "nil").asString).postln;
        };
        (phase: outPhase, unwrapped: outU, report: report);
    };

    at[\phfSheetCoherentSurface] = { |candidate, candidateU, activePcs=nil, pcWeights=nil, reason=\passiveHarmonicField|
        var cfgp, outPhase, outU, gauge, limit, beforeAssess, afterAssess, maxDelta, applied, report, activeSize;
        cfgp = cfg[\passiveHarmonicField];
        activeSize = (activePcs ? Array.new).size;
        outPhase = (candidate ? (st[\nodePhase] ? st[\etPhase])).copy;
        outU = (candidateU ? outPhase).copy;
        applied = false;
        if(((cfgp[\polySheetCoherenceEnabled] ? true) == true) and: { activeSize >= 3 }) {
            gauge = at[\phfWeightedActiveGauge].(outPhase, activePcs ? Array.new, pcWeights ? Array.fill(12, { 0.0 }));
            limit = ((cfgp[\polySheetCoherenceMaxDeviationCents] ? 42.0).max(12.0)) / 1200.0;
            cfg[\solver][\numNodes].do { |i|
                var baseU, basePhase, rel, relClamped, nextU;
                baseU = st[\etPhase][i] + gauge;
                basePhase = at[\wrap01].(baseU);
                rel = at[\wrapSigned].((outPhase[i] ? basePhase) - basePhase);
                relClamped = at[\fltClip].(rel, limit.neg, limit);
                nextU = st[\etPhase][i] + gauge + relClamped;
                outU[i] = nextU;
                outPhase[i] = at[\wrap01].(nextU);
                if((rel - relClamped).abs > 0.0000001) { applied = true; };
            };
            beforeAssess = if(at[\pitchIdentitySpacingGuardAssess].notNil) {
                at[\pitchIdentitySpacingGuardAssess].(candidate, \phfPreSheetCoherentRaw, activePcs ? Array.new)
            } { nil };
            afterAssess = if(at[\pitchIdentitySpacingGuardAssess].notNil) {
                at[\pitchIdentitySpacingGuardAssess].(outPhase, \phfSheetCoherentSurface, activePcs ? Array.new)
            } { nil };
            maxDelta = if(at[\pitchIdentitySpacingGuardMaxDeltaCents].notNil) {
                at[\pitchIdentitySpacingGuardMaxDeltaCents].(outPhase, candidate).round(0.01)
            } { 0.0 };
            report = (
                branch: \v3D41,
                reason: reason,
                activePcs: activePcs ? Array.new,
                applied: applied,
                gaugeCents: (gauge * 1200.0).round(0.01),
                maxRelativeDeviationCents: (limit * 1200.0).round(0.01),
                beforeCompact: if(beforeAssess.notNil) { beforeAssess[\compact] } { nil },
                afterCompact: if(afterAssess.notNil) { afterAssess[\compact] } { nil },
                maxSheetCoherenceDeltaCents: maxDelta,
                note: "3+ note harmonic worlds are normalized to one ordered sheet before playable-surface projection. This prevents wrapped/unwrapped sheet mixing from creating giant repair moves."
            );
            st[\lastPHFSheetCoherenceReport] = report;
            if((cfgp[\printReports] ? true) == true) {
                ("[AT SHEET COHERENT SURFACE] reason=" ++ reason.asString
                    ++ " applied=" ++ applied.asString
                    ++ " gauge=" ++ report[\gaugeCents].asString ++ "c"
                    ++ " before=" ++ (report[\beforeCompact] ? "nil").asString
                    ++ " after=" ++ (report[\afterCompact] ? "nil").asString
                    ++ " maxDelta=" ++ maxDelta.asString ++ "c").postln;
            };
        } {
            report = (branch: \v3D41, reason: reason, applied: false, skipped: true, activePcs: activePcs ? Array.new);
        };
        (phase: outPhase, unwrapped: outU, report: report)
    };

    at[\phfOrderedPlayableSurface] = { |candidate, candidateU, activePcs=nil, reason=\passiveHarmonicField|
        var cfgp, rawAssess, outputAssess, surfacePhase, surfaceU, rawNeeds, outputNeeds, applied, maxDelta, report, canProject;
        cfgp = cfg[\passiveHarmonicField];
        surfacePhase = (candidate ? (st[\nodePhase] ? st[\etPhase])).copy;
        surfaceU = (candidateU ? surfacePhase).copy;
        rawAssess = if(at[\pitchIdentitySpacingGuardAssess].notNil) {
            at[\pitchIdentitySpacingGuardAssess].(surfacePhase, \phfRawHarmonicSurface, activePcs ? Array.new)
        } { nil };
        rawNeeds = if(rawAssess.notNil) { rawAssess[\needsAction] ? false } { false };
        applied = false;
        canProject = (cfgp[\orderedPlayableSurfaceEnabled] ? true)
            and: { rawNeeds }
            and: { at[\pitchIdentitySpacingGuardProject].notNil }
            and: { at[\pitchIdentitySpacingGuardUnwrappedFromProjection].notNil };
        if(canProject) {
            surfacePhase = at[\pitchIdentitySpacingGuardProject].(surfacePhase, activePcs ? Array.new);
            surfaceU = at[\pitchIdentitySpacingGuardUnwrappedFromProjection].(candidate, surfaceU, surfacePhase);
            applied = true;
        };
        outputAssess = if(at[\pitchIdentitySpacingGuardAssess].notNil) {
            at[\pitchIdentitySpacingGuardAssess].(surfacePhase, \phfOrderedPlayableHarmonicSurface, activePcs ? Array.new)
        } { rawAssess };
        outputNeeds = if(outputAssess.notNil) { outputAssess[\needsAction] ? false } { false };
        maxDelta = if(at[\pitchIdentitySpacingGuardMaxDeltaCents].notNil) {
            at[\pitchIdentitySpacingGuardMaxDeltaCents].(surfacePhase, candidate).round(0.01)
        } { 0.0 };
        report = (
            branch: \v3D41,
            reason: reason,
            orderedPlayableSurface: true,
            applied: applied,
            rawNeedsAction: rawNeeds,
            rawCompact: if(rawAssess.notNil) { rawAssess[\compact] } { nil },
            outputNeedsAction: outputNeeds,
            outputCompact: if(outputAssess.notNil) { outputAssess[\compact] } { nil },
            maxSurfaceDeltaCents: maxDelta,
            role: \integratedHarmonicSurfaceProjection,
            emergencySpacingGuardUsed: false,
            changedSpacingThresholds: false,
            note: "The complete harmonic world is projected as a playable ordered 12-note surface before the field-commit guard verifies it."
        );
        st[\lastPHFOrderedSurfaceReport] = report;
        if(((cfgp[\printReports] ? true) == true) and: { applied or: { (cfgp[\surfaceProjectionPostReports] ? false) == true } }) {
            ("[AT ORDERED HARMONIC SURFACE] reason=" ++ reason.asString
                ++ " applied=" ++ applied.asString
                ++ " raw=" ++ (report[\rawCompact] ? "nil").asString
                ++ " output=" ++ (report[\outputCompact] ? "nil").asString
                ++ " maxSurfaceDelta=" ++ maxDelta.asString ++ "c").postln;
        };
        (phase: surfacePhase, unwrapped: surfaceU, report: report)
    };

    at[\applyPassiveHarmonicCompletion] = { |activePcs, pcWeights, externalSources=nil, reason=\passiveHarmonicField, activeLock=true, blend=nil|
        var cfgp, before, beforeU, candidate, candidateU, chartOut, chartReport, sheetOut, sheetReport, surfaceOut, surfaceReport, out, delta, activeSet, sources, b;
        var moved, passiveMoved, passiveMax, passiveMean, activeMax, report, mode;
        cfgp = cfg[\passiveHarmonicField];
        if((cfgp[\enabled] ? true).not) { nil } {
            before = st[\nodePhase].copy;
            if(at[\ensureCoreUnwrapped].notNil) { at[\ensureCoreUnwrapped].(); };
            beforeU = (st[\coreUnwrappedPhase] ? before).copy;
            activeSet = at[\phfActiveSet].(activePcs);
            sources = at[\phfSourceList].(activePcs, pcWeights, externalSources);
            if(sources.isEmpty) { nil } {
                b = (blend ? 1.0).clip(0.0, 1.0);
                candidate = before.copy;
                candidateU = beforeU.copy;
                chartReport = nil;
                if(((activePcs ? Array.new).size >= 3)
                    and: { (cfgp[\polyChartSelectionEnabled] ? true) == true }
                    and: { at[\phfPolyChartCandidate].notNil }) {
                    chartOut = at[\phfPolyChartCandidate].(before, beforeU, activePcs ? Array.new, pcWeights, sources, b, reason);
                    chartReport = chartOut[\report];
                    candidate = chartOut[\phase] ? candidate;
                    candidateU = chartOut[\unwrapped] ? candidateU;
                } {
                    cfg[\solver][\numNodes].do { |i|
                        var targetU, nextU;
                        targetU = at[\phfCompleteWorldTargetForNode].(i, beforeU, sources, activeSet, activeLock);
                        nextU = beforeU[i] + ((targetU - beforeU[i]) * b);
                        candidateU[i] = nextU;
                        candidate[i] = at[\wrap01].(nextU);
                    };
                };

                if(at[\phfSheetCoherentSurface].notNil) {
                    sheetOut = at[\phfSheetCoherentSurface].(candidate, candidateU, activePcs ? Array.new, pcWeights, reason);
                    sheetReport = sheetOut[\report];
                    candidate = sheetOut[\phase] ? candidate;
                    candidateU = sheetOut[\unwrapped] ? candidateU;
                };

                if(at[\phfOrderedPlayableSurface].notNil) {
                    surfaceOut = at[\phfOrderedPlayableSurface].(candidate, candidateU, activePcs ? Array.new, reason);
                    surfaceReport = surfaceOut[\report];
                    candidate = surfaceOut[\phase] ? candidate;
                    candidateU = surfaceOut[\unwrapped] ? candidateU;
                };

                if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                    out = at[\applyPitchIdentityFieldCommitGuard].(candidate, candidateU, reason, before, beforeU, activePcs ? Array.new);
                    candidate = out[\phase] ? candidate;
                    candidateU = out[\unwrapped] ? candidateU;
                };

                delta = Array.fill(cfg[\solver][\numNodes], { |i|
                    at[\wrapSigned].((candidate[i] ? before[i]) - (before[i] ? 0.0))
                });

                st[\nodePhase] = candidate.copy;
                st[\coreUnwrappedPhase] = candidateU.copy;
                if(st[\targetPhase].notNil) { st[\targetPhase] = candidate.copy; };
                if(st[\targetCoreUnwrappedPhase].notNil) { st[\targetCoreUnwrappedPhase] = candidateU.copy; };
                if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase] = candidate.copy; };
                if(st[\frozenPhase].notNil) { st[\frozenPhase] = candidate.copy; };
                if(st[\frozenCoreUnwrappedPhase].notNil) { st[\frozenCoreUnwrappedPhase] = candidateU.copy; };
                at[\updateDescriptors].(activePcs ? Array.new, pcWeights, externalSources, delta);
                if(at[\pushBuses].notNil) { at[\pushBuses].(); };

                moved = 0;
                passiveMoved = 0;
                passiveMax = 0.0;
                passiveMean = 0.0;
                activeMax = 0.0;
                cfg[\solver][\numNodes].do { |i|
                    var cents;
                    cents = (delta[i].abs * 1200.0);
                    if(cents > (cfgp[\passiveMovedEpsCents] ? 0.25)) { moved = moved + 1; };
                    if(activeSet.includes(i)) {
                        activeMax = activeMax.max(cents);
                    } {
                        passiveMax = passiveMax.max(cents);
                        passiveMean = passiveMean + cents;
                        if(cents > (cfgp[\passiveMovedEpsCents] ? 0.25)) { passiveMoved = passiveMoved + 1; };
                    };
                };
                passiveMean = passiveMean / (cfg[\solver][\numNodes] - (activePcs ? Array.new).size).max(1);
                mode = if((activePcs ? Array.new).size <= 1) { \singleOriginWorld } { if((activePcs ? Array.new).size == 2) { \dyadWorld } { \polyWeightedWorld } };
                report = (
                    branch: \v3D41,
                    reason: reason,
                    mode: mode,
                    activePcs: activePcs ? Array.new,
                    sourceCount: sources.size,
                    completeWorldProjection: true,
                    orderedPlayableSurface: true,
                    polyChartReport: chartReport,
                    polyChartSelectionApplied: chartReport.notNil,
                    polyChartAnchorPc: if(chartReport.notNil) { chartReport[\selectedAnchorPc] } { nil },
                    sheetCoherenceReport: sheetReport,
                    sheetCoherenceApplied: if(sheetReport.notNil) { sheetReport[\applied] ? false } { false },
                    surfaceReport: surfaceReport,
                    surfaceProjectionApplied: if(surfaceReport.notNil) { surfaceReport[\applied] ? false } { false },
                    rawSurfaceNeedsAction: if(surfaceReport.notNil) { surfaceReport[\rawNeedsAction] ? false } { false },
                    guardShouldOnlyVerify: true,
                    moved: moved,
                    passiveMoved: passiveMoved,
                    passiveMaxCents: passiveMax.round(0.01),
                    passiveMeanCents: passiveMean.round(0.01),
                    activeMaxCents: activeMax.round(0.01),
                    activeLocked: activeLock,
                    blend: b,
                    diagnosis: if(passiveMoved > 0) { \completeHarmonicWorldResponded } { \noPassiveMotionNeeded }
                );
                st[\lastPassiveHarmonicFieldReport] = report;
                if((cfgp[\printReports] ? true) == true) {
                    ("[AT PASSIVE HARMONIC FIELD] reason=" ++ reason.asString
                        ++ " mode=" ++ mode.asString
                        ++ " active=" ++ (activePcs ? Array.new).asString
                        ++ " passiveMoved=" ++ passiveMoved.asString
                        ++ " passiveMax=" ++ passiveMax.round(0.01).asString ++ "c"
                        ++ " passiveMean=" ++ passiveMean.round(0.01).asString ++ "c"
                        ++ " activeMax=" ++ activeMax.round(0.01).asString ++ "c"
                        ++ " diagnosis=" ++ report[\diagnosis].asString).postln;
                };
                report;
            };
        };
    };

    at[\settleDyadLock] = { |activePcs, pcWeights, externalSources=nil, reason=\dyadLock|
        var pcs, anchorPc, otherPc, oldPhase, oldU, k, best, desiredU, desiredPhase, diff, report, delta;
        pcs = (activePcs ? Array.new).sort;
        if(pcs.size != 2) { nil } {
            if(at[\ensureCoreUnwrapped].notNil) { at[\ensureCoreUnwrapped].(); };
            oldPhase = st[\nodePhase].copy;
            oldU = (st[\coreUnwrappedPhase] ? oldPhase).copy;
            anchorPc = at[\chooseAnchorPc].(pcs, pcWeights);
            otherPc = pcs.detect { |pc| pc != anchorPc };
            k = (otherPc - anchorPc) % 12;
            best = at[\ratioChoices][k][0];
            desiredU = (oldU[anchorPc] ? oldPhase[anchorPc]) + (best[0] ? (k / 12.0));
            desiredPhase = at[\wrap01].(desiredU);
            diff = at[\wrapSigned].(desiredPhase - oldPhase[otherPc]);
            st[\nodePhase][otherPc] = desiredPhase;
            st[\coreUnwrappedPhase][otherPc] = desiredU;
            delta = Array.fill(cfg[\solver][\numNodes], 0.0);
            delta[otherPc] = diff;
            at[\updateDescriptors].(pcs, pcWeights, externalSources, delta);
            report = at[\applyPassiveHarmonicCompletion].(pcs, pcWeights, externalSources, reason, true, cfg[\passiveHarmonicField][\dyadBlend] ? 1.0);
            st[\stateLabel] = \dyadLock;
            st[\lastDyadLock] = (
                anchorPc: anchorPc,
                otherPc: otherPc,
                intervalTargetCents: ((best[0] ? (k / 12.0)) * 1200.0).round(0.01),
                correctionCents: (diff * 1200.0).round(0.01),
                passiveReport: report,
                note: "Dyad corrected once, then treated as one stable interval world; 3+ notes invoke weighted negotiation."
            );
            if((cfg[\passiveHarmonicField][\printReports] ? true) == true) {
                ("[AT DYAD LOCK] anchor=" ++ names[anchorPc].asString
                    ++ " other=" ++ names[otherPc].asString
                    ++ " target=" ++ (((best[0] ? (k / 12.0)) * 1200.0).round(0.01)).asString ++ "c"
                    ++ " correction=" ++ ((diff * 1200.0).round(0.01)).asString ++ "c"
                    ++ " passiveMoved=" ++ ((report ? IdentityDictionary.new)[\passiveMoved] ? 0).asString).postln;
            };
            st[\lastDyadLock];
        };
    };


    // v3D33/v3D35/v3D36: The old singleton continuity path could restore the previous frozen
    // field and bypass settleSingle entirely. That preserved stale passive residue
    // after an arpeggio returned to one active note. For this instrument, exactly
    // one active note is the complete harmonic origin, so single-note reentry must
    // run through settleSingle + complete-world projection instead of merely
    // promoting/restoring the frozen field.
    if(at[\legacySingletonContinuityAnchor_v3D33].isNil) { at[\legacySingletonContinuityAnchor_v3D33] = at[\singletonContinuityAnchor]; };
    at[\singletonContinuityAnchor] = { |pc, externalSources|
        var primaryExternal, strength;
        primaryExternal = if(at[\strongestExternalSource].notNil) { at[\strongestExternalSource].(externalSources ? Array.new) } { nil };
        strength = if(primaryExternal.notNil and: { at[\sourceStrength].notNil }) { at[\sourceStrength].(primaryExternal) } { 0.0 };
        if(primaryExternal.notNil and: { strength > 0.000001 }) {
            // External source can still own a singleton calibration/reentry path.
            at[\legacySingletonContinuityAnchor_v3D33].(pc, externalSources);
        } {
            if((cfg[\passiveHarmonicField][\enabled] ? true)
                and: { (cfg[\passiveHarmonicField][\authoritativeActiveStateWorld] ? true) == true }
                and: { (cfg[\passiveHarmonicField][\bypassFrozenSingleContinuity] ? true) == true }) {
                nil
            } {
                at[\legacySingletonContinuityAnchor_v3D33].(pc, externalSources);
            }
        }
    };

    if(at[\legacyPrepareCorePathOnset_v3D35].isNil) { at[\legacyPrepareCorePathOnset_v3D35] = at[\prepareCorePathOnset]; };
    at[\prepareCorePathOnset] = { |midi, pc, prevCount=0, now=nil|
        var suppressReason;
        suppressReason = if(at[\fieldSuppressPathReasonForOnset].notNil) { at[\fieldSuppressPathReasonForOnset].(midi, pc, prevCount) } { nil };
        if(suppressReason.notNil) {
            at[\fieldNoTransportOnsetRecord].(midi, pc, suppressReason)
        } {
            at[\legacyPrepareCorePathOnset_v3D35].(midi, pc, prevCount, now)
        }
    };

    if(at[\legacySettleSingle_v3D33].isNil) { at[\legacySettleSingle_v3D33] = at[\settleSingle]; };
    if(at[\legacySettleMulti_v3D33].isNil) { at[\legacySettleMulti_v3D33] = at[\settleMulti]; };

    at[\settleSingle] = { |pc, anchorPhase, pcWeights, externalSources=nil, maxIter=nil|
        var out;
        out = at[\legacySettleSingle_v3D33].(pc, anchorPhase, pcWeights, externalSources, maxIter);
        if((cfg[\passiveHarmonicField][\singleOriginEnabled] ? true) == true) {
            at[\applyPassiveHarmonicCompletion].([pc], pcWeights, externalSources, \singleCompleteHarmonicOrigin, true, cfg[\passiveHarmonicField][\singleBlend] ? 1.0);
            st[\stateLabel] = \singleCompleteHarmonicOrigin;
        };
        out;
    };

    at[\settleMulti] = { |activePcs, pcWeights, externalSources=nil, maxIter=nil|
        var out;
        if(((activePcs ? Array.new).size == 2) and: { (cfg[\passiveHarmonicField][\dyadLockEnabled] ? true) == true }) {
            out = at[\settleDyadLock].(activePcs, pcWeights, externalSources, \dyadCompleteHarmonicWorld);
        } {
            out = at[\legacySettleMulti_v3D33].(activePcs, pcWeights, externalSources, maxIter);
            if(((activePcs ? Array.new).size >= 3) and: { (cfg[\passiveHarmonicField][\polyCompletionEnabled] ? true) == true }) {
                at[\applyPassiveHarmonicCompletion].(activePcs, pcWeights, externalSources, \polyWeightedCompleteHarmonicWorld, true, cfg[\passiveHarmonicField][\polyPassiveBlend] ? 0.72);
                st[\stateLabel] = \polyWeightedHarmonicField;
            };
        };
        out;
    };

    api[\passiveHarmonicFieldReport] = {
        var rep;
        rep = st[\lastPassiveHarmonicFieldReport] ? (installed: true, noReportYet: true);
        "".postln;
        "[AT PASSIVE HARMONIC FIELD REPORT]".postln;
        rep.postln;
        rep;
    };

    api[\dyadLockReport] = {
        var rep;
        rep = st[\lastDyadLock] ? (installed: true, noReportYet: true);
        "".postln;
        "[AT DYAD LOCK REPORT]".postln;
        rep.postln;
        rep;
    };

    api[\passiveHarmonicFieldPlan] = {
        var rep;
        rep = (
            branch: \v3D41_register_velocity_harmonic_chart_final_product,
            rule: "Every active evidence state generates a complete harmonic world, not merely correction of played notes.",
            surfaceRule: "The complete harmonic world must be an ordered, playable 12-note surface before the emergency spacing guard verifies it.",
            registerVelocityRule: "For 3+ active notes, the selected harmonic chart is chord-local salience: low register and high velocity can make a non-root note act like an inversion/slash-chord authority without key detection or global recentering.",
            singleNote: "one active note is a complete harmonic origin; the entire 12-note field re-projects around that note",
            dyad: "two active notes settle as one stable interval world; passive notes re-project around the dyad",
            polyphony: "three or more notes choose one register/velocity-weighted harmonic chart, then project the 12-note surface from that chart",
            carryInPublicDemo: 0,
            changedCoreLaw: true,
            singletonReentryBypassesFrozenResidue: true,
            orderedPlayableSurface: true,
            changedSpacingThresholds: false,
            changedTopologyGuard: false,
            pitchAuthorityAdded: false,
            keyDetection: false
        );
        "".postln;
        "[AT PASSIVE HARMONIC FIELD PLAN]".postln;
        rep.postln;
        rep;
    };

    "[AT PASSIVE HARMONIC FIELD] v3D41 loaded: register/velocity harmonic-chart authority is chord-local; low or loud non-root notes can select inversion/slash-chord charts. No key detection, global recentering, pitch authority, spacing/topology threshold, sample, tone, mic, or real-play-fast-path change.".postln;
};
)
