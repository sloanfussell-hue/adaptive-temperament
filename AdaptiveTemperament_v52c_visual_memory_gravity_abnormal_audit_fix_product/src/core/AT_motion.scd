(
// AT_motion.scd
// v3D42 motion-rate gate. The solver writes targetPhase; this layer is the only
// normal path that lets the audible/current field move toward that target.
// Motion changes rate only: it never changes which harmonic world is chosen.
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

    at[\setTargetPhase] = { |target, reason=\solve|
        st[\targetPhase] = (target ? st[\nodePhase]).copy;
        st[\targetCoreUnwrappedPhase] = st[\targetPhase].copy;
        st[\lastSolvedPhase] = st[\targetPhase].copy;
        st[\targetValid] = true;
        st[\motionActive] = true;
        st[\targetReason] = reason;
        st[\targetSetAt] = Main.elapsedTime;
    };

    at[\motionAmount] = {
        (st[\movement] ? 1.0).clip(0.0, 1.0)
    };

    at[\motionTargetDistanceCents] = { |target=nil|
        var t, maxRemain;
        t = target ? st[\targetPhase] ? st[\nodePhase] ? st[\etPhase];
        maxRemain = 0.0;
        cfg[\solver][\numNodes].do { |i|
            maxRemain = maxRemain.max(at[\wrapSigned].((t[i] ? 0.0) - ((st[\nodePhase] ? st[\etPhase])[i] ? 0.0)).abs);
        };
        maxRemain * 1200.0;
    };

    api[\motionRateGatePlan] = {
        (
            branch: \v3D42_motion_rate_gate_final_product,
            role: \globalCurrentToTargetRateGate,
            motionZero: "target may update, current audible/visible field must not move",
            motionOne: "fastest safe current-to-target motion",
            affects: [\activeVoices, \passiveNodes, \singleOrigin, \dyadLock, \polyChart, \memory, \gravity, \ear, \spectrum, \fastPathCommits],
            choosesHarmony: false,
            pitchAuthorityAdded: false,
            topologyAuthorityAdded: false,
            spacingThresholdChange: false
        )
    };

    api[\motionRateGateReport] = { |post=true|
        var rep;
        rep = st[\lastMotionGateReport] ? (
            branch: \v3D42_motion_rate_gate_final_product,
            noMotionStepYet: true,
            motionAmount: at[\motionAmount].(),
            targetDistanceCents: at[\motionTargetDistanceCents].(),
            motionActive: st[\motionActive] ? false,
            pitchAuthorityAdded: false
        );
        if(post) {
            "".postln;
            "[AT MOTION RATE GATE REPORT]".postln;
            rep.postln;
        };
        rep;
    };

    api[\runMotionRateGateProof] = { |post=true|
        var saveMovement, savePhase, saveU, saveTarget, saveTargetU, saveLastSolved, saveMotionActive, saveTargetValid;
        var before, target, zeroRep, oneRep, maxIter, i, dist, moved;
        saveMovement = st[\movement];
        savePhase = st[\nodePhase].copy;
        saveU = (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy;
        saveTarget = if(st[\targetPhase].notNil) { st[\targetPhase].copy } { nil };
        saveTargetU = if(st[\targetCoreUnwrappedPhase].notNil) { st[\targetCoreUnwrappedPhase].copy } { nil };
        saveLastSolved = if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase].copy } { nil };
        saveMotionActive = st[\motionActive];
        saveTargetValid = st[\targetValid];

        before = st[\nodePhase].copy;
        target = before.copy;
        target[0] = at[\wrap01].(target[0] + (24.0 / 1200.0));

        st[\movement] = 0.0;
        at[\setTargetPhase].(target, \motionRateGateProofZero);
        at[\motionStepToTarget].(false);
        zeroRep = (
            targetKnown: st[\targetPhase].notNil,
            targetDistanceCents: 24.0,
            currentMaxMoveCents: (Array.fill(cfg[\solver][\numNodes], { |j| at[\wrapSigned].(st[\nodePhase][j] - before[j]).abs * 1200.0 }).maxItem ? 0.0).round(0.001),
            newNoteSpawnAtCurrentField: ((Array.fill(cfg[\solver][\numNodes], { |j| at[\wrapSigned].(st[\nodePhase][j] - before[j]).abs * 1200.0 }).maxItem ? 0.0) <= 0.001),
            pitchAuthorityAdded: false
        );

        st[\movement] = 1.0;
        maxIter = 96;
        i = 0;
        while { (i < maxIter) and: { (at[\motionTargetDistanceCents].(target) > 0.02) } } {
            at[\motionStepToTarget].(false);
            i = i + 1;
        };
        dist = at[\motionTargetDistanceCents].(target);
        moved = Array.fill(cfg[\solver][\numNodes], { |j| at[\wrapSigned].(st[\nodePhase][j] - before[j]).abs * 1200.0 }).maxItem ? 0.0;
        oneRep = (
            targetKnown: st[\targetPhase].notNil,
            movedCents: moved.round(0.001),
            remainingCents: dist.round(0.001),
            reachedTarget: dist <= 0.02,
            steps: i,
            pitchAuthorityAdded: false
        );

        st[\movement] = saveMovement;
        st[\nodePhase] = savePhase.copy;
        st[\coreUnwrappedPhase] = saveU.copy;
        st[\targetPhase] = if(saveTarget.notNil) { saveTarget.copy } { nil };
        st[\targetCoreUnwrappedPhase] = if(saveTargetU.notNil) { saveTargetU.copy } { nil };
        st[\lastSolvedPhase] = if(saveLastSolved.notNil) { saveLastSolved.copy } { nil };
        st[\motionActive] = saveMotionActive;
        st[\targetValid] = saveTargetValid;
        if(at[\pushBuses].notNil) { at[\pushBuses].(); };

        if(post) {
            "".postln;
            "[AT MOTION SLEW ZERO]".postln;
            zeroRep.postln;
            "[AT MOTION SLEW ONE]".postln;
            oneRep.postln;
        };
        (branch: \v3D42_motion_rate_gate_final_product, zero: zeroRep, one: oneRep)
    };

    at[\snapCurrentToTarget] = { |reason=\snap|
        if(st[\targetPhase].notNil) {
            st[\nodePhase] = st[\targetPhase].copy;
            st[\coreUnwrappedPhase] = (st[\targetCoreUnwrappedPhase] ? st[\targetPhase]).copy;
            st[\motionActive] = false;
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

        // Authority inhibition does not create the core. It slows the current
        // world when earned/intentional stabilizers are strong. Movement/carry
        // remain conceptually separate exceptions.
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

    at[\motionStepToTarget] = { |force=false|
        var target, targetU, deltas, maxRemain, eps, changed, shouldSnap, result, beforePhase, beforeUnwrapped, guardOut, motionAmount, currentMaxMove;
        target = st[\targetPhase] ? st[\nodePhase];
        targetU = st[\targetCoreUnwrappedPhase] ? target;
        beforePhase = (st[\nodePhase] ? target).copy;
        beforeUnwrapped = (st[\coreUnwrappedPhase] ? beforePhase).copy;
        eps = ((cfg[\motion][\settleEpsilonCents] ? 0.015) / 1200.0).max(0.0);
        deltas = Array.fill(cfg[\solver][\numNodes], 0.0);
        maxRemain = 0.0;
        changed = false;
        shouldSnap = ((cfg[\motion][\enabled] ? true).not) or: { force == true };
        motionAmount = at[\motionAmount].();
        currentMaxMove = 0.0;

        if(shouldSnap) {
            if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                guardOut = at[\applyPitchIdentityFieldCommitGuard].(target.copy, targetU.copy, \motionSnap, beforePhase, beforeUnwrapped);
                target = guardOut[\phase] ? target;
                targetU = guardOut[\unwrapped] ? targetU;
            };
            st[\coreUnwrappedPhase] = targetU.copy;
            st[\nodePhase] = target.copy;
            st[\motionActive] = false;
            st[\lastDelta] = deltas;
            st[\nodeMotion] = deltas.collect { 0.0 };
            st[\lastMotionGateReport] = (
                branch: \v3D42_motion_rate_gate_final_product,
                reason: \motionSnap,
                force: force,
                motionAmount: motionAmount,
                targetKnown: true,
                targetDistanceCents: 0.0,
                currentMaxMoveCents: at[\motionTargetDistanceCents].(target).round(0.001),
                blockedByMotionZero: false,
                pitchAuthorityAdded: false
            );
            at[\pushBuses].();
            result = false;
        } {
            if(motionAmount <= 0.000001) {
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
                st[\motionActive] = maxRemain > eps;
                st[\lastMotionGateReport] = (
                    branch: \v3D42_motion_rate_gate_final_product,
                    reason: \motionZeroGate,
                    force: force,
                    motionAmount: motionAmount,
                    targetKnown: true,
                    targetDistanceCents: (maxRemain * 1200.0).round(0.001),
                    currentMaxMoveCents: 0.0,
                    blockedByMotionZero: true,
                    pitchAuthorityAdded: false
                );
                at[\pushBuses].();
                result = false;
            } {
            cfg[\solver][\numNodes].do { |i|
                var diff, limit, step;
                diff = at[\wrapSigned].(target[i] - st[\nodePhase][i]);
                maxRemain = maxRemain.max(diff.abs);
                limit = at[\motionLimitForPc].(i).abs;
                step = if(limit <= 0.000000001) { 0.0 } { diff.clip(limit.neg, limit) };
                currentMaxMove = currentMaxMove.max(step.abs);
                deltas[i] = step;
                if(step.abs > 0.00000001) { changed = true; };
                if(st[\coreUnwrappedPhase].isNil or: { st[\coreUnwrappedPhase].size != cfg[\solver][\numNodes] }) { st[\coreUnwrappedPhase] = st[\nodePhase].copy; };
                st[\coreUnwrappedPhase][i] = (st[\coreUnwrappedPhase][i] ? st[\nodePhase][i]) + step;
                st[\nodePhase][i] = at[\wrap01].(st[\nodePhase][i] + step);
                st[\nodeMotion][i] = if(limit <= 0.000000001) { 0.0 } { (step.abs / limit).clip(0.0, 1.0) };
            };

            st[\lastDelta] = deltas;
            st[\lastSolveTotalMotion] = Array.fill(cfg[\solver][\numNodes], { |i|
                at[\wrapSigned].(target[i] - st[\nodePhase][i]).abs
            });

            if(maxRemain <= eps) {
                if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                    guardOut = at[\applyPitchIdentityFieldCommitGuard].(target.copy, targetU.copy, \motionSettle, beforePhase, beforeUnwrapped);
                    target = guardOut[\phase] ? target;
                    targetU = guardOut[\unwrapped] ? targetU;
                };
                st[\coreUnwrappedPhase] = targetU.copy;
                st[\nodePhase] = target.copy;
                st[\motionActive] = false;
            } {
                if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                    guardOut = at[\applyPitchIdentityFieldCommitGuard].(st[\nodePhase].copy, st[\coreUnwrappedPhase].copy, \motionStep, beforePhase, beforeUnwrapped);
                    st[\nodePhase] = (guardOut[\phase] ? st[\nodePhase]).copy;
                    st[\coreUnwrappedPhase] = (guardOut[\unwrapped] ? st[\coreUnwrappedPhase]).copy;
                };
                st[\motionActive] = true;
            };

            st[\lastMotionGateReport] = (
                branch: \v3D42_motion_rate_gate_final_product,
                reason: \motionStep,
                force: force,
                motionAmount: motionAmount,
                targetKnown: true,
                targetDistanceCents: ((st[\lastSolveTotalMotion].collect { |x| x.abs }.maxItem ? 0.0) * 1200.0).round(0.001),
                currentMaxMoveCents: (currentMaxMove * 1200.0).round(0.001),
                blockedByMotionZero: false,
                pitchAuthorityAdded: false
            );
            at[\pushBuses].();
            result = changed;
            };
        };
        result;
    };

    "[at-motion] v3D42 global motion-rate gate loaded".postln;
};
)
