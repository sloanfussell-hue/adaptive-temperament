(
// AT_mic_poly_response.scd
// Mic Poly Field Response v1.
//
// Mic Field Response v2 made one held pitch-class respond correctly to one
// accepted same-PC external source.  This file extends that behavior to real
// musical situations: chords, sections, chord-clouds, and backing-track scenes.
//
// Main musical law:
//   raw mic data -> scene tracks -> accepted pressure -> poly response
//
// A chord or song scene should not become a swarm of absolute tuning commands.
// Stable external chord tones can pull their matching held pitch classes;
// chordCloud/songScene pressure is softer and slower; externalFollow remains
// the stronger calibration/special-use behavior.
var build, at, cfg, st, api, pitchClassNames, oldBuildReport;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-poly-response] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api]; pitchClassNames = at[\pitchClassNames];

    if(cfg[\micPolyResponse].isNil) {
        cfg[\micPolyResponse] = (
            enabled: true,

            // Multi-note response should be softer than the single same-PC
            // calibration path.  Otherwise a backing track can become a hard
            // external tuning grid.
            duetStableBlend: 0.52,
            duetVibratoBlend: 0.42,
            duetSceneBlend: 0.24,
            duetCloudBlend: 0.28,
            duetGenericBlend: 0.20,
            fullBlendBlend: 0.40,
            externalFollowBlend: 0.90,

            duetPostBlend: 0.42,
            scenePostBlend: 0.24,
            fullBlendPostBlend: 0.40,
            externalFollowPostBlend: 0.88,

            minConfidence: 0.16,
            minWeight: 0.006,
            minMatchedSources: 1,
            preferredMatchedSources: 2,

            maxDuetCorrectionCents: 22.0,
            maxSceneCorrectionCents: 10.0,
            maxExternalFollowCorrectionCents: 42.0,

            passiveMeanBlend: 0.18,
            passiveMaxMeanCorrectionCents: 8.0,
            applyPassiveMeanWhenMatched: 2,

            reportEnabled: true,

            // Live physical poly scene bridge.  In laptop speaker->mic tests and
            // real backing-track use, the mic scene may publish only part of a
            // chord as accepted pressure while the tracker still sees additional
            // same-PC traces.  Those visible traces may weakly fill missing held
            // chord tones.  This uses real mic tracks only; it does not inject
            // truth from the stimulus timeline.
            sceneBridgeEnabled: true,
            sceneBridgeMinTrackConfidence: 0.035,
            sceneBridgeMinTrackWeight: 0.00018,
            sceneBridgeWeightFloor: 0.008,
            sceneBridgeWeightCap: 0.026,
            sceneBridgeConfidenceScale: 0.78
        );
    };

    at[\micPolyPhaseCents] = { |phase, pc|
        if(phase.isNil or: { pc.isNil }) { nil } { at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0 }
    };

    at[\micPolyPhaseFromCents] = { |pc, cents|
        if(pc.isNil or: { cents.isNil }) { nil } { at[\wrap01].(st[\etPhase][pc] + (cents / 1200.0)) }
    };

    at[\micPolyActivePcs] = {
        at[\activePcsFromWeights].(at[\pcWeights].()).sort;
    };

    at[\micPolyAcceptableReason] = { |src|
        var reason, policy;
        if(src.isNil) { false } {
            reason = src[\policyReason] ? \unknown;
            policy = at[\currentMicInfluencePolicy].();
            (policy == \externalFollow) or: {
                (reason == \externalFollow) or: {
                    at[\micResponseSamePcReasons].().includes(reason) or: {
                        [\externalNonSamePcDuet, \fullBlend].includes(reason)
                    }
                }
            }
        }
    };

    at[\micPolyBaseBlendForSource] = { |src|
        var cls, reason, policy, conf, weight, blend;
        if(src.isNil) { 0.0 } {
            cls = src[\sourceClass] ? \unknown;
            reason = src[\policyReason] ? \unknown;
            policy = at[\currentMicInfluencePolicy].();
            conf = src[\confidence] ? src[\policyConfidence] ? 0.0;
            weight = src[\weight] ? src[\policyWeight] ? 0.0;
            if(conf < (cfg[\micPolyResponse][\minConfidence] ? 0.16) or: { weight < (cfg[\micPolyResponse][\minWeight] ? 0.006) }) {
                0.0
            } {
                if(policy == \externalFollow or: { reason == \externalFollow }) {
                    blend = cfg[\micPolyResponse][\externalFollowBlend] ? 0.90;
                } {
                    if(policy == \fullBlend or: { reason == \fullBlend }) {
                        blend = cfg[\micPolyResponse][\fullBlendBlend] ? 0.40;
                    } {
                        if([\songScene].includes(cls)) {
                            blend = cfg[\micPolyResponse][\duetSceneBlend] ? 0.24;
                        } {
                            if([\chordCloud].includes(cls)) {
                                blend = cfg[\micPolyResponse][\duetCloudBlend] ? 0.28;
                            } {
                                if(cls == \stableTone) {
                                    blend = cfg[\micPolyResponse][\duetStableBlend] ? 0.52;
                                } {
                                    if(cls == \vibratoTone) {
                                        blend = cfg[\micPolyResponse][\duetVibratoBlend] ? 0.42;
                                    } {
                                        blend = cfg[\micPolyResponse][\duetGenericBlend] ? 0.20;
                                    }
                                }
                            }
                        }
                    }
                };
                if(src[\externalLatch] == true) { blend = blend + 0.06; };
                blend.clip(0.0, 1.0)
            }
        }
    };

    at[\micPolyPostBlendForSource] = { |src|
        var cls, reason, policy;
        cls = src[\sourceClass] ? \unknown;
        reason = src[\policyReason] ? \unknown;
        policy = at[\currentMicInfluencePolicy].();
        if(policy == \externalFollow or: { reason == \externalFollow }) {
            cfg[\micPolyResponse][\externalFollowPostBlend] ? 0.88
        } {
            if(policy == \fullBlend or: { reason == \fullBlend }) {
                cfg[\micPolyResponse][\fullBlendPostBlend] ? 0.40
            } {
                if([\songScene, \chordCloud].includes(cls)) {
                    cfg[\micPolyResponse][\scenePostBlend] ? 0.24
                } {
                    cfg[\micPolyResponse][\duetPostBlend] ? 0.42
                }
            }
        }
    };

    at[\micPolyMaxCorrectionForSource] = { |src|
        var cls, reason, policy;
        cls = src[\sourceClass] ? \unknown;
        reason = src[\policyReason] ? \unknown;
        policy = at[\currentMicInfluencePolicy].();
        if(policy == \externalFollow or: { reason == \externalFollow }) {
            cfg[\micPolyResponse][\maxExternalFollowCorrectionCents] ? 42.0
        } {
            if([\songScene, \chordCloud].includes(cls)) {
                cfg[\micPolyResponse][\maxSceneCorrectionCents] ? 10.0
            } {
                cfg[\micPolyResponse][\maxDuetCorrectionCents] ? 22.0
            }
        }
    };

    at[\micPolySourceStillPressure] = { |src|
        var cls, missing;
        if(src.isNil) { false } {
            cls = src[\sourceClass] ? \unknown;
            missing = src[\missingFrames] ? 0;
            (src[\active] != false) and: {
                if(cls == \decaying) {
                    missing <= (cfg[\micScene][\decayPressureFrames] ? 2)
                } {
                    true
                }
            }
        }
    };

    at[\micPolySourcesForActivePcs] = { |activePcs, sources|
        var out;
        out = Array.new;
        (activePcs ? Array.new).do { |pc|
            var matching, src;
            matching = (sources ? Array.new).select { |s|
                s.notNil and: { at[\micPolySourceStillPressure].(s) and: { s[\pc] == pc and: { s[\phase].notNil and: { at[\micPolyAcceptableReason].(s) } } } }
            };
            if(matching.notEmpty) {
                src = matching.sort { |a, b| (at[\sourceStrength].(a) ? 0.0) > (at[\sourceStrength].(b) ? 0.0) }[0];
                out = out.add(src);
            };
        };
        out;
    };

    at[\micPolySceneBridgeSourcesForActivePcs] = { |activePcs, exactSources, sources|
        var out, matchedPcs, sceneClass, tracks, minConf, minWeight, weightFloor, weightCap, confScale;
        out = Array.new;
        if((cfg[\micPolyResponse][\sceneBridgeEnabled] ? true).not) {
            out
        } {
            sceneClass = st[\micSceneClass] ? st[\micSceneLastClass] ? \none;
            if([\chordCloud, \songScene].includes(sceneClass).not) {
                out
            } {
                if((sources ? Array.new).isEmpty) {
                    out
                } {
                    matchedPcs = (exactSources ? Array.new).collect { |s| s[\pc] }.as(Set);
                    tracks = st[\micSceneLastTracks] ? Array.new;
                    minConf = cfg[\micPolyResponse][\sceneBridgeMinTrackConfidence] ? 0.035;
                    minWeight = cfg[\micPolyResponse][\sceneBridgeMinTrackWeight] ? 0.00018;
                    weightFloor = cfg[\micPolyResponse][\sceneBridgeWeightFloor] ? 0.008;
                    weightCap = cfg[\micPolyResponse][\sceneBridgeWeightCap] ? 0.026;
                    confScale = cfg[\micPolyResponse][\sceneBridgeConfidenceScale] ? 0.78;
                    (activePcs ? Array.new).do { |pc|
                        var candidates, tr, src;
                        if(matchedPcs.includes(pc).not) {
                            candidates = tracks.select { |t|
                                t.notNil and: {
                                    (t[\pc] == pc) and: {
                                        t[\phase].notNil and: {
                                            (t[\confidence] ? 0.0) >= minConf and: {
                                                (t[\weight] ? 0.0) >= minWeight
                                            }
                                        }
                                    }
                                }
                            };
                            if(candidates.notEmpty) {
                                tr = candidates.sort { |a, b| ((a[\weight] ? 0.0) * (a[\confidence] ? 0.0)) > ((b[\weight] ? 0.0) * (b[\confidence] ? 0.0)) }[0];
                                src = at[\normalizeExternalSource].((
                                    id: ("sceneBridge-" ++ pc.asString),
                                    kind: \micSceneBridge,
                                    pc: pc,
                                    phase: tr[\phase],
                                    freq: tr[\freq] ? 0.0,
                                    weight: ((tr[\weight] ? 0.0).max(weightFloor)).clip(0.0, weightCap),
                                    confidence: ((tr[\confidence] ? 0.0) * confScale).clip(0.0, 1.0),
                                    amp: tr[\amp] ? 0.0,
                                    stableFrames: tr[\stableFrames] ? 0,
                                    active: true
                                ));
                                src[\sourceClass] = sceneClass;
                                src[\trackId] = tr[\id];
                                src[\policyDecision] = \accepted;
                                src[\policyReason] = \liveSceneBridge;
                                src[\projectedFromTrack] = true;
                                src[\missingFrames] = tr[\missingFrames] ? 0;
                                out = out.add(src);
                            };
                        };
                    };
                    out
                }
            }
        }
    };

    at[\micPolyBuildOne] = { |pc, src|
        var defaultPhase, basePhase, externalPhase, oldTargetPhase, baseBlend, postBlend;
        var responsePhase, rawNew, rawOffset, maxCorr, clampedOffset, finalPhase;
        var extC, baseC, oldC, responseC, finalC, desiredDir, actualDir, toward;
        defaultPhase = st[\targetPhase][pc] ? st[\nodePhase][pc] ? st[\etPhase][pc];
        basePhase = at[\micResponseBasePhaseForPc].(pc, defaultPhase);
        externalPhase = src[\phase];
        oldTargetPhase = st[\targetPhase][pc];
        baseBlend = at[\micPolyBaseBlendForSource].(src);
        postBlend = at[\micPolyPostBlendForSource].(src).clip(0.0, 1.0);
        responsePhase = at[\phaseBlend].(basePhase, externalPhase, baseBlend);
        rawNew = at[\phaseBlend].(oldTargetPhase, responsePhase, postBlend);
        rawOffset = at[\wrapSigned].(rawNew - oldTargetPhase);
        maxCorr = (at[\micPolyMaxCorrectionForSource].(src) / 1200.0).abs;
        clampedOffset = rawOffset.clip(maxCorr.neg, maxCorr);
        finalPhase = at[\wrap01].(oldTargetPhase + clampedOffset);

        extC = at[\micPolyPhaseCents].(externalPhase, pc);
        baseC = at[\micPolyPhaseCents].(basePhase, pc);
        oldC = at[\micPolyPhaseCents].(oldTargetPhase, pc);
        responseC = at[\micPolyPhaseCents].(responsePhase, pc);
        finalC = at[\micPolyPhaseCents].(finalPhase, pc);
        desiredDir = if(extC.notNil and: { oldC.notNil }) { (extC - oldC).sign } { 0 };
        actualDir = if(finalC.notNil and: { oldC.notNil }) { (finalC - oldC).sign } { 0 };
        toward = (desiredDir == 0) or: { actualDir == 0 } or: { desiredDir == actualDir };

        (
            pc: pc,
            pcName: pitchClassNames[pc] ? pc.asString,
            sourceId: src[\id],
            sourceClass: src[\sourceClass],
            policyReason: src[\policyReason],
            sourceWeight: (src[\weight] ? 0.0).round(0.001),
            sourceConfidence: (src[\confidence] ? 0.0).round(0.001),
            missingFrames: src[\missingFrames] ? 0,
            externalCents: extC.round(0.01),
            baseCents: baseC.round(0.01),
            oldTargetCents: oldC.round(0.01),
            responseCents: responseC.round(0.01),
            finalTargetCents: finalC.round(0.01),
            baseBlend: baseBlend.round(0.001),
            postBlend: postBlend.round(0.001),
            correctionCents: (clampedOffset * 1200.0).round(0.01),
            towardExternal: toward,
            finalPhase: finalPhase,
            clampedOffset: clampedOffset
        )
    };

    at[\micPolyPostCorrectTarget] = { |reason=\resolve|
        var activePcs, sources, exactMatches, bridgeMatches, matches, reports, offsets, matchedCount, exactMatchedCount, projectedCount, meanOffset, passiveBlend, passiveMax, applyPassive, status;
        if((cfg[\micPolyResponse][\enabled] ? true).not or: { st[\targetPhase].isNil }) {
            st[\lastMicPolyFieldResponse] = (status: \disabledOrNoTarget, reason: reason);
            false
        } {
            activePcs = at[\micPolyActivePcs].();
            sources = if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { st[\externalSources] ? Array.new };
            if(activePcs.size < 2 or: { sources.isEmpty }) {
                st[\lastMicPolyFieldResponse] = (
                    status: \notPoly,
                    reason: reason,
                    activePcs: activePcs,
                    sourceCount: sources.size,
                    sceneClass: st[\micSceneClass],
                    candidateDensity: st[\micSceneCandidateDensity] ? 0,
                    rawDensity: st[\micSceneRawDensity] ? 0,
                    suppressed: (st[\micScenePolicyEvents] ? Array.new).select { |ev| ev[\decision] != \accepted },
                    message: if(activePcs.size < 2) { "Need at least two active MIDI pitch classes for poly response." } { "No accepted mic pressure sources are currently published. Check micSceneReport/policy events." }
                );
                false
            } {
                exactMatches = at[\micPolySourcesForActivePcs].(activePcs, sources);
                bridgeMatches = at[\micPolySceneBridgeSourcesForActivePcs].(activePcs, exactMatches, sources);
                matches = exactMatches ++ bridgeMatches;
                exactMatchedCount = exactMatches.size;
                projectedCount = bridgeMatches.size;
                matchedCount = matches.size;
                if(matchedCount < (cfg[\micPolyResponse][\minMatchedSources] ? 1)) {
                    st[\lastMicPolyFieldResponse] = (
                        status: \noMatchedSources,
                        reason: reason,
                        activePcs: activePcs,
                        sourceCount: sources.size,
                        exactMatchedCount: 0,
                        projectedCount: 0,
                        matchedCount: 0,
                        sceneClass: st[\micSceneClass] ? st[\micSceneLastClass]
                    );
                    false
                } {
                    reports = matches.collect { |src| at[\micPolyBuildOne].(src[\pc], src) };
                    reports.do { |r|
                        st[\targetPhase][r[\pc]] = r[\finalPhase];
                        if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase][r[\pc]] = r[\finalPhase]; };
                    };
                    offsets = reports.collect { |r| r[\clampedOffset] ? 0.0 };
                    meanOffset = if(offsets.isEmpty) { 0.0 } { offsets.sum / offsets.size };
                    applyPassive = matchedCount >= (cfg[\micPolyResponse][\applyPassiveMeanWhenMatched] ? 2);
                    if(applyPassive) {
                        passiveBlend = cfg[\micPolyResponse][\passiveMeanBlend] ? 0.18;
                        passiveMax = ((cfg[\micPolyResponse][\passiveMaxMeanCorrectionCents] ? 8.0) / 1200.0).abs;
                        meanOffset = (meanOffset * passiveBlend).clip(passiveMax.neg, passiveMax);
                        (cfg[\solver][\numNodes] ? 12).do { |pc|
                            if(activePcs.includes(pc).not) {
                                st[\targetPhase][pc] = at[\wrap01].(st[\targetPhase][pc] + meanOffset);
                                if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase][pc] = at[\wrap01].(st[\lastSolvedPhase][pc] + meanOffset); };
                            };
                        };
                    };
                    status = if(projectedCount > 0) { \appliedWithSceneBridge } { \applied };
                    reports.do { |r| if((r[\towardExternal] == true).not) { status = \appliedWithMixedDirections; }; };
                    st[\lastMicPolyFieldResponse] = (
                        status: status,
                        reason: reason,
                        policy: at[\currentMicInfluencePolicy].(),
                        activePcs: activePcs,
                        matchedCount: matchedCount,
                        exactMatchedCount: exactMatchedCount,
                        projectedCount: projectedCount,
                        sourceCount: sources.size,
                        sceneClass: st[\micSceneClass] ? st[\micSceneLastClass],
                        perPc: reports.collect { |r| var c; c = r.copy; c.removeAt(\finalPhase); c.removeAt(\clampedOffset); c },
                        passiveMeanApplied: applyPassive,
                        passiveMeanCorrectionCents: (meanOffset * 1200.0).round(0.01),
                        timestamp: Main.elapsedTime
                    );
                    true
                }
            }
        }
    };

    if(at[\legacyInstallSolvedTarget_MicPolyResponse].isNil and: { at[\installSolvedTarget].notNil }) {
        at[\legacyInstallSolvedTarget_MicPolyResponse] = at[\installSolvedTarget];
        at[\installSolvedTarget] = { |oldPhase, solvedPhase, reason=\resolve|
            at[\legacyInstallSolvedTarget_MicPolyResponse].(oldPhase, solvedPhase, reason);
            at[\micPolyPostCorrectTarget].(reason);
            st[\targetPhase]
        };
    };

    oldBuildReport = at[\buildMicSceneReport];
    if(oldBuildReport.notNil and: { at[\legacyBuildMicSceneReport_MicPolyResponse].isNil }) {
        at[\legacyBuildMicSceneReport_MicPolyResponse] = oldBuildReport;
        at[\buildMicSceneReport] = {
            var rep;
            rep = at[\legacyBuildMicSceneReport_MicPolyResponse].();
            rep[\micPolyFieldResponse] = st[\lastMicPolyFieldResponse];
            rep;
        };
    };

    api[\micPolyFieldResponseReport] = {
        var rep;
        rep = st[\lastMicPolyFieldResponse] ? (status: \none, message: "No mic poly field response has been computed yet.");
        rep.postln;
        rep
    };
    at[\micPolyFieldResponseReport] = { api[\micPolyFieldResponseReport].(); };

    "[at-mic-poly-response] mic poly field response loaded".postln;
};
)
