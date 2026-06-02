(
// AT_visual_tension_timbre.scd
// v2f: visual-control contract + Tension/Adaptive Timbre semantic audit.
// This is intentionally render/control-surface work. It does not add tuning authority.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-visual-tension] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(cfg[\solver].isNil) { cfg[\solver] = IdentityDictionary.new; };
    if(cfg[\gravity].isNil) { cfg[\gravity] = IdentityDictionary.new; };
    if(cfg[\micScene].isNil) { cfg[\micScene] = IdentityDictionary.new; };
    if(cfg[\micResponse].isNil) { cfg[\micResponse] = IdentityDictionary.new; };

    cfg[\solver][\tensionPitchReference] = cfg[\solver][\tensionPitchReference] ? 0.55;
    cfg[\render][\tonePreset] = cfg[\render][\tonePreset] ? (st[\tonePreset] ? \production);
    cfg[\render][\toneLow] = cfg[\render][\toneLow] ? 0.5;
    cfg[\render][\toneMid] = cfg[\render][\toneMid] ? 0.5;
    cfg[\render][\toneHigh] = cfg[\render][\toneHigh] ? 0.5;
    cfg[\render][\adaptiveToneMode] = cfg[\render][\adaptiveToneMode] ? \static;
    cfg[\render][\adaptiveToneAmount] = cfg[\render][\adaptiveToneAmount] ? 0.0;
    cfg[\render][\adaptiveToneModes] = cfg[\render][\adaptiveToneModes] ? [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening];
    st[\tonePreset] = cfg[\render][\tonePreset];

    at[\tensionPitchReference] = {
        (cfg[\solver][\tensionPitchReference] ? 0.55).asFloat.clip(0.0, 1.0)
    };

    at[\adaptiveTimbreCompute] = {
        var mode, amount, tension, motion, targetErr, extCount, rvRep, rvConflict, gm;
        var harmonicStrain, motionStrain, externalPressure, registerVelocityConflict, abnormalPressure;
        var bloom, breath, edge, brightness, roughness, pan, low, mid, high;
        mode = (cfg[\render][\adaptiveToneMode] ? \static).asSymbol;
        amount = (cfg[\render][\adaptiveToneAmount] ? 0.0).asFloat.clip(0.0, 1.0);
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
        harmonicStrain = ((1.0 - ((st[\lastStabilityMean] ? 0.72).asFloat.clip(0.0, 1.0))) * 0.55) + (targetErr * 0.45);
        harmonicStrain = harmonicStrain.clip(0.0, 1.0);
        motionStrain = (targetErr * (1.0 - motion)).clip(0.0, 1.0);
        bloom = 0.0; breath = 0.0; edge = 0.0;
        switch(mode,
            \coherenceBloom, { bloom = harmonicStrain * amount; },
            \motionBreath, { breath = motionStrain * amount; },
            \tensionEdge, { edge = tension * amount; },
            \listening, {
                bloom = harmonicStrain * amount * 0.55;
                breath = motionStrain * amount * 0.40;
                edge = ((tension * 0.55) + (externalPressure * 0.30) + (abnormalPressure * 0.25) + (registerVelocityConflict * 0.25)).clip(0.0, 1.0) * amount;
            },
            { }
        );
        low = (cfg[\render][\toneLow] ? 0.5).asFloat.clip(0.0, 1.0);
        mid = (cfg[\render][\toneMid] ? 0.5).asFloat.clip(0.0, 1.0);
        high = (cfg[\render][\toneHigh] ? 0.5).asFloat.clip(0.0, 1.0);
        brightness = (0.35 + (high * 2.15) + (bloom * 0.55) + (edge * 0.85)).clip(0.05, 3.0);
        roughness = (0.30 + ((1.0 - mid) * 1.20) + (edge * 0.90) + (abnormalPressure * amount * 0.35)).clip(0.0, 3.0);
        pan = (0.15 + (breath * 1.35) + ((1.0 - low) * 0.30)).clip(0.0, 2.0);
        (
            role: \adaptiveTimbreSoundOnly,
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
            roughnessAmount: roughness.round(0.0001),
            panMotionAmount: pan.round(0.0001),
            pitchAuthorityAdded: false,
            tuningWrites: false,
            solverWrites: false,
            changesTimbreOnly: true
        )
    };

    api[\applyAdaptiveTimbre] = {
        var rep;
        rep = at[\adaptiveTimbreCompute].();
        cfg[\render][\brightnessAmount] = rep[\brightnessAmount];
        cfg[\render][\roughnessAmount] = rep[\roughnessAmount];
        cfg[\render][\panMotionAmount] = rep[\panMotionAmount];
        if(at[\setActiveVoiceParam].notNil) {
            at[\setActiveVoiceParam].(\brightnessAmount, rep[\brightnessAmount]);
            at[\setActiveVoiceParam].(\roughnessAmount, rep[\roughnessAmount]);
            at[\setActiveVoiceParam].(\panMotionAmount, rep[\panMotionAmount]);
        };
        st[\lastAdaptiveTimbreReport] = rep;
        rep
    };

    api[\setTension] = { |x|
        st[\tension] = x.asFloat.clip(0.0, 1.0);
        cfg[\render][\tension] = st[\tension];
        if(st[\tensionBus].notNil) { st[\tensionBus].set(st[\tension]); };
        if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); };
        // v2f: no resolveNow here. Tension is timbre/expression only, not pitch authority.
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        st[\tension]
    };

    api[\setTonePreset] = { |preset=\production|
        var p;
        p = preset.asSymbol;
        if([\production, \piano, \electricPiano, \organ, \strings, \pad, \synth, \bass, \drone].includes(p).not) { p = \production; };
        st[\tonePreset] = p;
        cfg[\render][\tonePreset] = p;
        cfg[\render][\toneProfile] = p;
        if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        p
    };
    api[\setToneProfile] = { |preset=\production| api[\setTonePreset].(preset) };
    api[\setToneLow] = { |x| cfg[\render][\toneLow] = x.asFloat.clip(0.0, 1.0); if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); }; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\render][\toneLow] };
    api[\setToneMid] = { |x| cfg[\render][\toneMid] = x.asFloat.clip(0.0, 1.0); if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); }; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\render][\toneMid] };
    api[\setToneHigh] = { |x| cfg[\render][\toneHigh] = x.asFloat.clip(0.0, 1.0); if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); }; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\render][\toneHigh] };
    api[\setAdaptiveToneMode] = { |mode=\static|
        var m;
        m = mode.asSymbol;
        if((cfg[\render][\adaptiveToneModes] ? [\static]).includes(m).not) { m = \static; };
        cfg[\render][\adaptiveToneMode] = m;
        if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        m
    };
    api[\setAdaptiveToneAmount] = { |x| cfg[\render][\adaptiveToneAmount] = x.asFloat.clip(0.0, 1.0); if(api[\applyAdaptiveTimbre].notNil) { api[\applyAdaptiveTimbre].(); }; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\render][\adaptiveToneAmount] };

    api[\setRegisterVelocityAuthority] = { |registerAmount=nil, velocityAmount=nil|
        if(registerAmount.notNil) { cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] = registerAmount.asFloat.clip(0.0, 1.0); };
        if(velocityAmount.notNil) { cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] = velocityAmount.asFloat.clip(0.0, 1.0); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        (register: cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] ? 0.46, velocity: cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] ? 0.54)
    };

    api[\setGravityType] = { |type=\off|
        var t;
        t = type.asSymbol;
        if([\off, \absolute, \pitchClass, \both].includes(t).not) { t = \off; };
        cfg[\gravity][\type] = t;
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(t != \off); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        t
    };
    api[\setGravityTargetMidi] = { |midi=60, cents=0.0, type=\absolute|
        var m, pc, c;
        m = midi.asInteger.clip(0, 127); pc = m % 12; c = cents.asFloat.clip(-100.0, 100.0);
        cfg[\gravity][\targetMidi] = m; cfg[\gravity][\targetPc] = pc; cfg[\gravity][\targetCents] = c; cfg[\gravity][\type] = type.asSymbol;
        if(at[\setGravityHome].notNil) { at[\setGravityHome].(pc, c); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].((type.asSymbol) != \off); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        st[\gravityHomePhase]
    };
    api[\setGravityTargetPc] = { |pc=0, cents=0.0, type=\pitchClass|
        var p, c;
        p = pc.asInteger.clip(0, 11); c = cents.asFloat.clip(-100.0, 100.0);
        cfg[\gravity][\targetPc] = p; cfg[\gravity][\targetCents] = c; cfg[\gravity][\type] = type.asSymbol;
        if(at[\setGravityHome].notNil) { at[\setGravityHome].(p, c); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].((type.asSymbol) != \off); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        st[\gravityHomePhase]
    };
    api[\setGravityTargetFreq] = { |freq=261.625565, type=\absolute|
        var f, midiFloat, midi, cents, pc;
        f = freq.asFloat.clip(20.0, 5000.0);
        midiFloat = (69.0 + (12.0 * ((f / 440.0).log / 2.0.log)));
        midi = midiFloat.round.asInteger.clip(0, 127);
        cents = ((midiFloat - midi.asFloat) * 100.0).clip(-100.0, 100.0);
        pc = midi % 12;
        cfg[\gravity][\targetFreq] = f; cfg[\gravity][\targetMidi] = midi; cfg[\gravity][\targetPc] = pc; cfg[\gravity][\targetCents] = cents; cfg[\gravity][\type] = type.asSymbol;
        if(at[\setGravityHome].notNil) { at[\setGravityHome].(pc, cents); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].((type.asSymbol) != \off); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        st[\gravityHomePhase]
    };
    api[\setGravityAuthority] = { |x| cfg[\gravity][\authority] = x.asFloat.clip(0.0, 1.5); if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\gravity][\authority] };
    api[\setGravitySlew] = { |x| cfg[\gravity][\slew] = x.asFloat.clip(0.0, 1.0); if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\gravity][\slew] };
    api[\setGravityPitchClassWeight] = { |x| cfg[\gravity][\pitchClassWeight] = x.asFloat.clip(0.0, 1.5); if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\gravity][\pitchClassWeight] };
    api[\clearGravity] = { if(at[\clearGravity].notNil) { at[\clearGravity].(); }; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; true };
    api[\gravitySnapshot] = { if(api[\gravityReport].notNil) { api[\gravityReport].() } { (enabled: cfg[\gravity][\enabled] ? false) } };

    api[\setMicSceneEnabled] = { |flag=true| cfg[\micScene][\enabled] = flag.asBoolean; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\micScene][\enabled] };
    api[\setMicFieldResponseEnabled] = { |flag=true| cfg[\micResponse][\enabled] = flag.asBoolean; if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); }; cfg[\micResponse][\enabled] };
    api[\setMicPitchThreshold] = { |x| if(api[\setMicPitchAmpThreshold].notNil) { api[\setMicPitchAmpThreshold].(x) } { cfg[\mic][\pitchAmpThreshold] = x.asFloat.clip(0.00001, 0.2) } };

    api[\toneSnapshot] = {
        (
            tonePreset: st[\tonePreset] ? (cfg[\render][\tonePreset] ? \production),
            toneLow: cfg[\render][\toneLow] ? 0.5,
            toneMid: cfg[\render][\toneMid] ? 0.5,
            toneHigh: cfg[\render][\toneHigh] ? 0.5,
            adaptiveToneMode: cfg[\render][\adaptiveToneMode] ? \static,
            adaptiveToneAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
            brightnessAmount: cfg[\render][\brightnessAmount] ? 1.0,
            roughnessAmount: cfg[\render][\roughnessAmount] ? 1.0,
            panMotionAmount: cfg[\render][\panMotionAmount] ? 1.0,
            tension: st[\tension] ? (cfg[\render][\tension] ? 0.55),
            tensionRole: \harmonicStrainTimbre,
            pitchAuthorityAdded: false,
            tuningWrites: false,
            adaptiveTimbre: st[\lastAdaptiveTimbreReport] ? at[\adaptiveTimbreCompute].()
        )
    };

    api[\tensionSemanticReport] = {
        (
            role: \harmonicStrainTimbre,
            tension: st[\tension] ? (cfg[\render][\tension] ? 0.55),
            pitchReferenceUsedBySolver: at[\tensionPitchReference].(),
            liveTensionAffectsPitch: false,
            pitchAuthorityAdded: false,
            keyDetection: false,
            changesTimbreOnly: true,
            adaptiveToneConnection: \tensionCanDriveEdgeBrightnessBreathWithoutRetuning,
            motionRelation: \motionControlsMovementRateOnly
        )
    };

    api[\tensionAdaptiveTimbreReport] = { at[\adaptiveTimbreCompute].() };


    // Clean foundation: no old audit/test entry points remain here.
    api[\applyAdaptiveTimbre].();

    "[at-visual-tension] clean visual controls + pitch-neutral Tension/adaptive timbre surface loaded.".postln;
};
)
