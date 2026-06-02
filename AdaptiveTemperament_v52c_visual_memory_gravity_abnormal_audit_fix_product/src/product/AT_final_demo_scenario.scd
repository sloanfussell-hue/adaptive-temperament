
(
// AT_final_demo_scenario.scd
// v50 final demo external-scene-truth + log-hygiene product: preserves staged source roles through Ear/Coherence reports.
// This is not a regression suite and not a hidden proof harness.  The demo
// drives the same public runtime controls a player can use: Motion, Memory,
// Gravity, Ear, Tone, Adaptive Tone, Spectrum/Accordion amount, and normal
// note input.  The only non-player action is generating external reference
// sounds through the laptop speakers so the laptop microphone can hear them.

var build, at, cfg, st, api, demo;

build = ~atBuild;
if(build.isNil) {
    "[AT FINAL DEMO] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(st[\finalDemoScenario].isNil) { st[\finalDemoScenario] = IdentityDictionary.new; };
    demo = st[\finalDemoScenario];
    cfg[\finalDemo] = cfg[\finalDemo] ? IdentityDictionary.new;
    cfg[\finalDemo][\externalStimulusAmp] = cfg[\finalDemo][\externalStimulusAmp] ? 0.14;
    cfg[\finalDemo][\motionTickSeconds] = cfg[\finalDemo][\motionTickSeconds] ? 0.05;
    cfg[\finalDemo][\requireLiveEar] = cfg[\finalDemo][\requireLiveEar] ? true;
    cfg[\finalDemo][\hardwarePollSeconds] = cfg[\finalDemo][\hardwarePollSeconds] ? 2.2;
    cfg[\finalDemo][\hardwareMinLiveSources] = cfg[\finalDemo][\hardwareMinLiveSources] ? 1;
    cfg[\finalDemo][\hardwareMinConfidence] = cfg[\finalDemo][\hardwareMinConfidence] ? 0.12;
    cfg[\finalDemo][\capturePollSeconds] = cfg[\finalDemo][\capturePollSeconds] ? 1.25;
    cfg[\finalDemo][\captureToneSeconds] = cfg[\finalDemo][\captureToneSeconds] ? 1.65;
    cfg[\finalDemo][\capturedExternalHoldSeconds] = cfg[\finalDemo][\capturedExternalHoldSeconds] ? 4.0;
    cfg[\finalDemo][\adaptiveGravityFollowMode] = cfg[\finalDemo][\adaptiveGravityFollowMode] ? \earMemory;
    cfg[\finalDemo][\capturedSceneTruthMinSources] = cfg[\finalDemo][\capturedSceneTruthMinSources] ? 1;
    cfg[\finalDemo][\speakerEnergyIsInformational] = cfg[\finalDemo][\speakerEnergyIsInformational] ? true;

    SynthDef(\at_final_demo_external_tone, { |out=0, freq=440, amp=0.08, dur=1.0, pan=0|
        var env, sig;
        env = EnvGen.kr(Env.linen(0.03, dur, 0.16), doneAction:2);
        sig = SinOsc.ar(freq.max(20)) * amp * env;
        Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    SynthDef(\at_final_demo_external_singer, { |out=0, freq=440, amp=0.07, dur=1.0, pan=0, flatCents=(-27), vibCents=7, vibRate=5.2|
        var env, cents, sig;
        env = EnvGen.kr(Env.linen(0.05, dur, 0.22), doneAction:2);
        cents = flatCents + SinOsc.kr(vibRate, 0, vibCents);
        sig = SinOsc.ar(freq.max(20) * (2 ** (cents / 1200.0))) * amp * env;
        Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    SynthDef(\at_final_demo_external_inharmonic, { |out=0, freq=220, amp=0.07, dur=1.0, pan=0|
        var env, sig;
        env = EnvGen.kr(Env.linen(0.02, dur, 0.35), doneAction:2);
        sig = (SinOsc.ar(freq.max(20)) * 0.42)
            + (SinOsc.ar(freq.max(20) * 2.03) * 0.26)
            + (SinOsc.ar(freq.max(20) * 3.18) * 0.18)
            + (SinOsc.ar(freq.max(20) * 4.41) * 0.11)
            + (SinOsc.ar(freq.max(20) * 5.97) * 0.07);
        Out.ar(out, Pan2.ar(sig * amp * env, pan));
    }).add;

    at[\finalDemoStage] = { |index=0, title="stage", note=""|
        "".postln;
        "============================================================".postln;
        ("[AT FINAL DEMO " ++ index.asString ++ "] " ++ title.asString).postln;
        if(note.notNil and: { note.asString.size > 0 }) { note.asString.postln; };
        "============================================================".postln;
    };

    at[\finalDemoSay] = { |msg=""|
        ("[AT FINAL DEMO] " ++ msg.asString).postln;
    };

    at[\finalDemoCentsForPc] = { |pc=0|
        at[\wrapSigned].((st[\nodePhase][pc] ? 0.0) - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0;
    };

    at[\finalDemoCaptureField] = {
        (st[\nodePhase] ? st[\etPhase]).copy;
    };

    at[\finalDemoMoveCurrentOnly] = { |reason=\finalDemoMotionStep|
        if(at[\motionStepToTarget].notNil) { at[\motionStepToTarget].(false); };
        if(at[\pushBuses].notNil) { at[\pushBuses].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
    };

    at[\finalDemoOpenMotionForTrace] = { |motion=0.5|
        // For the performance trace only, open the same Motion value without
        // taking the setter's immediate first scheduling step. This keeps the
        // trace legible: target-known/frozen -> one step -> continued motion.
        st[\movement] = motion.asFloat.clip(0.0, 1.0);
        if(st[\macros].notNil) { st[\macros][\motion] = st[\movement]; };
        if(st[\targetPhase].notNil) { st[\motionActive] = true; };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        st[\movement]
    };

    at[\finalDemoFieldMovementTelemetry] = { |label=\fieldMovement, beforePhase=nil, watchPc=9, post=true|
        var n, before, current, target, activePcs, passivePcs, moved, targetFromBefore, activeMax, passiveMax, maxMove, meanMove, remaining, watch, rep, fp;
        n = cfg[\solver][\numNodes] ? 12;
        before = beforePhase ? (st[\nodePhase] ? st[\etPhase]).copy;
        current = (st[\nodePhase] ? before).copy;
        target = (st[\targetPhase] ? current).copy;
        watch = watchPc.asInteger.clip(0, n - 1);
        activePcs = if(at[\activePcsFromWeights].notNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { Array.new };
        passivePcs = (0..(n - 1)).select { |i| activePcs.includes(i).not };
        moved = Array.fill(n, { |i| at[\wrapSigned].((current[i] ? 0.0) - (before[i] ? 0.0)).abs * 1200.0 });
        targetFromBefore = Array.fill(n, { |i| at[\wrapSigned].((target[i] ? 0.0) - (before[i] ? 0.0)).abs * 1200.0 });
        activeMax = if(activePcs.isEmpty) { 0.0 } { (activePcs.collect { |i| moved[i] ? 0.0 }.maxItem ? 0.0) };
        passiveMax = if(passivePcs.isEmpty) { 0.0 } { (passivePcs.collect { |i| moved[i] ? 0.0 }.maxItem ? 0.0) };
        maxMove = moved.maxItem ? 0.0;
        meanMove = moved.sum / n.max(1);
        remaining = if(at[\motionTargetDistanceCents].notNil) { at[\motionTargetDistanceCents].().round(0.01) } { 0.0 };
        fp = st[\realPlayFastPath] ? IdentityDictionary.new;
        rep = (
            label: label,
            motion: (st[\movement] ? 0.0).round(0.001),
            targetKnown: st[\targetPhase].notNil,
            targetMaxFromBeforeCents: (targetFromBefore.maxItem ? 0.0).round(0.01),
            currentMaxMoveCents: maxMove.round(0.01),
            currentMeanMoveCents: meanMove.round(0.01),
            passiveMaxMoveCents: passiveMax.round(0.01),
            activeMaxMoveCents: activeMax.round(0.01),
            remainingTargetDistanceCents: remaining,
            activePcs: activePcs.copy,
            watchPc: watch,
            watchPcName: if(at[\pcName].notNil) { at[\pcName].(watch) } { watch.asString },
            watchCurrentDevCents: at[\finalDemoCentsForPc].(watch).round(0.01),
            watchMovedCents: (moved[watch] ? 0.0).round(0.01),
            realPlayActiveMotionSuppressions: fp[\activeMotionSuppressions] ? 0,
            realPlayThrottledMotionSteps: fp[\throttledMotionSteps] ? 0,
            note: "This reports current nodePhase movement, not just target construction. Active anchors may stay fixed while passive/silent pitch classes move."
        );
        demo[\lastMovementTelemetry] = rep;
        if(post) {
            "[AT FINAL DEMO MOVEMENT]".postln;
            ("label=" ++ label.asString
                ++ " motion=" ++ rep[\motion].asString
                ++ " currentMax=" ++ rep[\currentMaxMoveCents].asString ++ "c"
                ++ " passiveMax=" ++ rep[\passiveMaxMoveCents].asString ++ "c"
                ++ " activeMax=" ++ rep[\activeMaxMoveCents].asString ++ "c"
                ++ " remaining=" ++ rep[\remainingTargetDistanceCents].asString ++ "c"
                ++ " watch=" ++ rep[\watchPcName].asString ++ ":" ++ rep[\watchMovedCents].asString ++ "c").postln;
            rep.postln;
        };
        rep;
    };

    at[\finalDemoFieldSummary] = { |label=\summary, pc=0, post=true|
        var rep;
        rep = (
            label: label,
            motion: (st[\movement] ? 0.0).round(0.001),
            memoryAmount: (st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0)).round(0.001),
            memoryConfidence: (st[\memoryConfidence] ? 0.0).round(0.001),
            gravityEnabled: cfg[\gravity][\enabled] ? false,
            gravityStrength: (cfg[\gravity][\strength] ? 0.0).round(0.001),
            gravityHomePc: st[\gravityHomePc],
            gravityHomeCents: (st[\gravityHomeCents] ? 0.0).round(0.01),
            earEnabled: cfg[\mic][\enabled] ? false,
            spectrumAmount: if(cfg[\perceptualSpectrum].notNil) { (cfg[\perceptualSpectrum][\amount] ? 0.0).round(0.001) } { 0.0 },
            currentPc: pc,
            currentPcCents: at[\finalDemoCentsForPc].(pc).round(0.01),
            targetDistanceCents: if(at[\motionTargetDistanceCents].notNil) { at[\motionTargetDistanceCents].().round(0.01) } { 0.0 },
            pitchAuthorityAdded: false
        );
        demo[\lastSummary] = rep;
        if(post) { "[AT FINAL DEMO SUMMARY]".postln; rep.postln; };
        rep;
    };

    at[\finalDemoResolve] = { |reason=\finalDemo, force=false|
        if(api[\resolveNow].notNil) { api[\resolveNow].(reason); };
        if(at[\motionStepToTarget].notNil) { at[\motionStepToTarget].(force == true); };
        if(at[\pushBuses].notNil) { at[\pushBuses].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
    };

    at[\finalDemoAdvance] = { |seconds=0.5, reason=\finalDemoTick, tick=nil|
        var dt, steps, remain;
        dt = (tick ? (cfg[\finalDemo][\motionTickSeconds] ? 0.05)).asFloat.max(0.02);
        steps = (seconds.asFloat.max(0.0) / dt).ceil.asInteger.max(0);
        steps.do {
            at[\finalDemoMoveCurrentOnly].(reason);
            dt.wait;
        };
        remain = seconds.asFloat.max(0.0) - (steps * dt);
        if(remain > 0.001) { remain.wait; };
    };

    at[\finalDemoAllNotesOff] = {
        var keys;
        keys = if(st[\activeNotes].notNil) { st[\activeNotes].keys.asArray } { Array.new };
        keys.do { |midi| if(at[\noteOff].notNil) { at[\noteOff].(midi); }; };
        if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
        if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
        at[\finalDemoResolve].(\finalDemoAllNotesOff, false);
    };

    at[\finalDemoClearExternal] = {
        if(at[\updateCommittedExternalSources].notNil) { at[\updateCommittedExternalSources].(Array.new); };
        st[\externalSources] = Array.new;
        st[\micSceneAcceptedSources] = Array.new;
        if(at[\clearMicReleaseHold].notNil) { at[\clearMicReleaseHold].(\finalDemoClearExternal); };
    };

    at[\finalDemoReset] = { |motion=0.0|
        at[\finalDemoAllNotesOff].();
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
        at[\finalDemoClearExternal].();
        if(api[\clearTonalMemory].notNil) { api[\clearTonalMemory].(); };
        cfg[\memory][\enabled] = false;
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(0.0); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); };
        if(api[\setWorldScoringEnabled].notNil) { api[\setWorldScoringEnabled].(false); };
        cfg[\phrase] = cfg[\phrase] ? IdentityDictionary.new;
        cfg[\phrase][\enabled] = false;
        if(api[\setSignedCarry].notNil) { api[\setSignedCarry].(0.0); };
        if(api[\setPerceptualCoherenceAmount].notNil) { api[\setPerceptualCoherenceAmount].(0.0); };
        if(api[\setPerceptualSpectrumAmount].notNil) { api[\setPerceptualSpectrumAmount].(0.0); };
        if(api[\setPerceptualSpectrumProfile].notNil) { api[\setPerceptualSpectrumProfile].(\harmonic); };
        if(api[\setPerceptualCylinderAmount].notNil) { api[\setPerceptualCylinderAmount].(0.0); };
        if(api[\setPerceptualCylinderAccordionAuthorityEnabled].notNil) { api[\setPerceptualCylinderAccordionAuthorityEnabled].(false); };
        if(api[\setPerceptualCylinderRenderHookEnabled].notNil) { api[\setPerceptualCylinderRenderHookEnabled].(false); };
        if(api[\setToneProfile].notNil) { api[\setToneProfile].(\pure); };
        if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
        if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
        if(api[\setTension].notNil) { api[\setTension].(0.55); };
        if(api[\setMovement].notNil) { api[\setMovement].(motion); };
        if(at[\resetToET].notNil) { at[\resetToET].(); };
        at[\finalDemoResolve].(\finalDemoReset, true);
        at[\finalDemoFieldSummary].(\reset, 0, true);
    };

    at[\finalDemoSetCoreControls] = { |motion=0.5, memory=0.0, gravity=0.0, ear=false|
        if(api[\setMovement].notNil) { api[\setMovement].(motion); };
        cfg[\memory][\enabled] = memory.asFloat > 0.0001;
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(memory); };
        if(memory.asFloat <= 0.0001 and: { api[\clearTonalMemory].notNil }) { api[\clearTonalMemory].(); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(gravity.asFloat > 0.0001); };
        if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(gravity); };
        if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(2.0 + (gravity.asFloat.clip(0.0, 1.0) * 16.0)); };
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(ear == true); };
        if(api[\setSignedCarry].notNil) { api[\setSignedCarry].(0.0); };
        at[\finalDemoResolve].(\finalDemoControls, false);
    };

    at[\finalDemoPlayNote] = { |midi=60, dur=0.55, velocity=0.75, reason=\finalDemoNote|
        if(at[\noteOn].notNil) { at[\noteOn].(midi, velocity.clip(0.0, 1.0), nil, false); };
        at[\finalDemoResolve].(reason, false);
        at[\finalDemoAdvance].(dur, reason, nil);
        if(at[\noteOff].notNil) { at[\noteOff].(midi); };
        at[\finalDemoResolve].(\finalDemoNoteOff, false);
        0.05.wait;
    };

    at[\finalDemoChordOn] = { |midis, velocity=0.68, reason=\finalDemoChordOn|
        var arr, oldSuppress, oldReason;
        arr = midis ? Array.new;
        oldSuppress = st[\finalDemoChordBatchSuppressCorePath] ? false;
        oldReason = st[\finalDemoChordBatchNoTransportReason];
        if(arr.size > 1) {
            st[\finalDemoChordBatchSuppressCorePath] = true;
            st[\finalDemoChordBatchNoTransportReason] = \finalDemoChordBatchNoTransport;
        };
        arr.do { |midi| if(at[\noteOn].notNil) { at[\noteOn].(midi, velocity.clip(0.0, 1.0), nil, false); }; };
        st[\finalDemoChordBatchSuppressCorePath] = oldSuppress;
        st[\finalDemoChordBatchNoTransportReason] = oldReason;
        at[\finalDemoResolve].(reason, false);
    };

    at[\finalDemoChordOff] = { |midis=nil|
        var arr;
        arr = midis ? if(st[\activeNotes].notNil) { st[\activeNotes].keys.asArray } { Array.new };
        arr.do { |midi| if(at[\noteOff].notNil) { at[\noteOff].(midi); }; };
        at[\finalDemoResolve].(\finalDemoChordOff, false);
    };

    at[\finalDemoPlayChord] = { |midis, dur=0.8, velocity=0.68, reason=\finalDemoChord|
        at[\finalDemoChordOn].(midis, velocity, reason);
        at[\finalDemoAdvance].(dur, reason, nil);
        at[\finalDemoChordOff].(midis);
        0.12.wait;
    };

    at[\finalDemoMusicPhrase] = { |chords, dur=0.72, velocity=0.66, reason=\finalDemoMusic|
        (chords ? Array.new).do { |ch|
            at[\finalDemoPlayChord].(ch, dur, velocity, reason);
        };
    };

    at[\finalDemoExternalTone] = { |freq=440, dur=1.0, amp=nil, kind=\tone|
        var a, synthName;
        a = (amp ? (cfg[\finalDemo][\externalStimulusAmp] ? 0.085)).asFloat.clip(0.0, 0.5);
        synthName = if(kind == \singer) { \at_final_demo_external_singer } { if(kind == \inharmonic) { \at_final_demo_external_inharmonic } { \at_final_demo_external_tone } };
        Synth(synthName, [\freq, freq.asFloat.max(20.0), \dur, dur.asFloat.max(0.05), \amp, a]);
        (dur.asFloat.max(0.05) * 0.15).min(0.12).wait;
    };

    at[\finalDemoExternalChord] = { |midis, dur=1.0, amp=nil, kind=\tone|
        var a;
        a = (amp ? (cfg[\finalDemo][\externalStimulusAmp] ? 0.085)).asFloat.clip(0.0, 0.5);
        (midis ? Array.new).do { |midi|
            at[\finalDemoExternalTone].(at[\midiToFreq].(midi), dur, a / ((midis ? [1]).size.max(1).sqrt), kind);
        };
        dur.asFloat.max(0.05).wait;
    };

    at[\finalDemoEnableEar] = { |weight=0.55|
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(true); };
        if(api[\setMicMode].notNil) { api[\setMicMode].(\polyPc); };
        if(api[\setMicInfluencePolicy].notNil) { api[\setMicInfluencePolicy].(\duetSafe); };
        if(api[\setMicWeight].notNil) { api[\setMicWeight].(weight); };
        if(api[\setMicConfidenceThreshold].notNil) { api[\setMicConfidenceThreshold].(0.55); };
        at[\finalDemoResolve].(\finalDemoEarOn, false);
    };

    at[\finalDemoBindGravityToBestExternal] = { |fallbackPc=9, fallbackCents=(-31.766653633429)|
        var sources, best, bestWeight, pc, phase, cents, rep;
        sources = (st[\micSceneAcceptedSources] ? st[\externalSources] ? Array.new).asArray;
        best = nil;
        bestWeight = -1.0;
        sources.do { |src|
            var w;
            w = ((src[\weight] ? 0.0) * (src[\confidence] ? 0.0)).asFloat;
            if((src[\pc].notNil) and: { w > bestWeight }) { best = src; bestWeight = w; };
        };
        if(best.notNil) {
            pc = (best[\pc] ? fallbackPc).asInteger.clip(0, 11);
            phase = best[\phase] ? ((st[\etPhase][pc] ? (pc / 12.0)) + (fallbackCents / 1200.0));
            cents = at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0;
        } {
            pc = fallbackPc;
            cents = fallbackCents;
        };
        if(api[\setAnchorToNote].notNil) { api[\setAnchorToNote].(pc, cents, true); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
        rep = (bound: true, usedLiveMicSource: best.notNil, pc: pc, cents: cents.round(0.01), sourceWeight: bestWeight.round(0.001), note: "Ear-to-Gravity uses a live accepted mic source when available; otherwise this demo falls back to the known speaker reference it just emitted.");
        "[AT FINAL DEMO EAR-TO-GRAVITY]".postln; rep.postln;
        rep;
    };

    at[\finalDemoUpdateGravityFromMemory] = { |pc=9|
        var cents, rep;
        cents = if(st[\memoryPhase].notNil) { at[\wrapSigned].((st[\memoryPhase][pc] ? st[\nodePhase][pc]) - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0 } { at[\finalDemoCentsForPc].(pc) };
        if(api[\setAnchorToNote].notNil) { api[\setAnchorToNote].(pc, cents, true); };
        cfg[\gravity][\followMemory] = true;
        cfg[\gravity][\followMode] = \memory;
        st[\gravityFollowMode] = \memory;
        rep = (enabled: true, pc: pc, cents: cents.round(0.01), memoryConfidence: (st[\memoryConfidence] ? 0.0).round(0.001), followMode: \memory, note: "Gravity home has been re-anchored to the learned memory field for this pitch class; future movement remains Motion-gated.");
        "[AT FINAL DEMO GRAVITY FOLLOWS MEMORY]".postln; rep.postln;
        rep;
    };

    at[\finalDemoSetGravityFollowMode] = { |mode=\fixed|
        var m, allowed, rep;
        m = mode.asSymbol;
        allowed = [\fixed, \memory, \ear, \earMemory, \earPlusMemory];
        if(allowed.includes(m).not) { m = \fixed; };
        if(m == \earPlusMemory) { m = \earMemory; };
        cfg[\gravity][\followMode] = m;
        st[\gravityFollowMode] = m;
        rep = (followMode: m, enabled: cfg[\gravity][\enabled] ? false, note: "Gravity source mode: fixed=user reference, memory=learned internal basin, ear=external coherence fit, earMemory=external fit stabilized by memory. Motion still controls movement speed.");
        "[AT FINAL DEMO GRAVITY FOLLOW MODE]".postln; rep.postln;
        rep
    };

    at[\finalDemoAdaptiveGravityFromSources] = { |label=\adaptiveGravity, sources=nil, mode=\earMemory, fallbackPc=9, fallbackCents=0.0|
        var allSources, arr, m, sumDiff, sumWeight, best, bestWeight, homePc, extCents, memCents, memBlend, cents, rep;
        allSources = (sources ? st[\finalDemoCapturedExternalSources] ? st[\externalSources] ? Array.new).asArray.select { |src| src.notNil and: { src[\pc].notNil } };
        arr = allSources.select { |src|
            var sourceClass, spectrumClass;
            sourceClass = src[\sourceClass] ? \unknown;
            spectrumClass = src[\spectrumClass] ? \harmonic;
            ((src[\gravityEligible] ? true) == true)
                and: { ((src[\pitchAuthorityEligible] ? true) == true)
                and: { sourceClass != \abnormalSpectrum
                and: { spectrumClass != \inharmonic } } }
        };
        m = mode.asSymbol;
        if(m == \earPlusMemory) { m = \earMemory; };
        if(arr.isEmpty) {
            homePc = fallbackPc.asInteger.clip(0, 11);
            memCents = if(st[\memoryPhase].notNil) { at[\wrapSigned].((st[\memoryPhase][homePc] ? st[\nodePhase][homePc]) - (st[\etPhase][homePc] ? (homePc / 12.0))) * 1200.0 } { at[\finalDemoCentsForPc].(homePc) };
            rep = (
                label: label,
                followMode: m,
                sourceCount: allSources.size,
                usedSourceCount: 0,
                blockedNonPitchSources: allSources.size,
                gravityAdapted: false,
                homePc: homePc,
                homeName: if(at[\pcName].notNil) { at[\pcName].(homePc) } { homePc.asString },
                externalFitCents: 0.0,
                memoryCents: memCents.round(0.01),
                memoryBlend: 0.0,
                homeCents: (st[\gravityHomeCents] ? fallbackCents).asFloat.round(0.01),
                motionGated: true,
                keyDetection: false,
                pitchAuthorityAdded: false,
                abnormalSpectrumChangesGravity: false,
                reason: \noPitchEligibleExternalSources,
                note: "Adaptive Gravity ignores spectral-only/abnormal/self-bleed sources as pitch anchors. They may affect Spectrum/Accordion or timbre, but they do not move Gravity."
            );
            "[AT FINAL DEMO ADAPTIVE GRAVITY]".postln; rep.postln;
            rep
        } {
            sumDiff = 0.0; sumWeight = 0.0; best = nil; bestWeight = -1.0;
            arr.do { |src|
                var pc, phase, diff, w;
                pc = (src[\pc] ? fallbackPc).asInteger.clip(0, 11);
                phase = src[\phase] ? ((st[\etPhase][pc] ? (pc / 12.0)) + ((src[\cents] ? fallbackCents) / 1200.0));
                diff = at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0)));
                w = ((src[\weight] ? 0.0) + ((src[\confidence] ? 0.0) * 0.10) + ((src[\spectralConfidence] ? 0.0) * 0.02)).asFloat.max(0.0001);
                sumDiff = sumDiff + (diff * w);
                sumWeight = sumWeight + w;
                if(w > bestWeight) { best = src; bestWeight = w; };
            };
            homePc = if(best.notNil) { (best[\pc] ? fallbackPc).asInteger.clip(0, 11) } { fallbackPc.asInteger.clip(0, 11) };
            extCents = if(sumWeight > 0.00001) { (sumDiff / sumWeight) * 1200.0 } { fallbackCents.asFloat };
            memCents = if(st[\memoryPhase].notNil) { at[\wrapSigned].((st[\memoryPhase][homePc] ? st[\nodePhase][homePc]) - (st[\etPhase][homePc] ? (homePc / 12.0))) * 1200.0 } { at[\finalDemoCentsForPc].(homePc) };
            memBlend = (((st[\memoryConfidence] ? 0.0) * (st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0))) * 0.65).clip(0.0, 0.75);
            cents = case
                { m == \memory } { memCents }
                { m == \ear } { extCents }
                { m == \earMemory } { (extCents * (1.0 - memBlend)) + (memCents * memBlend) }
                { extCents };
            if(api[\setAnchorToNote].notNil) { api[\setAnchorToNote].(homePc, cents, true); };
            if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
            cfg[\gravity][\followMode] = m;
            st[\gravityFollowMode] = m;
            rep = (
                label: label,
                followMode: m,
                sourceCount: allSources.size,
                usedSourceCount: arr.size,
                blockedNonPitchSources: allSources.size - arr.size,
                gravityAdapted: true,
                homePc: homePc,
                homeName: if(at[\pcName].notNil) { at[\pcName].(homePc) } { homePc.asString },
                externalFitCents: extCents.round(0.01),
                memoryCents: memCents.round(0.01),
                memoryBlend: memBlend.round(0.001),
                homeCents: cents.round(0.01),
                motionGated: true,
                keyDetection: false,
                pitchAuthorityAdded: false,
                abnormalSpectrumChangesGravity: false,
                note: "Adaptive Gravity follows pitch-eligible surrounding heard sources as a global gauge fit, optionally stabilized by Memory. It is not key detection and does not bypass Motion."
            );
            "[AT FINAL DEMO ADAPTIVE GRAVITY]".postln; rep.postln;
            rep
        }
    };

    at[\finalDemoAdaptiveGravityFromCapturedScene] = { |label=\capturedExternalScene, mode=\earMemory, fallbackPc=9, fallbackCents=0.0|
        var sources;
        sources = if(st[\finalDemoCapturedScenes].notNil) { st[\finalDemoCapturedScenes][label] ? st[\finalDemoCapturedExternalSources] ? Array.new } { st[\finalDemoCapturedExternalSources] ? Array.new };
        at[\finalDemoAdaptiveGravityFromSources].(label, sources, mode, fallbackPc, fallbackCents)
    };

    at[\finalDemoSetSpectrumAccordion] = { |amount=0.0, profile=\inharmonic|
        var amt, rep;
        amt = amount.asFloat.clip(0.0, 0.35);
        if(api[\setPerceptualSpectrumEnabled].notNil) { api[\setPerceptualSpectrumEnabled].(amt > 0.0001); };
        if(api[\setPerceptualSpectrumProfile].notNil) { api[\setPerceptualSpectrumProfile].(profile); };
        if(api[\setPerceptualSpectrumAmount].notNil) { api[\setPerceptualSpectrumAmount].(amt); };
        if(api[\setPerceptualCylinderAmount].notNil) { api[\setPerceptualCylinderAmount].(amt); };
        if(api[\setPerceptualCylinderAccordionAuthorityEnabled].notNil) { api[\setPerceptualCylinderAccordionAuthorityEnabled].(amt > 0.0001); };
        rep = (amount: amt, profile: profile, bounded: true, maxRequested: 0.35, motionGated: true, pitchAuthorityAdded: false, note: "Spectrum/Accordion is explicit and bounded; it influences the target only when amount > 0, and Motion still controls current movement.");
        "[AT FINAL DEMO SPECTRUM/ACCORDION CONTROL]".postln; rep.postln;
        rep;
    };


    at[\finalDemoExternalToneStart] = { |freq=440, dur=1.0, amp=nil, kind=\tone|
        var a, synthName;
        a = (amp ? (cfg[\finalDemo][\externalStimulusAmp] ? 0.14)).asFloat.clip(0.0, 0.5);
        synthName = if(kind == \singer) { \at_final_demo_external_singer } { if(kind == \inharmonic) { \at_final_demo_external_inharmonic } { \at_final_demo_external_tone } };
        Synth(synthName, [\freq, freq.asFloat.max(20.0), \dur, dur.asFloat.max(0.05), \amp, a]);
    };

    at[\finalDemoExternalChordStart] = { |midis, dur=1.0, amp=nil, kind=\tone|
        var a, arr;
        arr = midis ? Array.new;
        a = (amp ? (cfg[\finalDemo][\externalStimulusAmp] ? 0.14)).asFloat.clip(0.0, 0.5);
        arr.do { |midi|
            at[\finalDemoExternalToneStart].(at[\midiToFreq].(midi), dur, a / arr.size.max(1).sqrt, kind);
        };
        0.08.wait;
    };

    at[\finalDemoLiveExternalSources] = { |minConfidence=nil|
        var minConf;
        minConf = (minConfidence ? (cfg[\finalDemo][\hardwareMinConfidence] ? 0.12)).asFloat;
        ((st[\externalSources] ? Array.new).asArray).select { |src|
            src.notNil and: { (src[\active] != false) and: { (src[\confidence] ? 0.0) >= minConf and: { (src[\weight] ? 0.0) > 0.0 } } }
        }
    };

    at[\finalDemoPhysicalEarSnapshot] = { |label=\physicalEar, minSources=nil, minConfidence=nil, post=true|
        var sources, raw, scene, bridge, rep, minCount;
        minCount = (minSources ? (cfg[\finalDemo][\hardwareMinLiveSources] ? 1)).asInteger.max(1);
        if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
        if(at[\refreshMicMeters].notNil) { at[\refreshMicMeters].(); };
        sources = at[\finalDemoLiveExternalSources].(minConfidence);
        raw = st[\micRawAmp] ? 0.0;
        scene = if(api[\externalCoherenceSceneReport].notNil) { api[\externalCoherenceSceneReport].(false) } { nil };
        bridge = if(api[\externalCoherenceBridgeReport].notNil) { api[\externalCoherenceBridgeReport].(false) } { nil };
        rep = (
            label: label,
            required: cfg[\finalDemo][\requireLiveEar] ? true,
            currentLiveMicAccepted: sources.size >= minCount,
            liveSourceCount: sources.size,
            minRequiredSources: minCount,
            rawAmp: raw.round(0.0001),
            micVoiced: st[\micVoiced] ? false,
            currentExternalSceneStatus: if(scene.notNil) { scene[\status] } { \unknown },
            currentExternalSceneSources: if(scene.notNil) { scene[\sourceCount] ? 0 } { 0 },
            currentBridgeSources: if(bridge.notNil) { bridge[\usedSourceCount] ? 0 } { 0 },
            fallbackCountsAsPass: false,
            sources: sources.collect { |src|
                (pc: src[\pc], freq: (src[\freq] ? 0.0).round(0.01), cents: if(src[\pc].notNil) { (at[\wrapSigned].((src[\phase] ? 0.0) - (st[\etPhase][src[\pc]] ? 0.0)) * 1200.0).round(0.01) } { 0.0 }, confidence: (src[\confidence] ? 0.0).round(0.001), weight: (src[\weight] ? 0.0).round(0.001))
            },
            note: "This is a current live speaker-to-microphone gate. Last-meaningful or known-reference fallback is reported separately and never counts as a pass."
        );
        demo[\lastPhysicalEarSnapshot] = rep;
        if(post) {
            "[AT FINAL DEMO PHYSICAL EAR]".postln;
            ("label=" ++ label.asString
                ++ " liveAccepted=" ++ rep[\currentLiveMicAccepted].asString
                ++ " liveSources=" ++ rep[\liveSourceCount].asString
                ++ " rawAmp=" ++ rep[\rawAmp].asString
                ++ " currentScene=" ++ rep[\currentExternalSceneStatus].asString
                ++ " bridgeSources=" ++ rep[\currentBridgeSources].asString
                ++ " fallbackCountsAsPass=false").postln;
            rep.postln;
        };
        rep
    };

    at[\finalDemoPollPhysicalEar] = { |label=\physicalEar, seconds=nil, minSources=nil, minConfidence=nil, postEvery=false|
        var dur, dt, steps, i, snap, ok;
        dur = (seconds ? (cfg[\finalDemo][\hardwarePollSeconds] ? 2.2)).asFloat.max(0.1);
        dt = (cfg[\mic][\pollDt] ? 0.05).asFloat.max(0.03);
        steps = (dur / dt).ceil.asInteger.max(1);
        ok = false;
        i = 0;
        while { i < steps } {
            snap = at[\finalDemoPhysicalEarSnapshot].(label, minSources, minConfidence, postEvery);
            if(snap[\currentLiveMicAccepted] == true) { ok = true; i = steps; };
            at[\finalDemoMoveCurrentOnly].(label);
            dt.wait;
            i = i + 1;
        };
        snap = at[\finalDemoPhysicalEarSnapshot].(label, minSources, minConfidence, true);
        ok = ok or: { snap[\currentLiveMicAccepted] == true };
        if(ok.not) {
            "[AT FINAL DEMO HARDWARE EAR ROUTE FAILED]".postln;
            ("label=" ++ label.asString ++ " live mic did not accept the emitted speaker source. Raise laptop volume or run setFinalDemoExternalStimulusAmp before rerunning. Fallback is not counted as success.").postln;
        };
        ok
    };

    at[\finalDemoRequirePhysicalEarOrStop] = { |label=\physicalEar, seconds=nil, minSources=nil, minConfidence=nil|
        var ok;
        ok = at[\finalDemoPollPhysicalEar].(label, seconds, minSources, minConfidence, false);
        demo[\physicalEarLiveAccepted] = ok;
        if((cfg[\finalDemo][\requireLiveEar] ? true) and: { ok.not }) {
            at[\finalDemoAllNotesOff].();
            at[\finalDemoClearExternal].();
            if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
            demo[\running] = false;
            demo[\failedAt] = label;
            demo[\completedAt] = Main.elapsedTime;
            false
        } {
            true
        }
    };


    at[\finalDemoUniquePitchClasses] = { |sources|
        var seen, out;
        seen = IdentityDictionary.new;
        out = Array.new;
        (sources ? Array.new).asArray.do { |src|
            var pc;
            pc = src[\pc];
            if(pc.notNil) {
                pc = pc.asInteger.clip(0, 11);
                if(seen[pc].isNil) {
                    seen[pc] = true;
                    out = out.add(pc);
                };
            };
        };
        out
    };

    at[\finalDemoSourceCanCountForExpectedPitchClass] = { |src, expectedPc=nil, kind=\tone|
        var actualPc, expected;
        if(src.isNil or: { expectedPc.isNil }) {
            false
        } {
            if(kind == \inharmonic) {
                true
            } {
                actualPc = src[\pc];
                expected = expectedPc.asInteger.clip(0, 11);
                actualPc.notNil and: { actualPc.asInteger.clip(0, 11) == expected }
            }
        }
    };

    at[\finalDemoDecorateCapturedSource] = { |src, label=\capturedExternal, expectedPc=nil, kind=\tone|
        var out, pc, cents, expected, matched, pitchEligible, gravityEligible, spectralEligible;
        pc = (src[\pc] ? expectedPc ? 0).asInteger.clip(0, 11);
        expected = if(expectedPc.notNil) { expectedPc.asInteger.clip(0, 11) } { pc };
        matched = (pc == expected);
        cents = if(src[\phase].notNil) { at[\wrapSigned].((src[\phase] ? 0.0) - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0 } { src[\cents] ? 0.0 };
        pitchEligible = (kind != \inharmonic) and: { (src[\sourceClass] ? \stableTone) != \abnormalSpectrum };
        gravityEligible = pitchEligible and: { matched };
        spectralEligible = (kind == \inharmonic) or: { (src[\sourceClass] ? \stableTone) == \abnormalSpectrum };
        out = if(at[\normalizeExternalSource].notNil) {
            at[\normalizeExternalSource].(src.copy.putAll((
                id: label.asString ++ "-" ++ pc.asString,
                kind: if(kind == \singer) { \voice } { \liveCapturedMic },
                pc: pc,
                phase: src[\phase] ? ((st[\etPhase][pc] ? (pc / 12.0)) + (cents / 1200.0)),
                freq: src[\freq] ? (if(at[\midiToFreq].notNil) { at[\midiToFreq].(60 + pc) } { 0.0 }),
                confidence: (src[\confidence] ? 0.0).max(0.18).clip(0.0, 1.0),
                weight: (src[\weight] ? 0.0).max((src[\confidence] ? 0.0) * 0.07).clip(0.0, 0.18),
                amp: src[\amp] ? (st[\micRawAmp] ? 0.0),
                active: true
            )))
        } {
            src.copy
        };
        out[\id] = label.asString ++ "-" ++ pc.asString;
        out[\pc] = pc;
        out[\expectedPc] = expected;
        out[\pitchClassMatchedExpected] = matched;
        out[\cents] = cents;
        out[\liveCaptured] = true;
        out[\capturedAt] = Main.elapsedTime;
        out[\active] = true;
        out[\sourceClass] = if(kind == \singer) { \voice } { if(kind == \inharmonic) { \abnormalSpectrum } { \stableTone } };
        out[\spectrumClass] = if(kind == \inharmonic) { \inharmonic } { \harmonic };
        out[\spectralConfidence] = if(kind == \inharmonic) { 0.78 } { 0.35 };
        out[\pitchConfidence] = if(kind == \inharmonic) { ((out[\confidence] ? 0.0) * 0.35).clip(0.0, 0.30) } { out[\confidence] ? 0.0 };
        out[\jitterCents] = src[\jitterCents] ? (if(kind == \singer) { 7.5 } { 1.5 });
        out[\pitchAuthorityEligible] = pitchEligible;
        out[\gravityEligible] = gravityEligible;
        out[\spectralAuthorityEligible] = spectralEligible;
        out[\abnormalSpectrumChangesGravity] = false;
        out
    };

    at[\finalDemoCaptureOneExternalSource] = { |label=\externalCapture, midi=60, amp=nil, kind=\tone, minConfidence=nil, freqOverride=nil, expectedPcOverride=nil|
        var pc, freq, dur, pollDur, start, dt, best, bestScore, snap, sources, cand, score, rep, oldPHFPrint, oldPHFSurface;
        pc = (expectedPcOverride ? (midi.asInteger % 12)).asInteger.clip(0, 11);
        freq = (freqOverride ? at[\midiToFreq].(midi)).asFloat;
        dur = (cfg[\finalDemo][\captureToneSeconds] ? 1.65).asFloat.max(0.3);
        pollDur = (cfg[\finalDemo][\capturePollSeconds] ? 1.25).asFloat.max(0.2);
        best = nil;
        bestScore = -1.0;
        // Avoid counting stale previously held live sources as a fresh physical capture.
        st[\externalSources] = Array.new;
        st[\micSceneAcceptedSources] = Array.new;
        if(at[\clearMicReleaseHold].notNil) { at[\clearMicReleaseHold].(label); };
        oldPHFPrint = if(cfg[\passiveHarmonicField].notNil) { cfg[\passiveHarmonicField][\printReports] } { nil };
        oldPHFSurface = if(cfg[\passiveHarmonicField].notNil) { cfg[\passiveHarmonicField][\surfaceProjectionPostReports] } { nil };
        if(cfg[\passiveHarmonicField].notNil) {
            cfg[\passiveHarmonicField][\printReports] = false;
            cfg[\passiveHarmonicField][\surfaceProjectionPostReports] = false;
        };
        st[\finalDemoCaptureSuppressSolveLogs] = true;
        at[\finalDemoExternalToneStart].(freq, dur, amp, kind);
        0.08.wait;
        start = Main.elapsedTime;
        dt = (cfg[\mic][\pollDt] ? 0.05).asFloat.max(0.03);
        while { (Main.elapsedTime - start) < pollDur } {
            snap = at[\finalDemoPhysicalEarSnapshot].((label.asString ++ "_poll").asSymbol, 1, minConfidence, false);
            sources = at[\finalDemoLiveExternalSources].(minConfidence);
            sources.do { |src|
                var pcOk, pcPenalty;
                pcOk = at[\finalDemoSourceCanCountForExpectedPitchClass].(src, pc, kind);
                if(pcOk) {
                    pcPenalty = if(kind == \inharmonic) { 0.55 } { 1.0 };
                    score = ((src[\confidence] ? 0.0) * 1.0 + ((src[\weight] ? 0.0) * 4.0)) * pcPenalty;
                    if(score > bestScore) { best = src.copy; bestScore = score; };
                };
            };
            at[\finalDemoMoveCurrentOnly].(label);
            dt.wait;
        };
        if(cfg[\passiveHarmonicField].notNil) {
            cfg[\passiveHarmonicField][\printReports] = oldPHFPrint ? true;
            cfg[\passiveHarmonicField][\surfaceProjectionPostReports] = oldPHFSurface ? false;
        };
        st[\finalDemoCaptureSuppressSolveLogs] = false;
        if(best.notNil) { best = at[\finalDemoDecorateCapturedSource].(best, label, pc, kind); };
        rep = (
            label: label,
            midi: midi,
            freq: freq.round(0.01),
            expectedPc: pc,
            expectedPcName: if(at[\pcName].notNil) { at[\pcName].(pc) } { pc.asString },
            accepted: best.notNil,
            source: best,
            actualPc: if(best.notNil) { best[\pc] } { nil },
            actualPcName: if(best.notNil) { if(at[\pcName].notNil) { at[\pcName].(best[\pc]) } { best[\pc].asString } } { nil },
            pitchClassMatchedExpected: if(best.notNil) { best[\pitchClassMatchedExpected] ? false } { false },
            liveMicCaptured: best.notNil,
            fallbackCountsAsPass: false,
            kind: kind,
            strictPitchClassGate: (kind != \inharmonic),
            score: bestScore.round(0.001)
        );
        "[AT FINAL DEMO LIVE SOURCE CAPTURE]".postln;
        ("label=" ++ label.asString ++ " expected=" ++ rep[\expectedPcName].asString ++ " accepted=" ++ rep[\accepted].asString ++ " kind=" ++ kind.asString ++ " actual=" ++ rep[\actualPcName].asString ++ " strictPitchClassGate=" ++ rep[\strictPitchClassGate].asString ++ " fallbackCountsAsPass=false").postln;
        rep.postln;
        best
    };

    at[\finalDemoPublishCapturedExternalSources] = { |label=\capturedExternalScene, sources=nil, sceneClass=\chordCloud|
        var arr, rep;
        arr = (sources ? Array.new).select { |src| src.notNil }.collect { |src| src.copy.put(\active, true).put(\capturedAt, Main.elapsedTime) };
        st[\finalDemoCapturedExternalSources] = arr.collect { |src| src.copy };
        if(st[\finalDemoCapturedScenes].isNil) { st[\finalDemoCapturedScenes] = IdentityDictionary.new; };
        st[\finalDemoCapturedScenes][label] = arr.collect { |src| src.copy };
        if(at[\micSceneMaybePublishPressure].notNil) {
            at[\micSceneMaybePublishPressure].(arr, sceneClass, label);
        };
        // v50: a staged physical capture is the demo's current external scene
        // truth.  Publish it forcefully after the mic-pressure throttle so later
        // reports cannot silently replace a captured singer or abnormal spectrum
        // with a fresh generic stable-tone tracker observation.
        st[\externalSources] = arr.collect { |src| src.copy };
        st[\micSceneAcceptedSources] = arr.collect { |src| src.copy };
        st[\finalDemoExternalSceneHoldLabel] = label;
        st[\finalDemoExternalSceneHoldClass] = sceneClass;
        st[\finalDemoExternalSceneHeldAt] = Main.elapsedTime;
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(label); };
        rep = (
            label: label,
            capturedSourceCount: arr.size,
            uniquePitchClassCount: at[\finalDemoUniquePitchClasses].(arr).size,
            sourcePcs: arr.collect { |src| src[\pc] },
            uniqueSourcePcs: at[\finalDemoUniquePitchClasses].(arr),
            liveMicCaptured: true,
            sceneClass: sceneClass,
            fallbackCountsAsPass: false,
            note: "These sources were first accepted from the laptop speaker through the microphone, then briefly held as the live external scene so the ET/singer/inharmonic demo does not depend on impossible simultaneous sine tracking."
        );
        "[AT FINAL DEMO LIVE CAPTURED SCENE]".postln;
        rep.postln;
        rep
    };

    at[\finalDemoReportCapturedExternalCoherence] = { |label=\capturedExternalScene, sceneClass=\chordCloud, post=true|
        var arr, scene, bridge, roles, voice, score, rep;
        arr = if(st[\finalDemoCapturedScenes].notNil) { st[\finalDemoCapturedScenes][label] ? Array.new } { Array.new };
        at[\finalDemoPublishCapturedExternalSources].(label, arr, sceneClass);
        scene = if(api[\externalCoherenceSceneReport].notNil) { api[\externalCoherenceSceneReport].(post) } { nil };
        bridge = if(api[\externalCoherenceBridgeReport].notNil) { api[\externalCoherenceBridgeReport].(post) } { nil };
        roles = if(scene.notNil) { scene[\roleCounts] ? IdentityDictionary.new } { IdentityDictionary.new };
        voice = if(scene.notNil) { scene[\voiceReport] ? IdentityDictionary.new } { IdentityDictionary.new };
        score = if(scene.notNil) { scene[\scoreSummary] ? IdentityDictionary.new } { IdentityDictionary.new };
        rep = (
            label: label,
            sourceCount: arr.size,
            sceneClass: sceneClass,
            voiceCount: voice[\voiceCount] ? 0,
            flatVoiceCount: voice[\flatVoiceCount] ? 0,
            abnormalSpectrumCount: score[\abnormalSpectrumCount] ? 0,
            selfBleedBlockedCount: score[\selfBleedBlockedCount] ? 0,
            etLike: if(scene.notNil) { scene[\etLike] ? false } { false },
            bestWorld: if(scene.notNil) { scene[\bestWorld] ? \none } { \none },
            usedBridgeSources: if(bridge.notNil) { bridge[\usedSourceCount] ? 0 } { 0 },
            roleCounts: roles,
            pitchAuthorityAdded: false,
            abnormalSpectrumChangesPitchCircle: false,
            selfBleedExternalAuthority: false,
            note: "Final-demo coherence is reported from the physically captured held scene, preserving kind/sourceClass/spectrum metadata."
        );
        st[\finalDemoLastSceneRoleTruth] = rep;
        if(post) {
            "[AT FINAL DEMO SCENE ROLE TRUTH]".postln;
            ("label=" ++ label.asString
                ++ " sources=" ++ rep[\sourceCount].asString
                ++ " etLike=" ++ rep[\etLike].asString
                ++ " voiceCount=" ++ rep[\voiceCount].asString
                ++ " flatVoiceCount=" ++ rep[\flatVoiceCount].asString
                ++ " abnormal=" ++ rep[\abnormalSpectrumCount].asString
                ++ " usedBridgeSources=" ++ rep[\usedBridgeSources].asString
                ++ " best=" ++ rep[\bestWorld].asString
                ++ " pitchAuthorityAdded=false abnormalSpectrumChangesPitchCircle=false selfBleedExternalAuthority=false").postln;
            ("roles=" ++ roles.asString).postln;
        };
        rep
    };

    at[\finalDemoCapturedSceneTruthGate] = { |label=\capturedExternalScene, minSources=1, sceneClass=\chordCloud, gravityMode=\earMemory|
        var arr, uniquePcs, ok, scene, bridge, raw, rep;
        arr = if(st[\finalDemoCapturedScenes].notNil) { st[\finalDemoCapturedScenes][label] ? Array.new } { Array.new };
        uniquePcs = at[\finalDemoUniquePitchClasses].(arr);
        ok = uniquePcs.size >= minSources.asInteger.max(1);
        if(ok) {
            at[\finalDemoPublishCapturedExternalSources].(label, arr, sceneClass);
            at[\finalDemoAdaptiveGravityFromCapturedScene].(label, gravityMode, 9, st[\gravityHomeCents] ? 0.0);
            at[\finalDemoMoveCurrentOnly].(label);
        };
        raw = st[\micRawAmp] ? 0.0;
        scene = if(api[\externalCoherenceSceneReport].notNil) { api[\externalCoherenceSceneReport].(false) } { nil };
        bridge = if(api[\externalCoherenceBridgeReport].notNil) { api[\externalCoherenceBridgeReport].(false) } { nil };
        rep = (
            label: label,
            accepted: ok,
            truthStandard: \physicallyCapturedThenHeld,
            capturedSourceCount: arr.size,
            uniquePitchClassCount: uniquePcs.size,
            required: minSources,
            sceneClass: sceneClass,
            sourcePcs: arr.collect { |src| src[\pc] },
            uniqueSourcePcs: uniquePcs,
            currentExternalSceneStatus: if(scene.notNil) { scene[\status] } { \unknown },
            currentExternalSceneSources: if(scene.notNil) { scene[\sourceCount] ? 0 } { 0 },
            bridgeSources: if(bridge.notNil) { bridge[\usedSourceCount] ? 0 } { 0 },
            rawAmp: raw.round(0.0001),
            fallbackCountsAsPass: false,
            simultaneousPolyMicRequired: false,
            strictUniquePitchClasses: true,
            note: "This gate counts only unique pitch classes that were first accepted from the laptop speaker through the microphone, then held briefly as the external scene. It does not require impossible simultaneous laptop-mic polyphonic tracking."
        );
        "[AT FINAL DEMO CAPTURED SCENE TRUTH]".postln;
        ("label=" ++ label.asString ++ " accepted=" ++ ok.asString ++ " captured=" ++ arr.size.asString ++ " unique=" ++ uniquePcs.size.asString ++ " required=" ++ minSources.asString ++ " simultaneousPolyMicRequired=false fallbackCountsAsPass=false").postln;
        rep.postln;
        if(ok.not) {
            "[AT FINAL DEMO HARDWARE EAR ROUTE FAILED]".postln;
            ("label=" ++ label.asString ++ " did not have enough unique physically captured speaker-to-microphone pitch classes. Fallback is not counted as success.").postln;
        };
        rep
    };

    at[\finalDemoCaptureExternalScene] = { |label=\externalScene, midis=nil, amp=nil, kind=\tone, minRequired=1, minConfidence=nil, sceneClass=\chordCloud|
        var captured, arr, ok, rep, uniquePcs;
        arr = midis ? Array.new;
        captured = Array.new;
        arr.do { |midi|
            var src, retries;
            src = at[\finalDemoCaptureOneExternalSource].((label.asString ++ "_" ++ midi.asString).asSymbol, midi, amp, kind, minConfidence);
            retries = [midi + 12, midi - 12];
            retries.do { |alt|
                if(src.isNil and: { alt >= 36 and: { alt <= 84 } }) {
                    src = at[\finalDemoCaptureOneExternalSource].((label.asString ++ "_" ++ midi.asString ++ "_retry" ++ alt.asString).asSymbol, alt, amp, kind, minConfidence);
                };
            };
            if(src.notNil) { captured = captured.add(src); };
            0.08.wait;
        };
        uniquePcs = at[\finalDemoUniquePitchClasses].(captured);
        ok = uniquePcs.size >= minRequired.asInteger.max(1);
        if(st[\finalDemoCapturedScenes].isNil) { st[\finalDemoCapturedScenes] = IdentityDictionary.new; };
        st[\finalDemoCapturedScenes][label] = captured.collect { |src| src.copy };
        if(ok) { at[\finalDemoPublishCapturedExternalSources].(label, captured, sceneClass); };
        rep = (label: label, accepted: ok, captured: captured.size, uniquePitchClassCount: uniquePcs.size, uniqueSourcePcs: uniquePcs, required: minRequired, fallbackCountsAsPass: false, physicalMic: true, stagedCapture: true, strictUniquePitchClasses: true, sources: captured);
        "[AT FINAL DEMO STAGGERED PHYSICAL CAPTURE]".postln;
        rep.postln;
        if(ok.not) {
            "[AT FINAL DEMO HARDWARE EAR ROUTE FAILED]".postln;
            ("label=" ++ label.asString ++ " staggered live mic capture did not accept enough unique emitted speaker pitch classes. Raise laptop volume or run setFinalDemoExternalStimulusAmp before rerunning.").postln;
        };
        rep
    };

    at[\finalDemoCaptureReferenceFrequency] = { |label=\referenceTone, freq=432.0, expectedPc=9, amp=nil, minConfidence=nil, sceneClass=\referenceTone|
        var src, arr, uniquePcs, ok, rep;
        src = at[\finalDemoCaptureOneExternalSource].(label, 60 + expectedPc.asInteger.clip(0, 11), amp, \tone, minConfidence, freq, expectedPc);
        arr = if(src.notNil) { [src] } { Array.new };
        uniquePcs = at[\finalDemoUniquePitchClasses].(arr);
        ok = uniquePcs.size >= 1;
        if(st[\finalDemoCapturedScenes].isNil) { st[\finalDemoCapturedScenes] = IdentityDictionary.new; };
        st[\finalDemoCapturedScenes][label] = arr.collect { |item| item.copy };
        if(ok) { at[\finalDemoPublishCapturedExternalSources].(label, arr, sceneClass); };
        rep = (
            label: label,
            accepted: ok,
            freq: freq.round(0.01),
            expectedPc: expectedPc.asInteger.clip(0, 11),
            expectedPcName: if(at[\pcName].notNil) { at[\pcName].(expectedPc.asInteger.clip(0, 11)) } { expectedPc.asString },
            captured: arr.size,
            uniquePitchClassCount: uniquePcs.size,
            uniqueSourcePcs: uniquePcs,
            required: 1,
            physicalMic: true,
            stagedCapture: true,
            fallbackCountsAsPass: false,
            truthStandard: \frequencyReferenceCapturedThenHeld,
            note: "The stable reference was captured through the speaker/microphone and then held as the live external scene; the fallback reference is not counted as success."
        );
        "[AT FINAL DEMO REFERENCE CAPTURE]".postln;
        ("label=" ++ label.asString ++ " accepted=" ++ ok.asString ++ " freq=" ++ rep[\freq].asString ++ " captured=" ++ arr.size.asString ++ " unique=" ++ uniquePcs.size.asString ++ " fallbackCountsAsPass=false").postln;
        rep.postln;
        if(ok.not) {
            "[AT FINAL DEMO HARDWARE EAR ROUTE FAILED]".postln;
            ("label=" ++ label.asString ++ " did not capture the emitted stable reference through the microphone. Raise laptop volume or run setFinalDemoExternalStimulusAmp before rerunning.").postln;
        };
        rep
    };

    at[\finalDemoMotionTrace] = { |label=\motionTrace, beforePhase=nil, watchPc=9, checkpoints=nil|
        var cps;
        cps = checkpoints ? [[\early, 0.18], [\middle, 0.42], [\late, 0.70]];
        "[AT FINAL DEMO MOTION TRACE]".postln;
        cps.do { |item|
            var suffix, dur, teleLabel;
            suffix = item[0] ? \step;
            dur = (item[1] ? 0.2).asFloat.max(0.0);
            if(dur > 0.0001) {
                if(dur <= ((cfg[\finalDemo][\motionTickSeconds] ? 0.05).asFloat + 0.0001)) {
                    // For the named one-step checkpoint, move once and report
                    // immediately, before the background real-play scheduler has
                    // time to finish the target. This makes Motion 0.25 visibly
                    // different from Motion 1 without changing the instrument.
                    at[\finalDemoMoveCurrentOnly].(label);
                } {
                    at[\finalDemoAdvance].(dur, label, nil);
                }
            };
            teleLabel = (label.asString ++ "_" ++ suffix.asString).asSymbol;
            at[\finalDemoFieldMovementTelemetry].(teleLabel, beforePhase, watchPc, true);
        };
    };

    api[\setFinalDemoExternalStimulusAmp] = { |amp=0.14|
        cfg[\finalDemo][\externalStimulusAmp] = amp.asFloat.clip(0.0, 0.5);
        (externalStimulusAmp: cfg[\finalDemo][\externalStimulusAmp])
    };

    api[\setFinalDemoRequireLiveEar] = { |flag=true|
        cfg[\finalDemo][\requireLiveEar] = flag == true;
        (requireLiveEar: cfg[\finalDemo][\requireLiveEar])
    };

    api[\finalEndAllDemoPlan] = {
        (
            branch: \v50b_stable_ear_reference_capture_product,
            command: "Library.at(\\at)[\\api][\\runFinalDemoScenario].();",
            quickCommand: "Library.at(\\at)[\\api][\\runFinalDemoScenario].(\\quick);",
            productFacing: true,
            regressionSuite: false,
            usesOnlyPublicControls: true,
            externalSoundsThroughSpeakersAndMic: true,
            fakeExternalScenes: false,
            currentVsTargetMovementTelemetry: true,
            motionSpeedTraceTelemetry: true,
            physicalEarTruthGate: true,
            liveMicFallbackCountsAsPass: false,
            liveCapturedExternalScene: true,
            stagedSceneTruthGate: true,
            strictCapturedPitchClassGate: true,
            abnormalSpectrumGravityBlocked: true,
            adaptiveGravityFollow: true,
            simultaneousPolyMicRequiredAfterCapture: false,
            staggeredPhysicalExternalCapture: true,
            realPlayAllowsActiveMotion: true,
            carryNeutral: true,
            noExtraTestsOrDemos: true,
            stages: [
                \readinessAndRoute,
                \motionZeroEqualTemperamentFreeze,
                \motionQuarterSingleNoteSlowPassiveWorld,
                \motionOneSingleNoteFastPassiveWorld,
                \arpeggioLawHighAndLowMotion,
                \registerVelocityMinorSeventh,
                \memoryContextAndModulation,
                \gravityA432AndMemoryAdaptiveGravity,
                \adaptiveTimbre,
                \boundedSpectrumAccordion,
                \earStableExternalFrequency,
                \earEqualTemperamentInstrument,
                \earEtInstrumentPlusFlatSinger,
                \earInharmonicExternalSpectrum,
                \finalContextAwareInstrument,
                \cleanup
            ]
        )
    };

    api[\finalDemoScenarioPlan] = { api[\finalEndAllDemoPlan].() };

    api[\finalDemoScenarioReport] = { |post=true|
        var rep;
        rep = (
            branch: \v50b_stable_ear_reference_capture_product,
            running: demo[\running] ? false,
            lastMode: demo[\lastMode],
            lastStage: demo[\lastStage],
            lastSummary: demo[\lastSummary],
            startedAt: demo[\startedAt],
            completedAt: demo[\completedAt],
            productFacing: true,
            regressionSuite: false,
            usesOnlyPublicControls: true,
            externalSoundsThroughSpeakersAndMic: true,
            fakeExternalScenes: false,
            pitchAuthorityAddedByDemo: false,
            currentVsTargetMovementTelemetry: true,
            motionSpeedTraceTelemetry: true,
            physicalEarTruthGate: true,
            liveMicFallbackCountsAsPass: false,
            liveCapturedExternalScene: true,
            stagedSceneTruthGate: true,
            strictCapturedPitchClassGate: true,
            abnormalSpectrumGravityBlocked: true,
            adaptiveGravityFollow: true,
            simultaneousPolyMicRequiredAfterCapture: false,
            staggeredPhysicalExternalCapture: true,
            topologyAuthorityAddedByDemo: false,
            spacingThresholdChange: false
        );
        if(post) { rep.postln; };
        rep;
    };

    api[\stopFinalDemoScenario] = {
        if(demo[\routine].notNil) { demo[\routine].stop; demo[\routine] = nil; };
        demo[\running] = false;
        at[\finalDemoAllNotesOff].();
        at[\finalDemoClearExternal].();
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        "[AT FINAL DEMO] stopped and cleaned up.".postln;
        (stopped: true)
    };

    api[\runFinalDemoScenario] = { |mode=\full|
        var m, r;
        m = (mode ? \full).asSymbol;
        if(demo[\routine].notNil) { demo[\routine].stop; };
        r = Routine({
            var quick, amp, a432Cents, waitShort, waitMed, waitLong, beforeField;
            quick = (m == \quick);
            amp = cfg[\finalDemo][\externalStimulusAmp] ? 0.14;
            a432Cents = -31.766653633429;
            waitShort = if(quick) { 0.35 } { 0.75 };
            waitMed = if(quick) { 0.65 } { 1.35 };
            waitLong = if(quick) { 1.1 } { 2.4 };

            demo[\running] = true;
            demo[\lastMode] = m;
            demo[\startedAt] = Main.elapsedTime;
            demo[\completedAt] = nil;

            at[\finalDemoStage].(0, "Readiness / route", "Final product demonstration: no test harness, no fake external scene. Controls drive the instrument; external demo sounds are emitted through the speakers so the microphone can hear them.");
            if(api[\productReadinessReport].notNil) { api[\productReadinessReport].(); };
            api[\finalEndAllDemoPlan].().postln;
            at[\finalDemoSay].("External stimulus amplitude=" ++ amp.round(0.001).asString ++ ". Lower it with setFinalDemoExternalStimulusAmp if the laptop mic feeds back.");
            0.4.wait;

            demo[\lastStage] = \motionZeroEqualTemperamentFreeze;
            at[\finalDemoStage].(1, "Motion = 0 / pure sine / ET freeze", "Motion, Memory, Gravity, Ear, and Carry are zero/off. Notes sound, targets may be calculated, but the current audible/visible field stays at equal temperament.");
            at[\finalDemoReset].(0.0);
            at[\finalDemoSetCoreControls].(0.0, 0.0, 0.0, false);
            beforeField = at[\finalDemoCaptureField].();
            at[\finalDemoPlayChord].([60, 64, 67], waitMed, 0.64, \finalDemoMotionZeroChord);
            at[\finalDemoFieldMovementTelemetry].(\motionZeroEtFreeze, beforeField, 9, true);
            at[\finalDemoFieldSummary].(\motionZeroEtFreeze, 9, true);

            demo[\lastStage] = \motionQuarterSingleNoteSlowPassiveWorld;
            at[\finalDemoStage].(2, "Motion = 0.25 / one note slowly teaches the field", "A single C is pressed. Active C stays itself; passive/silent pitch classes drift slowly toward the C-origin harmonic world at the Motion rate.");
            at[\finalDemoReset].(0.0);
            at[\finalDemoSetCoreControls].(0.0, 0.0, 0.0, false);
            beforeField = at[\finalDemoCaptureField].();
            if(at[\noteOn].notNil) { at[\noteOn].(60, 0.72, nil, false); };
            at[\finalDemoResolve].(\finalDemoMotionQuarterTargetFrozen, false);
            at[\finalDemoFieldMovementTelemetry].(\motionQuarterTargetKnownBeforeMotion, beforeField, 9, true);
            at[\finalDemoOpenMotionForTrace].(0.25);
            at[\finalDemoMotionTrace].(\motionQuarterSingleHeld, beforeField, 9, [[\instant, 0.0], [\oneStep, 0.05], [\short, 0.20], [\long, 0.65]]);
            at[\finalDemoFieldMovementTelemetry].(\motionQuarterSingleHeld, beforeField, 9, true);
            at[\finalDemoFieldSummary].(\motionQuarterSingleHeld, 9, true);
            if(at[\noteOff].notNil) { at[\noteOff].(60); };
            at[\finalDemoAdvance].(waitShort, \finalDemoMotionQuarterRelease, nil);

            demo[\lastStage] = \motionOneSingleNoteFastPassiveWorld;
            at[\finalDemoStage].(3, "Motion = 1 / same note as fast as safely possible", "After reset, the same single-note harmonic origin is reached much faster because Motion is fully open.");
            at[\finalDemoReset].(0.0);
            at[\finalDemoSetCoreControls].(0.0, 0.0, 0.0, false);
            beforeField = at[\finalDemoCaptureField].();
            if(at[\noteOn].notNil) { at[\noteOn].(60, 0.72, nil, false); };
            at[\finalDemoResolve].(\finalDemoMotionOneTargetFrozen, false);
            at[\finalDemoFieldMovementTelemetry].(\motionOneTargetKnownBeforeMotion, beforeField, 9, true);
            at[\finalDemoOpenMotionForTrace].(1.0);
            at[\finalDemoMotionTrace].(\motionOneSingleHeld, beforeField, 9, [[\instant, 0.0], [\oneStep, 0.05], [\short, 0.20], [\long, 0.65]]);
            at[\finalDemoFieldMovementTelemetry].(\motionOneSingleHeld, beforeField, 9, true);
            at[\finalDemoFieldSummary].(\motionOneSingleHeld, 9, true);
            if(at[\noteOff].notNil) { at[\noteOff].(60); };
            at[\finalDemoAdvance].(waitShort, \finalDemoMotionOneRelease, nil);

            demo[\lastStage] = \arpeggioMotionLaw;
            at[\finalDemoStage].(4, "Arpeggio law, then lower Motion", "With Motion high, minor-third and major-third paths move clearly. With lower Motion, the same arpeggio only moves as far as the played speed allows.");
            at[\finalDemoReset].(1.0);
            beforeField = at[\finalDemoCaptureField].();
            [60, 63, 66, 69, 72].do { |midi| at[\finalDemoPlayNote].(midi, 0.24, 0.78, \finalDemoArpFastMinorThird); };
            if(api[\coreTransportReport].notNil) { api[\coreTransportReport].(); };
            at[\finalDemoFieldMovementTelemetry].(\minorThirdHighMotion, beforeField, 0, true);
            at[\finalDemoFieldSummary].(\minorThirdHighMotion, 0, true);
            at[\finalDemoReset].(0.25);
            beforeField = at[\finalDemoCaptureField].();
            [60, 63, 66, 69, 72].do { |midi| at[\finalDemoPlayNote].(midi, 0.14, 0.78, \finalDemoArpLowMotionFastPlayed); };
            if(api[\coreTransportReport].notNil) { api[\coreTransportReport].(); };
            at[\finalDemoFieldMovementTelemetry].(\minorThirdLowMotionFastPlayed, beforeField, 0, true);
            at[\finalDemoFieldSummary].(\minorThirdLowMotionFastPlayed, 0, true);
            at[\finalDemoReset].(1.0);
            [60, 64, 68, 72].do { |midi| at[\finalDemoPlayNote].(midi, 0.20, 0.78, \finalDemoArpMajorThird); };
            at[\finalDemoFieldSummary].(\majorThirdHighMotion, 0, true);

            demo[\lastStage] = \registerVelocitySeventh;
            at[\finalDemoStage].(5, "Register and velocity choose the chord-local chart", "Motion=0.5. A D minor chord adapts to C when C is the much lower seventh, and also when C is the much louder seventh. The chart changes; Motion controls how fast the current field follows.");
            at[\finalDemoReset].(0.5);
            at[\finalDemoSetCoreControls].(0.5, 0.0, 0.0, false);
            at[\finalDemoChordOn].([50, 53, 57], 0.58, \finalDemoDmChord);
            at[\finalDemoAdvance].(waitMed, \finalDemoDmChord, nil);
            if(at[\noteOn].notNil) { at[\noteOn].(48, 0.56, nil, false); };
            at[\finalDemoAdvance].(waitLong, \finalDemoLowSeventh, nil);
            if(api[\registerVelocityHarmonicChartReport].notNil) { api[\registerVelocityHarmonicChartReport].(); };
            at[\finalDemoAllNotesOff].();
            at[\finalDemoReset].(0.5);
            at[\finalDemoChordOn].([50, 53, 57], 0.45, \finalDemoDmSoftChord);
            at[\finalDemoAdvance].(waitMed, \finalDemoDmSoftChord, nil);
            if(at[\noteOn].notNil) { at[\noteOn].(60, 1.0, nil, false); };
            at[\finalDemoAdvance].(waitLong, \finalDemoLoudSeventh, nil);
            if(api[\registerVelocityHarmonicChartReport].notNil) { api[\registerVelocityHarmonicChartReport].(); };
            at[\finalDemoAllNotesOff].();
            at[\finalDemoFieldSummary].(\registerVelocitySeventh, 0, true);

            demo[\lastStage] = \memoryContextAndModulation;
            at[\finalDemoStage].(6, "Memory: key-context resistance and modulation", "Motion=0.5, Memory=0.75. Memory does not set motion speed; it learns and resists a contextual home. Modulation can still win over time.");
            at[\finalDemoReset].(0.5);
            at[\finalDemoSetCoreControls].(0.5, 0.75, 0.0, false);
            if(api[\setMemoryLearnRate].notNil) { api[\setMemoryLearnRate].(0.04); };
            at[\finalDemoMusicPhrase].([[48, 52, 55], [53, 57, 60], [55, 59, 62], [48, 52, 55]], 0.62, 0.63, \finalDemoMemoryKeyOne);
            if(api[\memoryReport].notNil) { api[\memoryReport].(); };
            at[\finalDemoMusicPhrase].([[50, 54, 57], [55, 59, 62], [57, 61, 64], [50, 54, 57]], 0.62, 0.63, \finalDemoMemoryModulation);
            if(api[\memoryReport].notNil) { api[\memoryReport].(); };
            at[\finalDemoFieldSummary].(\memoryModulation, 2, true);

            demo[\lastStage] = \gravityA432Memory;
            at[\finalDemoStage].(7, "Gravity: A4 = 432 Hz plus memory", "Motion=0.5, Memory=0.75, Gravity=0.75. A is anchored around 432 Hz while the rest of the field can still adapt to the harmonic context.");
            at[\finalDemoReset].(0.5);
            at[\finalDemoSetCoreControls].(0.5, 0.75, 0.75, false);
            if(api[\setAnchorToNote].notNil) { api[\setAnchorToNote].(9, a432Cents, true); };
            if(api[\gravityReport].notNil) { api[\gravityReport].(); };
            at[\finalDemoMusicPhrase].([[57, 60, 64], [52, 57, 60], [55, 59, 62], [57, 60, 64]], 0.62, 0.64, \finalDemoGravityA432);
            if(api[\gravityReport].notNil) { api[\gravityReport].(); };
            at[\finalDemoMusicPhrase].([[59, 62, 66], [54, 59, 62], [57, 61, 64], [59, 62, 66]], 0.62, 0.64, \finalDemoGravityModulation);
            at[\finalDemoUpdateGravityFromMemory].(9);
            if(api[\gravityReport].notNil) { api[\gravityReport].(); };

            demo[\lastStage] = \adaptiveTimbre;
            at[\finalDemoStage].(8, "Adaptive timbre", "Adaptive Tone changes the selected preset's timbre from the musical state: Motion, Memory, Gravity, coherence, density, external pressure, and Tension. It is sound expression, not hidden pitch law.");
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\electricPiano); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\coherenceBloom); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.58); };
            if(api[\setTension].notNil) { api[\setTension].(0.62); };
            if(api[\adaptiveToneReport].notNil) { api[\adaptiveToneReport].(); };
            at[\finalDemoMusicPhrase].([[48, 52, 55], [53, 57, 60], [55, 59, 62], [57, 60, 64]], 0.62, 0.64, \finalDemoAdaptiveTimbre);
            if(api[\adaptiveToneReport].notNil) { api[\adaptiveToneReport].(); };

            demo[\lastStage] = \boundedSpectrumAccordion;
            at[\finalDemoStage].(9, "Bounded Spectrum / Accordion", "Now an explicit small Spectrum/Accordion amount is enabled. Strange spectra can slightly change the target shape, but Motion still gates movement and spacing/topology safety still wins.");
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\synth); };
            at[\finalDemoSetSpectrumAccordion].(0.18, \inharmonic);
            at[\finalDemoMusicPhrase].([[48, 52, 55], [48, 51, 55, 58], [50, 54, 57]], 0.70, 0.62, \finalDemoSpectrumAccordion);
            if(api[\perceptualSpectrumReport].notNil) { api[\perceptualSpectrumReport].(); };
            if(api[\perceptualCylinderAuthorityReport].notNil) { api[\perceptualCylinderAuthorityReport].(); };

            demo[\lastStage] = \earStableFrequency;
            at[\finalDemoStage].(10, "Ear: stable external frequency becomes Gravity", "The demo captures A=432 through the speakers and microphone, then holds that captured reference as the external scene; Gravity is bound to the heard reference and remains a soft anchor.");
            at[\finalDemoEnableEar].(0.72);
            if((at[\finalDemoCaptureReferenceFrequency].(\earStableA432, 432.0, 9, amp, 0.08, \referenceTone)[\accepted] ? false).not) { ^nil; };
            if((at[\finalDemoCapturedSceneTruthGate].(\earStableA432, 1, \referenceTone, \earMemory)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoBindGravityToBestExternal].(9, a432Cents);
            if(api[\micSceneReport].notNil) { api[\micSceneReport].(); };
            if(api[\gravityReport].notNil) { api[\gravityReport].(); };

            demo[\lastStage] = \earEtInstrument;
            at[\finalDemoStage].(11, "Ear: equal-tempered external instrument", "An ET C-major source is emitted through the speakers while the instrument plays with it. The Ear treats ET as context: follow where needed, improve where safe.");
            at[\finalDemoSetSpectrumAccordion].(0.0, \harmonic);
            at[\finalDemoSetCoreControls].(0.5, 0.75, 0.75, true);
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\electricPiano); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.55); };
            if((at[\finalDemoCaptureExternalScene].(\earETChordLive, [60, 64, 67], amp, \tone, 2, 0.08, \chordCloud)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoExternalChordStart].([60, 64, 67], waitLong * 2.6, amp, \tone);
            if((at[\finalDemoCapturedSceneTruthGate].(\earETChordLive, 2, \chordCloud, \earMemory)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoPlayChord].([62, 65, 69], waitLong, 0.58, \finalDemoPlayWithET);
            at[\finalDemoReportCapturedExternalCoherence].(\earETChordLive, \chordCloud, true);

            demo[\lastStage] = \earEtPlusSinger;
            at[\finalDemoStage].(12, "Ear: ET instrument plus out-of-tune singer", "The ET chord continues, and a flat/wavering singer is added. The instrument does not blindly follow; it makes the best bounded corrections when and where it can.");
            if((at[\finalDemoCaptureExternalScene].(\earETPlusSingerContext, [60, 67], amp * 0.82, \tone, 1, 0.08, \chordCloud)[\accepted] ? false).not) { ^nil; };
            if((at[\finalDemoCaptureExternalScene].(\earFlatSingerLive, [64], amp * 0.9, \singer, 1, 0.08, \song)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoPublishCapturedExternalSources].(\earETPlusSingerLive, ((st[\finalDemoCapturedScenes][\earETPlusSingerContext] ? Array.new) ++ (st[\finalDemoCapturedScenes][\earFlatSingerLive] ? Array.new)), \song);
            at[\finalDemoExternalChordStart].([60, 64, 67], waitLong * 2.6, amp * 0.8, \tone);
            at[\finalDemoExternalToneStart].(at[\midiToFreq].(64), waitLong * 2.4, amp * 0.8, \singer);
            if((at[\finalDemoCapturedSceneTruthGate].(\earETPlusSingerLive, 2, \song, \earMemory)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoPlayChord].([62, 65, 69, 74], waitLong, 0.56, \finalDemoEtPlusSinger);
            if(api[\micSceneReport].notNil) { api[\micSceneReport].(); };
            at[\finalDemoReportCapturedExternalCoherence].(\earETPlusSingerLive, \song, true);

            demo[\lastStage] = \earInharmonicSpectrum;
            at[\finalDemoStage].(13, "Ear: inharmonic / stretched external spectrum", "The demo emits a stretched inharmonic source. The instrument keeps pitch safety while the spectral/accordion layer can add a small bounded target influence.");
            at[\finalDemoSetSpectrumAccordion].(0.20, \inharmonic);
            if((at[\finalDemoCaptureExternalScene].(\earInharmonicLive, [48], amp, \inharmonic, 1, 0.08, \abnormalSpectrum)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoExternalChordStart].([48, 52, 55], waitLong * 2.6, amp, \inharmonic);
            if((at[\finalDemoCapturedSceneTruthGate].(\earInharmonicLive, 1, \abnormalSpectrum, \earMemory)[\accepted] ? false).not) { ^nil; };
            at[\finalDemoPlayChord].([50, 54, 57], waitLong, 0.58, \finalDemoInharmonicExternal);
            if(api[\perceptualSpectrumReport].notNil) { api[\perceptualSpectrumReport].(); };
            at[\finalDemoReportCapturedExternalCoherence].(\earInharmonicLive, \abnormalSpectrum, true);

            demo[\lastStage] = \finalContextAwareInstrument;
            at[\finalDemoStage].(14, "Everything together", "Final playing state: Motion, Memory, Gravity, Ear, adaptive timbre, bounded spectrum/accordion, register/velocity chart, and safety all work together as one instrument.");
            at[\finalDemoSetCoreControls].(0.5, 0.75, 0.75, true);
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(\electricPiano); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.65); };
            at[\finalDemoMusicPhrase].([[48, 52, 55], [53, 57, 60], [55, 59, 62], [57, 60, 64], [50, 53, 57, 60], [48, 52, 55]], 0.70, 0.62, \finalDemoEverythingTogether);
            if(api[\authorityReport].notNil) { api[\authorityReport].(); };
            if(api[\adaptiveToneReport].notNil) { api[\adaptiveToneReport].(); };
            if(api[\pitchIdentitySpacingLegibilityReport].notNil) { api[\pitchIdentitySpacingLegibilityReport].(\ordinary); };

            demo[\lastStage] = \cleanup;
            at[\finalDemoStage].(15, "Cleanup", "All notes off, external sources cleared, Ear off, and a safe musical state restored.");
            at[\finalDemoAllNotesOff].();
            at[\finalDemoClearExternal].();
            if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
            at[\finalDemoSetSpectrumAccordion].(0.0, \harmonic);
            at[\finalDemoSetCoreControls].(0.5, 0.75, 0.75, false);
            if(api[\productReadinessReport].notNil) { api[\productReadinessReport].(); };
            demo[\running] = false;
            demo[\completedAt] = Main.elapsedTime;
            "[AT FINAL DEMO] COMPLETE. Finished first-version product demonstration.".postln;
            nil;
        });
        demo[\routine] = r;
        r.play(AppClock);
        (started: true, mode: m, productFacing: true, regressionSuite: false, usesOnlyPublicControls: true, externalSoundsThroughSpeakersAndMic: true, fakeExternalScenes: false, physicalEarTruthGate: true, liveMicFallbackCountsAsPass: false, liveCapturedExternalScene: true, stagedSceneTruthGate: true, adaptiveGravityFollow: true, staggeredPhysicalExternalCapture: true)
    };

    at[\runFinalDemoScenario] = { |mode=\full| api[\runFinalDemoScenario].(mode) };
    at[\stopFinalDemoScenario] = { api[\stopFinalDemoScenario].() };
    at[\finalDemoScenarioPlan] = { api[\finalDemoScenarioPlan].() };

    "[AT FINAL DEMO] v50b loaded. Run: Library.at(\\at)[\\api][\\runFinalDemoScenario].(); quick: .(\\quick); stop: Library.at(\\at)[\\api][\\stopFinalDemoScenario].();".postln;
};
)
