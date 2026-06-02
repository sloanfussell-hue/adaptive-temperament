(
// AT_sample_tone_evidence.scd
// v3D12: sample/tone evidence pipeline.
//
// This layer does not improve tone quality by faking sounds and does not grant
// pitch authority. It gives the instrument a clear evidence ledger for each tone:
// rendered model / sample asset status / measured or cached descriptor / next
// capture or install action. It is the practical bridge after v3D11: real samples
// and real spectral evidence can be registered here before any future tuning use.

var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[AT SAMPLE/TONE EVIDENCE] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(st[\sampleToneEvidenceDescriptors].isNil) { st[\sampleToneEvidenceDescriptors] = IdentityDictionary.new; };

    at[\sampleToneEvidenceProfiles] = { [\probe, \pure, \piano, \electricPiano, \organ, \pad, \synth] };

    at[\sampleToneEvidenceAssetStatus] = { |tone=\organ|
        var t, assets, status, loaded, required, sampleDir, source, license, sampleBased, notRequired, complete;
        t = (tone ? \organ).asSymbol;
        sampleBased = [\piano, \electricPiano].includes(t);
        notRequired = sampleBased.not;
        assets = nil;
        status = \notRequired;
        loaded = 0;
        required = 0;
        sampleDir = nil;
        source = \renderedModel;
        license = nil;

        if(t == \piano) {
            assets = at[\pianoAssets];
            status = if(assets.notNil) { assets[\status] ? \missing } { \missing };
            loaded = if(assets.notNil) { assets[\loadedLayerCount] ? 0 } { 0 };
            required = if(assets.notNil) { assets[\requiredLayerCount] ? 90 } { 90 };
            sampleDir = if(assets.notNil) { assets[\sampleDir] } { nil };
            source = if(assets.notNil) { assets[\source] ? \slenderSalamanderC5 } { \slenderSalamanderC5 };
            license = if(assets.notNil) { assets[\license] ? "CC BY 3.0" } { "CC BY 3.0" };
        };

        if(t == \electricPiano) {
            assets = at[\epianoAssets];
            status = if(assets.notNil) { assets[\status] ? \missing } { \missing };
            loaded = if(assets.notNil) { assets[\loadedLayerCount] ? 0 } { 0 };
            required = if(assets.notNil) { assets[\requiredLayerCount] ? 33 } { 33 };
            sampleDir = if(assets.notNil) { assets[\sampleDir] } { nil };
            source = \legalUserOrBundledEpianoKeygroups;
            license = "must be legal/user-supplied or bundled open-source floor";
        };

        complete = if(sampleBased) { status == \complete } { true };

        (
            toneProfile: t,
            sampleBased: sampleBased,
            sampleAssetRequired: sampleBased,
            sampleAssetNotRequired: notRequired,
            assetStatus: status,
            sampleComplete: complete,
            loadedLayerCount: loaded,
            requiredLayerCount: required,
            sampleDir: sampleDir,
            source: source,
            license: license,
            noGeneratedFakeSamples: true,
            note: if(sampleBased) {
                "sample-based tone requires complete legal keygroups before spectrum/stretch claims are trusted"
            } {
                "rendered model tone does not require sample assets for its conservative descriptor"
            }
        );
    };

    at[\sampleToneEvidenceDescriptorStoreKey] = { |tone=\organ, midi=60|
        ((tone ? \organ).asSymbol.asString ++ ":" ++ (midi ? 60).asInteger.asString).asSymbol
    };

    api[\setSampleToneEvidenceDescriptor] = { |tone=\organ, midi=60, partials=nil, sourceTag=\manualDescriptor, confidence=0.7|
        var t, key, clean, rep;
        t = (tone ? \organ).asSymbol;
        key = at[\sampleToneEvidenceDescriptorStoreKey].(t, midi ? 60);
        clean = (partials ? [[1.0, 1.0]]).collect { |pair|
            if(pair.isArray) {
                [(pair[0] ? 1.0).asFloat, (pair[1] ? 0.0).asFloat]
            } {
                [(pair[\ratio] ? 1.0).asFloat, (pair[\amplitude] ? (pair[\amp] ? 0.0)).asFloat]
            };
        };
        rep = (
            toneProfile: t,
            midi: (midi ? 60).asInteger,
            key: key,
            sourceTag: (sourceTag ? \manualDescriptor).asSymbol,
            confidence: (confidence ? 0.7).asFloat.clip(0.0, 1.0),
            descriptorPartialPairs: clean,
            descriptorPartialCount: clean.size,
            descriptorAvailable: true,
            verifiesSampleAsset: false,
            pitchAuthorityEligible: false,
            evidenceCanAuthorizePitch: false,
            note: "v3D12 stores manual/offline tone descriptors for sample/tone evidence only; descriptors do not verify missing samples and do not retune pitch"
        );
        st[\sampleToneEvidenceDescriptors][key] = rep;

        // Also mirror into the v3D11 measured-spectrum store so cylinder evidence reports
        // can inspect it. This still remains no-pitch and cannot verify samples.
        if(api[\setPerceptualCylinderMeasuredSpectrum].notNil) {
            api[\setPerceptualCylinderMeasuredSpectrum].(t, clean, sourceTag, confidence);
        };

        st[\sampleToneEvidenceLastDescriptorSet] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE DESCRIPTOR SET]".postln;
        ("tone=" ++ t.asString ++ " midi=" ++ (midi ? 60).asInteger.asString ++ " partials=" ++ clean.size.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\clearSampleToneEvidenceDescriptor] = { |tone=\organ, midi=60|
        var t, key, rep;
        t = (tone ? \organ).asSymbol;
        key = at[\sampleToneEvidenceDescriptorStoreKey].(t, midi ? 60);
        if(st[\sampleToneEvidenceDescriptors].notNil) { st[\sampleToneEvidenceDescriptors].removeAt(key); };
        if(api[\clearPerceptualCylinderMeasuredSpectrum].notNil) { api[\clearPerceptualCylinderMeasuredSpectrum].(t); };
        rep = (toneProfile: t, midi: (midi ? 60).asInteger, descriptorAvailable: false, pitchAuthorityEligible: false, note: "cleared sample/tone descriptor evidence; pitch authority remains blocked");
        st[\sampleToneEvidenceLastDescriptorClear] = rep;
        rep;
    };

    api[\sampleToneEvidenceDescriptorReport] = { |tone=\organ, midi=60|
        var t, key, entry, measured, score, rep;
        t = (tone ? \organ).asSymbol;
        key = at[\sampleToneEvidenceDescriptorStoreKey].(t, midi ? 60);
        entry = if(st[\sampleToneEvidenceDescriptors].notNil) { st[\sampleToneEvidenceDescriptors][key] } { nil };
        measured = if(api[\perceptualCylinderMeasuredSpectrumReport].notNil) { api[\perceptualCylinderMeasuredSpectrumReport].(t, midi) } { nil };
        score = if(measured.notNil) { measured[\measuredInharmonicityScore] ? 0.0 } { 0.0 };
        if(entry.isNil) {
            rep = (
                toneProfile: t,
                midi: (midi ? 60).asInteger,
                descriptorAvailable: false,
                descriptorPartialCount: 0,
                measuredEvidenceAvailable: if(measured.notNil) { measured[\measuredSpectrumAvailable] ? false } { false },
                pitchAuthorityEligible: false,
                note: "no sample/tone descriptor is stored for this tone/midi"
            );
        } {
            rep = entry.copy;
            rep[\measuredEvidenceAvailable] = if(measured.notNil) { measured[\measuredSpectrumAvailable] ? false } { false };
            rep[\measuredInharmonicityScore] = score;
            rep[\ordinaryOctaveSupportFromMeasurement] = if(measured.notNil) { measured[\ordinaryOctaveSupportFromMeasurement] ? \unknown } { \unknown };
            rep[\verifiesSampleAsset] = false;
            rep[\pitchAuthorityEligible] = false;
            rep[\evidenceCanAuthorizePitch] = false;
        };
        st[\sampleToneEvidenceLastDescriptorReport] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE DESCRIPTOR REPORT]".postln;
        ("tone=" ++ t.asString ++ " midi=" ++ (midi ? 60).asInteger.asString ++ " descriptor=" ++ (rep[\descriptorAvailable] ? false).asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleToneEvidenceReport] = { |tone=\organ, midi=60|
        var t, asset, truth, descriptor, sampleTruth, measured, defName, actualKind, sampleVerified, evidenceReady, fallbackPure, rep;
        t = (tone ? (cfg[\render][\toneProfile] ? \organ)).asSymbol;
        asset = at[\sampleToneEvidenceAssetStatus].(t);
        truth = if(api[\perceptualCylinderSpectralTruthReport].notNil) { api[\perceptualCylinderSpectralTruthReport].(t) } { at[\perceptualCylinderActualSpectrumTruth].(t) };
        descriptor = if(api[\perceptualCylinderActualSpectrumDescriptor].notNil) { api[\perceptualCylinderActualSpectrumDescriptor].(t, midi, 0.0, nil) } { nil };
        sampleTruth = if(api[\perceptualCylinderSampleTruthReport].notNil) { api[\perceptualCylinderSampleTruthReport].(t) } { nil };
        measured = if(api[\perceptualCylinderMeasuredSpectrumReport].notNil) { api[\perceptualCylinderMeasuredSpectrumReport].(t, midi) } { nil };
        defName = if(at[\toneProfileDefName].notNil) { at[\toneProfileDefName].(t) } { \unknown };
        fallbackPure = (truth[\truthStatus] ? \unknown) == \fallbackBlocked;
        actualKind = if(fallbackPure) { \fallbackPure } { truth[\truthStatus] ? \unknown };
        sampleVerified = if(sampleTruth.notNil) { sampleTruth[\sampleVerified] ? false } { asset[\sampleComplete] ? false };
        evidenceReady = if(asset[\sampleBased]) { sampleVerified } { (truth[\truthStatus] ? \unknown) == \actualRenderedModel or: { (truth[\truthStatus] ? \unknown) == \estimatedSynthetic } };
        rep = (
            toneProfile: t,
            midi: (midi ? 60).asInteger,
            synthDef: defName,
            sampleBased: asset[\sampleBased] ? false,
            sampleAssetStatus: asset[\assetStatus],
            sampleVerified: sampleVerified,
            actualKind: actualKind,
            actualSpectrumProfile: truth[\actualSpectrumProfile] ? \unknown,
            declaredSpectrumProfile: truth[\declaredSpectrumProfile] ? \unknown,
            actualDescriptorPartialCount: if(descriptor.notNil) { descriptor[\partialCount] ? 0 } { 0 },
            measuredEvidenceAvailable: if(measured.notNil) { measured[\measuredSpectrumAvailable] ? false } { false },
            measuredPartialCount: if(measured.notNil) { measured[\measuredPartialCount] ? 0 } { 0 },
            actualSoundEvidenceReady: evidenceReady,
            fallbackPure: fallbackPure,
            noGeneratedFakeSamples: asset[\noGeneratedFakeSamples] ? true,
            pitchAuthorityEligible: false,
            evidenceCanAuthorizePitch: false,
            nextStep: if(evidenceReady) { \captureOrCompareSpectrum } { if(asset[\sampleBased]) { \installVerifyLegalSamples } { \optionalRenderedSpectrumCapture } },
            note: "v3D12 reports practical tone/sample evidence readiness; it does not change tone engines, synthdefs, solver, render pitch, or cylinder authority"
        );
        st[\sampleToneEvidenceLastReport] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE REPORT]".postln;
        ("tone=" ++ t.asString ++ " actual=" ++ actualKind.asString ++ " sample=" ++ (asset[\assetStatus] ? \unknown).asString ++ " ready=" ++ evidenceReady.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleToneEvidenceCatalogReport] = {
        var profiles, entries, rep;
        profiles = at[\sampleToneEvidenceProfiles].();
        entries = profiles.collect { |p| at[\sampleToneEvidenceAssetStatus].(p) };
        rep = (
            profiles: profiles,
            entries: entries,
            builtInToneCount: profiles.size,
            stringsHiddenExternalOnly: true,
            noGeneratedFakeStrings: true,
            noGeneratedFakePiano: true,
            note: "v3D12 catalog keeps built-in tones explicit and keeps strings external-only; sample-based tones must have legal complete assets before sample-spectrum claims are trusted"
        );
        st[\sampleToneEvidenceLastCatalog] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE CATALOG]".postln;
        ("profiles=" ++ profiles.asString ++ " stringsExternalOnly=true").postln;
        rep;
    };

    api[\sampleToneEvidenceInstallPlan] = { |tone=\piano|
        var t, asset, url, commandAvailable, rep;
        t = (tone ? \piano).asSymbol;
        asset = at[\sampleToneEvidenceAssetStatus].(t);
        url = nil;
        commandAvailable = false;
        if(t == \piano and: { at[\pianoAssets].notNil }) {
            url = at[\pianoAssets][\downloadUrl];
            commandAvailable = api[\downloadSlenderPianoSamples].notNil;
        };
        rep = (
            toneProfile: t,
            sampleBased: asset[\sampleBased] ? false,
            currentAssetStatus: asset[\assetStatus],
            sampleDir: asset[\sampleDir],
            source: asset[\source],
            license: asset[\license],
            downloadUrl: url,
            commandAvailable: commandAvailable,
            noGeneratedFakeSamples: true,
            installAction: if((asset[\sampleBased] ? false).not) { \noneRequired } { if(t == \piano) { \downloadSlenderOrInstallLegalEquivalent } { \installLegalEpianoKeygroups } },
            pitchAuthorityAfterInstall: false,
            note: if((asset[\sampleBased] ? false).not) {
                "rendered-model tone does not need sample installation"
            } {
                "installing samples only creates actual sound evidence; pitch authority remains blocked until spectrum evidence and recognizability are proven"
            }
        );
        st[\sampleToneEvidenceLastInstallPlan] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE INSTALL PLAN]".postln;
        ("tone=" ++ t.asString ++ " action=" ++ (rep[\installAction] ? \unknown).asString ++ " fakeSamples=false pitchAuthority=false").postln;
        rep;
    };

    api[\sampleToneEvidenceToneQualityRiskReport] = { |tone=\organ|
        var t, ev, risk, reason, rep;
        t = (tone ? \organ).asSymbol;
        ev = api[\sampleToneEvidenceReport].(t, 60);
        risk = \low;
        reason = "rendered or verified tone has no known sample/fallback risk in this diagnostic";
        if(ev[\fallbackPure] == true) {
            risk = \high;
            reason = "sample-based profile is currently a pure fallback, so tone quality and spectrum claims are not valid";
        };
        if([\bellLike, \formantVoice].includes(t)) {
            risk = \diagnosticOnly;
            reason = "diagnostic spectral model exists but no built-in rendered/measured tone source is verified";
        };
        if((cfg[\render][\adaptiveToneMode] ? \static) != \static and: { (cfg[\render][\adaptiveToneAmount] ? 0.0) > 0.0 }) {
            if(risk == \low) { risk = \medium };
            reason = reason ++ "; adaptive tone coloration is active and may be heard as non-pitch weirdness";
        };
        rep = (
            toneProfile: t,
            risk: risk,
            fallbackPure: ev[\fallbackPure] ? false,
            adaptiveColorRisk: ((cfg[\render][\adaptiveToneMode] ? \static) != \static and: { (cfg[\render][\adaptiveToneAmount] ? 0.0) > 0.0 }),
            pitchAuthorityEligible: false,
            note: reason
        );
        st[\sampleToneEvidenceLastToneQualityRisk] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE QUALITY RISK REPORT]".postln;
        ("tone=" ++ t.asString ++ " risk=" ++ risk.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleToneEvidenceReadinessReport] = { |tone=\organ, midi=60|
        var ev, risk, rep;
        ev = api[\sampleToneEvidenceReport].(tone, midi);
        risk = api[\sampleToneEvidenceToneQualityRiskReport].(tone);
        rep = (
            toneProfile: ev[\toneProfile],
            midi: (midi ? 60).asInteger,
            actualSoundEvidenceReady: ev[\actualSoundEvidenceReady] ? false,
            toneQualityRisk: risk[\risk] ? \unknown,
            spectrumEvidenceReady: ((ev[\actualSoundEvidenceReady] ? false) and: { (ev[\measuredEvidenceAvailable] ? false) or: { (ev[\actualDescriptorPartialCount] ? 0) > 0 } }),
            canProceedToRenderedSpectrumCapture: ev[\actualSoundEvidenceReady] ? false,
            canProceedToPitchResearch: false,
            pitchAuthorityEligible: false,
            note: "v3D12 readiness is practical/evidence-only: samples or rendered tone must be real before spectrum capture, and pitch research remains blocked"
        );
        st[\sampleToneEvidenceLastReadiness] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE READINESS REPORT]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString ++ " soundReady=" ++ (rep[\actualSoundEvidenceReady] ? false).asString ++ " pitchResearch=false").postln;
        rep;
    };

    api[\renderedToneSpectrumCapturePlan] = { |tone=\organ, midi=60|
        var ev, rep;
        ev = api[\sampleToneEvidenceReport].(tone, midi);
        rep = (
            toneProfile: ev[\toneProfile],
            midi: (midi ? 60).asInteger,
            synthDef: ev[\synthDef],
            actualSoundEvidenceReady: ev[\actualSoundEvidenceReady] ? false,
            liveFftMeasured: false,
            offlineDescriptorCanBeStored: true,
            requiresSampleInstallFirst: (ev[\sampleBased] == true and: { (ev[\sampleVerified] ? false).not }),
            pitchAuthorityEligible: false,
            note: "v3D12 capture plan does not perform or pretend FFT; it tells whether rendered/offline analysis is meaningful for this tone right now"
        );
        st[\sampleToneEvidenceLastCapturePlan] = rep;
        "".postln;
        "[AT SAMPLE/TONE EVIDENCE CAPTURE PLAN]".postln;
        ("tone=" ++ (rep[\toneProfile] ? \unknown).asString ++ " fftMeasured=false requiresSampleInstall=" ++ (rep[\requiresSampleInstallFirst] ? false).asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleToneEvidenceReport].(cfg[\render][\toneProfile] ? \organ, 60);
    "[AT SAMPLE/TONE EVIDENCE] v3D12 loaded: sample/tone evidence reports installed; no tone engine or pitch behavior changed".postln;
};
)
