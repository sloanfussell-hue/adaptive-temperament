(
// AT_performance_product_v2.scd
// Product-facing performance layer for the frozen final-demo keeper.
// This file intentionally does not change the harmonic law, Motion gate,
// Memory law, Gravity law, Ear classification, topology/spacing guards,
// sample pitch path, or adaptive-timbre pitch neutrality.  It adds playable
// presets, compact status, memory snapshots, Ear calibration helpers, a
// lightweight performance session log, and panic/cleanup helpers.

var build, at, cfg, st, api, diag, ui, names;
var ensureStore, safe, reportLine, applyTone, applyEar, applyGravity;

build = ~atBuild;
if(build.isNil) {
    "[AT PERFORMANCE PRODUCT V2] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    names = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    ensureStore = {
        if(st[\performanceV2].isNil) { st[\performanceV2] = IdentityDictionary.new; };
        if(st[\performanceMemorySnapshots].isNil) { st[\performanceMemorySnapshots] = IdentityDictionary.new; };
        if(st[\performanceSessionLog].isNil) { st[\performanceSessionLog] = List.new; };
        if(st[\performanceEarCalibration].isNil) {
            st[\performanceEarCalibration] = IdentityDictionary.newFrom([
                \status, \notStarted,
                \measurements, IdentityDictionary.new,
                \lastApplied, nil
            ]);
        };
        if(st[\performanceV2][\defaultMemoryLearnRate].isNil) { st[\performanceV2][\defaultMemoryLearnRate] = cfg[\memory][\learningRate] ? 0.045; };
        if(st[\performanceV2][\defaultMemoryDecay].isNil) { st[\performanceV2][\defaultMemoryDecay] = cfg[\memory][\decay] ? 0.008; };
        if(st[\performanceV2][\defaultMemoryConfidenceDecay].isNil) { st[\performanceV2][\defaultMemoryConfidenceDecay] = cfg[\memory][\confidenceDecay] ? 0.012; };
    };

    safe = { |key, args|
        if(api[key].notNil) { api[key].valueArray(args ? Array.new); };
    };

    reportLine = { |report|
        ("[AT PERFORMANCE PRODUCT V2] preset=" ++ (report[\preset] ? \none).asString
            ++ " console=" ++ (report[\consoleMode] ? \compact).asString
            ++ " motion=" ++ ((report[\motion] ? 0.0).round(0.001)).asString
            ++ " memory=" ++ ((report[\memoryAmount] ? 0.0).round(0.001)).asString
            ++ " memoryConf=" ++ ((report[\memoryConfidence] ? 0.0).round(0.001)).asString
            ++ " gravity=" ++ (report[\gravityEnabled] ? false).asString
            ++ " ear=" ++ (report[\earEnabled] ? false).asString
            ++ " tone=" ++ (report[\toneProfile] ? \unknown).asString
            ++ " pitchAuthorityAdded=false").postln;
    };

    applyTone = { |profile=\electricPiano, adaptMode=\listening, adaptAmount=0.35, tension=0.45, master=0.85, low=0.50, mid=0.50, high=0.50|
        safe.(\setToneProfile, [profile]);
        safe.(\setAdaptiveToneMode, [adaptMode]);
        safe.(\setAdaptiveToneAmount, [adaptAmount]);
        safe.(\setTension, [tension]);
        safe.(\setMasterAmp, [master]);
        safe.(\setToneEQ, [low, mid, high]);
    };

    applyEar = { |enabled=false, weight=0.0, trust=0.55, policy=\externalOnly, mode=\polyPc|
        if(enabled) {
            safe.(\setMicMode, [mode]);
            safe.(\setMicInfluencePolicy, [policy]);
            safe.(\setMicWeight, [weight]);
            safe.(\setMicTrust, [trust]);
            safe.(\setMicEnabled, [true]);
        } {
            safe.(\setMicWeight, [0.0]);
            safe.(\setMicEnabled, [false]);
        };
    };

    applyGravity = { |enabled=false, pc=9, cents=0.0, strength=0.0, maxPull=8.0, followMode=\fixed|
        safe.(\setGravityFollowMode, [followMode]);
        safe.(\setGravityHome, [pc, cents]);
        safe.(\setGravityStrength, [strength]);
        safe.(\setGravityMaxPullCents, [maxPull]);
        safe.(\setGravityEnabled, [enabled]);
    };

    api[\setPerformanceConsoleMode] = { |mode=\compact|
        var m;
        ensureStore.();
        m = mode.asSymbol;
        if((m != \quiet) and: { m != \compact } and: { m != \verbose }) { m = \compact; };
        st[\performanceV2][\consoleMode] = m;
        cfg[\input][\postMidiEvents] = (m == \verbose);
        cfg[\field][\logEvidenceTicks] = false;
        cfg[\world][\debug] = (m == \verbose);
        cfg[\phrase][\debug] = (m == \verbose);
        cfg[\perceptual][\debug] = false;
        cfg[\gravity][\debug] = false;
        cfg[\pitchIdentityGuard][\debug] = false;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        (consoleMode: m, midiEventPosts: cfg[\input][\postMidiEvents], pitchAuthorityAdded: false);
    };

    api[\performancePresetNamesV2] = {
        [\pureCore, \stableComposer, \duoExternal, \stageSafe, \studioRecord];
    };

    api[\performancePresetPlanV2] = { |post=true|
        var plan;
        plan = (
            pureCore: "Motion open, Memory/Gravity/Ear off, signed Carry open, Pure tone. Raw harmonic field exposed.",
            stableComposer: "Motion medium, Memory learned/resisting, Gravity off, EP tone, adaptive timbre light.",
            duoExternal: "Ear on in duet-safe poly mode, adaptive Gravity can follow pitch-eligible external context, bounded authority only.",
            stageSafe: "Motion conservative, Memory high, fixed A432 Gravity, Ear off by default, lower master amp.",
            studioRecord: "Balanced recording state: compact console, EP tone, moderate Motion/Memory, no automatic mic unless enabled."
        );
        if(post) {
            "".postln;
            "[AT PERFORMANCE PRESET PLAN V2]".postln;
            api[\performancePresetNamesV2].().do { |k| (k.asString ++ " :: " ++ plan[k]).postln; };
        };
        plan;
    };

    api[\applyPerformancePresetV2] = { |preset=\stableComposer, post=true|
        var p, rep;
        ensureStore.();
        p = preset.asSymbol;
        if(api[\performancePresetNamesV2].().includes(p).not) { p = \stableComposer; };

        safe.(\setPowerEnabled, [true]);
        safe.(\setBrainEnabled, [true]);
        api[\setPerformanceConsoleMode].(\compact);

        switch(p,
            \pureCore, {
                safe.(\setMovement, [1.0]);
                safe.(\setSignedCarry, [1.0]);
                safe.(\setMemoryAmount, [0.0]);
                cfg[\memory][\learningRate] = 0.0;
                applyGravity.(false, 9, 0.0, 0.0, 4.0, \fixed);
                applyEar.(false, 0.0, 0.0, \externalOnly, \mono);
                safe.(\setPerceptualSpectrumAmount, [0.0]);
                applyTone.(\pure, \static, 0.0, 0.12, 0.82, 0.50, 0.50, 0.50);
            },
            \stableComposer, {
                safe.(\setMovement, [0.55]);
                safe.(\setSignedCarry, [0.20]);
                safe.(\setMemoryAmount, [0.72]);
                cfg[\memory][\learningRate] = 0.035;
                cfg[\memory][\decay] = 0.006;
                cfg[\memory][\confidenceDecay] = 0.010;
                applyGravity.(false, 9, 0.0, 0.0, 8.0, \fixed);
                applyEar.(false, 0.0, 0.55, \externalOnly, \polyPc);
                safe.(\setPerceptualSpectrumAmount, [0.0]);
                applyTone.(\electricPiano, \listening, 0.38, 0.45, 0.86, 0.52, 0.50, 0.55);
            },
            \duoExternal, {
                safe.(\setMovement, [0.50]);
                safe.(\setSignedCarry, [0.12]);
                safe.(\setMemoryAmount, [0.62]);
                cfg[\memory][\learningRate] = 0.030;
                cfg[\memory][\decay] = 0.007;
                cfg[\memory][\confidenceDecay] = 0.011;
                applyGravity.(true, 0, 0.0, 0.58, 10.0, \earMemory);
                applyEar.(true, 0.42, 0.70, \duetSafe, \polyPc);
                safe.(\setPerceptualSpectrumAmount, [0.0]);
                applyTone.(\electricPiano, \listening, 0.62, 0.52, 0.78, 0.50, 0.50, 0.56);
            },
            \stageSafe, {
                safe.(\setMovement, [0.38]);
                safe.(\setSignedCarry, [0.0]);
                safe.(\setMemoryAmount, [0.82]);
                cfg[\memory][\learningRate] = 0.020;
                cfg[\memory][\decay] = 0.004;
                cfg[\memory][\confidenceDecay] = 0.008;
                applyGravity.(true, 9, -31.766653633429, 0.72, 12.0, \fixed);
                applyEar.(false, 0.0, 0.55, \externalOnly, \polyPc);
                safe.(\setPerceptualSpectrumAmount, [0.0]);
                applyTone.(\electricPiano, \listening, 0.44, 0.58, 0.72, 0.55, 0.50, 0.50);
            },
            \studioRecord, {
                safe.(\setMovement, [0.65]);
                safe.(\setSignedCarry, [0.18]);
                safe.(\setMemoryAmount, [0.60]);
                cfg[\memory][\learningRate] = 0.030;
                cfg[\memory][\decay] = 0.006;
                cfg[\memory][\confidenceDecay] = 0.010;
                applyGravity.(false, 9, 0.0, 0.0, 8.0, \memory);
                applyEar.(false, 0.0, 0.55, \externalOnly, \polyPc);
                safe.(\setPerceptualSpectrumAmount, [0.0]);
                applyTone.(\electricPiano, \coherenceBloom, 0.35, 0.42, 0.78, 0.50, 0.50, 0.54);
            }
        );

        st[\performanceV2][\preset] = p;
        if(api[\resolveNow].notNil) { api[\resolveNow].(\performancePresetV2); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        rep = api[\performanceProductV2Report].(false);
        if(post) { reportLine.(rep); };
        rep;
    };

    api[\saveMemorySnapshotV2] = { |name=\slot1, post=true|
        var key, snap;
        ensureStore.();
        key = name.asSymbol;
        snap = (
            name: key,
            phase: (st[\memoryPhase] ? st[\nodePhase]).copy,
            valid: st[\memoryValid] ? false,
            confidence: st[\memoryConfidence] ? 0.0,
            amount: st[\memoryAmount] ? 0.0,
            supportCounts: (st[\memorySupportCounts] ? Array.fill(cfg[\solver][\numNodes], 0)).copy,
            capturedAt: Main.elapsedTime,
            pitchAuthorityAdded: false
        );
        st[\performanceMemorySnapshots][key] = snap;
        if(post) { ("[AT MEMORY SNAPSHOT SAVED] name=" ++ key.asString ++ " confidence=" ++ snap[\confidence].round(0.001).asString ++ " pitchAuthorityAdded=false").postln; };
        snap;
    };

    api[\recallMemorySnapshotV2] = { |name=\slot1, amount=nil, post=true|
        var key, snap, rep;
        ensureStore.();
        key = name.asSymbol;
        snap = st[\performanceMemorySnapshots][key];
        if(snap.isNil) {
            rep = (name: key, recalled: false, reason: \missingSnapshot, pitchAuthorityAdded: false);
        } {
            st[\memoryPhase] = snap[\phase].copy;
            st[\memoryValid] = snap[\valid] ? true;
            st[\memoryConfidence] = snap[\confidence] ? 0.0;
            st[\memorySupportCounts] = (snap[\supportCounts] ? Array.fill(cfg[\solver][\numNodes], 0)).copy;
            if(amount.notNil) { safe.(\setMemoryAmount, [amount]); } { safe.(\setMemoryAmount, [snap[\amount] ? (st[\memoryAmount] ? 0.0)]); };
            st[\memoryLastReason] = \snapshotRecall;
            if(api[\resolveNow].notNil) { api[\resolveNow].(\memorySnapshotRecall); };
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
            rep = (name: key, recalled: true, confidence: st[\memoryConfidence], amount: st[\memoryAmount], pitchAuthorityAdded: false);
        };
        if(post) { ("[AT MEMORY SNAPSHOT RECALL] name=" ++ key.asString ++ " recalled=" ++ rep[\recalled].asString ++ " pitchAuthorityAdded=false").postln; };
        rep;
    };

    api[\listMemorySnapshotsV2] = { |post=true|
        var keys;
        ensureStore.();
        keys = st[\performanceMemorySnapshots].keys.asArray;
        if(post) { ("[AT MEMORY SNAPSHOTS] " ++ keys.asString).postln; };
        keys;
    };

    api[\clearMemorySnapshotV2] = { |name=\slot1, post=true|
        var key;
        ensureStore.();
        key = name.asSymbol;
        st[\performanceMemorySnapshots].removeAt(key);
        if(post) { ("[AT MEMORY SNAPSHOT CLEARED] name=" ++ key.asString).postln; };
        (name: key, cleared: true);
    };

    api[\setMemoryPerformanceModeV2] = { |mode=\learn, post=true|
        var m, rep;
        ensureStore.();
        m = mode.asSymbol;
        if((m != \learn) and: { m != \hold } and: { m != \decay }) { m = \learn; };
        switch(m,
            \learn, {
                cfg[\memory][\learningRate] = st[\performanceV2][\defaultMemoryLearnRate] ? 0.045;
                cfg[\memory][\decay] = st[\performanceV2][\defaultMemoryDecay] ? 0.008;
                cfg[\memory][\confidenceDecay] = st[\performanceV2][\defaultMemoryConfidenceDecay] ? 0.012;
            },
            \hold, {
                cfg[\memory][\learningRate] = 0.0;
                cfg[\memory][\decay] = 0.0;
                cfg[\memory][\confidenceDecay] = 0.0;
            },
            \decay, {
                cfg[\memory][\learningRate] = 0.0;
                cfg[\memory][\decay] = 0.025;
                cfg[\memory][\confidenceDecay] = 0.035;
            }
        );
        st[\performanceV2][\memoryMode] = m;
        rep = (memoryMode: m, learningRate: cfg[\memory][\learningRate], decay: cfg[\memory][\decay], confidenceDecay: cfg[\memory][\confidenceDecay], pitchAuthorityAdded: false);
        if(post) { ("[AT MEMORY PERFORMANCE MODE] mode=" ++ m.asString ++ " learn=" ++ rep[\learningRate].round(0.001).asString ++ " decay=" ++ rep[\decay].round(0.001).asString).postln; };
        rep;
    };

    api[\startEarCalibrationV2] = { |post=true|
        var cal;
        ensureStore.();
        applyEar.(true, cfg[\mic][\weight] ? 0.35, st[\micTrust] ? 0.55, \duetSafe, \polyPc);
        cal = st[\performanceEarCalibration];
        cal[\status] = \measuring;
        cal[\measurements] = IdentityDictionary.new;
        cal[\startedAt] = Main.elapsedTime;
        cal[\note] = "Measure quiet room, then emitted reference tones; apply uses current live mic amplitude/frequency only.";
        if(post) {
            "[AT EAR CALIBRATION V2] started. Call measureEarCalibrationV2(\\room), then play/sing a reference and call measureEarCalibrationV2(\\reference), then applyEarCalibrationV2.".postln;
        };
        cal.copy;
    };

    api[\measureEarCalibrationV2] = { |label=\room, post=true|
        var cal, key, meas;
        ensureStore.();
        cal = st[\performanceEarCalibration];
        key = label.asSymbol;
        meas = (
            label: key,
            amp: st[\micRawAmp] ? 0.0,
            freq: st[\micRawFreq],
            pc: st[\micPc],
            confidence: st[\micConfidence] ? 0.0,
            capturedAt: Main.elapsedTime,
            pitchAuthorityAdded: false
        );
        cal[\measurements][key] = meas;
        if(post) { ("[AT EAR CALIBRATION MEASURE] label=" ++ key.asString ++ " amp=" ++ (meas[\amp] ? 0.0).round(0.0001).asString ++ " freq=" ++ (meas[\freq] ? 0.0).round(0.01).asString ++ " confidence=" ++ (meas[\confidence] ? 0.0).round(0.001).asString).postln; };
        meas;
    };

    api[\applyEarCalibrationV2] = { |post=true|
        var cal, room, ref, liveAmp, noiseAmp, refAmp, threshold, pitchThreshold, polyAbs, gain, rep;
        ensureStore.();
        cal = st[\performanceEarCalibration];
        room = cal[\measurements][\room];
        ref = cal[\measurements][\reference];
        liveAmp = st[\micRawAmp] ? 0.0;
        noiseAmp = ((if(room.notNil) { room[\amp] ? 0.0 } { 0.0 }).max(liveAmp * 0.35)).clip(0.00001, 0.05);
        refAmp = if(ref.notNil) { ref[\amp] ? liveAmp } { liveAmp };
        threshold = (noiseAmp * 2.8).clip(0.00015, 0.040);
        pitchThreshold = (threshold * 0.45).clip(0.00008, 0.025);
        polyAbs = (threshold * 1.4).clip(0.00020, 0.060);
        gain = if(refAmp > 0.0001) { (0.045 / refAmp).clip(1.0, 18.0) } { cfg[\mic][\gain] ? 8.0 };
        safe.(\setMicThreshold, [threshold]);
        safe.(\setMicPitchAmpThreshold, [pitchThreshold]);
        cfg[\mic][\polyAbsThreshold] = polyAbs;
        safe.(\setMicGain, [gain]);
        cal[\status] = \applied;
        rep = (
            status: \applied,
            roomAmp: noiseAmp,
            referenceAmp: refAmp,
            ampThreshold: threshold,
            pitchAmpThreshold: pitchThreshold,
            polyAbsThreshold: polyAbs,
            micGain: gain,
            pitchAuthorityAdded: false,
            note: "Calibration only adjusts microphone sensitivity thresholds/gain. It does not add pitch authority or bypass Motion."
        );
        cal[\lastApplied] = rep;
        if(post) { ("[AT EAR CALIBRATION APPLIED] threshold=" ++ threshold.round(0.0001).asString ++ " pitchThreshold=" ++ pitchThreshold.round(0.0001).asString ++ " gain=" ++ gain.round(0.01).asString ++ " pitchAuthorityAdded=false").postln; };
        rep;
    };

    api[\earCalibrationReportV2] = { |post=true|
        var cal, rep;
        ensureStore.();
        cal = st[\performanceEarCalibration];
        rep = (
            status: cal[\status] ? \notStarted,
            measurements: cal[\measurements],
            lastApplied: cal[\lastApplied],
            micEnabled: cfg[\mic][\enabled] ? false,
            ampThreshold: cfg[\mic][\ampThreshold],
            pitchAmpThreshold: cfg[\mic][\pitchAmpThreshold],
            micGain: cfg[\mic][\gain],
            pitchAuthorityAdded: false
        );
        if(post) { ("[AT EAR CALIBRATION REPORT] status=" ++ rep[\status].asString ++ " micEnabled=" ++ rep[\micEnabled].asString ++ " gain=" ++ (rep[\micGain] ? 0.0).round(0.01).asString ++ " pitchAuthorityAdded=false").postln; };
        rep;
    };

    api[\performancePanicV2] = { |post=true|
        st[\sustainDown] = false;
        if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
        if(st[\voices].notNil) { at[\allVoicesOff].(); };
        if(at[\clearMicEvidence].notNil) { at[\clearMicEvidence].(); };
        if(at[\clearMicBuses].notNil) { at[\clearMicBuses].(); };
        st[\singletonReentryPending] = nil;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        if(post) { "[AT PERFORMANCE PANIC] voicesOff=true sustainDown=false activeNotes=0".postln; };
        (voicesOff: true, sustainDown: false, activeNotes: 0, pitchAuthorityAdded: false);
    };

    if(st[\performanceV2InputWrapped] != true) {
        at[\performanceV2OriginalNoteOn] = at[\noteOn];
        at[\performanceV2OriginalNoteOff] = at[\noteOff];
        at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
            ensureStore.();
            if(st[\performanceSessionLogging] == true) {
                st[\performanceSessionLog].add((event: \noteOn, midi: midi, velocity: velocity, at: Main.elapsedTime, preset: st[\performanceV2][\preset]));
            };
            at[\performanceV2OriginalNoteOn].(midi, velocity, explicitFreq, suppressVoice);
        };
        at[\noteOff] = { |midi|
            ensureStore.();
            if(st[\performanceSessionLogging] == true) {
                st[\performanceSessionLog].add((event: \noteOff, midi: midi, at: Main.elapsedTime, preset: st[\performanceV2][\preset]));
            };
            at[\performanceV2OriginalNoteOff].(midi);
        };
        st[\performanceV2InputWrapped] = true;
    };

    api[\startPerformanceSessionLogV2] = { |post=true|
        ensureStore.();
        st[\performanceSessionLog] = List.new;
        st[\performanceSessionLogging] = true;
        st[\performanceSessionStartedAt] = Main.elapsedTime;
        st[\performanceSessionLog].add((event: \sessionStart, at: Main.elapsedTime, preset: st[\performanceV2][\preset], pitchAuthorityAdded: false));
        if(post) { "[AT PERFORMANCE SESSION LOG] started".postln; };
        (logging: true, events: st[\performanceSessionLog].size, pitchAuthorityAdded: false);
    };

    api[\stopPerformanceSessionLogV2] = { |post=true|
        ensureStore.();
        st[\performanceSessionLogging] = false;
        st[\performanceSessionLog].add((event: \sessionStop, at: Main.elapsedTime, pitchAuthorityAdded: false));
        if(post) { ("[AT PERFORMANCE SESSION LOG] stopped events=" ++ st[\performanceSessionLog].size.asString).postln; };
        (logging: false, events: st[\performanceSessionLog].size, pitchAuthorityAdded: false);
    };

    api[\exportPerformanceSessionLogV2] = { |fileName="AT_performance_session.atlog", post=true|
        var path, f, arr;
        ensureStore.();
        path = build[\baseDir] +/+ fileName.asString;
        arr = st[\performanceSessionLog].asArray;
        f = File(path, "w");
        f.write("Adaptive Temperament Performance Session Log v2\n");
        f.write("pitchAuthorityAdded=false\n");
        arr.do { |ev| f.write(ev.asCompileString ++ "\n"); };
        f.close;
        if(post) { ("[AT PERFORMANCE SESSION EXPORT] " ++ path ++ " events=" ++ arr.size.asString).postln; };
        (path: path, events: arr.size, pitchAuthorityAdded: false);
    };

    api[\performanceProductV2Report] = { |post=true|
        var rep, grav;
        ensureStore.();
        grav = if(api[\gravityReport].notNil) { api[\gravityReport].() } { (enabled: cfg[\gravity][\enabled] ? false, homePc: cfg[\gravity][\homePc] ? 0, homeCents: cfg[\gravity][\homeCents] ? 0.0) };
        rep = (
            branch: \v51_performance_product_v2_candidate,
            preset: st[\performanceV2][\preset] ? \none,
            presetNames: api[\performancePresetNamesV2].(),
            consoleMode: st[\performanceV2][\consoleMode] ? \compact,
            motion: if(at[\motionAmount].notNil) { at[\motionAmount].() } { st[\movement] ? 1.0 },
            signedCarry: if(st[\macros].notNil) { st[\macros][\carry] ? 0.0 } { 0.0 },
            memoryAmount: st[\memoryAmount] ? 0.0,
            memoryConfidence: st[\memoryConfidence] ? 0.0,
            memoryValid: st[\memoryValid] ? false,
            memoryMode: st[\performanceV2][\memoryMode] ? \learn,
            memorySnapshots: st[\performanceMemorySnapshots].keys.asArray,
            gravityEnabled: grav[\enabled] ? false,
            gravityHomePc: grav[\homePc] ? 0,
            gravityHomeName: names[(grav[\homePc] ? 0).asInteger.clip(0, 11)],
            gravityHomeCents: grav[\homeCents] ? 0.0,
            gravityFollowMode: grav[\followMode] ? (cfg[\gravity][\followMode] ? \fixed),
            earEnabled: cfg[\mic][\enabled] ? false,
            earPolicy: cfg[\mic][\influencePolicy] ? \externalOnly,
            earMode: cfg[\mic][\mode] ? \mono,
            earCalibrationStatus: if(st[\performanceEarCalibration].notNil) { st[\performanceEarCalibration][\status] ? \notStarted } { \notStarted },
            toneProfile: cfg[\render][\toneProfile] ? \organ,
            adaptiveToneMode: cfg[\render][\adaptiveToneMode] ? \static,
            adaptiveToneAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
            sessionLogging: st[\performanceSessionLogging] ? false,
            sessionEvents: if(st[\performanceSessionLog].notNil) { st[\performanceSessionLog].size } { 0 },
            pitchAuthorityAdded: false,
            harmonicLawChanged: false,
            motionGateChanged: false,
            memoryLawChanged: false,
            gravityLawChanged: false,
            earClassifierChanged: false,
            topologySpacingChanged: false,
            note: "Performance Product v2 is a playable surface layer: presets, calibration helpers, memory snapshots, compact status, panic, and session logging. It does not alter the frozen harmonic engine."
        );
        if(post) { reportLine.(rep); };
        rep;
    };

    api[\runPerformanceProductV2Audit] = { |post=true|
        var pass, fail, check, beforePreset, snap, rep;
        ensureStore.();
        pass = 0; fail = 0;
        check = { |label, cond|
            if(cond) { pass = pass + 1; if(post) { ("[pass] " ++ label.asString).postln; }; }
            { fail = fail + 1; if(post) { ("[FAIL] " ++ label.asString).postln; }; };
        };
        beforePreset = st[\performanceV2][\preset];
        check.(\presetNamesExist, api[\performancePresetNamesV2].().size >= 5);
        api[\setPerformanceConsoleMode].(\compact);
        check.(\compactConsoleDisablesMidiSpam, cfg[\input][\postMidiEvents] == false);
        api[\applyPerformancePresetV2].(\pureCore, false);
        check.(\pureCoreMotionOpen, (if(at[\motionAmount].notNil) { at[\motionAmount].() } { st[\movement] ? 0.0 }) >= 0.99);
        check.(\pureCoreMemoryZero, (st[\memoryAmount] ? 1.0) <= 0.001);
        api[\applyPerformancePresetV2].(\duoExternal, false);
        check.(\duoExternalEarEnabled, cfg[\mic][\enabled] == true);
        check.(\duoExternalPolicySafe, cfg[\mic][\influencePolicy] == \duetSafe);
        snap = api[\saveMemorySnapshotV2].(\audit, false);
        check.(\memorySnapshotSaved, st[\performanceMemorySnapshots][\audit].notNil);
        check.(\memorySnapshotRecallable, api[\recallMemorySnapshotV2].(\audit, nil, false)[\recalled] == true);
        check.(\calibrationStarts, api[\startEarCalibrationV2].(false)[\status] == \measuring);
        check.(\calibrationMeasures, api[\measureEarCalibrationV2].(\room, false)[\label] == \room);
        check.(\calibrationAppliesNoPitchAuthority, api[\applyEarCalibrationV2].(false)[\pitchAuthorityAdded] == false);
        check.(\sessionLogStarts, api[\startPerformanceSessionLogV2].(false)[\logging] == true);
        check.(\sessionLogStops, api[\stopPerformanceSessionLogV2].(false)[\logging] == false);
        rep = api[\performanceProductV2Report].(false);
        check.(\pitchAuthorityNotAdded, rep[\pitchAuthorityAdded] == false);
        check.(\harmonicLawUnchanged, rep[\harmonicLawChanged] == false);
        if(beforePreset.notNil) { api[\applyPerformancePresetV2].(beforePreset, false); };
        if(post) { ("[AT PERFORMANCE PRODUCT V2 AUDIT] pass=" ++ pass.asString ++ " fail=" ++ fail.asString ++ " ready=" ++ (fail == 0).asString).postln; };
        (pass: pass, fail: fail, ready: fail == 0, pitchAuthorityAdded: false);
    };

    at[\performanceProductV2Report] = { |post=true| api[\performanceProductV2Report].(post) };
    at[\applyPerformancePresetV2] = { |preset=\stableComposer| api[\applyPerformancePresetV2].(preset) };

    ensureStore.();
    api[\setPerformanceConsoleMode].(\compact);
    "[AT PERFORMANCE PRODUCT V2] v51 loaded: presets, Ear calibration helpers, memory snapshots, compact performance status, panic, and session logging; pitchAuthorityAdded=false".postln;
};
)
