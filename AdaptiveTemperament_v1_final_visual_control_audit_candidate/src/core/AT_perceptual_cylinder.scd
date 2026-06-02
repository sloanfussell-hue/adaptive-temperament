(
// AT_perceptual_cylinder.scd
// v3D11 measured-spectrum evidence bridge / sample-truth audit for the register-aware perceptual cylinder / accordion model.
//
// This does NOT change tuning, rendering, mic policy, memory, gravity, or the
// Sethares/perceptual-spectrum authority. It adds a hidden register-aware body
// underneath the existing 12 pitch-class surface so later branches can let
// partial roughness act in true frequency/register space.
//
// Design rule:
//   visible surface = pitch-class circle
//   hidden body     = pitch-class circle × register height = cylinder
//   future spectrum pressure may stretch/compress/shear that body = accordion
//
// v3D11 keeps the v3D10 spectral-truth descriptor/sample-truth gate and adds a no-pitch measured-spectrum evidence bridge. v3D9 added a stricter spectral-truth
// audit: declared spectra, fallback tones, formants, and inharmonic profiles
// are separated from the actual rendered tone. Formants/body filters weight
// partial amplitudes; they do not directly create inharmonicity or retune
// fundamentals. Piano stretch / bell-like / formant claims are diagnostic unless
// the actual sound source proves that spectrum. v3D10 added a no-pitch actual-spectrum descriptor path; v3D11 adds manually supplied/measured partial evidence reports and comparison gates without changing tuning.
var build, at, cfg, st, api, pcNames, oldApplyAuthorityPreset;

build = ~atBuild;
if(build.isNil) {
    "[at-perceptual-cylinder] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    pcNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    cfg[\perceptualCylinder] = cfg[\perceptualCylinder] ? (
        enabled: true,
        amount: 0.0,
        baseMidi: 24,              // C1
        registerCount: 7,          // C1..C7 surface rows
        residualLimitCents: 80.0,
        scaffoldOnly: false,
        debug: false,
        spectrumEvaluatorOnly: false,
        accordionProposalOnly: false,
        accordionAuthorityAvailable: true,
        accordionAuthorityEnabled: false,
        accordionRenderHookEnabled: false,
        accordionProtectActive: true,
        accordionProtectExternal: true,
        accordionProposalLimitCents: 24.0,
        accordionAuthorityLimitCents: 16.0,
        accordionAuditionProfile: \off,
        accordionProfileMode: \manual,
        accordionTimbreCouplingEnabled: false,
        accordionTimbreTone: \organ,
        accordionPitchAuditionEnabled: false,
        accordionExperimentalPitchEnabled: false,
        accordionBodyDiagnosticOnly: true,
        spectrumCandidateOffsetsCents: [-20.0, -10.0, -5.0, 0.0, 5.0, 10.0, 20.0]
    );

    // Backfill new v3D4 keys if this file is evaluated over an older config.
    cfg[\perceptualCylinder][\accordionAuthorityAvailable] = cfg[\perceptualCylinder][\accordionAuthorityAvailable] ? true;
    cfg[\perceptualCylinder][\accordionAuthorityEnabled] = cfg[\perceptualCylinder][\accordionAuthorityEnabled] ? false;
    cfg[\perceptualCylinder][\accordionRenderHookEnabled] = cfg[\perceptualCylinder][\accordionRenderHookEnabled] ? false;
    cfg[\perceptualCylinder][\accordionProtectActive] = cfg[\perceptualCylinder][\accordionProtectActive] ? true;
    cfg[\perceptualCylinder][\accordionProtectExternal] = cfg[\perceptualCylinder][\accordionProtectExternal] ? true;
    cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = cfg[\perceptualCylinder][\accordionAuthorityLimitCents] ? 16.0;
    cfg[\perceptualCylinder][\accordionAuditionProfile] = cfg[\perceptualCylinder][\accordionAuditionProfile] ? \off;
    cfg[\perceptualCylinder][\accordionProfileMode] = cfg[\perceptualCylinder][\accordionProfileMode] ? \manual;
    cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] ? false;
    cfg[\perceptualCylinder][\accordionTimbreTone] = cfg[\perceptualCylinder][\accordionTimbreTone] ? \organ;
    cfg[\perceptualCylinder][\accordionPitchAuditionEnabled] = cfg[\perceptualCylinder][\accordionPitchAuditionEnabled] ? false;
    cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] = cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] ? false;
    cfg[\perceptualCylinder][\accordionBodyDiagnosticOnly] = cfg[\perceptualCylinder][\accordionBodyDiagnosticOnly] ? true;

    at[\perceptualCylinderConfig] = { cfg[\perceptualCylinder] ? () };

    // v3D9 keeps diagnostic/timbre-coupling spectrum shapes. These do
    // not become the global Sethares profile and do not affect default tuning.
    // They are used only by cylinder/formant reports and explicitly enabled
    // audition/profile helpers.
    if(at[\perceptualSpectrumProfiles].notNil) {
        at[\perceptualSpectrumProfiles][\pianoStretch] = [[1.0, 1.0], [2.006, 0.55], [3.024, 0.34], [4.056, 0.22], [5.105, 0.15], [6.168, 0.10], [7.252, 0.07], [8.352, 0.05]];
        at[\perceptualSpectrumProfiles][\bellLike] = [[1.0, 1.0], [1.41, 0.72], [2.03, 0.54], [2.76, 0.38], [3.92, 0.25], [5.38, 0.16], [6.81, 0.10]];
        at[\perceptualSpectrumProfiles][\formantVoice] = [[1.0, 1.0], [2.0, 0.48], [3.0, 0.30], [4.0, 0.18], [5.0, 0.10], [6.0, 0.06]];
    };

    at[\perceptualCylinderAmount] = {
        var ccfg;
        ccfg = at[\perceptualCylinderConfig].();
        if(ccfg[\enabled] ? true) { (ccfg[\amount] ? 0.0).clip(0.0, 1.0) } { 0.0 }
    };

    at[\perceptualCylinderRegisterBases] = {
        var ccfg, base, count;
        ccfg = at[\perceptualCylinderConfig].();
        base = (ccfg[\baseMidi] ? 24).asInteger;
        count = (ccfg[\registerCount] ? 7).asInteger.max(1);
        Array.fill(count, { |i| base + (i * 12) });
    };

    at[\perceptualCylinderCopyGrid] = { |grid|
        (grid ? Array.new).collect { |row| (row ? Array.new).copy };
    };

    at[\perceptualCylinderEnsure] = {
        var bases, n, needs;
        bases = at[\perceptualCylinderRegisterBases].();
        n = cfg[\solver][\numNodes] ? 12;
        needs = st[\perceptualCylinderResidualCents].isNil
            or: { st[\perceptualCylinderResidualCents].size != bases.size };
        if(needs.not) {
            st[\perceptualCylinderResidualCents].do { |row|
                if(row.isNil or: { row.size != n }) { needs = true; };
            };
        };
        if(needs) {
            st[\perceptualCylinderResidualCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        };
        if(st[\perceptualCylinderPressureCents].isNil or: { st[\perceptualCylinderPressureCents].size != bases.size }) {
            st[\perceptualCylinderPressureCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        };
        if(st[\perceptualCylinderProposedResidualCents].isNil or: { st[\perceptualCylinderProposedResidualCents].size != bases.size }) {
            st[\perceptualCylinderProposedResidualCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        };
        if(st[\perceptualCylinderMeasuredSpectra].isNil) {
            st[\perceptualCylinderMeasuredSpectra] = IdentityDictionary.new;
        };
        st[\perceptualCylinderRegisterBases] = bases;
        st[\perceptualCylinderLastApplied] = false;
        st[\perceptualCylinderResidualCents];
    };

    at[\perceptualCylinderRegisterIndexForMidi] = { |midi=60|
        var bases, base, idx;
        bases = at[\perceptualCylinderRegisterBases].();
        base = bases[0] ? 24;
        idx = (((midi ? 60).asInteger - base) / 12.0).floor.asInteger;
        idx.max(0).min(bases.size - 1);
    };

    at[\perceptualCylinderPcForMidi] = { |midi=60|
        ((midi ? 60).asInteger % 12).asInteger;
    };

    at[\perceptualCylinderResidualFor] = { |pc=0, midi=60|
        var grid, ri, p;
        grid = at[\perceptualCylinderEnsure].();
        ri = at[\perceptualCylinderRegisterIndexForMidi].(midi);
        p = (pc ? 0).asInteger % 12;
        (grid[ri][p] ? 0.0).asFloat;
    };

    at[\perceptualCylinderSetResidual] = { |pc=0, midi=60, cents=0.0|
        var grid, ri, p, limit;
        grid = at[\perceptualCylinderEnsure].();
        ri = at[\perceptualCylinderRegisterIndexForMidi].(midi);
        p = (pc ? 0).asInteger % 12;
        limit = (cfg[\perceptualCylinder][\residualLimitCents] ? 80.0).abs;
        grid[ri][p] = (cents ? 0.0).asFloat.clip(0.0 - limit, limit);
        st[\perceptualCylinderLastApplied] = false;
        grid[ri][p];
    };

    at[\perceptualCylinderClear] = {
        var bases, n;
        bases = at[\perceptualCylinderRegisterBases].();
        n = cfg[\solver][\numNodes] ? 12;
        st[\perceptualCylinderResidualCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        st[\perceptualCylinderPressureCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        st[\perceptualCylinderProposedResidualCents] = Array.fill(bases.size, { Array.fill(n, 0.0) });
        st[\perceptualCylinderLastApplied] = false;
        nil;
    };

    at[\perceptualCylinderCell] = { |pc=0, midi=60|
        var p, ri, baseDev, residual, projected, freq;
        at[\perceptualCylinderEnsure].();
        p = (pc ? 0).asInteger % 12;
        ri = at[\perceptualCylinderRegisterIndexForMidi].(midi);
        baseDev = if(st[\nodePhase].notNil and: { st[\etPhase].notNil }) {
            at[\wrapSigned].((st[\nodePhase][p] ? 0.0) - (st[\etPhase][p] ? 0.0)) * 1200.0;
        } { 0.0 };
        residual = at[\perceptualCylinderResidualFor].(p, midi);
        projected = baseDev + residual;
        freq = at[\midiToFreq].(midi) * (2 ** (projected / 1200.0));
        (
            pc: p,
            pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(p) } { pcNames.wrapAt(p) },
            midi: (midi ? 60).asInteger,
            registerIndex: ri,
            registerBaseMidi: (st[\perceptualCylinderRegisterBases] ? [24]).wrapAt(ri),
            pitchClassDevCents: baseDev.round(0.01),
            registerResidualCents: residual.round(0.01),
            projectedDevCents: projected.round(0.01),
            projectedFreq: freq.round(0.01)
        );
    };

    at[\perceptualCylinderProjectionForMidi] = { |midi=60|
        at[\perceptualCylinderCell].(at[\perceptualCylinderPcForMidi].(midi), midi);
    };


    // v3D7 evaluator: let the Sethares partial-roughness system see actual
    // register/frequency addresses on the cylinder. This still writes no
    // nodePhase/targetPhase/coreUnwrappedPhase. The bounded accordion authority
    // may explicitly copy proposals into the residual grid; render application is
    // guarded by an off-by-default hook, and adds controlled audition reports/profiles for comparing hook off/on behavior.
    at[\perceptualCylinderSpectrumSourceForMidi] = { |midi=60, profile=nil, weight=1.0, confidence=1.0, residualOverride=nil|
        var m, p, ri, cell, residual, projectedDev, freq, prof;
        m = (midi ? 60).asInteger;
        p = at[\perceptualCylinderPcForMidi].(m);
        ri = at[\perceptualCylinderRegisterIndexForMidi].(m);
        cell = at[\perceptualCylinderCell].(p, m);
        residual = if(residualOverride.notNil) { residualOverride.asFloat } { cell[\registerResidualCents] ? 0.0 };
        projectedDev = (cell[\pitchClassDevCents] ? 0.0) + residual;
        freq = at[\midiToFreq].(m) * (2 ** (projectedDev / 1200.0));
        prof = (profile ? if(cfg[\perceptualSpectrum].notNil) { cfg[\perceptualSpectrum][\defaultProfile] ? \harmonic } { \harmonic }).asSymbol;
        (
            pc: p,
            pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(p) } { pcNames.wrapAt(p) },
            midi: m,
            registerIndex: ri,
            registerBaseMidi: (st[\perceptualCylinderRegisterBases] ? [24]).wrapAt(ri),
            frequency: freq,
            projectedDevCents: projectedDev.round(0.01),
            pitchClassDevCents: cell[\pitchClassDevCents] ? 0.0,
            registerResidualCents: residual.round(0.01),
            weight: (weight ? 1.0).asFloat,
            confidence: (confidence ? 1.0).asFloat,
            spectrumProfile: prof,
            kind: \registerCylinder
        );
    };

    at[\perceptualCylinderPartialsForSource] = { |src|
        var scfg, profileName, profile, srcWeight, conf, partials, maxPartials, minAmp, maxFreq, baseFreq, pc, pcName;
        scfg = if(at[\perceptualSpectrumConfig].notNil) { at[\perceptualSpectrumConfig].() } { () };
        profileName = (src[\spectrumProfile] ? src[\profile] ? (scfg[\defaultProfile] ? \harmonic)).asSymbol;
        if(at[\perceptualSpectrumProfiles].isNil or: { at[\perceptualSpectrumProfiles][profileName].isNil }) { profileName = \harmonic; };
        profile = if(at[\perceptualSpectrumProfiles].notNil) { at[\perceptualSpectrumProfiles][profileName] ? [[1.0, 1.0]] } { [[1.0, 1.0]] };
        baseFreq = (src[\frequency] ? 0.0).asFloat.max(1.0);
        srcWeight = (src[\weight] ? 1.0).asFloat.clip(0.0, 2.0);
        conf = (src[\confidence] ? 1.0).asFloat.clip(0.0, 1.0);
        maxPartials = (scfg[\maxPartialsPerSource] ? 8).asInteger.max(1);
        minAmp = (scfg[\minPartialAmp] ? 0.015).max(0.0);
        maxFreq = (scfg[\maxFrequency] ? 9000.0).max(200.0);
        pc = src[\pc] ? 0;
        pcName = src[\pcName] ? if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(pc) } { pcNames.wrapAt(pc) };
        partials = Array.new;
        profile.do { |pair, i|
            var ratio, amp, f;
            if(i < maxPartials) {
                ratio = (pair[0] ? 1.0).asFloat;
                amp = ((pair[1] ? 0.0).asFloat * srcWeight * conf).clip(0.0, 4.0);
                f = baseFreq * ratio;
                if(amp >= minAmp and: { f <= maxFreq }) {
                    partials = partials.add((
                        sourceIndex: src[\sourceIndex] ? 0,
                        pc: pc,
                        pcName: pcName,
                        midi: src[\midi] ? 60,
                        registerIndex: src[\registerIndex] ? 0,
                        profile: profileName,
                        partialIndex: i + 1,
                        ratio: ratio,
                        frequency: f,
                        amplitude: amp,
                        kind: \registerCylinder
                    ));
                };
            };
        };
        partials;
    };

    at[\perceptualCylinderSpectrumSourcesForMidis] = { |midis, profile=\harmonic|
        var sources;
        sources = Array.new;
        (midis ? [60, 64, 67]).do { |m, i|
            var src;
            src = at[\perceptualCylinderSpectrumSourceForMidi].(m, profile, 1.0, 1.0, nil);
            src[\sourceIndex] = i;
            sources = sources.add(src);
        };
        sources;
    };

    at[\perceptualCylinderSpectrumRoughnessForSources] = { |sources|
        var partials, rough;
        partials = Array.new;
        (sources ? Array.new).do { |src, i|
            var s;
            s = src.copy;
            s[\sourceIndex] = i;
            partials = partials ++ at[\perceptualCylinderPartialsForSource].(s);
        };
        rough = if(at[\perceptualSpectrumRoughnessForPartials].notNil) {
            at[\perceptualSpectrumRoughnessForPartials].(partials)
        } {
            (roughness: 0.0, pairCount: 0, pairs: Array.new)
        };
        (
            roughnessRaw: rough[\roughness] ? 0.0,
            roughnessEstimate: (rough[\roughness] ? 0.0).round(0.0001),
            sourceCount: (sources ? Array.new).size,
            partialCount: partials.size,
            partials: partials,
            strongestPairs: rough[\pairs] ? Array.new,
            note: "register-aware cylinder spectrum roughness is diagnostic/evaluator source for the v3D7 bounded accordion authority/audition layer"
        );
    };

    at[\perceptualCylinderSpectrumRoughnessForMidis] = { |midis, profile=\harmonic|
        at[\perceptualCylinderSpectrumRoughnessForSources].(at[\perceptualCylinderSpectrumSourcesForMidis].(midis, profile));
    };

    at[\perceptualCylinderCandidateCostsForMidi] = { |midi=60, sourceMidis=nil, profile=\harmonic, offsets=nil|
        var m, ccfg, mids, offs, baseResidual, costs, bestCost, bestMove, bestFreq;
        m = (midi ? 60).asInteger;
        ccfg = at[\perceptualCylinderConfig].();
        mids = sourceMidis ? [m, m + 4, m + 7];
        if(mids.includes(m).not) { mids = mids.add(m); };
        offs = offsets ? (ccfg[\spectrumCandidateOffsetsCents] ? [-20.0, -10.0, -5.0, 0.0, 5.0, 10.0, 20.0]);
        baseResidual = at[\perceptualCylinderResidualFor].(at[\perceptualCylinderPcForMidi].(m), m);
        costs = Array.new;
        bestCost = 999999999.0;
        bestMove = 0.0;
        bestFreq = 0.0;
        offs.do { |off|
            var sources, rough, moved;
            sources = Array.new;
            mids.do { |sm, i|
                var override, src;
                override = if(sm.asInteger == m) { baseResidual + (off ? 0.0).asFloat } { nil };
                src = at[\perceptualCylinderSpectrumSourceForMidi].(sm, profile, 1.0, 1.0, override);
                src[\sourceIndex] = i;
                sources = sources.add(src);
                if(sm.asInteger == m) { moved = src; };
            };
            rough = at[\perceptualCylinderSpectrumRoughnessForSources].(sources);
            costs = costs.add((
                moveCents: (off ? 0.0).asFloat,
                roughness: (rough[\roughnessRaw] ? 0.0).round(0.0001),
                frequency: (moved[\frequency] ? 0.0).round(0.01)
            ));
            if((rough[\roughnessRaw] ? 0.0) < bestCost) {
                bestCost = rough[\roughnessRaw] ? 0.0;
                bestMove = (off ? 0.0).asFloat;
                bestFreq = moved[\frequency] ? 0.0;
            };
        };
        (
            midi: m,
            pc: at[\perceptualCylinderPcForMidi].(m),
            pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(at[\perceptualCylinderPcForMidi].(m)) } { pcNames.wrapAt(at[\perceptualCylinderPcForMidi].(m)) },
            registerIndex: at[\perceptualCylinderRegisterIndexForMidi].(m),
            sourceMidis: mids,
            profile: profile,
            candidateCount: costs.size,
            bestMoveCents: bestMove.round(0.01),
            bestFrequency: bestFreq.round(0.01),
            bestRoughness: bestCost.round(0.0001),
            candidates: costs,
            note: "candidate is register-aware diagnostic pressure for the v3D7 bounded accordion authority/audition layer"
        );
    };

    api[\perceptualCylinderSpectrumReport] = {
        var c4Sources, c5Sources, c4H, c5H, c4I, c4Pure, c4Cand, c5Cand, rep;
        c4Sources = at[\perceptualCylinderSpectrumSourcesForMidis].([60, 64, 67], \harmonic);
        c5Sources = at[\perceptualCylinderSpectrumSourcesForMidis].([72, 76, 79], \harmonic);
        c4H = at[\perceptualCylinderSpectrumRoughnessForSources].(c4Sources);
        c5H = at[\perceptualCylinderSpectrumRoughnessForSources].(c5Sources);
        c4I = at[\perceptualCylinderSpectrumRoughnessForMidis].([60, 64, 67], \inharmonic);
        c4Pure = at[\perceptualCylinderSpectrumRoughnessForMidis].([60, 64, 67], \pure);
        c4Cand = at[\perceptualCylinderCandidateCostsForMidi].(60, [60, 64, 67], \harmonic, nil);
        c5Cand = at[\perceptualCylinderCandidateCostsForMidi].(72, [72, 76, 79], \harmonic, nil);
        rep = (
            enabled: cfg[\perceptualCylinder][\enabled] ? true,
            amount: at[\perceptualCylinderAmount].(),
            scaffoldOnly: cfg[\perceptualCylinder][\scaffoldOnly] ? true,
            spectrumEvaluatorOnly: cfg[\perceptualCylinder][\spectrumEvaluatorOnly] ? true,
            registerComparisons: [
                (label: \C4MajorHarmonic, midis: [60, 64, 67], roughness: c4H[\roughnessEstimate], partials: c4H[\partialCount]),
                (label: \C5MajorHarmonic, midis: [72, 76, 79], roughness: c5H[\roughnessEstimate], partials: c5H[\partialCount]),
                (label: \C4MajorPure, midis: [60, 64, 67], roughness: c4Pure[\roughnessEstimate], partials: c4Pure[\partialCount]),
                (label: \C4MajorInharmonic, midis: [60, 64, 67], roughness: c4I[\roughnessEstimate], partials: c4I[\partialCount])
            ],
            c4Candidate: c4Cand,
            c5Candidate: c5Cand,
            note: "v3D7 diagnostic-only/evaluator layer lets Sethares-style roughness see the cylinder; bounded accordion authority and audition render hook are optional, off by default, and only affect the residual body/render hook when explicitly enabled"
        );
        st[\perceptualCylinderSpectrumLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER SPECTRUM REPORT]".postln;
        ("enabled=" ++ rep[\enabled].asString
            ++ " amount=" ++ rep[\amount].round(0.001).asString
            ++ " evaluatorOnly=" ++ rep[\spectrumEvaluatorOnly].asString
            ++ " C4harm=" ++ c4H[\roughnessEstimate].asString
            ++ " C5harm=" ++ c5H[\roughnessEstimate].asString
            ++ " C4inh=" ++ c4I[\roughnessEstimate].asString).postln;
        rep;
    };

    at[\perceptualCylinderSpectrumReport] = { api[\perceptualCylinderSpectrumReport].() };

    // v3D7 accordion proposal/audition scaffold. This is where the register-aware
    // Sethares evaluator says "this octave sheet wants a residual." Proposals
    // remain separable from authority application; a later explicit call may copy
    // them into the residual body under bounds and protection rules.
    at[\perceptualCylinderZeroGrid] = {
        var bases, n;
        bases = at[\perceptualCylinderRegisterBases].();
        n = cfg[\solver][\numNodes] ? 12;
        Array.fill(bases.size, { Array.fill(n, 0.0) });
    };

    at[\perceptualCylinderGridAbsSum] = { |grid|
        var sum;
        sum = 0.0;
        (grid ? Array.new).do { |row| (row ? Array.new).do { |x| sum = sum + (x ? 0.0).abs; }; };
        sum;
    };

    at[\perceptualCylinderProposalForMidis] = { |midis=nil, profile=\harmonic, amountOverride=nil|
        var ccfg, mids, prof, amount, limit, grid, entries, totalAbs, maxAbs;
        ccfg = at[\perceptualCylinderConfig].();
        mids = (midis ? [60, 64, 67]).collect { |m| (m ? 60).asInteger };
        prof = (profile ? \harmonic).asSymbol;
        amount = if(amountOverride.notNil) { amountOverride.asFloat.clip(0.0, 1.0) } { at[\perceptualCylinderAmount].() };
        limit = (ccfg[\accordionProposalLimitCents] ? 24.0).abs;
        grid = at[\perceptualCylinderZeroGrid].();
        entries = Array.new;
        totalAbs = 0.0;
        maxAbs = 0.0;
        mids.do { |m|
            var cand, p, ri, raw, eff, costs, minusCost, plusCost, sourceFreq, bestFreq;
            cand = at[\perceptualCylinderCandidateCostsForMidi].(m, mids, prof, nil);
            raw = (cand[\bestMoveCents] ? 0.0).asFloat;
            costs = cand[\candidates] ? Array.new;
            minusCost = nil;
            plusCost = nil;
            costs.do { |c|
                var move, cost;
                move = (c[\moveCents] ? 0.0).asFloat;
                cost = (c[\roughness] ? 0.0).asFloat;
                if((move + 5.0).abs <= 0.001) { minusCost = cost; };
                if((move - 5.0).abs <= 0.001) { plusCost = cost; };
            };
            if(raw.abs <= 0.0001 and: { minusCost.notNil and: { plusCost.notNil and: { (minusCost - plusCost).abs > 0.000001 } } }) {
                raw = if(plusCost < minusCost) { 5.0 } { -5.0 };
            };
            raw = raw.clip(0.0 - limit, limit);
            eff = (raw * amount).clip(0.0 - limit, limit);
            p = at[\perceptualCylinderPcForMidi].(m);
            ri = at[\perceptualCylinderRegisterIndexForMidi].(m);
            grid[ri][p] = grid[ri][p] + eff;
            sourceFreq = (at[\perceptualCylinderSpectrumSourceForMidi].(m, prof)[\frequency] ? 0.0).round(0.01);
            bestFreq = cand[\bestFrequency] ? sourceFreq;
            entries = entries.add((
                midi: m,
                pc: p,
                pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(p) } { pcNames.wrapAt(p) },
                registerIndex: ri,
                profile: prof,
                sourceFrequency: sourceFreq,
                rawProposalCents: raw.round(0.01),
                effectiveProposalCents: eff.round(0.01),
                bestFrequency: bestFreq.round(0.01),
                bestRoughness: cand[\bestRoughness] ? 0.0,
                candidateCount: cand[\candidateCount] ? 0,
                note: "accordion residual proposal; v3D7 applies only through explicit bounded authority/audition"
            ));
            totalAbs = totalAbs + eff.abs;
            if(eff.abs > maxAbs) { maxAbs = eff.abs; };
        };
        st[\perceptualCylinderProposedResidualCents] = grid;
        (
            profile: prof,
            amount: amount.round(0.001),
            proposalOnly: true,
            sourceMidis: mids,
            entries: entries,
            grid: grid,
            maxAbsProposalCents: maxAbs.round(0.01),
            totalAbsProposalCents: totalAbs.round(0.01),
            note: "register-aware Sethares accordion proposal; no solver hook, render hook off by default in v3D7"
        );
    };

    at[\perceptualCylinderProposalGridDiff] = { |a, b|
        var sum;
        sum = 0.0;
        (a ? Array.new).do { |row, i|
            (row ? Array.new).do { |x, j|
                sum = sum + ((x ? 0.0) - (((b ? Array.new).wrapAt(i) ? Array.new).wrapAt(j) ? 0.0)).abs;
            };
        };
        sum.round(0.01);
    };

    at[\perceptualCylinderActiveMidis] = {
        if(at[\notesArray].notNil) { at[\notesArray].().collect { |n| (n[\midi] ? -999).asInteger } } { Array.new };
    };

    at[\perceptualCylinderExternalPcs] = {
        (st[\externalSources] ? Array.new).collect { |src| (src[\pc] ? -999).asInteger }.reject { |pc| pc < 0 };
    };

    at[\perceptualCylinderAuthorityActive] = {
        var ccfg;
        ccfg = at[\perceptualCylinderConfig].();
        ((ccfg[\enabled] ? true) == true)
            and: { ((ccfg[\accordionAuthorityEnabled] ? false) == true)
            and: { at[\perceptualCylinderAmount].() > 0.0001 } };
    };

    at[\perceptualCylinderRenderHookActive] = {
        var ccfg;
        ccfg = at[\perceptualCylinderConfig].();
        at[\perceptualCylinderAuthorityActive].()
            and: { (ccfg[\accordionRenderHookEnabled] ? false) == true };
    };

    at[\perceptualCylinderFrequencyForMidi] = { |midi=60|
        var base, pc, residual;
        base = at[\midiToFreq].(midi);
        if(at[\perceptualCylinderRenderHookActive].()) {
            pc = at[\perceptualCylinderPcForMidi].(midi);
            residual = at[\perceptualCylinderResidualFor].(pc, midi);
            base * (2 ** (residual / 1200.0));
        } {
            base;
        };
    };

    at[\perceptualCylinderApplyProposalAsAuthority] = { |midis=nil, profile=\harmonic, amountOverride=nil|
        var ccfg, proposal, appliedGrid, activeMidis, externalPcs, protectActive, protectExternal, authorityOn, limit, appliedEntries, protectedCount, appliedMax, appliedTotal;
        ccfg = at[\perceptualCylinderConfig].();
        proposal = at[\perceptualCylinderProposalForMidis].(midis, profile, amountOverride);
        appliedGrid = at[\perceptualCylinderZeroGrid].();
        activeMidis = at[\perceptualCylinderActiveMidis].();
        externalPcs = at[\perceptualCylinderExternalPcs].();
        protectActive = ccfg[\accordionProtectActive] ? true;
        protectExternal = ccfg[\accordionProtectExternal] ? true;
        authorityOn = ((ccfg[\accordionAuthorityEnabled] ? false) == true) and: { at[\perceptualCylinderAmount].() > 0.0001 };
        limit = (ccfg[\accordionAuthorityLimitCents] ? 16.0).abs;
        appliedEntries = Array.new;
        protectedCount = 0;
        appliedMax = 0.0;
        appliedTotal = 0.0;
        (proposal[\entries] ? Array.new).do { |entry|
            var m, p, ri, proposed, applied, protected, reason;
            m = (entry[\midi] ? 60).asInteger;
            p = (entry[\pc] ? (m % 12)).asInteger;
            ri = (entry[\registerIndex] ? at[\perceptualCylinderRegisterIndexForMidi].(m)).asInteger;
            proposed = (entry[\effectiveProposalCents] ? 0.0).asFloat.clip(0.0 - limit, limit);
            protected = false;
            reason = \none;
            if(protectActive and: { activeMidis.includes(m) }) { protected = true; reason = \activeMidiProtected; };
            if(protected.not and: { protectExternal and: { externalPcs.includes(p) } }) { protected = true; reason = \externalPcProtected; };
            applied = if(authorityOn and: { protected.not }) { proposed } { 0.0 };
            if(ri >= 0 and: { ri < appliedGrid.size }) { appliedGrid[ri][p] = appliedGrid[ri][p] + applied; };
            if(protected) { protectedCount = protectedCount + 1; };
            if(applied.abs > appliedMax) { appliedMax = applied.abs; };
            appliedTotal = appliedTotal + applied.abs;
            appliedEntries = appliedEntries.add(entry.copy.put(\authorityAppliedCents, applied.round(0.01)).put(\protected, protected).put(\protectionReason, reason));
        };
        st[\perceptualCylinderResidualCents] = appliedGrid;
        st[\perceptualCylinderLastApplied] = authorityOn;
        st[\perceptualCylinderAuthorityLastReport] = (
            authorityEnabled: ccfg[\accordionAuthorityEnabled] ? false,
            renderHookEnabled: ccfg[\accordionRenderHookEnabled] ? false,
            authorityActive: authorityOn,
            profile: profile,
            proposal: proposal,
            appliedGrid: appliedGrid,
            entries: appliedEntries,
            protectedEntries: protectedCount,
            maxAbsAppliedCents: appliedMax.round(0.01),
            totalAbsAppliedCents: appliedTotal.round(0.01),
            note: "v3D7 bounded accordion authority writes only the register residual body when explicitly enabled; normal audition/timbre coupling is diagnostic-only, nodePhase/solver remain untouched, and any audible render-hook pitch deformation requires explicit experimental enable"
        );
        st[\perceptualCylinderAuthorityLastReport];
    };

    api[\setPerceptualCylinderAccordionAuthorityEnabled] = { |flag=false|
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = flag == true;
        api[\perceptualCylinderAuthorityReport].();
    };

    api[\setPerceptualCylinderRenderHookEnabled] = { |flag=false|
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = flag == true;
        api[\perceptualCylinderAuthorityReport].();
    };

    api[\applyPerceptualCylinderAccordionAuthority] = { |midis=nil, profile=\harmonic, amountOverride=nil|
        at[\perceptualCylinderApplyProposalAsAuthority].(midis, profile, amountOverride);
    };

    api[\perceptualCylinderAuthorityReport] = {
        var rep, last;
        last = st[\perceptualCylinderAuthorityLastReport] ? ();
        rep = last.copy;
        rep[\authorityEnabled] = cfg[\perceptualCylinder][\accordionAuthorityEnabled] ? false;
        rep[\renderHookEnabled] = cfg[\perceptualCylinder][\accordionRenderHookEnabled] ? false;
        rep[\authorityActive] = at[\perceptualCylinderAuthorityActive].();
        rep[\maxAbsAppliedCents] = rep[\maxAbsAppliedCents] ? 0.0;
        rep[\protectedEntries] = rep[\protectedEntries] ? 0;
        rep[\note] = rep[\note] ? "v3D10 bounded accordion authority is available but off by default; normal audition is diagnostic-only";
        "".postln;
        "[AT PERCEPTUAL CYLINDER AUTHORITY REPORT]".postln;
        ("enabled=" ++ (rep[\authorityEnabled] ? false).asString
            ++ " renderHook=" ++ (rep[\renderHookEnabled] ? false).asString
            ++ " active=" ++ (rep[\authorityActive] ? false).asString
            ++ " maxApplied=" ++ (rep[\maxAbsAppliedCents] ? 0.0).asString ++ "c"
            ++ " protected=" ++ (rep[\protectedEntries] ? 0).asString).postln;
        rep;
    };




    // v3D9 timbre/formant coupling. This is intentionally conservative: it
    // does not turn the accordion into a general tuning mode. It reports whether
    // the selected tone has enough spectral/body evidence to earn register
    // deformation, and supplies small, bounded recommended amounts/limits.
    at[\perceptualCylinderToneSpec] = { |tone=nil|
        var t, spec;
        t = (tone ? (cfg[\render][\toneProfile] ? \organ)).asSymbol;
        spec = if(t == \probe) {
            (toneProfile: t, spectrumProfile: \pure, formantStrength: 0.0, inharmonicity: 0.0, accordionRelevance: \none, recommendedAmount: 0.0, recommendedAuthorityLimitCents: 0.0, formantBandsHz: [], formantBandwidthsHz: [], note: "probe/pure diagnostic tone earns no accordion deformation")
        } {
            if(t == \pure) {
                (toneProfile: t, spectrumProfile: \pure, formantStrength: 0.0, inharmonicity: 0.0, accordionRelevance: \none, recommendedAmount: 0.0, recommendedAuthorityLimitCents: 0.0, formantBandsHz: [], formantBandwidthsHz: [], note: "pure sine-like tone has no body/formant reason to deform the cylinder")
            } {
                if(t == \organ) {
                    (toneProfile: t, spectrumProfile: \harmonic, formantStrength: 0.08, inharmonicity: 0.0, accordionRelevance: \veryLow, recommendedAmount: 0.02, recommendedAuthorityLimitCents: 2.0, formantBandsHz: [700, 1800], formantBandwidthsHz: [600, 1200], note: "organ is mostly harmonic; accordion should be nearly zero and only a tiny color correction")
                } {
                    if(t == \piano) {
                        (toneProfile: t, spectrumProfile: \pianoStretch, formantStrength: 0.42, inharmonicity: 0.32, accordionRelevance: \medium, recommendedAmount: 0.10, recommendedAuthorityLimitCents: 7.0, formantBandsHz: [180, 520, 2100, 4300], formantBandwidthsHz: [120, 260, 900, 1500], note: "piano needs sample/body-dependent mild stretch; fallback piano should keep this conservative")
                    } {
                        if(t == \electricPiano) {
                            (toneProfile: t, spectrumProfile: \pianoStretch, formantStrength: 0.30, inharmonicity: 0.18, accordionRelevance: \lowMedium, recommendedAmount: 0.06, recommendedAuthorityLimitCents: 5.0, formantBandsHz: [240, 900, 2600], formantBandwidthsHz: [180, 650, 1300], note: "electric piano is mildly body-colored; accordion remains subtle and sample-dependent")
                        } {
                            if(t == \pad) {
                                (toneProfile: t, spectrumProfile: \harmonic, formantStrength: 0.24, inharmonicity: 0.08, accordionRelevance: \low, recommendedAmount: 0.04, recommendedAuthorityLimitCents: 4.0, formantBandsHz: [500, 1600, 3600], formantBandwidthsHz: [900, 1600, 2200], note: "pad has broad spectral body; only weak register correction is earned")
                            } {
                                if(t == \synth) {
                                    (toneProfile: t, spectrumProfile: \harmonic, formantStrength: 0.18, inharmonicity: 0.04, accordionRelevance: \low, recommendedAmount: 0.03, recommendedAuthorityLimitCents: 3.0, formantBandsHz: [900, 2400], formantBandwidthsHz: [900, 1800], note: "generic synth defaults to harmonic/low accordion relevance unless a specific inharmonic patch exists")
                                } {
                                    if(t == \bellLike) {
                                        (toneProfile: t, spectrumProfile: \bellLike, formantStrength: 0.82, inharmonicity: 0.75, accordionRelevance: \high, recommendedAmount: 0.35, recommendedAuthorityLimitCents: 16.0, formantBandsHz: [380, 1020, 2360, 5100], formantBandwidthsHz: [80, 160, 320, 760], note: "bell-like inharmonic body can legitimately earn strong non-octave/register deformation")
                                    } {
                                        if(t == \formantVoice) {
                                            (toneProfile: t, spectrumProfile: \formantVoice, formantStrength: 0.62, inharmonicity: 0.05, accordionRelevance: \medium, recommendedAmount: 0.12, recommendedAuthorityLimitCents: 8.0, formantBandsHz: [650, 1100, 2500, 3500], formantBandwidthsHz: [90, 120, 180, 300], note: "voice-like formants constrain where harmonic partials fit inside the resonant body")
                                        } {
                                            (toneProfile: t, spectrumProfile: \harmonic, formantStrength: 0.10, inharmonicity: 0.0, accordionRelevance: \veryLow, recommendedAmount: 0.02, recommendedAuthorityLimitCents: 2.0, formantBandsHz: [], formantBandwidthsHz: [], note: "unknown tone defaults to conservative harmonic/low accordion relevance")
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
        spec.put(\bodyModel, \timbreFormantCoupled);
        spec.put(\spectralWeightingOnly, true);
        spec.put(\directPitchAuthorityDefault, false);
        spec.put(\recommendedPitchAmount, 0.0);
        spec.put(\pitchRecommendation, \diagnosticOnly);
        spec.put(\mode, cfg[\perceptualCylinder][\accordionProfileMode] ? \manual);
        spec.put(\couplingEnabled, cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] ? false);
        spec;
    };

    at[\perceptualCylinderDefaultMidisForTone] = { |tone=nil|
        var t;
        t = (tone ? (cfg[\render][\toneProfile] ? \organ)).asSymbol;
        if(t == \bellLike) { [60, 63, 67, 70] } {
            if(t == \formantVoice) { [60, 64, 67] } {
                if(t == \piano or: { t == \electricPiano }) { [48, 60, 64, 67, 72] } { [60, 64, 67] };
            };
        };
    };

    at[\perceptualCylinderFormantFitEstimate] = { |midis=nil, tone=nil|
        var spec, mids, bands, widths, score, count;
        spec = at[\perceptualCylinderToneSpec].(tone);
        mids = midis ? at[\perceptualCylinderDefaultMidisForTone].(spec[\toneProfile]);
        bands = spec[\formantBandsHz] ? [];
        widths = spec[\formantBandwidthsHz] ? [];
        score = 0.0;
        count = 0;
        mids.do { |m|
            var f;
            f = at[\midiToFreq].(m);
            bands.do { |b, i|
                var w, d;
                w = (widths.wrapAt(i) ? 600.0).asFloat.max(50.0);
                d = ((f - b).abs / w).clip(0.0, 4.0);
                score = score + (1.0 / (1.0 + d));
                count = count + 1;
            };
        };
        if(count > 0) { (score / count).round(0.001) } { 0.0 };
    };

    at[\perceptualCylinderActualSpectrumTruth] = { |tone=nil|
        var t, declared, assetStatus, actualProfile, actualStatus, actualAvailable, synthDef, ordinarySupport, relatedScaleMayDiffer, pitchAuthorityEligible, reason;
        t = (tone ? (cfg[\render][\toneProfile] ? \organ)).asSymbol;
        declared = at[\perceptualCylinderToneSpec].(t);
        synthDef = if(at[\toneProfileDefName].notNil) { at[\toneProfileDefName].(t) } { \unknown };
        assetStatus = \notRequired;
        actualProfile = declared[\spectrumProfile] ? \harmonic;
        actualStatus = \actualRenderedModel;
        actualAvailable = true;
        ordinarySupport = \high;
        relatedScaleMayDiffer = false;
        pitchAuthorityEligible = false;
        reason = "actual rendered tone has a conservative declared spectrum; v3D10 keeps this diagnostic and blocks pitch authority";

        if(t == \probe or: { t == \pure }) {
            actualProfile = \pure;
            actualStatus = \actualRenderedModel;
            ordinarySupport = \high;
            relatedScaleMayDiffer = false;
            reason = "pure/probe tone has one simple partial model; ordinary octave identity is supported and no cylinder pitch authority is earned";
        };
        if(t == \organ) {
            actualProfile = \harmonic;
            actualStatus = \actualRenderedModel;
            ordinarySupport = \high;
            relatedScaleMayDiffer = false;
            reason = "organ is actual rendered harmonic-series-like tone; ordinary 12-note/octave identity is strongly supported";
        };
        if(t == \pad or: { t == \synth }) {
            actualProfile = \harmonic;
            actualStatus = \estimatedSynthetic;
            ordinarySupport = \high;
            relatedScaleMayDiffer = false;
            reason = "pad/synth use conservative harmonic estimated spectra until patch-specific analysis exists";
        };
        if(t == \piano) {
            assetStatus = if(at[\pianoAssets].notNil) { at[\pianoAssets][\status] ? \unknown } { \missing };
            if(assetStatus == \complete) {
                actualProfile = \pianoStretch;
                actualStatus = \actualSampleSource;
                actualAvailable = true;
                ordinarySupport = \mediumHigh;
                relatedScaleMayDiffer = false;
                reason = "complete piano sample source exists; piano-stretch spectrum may be analyzed, but v3D10 still keeps pitch authority blocked pending musical proof";
            } {
                actualProfile = \pure;
                actualStatus = \fallbackBlocked;
                actualAvailable = false;
                ordinarySupport = \unknown;
                relatedScaleMayDiffer = false;
                reason = "piano samples are missing/partial, so pianoStretch is only a declared target; actual rendered tone falls back and no piano-stretch claim is trusted";
            };
        };
        if(t == \electricPiano) {
            assetStatus = if(at[\epianoAssets].notNil) { at[\epianoAssets][\status] ? \unknown } { \missing };
            if(assetStatus == \complete) {
                actualProfile = \pianoStretch;
                actualStatus = \actualSampleSource;
                actualAvailable = true;
                ordinarySupport = \mediumHigh;
                relatedScaleMayDiffer = false;
                reason = "complete electric-piano source exists; mild spectrum/body audit may be meaningful, but pitch authority remains blocked";
            } {
                actualProfile = \pure;
                actualStatus = \fallbackBlocked;
                actualAvailable = false;
                ordinarySupport = \unknown;
                relatedScaleMayDiffer = false;
                reason = "electricPiano samples are missing/partial, so EP spectrum claims are blocked and actual render falls back";
            };
        };
        if(t == \bellLike) {
            assetStatus = \diagnosticOnly;
            actualProfile = \bellLike;
            actualStatus = \diagnosticModelOnly;
            actualAvailable = false;
            ordinarySupport = \low;
            relatedScaleMayDiffer = true;
            reason = "bellLike is a diagnostic spectrum, not a built-in rendered tone; it may imply non-octave/related-scale behavior only if an actual bell-like sound is supplied";
        };
        if(t == \formantVoice) {
            assetStatus = \diagnosticOnly;
            actualProfile = \formantVoice;
            actualStatus = \diagnosticModelOnly;
            actualAvailable = false;
            ordinarySupport = \high;
            relatedScaleMayDiffer = false;
            reason = "formantVoice is a diagnostic body/envelope model: formants weight harmonic partial amplitudes but do not themselves create inharmonic partial frequencies";
        };

        (
            toneProfile: t,
            synthDef: synthDef,
            declaredSpectrumProfile: declared[\spectrumProfile] ? \harmonic,
            actualSpectrumProfile: actualProfile,
            truthStatus: actualStatus,
            assetStatus: assetStatus,
            actualRenderedSpectrumAvailable: actualAvailable,
            ordinaryOctaveSupport: ordinarySupport,
            relatedScaleMayDiffer: relatedScaleMayDiffer,
            pitchAuthorityEligible: pitchAuthorityEligible,
            formantsAffectPartialWeights: true,
            formantsDirectlyRetuneFundamentals: false,
            inharmonicityChangesPartialFrequencies: true,
            inharmonicityAmplitudeWeightMayDecay: true,
            note: reason
        );
    };


    // v3D10 actual-spectrum descriptor path. This is still diagnostic/no-pitch:
    // it produces a concrete partial list for the actual rendered/fallback/model
    // status, lets piano-like modal frequencies stay fixed over time while
    // amplitudes decay, and lets formant/body filters reweight partial
    // amplitudes without moving partial frequencies or fundamentals.
    at[\perceptualCylinderPartialSetForProfile] = { |profile=\harmonic, baseFreq=261.6256, ageSeconds=0.0|
        var p, f, age, raw, partials;
        p = (profile ? \harmonic).asSymbol;
        f = (baseFreq ? 261.6256).asFloat.max(1.0);
        age = (ageSeconds ? 0.0).asFloat.max(0.0);
        raw = if(p == \pure) {
            [[1.0, 1.0]]
        } {
            if(p == \pianoStretch) {
                // Stiff-string/modal ratios stay inharmonic. Only amplitudes
                // change with age, especially in the upper partials.
                [[1.0, 1.0], [2.006, 0.55], [3.024, 0.34], [4.056, 0.22], [5.105, 0.15], [6.168, 0.10], [7.252, 0.07], [8.352, 0.05]]
            } {
                if(p == \bellLike) {
                    [[1.0, 1.0], [1.41, 0.72], [2.03, 0.54], [2.76, 0.38], [3.92, 0.25], [5.38, 0.16], [6.81, 0.10]]
                } {
                    if(p == \formantVoice) {
                        [[1.0, 1.0], [2.0, 0.48], [3.0, 0.30], [4.0, 0.18], [5.0, 0.10], [6.0, 0.06]]
                    } {
                        [[1.0, 1.0], [2.0, 0.52], [3.0, 0.31], [4.0, 0.20], [5.0, 0.13], [6.0, 0.09], [7.0, 0.06], [8.0, 0.04]]
                    };
                };
            };
        };
        partials = raw.collect { |pair, i|
            var ratio, amp, decay, ageAmp;
            ratio = (pair[0] ? 1.0).asFloat;
            amp = (pair[1] ? 0.0).asFloat;
            decay = if(p == \pianoStretch) { 1.0 / (1.0 + (age * (i.asFloat + 1.0) * 0.55)) } { 1.0 };
            ageAmp = amp * decay;
            (
                index: i + 1,
                ratio: ratio.round(0.0001),
                frequency: (f * ratio).round(0.01),
                amplitude: amp.round(0.0001),
                ageWeightedAmplitude: ageAmp.round(0.0001),
                formantWeightedAmplitude: ageAmp.round(0.0001)
            )
        };
        partials;
    };

    at[\perceptualCylinderApplyFormantWeightsToPartials] = { |partials, formantTone=nil|
        var tone, spec, bands, widths, strength;
        tone = (formantTone ? \none).asSymbol;
        spec = at[\perceptualCylinderToneSpec].(tone);
        bands = spec[\formantBandsHz] ? [];
        widths = spec[\formantBandwidthsHz] ? [];
        strength = (spec[\formantStrength] ? 0.0).asFloat.max(0.0);
        (partials ? Array.new).collect { |part|
            var freq, amp, weight, out;
            freq = (part[\frequency] ? 0.0).asFloat;
            amp = (part[\ageWeightedAmplitude] ? (part[\amplitude] ? 0.0)).asFloat;
            weight = 1.0;
            bands.do { |band, i|
                var width, d, local;
                width = (widths.wrapAt(i) ? 500.0).asFloat.max(50.0);
                d = ((freq - (band ? 0.0).asFloat).abs / width).clip(0.0, 20.0);
                local = 1.0 / (1.0 + (d * d));
                weight = weight + (strength * local);
            };
            out = part.copy;
            out[\formantWeight] = weight.round(0.0001);
            out[\formantWeightedAmplitude] = (amp * weight).round(0.0001);
            out;
        };
    };

    at[\perceptualCylinderDescriptorForTone] = { |tone=nil, midi=60, ageSeconds=0.0, formantTone=nil|
        var truth, baseFreq, actualProfile, actualPartials, formantPartials, formantApplied, ampSum, weightedAmpSum, upperWeight, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        baseFreq = at[\midiToFreq].(midi ? 60);
        actualProfile = truth[\actualSpectrumProfile] ? \harmonic;
        actualPartials = at[\perceptualCylinderPartialSetForProfile].(actualProfile, baseFreq, ageSeconds);
        formantApplied = formantTone.notNil and: { (formantTone.asSymbol != \none) };
        formantPartials = if(formantApplied) { at[\perceptualCylinderApplyFormantWeightsToPartials].(actualPartials, formantTone) } { actualPartials };
        ampSum = 0.0;
        weightedAmpSum = 0.0;
        upperWeight = 0.0;
        formantPartials.do { |part, i|
            ampSum = ampSum + (part[\ageWeightedAmplitude] ? 0.0).asFloat;
            weightedAmpSum = weightedAmpSum + (part[\formantWeightedAmplitude] ? 0.0).asFloat;
            if(i >= 3) { upperWeight = upperWeight + (part[\formantWeightedAmplitude] ? 0.0).asFloat; };
        };
        rep = (
            toneProfile: truth[\toneProfile],
            midi: (midi ? 60).asInteger,
            baseFrequency: baseFreq.round(0.01),
            ageSeconds: (ageSeconds ? 0.0).asFloat.round(0.001),
            declaredSpectrumProfile: truth[\declaredSpectrumProfile],
            actualSpectrumProfile: actualProfile,
            truthStatus: truth[\truthStatus],
            assetStatus: truth[\assetStatus],
            descriptorSource: truth[\truthStatus],
            actualRenderedSpectrumAvailable: truth[\actualRenderedSpectrumAvailable],
            sampleVerified: (truth[\assetStatus] == \complete),
            fallbackBlocked: (truth[\truthStatus] == \fallbackBlocked),
            diagnosticModelOnly: (truth[\truthStatus] == \diagnosticModelOnly),
            partials: formantPartials,
            partialCount: formantPartials.size,
            amplitudeSum: ampSum.round(0.0001),
            formantWeightedAmplitudeSum: weightedAmpSum.round(0.0001),
            upperPartialWeightedAmplitude: upperWeight.round(0.0001),
            formantApplied: formantApplied,
            formantTone: if(formantApplied) { formantTone.asSymbol } { \none },
            partialFrequenciesMoveWithAge: false,
            formantsMovePartialFrequencies: false,
            pitchAuthorityEligible: false,
            note: "v3D10 actual-spectrum descriptor is diagnostic/no-pitch: it describes the actual rendered/fallback/model partials and optional formant weighting without writing tuning or residuals"
        );
        rep;
    };

    api[\perceptualCylinderActualSpectrumDescriptor] = { |tone=nil, midi=60, ageSeconds=0.0, formantTone=nil|
        var rep;
        rep = at[\perceptualCylinderDescriptorForTone].(tone, midi, ageSeconds, formantTone);
        st[\perceptualCylinderActualSpectrumLastDescriptor] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER ACTUAL SPECTRUM DESCRIPTOR]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " actual=" ++ (rep[\actualSpectrumProfile] ? \unknown).asString
            ++ " truth=" ++ (rep[\truthStatus] ? \unknown).asString
            ++ " partials=" ++ (rep[\partialCount] ? 0).asString
            ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };


    // v3D11 measured-spectrum evidence bridge. This is deliberately no-pitch:
    // it stores or reports partial evidence from an external/measured/rendered
    // source and compares that evidence against declared/descriptor models, but
    // it never authorizes accordion residuals, render-hook pitch changes, or
    // fundamental retuning.
    at[\perceptualCylinderMeasuredSpectraEnsure] = {
        if(st[\perceptualCylinderMeasuredSpectra].isNil) { st[\perceptualCylinderMeasuredSpectra] = IdentityDictionary.new; };
        st[\perceptualCylinderMeasuredSpectra];
    };

    at[\perceptualCylinderNormalizeMeasuredPartials] = { |partials=nil, baseFreq=261.6256|
        var f, raw;
        f = (baseFreq ? 261.6256).asFloat.max(1.0);
        raw = partials ? [];
        raw.collect { |pair, i|
            var ratio, amp;
            ratio = if(pair.isArray) { (pair[0] ? 1.0).asFloat } { (pair[\ratio] ? 1.0).asFloat };
            amp = if(pair.isArray) { (pair[1] ? 0.0).asFloat } { (pair[\amplitude] ? (pair[\amp] ? 0.0)).asFloat };
            (
                index: i + 1,
                ratio: ratio.round(0.0001),
                frequency: (f * ratio).round(0.01),
                amplitude: amp.round(0.0001),
                ageWeightedAmplitude: amp.round(0.0001),
                formantWeightedAmplitude: amp.round(0.0001),
                evidenceMeasured: true
            )
        };
    };

    at[\perceptualCylinderAverageRatioError] = { |aPartials=nil, bPartials=nil|
        var n, sum;
        n = ((aPartials ? []).size).min((bPartials ? []).size);
        sum = 0.0;
        if(n <= 0) { 999.0 } {
            n.do { |i|
                var r0, r1;
                r0 = (((aPartials ? []).wrapAt(i) ? ())[\ratio] ? 1.0).asFloat;
                r1 = (((bPartials ? []).wrapAt(i) ? ())[\ratio] ? 1.0).asFloat;
                sum = sum + (r0 - r1).abs;
            };
            (sum / n).round(0.0001)
        };
    };

    at[\perceptualCylinderMeasuredInharmonicityScore] = { |partials=nil|
        var n, sum;
        n = 0;
        sum = 0.0;
        (partials ? []).do { |part, i|
            var ratio, nearest, d;
            ratio = (part[\ratio] ? 1.0).asFloat;
            if(i > 0) {
                nearest = ratio.round(1.0).max(1.0);
                d = (ratio - nearest).abs.min(0.5);
                sum = sum + d;
                n = n + 1;
            };
        };
        if(n > 0) { (sum / n).round(0.0001) } { 0.0 };
    };

    api[\setPerceptualCylinderMeasuredSpectrum] = { |tone=\organ, partials=nil, sourceTag=\manualMeasured, confidence=0.7|
        var t, store, clean, rep;
        at[\perceptualCylinderEnsure].();
        t = (tone ? \organ).asSymbol;
        store = at[\perceptualCylinderMeasuredSpectraEnsure].();
        clean = (partials ? [[1.0, 1.0]]).collect { |pair|
            if(pair.isArray) { [(pair[0] ? 1.0).asFloat, (pair[1] ? 0.0).asFloat] } { [(pair[\ratio] ? 1.0).asFloat, (pair[\amplitude] ? (pair[\amp] ? 0.0)).asFloat] };
        };
        rep = (
            toneProfile: t,
            sourceTag: (sourceTag ? \manualMeasured).asSymbol,
            confidence: (confidence ? 0.7).asFloat.clip(0.0, 1.0),
            storedPartialPairs: clean,
            measuredPartialCount: clean.size,
            measuredSpectrumAvailable: true,
            pitchAuthorityEligible: false,
            evidenceCanAuthorizePitch: false,
            note: "v3D11 stores measured/rendered partial evidence for diagnostics only; evidence comparison cannot retune fundamentals or enable cylinder pitch authority"
        );
        store[t] = rep;
        st[\perceptualCylinderMeasuredSpectrumLastSet] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER MEASURED SPECTRUM SET]".postln;
        ("tone=" ++ t.asString ++ " partials=" ++ clean.size.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\clearPerceptualCylinderMeasuredSpectrum] = { |tone=\organ|
        var t, store, rep;
        at[\perceptualCylinderEnsure].();
        t = (tone ? \organ).asSymbol;
        store = at[\perceptualCylinderMeasuredSpectraEnsure].();
        store.removeAt(t);
        rep = (toneProfile: t, measuredSpectrumAvailable: false, pitchAuthorityEligible: false, note: "v3D11 cleared measured-spectrum evidence for this tone; pitch authority remains blocked");
        st[\perceptualCylinderMeasuredSpectrumLastClear] = rep;
        rep;
    };

    api[\perceptualCylinderMeasuredSpectrumReport] = { |tone=\organ, midi=60|
        var t, store, entry, baseFreq, measuredPartials, truth, descriptor, err, score, octaveSupport, related, rep;
        at[\perceptualCylinderEnsure].();
        t = (tone ? \organ).asSymbol;
        store = at[\perceptualCylinderMeasuredSpectraEnsure].();
        entry = store[t];
        truth = at[\perceptualCylinderActualSpectrumTruth].(t);
        descriptor = at[\perceptualCylinderDescriptorForTone].(t, midi, 0.0, nil);
        if(entry.isNil) {
            rep = (
                toneProfile: t,
                measuredSpectrumAvailable: false,
                measuredPartialCount: 0,
                actualTruthStatus: truth[\truthStatus],
                pitchAuthorityEligible: false,
                evidenceCanAuthorizePitch: false,
                note: "v3D11 has no measured/rendered partial evidence stored for this tone; use sample verification, live/offline analysis, or setPerceptualCylinderMeasuredSpectrum for diagnostics"
            );
        } {
            baseFreq = at[\midiToFreq].(midi ? 60);
            measuredPartials = at[\perceptualCylinderNormalizeMeasuredPartials].(entry[\storedPartialPairs], baseFreq);
            err = at[\perceptualCylinderAverageRatioError].(measuredPartials, descriptor[\partials]);
            score = at[\perceptualCylinderMeasuredInharmonicityScore].(measuredPartials);
            octaveSupport = if(score < 0.035) { \high } { if(score < 0.12) { \medium } { \low } };
            related = (octaveSupport == \low);
            rep = entry.copy;
            rep[\midi] = (midi ? 60).asInteger;
            rep[\baseFrequency] = baseFreq.round(0.01);
            rep[\partials] = measuredPartials;
            rep[\actualTruthStatus] = truth[\truthStatus];
            rep[\actualDescriptorProfile] = descriptor[\actualSpectrumProfile];
            rep[\actualDescriptorPartialCount] = descriptor[\partialCount];
            rep[\averageRatioErrorVsDescriptor] = err;
            rep[\measuredInharmonicityScore] = score;
            rep[\ordinaryOctaveSupportFromMeasurement] = octaveSupport;
            rep[\relatedScaleMayDifferFromMeasurement] = related;
            rep[\measuredEvidenceAvailable] = true;
            rep[\pitchAuthorityEligible] = false;
            rep[\evidenceCanAuthorizePitch] = false;
            rep[\note] = "v3D11 measured-spectrum evidence can inform diagnostics and future research, but does not by itself authorize pitch movement; ordinary recognizability and explicit later gates are still required";
        };
        st[\perceptualCylinderMeasuredSpectrumLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER MEASURED SPECTRUM REPORT]".postln;
        ("tone=" ++ t.asString ++ " measured=" ++ (rep[\measuredSpectrumAvailable] ? false).asString ++ " partials=" ++ (rep[\measuredPartialCount] ? 0).asString ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderSpectrumEvidenceReport] = { |tone=\organ, midi=60|
        var truth, measured, sample, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        measured = api[\perceptualCylinderMeasuredSpectrumReport].(tone, midi);
        sample = api[\perceptualCylinderSampleTruthReport].(tone);
        rep = (
            toneProfile: truth[\toneProfile],
            declaredSpectrumProfile: truth[\declaredSpectrumProfile],
            actualSpectrumProfile: truth[\actualSpectrumProfile],
            truthStatus: truth[\truthStatus],
            sampleVerified: sample[\sampleVerified] ? false,
            measuredSpectrumAvailable: measured[\measuredSpectrumAvailable] ? false,
            measuredPartialCount: measured[\measuredPartialCount] ? 0,
            measuredInharmonicityScore: measured[\measuredInharmonicityScore] ? nil,
            ordinaryOctaveSupportFromMeasurement: measured[\ordinaryOctaveSupportFromMeasurement] ? truth[\ordinaryOctaveSupport],
            relatedScaleMayDifferFromMeasurement: measured[\relatedScaleMayDifferFromMeasurement] ? false,
            pitchAuthorityEligible: false,
            evidenceCanAuthorizePitch: false,
            note: "v3D11 combines sample truth, rendered-model truth, and measured/manual spectrum evidence into a no-pitch evidence report; evidence is necessary but not sufficient for future pitch authority"
        );
        st[\perceptualCylinderSpectrumEvidenceLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER SPECTRUM EVIDENCE REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString ++ " measured=" ++ (rep[\measuredSpectrumAvailable] ? false).asString ++ " sampleVerified=" ++ (rep[\sampleVerified] ? false).asString ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderRenderedSpectrumCapturePlan] = { |tone=\organ|
        var truth, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        rep = (
            toneProfile: truth[\toneProfile],
            liveFftMeasured: false,
            offlineDescriptorAvailable: true,
            measuredSpectrumStoreAvailable: true,
            sampleVerificationRequired: (truth[\truthStatus] == \fallbackBlocked),
            pitchAuthorityEligible: false,
            note: "v3D11 does not pretend a live FFT has occurred; this plan records the next evidence steps: verify samples, capture/render FFT or supply measured partials, compare descriptors, then keep pitch blocked until recognizability is proven"
        );
        st[\perceptualCylinderRenderedSpectrumCaptureLastPlan] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER RENDERED SPECTRUM CAPTURE PLAN]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString ++ " fftMeasured=" ++ (rep[\liveFftMeasured] ? false).asString ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderSpectrumEvolutionReport] = { |tone=\piano, midi=60|
        var t, baseFreq, attack, tail, maxFreqDiff, upperDrop, rep;
        t = (tone ? \piano).asSymbol;
        baseFreq = at[\midiToFreq].(midi ? 60);
        if(t == \pianoStretch) {
            attack = (toneProfile: \pianoStretch, partialCount: 8, upperPartialWeightedAmplitude: 0.0, partials: at[\perceptualCylinderPartialSetForProfile].(\pianoStretch, baseFreq, 0.0));
            tail = (toneProfile: \pianoStretch, partialCount: 8, upperPartialWeightedAmplitude: 0.0, partials: at[\perceptualCylinderPartialSetForProfile].(\pianoStretch, baseFreq, 3.0));
            attack[\partials].do { |part, i| if(i >= 3) { attack[\upperPartialWeightedAmplitude] = (attack[\upperPartialWeightedAmplitude] ? 0.0) + (part[\ageWeightedAmplitude] ? 0.0); }; };
            tail[\partials].do { |part, i| if(i >= 3) { tail[\upperPartialWeightedAmplitude] = (tail[\upperPartialWeightedAmplitude] ? 0.0) + (part[\ageWeightedAmplitude] ? 0.0); }; };
            attack[\upperPartialWeightedAmplitude] = (attack[\upperPartialWeightedAmplitude] ? 0.0).round(0.0001);
            tail[\upperPartialWeightedAmplitude] = (tail[\upperPartialWeightedAmplitude] ? 0.0).round(0.0001);
        } {
            attack = at[\perceptualCylinderDescriptorForTone].(t, midi, 0.0, nil);
            tail = at[\perceptualCylinderDescriptorForTone].(t, midi, 3.0, nil);
        };
        maxFreqDiff = 0.0;
        attack[\partials].do { |part, i|
            var f0, f1, d;
            f0 = (part[\frequency] ? 0.0).asFloat;
            f1 = ((tail[\partials].wrapAt(i) ? ())[\frequency] ? f0).asFloat;
            d = (f1 - f0).abs;
            if(d > maxFreqDiff) { maxFreqDiff = d; };
        };
        upperDrop = ((attack[\upperPartialWeightedAmplitude] ? 0.0).asFloat - (tail[\upperPartialWeightedAmplitude] ? 0.0).asFloat).max(0.0);
        rep = (
            toneProfile: t,
            midi: (midi ? 60).asInteger,
            attackPartialCount: attack[\partialCount],
            tailPartialCount: tail[\partialCount],
            maxFrequencyDriftHz: maxFreqDiff.round(0.0001),
            upperPartialWeightAttack: attack[\upperPartialWeightedAmplitude],
            upperPartialWeightTail: tail[\upperPartialWeightedAmplitude],
            upperPartialWeightDrop: upperDrop.round(0.0001),
            frequenciesDecayToHarmonic: false,
            amplitudesCanDecay: true,
            pitchAuthorityEligible: false,
            note: "v3D10 spectrum evolution keeps modal/partial frequencies fixed over note age; time variation is amplitude/perceptual-weight decay"
        );
        st[\perceptualCylinderSpectrumEvolutionLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER SPECTRUM EVOLUTION REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " freqDrift=" ++ (rep[\maxFrequencyDriftHz] ? 0.0).asString ++ "Hz"
            ++ " upperDrop=" ++ (rep[\upperPartialWeightDrop] ? 0.0).asString
            ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderFormantAppliedSpectrumReport] = { |tone=\organ, formantTone=\formantVoice, midi=60|
        var plain, weighted, maxFreqDiff, ampDiff, rep;
        plain = at[\perceptualCylinderDescriptorForTone].(tone, midi, 0.0, nil);
        weighted = at[\perceptualCylinderDescriptorForTone].(tone, midi, 0.0, formantTone);
        maxFreqDiff = 0.0;
        plain[\partials].do { |part, i|
            var f0, f1, d;
            f0 = (part[\frequency] ? 0.0).asFloat;
            f1 = ((weighted[\partials].wrapAt(i) ? ())[\frequency] ? f0).asFloat;
            d = (f1 - f0).abs;
            if(d > maxFreqDiff) { maxFreqDiff = d; };
        };
        ampDiff = ((weighted[\formantWeightedAmplitudeSum] ? 0.0).asFloat - (plain[\formantWeightedAmplitudeSum] ? 0.0).asFloat).abs;
        rep = (
            toneProfile: (tone ? \organ).asSymbol,
            formantTone: (formantTone ? \formantVoice).asSymbol,
            plainAmplitudeSum: plain[\formantWeightedAmplitudeSum],
            weightedAmplitudeSum: weighted[\formantWeightedAmplitudeSum],
            amplitudeWeightDifference: ampDiff.round(0.0001),
            maxFrequencyShiftHz: maxFreqDiff.round(0.0001),
            formantsWeightPartials: true,
            formantsMoveFrequencies: false,
            formantsRetuneFundamentals: false,
            pitchAuthorityEligible: false,
            note: "v3D10 formant/body report applies optional spectral-envelope weighting to partial amplitudes only; frequencies and fundamentals do not move"
        );
        st[\perceptualCylinderFormantAppliedLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER FORMANT-APPLIED SPECTRUM REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " formant=" ++ (rep[\formantTone] ? \unknown).asString
            ++ " ampDiff=" ++ (rep[\amplitudeWeightDifference] ? 0.0).asString
            ++ " freqShift=" ++ (rep[\maxFrequencyShiftHz] ? 0.0).asString ++ "Hz").postln;
        rep;
    };

    api[\perceptualCylinderSampleTruthReport] = { |tone=\piano|
        var truth, desc, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        desc = at[\perceptualCylinderDescriptorForTone].(tone, 60, 0.0, nil);
        rep = (
            toneProfile: truth[\toneProfile],
            assetStatus: truth[\assetStatus],
            truthStatus: truth[\truthStatus],
            actualSpectrumProfile: truth[\actualSpectrumProfile],
            declaredSpectrumProfile: truth[\declaredSpectrumProfile],
            sampleVerified: (truth[\assetStatus] == \complete),
            fallbackBlocked: (truth[\truthStatus] == \fallbackBlocked),
            actualPartialCount: desc[\partialCount],
            pitchAuthorityEligible: false,
            note: "v3D10 sample-truth report blocks piano/EP stretch claims unless real sample assets are verified; fallback render spectra are not allowed to authorize pitch movement"
        );
        st[\perceptualCylinderSampleTruthLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER SAMPLE TRUTH REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " asset=" ++ (rep[\assetStatus] ? \unknown).asString
            ++ " truth=" ++ (rep[\truthStatus] ? \unknown).asString
            ++ " actual=" ++ (rep[\actualSpectrumProfile] ? \unknown).asString
            ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderSpectralTruthReport] = { |tone=nil, midis=nil|
        var truth, declaredSpec, mids, actualRough, declaredRough, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        declaredSpec = at[\perceptualCylinderToneSpec].(truth[\toneProfile]);
        mids = midis ? at[\perceptualCylinderDefaultMidisForTone].(truth[\toneProfile]);
        actualRough = at[\perceptualCylinderSpectrumRoughnessForMidis].(mids, truth[\actualSpectrumProfile]);
        declaredRough = at[\perceptualCylinderSpectrumRoughnessForMidis].(mids, truth[\declaredSpectrumProfile]);
        rep = truth.copy;
        rep[\midis] = mids;
        rep[\declaredRoughnessEstimate] = declaredRough[\roughnessEstimate] ? 0.0;
        rep[\actualRoughnessEstimate] = actualRough[\roughnessEstimate] ? 0.0;
        rep[\declaredPartialCount] = declaredRough[\partialCount] ? 0;
        rep[\actualPartialCount] = actualRough[\partialCount] ? 0;
        rep[\accordionPitchAuthorityDefault] = false;
        rep[\spectralTruthAuditOnly] = true;
        rep[\recommendation] = if((truth[\pitchAuthorityEligible] ? false) == true) { \diagnosticFirst } { \blockPitchAuthority };
        rep[\note] = (truth[\note] ? "") ++ "; v3D11 separates declared spectrum, actual rendered/fallback descriptors, measured-spectrum evidence, formant weighting, sample truth, and ordinary-recognizability before any pitch authority";
        st[\perceptualCylinderSpectralTruthLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER SPECTRAL TRUTH REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " declared=" ++ (rep[\declaredSpectrumProfile] ? \unknown).asString
            ++ " actual=" ++ (rep[\actualSpectrumProfile] ? \unknown).asString
            ++ " truth=" ++ (rep[\truthStatus] ? \unknown).asString
            ++ " octaveSupport=" ++ (rep[\ordinaryOctaveSupport] ? \unknown).asString
            ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderToneSpectrumReport] = { |tone=nil, midis=nil|
        api[\perceptualCylinderSpectralTruthReport].(tone, midis)
    };

    api[\perceptualCylinderPianoInharmonicityReport] = { |midi=60|
        var truth, rep;
        truth = at[\perceptualCylinderActualSpectrumTruth].(\piano);
        rep = (
            toneProfile: \piano,
            midi: midi,
            assetStatus: truth[\assetStatus],
            sampleVerified: (truth[\assetStatus] == \complete),
            stringInharmonicityMechanism: \stiffStringModes,
            partialFrequenciesDecayToHarmonic: false,
            partialAmplitudeWeightsCanDecay: true,
            attackWeight: 1.0,
            sustainWeight: 0.35,
            pitchAuthorityEligible: false,
            diagnosticOnly: true,
            note: "piano string inharmonicity comes from stiff-string modal frequencies; the frequencies do not settle into harmonic ratios during one note, but upper-partial amplitudes can decay so the perceptual weight of inharmonicity changes over time"
        );
        st[\perceptualCylinderPianoInharmonicityLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER PIANO INHARMONICITY REPORT]".postln;
        ("assetStatus=" ++ (rep[\assetStatus] ? \unknown).asString
            ++ " freqDecayToHarmonic=" ++ rep[\partialFrequenciesDecayToHarmonic].asString
            ++ " amplitudeWeightCanDecay=" ++ rep[\partialAmplitudeWeightsCanDecay].asString).postln;
        rep;
    };

    api[\perceptualCylinderFormantWeightingReport] = { |tone=nil, midis=nil|
        var spec, truth, fit, rep;
        spec = at[\perceptualCylinderToneSpec].(tone);
        truth = at[\perceptualCylinderActualSpectrumTruth].(spec[\toneProfile]);
        fit = at[\perceptualCylinderFormantFitEstimate].(midis, spec[\toneProfile]);
        rep = (
            toneProfile: spec[\toneProfile],
            canApplyToAnyToneAsBodyFilter: true,
            formantsAffectPartialWeights: true,
            formantsCreateInharmonicPartialFrequencies: false,
            formantsDirectlyRetuneFundamentals: false,
            optionalControl: true,
            formantStrength: spec[\formantStrength] ? 0.0,
            formantBandsHz: spec[\formantBandsHz] ? [],
            formantBandwidthsHz: spec[\formantBandwidthsHz] ? [],
            formantFitEstimate: fit,
            actualSpectrumTruthStatus: truth[\truthStatus],
            pitchAuthorityEligible: false,
            note: "formants are optional spectral/body weighting filters applicable to any tone; they weight partial amplitudes before roughness evaluation and do not directly deform pitch"
        );
        st[\perceptualCylinderFormantWeightingLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER FORMANT WEIGHTING REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " optional=" ++ rep[\optionalControl].asString
            ++ " weightsPartials=" ++ rep[\formantsAffectPartialWeights].asString
            ++ " retunesFundamentals=" ++ rep[\formantsDirectlyRetuneFundamentals].asString).postln;
        rep;
    };

    api[\perceptualCylinderTimbreReport] = { |tone=nil, midis=nil|
        var spec, rough, fit, truth, rep;
        spec = at[\perceptualCylinderToneSpec].(tone);
        rough = at[\perceptualCylinderSpectrumRoughnessForMidis].(midis ? at[\perceptualCylinderDefaultMidisForTone].(spec[\toneProfile]), spec[\spectrumProfile]);
        fit = at[\perceptualCylinderFormantFitEstimate].(midis, spec[\toneProfile]);
        truth = at[\perceptualCylinderActualSpectrumTruth].(spec[\toneProfile]);
        rep = spec.copy;
        rep[\midis] = midis ? at[\perceptualCylinderDefaultMidisForTone].(spec[\toneProfile]);
        rep[\roughnessEstimate] = rough[\roughnessEstimate] ? 0.0;
        rep[\partialCount] = rough[\partialCount] ? 0;
        rep[\formantFitEstimate] = fit;
        rep[\actualSpectrumProfile] = truth[\actualSpectrumProfile];
        rep[\declaredSpectrumProfile] = truth[\declaredSpectrumProfile];
        rep[\truthStatus] = truth[\truthStatus];
        rep[\assetStatus] = truth[\assetStatus];
        rep[\actualRenderedSpectrumAvailable] = truth[\actualRenderedSpectrumAvailable];
        rep[\ordinaryOctaveSupport] = truth[\ordinaryOctaveSupport];
        rep[\relatedScaleMayDiffer] = truth[\relatedScaleMayDiffer];
        rep[\pitchAuthorityEligible] = false;
        rep[\recommendation] = if((truth[\truthStatus] == \fallbackBlocked) or: { (truth[\truthStatus] == \diagnosticModelOnly) }) { \diagnosticOnly } { if((spec[\recommendedAmount] ? 0.0) <= 0.001) { \doNotApply } { \spectralAuditOnly } };
        rep[\note] = (spec[\note] ? "") ++ "; v3D10 treats formant/body data as spectrum weighting and diagnostics first; declared spectra do not retune pitch unless actual spectral truth and recognizability are proven";
        st[\perceptualCylinderTimbreLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER TIMBRE REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " spectrum=" ++ (rep[\spectrumProfile] ? \harmonic).asString
            ++ " actual=" ++ (rep[\actualSpectrumProfile] ? \unknown).asString
            ++ " truth=" ++ (rep[\truthStatus] ? \unknown).asString
            ++ " relevance=" ++ (rep[\accordionRelevance] ? \low).asString
            ++ " formantStrength=" ++ (rep[\formantStrength] ? 0.0).asString).postln;
        rep;
    };

    api[\setPerceptualCylinderProfileMode] = { |mode=\manual|
        var m;
        m = (mode ? \manual).asSymbol;
        if([\manual, \followTone].includes(m).not) { m = \manual; };
        cfg[\perceptualCylinder][\accordionProfileMode] = m;
        api[\perceptualCylinderTimbreReport].();
    };

    api[\setPerceptualCylinderTimbreCouplingEnabled] = { |flag=false|
        cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = flag == true;
        api[\perceptualCylinderTimbreReport].();
    };

    api[\applyPerceptualCylinderTimbreProfile] = { |tone=nil, midis=nil|
        var spec, mids, rep;
        spec = at[\perceptualCylinderToneSpec].(tone);
        mids = midis ? at[\perceptualCylinderDefaultMidisForTone].(spec[\toneProfile]);
        cfg[\perceptualCylinder][\accordionTimbreTone] = spec[\toneProfile];
        cfg[\perceptualCylinder][\accordionProfileMode] = \followTone;
        cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = true;
        cfg[\perceptualCylinder][\amount] = 0.0;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
        at[\perceptualCylinderClear].();
        rep = (
            authorityEnabled: false,
            renderHookEnabled: false,
            authorityActive: false,
            profile: spec[\spectrumProfile],
            midis: mids,
            timbreSpec: spec,
            timbreCoupled: true,
            diagnosticOnly: true,
            blockedPitchAuthority: true,
            maxAbsAppliedCents: 0.0,
            protectedEntries: 0,
            note: "v3D10 timbre/formant profile is diagnostic-only: formants/body weight the spectrum report, but do not directly retune played fundamentals"
        );
        st[\perceptualCylinderAuthorityLastReport] = rep;
        api[\perceptualCylinderAuthorityReport].();
        rep;
    };

    api[\setPerceptualCylinderExperimentalPitchAuditionEnabled] = { |flag=false|
        cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] = flag == true;
        api[\perceptualCylinderAuthorityReport].();
    };

    api[\applyPerceptualCylinderExperimentalPitchProfile] = { |profile=\harmonicC4|
        var spec, rep;
        spec = at[\perceptualCylinderAuditionSpec].(profile);
        if((cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] ? false) != true) {
            cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
            cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
            at[\perceptualCylinderClear].();
            rep = (authorityActive: false, renderHookEnabled: false, experimentalBlocked: true, maxAbsAppliedCents: 0.0, note: "experimental accordion pitch audition is disabled; call setPerceptualCylinderExperimentalPitchAuditionEnabled.(true) only for non-musical research use");
            st[\perceptualCylinderAuthorityLastReport] = rep;
            rep;
        } {
            cfg[\perceptualCylinder][\amount] = spec[\amount] ? 1.0;
            cfg[\perceptualCylinder][\accordionAuthorityEnabled] = true;
            cfg[\perceptualCylinder][\accordionRenderHookEnabled] = true;
            cfg[\perceptualCylinder][\accordionAuditionProfile] = spec[\name];
            cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = spec[\authorityLimitCents] ? 16.0;
            rep = at[\perceptualCylinderApplyProposalAsAuthority].(spec[\midis], spec[\spectrumProfile], spec[\amount]);
            api[\perceptualCylinderAuthorityReport].();
            rep;
        };
    };

    // v3D9 controlled audition helpers. These keep normal musical audition diagnostic-only.
    // Reports can compare theoretical residuals, but applyPerceptualCylinderAuditionProfile
    // no longer turns on live pitch deformation. Experimental audible deformation is separated
    // behind applyPerceptualCylinderExperimentalPitchProfile.
    at[\perceptualCylinderAuditionSpec] = { |profile=\harmonicC4|
        var p;
        p = (profile ? \harmonicC4).asSymbol;
        if(p == \off) {
            (name: \off, midis: [60, 64, 67], spectrumProfile: \harmonic, amount: 0.0, authorityLimitCents: 16.0, toneProfile: \off, note: "off / restore default")
        } {
            if(p == \timbreMatched or: { p == \followTone }) {
                var ts;
                ts = at[\perceptualCylinderToneSpec].();
                (name: p, midis: at[\perceptualCylinderDefaultMidisForTone].(ts[\toneProfile]), spectrumProfile: ts[\spectrumProfile], amount: ts[\recommendedAmount], authorityLimitCents: ts[\recommendedAuthorityLimitCents], toneProfile: ts[\toneProfile], formantStrength: ts[\formantStrength], note: "current-tone timbre/formant-matched accordion audition")
            } {
                if(p == \organMatched) {
                    var ts;
                    ts = at[\perceptualCylinderToneSpec].(\organ);
                    (name: p, midis: [60, 64, 67], spectrumProfile: ts[\spectrumProfile], amount: ts[\recommendedAmount], authorityLimitCents: ts[\recommendedAuthorityLimitCents], toneProfile: \organ, formantStrength: ts[\formantStrength], note: "organ-matched near-zero accordion audition")
                } {
                    if(p == \pianoC4) {
                        var ts;
                        ts = at[\perceptualCylinderToneSpec].(\piano);
                        (name: p, midis: [48, 60, 64, 67, 72], spectrumProfile: ts[\spectrumProfile], amount: ts[\recommendedAmount], authorityLimitCents: ts[\recommendedAuthorityLimitCents], toneProfile: \piano, formantStrength: ts[\formantStrength], note: "piano-like mild stretched/formant accordion audition")
                    } {
                        if(p == \bellLikeC4) {
                            var ts;
                            ts = at[\perceptualCylinderToneSpec].(\bellLike);
                            (name: p, midis: [60, 63, 67, 70], spectrumProfile: ts[\spectrumProfile], amount: ts[\recommendedAmount], authorityLimitCents: ts[\recommendedAuthorityLimitCents], toneProfile: \bellLike, formantStrength: ts[\formantStrength], note: "bell-like inharmonic/formant accordion audition")
                        } {
                            if(p == \formantVoiceC4) {
                                var ts;
                                ts = at[\perceptualCylinderToneSpec].(\formantVoice);
                                (name: p, midis: [60, 64, 67], spectrumProfile: ts[\spectrumProfile], amount: ts[\recommendedAmount], authorityLimitCents: ts[\recommendedAuthorityLimitCents], toneProfile: \formantVoice, formantStrength: ts[\formantStrength], note: "voice-like formant-body accordion audition")
                            } {
                                if(p == \inharmonicC4) {
                                    (name: p, midis: [60, 64, 67], spectrumProfile: \inharmonic, amount: 1.0, authorityLimitCents: 16.0, toneProfile: \abstractInharmonic, note: "C4-register inharmonic accordion audition")
                                } {
                                    if(p == \harmonicC5) {
                                        (name: p, midis: [72, 76, 79], spectrumProfile: \harmonic, amount: 1.0, authorityLimitCents: 16.0, toneProfile: \abstractHarmonic, note: "C5-register harmonic accordion audition")
                                    } {
                                        if(p == \octaveStack) {
                                            (name: p, midis: [60, 72], spectrumProfile: \harmonic, amount: 1.0, authorityLimitCents: 16.0, toneProfile: \abstractHarmonic, note: "octave-stack accordion audition")
                                        } {
                                            (name: \harmonicC4, midis: [60, 64, 67], spectrumProfile: \harmonic, amount: 1.0, authorityLimitCents: 16.0, toneProfile: \abstractHarmonic, note: "C4-register harmonic accordion audition")
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    at[\perceptualCylinderAuditionReportFor] = { |profile=\harmonicC4|
        var spec, ccfg, oldAmount, oldAuth, oldHook, oldProfile, oldLimit, oldGrid, oldAuthReport;
        var beforeNode, afterNode, roughBefore, roughAfter, freqOff, freqOn, maxDeltaHz, authReport, rep;
        spec = at[\perceptualCylinderAuditionSpec].(profile);
        ccfg = at[\perceptualCylinderConfig].();
        oldAmount = ccfg[\amount] ? 0.0;
        oldAuth = ccfg[\accordionAuthorityEnabled] ? false;
        oldHook = ccfg[\accordionRenderHookEnabled] ? false;
        oldProfile = ccfg[\accordionAuditionProfile] ? \off;
        oldLimit = ccfg[\accordionAuthorityLimitCents] ? 16.0;
        oldGrid = at[\perceptualCylinderCopyGrid].(st[\perceptualCylinderResidualCents]);
        oldAuthReport = st[\perceptualCylinderAuthorityLastReport];
        beforeNode = st[\nodePhase].copy;

        at[\perceptualCylinderClear].();
        cfg[\perceptualCylinder][\amount] = spec[\amount] ? 1.0;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = true;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
        cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = spec[\authorityLimitCents] ? oldLimit;
        roughBefore = at[\perceptualCylinderSpectrumRoughnessForMidis].(spec[\midis], spec[\spectrumProfile]);
        freqOff = (spec[\midis] ? [60]).collect { |m| at[\perceptualCylinderFrequencyForMidi].(m) };
        authReport = at[\perceptualCylinderApplyProposalAsAuthority].(spec[\midis], spec[\spectrumProfile], spec[\amount]);
        roughAfter = at[\perceptualCylinderSpectrumRoughnessForMidis].(spec[\midis], spec[\spectrumProfile]);
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = true;
        freqOn = (spec[\midis] ? [60]).collect { |m| at[\perceptualCylinderFrequencyForMidi].(m) };
        maxDeltaHz = 0.0;
        freqOff.do { |f, i| var d; d = ((freqOn.wrapAt(i) ? f) - f).abs; if(d > maxDeltaHz) { maxDeltaHz = d; }; };
        afterNode = st[\nodePhase].copy;

        rep = (
            auditionOnly: true,
            profile: spec[\name],
            spectrumProfile: spec[\spectrumProfile],
            toneProfile: spec[\toneProfile] ? \abstract,
            formantStrength: spec[\formantStrength] ? 0.0,
            authorityLimitCents: spec[\authorityLimitCents] ? oldLimit,
            midis: spec[\midis],
            amount: spec[\amount],
            authorityMaxCents: authReport[\maxAbsAppliedCents] ? 0.0,
            protectedEntries: authReport[\protectedEntries] ? 0,
            roughnessBefore: roughBefore[\roughnessEstimate] ? 0.0,
            roughnessAfter: roughAfter[\roughnessEstimate] ? 0.0,
            roughnessDelta: (((roughAfter[\roughnessRaw] ? 0.0) - (roughBefore[\roughnessRaw] ? 0.0)).abs).round(0.0001),
            hookOffFrequencies: freqOff.collect { |f| f.round(0.01) },
            hookOnFrequencies: freqOn.collect { |f| f.round(0.01) },
            renderMaxDeltaHz: maxDeltaHz.round(0.01),
            nodePhaseChangedCents: if(at[\wrapSigned].notNil) {
                var m;
                m = 0.0;
                (beforeNode ? Array.new).size.do { |i| var d; d = (at[\wrapSigned].((beforeNode[i] ? 0.0) - (afterNode[i] ? 0.0)) * 1200.0).abs; if(d > m) { m = d; }; };
                m.round(0.01);
            } { 0.0 },
            note: "v3D7 diagnostic audition report compares theoretical accordion render-hook off/on and roughness before/after, then restores settings; it does not enable live pitch audition or change default behavior"
        );

        cfg[\perceptualCylinder][\amount] = oldAmount;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = oldAuth;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = oldHook;
        cfg[\perceptualCylinder][\accordionAuditionProfile] = oldProfile;
        cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = oldLimit;
        st[\perceptualCylinderResidualCents] = oldGrid;
        st[\perceptualCylinderAuthorityLastReport] = oldAuthReport;
        st[\perceptualCylinderAuditionLastReport] = rep;
        rep;
    };

    api[\perceptualCylinderAuditionReport] = { |profile=\harmonicC4|
        var rep;
        rep = at[\perceptualCylinderAuditionReportFor].(profile);
        "".postln;
        "[AT PERCEPTUAL CYLINDER AUDITION REPORT]".postln;
        ("profile=" ++ rep[\profile].asString
            ++ " spectrum=" ++ rep[\spectrumProfile].asString
            ++ " maxApplied=" ++ (rep[\authorityMaxCents] ? 0.0).asString ++ "c"
            ++ " renderDeltaHz=" ++ (rep[\renderMaxDeltaHz] ? 0.0).asString
            ++ " roughness=" ++ (rep[\roughnessBefore] ? 0.0).asString ++ "->" ++ (rep[\roughnessAfter] ? 0.0).asString).postln;
        rep;
    };

    api[\applyPerceptualCylinderAuditionProfile] = { |profile=\harmonicC4|
        var spec, rep;
        spec = at[\perceptualCylinderAuditionSpec].(profile);
        cfg[\perceptualCylinder][\amount] = 0.0;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
        cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = false;
        cfg[\perceptualCylinder][\accordionProfileMode] = \manual;
        cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = 16.0;
        at[\perceptualCylinderClear].();
        if((spec[\name] ? \off) == \off) {
            cfg[\perceptualCylinder][\accordionAuditionProfile] = \off;
            rep = api[\perceptualCylinderAuthorityReport].();
        } {
            cfg[\perceptualCylinder][\accordionAuditionProfile] = spec[\name];
            rep = (
                authorityEnabled: false,
                renderHookEnabled: false,
                authorityActive: false,
                auditionProfile: spec[\name],
                spectrumProfile: spec[\spectrumProfile],
                toneProfile: spec[\toneProfile],
                diagnosticOnly: true,
                blockedPitchAuthority: true,
                maxAbsAppliedCents: 0.0,
                protectedEntries: 0,
                note: "v3D10 normal audition is diagnostic-only; live accordion pitch deformation is blocked so ordinary chords/scales remain recognizable"
            );
            st[\perceptualCylinderAuthorityLastReport] = rep;
            api[\perceptualCylinderAuthorityReport].();
        };
        rep;
    };

    api[\clearPerceptualCylinderAudition] = {
        api[\applyPerceptualCylinderAuditionProfile].(\off);
    };


    api[\perceptualCylinderMusicalRecognizabilityReport] = {
        var ccfg, oldAmount, oldAuth, oldHook, oldGrid, oldProfile, midis, freqs, shifted, maxCents, rep;
        ccfg = at[\perceptualCylinderConfig].();
        oldAmount = ccfg[\amount] ? 0.0;
        oldAuth = ccfg[\accordionAuthorityEnabled] ? false;
        oldHook = ccfg[\accordionRenderHookEnabled] ? false;
        oldProfile = ccfg[\accordionAuditionProfile] ? \off;
        oldGrid = at[\perceptualCylinderCopyGrid].(st[\perceptualCylinderResidualCents]);
        midis = [48, 52, 55, 60, 64, 67, 72];
        cfg[\perceptualCylinder][\amount] = 0.0;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
        at[\perceptualCylinderClear].();
        freqs = midis.collect { |m| at[\midiToFreq].(m) };
        shifted = midis.collect { |m| at[\perceptualCylinderFrequencyForMidi].(m) };
        maxCents = 0.0;
        freqs.do { |f, i|
            var c;
            c = (1200.0 * (((shifted.wrapAt(i) ? f) / f).log / 2.0.log)).abs;
            if(c > maxCents) { maxCents = c; };
        };
        rep = (
            ordinaryMusicProtected: true,
            diagnosticOnly: true,
            midis: midis,
            maxPitchShiftCents: maxCents.round(0.01),
            authorityEnabled: cfg[\perceptualCylinder][\accordionAuthorityEnabled] ? false,
            renderHookEnabled: cfg[\perceptualCylinder][\accordionRenderHookEnabled] ? false,
            note: "v3D10 recognizability guard: ordinary chords/scales keep their played fundamentals unless an explicit experimental pitch API is used"
        );
        cfg[\perceptualCylinder][\amount] = oldAmount;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = oldAuth;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = oldHook;
        cfg[\perceptualCylinder][\accordionAuditionProfile] = oldProfile;
        st[\perceptualCylinderResidualCents] = oldGrid;
        st[\perceptualCylinderRecognizabilityLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER RECOGNIZABILITY REPORT]".postln;
        ("ordinaryMusicProtected=" ++ rep[\ordinaryMusicProtected].asString
            ++ " maxPitchShift=" ++ rep[\maxPitchShiftCents].asString ++ "c"
            ++ " diagnosticOnly=" ++ rep[\diagnosticOnly].asString).postln;
        rep;
    };


    api[\perceptualCylinderPitchAuthorityGateReport] = { |tone=nil|
        var truth, rep, status;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        status = truth[\truthStatus] ? \unknown;
        rep = (
            toneProfile: truth[\toneProfile] ? \unknown,
            declaredSpectrumProfile: truth[\declaredSpectrumProfile] ? \unknown,
            actualSpectrumProfile: truth[\actualSpectrumProfile] ? \unknown,
            truthStatus: status,
            actualSpectrumRequired: true,
            declaredSpectrumCanRetune: false,
            diagnosticModelCanRetune: false,
            fallbackCanRetune: false,
            formantDirectPitchAuthority: false,
            measuredOrVerifiedSpectrumRequiredForPitchAuthority: true,
            ordinaryRecognizabilityRequired: true,
            pitchAuthorityAllowed: false,
            blockReason: if(status == \fallbackBlocked) {
                \fallbackToneCannotAuthorizePitch
            } {
                if(status == \diagnosticModelOnly) {
                    \diagnosticModelCannotAuthorizePitch
                } {
                    if(status == \actualRenderedModel) {
                        \ordinaryOctaveSupportNoPitchNeed
                    } {
                        \requiresSeparateMusicalValidation
                    };
                };
            },
            note: "v3D10 pitch gate: no Sethares/cylinder/formant layer may move pitch from a profile label; actual spectrum truth plus ordinary musical recognizability are required first"
        );
        st[\perceptualCylinderPitchGateLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER PITCH AUTHORITY GATE REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " truth=" ++ (rep[\truthStatus] ? \unknown).asString
            ++ " allowed=" ++ (rep[\pitchAuthorityAllowed] ? false).asString
            ++ " reason=" ++ (rep[\blockReason] ? \unknown).asString).postln;
        rep;
    };

    api[\perceptualCylinderActualSpectrumMeasurementAudit] = { |tone=nil|
        var truth, rep, status;
        truth = at[\perceptualCylinderActualSpectrumTruth].(tone);
        status = truth[\truthStatus] ? \unknown;
        rep = (
            toneProfile: truth[\toneProfile] ? \unknown,
            declaredSpectrumProfile: truth[\declaredSpectrumProfile] ? \unknown,
            actualSpectrumProfile: truth[\actualSpectrumProfile] ? \unknown,
            truthStatus: status,
            actualAudioFFTMeasured: false,
            renderedModelKnown: status == \actualRenderedModel,
            sampleAssetVerified: truth[\assetStatus] == \complete,
            fallbackBlocked: status == \fallbackBlocked,
            diagnosticModelOnly: status == \diagnosticModelOnly,
            measuredSpectrumRequiredForNonOrdinaryPitchAuthority: true,
            pitchAuthorityEligible: false,
            octaveSupport: truth[\ordinaryOctaveSupport] ? \unknown,
            note: "v3D10 actual-spectrum audit distinguishes declared profile, known rendered model, sample-verified source, and real measured spectrum; pitch authority remains blocked"
        );
        st[\perceptualCylinderActualSpectrumMeasurementLastAudit] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER ACTUAL SPECTRUM MEASUREMENT AUDIT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " modelKnown=" ++ (rep[\renderedModelKnown] ? false).asString
            ++ " sampleVerified=" ++ (rep[\sampleAssetVerified] ? false).asString
            ++ " fftMeasured=" ++ (rep[\actualAudioFFTMeasured] ? false).asString
            ++ " pitchAuthority=" ++ (rep[\pitchAuthorityEligible] ? false).asString).postln;
        rep;
    };

    api[\perceptualCylinderOrdinaryMusicAuditReport] = { |midis=nil|
        var mids, neutralFreqs, currentFreqs, maxShift, mode, amount, tone, ccfg, rep;
        mids = midis ? [48, 52, 55, 50, 53, 57, 52, 55, 59, 60, 64, 67];
        neutralFreqs = mids.collect { |m| at[\midiToFreq].(m) };
        currentFreqs = mids.collect { |m| at[\perceptualCylinderFrequencyForMidi].(m) };
        maxShift = 0.0;
        neutralFreqs.do { |f, i|
            var sf, c;
            sf = currentFreqs.wrapAt(i) ? f;
            c = (1200.0 * (sf / f).log / 2.0.log).abs;
            if(c > maxShift) { maxShift = c; };
        };
        tone = if(cfg[\render].notNil) { cfg[\render][\toneProfile] ? \organ } { \unknown };
        mode = if(cfg[\render].notNil) { cfg[\render][\adaptiveToneMode] ? \static } { \static };
        amount = if(cfg[\render].notNil) { cfg[\render][\adaptiveToneAmount] ? 0.0 } { 0.0 };
        ccfg = at[\perceptualCylinderConfig].();
        rep = (
            ordinaryMusicAudit: true,
            midis: mids,
            neutralFrequencies: neutralFreqs.collect { |f| f.round(0.01) },
            currentFrequencies: currentFreqs.collect { |f| f.round(0.01) },
            maxCylinderPitchShiftCents: maxShift.round(0.01),
            pitchRecognizabilityProtected: maxShift <= 0.01,
            toneProfile: tone,
            adaptiveToneMode: mode,
            adaptiveToneAmount: amount,
            adaptiveToneMayColorRecognition: ((mode != \static) or: { amount > 0.001 }),
            accordionAuthorityEnabled: ccfg[\accordionAuthorityEnabled] ? false,
            accordionRenderHookEnabled: ccfg[\accordionRenderHookEnabled] ? false,
            cylinderAmount: ccfg[\amount] ? 0.0,
            residualMaxCents: 0.0,
            pitchAuthorityEligible: false,
            note: "v3D10 ordinary-music audit: if this report shows zero pitch shift but the instrument still sounds strange, the cause is tone/adaptive-tone/core-performance state, not cylinder/formant pitch authority"
        );
        st[\perceptualCylinderOrdinaryMusicLastAudit] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER ORDINARY MUSIC AUDIT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString
            ++ " adaptive=" ++ (rep[\adaptiveToneMode] ? \static).asString
            ++ "/" ++ (rep[\adaptiveToneAmount] ? 0.0).round(0.001).asString
            ++ " maxPitchShift=" ++ (rep[\maxCylinderPitchShiftCents] ? 0.0).asString ++ "c"
            ++ " adaptiveColorRisk=" ++ (rep[\adaptiveToneMayColorRecognition] ? false).asString).postln;
        rep;
    };

    api[\applyOrdinaryMusicReferencePreset] = { |tone=\organ|
        var t;
        t = (tone ? \organ).asSymbol;
        if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
        if(api[\resetField].notNil) { api[\resetField].(); };
        if(api[\clearPerceptualCylinderAudition].notNil) { api[\clearPerceptualCylinderAudition].(); };
        if(api[\clearPerceptualCylinder].notNil) { api[\clearPerceptualCylinder].(); };
        cfg[\perceptualCylinder][\amount] = 0.0;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
        cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = false;
        cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] = false;
        if(api[\setToneProfile].notNil) { api[\setToneProfile].(t); };
        if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
        if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
        if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.0); };
        if(api[\setPerceptualSpectrumAmount].notNil) { api[\setPerceptualSpectrumAmount].(0.0); };
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); };
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(0.0); };
        if(cfg[\memory].notNil) { cfg[\memory][\enabled] = false; };
        if(api[\clearTonalMemory].notNil) { api[\clearTonalMemory].(); };
        if(api[\setWorldScoringEnabled].notNil) { api[\setWorldScoringEnabled].(false); };
        if(cfg[\phrase].notNil) { cfg[\phrase][\enabled] = false; };
        if(api[\setContextGaugeEnabled].notNil) { api[\setContextGaugeEnabled].(false); };
        if(api[\setMovement].notNil) { api[\setMovement].(0.0); };
        if(api[\setTension].notNil) { api[\setTension].(0.0); };
        api[\perceptualCylinderOrdinaryMusicAuditReport].();
    };

    api[\perceptualCylinderAccordionReport] = {
        var harmonic, inharmonic, octave, rep, beforeNode;
        beforeNode = st[\nodePhase].copy;
        harmonic = at[\perceptualCylinderProposalForMidis].([60, 64, 67], \harmonic, nil);
        inharmonic = at[\perceptualCylinderProposalForMidis].([60, 64, 67], \inharmonic, nil);
        octave = at[\perceptualCylinderProposalForMidis].([60, 72], \harmonic, nil);
        rep = (
            enabled: cfg[\perceptualCylinder][\enabled] ? true,
            amount: at[\perceptualCylinderAmount].(),
            scaffoldOnly: cfg[\perceptualCylinder][\scaffoldOnly] ? true,
            spectrumEvaluatorOnly: cfg[\perceptualCylinder][\spectrumEvaluatorOnly] ? true,
            accordionProposalOnly: cfg[\perceptualCylinder][\accordionProposalOnly] ? false,
            accordionAuthorityEnabled: cfg[\perceptualCylinder][\accordionAuthorityEnabled] ? false,
            accordionRenderHookEnabled: cfg[\perceptualCylinder][\accordionRenderHookEnabled] ? false,
            harmonicProposal: harmonic,
            inharmonicProposal: inharmonic,
            octaveProposal: octave,
            harmonicVsInharmonicGridDiffCents: at[\perceptualCylinderProposalGridDiff].(harmonic[\grid], inharmonic[\grid]),
            nodePhaseChangedCents: if(at[\wrapSigned].notNil) {
                var m;
                m = 0.0;
                (beforeNode ? Array.new).size.do { |i|
                    var d;
                    d = (at[\wrapSigned].((beforeNode[i] ? 0.0) - (st[\nodePhase][i] ? 0.0)) * 1200.0).abs;
                    if(d > m) { m = d; };
                };
                m.round(0.01);
            } { 0.0 },
            note: "v3D7 reports register-specific accordion residual proposals; bounded authority can apply them to the residual body only when explicitly enabled, with render hook still separate/off by default and audition helpers available"
        );
        st[\perceptualCylinderAccordionLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER ACCORDION REPORT]".postln;
        ("enabled=" ++ rep[\enabled].asString
            ++ " amount=" ++ rep[\amount].round(0.001).asString
            ++ " proposalOnly=" ++ rep[\accordionProposalOnly].asString
            ++ " harmMax=" ++ (harmonic[\maxAbsProposalCents] ? 0.0).asString
            ++ " inhMax=" ++ (inharmonic[\maxAbsProposalCents] ? 0.0).asString
            ++ " diff=" ++ rep[\harmonicVsInharmonicGridDiffCents].asString).postln;
        rep;
    };

    at[\perceptualCylinderAccordionReport] = { api[\perceptualCylinderAccordionReport].() };

    api[\setPerceptualCylinderEnabled] = { |flag=true|
        cfg[\perceptualCylinder][\enabled] = flag == true;
        api[\perceptualCylinderReport].();
    };

    api[\setPerceptualCylinderAmount] = { |x=0.0|
        cfg[\perceptualCylinder][\amount] = (x ? 0.0).clip(0.0, 1.0);
        api[\perceptualCylinderReport].();
    };

    api[\clearPerceptualCylinder] = {
        at[\perceptualCylinderClear].();
        api[\perceptualCylinderReport].();
    };

    api[\setPerceptualCylinderResidual] = { |pc=0, midi=60, cents=0.0|
        at[\perceptualCylinderSetResidual].(pc, midi, cents);
        api[\perceptualCylinderReport].();
    };

    api[\perceptualCylinderReport] = {
        var ccfg, bases, rows, cells, rep, totalCells, maxResidual;
        ccfg = at[\perceptualCylinderConfig].();
        at[\perceptualCylinderEnsure].();
        bases = at[\perceptualCylinderRegisterBases].();
        rows = Array.new;
        totalCells = 0;
        maxResidual = 0.0;
        bases.do { |baseMidi, ri|
            cells = Array.new;
            (cfg[\solver][\numNodes] ? 12).do { |pc|
                var cell, residualAbs;
                cell = at[\perceptualCylinderCell].(pc, baseMidi + pc);
                residualAbs = (cell[\registerResidualCents] ? 0.0).abs;
                if(residualAbs > maxResidual) { maxResidual = residualAbs; };
                totalCells = totalCells + 1;
                cells = cells.add(cell);
            };
            rows = rows.add((registerIndex: ri, baseMidi: baseMidi, label: "C" ++ ri.asString, cells: cells));
        };
        rep = (
            enabled: ccfg[\enabled] ? true,
            amount: at[\perceptualCylinderAmount].(),
            scaffoldOnly: ccfg[\scaffoldOnly] ? false,
            accordionAuthorityAvailable: ccfg[\accordionAuthorityAvailable] ? true,
            accordionAuthorityEnabled: ccfg[\accordionAuthorityEnabled] ? false,
            accordionRenderHookEnabled: ccfg[\accordionRenderHookEnabled] ? false,
            accordionProfileMode: ccfg[\accordionProfileMode] ? \manual,
            accordionTimbreCouplingEnabled: ccfg[\accordionTimbreCouplingEnabled] ? false,
            accordionPitchAuditionEnabled: ccfg[\accordionPitchAuditionEnabled] ? false,
            accordionExperimentalPitchEnabled: ccfg[\accordionExperimentalPitchEnabled] ? false,
            accordionBodyDiagnosticOnly: ccfg[\accordionBodyDiagnosticOnly] ? true,
            registerCount: bases.size,
            pitchClassCount: cfg[\solver][\numNodes] ? 12,
            cellCount: totalCells,
            maxResidualCents: maxResidual.round(0.01),
            rows: rows,
            c4: at[\perceptualCylinderProjectionForMidi].(60),
            c5: at[\perceptualCylinderProjectionForMidi].(72),
            note: "perceptual cylinder keeps the circle surface plus register axis; accordion deformation remains diagnostic/future-only unless explicit research APIs are used; v3D11 preserves ordinary-musical-recognizability and adds actual-spectrum descriptor/sample-truth/measured-evidence gates, keeps formant/body/cylinder reports diagnostic by default, and blocks live pitch audition except explicit research APIs"
        );
        st[\perceptualCylinderLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL CYLINDER REPORT]".postln;
        ("enabled=" ++ rep[\enabled].asString
            ++ " amount=" ++ rep[\amount].round(0.001).asString
            ++ " scaffoldOnly=" ++ rep[\scaffoldOnly].asString
            ++ " registers=" ++ rep[\registerCount].asString
            ++ " cells=" ++ rep[\cellCount].asString
            ++ " maxResidual=" ++ rep[\maxResidualCents].asString ++ "c").postln;
        rep;
    };

    // Fish-core diagnostic must clear this scaffold too. Because this layer loads
    // after AT_legibility.scd, wrap the existing preset gesture without changing
    // the meaning of any preset or existing authority.
    oldApplyAuthorityPreset = api[\applyAuthorityPreset];
    if(oldApplyAuthorityPreset.notNil) {
        api[\applyAuthorityPreset] = { |preset=\humanStable|
            var result, p;
            p = preset.asSymbol;
            result = oldApplyAuthorityPreset.(p);
            if(p == \fishCoreDiagnostic) {
                cfg[\perceptualCylinder][\amount] = 0.0;
                cfg[\perceptualCylinder][\enabled] = true;
                cfg[\perceptualCylinder][\accordionAuthorityEnabled] = false;
                cfg[\perceptualCylinder][\accordionRenderHookEnabled] = false;
                cfg[\perceptualCylinder][\accordionAuditionProfile] = \off;
                cfg[\perceptualCylinder][\accordionProfileMode] = \manual;
                cfg[\perceptualCylinder][\accordionTimbreCouplingEnabled] = false;
                cfg[\perceptualCylinder][\accordionTimbreTone] = \organ;
                cfg[\perceptualCylinder][\accordionPitchAuditionEnabled] = false;
                cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] = false;
                cfg[\perceptualCylinder][\accordionBodyDiagnosticOnly] = true;
                cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = 16.0;
                at[\perceptualCylinderClear].();
            };
            result;
        };
        at[\applyAuthorityPreset] = { |preset=\humanStable| api[\applyAuthorityPreset].(preset) };
    };

    at[\perceptualCylinderReport] = { api[\perceptualCylinderReport].() };
    at[\setPerceptualCylinderAmount] = { |x| api[\setPerceptualCylinderAmount].(x) };
    at[\clearPerceptualCylinder] = { api[\clearPerceptualCylinder].() };

    at[\perceptualCylinderEnsure].();
    "[at-perceptual-cylinder] Measured-spectrum evidence bridge + sample-truth audit loaded; formant/body/cylinder pitch audition is blocked unless explicit research APIs are used".postln;
};
)
