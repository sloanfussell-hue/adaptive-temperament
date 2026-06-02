(
// AT_external_coherence_world_model.scd
// v50 External Coherence scene-truth bridge: preserve staged source roles through reports.
//
// The Ear is not a pitch dictator.  It turns the outside world into a bounded
// coherence scene: ET-like instruments, expressive/flat voices, abnormal
// spectra, and self-bleed are different kinds of evidence.  The model can
// soften/annotate external pitch pressure, produce candidate-world scores, and
// route the coherence-prepared source set into the actual live external-evidence
// path without letting ET, abnormal spectra, self-bleed, or unstable voices become
// pitch commands.
var build, at, cfg, st, api, pitchClassNames, previousCurrentExternalSources;

build = ~atBuild;
if(build.isNil) {
    "[AT EXTERNAL COHERENCE] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(cfg[\externalCoherence].isNil) {
        cfg[\externalCoherence] = (
            enabled: true,
            adaptExternalWeights: true,
            reportEnabled: true,

            // v3D40 bridge: the model decision is no longer only explanatory.
            // Actual live external-source consumers receive the decorated/filtered
            // source set, and reports show exactly what was used.  This remains
            // source-weight evidence, not direct pitch-circle authority.
            bridgePreparedSourcesToLivePaths: true,
            bridgeReportEnabled: true,
            boundedCoherenceAuthorityEnabled: true,
            boundedCoherenceAuthorityMin: 0.08,
            boundedCoherenceAuthorityMax: 0.24,
            boundedCoherenceAuthoritySourceStep: 0.035,
            boundedCoherenceAuthorityEtBonus: 0.045,
            boundedCoherenceAuthorityVoicePenalty: 0.025,
            boundedCoherenceAuthorityAbnormalPenalty: 0.015,
            boundedCoherenceAuthoritySelfBleedPenalty: 0.02,

            // ET-like context means the outside source is a stable grid to fit,
            // not a command to erase internal harmonic law.
            etLikeMinSources: 2,
            etLikeMaxMeanAbsCents: 30.0,
            etLikeMaxSpreadCents: 58.0,
            etLikeWeightScale: 0.82,

            // Voices are meaningful, but unstable/flat singing should not seize
            // the whole field.  Consistent flatness is context; jitter is lower
            // pitch authority.
            voiceWeightCap: 0.18,
            voiceStableWeightCap: 0.28,
            voiceFlatThresholdCents: -9.0,
            voiceUnstableJitterCents: 11.0,

            // Abnormal spectra are real perceptual evidence.  They are not
            // allowed to rewrite pitch-class identity unless they also have a
            // stable pitch model.
            abnormalPitchConfidenceCeiling: 0.30,
            abnormalSpectralConfidenceFloor: 0.45,
            abnormalPitchWeightScale: 0.0,

            // Self bleed is expected when the instrument is loud in the room.
            selfBleedWeightScale: 0.0,

            // Candidate-world scoring weights.  Lower score is better.
            pureJIPenaltyWhenET: 3.0,
            blindFollowVoicePenalty: 2.8,
            blindETInternalPenalty: 1.2,
            boundedCoherenceBase: 1.0,
            boundedSafetyPenalty: 0.25,
            candidateRoundCents: 0.01
        );
    };

    st[\externalCoherenceScene] = st[\externalCoherenceScene] ? nil;
    st[\externalCoherenceLastReport] = st[\externalCoherenceLastReport] ? nil;
    st[\externalCoherenceLastMeaningfulReport] = st[\externalCoherenceLastMeaningfulReport] ? nil;
    st[\externalCoherenceLastMeaningfulBridge] = st[\externalCoherenceLastMeaningfulBridge] ? nil;
    st[\externalCoherenceDemoSources] = st[\externalCoherenceDemoSources] ? Array.new;

    at[\externalCoherenceSourceCents] = { |src|
        var pc, phase;
        if(src.isNil) { 0.0 } {
            pc = src[\pc];
            phase = src[\phase];
            if(pc.isNil or: { phase.isNil }) {
                src[\cents] ? src[\externalCents] ? 0.0
            } {
                if(at[\phaseToPcCents].notNil) {
                    at[\phaseToPcCents].(phase, pc)
                } {
                    at[\wrapSigned].(phase - (pc.asInteger / 12.0)) * 1200.0
                }
            }
        }
    };

    at[\externalCoherenceSourceName] = { |src|
        var pc;
        if(src.isNil) { "nil" } {
            pc = src[\pc];
            (src[\id] ? src[\sourceId] ? "external").asString ++ ":" ++ (pitchClassNames[pc] ? pc.asString).asString
        }
    };

    at[\externalCoherenceLooksLike] = { |src, token|
        var s, t;
        if(src.isNil) { false } {
            s = ((src[\id] ? "").asString ++ " " ++ (src[\kind] ? "").asString ++ " " ++ (src[\sourceClass] ? "").asString ++ " " ++ (src[\spectrumClass] ? "").asString);
            t = token.asString;
            s.find(t).notNil
        }
    };

    at[\externalCoherenceIsSelfBleed] = { |src|
        if(src.isNil) { false } {
            (src[\selfBleed] == true) or: {
                (src[\kind] == \internalTone) or: {
                    (src[\isInternal] == true) or: {
                        at[\externalCoherenceLooksLike].(src, "self") or: { at[\externalCoherenceLooksLike].(src, "bleed") }
                    }
                }
            }
        }
    };

    at[\externalCoherenceIsVoice] = { |src|
        if(src.isNil) { false } {
            (src[\sourceClass] == \voice) or: {
                (src[\kind] == \voice) or: {
                    (src[\kind] == \singer) or: {
                        [\expressiveVoice, \expressiveFlatVoice].includes(src[\coherenceRole]) or: {
                            at[\externalCoherenceLooksLike].(src, "voice") or: { at[\externalCoherenceLooksLike].(src, "singer") }
                        }
                    }
                }
            }
        }
    };

    at[\externalCoherenceIsAbnormalSpectrum] = { |src|
        var cls, pitchConf, spectralConf;
        if(src.isNil) { false } {
            cls = src[\spectrumClass] ? src[\sourceClass] ? \unknown;
            pitchConf = src[\pitchConfidence] ? src[\confidence] ? 0.0;
            spectralConf = src[\spectralConfidence] ? src[\spectrumConfidence] ? 0.0;
            [\inharmonic, \noisy, \stretchedInharmonic, \percussion, \abnormalSpectrum, \noise].includes(cls) or: {
                (src[\kind] == \inharmonic) or: {
                    (src[\sourceClass] == \abnormalSpectrum) or: {
                        (src[\coherenceRole] == \spectralOnlyAbnormal) or: {
                            ((src[\spectralAuthorityEligible] ? false) == true and: { (src[\pitchAuthorityEligible] ? true) == false }) or: {
                                (spectralConf >= (cfg[\externalCoherence][\abnormalSpectralConfidenceFloor] ? 0.45)) and: {
                                    pitchConf <= (cfg[\externalCoherence][\abnormalPitchConfidenceCeiling] ? 0.30)
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    at[\externalCoherenceDecorateSource] = { |src, sceneKind=\unknown, etLike=false|
        var out, role, cents, weight, conf, jitter, cap, pitchEligible, spectralEligible;
        out = src.copy;
        cents = at[\externalCoherenceSourceCents].(src);
        weight = (src[\weight] ? 0.0).asFloat.clip(0.0, 1.5);
        conf = (src[\confidence] ? src[\pitchConfidence] ? 0.0).asFloat.clip(0.0, 1.0);
        jitter = (src[\jitterCents] ? src[\motionJitterCents] ? 0.0).asFloat;
        pitchEligible = true;
        spectralEligible = false;
        role = \externalPitchEvidence;

        if(at[\externalCoherenceIsSelfBleed].(src)) {
            role = \selfBleedBlocked;
            pitchEligible = false;
            weight = weight * (cfg[\externalCoherence][\selfBleedWeightScale] ? 0.0);
        } {
            if(at[\externalCoherenceIsAbnormalSpectrum].(src)) {
                role = \spectralOnlyAbnormal;
                pitchEligible = false;
                spectralEligible = true;
                weight = weight * (cfg[\externalCoherence][\abnormalPitchWeightScale] ? 0.0);
            } {
                if(at[\externalCoherenceIsVoice].(src)) {
                    role = if(cents <= (cfg[\externalCoherence][\voiceFlatThresholdCents] ? -9.0)) { \expressiveFlatVoice } { \expressiveVoice };
                    cap = if(jitter <= (cfg[\externalCoherence][\voiceUnstableJitterCents] ? 11.0)) {
                        cfg[\externalCoherence][\voiceStableWeightCap] ? 0.28
                    } {
                        cfg[\externalCoherence][\voiceWeightCap] ? 0.18
                    };
                    weight = weight.min(cap) * conf.max(0.15);
                } {
                    if(etLike) {
                        role = \stableETLikeExternalContext;
                        weight = weight * (cfg[\externalCoherence][\etLikeWeightScale] ? 0.82);
                    } {
                        if([\chordCloud, \songScene].includes(sceneKind)) {
                            role = \stableExternalContext;
                        } {
                            role = \externalPitchEvidence;
                        }
                    }
                }
            }
        };

        out[\coherenceRole] = role;
        out[\coherenceCents] = cents.round(0.01);
        out[\pitchAuthorityEligible] = pitchEligible;
        out[\spectralAuthorityEligible] = spectralEligible;
        out[\weightBeforeCoherence] = src[\weight] ? 0.0;
        out[\weight] = weight.clip(0.0, 1.5);
        out[\active] = (src[\active] != false) and: { ((out[\weight] ? 0.0) > 0.0) or: { spectralEligible } };
        out
    };

    at[\externalCoherenceSceneKindFor] = { |sources|
        var arr, usable, abnormalCount, selfCount;
        arr = sources ? Array.new;
        usable = arr.select { |src| src.notNil and: { at[\externalCoherenceIsSelfBleed].(src).not and: { at[\externalCoherenceIsAbnormalSpectrum].(src).not } } };
        abnormalCount = arr.count { |src| at[\externalCoherenceIsAbnormalSpectrum].(src) };
        selfCount = arr.count { |src| at[\externalCoherenceIsSelfBleed].(src) };
        if(usable.size >= 3) { \chordCloud } {
            if(usable.size >= 2) { \polyContext } {
                if(usable.size == 1) { \singleSource } {
                    if(abnormalCount > 0) { \abnormalSpectrum } { if(selfCount > 0) { \selfBleedOnly } { \none } }
                }
            }
        }
    };

    at[\externalCoherenceEtLikeReport] = { |sources|
        var usable, cents, meanAbs, spread, minC, maxC, stable, etLike;
        usable = (sources ? Array.new).select { |src|
            src.notNil and: {
                at[\externalCoherenceIsSelfBleed].(src).not and: {
                    at[\externalCoherenceIsAbnormalSpectrum].(src).not and: { at[\externalCoherenceIsVoice].(src).not }
                }
            }
        };
        cents = usable.collect { |src| at[\externalCoherenceSourceCents].(src) };
        meanAbs = if(cents.isEmpty) { 999.0 } { cents.collect { |c| c.abs }.sum / cents.size.max(1) };
        minC = if(cents.isEmpty) { 0.0 } { cents.minItem };
        maxC = if(cents.isEmpty) { 0.0 } { cents.maxItem };
        spread = (maxC - minC).abs;
        stable = usable.count { |src| (src[\confidence] ? src[\pitchConfidence] ? 0.0) >= 0.45 };
        etLike = (usable.size >= (cfg[\externalCoherence][\etLikeMinSources] ? 2)) and: {
            meanAbs <= (cfg[\externalCoherence][\etLikeMaxMeanAbsCents] ? 30.0)
        } and: {
            spread <= (cfg[\externalCoherence][\etLikeMaxSpreadCents] ? 58.0)
        };
        (
            etLike: etLike,
            usableSourceCount: usable.size,
            stableSourceCount: stable,
            meanAbsCents: meanAbs.round(0.01),
            spreadCents: spread.round(0.01),
            minCents: minC.round(0.01),
            maxCents: maxC.round(0.01)
        )
    };

    at[\externalCoherenceRoleCounts] = { |sources|
        var counts;
        counts = IdentityDictionary.new;
        (sources ? Array.new).do { |src|
            var role;
            role = src[\coherenceRole] ? \unknown;
            counts[role] = (counts[role] ? 0) + 1;
        };
        counts
    };

    at[\externalCoherenceVoiceReport] = { |sources|
        var voices, cents, mean, flatCount, unstableCount;
        voices = (sources ? Array.new).select { |src| at[\externalCoherenceIsVoice].(src) };
        cents = voices.collect { |src| src[\coherenceCents] ? at[\externalCoherenceSourceCents].(src) };
        mean = if(cents.isEmpty) { 0.0 } { cents.sum / cents.size.max(1) };
        flatCount = voices.count { |src|
            var c;
            c = src[\coherenceCents] ? at[\externalCoherenceSourceCents].(src);
            ((src[\coherenceRole] ? \unknown) == \expressiveFlatVoice) or: { c <= (cfg[\externalCoherence][\voiceFlatThresholdCents] ? -9.0) }
        };
        unstableCount = voices.count { |src| (src[\jitterCents] ? src[\motionJitterCents] ? 0.0) > (cfg[\externalCoherence][\voiceUnstableJitterCents] ? 11.0) };
        (
            voiceCount: voices.size,
            meanVoiceCents: mean.round(0.01),
            flatVoiceCount: flatCount,
            unstableVoiceCount: unstableCount
        )
    };

    at[\externalCoherenceCandidateScores] = { |decoratedSources, activePcs=nil, pcWeights=nil|
        var et, voice, abnormalCount, selfCount, externalCount, memoryAuth, gravityAuth, perceptualAuth, pureScore, etScore, followScore, spectralScore, boundedScore, candidates, best;
        et = at[\externalCoherenceEtLikeReport].(decoratedSources);
        voice = at[\externalCoherenceVoiceReport].(decoratedSources);
        abnormalCount = (decoratedSources ? Array.new).count { |src| src[\coherenceRole] == \spectralOnlyAbnormal };
        selfCount = (decoratedSources ? Array.new).count { |src| src[\coherenceRole] == \selfBleedBlocked };
        externalCount = (decoratedSources ? Array.new).count { |src| (src[\coherenceRole] ? \unknown) != \selfBleedBlocked };
        memoryAuth = ((cfg[\memory] ? IdentityDictionary.new)[\amount] ? 0.0).clip(0.0, 1.0);
        gravityAuth = if(((cfg[\gravity] ? IdentityDictionary.new)[\enabled] ? false)) { ((cfg[\gravity] ? IdentityDictionary.new)[\strength] ? 0.0).clip(0.0, 1.0) } { 0.0 };
        perceptualAuth = ((cfg[\perceptualCoherence] ? IdentityDictionary.new)[\amount] ? 0.0).clip(0.0, 1.0);

        if((decoratedSources ? Array.new).isEmpty) {
            candidates = [(name: \internalOnlyNoExternalEvidence, score: 0.0, reason: \noExternalEvidenceToAdapt)];
            best = candidates[0];
        } {
            pureScore = 2.0 + if(et[\etLike]) { cfg[\externalCoherence][\pureJIPenaltyWhenET] ? 3.0 } { 0.0 } + (voice[\unstableVoiceCount] * 0.8) + (abnormalCount * 0.6);
            etScore = 2.2 + if(et[\etLike]) { 0.0 } { 1.6 } + (cfg[\externalCoherence][\blindETInternalPenalty] ? 1.2) + (memoryAuth * 0.5) + (gravityAuth * 0.5);
            followScore = 2.5 + (voice[\unstableVoiceCount] * (cfg[\externalCoherence][\blindFollowVoicePenalty] ? 2.8)) + (selfCount * 3.0) + (abnormalCount * 1.4);
            spectralScore = 2.4 + if(abnormalCount > 0) { -0.35 } { 0.35 } + if(et[\etLike]) { 0.45 } { 0.0 };
            boundedScore = (cfg[\externalCoherence][\boundedCoherenceBase] ? 1.0) + (abnormalCount * 0.12) + (voice[\unstableVoiceCount] * 0.18) + (selfCount * 0.08) + (perceptualAuth * -0.15) + (cfg[\externalCoherence][\boundedSafetyPenalty] ? 0.25);

            candidates = [
                (name: \pureRatioWorld, score: pureScore.round(0.01), reason: \tooPureWhenExternalContextExists),
                (name: \equalTemperamentGrid, score: etScore.round(0.01), reason: \tooRigidForInternalHarmonyMemoryGravity),
                (name: \blindExternalFollow, score: followScore.round(0.01), reason: \unsafeWithVoiceJitterSelfBleedOrAbnormalSpectrum),
                (name: \spectralTimbreOnly, score: spectralScore.round(0.01), reason: \usefulButIncomplete),
                (name: \boundedCoherence, score: boundedScore.round(0.01), reason: \bestUnderEvidenceAndSafety)
            ];
            best = candidates.sort { |a, b| (a[\score] ? 999.0) < (b[\score] ? 999.0) }[0];
        };
        (
            candidates: candidates,
            best: best,
            etLike: et[\etLike],
            externalCount: externalCount,
            abnormalSpectrumCount: abnormalCount,
            selfBleedBlockedCount: selfCount,
            voiceCount: voice[\voiceCount],
            meanVoiceCents: voice[\meanVoiceCents],
            memoryAuthority: memoryAuth.round(0.001),
            gravityAuthority: gravityAuth.round(0.001),
            perceptualAuthority: perceptualAuth.round(0.001)
        )
    };

    at[\externalCoherenceAnalyzeScene] = { |activePcs=nil, pcWeights=nil, rawSources=nil, post=true, label=\externalCoherence|
        var sources, sceneKind, et, decorated, roles, voice, scores, report;
        sources = rawSources;
        if(sources.isNil) { sources = if(at[\legacyCurrentExternalSources_v3D40].notNil) { at[\legacyCurrentExternalSources_v3D40].() } { if(at[\legacyCurrentExternalSources_v3D39].notNil) { at[\legacyCurrentExternalSources_v3D39].() } { st[\externalSources] ? Array.new } } };
        sceneKind = at[\externalCoherenceSceneKindFor].(sources);
        et = at[\externalCoherenceEtLikeReport].(sources);
        decorated = (sources ? Array.new).collect { |src| at[\externalCoherenceDecorateSource].(src, sceneKind, et[\etLike]) };
        roles = at[\externalCoherenceRoleCounts].(decorated);
        voice = at[\externalCoherenceVoiceReport].(decorated);
        scores = at[\externalCoherenceCandidateScores].(decorated, activePcs, pcWeights);
        report = (
            label: label,
            status: if((sources ? Array.new).isEmpty) { \noExternalScene } { \ok },
            enabled: cfg[\externalCoherence][\enabled] ? true,
            adaptExternalWeights: cfg[\externalCoherence][\adaptExternalWeights] ? true,
            sceneKind: sceneKind,
            sourceCount: (sources ? Array.new).size,
            activePcs: activePcs ? Array.new,
            etLike: et[\etLike],
            etLikeReport: et,
            voiceReport: voice,
            roleCounts: roles,
            decoratedSources: decorated,
            candidateScores: scores[\candidates],
            scoreSummary: scores,
            bestWorld: scores[\best][\name],
            bestReason: scores[\best][\reason],
            pitchAuthorityAdded: false,
            topologyAuthorityAdded: false,
            spacingThresholdChange: false,
            abnormalSpectrumChangesPitchCircle: false,
            abnormalSpectrumPitchAuthority: false,
            selfBleedExternalAuthority: false,
            coherenceDefinition: \bestAvailableWorldUnderEvidenceMemoryGravityTimbreExternalContextAndSafety
        );
        st[\externalCoherenceScene] = report;
        st[\externalCoherenceLastReport] = report;
        if((report[\status] ? \unknown) != \noExternalScene) {
            st[\externalCoherenceLastMeaningfulReport] = report;
        };
        if(post and: { cfg[\externalCoherence][\reportEnabled] ? true }) {
            "".postln;
            "[AT EXTERNAL COHERENCE SCENE]".postln;
            ("label=" ++ label.asString
                ++ " status=" ++ report[\status].asString
                ++ " scene=" ++ sceneKind.asString
                ++ " sources=" ++ report[\sourceCount].asString
                ++ " etLike=" ++ report[\etLike].asString
                ++ " voiceCount=" ++ voice[\voiceCount].asString
                ++ " meanVoice=" ++ voice[\meanVoiceCents].asString ++ "c"
                ++ " abnormal=" ++ scores[\abnormalSpectrumCount].asString
                ++ " selfBleedBlocked=" ++ scores[\selfBleedBlockedCount].asString).postln;
            ("roles=" ++ roles.asString).postln;
            "[AT EXTERNAL COHERENCE CANDIDATE WORLDS]".postln;
            scores[\candidates].do { |cand|
                (cand[\name].asString ++ " score=" ++ cand[\score].asString ++ " reason=" ++ cand[\reason].asString).postln;
            };
            ("[AT EXTERNAL COHERENCE DECISION] best=" ++ report[\bestWorld].asString
                ++ " boundedAuthority=" ++ at[\externalCoherenceAuthorityScalarForReport].(report).asString
                ++ " pitchAuthorityAdded=false abnormalSpectrumChangesPitchCircle=false selfBleedExternalAuthority=false").postln;
        };
        report
    };

    at[\externalCoherenceAuthorityScalarForReport] = { |report|
        var scores, externalCount, abnormalCount, selfCount, voiceReport, unstableVoices, scalar;
        if((cfg[\externalCoherence][\boundedCoherenceAuthorityEnabled] ? true).not) { 0.0 } {
            if(report.isNil or: { (report[\status] ? \unknown) == \noExternalScene or: { (report[\sourceCount] ? 0) <= 0 or: { (report[\bestWorld] ? \none) != \boundedCoherence } } }) { 0.0 } {
                scores = report[\scoreSummary] ? IdentityDictionary.new;
                externalCount = scores[\externalCount] ? (report[\sourceCount] ? 0);
                abnormalCount = scores[\abnormalSpectrumCount] ? 0;
                selfCount = scores[\selfBleedBlockedCount] ? 0;
                voiceReport = report[\voiceReport] ? IdentityDictionary.new;
                unstableVoices = voiceReport[\unstableVoiceCount] ? 0;
                scalar = (cfg[\externalCoherence][\boundedCoherenceAuthorityMin] ? 0.08)
                    + (externalCount * (cfg[\externalCoherence][\boundedCoherenceAuthoritySourceStep] ? 0.035))
                    + (if(report[\etLike] == true) { cfg[\externalCoherence][\boundedCoherenceAuthorityEtBonus] ? 0.045 } { 0.0 })
                    - (unstableVoices * (cfg[\externalCoherence][\boundedCoherenceAuthorityVoicePenalty] ? 0.025))
                    - (abnormalCount * (cfg[\externalCoherence][\boundedCoherenceAuthorityAbnormalPenalty] ? 0.015))
                    - (selfCount * (cfg[\externalCoherence][\boundedCoherenceAuthoritySelfBleedPenalty] ? 0.02));
                scalar.clip(0.0, cfg[\externalCoherence][\boundedCoherenceAuthorityMax] ? 0.24).round(0.001)
            }
        }
    };

    at[\externalCoherenceUsedSourceSummary] = { |src|
        if(src.isNil) { nil } {
            (
                id: src[\id] ? src[\sourceId] ? \external,
                pc: src[\pc],
                pcName: pitchClassNames[src[\pc]] ? (src[\pc] ? \nil).asString,
                role: src[\coherenceRole] ? \externalPitchEvidence,
                cents: src[\coherenceCents] ? at[\externalCoherenceSourceCents].(src).round(0.01),
                weightBeforeCoherence: (src[\weightBeforeCoherence] ? src[\weight] ? 0.0).round(0.001),
                weightUsed: (src[\weight] ? 0.0).round(0.001),
                confidence: (src[\confidence] ? src[\pitchConfidence] ? 0.0).round(0.001),
                pitchAuthorityEligible: src[\pitchAuthorityEligible] ? true,
                spectralAuthorityEligible: src[\spectralAuthorityEligible] ? false,
                sourceClass: src[\sourceClass] ? \unknown,
                spectrumClass: src[\spectrumClass] ? \unknown,
                kind: src[\kind] ? \unknown,
                liveCaptured: src[\liveCaptured] ? false
            )
        }
    };

    at[\externalCoherenceBridgeReportFor] = { |rawSources, usedSources, report|
        var scalar, bridge;
        scalar = at[\externalCoherenceAuthorityScalarForReport].(report);
        bridge = (
            label: report[\label] ? \liveExternalCoherence,
            status: report[\status] ? \unknown,
            bestWorld: report[\bestWorld] ? \none,
            bestReason: report[\bestReason] ? \none,
            bridgePreparedSourcesToLivePaths: cfg[\externalCoherence][\bridgePreparedSourcesToLivePaths] ? true,
            rawSourceCount: (rawSources ? Array.new).size,
            usedSourceCount: (usedSources ? Array.new).size,
            boundedCoherenceAuthority: scalar,
            usedSources: (usedSources ? Array.new).collect { |src| at[\externalCoherenceUsedSourceSummary].(src) },
            rawRoles: at[\externalCoherenceRoleCounts].(report[\decoratedSources] ? Array.new),
            pitchAuthorityAdded: false,
            topologyAuthorityAdded: false,
            spacingThresholdChange: false,
            abnormalSpectrumChangesPitchCircle: false,
            selfBleedExternalAuthority: false,
            note: \coherencePreparedSourcesAreUsedAsBoundedEvidenceNotPitchCommands
        );
        st[\externalCoherenceBridgeReport] = bridge;
        if(((rawSources ? Array.new).size > 0) or: { (usedSources ? Array.new).size > 0 }) {
            st[\externalCoherenceLastMeaningfulBridge] = bridge;
        };
        st[\externalCoherenceUsedSources] = (usedSources ? Array.new).collect { |src| src.copy };
        st[\externalCoherenceRawSources] = (rawSources ? Array.new).collect { |src| src.copy };
        bridge
    };

    at[\externalCoherencePrepareSources] = { |sources|
        var report, used, bridge;
        if((cfg[\externalCoherence][\enabled] ? true).not or: { (cfg[\externalCoherence][\adaptExternalWeights] ? true).not }) {
            sources ? Array.new
        } {
            report = at[\externalCoherenceAnalyzeScene].(nil, nil, sources, false, \liveExternalCoherence);
            used = (report[\decoratedSources] ? Array.new).select { |src|
                src.notNil and: { src[\active] != false and: { (src[\weight] ? 0.0) > 0.0 and: { src[\pitchAuthorityEligible] != false } } }
            };
            bridge = at[\externalCoherenceBridgeReportFor].(sources ? Array.new, used, report);
            if((cfg[\externalCoherence][\bridgePreparedSourcesToLivePaths] ? true).not) {
                sources ? Array.new
            } {
                used
            }
        }
    };

    at[\externalCoherencePcSource] = { |pc=0, cents=0.0, weight=0.6, confidence=0.9, id="source", sourceClass=\stableTone, spectrumClass=\harmonic, spectralConfidence=0.4, jitter=0.0|
        var phase;
        phase = (pc.asInteger % 12) / 12.0 + (cents.asFloat / 1200.0);
        (
            id: id.asString,
            kind: \externalCoherenceDemo,
            pc: pc.asInteger % 12,
            phase: at[\wrap01].(phase),
            freq: 0.0,
            weight: weight.asFloat.clip(0.0, 1.5),
            confidence: confidence.asFloat.clip(0.0, 1.0),
            pitchConfidence: confidence.asFloat.clip(0.0, 1.0),
            spectralConfidence: spectralConfidence.asFloat.clip(0.0, 1.0),
            sourceClass: sourceClass,
            spectrumClass: spectrumClass,
            jitterCents: jitter.asFloat,
            amp: 0.1,
            stableFrames: 8,
            active: true
        )
    };

    at[\externalCoherenceDemoSources] = { |scenario=\etPlusFlatSingerAbnormal|
        var sources, bleed;
        sources = Array.new;
        if(scenario == \etPianoOnly) {
            sources = sources.add(at[\externalCoherencePcSource].(0, 1.0, 0.70, 0.95, "et-piano-C", \stableTone, \harmonic, 0.35, 1.2));
            sources = sources.add(at[\externalCoherencePcSource].(4, -1.0, 0.68, 0.94, "et-piano-E", \stableTone, \harmonic, 0.35, 1.4));
            sources = sources.add(at[\externalCoherencePcSource].(7, 0.5, 0.66, 0.93, "et-piano-G", \stableTone, \harmonic, 0.35, 1.0));
        } {
            sources = sources.add(at[\externalCoherencePcSource].(0, 2.0, 0.70, 0.95, "et-piano-C", \stableTone, \harmonic, 0.35, 1.2));
            sources = sources.add(at[\externalCoherencePcSource].(4, -2.0, 0.68, 0.94, "et-piano-E", \stableTone, \harmonic, 0.35, 1.4));
            sources = sources.add(at[\externalCoherencePcSource].(7, 1.0, 0.66, 0.93, "et-piano-G", \stableTone, \harmonic, 0.35, 1.0));
            sources = sources.add(at[\externalCoherencePcSource].(4, -27.0, 0.38, 0.52, "novice-singer-flat-E", \voice, \voice, 0.52, 17.0));
            sources = sources.add(at[\externalCoherencePcSource].(2, 44.0, 0.42, 0.22, "abnormal-bell-partial", \abnormalSpectrum, \inharmonic, 0.83, 4.0));
            bleed = at[\externalCoherencePcSource].(0, 0.0, 0.50, 0.90, "self-bleed-epiano-C", \stableTone, \harmonic, 0.72, 0.8);
            bleed[\selfBleed] = true;
            sources = sources.add(bleed);
        };
        sources
    };

    api[\externalCoherenceSceneReport] = { |post=true|
        var activePcs, pcWeights;
        pcWeights = if(at[\pcWeights].notNil) { at[\pcWeights].() } { Array.fill(12, 0.0) };
        activePcs = if(at[\activePcsFromWeights].notNil) { at[\activePcsFromWeights].(pcWeights) } { Array.new };
        at[\externalCoherenceAnalyzeScene].(activePcs, pcWeights, nil, post, \liveExternalCoherence)
    };

    api[\simulateExternalCoherenceScenario] = { |scenario=\etPlusFlatSingerAbnormal, post=true|
        var pcWeights, activePcs, sources, report;
        pcWeights = Array.fill(12, 0.0);
        [0, 4, 7].do { |pc| pcWeights[pc] = 0.72; };
        activePcs = [0, 4, 7];
        sources = at[\externalCoherenceDemoSources].(scenario);
        st[\externalCoherenceDemoSources] = sources.collect { |src| src.copy };
        report = at[\externalCoherenceAnalyzeScene].(activePcs, pcWeights, sources, post, scenario);
        if(post) {
            ("[AT EXTERNAL COHERENCE SIM] scenario=" ++ scenario.asString
                ++ " etInstrumentUnderstood=" ++ report[\etLike].asString
                ++ " flatSingerContext=" ++ (report[\voiceReport][\meanVoiceCents] ? 0.0).asString ++ "c"
                ++ " bestWorld=" ++ report[\bestWorld].asString
                ++ " pitchAuthorityAdded=false").postln;
        };
        report
    };

    api[\externalCoherenceBridgeReport] = { |post=true|
        var raw, used, report, bridge, lastMeaningful;
        raw = if(at[\legacyCurrentExternalSources_v3D40].notNil) { at[\legacyCurrentExternalSources_v3D40].() } {
            if(at[\legacyCurrentExternalSources_v3D39].notNil) { at[\legacyCurrentExternalSources_v3D39].() } { st[\externalSources] ? Array.new }
        };
        report = at[\externalCoherenceAnalyzeScene].(nil, nil, raw, false, \liveExternalCoherence);
        used = at[\externalCoherencePrepareSources].(raw);
        bridge = st[\externalCoherenceBridgeReport] ? at[\externalCoherenceBridgeReportFor].(raw, used, report);
        lastMeaningful = st[\externalCoherenceLastMeaningfulBridge];
        bridge[\lastMeaningfulBridge] = lastMeaningful;
        if(post and: { cfg[\externalCoherence][\bridgeReportEnabled] ? true }) {
            "".postln;
            "[AT EXTERNAL COHERENCE AUTHORITY BRIDGE]".postln;
            ("best=" ++ (bridge[\bestWorld] ? \none).asString
                ++ " rawSources=" ++ (bridge[\rawSourceCount] ? 0).asString
                ++ " usedSources=" ++ (bridge[\usedSourceCount] ? 0).asString
                ++ " boundedAuthority=" ++ (bridge[\boundedCoherenceAuthority] ? 0.0).asString
                ++ " pitchAuthorityAdded=false abnormalSpectrumChangesPitchCircle=false selfBleedExternalAuthority=false").postln;
            ("used=" ++ (bridge[\usedSources] ? Array.new).asString).postln;
            if(((bridge[\rawSourceCount] ? 0) <= 0) and: { lastMeaningful.notNil }) {
                "[AT EXTERNAL COHERENCE LAST MEANINGFUL BRIDGE]".postln;
                ("best=" ++ (lastMeaningful[\bestWorld] ? \none).asString
                    ++ " rawSources=" ++ (lastMeaningful[\rawSourceCount] ? 0).asString
                    ++ " usedSources=" ++ (lastMeaningful[\usedSourceCount] ? 0).asString
                    ++ " boundedAuthority=" ++ (lastMeaningful[\boundedCoherenceAuthority] ? 0.0).asString
                    ++ " pitchAuthorityAdded=false abnormalSpectrumChangesPitchCircle=false selfBleedExternalAuthority=false").postln;
                ("used=" ++ (lastMeaningful[\usedSources] ? Array.new).asString).postln;
            };
        };
        bridge
    };

    api[\externalCoherenceWorldModelReport] = { |post=true| api[\externalCoherenceSceneReport].(post) };
    at[\externalCoherenceSceneReport] = { |post=true| api[\externalCoherenceSceneReport].(post) };
    at[\simulateExternalCoherenceScenario] = { |scenario=\etPlusFlatSingerAbnormal, post=true| api[\simulateExternalCoherenceScenario].(scenario, post) };

    if(at[\legacyCurrentExternalSources_v3D40].isNil and: { at[\currentExternalSources].notNil }) {
        at[\legacyCurrentExternalSources_v3D40] = at[\currentExternalSources];
        previousCurrentExternalSources = at[\legacyCurrentExternalSources_v3D40];
        at[\currentExternalSources] = {
            var raw;
            raw = previousCurrentExternalSources.() ? Array.new;
            at[\externalCoherencePrepareSources].(raw)
        };
    };

    "[AT EXTERNAL COHERENCE] v50 loaded: staged/live source roles are preserved through coherence reports; voices remain voices, abnormal spectra remain spectral-only, and empty scenes still report zero authority.".postln;
};
)
