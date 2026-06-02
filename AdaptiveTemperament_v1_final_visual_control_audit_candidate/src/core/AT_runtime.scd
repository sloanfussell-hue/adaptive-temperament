(
// AT_runtime.scd
// v29 real-play runtime hardening layer.
// This file is deliberately runtime-only: it does not change harmonic law,
// sample authority, perceptual/cylinder authority, or render routing.
var build, at, cfg, st, api, diag, ui;
var oldRefresh, oldSnapshot, oldStart, oldStop, oldNoteOn, oldNoteOff, oldSustainRelease;

build = ~atBuild;
if(build.isNil) {
    "[at-runtime] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\runtime].isNil) {
        cfg[\runtime] = (
            enabled: true,
            performanceMode: \realtimeSafe,
            tickSeconds: 0.05,
            diagnosticTickSeconds: 0.025,
            realtimeSafeTickSeconds: 0.05,
            freezeSafeTickSeconds: 0.10,
            snapshotMinInterval: 0.12,
            diagnosticSnapshotMinInterval: 0.04,
            readinessRecentWindow: 32,
            overrunSeconds: 0.18,
            dangerSeconds: 0.35,
            recentInputWindow: 0.18,
            denseInputEventsPerSecond: 18,
            skipFieldOnOverrun: true,
            skipFieldDuringDenseInput: true,
            maxHeldNotesBeforeFreezeSafe: 10,
            postMidiEventsInRealtimeSafe: false,
            uiFpsRealtimeSafe: 10,
            uiFpsFreezeSafe: 7
        );
    };

    at[\runtimeEnsureState] = {
        var rt;
        if(st[\runtimePerf].isNil) {
            st[\runtimePerf] = IdentityDictionary.new;
        };
        rt = st[\runtimePerf];
        if(rt[\mode].isNil) { rt[\mode] = cfg[\runtime][\performanceMode] ? \realtimeSafe; };
        if(rt[\enabled].isNil) { rt[\enabled] = cfg[\runtime][\enabled] ? true; };
        if(rt[\recentDurations].isNil) { rt[\recentDurations] = List.new; };
        if(rt[\inputTimes].isNil) { rt[\inputTimes] = List.new; };
        if(rt[\tickCount].isNil) { rt[\tickCount] = 0; };
        if(rt[\overrunCount].isNil) { rt[\overrunCount] = 0; };
        if(rt[\dangerCount].isNil) { rt[\dangerCount] = 0; };
        if(rt[\reentrantSkipCount].isNil) { rt[\reentrantSkipCount] = 0; };
        if(rt[\deferredFieldTickCount].isNil) { rt[\deferredFieldTickCount] = 0; };
        if(rt[\lastTickDuration].isNil) { rt[\lastTickDuration] = 0.0; };
        if(rt[\recentMeanDuration].isNil) { rt[\recentMeanDuration] = 0.0; };
        if(rt[\recentMaxDuration].isNil) { rt[\recentMaxDuration] = 0.0; };
        if(rt[\midiEventRate].isNil) { rt[\midiEventRate] = 0; };
        if(rt[\inTick].isNil) { rt[\inTick] = false; };
        if(rt[\lastSnapshotAt].isNil) { rt[\lastSnapshotAt] = 0.0; };
        if(rt[\lastWatchdogIntervention].isNil) { rt[\lastWatchdogIntervention] = \none; };
        rt;
    };

    at[\runtimeRecordDuration] = { |duration|
        var rt, hist, maxCount, sum, maxDur;
        rt = at[\runtimeEnsureState].();
        hist = rt[\recentDurations];
        hist.add(duration);
        maxCount = cfg[\runtime][\readinessRecentWindow] ? 32;
        while { hist.size > maxCount } { hist.removeAt(0); };
        sum = 0.0;
        maxDur = 0.0;
        hist.do { |x|
            sum = sum + x;
            if(x > maxDur) { maxDur = x; };
        };
        rt[\lastTickDuration] = duration;
        rt[\recentMeanDuration] = if(hist.size > 0) { sum / hist.size } { 0.0 };
        rt[\recentMaxDuration] = maxDur;
        if(duration > (cfg[\runtime][\overrunSeconds] ? 0.18)) {
            rt[\overrunCount] = (rt[\overrunCount] ? 0) + 1;
            rt[\lastWatchdogIntervention] = \tickOverrunObserved;
            rt[\lastWatchdogAt] = Main.elapsedTime;
        };
        if(duration > (cfg[\runtime][\dangerSeconds] ? 0.35)) {
            rt[\dangerCount] = (rt[\dangerCount] ? 0) + 1;
            rt[\lastWatchdogIntervention] = \dangerTickObserved;
            rt[\lastWatchdogAt] = Main.elapsedTime;
        };
        duration;
    };

    at[\runtimeStampInput] = { |kind=\input|
        var rt, now, times;
        rt = at[\runtimeEnsureState].();
        now = Main.elapsedTime;
        rt[\lastInputAt] = now;
        rt[\lastInputKind] = kind;
        rt[\inputEventCount] = (rt[\inputEventCount] ? 0) + 1;
        times = rt[\inputTimes];
        times.add(now);
        while { times.notEmpty and: { (now - times[0]) > 1.0 } } { times.removeAt(0); };
        rt[\midiEventRate] = times.size;
        nil;
    };

    at[\runtimeTickSeconds] = {
        var rt, mode;
        rt = at[\runtimeEnsureState].();
        mode = rt[\mode] ? \realtimeSafe;
        if(mode == \diagnostic) {
            cfg[\runtime][\diagnosticTickSeconds] ? 0.025;
        } {
            if(mode == \freezeSafe) {
                cfg[\runtime][\freezeSafeTickSeconds] ? 0.10;
            } {
                cfg[\runtime][\realtimeSafeTickSeconds] ? (cfg[\runtime][\tickSeconds] ? 0.05);
            };
        };
    };

    at[\runtimeSnapshotMinInterval] = {
        var rt, mode;
        rt = at[\runtimeEnsureState].();
        mode = rt[\mode] ? \realtimeSafe;
        if(mode == \diagnostic) {
            cfg[\runtime][\diagnosticSnapshotMinInterval] ? 0.04;
        } {
            cfg[\runtime][\snapshotMinInterval] ? 0.12;
        };
    };

    oldRefresh = api[\refreshUISnapshot];
    oldSnapshot = api[\uiSnapshot];

    api[\refreshUISnapshot] = { |force=false|
        var rt, now, due, snap;
        rt = at[\runtimeEnsureState].();
        now = Main.elapsedTime;
        due = (now - (rt[\lastSnapshotAt] ? 0.0)) >= at[\runtimeSnapshotMinInterval].();

        if((force == true) or: { (rt[\inTick] ? false).not or: { due } }) {
            if(at[\syncWorldMirrorsFromLegacy].notNil) {
                at[\syncWorldMirrorsFromLegacy].(if(rt[\inTick] ? false) { \runtimeSnapshot } { \uiRefresh });
            };
            snap = if(oldRefresh.notNil) {
                oldRefresh.value;
            } {
                if(at[\buildUISnapshot].notNil) { at[\buildUISnapshot].() } { IdentityDictionary.new };
            };
            if(at[\syncWorldSnapshotFieldsInto].notNil) {
                at[\syncWorldSnapshotFieldsInto].(snap);
            };
            st[\uiSnapshotCache] = snap;
            rt[\lastSnapshotAt] = now;
            rt[\snapshotCount] = (rt[\snapshotCount] ? 0) + 1;
            snap;
        } {
            rt[\snapshotThrottleCount] = (rt[\snapshotThrottleCount] ? 0) + 1;
            st[\uiSnapshotCache] ? IdentityDictionary.new;
        };
    };

    api[\uiSnapshot] = {
        if(st[\uiSnapshotCache].isNil) {
            api[\refreshUISnapshot].(true);
        };
        st[\uiSnapshotCache]
    };

    at[\runtimeShouldDeferFieldTick] = { |record=true|
        var rt, mode, now, recentInputAge, denseInput, manyHeld, overrunRisk, shouldDefer;
        rt = at[\runtimeEnsureState].();
        mode = rt[\mode] ? \realtimeSafe;
        now = Main.elapsedTime;
        recentInputAge = if(rt[\lastInputAt].isNil) { 999.0 } { now - rt[\lastInputAt] };
        denseInput = (rt[\midiEventRate] ? 0) >= (cfg[\runtime][\denseInputEventsPerSecond] ? 18);
        manyHeld = (st[\activeNotes].size ? 0) >= (cfg[\runtime][\maxHeldNotesBeforeFreezeSafe] ? 10);
        overrunRisk = (rt[\lastTickDuration] ? 0.0) > (cfg[\runtime][\overrunSeconds] ? 0.18);
        shouldDefer = false;

        if(mode == \freezeSafe) {
            if(recentInputAge < (cfg[\runtime][\recentInputWindow] ? 0.18)) { shouldDefer = true; };
            if(denseInput) { shouldDefer = true; };
            if(manyHeld) { shouldDefer = true; };
            if(overrunRisk) { shouldDefer = true; };
        };

        if(mode == \realtimeSafe) {
            if((cfg[\runtime][\skipFieldDuringDenseInput] ? true) and: { denseInput }) { shouldDefer = true; };
            if((cfg[\runtime][\skipFieldOnOverrun] ? true) and: { overrunRisk }) { shouldDefer = true; };
        };

        if(shouldDefer and: { record == true }) {
            rt[\deferredFieldTickCount] = (rt[\deferredFieldTickCount] ? 0) + 1;
            rt[\lastWatchdogIntervention] = \deferredFieldTick;
            rt[\lastWatchdogAt] = now;
        };
        shouldDefer;
    };

    at[\runtimeProtectedTick] = {
        var rt, start, duration, deferField;
        rt = at[\runtimeEnsureState].();
        if((rt[\enabled] ? true).not) {
            nil;
        } {
            if(rt[\inTick] == true) {
                rt[\reentrantSkipCount] = (rt[\reentrantSkipCount] ? 0) + 1;
                rt[\lastWatchdogIntervention] = \reentrantTickSkipped;
                rt[\lastWatchdogAt] = Main.elapsedTime;
                nil;
            } {
                rt[\inTick] = true;
                start = Main.elapsedTime;
                rt[\tickCount] = (rt[\tickCount] ? 0) + 1;
                rt[\lastTickAt] = start;

                if(cfg[\mic][\enabled]) {
                    if(at[\micStep].notNil) { at[\micStep].(); };
                };

                deferField = at[\runtimeShouldDeferFieldTick].(true);
                if(deferField.not) {
                    if(at[\fieldTick].notNil) { at[\fieldTick].(); };
                } {
                    st[\targetUpdatedByTick] = false;
                    st[\lastFieldAction] = \runtimeDeferred;
                };

                if(at[\motionStepToTarget].notNil and: { st[\motionActive] == true }) {
                    at[\motionStepToTarget].();
                };

                if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };

                duration = Main.elapsedTime - start;
                at[\runtimeRecordDuration].(duration);
                rt[\inTick] = false;
                duration;
            };
        };
    };

    oldStart = at[\start];
    oldStop = at[\stop];

    at[\start] = {
        var rt;
        rt = at[\runtimeEnsureState].();
        if(st[\controlRoutine].notNil) {
            st[\controlRoutine].stop;
            st[\controlRoutine] = nil;
        };
        at[\pushBuses].();
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
        st[\controlRoutine] = Routine({
            inf.do {
                at[\runtimeProtectedTick].();
                at[\runtimeTickSeconds].().wait;
            };
        }).play(SystemClock);
        st[\runtimeRunning] = true;
        rt[\running] = true;
        rt[\startedAt] = Main.elapsedTime;
        diag[\log].("runtime start mode=" ++ (rt[\mode] ? \realtimeSafe).asString ++ " tick=" ++ at[\runtimeTickSeconds].().asString);
        nil;
    };

    at[\stop] = {
        var rt;
        rt = at[\runtimeEnsureState].();
        if(st[\controlRoutine].notNil) {
            st[\controlRoutine].stop;
            st[\controlRoutine] = nil;
        };
        st[\runtimeRunning] = false;
        rt[\running] = false;
        rt[\stoppedAt] = Main.elapsedTime;
        rt[\inTick] = false;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
        nil;
    };

    at[\runtimeApplyModeSideEffects] = { |mode|
        var rt;
        rt = at[\runtimeEnsureState].();
        if(rt[\savedPostMidiEvents].isNil) { rt[\savedPostMidiEvents] = cfg[\input][\postMidiEvents] ? true; };
        if(rt[\savedUiFps].isNil) { rt[\savedUiFps] = cfg[\ui][\fps] ? 14; };

        if(mode == \diagnostic) {
            cfg[\input][\postMidiEvents] = rt[\savedPostMidiEvents] ? true;
            cfg[\ui][\fps] = rt[\savedUiFps] ? 14;
        } {
            cfg[\input][\postMidiEvents] = cfg[\runtime][\postMidiEventsInRealtimeSafe] ? false;
            if(mode == \freezeSafe) {
                cfg[\ui][\fps] = (cfg[\runtime][\uiFpsFreezeSafe] ? 7).min(rt[\savedUiFps] ? 14);
            } {
                cfg[\ui][\fps] = (cfg[\runtime][\uiFpsRealtimeSafe] ? 10).min(rt[\savedUiFps] ? 14);
            };
        };
        nil;
    };

    api[\setRuntimePerformanceMode] = { |mode=\realtimeSafe|
        var rt, chosen, valid;
        rt = at[\runtimeEnsureState].();
        valid = [\diagnostic, \realtimeSafe, \freezeSafe].includes(mode);
        chosen = if(valid) { mode } { \realtimeSafe };
        rt[\mode] = chosen;
        st[\runtimePerformanceMode] = chosen;
        cfg[\runtime][\performanceMode] = chosen;
        at[\runtimeApplyModeSideEffects].(chosen);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
        chosen;
    };

    api[\stopRuntime] = {
        at[\stop].();
        st;
    };

    api[\restartRuntime] = {
        at[\stop].();
        at[\start].();
        st;
    };

    oldNoteOn = at[\noteOn];
    oldNoteOff = at[\noteOff];
    oldSustainRelease = at[\removeInactiveSustainNotes];

    if(oldNoteOn.notNil) {
        at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
            at[\runtimeStampInput].(\noteOn);
            oldNoteOn.value(midi, velocity, explicitFreq, suppressVoice);
        };
    };

    if(oldNoteOff.notNil) {
        at[\noteOff] = { |midi|
            at[\runtimeStampInput].(\noteOff);
            oldNoteOff.value(midi);
        };
    };

    if(oldSustainRelease.notNil) {
        at[\removeInactiveSustainNotes] = {
            at[\runtimeStampInput].(\sustainRelease);
            oldSustainRelease.value;
        };
    };

    api[\runtimePerformanceSnapshot] = {
        var rt, now, hist, activeVoiceCount, activeNoteCount, sampleVoiceLikely, serverRunning, recentInputAge;
        rt = at[\runtimeEnsureState].();
        now = Main.elapsedTime;
        hist = rt[\recentDurations] ? List.new;
        activeVoiceCount = if(st[\voices].notNil) { st[\voices].size } { 0 };
        activeNoteCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
        sampleVoiceLikely = if(st[\lastVoiceSpawn].notNil) {
            [\atvoice_piano_sample, \atvoice_electric_piano_sample].includes(st[\lastVoiceSpawn][\defName]);
        } { false };
        serverRunning = if(s.notNil) { s.serverRunning } { false };
        recentInputAge = if(rt[\lastInputAt].isNil) { nil } { now - rt[\lastInputAt] };
        (
            runtimeEnabled: rt[\enabled] ? true,
            runtimeRunning: st[\runtimeRunning] ? false,
            performanceMode: rt[\mode] ? \realtimeSafe,
            tickSeconds: at[\runtimeTickSeconds].(),
            snapshotMinInterval: at[\runtimeSnapshotMinInterval].(),
            tickCount: rt[\tickCount] ? 0,
            lastTickDuration: rt[\lastTickDuration] ? 0.0,
            recentMeanDuration: rt[\recentMeanDuration] ? 0.0,
            recentMaxDuration: rt[\recentMaxDuration] ? 0.0,
            durationHistoryCount: hist.size,
            overrunCount: rt[\overrunCount] ? 0,
            dangerCount: rt[\dangerCount] ? 0,
            reentrantSkipCount: rt[\reentrantSkipCount] ? 0,
            deferredFieldTickCount: rt[\deferredFieldTickCount] ? 0,
            backlogRisk: ((rt[\recentMaxDuration] ? 0.0) > (cfg[\runtime][\overrunSeconds] ? 0.18)) or: { (rt[\reentrantSkipCount] ? 0) > 0 },
            uiRefreshInterval: 1.0 / ((cfg[\ui][\fps] ? 10).max(1)),
            uiFps: cfg[\ui][\fps] ? 10,
            snapshotCount: rt[\snapshotCount] ? 0,
            snapshotThrottleCount: rt[\snapshotThrottleCount] ? 0,
            midiEventRate: rt[\midiEventRate] ? 0,
            recentInputAge: recentInputAge,
            activeVoiceCount: activeVoiceCount,
            sampleVoiceCount: if(sampleVoiceLikely) { activeVoiceCount } { 0 },
            activeNoteCount: activeNoteCount,
            heldMidiCount: activeNoteCount,
            micMonitorActive: cfg[\mic][\enabled] ? false,
            expensiveDiagnosticsActive: false,
            lastWatchdogIntervention: rt[\lastWatchdogIntervention] ? \none,
            lastWatchdogAt: rt[\lastWatchdogAt],
            stuckNoteCount: activeNoteCount - activeVoiceCount,
            serverRunning: serverRunning,
            powerEnabled: st[\powerEnabled] ? true,
            spawnVoicesEnabled: st[\spawnVoicesEnabled] ? true,
            postMidiEvents: cfg[\input][\postMidiEvents] ? false,
            fieldAction: st[\lastFieldAction] ? \none
        )
    };

    api[\runtimePerformanceReadinessReport] = {
        var snap, ready, warningLoad, dangerFreeze, diagnosticsTooExpensive, uiTooFast, micTooExpensive, samplePressure, stuck;
        snap = api[\runtimePerformanceSnapshot].();
        warningLoad = (snap[\recentMaxDuration] ? 0.0) > (cfg[\runtime][\overrunSeconds] ? 0.18);
        dangerFreeze = (snap[\recentMaxDuration] ? 0.0) > (cfg[\runtime][\dangerSeconds] ? 0.35);
        diagnosticsTooExpensive = (snap[\postMidiEvents] ? false) == true;
        uiTooFast = (snap[\uiFps] ? 10) > 14;
        micTooExpensive = (snap[\micMonitorActive] ? false) and: { (snap[\performanceMode] ? \realtimeSafe) != \diagnostic };
        samplePressure = (snap[\activeVoiceCount] ? 0) > 12;
        stuck = (snap[\stuckNoteCount] ? 0) > 0;
        ready = warningLoad.not and: { dangerFreeze.not and: { diagnosticsTooExpensive.not and: { samplePressure.not and: { stuck.not } } } };
        (
            readyForRealPlay: ready,
            warningRuntimeLoad: warningLoad,
            dangerFreezeRisk: dangerFreeze,
            diagnosticsTooExpensiveForLive: diagnosticsTooExpensive,
            uiRefreshTooFast: uiTooFast,
            micMonitoringTooExpensive: micTooExpensive,
            sampleVoicePressureHigh: samplePressure,
            stuckNotesPresent: stuck,
            snapshot: snap
        )
    };

    api[\runtimeFreezeSafeDecisionSnapshot] = {
        var rt, now, recentInputAge;
        rt = at[\runtimeEnsureState].();
        now = Main.elapsedTime;
        recentInputAge = if(rt[\lastInputAt].isNil) { nil } { now - rt[\lastInputAt] };
        (
            performanceMode: rt[\mode] ? \realtimeSafe,
            recentInputAge: recentInputAge,
            midiEventRate: rt[\midiEventRate] ? 0,
            activeNoteCount: if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 },
            lastTickDuration: rt[\lastTickDuration] ? 0.0,
            wouldDeferFieldTickNow: at[\runtimeShouldDeferFieldTick].(false),
            deferredFieldTickCount: rt[\deferredFieldTickCount] ? 0,
            lastWatchdogIntervention: rt[\lastWatchdogIntervention] ? \none
        )
    };

    api[\setRuntimePerformanceMode].(cfg[\runtime][\performanceMode] ? \realtimeSafe);

    ("[at-runtime] v29 real-play runtime hardening loaded; default performance mode=" ++ (st[\runtimePerformanceMode] ? \realtimeSafe).asString).postln;
    ("[at-runtime] use Library.at(\\at)[\\api][\\runtimePerformanceSnapshot].() and [\\runtimePerformanceReadinessReport].()").postln;
};
)
