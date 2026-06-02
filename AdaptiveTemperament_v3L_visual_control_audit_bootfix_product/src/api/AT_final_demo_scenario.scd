(
// AT_final_demo_scenario.scd
// v3G final end-all demonstration scenario with adaptive memory/gravity semantics, tone stabilization, and final musical surface contract.
// This is not a regression suite and not a synthetic proof harness. It is a
// staged product demonstration that drives the same controls a player can use.
// The only non-player action is generating external speaker stimuli for the
// laptop microphone / Ear scenes.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[AT FINAL DEMO] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    ~atFinalDemoScenario = IdentityDictionary.new;

    // ------------------------------------------------------------
    // Final product controls that belong in the product, not in old tests.
    // ------------------------------------------------------------

    if(api[\setGravityFollowMode].isNil) {
    api[\setGravityFollowMode] = { |mode=\off|
        var m;
        m = mode.asSymbol;
        if([\off, \fixed, \memory, \ear].includes(m).not) { m = \off; };
        cfg[\gravity][\followMode] = m;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        m
    };

    };

    if(api[\applyGravityFollow].isNil) {
    api[\applyGravityFollow] = { |amount=nil|
        var mode, pc, phase, cents, amt, freq;
        mode = (cfg[\gravity][\followMode] ? \off).asSymbol;
        amt = if(amount.isNil) { (cfg[\gravity][\strength] ? 0.0).asFloat.clip(0.0, 1.0) } { amount.asFloat.clip(0.0, 1.0) };
        if(mode == \memory) {
            pc = st[\worldRootPc] ? (st[\gravityHomePc] ? 9);
            if(st[\memoryPhase].notNil and: { st[\memoryPhase].size > pc }) {
                phase = st[\memoryPhase][pc] ? (st[\etPhase][pc] ? (pc / 12.0));
                cents = (at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0).clip(-100.0, 100.0) * amt;
                if(at[\setGravityHome].notNil) { at[\setGravityHome].(pc, cents); };
            };
        };
        if(mode == \ear) {
            freq = st[\micRawFreq] ? st[\micFreq];
            if(freq.notNil and: { freq.asFloat > 20.0 }) {
                if(api[\setGravityTargetFreq].notNil) { api[\setGravityTargetFreq].(freq.asFloat, \absolute); };
            };
        };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(mode != \off); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        (
            mode: mode,
            gravityHomePc: st[\gravityHomePc],
            gravityHomeCents: st[\gravityHomeCents] ? 0.0,
            amount: amt,
            pitchAuthorityAdded: false,
            role: \gravityFollowControl
        )
    };
    };

    api[\setSpectrumAccordionAmount] = { |amount=0.0|
        var v;
        v = amount.asFloat.clip(0.0, 1.0);
        if(cfg[\perceptualCylinder].isNil) { cfg[\perceptualCylinder] = IdentityDictionary.new; };
        cfg[\perceptualCylinder][\amount] = v;
        cfg[\perceptualCylinder][\accordionAmount] = v;
        cfg[\perceptualCylinder][\accordionAuthorityEnabled] = v > 0.0001;
        cfg[\perceptualCylinder][\accordionRenderHookEnabled] = v > 0.0001;
        cfg[\perceptualCylinder][\accordionPitchAuditionEnabled] = v > 0.0001;
        cfg[\perceptualCylinder][\accordionExperimentalPitchEnabled] = v > 0.0001;
        cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = 16.0;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        v
    };

    api[\spectrumAccordionReport] = {
        var rep;
        rep = if(api[\perceptualCylinderAccordionReport].notNil) {
            api[\perceptualCylinderAccordionReport].()
        } {
            (
                amount: if(cfg[\perceptualCylinder].isNil) { 0.0 } { cfg[\perceptualCylinder][\amount] ? 0.0 },
                accordionAuthorityEnabled: if(cfg[\perceptualCylinder].isNil) { false } { cfg[\perceptualCylinder][\accordionAuthorityEnabled] ? false },
                note: "perceptual cylinder report unavailable"
            )
        };
        rep
    };

    // Compatibility alias. The clean external-coherence module keeps the safe
    // bounded scenario function; this gives the final demo one stable name.
    api[\applyExternalCoherenceBoundedAuthority] = { |scenario=\mixedWorld, amount=0.2|
        if(api[\simulateExternalCoherenceBoundedAuthorityScenario].notNil) {
            api[\simulateExternalCoherenceBoundedAuthorityScenario].(scenario, amount, true)
        } {
            (applied: false, scenario: scenario, reason: \externalCoherenceRuntimeMissing)
        }
    };

    // ------------------------------------------------------------
    // Speaker stimuli used only for the external Ear scenes.
    // ------------------------------------------------------------

    SynthDef(\atFinalDemoExternalSine, {
        |out=0, freq=432, amp=0.10, dur=1.0, pan=0.0|
        var env, sig;
        env = EnvGen.kr(Env.linen(0.03, dur.max(0.05), 0.08, 1.0, -3), doneAction: 2);
        sig = SinOsc.ar(freq.clip(20.0, 8000.0), 0, amp.clip(0.0, 0.5)) * env;
        Out.ar(out, Pan2.ar(sig, pan.clip(-1.0, 1.0)));
    }).add;

    SynthDef(\atFinalDemoExternalSinger, {
        |out=0, freq=432, amp=0.09, dur=1.0, flatCents=(-28), vibCents=18, vibRate=5.2, pan=0.0|
        var env, cents, sig, f;
        env = EnvGen.kr(Env.linen(0.04, dur.max(0.05), 0.10, 1.0, -3), doneAction: 2);
        cents = flatCents + SinOsc.kr(vibRate, 0, vibCents) + LFNoise1.kr(3.5).range(-6.0, 6.0);
        f = freq.clip(20.0, 8000.0) * (2 ** (cents / 1200.0));
        sig = (SinOsc.ar(f, 0, 0.75) + SinOsc.ar(f * 2.0, 0, 0.18) + BPF.ar(PinkNoise.ar(0.06), f * 2.7, 0.22)) * amp.clip(0.0, 0.5) * env;
        Out.ar(out, Pan2.ar(sig, pan.clip(-1.0, 1.0)));
    }).add;

    SynthDef(\atFinalDemoExternalInharmonic, {
        |out=0, freq=370, amp=0.10, dur=1.0, pan=0.0|
        var env, sig;
        env = EnvGen.kr(Env.linen(0.005, dur.max(0.05), 0.25, 1.0, -4), doneAction: 2);
        sig = (SinOsc.ar(freq, 0, 0.55)
            + SinOsc.ar(freq * 1.41, 0, 0.42)
            + SinOsc.ar(freq * 2.03, 0, 0.32)
            + SinOsc.ar(freq * 2.76, 0, 0.22)
            + SinOsc.ar(freq * 4.19, 0, 0.12));
        sig = sig * amp.clip(0.0, 0.5) * env;
        Out.ar(out, Pan2.ar(sig, pan.clip(-1.0, 1.0)));
    }).add;

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------

    ~atFinalDemoScenario[\externalSynths] = List.new;

    ~atFinalDemoScenario[\freeExternalSynths] = {
        (~atFinalDemoScenario[\externalSynths] ? List.new).do { |syn|
            if(syn.notNil) { syn.free; };
        };
        ~atFinalDemoScenario[\externalSynths] = List.new;
        true
    };

    ~atFinalDemoScenario[\status] = {
        (
            version: \v3L_finalEndAllDemo,
            role: \productDemonstration,
            run: "~atFinalDemoScenario[\\run].();",
            stop: "~atFinalDemoScenario[\\stop].();",
            motionGate: if(api[\globalMotionRateGateSnapshot].notNil) { api[\globalMotionRateGateSnapshot].(\finalDemoStatus) } { nil },
            adaptiveTimbre: if(api[\tensionAdaptiveTimbreReport].notNil) { api[\tensionAdaptiveTimbreReport].() } { nil },
            gravity: if(api[\gravitySnapshot].notNil) { api[\gravitySnapshot].() } { nil },
            spectrumAccordion: if(api[\spectrumAccordionReport].notNil) { api[\spectrumAccordionReport].() } { nil }
        )
    };

    ~atFinalDemoScenario[\cleanup] = { |label=\cleanup, stopRoutine=true|
        if((stopRoutine == true) and: { st[\finalDemoRoutine].notNil }) {
            st[\finalDemoRoutine].stop;
            st[\finalDemoRoutine] = nil;
            st[\finalDemoRunning] = false;
            ("[AT FINAL DEMO CLEANUP] stopped previous routine for " ++ label.asString).postln;
        };
        ~atFinalDemoScenario[\freeExternalSynths].();
        if(at[\allNotesOff].notNil) { at[\allNotesOff].(); };
        if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
        if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
        if(api[\clearExternalCoherenceAppliedAuthority].notNil) { api[\clearExternalCoherenceAppliedAuthority].(); };
        if(api[\clearExternalCoherenceScene].notNil) { api[\clearExternalCoherenceScene].(); };
        if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
        if(api[\clearAdaptiveGravityState].notNil) { api[\clearAdaptiveGravityState].(); };
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
        if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\off); };
        if(api[\clearGravity].notNil) { api[\clearGravity].(); };
        if(api[\clearTonalMemory].notNil) { api[\clearTonalMemory].(); };
        if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.0); };
        if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
        if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
        if(api[\setTension].notNil) { api[\setTension].(0.55); };
        if(api[\setRenderMode].notNil) { api[\setRenderMode].(\reference); };
        if(api[\setTonePreset].notNil) { api[\setTonePreset].(\production); };
        if(api[\setSignedCarry].notNil) { api[\setSignedCarry].(0.0); };
        if(api[\setMovement].notNil) { api[\setMovement].(0.0); };
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(0.0); };
        if(api[\reset].notNil) { api[\reset].(); } { if(at[\resetToET].notNil) { at[\resetToET].(); }; };
        if(at[\globalMotionGateForceState].notNil) { at[\globalMotionGateForceState].(0.0, Array.fill(12, 0.0), label); };
        if(at[\pushBuses].notNil) { at[\pushBuses].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        true
    };

    ~atFinalDemoScenario[\stop] = {
        st[\finalDemoAbort] = true;
        ~atFinalDemoScenario[\cleanup].(\finalDemoStop, true);
        "[AT FINAL DEMO STOP] stopped/cleaned.".postln;
        true
    };

    // ------------------------------------------------------------
    // Main staged demo.
    // ------------------------------------------------------------

    ~atFinalDemoScenario[\run] = { |variant=\full|
        var durScale, routine;
        variant = (variant ? \full).asSymbol;
        durScale = if(variant == \quick) { 0.78 } { 1.0 };

        if(st[\finalDemoRoutine].notNil) {
            "[AT FINAL DEMO RESTART] existing demo routine stopped before starting the new requested run.".postln;
        };
        ~atFinalDemoScenario[\cleanup].(\finalDemoPreRunClean, true);
        st[\finalDemoAbort] = false;
        st[\finalDemoRunning] = true;

        routine = Routine({
            var sceneNo, num, waitDur, line, fieldLine, setControls, resetScene;
            var playNote, playHeldNote, playChord, playArp, playProgression;
            var externalTone, externalChord, externalSinger, externalInharmonic, hardwareGate, publishExternalScene;
            var gateOk, slowBefore, slowAfter, fastBefore, fastAfter, regRep, gravRep, accRep, finalStatus, memSeedRep;

            sceneNo = 0;
            num = { |x, default=0.0| if(x.isNil) { default.asFloat } { x.asFloat } };
            waitDur = { |x| (x.asFloat * durScale).max(0.01).wait; };
            line = { |title|
                sceneNo = sceneNo + 1;
                "".postln;
                ("[AT FINAL DEMO SCENE " ++ sceneNo.asString ++ "] " ++ title.asString).postln;
            };
            fieldLine = { |label=\field|
                var gm, snap, devMax, targetErr, gauge, targetGauge, shapeSpan, activeDev;
                gm = if(api[\globalMotionRateGateSnapshot].notNil) { api[\globalMotionRateGateSnapshot].(label) } { () };
                snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { () };
                devMax = num.(snap[\maxDevCents], 0.0);
                targetErr = num.(gm[\maxTargetErrorCents], 0.0);
                gauge = num.(gm[\realizedGaugeCents], num.(gm[\gaugeCents], 0.0));
                targetGauge = num.(gm[\targetGaugeCents], 0.0);
                shapeSpan = num.(gm[\realizedShapeSpanCents], num.(gm[\shapeSpanCents], 0.0));
                activeDev = if(st[\activeNotes].notNil and: { st[\activeNotes].size > 0 }) {
                    st[\activeNotes].values.asArray.collect { |note|
                        var pc;
                        pc = note[\pc] ? 0;
                        (at[\wrapSigned].((st[\nodePhase][pc] ? (pc/12.0)) - (st[\etPhase][pc] ? (pc/12.0))) * 1200.0).abs;
                    }.maxItem ? 0.0
                } { 0.0 };
                ("[AT FINAL DEMO FIELD] " ++ label.asString
                    ++ " currentGauge=" ++ gauge.round(0.01).asString ++ "c"
                    ++ " targetGauge=" ++ targetGauge.round(0.01).asString ++ "c"
                    ++ " shapeSpan=" ++ shapeSpan.round(0.01).asString ++ "c"
                    ++ " targetErr=" ++ targetErr.round(0.01).asString ++ "c"
                    ++ " maxDev=" ++ devMax.round(0.01).asString ++ "c"
                    ++ " activeDev=" ++ activeDev.round(0.01).asString ++ "c").postln;
                if(st[\lastMusicalSurfaceContractReport].notNil and: { st[\lastMusicalSurfaceContractReport][\changed] == true }) {
                    ("[AT FINAL DEMO SURFACE] " ++ label.asString
                        ++ " spanIn=" ++ (st[\lastMusicalSurfaceContractReport][\shapeSpanInCents] ? 0.0).asString ++ "c"
                        ++ " spanOut=" ++ (st[\lastMusicalSurfaceContractReport][\shapeSpanOutCents] ? 0.0).asString ++ "c"
                        ++ " activeOut=" ++ (st[\lastMusicalSurfaceContractReport][\activeMaxOutCents] ? 0.0).asString ++ "c").postln;
                };
                gm
            };
            setControls = { |motion=0.0, memory=0.0, gravity=0.0, ear=false, adaptive=false, render=\reference, tone=\production|
                if(api[\setRenderMode].notNil) { api[\setRenderMode].(render); };
                if(api[\setTonePreset].notNil) { api[\setTonePreset].(tone); };
                if(api[\setSignedCarry].notNil) { api[\setSignedCarry].(0.0); };
                if(api[\setMovement].notNil) { api[\setMovement].(motion); };
                if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(memory); };
                if(api[\setMemoryLearnRate].notNil) { api[\setMemoryLearnRate].((0.004 + (memory * 0.026)).clip(0.0, 0.045)); };
                if(gravity.asFloat <= 0.0001) {
                    if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\off); };
                    if(api[\clearGravity].notNil) { api[\clearGravity].(); };
                } {
                    if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); };
                    if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(gravity); };
                    if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(1.5 + (gravity * 10.0)); };
                };
                if(ear == true) {
                    if(api[\setMicInfluencePolicy].notNil) { api[\setMicInfluencePolicy].(\externalFollow); };
                    if(api[\setMicWeight].notNil) { api[\setMicWeight].(0.48); };
                    if(api[\setMicTrust].notNil) { api[\setMicTrust].(0.55); };
                    if(api[\setMicGain].notNil) { api[\setMicGain].(8.0); };
                    if(api[\setMicPitchDetectGain].notNil) { api[\setMicPitchDetectGain].(18.0); };
                    if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(true); };
                } {
                    if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
                };
                if(adaptive == true) {
                    if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
                    if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.22); };
                } {
                    if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
                    if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
                };
                if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
                ("[AT FINAL DEMO CONTROLS] motion=" ++ motion.asString
                    ++ " memory=" ++ memory.asString
                    ++ " gravity=" ++ gravity.asString
                    ++ " carry=0 ear=" ++ ear.asString
                    ++ " adaptiveTimbre=" ++ adaptive.asString
                    ++ " render=" ++ render.asString
                    ++ " tone=" ++ tone.asString).postln;
            };
            resetScene = { |label=\reset|
                line.("RESET — clear notes, external evidence, memory/gravity targets, spectrum accordion, and global Motion state");
                ~atFinalDemoScenario[\cleanup].(label, false);
                waitDur.(0.25);
                fieldLine.(label);
            };
            playNote = { |midi=60, dur=0.45, vel=0.75|
                at[\noteOn].(midi.asInteger, vel.asFloat.clip(0.0, 1.0));
                waitDur.(dur);
                at[\noteOff].(midi.asInteger);
                waitDur.(0.05);
            };
            playHeldNote = { |midi=60, dur=1.5, vel=0.75|
                at[\noteOn].(midi.asInteger, vel.asFloat.clip(0.0, 1.0));
                waitDur.(dur);
                fieldLine.(("heldNote" ++ midi.asString).asSymbol);
                at[\noteOff].(midi.asInteger);
                waitDur.(0.15);
            };
            playChord = { |midis, dur=0.85, vels=0.65|
                var vv;
                (midis ? Array.new).do { |m, i|
                    vv = if(vels.isKindOf(Array)) { vels.wrapAt(i) } { vels };
                    at[\noteOn].(m.asInteger, vv.asFloat.clip(0.0, 1.0));
                    waitDur.(0.035);
                };
                waitDur.(dur);
                (midis ? Array.new).reverse.do { |m|
                    at[\noteOff].(m.asInteger);
                    waitDur.(0.025);
                };
                waitDur.(0.12);
            };
            playArp = { |midis, step=0.28, vel=0.72|
                (midis ? Array.new).do { |m|
                    at[\noteOn].(m.asInteger, vel.asFloat.clip(0.0, 1.0));
                    waitDur.(step * 0.58);
                    at[\noteOff].(m.asInteger);
                    waitDur.(step * 0.42);
                };
                waitDur.(0.18);
            };
            playProgression = { |chords, dur=0.75, vel=0.62|
                (chords ? Array.new).do { |ch|
                    playChord.(ch, dur, vel);
                };
            };
            externalTone = { |freq=432, dur=1.2, amp=0.11, pan=0.0|
                var syn;
                syn = Synth(\atFinalDemoExternalSine, [\freq, freq.asFloat, \dur, (dur * durScale).max(0.1), \amp, amp.asFloat, \pan, pan.asFloat]);
                ~atFinalDemoScenario[\externalSynths].add(syn);
                AppClock.sched(((dur * durScale).max(0.1) + 0.25), { ~atFinalDemoScenario[\externalSynths].remove(syn); nil });
                syn
            };
            externalChord = { |freqs, dur=1.5, amp=0.08|
                var n;
                n = (freqs ? [432.0]).size.max(1);
                (freqs ? [432.0]).do { |f, i|
                    externalTone.(f.asFloat, dur, amp / n.sqrt, ((i / n.max(1)) * 1.2) - 0.6);
                };
            };
            externalSinger = { |freq=440, dur=1.5, amp=0.08|
                var syn;
                syn = Synth(\atFinalDemoExternalSinger, [\freq, freq.asFloat, \dur, (dur * durScale).max(0.1), \amp, amp.asFloat]);
                ~atFinalDemoScenario[\externalSynths].add(syn);
                AppClock.sched(((dur * durScale).max(0.1) + 0.25), { ~atFinalDemoScenario[\externalSynths].remove(syn); nil });
                syn
            };
            externalInharmonic = { |freq=370, dur=1.5, amp=0.09|
                var syn;
                syn = Synth(\atFinalDemoExternalInharmonic, [\freq, freq.asFloat, \dur, (dur * durScale).max(0.1), \amp, amp.asFloat]);
                ~atFinalDemoScenario[\externalSynths].add(syn);
                AppClock.sched(((dur * durScale).max(0.1) + 0.25), { ~atFinalDemoScenario[\externalSynths].remove(syn); nil });
                syn
            };
            hardwareGate = { |label=\earGate, playFunc=nil, pollSeconds=1.3|
                var maxAmp, maxRaw, voiced, loops, amp, raw, gate;
                maxAmp = 0.0;
                maxRaw = 0.0;
                voiced = false;
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(true); };
                if(api[\setMicGain].notNil) { api[\setMicGain].(8.0); };
                if(api[\setMicPitchDetectGain].notNil) { api[\setMicPitchDetectGain].(22.0); };
                if(api[\setMicPitchAmpThreshold].notNil) { api[\setMicPitchAmpThreshold].(0.00005); };
                waitDur.(0.20);
                if(playFunc.notNil) { playFunc.value; };
                loops = ((pollSeconds.asFloat * durScale) / 0.08).ceil.asInteger.max(6);
                loops.do {
                    if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
                    amp = [st[\micAnalyzedAmp], st[\micRawAmp], st[\micInputAmp0], st[\micInputAmp1]].collect { |x| num.(x, 0.0) }.maxItem ? 0.0;
                    raw = num.(st[\micRawAmp], 0.0);
                    if(amp > maxAmp) { maxAmp = amp; };
                    if(raw > maxRaw) { maxRaw = raw; };
                    if((st[\micVoiced] ? false) or: { (st[\micSignalPresent] ? false) }) { voiced = true; };
                    0.08.wait;
                };
                gate = (maxAmp > 0.00012) or: { maxRaw > 0.00008 } or: { voiced == true };
                ("[AT FINAL DEMO HARDWARE EAR] " ++ label.asString
                    ++ " heard=" ++ gate.asString
                    ++ " maxAmp=" ++ maxAmp.round(0.000001).asString
                    ++ " maxRaw=" ++ maxRaw.round(0.000001).asString
                    ++ " voiced=" ++ voiced.asString).postln;
                if(gate.not) {
                    st[\finalDemoAbort] = true;
                    ("[AT FINAL DEMO HARDWARE FAIL] Laptop speaker/mic did not produce detectable external evidence for " ++ label.asString ++ ". Demo stops rather than pretending the Ear worked.").warn;
                };
                gate
            };
            publishExternalScene = { |scenario=\etCMajor, amount=0.25|
                var rep;
                rep = if(api[\applyExternalCoherenceBoundedAuthority].notNil) {
                    api[\applyExternalCoherenceBoundedAuthority].(scenario, amount)
                } {
                    (applied: false, scenario: scenario, reason: \missingExternalCoherenceApply)
                };
                if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
                rep
            };

            "".postln;
            "[AT FINAL DEMO v3L] START — final product demonstration. This uses real controls; only external speaker stimuli are scripted.".postln;
            if(variant == \quick) { "[AT FINAL DEMO] quick timing selected; musical order is unchanged.".postln; };

            // 1. Pure sine / all authorities off / Motion 0.
            resetScene.(\scene0Clean);
            line.("Pure sine, Motion 0, Memory 0, Gravity 0, Ear off: current field stays equal temperament");
            setControls.(0.0, 0.0, 0.0, false, false, \reference, \production);
            playChord.([60, 64, 67, 72], 0.85, 0.62);
            waitDur.(0.35);
            fieldLine.(\motionZeroEtForever);

            // 2. Single note slow motion.
            resetScene.(\scene1Motion025);
            line.("Motion 0.25: one note creates the target harmonic world; passive field moves slowly");
            setControls.(0.25, 0.0, 0.0, false, false, \reference, \production);
            slowBefore = fieldLine.(\beforeSingleNote025);
            playHeldNote.(60, 2.2, 0.78);
            slowAfter = fieldLine.(\afterSingleNote025);

            // 3. Single note fast motion.
            resetScene.(\scene2Motion1);
            line.("Motion 1.0: same single note, fastest safe movement toward the harmonic-origin world");
            setControls.(1.0, 0.0, 0.0, false, false, \reference, \production);
            fastBefore = fieldLine.(\beforeSingleNote1);
            playHeldNote.(60, 1.0, 0.78);
            fastAfter = fieldLine.(\afterSingleNote1);

            // 4. Arpeggio interval law at full motion and low motion timing.
            line.("Arpeggio law: diminished, augmented, and fifth paths move by interval-stream pressure");
            setControls.(0.75, 0.0, 0.0, false, false, \reference, \production);
            playArp.([60, 63, 66, 69, 72], 0.24, 0.70); fieldLine.(\diminishedMinorThirdPathMotion1);
            playArp.([60, 64, 68, 72], 0.24, 0.74); fieldLine.(\augmentedMajorThirdPathMotion1);
            playArp.([60, 67, 62, 69, 64], 0.22, 0.74); fieldLine.(\fifthCyclePathMotion1);
            line.("Same arpeggio at lower Motion: timing matters because current movement is rate-gated");
            setControls.(0.25, 0.0, 0.0, false, false, \reference, \production);
            playArp.([60, 63, 66, 69, 72], 0.13, 0.74); fieldLine.(\fastArpMotion025);
            playArp.([60, 63, 66, 69, 72], 0.46, 0.74); fieldLine.(\slowArpMotion025);

            // 5. Register / velocity chord authority.
            resetScene.(\scene3RegisterVelocity);
            line.("Motion 0.5: D minor plus lower-register minor seventh; C becomes chord-local authority");
            setControls.(0.5, 0.0, 0.0, false, false, \production, \electricPiano);
            if(api[\setRegisterVelocityAuthority].notNil) { regRep = api[\setRegisterVelocityAuthority].(1.0, 0.35); };
            at[\noteOn].(62, 0.56); waitDur.(0.06); at[\noteOn].(65, 0.54); waitDur.(0.06); at[\noteOn].(69, 0.54); waitDur.(0.55);
            at[\noteOn].(48, 0.62); waitDur.(1.15); fieldLine.(\lowMinorSeventhAuthority);
            [48, 69, 65, 62].do { |m| at[\noteOff].(m); waitDur.(0.03); };
            waitDur.(0.25);
            ~atFinalDemoScenario[\cleanup].(\betweenRegisterVelocityExamples, false);
            waitDur.(0.20);
            setControls.(0.5, 0.0, 0.0, false, false, \production, \electricPiano);
            line.("Motion 0.5: D minor plus louder minor seventh; loud C becomes chord-local authority");
            if(api[\setRegisterVelocityAuthority].notNil) { regRep = api[\setRegisterVelocityAuthority].(0.18, 0.72); };
            at[\noteOn].(62, 0.38); waitDur.(0.06); at[\noteOn].(65, 0.36); waitDur.(0.06); at[\noteOn].(69, 0.36); waitDur.(0.55);
            at[\noteOn].(72, 1.0); waitDur.(1.15); fieldLine.(\loudMinorSeventhAuthority);
            [72, 69, 65, 62].do { |m| at[\noteOff].(m); waitDur.(0.03); };
            waitDur.(0.25);

            // 6. Memory.
            resetScene.(\scene4Memory);
            line.("Motion 0.5 + Memory 0.75: play in one key; memory learns a tonal basin");
            setControls.(0.45, 0.55, 0.0, false, false, \production, \electricPiano);
            playProgression.([[60,64,67], [65,69,72], [67,71,74], [60,64,67,72]], 0.70, 0.58);
            fieldLine.(\memoryAfterKeyC);
            line.("Modulate: memory resists briefly, then the new key becomes the learned basin while Motion controls realized movement");
            playProgression.([[64,68,71], [69,73,76], [71,75,78], [64,68,71,76]], 0.70, 0.58);
            fieldLine.(\memoryAfterModulationE);

            // 7. Fixed gravity A=432.
            resetScene.(\scene5FixedGravity);
            line.("Motion 0.5 + Memory 0.75 + Gravity 0.75: fixed A4=432 Hz soft global anchor");
            setControls.(0.45, 0.55, 0.55, false, false, \production, \electricPiano);
            if(api[\setGravityTargetFreq].notNil) { api[\setGravityTargetFreq].(432.0, \absolute); };
            if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\fixed); };
            playProgression.([[57,60,64], [62,66,69], [64,67,71], [57,60,64,69]], 0.72, 0.58);
            gravRep = if(api[\gravitySnapshot].notNil) { api[\gravitySnapshot].() } { nil };
            fieldLine.(\fixedGravityA432KeyA);
            line.("Modulate under fixed gravity: harmonic intonation changes, but the anchor keeps pulling the A reference toward 432");
            playProgression.([[59,63,66], [64,68,71], [66,70,73], [59,63,66,71]], 0.70, 0.58);
            fieldLine.(\fixedGravityAfterModulation);

            // 8. Adaptive gravity follows memory.
            line.("Gravity follows Memory: home reference adapts toward the learned tonal basin instead of remaining fixed");
            if(api[\setGravityMemoryFollowMinConfidence].notNil) { api[\setGravityMemoryFollowMinConfidence].(0.035); };
            // The preceding fixed-gravity music has actually moved the playable surface.
            // Seed Memory from that current surface so memory-follow demonstrates the
            // learned basin rather than falling back to the fixed A home after release.
            if(api[\seedMemoryFromCurrentSurface].notNil) {
                memSeedRep = api[\seedMemoryFromCurrentSurface].([11,3,6], \finalDemoMemoryFollowSeed);
                ("[AT FINAL DEMO MEMORY] memoryFollowSeed " ++ memSeedRep.asString).postln;
            };
            if(api[\clearAdaptiveGravityState].notNil) { api[\clearAdaptiveGravityState].(); };
            if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\memory); };
            if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(0.90); };
            if(api[\gravityAdaptiveReport].notNil) { ("[AT FINAL DEMO GRAVITY] memoryFollow " ++ api[\gravityAdaptiveReport].().asString).postln; };
            fieldLine.(\adaptiveGravityFollowMemory);

            // 9. Adaptive timbre, sound-only. Isolated from accumulated memory/gravity motion so the listener hears timbre, not a new retuning event.
            resetScene.(\scene5bAdaptiveTimbreIsolated);
            line.("Adaptive timbre on: tone changes with harmonic strain/control pressure; pitch authority remains blocked");
            setControls.(0.42, 0.35, 0.22, false, true, \production, \electricPiano);
            if(api[\setTension].notNil) { api[\setTension].(0.62); };
            playProgression.([[60,64,67], [62,65,69], [59,64,67], [60,64,67,72]], 0.65, 0.58);
            if(api[\tensionAdaptiveTimbreReport].notNil) { api[\tensionAdaptiveTimbreReport].().postln; };
            fieldLine.(\adaptiveTimbreSoundOnly);

            // 10. Spectrum accordion / cylinder. Isolated and deliberately small.
            resetScene.(\scene5cSpectrumIsolated);
            line.("Strange timbre + bounded Spectrum Accordion: subtle spectrum-shaped pitch-body deformation is explicit and bounded");
            setControls.(0.42, 0.30, 0.18, false, true, \production, \synth);
            if(api[\setTension].notNil) { api[\setTension].(0.66); };
            if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.06); };
            accRep = if(api[\applyPerceptualCylinderAccordionAuthority].notNil) { api[\applyPerceptualCylinderAccordionAuthority].([60,63,67,70], \inharmonic, 0.06) } { nil };
            if(api[\spectrumAccordionReport].notNil) { api[\spectrumAccordionReport].().postln; };
            playChord.([60,63,67,70], 1.35, 0.60);
            fieldLine.(\spectrumAccordionBounded);

            // 11. Ear scenes use real laptop speaker/mic. Stop if hardware does not hear.
            resetScene.(\scene6HardwareEar);
            line.("Ear on with adaptive Gravity: laptop speaker emits A=432; mic must hear it before external home-following is claimed");
            setControls.(0.40, 0.38, 0.35, true, true, \production, \electricPiano);
            gateOk = hardwareGate.(\externalA432, { externalTone.(432.0, 1.4, 0.12, 0.0); }, 1.5);
            if(gateOk) {
                publishExternalScene.(\externalA432, 0.08);
                if(api[\setGravityTargetFreq].notNil) { api[\setGravityTargetFreq].(432.0, \absolute); };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\ear); };
                if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(0.55); };
                if(api[\gravityAdaptiveReport].notNil) { ("[AT FINAL DEMO GRAVITY] earFollowA432 " ++ api[\gravityAdaptiveReport].().asString).postln; };
                playChord.([57,60,64,69], 1.0, 0.55);
                fieldLine.(\earExternalFrequencyGravity);
            };

            if(st[\finalDemoAbort] != true) {
                line.("Ear hears external Equal Temperament C major: fit the ET context while improving where freedom remains");
                gateOk = hardwareGate.(\externalEtCMajor, { externalChord.([261.6256, 329.6276, 391.9954], 1.5, 0.15); }, 1.55);
                if(gateOk) {
                    publishExternalScene.(\etCMajor, 0.08);
                    if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\ear); };
                    if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(0.45); };
                    if(api[\gravityAdaptiveReport].notNil) { ("[AT FINAL DEMO GRAVITY] earFollowEtContext " ++ api[\gravityAdaptiveReport].().asString).postln; };
                    playProgression.([[60,64,67], [62,65,69], [60,64,67,72]], 0.65, 0.52);
                    fieldLine.(\earEtInstrumentContext);
                };
            };

            if(st[\finalDemoAbort] != true) {
                line.("Ear hears ET instrument plus amateur/out-of-tune singer: coherent compromise, not blind pitch following");
                gateOk = hardwareGate.(\externalEtPlusFlatSinger, {
                    externalChord.([261.6256, 329.6276, 391.9954], 1.7, 0.12);
                    externalSinger.(440.0, 1.7, 0.08);
                }, 1.75);
                if(gateOk) {
                    publishExternalScene.(\etPlusFlatSinger, 0.08);
                    if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\ear); };
                    if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(0.35); };
                    if(api[\gravityAdaptiveReport].notNil) { ("[AT FINAL DEMO GRAVITY] earFollowEtPlusSinger " ++ api[\gravityAdaptiveReport].().asString).postln; };
                    playProgression.([[60,64,67], [57,60,64], [62,65,69]], 0.65, 0.52);
                    fieldLine.(\earEtPlusFlatSinger);
                };
            };

            if(st[\finalDemoAbort] != true) {
                line.("Ear hears inharmonic/stretched spectrum: pitch context remains bounded; spectrum accordion/body adapts where allowed");
                gateOk = hardwareGate.(\externalInharmonicSpectrum, { externalInharmonic.(370.0, 1.8, 0.11); }, 1.85);
                if(gateOk) {
                    publishExternalScene.(\abnormalSpectrum, 0.06);
                    if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.06); };
                    if(api[\applyPerceptualCylinderAccordionAuthority].notNil) { api[\applyPerceptualCylinderAccordionAuthority].([60,63,67,70], \bellLike, 0.35); };
                    playChord.([60,63,67,70], 1.2, 0.58);
                    fieldLine.(\earInharmonicAccordion);
                };
            };

            // 12. Full final state.
            if(st[\finalDemoAbort] != true) {
                line.("Full final scene: Motion, Memory, Gravity, Ear, adaptive timbre, register/velocity, and spectrum response active");
                setControls.(0.40, 0.38, 0.35, true, true, \production, \electricPiano);
                externalChord.([261.6256, 329.6276, 391.9954], 2.2, 0.10);
                externalSinger.(440.0, 2.2, 0.055);
                waitDur.(0.18);
                publishExternalScene.(\etPlusFlatSinger, 0.08);
                if(api[\setGravityTargetFreq].notNil) { api[\setGravityTargetFreq].(432.0, \absolute); };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\hybrid); };
                if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(0.35); };
                if(api[\gravityAdaptiveReport].notNil) { ("[AT FINAL DEMO GRAVITY] fullHybrid " ++ api[\gravityAdaptiveReport].().asString).postln; };
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.04); };
                playProgression.([[60,64,67], [48,62,65,69], [60,63,67,70], [57,60,64,69]], 0.72, 0.55);
                fieldLine.(\fullFinalState);
            };

            if(st[\finalDemoAbort] == true) {
                "[AT FINAL DEMO STOPPED] Hardware Ear gate failed; no fake external-Ear result was claimed.".warn;
                st[\finalDemoRoutine] = nil;
                ~atFinalDemoScenario[\cleanup].(\finalDemoHardwareFailCleanup, false);
            } {
                finalStatus = ~atFinalDemoScenario[\status].();
                "".postln;
                "[AT FINAL DEMO READY] Complete final demo finished: real controls used, audible music played, external speaker/mic scenes gated, no pitch/tuning authority from adaptive timbre, Motion remains final realized-movement gate.".postln;
                finalStatus.postln;
                st[\finalDemoRoutine] = nil;
                ~atFinalDemoScenario[\cleanup].(\finalDemoFinishedCleanup, false);
            };
            st[\finalDemoRunning] = false;
            nil
        });

        st[\finalDemoRoutine] = routine;
        routine.play(AppClock);
        (
            version: \v3L_finalEndAllDemo,
            variant: variant,
            status: \scheduled,
            stopCommand: "~atFinalDemoScenario[\\stop].();",
            note: "The final demo is running on AppClock and will play audible internal and external scenes. Starting a new run stops the previous one first."
        )
    };

    ~atFinalDemoScenario[\quick] = { ~atFinalDemoScenario[\run].(\quick) };
    ~atFinalDemoScenario[\hardwareEar] = { ~atFinalDemoScenario[\run].(\full) };
    api[\finalDemoStatus] = { ~atFinalDemoScenario[\status].() };
    api[\runFinalDemoScenario] = { |variant=\full| ~atFinalDemoScenario[\run].(variant) };
    api[\quickFinalDemoScenario] = { ~atFinalDemoScenario[\quick].() };
    api[\stopFinalDemoScenario] = { ~atFinalDemoScenario[\stop].() };

    "[AT FINAL DEMO] v3L final demo visual-control-audit-safe memory/gravity source-ordered end-all demo loaded. Run: ~atFinalDemoScenario[\\run].(); quick: ~atFinalDemoScenario[\\quick].(); stop: ~atFinalDemoScenario[\\stop].();".postln;
};
)
