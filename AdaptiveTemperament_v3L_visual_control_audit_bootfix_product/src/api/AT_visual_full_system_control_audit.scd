(
// AT_visual_full_system_control_audit.scd
// v3L: product-facing visual/control coverage audit bootfix. It does not add tuning law.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-visual-full-audit] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    api[\visualControlCoverageReport] = {
        var required, missing, present, uiFacing, advanced, reports;
        required = [
            \setPowerEnabled, \setBrainEnabled, \setMacro, \setMovement, \setSignedCarry, \setMemoryAmount, \setMemoryLearnRate, \clearTonalMemory,
            \setGravityEnabled, \setGravityStrength, \setGravityMaxPullCents, \setGravityType, \setGravityTargetMidi, \setGravityTargetPc, \setGravityTargetFreq,
            \setGravityAuthority, \setGravitySlew, \setGravityPitchClassWeight, \setGravityFollowMode, \applyGravityFollow, \clearGravity, \gravitySnapshot,
            \setMicEnabled, \setMicMode, \setMicInputMode, \setMicInfluencePolicy, \setMicSourceRoleMode, \setMicGain, \setMicThreshold, \setMicPitchThreshold,
            \setMicSceneEnabled, \setMicFieldResponseEnabled, \micSceneReport,
            \setTonePreset, \setAdaptiveToneMode, \setAdaptiveToneAmount, \setToneLow, \setToneMid, \setToneHigh, \toneSnapshot, \tensionAdaptiveTimbreReport,
            \setRenderMode, \setPitchLag, \setReleaseTime, \setMasterAmp, \setBrightnessAmount, \setRoughnessAmount, \setPanMotionAmount,
            \setRegisterVelocityAuthority, \setSpectrumAccordionAmount, \spectrumAccordionReport,
            \setShowIntervalLinks, \setFrozenGhostAlpha, \setUIFps, \printControlEcology, \uiSnapshot, \refreshUISnapshot,
            \runMemoryGravityAudit, \runFinalDemoScenario, \quickFinalDemoScenario, \stopFinalDemoScenario
        ];
        missing = required.select { |k| api[k].isNil };
        present = required.reject { |k| api[k].isNil };
        uiFacing = [\Power, \Brain, \Motion, \Carry, \Memory, \Gravity, \Tension, \Ear, \Tone, \AdaptiveTimbre, \EQ, \Render, \Mic, \RegisterVelocity, \SpectrumAccordion, \SystemDiagnostics];
        advanced = [\GravityFollowMode, \MemoryLearnRate, \MemorySeed, \SpectrumAccordionAmount, \FinalDemo, \MemoryGravityAudit, \VisualControlAudit];
        reports = [\uiSnapshot, \toneSnapshot, \gravitySnapshot, \tensionAdaptiveTimbreReport, \spectrumAccordionReport, \memoryGravityReport, \visualControlCoverageReport];
        (
            version: \v3LVisualFullSystemControlAudit,
            role: \visualControlCoverageReport,
            uiFacingControls: uiFacing,
            advancedVisualControls: advanced,
            reportButtons: reports,
            requiredCount: required.size,
            presentCount: present.size,
            missingCount: missing.size,
            missing: missing,
            readyForVisualControlAudit: missing.isEmpty
        )
    };

    api[\runVisualFullSystemControlAudit] = {
        var pass, fail, check, endpoints, old, snapBefore, snapAfter, pitchDelta, maxDelta, arrBefore, arrAfter;
        var cov, grav, tone, timbre, spec, mem, modeOK, missingOK;
        pass = 0; fail = 0;
        check = { |name, cond, detail=""|
            if(cond) {
                pass = pass + 1;
                ("[AT VISUAL CONTROL PASS] " ++ name.asString ++ " :: " ++ detail.asString).postln;
            } {
                fail = fail + 1;
                ("[AT VISUAL CONTROL FAIL] " ++ name.asString ++ " :: " ++ detail.asString).warn;
            };
        };

        old = (
            power: st[\powerEnabled] ? true,
            brain: st[\brainEnabled] ? true,
            motion: st[\movement] ? 0.82,
            carry: if(st[\macros].notNil) { st[\macros][\carry] ? 0.0 } { 0.0 },
            memory: st[\memoryAmount] ? 0.0,
            learn: cfg[\memory][\learnRate] ? (cfg[\memory][\learningRate] ? 0.04),
            tension: st[\tension] ? 0.55,
            micEnabled: cfg[\mic][\enabled] ? false,
            micMode: cfg[\mic][\mode] ? \duetSafe,
            micInput: cfg[\mic][\inputMode] ? \sum01,
            micRole: cfg[\mic][\sourceRoleMode] ? \auto,
            micGain: cfg[\mic][\gain] ? 1.0,
            micThreshold: cfg[\mic][\ampThreshold] ? 0.015,
            micPitchThreshold: cfg[\mic][\pitchAmpThreshold] ? 0.01,
            micSceneEnabled: cfg[\micScene][\enabled] ? true,
            micFieldEnabled: cfg[\micResponse][\enabled] ? true,
            tone: st[\tonePreset] ? (cfg[\render][\tonePreset] ? \production),
            toneMode: cfg[\render][\adaptiveToneMode] ? \static,
            toneAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
            toneLow: cfg[\render][\toneLow] ? 0.5,
            toneMid: cfg[\render][\toneMid] ? 0.5,
            toneHigh: cfg[\render][\toneHigh] ? 0.5,
            renderMode: st[\renderMode] ? (cfg[\render][\mode] ? \production),
            pitchLag: cfg[\render][\pitchLag] ? 0.035,
            releaseTime: cfg[\render][\releaseTime] ? 0.18,
            masterAmp: cfg[\render][\masterAmp] ? 1.0,
            brightness: cfg[\render][\brightnessAmount] ? 1.0,
            roughness: cfg[\render][\roughnessAmount] ? 0.0,
            pan: cfg[\render][\panMotionAmount] ? 0.0,
            gravEnabled: cfg[\gravity][\enabled] ? false,
            gravType: cfg[\gravity][\type] ? \off,
            gravPc: st[\gravityHomePc] ? (cfg[\gravity][\targetPc] ? 9),
            gravCents: st[\gravityHomeCents] ? (cfg[\gravity][\targetCents] ? -31.766653633429),
            gravStrength: cfg[\gravity][\strength] ? 0.0,
            gravMaxPull: cfg[\gravity][\maxPullCents] ? 5.0,
            gravAuthority: cfg[\gravity][\authority] ? 1.0,
            gravSlew: cfg[\gravity][\slew] ? 1.0,
            gravPcWeight: cfg[\gravity][\pitchClassWeight] ? 0.12,
            gravFollow: cfg[\gravity][\followMode] ? (st[\gravityFollowMode] ? \fixed),
            regAmount: cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] ? 0.46,
            velAmount: cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] ? 0.54,
            specAmount: cfg[\perceptualCylinder][\accordionAmount] ? (cfg[\perceptualCylinder][\amount] ? 0.0),
            links: cfg[\ui][\showIntervalLinks] ? true,
            ghost: cfg[\ui][\frozenGhostAlpha] ? 0.45,
            fps: cfg[\ui][\fps] ? 14.0
        );

        cov = api[\visualControlCoverageReport].();
        check.(\allVisualAPIsPresent, cov[\missingCount] == 0, cov.asString);

        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        snapBefore = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { () };
        check.(\visualSnapshotAvailable, snapBefore.notNil and: { snapBefore[\movement].notNil }, snapBefore[\state].asString);

        if(api[\setPowerEnabled].notNil) { api[\setPowerEnabled].(false); api[\setPowerEnabled].(true); };
        check.(\powerButtonResponds, st[\powerEnabled] == true, "power=" ++ (st[\powerEnabled] ? nil).asString);
        if(api[\setBrainEnabled].notNil) { api[\setBrainEnabled].(false); api[\setBrainEnabled].(true); };
        check.(\brainButtonResponds, st[\brainEnabled] == true, "brain=" ++ (st[\brainEnabled] ? nil).asString);

        if(api[\setMacro].notNil) {
            api[\setMacro].(\motion, 0.37); api[\setMacro].(\carry, 0.0); api[\setMacro].(\memory, 0.31); api[\setMacro].(\gravity, 0.22); api[\setMacro].(\tension, 0.64);
        };
        check.(\brainSlidersRespond, ((st[\movement] ? 0.0) - 0.37).abs < 0.001 and: { ((st[\memoryAmount] ? 0.0) - 0.31).abs < 0.001 and: { ((st[\tension] ? 0.0) - 0.64).abs < 0.001 } }, "motion/memory/tension=" ++ [st[\movement], st[\memoryAmount], st[\tension]].asString);

        if(api[\setMemoryLearnRate].notNil) { api[\setMemoryLearnRate].(0.022); };
        check.(\memoryLearnRateVisualResponds, ((cfg[\memory][\learnRate] ? (cfg[\memory][\learningRate] ? 0.0)) - 0.022).abs < 0.001, "learn=" ++ (cfg[\memory][\learnRate] ? (cfg[\memory][\learningRate] ? nil)).asString);

        if(api[\setGravityType].notNil) { api[\setGravityType].(\both); };
        if(api[\setGravityTargetFreq].notNil) { api[\setGravityTargetFreq].(432.0, \both); };
        if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(0.41); };
        if(api[\setGravityAuthority].notNil) { api[\setGravityAuthority].(0.73); };
        if(api[\setGravitySlew].notNil) { api[\setGravitySlew].(0.52); };
        if(api[\setGravityPitchClassWeight].notNil) { api[\setGravityPitchClassWeight].(0.24); };
        if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(\hybrid); };
        grav = if(api[\gravitySnapshot].notNil) { api[\gravitySnapshot].() } { () };
        modeOK = (cfg[\gravity][\followMode] ? st[\gravityFollowMode]) == \hybrid;
        check.(\gravityVisualControlsRespond, (cfg[\gravity][\enabled] ? false) and: { ((cfg[\gravity][\strength] ? 0.0) - 0.41).abs < 0.001 and: { modeOK } }, grav.asString);

        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(false); };
        if(api[\setMicMode].notNil) { api[\setMicMode].(\duetSafe); };
        if(api[\setMicInputMode].notNil) { api[\setMicInputMode].(\sum01); };
        if(api[\setMicSourceRoleMode].notNil) { api[\setMicSourceRoleMode].(\externalPianoLike); };
        if(api[\setMicGain].notNil) { api[\setMicGain].(1.7); };
        if(api[\setMicThreshold].notNil) { api[\setMicThreshold].(0.021); };
        if(api[\setMicPitchThreshold].notNil) { api[\setMicPitchThreshold].(0.019); };
        if(api[\setMicSceneEnabled].notNil) { api[\setMicSceneEnabled].(true); };
        if(api[\setMicFieldResponseEnabled].notNil) { api[\setMicFieldResponseEnabled].(true); };
        check.(\earVisualControlsRespond, ((cfg[\mic][\gain] ? 0.0) - 1.7).abs < 0.001 and: { ((cfg[\mic][\ampThreshold] ? 0.0) - 0.021).abs < 0.001 and: { (cfg[\mic][\sourceRoleMode] ? \auto) == \externalPianoLike } }, "mic gain/threshold/role=" ++ [cfg[\mic][\gain], cfg[\mic][\ampThreshold], cfg[\mic][\sourceRoleMode]].asString);

        arrBefore = st[\nodePhase].copy;
        if(api[\setTension].notNil) { api[\setTension].(0.82); };
        if(api[\setTonePreset].notNil) { api[\setTonePreset].(\electricPiano); };
        if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(\listening); };
        if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.44); };
        if(api[\setToneLow].notNil) { api[\setToneLow].(0.25); };
        if(api[\setToneMid].notNil) { api[\setToneMid].(0.62); };
        if(api[\setToneHigh].notNil) { api[\setToneHigh].(0.78); };
        tone = if(api[\toneSnapshot].notNil) { api[\toneSnapshot].() } { () };
        timbre = if(api[\tensionAdaptiveTimbreReport].notNil) { api[\tensionAdaptiveTimbreReport].() } { () };
        arrAfter = st[\nodePhase].copy;
        maxDelta = if(arrBefore.notNil and: { arrAfter.notNil }) { arrBefore.collect { |p, i| (at[\wrapSigned].(arrAfter[i] - p).abs * 1200.0) }.maxItem ? 0.0 } { 0.0 };
        check.(\toneTensionAdaptiveTimbreVisualResponds, tone[\tonePreset] == \electricPiano and: { (cfg[\render][\adaptiveToneMode] ? \static) == \listening and: { timbre[\pitchAuthorityAdded] == false } }, tone.asString);
        check.(\tensionTonePitchNeutral, maxDelta <= 0.0001, "maxPitchDeltaCents=" ++ maxDelta.round(0.0001).asString);

        if(api[\setRenderMode].notNil) { api[\setRenderMode].(\production); };
        if(api[\setPitchLag].notNil) { api[\setPitchLag].(0.041); };
        if(api[\setReleaseTime].notNil) { api[\setReleaseTime].(0.23); };
        if(api[\setMasterAmp].notNil) { api[\setMasterAmp].(0.76); };
        if(api[\setBrightnessAmount].notNil) { api[\setBrightnessAmount].(1.22); };
        if(api[\setRoughnessAmount].notNil) { api[\setRoughnessAmount].(0.11); };
        if(api[\setPanMotionAmount].notNil) { api[\setPanMotionAmount].(0.06); };
        check.(\renderVisualControlsRespond, ((cfg[\render][\pitchLag] ? 0.0) - 0.041).abs < 0.001 and: { ((cfg[\render][\releaseTime] ? 0.0) - 0.23).abs < 0.001 and: { ((cfg[\render][\masterAmp] ? 0.0) - 0.76).abs < 0.001 } }, "render=" ++ [cfg[\render][\pitchLag], cfg[\render][\releaseTime], cfg[\render][\masterAmp]].asString);

        if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(0.33, 0.67); };
        check.(\registerVelocityVisualControlsRespond, ((cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] ? 0.0) - 0.33).abs < 0.001 and: { ((cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] ? 0.0) - 0.67).abs < 0.001 }, "reg/vel=" ++ [cfg[\solver][\registerVelocityChordAuthorityRegisterAmount], cfg[\solver][\registerVelocityChordAuthorityVelocityAmount]].asString);

        if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(0.035); };
        spec = if(api[\spectrumAccordionReport].notNil) { api[\spectrumAccordionReport].() } { () };
        check.(\spectrumAccordionVisualControlResponds, ((cfg[\perceptualCylinder][\accordionAmount] ? (cfg[\perceptualCylinder][\amount] ? 0.0)) - 0.035).abs < 0.001, "amount=" ++ (cfg[\perceptualCylinder][\accordionAmount] ? (cfg[\perceptualCylinder][\amount] ? nil)).asString);

        if(api[\setShowIntervalLinks].notNil) { api[\setShowIntervalLinks].(false); };
        if(api[\setFrozenGhostAlpha].notNil) { api[\setFrozenGhostAlpha].(0.37); };
        if(api[\setUIFps].notNil) { api[\setUIFps].(18.0); };
        check.(\systemVisualControlsRespond, (cfg[\ui][\showIntervalLinks] == false) and: { ((cfg[\ui][\frozenGhostAlpha] ? 0.0) - 0.37).abs < 0.001 and: { ((cfg[\ui][\fps] ? 0.0) - 18.0).abs < 0.001 } }, "ui=" ++ [cfg[\ui][\showIntervalLinks], cfg[\ui][\frozenGhostAlpha], cfg[\ui][\fps]].asString);

        missingOK = [\printControlEcology, \micSceneReport, \gravitySnapshot, \toneSnapshot, \uiSnapshot, \runMemoryGravityAudit, \runFinalDemoScenario, \quickFinalDemoScenario, \stopFinalDemoScenario].detect { |k| api[k].isNil }.isNil;
        check.(\diagnosticAndDemoButtonsAvailable, missingOK, "diagnostics/final demo endpoints present=" ++ missingOK.asString);

        // Restore product defaults/state as closely as possible.
        if(api[\setPowerEnabled].notNil) { api[\setPowerEnabled].(old[\power]); };
        if(api[\setBrainEnabled].notNil) { api[\setBrainEnabled].(old[\brain]); };
        if(api[\setMovement].notNil) { api[\setMovement].(old[\motion]); };
        if(api[\setSignedCarry].notNil) { api[\setSignedCarry].(old[\carry]); };
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(old[\memory]); };
        if(api[\setMemoryLearnRate].notNil) { api[\setMemoryLearnRate].(old[\learn]); };
        if(api[\setTension].notNil) { api[\setTension].(old[\tension]); };
        if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(old[\micEnabled]); };
        if(api[\setMicMode].notNil) { api[\setMicMode].(old[\micMode]); };
        if(api[\setMicInputMode].notNil) { api[\setMicInputMode].(old[\micInput]); };
        if(api[\setMicSourceRoleMode].notNil) { api[\setMicSourceRoleMode].(old[\micRole]); };
        if(api[\setMicGain].notNil) { api[\setMicGain].(old[\micGain]); };
        if(api[\setMicThreshold].notNil) { api[\setMicThreshold].(old[\micThreshold]); };
        if(api[\setMicPitchThreshold].notNil) { api[\setMicPitchThreshold].(old[\micPitchThreshold]); };
        if(api[\setMicSceneEnabled].notNil) { api[\setMicSceneEnabled].(old[\micSceneEnabled]); };
        if(api[\setMicFieldResponseEnabled].notNil) { api[\setMicFieldResponseEnabled].(old[\micFieldEnabled]); };
        if(api[\setTonePreset].notNil) { api[\setTonePreset].(old[\tone]); };
        if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(old[\toneMode]); };
        if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(old[\toneAmount]); };
        if(api[\setToneLow].notNil) { api[\setToneLow].(old[\toneLow]); };
        if(api[\setToneMid].notNil) { api[\setToneMid].(old[\toneMid]); };
        if(api[\setToneHigh].notNil) { api[\setToneHigh].(old[\toneHigh]); };
        if(api[\setRenderMode].notNil) { api[\setRenderMode].(old[\renderMode]); };
        if(api[\setPitchLag].notNil) { api[\setPitchLag].(old[\pitchLag]); };
        if(api[\setReleaseTime].notNil) { api[\setReleaseTime].(old[\releaseTime]); };
        if(api[\setMasterAmp].notNil) { api[\setMasterAmp].(old[\masterAmp]); };
        if(api[\setBrightnessAmount].notNil) { api[\setBrightnessAmount].(old[\brightness]); };
        if(api[\setRoughnessAmount].notNil) { api[\setRoughnessAmount].(old[\roughness]); };
        if(api[\setPanMotionAmount].notNil) { api[\setPanMotionAmount].(old[\pan]); };
        if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(old[\regAmount], old[\velAmount]); };
        if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(old[\specAmount]); };
        if(api[\setShowIntervalLinks].notNil) { api[\setShowIntervalLinks].(old[\links]); };
        if(api[\setFrozenGhostAlpha].notNil) { api[\setFrozenGhostAlpha].(old[\ghost]); };
        if(api[\setUIFps].notNil) { api[\setUIFps].(old[\fps]); };
        if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(old[\gravFollow]); };
        if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(old[\gravStrength]); };
        if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(old[\gravMaxPull]); };
        if(api[\setGravityAuthority].notNil) { api[\setGravityAuthority].(old[\gravAuthority]); };
        if(api[\setGravitySlew].notNil) { api[\setGravitySlew].(old[\gravSlew]); };
        if(api[\setGravityPitchClassWeight].notNil) { api[\setGravityPitchClassWeight].(old[\gravPcWeight]); };
        if(api[\setGravityTargetPc].notNil) { api[\setGravityTargetPc].(old[\gravPc], old[\gravCents], old[\gravType]); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(old[\gravEnabled]); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };

        ("[AT VISUAL FULL SYSTEM CONTROL AUDIT v3L] pass=" ++ pass ++ " fail=" ++ fail ++ " visualControlsComplete=" ++ (fail == 0).asString ++ " pitchAuthorityAdded=false").postln;
        (
            pass: pass,
            fail: fail,
            visualControlsComplete: fail == 0,
            pitchAuthorityAdded: false,
            coverage: cov,
            finalSnapshot: if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { nil }
        )
    };

    api[\runVisualControlAudit] = { api[\runVisualFullSystemControlAudit].() };

    "[at-visual-full-audit] v3L visual full-system control audit loaded; all final product controls can be verified without adding pitch law.".postln;
};
)
