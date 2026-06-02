(
// AT_runtime_performance_hardening.scd
// v29c real-play runtime hardening: bounded active-input shape service without budget-overrun starvation.
// This module does not change tuning law, spectrum authority, samples, mic policy, or UI controls.
var build, at, cfg, st, api, diag, oldRefresh;

build = ~atBuild;
if(build.isNil) {
    "[at-runtime-hardening] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];

    if(cfg[\perf].isNil) { cfg[\perf] = IdentityDictionary.new; };

    // Execution-only defaults. These reduce runtime pressure during real play without
    // imposing cent caps or changing harmonic destinations.
    cfg[\perf][\runtimeHardeningEnabled] = true;
    cfg[\perf][\runtimeProfile] = cfg[\perf][\runtimeProfile] ? \realPlaySafe;
    cfg[\perf][\runtimeFieldHoldUntil] = cfg[\perf][\runtimeFieldHoldUntil] ? 0.0;
    cfg[\perf][\runtimeFieldOverrunHoldSeconds] = cfg[\perf][\runtimeFieldOverrunHoldSeconds] ? 0.45;
    cfg[\perf][\runtimeFieldHardLimitMs] = cfg[\perf][\runtimeFieldHardLimitMs] ? 7.5;
    cfg[\perf][\runtimeFieldOverrunMultiplier] = cfg[\perf][\runtimeFieldOverrunMultiplier] ? 2.25;
    cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] = cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] ? 8;
    cfg[\perf][\runtimeSkipFieldWhileInputRecent] = cfg[\perf][\runtimeSkipFieldWhileInputRecent] ? true;
    cfg[\perf][\runtimeUiActiveRefreshDt] = cfg[\perf][\runtimeUiActiveRefreshDt] ? 0.70;
    cfg[\perf][\runtimeUiIdleRefreshDt] = cfg[\perf][\runtimeUiIdleRefreshDt] ? 0.45;
    cfg[\perf][\runtimeUiActiveMinInterval] = cfg[\perf][\runtimeUiActiveMinInterval] ? 0.42;
    cfg[\perf][\runtimeUiIdleMinInterval] = cfg[\perf][\runtimeUiIdleMinInterval] ? 0.20;
    cfg[\perf][\runtimeSnapshotThrottleEnabled] = cfg[\perf][\runtimeSnapshotThrottleEnabled] ? true;
    // v29c: recent MIDI input still holds background/heavy field work, but
    // not the active harmonic body. Recent-input shape service remains one tiny
    // substep; budget overrun on that substep no longer triggers a long hold
    // unless it crosses the hard runtime limit.
    cfg[\perf][\runtimeAllowRecentInputShapeService] = cfg[\perf][\runtimeAllowRecentInputShapeService] ? true;
    cfg[\perf][\runtimeRecentShapeServiceHardOverrunOnly] = cfg[\perf][\runtimeRecentShapeServiceHardOverrunOnly] ? true;

    at[\runtimeApplyPerformanceProfile] = { |profile=\realPlaySafe|
        var p;
        p = profile ? \realPlaySafe;
        cfg[\perf][\runtimeProfile] = p;

        if(p == \legacyResponsive) {
            cfg[\perf][\liveFieldDt] = 0.010;
            cfg[\perf][\liveFastSettleDt] = 0.006;
            cfg[\perf][\liveFieldBudgetMs] = 1.8;
            cfg[\perf][\liveFieldRecentBudgetMs] = 0.35;
            cfg[\perf][\liveFastSettleBudgetMs] = 1.6;
            cfg[\perf][\liveFieldMaxSubsteps] = 4;
            cfg[\perf][\liveFieldRecentSubsteps] = 1;
            cfg[\perf][\liveFastSettleSubsteps] = 4;
            cfg[\perf][\liveFastSettleAlphaScale] = 3.2;
            cfg[\perf][\liveFastSettleStepScale] = 2.2;
            cfg[\perf][\liveCatchUpAlphaScale] = 1.65;
            cfg[\perf][\inputRecentWindow] = 0.09;
            cfg[\perf][\runtimeSkipFieldWhileInputRecent] = false;
            cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] = 12;
            cfg[\perf][\uiSlowRefreshDt] = 0.35;
            cfg[\perf][\runtimeUiActiveRefreshDt] = 0.45;
            cfg[\perf][\runtimeUiIdleRefreshDt] = 0.35;
            cfg[\solver][\continuousAlpha] = 0.032;
            cfg[\solver][\continuousMaxStep] = 0.0022;
        } {
            if(p == \auditionSafe) {
                cfg[\perf][\liveFieldDt] = 0.014;
                cfg[\perf][\liveFastSettleDt] = 0.010;
                cfg[\perf][\liveFieldBudgetMs] = 1.05;
                cfg[\perf][\liveFieldRecentBudgetMs] = 0.18;
                cfg[\perf][\liveFastSettleBudgetMs] = 0.95;
                cfg[\perf][\liveFieldMaxSubsteps] = 2;
                cfg[\perf][\liveFieldRecentSubsteps] = 0;
                cfg[\perf][\liveFastSettleSubsteps] = 2;
                cfg[\perf][\liveFastSettleAlphaScale] = 2.35;
                cfg[\perf][\liveFastSettleStepScale] = 1.70;
                cfg[\perf][\liveCatchUpAlphaScale] = 1.15;
                cfg[\perf][\inputRecentWindow] = 0.11;
                cfg[\perf][\runtimeSkipFieldWhileInputRecent] = true;
                cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] = 9;
                cfg[\perf][\uiSlowRefreshDt] = 0.50;
                cfg[\perf][\runtimeUiActiveRefreshDt] = 0.60;
                cfg[\perf][\runtimeUiIdleRefreshDt] = 0.40;
                cfg[\solver][\continuousAlpha] = 0.026;
                cfg[\solver][\continuousMaxStep] = 0.0018;
            } {
                // Default real-play profile: fail open by keeping sound responsive and
                // temporarily holding field work during input bursts/dense chords.
                cfg[\perf][\runtimeProfile] = \realPlaySafe;
                cfg[\perf][\liveFieldDt] = 0.014;
                cfg[\perf][\liveFastSettleDt] = 0.010;
                cfg[\perf][\liveFieldBudgetMs] = 0.75;
                cfg[\perf][\liveFieldRecentBudgetMs] = 0.24;
                cfg[\perf][\liveFastSettleBudgetMs] = 0.70;
                cfg[\perf][\liveFieldMaxSubsteps] = 1;
                cfg[\perf][\liveFieldRecentSubsteps] = 1;
                cfg[\perf][\liveFastSettleSubsteps] = 1;
                cfg[\perf][\liveFastSettleAlphaScale] = 2.05;
                cfg[\perf][\liveFastSettleStepScale] = 1.45;
                cfg[\perf][\liveCatchUpAlphaScale] = 1.05;
                cfg[\perf][\liveCatchUpThreshold] = 0.085;
                cfg[\perf][\inputRecentWindow] = 0.13;
                cfg[\perf][\runtimeSkipFieldWhileInputRecent] = true;
                cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] = 8;
                cfg[\perf][\uiSlowRefreshDt] = 0.55;
                cfg[\perf][\runtimeUiActiveRefreshDt] = 0.75;
                cfg[\perf][\runtimeUiIdleRefreshDt] = 0.45;
                cfg[\solver][\continuousAlpha] = 0.026;
                cfg[\solver][\continuousMaxStep] = 0.00180;
            };
        };

        st[\runtimeLastProfileApplied] = (
            timestamp: Main.elapsedTime,
            profile: cfg[\perf][\runtimeProfile],
            liveFieldDt: cfg[\perf][\liveFieldDt],
            liveFieldBudgetMs: cfg[\perf][\liveFieldBudgetMs],
            liveFieldRecentBudgetMs: cfg[\perf][\liveFieldRecentBudgetMs],
            liveFastSettleBudgetMs: cfg[\perf][\liveFastSettleBudgetMs],
            liveFieldMaxSubsteps: cfg[\perf][\liveFieldMaxSubsteps],
            liveFieldRecentSubsteps: cfg[\perf][\liveFieldRecentSubsteps],
            recentInputShapeServiceEnabled: cfg[\perf][\runtimeAllowRecentInputShapeService] ? true,
            recentShapeServiceHardOverrunOnly: cfg[\perf][\runtimeRecentShapeServiceHardOverrunOnly] ? true,
            lastRecentShapeService: st[\runtimeLastRecentShapeService],
            inputRecentWindow: cfg[\perf][\inputRecentWindow],
            recentInputShapeService: cfg[\perf][\runtimeAllowRecentInputShapeService] ? true,
            liveFieldRecentBudgetMs: cfg[\perf][\liveFieldRecentBudgetMs],
            liveFieldRecentSubsteps: cfg[\perf][\liveFieldRecentSubsteps],
            uiActiveRefreshDt: cfg[\perf][\runtimeUiActiveRefreshDt]
        );
        st[\uiSnapshotCache] = nil;
        st[\runtimeFieldHoldUntil] = 0.0;
        p
    };

    at[\runtimeRecentInput] = {
        (Main.elapsedTime - (st[\lastInputAt] ? -9999.0)) < (cfg[\perf][\inputRecentWindow] ? 0.13)
    };

    at[\runtimeDenseActive] = {
        st[\activeNotes].size >= (cfg[\perf][\runtimeMaxActiveNotesBeforeFieldHold] ? 8)
    };

    at[\runtimeShouldHoldField] = {
        var now, reason, activeCount;
        now = Main.elapsedTime;
        reason = nil;
        activeCount = st[\activeNotes].size;

        if((cfg[\perf][\runtimeHardeningEnabled] ? true) == false) {
            false
        } {
            if(now < (st[\runtimeFieldHoldUntil] ? -1.0)) {
                reason = \postOverrunHold;
            };
            if(reason.isNil and: { ((cfg[\perf][\runtimeSkipFieldWhileInputRecent] ? true) == true) and: { at[\runtimeRecentInput].() } }) {
                if(((cfg[\perf][\runtimeAllowRecentInputShapeService] ? true) == true) and: { activeCount > 0 }) {
                    st[\runtimeLastRecentShapeService] = (
                        timestamp: now,
                        reason: \recentInputShapeServiceAllowed,
                        activeNotes: activeCount,
                        voiceCount: st[\voices].size,
                        budgetMs: cfg[\perf][\liveFieldRecentBudgetMs] ? 0.24,
                        maxSubsteps: cfg[\perf][\liveFieldRecentSubsteps] ? 1
                    );
                } {
                    reason = \recentInput;
                };
            };
            if(reason.isNil and: { at[\runtimeDenseActive].() }) {
                reason = \denseActiveNotes;
            };
            if(reason.notNil) {
                st[\runtimeLastFieldHold] = (
                    timestamp: now,
                    reason: reason,
                    activeNotes: activeCount,
                    voiceCount: st[\voices].size,
                    holdUntil: st[\runtimeFieldHoldUntil] ? 0.0,
                    recentInput: at[\runtimeRecentInput].()
                );
                true
            } {
                false
            }
        }
    };

    at[\runtimeMarkFieldStepResult] = { |elapsedMs=0.0, budgetMs=1.0, status=\live, steps=0|
        var now, overrun, hardOverrun, budgetOverrun, shapeServiceHardOnly;
        now = Main.elapsedTime;
        shapeServiceHardOnly = ((status == \liveRecentShapeService) and: { (cfg[\perf][\runtimeRecentShapeServiceHardOverrunOnly] ? true) == true });
        budgetOverrun = if(shapeServiceHardOnly) { false } { elapsedMs > (budgetMs * (cfg[\perf][\runtimeFieldOverrunMultiplier] ? 2.25)) };
        hardOverrun = elapsedMs > (cfg[\perf][\runtimeFieldHardLimitMs] ? 7.5);
        overrun = budgetOverrun or: { hardOverrun };
        st[\runtimeLastFieldStep] = (
            timestamp: now,
            elapsedMs: elapsedMs,
            budgetMs: budgetMs,
            status: status,
            steps: steps,
            overrun: overrun,
            hardOverrun: hardOverrun,
            activeNotes: st[\activeNotes].size,
            voiceCount: st[\voices].size,
            shapeServiceHardOnly: shapeServiceHardOnly
        );
        if(overrun) {
            st[\runtimeOverrunCount] = (st[\runtimeOverrunCount] ? 0) + 1;
            st[\runtimeFieldHoldUntil] = now + (cfg[\perf][\runtimeFieldOverrunHoldSeconds] ? 0.45);
            st[\runtimeLastFieldHold] = (
                timestamp: now,
                reason: if(hardOverrun) { \hardFieldOverrun } { \fieldBudgetOverrun },
                elapsedMs: elapsedMs,
                budgetMs: budgetMs,
                holdUntil: st[\runtimeFieldHoldUntil],
                activeNotes: st[\activeNotes].size,
                voiceCount: st[\voices].size
            );
        };
        st[\runtimeLastFieldStep]
    };

    at[\runtimeUiRefreshDt] = {
        if((st[\activeNotes].size > 0) or: { at[\runtimeRecentInput].() }) {
            cfg[\perf][\runtimeUiActiveRefreshDt] ? 0.75
        } {
            cfg[\perf][\runtimeUiIdleRefreshDt] ? 0.45
        }
    };

    oldRefresh = api[\refreshUISnapshot];
    if(oldRefresh.notNil) {
        api[\refreshUISnapshot] = { |force=true|
            var now, recentInput, activePlay, minInterval, canSkip, snap;
            now = Main.elapsedTime;
            recentInput = if(at[\runtimeRecentInput].notNil) { at[\runtimeRecentInput].() } { false };
            activePlay = st[\activeNotes].size > 0;
            minInterval = if(activePlay or: { recentInput }) {
                cfg[\perf][\runtimeUiActiveMinInterval] ? 0.42
            } {
                cfg[\perf][\runtimeUiIdleMinInterval] ? 0.20
            };
            canSkip = ((cfg[\perf][\runtimeSnapshotThrottleEnabled] ? true) == true)
                and: { force.asBoolean.not }
                and: { st[\uiSnapshotCache].notNil }
                and: { (now - (st[\runtimeLastUiRefreshAt] ? -9999.0)) < minInterval };

            if((st[\runtimeUiRefreshInProgress] ? false) == true) {
                st[\runtimeUiRefreshReentrantSkips] = (st[\runtimeUiRefreshReentrantSkips] ? 0) + 1;
                st[\uiSnapshotCache] ? IdentityDictionary.new
            } {
                if(canSkip) {
                    st[\runtimeUiRefreshSkips] = (st[\runtimeUiRefreshSkips] ? 0) + 1;
                    st[\runtimeLastUiRefreshSkip] = (
                        timestamp: now,
                        activePlay: activePlay,
                        recentInput: recentInput,
                        minInterval: minInterval
                    );
                    st[\uiSnapshotCache]
                } {
                    st[\runtimeUiRefreshInProgress] = true;
                    snap = oldRefresh.value;
                    st[\runtimeUiRefreshInProgress] = false;
                    st[\runtimeLastUiRefreshAt] = Main.elapsedTime;
                    st[\runtimeLastUiRefresh] = (
                        timestamp: st[\runtimeLastUiRefreshAt],
                        force: force.asBoolean,
                        activePlay: activePlay,
                        recentInput: recentInput
                    );
                    snap
                }
            }
        };
    };

    at[\runtimeSafeRefreshUISnapshot] = {
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(false) } { st[\uiSnapshotCache] ? IdentityDictionary.new }
    };

    api[\applyRuntimePerformanceProfile] = { |profile=\realPlaySafe|
        at[\runtimeApplyPerformanceProfile].(profile);
        api[\runtimePerformanceSnapshot].()
    };

    api[\runtimePerformanceSnapshot] = {
        var now;
        now = Main.elapsedTime;
        (
            role: \runtimePerformanceSnapshot,
            runtimeProfile: cfg[\perf][\runtimeProfile] ? \realPlaySafe,
            hardeningEnabled: cfg[\perf][\runtimeHardeningEnabled] ? true,
            activeNotes: st[\activeNotes].size,
            voiceCount: st[\voices].size,
            recentInput: if(at[\runtimeRecentInput].notNil) { at[\runtimeRecentInput].() } { false },
            denseActiveHold: if(at[\runtimeDenseActive].notNil) { at[\runtimeDenseActive].() } { false },
            fieldHoldActive: now < (st[\runtimeFieldHoldUntil] ? -1.0),
            lastFieldHold: st[\runtimeLastFieldHold],
            lastFieldStep: st[\runtimeLastFieldStep],
            lastSolveProfile: st[\lastSolveProfile],
            lastUiRefresh: st[\runtimeLastUiRefresh],
            lastUiRefreshSkip: st[\runtimeLastUiRefreshSkip],
            uiRefreshSkips: st[\runtimeUiRefreshSkips] ? 0,
            reentrantUiSkips: st[\runtimeUiRefreshReentrantSkips] ? 0,
            overrunCount: st[\runtimeOverrunCount] ? 0,
            liveFieldDt: cfg[\perf][\liveFieldDt],
            liveFieldBudgetMs: cfg[\perf][\liveFieldBudgetMs],
            liveFieldRecentBudgetMs: cfg[\perf][\liveFieldRecentBudgetMs],
            liveFastSettleBudgetMs: cfg[\perf][\liveFastSettleBudgetMs],
            liveFieldMaxSubsteps: cfg[\perf][\liveFieldMaxSubsteps],
            liveFieldRecentSubsteps: cfg[\perf][\liveFieldRecentSubsteps],
            recentInputShapeServiceEnabled: cfg[\perf][\runtimeAllowRecentInputShapeService] ? true,
            recentShapeServiceHardOverrunOnly: cfg[\perf][\runtimeRecentShapeServiceHardOverrunOnly] ? true,
            lastRecentShapeService: st[\runtimeLastRecentShapeService],
            liveFastSettleSubsteps: cfg[\perf][\liveFastSettleSubsteps],
            inputRecentWindow: cfg[\perf][\inputRecentWindow],
            uiActiveRefreshDt: cfg[\perf][\runtimeUiActiveRefreshDt],
            uiIdleRefreshDt: cfg[\perf][\runtimeUiIdleRefreshDt],
            micEnabled: cfg[\mic][\enabled],
            noSolverHook: (cfg[\perf][\liveEventSolvesEnabled] ? false).not,
            noTuningAuthorityChange: true,
            noSampleSpectrumTruthChange: true,
            noVisualRedesign: true,
            shapePreservationPatch: \v29c
        )
    };

    api[\runtimeEmergencyQuiet] = {
        st[\sustainDown] = false;
        st[\activeNotes].clear;
        if(at[\allVoicesOff].notNil) { at[\allVoicesOff].() };
        if(at[\cancelSolve].notNil) { at[\cancelSolve].() };
        st[\runtimeFieldHoldUntil] = Main.elapsedTime + (cfg[\perf][\runtimeFieldOverrunHoldSeconds] ? 0.45);
        st[\lastInputAt] = Main.elapsedTime;
        if(at[\freezeCurrentField].notNil) { at[\freezeCurrentField].() };
        if(at[\pushBuses].notNil) { at[\pushBuses].() };
        api[\runtimePerformanceSnapshot].()
    };

    at[\runtimeApplyPerformanceProfile].(cfg[\perf][\runtimeProfile] ? \realPlaySafe);

    "[at-runtime-hardening] v29c real-play safe runtime profile loaded; shape service no-overrun-hold/no tuning authority".postln;
};
)
