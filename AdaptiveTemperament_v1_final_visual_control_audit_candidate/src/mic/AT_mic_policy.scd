(
// AT_mic_policy.scd
// Policy gate: off/monitor/externalOnly/duetSafe/fullBlend/externalFollow.
// This layer decides whether a classified mic track is external musical pressure,
// self/harmonic bleed, a low-risk debug source, or blocked context.
var build, at, cfg, st;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-policy] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state];

    // v2: decaying tracks remain visible for diagnostics/source identity, but
    // should stop acting as field pressure after a short grace period.  This
    // lets brief physical-mic dropouts avoid chatter without preventing
    // release-hold once a source has truly disappeared.
    if(cfg[\micScene][\decayPressureFrames].isNil) { cfg[\micScene][\decayPressureFrames] = 2; };
    if(cfg[\micScene][\decayPressureWeightScale].isNil) { cfg[\micScene][\decayPressureWeightScale] = 0.45; };

    at[\micTrackDiffFromNodeCents] = { |track|
        var pc;
        if(track.isNil or: { track[\pc].isNil }) { 0.0 } {
            pc = track[\pc];
            (at[\wrapSigned].((track[\phase] ? st[\nodePhase][pc]) - st[\nodePhase][pc]) * 1200.0)
        }
    };

    at[\micLikelyHarmonicBleed] = { |track, activePcs|
        var cls, conf, diff, nonSame, movingish;
        if(track.isNil or: { (activePcs ? Array.new).isEmpty }) {
            false
        } {
            cls = track[\sourceClass] ? \unknown;
            conf = track[\confidence] ? 0.0;
            nonSame = (activePcs ? Array.new).includes(track[\pc]).not;
            diff = at[\micTrackDiffFromNodeCents].(track).abs;
            movingish = [\raw, \tentative, \noise, \movingTone, \guitarBend].includes(cls);
            nonSame and: { (conf <= (cfg[\micScene][\harmonicBleedLowConfidence] ? 0.32)) or: { movingish and: { diff < 35.0 } } }
        }
    };

    at[\micPolicyDecisionForTrack] = { |track, activePcs=nil|
        var policy, pcs, pc, cls, src, diffCents, baseWeight, cap, scale, confScale, reason, accepted, latchedExternal, missingFrames, minActiveConfidence;
        if(track.isNil) { nil } {
            policy = at[\currentMicInfluencePolicy].();
            pcs = activePcs ? at[\activePcsFromWeights].(at[\pcWeights].());
            pc = track[\pc];
            cls = track[\sourceClass] ? \unknown;
            diffCents = at[\micTrackDiffFromNodeCents].(track).abs;
            baseWeight = (track[\weight] ? 0.0) * at[\micClassWeightScale].(cls);
            if((cfg[\mic][\mode] == \polyPc) and: { [\chordCloud, \songScene].includes(cls) }) {
                baseWeight = baseWeight.max(cfg[\micScene][\livePolySceneWeightFloor] ? 0.012);
            };
            cap = at[\micClassWeightCap].(cls, pc);
            scale = 1.0;
            confScale = 1.0;
            reason = \accepted;
            accepted = true;
            latchedExternal = track[\externalLatch] == true;
            missingFrames = track[\missingFrames] ? 0;

            // A decaying track is allowed to bridge a tiny dropout, but after
            // decayPressureFrames it is no longer musical evidence.  This is
            // the key distinction between source memory and pressure.
            if(cls == \decaying) {
                if(missingFrames > (cfg[\micScene][\decayPressureFrames] ? 2)) {
                    accepted = false; reason = \decayPressureExpired;
                } {
                    scale = scale * (cfg[\micScene][\decayPressureWeightScale] ? 0.45);
                };
            };

            if((cfg[\mic][\enabled] ? true).not or: { policy == \off }) {
                accepted = false; reason = \micOff;
            };

            if(policy == \monitor) {
                accepted = false; reason = \monitorOnly;
            };

            if(accepted and: { policy == \externalOnly and: { pcs.notEmpty } }) {
                accepted = false; reason = \externalOnlyMidiActive;
            };

            if(accepted and: { [\noise, \raw].includes(cls) }) {
                accepted = false; reason = \unstableOrNoise;
            };

            if(accepted and: { policy == \duetSafe and: { pcs.notEmpty } }) {
                if(pcs.includes(pc)) {
                    if(diffCents <= (cfg[\mic][\duetSamePcSelfCents] ? 4.0)) {
                        if(latchedExternal) {
                            // Once a track has already been accepted as an external same-PC
                            // source, do not reclassify it as self-bleed merely because the
                            // field successfully moved toward it. This prevents the mic from
                            // winning then disappearing as soon as agreement is reached.
                            reason = \samePcLatchedExternal;
                            scale = cfg[\mic][\duetSamePcTuningScale].clip(0.05, 2.0) * (cfg[\mic][\duetWeightScale] ? 0.55);
                            confScale = cfg[\mic][\duetSamePcConfidenceScale].clip(0.05, 1.5);
                            cap = cap.min(cfg[\micScene][\samePcDuetWeightCap] ? 0.18);
                        } {
                            accepted = false; reason = \samePcSelfBleed;
                        };
                    } {
                        if(diffCents <= (cfg[\mic][\duetSamePcUsefulCents] ? 80.0)) {
                            reason = \samePcOffsetExternal;
                            scale = cfg[\mic][\duetSamePcTuningScale].clip(0.05, 2.0) * (cfg[\mic][\duetWeightScale] ? 0.55);
                            confScale = cfg[\mic][\duetSamePcConfidenceScale].clip(0.05, 1.5);
                            cap = cap.min(cfg[\micScene][\samePcDuetWeightCap] ? 0.18);
                        } {
                            reason = \samePcFarExternal;
                            scale = (cfg[\mic][\selfGeneralPenalty] ? 0.22).clip(0.02, 1.0);
                            confScale = scale;
                        };
                    };
                } {
                    if(at[\micLikelyHarmonicBleed].(track, pcs)) {
                        reason = \harmonicOrRoomBleed;
                        scale = cfg[\micScene][\harmonicBleedWeightScale] ? 0.18;
                        confScale = 0.55;
                    } {
                        reason = \externalNonSamePcDuet;
                        scale = (cfg[\mic][\selfGeneralPenalty] ? 0.22).clip(0.02, 1.0);
                        confScale = scale.max(0.25);
                    };
                };
            };

            if(accepted and: { policy == \fullBlend }) {
                reason = \fullBlend;
                scale = 1.0;
            };

            if(accepted and: { policy == \externalFollow }) {
                reason = \externalFollow;
                scale = if(at[\micTrackLikelyStable].(track)) { 1.75 } { 0.55 };
                cap = cfg[\micScene][\externalFollowWeightCap] ? 0.75;
            };

            if(accepted and: { policy == \debugRaw }) {
                reason = \debugRaw;
                scale = cfg[\micScene][\rawDebugScale] ? 0.02;
                cap = cfg[\micScene][\debugRawMaxWeight] ? 0.02;
            };

            src = at[\normalizeExternalSource].((
                id: track[\id] ? ("track-" ++ pc.asString),
                kind: \micScene,
                pc: pc,
                phase: track[\phase],
                freq: track[\freq] ? 0.0,
                weight: (baseWeight * scale).clip(0.0, cap.max(0.0)),
                confidence: ((track[\confidence] ? 0.0) * confScale).clip(0.0, 1.0),
                amp: track[\amp] ? 0.0,
                stableFrames: track[\stableFrames] ? 0,
                active: accepted
            ));
            src[\sourceClass] = cls;
            src[\trackId] = track[\id];
            src[\trackAgeSec] = track[\ageSec] ? 0.0;
            src[\jitterCents] = track[\jitterCents] ? 0.0;
            src[\motionCentsPerSec] = track[\motionCentsPerSec] ? 0.0;
            src[\missingFrames] = missingFrames;
            src[\policyDecision] = if(accepted) { \accepted } { \suppressed };
            src[\policyReason] = reason;
            minActiveConfidence = if((cfg[\mic][\mode] == \polyPc) and: { [\chordCloud, \songScene].includes(cls) }) {
                cfg[\micScene][\livePolyPolicyMinConfidence] ? 0.035
            } {
                (cfg[\mic][\minConfidence] ? 0.2) * 0.55
            };
            src[\active] = accepted and: { (src[\weight] ? 0.0) > 0.0 } and: { (src[\confidence] ? 0.0) >= minActiveConfidence };
            if(src[\active] == true and: { [\samePcOffsetExternal, \samePcLatchedExternal, \samePcFarExternal, \externalNonSamePcDuet, \fullBlend, \externalFollow].includes(reason) }) {
                track[\externalLatch] = true;
                track[\externalLatchReason] = reason;
                track[\externalLatchAt] = Main.elapsedTime;
            };
            src
        }
    };

    at[\micPolicyApply] = { |tracks, activePcs=nil|
        var decided, accepted, suppressed;
        tracks = tracks ? Array.new;
        decided = Array.new;
        tracks.do { |tr|
            var src;
            src = at[\micPolicyDecisionForTrack].(tr, activePcs);
            if(src.notNil) {
                tr[\policyDecision] = src[\policyDecision];
                tr[\policyReason] = src[\policyReason];
                tr[\policyWeight] = src[\weight];
                tr[\policyConfidence] = src[\confidence];
                if(src[\policyReason].notNil) { tr[\lastPolicyReason] = src[\policyReason]; };
                decided = decided.add(src);
            };
        };
        accepted = decided.select { |src| src[\active] == true };
        suppressed = decided.select { |src| src[\active] != true };
        st[\micSceneSuppressedTracks] = suppressed.collect { |src| src.copy };
        st[\micScenePolicyEvents] = decided.collect { |src| (
            id: src[\id], pc: src[\pc], sourceClass: src[\sourceClass], decision: src[\policyDecision], reason: src[\policyReason], weight: src[\weight], confidence: src[\confidence]
        ) };
        st[\micSceneLastTracks] = tracks.collect { |tr| tr.copy };
        accepted
    };

    "[at-mic-policy] mic scene policy gate loaded".postln;
};
)
