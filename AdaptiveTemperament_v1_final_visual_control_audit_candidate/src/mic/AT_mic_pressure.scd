(
// AT_mic_pressure.scd
// Final mic-scene pressure publisher. This overrides the legacy source commit
// function so the field sees only classified, policy-approved, rate-limited
// acoustic pressure.
var build, at, cfg, st;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-pressure] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state];

    if(at[\legacyUpdateCommittedExternalSources].isNil and: { at[\updateCommittedExternalSources].notNil }) {
        at[\legacyUpdateCommittedExternalSources] = at[\updateCommittedExternalSources];
    };

    at[\micScenePrepareSources] = { |candidates|
        var activePcs, tracks, classified, accepted, sceneClass, limit;
        activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
        tracks = at[\micSceneTrackCandidates].(candidates ? Array.new);
        classified = at[\classifyMicTracks].(tracks);
        sceneClass = at[\micSceneClassForTracks].(classified);
        st[\micSceneClass] = sceneClass;
        accepted = at[\micPolicyApply].(classified, activePcs);

        limit = if(sceneClass == \songScene or: { sceneClass == \chordCloud }) {
            (cfg[\micScene][\chordCloudMaxSources] ? 3).asInteger.max(1)
        } {
            at[\effectiveExternalSourceLimit].(activePcs)
        };
        accepted = at[\takeStrongestSources].(accepted, limit);
        [accepted, classified, sceneClass]
    };

    at[\micSceneMaybePublishPressure] = { |sources, sceneClass, reason=\micScene|
        var now, oldSources, newKey, oldKey, interval, structural, doPublish;
        now = Main.elapsedTime;
        sources = sources ? Array.new;
        oldSources = st[\externalSources] ? Array.new;
        newKey = at[\micSceneKeyForSources].(sources, sceneClass);
        oldKey = st[\micScenePressureKey];
        interval = at[\micSceneMinDirtyInterval].(sceneClass);
        structural = at[\micSceneStructuralChange].(oldSources, sources);
        doPublish = false;

        if(newKey != oldKey) {
            if(structural) {
                doPublish = true;
            } {
                if(st[\micSceneLastPressureAt].isNil or: { (now - st[\micSceneLastPressureAt]) >= interval }) {
                    doPublish = true;
                };
            };
        };

        if(doPublish) {
            if(sources.notEmpty) {
                if(at[\clearMicReleaseHold].notNil) { at[\clearMicReleaseHold].(\newExternalPressure); };
            } {
                if(oldSources.notEmpty and: { at[\activateMicReleaseHold].notNil }) {
                    at[\activateMicReleaseHold].(oldSources, reason);
                };
            };
            st[\externalSources] = sources.collect { |src| src.copy };
            st[\micSceneAcceptedSources] = st[\externalSources].collect { |src| src.copy };
            st[\micScenePressureKey] = newKey;
            st[\micSceneLastPressureAt] = now;
            st[\micSceneLastPressureReason] = reason;
            st[\lastMicKey] = newKey;
            st[\micCommittedByPc] = Array.fill(cfg[\solver][\numNodes], { nil });
            st[\externalSources].do { |src|
                if(src[\pc].notNil) { st[\micCommittedByPc][src[\pc]] = src.copy; };
            };
            if(st[\externalSources].notEmpty) {
                at[\markEvidenceDirty].(reason);
            } {
                at[\markEvidenceDirty].(\micSceneCleared);
            };
        } {
            if(newKey != oldKey) {
                st[\micSceneDirtySuppressedCount] = (st[\micSceneDirtySuppressedCount] ? 0) + 1;
            };
        };
        st[\externalSources]
    };

    at[\updateCommittedExternalSources] = { |candidates|
        var activePcs, policy, blocked, prepared, sources, tracks, sceneClass, oldSources;
        activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
        policy = at[\currentMicInfluencePolicy].();
        st[\micScenePolicy] = policy;
        blocked = at[\micInfluenceBlocked].(activePcs);
        st[\micInfluenceBlocked] = blocked;
        oldSources = st[\externalSources] ? Array.new;

        if((cfg[\micScene][\enabled] ? true).not) {
            at[\legacyUpdateCommittedExternalSources].(candidates);
        } {
            if(policy == \debugRaw) {
                var proposed;
                proposed = at[\takeStrongestSources].(
                    at[\micSceneNormalizeCandidates].(candidates).select { |src|
                        (src[\confidence] ? 0.0) >= ((cfg[\mic][\minConfidence] ? 0.2) * 0.25)
                    },
                    at[\effectiveExternalSourceLimit].(activePcs)
                ).collect { |src|
                    var out;
                    out = at[\normalizeExternalSource].(src.copy.putAll((
                        kind: \micScene,
                        weight: ((src[\weight] ? 0.0) * (cfg[\micScene][\rawDebugScale] ? 0.02)).clip(0.0, cfg[\micScene][\debugRawMaxWeight] ? 0.02),
                        confidence: ((src[\confidence] ? 0.0) * 0.85).clip(0.0, 1.0),
                        active: true
                    )));
                    out[\sourceClass] = \debugRaw;
                    out[\policyDecision] = \accepted;
                    out[\policyReason] = \debugRaw;
                    out
                };
                st[\micSceneClass] = \debugRaw;
                at[\micSceneMaybePublishPressure].(proposed, \debugRaw, \debugRaw);
            } {
                if(blocked or: { policy == \off } or: { policy == \monitor }) {
                    // Still update tracks for monitor/diagnostics, but publish no pressure.
                    prepared = at[\micScenePrepareSources].(candidates ? Array.new);
                    tracks = prepared[1];
                    st[\micSceneClass] = prepared[2];
                    st[\micSceneAcceptedSources] = Array.new;
                    if(oldSources.notEmpty and: { at[\activateMicReleaseHold].notNil }) {
                        at[\activateMicReleaseHold].(oldSources, \micSceneBlockedClear);
                    };
                    st[\externalSources] = Array.new;
                    st[\micScenePressureKey] = nil;
                    if(oldSources.notEmpty) { at[\markEvidenceDirty].(\micSceneBlockedClear); };
                    st[\externalSources]
                } {
                    prepared = at[\micScenePrepareSources].(candidates ? Array.new);
                    sources = prepared[0];
                    tracks = prepared[1];
                    sceneClass = prepared[2];
                    at[\micSceneMaybePublishPressure].(sources, sceneClass, \micScenePressure);
                }
            }
        }
    };

    "[at-mic-pressure] mic scene pressure publisher loaded".postln;
};
)
