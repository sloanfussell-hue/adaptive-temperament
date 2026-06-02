(
// AT_external_coherence_world_model.scd
// External Coherence / Ear Intelligence clean runtime model.
// Report + bounded authority integration + live audition proof: classify outside evidence,
// separate pitch authority from spectral/timbral pressure, generate safe bounded coherence
// proposals, publish explicitly enabled bounded external evidence through the existing
// safe external-source path, and prove the live path can be enabled/cleared. Default
// authority remains 0.0.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at-external-coherence] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    cfg[\externalCoherence] = cfg[\externalCoherence] ? (
        enabled: true,
        defaultReportOnly: true,
        authorityAmount: 0.0,
        proposalOnly: true,
        boundedIntegrationEnabled: true,
        maxPublishedExternalSources: 5,
        minPublishedBoundedAuthority: 0.0001,
        pitchAuthorityAdded: false,
        maxRecommendedWorldShiftCents: 12.0,
        maxEffectiveGaugePressureCents: 6.0,
        maxEffectivePassiveShapePressureCents: 9.0,
        etLikeMaxAbsCents: 5.0,
        flatSingerThresholdCents: 10.0,
        abnormalSpectrumThreshold: 0.62,
        minPitchConfidence: 0.20,
        minPitchWeight: 0.01,
        selfBleedBlocked: true,
        abnormalSpectrumChangesPitchCircle: false,
        selfBleedExternalAuthority: false,
        spectralTimbreScale: 0.45
    );

    at[\externalCoherencePcName] = { |pc|
        var idx, names;
        names = pitchClassNames ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
        if(pc.isNil) {
            "none"
        } {
            idx = pc.asInteger % 12;
            names[idx].asString;
        }
    };

    at[\externalCoherencePhaseFromPcCents] = { |pc, cents=0.0|
        if(pc.isNil) {
            nil
        } {
            at[\wrap01].((pc.asFloat / 12.0) + ((cents ? 0.0).asFloat / 1200.0))
        }
    };

    at[\externalCoherenceSource] = { |id, kind=\external, pc=nil, cents=0.0, weight=0.5, confidence=0.8, stability=0.8, spectrumAbnormality=0.0, selfBleed=false, etLike=false, roleHint=\none|
        (
            id: id,
            kind: kind,
            pc: pc,
            cents: cents.asFloat,
            phase: at[\externalCoherencePhaseFromPcCents].(pc, cents),
            weight: weight.asFloat.clip(0.0, 1.5),
            confidence: confidence.asFloat.clip(0.0, 1.0),
            stability: stability.asFloat.clip(0.0, 1.0),
            amp: weight.asFloat.clip(0.0, 1.5),
            spectrumAbnormality: spectrumAbnormality.asFloat.clip(0.0, 1.0),
            selfBleed: selfBleed.asBoolean,
            etLike: etLike.asBoolean,
            roleHint: roleHint,
            active: true
        )
    };

    // v3 bounded authority integration: keep the existing mic/external source
    // function intact, but append explicitly enabled coherence sources. This is
    // the safe integration bridge: no direct pitch-circle rewrite, no direct
    // tuning writes, and self-bleed/abnormal-spectrum pitch evidence remain blocked.
    if(at[\externalCoherenceOriginalCurrentExternalSources].isNil and: { at[\currentExternalSources].notNil }) {
        at[\externalCoherenceOriginalCurrentExternalSources] = at[\currentExternalSources];
        at[\currentExternalSources] = {
            var base, applied;
            base = at[\externalCoherenceOriginalCurrentExternalSources].();
            applied = st[\externalCoherenceAppliedSources] ? Array.new;
            ((base ? Array.new) ++ (applied ? Array.new)).select { |src| src.notNil and: { src[\active] != false } };
        };
    };

    at[\externalCoherenceClassifySource] = { |src|
        var role, kind, cents, conf, weight, abnormal, selfBleed, etLike, threshold;
        role = src[\roleHint] ? \none;
        kind = src[\kind] ? \external;
        cents = src[\cents] ? 0.0;
        conf = src[\confidence] ? 0.0;
        weight = src[\weight] ? 0.0;
        abnormal = src[\spectrumAbnormality] ? 0.0;
        selfBleed = src[\selfBleed] ? false;
        etLike = src[\etLike] ? false;
        threshold = cfg[\externalCoherence][\flatSingerThresholdCents] ? 10.0;

        if(selfBleed) {
            role = \selfBleed;
        } {
            if((conf < (cfg[\externalCoherence][\minPitchConfidence] ? 0.20)) or: { weight < (cfg[\externalCoherence][\minPitchWeight] ? 0.01) }) {
                role = \noiseOrWeakEvidence;
            } {
                if(abnormal >= (cfg[\externalCoherence][\abnormalSpectrumThreshold] ? 0.62)) {
                    role = \abnormalSpectrum;
                } {
                    if((kind == \singer) and: { cents.abs >= threshold }) {
                        if(cents < 0.0) { role = \expressiveFlatVoice } { role = \expressiveSharpVoice };
                    } {
                        if(etLike) {
                            role = \etInstrument;
                        } {
                            if(kind == \singer) { role = \expressiveVoice } { role = \stableExternalPitch };
                        }
                    }
                }
            }
        };
        role
    };

    at[\externalCoherenceNormalizeSource] = { |src|
        var out, role, pc, cents;
        pc = src[\pc];
        cents = src[\cents] ? 0.0;
        out = (
            id: src[\id] ? ((src[\kind] ? \external).asString ++ "-" ++ (pc ? -1).asString),
            kind: src[\kind] ? \external,
            pc: pc,
            pcName: at[\externalCoherencePcName].(pc),
            cents: cents.asFloat,
            phase: src[\phase] ? at[\externalCoherencePhaseFromPcCents].(pc, cents),
            weight: (src[\weight] ? 0.0).asFloat.clip(0.0, 1.5),
            confidence: (src[\confidence] ? 0.0).asFloat.clip(0.0, 1.0),
            stability: (src[\stability] ? 0.0).asFloat.clip(0.0, 1.0),
            spectrumAbnormality: (src[\spectrumAbnormality] ? 0.0).asFloat.clip(0.0, 1.0),
            selfBleed: (src[\selfBleed] ? false).asBoolean,
            etLike: (src[\etLike] ? false).asBoolean,
            roleHint: src[\roleHint] ? \none,
            active: src[\active] ? true
        );
        role = at[\externalCoherenceClassifySource].(out);
        out[\role] = role;
        out[\pitchAuthorityCandidate] = ([\etInstrument, \stableExternalPitch, \expressiveFlatVoice, \expressiveSharpVoice, \expressiveVoice].includes(role));
        out[\spectralAuthorityCandidate] = ((role == \abnormalSpectrum) or: { (out[\spectrumAbnormality] ? 0.0) > 0.18 });
        out
    };

    at[\externalCoherenceWeightedMeanCents] = { |sources|
        var sum, weightSum;
        sum = 0.0;
        weightSum = 0.0;
        (sources ? Array.new).do { |src|
            var w;
            w = ((src[\weight] ? 0.0) * (src[\confidence] ? 0.0) * (src[\stability] ? 0.0)).max(0.0);
            sum = sum + ((src[\cents] ? 0.0) * w);
            weightSum = weightSum + w;
        };
        if(weightSum <= 0.000001) { 0.0 } { sum / weightSum }
    };

    at[\externalCoherenceScenarioSources] = { |scenario=\etCMajor|
        var sources;
        if(scenario.isKindOf(Symbol).not) {
            ("[AT EXTERNAL COHERENCE WARN] invalid scenario argument " ++ scenario.class.asString ++ "; using \etCMajor").warn;
            scenario = \etCMajor;
        };
        sources = Array.new;
        if(scenario == \externalA432) {
            sources = [
                at[\externalCoherenceSource].("external-A432", \instrument, 9, -31.766653633429, 0.80, 0.95, 0.96, 0.02, false, true, \none)
            ];
        } {
            if(scenario == \etCMajor) {
                sources = [
                    at[\externalCoherenceSource].("et-C", \instrument, 0, 0.0, 0.72, 0.95, 0.96, 0.02, false, true, \none),
                    at[\externalCoherenceSource].("et-E", \instrument, 4, 0.0, 0.66, 0.94, 0.95, 0.02, false, true, \none),
                    at[\externalCoherenceSource].("et-G", \instrument, 7, 0.0, 0.68, 0.94, 0.95, 0.02, false, true, \none)
                ];
            } {
            if(scenario == \etGMajor) {
                sources = [
                    at[\externalCoherenceSource].("et-G", \instrument, 7, 0.0, 0.72, 0.95, 0.96, 0.02, false, true, \none),
                    at[\externalCoherenceSource].("et-B", \instrument, 11, 0.0, 0.64, 0.93, 0.95, 0.02, false, true, \none),
                    at[\externalCoherenceSource].("et-D", \instrument, 2, 0.0, 0.66, 0.93, 0.95, 0.02, false, true, \none)
                ];
            } {
                if(scenario == \etPlusFlatSinger) {
                    sources = [
                        at[\externalCoherenceSource].("et-C", \instrument, 0, 0.0, 0.72, 0.95, 0.96, 0.02, false, true, \none),
                        at[\externalCoherenceSource].("et-E", \instrument, 4, 0.0, 0.66, 0.94, 0.95, 0.02, false, true, \none),
                        at[\externalCoherenceSource].("et-G", \instrument, 7, 0.0, 0.68, 0.94, 0.95, 0.02, false, true, \none),
                        at[\externalCoherenceSource].("flat-singer-A", \singer, 9, -31.0, 0.42, 0.68, 0.42, 0.12, false, false, \none)
                    ];
                } {
                    if(scenario == \abnormalSpectrum) {
                        sources = [
                            at[\externalCoherenceSource].("bell-ish-Fsharp", \inharmonicObject, 6, 18.0, 0.50, 0.64, 0.52, 0.88, false, false, \none)
                        ];
                    } {
                        if(scenario == \etPlusAbnormalSpectrum) {
                            sources = [
                                at[\externalCoherenceSource].("et-C", \instrument, 0, 0.0, 0.70, 0.95, 0.96, 0.02, false, true, \none),
                                at[\externalCoherenceSource].("et-E", \instrument, 4, 0.0, 0.64, 0.94, 0.95, 0.02, false, true, \none),
                                at[\externalCoherenceSource].("et-G", \instrument, 7, 0.0, 0.66, 0.94, 0.95, 0.02, false, true, \none),
                                at[\externalCoherenceSource].("abnormal-bell", \inharmonicObject, 6, 21.0, 0.44, 0.62, 0.50, 0.86, false, false, \none)
                            ];
                        } {
                            if(scenario == \selfBleed) {
                                sources = [
                                    at[\externalCoherenceSource].("self-C", \selfOutput, 0, 0.0, 0.80, 0.96, 0.98, 0.04, true, false, \none),
                                    at[\externalCoherenceSource].("self-E", \selfOutput, 4, -13.69, 0.60, 0.90, 0.95, 0.04, true, false, \none)
                                ];
                            } {
                                if(scenario == \mixedWorld) {
                                    sources = [
                                        at[\externalCoherenceSource].("et-C", \instrument, 0, 0.0, 0.72, 0.95, 0.96, 0.02, false, true, \none),
                                        at[\externalCoherenceSource].("et-E", \instrument, 4, 0.0, 0.64, 0.94, 0.95, 0.02, false, true, \none),
                                        at[\externalCoherenceSource].("et-G", \instrument, 7, 0.0, 0.66, 0.94, 0.95, 0.02, false, true, \none),
                                        at[\externalCoherenceSource].("flat-singer-A", \singer, 9, -28.0, 0.38, 0.66, 0.40, 0.10, false, false, \none),
                                        at[\externalCoherenceSource].("abnormal-metal", \inharmonicObject, 6, 19.0, 0.40, 0.60, 0.48, 0.84, false, false, \none),
                                        at[\externalCoherenceSource].("self-leak-C", \selfOutput, 0, 0.0, 0.62, 0.94, 0.96, 0.04, true, false, \none),
                                        at[\externalCoherenceSource].("room-noise", \noise, nil, 0.0, 0.12, 0.10, 0.10, 0.30, false, false, \none)
                                    ];
                                } {
                                    sources = [
                                        at[\externalCoherenceSource].("default-et-C", \instrument, 0, 0.0, 0.70, 0.90, 0.90, 0.02, false, true, \none),
                                        at[\externalCoherenceSource].("default-et-E", \instrument, 4, 0.0, 0.60, 0.90, 0.90, 0.02, false, true, \none),
                                        at[\externalCoherenceSource].("default-et-G", \instrument, 7, 0.0, 0.60, 0.90, 0.90, 0.02, false, true, \none)
                                    ];
                                }
                            }
                        }
                    }
                }
            }
            };
        };
        sources
    };

    at[\externalCoherenceAnalyzeScene] = { |rawSources, scenarioName=\custom|
        var sources, usedPitch, usedSpectrum, rejectedSelf, rejectedAbnormalPitch, rejectedWeak, etSources, singerSources, abnormalSources, roles, pcs, cents, centerPc, etLike, flatSingerCents, abnormalMax, weightedMean, recommendedShift, timbreAdapt, decision, rationale, boundedAuthority, report;
        sources = (rawSources ? Array.new).collect { |src| at[\externalCoherenceNormalizeSource].(src) };
        usedPitch = sources.select { |src| (src[\pitchAuthorityCandidate] ? false) and: { (src[\selfBleed] ? false).not } };
        usedSpectrum = sources.select { |src| (src[\spectralAuthorityCandidate] ? false) and: { (src[\selfBleed] ? false).not } };
        rejectedSelf = sources.select { |src| src[\role] == \selfBleed };
        rejectedAbnormalPitch = sources.select { |src| src[\role] == \abnormalSpectrum };
        rejectedWeak = sources.select { |src| src[\role] == \noiseOrWeakEvidence };
        etSources = sources.select { |src| src[\role] == \etInstrument };
        singerSources = sources.select { |src| [\expressiveFlatVoice, \expressiveSharpVoice, \expressiveVoice].includes(src[\role]) };
        abnormalSources = sources.select { |src| src[\role] == \abnormalSpectrum };
        roles = sources.collect { |src| src[\role] };
        pcs = usedPitch.collect { |src| src[\pc] }.reject { |pc| pc.isNil };
        cents = usedPitch.collect { |src| src[\cents] ? 0.0 };
        centerPc = if(etSources.notEmpty) { etSources[0][\pc] } { if(usedPitch.notEmpty) { usedPitch[0][\pc] } { nil } };
        etLike = (etSources.size >= 3) and: { etSources.collect { |src| (src[\cents] ? 0.0).abs }.maxItem <= (cfg[\externalCoherence][\etLikeMaxAbsCents] ? 5.0) };
        flatSingerCents = if(singerSources.isEmpty) { nil } { at[\externalCoherenceWeightedMeanCents].(singerSources) };
        abnormalMax = if(abnormalSources.isEmpty) { 0.0 } { abnormalSources.collect { |src| src[\spectrumAbnormality] ? 0.0 }.maxItem };
        weightedMean = at[\externalCoherenceWeightedMeanCents].(usedPitch);
        recommendedShift = (weightedMean * 0.35).clip((cfg[\externalCoherence][\maxRecommendedWorldShiftCents] ? 12.0).neg, cfg[\externalCoherence][\maxRecommendedWorldShiftCents] ? 12.0);
        timbreAdapt = (abnormalMax * (cfg[\externalCoherence][\spectralTimbreScale] ? 0.45)).clip(0.0, 1.0);
        boundedAuthority = (cfg[\externalCoherence][\authorityAmount] ? 0.0).clip(0.0, 1.0);

        decision = \ignoreAsNoise;
        rationale = "no confident external evidence";
        if(rejectedSelf.size == sources.size and: { sources.notEmpty }) {
            decision = \selfBleedBlocked;
            rationale = "all detected evidence is self-output; no external authority";
        } {
            if(usedPitch.isEmpty and: { usedSpectrum.notEmpty }) {
                decision = \spectralTimbreOnly;
                rationale = "abnormal spectrum is timbral/roughness evidence, not pitch-circle authority";
            } {
                if(etLike and: { singerSources.notEmpty }) {
                    decision = \boundedCoherence;
                    rationale = "ET grid plus expressive singer requires coherent compromise";
                } {
                    if(etLike and: { abnormalSources.notEmpty }) {
                        decision = \boundedCoherence;
                        rationale = "ET grid plus abnormal spectrum: pitch context and timbral pressure stay separate";
                    } {
                        if(etLike) {
                            decision = \equalTemperamentGridContext;
                            rationale = "stable external ET grid should be fit where necessary, not overwritten by pure ratios";
                        } {
                            if(usedPitch.notEmpty) {
                                decision = \boundedCoherence;
                                rationale = "external pitch evidence is present but not a complete tuning system";
                            }
                        }
                    }
                }
            }
        };

        report = (
            branch: \externalCoherenceWorldModel_v5b,
            scenario: scenarioName,
            rawCount: sources.size,
            usedPitchCount: usedPitch.size,
            usedSpectrumCount: usedSpectrum.size,
            rejectedSelfBleedCount: rejectedSelf.size,
            rejectedAbnormalPitchCount: rejectedAbnormalPitch.size,
            rejectedWeakCount: rejectedWeak.size,
            roles: roles,
            usedPcs: pcs,
            usedPcNames: pcs.collect { |pc| at[\externalCoherencePcName].(pc) },
            usedCents: cents.collect { |c| c.round(0.01) },
            centerPc: centerPc,
            centerName: at[\externalCoherencePcName].(centerPc),
            etLikeGrid: etLike,
            externalGrid: if(etLike) { \equalTemperamentLike } { \noneOrMixed },
            flatSingerCents: if(flatSingerCents.isNil) { nil } { flatSingerCents.round(0.01) },
            abnormalSpectrumMax: abnormalMax.round(0.001),
            decision: decision,
            rationale: rationale,
            recommendedWorldShiftCents: recommendedShift.round(0.01),
            recommendedTimbreAdaptAmount: timbreAdapt.round(0.001),
            boundedAuthority: boundedAuthority,
            reportOnly: (boundedAuthority <= 0.0001),
            pitchAuthorityAdded: false,
            pitchCircleRewrite: false,
            abnormalSpectrumChangesPitchCircle: false,
            selfBleedExternalAuthority: false,
            memoryGravityRemainContext: true,
            coherenceNotPurity: true,
            rawSources: sources,
            usedPitchSources: usedPitch,
            usedSpectrumSources: usedSpectrum
        );
        st[\externalCoherenceRawSources] = sources;
        st[\externalCoherenceUsedPitchSources] = usedPitch;
        st[\externalCoherenceUsedSpectrumSources] = usedSpectrum;
        st[\externalCoherenceDecisionReport] = report;
        st[\externalCoherenceSceneReport] = report;
        report
    };

    at[\externalCoherencePrintReport] = { |report|
        var line;
        line = "[AT EXTERNAL COHERENCE] scenario=" ++ (report[\scenario] ? \none).asString
            ++ " raw=" ++ (report[\rawCount] ? 0).asString
            ++ " pitch=" ++ (report[\usedPitchCount] ? 0).asString
            ++ " spectrum=" ++ (report[\usedSpectrumCount] ? 0).asString
            ++ " roles=" ++ (report[\roles] ? Array.new).asString
            ++ " pcs=" ++ (report[\usedPcs] ? Array.new).asString
            ++ " grid=" ++ (report[\externalGrid] ? \none).asString
            ++ " center=" ++ (report[\centerName] ? "none").asString
            ++ " flatSinger=" ++ (report[\flatSingerCents] ? "none").asString
            ++ " abnormalMax=" ++ (report[\abnormalSpectrumMax] ? 0.0).asString
            ++ " decision=" ++ (report[\decision] ? \none).asString
            ++ " shift=" ++ (report[\recommendedWorldShiftCents] ? 0.0).asString
            ++ " timbreAdapt=" ++ (report[\recommendedTimbreAdaptAmount] ? 0.0).asString
            ++ " reportOnly=" ++ (report[\reportOnly] ? true).asString
            ++ " pitchAuthorityAdded=" ++ (report[\pitchAuthorityAdded] ? false).asString
            ++ " pitchCircleRewrite=" ++ (report[\pitchCircleRewrite] ? false).asString
            ++ " selfBleedAuthority=" ++ (report[\selfBleedExternalAuthority] ? false).asString;
        line.postln;
        report
    };

    at[\externalCoherenceDecisionBaseAuthority] = { |decision|
        if(decision == \boundedCoherence) {
            0.62
        } {
            if(decision == \equalTemperamentGridContext) {
                0.36
            } {
                if(decision == \spectralTimbreOnly) {
                    0.18
                } {
                    if(decision == \selfBleedBlocked) { 0.0 } { 0.10 }
                }
            }
        }
    };

    at[\externalCoherenceBuildAuthorityProposal] = { |report|
        var amount, decision, baseAuthority, boundedAuthority, recommendedShift, timbreAdapt, flatSingerCents, gridPull, flatAccommodation, effectiveGauge, effectivePassive, effectiveTimbre, abnormalBlocked, selfBleedBlocked, proposal;
        amount = (cfg[\externalCoherence][\authorityAmount] ? 0.0).asFloat.clip(0.0, 1.0);
        decision = report[\decision] ? \ignoreAsNoise;
        baseAuthority = at[\externalCoherenceDecisionBaseAuthority].(decision);
        boundedAuthority = (amount * baseAuthority).clip(0.0, 0.65);
        recommendedShift = (report[\recommendedWorldShiftCents] ? 0.0).asFloat;
        timbreAdapt = (report[\recommendedTimbreAdaptAmount] ? 0.0).asFloat.clip(0.0, 1.0);
        flatSingerCents = report[\flatSingerCents];
        gridPull = if(report[\externalGrid] == \equalTemperamentLike) { baseAuthority.max(0.22) } { 0.0 };
        flatAccommodation = if(flatSingerCents.isNil) { 0.0 } { (flatSingerCents.asFloat * 0.08).clip(-6.0, 6.0) };
        effectiveGauge = (recommendedShift * boundedAuthority).clip((cfg[\externalCoherence][\maxEffectiveGaugePressureCents] ? 6.0).neg, cfg[\externalCoherence][\maxEffectiveGaugePressureCents] ? 6.0);
        effectivePassive = ((recommendedShift + flatAccommodation) * boundedAuthority).clip((cfg[\externalCoherence][\maxEffectivePassiveShapePressureCents] ? 9.0).neg, cfg[\externalCoherence][\maxEffectivePassiveShapePressureCents] ? 9.0);
        effectiveTimbre = (timbreAdapt * (if(decision == \spectralTimbreOnly) { 1.0 } { 0.72 }) * (0.25 + (0.75 * amount))).clip(0.0, 1.0);
        abnormalBlocked = (report[\rejectedAbnormalPitchCount] ? 0) > 0;
        selfBleedBlocked = (report[\rejectedSelfBleedCount] ? 0) > 0 or: { decision == \selfBleedBlocked };
        proposal = (
            branch: \externalCoherenceAuthorityBridge_v5b,
            scenario: report[\scenario] ? \none,
            decision: decision,
            authorityAmount: amount.round(0.001),
            decisionBaseAuthority: baseAuthority.round(0.001),
            boundedAuthority: boundedAuthority.round(0.001),
            proposalOnly: true,
            applied: false,
            tuningWrites: false,
            pitchAuthorityApplied: false,
            pitchAuthorityAdded: false,
            pitchCircleRewrite: false,
            selfBleedExternalAuthority: false,
            abnormalSpectrumChangesPitchCircle: false,
            abnormalPitchRejected: abnormalBlocked,
            selfBleedBlocked: selfBleedBlocked,
            memoryGravityRemainContext: true,
            externalGridPull: gridPull.round(0.001),
            externalGridCenterPc: report[\centerPc],
            externalGridCenterName: report[\centerName] ? "none",
            flatSingerAccommodationCents: flatAccommodation.round(0.01),
            recommendedGaugeShiftCents: recommendedShift.round(0.01),
            effectiveGaugePressureCents: effectiveGauge.round(0.01),
            recommendedPassiveShapePressureCents: (recommendedShift + flatAccommodation).round(0.01),
            effectivePassiveShapePressureCents: effectivePassive.round(0.01),
            recommendedTimbreAdaptAmount: timbreAdapt.round(0.001),
            effectiveTimbreAdaptAmount: effectiveTimbre.round(0.001),
            coherenceNotPurity: true,
            authoritySummary: if(amount <= 0.0001) { \reportOnlyPreview } { \boundedProposalPreview }
        );
        proposal
    };

    at[\externalCoherenceAppliedSourceFromNormalized] = { |src, proposal|
        var bounded, weight, conf, stab, phase;
        bounded = (proposal[\boundedAuthority] ? 0.0).asFloat.clip(0.0, 1.0);
        conf = (src[\confidence] ? 0.0).asFloat.clip(0.0, 1.0);
        stab = (src[\stability] ? 0.0).asFloat.clip(0.0, 1.0);
        weight = ((src[\weight] ? 0.0).asFloat * conf.max(0.25) * stab.max(0.25) * bounded).clip(0.0, 0.28);
        phase = src[\phase] ? at[\externalCoherencePhaseFromPcCents].(src[\pc], src[\cents] ? 0.0);
        (
            id: "externalCoherence-" ++ (src[\id] ? "source").asString,
            kind: \externalCoherence,
            pc: src[\pc],
            phase: phase,
            freq: 0.0,
            weight: weight,
            confidence: conf,
            amp: weight,
            stableFrames: (stab * 8.0).round(1).asInteger.max(1),
            stability: stab,
            phaseVelocity: 0.0,
            age: 0,
            sourceRole: \externalCoherenceBounded,
            targetMidi: nil,
            active: true,
            coherenceRole: src[\role],
            externalCoherenceBoundedAuthority: bounded,
            externalCoherenceScenario: proposal[\scenario]
        )
    };

    at[\externalCoherenceApplyAuthorityProposal] = { |report|
        var proposal, amount, decision, pitchSources, published, effectiveTimbre, canPublish, result, maxPub, minAuth;
        proposal = report[\authorityProposal] ? at[\externalCoherenceBuildAuthorityProposal].(report);
        amount = (proposal[\authorityAmount] ? 0.0).asFloat.clip(0.0, 1.0);
        decision = proposal[\decision] ? (report[\decision] ? \none);
        pitchSources = report[\usedPitchSources] ? Array.new;
        maxPub = (cfg[\externalCoherence][\maxPublishedExternalSources] ? 5).asInteger.max(1);
        minAuth = (cfg[\externalCoherence][\minPublishedBoundedAuthority] ? 0.0001).asFloat;
        canPublish = (amount > minAuth) and: { decision != \selfBleedBlocked };
        published = Array.new;
        effectiveTimbre = 0.0;
        if(canPublish) {
            published = pitchSources.select { |src|
                (src[\selfBleed] ? false).not and: { src[\role] != \abnormalSpectrum }
            }.collect { |src|
                at[\externalCoherenceAppliedSourceFromNormalized].(src, proposal)
            }.select { |src|
                (src[\weight] ? 0.0) > 0.0001
            };
            if(published.size > maxPub) { published = published.copyRange(0, maxPub - 1); };
            effectiveTimbre = (proposal[\effectiveTimbreAdaptAmount] ? 0.0).asFloat.clip(0.0, 1.0);
        };
        st[\externalCoherenceAppliedSources] = published;
        st[\externalCoherenceAppliedTimbreAdaptAmount] = effectiveTimbre;
        st[\externalCoherenceAppliedReport] = report;
        st[\externalCoherenceAppliedProposal] = proposal;
        result = proposal.copy;
        result[\branch] = \externalCoherenceBoundedAuthority_v3;
        result[\proposalOnly] = false;
        result[\applied] = canPublish and: { published.notEmpty or: { effectiveTimbre > 0.0001 } };
        result[\publishedExternalSourceCount] = published.size;
        result[\publishedExternalPcs] = published.collect { |src| src[\pc] };
        result[\externalSourcesPublished] = published.notEmpty;
        result[\pitchAuthorityApplied] = published.notEmpty;
        result[\pitchAuthorityAdded] = published.notEmpty;
        result[\directTuningWrites] = false;
        result[\tuningWrites] = false;
        result[\effectiveTimbreAdaptAmount] = effectiveTimbre.round(0.001);
        result[\boundedIntegrationEnabled] = true;
        st[\externalCoherenceAppliedResult] = result;
        if((result[\applied] ? false) and: { api[\resolveNow].notNil }) {
            api[\resolveNow].(\externalCoherenceBoundedAuthority);
        };
        result
    };

    at[\externalCoherenceBridgeReportFromScene] = { |rawSources, scenarioName=\custom|
        var report, proposal, bridgeReport;
        report = at[\externalCoherenceAnalyzeScene].(rawSources, scenarioName);
        proposal = at[\externalCoherenceBuildAuthorityProposal].(report);
        bridgeReport = report.copy;
        bridgeReport[\branch] = \externalCoherenceAuthorityBridge_v3;
        bridgeReport[\authorityProposal] = proposal;
        bridgeReport[\boundedAuthority] = proposal[\boundedAuthority];
        bridgeReport[\authorityAmount] = proposal[\authorityAmount];
        bridgeReport[\proposalOnly] = true;
        bridgeReport[\pitchAuthorityApplied] = false;
        bridgeReport[\pitchAuthorityAdded] = false;
        bridgeReport[\tuningWrites] = false;
        bridgeReport[\effectiveGaugePressureCents] = proposal[\effectiveGaugePressureCents];
        bridgeReport[\effectivePassiveShapePressureCents] = proposal[\effectivePassiveShapePressureCents];
        bridgeReport[\effectiveTimbreAdaptAmount] = proposal[\effectiveTimbreAdaptAmount];
        st[\externalCoherenceAuthorityProposal] = proposal;
        st[\externalCoherenceAuthorityBridgeReport] = bridgeReport;
        bridgeReport
    };

    at[\externalCoherencePrintBridgeReport] = { |report|
        var p, line;
        p = report[\authorityProposal] ? at[\externalCoherenceBuildAuthorityProposal].(report);
        line = "[AT EXTERNAL COHERENCE BRIDGE] scenario=" ++ (report[\scenario] ? \none).asString
            ++ " decision=" ++ (report[\decision] ? \none).asString
            ++ " grid=" ++ (report[\externalGrid] ? \none).asString
            ++ " center=" ++ (report[\centerName] ? "none").asString
            ++ " flatSinger=" ++ (report[\flatSingerCents] ? "none").asString
            ++ " abnormalMax=" ++ (report[\abnormalSpectrumMax] ? 0.0).asString
            ++ " authorityAmount=" ++ (p[\authorityAmount] ? 0.0).asString
            ++ " boundedAuthority=" ++ (p[\boundedAuthority] ? 0.0).asString
            ++ " gridPull=" ++ (p[\externalGridPull] ? 0.0).asString
            ++ " gaugeProposal=" ++ (p[\recommendedGaugeShiftCents] ? 0.0).asString
            ++ " effectiveGauge=" ++ (p[\effectiveGaugePressureCents] ? 0.0).asString
            ++ " passiveProposal=" ++ (p[\recommendedPassiveShapePressureCents] ? 0.0).asString
            ++ " timbreAdapt=" ++ (p[\recommendedTimbreAdaptAmount] ? 0.0).asString
            ++ " pitchApplied=" ++ (p[\pitchAuthorityApplied] ? false).asString
            ++ " applied=" ++ (p[\applied] ? false).asString
            ++ " selfBleedBlocked=" ++ (p[\selfBleedBlocked] ? false).asString
            ++ " abnormalPitchRejected=" ++ (p[\abnormalPitchRejected] ? false).asString;
        line.postln;
        report
    };

    api[\simulateExternalCoherenceScenario] = { |scenario=\etCMajor, print=true|
        var sources, report;
        sources = at[\externalCoherenceScenarioSources].(scenario);
        report = at[\externalCoherenceAnalyzeScene].(sources, scenario);
        if(print ? true) { at[\externalCoherencePrintReport].(report); };
        report
    };

    api[\simulateExternalCoherenceAuthorityScenario] = { |scenario=\etCMajor, print=true|
        var sources, report;
        sources = at[\externalCoherenceScenarioSources].(scenario);
        report = at[\externalCoherenceBridgeReportFromScene].(sources, scenario);
        if(print ? true) { at[\externalCoherencePrintBridgeReport].(report); };
        report
    };

    at[\externalCoherencePrintBoundedAuthorityReport] = { |report|
        var p, line;
        p = report[\authorityApplication] ? (report[\authorityProposal] ? at[\externalCoherenceBuildAuthorityProposal].(report));
        line = "[AT EXTERNAL COHERENCE AUTHORITY] scenario=" ++ (report[\scenario] ? \none).asString
            ++ " decision=" ++ (report[\decision] ? \none).asString
            ++ " amount=" ++ (p[\authorityAmount] ? 0.0).asString
            ++ " boundedAuthority=" ++ (p[\boundedAuthority] ? 0.0).asString
            ++ " applied=" ++ (p[\applied] ? false).asString
            ++ " published=" ++ (p[\publishedExternalSourceCount] ? 0).asString
            ++ " pcs=" ++ (p[\publishedExternalPcs] ? Array.new).asString
            ++ " effectiveGauge=" ++ (p[\effectiveGaugePressureCents] ? 0.0).asString
            ++ " passive=" ++ (p[\effectivePassiveShapePressureCents] ? 0.0).asString
            ++ " timbre=" ++ (p[\effectiveTimbreAdaptAmount] ? 0.0).asString
            ++ " pitchApplied=" ++ (p[\pitchAuthorityApplied] ? false).asString
            ++ " directWrites=" ++ (p[\directTuningWrites] ? false).asString
            ++ " selfBleedBlocked=" ++ (p[\selfBleedBlocked] ? false).asString
            ++ " abnormalPitchRejected=" ++ (p[\abnormalPitchRejected] ? false).asString;
        line.postln;
        report
    };

    api[\simulateExternalCoherenceBoundedAuthorityScenario] = { |scenario=\mixedWorld, amount=nil, print=true|
        var sources, report, application;
        if(amount.notNil) { api[\externalCoherenceSetAuthorityAmount].(amount); };
        sources = at[\externalCoherenceScenarioSources].(scenario);
        report = at[\externalCoherenceBridgeReportFromScene].(sources, scenario);
        application = at[\externalCoherenceApplyAuthorityProposal].(report);
        report[\authorityApplication] = application;
        st[\externalCoherenceBoundedAuthorityReport] = report;
        if(print ? true) { at[\externalCoherencePrintBoundedAuthorityReport].(report); };
        report
    };

    api[\clearExternalCoherenceAppliedAuthority] = {
        st[\externalCoherenceAppliedSources] = Array.new;
        st[\externalCoherenceAppliedTimbreAdaptAmount] = 0.0;
        st[\externalCoherenceAppliedReport] = nil;
        st[\externalCoherenceAppliedProposal] = nil;
        st[\externalCoherenceAppliedResult] = nil;
        st[\externalCoherenceBoundedAuthorityReport] = nil;
        if(api[\resolveNow].notNil) { api[\resolveNow].(\externalCoherenceAuthorityCleared); };
        "[AT EXTERNAL COHERENCE] bounded authority application cleared".postln;
        true
    };

    api[\externalCoherenceBoundedAuthoritySnapshot] = {
        st[\externalCoherenceAppliedResult] ? (
            branch: \externalCoherenceHumanListening_v5b,
            applied: false,
            publishedExternalSourceCount: 0,
            effectiveTimbreAdaptAmount: 0.0,
            authorityAmount: cfg[\externalCoherence][\authorityAmount] ? 0.0
        )
    };

    api[\externalCoherenceSceneReport] = {
        st[\externalCoherenceSceneReport] ? at[\externalCoherenceAnalyzeScene].(Array.new, \none)
    };

    api[\externalCoherenceDecisionReport] = {
        st[\externalCoherenceDecisionReport] ? api[\externalCoherenceSceneReport].()
    };

    api[\externalCoherenceAuthorityBridgeReport] = {
        st[\externalCoherenceAuthorityBridgeReport] ? api[\simulateExternalCoherenceAuthorityScenario].(\mixedWorld, false)
    };

    api[\clearExternalCoherenceScene] = {
        st[\externalCoherenceRawSources] = Array.new;
        st[\externalCoherenceUsedPitchSources] = Array.new;
        st[\externalCoherenceUsedSpectrumSources] = Array.new;
        st[\externalCoherenceDecisionReport] = nil;
        st[\externalCoherenceSceneReport] = nil;
        st[\externalCoherenceAuthorityProposal] = nil;
        st[\externalCoherenceAuthorityBridgeReport] = nil;
        "[AT EXTERNAL COHERENCE] cleared report-only scene state".postln;
        true
    };

    api[\externalCoherenceSetAuthorityAmount] = { |amount=0.0|
        var v;
        v = amount.asFloat.clip(0.0, 1.0);
        cfg[\externalCoherence][\authorityAmount] = v;
        ("[AT EXTERNAL COHERENCE] authority bridge scalar=" ++ v.round(0.001).asString ++ " (bounded integration scalar; amount 0 is report-only, positive values publish guarded external sources)").postln;
        v
    };

    api[\externalCoherenceAuthoritySetAmount] = { |amount=0.0|
        api[\externalCoherenceSetAuthorityAmount].(amount)
    };


    ~atExternalCoherence = (
        report: { api[\externalCoherenceSceneReport].() },
        bridge: { api[\externalCoherenceAuthorityBridgeReport].() },
        applyScene: { |scenario=\mixedWorld, amount=0.2| api[\applyExternalCoherenceBoundedAuthority].(scenario, amount) },
        clearAuthority: { api[\clearExternalCoherenceAuthority].() }
    );

    "[at-external-coherence] clean runtime model loaded; bounded external authority remains guarded.".postln;
};
)
