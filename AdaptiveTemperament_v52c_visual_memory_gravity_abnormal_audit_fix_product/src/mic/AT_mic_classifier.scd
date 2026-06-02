(
// AT_mic_classifier.scd
// Acoustic source classification. The classifier names what kind of external
// thing a mic track appears to be before it is allowed to pressure the field.
// v1g: live mono stability lock + external latch stability. A steady but
// imperfect physical tone should not be reclassified as a bend because of one
// noisy motion estimate. Accepted external sources retain a stable identity
// while jitter remains low.
var build, at, cfg, st;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-classifier] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state];

    at[\micTrackStableLock] = { |track|
        var conf, jitter, age, density, stableFrames, latched;
        if(track.isNil) { false } {
            conf = track[\confidence] ? 0.0;
            jitter = track[\jitterCents] ? 0.0;
            age = track[\ageSec] ? 0.0;
            density = st[\micSceneCandidateDensity] ? 0;
            stableFrames = track[\stableFrames] ? 0;
            latched = track[\externalLatch] == true;

            if(latched and: {
                density <= (cfg[\micScene][\liveStableMaxDensity] ? 1)
            } and: {
                age >= (cfg[\micScene][\externalLatchStableMinAge] ? 0.25)
            } and: {
                conf >= (cfg[\micScene][\externalLatchStableMinConfidence] ? 0.30)
            } and: {
                jitter <= (cfg[\micScene][\externalLatchStableMaxJitterCents] ? 8.0)
            }) {
                true
            } {
                (density <= (cfg[\micScene][\liveStableMaxDensity] ? 1)) and: {
                    age >= (cfg[\micScene][\liveStableMinAge] ? 0.40)
                } and: {
                    conf >= (cfg[\micScene][\liveStableMinConfidence] ? 0.34)
                } and: {
                    stableFrames >= (cfg[\micScene][\liveStableMinStableFrames] ? 1)
                } and: {
                    jitter <= (cfg[\micScene][\liveStableMaxJitterCents] ? 5.5)
                }
            }
        }
    };

    at[\micTrackStableHysteresis] = { |track|
        var prev, conf, jitter, age, density, latched;
        if(track.isNil) { false } {
            prev = track[\sourceClass] ? \unknown;
            conf = track[\confidence] ? 0.0;
            jitter = track[\jitterCents] ? 0.0;
            age = track[\ageSec] ? 0.0;
            density = st[\micSceneCandidateDensity] ? 0;
            latched = track[\externalLatch] == true;
            ([\stableTone, \vibratoTone].includes(prev) or: { latched }) and: {
                density <= (cfg[\micScene][\liveStableMaxDensity] ? 1)
            } and: {
                age >= (cfg[\micScene][\stableClassHysteresisSec] ? 0.45)
            } and: {
                conf >= ((cfg[\mic][\minConfidence] ? 0.06) * 0.9).max(0.05)
            } and: {
                jitter <= (cfg[\micScene][\stableClassHysteresisJitterCents] ? 8.0)
            }
        }
    };

    at[\classifyMicTrack] = { |track|
        var cls, conf, weight, stable, jitter, motion, missing, density, age, stableLock, stableHold, activePcs;
        if(track.isNil) {
            nil
        } {
            conf = track[\confidence] ? 0.0;
            weight = track[\weight] ? 0.0;
            stable = track[\stableFrames] ? 0;
            jitter = track[\jitterCents] ? 0.0;
            motion = track[\motionCentsPerSec] ? 0.0;
            missing = track[\missingFrames] ? 0;
            density = st[\micSceneCandidateDensity] ? 0;
            age = track[\ageSec] ? 0.0;
            activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
            stableLock = at[\micTrackStableLock].(track);
            stableHold = at[\micTrackStableHysteresis].(track);

            cls = if(missing > 0) { \decaying } {
                if(conf < ((cfg[\mic][\minConfidence] ? 0.2) * 0.45) or: { weight <= 0.0001 }) {
                    \noise
                } {
                    if(density >= (cfg[\micScene][\songDensityThreshold] ? 5)) {
                        \songScene
                    } {
                        if((density >= (cfg[\micScene][\chordCloudThreshold] ? 3)) or: {
                            (cfg[\mic][\mode] == \polyPc) and: {
                                (cfg[\micScene][\livePolySceneEnabled] ? true)
                            } and: {
                                density >= (cfg[\micScene][\livePolySceneMinDensity] ? 2)
                            } and: {
                                activePcs.size >= (cfg[\micScene][\livePolySceneMinActivePcs] ? 2)
                            }
                        }) {
                            \chordCloud
                        } {
                            // For a single live mono source, stable identity wins over
                            // instantaneous motion. This is what lets a 255/265 Hz phone
                            // tone settle instead of being named a guitar bend forever.
                            if(stableLock or: { stableHold }) {
                                \stableTone
                            } {
                                if(motion >= (cfg[\micScene][\bendCentsPerSec] ? 55.0)) {
                                    \guitarBend
                                } {
                                    if(motion >= (cfg[\micScene][\movingCentsPerSec] ? 22.0)) {
                                        \movingTone
                                    } {
                                        if(jitter >= (cfg[\micScene][\highJitterCents] ? 9.0)) {
                                            \movingTone
                                        } {
                                            if(jitter >= (cfg[\micScene][\vibratoJitterCents] ? 5.5)) {
                                                \vibratoTone
                                            } {
                                                if(stable >= (cfg[\micScene][\stableFrames] ? 4)) {
                                                    \stableTone
                                                } {
                                                    if(age >= 0.25) { \tentative } { \raw }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            };

            track.copy.putAll((sourceClass: cls, stableLock: stableLock, stableClassHeld: stableHold))
        }
    };

    at[\classifyMicTracks] = { |tracks|
        var out;
        out = (tracks ? Array.new).collect { |tr| at[\classifyMicTrack].(tr) }.select { |tr| tr.notNil };
        st[\micSceneClass] = at[\micSceneClassForTracks].(out);
        st[\micSceneLastTracks] = out.collect { |tr| tr.copy };
        out
    };

    at[\micClassWeightCap] = { |sourceClass, pc=nil|
        if(sourceClass == \stableTone) { cfg[\micScene][\stableToneWeightCap] ? 0.32 } {
            if(sourceClass == \vibratoTone) { (cfg[\micScene][\stableToneWeightCap] ? 0.32) * 0.75 } {
                if(sourceClass == \movingTone) { cfg[\micScene][\movingToneWeightCap] ? 0.10 } {
                    if(sourceClass == \guitarBend) { cfg[\micScene][\bendWeightCap] ? 0.07 } {
                        if(sourceClass == \chordCloud) { cfg[\micScene][\chordCloudWeightCap] ? 0.11 } {
                            if(sourceClass == \songScene) { cfg[\micScene][\songSceneWeightCap] ? 0.07 } {
                                if(sourceClass == \decaying) { (cfg[\micScene][\stableToneWeightCap] ? 0.32) * 0.45 } {
                                    cfg[\micScene][\uncertainWeightCap] ? 0.04
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    at[\micClassWeightScale] = { |sourceClass|
        if(sourceClass == \stableTone) { 1.0 } {
            if(sourceClass == \vibratoTone) { 0.70 } {
                if(sourceClass == \movingTone) { 0.40 } {
                    if(sourceClass == \guitarBend) { 0.25 } {
                        if(sourceClass == \chordCloud) { 0.42 } {
                            if(sourceClass == \songScene) { 0.25 } {
                                if(sourceClass == \decaying) { 0.35 } { 0.18 }
                            }
                        }
                    }
                }
            }
        }
    };

    at[\micTrackLikelyStable] = { |track|
        track.notNil and: {
            [\stableTone, \vibratoTone, \decaying].includes(track[\sourceClass]) and: {
                (track[\confidence] ? 0.0) >= (cfg[\mic][\minConfidence] ? 0.2)
            }
        }
    };

    "[at-mic-classifier] acoustic source classification loaded".postln;
};
)
