
(
// AT_product_status.scd
// v52c visual-control adaptive-memory-gravity abnormal audit baseline product status.  Normal boot is the finished playable instrument and
// the single final movement-legible, physical-Ear-truth-gated demo.  No test suite, old docs, release notes, txt
// files, or alternate demo harness is packaged.

var build, at, cfg, st, api;

build = ~atBuild;
if(build.isNil) {
    "[AT PRODUCT STATUS] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    api[\productReadinessReport] = { |post=true|
        var report;
        report = (
            branch: \v52c_visual_memory_gravity_abnormal_audit_fix_candidate,
            productReadySurface: true,
            performanceProductV2: api[\performanceProductV2Report].notNil,
            visualMemoryGravityBridge: api[\visualMemoryGravityBridgeReport].notNil,
            visualControlAudit: api[\runVisualMemoryGravityBridgeAudit].notNil,
            adaptiveMemoryMode: api[\setMemoryMode].notNil,
            gravityFollowBridge: at[\updateGravityFollowHome].notNil,
            registerVelocityVisualControls: api[\setRegisterAuthority].notNil and: { api[\setVelocityAuthority].notNil },
            performancePresetLayer: api[\applyPerformancePresetV2].notNil,
            earCalibrationWizard: api[\startEarCalibrationV2].notNil,
            memorySnapshots: api[\saveMemorySnapshotV2].notNil,
            compactPerformanceStatus: api[\performanceProductV2Report].notNil,
            performanceSessionLog: api[\startPerformanceSessionLogV2].notNil,
            normalRunFile: \AdaptiveTemperament_run_scd,
            singleFinalDemoCommand: "Library.at(\\at)[\\api][\\runFinalDemoScenario].();",
            testsPackaged: false,
            docsPackaged: false,
            txtFilesPackaged: false,
            extraDemoHarnessPackaged: false,
            realPlayFastPath: api[\realPlayFastPathInstalled].notNil and: { api[\realPlayFastPathInstalled].() == true },
            topologyGuard: at[\applyPitchIdentityTopologyGuard].notNil,
            spacingGuard: at[\applyPitchIdentitySpacingGuard].notNil,
            electricPianoSourceRootPitchFix: api[\epianoPitchMapReport].notNil,
            electricPianoNearestSourceZoneFix: api[\epianoPitchMapReport].notNil,
            externalCoherenceWorldModel: api[\externalCoherenceSceneReport].notNil,
            externalCoherenceAuthorityBridge: api[\externalCoherenceBridgeReport].notNil,
            registerVelocityHarmonicChartAuthority: api[\registerVelocityHarmonicChartReport].notNil,
            motionRateGate: api[\motionRateGateReport].notNil,
            adaptiveTimbre: api[\adaptiveToneReport].notNil,
            boundedSpectrumAccordionAvailable: api[\setPerceptualSpectrumAmount].notNil,
            finalEndAllDemo: api[\runFinalDemoScenario].notNil,
            laptopSpeakerMicExternalStimulus: true,
            fakeExternalScenesInFinalDemo: false,
            currentVsTargetMovementTelemetry: true,
            motionSpeedTraceTelemetry: true,
            physicalEarTruthGate: true,
                liveCapturedExternalScene: true,
            stagedSceneTruthGate: true,
            strictCapturedPitchClassGate: true,
            abnormalSpectrumGravityBlocked: true,
            adaptiveGravityFollow: true,
            gravityFollowModes: [\fixed, \memory, \ear, \earMemory],
            simultaneousPolyMicRequiredAfterCapture: false,
            staggeredPhysicalExternalCapture: true,
            liveMicFallbackCountsAsPass: false,
            realPlayAllowsActiveMotion: true,
            pitchAuthorityAddedByProductLayer: false,
            topologyAuthorityAddedByProductLayer: false,
            spacingThresholdChange: false,
            abnormalSpectrumPitchAuthority: false,
            selfBleedExternalAuthority: false,
            normalBootLoadsDeepAcceptanceSuites: false,
            intent: "v52c visual-control adaptive-memory-gravity bridge abnormal audit fix candidate layered on the frozen v51 performance product keeper: one clean runtime, one final demo command, controls drive the instrument, external test sounds come through speaker/mic, Motion gates movement, Memory can Learn/Hold/Decay/Adaptive and remembers the 12-note field body, Gravity can stay Fixed or follow Memory/Ear/Ear+Memory, Ear supplies bounded external coherence, adaptive timbre is sound expression, bounded Spectrum/Accordion is explicit and small, and the demo prints motion-speed traces and current-vs-target movement telemetry so passive-field movement is visible, does not count fallback/last-meaningful Ear evidence as a physical microphone pass, and uses adaptive Gravity follow so Ear-enabled Gravity can fit pitch-eligible surrounding musical evidence without becoming key detection; strict staged capture prevents duplicate/wrong pitch classes from passing as a chord; captured scene roles are preserved through External Coherence so singers remain voices, abnormal spectra remain spectral-only, and abnormal spectra cannot become Gravity anchors; staged Ear sources carrying pc+cents are normalized to phase before they reach the solver; abnormal/self-bleed Gravity protection is audited against an explicit baseline home."
        );
        if(post) {
            "".postln;
            "[AT PRODUCT READINESS REPORT]".postln;
            ("branch=" ++ report[\branch].asString
                ++ " realPlayFastPath=" ++ report[\realPlayFastPath].asString
                ++ " registerVelocityChart=" ++ report[\registerVelocityHarmonicChartAuthority].asString
                ++ " motionRateGate=" ++ report[\motionRateGate].asString
                ++ " movementTelemetry=" ++ report[\currentVsTargetMovementTelemetry].asString
                ++ " physicalEarTruthGate=" ++ report[\physicalEarTruthGate].asString
                ++ " activeMotion=" ++ report[\realPlayAllowsActiveMotion].asString
                ++ " adaptiveTimbre=" ++ report[\adaptiveTimbre].asString
                ++ " finalEndAllDemo=" ++ report[\finalEndAllDemo].asString
                ++ " testsPackaged=" ++ report[\testsPackaged].asString).postln;
        };
        report;
    };

    api[\finishedProductReport] = { |post=true| api[\productReadinessReport].(post) };
    at[\productReadinessReport] = { |post=true| api[\productReadinessReport].(post) };

    "[AT PRODUCT STATUS] v52c loaded: visual-control adaptive-memory-gravity bridge abnormal audit fix candidate, clean runtime package, no tests/docs/txt/extra demo harness.".postln;
};
)
