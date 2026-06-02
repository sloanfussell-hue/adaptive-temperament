(
// AT_perceptual_spectrum.scd
// Full Sethares-style perceptual-spectrum authority layer.
// This extends the existing soft perceptual coherence layer with actual
// partial-by-partial sensory roughness. It is not a mode, not the master law,
// and not a replacement for raw harmonic transport, memory, gravity, or mic
// evidence. Default amount=0 makes it inert until explicitly enabled.
var build, at, cfg, st, api, pcNames, oldCandidateCost;

build = ~atBuild;
if(build.isNil) {
    "[at-perceptual-spectrum] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    pcNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    cfg[\perceptualSpectrum] = cfg[\perceptualSpectrum] ? (
        enabled: true,
        amount: 0.0,
        defaultProfile: \harmonic,
        passiveCandidateWeight: 0.42,
        candidateCostWeight: 3.6,
        maxPartialsPerSource: 8,
        minPartialAmp: 0.015,
        maxFrequency: 9000.0,
        baseFrequency: 261.625565,
        activeBlendScale: 1.0,
        passiveBlendScale: 1.0,
        debug: false
    );

    st[\perceptualSpectrumLastReport] = nil;
    st[\perceptualSpectrumLastApplied] = false;

    at[\perceptualSpectrumConfig] = { cfg[\perceptualSpectrum] ? () };

    at[\perceptualSpectrumAmount] = {
        var scfg;
        scfg = at[\perceptualSpectrumConfig].();
        if(scfg[\enabled] ? true) { (scfg[\amount] ? 0.0).clip(0.0, 1.0) } { 0.0 }
    };

    // Each profile is [partialRatio, relativeAmplitude]. These are deliberately
    // compact profile estimates, not sample assets. They let the tuning field ask
    // a real Sethares question: what roughness does this sonority have under this
    // spectrum? More detailed measured spectra can be substituted later.
    at[\perceptualSpectrumProfiles] = (
        pure: [[1.0, 1.0]],
        harmonic: [[1.0, 1.0], [2.0, 0.55], [3.0, 0.34], [4.0, 0.22], [5.0, 0.15], [6.0, 0.10], [7.0, 0.07], [8.0, 0.05]],
        organ: [[1.0, 1.0], [2.0, 0.82], [3.0, 0.62], [4.0, 0.38], [5.0, 0.24], [6.0, 0.18], [8.0, 0.12]],
        bright: [[1.0, 0.85], [2.0, 0.72], [3.0, 0.58], [4.0, 0.44], [5.0, 0.34], [6.0, 0.26], [7.0, 0.18], [8.0, 0.12]],
        pad: [[1.0, 1.0], [2.0, 0.35], [3.0, 0.18], [4.0, 0.10], [5.0, 0.07], [6.0, 0.05]],
        bell: [[1.0, 1.0], [2.01, 0.55], [2.88, 0.48], [4.19, 0.33], [5.43, 0.23], [6.80, 0.16], [8.21, 0.10]],
        inharmonic: [[1.0, 1.0], [1.52, 0.62], [2.17, 0.46], [2.94, 0.32], [3.83, 0.22], [5.06, 0.14], [6.41, 0.09]]
    );

    at[\perceptualSpectrumProfileForSource] = { |src|
        var scfg, p;
        scfg = at[\perceptualSpectrumConfig].();
        p = if(src.notNil) { src[\spectrumProfile] ? src[\profile] ? src[\kind] } { nil };
        p = (p ? (scfg[\defaultProfile] ? \harmonic)).asSymbol;
        if(at[\perceptualSpectrumProfiles][p].isNil) { p = scfg[\defaultProfile] ? \harmonic; };
        p.asSymbol;
    };

    at[\perceptualSpectrumBaseFreqForPhase] = { |phase|
        var scfg, p;
        scfg = at[\perceptualSpectrumConfig].();
        p = phase ? 0.0;
        // C4 is phase 0.0. Fractional phase gives the pitch-class frequency within that octave.
        (scfg[\baseFrequency] ? 261.625565) * (2.0.pow(p));
    };

    at[\perceptualSpectrumPartialsForSource] = { |src, phaseOverride=nil, sourceIndex=0|
        var scfg, profileName, profile, baseFreq, srcWeight, conf, partials, maxPartials, minAmp, maxFreq, pc, pcName, ph;
        scfg = at[\perceptualSpectrumConfig].();
        profileName = at[\perceptualSpectrumProfileForSource].(src);
        profile = at[\perceptualSpectrumProfiles][profileName] ? at[\perceptualSpectrumProfiles][\harmonic];
        ph = phaseOverride ? (src[\phase] ? 0.0);
        baseFreq = at[\perceptualSpectrumBaseFreqForPhase].(ph);
        srcWeight = (src[\weight] ? 0.0).clip(0.0, 2.0);
        conf = (src[\confidence] ? 1.0).clip(0.0, 1.0);
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
                        sourceIndex: sourceIndex,
                        pc: pc,
                        pcName: pcName,
                        profile: profileName,
                        partialIndex: i + 1,
                        ratio: ratio,
                        frequency: f,
                        amplitude: amp,
                        kind: src[\kind] ? \unknown
                    ));
                };
            };
        };
        partials;
    };

    at[\perceptualSpectrumPartialsForSources] = { |sources|
        var partials;
        partials = Array.new;
        (sources ? Array.new).do { |src, i|
            partials = partials ++ at[\perceptualSpectrumPartialsForSource].(src, nil, i);
        };
        partials;
    };

    // Sethares / Plomp-Levelt-style roughness curve between two sinusoids.
    // Constants follow the standard Sethares curve form. The result is nonnegative;
    // zero means no critical-band beating pressure between that pair.
    at[\perceptualSpectrumPartialRoughness] = { |f1, a1, f2, a2|
        var fmin, df, s, x, r;
        f1 = (f1 ? 0.0).asFloat.max(1.0);
        f2 = (f2 ? 0.0).asFloat.max(1.0);
        a1 = (a1 ? 0.0).asFloat.max(0.0);
        a2 = (a2 ? 0.0).asFloat.max(0.0);
        fmin = f1.min(f2);
        df = (f2 - f1).abs;
        s = 0.24 / ((0.0207 * fmin) + 18.96);
        x = s * df;
        r = (a1 * a2) * (((-3.5 * x).exp) - ((-5.75 * x).exp));
        r.max(0.0);
    };

    at[\perceptualSpectrumRoughnessForPartials] = { |partials|
        var total, pairs, i, j;
        total = 0.0;
        pairs = Array.new;
        i = 0;
        while { i < partials.size } {
            j = i + 1;
            while { j < partials.size } {
                var a, b, r;
                a = partials[i];
                b = partials[j];
                if((a[\sourceIndex] ? -1) != (b[\sourceIndex] ? -1)) {
                    r = at[\perceptualSpectrumPartialRoughness].(a[\frequency], a[\amplitude], b[\frequency], b[\amplitude]);
                    if(r > 0.000001) {
                        total = total + r;
                        if(pairs.size < 60) {
                            pairs = pairs.add((
                                from: (a[\pcName].asString ++ ":" ++ a[\partialIndex].asString),
                                to: (b[\pcName].asString ++ ":" ++ b[\partialIndex].asString),
                                f1: (a[\frequency] ? 0.0).round(0.1),
                                f2: (b[\frequency] ? 0.0).round(0.1),
                                roughness: r.round(0.0001)
                            ));
                        };
                    };
                };
                j = j + 1;
            };
            i = i + 1;
        };
        (roughness: total, pairCount: pairs.size, pairs: pairs)
    };

    at[\perceptualSpectrumRoughnessForSources] = { |sources|
        var partials, rough;
        partials = at[\perceptualSpectrumPartialsForSources].(sources);
        rough = at[\perceptualSpectrumRoughnessForPartials].(partials);
        (
            roughnessEstimate: (rough[\roughness] ? 0.0).round(0.0001),
            roughnessRaw: rough[\roughness] ? 0.0,
            sourceCount: (sources ? Array.new).size,
            partialCount: partials.size,
            partials: partials,
            strongestPairs: rough[\pairs]
        )
    };

    at[\perceptualSpectrumCandidateSources] = { |pc, phase, sources|
        var out, matched, scfg, passiveWeight, pseudo;
        scfg = at[\perceptualSpectrumConfig].();
        out = Array.new;
        matched = false;
        (sources ? Array.new).do { |src|
            var c;
            c = src.copy;
            if((src[\pc] ? -1) == pc) {
                c[\phase] = phase;
                c[\candidateMoved] = true;
                matched = true;
            };
            out = out.add(c);
        };
        if(matched.not) {
            passiveWeight = scfg[\passiveCandidateWeight] ? 0.42;
            pseudo = (
                pc: pc,
                pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(pc) } { pcNames.wrapAt(pc) },
                phase: phase,
                weight: passiveWeight,
                confidence: 1.0,
                kind: \passiveCandidate,
                spectrumProfile: scfg[\defaultProfile] ? \harmonic,
                pinned: false
            );
            out = out.add(pseudo);
        };
        out;
    };

    at[\perceptualSpectrumCandidateCost] = { |pc, phase, solvedPhase, sources|
        var scfg, candidateSources, rough, cost;
        scfg = at[\perceptualSpectrumConfig].();
        if(at[\perceptualSpectrumAmount].() <= 0.0001) { 0.0 } {
            candidateSources = at[\perceptualSpectrumCandidateSources].(pc, phase, sources);
            rough = at[\perceptualSpectrumRoughnessForSources].(candidateSources);
            cost = (rough[\roughnessRaw] ? rough[\roughnessEstimate] ? 0.0) * (scfg[\candidateCostWeight] ? 3.6);
            cost;
        }
    };

    at[\perceptualSpectrumBestCandidateForPc] = { |pc, solvedPhase, sources|
        var candidates, bestPhase, bestCost, bestMove, costs, sourceReport;
        candidates = if(at[\perceptualCandidatePhasesForPc].notNil) {
            at[\perceptualCandidatePhasesForPc].(pc, solvedPhase, sources)
        } {
            [solvedPhase[pc], st[\etPhase][pc]]
        };
        bestPhase = solvedPhase[pc];
        bestCost = 999999.0;
        costs = Array.new;
        candidates.do { |cand|
            var c, rough;
            rough = at[\perceptualSpectrumCandidateCost].(pc, cand, solvedPhase, sources);
            c = rough;
            costs = costs.add((phase: cand, moveCents: (at[\wrapSigned].(cand - solvedPhase[pc]) * 1200.0).round(0.01), spectrumCost: c.round(0.0001)));
            if(c < bestCost) { bestCost = c; bestPhase = cand; };
        };
        bestMove = at[\wrapSigned].(bestPhase - solvedPhase[pc]) * 1200.0;
        sourceReport = at[\perceptualSpectrumRoughnessForSources].(at[\perceptualSpectrumCandidateSources].(pc, bestPhase, sources));
        (
            pc: pc,
            pcName: if(at[\pcNameSafe].notNil) { at[\pcNameSafe].(pc) } { pcNames.wrapAt(pc) },
            bestPhase: bestPhase,
            bestMoveCents: bestMove.round(0.01),
            bestSpectrumCost: bestCost.round(0.0001),
            candidateCount: candidates.size,
            candidates: costs,
            partialCount: sourceReport[\partialCount],
            roughnessEstimate: sourceReport[\roughnessEstimate]
        )
    };

    // Integrate with the existing perceptual candidate chooser. When amount=0,
    // this exactly preserves the v3 clean behavior. When amount>0, it adds the
    // partial-roughness landscape to the existing ratio/continuity cost.
    oldCandidateCost = at[\perceptualCandidateCost];
    if(oldCandidateCost.notNil) {
        at[\perceptualLegacyCandidateCost] = oldCandidateCost;
        at[\perceptualCandidateCost] = { |pc, phase, solvedPhase, sources|
            var base, specAmount, specCost;
            base = at[\perceptualLegacyCandidateCost].(pc, phase, solvedPhase, sources);
            specAmount = at[\perceptualSpectrumAmount].();
            if(specAmount <= 0.0001) { base } {
                specCost = at[\perceptualSpectrumCandidateCost].(pc, phase, solvedPhase, sources);
                base + (specAmount * specCost);
            };
        };
    };

    api[\setPerceptualSpectrumEnabled] = { |flag=true|
        cfg[\perceptualSpectrum][\enabled] = flag == true;
        api[\perceptualSpectrumReport].();
    };

    api[\setPerceptualSpectrumAmount] = { |x=0.0|
        cfg[\perceptualSpectrum][\amount] = (x ? 0.0).clip(0.0, 1.0);
        api[\perceptualSpectrumReport].();
    };

    api[\setPerceptualSpectrumProfile] = { |profile=\harmonic|
        var p;
        p = profile.asSymbol;
        if(at[\perceptualSpectrumProfiles][p].isNil) {
            ("[at-perceptual-spectrum] unknown profile " ++ p.asString ++ "; keeping " ++ (cfg[\perceptualSpectrum][\defaultProfile] ? \harmonic).asString).warn;
        } {
            cfg[\perceptualSpectrum][\defaultProfile] = p;
        };
        api[\perceptualSpectrumReport].();
    };

    api[\perceptualSpectrumReport] = {
        var scfg, amount, ph, sources, rough, candidates, rep;
        scfg = at[\perceptualSpectrumConfig].();
        amount = at[\perceptualSpectrumAmount].();
        ph = st[\targetPhase] ? st[\nodePhase];
        sources = if(at[\perceptualCurrentSources].notNil) { at[\perceptualCurrentSources].(nil, nil, ph) } { Array.new };
        rough = at[\perceptualSpectrumRoughnessForSources].(sources);
        candidates = Array.new;
        if(sources.size >= 2) {
            cfg[\solver][\numNodes].do { |pc| candidates = candidates.add(at[\perceptualSpectrumBestCandidateForPc].(pc, ph, sources)); };
        };
        rep = (
            enabled: scfg[\enabled] ? true,
            amount: amount,
            defaultProfile: scfg[\defaultProfile] ? \harmonic,
            sourceCount: sources.size,
            partialCount: rough[\partialCount],
            roughnessEstimate: rough[\roughnessEstimate],
            strongestPairs: rough[\strongestPairs],
            candidateDirections: candidates,
            note: "perceptual spectrum is the Sethares-style partial roughness authority; it is bounded, optional, and not the master tuning law"
        );
        st[\perceptualSpectrumLastReport] = rep;
        "".postln;
        "[AT PERCEPTUAL SPECTRUM REPORT]".postln;
        ("enabled=" ++ rep[\enabled].asString
            ++ " amount=" ++ amount.round(0.001).asString
            ++ " profile=" ++ rep[\defaultProfile].asString
            ++ " sources=" ++ sources.size.asString
            ++ " partials=" ++ (rough[\partialCount] ? 0).asString
            ++ " roughness=" ++ (rough[\roughnessEstimate] ? 0.0).asString).postln;
        rep;
    };

    at[\perceptualSpectrumReport] = { api[\perceptualSpectrumReport].() };
    at[\setPerceptualSpectrumAmount] = { |x| api[\setPerceptualSpectrumAmount].(x) };
    at[\setPerceptualSpectrumEnabled] = { |flag| api[\setPerceptualSpectrumEnabled].(flag) };

    "[at-perceptual-spectrum] Sethares-style partial roughness authority loaded; default amount=0 so current keeper behavior is preserved".postln;
};
)
