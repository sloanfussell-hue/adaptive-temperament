(
// AT_actual_spectrum.scd
// Diagnostic actual-spectrum material pipeline.
// This is the layer that keeps Sethares/cylinder/formant logic honest:
// actual tone material -> partial frequencies/amplitudes -> optional formant/body envelope
// -> time-varying spectral weights -> roughness/cylinder diagnostics.
// It does not install a solver hook and never writes nodePhase, trueGauge,
// nodeShape, targetNodeShape, or render voice offsets.

var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-actual-spectrum] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    at[\actualSpectrumEnsureDefaults] = {
        if(cfg[\solver][\actualSpectrumDiagnosticsEnabled].isNil) { cfg[\solver][\actualSpectrumDiagnosticsEnabled] = true; };
        if(cfg[\solver][\actualSpectrumUseForLiveRoughness].isNil) { cfg[\solver][\actualSpectrumUseForLiveRoughness] = false; };
        if(cfg[\solver][\actualSpectrumUseForCylinder].isNil) { cfg[\solver][\actualSpectrumUseForCylinder] = false; };
        if(cfg[\solver][\actualSpectrumCandidateLimitCents].isNil) { cfg[\solver][\actualSpectrumCandidateLimitCents] = 16.0; };
        if(cfg[\solver][\actualSpectrumCandidateStepCents].isNil) { cfg[\solver][\actualSpectrumCandidateStepCents] = 4.0; };
        if(cfg[\solver][\actualSpectrumFormantEnabled].isNil) { cfg[\solver][\actualSpectrumFormantEnabled] = false; };
        if(cfg[\solver][\actualSpectrumFormantAmount].isNil) { cfg[\solver][\actualSpectrumFormantAmount] = 0.0; };
        if(cfg[\solver][\actualSpectrumFormantCenterHz].isNil) { cfg[\solver][\actualSpectrumFormantCenterHz] = 1200.0; };
        if(cfg[\solver][\actualSpectrumFormantBandwidthSemitones].isNil) { cfg[\solver][\actualSpectrumFormantBandwidthSemitones] = 7.0; };
        if(cfg[\solver][\actualSpectrumPianoB].isNil) { cfg[\solver][\actualSpectrumPianoB] = 0.00030; };
        if(cfg[\solver][\actualSpectrumElectricPianoB].isNil) { cfg[\solver][\actualSpectrumElectricPianoB] = 0.00010; };
        if(cfg[\solver][\actualSpectrumAttackAgeSeconds].isNil) { cfg[\solver][\actualSpectrumAttackAgeSeconds] = 0.03; };
        if(cfg[\solver][\actualSpectrumTailAgeSeconds].isNil) { cfg[\solver][\actualSpectrumTailAgeSeconds] = 1.80; };
        true
    };

    at[\actualSpectrumNormalizeProfile] = { |profile=\production|
        if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(profile) } { if(profile.isNil) { \production } { profile.asSymbol } }
    };

    at[\actualSpectrumFamilyForProfile] = { |profile=\production|
        var p, family;
        p = at[\actualSpectrumNormalizeProfile].(profile);
        family = \harmonic;
        if(p == \piano) { family = \pianoStiffString; };
        if(p == \electricPiano) { family = \electricPianoTine; };
        if(p == \bellInharmonic) { family = \inharmonicBell; };
        if(p == \pure) { family = \pure; };
        if(p == \organ) { family = \sustainedHarmonic; };
        family
    };

    at[\actualSpectrumInharmonicityBForProfile] = { |profile=\production|
        var p, b;
        at[\actualSpectrumEnsureDefaults].();
        p = at[\actualSpectrumNormalizeProfile].(profile);
        b = 0.0;
        if(p == \piano) { b = (cfg[\solver][\actualSpectrumPianoB] ? 0.00030).asFloat; };
        if(p == \electricPiano) { b = (cfg[\solver][\actualSpectrumElectricPianoB] ? 0.00010).asFloat; };
        b.max(0.0)
    };

    at[\actualSpectrumDecayParamsForProfile] = { |profile=\production|
        var p, base, high;
        p = at[\actualSpectrumNormalizeProfile].(profile);
        base = 0.10;
        high = 0.35;
        if(p == \piano) { base = 0.20; high = 1.35; };
        if(p == \electricPiano) { base = 0.12; high = 0.82; };
        if(p == \organ) { base = 0.00; high = 0.00; };
        if(p == \strings) { base = 0.035; high = 0.16; };
        if(p == \pad) { base = 0.025; high = 0.10; };
        if(p == \synth) { base = 0.08; high = 0.35; };
        if(p == \bellInharmonic) { base = 0.28; high = 0.55; };
        if(p == \pure) { base = 0.05; high = 0.0; };
        (base: base, high: high)
    };

    at[\actualSpectrumFormantWeight] = { |freq=440.0, formantSpec=nil|
        var enabled, amount, center, bw, f, semis, x, weight;
        at[\actualSpectrumEnsureDefaults].();
        enabled = (cfg[\solver][\actualSpectrumFormantEnabled] ? false).asBoolean;
        amount = cfg[\solver][\actualSpectrumFormantAmount] ? 0.0;
        center = cfg[\solver][\actualSpectrumFormantCenterHz] ? 1200.0;
        bw = cfg[\solver][\actualSpectrumFormantBandwidthSemitones] ? 7.0;
        if(formantSpec.notNil) {
            if(formantSpec[\enabled].notNil) { enabled = formantSpec[\enabled].asBoolean; };
            if(formantSpec[\amount].notNil) { amount = formantSpec[\amount]; };
            if(formantSpec[\centerHz].notNil) { center = formantSpec[\centerHz]; };
            if(formantSpec[\bandwidthSemitones].notNil) { bw = formantSpec[\bandwidthSemitones]; };
        };
        amount = amount.asFloat.clip(0.0, 3.0);
        if((enabled.not) or: { amount <= 0.000001 }) {
            1.0
        } {
            f = freq.asFloat.max(0.001);
            center = center.asFloat.max(20.0);
            bw = bw.asFloat.abs.max(0.5);
            semis = 12.0 * ((f / center).log / 2.0.log);
            x = semis / bw;
            weight = 1.0 + (amount * ((-0.5 * x * x).exp));
            weight.clip(0.05, 4.0)
        }
    };

    at[\actualSpectrumDescriptorForVoice] = { |midi=60, profile=\production, ageSeconds=0.0, velocity=1.0, centsOffset=0.0, formantSpec=nil|
        var p, family, ev, ratios, amps, n, baseFreq, b, decay, idxDenom, parts, vel, age, conf;
        at[\actualSpectrumEnsureDefaults].();
        p = at[\actualSpectrumNormalizeProfile].(profile);
        family = at[\actualSpectrumFamilyForProfile].(p);
        ev = if(at[\perceptualProfileEvent].notNil) { at[\perceptualProfileEvent].(p) } { nil };
        ratios = if(ev.notNil) { ev[\partials] ? [1.0] } { [1.0] };
        amps = if(ev.notNil) { ev[\amps] ? [1.0] } { [1.0] };
        n = ratios.size.min(amps.size).max(1);
        baseFreq = at[\midiToFreq].(midi.asInteger) * (2 ** (centsOffset.asFloat / 1200.0));
        b = at[\actualSpectrumInharmonicityBForProfile].(p);
        decay = at[\actualSpectrumDecayParamsForProfile].(p);
        idxDenom = (n - 1).max(1).asFloat;
        parts = Array.new;
        vel = velocity.asFloat.clip(0.0, 1.5);
        age = ageSeconds.asFloat.max(0.0);
        n.do { |idx|
            var partialIndex, baseRatio, ratio, freq, baseAmp, pos, decayWeight, formantWeight, amp;
            partialIndex = idx + 1;
            baseRatio = ratios[idx].asFloat.max(0.0001);
            ratio = baseRatio;
            if((family == \pianoStiffString) or: { family == \electricPianoTine }) {
                // Stiff-string inharmonicity: modal frequencies remain stretched.
                // What changes over note age is mostly amplitude weighting, not frequency location.
                ratio = partialIndex.asFloat * ((1.0 + (b * (partialIndex * partialIndex))).sqrt);
            };
            freq = baseFreq * ratio;
            baseAmp = amps[idx].asFloat.max(0.0) * vel;
            pos = idx.asFloat / idxDenom;
            decayWeight = (-1.0 * age * ((decay[\base] ? 0.0) + ((decay[\high] ? 0.0) * pos.squared))).exp;
            formantWeight = at[\actualSpectrumFormantWeight].(freq, formantSpec);
            amp = (baseAmp * decayWeight * formantWeight).max(0.0);
            if((freq > 15.0) and: { freq < 20000.0 } and: { amp > 0.000001 }) {
                parts = parts.add((
                    index: partialIndex,
                    ratio: ratio,
                    freq: freq,
                    amp: amp,
                    baseAmp: baseAmp,
                    decayWeight: decayWeight,
                    formantWeight: formantWeight,
                    profile: p,
                    family: family
                ));
            };
        };
        conf = if(at[\perceptualProfileConfidence].notNil) { at[\perceptualProfileConfidence].(p) } { 0.70 };
        (
            midi: midi.asInteger,
            fundamentalFreq: baseFreq,
            centsOffset: centsOffset.asFloat,
            tonePreset: p,
            spectralProfile: p,
            spectralFamily: family,
            ageSeconds: age,
            velocity: vel,
            inharmonicityB: b,
            formantEnabled: if(formantSpec.notNil and: { formantSpec[\enabled].notNil }) { formantSpec[\enabled].asBoolean } { (cfg[\solver][\actualSpectrumFormantEnabled] ? false).asBoolean },
            formantAmount: if(formantSpec.notNil and: { formantSpec[\amount].notNil }) { formantSpec[\amount].asFloat } { (cfg[\solver][\actualSpectrumFormantAmount] ? 0.0).asFloat },
            partialCount: parts.size,
            partials: parts,
            confidence: conf,
            role: \actualSpectrumDescriptorOnlyNoTuningWrites
        )
    };

    at[\actualSpectrumPartialsForSpec] = { |spec, ageSeconds=0.0, formantSpec=nil|
        var midi, profile, weight, freq, desc, scale;
        if(spec.isNil) {
            Array.new
        } {
            midi = spec[\midi] ? spec[\targetMidi];
            freq = spec[\freq] ? 0.0;
            if(midi.isNil) {
                midi = if(freq > 0.0) { (69.0 + (12.0 * ((freq.asFloat / 440.0).log / 2.0.log))).round.asInteger } { 60 };
            };
            profile = spec[\profile] ? \production;
            weight = (spec[\weight] ? 1.0).asFloat.max(0.0);
            desc = at[\actualSpectrumDescriptorForVoice].(midi, profile, ageSeconds, 1.0, spec[\offsetCents] ? 0.0, formantSpec);
            scale = if(desc[\fundamentalFreq].notNil and: { freq > 0.0 }) { freq.asFloat / desc[\fundamentalFreq].asFloat.max(0.001) } { 1.0 };
            desc[\partials].collect { |part| (freq: part[\freq] * scale, amp: part[\amp] * weight, ratio: part[\ratio], profile: profile, actualSpectrum: true) }
        }
    };

    at[\actualSpectrumRoughnessForDescriptors] = { |descriptors=nil|
        var specs, total, n;
        specs = descriptors ? Array.new;
        total = 0.0;
        n = specs.size;
        n.do { |i|
            var a;
            a = specs[i][\partials] ? Array.new;
            n.do { |j|
                var b;
                if(j > i) {
                    b = specs[j][\partials] ? Array.new;
                    a.do { |pa|
                        b.do { |pb|
                            total = total + at[\perceptualRoughnessPair].(pa[\freq], pa[\amp], pb[\freq], pb[\amp]);
                        };
                    };
                };
            };
        };
        total
    };

    at[\actualSpectrumDescriptorsForVoicing] = { |midis=nil, offsets=nil, profile=\production, ageSeconds=0.0, velocity=1.0, formantSpec=nil|
        var arr, offs, out;
        arr = midis ? [60, 64, 67];
        offs = offsets ? Array.fill(arr.size, 0.0);
        out = Array.new;
        arr.do { |m, idx|
            out = out.add(at[\actualSpectrumDescriptorForVoice].(m, profile, ageSeconds, velocity, offs[idx] ? 0.0, formantSpec));
        };
        out
    };

    at[\actualSpectrumRoughnessForVoicing] = { |midis=nil, offsets=nil, profile=\production, ageSeconds=0.0, formantSpec=nil|
        at[\actualSpectrumRoughnessForDescriptors].(at[\actualSpectrumDescriptorsForVoicing].(midis, offsets, profile, ageSeconds, 1.0, formantSpec))
    };

    at[\actualSpectrumCandidateOffsets] = {
        var limit, step, arr, x;
        at[\actualSpectrumEnsureDefaults].();
        limit = (cfg[\solver][\actualSpectrumCandidateLimitCents] ? 16.0).asFloat.abs.max(1.0);
        step = (cfg[\solver][\actualSpectrumCandidateStepCents] ? 4.0).asFloat.abs.max(1.0);
        arr = Array.new;
        x = limit.neg;
        while { x <= limit } {
            arr = arr.add(x.round(0.0001));
            x = x + step;
        };
        if(arr.includes(0.0).not) { arr = arr.add(0.0).sort; };
        arr
    };

    at[\actualSpectrumScanVoicing] = { |midis=nil, profile=\production, ageSeconds=0.0, formantSpec=nil|
        var arr, candidates, n, etOffsets, etR, bestOffsets, bestR, offsets, r;
        arr = midis ? [60, 64, 67];
        candidates = at[\actualSpectrumCandidateOffsets].();
        n = arr.size.min(3).max(1);
        arr = arr.copyRange(0, n - 1);
        etOffsets = Array.fill(n, 0.0);
        etR = at[\actualSpectrumRoughnessForVoicing].(arr, etOffsets, profile, ageSeconds, formantSpec);
        bestOffsets = etOffsets.copy;
        bestR = etR;
        if(n == 2) {
            candidates.do { |a|
                candidates.do { |b|
                    offsets = [a.asFloat, b.asFloat];
                    r = at[\actualSpectrumRoughnessForVoicing].(arr, offsets, profile, ageSeconds, formantSpec);
                    if(r < bestR) { bestR = r; bestOffsets = offsets.copy; };
                };
            };
        };
        if(n >= 3) {
            candidates.do { |a|
                candidates.do { |b|
                    candidates.do { |c|
                        offsets = [a.asFloat, b.asFloat, c.asFloat];
                        r = at[\actualSpectrumRoughnessForVoicing].(arr, offsets, profile, ageSeconds, formantSpec);
                        if(r < bestR) { bestR = r; bestOffsets = offsets.copy; };
                    };
                };
            };
        };
        (
            midis: arr,
            profile: at[\actualSpectrumNormalizeProfile].(profile),
            ageSeconds: ageSeconds.asFloat.max(0.0),
            etOffsetsCents: etOffsets,
            roughnessET: etR,
            bestOffsetsCents: bestOffsets,
            bestRoughness: bestR,
            roughnessImprovement: (etR - bestR).max(0.0),
            role: \actualSpectrumScanDiagnosticOnlyNoTuningWrites
        )
    };

    at[\actualSpectrumPipelineDiagnostic] = { |profile=\piano|
        var attackAge, tailAge, p, pianoAttack, pianoTail, formantOff, formantOn, attackScan, tailScan, bellOct, summary, upperAttack, upperTail, freqsSame, formantFreqsSame, formantAmpsChanged;
        at[\actualSpectrumEnsureDefaults].();
        p = at[\actualSpectrumNormalizeProfile].(profile);
        attackAge = cfg[\solver][\actualSpectrumAttackAgeSeconds] ? 0.03;
        tailAge = cfg[\solver][\actualSpectrumTailAgeSeconds] ? 1.80;
        pianoAttack = at[\actualSpectrumDescriptorForVoice].(60, \piano, attackAge, 1.0, 0.0, (enabled: false, amount: 0.0));
        pianoTail = at[\actualSpectrumDescriptorForVoice].(60, \piano, tailAge, 1.0, 0.0, (enabled: false, amount: 0.0));
        upperAttack = if(pianoAttack[\partials].size > 5) { pianoAttack[\partials][5][\amp] } { pianoAttack[\partials].last[\amp] };
        upperTail = if(pianoTail[\partials].size > 5) { pianoTail[\partials][5][\amp] } { pianoTail[\partials].last[\amp] };
        freqsSame = (pianoAttack[\partials][1][\freq] - pianoTail[\partials][1][\freq]).abs < 0.0001;
        formantOff = at[\actualSpectrumDescriptorForVoice].(60, \organ, 0.0, 1.0, 0.0, (enabled: false, amount: 0.0, centerHz: 1000.0, bandwidthSemitones: 6.0));
        formantOn = at[\actualSpectrumDescriptorForVoice].(60, \organ, 0.0, 1.0, 0.0, (enabled: true, amount: 1.0, centerHz: 1000.0, bandwidthSemitones: 6.0));
        formantFreqsSame = (formantOff[\partials][3][\freq] - formantOn[\partials][3][\freq]).abs < 0.0001;
        formantAmpsChanged = (formantOff[\partials][3][\amp] - formantOn[\partials][3][\amp]).abs > 0.0001;
        attackScan = at[\actualSpectrumScanVoicing].([48, 64, 79], p, attackAge, nil);
        tailScan = at[\actualSpectrumScanVoicing].([48, 64, 79], p, tailAge, nil);
        bellOct = if(at[\cylinderOctaveEquivalenceReport].notNil) { at[\cylinderOctaveEquivalenceReport].(60, \bellInharmonic) } { nil };
        summary = (
            profile: p,
            role: \actualSpectrumPipelineDiagnosticOnlyNoTuningWrites,
            pianoInharmonicFrequenciesStableOverAge: freqsSame,
            pianoUpperPartialAmpAttack: upperAttack,
            pianoUpperPartialAmpTail: upperTail,
            pianoUpperPartialAmpDecays: upperTail < upperAttack,
            formantChangesFrequencies: formantFreqsSame.not,
            formantChangesAmplitudes: formantAmpsChanged,
            formantMechanism: \amplitudeEnvelopeOnly,
            attackScan: attackScan,
            tailScan: tailScan,
            bellOctaveReport: bellOct,
            writesCoreTuning: false,
            noSolverHook: true
        );
        st[\lastActualSpectrumPipelineReport] = summary;
        summary
    };



    // Diagnostic bridge from actual-spectrum material into cylinder-style reporting.
    // Still no solver hook and no render authority: this only reports what the actual
    // time-varying partial material would imply for wide-register/cylinder decisions.
    at[\actualSpectrumCylinderBridgeReport] = { |profile=\piano, midis=nil, formantSpec=nil|
        var arr, p, attackAge, tailAge, attackScan, tailScan, formantScan, attackDescs, tailDescs, upperAttack, upperTail, improvementDelta, role;
        at[\actualSpectrumEnsureDefaults].();
        arr = midis ? [48, 64, 79];
        p = at[\actualSpectrumNormalizeProfile].(profile);
        attackAge = cfg[\solver][\actualSpectrumAttackAgeSeconds] ? 0.03;
        tailAge = cfg[\solver][\actualSpectrumTailAgeSeconds] ? 1.80;
        attackScan = at[\actualSpectrumScanVoicing].(arr, p, attackAge, formantSpec);
        tailScan = at[\actualSpectrumScanVoicing].(arr, p, tailAge, formantSpec);
        formantScan = at[\actualSpectrumScanVoicing].(arr, p, attackAge, (enabled: true, amount: 1.0, centerHz: 1000.0, bandwidthSemitones: 6.0));
        attackDescs = at[\actualSpectrumDescriptorsForVoicing].(arr, nil, p, attackAge, 1.0, formantSpec);
        tailDescs = at[\actualSpectrumDescriptorsForVoicing].(arr, nil, p, tailAge, 1.0, formantSpec);
        upperAttack = if(attackDescs.size > 0 and: { attackDescs[0][\partials].size > 0 }) { attackDescs[0][\partials].last[\amp] } { 0.0 };
        upperTail = if(tailDescs.size > 0 and: { tailDescs[0][\partials].size > 0 }) { tailDescs[0][\partials].last[\amp] } { 0.0 };
        improvementDelta = (attackScan[\roughnessImprovement] ? 0.0).asFloat - (tailScan[\roughnessImprovement] ? 0.0).asFloat;
        role = \actualSpectrumCylinderBridgeDiagnosticOnlyNoTuningWrites;
        (
            role: role,
            profile: p,
            midis: arr,
            attackAgeSeconds: attackAge,
            tailAgeSeconds: tailAge,
            attackScan: attackScan,
            tailScan: tailScan,
            formantScan: formantScan,
            upperPartialAmpAttack: upperAttack,
            upperPartialAmpTail: upperTail,
            upperPartialAmpDecays: upperTail < upperAttack,
            roughnessImprovementAttackMinusTail: improvementDelta,
            timeVaryingSpectrum: true,
            formantMechanism: \amplitudeEnvelopeOnly,
            writesCoreTuning: false,
            wouldChangeCoreTuningNow: false,
            noSolverHook: true,
            note: \actualSpectrumFeedsCylinderDiagnosticsOnlyNotRenderOrSolver
        )
    };




    // v15 bridge: convert actual-spectrum scan results into a bounded render-preview report.
    // This still does not apply render offsets and never writes core tuning state. It is the
    // safe bridge between actual partial material and the existing render-only audition idea.
    at[\actualSpectrumCylinderRenderPreview] = { |profile=\piano, midis=nil, amount=0.5, ageSeconds=nil, formantSpec=nil|
        var arr, p, age, amt, scan, best, mean, n, improvement, confidence, scale, maxCents;
        var offsets, offsetsByMidi, maxAbs, role;
        at[\actualSpectrumEnsureDefaults].();
        arr = midis ? [48, 64, 79];
        p = at[\actualSpectrumNormalizeProfile].(profile);
        age = ageSeconds ? (cfg[\solver][\actualSpectrumAttackAgeSeconds] ? 0.03);
        amt = amount.asFloat.clip(0.0, 1.0);
        scan = at[\actualSpectrumScanVoicing].(arr, p, age, formantSpec);
        best = scan[\bestOffsetsCents] ? Array.fill(arr.size, 0.0);
        n = best.size.max(1);
        mean = 0.0;
        best.do { |v| mean = mean + v.asFloat; };
        mean = mean / n.asFloat;
        improvement = (scan[\roughnessImprovement] ? 0.0).asFloat.max(0.0);
        // Confidence is deliberately conservative: a raw roughness optimum must earn authority.
        // 0.03 roughness improvement is treated as strong for this diagnostic scale.
        confidence = (improvement / 0.03).clip(0.0, 1.0);
        scale = amt * confidence;
        maxCents = 2.0;
        offsets = Array.new;
        offsetsByMidi = IdentityDictionary.new;
        maxAbs = 0.0;
        arr.do { |m, idx|
            var off;
            off = (((best[idx] ? 0.0).asFloat - mean) * scale).clip(maxCents.neg, maxCents);
            off = off.round(0.000001);
            offsets = offsets.add(off);
            offsetsByMidi[m] = off;
            maxAbs = maxAbs.max(off.abs);
        };
        role = \actualSpectrumCylinderRenderPreviewOnlyNoWrites;
        (
            role: role,
            profile: p,
            midis: arr,
            ageSeconds: age.asFloat,
            amount: amt,
            sourceScan: scan,
            rawBestOffsetsCents: best,
            rawGaugeMeanCents: mean,
            actualSpectrumConfidence: confidence,
            confidenceScaledAmount: scale,
            maxAppliedCents: maxCents,
            voiceOffsetsCents: offsets,
            voiceOffsetsByMidi: offsetsByMidi,
            wouldChangeRenderPitchNow: maxAbs > 0.0001,
            wouldChangeCoreTuningNow: false,
            writesRenderNow: false,
            writesCoreTuning: false,
            noSolverHook: true,
            warning: "actual-spectrum cylinder render preview only; no synths or core tuning state are written"
        )
    };

    at[\actualSpectrumCylinderRenderBridgeReport] = { |profile=\piano, midis=nil, amount=0.5, formantSpec=nil|
        var arr, p, attackAge, tailAge, attackPreview, tailPreview, formantPreview, attackMax, tailMax;
        at[\actualSpectrumEnsureDefaults].();
        arr = midis ? [48, 64, 79];
        p = at[\actualSpectrumNormalizeProfile].(profile);
        attackAge = cfg[\solver][\actualSpectrumAttackAgeSeconds] ? 0.03;
        tailAge = cfg[\solver][\actualSpectrumTailAgeSeconds] ? 1.80;
        attackPreview = at[\actualSpectrumCylinderRenderPreview].(p, arr, amount, attackAge, formantSpec);
        tailPreview = at[\actualSpectrumCylinderRenderPreview].(p, arr, amount, tailAge, formantSpec);
        formantPreview = at[\actualSpectrumCylinderRenderPreview].(p, arr, amount, attackAge, (enabled: true, amount: 1.0, centerHz: 1000.0, bandwidthSemitones: 6.0));
        attackMax = 0.0; tailMax = 0.0;
        attackPreview[\voiceOffsetsCents].do { |v| attackMax = attackMax.max(v.asFloat.abs); };
        tailPreview[\voiceOffsetsCents].do { |v| tailMax = tailMax.max(v.asFloat.abs); };
        (
            role: \actualSpectrumCylinderRenderBridgePreviewOnlyNoWrites,
            profile: p,
            midis: arr,
            amount: amount.asFloat.clip(0.0, 1.0),
            attackPreview: attackPreview,
            tailPreview: tailPreview,
            formantPreview: formantPreview,
            attackMaxAbsOffsetCents: attackMax,
            tailMaxAbsOffsetCents: tailMax,
            attackRenderPreviewNotWeakerThanTail: attackMax >= (tailMax - 0.0001),
            formantMechanism: \amplitudeEnvelopeOnly,
            writesRenderNow: false,
            writesCoreTuning: false,
            wouldChangeCoreTuningNow: false,
            noSolverHook: true,
            note: \actualSpectrumCanPreviewRenderOffsetsButDoesNotApplyThem
        )
    };


    // v16 audition bridge: apply the actual-spectrum render preview to currently active synth voices only.
    // This is still explicitly outside the solver and never writes nodePhase/trueGauge/nodeShape/targetNodeShape.
    // It exists so the actual partial-material bridge can be tested audibly without installing automatic authority.
    at[\clearActualSpectrumRenderPreviewFromVoices] = {
        st[\lastActualSpectrumRenderApplyReport] = (
            role: \actualSpectrumRenderPreviewCleared,
            voiceOffsetsByMidi: IdentityDictionary.new,
            writesRenderNow: true,
            writesCoreTuning: false,
            wouldChangeCoreTuningNow: false,
            noSolverHook: true,
            warning: "actual-spectrum render preview cleared from synth voiceOffsetCents; core tuning unchanged"
        );
        if(st[\voices].notNil) {
            st[\voices].keysValuesDo { |midi, synth| synth.set(\voiceOffsetCents, 0.0); };
        };
        st[\lastActualSpectrumRenderApplyReport]
    };

    at[\applyActualSpectrumRenderPreviewToVoices] = { |profile=\piano, amount=0.5, scale=1.0, ageSeconds=nil, formantSpec=nil|
        var midis, p, amt, sc, preview, baseOffsets, scaledOffsets, maxCents, maxAbs, applied;
        at[\actualSpectrumEnsureDefaults].();
        midis = if(at[\activeMidisSorted].notNil) { at[\activeMidisSorted].() } { Array.new };
        p = at[\actualSpectrumNormalizeProfile].(profile ? (st[\tonePreset] ? \production));
        amt = amount.asFloat.clip(0.0, 1.0);
        sc = scale.asFloat.clip(0.0, 24.0);
        maxCents = cfg[\solver][\actualSpectrumRenderAuditionMaxCents] ? 24.0;
        maxCents = maxCents.asFloat.abs.max(0.001);
        preview = at[\actualSpectrumCylinderRenderPreview].(p, midis, amt, ageSeconds, formantSpec);
        baseOffsets = preview[\voiceOffsetsByMidi] ? IdentityDictionary.new;
        scaledOffsets = IdentityDictionary.new;
        maxAbs = 0.0;
        midis.do { |m|
            var off;
            off = ((baseOffsets[m] ? 0.0).asFloat * sc).clip(maxCents.neg, maxCents);
            off = off.round(0.000001);
            scaledOffsets[m] = off;
            maxAbs = maxAbs.max(off.abs);
            if(st[\voices].notNil and: { st[\voices][m].notNil }) {
                st[\voices][m].set(\voiceOffsetCents, off);
            };
        };
        applied = (
            role: \actualSpectrumRenderAuditionOnlyNoCoreWrites,
            profile: p,
            amount: amt,
            auditionScale: sc,
            auditionMaxCents: maxCents,
            sourceMidis: midis.copy,
            sourcePreview: preview,
            realVoiceOffsetsByMidi: baseOffsets,
            scaledVoiceOffsetsByMidi: scaledOffsets,
            writesRenderNow: true,
            writesCoreTuning: false,
            wouldChangeCoreTuningNow: false,
            wouldChangeRenderPitchNow: maxAbs > 0.0001,
            noSolverHook: true,
            requiresManualStretchInput: false,
            warning: "actual-spectrum render audition only; offsets come from partial-material preview and are written only to synth voiceOffsetCents"
        );
        st[\lastActualSpectrumRenderApplyReport] = applied;
        applied
    };

    api[\actualSpectrumCylinderBridgeReport] = { |profile=\piano|
        at[\actualSpectrumCylinderBridgeReport].(profile, [48, 64, 79], nil)
    };

    api[\actualSpectrumCylinderRenderPreview] = { |profile=\piano, amount=0.5|
        at[\actualSpectrumCylinderRenderPreview].(profile, [48, 64, 79], amount, nil, nil)
    };

    api[\actualSpectrumCylinderRenderBridgeReport] = { |profile=\piano, amount=0.5|
        at[\actualSpectrumCylinderRenderBridgeReport].(profile, [48, 64, 79], amount, nil)
    };

    api[\applyActualSpectrumCylinderRenderPreview] = { |profile=\piano, amount=0.5, scale=1.0|
        at[\applyActualSpectrumRenderPreviewToVoices].(profile, amount, scale, nil, nil)
    };

    api[\clearActualSpectrumCylinderRenderPreview] = {
        at[\clearActualSpectrumRenderPreviewFromVoices].()
    };
    api[\actualSpectrumDescriptor] = { |midi=60, profile=\production, ageSeconds=0.0, velocity=1.0|
        at[\actualSpectrumDescriptorForVoice].(midi, profile, ageSeconds, velocity, 0.0, nil)
    };

    api[\actualSpectrumPipelineDiagnostic] = { |profile=\piano|
        at[\actualSpectrumPipelineDiagnostic].(profile)
    };

    api[\setActualSpectrumFormant] = { |enabled=false, amount=0.0, centerHz=1200.0, bandwidthSemitones=7.0|
        at[\actualSpectrumEnsureDefaults].();
        cfg[\solver][\actualSpectrumFormantEnabled] = enabled.asBoolean;
        cfg[\solver][\actualSpectrumFormantAmount] = amount.asFloat.clip(0.0, 3.0);
        cfg[\solver][\actualSpectrumFormantCenterHz] = centerHz.asFloat.max(20.0);
        cfg[\solver][\actualSpectrumFormantBandwidthSemitones] = bandwidthSemitones.asFloat.abs.max(0.5);
        (
            enabled: cfg[\solver][\actualSpectrumFormantEnabled],
            amount: cfg[\solver][\actualSpectrumFormantAmount],
            centerHz: cfg[\solver][\actualSpectrumFormantCenterHz],
            bandwidthSemitones: cfg[\solver][\actualSpectrumFormantBandwidthSemitones]
        )
    };

    at[\actualSpectrumEnsureDefaults].();
    "[at-actual-spectrum] diagnostic actual-spectrum material pipeline loaded; diagnostic only/no tuning writes.".postln;
};
)
