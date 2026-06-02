(
// AT_mic_scene.scd
// Mic Scene Model v1: state, defaults, and utilities.
// Raw mic candidates are not harmonic truth. They become persistent acoustic
// tracks, then classified/policy-approved pressure sources.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-scene] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    cfg[\micScene] = cfg[\micScene] ? (
        enabled: true,
        trackByPc: true,
        stableCents: 3.5,
        tentativeFrames: 2,
        stableFrames: 4,
        dropoutFrames: 7,
        phaseAlpha: 0.28,
        freqAlpha: 0.22,
        weightAlpha: 0.30,
        confidenceAlpha: 0.35,
        ampAlpha: 0.25,
        jitterAlpha: 0.18,
        motionAlpha: 0.22,
        movingCentsPerSec: 22.0,
        bendCentsPerSec: 55.0,
        highJitterCents: 9.0,
        vibratoJitterCents: 5.5,
        stableJitterCents: 4.0,
        // Live physical pitch detectors often produce one or two jumpy motion
        // estimates even for a steady tone. Stability should be judged by
        // age + low jitter + persistent pc, not instantaneous velocity alone.
        liveStableMinAge: 0.40,
        liveStableMinConfidence: 0.34,
        liveStableMaxJitterCents: 5.5,
        liveStableMaxDensity: 1,
        liveStableMinStableFrames: 1,
        stableClassHysteresisSec: 0.45,
        stableClassHysteresisJitterCents: 8.0,
        externalLatchStableMinAge: 0.25,
        externalLatchStableMinConfidence: 0.30,
        externalLatchStableMaxJitterCents: 8.0,
        // Live polyPc scene bridge: physical songs/chords can expose only
        // two visible pitch-class traces at a report instant. With a held
        // MIDI chord, those traces should become weak scene pressure instead
        // of being discarded merely because they have not met strict active
        // stability yet.
        livePolySceneEnabled: true,
        livePolySceneMinActivePcs: 2,
        livePolySceneMinDensity: 2,
        livePolyTrackInactiveVisible: true,
        livePolyTrackMinWeight: 0.00025,
        livePolyTrackMinConfidence: 0.035,
        livePolyPolicyMinConfidence: 0.035,
        livePolySceneWeightFloor: 0.012,
        songDensityThreshold: 5,
        chordCloudThreshold: 3,
        chordCloudMaxSources: 3,
        rawDebugScale: 0.02,
        debugRawMaxWeight: 0.02,
        stableToneWeightCap: 0.32,
        samePcDuetWeightCap: 0.18,
        externalFollowWeightCap: 0.75,
        movingToneWeightCap: 0.10,
        bendWeightCap: 0.07,
        chordCloudWeightCap: 0.11,
        songSceneWeightCap: 0.07,
        uncertainWeightCap: 0.04,
        minDirtyIntervalStable: 0.08,
        minDirtyIntervalMoving: 0.14,
        minDirtyIntervalCloud: 0.25,
        minDirtyIntervalSong: 0.45,
        keyCentsQuantStable: 2.0,
        keyCentsQuantCloud: 8.0,
        keyWeightQuant: 0.03,
        tinyCentsChange: 2.5,
        tinyWeightChange: 0.04,
        harmonicBleedLowConfidence: 0.32,
        harmonicBleedWeightScale: 0.18,
        // When a stable external source disappears, do not let its disappearance
        // become a reverse force. Hold the current audible field until new
        // musical evidence arrives: a changed MIDI pc set, a new external scene,
        // reset/cleanup, or an explicit mode change.
        externalReleaseHoldEnabled: true,
        externalReleaseHoldMinWeight: 0.015,
        externalReleaseHoldMinConfidence: 0.20,
        externalReleaseHoldAllowScene: true,
        sceneLog: false
    );

    at[\initMicSceneState] = {
        st[\micSceneTracks] = Array.fill(cfg[\solver][\numNodes], { nil });
        st[\micSceneLastTracks] = Array.new;
        st[\micSceneClass] = \none;
        st[\micSceneDensity] = 0;
        st[\micSceneRawDensity] = 0;
        st[\micSceneCandidateDensity] = 0;
        st[\micSceneLastAt] = nil;
        st[\micScenePolicy] = cfg[\mic][\influencePolicy] ? \externalOnly;
        st[\micScenePressureKey] = nil;
        st[\micSceneLastPressureAt] = nil;
        st[\micSceneLastPressureReason] = nil;
        st[\micSceneDirtySuppressedCount] = 0;
        st[\micSceneAcceptedSources] = Array.new;
        st[\micSceneSuppressedTracks] = Array.new;
        st[\micScenePolicyEvents] = Array.new;
        st[\micSceneReportCache] = nil;
        st[\micSceneLastRawSummary] = nil;
        st[\micReleaseHoldActive] = false;
        st[\micReleaseHoldPhase] = nil;
        st[\micReleaseHoldActivePcs] = Array.new;
        st[\micReleaseHoldSources] = Array.new;
        st[\micReleaseHoldAt] = nil;
        st[\micReleaseHoldReason] = nil;
        st[\micReleaseHoldReleasedBy] = nil;
    };

    at[\clearMicScene] = {
        at[\initMicSceneState].();
    };

    if(st[\micSceneTracks].isNil) {
        at[\initMicSceneState].();
    };

    // r17ba: explicit mic clears should clear scene identity too, but ordinary
    // no-voice poly frames should call updateCommittedExternalSources([]) instead
    // so tracks can decay and external release-hold can engage.
    if(at[\legacyClearMicEvidence_MicScene].isNil and: { at[\clearMicEvidence].notNil }) {
        at[\legacyClearMicEvidence_MicScene] = at[\clearMicEvidence];
        at[\clearMicEvidence] = {
            at[\legacyClearMicEvidence_MicScene].();
            at[\clearMicScene].();
        };
    };

    at[\phaseToPcCents] = { |phase, pc=nil|
        var p, refPc;
        p = at[\wrap01].(phase ? 0.0);
        refPc = if(pc.isNil) { ((p * 12.0).round.asInteger) % 12 } { pc.asInteger % 12 };
        (at[\wrapSigned].(p - (refPc / 12.0)) * 1200.0)
    };

    at[\freqToPcAndCents] = { |freq|
        var phase, pc, cents;
        if((freq ? 0.0) <= 0.0) {
            (pc: nil, cents: nil, phase: nil)
        } {
            phase = at[\freqToPhase].(freq);
            pc = ((phase * 12.0).round.asInteger) % 12;
            cents = at[\phaseToPcCents].(phase, pc);
            (pc: pc, cents: cents, phase: phase)
        }
    };

    at[\micSceneTrackArray] = {
        (st[\micSceneTracks] ? Array.new).select { |tr| tr.notNil }
    };

    at[\micSceneSourceArray] = {
        (st[\externalSources] ? Array.new).select { |src| src.notNil and: { src[\active] != false } }
    };

    at[\micSceneClassForTracks] = { |tracks|
        var density, stableCount, movingCount, cloudCount, activePcs;
        tracks = tracks ? Array.new;
        density = st[\micSceneCandidateDensity] ? tracks.size;
        stableCount = tracks.count { |tr| tr[\sourceClass] == \stableTone };
        movingCount = tracks.count { |tr| [\movingTone, \guitarBend, \vibratoTone].includes(tr[\sourceClass]) };
        cloudCount = tracks.count { |tr| [\chordCloud, \songScene].includes(tr[\sourceClass]) };
        activePcs = at[\activePcsFromWeights].(at[\pcWeights].());

        if(density >= (cfg[\micScene][\songDensityThreshold] ? 5)) {
            \songScene
        } {
            if(density >= (cfg[\micScene][\chordCloudThreshold] ? 3)) {
                \chordCloud
            } {
                if((cfg[\mic][\mode] == \polyPc) and: {
                    (cfg[\micScene][\livePolySceneEnabled] ? true)
                } and: {
                    density >= (cfg[\micScene][\livePolySceneMinDensity] ? 2)
                } and: {
                    activePcs.size >= (cfg[\micScene][\livePolySceneMinActivePcs] ? 2)
                }) {
                    \chordCloud
                } {
                    if(movingCount > stableCount) { \movingTone } {
                        if(stableCount > 0) { \stableTone } { if(cloudCount > 0) { \chordCloud } { \none } }
                    }
                }
            }
        }
    };

    at[\micScenePressureQuant] = { |src, sceneClass=nil|
        var pc, cents, qCents, qWeight, qConf;
        pc = src[\pc];
        cents = at[\phaseToPcCents].(src[\phase], pc);
        qCents = if([\chordCloud, \songScene].includes(sceneClass ? src[\sourceClass])) {
            cfg[\micScene][\keyCentsQuantCloud] ? 8.0
        } {
            cfg[\micScene][\keyCentsQuantStable] ? 2.0
        };
        qWeight = cfg[\micScene][\keyWeightQuant] ? 0.03;
        qConf = cfg[\mic][\keyConfidenceQuant] ? 0.03;
        [pc, cents.round(qCents), (src[\weight] ? 0.0).round(qWeight), (src[\confidence] ? 0.0).round(qConf), src[\sourceClass] ? \unknown]
    };

    at[\micSceneKeyForSources] = { |sources, sceneClass=nil|
        if((sources ? Array.new).isEmpty) {
            nil
        } {
            (sources ? Array.new).sort { |a, b| (a[\pc] ? 0) < (b[\pc] ? 0) }.collect { |src|
                at[\micScenePressureQuant].(src, sceneClass)
            }
        }
    };

    at[\micSceneStructuralChange] = { |oldSources, newSources|
        var oldPcs, newPcs;
        oldPcs = (oldSources ? Array.new).collect { |s| s[\pc] }.sort;
        newPcs = (newSources ? Array.new).collect { |s| s[\pc] }.sort;
        oldPcs != newPcs
    };

    at[\micSceneMinDirtyInterval] = { |sceneClass|
        if(sceneClass == \songScene) { cfg[\micScene][\minDirtyIntervalSong] ? 0.45 } {
            if(sceneClass == \chordCloud) { cfg[\micScene][\minDirtyIntervalCloud] ? 0.25 } {
                if([\movingTone, \guitarBend, \vibratoTone].includes(sceneClass)) { cfg[\micScene][\minDirtyIntervalMoving] ? 0.14 } {
                    cfg[\micScene][\minDirtyIntervalStable] ? 0.08
                }
            }
        }
    };

    at[\micSourceCentsString] = { |src|
        var pc, cents;
        if(src.isNil) { "nil" } {
            pc = src[\pc];
            cents = if(pc.isNil or: { src[\phase].isNil }) { nil } { at[\phaseToPcCents].(src[\phase], pc).round(0.01) };
            (src[\id] ? "src").asString ++ ":" ++ (pitchClassNames[pc] ? pc.asString) ++ " " ++ cents.asString ++ "c" ++
            " w=" ++ ((src[\weight] ? 0.0).round(0.001)).asString ++
            " c=" ++ ((src[\confidence] ? 0.0).round(0.001)).asString ++
            " class=" ++ (src[\sourceClass] ? src[\kind] ? \unknown).asString ++
            " reason=" ++ (src[\policyReason] ? \none).asString
        }
    };

    "[at-mic-scene] scene state/utilities loaded".postln;
};
)
