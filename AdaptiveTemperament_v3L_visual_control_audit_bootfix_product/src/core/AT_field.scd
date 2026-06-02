(
// AT_field.scd
// r16d real target/current shape separation on top of the r16b hard field write barrier.
//
// r16 introduced first-class fieldTrueGaugeCents and nodeShapeCents, but the
// old nodePhase field could still absorb absolute gauge residue. r16a makes
// decomposition authoritative after every field update:
//
//   nodePhase[pc] = etPhase[pc] + (fieldTrueGaugeCents + nodeShapeCents[pc]) / 1200
//
// Internal harmony solves shape. Stable external acoustic evidence may carry
// true gauge freely. Unsupported internal active-centroid residue is extracted
// from shape instead of being allowed to ratchet through future chords.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-field] ~atBuild missing.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    at[\fieldEnsureState] = {
        if(st[\fieldTrueGaugeCents].isNil) { st[\fieldTrueGaugeCents] = 0.0; };
        if(st[\fieldTrueGaugeVelocityCents].isNil) { st[\fieldTrueGaugeVelocityCents] = 0.0; };
        if(st[\nodeShapeCents].isNil) { st[\nodeShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0); };
        if(st[\frozenShapeCents].isNil) { st[\frozenShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0); };
        if(st[\frozenGaugeCents].isNil) { st[\frozenGaugeCents] = 0.0; };
        if(st[\lastFieldDecompositionReport].isNil) { st[\lastFieldDecompositionReport] = nil; };
        if(st[\targetNodeShapeCents].isNil) { st[\targetNodeShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0); };
        if(st[\nodeShapeVelocityCents].isNil) { st[\nodeShapeVelocityCents] = Array.fill(cfg[\solver][\numNodes], 0.0); };
        if(st[\lastShapeMorphReport].isNil) { st[\lastShapeMorphReport] = nil; };
        if(at[\gravityEnsureState].notNil) { at[\gravityEnsureState].(); };
        nil
    };

    at[\fieldRawDevCents] = {
        at[\devArray].().collect { |x| x * 1200.0 }
    };

    at[\fieldCurrentActivePcs] = {
        var pcs, weights;
        pcs = Array.new;
        if(at[\pcWeights].notNil and: { at[\activePcsFromWeights].notNil }) {
            weights = at[\pcWeights].();
            pcs = at[\activePcsFromWeights].(weights);
        };
        if(pcs.isNil or: { pcs.isEmpty }) {
            if(st[\activeNotes].notNil) {
                st[\activeNotes].keysValuesDo { |midi, info|
                    if(info.notNil and: { info[\pc].notNil }) { pcs = pcs.add(info[\pc].asInteger % 12); };
                };
                pcs = pcs.as(Set).asArray.sort;
            };
        };
        pcs ? Array.new
    };

    at[\fieldCurrentPcWeights] = {
        if(at[\pcWeights].notNil) { at[\pcWeights].() } { Array.fill(cfg[\solver][\numNodes], 0.0) }
    };

    at[\fieldCurrentExternalSources] = {
        if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { st[\externalSources] ? Array.new }
    };

    at[\fieldComposeFromShapeGauge] = {
        var gauge, shape, n;
        at[\fieldEnsureState].();
        n = cfg[\solver][\numNodes];
        gauge = st[\fieldTrueGaugeCents] ? 0.0;
        shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        st[\nodePhase] = Array.fill(n, { |pc|
            at[\wrap01].(st[\etPhase][pc] + ((gauge + (shape[pc] ? 0.0)) / 1200.0))
        });
        st[\fieldGaugeCents] = gauge; // compatibility diagnostics
        nil
    };

    at[\fieldComposedDevCents] = {
        var gauge, shape, n;
        at[\fieldEnsureState].();
        n = cfg[\solver][\numNodes];
        gauge = st[\fieldTrueGaugeCents] ? 0.0;
        shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        Array.fill(n, { |pc| gauge + (shape[pc] ? 0.0) })
    };

    at[\fieldRawVsCommittedMaxDiffCents] = { |rawDevs=nil|
        var raw, committed, n, diffs;
        n = cfg[\solver][\numNodes];
        raw = rawDevs ? at[\fieldRawDevCents].();
        committed = at[\fieldComposedDevCents].();
        diffs = Array.fill(n, { |pc| ((raw[pc] ? 0.0) - (committed[pc] ? 0.0)).abs });
        if(diffs.isEmpty) { 0.0 } { diffs.maxItem ? 0.0 }
    };

    at[\fieldActiveCentroidCents] = { |activePcs|
        var vals, sum;
        vals = Array.new;
        (activePcs ? Array.new).do { |pc|
            vals = vals.add(at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0);
        };
        if(vals.isEmpty) { 0.0 } {
            sum = 0.0;
            vals.do { |x| sum = sum + x; };
            sum / vals.size.asFloat.max(1.0)
        }
    };

    at[\fieldWeightedShapeCentroidCents] = { |shape, activePcs, pcWeights=nil|
        var sum, total, weight;
        sum = 0.0;
        total = 0.0;
        (activePcs ? Array.new).do { |pc|
            weight = if(pcWeights.isNil) { 1.0 } { ((pcWeights[pc] ? 0.0).abs.max(0.15)) };
            sum = sum + ((shape[pc] ? 0.0) * weight);
            total = total + weight;
        };
        if(total > 0.000001) { sum / total } { 0.0 }
    };

    at[\fieldShapeMorphFollow] = { |reason=\continuous, extSupport=0.0|
        var follow, extThreshold;
        if((cfg[\solver][\fieldShapeMorphEnabled] ? true) == false) {
            1.0
        } {
            extThreshold = cfg[\solver][\fieldExternalGaugeMinSupport] ? 0.16;
            follow = if((reason == \freeze) or: { reason == \reset }) {
                cfg[\solver][\fieldShapeMorphFreezeFollow] ? 1.0
            } {
                if((reason == \single) or: { reason == \singleReentry }) {
                    cfg[\solver][\fieldShapeMorphSingleFollow] ? 1.0
                } {
                    if(extSupport >= extThreshold) {
                        cfg[\solver][\fieldShapeMorphExternalFollow] ? 0.62
                    } {
                        if((reason == \continuous) or: { reason == \pushBuses }) {
                            cfg[\solver][\fieldShapeMorphContinuousFollow] ? 0.30
                        } {
                            cfg[\solver][\fieldShapeMorphEventFollow] ? 0.42
                        }
                    }
                }
            };
            follow.clip(0.0, 1.0)
        }
    };

    at[\fieldMorphShapeTowardTarget] = { |targetShape, activePcs=nil, reason=\continuous, extSupport=0.0|
        var enabled, n, oldShape, target, shaped, velocity, activeSet, follow, activeBoost, passiveScale, maxStep;
        var diff, localFollow, step, maxMove, maxError, activePcsSafe, now;
        at[\fieldEnsureState].();
        enabled = cfg[\solver][\fieldShapeMorphEnabled] ? true;
        n = cfg[\solver][\numNodes];
        target = targetShape ? Array.fill(n, 0.0);
        oldShape = st[\nodeShapeCents] ? target.copy;
        if(oldShape.size != n) { oldShape = target.copy; };
        activePcsSafe = activePcs ? Array.new;
        now = Main.elapsedTime;

        if(enabled == false) {
            shaped = target.copy;
            velocity = Array.fill(n, { |i| (shaped[i] ? 0.0) - (oldShape[i] ? 0.0) });
        } {
            follow = at[\fieldShapeMorphFollow].(reason, extSupport);
            activeBoost = cfg[\solver][\fieldShapeMorphActiveBoost] ? 1.18;
            passiveScale = cfg[\solver][\fieldShapeMorphPassiveScale] ? 0.82;
            maxStep = cfg[\solver][\fieldShapeMorphMaxStepCents] ? 7.5;
            activeSet = IdentitySet.new;
            activePcsSafe.do { |pc| activeSet.add(pc.asInteger % n); };

            shaped = Array.fill(n, { |i|
                localFollow = follow;
                if(activePcsSafe.notEmpty) {
                    if(activeSet.includes(i)) {
                        localFollow = (localFollow * activeBoost).clip(0.0, 1.0);
                    } {
                        localFollow = (localFollow * passiveScale).clip(0.0, 1.0);
                    };
                };
                diff = (target[i] ? 0.0) - (oldShape[i] ? 0.0);
                step = diff * localFollow;
                if(maxStep > 0.0) { step = step.clip(maxStep.neg, maxStep); };
                (oldShape[i] ? 0.0) + step
            });
            velocity = Array.fill(n, { |i| (shaped[i] ? 0.0) - (oldShape[i] ? 0.0) });
        };

        maxMove = if(velocity.isEmpty) { 0.0 } { velocity.collect { |x| x.abs }.maxItem ? 0.0 };
        maxError = if(target.isEmpty) { 0.0 } { Array.fill(n, { |i| ((target[i] ? 0.0) - (shaped[i] ? 0.0)).abs }).maxItem ? 0.0 };
        st[\targetNodeShapeCents] = target.copy;
        st[\nodeShapeVelocityCents] = velocity.copy;
        st[\lastShapeMorphReport] = (
            timestamp: now,
            reason: reason,
            activePcs: activePcsSafe.copy,
            externalSupport: extSupport,
            follow: at[\fieldShapeMorphFollow].(reason, extSupport),
            maxMoveCents: maxMove,
            maxTargetErrorCents: maxError,
            enabled: enabled
        );
        shaped
    };

    at[\fieldMedianGaugeCents] = {
        var vals, sorted, idx;
        vals = at[\fieldRawDevCents].();
        sorted = vals.copy.sort;
        idx = (sorted.size / 2).floor.clip(0, sorted.size - 1);
        if(sorted.isEmpty) { 0.0 } { sorted[idx] ? 0.0 }
    };

    at[\fieldExternalGaugeInfo] = { |externalSources|
        var sum, total, maxSupport, pc, phase, confidence, stability, sourceStrength, roleScale, behaviorScale, weight, cents, srcs;
        var role, structuralExternal, structuralFloor, structuralMinStability, structuralMinConfidence;
        srcs = externalSources ? Array.new;
        sum = 0.0;
        total = 0.0;
        maxSupport = 0.0;
        structuralFloor = (cfg[\solver][\externalStructuralGaugeSupportFloor] ? 0.24).clip(0.0, 1.0);
        structuralMinStability = (cfg[\solver][\externalStructuralGaugeMinStability] ? 0.55).clip(0.0, 1.0);
        structuralMinConfidence = (cfg[\solver][\externalStructuralGaugeMinConfidence] ? (cfg[\mic][\minConfidence] ? 0.003)).clip(0.0, 1.0);
        srcs.do { |src|
            if(src.notNil and: { src[\pc].notNil and: { src[\phase].notNil } }) {
                pc = src[\pc].asInteger % 12;
                phase = src[\phase];
                confidence = (src[\confidence] ? 0.0).clip(0.0, 1.0);
                stability = (src[\stability] ? 0.0).clip(0.0, 1.0);
                sourceStrength = if(at[\sourceStrength].notNil) { (at[\sourceStrength].(src) ? (src[\weight] ? 0.0)) } { (src[\weight] ? 0.0) };
                sourceStrength = sourceStrength.clip(0.0, 1.2);
                roleScale = if(at[\externalRoleGaugeScale].notNil) { at[\externalRoleGaugeScale].(src, Array.new).clip(0.0, 1.5) } { 1.0 };
                behaviorScale = if(at[\externalBehaviorScale].notNil) { at[\externalBehaviorScale].(src).clip(0.0, 1.2) } { stability };
                role = if(at[\normalizeExternalRole].notNil) { at[\normalizeExternalRole].(src[\sourceRole] ? src[\role]) } { src[\sourceRole] ? src[\role] };
                structuralExternal = (role == \externalDrone) or: { role == \externalBass } or: { role == \externalPianoLike };
                // Support answers: is this source real enough to move whole-field gauge?
                // It is not a distance cap. A stable source 40 cents away may carry gauge;
                // a noisy/unstable source does not.
                weight = (sourceStrength * confidence.sqrt * stability * behaviorScale * roleScale).max(0.0);

                // r17ah: structural external roles (drone/bass/piano-like) are intentionally
                // allowed to carry absolute gauge even when their microphone confidence is low
                // because laptop speakers/mics often produce stable but low-amplitude candidates.
                // The source must already be committed, stable, and above the basic confidence
                // floor; singers/melody/unknown sources keep the stricter confidence-weighted path.
                if(structuralExternal
                    and: { stability >= structuralMinStability }
                    and: { confidence >= structuralMinConfidence }
                    and: { (src[\active] ? true) == true }) {
                    weight = weight.max(structuralFloor * stability * behaviorScale * roleScale);
                };

                cents = at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0;
                sum = sum + (cents * weight.max(0.000001));
                total = total + weight.max(0.000001);
                maxSupport = maxSupport.max(weight.clip(0.0, 1.0));
            };
        };
        if(total > 0.000001) {
            (gaugeCents: sum / total, support: maxSupport.clip(0.0, 1.0), count: srcs.size)
        } {
            (gaugeCents: nil, support: 0.0, count: 0)
        }
    };

    at[\fieldExternalGaugeCents] = { |externalSources|
        var info;
        info = at[\fieldExternalGaugeInfo].(externalSources);
        info[\gaugeCents]
    };

    at[\fieldSyncShapeFromNodePhase] = { |gaugeCents=nil|
        var gauge, devs;
        at[\fieldEnsureState].();
        gauge = gaugeCents ? (st[\fieldTrueGaugeCents] ? 0.0);
        st[\fieldTrueGaugeCents] = gauge;
        devs = at[\fieldRawDevCents].();
        st[\nodeShapeCents] = devs.collect { |x| x - gauge };
        st[\fieldGaugeCents] = gauge; // compatibility: old diagnostics read this name
        nil
    };

    at[\fieldReset] = {
        at[\fieldEnsureState].();
        st[\fieldTrueGaugeCents] = 0.0;
        st[\fieldTrueGaugeVelocityCents] = 0.0;
        st[\fieldGaugeCents] = 0.0;
        st[\fieldGaugeVelocity] = 0.0;
        st[\fieldGaugeLastOffset] = 0.0;
        st[\fieldGaugeLastTime] = nil;
        st[\nodeShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\frozenShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\frozenGaugeCents] = 0.0;
        st[\lastFieldDecompositionReport] = nil;
        st[\targetNodeShapeCents] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\nodeShapeVelocityCents] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\lastShapeMorphReport] = nil;
        nil
    };

    at[\fieldFreezeShapeGauge] = {
        var pcs;
        at[\fieldEnsureState].();
        pcs = st[\lastFrozenActivePcs] ? at[\fieldCurrentActivePcs].();
        at[\fieldEnforceGaugeShape].(pcs, at[\fieldCurrentExternalSources].(), \freeze, at[\fieldCurrentPcWeights].());
        st[\frozenShapeCents] = (st[\nodeShapeCents] ? Array.fill(cfg[\solver][\numNodes], 0.0)).copy;
        st[\frozenGaugeCents] = st[\fieldTrueGaugeCents] ? 0.0;
        st[\frozenPhase] = st[\nodePhase].copy;
        nil
    };

    at[\fieldEnforceGaugeShape] = { |activePcs=nil, externalSources=nil, reason=\continuous, pcWeights=nil|
        var enabled, act, ext, extInfo, gaugeInfo, oldGauge, targetGauge, newGauge, follow, extSupport, extThreshold;
        var devs, shape, targetShape, shapeCentroid, extracted, n, normalizeStrength, shouldNormalizeShape;
        var oldVel, now, morphReport, currentShape, committedDevs, rawDiff, dirtyThreshold, passiveReason, snapshotReason;
        var targetBefore, targetDiff;
        enabled = cfg[\solver][\fieldDecompositionEnabled] ? true;
        at[\fieldEnsureState].();
        act = activePcs ? at[\fieldCurrentActivePcs].();
        ext = externalSources ? at[\fieldCurrentExternalSources].();
        now = Main.elapsedTime;
        n = cfg[\solver][\numNodes];

        if(enabled == false) {
            at[\fieldSyncShapeFromNodePhase].(st[\fieldTrueGaugeCents] ? 0.0);
            false
        } {
            oldGauge = st[\fieldTrueGaugeCents] ? 0.0;
            oldVel = st[\fieldTrueGaugeVelocityCents] ? 0.0;
            currentShape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
            if(currentShape.size != n) { currentShape = Array.fill(n, 0.0); };
            targetBefore = st[\targetNodeShapeCents] ? currentShape.copy;
            if(targetBefore.size != n) { targetBefore = currentShape.copy; };

            extInfo = at[\fieldExternalGaugeInfo].(ext);
            gaugeInfo = if(at[\gravityCombinedGaugeInfo].notNil) { at[\gravityCombinedGaugeInfo].(extInfo) } { extInfo };
            extSupport = gaugeInfo[\support] ? 0.0;
            extThreshold = cfg[\solver][\fieldExternalGaugeMinSupport] ? 0.16;
            devs = at[\fieldRawDevCents].();
            rawDiff = at[\fieldRawVsCommittedMaxDiffCents].(devs);
            dirtyThreshold = cfg[\solver][\fieldShapeMorphDirtyThresholdCents] ? 0.035;
            snapshotReason = (reason == \snapshot);
            passiveReason = ((reason == \pushBuses) or: { reason == \barrier }) and: { rawDiff <= dirtyThreshold };

            // r16d: snapshots and clean push-bus barriers must not reinterpret the
            // already-sounding current shape as a new target. This was why r16c
            // always printed shapeMove=0 and shapeErr=0: snapshot/pushBuses were
            // retargeting from the current committed nodePhase and erasing the
            // target/current gap. Only a dirty legacy write or an explicit solver
            // call may create a new target.
            if(snapshotReason and: { (cfg[\solver][\fieldShapeMorphSnapshotRetargets] ? false) == false }) {
                at[\fieldComposeFromShapeGauge].();
                true
            } {
                if(passiveReason) {
                    at[\fieldComposeFromShapeGauge].();
                    true
                } {
                    if(gaugeInfo[\gaugeCents].notNil and: { extSupport >= extThreshold }) {
                        targetGauge = gaugeInfo[\gaugeCents];
                        follow = cfg[\solver][\fieldExternalTrueGaugeFollow] ? 1.0;
                        newGauge = oldGauge + ((targetGauge - oldGauge) * follow.clip(0.0, 1.0));
                    } {
                        // No reliable acoustic gauge source: preserve only the prior true gauge.
                        // Internal harmony may still reshape the field, but cannot hide centroid
                        // residue inside nodeShape.
                        targetGauge = oldGauge;
                        newGauge = oldGauge;
                    };

                    if((gaugeInfo[\hasGravity] ? false) and: { rawDiff <= dirtyThreshold }) {
                        // Absolute gravity is a trueGauge pull. When no legacy/raw solver
                        // proposal is pending, keep harmonic shape intact and move the
                        // whole field by gauge. This is not a shape ratchet or ET reset.
                        shape = currentShape.copy;
                    } {
                        shape = devs.collect { |x| x - newGauge };
                    };
                    shapeCentroid = 0.0;
                    extracted = 0.0;
                    shouldNormalizeShape = (act.size > 1) and: { extSupport < extThreshold };
                    if(shouldNormalizeShape) {
                        normalizeStrength = cfg[\solver][\fieldInternalShapeCentroidRemoval] ? 1.0;
                        shapeCentroid = at[\fieldWeightedShapeCentroidCents].(shape, act, pcWeights);
                        extracted = shapeCentroid * normalizeStrength.clip(0.0, 1.0);
                        if(extracted.abs > 0.000001) {
                            shape = shape.collect { |x| x - extracted };
                        };
                    } {
                        // With a trusted external gauge, do not steal the source's gauge by forcing
                        // the active centroid to zero. The external source owns trueGauge.
                        shapeCentroid = if(act.size > 1) { at[\fieldWeightedShapeCentroidCents].(shape, act, pcWeights) } { 0.0 };
                    };

                    targetShape = shape.copy;
                    shape = at[\fieldMorphShapeTowardTarget].(targetShape, act, reason, extSupport);
                    morphReport = st[\lastShapeMorphReport];

                    st[\fieldTrueGaugeVelocityCents] = newGauge - oldGauge;
                    if(extSupport < extThreshold) {
                        st[\fieldTrueGaugeVelocityCents] = (st[\fieldTrueGaugeVelocityCents] ? 0.0)
                            + (oldVel * (cfg[\solver][\fieldUnsupportedGaugeVelocityDecay] ? 0.35).clip(0.0, 1.0));
                    };
                    st[\fieldTrueGaugeCents] = newGauge;
                    st[\fieldGaugeCents] = newGauge;
                    st[\nodeShapeCents] = shape.copy;
                    at[\fieldComposeFromShapeGauge].();

                    // The motion bus should describe the committed audible movement, not the
                    // larger raw legacy proposal that got normalized or morphed away. Otherwise
                    // render roughness can spike even when the pitch field is now moving smoothly.
                    if((cfg[\solver][\fieldShapeMorphDescriptorsFromCommitted] ? true) == true) {
                        st[\lastDelta] = Array.fill(n, { |i| (((st[\nodeShapeVelocityCents][i] ? 0.0) + (st[\fieldTrueGaugeVelocityCents] ? 0.0)) / 1200.0) });
                        st[\nodeMotion] = Array.fill(n, { |i| ((st[\lastDelta][i] ? 0.0).abs / (cfg[\solver][\maxStep] ? 0.01)).clip(0.0, 1.0) });
                        st[\nodeStability] = Array.fill(n, { |i| ((st[\nodeAlignment][i] ? 1.0) * (1.0 - (st[\nodeMotion][i] ? 0.0))).clip(0.0, 1.0) });
                    };

                    if(cfg[\solver][\fieldDecompositionReportEnabled] ? true) {
                        targetDiff = Array.fill(n, { |i| ((targetShape[i] ? 0.0) - (targetBefore[i] ? 0.0)).abs }).maxItem ? 0.0;
                        st[\lastFieldDecompositionReport] = (
                            timestamp: now,
                            reason: reason,
                            activePcs: act.copy,
                            externalCount: ext.size,
                            externalGaugeCents: extInfo[\gaugeCents],
                            externalGaugeSupport: extInfo[\support] ? 0.0,
                            externalGaugeAccepted: (extInfo[\gaugeCents].notNil and: { (extInfo[\support] ? 0.0) >= extThreshold }),
                            gaugeCents: gaugeInfo[\gaugeCents],
                            gaugeSupport: extSupport,
                            gaugeAccepted: (gaugeInfo[\gaugeCents].notNil and: { extSupport >= extThreshold }),
                            gravityReport: st[\lastGravityReport],
                            rawVsCommittedDiffCents: rawDiff,
                            targetShapeChangedCents: targetDiff,
                            trueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                            trueGaugeVelocityCents: st[\fieldTrueGaugeVelocityCents] ? 0.0,
                            shapeCentroidBeforeNormalizeCents: shapeCentroid,
                            unsupportedGaugeResidueRemovedCents: extracted,
                            shapeCentroidAfterNormalizeCents: if(act.size > 1) { at[\fieldWeightedShapeCentroidCents].(st[\nodeShapeCents], act, pcWeights) } { 0.0 },
                            targetShapeCents: (st[\targetNodeShapeCents] ? Array.new).copy,
                            shapeCents: (st[\nodeShapeCents] ? Array.new).copy,
                            shapeMorphMaxMoveCents: if(morphReport.isNil) { 0.0 } { morphReport[\maxMoveCents] ? 0.0 },
                            shapeMorphTargetErrorCents: if(morphReport.isNil) { 0.0 } { morphReport[\maxTargetErrorCents] ? 0.0 },
                            shapeMorphFollow: if(morphReport.isNil) { 1.0 } { morphReport[\follow] ? 1.0 }
                        );
                    };
                    true
                }
            }
        }
    };

    // r16b hard write barrier. This is the authoritative commit point used
    // before buses and snapshots. It prevents legacy nodePhase writes from
    // bypassing gauge/shape separation.
    at[\fieldWriteBarrier] = { |reason=\barrier, activePcs=nil, externalSources=nil|
        var act, ext, weights, result;
        at[\fieldEnsureState].();
        act = activePcs ? at[\fieldCurrentActivePcs].();
        ext = externalSources ? at[\fieldCurrentExternalSources].();
        weights = at[\fieldCurrentPcWeights].();
        result = at[\fieldEnforceGaugeShape].(act, ext, reason, weights);
        result
    };

    // Backward-compatible entry point used throughout the r15/r16 solver.
    at[\fieldSeparateGaugeShape] = { |activePcs=nil, externalSources=nil, reason=\continuous|
        var weights;
        weights = if(at[\pcWeights].notNil) { at[\pcWeights].() } { nil };
        at[\fieldEnforceGaugeShape].(activePcs, externalSources, reason, weights)
    };

    at[\fieldEnsureState].();
    "[at-field] r16d real target/current shape separation / hard write barrier loaded".postln;
};
)
