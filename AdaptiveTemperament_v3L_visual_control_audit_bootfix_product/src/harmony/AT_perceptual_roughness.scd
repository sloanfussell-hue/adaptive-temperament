(
// AT_perceptual_roughness.scd
// Spectrum-aware Sethares/perceptual roughness pressure prototype.
// This is not a mode, does not replace the interval-law core, and never writes
// nodePhase directly. It adds optional pressure through the existing solver path.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at-perceptual] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    at[\perceptualEnsureDefaults] = {
        if(at[\perceptualEnsureSpectrumDefaults].notNil) { at[\perceptualEnsureSpectrumDefaults].(); };
        if(cfg[\solver][\perceptualPressureEnabled].isNil) { cfg[\solver][\perceptualPressureEnabled] = false; };
        if(cfg[\solver][\perceptualPressureAmount].isNil) { cfg[\solver][\perceptualPressureAmount] = 0.22; };
        if(cfg[\solver][\perceptualExternalWeight].isNil) { cfg[\solver][\perceptualExternalWeight] = 0.18; };
        if(cfg[\solver][\perceptualInternalWeight].isNil) { cfg[\solver][\perceptualInternalWeight] = 1.0; };
        if(cfg[\solver][\perceptualPartialNumbers].isNil) { cfg[\solver][\perceptualPartialNumbers] = [1, 2, 3, 4, 5, 6, 8]; };
        if(cfg[\solver][\perceptualPartialAmplitudes].isNil) { cfg[\solver][\perceptualPartialAmplitudes] = [1.0, 0.52, 0.34, 0.25, 0.20, 0.16, 0.11]; };
        if(cfg[\solver][\perceptualFiniteDiffCents].isNil) { cfg[\solver][\perceptualFiniteDiffCents] = 1.0; };
        if(cfg[\solver][\perceptualGradientGain].isNil) { cfg[\solver][\perceptualGradientGain] = 48.0; };
        if(cfg[\solver][\perceptualMaxForce].isNil) { cfg[\solver][\perceptualMaxForce] = 0.018; };
        if(cfg[\solver][\perceptualMaxSources].isNil) { cfg[\solver][\perceptualMaxSources] = 8; };
        if(cfg[\solver][\perceptualActiveOnly].isNil) { cfg[\solver][\perceptualActiveOnly] = true; };
        if(cfg[\solver][\perceptualConfidenceGatingEnabled].isNil) { cfg[\solver][\perceptualConfidenceGatingEnabled] = true; };
        if(cfg[\solver][\perceptualMinConfidence].isNil) { cfg[\solver][\perceptualMinConfidence] = 0.08; };
        if(cfg[\solver][\perceptualSlopeReference].isNil) { cfg[\solver][\perceptualSlopeReference] = 0.0012; };
        if(cfg[\solver][\perceptualRegularizationEnabled].isNil) { cfg[\solver][\perceptualRegularizationEnabled] = true; };
        if(cfg[\solver][\perceptualRegularizationAmount].isNil) { cfg[\solver][\perceptualRegularizationAmount] = 0.035; };
        if(cfg[\solver][\perceptualRegularizationReferenceCents].isNil) { cfg[\solver][\perceptualRegularizationReferenceCents] = 12.0; };
        if(cfg[\solver][\perceptualReportEnabled].isNil) { cfg[\solver][\perceptualReportEnabled] = true; };
        if(cfg[\solver][\perceptualExternalSceneDiagnostic].isNil) { cfg[\solver][\perceptualExternalSceneDiagnostic] = false; };
        true
    };

    at[\perceptualPcBaseMidi] = { |pc|
        var p;
        p = pc.asInteger % 12;
        if(p < 0) { p = p + 12; };
        60 + p
    };

    // Backward-compatible generic template used only if the spectrum-material
    // module has not been loaded.
    at[\perceptualTemplate] = {
        var nums, amps, n;
        at[\perceptualEnsureDefaults].();
        nums = cfg[\solver][\perceptualPartialNumbers] ? [1, 2, 3, 4, 5, 6, 8];
        amps = cfg[\solver][\perceptualPartialAmplitudes] ? [1.0, 0.52, 0.34, 0.25, 0.20, 0.16, 0.11];
        n = nums.size.min(amps.size);
        Array.fill(n, { |idx| (ratio: nums[idx].asFloat.max(0.0001), amp: amps[idx].asFloat.max(0.0)) })
    };

    at[\perceptualRoughnessPair] = { |freq1, amp1, freq2, amp2|
        var f1, f2, a1, a2, minFreq, diff, s, r;
        f1 = freq1.asFloat.max(0.001);
        f2 = freq2.asFloat.max(0.001);
        a1 = amp1.asFloat.max(0.0);
        a2 = amp2.asFloat.max(0.0);
        minFreq = f1.min(f2).max(20.0);
        diff = (f2 - f1).abs;
        s = 0.24 / ((0.021 * minFreq) + 19.0);
        r = a1 * a2 * (((-3.5 * s * diff).exp) - ((-5.75 * s * diff).exp));
        r.max(0.0)
    };

    at[\perceptualSpectrumForFreq] = { |freq, noteWeight=1.0, profile=nil|
        var spectrum, partials, base, weight;
        if(at[\perceptualSpectrumForFreqProfile].notNil) {
            at[\perceptualSpectrumForFreqProfile].(freq, noteWeight, profile ? \production)
        } {
            partials = at[\perceptualTemplate].();
            spectrum = Array.new;
            base = freq.asFloat.max(0.001);
            weight = noteWeight.asFloat.max(0.0);
            partials.do { |part|
                var partialFreq, partialAmp;
                partialFreq = base * (part[\ratio] ? 1.0);
                partialAmp = (part[\amp] ? 0.0) * weight;
                if((partialFreq > 15.0) and: { partialFreq < 20000.0 } and: { partialAmp > 0.000001 }) {
                    spectrum = spectrum.add((freq: partialFreq, amp: partialAmp));
                };
            };
            spectrum
        }
    };

    at[\perceptualRoughnessForSpecs] = { |specs|
        var total, n, spectra;
        specs = specs ? Array.new;
        total = 0.0;
        n = specs.size;

        // v5e: precompute each note/source spectrum once. The old version rebuilt
        // spectra inside every pair loop. That was mathematically correct but could
        // make bright profiles such as synth/pad look like a freeze during live
        // audition or active-note snapshots.
        spectra = Array.fill(n, { |idx|
            var spec;
            spec = specs[idx];
            if(at[\perceptualSpectrumForSpec].notNil) {
                at[\perceptualSpectrumForSpec].(spec)
            } {
                at[\perceptualSpectrumForFreq].(spec[\freq] ? 0.0, spec[\weight] ? 1.0, spec[\profile])
            }
        });

        n.do { |idxA|
            var spectrumA;
            spectrumA = spectra[idxA] ? Array.new;
            n.do { |idxB|
                var spectrumB;
                if(idxB > idxA) {
                    spectrumB = spectra[idxB] ? Array.new;
                    spectrumA.do { |partA|
                        spectrumB.do { |partB|
                            total = total + at[\perceptualRoughnessPair].(partA[\freq], partA[\amp], partB[\freq], partB[\amp]);
                        };
                    };
                };
            };
        };
        total
    };

    at[\perceptualInternalSpecs] = { |activePcs, pcWeights, offsetPc=nil, offsetCents=0.0, profileOverride=nil|
        var specs, notes, internalWeight, profile, pressureScale;
        at[\perceptualEnsureDefaults].();
        activePcs = activePcs ? Array.new;
        pcWeights = pcWeights ? Array.fill(cfg[\solver][\numNodes], 0.0);
        notes = if(at[\notesArray].notNil) { at[\notesArray].() } { Array.new };
        internalWeight = cfg[\solver][\perceptualInternalWeight] ? 1.0;
        profile = if(profileOverride.notNil) { profileOverride } { if(at[\perceptualInternalProfileSymbol].notNil) { at[\perceptualInternalProfileSymbol].() } { \production } };
        profile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(profile) } { profile.asSymbol };
        pressureScale = if(at[\perceptualPressureScaleForProfile].notNil) { at[\perceptualPressureScaleForProfile].(profile) } { 1.0 };
        specs = Array.new;
        activePcs.do { |pc|
            var pcNotes, note, midi, baseFreq, devCents, extraCents, freq, weight;
            pcNotes = notes.select { |n| (n[\pc] ? -1) == pc };
            note = if(pcNotes.isEmpty) { nil } { pcNotes.sort { |a, b| (a[\midi] ? 999) < (b[\midi] ? 999) }[0] };
            midi = if(note.notNil) { note[\midi] ? at[\perceptualPcBaseMidi].(pc) } { at[\perceptualPcBaseMidi].(pc) };
            baseFreq = if(note.notNil and: { note[\referenceFreq].notNil }) { note[\referenceFreq] } { at[\midiToFreq].(midi) };
            devCents = if(st[\nodePhase].notNil and: { st[\etPhase].notNil }) { at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0 } { 0.0 };
            extraCents = if(offsetPc.notNil and: { pc == offsetPc }) { offsetCents.asFloat } { 0.0 };
            freq = baseFreq * (2 ** ((devCents + extraCents) / 1200.0));
            weight = ((pcWeights[pc] ? 0.0).max(0.08) * internalWeight).clip(0.0, 2.0);
            specs = specs.add((pc: pc, freq: freq, weight: weight, kind: \internal, profile: profile, pressureScale: pressureScale, offsetCents: extraCents, devCents: devCents));
        };
        specs
    };

    at[\perceptualExternalSpecs] = { |externalSources, profileOverride=nil|
        var specs, maxSources, externalWeight, sources;
        at[\perceptualEnsureDefaults].();
        specs = Array.new;
        maxSources = (cfg[\solver][\perceptualMaxSources] ? 8).asInteger.max(0);
        externalWeight = (cfg[\solver][\perceptualExternalWeight] ? 0.18).clip(0.0, 4.0);
        sources = at[\takeStrongestSources].(externalSources ? Array.new, maxSources);
        sources.do { |src|
            var freq, pc, midi, phase, trust, roleScale, weight, profile, pressureScale;
            pc = src[\pc];
            if(pc.notNil) {
                freq = src[\freq] ? 0.0;
                if(freq <= 15.0) {
                    midi = src[\targetMidi] ? at[\perceptualPcBaseMidi].(pc);
                    freq = at[\midiToFreq].(midi);
                    phase = src[\phase];
                    if(phase.notNil) {
                        freq = freq * (2 ** ((at[\wrapSigned].(phase - (pc / 12.0)) * 1200.0) / 1200.0));
                    };
                };
                profile = if(profileOverride.notNil) { profileOverride } { if(at[\perceptualExternalProfileSymbol].notNil) { at[\perceptualExternalProfileSymbol].(src) } { \micObserved } };
                profile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(profile) } { profile.asSymbol };
                pressureScale = if(at[\perceptualPressureScaleForProfile].notNil) { at[\perceptualPressureScaleForProfile].(profile) } { 1.0 };
                trust = if(at[\externalEvidenceTrustScale].notNil) { at[\externalEvidenceTrustScale].(src) } { src[\confidence] ? 1.0 };
                roleScale = if(at[\externalRoleRelationalScale].notNil) { at[\externalRoleRelationalScale].(src, Array.new) } { 1.0 };
                weight = ((src[\weight] ? 0.0).clip(0.0, 1.5) * (src[\confidence] ? 1.0).clip(0.0, 1.0) * trust.clip(0.0, 1.5) * roleScale.clip(0.0, 1.5) * externalWeight).clip(0.0, 2.5);
                if(weight > 0.000001) {
                    specs = specs.add((pc: pc, freq: freq, weight: weight, kind: src[\kind] ? \external, profile: profile, pressureScale: pressureScale, sourceRole: src[\sourceRole] ? \external));
                };
            };
        };
        specs
    };

    at[\perceptualSpecsForField] = { |activePcs, pcWeights, externalSources=nil, offsetPc=nil, offsetCents=0.0, internalProfile=nil, externalProfile=nil|
        at[\perceptualInternalSpecs].(activePcs, pcWeights, offsetPc, offsetCents, internalProfile) ++ at[\perceptualExternalSpecs].(externalSources ? Array.new, externalProfile)
    };

    at[\perceptualExternalSceneRoughness] = { |externalSources=nil, externalProfile=nil|
        at[\perceptualRoughnessForSpecs].(at[\perceptualExternalSpecs].(externalSources ? Array.new, externalProfile))
    };


    at[\perceptualSlopeConfidence] = { |slope=0.0, profile=\production|
        var profileConf, slopeRef, slopeConf, minConf, conf;
        profileConf = if(at[\perceptualProfileConfidence].notNil) { at[\perceptualProfileConfidence].(profile) } { 0.70 };
        slopeRef = (cfg[\solver][\perceptualSlopeReference] ? 0.0012).asFloat.max(0.00001);
        minConf = (cfg[\solver][\perceptualMinConfidence] ? 0.08).asFloat.clip(0.0, 0.6);
        slopeConf = (slope.asFloat.abs / slopeRef).clip(0.0, 1.0);
        conf = profileConf * (minConf + ((1.0 - minConf) * slopeConf));
        conf.clip(0.0, 1.10)
    };

    at[\perceptualRegularizationPenaltyForOffsets] = { |offsets, profile=\production, externalWeight=0.0|
        var enabled, confidence, restraint, regAmount, refCents, sumSq, count, rms, penalty;
        at[\perceptualEnsureDefaults].();
        enabled = (cfg[\solver][\perceptualRegularizationEnabled] ? true).asBoolean;
        if(enabled.not) {
            0.0
        } {
            confidence = if(at[\perceptualProfileConfidence].notNil) { at[\perceptualProfileConfidence].(profile) } { 0.70 };
            restraint = (1.0 - confidence).clip(0.0, 1.0);
            regAmount = (cfg[\solver][\perceptualRegularizationAmount] ? 0.035).asFloat.max(0.0);
            refCents = (cfg[\solver][\perceptualRegularizationReferenceCents] ? 12.0).asFloat.max(0.5);
            sumSq = 0.0;
            count = 0.0;
            (offsets ? Array.new).do { |off|
                sumSq = sumSq + (off.asFloat * off.asFloat);
                count = count + 1.0;
            };
            rms = if(count > 0.0) { (sumSq / count).sqrt } { 0.0 };
            penalty = regAmount * restraint * ((rms / refCents) * (rms / refCents));
            penalty.max(0.0)
        }
    };

    at[\perceptualPressureForActiveField] = { |activePcs, pcWeights, externalSources=nil|
        var forces, enabled, amount, epsCents, gain, maxForce, pressureCentsByPc, roughNow, roughExternal, externalCount, internalProfile, externalProfile, pressureScaleByPc, confidenceByPc, slopeByPc, localMaxForceByPc, t0, elapsed;
        at[\perceptualEnsureDefaults].();
        t0 = Main.elapsedTime;
        forces = Array.fill(cfg[\solver][\numNodes], 0.0);
        activePcs = activePcs ? Array.new;
        pcWeights = pcWeights ? Array.fill(cfg[\solver][\numNodes], 0.0);
        externalSources = externalSources ? Array.new;
        enabled = cfg[\solver][\perceptualPressureEnabled] ? false;
        amount = (cfg[\solver][\perceptualPressureAmount] ? 0.0).clip(0.0, 1.5);
        epsCents = (cfg[\solver][\perceptualFiniteDiffCents] ? 1.0).max(0.05);
        gain = cfg[\solver][\perceptualGradientGain] ? 48.0;
        maxForce = (cfg[\solver][\perceptualMaxForce] ? 0.018).abs;
        pressureCentsByPc = Array.fill(cfg[\solver][\numNodes], 0.0);
        pressureScaleByPc = Array.fill(cfg[\solver][\numNodes], 0.0);
        confidenceByPc = Array.fill(cfg[\solver][\numNodes], 0.0);
        slopeByPc = Array.fill(cfg[\solver][\numNodes], 0.0);
        localMaxForceByPc = Array.fill(cfg[\solver][\numNodes], 0.0);
        roughNow = nil;
        roughExternal = nil;
        externalCount = externalSources.size;
        internalProfile = if(at[\perceptualInternalProfileSymbol].notNil) { at[\perceptualInternalProfileSymbol].() } { \production };
        externalProfile = cfg[\solver][\perceptualExternalProfile] ? \micObserved;

        if(enabled.asBoolean and: { amount > 0.000001 } and: { activePcs.notEmpty }) {
            roughNow = at[\perceptualRoughnessForSpecs].(at[\perceptualSpecsForField].(activePcs, pcWeights, externalSources, nil, 0.0, internalProfile, nil));
            if((cfg[\solver][\perceptualExternalSceneDiagnostic] ? true).asBoolean and: { externalSources.notEmpty }) {
                roughExternal = at[\perceptualExternalSceneRoughness].(externalSources, nil);
            };
            activePcs.do { |pc|
                var roughPlus, roughMinus, slope, pressureCentsRaw, pressureCents, force, pScale, confidence, localMax;
                roughPlus = at[\perceptualRoughnessForSpecs].(at[\perceptualSpecsForField].(activePcs, pcWeights, externalSources, pc, epsCents, internalProfile, nil));
                roughMinus = at[\perceptualRoughnessForSpecs].(at[\perceptualSpecsForField].(activePcs, pcWeights, externalSources, pc, epsCents.neg, internalProfile, nil));
                slope = (roughPlus - roughMinus) / (2.0 * epsCents);
                pScale = if(at[\perceptualPressureScaleForProfile].notNil) { at[\perceptualPressureScaleForProfile].(internalProfile) } { 1.0 };
                confidence = if((cfg[\solver][\perceptualConfidenceGatingEnabled] ? true).asBoolean) {
                    if(at[\perceptualSlopeConfidence].notNil) { at[\perceptualSlopeConfidence].(slope, internalProfile) } { pScale.clip(0.05, 1.0) }
                } {
                    1.0
                };
                pressureCentsRaw = slope.neg * gain * amount * pScale;
                pressureCents = pressureCentsRaw * confidence;
                localMax = (maxForce * confidence.clip(0.12, 1.0)).max(maxForce * 0.08);
                force = (pressureCents / 1200.0).clip(localMax.neg, localMax);
                forces[pc] = force;
                pressureCentsByPc[pc] = pressureCents;
                pressureScaleByPc[pc] = pScale;
                confidenceByPc[pc] = confidence;
                slopeByPc[pc] = slope;
                localMaxForceByPc[pc] = localMax;
            };
        };

        elapsed = Main.elapsedTime - t0;
        st[\lastPerceptualRoughnessReport] = (
            timestamp: Main.elapsedTime,
            elapsedSeconds: elapsed,
            enabled: enabled.asBoolean,
            amount: amount,
            externalWeight: cfg[\solver][\perceptualExternalWeight] ? 0.18,
            activePcs: activePcs.copy,
            externalCount: externalCount,
            internalProfile: internalProfile,
            externalProfile: externalProfile,
            followToneProfile: cfg[\solver][\perceptualFollowToneProfile] ? true,
            followToneSurface: cfg[\solver][\perceptualFollowToneSurface] ? false,
            confidenceGatingEnabled: cfg[\solver][\perceptualConfidenceGatingEnabled] ? true,
            regularizationEnabled: cfg[\solver][\perceptualRegularizationEnabled] ? true,
            roughness: roughNow,
            externalSceneRoughness: roughExternal,
            pressureCentsByPc: pressureCentsByPc.copy,
            pressureScaleByPc: pressureScaleByPc.copy,
            confidenceByPc: confidenceByPc.copy,
            slopeByPc: slopeByPc.copy,
            localMaxForceByPc: localMaxForceByPc.copy,
            forceByPc: forces.copy,
            mode: \notAMode,
            writesNodePhase: false
        );

        forces
    };

    at[\perceptualTriadSpecs] = { |pcs, midis, offsets, internalWeight=1.0, externalWeight=0.0, internalProfile=\production, externalProfile=\externalEt|
        var specs, iProfile, eProfile, iScale, eScale;
        specs = Array.new;
        iProfile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(internalProfile) } { internalProfile.asSymbol };
        eProfile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(externalProfile) } { externalProfile.asSymbol };
        iScale = if(at[\perceptualPressureScaleForProfile].notNil) { at[\perceptualPressureScaleForProfile].(iProfile) } { 1.0 };
        eScale = if(at[\perceptualPressureScaleForProfile].notNil) { at[\perceptualPressureScaleForProfile].(eProfile) } { 1.0 };
        pcs.do { |pc, idx|
            var midi, off, freq;
            midi = midis[idx] ? at[\perceptualPcBaseMidi].(pc);
            off = offsets[idx] ? 0.0;
            freq = at[\midiToFreq].(midi) * (2 ** (off / 1200.0));
            specs = specs.add((pc: pc, freq: freq, weight: internalWeight, kind: \internalDiagnostic, profile: iProfile, pressureScale: iScale, offsetCents: off));
        };
        if(externalWeight.asFloat > 0.000001) {
            pcs.do { |pc, idx|
                var midi, freq;
                midi = midis[idx] ? at[\perceptualPcBaseMidi].(pc);
                freq = at[\midiToFreq].(midi);
                specs = specs.add((pc: pc, freq: freq, weight: externalWeight, kind: \externalEtDiagnostic, profile: eProfile, pressureScale: eScale, offsetCents: 0.0));
            };
        };
        specs
    };

    at[\perceptualDiagnosticCacheKey] = { |name=\Cmajor, externalWeight=0.0, internalProfile=\production, externalProfile=\externalEt|
        var regEnabled, regAmount, confEnabled;
        regEnabled = (cfg[\solver][\perceptualRegularizationEnabled] ? true).asBoolean;
        regAmount = (cfg[\solver][\perceptualRegularizationAmount] ? 0.035).asFloat.round(0.0001);
        confEnabled = (cfg[\solver][\perceptualConfidenceGatingEnabled] ? true).asBoolean;
        name.asString ++ "|" ++ externalWeight.asFloat.round(0.0001).asString
            ++ "|" ++ internalProfile.asString ++ "|" ++ externalProfile.asString
            ++ "|reg=" ++ regEnabled.asString ++ "|amt=" ++ regAmount.asString
            ++ "|conf=" ++ confEnabled.asString
    };

    at[\perceptualClearDiagnosticCache] = {
        st[\perceptualTriadScanCache] = IdentityDictionary.new;
        true
    };

    at[\perceptualScanTriad] = { |name=\Cmajor, externalWeight=0.0, internalProfile=nil, externalProfile=\externalEt|
        var pcs, midis, etOffsets, jiOffsets, rawBest, rawBestR, regBest, regBestR, regBestObj, eMin, eMax, gMin, gMax, eOff, gOff, r, score, offsets, iProfile, eProfile, roughET, roughJI, confidence, rawPenalty, regPenalty, etPenalty, jiPenalty;
        var cache, cacheKey, cached, result;
        // Diagnostic scanner. C major is the acceptance probe; it does not hard-code
        // runtime behavior and is never used by the solver. v5c caches diagnostic
        // scans so repeated keeper probes do not take minutes. Live pressure is not
        // cached here and is not behaviorally changed by this optimization.
        pcs = [0, 4, 7];
        midis = [60, 64, 67];
        etOffsets = [0.0, 0.0, 0.0];
        jiOffsets = [0.0, -13.6863, 1.9550];
        iProfile = if(internalProfile.isNil) { if(at[\perceptualInternalProfileSymbol].notNil) { at[\perceptualInternalProfileSymbol].() } { \production } } { internalProfile };
        iProfile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(iProfile) } { iProfile.asSymbol };
        eProfile = if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(externalProfile) } { externalProfile.asSymbol };
        cache = st[\perceptualTriadScanCache];
        if(cache.isNil) { cache = IdentityDictionary.new; st[\perceptualTriadScanCache] = cache; };
        cacheKey = at[\perceptualDiagnosticCacheKey].(name, externalWeight, iProfile, eProfile);
        cached = cache[cacheKey.asSymbol];
        if(cached.notNil) {
            cached.copy
        } {
            confidence = if(at[\perceptualProfileConfidence].notNil) { at[\perceptualProfileConfidence].(iProfile) } { 0.70 };
            roughET = at[\perceptualRoughnessForSpecs].(at[\perceptualTriadSpecs].(pcs, midis, etOffsets, 1.0, externalWeight, iProfile, eProfile));
            roughJI = at[\perceptualRoughnessForSpecs].(at[\perceptualTriadSpecs].(pcs, midis, jiOffsets, 1.0, externalWeight, iProfile, eProfile));
            rawBest = etOffsets.copy;
            rawBestR = roughET;
            regBest = etOffsets.copy;
            regBestR = roughET;
            etPenalty = at[\perceptualRegularizationPenaltyForOffsets].(etOffsets, iProfile, externalWeight);
            jiPenalty = at[\perceptualRegularizationPenaltyForOffsets].(jiOffsets, iProfile, externalWeight);
            regBestObj = roughET + etPenalty;
            eMin = -32; eMax = 12; gMin = -12; gMax = 16;
            eOff = eMin;
            while { eOff <= eMax } {
                gOff = gMin;
                while { gOff <= gMax } {
                    offsets = [0.0, eOff.asFloat, gOff.asFloat];
                    r = at[\perceptualRoughnessForSpecs].(at[\perceptualTriadSpecs].(pcs, midis, offsets, 1.0, externalWeight, iProfile, eProfile));
                    if(r < rawBestR) {
                        rawBestR = r;
                        rawBest = offsets.copy;
                    };
                    score = r + at[\perceptualRegularizationPenaltyForOffsets].(offsets, iProfile, externalWeight);
                    if(score < regBestObj) {
                        regBestObj = score;
                        regBestR = r;
                        regBest = offsets.copy;
                    };
                    gOff = gOff + 1;
                };
                eOff = eOff + 1;
            };
            rawPenalty = at[\perceptualRegularizationPenaltyForOffsets].(rawBest, iProfile, externalWeight);
            regPenalty = at[\perceptualRegularizationPenaltyForOffsets].(regBest, iProfile, externalWeight);
            result = (
                name: name,
                internalProfile: iProfile,
                externalProfile: eProfile,
                externalWeight: externalWeight,
                etOffsetsCents: etOffsets.copy,
                jiOffsetsCents: jiOffsets.copy,
                roughnessET: roughET,
                roughnessJI: roughJI,
                rawBestOffsetsCents: rawBest.copy,
                rawBestRoughness: rawBestR,
                rawBestRegularizationPenalty: rawPenalty,
                regularizedBestOffsetsCents: regBest.copy,
                regularizedBestRoughness: regBestR,
                regularizedBestObjective: regBestObj,
                regularizedBestPenalty: regPenalty,
                bestOffsetsCents: regBest.copy,
                bestRoughness: regBestR,
                spectralConfidence: confidence,
                regularizationEnabled: cfg[\solver][\perceptualRegularizationEnabled] ? true,
                roughnessImprovementOverET: roughET - regBestR,
                roughnessImprovementOverJI: roughJI - regBestR,
                regularizedJiObjective: roughJI + jiPenalty,
                cacheKey: cacheKey,
                cacheHit: false,
                interpretation: \regularizedSpectrumDependentRoughnessCompromise
            );
            cache[cacheKey.asSymbol] = result.copy;
            result
        }
    };

    at[\perceptualTriadDiagnostic] = { |name=\Cmajor, internalProfile=nil|
        var low, mid, high, iProfile;
        iProfile = if(internalProfile.isNil) { if(at[\perceptualInternalProfileSymbol].notNil) { at[\perceptualInternalProfileSymbol].() } { \production } } { internalProfile };
        low = at[\perceptualScanTriad].(name, 0.05, iProfile, \externalEt);
        mid = at[\perceptualScanTriad].(name, 0.18, iProfile, \externalEt);
        high = at[\perceptualScanTriad].(name, 0.90, iProfile, \externalEt);
        (
            name: name,
            internalProfile: if(at[\perceptualNormalizeProfile].notNil) { at[\perceptualNormalizeProfile].(iProfile) } { iProfile.asSymbol },
            internalOnly: at[\perceptualScanTriad].(name, 0.0, iProfile, \externalEt),
            externalEtLow: low,
            externalEtMedium: mid,
            externalEtHigh: high,
            note: "Regularized spectrum-aware Sethares diagnostic: raw roughness is reported, but recommended offsets are continuity/confidence restrained."
        )
    };

    at[\perceptualToneTriadDiagnostic] = { |name=\Cmajor|
        var profiles, out;
        profiles = [\pure, \production, \electricPiano, \organ, \piano, \strings, \pad, \synth, \bellInharmonic];
        out = IdentityDictionary.new;
        profiles.do { |profile|
            out[profile] = at[\perceptualScanTriad].(name, 0.0, profile, \externalEt);
        };
        (
            name: name,
            results: out,
            note: "Different spectra yield different raw optima; recommended offsets are regularized by spectral confidence, not selected by a visible mode."
        )
    };

    api[\setPerceptualPressureEnabled] = { |flag=true|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualPressureEnabled] = flag.asBoolean;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualPressureEnabled]
    };

    api[\setPerceptualPressureAmount] = { |x=0.22|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualPressureAmount] = x.asFloat.clip(0.0, 1.5);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualPressureAmount]
    };

    api[\setPerceptualExternalWeight] = { |x=0.18|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualExternalWeight] = x.asFloat.clip(0.0, 4.0);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualExternalWeight]
    };

    api[\setPerceptualRegularizationEnabled] = { |flag=true|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualRegularizationEnabled] = flag.asBoolean;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualRegularizationEnabled]
    };

    api[\setPerceptualRegularizationAmount] = { |x=0.035|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualRegularizationAmount] = x.asFloat.clip(0.0, 0.08);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualRegularizationAmount]
    };

    api[\setPerceptualConfidenceGatingEnabled] = { |flag=true|
        at[\perceptualEnsureDefaults].();
        cfg[\solver][\perceptualConfidenceGatingEnabled] = flag.asBoolean;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\solver][\perceptualConfidenceGatingEnabled]
    };

    api[\perceptualSnapshot] = {
        var pcWeights, activePcs, externalSources, forces, report;
        at[\perceptualEnsureDefaults].();
        pcWeights = if(at[\pcWeights].notNil) { at[\pcWeights].() } { Array.fill(cfg[\solver][\numNodes], 0.0) };
        activePcs = if(at[\activePcsFromWeights].notNil) { at[\activePcsFromWeights].(pcWeights) } { Array.new };
        externalSources = if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { st[\externalSources] ? Array.new };
        forces = at[\perceptualPressureForActiveField].(activePcs, pcWeights, externalSources);
        report = (st[\lastPerceptualRoughnessReport] ? IdentityDictionary.new).copy;
        report[\forceByPc] = forces.copy;
        report
    };

    api[\perceptualTriadDiagnostic] = { |name=\Cmajor, internalProfile=nil| at[\perceptualTriadDiagnostic].(name, internalProfile) };
    api[\compareTriadTargets] = { |name=\Cmajor, internalProfile=nil| at[\perceptualTriadDiagnostic].(name, internalProfile) };
    api[\perceptualToneTriadDiagnostic] = { |name=\Cmajor| at[\perceptualToneTriadDiagnostic].(name) };
    api[\clearPerceptualDiagnosticCache] = { if(at[\perceptualClearDiagnosticCache].notNil) { at[\perceptualClearDiagnosticCache].() } { false } };
    api[\perceptualExternalSceneRoughness] = { at[\perceptualExternalSceneRoughness].(if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { st[\externalSources] ? Array.new }, nil) };

    at[\perceptualEnsureDefaults].();
    "[at-perceptual] regularized spectrum-aware Sethares roughness pressure loaded (off by default; diagnostic/API only).".postln;
};
)
