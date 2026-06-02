(
// AT_memory.scd
// Tonal-basin memory: slow field-level gravity, not a lock.
// Immediate evidence creates a target; memory bends that target according to
// confidence and amount, then learns slowly from persistent evidence.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;
if(build.isNil) {
    "[at-memory] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    st[\memoryAmount] = cfg[\memory][\amount] ? 0.35;
    st[\memoryPhase] = (st[\etPhase] ? Array.fill(cfg[\solver][\numNodes], { |i| i / 12.0 })).copy;
    st[\memoryValid] = false;
    st[\memoryConfidence] = 0.0;
    st[\memoryLastUpdateAt] = nil;
    st[\memoryLastDistance] = nil;
    st[\memoryLastInfluence] = 0.0;
    st[\memoryLastLearnRate] = 0.0;
    st[\memoryLastReason] = nil;
    st[\memorySupportCounts] = Array.fill(cfg[\solver][\numNodes], 0);

    at[\phaseBlend] = { |prevPhase, nextPhase, alpha=0.5|
        if(prevPhase.isNil) {
            at[\wrap01].(nextPhase);
        } {
            at[\wrap01].(prevPhase + (at[\wrapSigned].(nextPhase - prevPhase) * alpha.clip(0.0, 1.0)));
        };
    };

    at[\memoryActivePcs] = {
        var weights, pcs, ext;
        weights = at[\pcWeights].();
        pcs = at[\activePcsFromWeights].(weights);
        if(at[\currentExternalSources].notNil) {
            ext = at[\currentExternalSources].();
            (ext ? Array.new).do { |src|
                if(src.notNil and: { src[\pc].notNil }) {
                    if(pcs.includes(src[\pc]).not) { pcs = pcs.add(src[\pc]); };
                };
            };
        };
        pcs.sort;
    };

    at[\phaseArrayDistance] = { |a, b, pcs=nil|
        var list, sum, count;
        list = if(pcs.isNil or: { pcs.isEmpty }) {
            (0 .. (cfg[\solver][\numNodes] - 1));
        } { pcs };
        sum = 0.0;
        count = 0;
        list.do { |pc|
            if(a[pc].notNil and: { b[pc].notNil }) {
                sum = sum + at[\wrapSigned].(a[pc] - b[pc]).abs;
                count = count + 1;
            };
        };
        if(count <= 0) { 0.0 } { sum / count };
    };

    at[\clearTonalMemory] = {
        st[\memoryPhase] = (st[\nodePhase] ? st[\etPhase]).copy;
        st[\memoryValid] = false;
        st[\memoryConfidence] = 0.0;
        st[\memoryLastUpdateAt] = nil;
        st[\memoryLastDistance] = nil;
        st[\memoryLastInfluence] = 0.0;
        st[\memoryLastLearnRate] = 0.0;
        st[\memoryLastReason] = \clear;
        st[\memorySupportCounts] = Array.fill(cfg[\solver][\numNodes], 0);
    };

    at[\memoryDecayNoEvidence] = {
        var dec, cdec;
        if(st[\memoryValid] == true) {
            dec = cfg[\memory][\decay] ? 0.008;
            cdec = cfg[\memory][\confidenceDecay] ? 0.012;
            // Keep the remembered field, but let its authority fade slowly.
            st[\memoryConfidence] = (st[\memoryConfidence] * (1.0 - cdec.clip(0.0, 0.95))).clip(0.0, 1.0);
            if(st[\memoryConfidence] <= 0.0001) { st[\memoryValid] = false; };
            st[\memoryLastReason] = \decay;
        };
    };

    at[\learnTonalMemory] = { |evidencePhase, activePcs=nil, reason=\solve|
        var pcs, dist, soft, hard, conflict, baseLearn, boost, learn, confLearn, amount, conf, authorityHold;
        pcs = activePcs;
        if(pcs.isNil or: { pcs.isEmpty }) { pcs = at[\memoryActivePcs].(); };

        if((cfg[\memory][\enabled] ? true).not) { nil } {
            if(pcs.isEmpty) {
                at[\memoryDecayNoEvidence].();
            } {
                if(st[\memoryValid].not) {
                    st[\memoryPhase] = evidencePhase.copy;
                    st[\memoryValid] = true;
                    st[\memoryConfidence] = (cfg[\memory][\confidenceLearn] ? 0.10).clip(0.0, 1.0);
                    st[\memoryLastDistance] = 0.0;
                    st[\memoryLastLearnRate] = 1.0;
                } {
                    dist = at[\phaseArrayDistance].(evidencePhase, st[\memoryPhase], pcs);
                    soft = ((cfg[\memory][\conflictSoftCents] ? 18.0) / 1200.0).max(0.000001);
                    hard = ((cfg[\memory][\conflictHardCents] ? 55.0) / 1200.0).max(soft + 0.000001);
                    conflict = ((dist - soft) / (hard - soft)).clip(0.0, 1.0);
                    baseLearn = (cfg[\memory][\learningRate] ? 0.045).clip(0.0, 1.0);
                    boost = (cfg[\memory][\modulationAdapt] ? 0.18).clip(0.0, 1.0);
                    // Contradictory evidence can learn faster at normal authority, so real
                    // modulation can win over time. But maxed/earned memory is an
                    // inhibiting authority: it must not instantly chase every raw
                    // fish-core movement, or the "fully embodied" pole amplifies
                    // motion instead of preserving the established world.
                    amount = (st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0)).clip(0.0, 1.0);
                    conf = (st[\memoryConfidence] ? 0.0).clip(0.0, 1.0);
                    authorityHold = (amount * conf).clip(0.0, 1.0);
                    learn = (baseLearn + (boost * conflict)).clip(0.0, 0.45);
                    learn = learn * (1.0 - authorityHold).squared;
                    st[\memoryPhase] = Array.fill(cfg[\solver][\numNodes], { |i|
                        at[\phaseBlend].(st[\memoryPhase][i], evidencePhase[i], learn)
                    });
                    st[\memoryLastDistance] = dist;
                    st[\memoryLastLearnRate] = learn;
                };
                confLearn = cfg[\memory][\confidenceLearn] ? 0.10;
                st[\memoryConfidence] = (st[\memoryConfidence] + ((1.0 - st[\memoryConfidence]) * confLearn)).clip(0.0, 1.0);
                pcs.do { |pc| st[\memorySupportCounts][pc] = (st[\memorySupportCounts][pc] ? 0) + 1; };
                st[\memoryLastUpdateAt] = Main.elapsedTime;
                st[\memoryLastReason] = reason;
            };
        };
    };

    at[\applyTonalMemoryBias] = { |evidencePhase, activePcs=nil, reason=\solve|
        var pcs, amount, conf, dist, soft, hard, conflict, agreement, influence, maxBias, biased;
        if((cfg[\memory][\enabled] ? true).not or: { st[\memoryValid].not }) {
            evidencePhase;
        } {
            amount = (st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0)).clip(0.0, 1.0);
            conf = (st[\memoryConfidence] ? 0.0).clip(0.0, 1.0);
            pcs = activePcs;
            if(pcs.isNil or: { pcs.isEmpty }) { pcs = at[\memoryActivePcs].(); };
            dist = at[\phaseArrayDistance].(evidencePhase, st[\memoryPhase], pcs);
            soft = ((cfg[\memory][\conflictSoftCents] ? 18.0) / 1200.0).max(0.000001);
            hard = ((cfg[\memory][\conflictHardCents] ? 55.0) / 1200.0).max(soft + 0.000001);
            conflict = ((dist - soft) / (hard - soft)).clip(0.0, 1.0);
            agreement = (1.0 - conflict).clip(0.0, 1.0);
            // Memory has strong pull in a familiar key, weaker pull during modulation.
            influence = (amount * conf * (0.25 + (0.75 * agreement))).clip(0.0, 0.92);
            maxBias = ((cfg[\memory][\maxBiasCents] ? 18.0) / 1200.0).max(0.0);
            biased = Array.fill(cfg[\solver][\numNodes], { |i|
                var diff, step;
                diff = at[\wrapSigned].(st[\memoryPhase][i] - evidencePhase[i]);
                step = (diff * influence).clip(maxBias.neg, maxBias);
                at[\wrap01].(evidencePhase[i] + step);
            });
            st[\memoryLastInfluence] = influence;
            biased;
        };
    };

    "[at-memory] tonal-basin memory loaded".postln;
};
)
