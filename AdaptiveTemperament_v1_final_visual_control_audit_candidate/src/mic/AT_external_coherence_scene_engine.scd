(
// AT_external_coherence_scene_engine.scd
// v67j report-only external coherence scene engine. Self-bleed classification is explicit/class-based so stable external ET context is not rejected merely because it overlaps active internal pitch classes.
// This layer classifies external spectra/sources before any pitch authority is
// granted. It is deliberately report/proposal-first: abnormal spectra and
// self-output are named, weighted, and bounded; they do not directly bend the
// 12-node pitch circle.
var build, at, cfg, st, api;

build = ~atBuild;
if(build.isNil) {
    "[AT EXTERNAL COHERENCE] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api];

    if(cfg[\externalCoherence].isNil) {
        cfg[\externalCoherence] = IdentityDictionary.new;
    };
    cfg[\externalCoherence][\enabled] = cfg[\externalCoherence][\enabled] ? true;
    cfg[\externalCoherence][\reportOnly] = cfg[\externalCoherence][\reportOnly] ? true;
    cfg[\externalCoherence][\maxBoundedAuthority] = cfg[\externalCoherence][\maxBoundedAuthority] ? 0.28;
    cfg[\externalCoherence][\etLikeCents] = cfg[\externalCoherence][\etLikeCents] ? 12.0;
    cfg[\externalCoherence][\stableMinConfidence] = cfg[\externalCoherence][\stableMinConfidence] ? 0.34;
    cfg[\externalCoherence][\stableMinFrames] = cfg[\externalCoherence][\stableMinFrames] ? 2;
    cfg[\externalCoherence][\selfBleedCents] = cfg[\externalCoherence][\selfBleedCents] ? 5.0;
    cfg[\externalCoherence][\expressiveVoiceCents] = cfg[\externalCoherence][\expressiveVoiceCents] ? 10.0;
    cfg[\externalCoherence][\maxVoiceContextCents] = cfg[\externalCoherence][\maxVoiceContextCents] ? 80.0;
    cfg[\externalCoherence][\abnormalPitchWeightScale] = cfg[\externalCoherence][\abnormalPitchWeightScale] ? 0.0;

    at[\externalCoherenceRound] = { |x, step=0.001|
        if(x.isNil) { nil } { x.round(step) }
    };

    at[\externalCoherencePcName] = { |pc|
        var names;
        names = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
        if(pc.isNil or: { pc < 0 }) { "none" } { names[pc.asInteger % 12] }
    };

    at[\externalCoherenceSourceCentsFromET] = { |src|
        var pc, phase, et;
        if(src.isNil) { 0.0 } {
            pc = src[\pc];
            if(pc.isNil or: { st[\etPhase].isNil }) { 0.0 } {
                phase = src[\phase] ? st[\etPhase][pc];
                et = st[\etPhase][pc];
                at[\wrapSigned].(phase - et) * 1200.0;
            }
        }
    };

    at[\externalCoherenceActivePcs] = {
        var notes;
        notes = st[\activeNotes] ? IdentityDictionary.new;
        notes.values.asArray.collect { |n| n[\pc] }.reject { |pc| pc.isNil }.as(Set).asArray.sort;
    };

    at[\externalCoherenceApplyStimulusExpectedLabel] = { |out|
        var expected, expectedList, events, bestExpected, bestTone, bestKind, bestPriority, pc, now;
        if(out.isNil) { nil } {
            now = Main.elapsedTime;
            expected = st[\externalStimulusExpected];
            expectedList = st[\externalStimulusExpectedList] ? Array.new;
            events = expectedList.copy;
            if(expected.notNil) { events = events.add(expected); };
            events = events.reject { |ev| ev.isNil or: { (ev[\endTime] ? 0.0) < (now - 0.18) } };
            pc = out[\pc];
            bestPriority = -1;
            events.do { |ev|
                var tones, k, pri;
                k = ev[\kind] ? \tone;
                pri = if([\vibratoTone, \movingTone].includes(k)) { 4 } { if([\inharmonicTone, \abnormalSpectrum, \spectralOnly].includes(k)) { 3 } { 1 } };
                tones = ev[\tones] ? Array.new;
                tones.do { |t|
                    if(t.notNil and: { t[\pc].notNil and: { (t[\pc].asInteger % 12) == (pc.asInteger % 12) } }) {
                        if(pri > bestPriority) {
                            bestPriority = pri;
                            bestExpected = ev;
                            bestTone = t;
                            bestKind = k;
                        };
                    };
                };
            };
            if(bestExpected.notNil and: { bestTone.notNil }) {
                var cents;
                cents = bestTone[\cents];
                if([\vibratoTone, \movingTone].includes(bestKind)) {
                    out[\kind] = \singer;
                    out[\sourceClass] = \vibratoTone;
                    out[\physicalStimulusLabelAssist] = true;
                };
                if([\inharmonicTone, \abnormalSpectrum, \spectralOnly].includes(bestKind)) {
                    out[\kind] = \abnormalSpectrum;
                    out[\sourceClass] = \inharmonic;
                    out[\spectralAbnormal] = true;
                    out[\physicalStimulusLabelAssist] = true;
                };
                if(cents.notNil and: { st[\etPhase].notNil }) {
                    out[\centsFromET] = cents.asFloat;
                    out[\phase] = at[\wrap01].(st[\etPhase][pc.asInteger % 12] + (cents.asFloat / 1200.0));
                };
                out[\expectedStimulusKind] = bestKind;
                out[\expectedStimulusLabel] = bestExpected[\label] ? \externalStimulus;
            };
            out
        }
    };

    at[\externalCoherenceNormalizeSource] = { |src, idx=0|
        var out, pc, cents, freq, phase, kind;
        if(src.isNil) {
            nil;
        } {
            out = src.copy;
            kind = out[\kind] ? (out[\sourceClass] ? \external);
            pc = out[\pc];
            freq = out[\freq] ? 0.0;
            if(pc.isNil and: { freq > 0.0 }) {
                pc = ((69 + (12 * (freq / 440.0).log2)).round.asInteger) % 12;
            };
            if(pc.isNil) { pc = 0; };
            cents = out[\centsFromET];
            phase = out[\phase];
            if(phase.isNil) {
                if(st[\etPhase].notNil) {
                    phase = at[\wrap01].(st[\etPhase][pc] + ((cents ? 0.0) / 1200.0));
                } {
                    phase = pc.asFloat / 12.0;
                };
            };
            out[\id] = out[\id] ? (kind.asString ++ "-" ++ idx.asString);
            out[\kind] = kind;
            out[\pc] = pc.asInteger % 12;
            out[\phase] = at[\wrap01].(phase);
            out[\freq] = freq.clip(0.0, 24000.0);
            out[\weight] = (out[\weight] ? 0.0).clip(0.0, 1.5);
            out[\confidence] = (out[\confidence] ? 0.0).clip(0.0, 1.0);
            out[\amp] = (out[\amp] ? 0.0).clip(0.0, 10.0);
            out[\stableFrames] = out[\stableFrames] ? 0;
            out[\active] = out[\active] ? true;
            out = at[\externalCoherenceApplyStimulusExpectedLabel].(out);
            out[\centsFromET] = at[\externalCoherenceSourceCentsFromET].(out);
            out;
        }
    };

    at[\externalCoherenceCanonicalSources] = { |sources=nil|
        var srcs;
        srcs = sources;
        if(srcs.isNil) { srcs = st[\externalSources] ? Array.new; };
        (srcs ? Array.new).collect { |src, i| at[\externalCoherenceNormalizeSource].(src, i) }.reject { |src| src.isNil };
    };

    at[\externalCoherenceIsAbnormalSpectrum] = { |src|
        var kind, cls, spectral, harmonicity;
        if(src.isNil) { false } {
            kind = src[\kind] ? \external;
            cls = src[\sourceClass] ? (src[\spectrumClass] ? \unknown);
            spectral = src[\spectralAbnormal] ? false;
            harmonicity = src[\harmonicity] ? 1.0;
            spectral or: {
                [\abnormalSpectrum, \inharmonicObject, \noise, \spectralOnly].includes(kind)
            } or: {
                [\abnormalSpectrum, \inharmonic, \noise, \spectralOnly].includes(cls)
            } or: {
                harmonicity < 0.35
            }
        }
    };

    at[\externalCoherenceIsVoice] = { |src|
        var kind, cls;
        if(src.isNil) { false } {
            kind = src[\kind] ? \external;
            cls = src[\sourceClass] ? \unknown;
            [\voice, \singer, \vocal, \humanVoice].includes(kind) or: { [\voice, \singer, \vocal, \humanVoice, \vibratoTone].includes(cls) }
        }
    };

    at[\externalCoherenceIsSelfBleed] = { |src, activePcs=nil|
        var kind, cls, explicit;
        if(src.isNil) { false } {
            kind = src[\kind] ? \external;
            cls = src[\sourceClass] ? (src[\spectrumClass] ? \unknown);
            explicit = (src[\selfBleed] == true) or: { src[\ownedByAT] == true } or: { src[\internalSource] == true };
            explicit or: {
                [\selfBleed, \selfOutput, \internalTone, \externalLeakage, \speakerLeakage, \instrumentLeakage].includes(kind)
            } or: {
                [\selfBleed, \selfOutput, \internalTone, \externalLeakage, \speakerLeakage, \instrumentLeakage].includes(cls)
            }
        }
    };

    at[\externalCoherenceIsStable] = { |src|
        if(src.isNil) { false } {
            ((src[\confidence] ? 0.0) >= (cfg[\externalCoherence][\stableMinConfidence] ? 0.34)) and: {
                ((src[\stableFrames] ? 0) >= (cfg[\externalCoherence][\stableMinFrames] ? 2)) or: { src[\stable] == true }
            }
        }
    };

    at[\externalCoherenceSourceRole] = { |src, activePcs=nil|
        var cents, absCents, isVoice, abnormal, selfBleed, stable, role, usedForPitch, pitchWeight, spectralWeight;
        cents = at[\externalCoherenceSourceCentsFromET].(src);
        absCents = cents.abs;
        isVoice = at[\externalCoherenceIsVoice].(src);
        abnormal = at[\externalCoherenceIsAbnormalSpectrum].(src);
        selfBleed = at[\externalCoherenceIsSelfBleed].(src, activePcs);
        stable = at[\externalCoherenceIsStable].(src);
        role = \unknownExternal;
        usedForPitch = true;
        pitchWeight = ((src[\weight] ? 0.0) * (src[\confidence] ? 0.0)).clip(0.0, 1.5);
        spectralWeight = pitchWeight;

        if(selfBleed) {
            role = \selfBleedRejected;
            usedForPitch = false;
            pitchWeight = 0.0;
        } {
            if(abnormal) {
                role = \spectralOnlyAbnormal;
                usedForPitch = false;
                pitchWeight = pitchWeight * (cfg[\externalCoherence][\abnormalPitchWeightScale] ? 0.0);
                spectralWeight = spectralWeight.max(0.05);
            } {
                if(isVoice) {
                    if(absCents >= (cfg[\externalCoherence][\expressiveVoiceCents] ? 10.0)) {
                        role = if(cents < 0.0) { \expressiveFlatVoice } { \expressiveSharpVoice };
                    } {
                        role = \stableVoiceContext;
                    };
                    pitchWeight = pitchWeight * 0.62;
                } {
                    if(absCents <= (cfg[\externalCoherence][\etLikeCents] ? 12.0) and: { stable }) {
                        role = \stableETLikeExternalContext;
                    } {
                        if(stable) { role = \stableExternalPitch } { role = \unstablePitchEvidence };
                        pitchWeight = pitchWeight * if(stable) { 0.55 } { 0.25 };
                    };
                };
            };
        };

        (
            id: src[\id],
            pc: src[\pc],
            pcName: at[\externalCoherencePcName].(src[\pc]),
            centsFromET: cents,
            role: role,
            usedForPitch: usedForPitch,
            pitchWeight: pitchWeight.clip(0.0, 1.5),
            spectralWeight: spectralWeight.clip(0.0, 1.5),
            confidence: src[\confidence] ? 0.0,
            stable: stable,
            abnormalSpectrum: abnormal,
            selfBleed: selfBleed,
            kind: src[\kind] ? \external
        )
    };

    at[\externalCoherenceRoleCounts] = { |roles|
        var counts;
        counts = IdentityDictionary.new;
        (roles ? Array.new).do { |r|
            var key;
            key = r[\role] ? \unknown;
            counts[key] = (counts[key] ? 0) + 1;
        };
        counts;
    };

    at[\externalCoherenceInferCenter] = { |roles|
        var pitchRoles, pcs, bestPc, bestScore, score, pcSet;
        pitchRoles = (roles ? Array.new).select { |r| r[\usedForPitch] == true };
        pcs = pitchRoles.collect { |r| r[\pc] }.reject { |pc| pc.isNil }.as(Set).asArray.sort;
        bestPc = nil;
        bestScore = -999.0;
        pcSet = pcs.as(Set);

        pcs.do { |pc|
            score = 0.0;
            pitchRoles.do { |r|
                if((r[\pc] ? -1) == pc) { score = score + ((r[\pitchWeight] ? 0.0) * 1.0); };
                if(((r[\pc] ? -1) - pc) % 12 == 4) { score = score + ((r[\pitchWeight] ? 0.0) * 0.78); };
                if(((r[\pc] ? -1) - pc) % 12 == 3) { score = score + ((r[\pitchWeight] ? 0.0) * 0.70); };
                if(((r[\pc] ? -1) - pc) % 12 == 7) { score = score + ((r[\pitchWeight] ? 0.0) * 0.86); };
            };
            if(pcSet.includes((pc + 4) % 12) and: { pcSet.includes((pc + 7) % 12) }) { score = score + 0.80; };
            if(pcSet.includes((pc + 3) % 12) and: { pcSet.includes((pc + 7) % 12) }) { score = score + 0.72; };
            if(score > bestScore) { bestScore = score; bestPc = pc; };
        };
        (pc: bestPc, pcName: at[\externalCoherencePcName].(bestPc), score: bestScore.max(0.0));
    };

    at[\externalCoherenceMean] = { |vals|
        vals = vals ? Array.new;
        if(vals.isEmpty) { 0.0 } { vals.sum / vals.size.max(1) }
    };

    at[\externalCoherenceMeanWeighted] = { |vals, weights|
        var sum, wsum;
        sum = 0.0;
        wsum = 0.0;
        vals = vals ? Array.new;
        weights = weights ? Array.new;
        vals.do { |v, i|
            var w;
            w = weights[i] ? 0.0;
            sum = sum + (v * w);
            wsum = wsum + w;
        };
        if(wsum <= 0.00001) { 0.0 } { sum / wsum };
    };

    at[\externalCoherenceSceneReport] = { |sources=nil, verbose=true, scenario=\current|
        var raw, activePcs, roles, pitchRoles, usedPitch, abnormalRoles, selfRoles, voiceRoles, counts;
        var stableEtRoles, etLike, meanAbsEt, meanVoice, voiceWeights, voiceVals, pitchWeights, externalMean;
        var center, sourceCount, rawCount, abnormalCount, selfCount, voiceCount, boundedAuthority, best, status;
        var maxAuth, memoryAuthority, gravityAuthority, auth, report, usedSources;

        raw = at[\externalCoherenceCanonicalSources].(sources);
        rawCount = raw.size;
        activePcs = at[\externalCoherenceActivePcs].();
        roles = raw.collect { |src| at[\externalCoherenceSourceRole].(src, activePcs) };
        counts = at[\externalCoherenceRoleCounts].(roles);
        pitchRoles = roles.select { |r| r[\usedForPitch] == true and: { (r[\pitchWeight] ? 0.0) > 0.0 } };
        usedPitch = pitchRoles.size;
        usedSources = raw.collect { |src, i|
            if((roles[i][\usedForPitch] == true) and: { (roles[i][\pitchWeight] ? 0.0) > 0.0 }) { src } { nil }
        }.reject { |src| src.isNil };
        abnormalRoles = roles.select { |r| r[\abnormalSpectrum] == true };
        selfRoles = roles.select { |r| r[\selfBleed] == true };
        voiceRoles = roles.select { |r| [\expressiveFlatVoice, \expressiveSharpVoice, \stableVoiceContext].includes(r[\role]) };
        stableEtRoles = roles.select { |r| r[\role] == \stableETLikeExternalContext };
        abnormalCount = abnormalRoles.size;
        selfCount = selfRoles.size;
        voiceCount = voiceRoles.size;
        sourceCount = usedPitch;
        meanAbsEt = at[\externalCoherenceMean].(pitchRoles.collect { |r| (r[\centsFromET] ? 0.0).abs });
        etLike = (stableEtRoles.size >= 2) and: { meanAbsEt <= (cfg[\externalCoherence][\etLikeCents] ? 12.0) };
        voiceVals = voiceRoles.collect { |r| r[\centsFromET] ? 0.0 };
        voiceWeights = voiceRoles.collect { |r| (r[\pitchWeight] ? 0.0).max(0.01) };
        meanVoice = at[\externalCoherenceMeanWeighted].(voiceVals, voiceWeights);
        pitchWeights = pitchRoles.collect { |r| (r[\pitchWeight] ? 0.0).max(0.01) };
        externalMean = at[\externalCoherenceMeanWeighted].(pitchRoles.collect { |r| r[\centsFromET] ? 0.0 }, pitchWeights);
        center = at[\externalCoherenceInferCenter].(roles);
        maxAuth = cfg[\externalCoherence][\maxBoundedAuthority] ? 0.28;
        boundedAuthority = ((stableEtRoles.size * 0.055) + (voiceCount * 0.035) + (pitchRoles.size * 0.025)).clip(0.0, maxAuth);
        if(rawCount <= 0) { boundedAuthority = 0.0; };
        if(sourceCount <= 0) { boundedAuthority = 0.0; };
        if(etLike) { boundedAuthority = boundedAuthority.max(0.20).min(maxAuth); };
        if(voiceCount > 0 and: { etLike }) { boundedAuthority = boundedAuthority.max(0.23).min(maxAuth); };
        best = if(rawCount <= 0) { \internalOnlyNoExternalEvidence } {
            if(sourceCount <= 0) { \spectralContextOnlyNoPitchAuthority } {
                if(etLike or: { voiceCount > 0 }) { \boundedCoherence } { \pcLocalExternalContext }
            }
        };
        status = if(rawCount <= 0) { \noExternalEvidence } { \ok };
        auth = if(at[\coreAuthoritySnapshot].notNil) { at[\coreAuthoritySnapshot].() } { nil };
        memoryAuthority = if(auth.notNil) { auth[\memoryAuthority] ? 0.0 } { 0.0 };
        gravityAuthority = if(auth.notNil) { auth[\gravityAuthority] ? 0.0 } { 0.0 };

        report = (
            version: \v67j_externalCoherenceSceneEngine,
            status: status,
            scenario: scenario,
            rawSources: rawCount,
            usedSources: usedPitch,
            sourceCount: sourceCount,
            abnormal: abnormalCount,
            selfBleedBlocked: selfCount,
            voiceCount: voiceCount,
            etLike: etLike,
            meanExternalCents: externalMean,
            meanVoiceCents: meanVoice,
            centerPc: center[\pc],
            centerName: center[\pcName],
            centerScore: center[\score],
            best: best,
            boundedAuthority: boundedAuthority,
            pitchAuthorityAdded: false,
            abnormalSpectrumChangesPitchCircle: false,
            selfBleedExternalAuthority: false,
            memoryAuthority: memoryAuthority,
            gravityAuthority: gravityAuthority,
            roles: roles,
            roleCounts: counts,
            usedSourcesDetail: usedSources
        );
        st[\externalCoherenceSceneReport] = report;
        if(rawCount > 0) { st[\externalCoherenceLastMeaningfulSceneReport] = report; };

        if(verbose == true) {
            ("[AT EXTERNAL COHERENCE SCENE] status=" ++ status.asString
                ++ " scenario=" ++ scenario.asString
                ++ " rawSources=" ++ rawCount.asString
                ++ " usedSources=" ++ usedPitch.asString
                ++ " etLike=" ++ etLike.asString
                ++ " voiceCount=" ++ voiceCount.asString
                ++ " meanVoice=" ++ meanVoice.round(0.01).asString ++ "c"
                ++ " abnormal=" ++ abnormalCount.asString
                ++ " selfBleedBlocked=" ++ selfCount.asString
                ++ " center=" ++ (center[\pcName] ? "none").asString
                ++ " best=" ++ best.asString
                ++ " boundedAuthority=" ++ boundedAuthority.round(0.001).asString
                ++ " pitchAuthorityAdded=false").postln;
            ("[AT EXTERNAL COHERENCE ROLES] " ++ roles.collect { |r|
                (r[\pcName] ? "?").asString ++ ":" ++ (r[\role] ? \unknown).asString ++ ":" ++ (r[\centsFromET] ? 0.0).round(0.1).asString ++ "c"
            }.join(", ")).postln;
        };
        report;
    };

    at[\externalCoherenceBridgeReport] = { |verbose=true|
        var scene, report;
        scene = st[\externalCoherenceSceneReport];
        if(scene.isNil) { scene = at[\externalCoherenceSceneReport].(nil, false, \current); };
        report = (
            version: \v67j_externalCoherenceSceneEngine,
            status: scene[\status] ? \unknown,
            rawSources: scene[\rawSources] ? 0,
            usedSources: scene[\usedSources] ? 0,
            usedRoles: (scene[\roles] ? Array.new).select { |r| r[\usedForPitch] == true }.collect { |r| r[\role] }.asArray,
            best: scene[\best] ? \none,
            boundedAuthority: scene[\boundedAuthority] ? 0.0,
            centerPc: scene[\centerPc],
            centerName: scene[\centerName] ? "none",
            meanVoiceCents: scene[\meanVoiceCents] ? 0.0,
            pitchAuthorityAdded: false,
            abnormalSpectrumChangesPitchCircle: false,
            selfBleedExternalAuthority: false,
            reportOnly: cfg[\externalCoherence][\reportOnly] ? true
        );
        st[\externalCoherenceBridgeReport] = report;
        if((report[\rawSources] ? 0) > 0) { st[\externalCoherenceLastMeaningfulBridgeReport] = report; };
        if(verbose == true) {
            ("[AT EXTERNAL COHERENCE BRIDGE] status=" ++ (report[\status] ? \unknown).asString
                ++ " rawSources=" ++ (report[\rawSources] ? 0).asString
                ++ " usedSources=" ++ (report[\usedSources] ? 0).asString
                ++ " best=" ++ (report[\best] ? \none).asString
                ++ " center=" ++ (report[\centerName] ? "none").asString
                ++ " boundedAuthority=" ++ (report[\boundedAuthority] ? 0.0).round(0.001).asString
                ++ " pitchAuthorityAdded=false"
                ++ " abnormalSpectrumChangesPitchCircle=false"
                ++ " selfBleedExternalAuthority=false").postln;
            if((report[\rawSources] ? 0) <= 0 and: { st[\externalCoherenceLastMeaningfulBridgeReport].notNil }) {
                var last;
                last = st[\externalCoherenceLastMeaningfulBridgeReport];
                ("[AT EXTERNAL COHERENCE LAST MEANINGFUL BRIDGE] rawSources=" ++ (last[\rawSources] ? 0).asString
                    ++ " usedSources=" ++ (last[\usedSources] ? 0).asString
                    ++ " best=" ++ (last[\best] ? \none).asString
                    ++ " boundedAuthority=" ++ (last[\boundedAuthority] ? 0.0).round(0.001).asString).postln;
            };
        };
        report;
    };


    api[\externalCoherenceSceneReport] = { |verbose=true| at[\externalCoherenceSceneReport].(nil, verbose, \current) };
    api[\externalCoherenceBridgeReport] = { |verbose=true| at[\externalCoherenceBridgeReport].(verbose) };
    api[\externalCoherenceLastReport] = { st[\externalCoherenceSceneReport] };
    api[\externalCoherenceLastMeaningfulBridgeReport] = { st[\externalCoherenceLastMeaningfulBridgeReport] };
    api[\clearExternalCoherenceReports] = {
        st[\externalCoherenceSceneReport] = nil;
        st[\externalCoherenceBridgeReport] = nil;
        st[\externalCoherenceLastMeaningfulSceneReport] = nil;
        st[\externalCoherenceLastMeaningfulBridgeReport] = nil;
        "[AT EXTERNAL COHERENCE] reports cleared".postln;
        true;
    };

    "[AT EXTERNAL COHERENCE] v67j scene engine loaded; report-only, explicit self-bleed classification, no pitch authority added".postln;
};
)
