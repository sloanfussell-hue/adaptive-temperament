(
// AT_adaptive_timbre_presets.scd
// Clean final foundation: per-tone adaptive timbre preset mapping.
// Tension/adaptive timbre has a musical, preset-specific sound role while preserving
// the global Motion gate and the pitch-neutral timbre boundary.
var build, at, cfg, st, api;

build = ~atBuild;

if(build.isNil) {
    "[at-adaptive-timbre] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(cfg[\solver].isNil) { cfg[\solver] = IdentityDictionary.new; };

    cfg[\render][\adaptiveToneModes] = [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening];
    cfg[\render][\adaptiveTonePerformanceDefaultMode] = \listening;
    cfg[\render][\adaptiveTonePerformanceDefaultAmount] = 0.35;

    // v2g: make the finished product actually adaptive by default, but keep it
    // deliberately conservative. The UI can still set Static/0.0 at any time.
    cfg[\render][\adaptiveToneMode] = \listening;
    if((cfg[\render][\adaptiveToneAmount] ? 0.0).asFloat <= 0.001) {
        cfg[\render][\adaptiveToneAmount] = cfg[\render][\adaptiveTonePerformanceDefaultAmount];
    };

    at[\adaptiveTimbreTonePresets] = [\production, \piano, \electricPiano, \organ, \strings, \pad, \synth, \bass, \drone];

    at[\adaptiveTimbreToneProfile] = { |preset=\production|
        var p;
        p = preset.asSymbol;
        switch(p,
            \piano, {
                (kind: \acousticPiano, brightnessBase: 0.74, roughnessBase: 0.035, panBase: 0.0,
                    eqLowBody: 0.20, eqMidSoothe: 0.34, eqHighAir: 0.62,
                    bloomBrightness: 0.40, bloomRoughness: -0.08, bloomPan: 0.05,
                    breathBrightness: 0.15, breathRoughness: 0.05, breathPan: 0.13,
                    edgeBrightness: 0.36, edgeRoughness: 0.24, edgePan: 0.04,
                    brightnessMin: 0.45, brightnessMax: 1.65, roughnessMin: 0.02, roughnessMax: 0.32, panMin: 0.0, panMax: 0.0)
            },
            \electricPiano, {
                (kind: \electricPianoTine, brightnessBase: 0.90, roughnessBase: 0.04, panBase: 0.0,
                    eqLowBody: 0.14, eqMidSoothe: 0.12, eqHighAir: 0.72,
                    bloomBrightness: 0.34, bloomRoughness: -0.03, bloomPan: 0.10,
                    breathBrightness: 0.22, breathRoughness: 0.13, breathPan: 0.28,
                    edgeBrightness: 0.74, edgeRoughness: 0.58, edgePan: 0.13,
                    brightnessMin: 0.50, brightnessMax: 2.25, roughnessMin: 0.04, roughnessMax: 0.36, panMin: 0.0, panMax: 0.0)
            },
            \organ, {
                (kind: \tonewheelOrgan, brightnessBase: 0.86, roughnessBase: 0.06, panBase: 0.0,
                    eqLowBody: 0.22, eqMidSoothe: 0.20, eqHighAir: 0.54,
                    bloomBrightness: 0.62, bloomRoughness: -0.10, bloomPan: 0.07,
                    breathBrightness: 0.18, breathRoughness: 0.04, breathPan: 0.22,
                    edgeBrightness: 0.30, edgeRoughness: 0.18, edgePan: 0.05,
                    brightnessMin: 0.48, brightnessMax: 1.85, roughnessMin: 0.01, roughnessMax: 0.28, panMin: 0.0, panMax: 0.0)
            },
            \strings, {
                (kind: \bowedEnsemble, brightnessBase: 0.64, roughnessBase: 0.05, panBase: 0.0,
                    eqLowBody: 0.16, eqMidSoothe: 0.30, eqHighAir: 0.50,
                    bloomBrightness: 0.52, bloomRoughness: -0.05, bloomPan: 0.20,
                    breathBrightness: 0.24, breathRoughness: 0.08, breathPan: 0.42,
                    edgeBrightness: 0.22, edgeRoughness: 0.18, edgePan: 0.08,
                    brightnessMin: 0.35, brightnessMax: 1.55, roughnessMin: 0.01, roughnessMax: 0.25, panMin: 0.0, panMax: 0.0)
            },
            \pad, {
                (kind: \slowPad, brightnessBase: 0.56, roughnessBase: 0.035, panBase: 0.0,
                    eqLowBody: 0.18, eqMidSoothe: 0.22, eqHighAir: 0.44,
                    bloomBrightness: 0.58, bloomRoughness: -0.04, bloomPan: 0.34,
                    breathBrightness: 0.18, breathRoughness: 0.03, breathPan: 0.50,
                    edgeBrightness: 0.16, edgeRoughness: 0.12, edgePan: 0.10,
                    brightnessMin: 0.25, brightnessMax: 1.45, roughnessMin: 0.0, roughnessMax: 0.20, panMin: 0.0, panMax: 0.0)
            },
            \synth, {
                (kind: \expressiveSynth, brightnessBase: 0.98, roughnessBase: 0.12, panBase: 0.0,
                    eqLowBody: 0.10, eqMidSoothe: 0.05, eqHighAir: 0.88,
                    bloomBrightness: 0.34, bloomRoughness: 0.02, bloomPan: 0.10,
                    breathBrightness: 0.25, breathRoughness: 0.15, breathPan: 0.32,
                    edgeBrightness: 0.95, edgeRoughness: 0.82, edgePan: 0.18,
                    brightnessMin: 0.45, brightnessMax: 2.75, roughnessMin: 0.04, roughnessMax: 0.44, panMin: 0.0, panMax: 0.0)
            },
            \bass, {
                (kind: \anchoredBass, brightnessBase: 0.48, roughnessBase: 0.08, panBase: 0.0,
                    eqLowBody: 0.42, eqMidSoothe: 0.16, eqHighAir: 0.28,
                    bloomBrightness: 0.20, bloomRoughness: -0.02, bloomPan: 0.02,
                    breathBrightness: 0.08, breathRoughness: 0.04, breathPan: 0.06,
                    edgeBrightness: 0.34, edgeRoughness: 0.32, edgePan: 0.03,
                    brightnessMin: 0.22, brightnessMax: 1.25, roughnessMin: 0.02, roughnessMax: 0.30, panMin: 0.0, panMax: 0.0)
            },
            \drone, {
                (kind: \stableDrone, brightnessBase: 0.42, roughnessBase: 0.04, panBase: 0.0,
                    eqLowBody: 0.24, eqMidSoothe: 0.28, eqHighAir: 0.28,
                    bloomBrightness: 0.30, bloomRoughness: -0.06, bloomPan: 0.10,
                    breathBrightness: 0.08, breathRoughness: 0.02, breathPan: 0.20,
                    edgeBrightness: 0.10, edgeRoughness: 0.08, edgePan: 0.03,
                    brightnessMin: 0.20, brightnessMax: 1.10, roughnessMin: 0.0, roughnessMax: 0.18, panMin: 0.0, panMax: 0.0)
            },
            { // production / unknown
                (kind: \balancedProduction, brightnessBase: 0.82, roughnessBase: 0.08, panBase: 0.0,
                    eqLowBody: 0.18, eqMidSoothe: 0.18, eqHighAir: 0.62,
                    bloomBrightness: 0.42, bloomRoughness: -0.04, bloomPan: 0.10,
                    breathBrightness: 0.20, breathRoughness: 0.10, breathPan: 0.24,
                    edgeBrightness: 0.52, edgeRoughness: 0.42, edgePan: 0.10,
                    brightnessMin: 0.35, brightnessMax: 2.05, roughnessMin: 0.02, roughnessMax: 0.34, panMin: 0.0, panMax: 0.0)
            }
        )
    };

    at[\adaptiveTimbreCompute] = {
        var mode, amount, tension, motion, targetErr, extCount, rvRep, rvConflict, gm, preset, profile;
        var harmonicStrain, motionStrain, externalPressure, registerVelocityConflict, abnormalPressure;
        var bloom, breath, edge, body, air, brightness, roughness, pan, low, mid, high;
        preset = (st[\tonePreset] ? (cfg[\render][\tonePreset] ? \production)).asSymbol;
        profile = at[\adaptiveTimbreToneProfile].(preset);
        mode = (cfg[\render][\adaptiveToneMode] ? \listening).asSymbol;
        amount = (cfg[\render][\adaptiveToneAmount] ? 0.35).asFloat.clip(0.0, 1.0);
        tension = (st[\tension] ? (cfg[\render][\tension] ? 0.55)).asFloat.clip(0.0, 1.0);
        motion = (st[\movement] ? 0.0).asFloat.clip(0.0, 1.0);
        targetErr = 0.0;
        if(at[\globalMotionGateSnapshot].notNil) {
            gm = at[\globalMotionGateSnapshot].();
            targetErr = ((gm[\maxTargetErrorCents] ? 0.0).asFloat / 48.0).clip(0.0, 1.0);
        };
        extCount = (st[\externalSources] ? Array.new).size;
        externalPressure = (extCount.asFloat / 6.0).clip(0.0, 1.0);
        rvRep = st[\lastRegisterVelocityChordAuthorityReport];
        registerVelocityConflict = if(rvRep.notNil) { ((rvRep[\contrast] ? 0.0).asFloat * 2.0).clip(0.0, 1.0) } { 0.0 };
        abnormalPressure = if((st[\externalCoherenceLastReport].notNil) and: { (st[\externalCoherenceLastReport][\abnormalCount] ? 0) > 0 }) { 1.0 } { 0.0 };
        harmonicStrain = ((1.0 - ((st[\lastStabilityMean] ? 0.72).asFloat.clip(0.0, 1.0))) * 0.50) + (targetErr * 0.35) + (registerVelocityConflict * 0.15);
        harmonicStrain = harmonicStrain.clip(0.0, 1.0);
        motionStrain = (targetErr * (1.0 - motion)).clip(0.0, 1.0);
        bloom = 0.0; breath = 0.0; edge = 0.0;
        switch(mode,
            \coherenceBloom, { bloom = harmonicStrain * amount; },
            \motionBreath, { breath = motionStrain * amount; },
            \tensionEdge, { edge = tension * amount; },
            \listening, {
                bloom = ((harmonicStrain * 0.62) + (externalPressure * 0.12)).clip(0.0, 1.0) * amount;
                breath = motionStrain * amount * 0.82;
                edge = ((tension * 0.52) + (externalPressure * 0.18) + (abnormalPressure * 0.18) + (registerVelocityConflict * 0.28)).clip(0.0, 1.0) * amount;
            },
            { }
        );
        low = (cfg[\render][\toneLow] ? 0.5).asFloat.clip(0.0, 1.0);
        mid = (cfg[\render][\toneMid] ? 0.5).asFloat.clip(0.0, 1.0);
        high = (cfg[\render][\toneHigh] ? 0.5).asFloat.clip(0.0, 1.0);
        body = (low - 0.5) * (profile[\eqLowBody] ? 0.0);
        air = (high - 0.5) * (profile[\eqHighAir] ? 0.0);
        brightness = ((profile[\brightnessBase] ? 0.82) + body + air
            + (bloom * (profile[\bloomBrightness] ? 0.0))
            + (breath * (profile[\breathBrightness] ? 0.0))
            + (edge * (profile[\edgeBrightness] ? 0.0))).clip(profile[\brightnessMin] ? 0.05, profile[\brightnessMax] ? 3.0);
        roughness = ((profile[\roughnessBase] ? 0.28) + (((0.5 - mid) max: 0.0) * (profile[\eqMidSoothe] ? 0.0))
            + (bloom * (profile[\bloomRoughness] ? 0.0))
            + (breath * (profile[\breathRoughness] ? 0.0))
            + (edge * (profile[\edgeRoughness] ? 0.0))
            + (abnormalPressure * amount * 0.10)).clip(profile[\roughnessMin] ? 0.0, profile[\roughnessMax] ? 3.0);
        pan = ((profile[\panBase] ? 0.20)
            + (bloom * (profile[\bloomPan] ? 0.0))
            + (breath * (profile[\breathPan] ? 0.0))
            + (edge * (profile[\edgePan] ? 0.0))).clip(profile[\panMin] ? 0.0, profile[\panMax] ? 2.0);
        (
            role: \adaptiveTimbreSoundOnly,
            version: \cleanFoundationPresetAware,
            tonePreset: preset,
            profileKind: profile[\kind] ? \balancedProduction,
            mode: mode,
            amount: amount,
            tension: tension,
            toneLow: low,
            toneMid: mid,
            toneHigh: high,
            harmonicStrain: harmonicStrain.round(0.0001),
            targetMotionDistance: targetErr.round(0.0001),
            motionStrain: motionStrain.round(0.0001),
            registerVelocityConflict: registerVelocityConflict.round(0.0001),
            externalPressure: externalPressure.round(0.0001),
            abnormalExternalContext: abnormalPressure.round(0.0001),
            bloomPush: bloom.round(0.0001),
            breathPush: breath.round(0.0001),
            edgePush: edge.round(0.0001),
            brightnessAmount: brightness.round(0.0001),
            roughnessAmount: roughness.clip(0.0, 0.38).round(0.0001),
            panMotionAmount: 0.0,
            presetSpecificMapping: true,
            pitchAuthorityAdded: false,
            tuningWrites: false,
            solverWrites: false,
            changesTimbreOnly: true
        )
    };

    api[\adaptiveTimbrePerformanceDefault] = {
        cfg[\render][\adaptiveToneMode] = cfg[\render][\adaptiveTonePerformanceDefaultMode] ? \listening;
        cfg[\render][\adaptiveToneAmount] = cfg[\render][\adaptiveTonePerformanceDefaultAmount] ? 0.35;
        if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        (mode: cfg[\render][\adaptiveToneMode], amount: cfg[\render][\adaptiveToneAmount])
    };


    // Clean foundation: production adaptive timbre only; old audit/audition commands removed.
    api[\adaptiveTimbrePerformanceDefault].();

    "[at-adaptive-timbre] clean per-tone adaptive timbre presets loaded; default listening/0.35, pitch-neutral.".postln;
};
)
