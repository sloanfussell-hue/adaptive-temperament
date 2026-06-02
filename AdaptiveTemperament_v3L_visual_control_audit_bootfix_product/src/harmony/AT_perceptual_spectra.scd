(
// AT_perceptual_spectra.scd
// Spectrum-material layer for the Sethares/perceptual roughness prototype.
// Tone Profile may select the spectral material used by the perceptual model,
// but this file never writes tuning state and never turns Tone/Timbre into a mode.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-perceptual-spectra] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    at[\perceptualEnsureSpectrumDefaults] = {
        if(cfg[\solver][\perceptualFollowToneProfile].isNil) { cfg[\solver][\perceptualFollowToneProfile] = true; };
        if(cfg[\solver][\perceptualFollowToneSurface].isNil) { cfg[\solver][\perceptualFollowToneSurface] = false; };
        if(cfg[\solver][\perceptualInternalProfile].isNil) { cfg[\solver][\perceptualInternalProfile] = \auto; };
        if(cfg[\solver][\perceptualExternalProfile].isNil) { cfg[\solver][\perceptualExternalProfile] = \micObserved; };
        if(cfg[\solver][\perceptualDiagnosticProfile].isNil) { cfg[\solver][\perceptualDiagnosticProfile] = \production; };
        true
    };

    at[\perceptualBuildSpectralProfiles] = {
        var d;
        d = IdentityDictionary.new;

        // pressureScale is not a musical mode. It is a physical confidence/strength
        // estimate for how audibly this spectral material exposes beating.
        d[\pure] = (
            label: "Pure sine",
            partials: [1.0],
            amps: [1.0],
            pressureScale: 0.22,
            description: "single partial; weak roughness pressure"
        );

        d[\production] = (
            label: "Production harmonic",
            partials: [1, 2, 3, 4, 5, 6, 8],
            amps: [1.0, 0.52, 0.34, 0.25, 0.20, 0.16, 0.11],
            pressureScale: 1.0,
            description: "generic harmonic AT production voice"
        );

        d[\piano] = (
            label: "Piano / stretched harmonic",
            partials: [1.0, 2.002, 3.006, 4.014, 5.026, 6.041, 8.078],
            amps: [1.0, 0.42, 0.24, 0.16, 0.105, 0.072, 0.040],
            pressureScale: 0.72,
            description: "decaying piano-like partials with mild stretch"
        );

        d[\electricPiano] = (
            label: "Clean electric piano",
            partials: [1.0, 2.01, 3.98, 4.02, 5.20, 6.10],
            amps: [1.0, 0.34, 0.15, 0.10, 0.055, 0.035],
            pressureScale: 0.58,
            description: "Rhodes-like tine/bell spectrum; moderate pressure"
        );

        d[\organ] = (
            label: "Organ / sustained drawbars",
            partials: [1, 2, 3, 4, 5, 6, 8],
            amps: [1.0, 0.58, 0.38, 0.24, 0.18, 0.12, 0.08],
            pressureScale: 1.28,
            description: "stable sustained harmonic partials; beating is exposed"
        );

        d[\strings] = (
            label: "Strings / bowed harmonic",
            partials: [1, 2, 3, 4, 5, 6, 7, 8],
            amps: [1.0, 0.55, 0.32, 0.22, 0.16, 0.12, 0.09, 0.07],
            pressureScale: 0.96,
            description: "bowed harmonic spectrum with broad upper partials"
        );

        d[\pad] = (
            label: "Pad / cloudy harmonic",
            partials: [0.5, 1.0, 2.0, 3.0, 4.0],
            amps: [0.35, 1.0, 0.34, 0.14, 0.08],
            pressureScale: 0.62,
            description: "soft spectrum with sub/second harmonic emphasis"
        );

        d[\synth] = (
            label: "Bright synth / saw",
            partials: [0.5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12],
            amps: [0.26, 1.0, 0.50, 0.33, 0.25, 0.20, 0.17, 0.14, 0.12, 0.105, 0.095, 0.075],
            pressureScale: 1.08,
            description: "bright saw/pulse-like spectrum"
        );

        d[\bass] = (
            label: "Bass / sub harmonic",
            partials: [0.5, 1.0, 2.0, 3.0, 4.0],
            amps: [0.32, 1.0, 0.27, 0.11, 0.055],
            pressureScale: 0.78,
            description: "sub/fundamental-heavy spectrum"
        );

        d[\drone] = (
            label: "Drone / low partial cloud",
            partials: [0.5, 1.0, 1.5, 2.0, 3.0],
            amps: [0.30, 1.0, 0.26, 0.18, 0.09],
            pressureScale: 0.66,
            description: "slow, broad drone spectrum"
        );

        d[\bellInharmonic] = (
            label: "Bell / inharmonic",
            partials: [1.0, 2.01, 2.73, 3.98, 5.31, 6.71, 8.07],
            amps: [1.0, 0.42, 0.31, 0.20, 0.13, 0.09, 0.055],
            pressureScale: 1.12,
            description: "inharmonic material; consonance need not be JI"
        );

        d[\micObserved] = (
            label: "Mic observed fallback",
            partials: [1, 2, 3, 4, 5, 6],
            amps: [1.0, 0.45, 0.26, 0.16, 0.10, 0.065],
            pressureScale: 0.90,
            description: "fallback spectrum for detected external notes"
        );

        d[\externalEt] = (
            label: "External ET piano/synth evidence",
            partials: [1.0, 2.001, 3.004, 4.009, 5.018, 6.030],
            amps: [1.0, 0.40, 0.23, 0.15, 0.09, 0.06],
            pressureScale: 0.80,
            description: "diagnostic external equal-tempered source"
        );

        st[\perceptualSpectralProfiles] = d;
        d
    };

    at[\perceptualSpectralProfiles] = {
        if(st[\perceptualSpectralProfiles].isNil) { at[\perceptualBuildSpectralProfiles].(); };
        st[\perceptualSpectralProfiles]
    };

    at[\perceptualListProfiles] = {
        [\pure, \production, \piano, \electricPiano, \organ, \strings, \pad, \synth, \bass, \drone, \bellInharmonic, \micObserved, \externalEt]
    };

    at[\perceptualNormalizeProfile] = { |profile=\production|
        var symbol, allowed;
        symbol = if(profile.isNil) { \production } { profile.asSymbol };
        if(symbol == \epiano) { symbol = \electricPiano; };
        if(symbol == \ePiano) { symbol = \electricPiano; };
        if(symbol == \probe) { symbol = \production; };
        allowed = at[\perceptualListProfiles].();
        if(allowed.includes(symbol).not) { symbol = \production; };
        symbol
    };

    at[\perceptualProfileEvent] = { |profile=\production|
        var d, symbol, ev;
        d = at[\perceptualSpectralProfiles].();
        symbol = at[\perceptualNormalizeProfile].(profile);
        ev = d[symbol];
        if(ev.isNil) { ev = d[\production]; };
        ev
    };

    at[\perceptualInternalProfileSymbol] = {
        var configured, tone;
        at[\perceptualEnsureSpectrumDefaults].();
        configured = cfg[\solver][\perceptualInternalProfile] ? \auto;
        if(configured.asSymbol != \auto) {
            at[\perceptualNormalizeProfile].(configured)
        } {
            if((cfg[\solver][\perceptualFollowToneProfile] ? true).asBoolean) {
                tone = st[\tonePreset] ? (cfg[\render][\tonePreset] ? \production);
                at[\perceptualNormalizeProfile].(tone)
            } {
                \production
            }
        }
    };

    at[\perceptualExternalProfileSymbol] = { |src=nil|
        var configured, role, kind;
        at[\perceptualEnsureSpectrumDefaults].();
        configured = cfg[\solver][\perceptualExternalProfile] ? \micObserved;
        if(configured.asSymbol != \auto) {
            at[\perceptualNormalizeProfile].(configured)
        } {
            if(src.isNil) {
                \micObserved
            } {
                kind = src[\kind] ? \external;
                role = src[\sourceRole] ? src[\role] ? \external;
                if((kind == \externalEtDiagnostic) or: { role == \externalEt }) { \externalEt } { \micObserved }
            }
        }
    };

    at[\perceptualPressureScaleForProfile] = { |profile=\production|
        var ev;
        ev = at[\perceptualProfileEvent].(profile);
        (ev[\pressureScale] ? 1.0).asFloat.clip(0.05, 2.0)
    };



    at[\perceptualProfileConfidence] = { |profile=\production|
        var symbol, d, value;
        symbol = at[\perceptualNormalizeProfile].(profile);
        d = IdentityDictionary.new;
        d[\pure] = 0.16;
        d[\production] = 0.92;
        d[\piano] = 0.62;
        d[\electricPiano] = 0.38;
        d[\organ] = 1.00;
        d[\strings] = 0.86;
        d[\pad] = 0.28;
        d[\synth] = 0.88;
        d[\bass] = 0.52;
        d[\drone] = 0.36;
        d[\bellInharmonic] = 0.46;
        d[\micObserved] = 0.64;
        d[\externalEt] = 0.74;
        value = d[symbol];
        if(value.isNil) { value = 0.70; };
        value.asFloat.clip(0.05, 1.10)
    };

    at[\perceptualRegularizationRestraintForProfile] = { |profile=\production|
        var confidence;
        confidence = if(at[\perceptualProfileConfidence].notNil) { at[\perceptualProfileConfidence].(profile) } { 0.70 };
        (1.0 - confidence).clip(0.0, 1.0)
    };

    at[\perceptualTemplateForProfile] = { |profile=\production|
        var ev, nums, amps, n, followSurface, brightTilt, midScale, idxDenom;
        ev = at[\perceptualProfileEvent].(profile);
        nums = ev[\partials] ? [1.0];
        amps = ev[\amps] ? [1.0];
        n = nums.size.min(amps.size);
        followSurface = (cfg[\solver][\perceptualFollowToneSurface] ? false).asBoolean;
        brightTilt = 1.0;
        midScale = 1.0;
        if(followSurface) {
            brightTilt = (0.65 + ((cfg[\render][\toneHigh] ? 0.5).clip(0.0, 1.0) * 0.70)).clip(0.35, 1.55);
            midScale = (0.80 + ((cfg[\render][\toneMid] ? 0.5).clip(0.0, 1.0) * 0.40)).clip(0.55, 1.35);
        };
        idxDenom = (n - 1).max(1).asFloat;
        Array.fill(n, { |idx|
            var ratio, amp, pos, tilt;
            ratio = nums[idx].asFloat.max(0.0001);
            amp = amps[idx].asFloat.max(0.0);
            pos = idx.asFloat / idxDenom;
            tilt = (1.0 + ((pos - 0.5) * (brightTilt - 1.0) * 1.2)).clip(0.05, 2.25);
            (ratio: ratio, amp: (amp * tilt * midScale).max(0.0))
        })
    };

    at[\perceptualSpectrumForFreqProfile] = { |freq, noteWeight=1.0, profile=\production|
        var partials, spectrum, base, weight;
        partials = at[\perceptualTemplateForProfile].(profile);
        spectrum = Array.new;
        base = freq.asFloat.max(0.001);
        weight = noteWeight.asFloat.max(0.0);
        partials.do { |part|
            var partialFreq, partialAmp;
            partialFreq = base * (part[\ratio] ? 1.0);
            partialAmp = (part[\amp] ? 0.0) * weight;
            if((partialFreq > 15.0) and: { partialFreq < 20000.0 } and: { partialAmp > 0.000001 }) {
                spectrum = spectrum.add((freq: partialFreq, amp: partialAmp, ratio: part[\ratio] ? 1.0, profile: profile));
            };
        };
        spectrum
    };

    at[\perceptualSpectrumForSpec] = { |spec|
        var profile;
        if(spec.isNil) {
            Array.new
        } {
            profile = spec[\profile];
            if(profile.isNil) {
                if((spec[\kind] ? \internal) == \internal) {
                    profile = at[\perceptualInternalProfileSymbol].();
                } {
                    profile = at[\perceptualExternalProfileSymbol].(spec);
                };
            };
            at[\perceptualSpectrumForFreqProfile].(spec[\freq] ? 0.0, spec[\weight] ? 1.0, profile)
        }
    };

    at[\perceptualSpectrumSnapshot] = {
        var internalProfile, externalProfile, internalEv, externalEv;
        at[\perceptualEnsureSpectrumDefaults].();
        internalProfile = at[\perceptualInternalProfileSymbol].();
        externalProfile = cfg[\solver][\perceptualExternalProfile] ? \micObserved;
        externalProfile = if(externalProfile.asSymbol == \auto) { \auto } { at[\perceptualNormalizeProfile].(externalProfile) };
        internalEv = at[\perceptualProfileEvent].(internalProfile);
        externalEv = if(externalProfile == \auto) { (label: "Auto external", description: "source-sensitive external profile") } { at[\perceptualProfileEvent].(externalProfile) };
        (
            tonePreset: st[\tonePreset] ? (cfg[\render][\tonePreset] ? \production),
            internalProfile: internalProfile,
            externalProfile: externalProfile,
            followToneProfile: (cfg[\solver][\perceptualFollowToneProfile] ? true).asBoolean,
            followToneSurface: (cfg[\solver][\perceptualFollowToneSurface] ? false).asBoolean,
            internalLabel: internalEv[\label],
            externalLabel: externalEv[\label],
            internalPressureScale: at[\perceptualPressureScaleForProfile].(internalProfile),
            internalSpectralConfidence: at[\perceptualProfileConfidence].(internalProfile),
            description: "spectrum material only; not a temperament mode and no direct nodePhase writes"
        )
    };

    api[\listPerceptualSpectralProfiles] = { at[\perceptualListProfiles].() };

    api[\setPerceptualFollowToneProfile] = { |flag=true|
        at[\perceptualEnsureSpectrumDefaults].();
        cfg[\solver][\perceptualFollowToneProfile] = flag.asBoolean;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualFollowToneProfile]
    };

    api[\setPerceptualFollowToneSurface] = { |flag=false|
        at[\perceptualEnsureSpectrumDefaults].();
        cfg[\solver][\perceptualFollowToneSurface] = flag.asBoolean;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualFollowToneSurface]
    };

    api[\setPerceptualInternalProfile] = { |profile=\auto|
        at[\perceptualEnsureSpectrumDefaults].();
        if(profile.isNil or: { profile.asSymbol == \auto }) {
            cfg[\solver][\perceptualInternalProfile] = \auto;
        } {
            cfg[\solver][\perceptualInternalProfile] = at[\perceptualNormalizeProfile].(profile);
        };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualInternalProfile]
    };

    api[\setPerceptualExternalProfile] = { |profile=\micObserved|
        at[\perceptualEnsureSpectrumDefaults].();
        if(profile.isNil or: { profile.asSymbol == \auto }) {
            cfg[\solver][\perceptualExternalProfile] = \auto;
        } {
            cfg[\solver][\perceptualExternalProfile] = at[\perceptualNormalizeProfile].(profile);
        };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualExternalProfile]
    };

    api[\perceptualSpectrumSnapshot] = { at[\perceptualSpectrumSnapshot].() };

    at[\perceptualEnsureSpectrumDefaults].();
    at[\perceptualBuildSpectralProfiles].();
    "[at-perceptual-spectra] spectrum material + confidence model loaded (tone-aware only when perceptual pressure is enabled).".postln;
};
)
