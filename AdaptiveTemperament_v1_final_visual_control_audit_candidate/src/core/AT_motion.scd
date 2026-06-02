(
// AT_motion.scd
// Authoritative current→target motion layer. Target calculation may be immediate;
// Movement/Motion gates how much the audible/visible current field is allowed to
// travel toward that target.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;
if(build.isNil) {
    "[at-motion] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    at[\motionAmount] = {
        (st[\movement] ? 1.0).clip(0.0, 1.0);
    };

    at[\motionTargetDistance] = { |target=nil|
        var t, n, maxDist;
        t = target ? st[\targetPhase] ? st[\nodePhase];
        n = st[\nodePhase] ? st[\etPhase];
        maxDist = 0.0;
        cfg[\solver][\numNodes].do { |i|
            maxDist = maxDist.max(at[\wrapSigned].((t[i] ? n[i]) - (n[i] ? 0.0)).abs);
        };
        maxDist;
    };

    at[\setTargetPhase] = { |target, reason=\solve|
        var dist, eps, move;
        st[\targetPhase] = (target ? st[\nodePhase]).copy;
        st[\targetCoreUnwrappedPhase] = st[\targetPhase].copy;
        st[\lastSolvedPhase] = st[\targetPhase].copy;
        st[\targetValid] = true;
        st[\targetReason] = reason;
        st[\targetSetAt] = Main.elapsedTime;
        eps = ((cfg[\motion][\settleEpsilonCents] ? 0.015) / 1200.0).max(0.0);
        dist = at[\motionTargetDistance].(st[\targetPhase]);
        move = at[\motionAmount].();
        st[\motionActive] = (dist > eps) and: { move > 0.0 };
        st[\motionFrozenByMovement] = (dist > eps) and: { move <= 0.0 };
    };

    at[\snapCurrentToTarget] = { |reason=\snap|
        if(st[\targetPhase].notNil) {
            st[\nodePhase] = st[\targetPhase].copy;
            st[\coreUnwrappedPhase] = (st[\targetCoreUnwrappedPhase] ? st[\targetPhase]).copy;
            st[\motionActive] = false;
            st[\motionFrozenByMovement] = false;
            st[\lastDelta] = Array.fill(cfg[\solver][\numNodes], 0.0);
            st[\nodeMotion] = Array.fill(cfg[\solver][\numNodes], 0.0);
            at[\pushBuses].();
        };
    };

    at[\motionLimitForPc] = { |pc|
        var activePcs, active, age, held, fresh, passive, interp, limit, auth, acfg, inhibit, depth, minFreedom;
        activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
        active = activePcs.includes(pc);
        age = at[\heldAgeForPc].(pc);
        held = cfg[\motion][\heldMaxCentsPerTick] ? 1.15;
        fresh = cfg[\motion][\freshMaxCentsPerTick] ? 7.0;
        passive = cfg[\motion][\passiveMaxCentsPerTick] ? 5.5;
        if(active) {
            interp = (age / (cfg[\motion][\heldAgeThreshold] ? 0.65)).clip(0.0, 1.0);
            limit = (fresh + ((held - fresh) * interp)) / 1200.0;
        } {
            limit = passive / 1200.0;
        };

        if(at[\coreAuthoritySnapshot].notNil) {
            auth = at[\coreAuthoritySnapshot].();
            acfg = cfg[\authority] ? ();
            inhibit = (auth[\inhibition] ? 0.0).clip(0.0, 1.0);
            depth = (acfg[\motionLimitInhibitionDepth] ? 0.86).clip(0.0, 0.98);
            minFreedom = (acfg[\minMotionFreedom] ? 0.04).clip(0.01, 1.0);
            limit = limit * (1.0 - (inhibit * depth)).max(minFreedom);
        };
        limit = limit * at[\motionAmount].();
        limit;
    };

    at[\nudgeMotionAfterMovementChange] = { |reason=\movementChange|
        var move, dist, eps;
        move = at[\motionAmount].();
        eps = ((cfg[\motion][\settleEpsilonCents] ? 0.015) / 1200.0).max(0.0);
        dist = at[\motionTargetDistance].(st[\targetPhase]);
        st[\motionActive] = (dist > eps) and: { move > 0.0 };
        st[\motionFrozenByMovement] = (dist > eps) and: { move <= 0.0 };
        if(move > 0.0 and: { dist > eps }) {
            if(move >= 0.999) { at[\motionStepToTarget].(true); } { at[\motionStepToTarget].(false); };
        } {
            at[\pushBuses].();
        };
    };

    at[\motionStepToTarget] = { |force=false|
        var target, targetU, deltas, maxRemain, eps, changed, shouldSnap, result, move;
        target = st[\targetPhase] ? st[\nodePhase];
        targetU = st[\targetCoreUnwrappedPhase] ? target;
        eps = ((cfg[\motion][\settleEpsilonCents] ? 0.015) / 1200.0).max(0.0);
        deltas = Array.fill(cfg[\solver][\numNodes], 0.0);
        maxRemain = 0.0;
        changed = false;
        move = at[\motionAmount].();
        shouldSnap = ((cfg[\motion][\enabled] ? true).not) or: { force == true };

        if((move <= 0.0) and: { force != true }) {
            cfg[\solver][\numNodes].do { |i|
                var diff;
                diff = at[\wrapSigned].(target[i] - st[\nodePhase][i]);
                maxRemain = maxRemain.max(diff.abs);
            };
            st[\lastDelta] = deltas;
            st[\nodeMotion] = deltas.collect { 0.0 };
            st[\lastSolveTotalMotion] = Array.fill(cfg[\solver][\numNodes], { |i|
                at[\wrapSigned].(target[i] - st[\nodePhase][i]).abs
            });
            st[\motionActive] = false;
            st[\motionFrozenByMovement] = maxRemain > eps;
            at[\pushBuses].();
            result = false;
        } {
            if(shouldSnap) {
                st[\coreUnwrappedPhase] = targetU.copy;
                st[\nodePhase] = target.copy;
                st[\motionActive] = false;
                st[\motionFrozenByMovement] = false;
                st[\lastDelta] = deltas;
                st[\nodeMotion] = deltas.collect { 0.0 };
                at[\pushBuses].();
                result = false;
            } {
                cfg[\solver][\numNodes].do { |i|
                    var diff, limit, step;
                    diff = at[\wrapSigned].(target[i] - st[\nodePhase][i]);
                    maxRemain = maxRemain.max(diff.abs);
                    limit = at[\motionLimitForPc].(i).abs;
                    step = if(limit <= 0.0) { 0.0 } { diff.clip(limit.neg, limit) };
                    deltas[i] = step;
                    if(step.abs > 0.00000001) { changed = true; };
                    if(st[\coreUnwrappedPhase].isNil or: { st[\coreUnwrappedPhase].size != cfg[\solver][\numNodes] }) {
                        st[\coreUnwrappedPhase] = st[\nodePhase].copy;
                    };
                    st[\coreUnwrappedPhase][i] = (st[\coreUnwrappedPhase][i] ? st[\nodePhase][i]) + step;
                    st[\nodePhase][i] = at[\wrap01].(st[\nodePhase][i] + step);
                    st[\nodeMotion][i] = if(limit <= 0.0) { 0.0 } { (step.abs / limit).clip(0.0, 1.0) };
                };

                st[\lastDelta] = deltas;
                st[\lastSolveTotalMotion] = Array.fill(cfg[\solver][\numNodes], { |i|
                    at[\wrapSigned].(target[i] - st[\nodePhase][i]).abs
                });

                if(maxRemain <= eps) {
                    st[\coreUnwrappedPhase] = targetU.copy;
                    st[\nodePhase] = target.copy;
                    st[\motionActive] = false;
                    st[\motionFrozenByMovement] = false;
                } {
                    st[\motionActive] = true;
                    st[\motionFrozenByMovement] = false;
                };

                at[\pushBuses].();
                result = changed;
            };
        };
        result;
    };

    api[\motionSlewGateReport] = {
        var dist, move, rep;
        dist = at[\motionTargetDistance].(st[\targetPhase]) * 1200.0;
        move = at[\motionAmount].();
        rep = (
            version: \v64b_movementMotionGlobalSlewGate,
            movement: move,
            targetKnown: st[\targetPhase].notNil,
            targetDistanceCents: dist.round(0.001),
            motionActive: st[\motionActive] ? false,
            motionFrozenByMovement: st[\motionFrozenByMovement] ? false,
            currentMovesAtZero: false,
            pitchAuthorityAdded: false
        );
        ("[AT MOTION SLEW REPORT] movement=" ++ move.round(0.001).asString
            ++ " targetKnown=" ++ rep[\targetKnown].asString
            ++ " targetDistanceCents=" ++ rep[\targetDistanceCents].asString
            ++ " motionActive=" ++ rep[\motionActive].asString
            ++ " motionFrozenByMovement=" ++ rep[\motionFrozenByMovement].asString
            ++ " pitchAuthorityAdded=false").postln;
        rep;
    };



    "[at-motion] v64b global Movement/Motion slew gate loaded".postln;
};
)
