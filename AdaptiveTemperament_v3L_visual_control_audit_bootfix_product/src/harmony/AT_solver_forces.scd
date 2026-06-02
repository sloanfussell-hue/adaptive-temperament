(
// AT_solver_forces.scd
// v2d: numerical guards for live-authority Motion proof; missing phases,
// weights, or config values cannot leak nil arithmetic into the background
// field service. This does not change the harmonic law; it only makes the
// existing force calculations total over partially-initialized live state.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    at[\computeForces] = { |activePcs, pcWeights, externalSources=nil|
        var n, forces, sources, activeSet, activeCount, minGap, perceptualForces;
        n = cfg[\solver][\numNodes] ? 12;
        activePcs = activePcs ? Array.new;
        pcWeights = pcWeights ? Array.fill(n, 0.0);
        externalSources = externalSources ? Array.new;
        forces = Array.fill(n, 0.0);
        sources = at[\buildSources].(activePcs, pcWeights, externalSources) ? Array.new;
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc.asInteger % n); };
        activeCount = activePcs.size;
        minGap = (cfg[\solver][\topologyMinGap] ? 0.015) * (1.0 - ((cfg[\solver][\tensionPitchReference] ? 0.55) * 0.35));

        sources.do { |src|
            var srcPc, srcPhase, srcWeight, srcInternal;
            if(src.notNil) {
                srcPc = (src[\pc] ? 0).asInteger % n;
                srcPhase = src[\phase] ? (st[\nodePhase][srcPc] ? st[\etPhase][srcPc]);
                srcWeight = src[\weight] ? 0.0;
                srcInternal = src[\isInternal] ? false;

                n.do { |i|
                    var k, currentDiff, best, targetPhase, simplicity, err, localWeight, phaseI;
                    if((activeCount == 1) and: { srcInternal and: { i == srcPc } }) {
                        // keep sole internal anchor absolute
                    } {
                        k = (i - srcPc) % 12;
                        phaseI = st[\nodePhase][i] ? st[\etPhase][i];
                        currentDiff = at[\wrapSigned].(phaseI - srcPhase);
                        best = at[\bestChoiceFor].(currentDiff, k);
                        targetPhase = best[0] ? 0.0;
                        simplicity = best[1] ? 0.0;
                        err = at[\wrapSigned].(currentDiff - targetPhase);

                        localWeight = simplicity * srcWeight;
                        if(activeSet.includes(i)) {
                            localWeight = localWeight * 1.0;
                        } {
                            localWeight = localWeight * (cfg[\solver][\passiveScale] ? 0.35) * at[\passiveContextScale].(src, activePcs, externalSources);
                        };

                        forces[i] = (forces[i] ? 0.0) + ((err.neg) * localWeight);

                        if(srcInternal and: { activeSet.includes(i) and: { i != srcPc } }) {
                            forces[srcPc] = (forces[srcPc] ? 0.0) + (err * simplicity * srcWeight * 0.55);
                        };
                    };
                };
            };
        };

        if(at[\perceptualPressureForActiveField].notNil) {
            perceptualForces = at[\perceptualPressureForActiveField].(activePcs, pcWeights, externalSources) ? Array.fill(n, 0.0);
            n.do { |pidx| forces[pidx] = (forces[pidx] ? 0.0) + (perceptualForces[pidx] ? 0.0); };
        };

        n.do { |i|
            var left, right, dl, dr, phaseI, phaseLeft, phaseRight;
            left = (i + 11) % 12;
            right = (i + 1) % 12;
            phaseI = st[\nodePhase][i] ? st[\etPhase][i];
            phaseLeft = st[\nodePhase][left] ? st[\etPhase][left];
            phaseRight = st[\nodePhase][right] ? st[\etPhase][right];
            dl = at[\wrapSigned].(phaseI - phaseLeft);
            dr = at[\wrapSigned].(phaseRight - phaseI);

            if(dl.abs < minGap) {
                forces[i] = (forces[i] ? 0.0) + ((minGap - dl.abs) * (if(dl >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };

            if(dr.abs < minGap) {
                forces[i] = (forces[i] ? 0.0) - ((minGap - dr.abs) * (if(dr >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };
        };

        forces.collect { |f| f ? 0.0 };
    };

    at[\computeForcesFromSourceList] = { |sources, activePcs|
        var n, forces, activeSet, minGap;
        n = cfg[\solver][\numNodes] ? 12;
        forces = Array.fill(n, 0.0);
        activeSet = IdentitySet.new;
        (activePcs ? Array.new).do { |pc| activeSet.add(pc.asInteger % n); };
        minGap = (cfg[\solver][\topologyMinGap] ? 0.015) * (1.0 - ((cfg[\solver][\tensionPitchReference] ? 0.55) * 0.35));

        (sources ? Array.new).do { |src|
            var srcPc, srcPhase, srcWeight;
            if(src.notNil and: { src[\pc].notNil }) {
                srcPc = (src[\pc] ? 0).asInteger % n;
                srcPhase = src[\phase] ? (st[\nodePhase][srcPc] ? st[\etPhase][srcPc]);
                srcWeight = ((src[\weight] ? 0.0)
                    * (if(at[\externalEvidenceTrustScale].notNil) { at[\externalEvidenceTrustScale].(src) ? 0.0 } { 1.0 })
                    * (if(at[\externalRoleRelationalScale].notNil) { at[\externalRoleRelationalScale].(src, activePcs) ? 1.0 } { 1.0 })).clip(0.0, 1.5);

                n.do { |i|
                    var k, currentDiff, best, targetPhase, simplicity, err, localWeight, phaseI;
                    k = (i - srcPc) % 12;
                    phaseI = st[\nodePhase][i] ? st[\etPhase][i];
                    currentDiff = at[\wrapSigned].(phaseI - srcPhase);
                    best = at[\bestChoiceFor].(currentDiff, k);
                    targetPhase = best[0] ? 0.0;
                    simplicity = best[1] ? 0.0;
                    err = at[\wrapSigned].(currentDiff - targetPhase);

                    localWeight = simplicity * srcWeight;
                    if(activeSet.includes(i)) {
                        localWeight = localWeight * 1.0;
                    } {
                        localWeight = localWeight * (cfg[\solver][\passiveScale] ? 0.35) * at[\passiveContextScale].(src, activePcs, sources);
                    };

                    forces[i] = (forces[i] ? 0.0) + ((err.neg) * localWeight);
                };
            };
        };

        n.do { |i|
            var left, right, dl, dr, phaseI, phaseLeft, phaseRight;
            left = (i + 11) % 12;
            right = (i + 1) % 12;
            phaseI = st[\nodePhase][i] ? st[\etPhase][i];
            phaseLeft = st[\nodePhase][left] ? st[\etPhase][left];
            phaseRight = st[\nodePhase][right] ? st[\etPhase][right];
            dl = at[\wrapSigned].(phaseI - phaseLeft);
            dr = at[\wrapSigned].(phaseRight - phaseI);

            if(dl.abs < minGap) {
                forces[i] = (forces[i] ? 0.0) + ((minGap - dl.abs) * (if(dl >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };

            if(dr.abs < minGap) {
                forces[i] = (forces[i] ? 0.0) - ((minGap - dr.abs) * (if(dr >= 0.0) { 1.0 } { -1.0 }) * 0.2);
            };
        };

        forces.collect { |f| f ? 0.0 };
    };

    at[\updateDescriptors] = { |activePcs, pcWeights, externalSources, delta|
        var sources, activeCount, n;
        n = cfg[\solver][\numNodes] ? 12;
        activePcs = activePcs ? Array.new;
        delta = delta ? Array.fill(n, 0.0);
        sources = at[\buildSources].(activePcs, pcWeights, externalSources) ? Array.new;
        activeCount = activePcs.size;

        n.do { |i|
            var align, cnt;
            if(sources.isEmpty) {
                align = 1.0;
            } {
                align = 0.0;
                cnt = 0.0;
                sources.do { |src|
                    var closeness, k, currentDiff, best, err, srcPc, srcPhase, phaseI;
                    if(src.notNil) {
                        srcPc = (src[\pc] ? 0).asInteger % n;
                        srcPhase = src[\phase] ? (st[\nodePhase][srcPc] ? st[\etPhase][srcPc]);
                        if((activeCount == 1) and: { (src[\isInternal] ? false) and: { i == srcPc } }) {
                            closeness = 1.0;
                        } {
                            k = (i - srcPc) % 12;
                            phaseI = st[\nodePhase][i] ? st[\etPhase][i];
                            currentDiff = at[\wrapSigned].(phaseI - srcPhase);
                            best = at[\bestChoiceFor].(currentDiff, k);
                            err = (at[\wrapSigned].(currentDiff - (best[0] ? 0.0))).abs;
                            closeness = 1.0 - (err / 0.08).clip(0.0, 1.0);
                        };
                        align = align + closeness;
                        cnt = cnt + 1.0;
                    };
                };
                align = if(cnt <= 0.000001) { 1.0 } { (align / cnt).clip(0.0, 1.0) };
            };

            st[\nodeAlignment][i] = align;
            st[\nodeMotion][i] = ((delta[i] ? 0.0).abs / (cfg[\solver][\maxStep] ? 0.0022)).clip(0.0, 1.0);
            st[\nodeStability][i] = (align * (1.0 - (st[\nodeMotion][i] ? 0.0))).clip(0.0, 1.0);
            st[\lastDelta][i] = delta[i] ? 0.0;
        };
    };

    at[\applyDelta] = { |delta|
        var n;
        n = cfg[\solver][\numNodes] ? 12;
        delta = delta ? Array.fill(n, 0.0);
        n.do { |i|
            st[\nodePhase][i] = at[\wrap01].((st[\nodePhase][i] ? st[\etPhase][i]) + (delta[i] ? 0.0));
        };
    };

    at[\updateDescriptorsFromSources] = { |sources, activePcs, delta|
        var activeCount, n;
        n = cfg[\solver][\numNodes] ? 12;
        activePcs = activePcs ? Array.new;
        delta = delta ? Array.fill(n, 0.0);
        activeCount = activePcs.size;

        n.do { |i|
            var align, cnt;
            if((sources ? Array.new).isEmpty) {
                align = 1.0;
            } {
                align = 0.0;
                cnt = 0.0;
                (sources ? Array.new).do { |src|
                    var closeness, k, currentDiff, best, err, srcPc, srcPhase, phaseI;
                    if(src.notNil) {
                        srcPc = (src[\pc] ? 0).asInteger % n;
                        srcPhase = src[\phase] ? (st[\nodePhase][srcPc] ? st[\etPhase][srcPc]);
                        if((activeCount == 1) and: { activePcs[0] == i }) {
                            closeness = 1.0;
                        } {
                            k = (i - srcPc) % 12;
                            phaseI = st[\nodePhase][i] ? st[\etPhase][i];
                            currentDiff = at[\wrapSigned].(phaseI - srcPhase);
                            best = at[\bestChoiceFor].(currentDiff, k);
                            err = (at[\wrapSigned].(currentDiff - (best[0] ? 0.0))).abs;
                            closeness = 1.0 - (err / 0.08).clip(0.0, 1.0);
                        };
                        align = align + closeness;
                        cnt = cnt + 1.0;
                    };
                };
                align = if(cnt <= 0.000001) { 1.0 } { (align / cnt).clip(0.0, 1.0) };
            };

            st[\nodeAlignment][i] = align;
            st[\nodeMotion][i] = ((delta[i] ? 0.0).abs / (cfg[\solver][\maxStep] ? 0.0022)).clip(0.0, 1.0);
            st[\nodeStability][i] = (align * (1.0 - (st[\nodeMotion][i] ? 0.0))).clip(0.0, 1.0);
            st[\lastDelta][i] = delta[i] ? 0.0;
        };
    };

};
)
