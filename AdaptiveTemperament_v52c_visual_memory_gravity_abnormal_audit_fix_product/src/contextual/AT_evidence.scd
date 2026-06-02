(
// AT_evidence.scd
// Authoritative evidence + harmonic-field force layer.
// MIDI/memory/mic become source objects here; mic does not own harmonic force construction.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;
if(build.isNil) {
    "[at-evidence] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    // ------------------------------------------------------------
    // external-source defaults; AT_mic.scd overwrites currentExternalSources
    // with the real microphone policy implementation when loaded.
    // ------------------------------------------------------------

    if(at[\currentExternalSources].isNil) {
        at[\currentExternalSources] = { st[\externalSources] ? Array.new };
    };

    at[\markEvidenceDirty] = { |reason=\unknown|
        st[\evidenceDirty] = true;
        st[\evidenceDirtyReason] = reason;
        st[\evidenceDirtyAt] = Main.elapsedTime;
    };

    at[\evidenceKeyFor] = { |activePcs, pcWeights, externalSources|
        var activeKey, externalKey;
        activeKey = (activePcs ? Array.new).collect { |pc|
            [pc, (pcWeights[pc] ? 0.0).round(0.02)]
        };
        externalKey = (externalSources ? Array.new).sort { |a, b| (a[\pc] ? 0) < (b[\pc] ? 0) }.collect { |src|
            [
                src[\pc],
                (src[\phase] ? 0.0).round(0.002),
                (src[\weight] ? 0.0).round(0.02),
                (src[\confidence] ? 0.0).round(0.02),
                src[\kind] ? \mic
            ]
        };
        [activeKey, externalKey];
    };

    at[\collectEvidence] = {
        var pcWeights, activePcs, externalSources, sources, key;
        pcWeights = at[\pcWeights].();
        activePcs = at[\activePcsFromWeights].(pcWeights);
        externalSources = if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { Array.new };
        sources = at[\buildSources].(activePcs, pcWeights, externalSources);
        key = at[\evidenceKeyFor].(activePcs, pcWeights, externalSources);
        (
            pcWeights: pcWeights,
            activePcs: activePcs,
            externalSources: externalSources,
            sources: sources,
            key: key,
            hasMidi: activePcs.notEmpty,
            hasExternal: externalSources.notEmpty,
            timestamp: Main.elapsedTime
        )
    };

    // ------------------------------------------------------------
    // ratio candidates and force construction
    // ------------------------------------------------------------

    at[\bestChoiceFor] = { |currentDiff, pcDistance|
        var choices, bestPhase, bestWeight, bestCost;
        choices = at[\ratioChoices][pcDistance];
        bestPhase = choices[0][0];
        bestWeight = choices[0][1];
        bestCost = (at[\wrapSigned].(currentDiff - bestPhase)).abs / (bestWeight + 0.000001);

        choices.do { |pair|
            var phase, weight, cost;
            phase = pair[0];
            weight = pair[1];
            cost = (at[\wrapSigned].(currentDiff - phase)).abs / (weight + 0.000001);
            if(cost < bestCost) {
                bestCost = cost;
                bestPhase = phase;
                bestWeight = weight;
            };
        };

        [bestPhase, bestWeight];
    };

    at[\buildSources] = { |activePcs, pcWeights, externalSources=nil|
        var sources;
        sources = Array.new;

        activePcs.do { |pc|
            sources = sources.add((
                pc: pc,
                phase: st[\nodePhase][pc],
                weight: pcWeights[pc].clip(0.05, 2.0),
                isInternal: true,
                kind: \midi
            ));
        };

        (externalSources ? Array.new).do { |src|
            if(src.notNil and: { src[\pc].notNil }) {
                sources = sources.add((
                    pc: src[\pc],
                    phase: src[\phase],
                    weight: (src[\weight] ? 0.0).clip(0.0, 1.5),
                    isInternal: false,
                    confidence: src[\confidence] ? 1.0,
                    kind: src[\kind] ? \mic
                ));
            };
        };

        sources;
    };

    at[\applyTopologyGapForce] = { |forces|
        var minGap;
        minGap = cfg[\solver][\topologyMinGap] * (1.0 - (((cfg[\solver][\solverTension] ? 0.55).clip(0.0, 1.0)) * 0.35));
        cfg[\solver][\numNodes].do { |i|
            var left, right, dl, dr;
            left = (i + 11) % 12;
            right = (i + 1) % 12;
            dl = at[\wrapSigned].(st[\nodePhase][i] - st[\nodePhase][left]);
            dr = at[\wrapSigned].(st[\nodePhase][right] - st[\nodePhase][i]);

            if(dl.abs < minGap) {
                forces[i] = forces[i] + ((minGap - dl.abs) * (if(dl >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };

            if(dr.abs < minGap) {
                forces[i] = forces[i] - ((minGap - dr.abs) * (if(dr >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };
        };
        forces;
    };

    at[\computeForces] = { |activePcs, pcWeights, externalSources=nil|
        var forces, sources, activeSet, activeCount;

        forces = Array.fill(cfg[\solver][\numNodes], 0.0);
        sources = at[\buildSources].(activePcs, pcWeights, externalSources);
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc); };
        activeCount = activePcs.size;

        sources.do { |src|
            var srcPc, srcPhase, srcWeight, srcInternal;
            srcPc = src[\pc];
            srcPhase = src[\phase];
            srcWeight = src[\weight];
            srcInternal = src[\isInternal];

            cfg[\solver][\numNodes].do { |i|
                var k, currentDiff, best, targetPhase, simplicity, err, localWeight;

                if((activeCount == 1) and: { srcInternal and: { i == srcPc } }) {
                    // keep sole internal anchor absolute
                } {
                    k = (i - srcPc) % 12;
                    currentDiff = at[\wrapSigned].(st[\nodePhase][i] - srcPhase);
                    best = at[\bestChoiceFor].(currentDiff, k);
                    targetPhase = best[0];
                    simplicity = best[1];
                    err = at[\wrapSigned].(currentDiff - targetPhase);

                    localWeight = simplicity * srcWeight;
                    if(activeSet.includes(i)) {
                        localWeight = localWeight * 1.0;
                    } {
                        localWeight = localWeight * cfg[\solver][\passiveScale];
                    };

                    forces[i] = forces[i] + ((err.neg) * localWeight);

                    if(srcInternal and: { activeSet.includes(i) and: { i != srcPc } }) {
                        forces[srcPc] = forces[srcPc] + (err * simplicity * srcWeight * 0.55);
                    };
                };
            };
        };

        at[\applyTopologyGapForce].(forces);
    };

    at[\computeForcesFromSourceList] = { |sources, activePcs|
        var forces, activeSet;

        forces = Array.fill(cfg[\solver][\numNodes], 0.0);
        activeSet = IdentitySet.new;
        (activePcs ? Array.new).do { |pc| activeSet.add(pc); };

        (sources ? Array.new).do { |src|
            var srcPc, srcPhase, srcWeight;
            srcPc = src[\pc];
            srcPhase = src[\phase];
            srcWeight = src[\weight] ? 0.0;

            cfg[\solver][\numNodes].do { |i|
                var k, currentDiff, best, targetPhase, simplicity, err, localWeight;

                k = (i - srcPc) % 12;
                currentDiff = at[\wrapSigned].(st[\nodePhase][i] - srcPhase);
                best = at[\bestChoiceFor].(currentDiff, k);
                targetPhase = best[0];
                simplicity = best[1];
                err = at[\wrapSigned].(currentDiff - targetPhase);

                localWeight = simplicity * srcWeight;
                if(activeSet.includes(i)) {
                    localWeight = localWeight * 1.0;
                } {
                    localWeight = localWeight * cfg[\solver][\passiveScale];
                };

                forces[i] = forces[i] + ((err.neg) * localWeight);
            };
        };

        at[\applyTopologyGapForce].(forces);
    };

    at[\updateDescriptors] = { |activePcs, pcWeights, externalSources, delta|
        var sources, activeCount;

        sources = at[\buildSources].(activePcs, pcWeights, externalSources);
        activeCount = activePcs.size;

        cfg[\solver][\numNodes].do { |i|
            var align, cnt;
            if(sources.isEmpty) {
                align = 1.0;
            } {
                align = 0.0;
                cnt = 0.0;
                sources.do { |src|
                    var closeness, k, currentDiff, best, err;
                    if((activeCount == 1) and: { src[\isInternal] and: { i == src[\pc] } }) {
                        closeness = 1.0;
                    } {
                        k = (i - src[\pc]) % 12;
                        currentDiff = at[\wrapSigned].(st[\nodePhase][i] - src[\phase]);
                        best = at[\bestChoiceFor].(currentDiff, k);
                        err = (at[\wrapSigned].(currentDiff - best[0])).abs;
                        closeness = 1.0 - (err / 0.08).clip(0.0, 1.0);
                    };
                    align = align + closeness;
                    cnt = cnt + 1.0;
                };
                align = (align / cnt).clip(0.0, 1.0);
            };

            st[\nodeAlignment][i] = align;
            st[\nodeMotion][i] = (delta[i].abs / cfg[\solver][\maxStep]).clip(0.0, 1.0);
            st[\nodeStability][i] = (align * (1.0 - st[\nodeMotion][i])).clip(0.0, 1.0);
            st[\lastDelta][i] = delta[i];
        };
    };

    at[\applyDelta] = { |delta|
        if(st[\coreUnwrappedPhase].isNil or: { st[\coreUnwrappedPhase].size != cfg[\solver][\numNodes] }) {
            st[\coreUnwrappedPhase] = st[\nodePhase].copy;
        };
        cfg[\solver][\numNodes].do { |i|
            st[\coreUnwrappedPhase][i] = (st[\coreUnwrappedPhase][i] ? st[\nodePhase][i]) + delta[i];
            st[\nodePhase][i] = at[\wrap01].(st[\nodePhase][i] + delta[i]);
        };
    };

    at[\updateDescriptorsFromSources] = { |sources, activePcs, delta|
        var activeCount;
        activeCount = (activePcs ? Array.new).size;

        cfg[\solver][\numNodes].do { |i|
            var align, cnt;
            if((sources ? Array.new).isEmpty) {
                align = 1.0;
            } {
                align = 0.0;
                cnt = 0.0;
                (sources ? Array.new).do { |src|
                    var closeness, k, currentDiff, best, err;
                    if((activeCount == 1) and: { activePcs[0] == i }) {
                        closeness = 1.0;
                    } {
                        k = (i - src[\pc]) % 12;
                        currentDiff = at[\wrapSigned].(st[\nodePhase][i] - src[\phase]);
                        best = at[\bestChoiceFor].(currentDiff, k);
                        err = (at[\wrapSigned].(currentDiff - best[0])).abs;
                        closeness = 1.0 - (err / 0.08).clip(0.0, 1.0);
                    };
                    align = align + closeness;
                    cnt = cnt + 1.0;
                };
                align = (align / cnt).clip(0.0, 1.0);
            };

            st[\nodeAlignment][i] = align;
            st[\nodeMotion][i] = (delta[i].abs / cfg[\solver][\maxStep]).clip(0.0, 1.0);
            st[\nodeStability][i] = (align * (1.0 - st[\nodeMotion][i])).clip(0.0, 1.0);
            st[\lastDelta][i] = delta[i];
        };
    };

    // ------------------------------------------------------------
    // continuous field heartbeat
    // ------------------------------------------------------------

    at[\fieldTick] = {
        var ev, now, interval, shouldResolve, hasEvidence, noEvidence, canResolveByInterval, canResolveByDirty;
        ev = at[\collectEvidence].();
        now = Main.elapsedTime;
        hasEvidence = (ev[\hasMidi] ? false) or: { ev[\hasExternal] ? false };
        noEvidence = hasEvidence.not;

        st[\fieldTickCount] = (st[\fieldTickCount] ? 0) + 1;
        st[\lastFieldTickAt] = now;
        st[\lastFieldHadEvidence] = hasEvidence;
        st[\lastEvidence] = ev;

        if(st[\lastEvidenceKey].isNil) { st[\lastEvidenceKey] = ev[\key]; };
        if(ev[\key] != st[\lastEvidenceKey]) {
            st[\lastEvidenceKey] = ev[\key];
            at[\markEvidenceDirty].(\evidenceChanged);
        };

        // Silence is not amnesia. With no MIDI and no committed external source,
        // fieldTick freezes the current audible world once and then leaves it alone.
        if((cfg[\field][\enabled] ? true) and: { noEvidence and: { cfg[\field][\freezeOnNoEvidence] ? true } }) {
            if((st[\fieldFrozen] ? false).not or: { st[\evidenceDirty] == true }) {
                if(at[\freezeCurrentField].notNil) {
                    at[\freezeCurrentField].();
                    if(at[\syncWorldMirrorsFromLegacy].notNil) { at[\syncWorldMirrorsFromLegacy].(\fieldTickFreeze); };
                    st[\evidenceDirty] = false;
                    st[\targetUpdatedByTick] = false;
                    st[\lastFieldAction] = \freeze;
                    if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
                };
            };
            ev;
        } {
            shouldResolve = false;
            if((cfg[\field][\enabled] ? true) and: { hasEvidence }) {
                st[\fieldFrozen] = false;
                interval = cfg[\field][\continuousResolveInterval] ? 0.08;
                canResolveByInterval = (cfg[\field][\continuousResolveEnabled] ? true)
                    and: { st[\motionActive].not }
                    and: { st[\lastFieldResolveAt].isNil or: { (now - st[\lastFieldResolveAt]) >= interval } };
                canResolveByDirty = (cfg[\field][\resolveOnEvidenceChange] ? true) and: { st[\evidenceDirty] == true };
                shouldResolve = canResolveByDirty or: { canResolveByInterval };
            };

            if(shouldResolve and: { at[\settleForCurrentConstraints].notNil }) {
                st[\evidenceDirty] = false;
                st[\lastFieldResolveAt] = now;
                st[\targetUpdatedByTick] = true;
                st[\targetUpdatedByTickAt] = now;
                st[\lastFieldAction] = \resolve;
                at[\settleForCurrentConstraints].(\fieldTick);
                if(at[\syncWorldMirrorsFromLegacy].notNil) { at[\syncWorldMirrorsFromLegacy].(\fieldTick); };
                if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
            } {
                st[\targetUpdatedByTick] = false;
            };

            if((cfg[\field][\logEvidenceTicks] ? false) == true) {
                ("[at-field] tick hasEvidence=" ++ hasEvidence.asString ++ " dirty=" ++ st[\evidenceDirty].asString ++ " action=" ++ st[\lastFieldAction].asString).postln;
            };

            ev;
        };
    };

    "[at-evidence] source collection and harmonic force layer loaded".postln;
};
)
