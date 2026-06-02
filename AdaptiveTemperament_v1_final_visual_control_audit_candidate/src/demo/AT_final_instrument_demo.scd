
(
// AT_final_instrument_demo.scd — v67o first-version final product demo physical capture stabilization.
// This is not a regression suite. It is a guided performance that uses the
// same public controls as the UI/API, plays real internal voices, and creates
// external context only as real speaker audio for the laptop mic to hear.
{
    var build, at, cfg, st, api, demo, pitchNames;

    build = ~atBuild;
    if(build.isNil) {
        "[AT FINAL INSTRUMENT DEMO] ~atBuild missing".warn;
    } {
        at = build[\at];
        cfg = build[\cfg];
        st = build[\state];
        api = build[\api];
        pitchNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
        demo = IdentityDictionary.new;

        demo[\summaryPath] = {
            var base;
            base = at[\baseDir];
            if(base.notNil) { base +/+ "final_product_demo_summary.log" } { "final_product_demo_summary.log" }
        };

        demo[\save] = {
            (
                powerEnabled: st[\powerEnabled] ? true,
                brainEnabled: st[\brainEnabled] ? true,
                micEnabled: cfg[\mic][\enabled] ? false,
                micWeight: cfg[\mic][\weight] ? 0.0,
                micTrust: cfg[\mic][\trust] ? 0.70,
                micPolicy: cfg[\mic][\influencePolicy] ? \externalOnly,
                micGain: cfg[\mic][\gain] ? 8.0,
                micAmpThreshold: cfg[\mic][\ampThreshold] ? 0.0012,
                micPitchAmpThreshold: cfg[\mic][\pitchAmpThreshold] ? 0.00025,
                micPitchDetectGain: cfg[\mic][\pitchDetectGain] ? 10.0,
                micZeroCrossAmpThreshold: cfg[\mic][\zeroCrossAmpThreshold] ? 0.00018,
                externalStimulusMasterAmp: if(cfg[\externalStimulus].notNil) { cfg[\externalStimulus][\masterAmp] ? 1.0 } { 1.0 },
                memoryEnabled: cfg[\memory][\enabled] ? true,
                memoryAmount: st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0),
                gravityEnabled: cfg[\gravity][\enabled] ? false,
                gravityStrength: cfg[\gravity][\strength] ? 0.0,
                gravityMaxPullCents: cfg[\gravity][\maxPullCents] ? 0.0,
                gravityHomePc: cfg[\gravity][\homePc] ? 9,
                gravityHomeCents: cfg[\gravity][\homeCents] ? 0.0,
                movement: st[\movement] ? 1.0,
                carryEnabled: cfg[\solver][\contextGaugeEnabled] ? false,
                carryStrength: cfg[\solver][\contextGaugeStrength] ? 0.0,
                tension: st[\tension] ? 0.55,
                toneProfile: cfg[\render][\toneProfile] ? \pure,
                adaptiveToneMode: cfg[\render][\adaptiveToneMode] ? \static,
                adaptiveToneAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
                masterAmp: cfg[\render][\masterAmp] ? 1.0,
                runtimeRunning: st[\runtimeRunning] ? false,
                earGravityFollowMode: if(cfg[\finalControls].notNil) { cfg[\finalControls][\earGravityFollowMode] ? \off } { \off },
                spectrumAccordionAmount: if(cfg[\finalControls].notNil) { cfg[\finalControls][\spectrumAccordionAmount] ? 0.0 } { 0.0 },
                spectrumAccordionProfile: if(cfg[\finalControls].notNil) { cfg[\finalControls][\spectrumAccordionProfile] ? \harmonic } { \harmonic }
            )
        };

        demo[\restore] = { |saved|
            if(at[\externalStimulus].notNil) { at[\externalStimulus][\stop].(); };
            if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
            if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
            st[\sustainDown] = false;
            if(saved.notNil) {
                if(api[\setPowerEnabled].notNil) { api[\setPowerEnabled].(saved[\powerEnabled]); };
                if(api[\setBrainEnabled].notNil) { api[\setBrainEnabled].(saved[\brainEnabled]); };
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
                if(api[\setMacro].notNil) {
                    api[\setMacro].(\motion, saved[\movement]);
                    api[\setMacro].(\memory, saved[\memoryAmount]);
                    api[\setMacro].(\tension, saved[\tension]);
                    api[\setMacro].(\carry, 0.0);
                };
                cfg[\solver][\contextGaugeEnabled] = saved[\carryEnabled];
                cfg[\solver][\contextGaugeStrength] = saved[\carryStrength];
                if(cfg[\gravity].notNil) {
                    cfg[\gravity][\enabled] = saved[\gravityEnabled];
                    cfg[\gravity][\strength] = saved[\gravityStrength];
                    cfg[\gravity][\maxPullCents] = saved[\gravityMaxPullCents];
                    if(api[\setGravityHome].notNil) { api[\setGravityHome].(saved[\gravityHomePc], saved[\gravityHomeCents]); };
                };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(saved[\earGravityFollowMode], 1.0); };
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(saved[\spectrumAccordionAmount], saved[\spectrumAccordionProfile]); };
                if(api[\setToneProfile].notNil) { api[\setToneProfile].(saved[\toneProfile]); };
                if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(saved[\adaptiveToneMode]); };
                if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(saved[\adaptiveToneAmount]); };
                cfg[\render][\masterAmp] = saved[\masterAmp] ? 1.0;
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(saved[\micEnabled]); };
                cfg[\mic][\weight] = saved[\micWeight];
                cfg[\mic][\trust] = saved[\micTrust];
                cfg[\mic][\influencePolicy] = saved[\micPolicy];
                if(api[\setMicGain].notNil) { api[\setMicGain].(saved[\micGain] ? 8.0); };
                if(api[\setMicThreshold].notNil) { api[\setMicThreshold].(saved[\micAmpThreshold] ? 0.0012); };
                if(api[\setMicPitchAmpThreshold].notNil) { api[\setMicPitchAmpThreshold].(saved[\micPitchAmpThreshold] ? 0.00025); };
                if(api[\setMicPitchDetectGain].notNil) { api[\setMicPitchDetectGain].(saved[\micPitchDetectGain] ? 10.0); };
                if(api[\setMicZeroCrossAmpThreshold].notNil) { api[\setMicZeroCrossAmpThreshold].(saved[\micZeroCrossAmpThreshold] ? 0.00018); };
                if(at[\externalStimulus].notNil) { at[\externalStimulus][\setMasterAmp].(saved[\externalStimulusMasterAmp] ? 1.0); };
            };
            if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
            if(at[\resetToET].notNil) { at[\resetToET].(); };
            if((saved.notNil) and: { (saved[\runtimeRunning] ? false).not } and: { at[\stop].notNil }) { at[\stop].(); };
            if(at[\pushBuses].notNil) { at[\pushBuses].(); };
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        };

        demo[\section] = { |num, title, wait=0.7|
            "".postln;
            "------------------------------------------------------------".postln;
            ("[AT FINAL INSTRUMENT DEMO SECTION " ++ num.asString ++ "] " ++ title).postln;
            "------------------------------------------------------------".postln;
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
            demo[\advance].(wait);
        };


        demo[\advance] = { |dur=0.25, pollMic=true, stepMotion=true|
            var dt, n;
            dt = 0.05;
            n = ((dur.max(0.0) / dt).ceil.asInteger).max(1);
            n.do {
                if(stepMotion == true) {
                    if((st[\motionActive] ? false) and: { at[\motionStepToTarget].notNil }) { at[\motionStepToTarget].(false); };
                };
                if(pollMic == true) {
                    if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
                    // The final demo must not force a heavy mic resolve on every 50 ms
                    // while internal notes are active. Real play uses the runtime path;
                    // this polling path is only for physical speaker->mic scenes.
                    if(api[\resolveNow].notNil
                        and: { cfg[\mic][\enabled] ? false }
                        and: { (st[\activeNotes] ? IdentityDictionary.new).size == 0 }) {
                        api[\resolveNow].(\finalDemoMicPoll);
                    };
                };
                dt.wait;
            };
        };

        demo[\micPhysicalOk] = {
            var raw, analyzed, extCount, voiced, meterThreshold;
            raw = st[\micRawAmp] ? 0.0;
            analyzed = st[\micAnalyzedAmp] ? 0.0;
            extCount = (st[\externalSources] ? Array.new).size;
            voiced = st[\micVoiced] ? false;
            meterThreshold = (cfg[\mic][\meterThreshold] ? 0.0006) * 0.35;
            (extCount > 0) or: { voiced == true } or: { raw > meterThreshold } or: { analyzed > (cfg[\mic][\ampThreshold] ? 0.0012) * 0.35 }
        };

        demo[\physicalMicGate] = { |label="external physical scene"|
            var ok, raw, analyzed, extCount, voiced;
            raw = st[\micRawAmp] ? 0.0;
            analyzed = st[\micAnalyzedAmp] ? 0.0;
            extCount = (st[\externalSources] ? Array.new).size;
            voiced = st[\micVoiced] ? false;
            ok = demo[\micPhysicalOk].();
            ("[AT FINAL PHYSICAL MIC CHECK] " ++ label.asString
                ++ " status=" ++ (if(ok) { "ok" } { "failedNoMicInput" })
                ++ " externalSources=" ++ extCount.asString
                ++ " micRawAmp=" ++ raw.round(0.0001).asString
                ++ " micAnalyzedAmp=" ++ analyzed.round(0.0001).asString
                ++ " micVoiced=" ++ voiced.asString
                ++ " hiddenExternalInjection=false").postln;
            if(ok.not) {
                Error("Physical laptop mic did not detect the generated speaker stimulus; the final external/Ear sections cannot be truthfully demonstrated. Check macOS input permission/input device/speaker volume and rerun.").throw;
            };
            ok
        };

        demo[\control] = { |label|
            var snap;
            snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { () };
            ("[AT FINAL CONTROL STATE] " ++ label.asString
                ++ " motion=" ++ (snap[\movement] ? st[\movement] ? 0.0).round(0.001).asString
                ++ " memory=" ++ (snap[\memoryAmount] ? 0.0).round(0.001).asString
                ++ " gravity=" ++ (snap[\gravityStrength] ? 0.0).round(0.001).asString
                ++ " gravityOn=" ++ (snap[\gravityEnabled] ? false).asString
                ++ " ear=" ++ (snap[\micEnabled] ? false).asString
                ++ " tone=" ++ (snap[\toneProfile] ? \unknown).asString
                ++ " adapt=" ++ (snap[\adaptiveToneMode] ? \static).asString
                ++ " adaptAmount=" ++ (snap[\adaptiveToneAmount] ? 0.0).round(0.001).asString
                ++ " spectrumAccordion=" ++ (snap[\spectrumAccordionAmount] ? 0.0).round(0.001).asString).postln;
        };

        demo[\hardResetControls] = { |tone=\pure|
            if(api[\hardReset].notNil) { api[\hardReset].(); } {
                if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
                if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
                if(at[\resetToET].notNil) { at[\resetToET].(); };
            };
            if(api[\setPowerEnabled].notNil) { api[\setPowerEnabled].(true); };
            if(api[\setBrainEnabled].notNil) { api[\setBrainEnabled].(true); };
            if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
            if(api[\setMacro].notNil) {
                api[\setMacro].(\motion, 0.0);
                api[\setMacro].(\memory, 0.0);
                api[\setMacro].(\gravity, 0.0);
                api[\setMacro].(\carry, 0.0);
                api[\setMacro].(\tension, 0.55);
            };
            if(api[\clearTonalMemory].notNil) { api[\clearTonalMemory].(); };
            if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
            if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\off, 1.0); };
            if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.0, \harmonic); };
            if(api[\setToneProfile].notNil) { api[\setToneProfile].(tone); };
            if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\static); };
            if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.0); };
            cfg[\render][\masterAmp] = 0.92;
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        };

        demo[\note] = { |midi=60, vel=0.78, hold=0.55, gap=0.12|
            at[\noteOn].(midi, vel, nil, false);
            demo[\advance].(hold);
            at[\noteOff].(midi);
            demo[\advance].(gap);
        };

        demo[\chordOn] = { |notes, vels=nil|
            // Emulate a real simultaneous MIDI chord. Do not turn a chord into a fake arpeggio.
            if(at[\beginOnsetBatch].notNil) { at[\beginOnsetBatch].(\finalInstrumentDemoChord); };
            notes.do { |m, i| at[\noteOn].(m, if(vels.isNil) { 0.72 } { vels.wrapAt(i) }, nil, false); };
            if(at[\endOnsetBatch].notNil) { at[\endOnsetBatch].(\finalInstrumentDemoChord); };
            demo[\advance].(0.04);
        };

        demo[\addNoteBatched] = { |midi, vel=0.72|
            // Add a chord member as a harmonic chord update, not as a melodic arpeggio path.
            if(at[\beginOnsetBatch].notNil) { at[\beginOnsetBatch].(\finalInstrumentDemoChordAddition); };
            at[\noteOn].(midi, vel, nil, false);
            if(at[\endOnsetBatch].notNil) { at[\endOnsetBatch].(\finalInstrumentDemoChordAddition); };
            demo[\advance].(0.04);
        };

        demo[\chordOff] = { |notes|
            notes.do { |m| at[\noteOff].(m); demo[\advance].(0.015); };
        };

        demo[\chord] = { |notes, vels=nil, hold=1.1, gap=0.22|
            demo[\chordOn].(notes, vels);
            demo[\advance].(hold);
            demo[\chordOff].(notes);
            demo[\advance].(gap);
        };

        demo[\chordNoMicPoll] = { |notes, vels=nil, hold=0.8, gap=0.12|
            // Freeze-safe internal response phrase after a physical Ear scene:
            // keep the public Ear control state intact, but do not run the demo's
            // aggressive speaker-mic polling loop during internal instrument notes.
            demo[\chordOn].(notes, vels);
            demo[\advance].(hold, false, true);
            demo[\chordOff].(notes);
            demo[\advance].(gap, false, true);
        };

        demo[\phraseNoMicPoll] = { |notes, vel=0.62, hold=0.20, gap=0.06|
            notes.do { |m|
                at[\noteOn].(m, vel, nil, false);
                demo[\advance].(hold, false, true);
                at[\noteOff].(m);
                demo[\advance].(gap, false, true);
            };
        };

        demo[\phrase] = { |notes, vel=0.74, hold=0.34, gap=0.08|
            notes.do { |m| demo[\note].(m, vel, hold, gap); };
        };

        demo[\fieldLine] = { |label|
            var snap, dev, targetDev, maxDev, maxTarget;
            snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { () };
            dev = if(snap[\nodePhase].notNil) { snap[\nodePhase].collect { |p, i| at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0 } } { Array.fill(12, { 0.0 }) };
            targetDev = if(snap[\targetPhase].notNil) { snap[\targetPhase].collect { |p, i| at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0 } } { Array.fill(12, { 0.0 }) };
            maxDev = dev.collect(_.abs).maxItem ? 0.0;
            maxTarget = targetDev.collect(_.abs).maxItem ? 0.0;
            ("[AT FINAL FIELD] " ++ label.asString
                ++ " currentMaxDev=" ++ maxDev.round(0.01).asString ++ "c"
                ++ " targetMaxDev=" ++ maxTarget.round(0.01).asString ++ "c"
                ++ " targetKnown=" ++ (st[\targetPhase].notNil).asString
                ++ " motionActive=" ++ (snap[\motionActive] ? false).asString).postln;
        };

        demo[\playCMusic] = { |tempo=1.0|
            // Memory demonstration uses complete chord objects, not exposed raw arpeggio transport.
            demo[\chord].([60, 64, 67], [0.70, 0.62, 0.66], 0.85 / tempo, 0.10);
            demo[\chord].([65, 69, 72], [0.66, 0.62, 0.62], 0.75 / tempo, 0.10);
            demo[\chord].([67, 71, 74], [0.66, 0.62, 0.62], 0.75 / tempo, 0.10);
            demo[\chord].([60, 64, 67, 72], [0.68, 0.62, 0.62, 0.58], 0.95 / tempo, 0.14);
        };

        demo[\playModulationMusic] = { |tempo=1.0|
            // Modulation is shown as full chordal music so Memory follows center rather than a fake monophonic path.
            demo[\chord].([62, 66, 69], [0.68, 0.62, 0.62], 0.78 / tempo, 0.10);
            demo[\chord].([67, 71, 74], [0.66, 0.62, 0.62], 0.78 / tempo, 0.10);
            demo[\chord].([69, 73, 76], [0.66, 0.62, 0.62], 0.78 / tempo, 0.10);
            demo[\chord].([62, 66, 69, 74], [0.68, 0.62, 0.62, 0.58], 0.95 / tempo, 0.14);
        };

        		demo[\externalReport] = { |label, countWarning=true|
            var scene, bridge, mode, follow, homePc, homeName, goodScene, physicalSources, rep, warnCount;
            goodScene = false;
            12.do { |i|
                if(goodScene.not) {
                    // Physical speaker->mic scenes are frame-dependent. Poll while the
                    // speaker is still sounding, but stop once we have enough real evidence.
                    demo[\advance].(if(i == 0) { 0.42 } { 0.36 }, true, true);
                    scene = if(api[\externalCoherenceSceneReport].notNil) { api[\externalCoherenceSceneReport].(false) } { nil };
                    bridge = if(api[\externalCoherenceBridgeReport].notNil) { api[\externalCoherenceBridgeReport].(false) } { nil };
                    if(scene.notNil) {
                        goodScene = (((scene[\usedSources] ? 0) >= 3)
                            or: { ((scene[\rawSources] ? 0) >= 3) }
                            or: { ((scene[\rawSources] ? 0) == 1) and: { (scene[\usedSources] ? 0) == 1 } }
                            or: { (scene[\abnormal] ? 0) > 0 });
                    };
                };
            };
            scene = if(api[\externalCoherenceSceneReport].notNil) { api[\externalCoherenceSceneReport].() } { scene };
            bridge = if(api[\externalCoherenceBridgeReport].notNil) { api[\externalCoherenceBridgeReport].() } { bridge };
            mode = if(cfg[\finalControls].notNil) { cfg[\finalControls][\earGravityFollowMode] ? \off } { \off };
            if((mode == \ear) and: { scene.notNil } and: { (scene[\rawSources] ? 0) > 0 } and: { (scene[\usedSources] ? 0) > 0 }) {
                follow = if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(("earGravity_" ++ label.asString.replace(" ", "_")).asSymbol) } { nil };
                if((follow.notNil) and: { follow[\applied] == true } and: { api[\gravityReport].notNil }) { api[\gravityReport].(); };
            } { follow = nil; };
            homePc = if(cfg[\gravity].notNil) { cfg[\gravity][\homePc] } { nil };
            homeName = if(homePc.isNil) { "none" } { (pitchNames[homePc.asInteger.clip(0, 11)] ? homePc.asString).asString };
            physicalSources = [ (st[\externalSources] ? Array.new).size, if(scene.isNil) { 0 } { scene[\rawSources] ? 0 } ].maxItem;
            rep = (
                label: label,
                externalSources: physicalSources,
                rawSources: if(scene.isNil) { 0 } { scene[\rawSources] ? 0 },
                usedSources: if(scene.isNil) { 0 } { scene[\usedSources] ? 0 },
                etLike: if(scene.isNil) { false } { scene[\etLike] ? false },
                abnormal: if(scene.isNil) { 0 } { scene[\abnormal] ? 0 },
                voiceCount: if(scene.isNil) { 0 } { scene[\voiceCount] ? 0 },
                center: if(scene.isNil) { \none } { scene[\center] ? \none },
                gravityApplied: if(follow.isNil) { false } { follow[\applied] ? false },
                gravityTrust: if(follow.isNil) { \none } { follow[\trustReason] ? \none },
                gravityHome: homeName.asSymbol
            );
            cfg[\finalControls][\lastFinalExternalReport] = rep;
            if((countWarning == true) and: { physicalSources <= 0 }) {
                warnCount = cfg[\finalControls][\finalDemoPhysicalWarnings] ? 0;
                cfg[\finalControls][\finalDemoPhysicalWarnings] = warnCount + 1;
            };
            ("[AT FINAL EXTERNAL REPORT] " ++ label.asString
                ++ " externalSources=" ++ physicalSources.asString
                ++ " micRawAmp=" ++ (st[\micRawAmp] ? 0.0).round(0.0001).asString
                ++ " micVoiced=" ++ (st[\micVoiced] ? false).asString
                ++ " gravityFollow=" ++ mode.asString
                ++ " gravityApplied=" ++ rep[\gravityApplied].asString
                ++ " gravityTrust=" ++ rep[\gravityTrust].asString
                ++ " gravityHome=" ++ homeName
                ++ " hiddenExternalInjection=false").postln;
            rep
        };


        demo[\captureOk] = { |rep, requireVoice=false, allowSpectral=false|
            var ext, raw, used, voice, abnormal, trust, gravityApplied;
            if(rep.isNil) { false } {
                ext = rep[\externalSources] ? 0;
                raw = rep[\rawSources] ? 0;
                used = rep[\usedSources] ? 0;
                voice = rep[\voiceCount] ? 0;
                abnormal = rep[\abnormal] ? 0;
                trust = rep[\gravityTrust] ? \none;
                gravityApplied = rep[\gravityApplied] ? false;
                (ext > 0)
                    and: { (raw > 0) or: { allowSpectral and: { abnormal > 0 } } }
                    and: { if(requireVoice) { voice > 0 } { true } }
                    and: { (used > 0) or: { gravityApplied == true } or: { trust != \none } or: { allowSpectral and: { abnormal > 0 } } }
            }
        };

        demo[\beginExternalPhase] = { |mode=\polyPc|
            // Final demo physical capture uses public controls only, but gives
            // the laptop mic a stable, high-SNR reference window. This avoids
            // stochastic misses from quiet speaker chords without injecting
            // external evidence.
            if(at[\externalStimulus].notNil) { at[\externalStimulus][\setMasterAmp].(1.75); };
            if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(true); };
            if(api[\setMicInputMode].notNil) { api[\setMicInputMode].(\sum01); };
            if(api[\setMicMode].notNil) { api[\setMicMode].(mode); };
            if(api[\setMicInfluencePolicy].notNil) { api[\setMicInfluencePolicy].(\externalOnly); };
            if(api[\setMicGain].notNil) { api[\setMicGain].(20.0); };
            if(api[\setMicThreshold].notNil) { api[\setMicThreshold].(0.00018); };
            if(api[\setMicPitchAmpThreshold].notNil) { api[\setMicPitchAmpThreshold].(0.00006); };
            if(api[\setMicPitchDetectGain].notNil) { api[\setMicPitchDetectGain].(24.0); };
            if(api[\setMicZeroCrossAmpThreshold].notNil) { api[\setMicZeroCrossAmpThreshold].(0.00005); };
            if(api[\setMicWeight].notNil) { api[\setMicWeight].(0.55); };
            if(api[\setMicTrust].notNil) { api[\setMicTrust].(0.70); };
            if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\ear, 1.0); };
            if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
            demo[\advance].(0.22, true, true);
        };

        demo[\closeExternalPhase] = { |stimObj=nil, holdGravity=true|
            if(stimObj.notNil) { stimObj[\stop].(); };
            if(at[\externalStimulus].notNil) { at[\externalStimulus][\setMasterAmp].(1.0); };
            demo[\advance].(0.22, false, true);
            if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
            if(holdGravity and: { api[\setGravityFollowMode].notNil }) { api[\setGravityFollowMode].(\fixed, 1.0); };
            demo[\advance].(0.12, false, true);
        };

        demo[\skipInternalBecauseNoCapture] = { |label, stimObj=nil, countWarning=true|
            var warnCount;
            ("[AT FINAL PHYSICAL CAPTURE SKIP] " ++ label.asString
                ++ " captureMissingOrUntrusted=true; speaker stopped; live Ear paused; internal response skipped to avoid stale gravity/self-chase.").postln;
            if(countWarning == true) {
                warnCount = cfg[\finalControls][\finalDemoPhysicalWarnings] ? 0;
                cfg[\finalControls][\finalDemoPhysicalWarnings] = warnCount + 1;
            };
            demo[\closeExternalPhase].(stimObj, true);
            if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
            demo[\advance].(0.15, false, true);
        };

        demo[\run] = {
            var saved, summary, scn, stim;
            saved = demo[\save].();
            summary = List.new;
            scn = at[\externalStimulusScenarios];
            stim = at[\externalStimulus];
            try {
                "".postln;
                "============================================================".postln;
                "[AT FINAL INSTRUMENT DEMO] v67o FIRST FULL PRODUCT DEMO".postln;
                "Actual controls. Actual instrument voices. External context is real speaker audio into the laptop mic.".postln;
                "No hidden regression suite. No injected external scene evidence.".postln;
                "============================================================".postln;

                if(api[\openUI].notNil) { api[\openUI].(); };
                if(at[\start].notNil) { at[\start].(); };
                demo[\advance].(0.8);
                if(api[\finalProductControlReport].notNil) { api[\finalProductControlReport].(); };
                cfg[\finalControls][\finalDemoPhysicalWarnings] = 0;
                cfg[\finalControls][\lastFinalExternalReport] = nil;

                demo[\section].(1, "Pure sine start: Motion=0, Memory=0, Gravity=0, Carry=0, Ear off. Current field does not move.");
                demo[\hardResetControls].(\pure);
                demo[\control].("pure / all resistance off / Motion 0");
                at[\noteOn].(60, 0.76, nil, false);
                demo[\advance].(0.65);
                if(api[\motionSlewGateReport].notNil) { api[\motionSlewGateReport].(); };
                demo[\fieldLine].("Motion 0 while holding single C: current field stays fixed, target can be known");
                at[\noteOff].(60); demo[\advance].(0.25);

                demo[\section].(2, "Motion=0.25: the same single note slowly pulls the silent field.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.25); };
                demo[\control].("Motion 0.25");
                at[\noteOn].(60, 0.76, nil, false);
                demo[\fieldLine].("Motion 0.25 immediate");
                demo[\advance].(0.12); demo[\fieldLine].("Motion 0.25 early");
                demo[\advance].(0.55); demo[\fieldLine].("Motion 0.25 later");
                at[\noteOff].(60); demo[\advance].(0.35);

                demo[\section].(3, "Reset, Motion=1: same single note moves as fast as safely possible.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 1.0); };
                demo[\control].("Motion 1");
                demo[\note].(60, 0.76, 0.9, 0.2);
                demo[\fieldLine].("Motion 1 after single C");

                demo[\section].(4, "Arpeggios: Motion controls how far the field travels before the next note.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 1.0); };
                demo[\phrase].([60, 63, 66, 69, 72], 0.75, 0.28, 0.08);
                demo[\fieldLine].("fastest minor-third arpeggio");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.25); };
                demo[\phrase].([60, 63, 66, 69, 72], 0.75, 0.18, 0.04);
                demo[\fieldLine].("low-motion fast arpeggio");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.25); };
                demo[\phrase].([60, 63, 66, 69, 72], 0.75, 0.55, 0.18);
                demo[\fieldLine].("low-motion slow arpeggio");

                demo[\section].(5, "Register/Velocity: D minor adapts to its lower or louder minor seventh at Motion=0.5.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.5); };
                if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(1.25, 0.85); };
                demo[\chordOn].([62, 65, 69], [0.60, 0.58, 0.58]); demo[\advance].(0.8);
                demo[\addNoteBatched].(48, 0.64); demo[\advance].(1.1);
                if(api[\registerVelocityChartReport].notNil) { api[\registerVelocityChartReport].(); };
                demo[\fieldLine].("D minor plus lower C minor seventh selects C by register");
                [62,65,69,48].do { |m| at[\noteOff].(m) }; demo[\advance].(0.35);
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.5); };
                if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(0.85, 1.45); };
                demo[\chordOn].([62, 65, 69], [0.42, 0.42, 0.42]); demo[\advance].(0.8);
                demo[\addNoteBatched].(72, 1.0); demo[\advance].(1.1);
                if(api[\registerVelocityChartReport].notNil) { api[\registerVelocityChartReport].(); };
                demo[\fieldLine].("D minor plus louder C minor seventh selects C by velocity");
                [62,65,69,72].do { |m| at[\noteOff].(m) }; demo[\advance].(0.45);
                if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(1.0, 1.0); };
                // Do not let the register/velocity audition become the starting state for Memory.
                demo[\hardResetControls].(\pure);

                demo[\section].(6, "Memory=0.75: the instrument learns a general intonation from music, then follows modulation.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.5); api[\setMacro].(\memory, 0.75); };
                if(cfg[\memory].notNil) { cfg[\memory][\enabled] = true; };
                demo[\control].("Motion 0.5 / Memory 0.75");
                demo[\playCMusic].(1.0);
                demo[\playCMusic].(1.05);
                demo[\fieldLine].("memory after C music");
                demo[\playModulationMusic].(1.0);
                demo[\fieldLine].("memory after modulation");

                demo[\section].(7, "Gravity=0.75: A is pulled toward 432 Hz while the field remains harmonic.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.5); api[\setMacro].(\memory, 0.75); api[\setMacro].(\gravity, 0.75); };
                if(api[\setGravityHome].notNil) { api[\setGravityHome].(9, -31.77); };
                demo[\control].("Motion 0.5 / Memory 0.75 / Gravity 0.75 / A=432");
                demo[\chord].([57, 60, 64], [0.72, 0.62, 0.62], 1.4, 0.15);
                if(api[\gravityReport].notNil) { api[\gravityReport].(); };
                demo[\playModulationMusic].(1.0);
                if(api[\gravityReport].notNil) { api[\gravityReport].(); };
                demo[\fieldLine].("fixed A432 gravity during modulation");

                demo[\section].(8, "Adaptive Gravity: Gravity follows learned Memory when explicitly tied to it.");
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\memory, 1.0); };
                if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(\finalDemoMemoryFollow); };
                if(api[\gravityReport].notNil) { api[\gravityReport].(); };
                demo[\chord].([62, 66, 69], [0.70, 0.62, 0.62], 1.2, 0.15);
                if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(\finalDemoMemoryFollowAfterMusic); };
                if(api[\gravityReport].notNil) { api[\gravityReport].(); };

                demo[\section].(9, "Adaptive Timbre: same tuning controls now color the preset tone, without adding pitch authority.");
                if(api[\setToneProfile].notNil) { api[\setToneProfile].(\organ); };
                if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
                if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.82); };
                if(api[\setMacro].notNil) { api[\setMacro].(\tension, 0.72); };
                demo[\control].("Adaptive timbre listening / Tension expression");
                demo[\playCMusic].(1.15);
                if(api[\adaptiveToneReport].notNil) { api[\adaptiveToneReport].(); };

                demo[\section].(10, "Spectrum Accordion: a strange spectrum can explicitly and subtly color the residual body.");
                if(api[\setToneProfile].notNil) { api[\setToneProfile].(\synth); };
                demo[\chordOn].([60, 64, 67], [0.62, 0.62, 0.62]);
                demo[\advance].(0.35);
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.58, \bellLike); };
                demo[\control].("Spectrum accordion amount 0.58 / bellLike while chord is active");
                demo[\advance].(0.9);
                if(api[\spectrumAccordionReport].notNil) { api[\spectrumAccordionReport].(); };
                demo[\chordOff].([60, 64, 67]); demo[\advance].(0.2);

                demo[\section].(11, "Ear on: external sound can steer Gravity only through explicit Ear→Gravity follow.");
                demo[\hardResetControls].(\pure);
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.5); api[\setMacro].(\memory, 0.75); api[\setMacro].(\gravity, 0.75); api[\setMacro].(\micAmount, 0.50); api[\setMacro].(\micTrust, 0.75); };
                if(at[\externalStimulus].notNil) { at[\externalStimulus][\setMasterAmp].(1.45); };
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(true); };
                if(api[\setMicMode].notNil) { api[\setMicMode].(\mono); };
                if(api[\setMicInputMode].notNil) { api[\setMicInputMode].(\sum01); };
                if(api[\setMicGain].notNil) { api[\setMicGain].(18.0); };
                if(api[\setMicThreshold].notNil) { api[\setMicThreshold].(0.00018); };
                if(api[\setMicPitchAmpThreshold].notNil) { api[\setMicPitchAmpThreshold].(0.00006); };
                if(api[\setMicPitchDetectGain].notNil) { api[\setMicPitchDetectGain].(24.0); };
                if(api[\setMicZeroCrossAmpThreshold].notNil) { api[\setMicZeroCrossAmpThreshold].(0.00005); };
                if(api[\setMicInfluencePolicy].notNil) { api[\setMicInfluencePolicy].(\externalOnly); };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\ear, 1.0); };
                demo[\control].("Ear on / Gravity follow=Ear");
                if(stim.notNil) { stim[\playNote].(69, -31.77, 4.0, 0.14, 0, "external A 432 Hz gravity reference", 0.0); };
                demo[\advance].(1.2);
                demo[\physicalMicGate].("external A432 gravity reference");
                if(api[\applyGravityFollow].notNil) { api[\applyGravityFollow].(\externalA432); };
                demo[\advance].(1.0);
                if(api[\gravityReport].notNil) { api[\gravityReport].(); };
                demo[\externalReport].("external A432 physical speaker-to-mic scene");

                demo[\section].(12, "External ET instrument: Ear stays on and Gravity adapts only to coherent physical context.");
                demo[\beginExternalPhase].(\polyPc);
                if(stim.notNil) {
                    var amp, repC, repF, repCResolve;
                    amp = (cfg[\externalStimulus][\songAmp] ? 0.055) * 1.55;
                    stim[\stop].();
                    stim[\playChord].([
                        (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.2),
                        (midi: 60, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 64, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 67, cents: 0.0, timbre: 1, amp: amp)
                    ], 5.0, amp, 3, "final-demo direct ET C", 0.015);
                    demo[\advance].(1.2);
                    repC = demo[\externalReport].("ET direct C physical scene while sounding", false);
                    stim[\stop].(); demo[\advance].(0.18, true, true);

                    demo[\beginExternalPhase].(\polyPc);
                    stim[\playChord].([
                        (midi: 53, cents: 0.0, timbre: 2, amp: amp*1.2),
                        (midi: 65, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 69, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 72, cents: 0.0, timbre: 1, amp: amp)
                    ], 5.0, amp, 3, "final-demo direct ET F", 0.015);
                    demo[\advance].(1.2);
                    repF = demo[\externalReport].("ET direct F physical scene while sounding", false);
                    stim[\stop].(); demo[\advance].(0.18, true, true);

                    demo[\beginExternalPhase].(\polyPc);
                    stim[\playChord].([
                        (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.2),
                        (midi: 60, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 64, cents: -13.69, timbre: 1, amp: amp),
                        (midi: 67, cents: 1.96, timbre: 1, amp: amp)
                    ], 5.2, amp, 3, "final-demo direct C resolve", 0.015);
                    demo[\advance].(1.25);
                    repCResolve = demo[\externalReport].("ET direct C resolve physical scene while sounding");
                    if(demo[\captureOk].(repCResolve).not) {
                        "[AT FINAL EXTERNAL RETRY] ET C-resolve was not captured; retrying as a stronger isolated physical reference.".postln;
                        stim[\stop].(); demo[\advance].(0.30, true, true);
                        demo[\beginExternalPhase].(\polyPc);
                        stim[\playChord].([
                            (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.50),
                            (midi: 60, cents: 0.0, timbre: 3, amp: amp*1.35),
                            (midi: 64, cents: -13.69, timbre: 1, amp: amp*1.25),
                            (midi: 67, cents: 1.96, timbre: 1, amp: amp*1.25)
                        ], 5.6, amp*1.25, 3, "final-demo direct C resolve retry", 0.015);
                        demo[\advance].(1.35);
                        repCResolve = demo[\externalReport].("ET direct C resolve physical scene retry while sounding");
                    };
                    if(demo[\captureOk].(repCResolve)) {
                        demo[\closeExternalPhase].(stim, true);
                        "[AT FINAL PERFORMANCE] short internal response after captured ET C context (speaker stopped; live Ear paused; captured gravity held)".postln;
                        demo[\phraseNoMicPoll].([72, 71, 69, 67], 0.62, 0.20, 0.06);
                    } {
                        demo[\skipInternalBecauseNoCapture].("ET direct C resolve physical scene", stim);
                    };
                };

                demo[\section].(13, "ET instrument plus out-of-tune singer: bounded coherence, not blind obedience.");
                demo[\beginExternalPhase].(\polyPc);
                if(stim.notNil) {
                    var amp, repSinger;
                    amp = (cfg[\externalStimulus][\songAmp] ? 0.055) * 1.35;
                    stim[\stop].();
                    // Direct physical scene, not a background routine. Use a C/G ET backing and put the flat/vibrato
                    // singer on E, a pitch class not already doubled by the backing. This avoids same-PC masking of the
                    // singer by the ET band while still demonstrating an out-of-tune singer inside a stable external context.
                    stim[\playChord].([
                        (midi: 48, cents: 0.0, timbre: 2, amp: amp*0.92),
                        (midi: 60, cents: 0.0, timbre: 3, amp: amp*0.82),
                        (midi: 67, cents: 0.0, timbre: 1, amp: amp*0.78)
                    ], 5.8, amp, 1, "final-demo direct C/G band under singer", 0.01);
                    demo[\advance].(0.15);
                    if(stim.notNil) { stim[\playVibratoNote].(64, -20.0, 15.0, 5.0, 5.2, 0.26, 1, "singer E -20c with vibrato"); };
                    demo[\advance].(1.35);
                    repSinger = demo[\externalReport].("ET plus flat/vibrato singer direct physical scene while sounding", false);
                    if(demo[\captureOk].(repSinger, true).not) {
                        // One controlled retry with stronger isolated singer evidence before declaring the critical voice capture missed.
                        stim[\stop].(); demo[\advance].(0.28, true, true);
                        demo[\beginExternalPhase].(\polyPc);
                        // Critical voice retry is deliberately isolated: prove the Ear
                        // really heard the flat/vibrato singer, then hold the captured
                        // context for the internal response.
                        stim[\playVibratoNote].(64, -20.0, 18.0, 5.0, 5.4, 0.30, 1, "isolated singer E -20c retry with vibrato");
                        demo[\advance].(1.35);
                        repSinger = demo[\externalReport].("isolated flat/vibrato singer retry while sounding", false);
                    };
                    if(demo[\captureOk].(repSinger, true)) {
                        demo[\closeExternalPhase].(stim, true);
                        "[AT FINAL PERFORMANCE] internal response after captured singer/ET context (speaker stopped; live Ear paused; captured gravity held)".postln;
                        demo[\chordNoMicPoll].([60, 64, 67, 72], [0.58, 0.56, 0.58, 0.54], 0.75, 0.10);
                        demo[\chordNoMicPoll].([65, 69, 72, 76], [0.58, 0.56, 0.58, 0.54], 0.75, 0.10);
                    } {
                        demo[\skipInternalBecauseNoCapture].("ET plus flat/vibrato singer direct physical scene", stim);
                    };
                };

                demo[\section].(14, "Inharmonic / stretched spectrum: spectral context informs the accordion/cylinder, bounded and explicit.");
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.62, \pianoStretch); };
                demo[\beginExternalPhase].(\polyPc);
                if(stim.notNil) {
                    var repSpectral;
                    stim[\stop].();
                    stim[\playToneFreq].(261.63, 4.4, 0.13, 3, "external stretched-spectrum C", -0.25, 0, 0.0, 261.63, 0.0, 5.0, 0.0, nil, 0.02, \inharmonicTone);
                    stim[\playToneFreq].(329.63, 4.4, 0.115, 3, "external stretched-spectrum E", 0.25, 4, 0.0, 329.63, 0.0, 5.0, 0.0, nil, 0.02, \inharmonicTone);
                    demo[\advance].(1.0);
                    repSpectral = demo[\externalReport].("stretched/inharmonic physical spectrum while sounding", false);
                    if(demo[\captureOk].(repSpectral, false, true).not) {
                        stim[\stop].(); demo[\advance].(0.25, true, true);
                        stim[\playToneFreq].(261.63, 4.2, 0.14, 3, "external stretched-spectrum C retry", -0.25, 0, 0.0, 261.63, 0.0, 5.0, 0.0, nil, 0.02, \inharmonicTone);
                        stim[\playToneFreq].(329.63, 4.2, 0.12, 3, "external stretched-spectrum E retry", 0.25, 4, 0.0, 329.63, 0.0, 5.0, 0.0, nil, 0.02, \inharmonicTone);
                        demo[\advance].(1.1);
                        repSpectral = demo[\externalReport].("stretched/inharmonic physical spectrum retry while sounding");
                    };
                    if(demo[\captureOk].(repSpectral, false, true).not) {
                        demo[\skipInternalBecauseNoCapture].("stretched/inharmonic physical spectrum", stim);
                    };
                };
                if(stim.notNil) { stim[\stop].(); };
                demo[\advance].(0.25, false, true);
                // Freeze-safe phase boundary: the physical spectral scene has been heard;
                // now audition the explicit Spectrum Accordion control on an internal chord without live mic polling.
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\fixed, 1.0); };
                demo[\chordOn].([60, 64, 67], [0.62, 0.62, 0.62]);
                demo[\advance].(0.35, false, true);
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.62, \pianoStretch); };
                demo[\advance].(0.7, false, true);
                if(api[\spectrumAccordionReport].notNil) { api[\spectrumAccordionReport].(); };
                demo[\chordOff].([60, 64, 67]); demo[\advance].(0.2, false, true);

                demo[\section].(15, "Everything together: Motion, Memory, captured Ear-following Gravity, adaptive timbre, and spectrum context.");
                demo[\beginExternalPhase].(\polyPc);
                if(api[\setToneProfile].notNil) { api[\setToneProfile].(\electricPiano); };
                if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
                if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.75); };
                if(api[\setMacro].notNil) { api[\setMacro].(\motion, 0.55); api[\setMacro].(\memory, 0.75); api[\setMacro].(\gravity, 0.75); api[\setMacro].(\tension, 0.62); };
                demo[\control].("Final combined musical state");
                if(stim.notNil) {
                    var amp, repFinal;
                    amp = (cfg[\externalStimulus][\songAmp] ? 0.055) * 1.55;
                    stim[\stop].();
                    stim[\playChord].([
                        (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.2),
                        (midi: 60, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 64, cents: 0.0, timbre: 3, amp: amp),
                        (midi: 67, cents: 0.0, timbre: 1, amp: amp)
                    ], 5.2, amp, 3, "final combined direct C context", 0.015);
                    demo[\advance].(1.25);
                    repFinal = demo[\externalReport].("final combined direct C physical context while sounding");
                    if(demo[\captureOk].(repFinal).not) {
                        "[AT FINAL EXTERNAL RETRY] final combined C context was not captured on first pass; retrying stronger while speaker is still isolated.".postln;
                        stim[\stop].(); demo[\advance].(0.35, true, true);
                        demo[\beginExternalPhase].(\polyPc);
                        stim[\playChord].([
                            (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.65),
                            (midi: 60, cents: 0.0, timbre: 3, amp: amp*1.40),
                            (midi: 64, cents: 0.0, timbre: 3, amp: amp*1.40),
                            (midi: 67, cents: 0.0, timbre: 1, amp: amp*1.35)
                        ], 6.0, amp*1.45, 3, "final combined direct C context retry", 0.015);
                        demo[\advance].(1.45);
                        repFinal = demo[\externalReport].("final combined direct C physical context retry while sounding");
                    };
                    if(demo[\captureOk].(repFinal)) {
                        demo[\closeExternalPhase].(stim, true);
                        "[AT FINAL PERFORMANCE] final internal connected response after captured external context".postln;
                        demo[\chordNoMicPoll].([57, 60, 64, 69], [0.64, 0.58, 0.60, 0.62], 0.85, 0.05);
                        demo[\chordNoMicPoll].([57, 60, 64, 67], [0.64, 0.58, 0.60, 0.70], 0.8, 0.05);
                        demo[\chordNoMicPoll].([55, 60, 64, 67], [0.66, 0.58, 0.60, 0.62], 0.8, 0.05);
                        demo[\chordNoMicPoll].([55, 59, 62, 67], [0.64, 0.60, 0.60, 0.62], 0.85, 0.05);
                        demo[\chordNoMicPoll].([60, 64, 67, 72], [0.60, 0.62, 0.60, 0.68], 1.0, 0.18);
                    } {
                        demo[\skipInternalBecauseNoCapture].("final combined direct C physical context", stim);
                    };
                };
                if(api[\adaptiveToneReport].notNil) { api[\adaptiveToneReport].(); };

                if(stim.notNil) { stim[\stop].(); };
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.0, \harmonic); };
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
                if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
                if(api[\clearExternalEvidence].notNil) { api[\clearExternalEvidence].(); };
                cfg[\finalControls][\finalDemoCompleted] = true;
                cfg[\finalControls][\finalDemoResult] = \completed;
                cfg[\finalControls][\finalDemoFinalFreezeReady] = ((cfg[\finalControls][\finalDemoPhysicalWarnings] ? 0) <= 0);
                summary.add("v67o final instrument demo completed");
                ("[AT FINAL PRODUCT DEMO PHYSICAL WARNINGS] count=" ++ (cfg[\finalControls][\finalDemoPhysicalWarnings] ? 0).asString
                    ++ " finalFreezeReady=" ++ (cfg[\finalControls][\finalDemoFinalFreezeReady] ? false).asString).postln;
                File.use(demo[\summaryPath].(), "w", { |f|
                    f.write("Adaptive Temperament v67o final instrument demo completed\n");
                    f.write("publicControlsOnly=true\n");
                    f.write("externalStimulusMode=realSpeakerToMic\n");
                    f.write("hiddenExternalInjection=false\n");
                    f.write("physicalWarnings=" ++ (cfg[\finalControls][\finalDemoPhysicalWarnings] ? 0).asString ++ "\n");
                    f.write("finalFreezeReady=" ++ (cfg[\finalControls][\finalDemoFinalFreezeReady] ? false).asString ++ "\n");
                });
                ("[AT FINAL PRODUCT DEMO SUMMARY FILE] " ++ demo[\summaryPath].()).postln;
                "[AT FINAL PRODUCT DEMO COMPLETE] first full product demonstration finished; freeze only when finalFreezeReady=true.".postln;
                "============================================================".postln;
            } { |err|
                "[AT FINAL PRODUCT DEMO ERROR] cleanup running".warn;
                err.reportError;
                demo[\restore].(saved);
            };
        };

        demo[\startRoutine] = {
            var r;
            r = Routine({ demo[\run].(); });
            r.play(AppClock);
            r
        };

        api[\runFinalInstrumentDemo] = { demo[\startRoutine].(); };
        api[\runFinalDemoScenario] = { demo[\startRoutine].(); };
        at[\runFinalInstrumentDemo] = { demo[\startRoutine].(); };
        at[\runFinalDemoScenario] = { demo[\startRoutine].(); };
        ~atRunFinalInstrumentDemo = { api[\runFinalInstrumentDemo].(); };
        ~atRunFinalDemoScenario = { api[\runFinalInstrumentDemo].(); };
        "[AT FINAL INSTRUMENT DEMO] v67o loaded. Run Library.at(\\at)[\\api][\\runFinalInstrumentDemo].();".postln;
    };
}.value;
)
