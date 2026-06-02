(
// AT_real_play_fast_path.scd
// v46: hard realtime gesture fast path + release-quiescence latch, with active Motion movement allowed.
//
// The latency profiler proved the live bottleneck is not audio voice spawning,
// noteOff, UI refresh, mic, or bus pushes.  It is heavy fieldTick -> solve work
// and heavy field solving during active play.  This layer keeps the existing
// harmonic law, topology guard, spacing guard, mic policy, samples, and tone
// engines intact, but changes WHEN expensive work is allowed to run.
//
// Musical policy: sound first, preserve the last safe keyboard surface, and run
// deeper coherence solving after the attack / during small idle windows.  This is
// bounded coherence, not impossible perfect harmony on every frame.

var build, at, cfg, st, api, diag;

build = ~atBuild;
if(build.isNil) {
    "[AT REAL PLAY FAST PATH] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];

    if(cfg[\realPlayFastPath].isNil) {
        cfg[\realPlayFastPath] = (
            enabled: true,
            liveMidiEventWindow: 0.065,
            // Hard realtime policy: a human phrase is not idle merely because
            // 180 ms passed.  Full solves are held until notes are released and
            // the gesture has been quiet long enough.
            activeInputDeferWindow: 0.75,
            idleSolveWindow: 1.0,
            motionThrottleWindow: 0.75,
            motionThrottleEvery: 4,
            suppressMotionWhileActive: false,
            earlyVoiceSpawn: true,
            deferFieldTickSolves: true,
            throttleMotionSteps: true,
            deferLiveCorePathCommits: true,
            quietLiveGuardPosts: true,
            uiActiveRefreshDt: 0.08,
            releaseQuiescenceWindow: 0.42,
            releaseFreezeOnAllNotesOff: true,
            releaseQuiescenceSuppressFieldTick: true,
            releaseQuiescenceSuppressMotion: true
        );
    };

    if(st[\realPlayFastPath].isNil) { st[\realPlayFastPath] = IdentityDictionary.new; };
    st[\realPlayFastPath][\branch] = \v46_motion_visible_realtime_fast_path;
    st[\realPlayFastPath][\installedAt] = Main.elapsedTime;
    st[\realPlayFastPath][\deferredFieldTicks] = st[\realPlayFastPath][\deferredFieldTicks] ? 0;
    st[\realPlayFastPath][\throttledMotionSteps] = st[\realPlayFastPath][\throttledMotionSteps] ? 0;
    st[\realPlayFastPath][\earlyVoiceSpawns] = st[\realPlayFastPath][\earlyVoiceSpawns] ? 0;
    st[\realPlayFastPath][\motionCounter] = st[\realPlayFastPath][\motionCounter] ? 0;
    st[\realPlayFastPath][\releaseQuiescenceEntries] = st[\realPlayFastPath][\releaseQuiescenceEntries] ? 0;
    st[\realPlayFastPath][\releaseDeferredFieldTicks] = st[\realPlayFastPath][\releaseDeferredFieldTicks] ? 0;
    st[\realPlayFastPath][\releaseMotionFreezes] = st[\realPlayFastPath][\releaseMotionFreezes] ? 0;
    st[\realPlayFastPath][\liveCorePathDeferrals] = st[\realPlayFastPath][\liveCorePathDeferrals] ? 0;
    st[\realPlayFastPath][\activeFieldTickDeferrals] = st[\realPlayFastPath][\activeFieldTickDeferrals] ? 0;
    st[\realPlayFastPath][\activeMotionSuppressions] = st[\realPlayFastPath][\activeMotionSuppressions] ? 0;

    // Live-play log quieting.  The guard still acts and reports counts; repeated
    // coreFreePath posts should not steal language-thread time while playing.
    if((cfg[\pitchIdentitySpacingGuard].notNil) and: { (cfg[\realPlayFastPath][\quietLiveGuardPosts] ? true) == true }) {
        var reasons;
        reasons = (cfg[\pitchIdentitySpacingGuard][\quietPostReasons] ? Array.new).copy;
        [\coreFreePath, \fastPathCorePathDeferred, \fastPathDeferred, \fastPathActiveDeferred, \fastPathMotionThrottle, \releaseQuiescence].do { |r|
            if(reasons.includes(r).not) { reasons = reasons.add(r); };
        };
        cfg[\pitchIdentitySpacingGuard][\quietPostReasons] = reasons;
    };

    at[\realPlayFastPathIsEnabled] = {
        (cfg[\realPlayFastPath][\enabled] ? true) == true
    };

    at[\realPlayFastPathIsRecentMidiEvent] = { |midi=nil, kind=\noteOn|
        var ev, now, win, ok;
        ev = st[\lastMidiEvent];
        now = Main.elapsedTime;
        win = cfg[\realPlayFastPath][\liveMidiEventWindow] ? 0.065;
        ok = ev.notNil
            and: { ev[\type] == kind }
            and: { midi.isNil or: { ev[\num] == midi } }
            and: { (now - (ev[\timestamp] ? 0.0)) <= win };
        ok;
    };

    at[\realPlayFastPathMarkInput] = { |midi=nil, kind=\noteOn|
        var now;
        now = Main.elapsedTime;
        st[\realPlayFastPath][\lastLiveInputAt] = now;
        st[\realPlayFastPath][\lastLiveInputKind] = kind;
        st[\realPlayFastPath][\lastLiveMidi] = midi;
        st[\realPlayFastPath][\liveInputCount] = (st[\realPlayFastPath][\liveInputCount] ? 0) + 1;
        st[\realPlayFastPath][\motionCounter] = 0;
        now;
    };

    at[\realPlayFastPathRecentlyActive] = { |window=nil|
        var last, now, win;
        last = st[\realPlayFastPath][\lastLiveInputAt];
        if(last.isNil) {
            false;
        } {
            now = Main.elapsedTime;
            win = window ? (cfg[\realPlayFastPath][\activeInputDeferWindow] ? 0.18);
            (now - last) <= win;
        }
    };


    at[\realPlayFastPathHasActiveMidi] = {
        st[\activeNotes].notNil and: { st[\activeNotes].size > 0 }
    };

    at[\realPlayFastPathGestureIsLive] = { |window=nil|
        var win;
        win = window ? (cfg[\realPlayFastPath][\idleSolveWindow] ? (cfg[\realPlayFastPath][\activeInputDeferWindow] ? 0.75));
        at[\realPlayFastPathHasActiveMidi].() or: { at[\realPlayFastPathRecentlyActive].(win) } or: { at[\realPlayFastPathInReleaseQuiescence].(cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.42) };
    };

    at[\realPlayFastPathShouldDeferCorePathCommit] = { |midi=nil, pc=nil|
        at[\realPlayFastPathIsEnabled].()
            and: { (cfg[\realPlayFastPath][\deferLiveCorePathCommits] ? true) == true }
            and: { at[\realPlayFastPathRecentlyActive].(cfg[\realPlayFastPath][\activeInputDeferWindow] ? 0.75) }
    };

    at[\realPlayFastPathDeferredCorePathRecord] = { |midi, pc, prevCount=0, now=nil|
        var phase, u, rec, hist;
        now = now ? Main.elapsedTime;
        at[\ensureCoreUnwrapped].();
        phase = st[\nodePhase][pc];
        u = st[\coreUnwrappedPhase][pc] ? phase;
        rec = (
            timestamp: now,
            midi: midi,
            pc: pc,
            prevCount: prevCount,
            audiblePhase: phase,
            desiredUnwrappedPhase: u,
            audibleDevCents: at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0,
            sheetDevCents: (u - st[\etPhase][pc]) * 1200.0,
            applied: false,
            deferred: true,
            reason: \fastPathCorePathDeferred
        );
        st[\lastCoreTransport] = rec;
        st[\lastCorePathOnset] = (timestamp: now, midi: midi, pc: pc, phase: phase, unwrappedPhase: u);
        hist = st[\coreTransportHistory] ? Array.new;
        hist = hist.add(rec);
        if(hist.size > 64) { hist = hist.copyRange(hist.size - 64, hist.size - 1); };
        st[\coreTransportHistory] = hist;
        st[\realPlayFastPath][\liveCorePathDeferrals] = (st[\realPlayFastPath][\liveCorePathDeferrals] ? 0) + 1;
        rec;
    };

    at[\realPlayFastPathInReleaseQuiescence] = { |window=nil|
        var last, now, win, activeCount;
        last = st[\realPlayFastPath][\lastAllNotesOffAt];
        if(last.isNil) {
            false;
        } {
            now = Main.elapsedTime;
            win = window ? (cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.26);
            activeCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
            (activeCount <= 0) and: { (now - last) <= win };
        }
    };

    at[\realPlayFastPathFreezeCurrentForRelease] = { |reason=\releaseQuiescence|
        var phase, unwrapped;
        phase = (st[\nodePhase] ? st[\etPhase]).copy;
        unwrapped = (st[\coreUnwrappedPhase] ? phase).copy;
        st[\targetPhase] = phase.copy;
        st[\lastSolvedPhase] = phase.copy;
        st[\targetCoreUnwrappedPhase] = unwrapped.copy;
        st[\targetValid] = false;
        st[\motionActive] = false;
        st[\lastFieldAction] = reason;
        if(at[\clearDescriptors].notNil) { at[\clearDescriptors].(); };
        if(at[\pushBuses].notNil) { at[\pushBuses].(); };
        phase;
    };

    at[\realPlayFastPathMarkRelease] = { |midi=nil, beforeCount=0, afterCount=0, kind=\noteOff|
        var now;
        now = Main.elapsedTime;
        st[\realPlayFastPath][\lastReleaseAt] = now;
        st[\realPlayFastPath][\lastReleaseMidi] = midi;
        st[\realPlayFastPath][\lastReleaseKind] = kind;
        st[\realPlayFastPath][\lastReleaseBeforeCount] = beforeCount;
        st[\realPlayFastPath][\lastReleaseAfterCount] = afterCount;
        if((afterCount <= 0) and: { (cfg[\realPlayFastPath][\releaseFreezeOnAllNotesOff] ? true) == true }) {
            st[\realPlayFastPath][\lastAllNotesOffAt] = now;
            st[\realPlayFastPath][\releaseQuiescenceEntries] = (st[\realPlayFastPath][\releaseQuiescenceEntries] ? 0) + 1;
            at[\realPlayFastPathFreezeCurrentForRelease].(\releaseQuiescence);
        };
        now;
    };

    at[\realPlayFastPathReleaseQuiescenceTick] = {
        var now;
        now = Main.elapsedTime;
        st[\fieldTickCount] = (st[\fieldTickCount] ? 0) + 1;
        st[\lastFieldTickAt] = now;
        st[\lastFieldHadEvidence] = false;
        st[\targetUpdatedByTick] = false;
        st[\lastFieldAction] = \releaseQuiescence;
        st[\realPlayFastPath][\releaseDeferredFieldTicks] = (st[\realPlayFastPath][\releaseDeferredFieldTicks] ? 0) + 1;
        nil;
    };

    at[\realPlayFastPathShouldUseEarlyVoice] = { |midi, suppressVoice=false|
        at[\realPlayFastPathIsEnabled].()
            and: { (cfg[\realPlayFastPath][\earlyVoiceSpawn] ? true) == true }
            and: { suppressVoice.not }
            and: { at[\realPlayFastPathIsRecentMidiEvent].(midi, \noteOn) };
    };

    at[\realPlayFastPathShouldMarkLiveInput] = { |midi, kind=\noteOn|
        at[\realPlayFastPathIsEnabled].() and: { at[\realPlayFastPathIsRecentMidiEvent].(midi, kind) };
    };

    at[\realPlayFastPathShouldDeferFieldTick] = {
        var active, recent, hasEvidence, liveGesture;
        if(at[\realPlayFastPathIsEnabled].().not or: { (cfg[\realPlayFastPath][\deferFieldTickSolves] ? true).not }) {
            false;
        } {
            active = at[\realPlayFastPathHasActiveMidi].();
            recent = at[\realPlayFastPathRecentlyActive].(cfg[\realPlayFastPath][\idleSolveWindow] ? 1.0);
            liveGesture = active or: { recent } or: { at[\realPlayFastPathInReleaseQuiescence].(cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.42) };
            hasEvidence = active or: { ((st[\externalSources] ? Array.new).notEmpty) };
            hasEvidence and: { liveGesture };
        }
    };

    at[\realPlayFastPathCheapEvidenceTick] = {
        var ev, now, hasEvidence;
        ev = if(at[\collectEvidence].notNil) { at[\collectEvidence].() } { nil };
        now = Main.elapsedTime;
        if(ev.notNil) {
            hasEvidence = (ev[\hasMidi] ? false) or: { ev[\hasExternal] ? false };
            st[\lastEvidence] = ev;
            st[\lastFieldHadEvidence] = hasEvidence;
            if(st[\lastEvidenceKey].isNil) { st[\lastEvidenceKey] = ev[\key]; };
            if(ev[\key] != st[\lastEvidenceKey]) {
                st[\lastEvidenceKey] = ev[\key];
                st[\evidenceDirty] = true;
                st[\evidenceDirtyReason] = \fastPathDeferredEvidenceChanged;
                st[\evidenceDirtyAt] = now;
            };
        };
        st[\fieldTickCount] = (st[\fieldTickCount] ? 0) + 1;
        st[\lastFieldTickAt] = now;
        st[\targetUpdatedByTick] = false;
        if(at[\realPlayFastPathHasActiveMidi].()) {
            st[\lastFieldAction] = \fastPathActiveDeferred;
            st[\realPlayFastPath][\activeFieldTickDeferrals] = (st[\realPlayFastPath][\activeFieldTickDeferrals] ? 0) + 1;
        } {
            st[\lastFieldAction] = \fastPathDeferred;
        };
        st[\realPlayFastPath][\deferredFieldTicks] = (st[\realPlayFastPath][\deferredFieldTicks] ? 0) + 1;
        ev;
    };

    at[\realPlayFastPathShouldThrottleMotion] = { |force=false|
        var recent, active, n, counter;
        if(force == true) {
            false;
        } {
            if(at[\realPlayFastPathIsEnabled].().not or: { (cfg[\realPlayFastPath][\throttleMotionSteps] ? true).not }) {
                false;
            } {
                active = at[\realPlayFastPathHasActiveMidi].();
                if(active and: { (cfg[\realPlayFastPath][\suppressMotionWhileActive] ? true) == true }) {
                    st[\realPlayFastPath][\activeMotionSuppressions] = (st[\realPlayFastPath][\activeMotionSuppressions] ? 0) + 1;
                    true;
                } {
                    recent = at[\realPlayFastPathRecentlyActive].(cfg[\realPlayFastPath][\motionThrottleWindow] ? 0.75);
                    if(recent.not) {
                        false;
                    } {
                        n = (cfg[\realPlayFastPath][\motionThrottleEvery] ? 12).asInteger.max(1);
                        counter = (st[\realPlayFastPath][\motionCounter] ? 0) + 1;
                        st[\realPlayFastPath][\motionCounter] = counter;
                        (counter % n) != 0;
                    }
                }
            }
        }
    };

    at[\realPlayFastPathInstall] = {
        var fp;
        fp = st[\realPlayFastPath];
        if((fp[\wrapped] ? false).not) {
            if(at[\prepareCorePathOnset].notNil) {
                fp[\originalPrepareCorePathOnset] = at[\prepareCorePathOnset];
                at[\prepareCorePathOnset] = { |midi, pc, prevCount=0, now=nil|
                    if(at[\realPlayFastPathShouldDeferCorePathCommit].(midi, pc)) {
                        at[\realPlayFastPathDeferredCorePathRecord].(midi, pc, prevCount, now);
                    } {
                        fp[\originalPrepareCorePathOnset].(midi, pc, prevCount, now);
                    }
                };
            };

            if(at[\noteOn].notNil) {
                fp[\originalNoteOn] = at[\noteOn];
                at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
                    var live, early, result;
                    live = at[\realPlayFastPathShouldMarkLiveInput].(midi, \noteOn);
                    if(live) { at[\realPlayFastPathMarkInput].(midi, \noteOn); };
                    early = at[\realPlayFastPathShouldUseEarlyVoice].(midi, suppressVoice);
                    if(early and: { st[\voices][midi].isNil }) {
                        at[\spawnVoice].(midi, velocity.clip(0.0, 1.0));
                        st[\realPlayFastPath][\earlyVoiceSpawns] = (st[\realPlayFastPath][\earlyVoiceSpawns] ? 0) + 1;
                    };
                    result = fp[\originalNoteOn].(midi, velocity, explicitFreq, if(early) { true } { suppressVoice });
                    result;
                };
            };

            if(at[\noteOff].notNil) {
                fp[\originalNoteOff] = at[\noteOff];
                at[\noteOff] = { |midi|
                    var beforeCount, result, afterCount;
                    beforeCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
                    if(at[\realPlayFastPathShouldMarkLiveInput].(midi, \noteOff)) { at[\realPlayFastPathMarkInput].(midi, \noteOff); };
                    result = fp[\originalNoteOff].(midi);
                    afterCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
                    if(beforeCount > afterCount) { at[\realPlayFastPathMarkRelease].(midi, beforeCount, afterCount, \noteOff); };
                    result;
                };
            };

            if(at[\removeInactiveSustainNotes].notNil) {
                fp[\originalRemoveInactiveSustainNotes] = at[\removeInactiveSustainNotes];
                at[\removeInactiveSustainNotes] = {
                    var beforeCount, result, afterCount;
                    beforeCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
                    result = fp[\originalRemoveInactiveSustainNotes].();
                    afterCount = if(st[\activeNotes].notNil) { st[\activeNotes].size } { 0 };
                    if(beforeCount > afterCount) { at[\realPlayFastPathMarkRelease].(nil, beforeCount, afterCount, \sustainRelease); };
                    result;
                };
            };

            if(at[\fieldTick].notNil) {
                fp[\originalFieldTick] = at[\fieldTick];
                at[\fieldTick] = {
                    if(at[\realPlayFastPathInReleaseQuiescence].(cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.26)
                        and: { (cfg[\realPlayFastPath][\releaseQuiescenceSuppressFieldTick] ? true) == true }) {
                        at[\realPlayFastPathReleaseQuiescenceTick].();
                    } {
                        if(at[\realPlayFastPathShouldDeferFieldTick].()) {
                            at[\realPlayFastPathCheapEvidenceTick].();
                        } {
                            fp[\originalFieldTick].();
                        }
                    }
                };
            };

            if(at[\motionStepToTarget].notNil) {
                fp[\originalMotionStepToTarget] = at[\motionStepToTarget];
                at[\motionStepToTarget] = { |force=false|
                    if((force != true) and: { at[\realPlayFastPathInReleaseQuiescence].(cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.26) }
                        and: { (cfg[\realPlayFastPath][\releaseQuiescenceSuppressMotion] ? true) == true }) {
                        st[\realPlayFastPath][\releaseMotionFreezes] = (st[\realPlayFastPath][\releaseMotionFreezes] ? 0) + 1;
                        false;
                    } {
                        if(at[\realPlayFastPathShouldThrottleMotion].(force)) {
                            st[\realPlayFastPath][\throttledMotionSteps] = (st[\realPlayFastPath][\throttledMotionSteps] ? 0) + 1;
                            false;
                        } {
                            fp[\originalMotionStepToTarget].(force);
                        }
                    }
                };
                at[\motionStep] = { at[\motionStepToTarget].() };
            };
            fp[\wrapped] = true;
        };
        fp[\wrapped];
    };

    api[\setRealPlayFastPathEnabled] = { |enabled=true|
        cfg[\realPlayFastPath][\enabled] = enabled == true;
        api[\realPlayFastPathReport].(true);
    };

    api[\realPlayFastPathResetCounters] = {
        st[\realPlayFastPath][\deferredFieldTicks] = 0;
        st[\realPlayFastPath][\throttledMotionSteps] = 0;
        st[\realPlayFastPath][\earlyVoiceSpawns] = 0;
        st[\realPlayFastPath][\liveInputCount] = 0;
        st[\realPlayFastPath][\motionCounter] = 0;
        st[\realPlayFastPath][\releaseQuiescenceEntries] = 0;
        st[\realPlayFastPath][\releaseDeferredFieldTicks] = 0;
        st[\realPlayFastPath][\releaseMotionFreezes] = 0;
        st[\realPlayFastPath][\liveCorePathDeferrals] = 0;
        st[\realPlayFastPath][\activeFieldTickDeferrals] = 0;
        st[\realPlayFastPath][\activeMotionSuppressions] = 0;
        st[\realPlayFastPath][\lastLiveInputAt] = nil;
        st[\realPlayFastPath][\lastReleaseAt] = nil;
        st[\realPlayFastPath][\lastAllNotesOffAt] = nil;
        true;
    };

    api[\realPlayFastPathReport] = { |post=true|
        var fp, report;
        fp = st[\realPlayFastPath];
        report = (
            branch: \v3D26c_hard_realtime_gesture_fast_path,
            role: \soundFirstHardRealtimeGestureScheduler,
            enabled: cfg[\realPlayFastPath][\enabled] ? true,
            wrapped: fp[\wrapped] ? false,
            earlyVoiceSpawns: fp[\earlyVoiceSpawns] ? 0,
            deferredFieldTicks: fp[\deferredFieldTicks] ? 0,
            throttledMotionSteps: fp[\throttledMotionSteps] ? 0,
            releaseQuiescenceEntries: fp[\releaseQuiescenceEntries] ? 0,
            releaseDeferredFieldTicks: fp[\releaseDeferredFieldTicks] ? 0,
            releaseMotionFreezes: fp[\releaseMotionFreezes] ? 0,
            liveCorePathDeferrals: fp[\liveCorePathDeferrals] ? 0,
            activeFieldTickDeferrals: fp[\activeFieldTickDeferrals] ? 0,
            activeMotionSuppressions: fp[\activeMotionSuppressions] ? 0,
            inReleaseQuiescence: at[\realPlayFastPathInReleaseQuiescence].(cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.26),
            liveInputCount: fp[\liveInputCount] ? 0,
            activeInputDeferWindow: cfg[\realPlayFastPath][\activeInputDeferWindow] ? 0.75,
            idleSolveWindow: cfg[\realPlayFastPath][\idleSolveWindow] ? 1.0,
            releaseQuiescenceWindow: cfg[\realPlayFastPath][\releaseQuiescenceWindow] ? 0.26,
            motionThrottleEvery: cfg[\realPlayFastPath][\motionThrottleEvery] ? 3,
            pitchAuthority: false,
            topologyAuthority: false,
            spacingThresholdChange: false,
            behaviorChange: true,
            intent: "bounded coherence, not impossible perfect harmony on every frame; sound first, defer live core-path commits, and allow full solves only after the gesture is idle"
        );
        fp[\lastReport] = report;
        if(post == true) {
            "".postln;
            "[AT REAL PLAY FAST PATH REPORT]".postln;
            ("enabled=" ++ report[\enabled].asString
                ++ " wrapped=" ++ report[\wrapped].asString
                ++ " earlyVoiceSpawns=" ++ report[\earlyVoiceSpawns].asString
                ++ " deferredFieldTicks=" ++ report[\deferredFieldTicks].asString
                ++ " throttledMotionSteps=" ++ report[\throttledMotionSteps].asString
                ++ " releaseQuiescenceEntries=" ++ report[\releaseQuiescenceEntries].asString
                ++ " releaseDeferredFieldTicks=" ++ report[\releaseDeferredFieldTicks].asString
                ++ " releaseMotionFreezes=" ++ report[\releaseMotionFreezes].asString).postln;
            ("intent=" ++ report[\intent]).postln;
        };
        report;
    };

    api[\realPlayFastPathInstalled] = { (st[\realPlayFastPath][\wrapped] ? false) == true };

    api[\realPlayResponsivenessPlan] = {
        (
            branch: \v3D26c_hard_realtime_gesture_fast_path,
            role: \correctiveRuntimeSchedulingWithReleaseQuiescence,
            behaviorChange: true,
            pitchAuthority: false,
            topologyAuthority: false,
            spacingThresholdChange: false,
            strategy: [\earlyVoiceSpawn, \deferFieldTickSolvesDuringActiveInput, \throttleMotionStepDuringActiveInput, \releaseQuiescenceFreeze, \idleHeavySolve],
            intendedMusicalPolicy: "Correct as much as evidence and timing budget permit; hold/compromise when music is messy, contradictory, out-of-tune, or moving too fast."
        )
    };

    at[\realPlayFastPathInstall].();

    "[AT REAL PLAY FAST PATH] v46 loaded: hard-realtime sound-first/deferred-solve + release-quiescence scheduler installed; active Motion movement is allowed; no tone/sample/mic/cylinder/topology/spacing-threshold changes.".postln;
};
)
