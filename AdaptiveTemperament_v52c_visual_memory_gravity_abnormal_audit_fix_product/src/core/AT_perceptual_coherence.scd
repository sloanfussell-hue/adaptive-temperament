(
// AT_perceptual_coherence.scd
// Optional perceptual-coherence authority. This is Sethares-inspired in the
// practical sense: reduce predicted beating/roughness across the whole current
// sonority. It is not the master law, not equal temperament, and not a mode.
// At amount=0 it has no tuning effect, preserving the naked fish core.
var build, at, cfg, st, api, diag, ui, pcNames;

build = ~atBuild;
if(build.isNil) {
    "[at-perceptual] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pcNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    st[\perceptualLastReport] = nil;
    st[\perceptualLastApplied] = false;
    st[\perceptualLastMoves] = Array.new;

    at[\perceptualConfig] = { cfg[\perceptual] ? () };

    at[\pcNameSafe] = { |pc|
        if(at[\pcName].notNil) { at[\pcName].(pc) } { pcNames.wrapAt((pc ? 0).asInteger % 12) }
    };

    at[\perceptualAmount] = {
        var pcfg;
        pcfg = at[\perceptualConfig].();
        if(pcfg[\enabled] ? true) { (pcfg[\amount] ? 0.0).clip(0.0, 1.0) } { 0.0 }
    };

    at[\perceptualCurrentSources] = { |activePcs=nil, externalSources=nil, phases=nil|
        var pcfg, weights, pcs, srcs, ph, ext;
        pcfg = at[\perceptualConfig].();
        weights = at[\pcWeights].();
        pcs = activePcs ? at[\activePcsFromWeights].(weights);
        ph = phases ? st[\nodePhase];
        srcs = Array.new;

        (pcs ? Array.new).do { |pc|
            srcs = srcs.add((
                pc: pc,
                pcName: at[\pcNameSafe].(pc),
                phase: ph[pc],
                weight: ((weights[pc] ? 0.0).clip(0.0, 2.0) * (pcfg[\activeWeightScale] ? 0.72)),
                confidence: 1.0,
                kind: \midi,
                spectrumProfile: if(cfg[\perceptualSpectrum].notNil) { cfg[\perceptualSpectrum][\defaultProfile] ? \harmonic } { \harmonic },
                pinned: true
            ));
        };

        ext = externalSources;
        if(ext.isNil and: { at[\currentExternalSources].notNil }) { ext = at[\currentExternalSources].(); };
        (ext ? Array.new).do { |src|
            if(src.notNil and: { src[\pc].notNil and: { src[\phase].notNil } }) {
                srcs = srcs.add((
                    pc: src[\pc],
                    pcName: at[\pcNameSafe].(src[\pc]),
                    phase: src[\phase],
                    weight: ((src[\weight] ? 0.0).clip(0.0, 1.5) * (src[\confidence] ? 1.0).clip(0.0, 1.0) * (pcfg[\externalWeightScale] ? 1.2)),
                    confidence: src[\confidence] ? 1.0,
                    kind: src[\kind] ? \mic,
                    spectrumProfile: src[\spectrumProfile] ? src[\profile] ? if(cfg[\perceptualSpectrum].notNil) { cfg[\perceptualSpectrum][\defaultProfile] ? \harmonic } { \harmonic },
                    policyReason: src[\policyReason] ? src[\reason],
                    pinned: true
                ));
            };
        };
        srcs;
    };

    at[\perceptualPinnedSet] = { |sources|
        var set;
        set = IdentitySet.new;
        (sources ? Array.new).do { |src| if(src[\pc].notNil) { set.add(src[\pc]); }; };
        set;
    };

    at[\perceptualCandidatePhasesForPc] = { |pc, solvedPhase, sources|
        var pcfg, candidates, limit;
        pcfg = at[\perceptualConfig].();
        candidates = Array.new;
        limit = (pcfg[\candidateRatioLimit] ? 3).asInteger.max(1);
        candidates = candidates.add(solvedPhase[pc]);
        candidates = candidates.add(st[\etPhase][pc]);
        (sources ? Array.new).do { |src|
            var k, choices, n;
            if(src[\pc].notNil and: { src[\phase].notNil }) {
                k = (pc - src[\pc]) % 12;
                choices = at[\ratioChoices].wrapAt(k) ? [[k / 12.0, 0.1]];
                n = 0;
                choices.do { |ch|
                    if(n < limit) {
                        candidates = candidates.add(at[\wrap01].(src[\phase] + ch[0]));
                    };
                    n = n + 1;
                };
            };
        };
        candidates;
    };

    at[\perceptualPairCost] = { |pc, phase, src|
        var pcfg, k, diff, best, errCents, errNorm, complexity, w, soft, cost;
        pcfg = at[\perceptualConfig].();
        if(src.isNil or: { src[\pc].isNil or: { src[\phase].isNil } }) { 0.0 } {
            k = (pc - src[\pc]) % 12;
            diff = at[\wrapSigned].(phase - src[\phase]);
            if(diff < 0.0) { diff = diff + 1.0; };
            best = at[\bestChoiceFor].(diff, k);
            errCents = (at[\wrapSigned].(diff - best[0]) * 1200.0).abs;
            soft = (pcfg[\roughnessSoftCents] ? 18.0).max(1.0);
            errNorm = (errCents / soft).clip(0.0, 8.0);
            complexity = (1.0 - (best[1] ? 0.0)).clip(0.0, 1.0);
            w = (src[\weight] ? 0.0).clip(0.0, 2.0);
            cost = w * ((errNorm * errNorm) + ((pcfg[\complexityWeight] ? 0.10) * complexity));
            cost;
        }
    };

    at[\perceptualCandidateCost] = { |pc, phase, solvedPhase, sources|
        var pcfg, cost, continuity;
        pcfg = at[\perceptualConfig].();
        cost = 0.0;
        (sources ? Array.new).do { |src| cost = cost + at[\perceptualPairCost].(pc, phase, src); };
        continuity = (at[\wrapSigned].(phase - solvedPhase[pc]).abs * 1200.0) / ((pcfg[\maxMoveCents] ? 7.0).max(1.0));
        cost = cost + ((pcfg[\continuityWeight] ? 0.42) * continuity * continuity);
        cost;
    };

    at[\perceptualBestCandidateForPc] = { |pc, solvedPhase, sources|
        var candidates, bestPhase, bestCost, bestMove, costs;
        candidates = at[\perceptualCandidatePhasesForPc].(pc, solvedPhase, sources);
        bestPhase = solvedPhase[pc];
        bestCost = 999999.0;
        costs = Array.new;
        candidates.do { |cand|
            var c;
            c = at[\perceptualCandidateCost].(pc, cand, solvedPhase, sources);
            costs = costs.add((phase: cand, moveCents: (at[\wrapSigned].(cand - solvedPhase[pc]) * 1200.0).round(0.01), cost: c.round(0.001)));
            if(c < bestCost) {
                bestCost = c;
                bestPhase = cand;
            };
        };
        bestMove = at[\wrapSigned].(bestPhase - solvedPhase[pc]) * 1200.0;
        (
            pc: pc,
            pcName: at[\pcNameSafe].(pc),
            solvedPhase: solvedPhase[pc],
            bestPhase: bestPhase,
            bestMoveCents: bestMove.round(0.01),
            bestCost: bestCost.round(0.001),
            candidateCount: candidates.size,
            candidates: costs
        )
    };

    at[\perceptualRoughnessForPhases] = { |phases, sources=nil|
        var srcs, total, pairs, i, j;
        srcs = sources ? at[\perceptualCurrentSources].(nil, nil, phases);
        total = 0.0;
        pairs = Array.new;
        i = 0;
        while { i < srcs.size } {
            j = i + 1;
            while { j < srcs.size } {
                var a, b, k, diff, best, errCents, pairWeight, soft, rough;
                a = srcs[i]; b = srcs[j];
                k = (b[\pc] - a[\pc]) % 12;
                diff = at[\wrapSigned].(b[\phase] - a[\phase]);
                if(diff < 0.0) { diff = diff + 1.0; };
                best = at[\bestChoiceFor].(diff, k);
                errCents = (at[\wrapSigned].(diff - best[0]) * 1200.0).abs;
                pairWeight = (((a[\weight] ? 0.0) * (b[\weight] ? 0.0)).sqrt).clip(0.0, 2.0);
                soft = ((cfg[\perceptual] ? ())[\roughnessSoftCents] ? 18.0).max(1.0);
                rough = pairWeight * (((errCents / soft) * (errCents / soft)) + (0.08 * (1.0 - (best[1] ? 0.0)).clip(0.0, 1.0)));
                total = total + rough;
                pairs = pairs.add((from: a[\pcName], to: b[\pcName], errCents: errCents.round(0.01), weight: pairWeight.round(0.001), roughness: rough.round(0.001)));
                j = j + 1;
            };
            i = i + 1;
        };
        (roughnessEstimate: total.round(0.001), pairs: pairs, sources: srcs)
    };

    at[\applyPerceptualCoherenceBias] = { |solvedPhase, activePcs=nil, reason=\resolve|
        var pcfg, amount, sources, pinned, out, moves, maxMove, anyMove, report;
        pcfg = at[\perceptualConfig].();
        amount = at[\perceptualAmount].();
        if(amount <= 0.0001) {
            st[\perceptualLastApplied] = false;
            solvedPhase;
        } {
            sources = at[\perceptualCurrentSources].(activePcs, nil, solvedPhase);
            if(sources.size < 2) {
                st[\perceptualLastApplied] = false;
                solvedPhase;
            } {
                pinned = at[\perceptualPinnedSet].(sources);
                out = solvedPhase.copy;
                moves = Array.new;
                maxMove = ((pcfg[\maxMoveCents] ? 7.0).max(0.0)) / 1200.0;
                anyMove = false;
                cfg[\solver][\numNodes].do { |pc|
                    var best, pinnedHere, blend, rawMove, clampedPhase, newPhase, moveCents;
                    best = at[\perceptualBestCandidateForPc].(pc, solvedPhase, sources);
                    pinnedHere = pinned.includes(pc);
                    blend = amount * if(pinnedHere) { pcfg[\activeBlend] ? 0.06 } { pcfg[\passiveBlend] ? 0.36 };
                    rawMove = at[\wrapSigned].(best[\bestPhase] - solvedPhase[pc]).clip(maxMove.neg, maxMove);
                    clampedPhase = at[\wrap01].(solvedPhase[pc] + rawMove);
                    newPhase = at[\phaseBlend].(solvedPhase[pc], clampedPhase, blend);
                    moveCents = at[\wrapSigned].(newPhase - solvedPhase[pc]) * 1200.0;
                    if(moveCents.abs > 0.001) { anyMove = true; };
                    out[pc] = newPhase;
                    best[\appliedMoveCents] = moveCents.round(0.01);
                    best[\pinned] = pinnedHere;
                    best[\blend] = blend.round(0.001);
                    moves = moves.add(best);
                };
                report = (
                    timestamp: Main.elapsedTime,
                    reason: reason,
                    enabled: pcfg[\enabled] ? true,
                    amount: amount,
                    sourceCount: sources.size,
                    sources: sources,
                    moves: moves,
                    roughnessBefore: at[\perceptualRoughnessForPhases].(solvedPhase, sources)[\roughnessEstimate],
                    roughnessAfter: at[\perceptualRoughnessForPhases].(out, sources)[\roughnessEstimate],
                    applied: anyMove
                );
                st[\perceptualLastReport] = report;
                st[\perceptualLastApplied] = anyMove;
                st[\perceptualLastMoves] = moves;
                if(pcfg[\debug] ? false) {
                    "".postln;
                    "[AT PERCEPTUAL COHERENCE]".postln;
                    report.postln;
                };
                out;
            };
        };
    };

    api[\setPerceptualCoherenceEnabled] = { |flag=true|
        cfg[\perceptual][\enabled] = flag == true;
        api[\perceptualCoherenceReport].();
    };

    api[\setPerceptualCoherenceAmount] = { |x=0.0|
        cfg[\perceptual][\amount] = (x ? 0.0).clip(0.0, 1.0);
        api[\perceptualCoherenceReport].();
    };

    api[\perceptualCoherenceReport] = {
        var pcfg, amount, sources, ph, rough, rep, candidates;
        pcfg = at[\perceptualConfig].();
        amount = at[\perceptualAmount].();
        ph = st[\targetPhase] ? st[\nodePhase];
        sources = at[\perceptualCurrentSources].(nil, nil, ph);
        rough = at[\perceptualRoughnessForPhases].(ph, sources);
        candidates = Array.new;
        if(sources.size >= 2) {
            cfg[\solver][\numNodes].do { |pc| candidates = candidates.add(at[\perceptualBestCandidateForPc].(pc, ph, sources)); };
        };
        rep = (
            enabled: pcfg[\enabled] ? true,
            amount: amount,
            sourceCount: sources.size,
            sources: sources,
            roughnessEstimate: rough[\roughnessEstimate],
            pairRoughness: rough[\pairs],
            candidateDirections: candidates,
            lastApplied: st[\perceptualLastApplied] ? false,
            lastAppliedReport: st[\perceptualLastReport],
            note: "perceptual coherence is a soft whole-sonority authority; it does not replace ratio law, external evidence, memory, or gravity"
        );
        "".postln;
        "[AT PERCEPTUAL COHERENCE REPORT]".postln;
        ("enabled=" ++ rep[\enabled].asString ++ " amount=" ++ amount.round(0.001).asString ++ " sources=" ++ sources.size.asString ++ " roughness=" ++ rough[\roughnessEstimate].asString).postln;
        rep;
    };

    at[\perceptualCoherenceReport] = { api[\perceptualCoherenceReport].() };
    at[\setPerceptualCoherenceAmount] = { |x| api[\setPerceptualCoherenceAmount].(x) };
    at[\setPerceptualCoherenceEnabled] = { |flag| api[\setPerceptualCoherenceEnabled].(flag) };

    "[at-perceptual] perceptual coherence authority loaded; default amount=0 so fish core remains unaltered".postln;
};
)
