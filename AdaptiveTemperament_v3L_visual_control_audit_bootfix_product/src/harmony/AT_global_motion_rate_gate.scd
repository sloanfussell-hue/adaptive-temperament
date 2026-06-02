(
// AT_global_motion_rate_gate.scd
// Clean final foundation global Motion/Movement live-authority realization gate with administrative reset cleanup.
//
// Target calculation may happen immediately. This module gates realized field
// movement afterward. Motion=0 keeps the current gauge/shape/active render field
// frozen while target reports can update; Motion=1 commits the target as fast as
// the existing safe path permits. v2e keeps the live-authority write barrier/runtime guards and fixes the live new-note spawn proof so it compares against the pre-spawn hidden target instead of the post-onset harmonic-origin target:
// single-note/core path, arpeggio transport, register/velocity chord authority,
// external coherence, and new voice spawning must all pass through this same
// target/current boundary. This is not a mode and not a harmonic-law layer.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-global-motion] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    cfg[\solver][\globalMotionRateGateEnabled] = cfg[\solver][\globalMotionRateGateEnabled] ? true;
    cfg[\solver][\globalMotionRateGateEpsilon] = cfg[\solver][\globalMotionRateGateEpsilon] ? 0.000001;

    at[\globalMotionGateAmount] = {
        (st[\movement] ? 0.82).clip(0.0, 1.0)
    };

    at[\globalMotionGateEnsureState] = {
        var n, shape;
        n = cfg[\solver][\numNodes] ? 12;
        if(st[\globalMotionRealizedGaugeCents].isNil) { st[\globalMotionRealizedGaugeCents] = st[\fieldTrueGaugeCents] ? 0.0; };
        if(st[\globalMotionTargetGaugeCents].isNil) { st[\globalMotionTargetGaugeCents] = st[\fieldTrueGaugeCents] ? 0.0; };
        if(st[\globalMotionRealizedNodeShapeCents].isNil or: { st[\globalMotionRealizedNodeShapeCents].size != n }) {
            shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
            if(shape.size != n) { shape = Array.fill(n, 0.0); };
            st[\globalMotionRealizedNodeShapeCents] = shape.copy;
        };
        if(st[\globalMotionTargetNodeShapeCents].isNil or: { st[\globalMotionTargetNodeShapeCents].size != n }) {
            shape = st[\targetNodeShapeCents] ? (st[\nodeShapeCents] ? Array.fill(n, 0.0));
            if(shape.size != n) { shape = Array.fill(n, 0.0); };
            st[\globalMotionTargetNodeShapeCents] = shape.copy;
        };
        if(st[\lastGlobalMotionRateGateReport].isNil) { st[\lastGlobalMotionRateGateReport] = nil; };
        nil
    };

    at[\globalMotionGateMaxAbsDiff] = { |a, b|
        var n, vals;
        n = cfg[\solver][\numNodes] ? 12;
        a = a ? Array.fill(n, 0.0);
        b = b ? Array.fill(n, 0.0);
        vals = Array.fill(n, { |i| ((a[i] ? 0.0) - (b[i] ? 0.0)).abs });
        if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 }
    };

    at[\globalMotionGateShapeSpan] = { |shape|
        var s;
        s = shape ? Array.new;
        if(s.isEmpty) { 0.0 } { (s.maxItem ? 0.0) - (s.minItem ? 0.0) }
    };

    at[\globalMotionGateTargetPhaseFromGaugeShape] = { |targetGauge=0.0, targetShape=nil|
        var n, shape, gauge;
        n = cfg[\solver][\numNodes] ? 12;
        gauge = (targetGauge ? 0.0).asFloat;
        shape = targetShape ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        Array.fill(n, { |pc|
            at[\wrap01].(st[\etPhase][pc] + ((gauge + (shape[pc] ? 0.0)) / 1200.0))
        })
    };

    at[\globalMotionGateComposeCurrent] = {
        var n, gauge, shape;
        n = cfg[\solver][\numNodes] ? 12;
        gauge = st[\fieldTrueGaugeCents] ? 0.0;
        shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        st[\nodePhase] = Array.fill(n, { |pc|
            at[\wrap01].(st[\etPhase][pc] + ((gauge + (shape[pc] ? 0.0)) / 1200.0))
        });
        st[\fieldGaugeCents] = gauge;
        st[\nodePhase]
    };

    at[\globalMotionGateMaxPhaseDiffCents] = { |phaseA=nil, phaseB=nil|
        var n, a, b, vals;
        n = cfg[\solver][\numNodes] ? 12;
        a = phaseA ? (st[\nodePhase] ? st[\etPhase]);
        b = phaseB ? (st[\nodePhase] ? st[\etPhase]);
        if(a.size != n) { a = st[\etPhase].copy; };
        if(b.size != n) { b = st[\etPhase].copy; };
        vals = Array.fill(n, { |i| (at[\wrapSigned].((a[i] ? 0.0) - (b[i] ? 0.0)) * 1200.0).abs });
        if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 }
    };

    at[\globalMotionGateTargetFromPhase] = { |phase=nil|
        var n, ph, devs, sorted, idx, gauge, shape;
        n = cfg[\solver][\numNodes] ? 12;
        ph = phase ? (st[\targetPhase] ? st[\nodePhase] ? st[\etPhase]);
        if(ph.size != n) { ph = st[\etPhase].copy; };
        devs = Array.fill(n, { |i| at[\wrapSigned].((ph[i] ? st[\etPhase][i]) - st[\etPhase][i]) * 1200.0 });
        sorted = devs.copy.sort;
        idx = (sorted.size / 2).floor.clip(0, sorted.size - 1);
        gauge = if(sorted.isEmpty) { 0.0 } { sorted[idx] ? 0.0 };
        shape = devs.collect { |x| (x ? 0.0) - gauge };
        (gaugeCents: gauge, shapeCents: shape, devsCents: devs)
    };

    at[\globalMotionGateRealizedPhase] = {
        var n, gauge, shape;
        at[\globalMotionGateEnsureState].();
        n = cfg[\solver][\numNodes] ? 12;
        gauge = st[\globalMotionRealizedGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0);
        shape = st[\globalMotionRealizedNodeShapeCents] ? (st[\nodeShapeCents] ? Array.fill(n, 0.0));
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        at[\globalMotionGateTargetPhaseFromGaugeShape].(gauge, shape)
    };

    at[\globalMotionGateCaptureTargetPhaseIfNeeded] = { |reason=\targetPhaseBarrier|
        var n, targetPhase, realizedPhase, diff, converted, report, oldCompose;
        n = cfg[\solver][\numNodes] ? 12;
        targetPhase = st[\targetPhase];
        if(targetPhase.isNil or: { targetPhase.size != n }) {
            nil
        } {
            realizedPhase = at[\globalMotionGateRealizedPhase].();
            diff = at[\globalMotionGateMaxPhaseDiffCents].(targetPhase, realizedPhase);
            if(diff <= ((cfg[\solver][\globalMotionRateGateEpsilon] ? 0.000001) * 1200.0).max(0.001)) {
                nil
            } {
                converted = at[\globalMotionGateTargetFromPhase].(targetPhase);
                report = at[\globalMotionGateRealize].(converted[\gaugeCents] ? 0.0, converted[\shapeCents] ? Array.fill(n, 0.0), reason);
                oldCompose = at[\globalMotionOriginalFieldComposeFromShapeGauge];
                if(oldCompose.notNil) { oldCompose.value; } { at[\globalMotionGateComposeCurrent].(); };
                st[\lastGlobalMotionTargetPhaseCapture] = (timestamp: Main.elapsedTime, reason: reason, targetPhaseDiffCents: diff, gaugeCents: converted[\gaugeCents], shapeSpanCents: at[\globalMotionGateShapeSpan].(converted[\shapeCents]), report: report);
                report
            }
        }
    };

    at[\globalMotionGateRealize] = { |targetGauge=0.0, targetShape=nil, reason=\manual|
        var n, motion, eps, enabled, bypass, currentGauge, currentShape, realizedGauge, realizedShape, deltaShape;
        var targetErr, maxMove, now;
        at[\globalMotionGateEnsureState].();
        n = cfg[\solver][\numNodes] ? 12;
        now = Main.elapsedTime;
        targetGauge = (targetGauge ? 0.0).asFloat;
        targetShape = targetShape ? Array.fill(n, 0.0);
        if(targetShape.size != n) { targetShape = Array.fill(n, 0.0); };
        motion = at[\globalMotionGateAmount].();
        eps = cfg[\solver][\globalMotionRateGateEpsilon] ? 0.000001;
        enabled = cfg[\solver][\globalMotionRateGateEnabled] ? true;
        bypass = (st[\globalMotionRateGateBypass] ? false) or: { enabled == false };
        currentGauge = st[\globalMotionRealizedGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0);
        currentShape = st[\globalMotionRealizedNodeShapeCents] ? (st[\nodeShapeCents] ? Array.fill(n, 0.0));
        if(currentShape.size != n) { currentShape = Array.fill(n, 0.0); };
        if(bypass or: { motion >= (1.0 - eps) }) {
            realizedGauge = targetGauge;
            realizedShape = targetShape.copy;
        } {
            if(motion <= eps) {
                realizedGauge = currentGauge;
                realizedShape = currentShape.copy;
            } {
                realizedGauge = currentGauge + ((targetGauge - currentGauge) * motion);
                realizedShape = Array.fill(n, { |i|
                    (currentShape[i] ? 0.0) + (((targetShape[i] ? 0.0) - (currentShape[i] ? 0.0)) * motion)
                });
            };
        };
        deltaShape = Array.fill(n, { |i| (realizedShape[i] ? 0.0) - (currentShape[i] ? 0.0) });
        maxMove = (deltaShape.collect { |x| x.abs }.maxItem ? 0.0).max((realizedGauge - currentGauge).abs);
        targetErr = at[\globalMotionGateMaxAbsDiff].(targetShape, realizedShape).max((targetGauge - realizedGauge).abs);
        st[\globalMotionTargetGaugeCents] = targetGauge;
        st[\globalMotionTargetNodeShapeCents] = targetShape.copy;
        st[\globalMotionRealizedGaugeCents] = realizedGauge;
        st[\globalMotionRealizedNodeShapeCents] = realizedShape.copy;
        st[\targetNodeShapeCents] = targetShape.copy;
        st[\targetPhase] = at[\globalMotionGateTargetPhaseFromGaugeShape].(targetGauge, targetShape);
        st[\targetValid] = targetErr > eps;
        st[\motionActive] = targetErr > eps;
        st[\fieldTrueGaugeVelocityCents] = realizedGauge - currentGauge;
        st[\fieldTrueGaugeCents] = realizedGauge;
        st[\fieldGaugeCents] = realizedGauge;
        st[\nodeShapeCents] = realizedShape.copy;
        st[\nodeShapeVelocityCents] = deltaShape.copy;
        st[\lastGlobalMotionRateGateReport] = (
            timestamp: now, reason: reason, enabled: enabled, bypass: bypass, motion: motion,
            targetGaugeCents: targetGauge, realizedGaugeCents: realizedGauge,
            targetShapeSpanCents: at[\globalMotionGateShapeSpan].(targetShape),
            realizedShapeSpanCents: at[\globalMotionGateShapeSpan].(realizedShape),
            maxRealizedMoveCents: maxMove, maxTargetErrorCents: targetErr,
            targetChangedButCurrentFrozen: (motion <= eps) and: { targetErr > eps } and: { maxMove <= eps },
            rule: \targetCalculationImmediateRealizedMovementMotionGated
        );
        st[\lastGlobalMotionRateGateReport]
    };

    at[\globalMotionGateRealizeStoredTarget] = { |reason=\storedTarget|
        var n, targetGauge, targetShape, oldCompose, report;
        at[\globalMotionGateEnsureState].();
        n = cfg[\solver][\numNodes] ? 12;
        targetGauge = st[\globalMotionTargetGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0);
        targetShape = st[\globalMotionTargetNodeShapeCents] ? (st[\targetNodeShapeCents] ? (st[\nodeShapeCents] ? Array.fill(n, 0.0)));
        if(targetShape.size != n) { targetShape = Array.fill(n, 0.0); };
        oldCompose = at[\globalMotionOriginalFieldComposeFromShapeGauge];
        report = at[\globalMotionGateRealize].(targetGauge, targetShape, reason);
        if(oldCompose.notNil) { oldCompose.value; } { at[\globalMotionGateComposeCurrent].(); };
        report
    };

    at[\globalMotionGateCaptureCurrentAsRealized] = { |reason=\captureCurrent|
        var n, shape, gauge;
        at[\globalMotionGateEnsureState].();
        n = cfg[\solver][\numNodes] ? 12;
        gauge = st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0);
        shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        st[\globalMotionRealizedGaugeCents] = gauge;
        st[\globalMotionRealizedNodeShapeCents] = shape.copy;
        st[\globalMotionTargetGaugeCents] = st[\globalMotionTargetGaugeCents] ? gauge;
        st[\globalMotionTargetNodeShapeCents] = st[\globalMotionTargetNodeShapeCents] ? shape.copy;
        (reason: reason, realizedGaugeCents: gauge, realizedShapeSpanCents: at[\globalMotionGateShapeSpan].(shape))
    };

    if(at[\globalMotionOriginalFieldComposeFromShapeGauge].isNil and: { at[\fieldComposeFromShapeGauge].notNil }) {
        at[\globalMotionOriginalFieldComposeFromShapeGauge] = at[\fieldComposeFromShapeGauge];
    };

    at[\globalMotionGateComposeCurrentOnly] = { |reason=\currentOnlyCompose|
        var oldCompose;
        oldCompose = at[\globalMotionOriginalFieldComposeFromShapeGauge];
        if(oldCompose.notNil) { oldCompose.value; } { at[\globalMotionGateComposeCurrent].(); };
        st[\lastGlobalMotionCurrentOnlyCompose] = (timestamp: Main.elapsedTime, reason: reason);
        st[\nodePhase]
    };

    at[\fieldComposeFromShapeGauge] = {
        var n, targetGauge, targetShape, oldCompose, report, currentOnly;
        n = cfg[\solver][\numNodes] ? 12;
        oldCompose = at[\globalMotionOriginalFieldComposeFromShapeGauge];
        currentOnly = st[\globalMotionCurrentOnlyCompose] ? false;
        if(currentOnly == true) {
            report = at[\globalMotionGateComposeCurrentOnly].(\fieldComposeCurrentOnly);
        } {
            targetGauge = st[\fieldTrueGaugeCents] ? 0.0;
            targetShape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
            if(targetShape.size != n) { targetShape = Array.fill(n, 0.0); };
            report = at[\globalMotionGateRealize].(targetGauge, targetShape, \fieldCompose);
            if(oldCompose.notNil) { oldCompose.value; };
        };
        report
    };

    if(at[\globalMotionOriginalFieldReset].isNil and: { at[\fieldReset].notNil }) {
        at[\globalMotionOriginalFieldReset] = at[\fieldReset];
        at[\fieldReset] = {
            var n, oldReset, oldBypass;
            n = cfg[\solver][\numNodes] ? 12;
            oldReset = at[\globalMotionOriginalFieldReset];
            oldBypass = st[\globalMotionRateGateBypass] ? false;
            st[\globalMotionRateGateBypass] = true;
            if(oldReset.notNil) { oldReset.value; };
            st[\globalMotionRealizedGaugeCents] = 0.0;
            st[\globalMotionTargetGaugeCents] = 0.0;
            st[\globalMotionRealizedNodeShapeCents] = Array.fill(n, 0.0);
            st[\globalMotionTargetNodeShapeCents] = Array.fill(n, 0.0);
            st[\targetNodeShapeCents] = Array.fill(n, 0.0);
            st[\targetPhase] = st[\etPhase].copy;
            st[\motionActive] = false;
            st[\targetValid] = false;
            st[\lastGlobalMotionRateGateReport] = (
                timestamp: Main.elapsedTime, reason: \fieldReset, motion: at[\globalMotionGateAmount].(),
                targetGaugeCents: 0.0, realizedGaugeCents: 0.0, targetShapeSpanCents: 0.0,
                realizedShapeSpanCents: 0.0, maxRealizedMoveCents: 0.0, maxTargetErrorCents: 0.0,
                bypass: true
            );
            st[\globalMotionRateGateBypass] = oldBypass;
            nil
        };
    };

    // v2k: administrative reset must clear the global Motion target/current state too.
    // The audible timbre audition can legitimately move the musical world; later
    // proof commands must still be independent. resetToET/field reset now restore
    // realized gauge, realized shape, target gauge, target shape, node phase, and
    // bus-visible current field to the same clean ET baseline.
    at[\globalMotionGateForceState] = { |gauge=0.0, shape=nil, reason=\adminForceState|
        var n, oldBypass, oldCompose, phase;
        n = cfg[\solver][\numNodes] ? 12;
        gauge = (gauge ? 0.0).asFloat;
        shape = shape ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        oldBypass = st[\globalMotionRateGateBypass] ? false;
        st[\globalMotionRateGateBypass] = true;
        phase = at[\globalMotionGateTargetPhaseFromGaugeShape].(gauge, shape);
        st[\globalMotionRealizedGaugeCents] = gauge;
        st[\globalMotionTargetGaugeCents] = gauge;
        st[\globalMotionRealizedNodeShapeCents] = shape.copy;
        st[\globalMotionTargetNodeShapeCents] = shape.copy;
        st[\fieldTrueGaugeCents] = gauge;
        st[\fieldGaugeCents] = gauge;
        st[\fieldTrueGaugeVelocityCents] = 0.0;
        st[\nodeShapeCents] = shape.copy;
        st[\targetNodeShapeCents] = shape.copy;
        st[\nodeShapeVelocityCents] = Array.fill(n, 0.0);
        st[\nodePhase] = phase.copy;
        st[\targetPhase] = phase.copy;
        st[\lastSolvedPhase] = phase.copy;
        st[\coreUnwrappedPhase] = phase.copy;
        st[\targetCoreUnwrappedPhase] = phase.copy;
        st[\targetValid] = false;
        st[\motionActive] = false;
        st[\lastGlobalMotionRateGateReport] = (
            timestamp: Main.elapsedTime, reason: reason, enabled: cfg[\solver][\globalMotionRateGateEnabled] ? true,
            bypass: true, motion: at[\globalMotionGateAmount].(), targetGaugeCents: gauge,
            realizedGaugeCents: gauge, targetShapeSpanCents: at[\globalMotionGateShapeSpan].(shape),
            realizedShapeSpanCents: at[\globalMotionGateShapeSpan].(shape), maxRealizedMoveCents: 0.0,
            maxTargetErrorCents: 0.0, targetChangedButCurrentFrozen: false,
            rule: \adminResetAlsoClearsGlobalMotionTargetCurrent
        );
        oldCompose = at[\globalMotionOriginalFieldComposeFromShapeGauge];
        if(oldCompose.notNil) { oldCompose.value; } { at[\globalMotionGateComposeCurrent].(); };
        if(at[\clearDescriptors].notNil) { at[\clearDescriptors].(); };
        if(at[\pushBuses].notNil and: { st[\globalMotionPushBusesInProgress] != true }) { at[\pushBuses].(); };
        st[\globalMotionRateGateBypass] = oldBypass;
        st[\lastGlobalMotionRateGateReport]
    };

    if(at[\globalMotionOriginalResetToET].isNil and: { at[\resetToET].notNil }) {
        at[\globalMotionOriginalResetToET] = at[\resetToET];
        at[\resetToET] = {
            var oldReset, n;
            n = cfg[\solver][\numNodes] ? 12;
            oldReset = at[\globalMotionOriginalResetToET];
            if(oldReset.notNil) { oldReset.value; };
            at[\globalMotionGateForceState].(0.0, Array.fill(n, 0.0), \resetToETGlobalMotionState);
        };
    };

    if(at[\globalMotionOriginalPushBuses].isNil and: { at[\pushBuses].notNil }) {
        at[\globalMotionOriginalPushBuses] = at[\pushBuses];
    };

    at[\pushBuses] = {
        var oldPush, oldFlag, oldCurrentOnly;
        oldPush = at[\globalMotionOriginalPushBuses];
        oldFlag = st[\globalMotionPushBusesInProgress] ? false;
        if(oldFlag == true) {
            if(oldPush.notNil) { oldPush.value; };
        } {
            st[\globalMotionPushBusesInProgress] = true;
            if(at[\globalMotionGateCaptureTargetPhaseIfNeeded].notNil) { at[\globalMotionGateCaptureTargetPhaseIfNeeded].(\pushBusesTargetPhase); };
            oldCurrentOnly = st[\globalMotionCurrentOnlyCompose] ? false;
            st[\globalMotionCurrentOnlyCompose] = true;
            if(at[\fieldWriteBarrier].notNil) {
                at[\fieldWriteBarrier].(\pushBuses);
            } {
                if(at[\globalMotionGateComposeCurrentOnly].notNil) { at[\globalMotionGateComposeCurrentOnly].(\pushBusesNoBarrier); } {
                    if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].(); } {
                        at[\globalMotionGateRealizeStoredTarget].(\pushBusesNoCompose);
                    };
                };
            };
            st[\globalMotionCurrentOnlyCompose] = oldCurrentOnly;
            if(oldPush.notNil) { oldPush.value; };
            st[\globalMotionPushBusesInProgress] = oldFlag;
        };
        nil
    };

    if(at[\globalMotionOriginalFieldMobilityScale].isNil and: { at[\fieldMobilityScale].notNil }) {
        at[\globalMotionOriginalFieldMobilityScale] = at[\fieldMobilityScale];
    };

    // v2: Motion is the actuator/global realized-rate gate, not hidden target-law inhibition.
    // Target calculation must still know where it wants to go when Motion is zero.
    at[\fieldMobilityScale] = { 1.0 };

    at[\globalMotionGateCommitTarget] = { |gauge=0.0, shape=nil, reason=\manualTarget|
        var n;
        n = cfg[\solver][\numNodes] ? 12;
        shape = shape ? Array.fill(n, 0.0);
        if(shape.size != n) { shape = Array.fill(n, 0.0); };
        st[\fieldTrueGaugeCents] = gauge ? 0.0;
        st[\fieldGaugeCents] = gauge ? 0.0;
        st[\nodeShapeCents] = shape.copy;
        st[\targetNodeShapeCents] = shape.copy;
        if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].(); };
        st[\lastGlobalMotionRateGateReport][\reason] = reason;
        st[\lastGlobalMotionRateGateReport]
    };

    api[\globalMotionRateGateSnapshot] = { |label=\snapshot|
        var n, realized, target, err;
        at[\globalMotionGateEnsureState].();
        n = cfg[\solver][\numNodes] ? 12;
        realized = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        target = st[\targetNodeShapeCents] ? realized;
        err = at[\globalMotionGateMaxAbsDiff].(target, realized).max(((st[\globalMotionTargetGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0)) - (st[\fieldTrueGaugeCents] ? 0.0)).abs);
        (
            label: label,
            movement: at[\globalMotionGateAmount].(),
            gaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
            targetGaugeCents: st[\globalMotionTargetGaugeCents] ? (st[\fieldTrueGaugeCents] ? 0.0),
            shapeSpanCents: at[\globalMotionGateShapeSpan].(realized),
            targetShapeSpanCents: at[\globalMotionGateShapeSpan].(target),
            maxTargetErrorCents: err,
            report: st[\lastGlobalMotionRateGateReport]
        )
    };


    at[\globalMotionGateSnapshot] = { |label=\snapshot| api[\globalMotionRateGateSnapshot].(label) };

    "[at-global-motion] clean global live-authority realized-movement-rate gate loaded.".postln;
};
)
