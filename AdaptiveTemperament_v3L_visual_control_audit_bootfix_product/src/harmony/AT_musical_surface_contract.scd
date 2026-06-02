(
// AT_musical_surface_contract.scd
// v3F final musical pitch-surface contract / musical-sanity and product-tone boundary.
// This is not ET snapping, not key detection, and not a chord-name layer.
// It is the final playable-keyboard boundary: every authority may propose a
// harmonic target, but the product surface must remain a legible temperament.

var build, at, cfg, st, api;

build = ~atBuild;

if(build.isNil) {
    "[at-musical-surface] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api];

    if(cfg[\musicalSurfaceContract].isNil) {
        cfg[\musicalSurfaceContract] = (
            enabled: true,
            maxPassiveAbsCents: 34.0,
            maxActiveAbsCents: 16.0,
            maxShapeSpanCents: 52.0,
            maxGaugeAbsCents: 28.0,
            emergencyMaxAbsCents: 46.0,
            projectPitchIdentityGaps: true,
            debug: false
        );
    };

    if(cfg[\pitchIdentityRuntimeGuard].notNil) {
        cfg[\pitchIdentityRuntimeGuard][\passiveNeighborFloorCents] = 84.0;
        cfg[\pitchIdentityRuntimeGuard][\activeNeighborFloorCents] = 90.0;
        cfg[\pitchIdentityRuntimeGuard][\maxNeighborGapCents] = 124.0;
        cfg[\pitchIdentityRuntimeGuard][\emergencyFloorCents] = 72.0;
    };

    at[\musicalSurfaceNumber] = { |x, fallback=0.0|
        if(x.isNil) { fallback.asFloat } { x.asFloat };
    };

    at[\musicalSurfaceActivePcs] = { |activePcs=nil|
        var pcs;
        pcs = activePcs;
        if(pcs.isNil) {
            pcs = if(at[\pitchIdentityRuntimeActivePcs].notNil) { at[\pitchIdentityRuntimeActivePcs].() } {
                if(st[\activeNotes].notNil) { st[\activeNotes].values.asArray.collect { |n| n[\pc] ? 0 }.as(Set).asArray.sort } { Array.new };
            };
        };
        pcs ? Array.new;
    };

    at[\musicalSurfaceMedian] = { |arr|
        var a, sorted, idx;
        a = arr ? Array.new;
        if(a.isEmpty) { 0.0 } {
            sorted = a.collect { |x| at[\musicalSurfaceNumber].(x, 0.0) }.sort;
            idx = (sorted.size / 2).floor.clip(0, sorted.size - 1);
            sorted[idx] ? 0.0;
        };
    };

    at[\musicalSurfaceSpan] = { |arr|
        var a;
        a = arr ? Array.new;
        if(a.isEmpty) { 0.0 } { (a.maxItem ? 0.0) - (a.minItem ? 0.0) };
    };

    at[\musicalSurfaceMaxAbs] = { |arr|
        var a;
        a = arr ? Array.new;
        if(a.isEmpty) { 0.0 } { a.collect { |x| (x ? 0.0).abs }.maxItem ? 0.0 };
    };

    at[\musicalSurfaceActiveMaxAbs] = { |arr, activePcs=nil|
        var pcs, a, vals;
        a = arr ? Array.new;
        pcs = at[\musicalSurfaceActivePcs].(activePcs);
        if(pcs.isEmpty or: { a.isEmpty }) { 0.0 } {
            vals = pcs.collect { |pc| (a[pc.asInteger % a.size] ? 0.0).abs };
            vals.maxItem ? 0.0;
        };
    };

    at[\musicalSurfaceClipAndScaleShape] = { |shape=nil, activePcs=nil|
        var n, cfgS, s, active, activeSet, maxPassive, maxActive, maxSpan, median, span, scale, changed;
        n = cfg[\solver][\numNodes] ? 12;
        cfgS = cfg[\musicalSurfaceContract] ? ();
        maxPassive = (cfgS[\maxPassiveAbsCents] ? 34.0).asFloat.max(1.0);
        maxActive = (cfgS[\maxActiveAbsCents] ? 16.0).asFloat.max(1.0);
        maxSpan = (cfgS[\maxShapeSpanCents] ? 52.0).asFloat.max(maxActive * 2.0);
        s = shape ? Array.fill(n, 0.0);
        if(s.size != n) { s = Array.fill(n, 0.0); } { s = Array.fill(n, { |i| at[\musicalSurfaceNumber].(s[i], 0.0) }); };
        active = at[\musicalSurfaceActivePcs].(activePcs);
        activeSet = IdentitySet.new;
        active.do { |pc| activeSet.add(pc.asInteger % n); };
        changed = false;

        median = at[\musicalSurfaceMedian].(s);
        if(median.abs > 0.0001) {
            s = s.collect { |x| (x ? 0.0) - median };
            changed = true;
        };

        s = Array.fill(n, { |i|
            var lim, before, after;
            lim = if(activeSet.includes(i)) { maxActive } { maxPassive };
            before = s[i] ? 0.0;
            after = before.clip(lim.neg, lim);
            if((after - before).abs > 0.0001) { changed = true; };
            after;
        });

        span = at[\musicalSurfaceSpan].(s);
        if(span > maxSpan) {
            median = at[\musicalSurfaceMedian].(s);
            s = s.collect { |x| (x ? 0.0) - median };
            scale = (maxSpan / span).clip(0.0, 1.0);
            s = s.collect { |x| (x ? 0.0) * scale };
            changed = true;
        };

        // Final pass after global scaling, so active held notes cannot be thrown
        // outside their named-note identity by a register/velocity or memory target.
        s = Array.fill(n, { |i|
            var lim, before, after;
            lim = if(activeSet.includes(i)) { maxActive } { maxPassive };
            before = s[i] ? 0.0;
            after = before.clip(lim.neg, lim);
            if((after - before).abs > 0.0001) { changed = true; };
            after;
        });

        (shapeCents: s, changed: changed);
    };

    at[\musicalSurfaceContractProjectGaugeShape] = { |gauge=0.0, shape=nil, reason=\surface, activePcs=nil, role=\target|
        var n, cfgS, enabled, active, gaugeIn, sIn, beforeSpan, beforeMax, beforeActiveMax;
        var median, gaugeMid, maxGauge, clip1, s, phase, projectedPhase, converted, clip2, outGauge, outShape;
        var afterSpan, afterMax, afterActiveMax, changed, report;
        n = cfg[\solver][\numNodes] ? 12;
        cfgS = cfg[\musicalSurfaceContract] ? ();
        enabled = cfgS[\enabled] ? true;
        active = at[\musicalSurfaceActivePcs].(activePcs);
        gaugeIn = at[\musicalSurfaceNumber].(gauge, 0.0);
        sIn = shape ? Array.fill(n, 0.0);
        if(sIn.size != n) { sIn = Array.fill(n, 0.0); } { sIn = Array.fill(n, { |i| at[\musicalSurfaceNumber].(sIn[i], 0.0) }); };
        beforeSpan = at[\musicalSurfaceSpan].(sIn);
        beforeMax = at[\musicalSurfaceMaxAbs].(sIn);
        beforeActiveMax = at[\musicalSurfaceActiveMaxAbs].(sIn, active);

        if(enabled.not) {
            report = (role: \musicalSurfaceContract, enabled: false, reason: reason, changed: false, activePcs: active, gaugeCents: gaugeIn, shapeSpanCents: beforeSpan, maxAbsCents: beforeMax, activeMaxAbsCents: beforeActiveMax, pitchAuthorityAdded: false);
            st[\lastMusicalSurfaceContractReport] = report;
            (gaugeCents: gaugeIn, shapeCents: sIn.copy, changed: false, report: report)
        } {
            median = at[\musicalSurfaceMedian].(sIn);
            gaugeMid = gaugeIn + median;
            s = sIn.collect { |x| (x ? 0.0) - median };
            changed = median.abs > 0.0001;

            clip1 = at[\musicalSurfaceClipAndScaleShape].(s, active);
            s = clip1[\shapeCents] ? s;
            if(clip1[\changed] == true) { changed = true; };

            if((cfgS[\projectPitchIdentityGaps] ? true) and: { at[\pitchIdentityRuntimeProject].notNil and: { at[\globalMotionGateTargetPhaseFromGaugeShape].notNil and: { at[\globalMotionGateTargetFromPhase].notNil } } }) {
                phase = at[\globalMotionGateTargetPhaseFromGaugeShape].(gaugeMid, s);
                projectedPhase = at[\pitchIdentityRuntimeProject].(phase, active);
                if(at[\globalMotionGateMaxPhaseDiffCents].notNil) {
                    if(at[\globalMotionGateMaxPhaseDiffCents].(phase, projectedPhase) > 0.001) { changed = true; };
                };
                converted = at[\globalMotionGateTargetFromPhase].(projectedPhase);
                gaugeMid = converted[\gaugeCents] ? gaugeMid;
                s = converted[\shapeCents] ? s;
                clip2 = at[\musicalSurfaceClipAndScaleShape].(s, active);
                s = clip2[\shapeCents] ? s;
                if(clip2[\changed] == true) { changed = true; };
            };

            maxGauge = (cfgS[\maxGaugeAbsCents] ? 28.0).asFloat.max(1.0);
            if(gaugeMid.abs > maxGauge) {
                gaugeMid = gaugeMid.clip(maxGauge.neg, maxGauge);
                changed = true;
            };
            outGauge = gaugeMid;
            outShape = s.copy;
            afterSpan = at[\musicalSurfaceSpan].(outShape);
            afterMax = at[\musicalSurfaceMaxAbs].(outShape);
            afterActiveMax = at[\musicalSurfaceActiveMaxAbs].(outShape, active);
            if((afterSpan - beforeSpan).abs > 0.001 or: { (afterMax - beforeMax).abs > 0.001 or: { (outGauge - gaugeIn).abs > 0.001 } }) { changed = true; };
            report = (
                role: \musicalSurfaceContract, enabled: true, reason: reason, surfaceRole: role,
                changed: changed, activePcs: active.copy,
                gaugeInCents: gaugeIn.round(0.01), gaugeOutCents: outGauge.round(0.01),
                shapeSpanInCents: beforeSpan.round(0.01), shapeSpanOutCents: afterSpan.round(0.01),
                maxAbsInCents: beforeMax.round(0.01), maxAbsOutCents: afterMax.round(0.01),
                activeMaxInCents: beforeActiveMax.round(0.01), activeMaxOutCents: afterActiveMax.round(0.01),
                maxPassiveAbsCents: (cfgS[\maxPassiveAbsCents] ? 34.0),
                maxActiveAbsCents: (cfgS[\maxActiveAbsCents] ? 16.0),
                maxShapeSpanCents: (cfgS[\maxShapeSpanCents] ? 52.0),
                maxGaugeAbsCents: (cfgS[\maxGaugeAbsCents] ? 28.0),
                pitchAuthorityAdded: false,
                note: if(changed) { "Playable keyboard surface contracted: authorities kept, impossible pitch-map deformation rejected." } { "Surface already within playable bounds." }
            );
            st[\lastMusicalSurfaceContractReport] = report;
            if(changed and: { cfgS[\debug] ? false }) {
                ("[AT MUSICAL SURFACE CONTRACT] reason=" ++ reason.asString ++ " role=" ++ role.asString ++ " span " ++ beforeSpan.round(0.01).asString ++ "c -> " ++ afterSpan.round(0.01).asString ++ "c max " ++ beforeMax.round(0.01).asString ++ "c -> " ++ afterMax.round(0.01).asString ++ "c").postln;
            };
            (gaugeCents: outGauge, shapeCents: outShape, changed: changed, report: report)
        };
    };

    at[\musicalSurfaceContractProjectPhase] = { |phase=nil, reason=\surfacePhase, activePcs=nil, role=\phase|
        var converted, projected;
        if(at[\globalMotionGateTargetFromPhase].isNil or: { at[\globalMotionGateTargetPhaseFromGaugeShape].isNil }) {
            phase
        } {
            converted = at[\globalMotionGateTargetFromPhase].(phase ? (st[\nodePhase] ? st[\etPhase]));
            projected = at[\musicalSurfaceContractProjectGaugeShape].(converted[\gaugeCents] ? 0.0, converted[\shapeCents] ? Array.fill(cfg[\solver][\numNodes] ? 12, 0.0), reason, activePcs, role);
            at[\globalMotionGateTargetPhaseFromGaugeShape].(projected[\gaugeCents] ? 0.0, projected[\shapeCents] ? Array.fill(cfg[\solver][\numNodes] ? 12, 0.0));
        };
    };

    if(at[\musicalSurfaceOriginalGlobalMotionGateRealize].isNil and: { at[\globalMotionGateRealize].notNil }) {
        at[\musicalSurfaceOriginalGlobalMotionGateRealize] = at[\globalMotionGateRealize];
        at[\globalMotionGateRealize] = { |targetGauge=0.0, targetShape=nil, reason=\manual|
            var n, active, currentGauge, currentShape, currentProject, targetProject, oldRealize, report;
            n = cfg[\solver][\numNodes] ? 12;
            active = at[\musicalSurfaceActivePcs].(nil);
            currentGauge = st[\globalMotionRealizedGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0);
            currentShape = st[\globalMotionRealizedNodeShapeCents] ? (st[\nodeShapeCents] ? Array.fill(n, 0.0));
            if(currentShape.size != n) { currentShape = Array.fill(n, 0.0); };
            currentProject = at[\musicalSurfaceContractProjectGaugeShape].(currentGauge, currentShape, reason, active, \current);
            if(currentProject[\changed] == true) {
                st[\globalMotionRealizedGaugeCents] = currentProject[\gaugeCents] ? currentGauge;
                st[\globalMotionRealizedNodeShapeCents] = (currentProject[\shapeCents] ? currentShape).copy;
                st[\fieldTrueGaugeCents] = currentProject[\gaugeCents] ? currentGauge;
                st[\fieldGaugeCents] = currentProject[\gaugeCents] ? currentGauge;
                st[\nodeShapeCents] = (currentProject[\shapeCents] ? currentShape).copy;
            };
            targetProject = at[\musicalSurfaceContractProjectGaugeShape].(targetGauge, targetShape, reason, active, \target);
            oldRealize = at[\musicalSurfaceOriginalGlobalMotionGateRealize];
            report = oldRealize.value(targetProject[\gaugeCents] ? 0.0, targetProject[\shapeCents] ? Array.fill(n, 0.0), reason);
            if(report.notNil) { report[\musicalSurfaceContract] = targetProject[\report]; };
            report;
        };
    };

    if(at[\musicalSurfaceOriginalFieldMorphShapeTowardTarget].isNil and: { at[\fieldMorphShapeTowardTarget].notNil }) {
        at[\musicalSurfaceOriginalFieldMorphShapeTowardTarget] = at[\fieldMorphShapeTowardTarget];
        at[\fieldMorphShapeTowardTarget] = { |targetShape, activePcs=nil, reason=\continuous, extSupport=0.0|
            var n, gauge, projected, oldMorph;
            n = cfg[\solver][\numNodes] ? 12;
            gauge = st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0);
            projected = at[\musicalSurfaceContractProjectGaugeShape].(gauge, targetShape, reason, activePcs, \fieldMorphTarget);
            oldMorph = at[\musicalSurfaceOriginalFieldMorphShapeTowardTarget];
            oldMorph.value(projected[\shapeCents] ? Array.fill(n, 0.0), activePcs, reason, extSupport);
        };
    };

    if(at[\musicalSurfaceOriginalLearnTonalMemory].isNil and: { at[\learnTonalMemory].notNil }) {
        at[\musicalSurfaceOriginalLearnTonalMemory] = at[\learnTonalMemory];
        at[\learnTonalMemory] = { |evidencePhase, activePcs=nil, reason=\solve|
            var oldLearn, projected;
            oldLearn = at[\musicalSurfaceOriginalLearnTonalMemory];
            oldLearn.value(evidencePhase, activePcs, reason);
            if(st[\memoryPhase].notNil) {
                projected = at[\musicalSurfaceContractProjectPhase].(st[\memoryPhase], \memoryLearn, activePcs, \memory);
                if(projected.notNil) { st[\memoryPhase] = projected.copy; };
            };
            nil;
        };
    };

    if(at[\musicalSurfaceOriginalApplyTonalMemoryBias].isNil and: { at[\applyTonalMemoryBias].notNil }) {
        at[\musicalSurfaceOriginalApplyTonalMemoryBias] = at[\applyTonalMemoryBias];
        at[\applyTonalMemoryBias] = { |evidencePhase, activePcs=nil, reason=\solve|
            var oldApply, out;
            oldApply = at[\musicalSurfaceOriginalApplyTonalMemoryBias];
            out = oldApply.value(evidencePhase, activePcs, reason);
            at[\musicalSurfaceContractProjectPhase].(out, \memoryBias, activePcs, \memoryBias);
        };
    };

    api[\musicalSurfaceContractReport] = { st[\lastMusicalSurfaceContractReport] ? (role: \musicalSurfaceContract, changed: false, note: \noReportYet) };

    api[\runMusicalSurfaceContractDemo] = {
        var n, pass, fail, check, mkShape, rep, beforeBad, afterBad, beforeActive, afterActive;
        n = cfg[\solver][\numNodes] ? 12;
        pass = 0; fail = 0;
        check = { |name, cond, detail=""|
            if(cond) { pass = pass + 1; ("[AT MUSICAL SURFACE PASS] " ++ name.asString ++ " :: " ++ detail.asString).postln; }
            { fail = fail + 1; ("[AT MUSICAL SURFACE FAIL] " ++ name.asString ++ " :: " ++ detail.asString).warn; };
        };
        mkShape = Array.fill(n, { |i| if(i.even) { 260.0 } { -260.0 } });
        beforeBad = at[\musicalSurfaceSpan].(mkShape);
        rep = at[\musicalSurfaceContractProjectGaugeShape].(0.0, mkShape, \surfaceContractDemo, [0,4,7], \target);
        afterBad = at[\musicalSurfaceSpan].(rep[\shapeCents]);
        beforeActive = at[\musicalSurfaceActiveMaxAbs].(mkShape, [0,4,7]);
        afterActive = at[\musicalSurfaceActiveMaxAbs].(rep[\shapeCents], [0,4,7]);
        check.(\badSurfaceCompressed, afterBad <= ((cfg[\musicalSurfaceContract][\maxShapeSpanCents] ? 126.0) + 0.01), "beforeSpan=" ++ beforeBad.round(0.01).asString ++ " afterSpan=" ++ afterBad.round(0.01).asString);
        check.(\activeSurfaceBounded, afterActive <= ((cfg[\musicalSurfaceContract][\maxActiveAbsCents] ? 38.0) + 0.01), "beforeActive=" ++ beforeActive.round(0.01).asString ++ " afterActive=" ++ afterActive.round(0.01).asString);
        check.(\pitchAuthorityNotAdded, (rep[\report][\pitchAuthorityAdded] ? true) == false, "pitchAuthorityAdded=" ++ (rep[\report][\pitchAuthorityAdded] ? nil).asString);
        ("[AT MUSICAL SURFACE CONTRACT v3F] pass=" ++ pass.asString ++ " fail=" ++ fail.asString ++ " readyForFinalDemo=" ++ (fail == 0).asString).postln;
        (pass: pass, fail: fail, readyForFinalDemo: fail == 0, report: rep[\report]);
    };

    "[at-musical-surface] v3F final musical pitch-surface and product-tone sanity contract loaded; normal product mode bounds active/passive shape and global gauge without ET snapping.".postln;
};
)
