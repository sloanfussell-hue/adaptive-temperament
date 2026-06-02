(
// AT_mic_tracker.scd
// Persistent per-pitch-class acoustic source tracks. This layer turns raw
// candidate flicker into remembered source identities with age, jitter, motion,
// dropout memory, and smoothed phase/frequency.
var build, at, cfg, st;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-tracker] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state];

    at[\micSceneNormalizeCandidates] = { |candidates|
        (candidates ? Array.new).collect { |src| at[\normalizeExternalSource].(src) }.select { |src|
            src.notNil and: { src[\pc].notNil }
        }
    };

    at[\micSceneCandidateByPc] = { |candidates|
        var byPc;
        byPc = Array.fill(cfg[\solver][\numNodes], { nil });
        (candidates ? Array.new).do { |src|
            var pc, old;
            pc = src[\pc];
            if(pc.notNil) {
                old = byPc[pc];
                if(old.isNil or: { ((src[\weight] ? 0.0) * (src[\confidence] ? 0.0)) > ((old[\weight] ? 0.0) * (old[\confidence] ? 0.0)) }) {
                    byPc[pc] = src;
                };
            };
        };
        byPc
    };

    at[\micSceneShouldTrackCandidate] = { |cand|
        var activePcs;
        if(cand.isNil) { false } {
            if(cand[\active] != false) { true } {
                activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
                (cfg[\mic][\mode] == \polyPc) and: {
                    (cfg[\micScene][\livePolySceneEnabled] ? true)
                } and: {
                    (cfg[\micScene][\livePolyTrackInactiveVisible] ? true)
                } and: {
                    activePcs.size >= (cfg[\micScene][\livePolySceneMinActivePcs] ? 2)
                } and: {
                    (cand[\weight] ? 0.0) >= (cfg[\micScene][\livePolyTrackMinWeight] ? 0.00025)
                } and: {
                    (cand[\confidence] ? 0.0) >= (cfg[\micScene][\livePolyTrackMinConfidence] ? 0.035)
                }
            }
        }
    };

    at[\micSceneUpdateTrack] = { |old, cand, pc, now|
        var tr, prevPhase, prevAt, dt, phaseDelta, phaseDeltaCents, freqDeltaCents, motion, jitter, stableFrames;
        var phaseAlpha, freqAlpha, weightAlpha, confAlpha, ampAlpha;

        phaseAlpha = cfg[\micScene][\phaseAlpha] ? 0.28;
        freqAlpha = cfg[\micScene][\freqAlpha] ? 0.22;
        weightAlpha = cfg[\micScene][\weightAlpha] ? 0.30;
        confAlpha = cfg[\micScene][\confidenceAlpha] ? 0.35;
        ampAlpha = cfg[\micScene][\ampAlpha] ? 0.25;

        if(old.isNil) {
            tr = (
                id: "track-" ++ pc.asString,
                pc: pc,
                birthAt: now,
                lastSeenAt: now,
                updatedAt: now,
                ageSec: 0.0,
                phase: cand[\phase],
                freq: cand[\freq] ? 0.0,
                weight: cand[\weight] ? 0.0,
                confidence: cand[\confidence] ? 0.0,
                amp: cand[\amp] ? 0.0,
                stableFrames: 1,
                seenFrames: 1,
                missingFrames: 0,
                jitterCents: 0.0,
                motionCentsPerSec: 0.0,
                rawCents: at[\phaseToPcCents].(cand[\phase], pc),
                sourceClass: \tentative,
                policyDecision: \pending,
                policyReason: \newTrack,
                active: true
            );
        } {
            prevPhase = old[\phase];
            prevAt = old[\updatedAt] ? now;
            dt = (now - prevAt).max(0.001);
            phaseDelta = if(prevPhase.notNil and: { cand[\phase].notNil }) { at[\wrapSigned].(cand[\phase] - prevPhase) } { 0.0 };
            phaseDeltaCents = (phaseDelta * 1200.0).abs;
            freqDeltaCents = if((old[\freq] ? 0.0) > 0.0 and: { (cand[\freq] ? 0.0) > 0.0 }) {
                ((cand[\freq] / old[\freq]).log2 * 1200.0).abs
            } { phaseDeltaCents };
            motion = ((freqDeltaCents.max(phaseDeltaCents)) / dt).clip(0.0, 9999.0);
            jitter = ((old[\jitterCents] ? 0.0) * (1.0 - (cfg[\micScene][\jitterAlpha] ? 0.18))) + (phaseDeltaCents * (cfg[\micScene][\jitterAlpha] ? 0.18));
            motion = ((old[\motionCentsPerSec] ? 0.0) * (1.0 - (cfg[\micScene][\motionAlpha] ? 0.22))) + (motion * (cfg[\micScene][\motionAlpha] ? 0.22));

            stableFrames = if(phaseDeltaCents <= (cfg[\micScene][\stableCents] ? 3.5)) {
                (old[\stableFrames] ? 0) + 1
            } {
                1
            };

            tr = old.copy.putAll((
                lastSeenAt: now,
                updatedAt: now,
                ageSec: now - (old[\birthAt] ? now),
                phase: at[\phaseBlend].(old[\phase], cand[\phase], phaseAlpha),
                freq: if((old[\freq] ? 0.0) <= 0.0) { cand[\freq] ? 0.0 } { (old[\freq] ? 0.0) + (((cand[\freq] ? old[\freq]) - (old[\freq] ? 0.0)) * freqAlpha.clip(0.0, 1.0)) },
                weight: (((old[\weight] ? 0.0) * (1.0 - weightAlpha)) + ((cand[\weight] ? 0.0) * weightAlpha)).clip(0.0, 1.5),
                confidence: (((old[\confidence] ? 0.0) * (1.0 - confAlpha)) + ((cand[\confidence] ? 0.0) * confAlpha)).clip(0.0, 1.0),
                amp: (((old[\amp] ? 0.0) * (1.0 - ampAlpha)) + ((cand[\amp] ? 0.0) * ampAlpha)).clip(0.0, 10.0),
                stableFrames: stableFrames,
                seenFrames: (old[\seenFrames] ? 0) + 1,
                missingFrames: 0,
                jitterCents: jitter,
                motionCentsPerSec: motion,
                rawCents: at[\phaseToPcCents].(cand[\phase], pc),
                active: true
            ));
        };
        tr
    };

    at[\micSceneDecayTrack] = { |old, now|
        var tr, missing, releaseFrames;
        if(old.isNil) { nil } {
            releaseFrames = cfg[\micScene][\dropoutFrames] ? 7;
            missing = (old[\missingFrames] ? 0) + 1;
            if(missing > releaseFrames) {
                nil
            } {
                tr = old.copy.putAll((
                    updatedAt: now,
                    ageSec: now - (old[\birthAt] ? now),
                    missingFrames: missing,
                    weight: ((old[\weight] ? 0.0) * 0.78).clip(0.0, 1.5),
                    confidence: ((old[\confidence] ? 0.0) * 0.86).clip(0.0, 1.0),
                    motionCentsPerSec: ((old[\motionCentsPerSec] ? 0.0) * 0.75),
                    sourceClass: \decaying,
                    policyDecision: \decaying,
                    policyReason: \dropoutHysteresis,
                    active: true
                ));
                tr
            }
        }
    };

    at[\micSceneTrackCandidates] = { |candidates|
        var now, normalized, byPc, tracks, out;
        now = Main.elapsedTime;
        normalized = at[\micSceneNormalizeCandidates].(candidates);
        byPc = at[\micSceneCandidateByPc].(normalized);
        if(st[\micSceneTracks].isNil) { at[\initMicSceneState].(); };
        tracks = st[\micSceneTracks];
        st[\micSceneRawDensity] = (st[\micRawCandidates] ? Array.new).size;
        st[\micSceneCandidateDensity] = normalized.size;
        st[\micSceneLastRawSummary] = normalized.collect { |src| src.copy };

        cfg[\solver][\numNodes].do { |pc|
            var cand, old;
            cand = byPc[pc];
            old = tracks[pc];
            if(cand.notNil and: { at[\micSceneShouldTrackCandidate].(cand) }) {
                tracks[pc] = at[\micSceneUpdateTrack].(old, cand, pc, now);
                if(cand[\active] == false) {
                    tracks[pc][\sceneVisibleOnly] = true;
                } {
                    tracks[pc][\sceneVisibleOnly] = false;
                };
            } {
                tracks[pc] = at[\micSceneDecayTrack].(old, now);
            };
        };

        out = tracks.select { |tr| tr.notNil };
        st[\micSceneTracks] = tracks;
        st[\micSceneLastTracks] = out.collect { |tr| tr.copy };
        st[\micSceneDensity] = out.size;
        st[\micSceneLastAt] = now;
        out
    };

    "[at-mic-tracker] persistent mic source tracking loaded".postln;
};
)
