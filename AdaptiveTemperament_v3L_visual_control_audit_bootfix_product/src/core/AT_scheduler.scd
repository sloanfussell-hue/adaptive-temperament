(
// AT_scheduler.scd
// v2d: live Motion proof guard; background field service sanitizes force arrays before projection.
// v29c live fast-settle pump / non-starving bounded recent-input shape service.
// This keeps r15m/r15q musical law: unbounded coherent transport, no cent caps.
// It fixes the r15q loss of harmonic intelligence by running tiny, budgeted live
// field substeps in their own routine. MIDI noteOn/noteOff remain sacred:
// they never run event settles, never build solve jobs, and noteOff releases audio immediately.
var build, at, cfg, st, api, diag;

build = ~atBuild;
if(build.isNil) {
    "[at-scheduler] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];

    if(cfg[\perf].isNil) { cfg[\perf] = IdentityDictionary.new; };

    // Performance defaults. These shape execution only; they do not cap musical movement.
    cfg[\perf][\schedulerEnabled] = true;
    cfg[\perf][\liveEventSolvesEnabled] = false;
    cfg[\perf][\syncSolveForManualOnly] = true;
    cfg[\perf][\liveDiagnostics] = false;
    cfg[\perf][\printMidi] = false;
    cfg[\perf][\printCC] = false;
    cfg[\perf][\printSolveRequests] = false;
    cfg[\perf][\profileEnabled] = false;

    cfg[\perf][\liveFieldEngineEnabled] = true;
    cfg[\perf][\liveFieldDt] = cfg[\perf][\liveFieldDt] ? 0.010;              // ~100Hz field service
    cfg[\perf][\liveFieldBudgetMs] = cfg[\perf][\liveFieldBudgetMs] ? 1.8;      // non-blocking budget
    cfg[\perf][\liveFieldRecentBudgetMs] = cfg[\perf][\liveFieldRecentBudgetMs] ? 0.35;
    cfg[\perf][\liveFieldMaxSubsteps] = cfg[\perf][\liveFieldMaxSubsteps] ? 4;
    cfg[\perf][\liveFieldRecentSubsteps] = cfg[\perf][\liveFieldRecentSubsteps] ? 1;
    cfg[\perf][\inputRecentWindow] = cfg[\perf][\inputRecentWindow] ? 0.018;
    cfg[\perf][\liveFieldIdleSleepFactor] = cfg[\perf][\liveFieldIdleSleepFactor] ? 1.5;
    cfg[\perf][\liveFastSettleWindow] = cfg[\perf][\liveFastSettleWindow] ? 0.55;
    cfg[\perf][\liveFastSettleDt] = cfg[\perf][\liveFastSettleDt] ? 0.006;
    cfg[\perf][\liveFastSettleBudgetMs] = cfg[\perf][\liveFastSettleBudgetMs] ? 1.6;
    cfg[\perf][\liveFastSettleSubsteps] = cfg[\perf][\liveFastSettleSubsteps] ? 4;
    cfg[\perf][\liveFastSettleAlphaScale] = cfg[\perf][\liveFastSettleAlphaScale] ? 3.2;
    cfg[\perf][\liveFastSettleStepScale] = cfg[\perf][\liveFastSettleStepScale] ? 2.2;
    cfg[\perf][\liveCatchUpAlphaScale] = cfg[\perf][\liveCatchUpAlphaScale] ? 1.65;
    cfg[\perf][\liveCatchUpThreshold] = cfg[\perf][\liveCatchUpThreshold] ? 0.04;
    cfg[\perf][\freezeOnAllNotesOffImmediately] = true;

    // r15r: continuous field is the live solve. Make the single substep stronger than r15q
    // but still very small; repeated tiny substeps replace the old 1200-iteration event solve.
    cfg[\solver][\continuousEnabled] = true;
    cfg[\solver][\continuousAlpha] = cfg[\solver][\continuousAlpha] ? 0.032;
    cfg[\solver][\continuousMaxStep] = cfg[\solver][\continuousMaxStep] ? 0.0022;

    // ------------------------------------------------------------
    // Solve cancellation / dirty state
    // ------------------------------------------------------------

    at[\cancelSolve] = {
        st[\solveRequestId] = (st[\solveRequestId] ? 0) + 1;
        if(st[\solveRoutine].notNil) {
            st[\solveRoutine].stop;
            st[\solveRoutine] = nil;
        };
        st[\solveRunning] = false;
        st[\solveLaunchPending] = false;
        st[\solveJob] = nil;
        nil
    };

    at[\markFieldDirty] = { |reason=\event|
        var now, fastWindow;
        now = Main.elapsedTime;
        fastWindow = cfg[\perf][\liveFastSettleWindow] ? 0.55;
        st[\fieldDirty] = true;
        st[\fieldDirtyReason] = reason;
        st[\lastInputAt] = now;
        st[\fastSettleUntil] = now + fastWindow;
        st[\fieldServiceLastAt] = now;
        st[\uiSnapshotCache] = nil;
        nil
    };

    at[\finishSchedulerProfile] = { |reason=\liveDeferred, status=\deferred|
        var report;
        report = (
            timestamp: Main.elapsedTime,
            status: status,
            reason: reason,
            mode: \liveIncremental,
            elapsedMs: 0.0,
            iterations: 0,
            chunks: 0,
            activePcs: at[\activePcsFromWeights].(at[\pcWeights].()).copy,
            externalCount: at[\currentExternalSources].().size
        );
        st[\lastSolveProfile] = report;
        report
    };

    // Live resolve requests are cheap: mark dirty and return. The live field routine performs
    // tiny incremental harmonic work after control returns to the scheduler.
    at[\requestSolve] = { |reason=\manual, synchronous=false|
        if((st[\powerEnabled] ? true).not) {
            if(at[\cancelSolve].notNil) { at[\cancelSolve].(); };
            st[\fieldDirty] = false;
            st[\lastSolveProfile] = (
                timestamp: Main.elapsedTime,
                status: \powerOff,
                reason: reason,
                mode: \paused,
                elapsedMs: 0.0,
                iterations: 0,
                chunks: 0,
                activePcs: Array.new,
                externalCount: 0
            );
            nil
        } {
            if(synchronous == true) {
                // Manual/test-only escape hatch. Do not use from live MIDI.
                at[\cancelSolve].();
                st[\solveRunning] = true;
                at[\settleForCurrentConstraints].();
                st[\solveRunning] = false;
                at[\pushBuses].();
                if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
                st[\lastSolveProfile] = (
                    timestamp: Main.elapsedTime,
                    status: \syncDone,
                    reason: reason,
                    mode: \syncLegacy,
                    elapsedMs: 0.0,
                    iterations: -1,
                    chunks: -1,
                    activePcs: at[\activePcsFromWeights].(at[\pcWeights].()).copy,
                    externalCount: at[\currentExternalSources].().size
                );
            } {
                at[\cancelSolve].();
                at[\markFieldDirty].(reason);
                at[\finishSchedulerProfile].(reason, \queuedForLiveField);
            };
            nil
        }
    };

    api[\resolveNow] = { |reason=\manual|
        if((cfg[\perf][\printSolveRequests] ? false) == true) {
            diag[\log].("live field request reason=" ++ reason.asString);
        };
        at[\requestSolve].(reason, false);
        nil
    };

    api[\resolveNowSync] = { |reason=\manual|
        if((cfg[\perf][\printSolveRequests] ? false) == true) {
            diag[\log].("sync solve reason=" ++ reason.asString);
        };
        at[\requestSolve].(reason, true);
        nil
    };

    // ------------------------------------------------------------
    // Single live substep: same field law as continuous fieldStep, but no bus push.
    // The wrapper pushes once after one or more tiny substeps.
    // ------------------------------------------------------------

    at[\liveFieldSubstep] = { |reason=\live, alphaScale=1.0, stepScale=1.0|
        var pcWeights, activePcs, externalSources, sources, anchorSrc, anchorPc, anchorPhase;
        var forces, delta, alpha, maxStep, mean, didStep;

        didStep = false;
        if((cfg[\solver][\continuousEnabled] ? true) == true) {
            pcWeights = at[\pcWeights].();
            activePcs = at[\activePcsFromWeights].(pcWeights);
            externalSources = at[\currentExternalSources].();
            alpha = (cfg[\solver][\continuousAlpha] ? 0.032) * alphaScale.max(0.01) * at[\fieldMobilityScale].() * (0.45 + (((cfg[\solver][\tensionPitchReference] ? 0.55).clip(0.0, 1.0) * 0.55)));
            maxStep = ((cfg[\solver][\continuousMaxStep] ? 0.0022) * stepScale.max(0.01)).max(0.00005);
            delta = Array.fill(cfg[\solver][\numNodes], 0.0);

            if(activePcs.size > 0) {
                // v45 context-threshold cleanup: with no external authority, one or two
                // active notes are placement/context only. They must not be moved by the
                // background continuous field. One note seeds/holds the harmonic origin;
                // two notes define an already complete dyad relation. Active-note
                // negotiation begins only at 3+ active notes.
                if(((externalSources ? Array.new).isEmpty) and: { activePcs.size < (cfg[\solver][\activeNegotiationMinActiveNotes] ? 3) }) {
                    delta = Array.fill(cfg[\solver][\numNodes], 0.0);
                    at[\fieldComposeFromShapeGauge].();
                    at[\updateDescriptors].(activePcs, pcWeights, externalSources, delta);
                    at[\updateCausalTransportState].(activePcs, externalSources, \contextThresholdHold);
                    st[\stateLabel] = if(activePcs.size == 1) { \singleContextHeld } { \dyadContextHeld };
                    st[\fieldDirty] = false;
                    st[\lastFieldStep] = (timestamp: Main.elapsedTime, reason: \contextThresholdHold, maxDelta: 0.0, activePcs: activePcs.copy);
                    didStep = true;
                } {
                    anchorPc = at[\chooseAnchorPc].(activePcs, pcWeights, externalSources);
                    anchorPhase = at[\chooseAnchorPhase].(anchorPc);
                    forces = at[\computeForces].(activePcs, pcWeights, externalSources) ? Array.fill(cfg[\solver][\numNodes] ? 12, 0.0);
                    forces = Array.fill(cfg[\solver][\numNodes] ? 12, { |fi| forces[fi] ? 0.0 });
                    if(activePcs.size == 1) {
                        forces[anchorPc] = 0.0;
                    } {
                        forces = at[\activeForceBodyBalance].(forces, activePcs, pcWeights);
                    };
                    delta = forces.collect { |f| (f * alpha).clip(maxStep.neg, maxStep) };
                    if(activePcs.size > 1) { delta = at[\r15kProjectActiveDeltaBody].(delta, activePcs, pcWeights, \continuous); };
                    if(activePcs.size == 1) { delta[anchorPc] = 0.0; };
                    at[\applyDelta].(delta);
                    if(activePcs.size == 1) {
                        at[\rotateWholeFieldTo].(anchorPc, anchorPhase);
                    } {
                        at[\applySoftAnchorGauge].(anchorPc, anchorPhase, activePcs, pcWeights, \continuous);
                    };
                    at[\updateDescriptors].(activePcs, pcWeights, externalSources, delta);
                    at[\applyExternalGaugeCarry].(activePcs, pcWeights, externalSources);
                    at[\applyPassiveGhostDissipation].(activePcs, \continuous, externalSources);
                    at[\updateCausalTransportState].(activePcs, externalSources, \continuous);
                    st[\stateLabel] = if((externalSources ? Array.new).notEmpty) { \mixedMulti } { if(activePcs.size == 1) { \single } { \multi } };
                    didStep = true;
                };
            } {
                if(externalSources.notEmpty) {
                    sources = at[\takeStrongestSources].(externalSources, cfg[\mic][\maxExternalSources]);
                    anchorSrc = at[\strongestExternalSource].(sources);
                    if(anchorSrc.notNil) {
                        anchorPc = anchorSrc[\pc];
                        anchorPhase = anchorSrc[\phase];
                        activePcs = sources.collect { |src| src[\pc] }.as(Set).asArray.sort;
                        forces = at[\computeForcesFromSourceList].(sources, activePcs) ? Array.fill(cfg[\solver][\numNodes] ? 12, 0.0);
                        forces = Array.fill(cfg[\solver][\numNodes] ? 12, { |fi| forces[fi] ? 0.0 });
                        mean = activePcs.collect { |pc| forces[pc] ? 0.0 }.sum / activePcs.size.max(1);
                        forces = forces.collect { |f| (f ? 0.0) - (mean ? 0.0) };
                        delta = forces.collect { |f| (f * alpha).clip(maxStep.neg, maxStep) };
                        at[\applyDelta].(delta);
                        at[\rotateWholeFieldTo].(anchorPc, anchorPhase);
                        at[\updateDescriptorsFromSources].(sources, activePcs, delta);
                        at[\updateCausalTransportState].(activePcs, sources, \externalEvidence);
                        st[\stateLabel] = \external;
                        didStep = true;
                    };
                };
            };

            if(didStep) {
                st[\fieldTickCount] = (st[\fieldTickCount] ? 0) + 1;
                st[\lastFieldStep] = (timestamp: Main.elapsedTime, reason: reason, maxDelta: at[\maxAbs].(delta));
            };
        };
        didStep
    };

    at[\liveFieldNeeded] = {
        var activeCount, externalCount;
        if((st[\powerEnabled] ? true).not) {
            false
        } {
            activeCount = st[\activeNotes].size;
            externalCount = at[\currentExternalSources].().size;
            ((st[\fieldDirty] ? false) == true) or: { activeCount > 0 } or: { externalCount > 0 }
        }
    };

    at[\fieldStep] = { |reason=\live|
        var start, budgetSec, maxSteps, recentInput, fastSettle, catchUp, didAny, steps, keepGoing, elapsedMs, activePcs, externalCount;
        var alphaScale, stepScale, now, lastServiceAt, status;
        didAny = false;
        steps = 0;

        if((cfg[\perf][\liveFieldEngineEnabled] ? true) == false) {
            false
        } {
            if(at[\liveFieldNeeded].().not) {
                false
            } {
                now = Main.elapsedTime;
                if(at[\runtimeShouldHoldField].notNil and: { at[\runtimeShouldHoldField].() }) {
                    st[\lastSolveProfile] = (
                        timestamp: now,
                        status: \runtimeHeld,
                        reason: reason,
                        mode: \liveIncremental,
                        elapsedMs: 0.0,
                        iterations: 0,
                        chunks: 0,
                        activePcs: at[\activePcsFromWeights].(at[\pcWeights].()).copy,
                        externalCount: at[\currentExternalSources].().size,
                        hold: st[\runtimeLastFieldHold]
                    );
                    false
                } {
                    lastServiceAt = st[\fieldServiceLastAt] ? now;
                    recentInput = (now - (st[\lastInputAt] ? -9999.0)) < (cfg[\perf][\inputRecentWindow] ? 0.018);
                    fastSettle = (st[\activeNotes].size > 0) and: { now < (st[\fastSettleUntil] ? -9999.0) };
                    catchUp = (now - lastServiceAt) > (cfg[\perf][\liveCatchUpThreshold] ? 0.04);
                    alphaScale = 1.0;
                    stepScale = 1.0;
                    status = \liveStepped;

                    if(recentInput) {
                        budgetSec = (cfg[\perf][\liveFieldRecentBudgetMs] ? 0.35) / 1000.0;
                        maxSteps = cfg[\perf][\liveFieldRecentSubsteps] ? 1;
                        status = if(st[\activeNotes].size > 0) { \liveRecentShapeService } { \liveRecent };
                    } {
                        if(fastSettle) {
                            budgetSec = (cfg[\perf][\liveFastSettleBudgetMs] ? 1.6) / 1000.0;
                            maxSteps = cfg[\perf][\liveFastSettleSubsteps] ? 4;
                            alphaScale = cfg[\perf][\liveFastSettleAlphaScale] ? 3.2;
                            stepScale = cfg[\perf][\liveFastSettleStepScale] ? 2.2;
                            status = \liveFastSettle;
                        } {
                            budgetSec = (cfg[\perf][\liveFieldBudgetMs] ? 1.8) / 1000.0;
                            maxSteps = cfg[\perf][\liveFieldMaxSubsteps] ? 4;
                            status = \liveStepped;
                        };
                    };

                    if(maxSteps <= 0) {
                        st[\lastSolveProfile] = (
                            timestamp: Main.elapsedTime,
                            status: \runtimeZeroStepHold,
                            reason: reason,
                            mode: \liveIncremental,
                            elapsedMs: 0.0,
                            iterations: 0,
                            chunks: 0,
                            activePcs: at[\activePcsFromWeights].(at[\pcWeights].()).copy,
                            externalCount: at[\currentExternalSources].().size,
                            recentInput: recentInput,
                            fastSettle: fastSettle,
                            catchUp: catchUp
                        );
                        false
                    } {
                        if(catchUp and: { recentInput.not }) {
                            alphaScale = alphaScale * (cfg[\perf][\liveCatchUpAlphaScale] ? 1.65);
                            status = if(fastSettle) { \liveFastCatchUp } { \liveCatchUp };
                        };

                        start = Main.elapsedTime;
                        keepGoing = true;
                        while { keepGoing } {
                            if(at[\liveFieldSubstep].(reason, alphaScale, stepScale) == true) { didAny = true; };
                            steps = steps + 1;
                            keepGoing = (steps < maxSteps) and: { (Main.elapsedTime - start) < budgetSec } and: { at[\liveFieldNeeded].() };
                        };

                        if(didAny) {
                            at[\pushBuses].();
                            activePcs = at[\activePcsFromWeights].(at[\pcWeights].()).copy;
                            externalCount = at[\currentExternalSources].().size;
                            elapsedMs = (Main.elapsedTime - start) * 1000.0;
                            st[\fieldServiceLastAt] = Main.elapsedTime;
                            if(at[\runtimeMarkFieldStepResult].notNil) { at[\runtimeMarkFieldStepResult].(elapsedMs, budgetSec * 1000.0, status, steps); };
                            st[\lastSolveProfile] = (
                                timestamp: Main.elapsedTime,
                                status: status,
                                reason: reason,
                                mode: \liveIncremental,
                                elapsedMs: elapsedMs,
                                iterations: steps,
                                chunks: 1,
                                activePcs: activePcs,
                                externalCount: externalCount,
                                recentInput: recentInput,
                                fastSettle: fastSettle,
                                catchUp: catchUp,
                                alphaScale: alphaScale,
                                stepScale: stepScale
                            );
                            if(st[\activeNotes].size == 0 and: { externalCount == 0 }) { st[\fieldDirty] = false; };
                        };
                        didAny
                    }
                }
            }
        }
    };

    // ------------------------------------------------------------
    // Runtime loops: separate field, mic, and UI snapshot work.
    // ------------------------------------------------------------

    at[\start] = {
        at[\stop].();
        at[\pushBuses].();
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };

        st[\fieldRoutine] = Routine({
            inf.do {
                var dt;
                dt = if((st[\activeNotes].size > 0) and: { Main.elapsedTime < (st[\fastSettleUntil] ? -9999.0) }) {
                    cfg[\perf][\liveFastSettleDt] ? 0.006
                } {
                    cfg[\perf][\liveFieldDt] ? 0.010
                };
                if(((st[\powerEnabled] ? true) == true) and: { (cfg[\perf][\liveFieldEngineEnabled] ? true) == true }) {
                    at[\fieldStep].(st[\fieldDirtyReason] ? \live);
                };
                dt.wait;
            };
        }).play(SystemClock);

        st[\micRoutine] = Routine({
            inf.do {
                if(((st[\powerEnabled] ? true) == true) and: { cfg[\mic][\enabled] }) {
                    at[\micStep].();
                };
                (cfg[\mic][\pollDt] ? 0.05).wait;
            };
        }).play(SystemClock);

        st[\slowUiRoutine] = Routine({
            inf.do {
                if(at[\runtimeSafeRefreshUISnapshot].notNil) {
                    at[\runtimeSafeRefreshUISnapshot].();
                } {
                    if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
                };
                if(at[\runtimeUiRefreshDt].notNil) {
                    at[\runtimeUiRefreshDt].().wait;
                } {
                    (cfg[\perf][\uiSlowRefreshDt] ? 0.35).wait;
                };
            };
        }).play(AppClock);

        nil
    };

    at[\stop] = {
        if(st[\controlRoutine].notNil) { st[\controlRoutine].stop; st[\controlRoutine] = nil; };
        if(st[\fieldRoutine].notNil) { st[\fieldRoutine].stop; st[\fieldRoutine] = nil; };
        if(st[\micRoutine].notNil) { st[\micRoutine].stop; st[\micRoutine] = nil; };
        if(st[\slowUiRoutine].notNil) { st[\slowUiRoutine].stop; st[\slowUiRoutine] = nil; };
        nil
    };

    "[at-scheduler] v46 context-threshold live pump: one/two active notes hold; released arpeggios move passive world; 3+ negotiate; report proves active-note stability".postln;
};
)
