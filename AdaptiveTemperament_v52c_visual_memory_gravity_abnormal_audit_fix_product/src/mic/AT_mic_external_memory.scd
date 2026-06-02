(
// AT_mic_external_memory.scd
// Acoustic release memory: when a real external mic source disappears, do not
// let the disappearance itself yank the field back. This is separate from tonal
// memory: it remembers the current audible field after an external scene has
// successfully influenced it, and holds that field until new musical evidence
// arrives.
var build, at, cfg, st;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-external-memory] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state];

    at[\micReleaseHoldRealSource] = { |src|
        var cls, reason, w, conf, allowScene;
        if(src.isNil) { false } {
            cls = src[\sourceClass] ? src[\kind] ? \unknown;
            reason = src[\policyReason] ? \unknown;
            w = src[\weight] ? src[\policyWeight] ? 0.0;
            conf = src[\confidence] ? src[\policyConfidence] ? 0.0;
            allowScene = cfg[\micScene][\externalReleaseHoldAllowScene] ? true;
            (w >= (cfg[\micScene][\externalReleaseHoldMinWeight] ? 0.015)) and: {
                conf >= (cfg[\micScene][\externalReleaseHoldMinConfidence] ? 0.20)
            } and: {
                (reason != \debugRaw) and: { reason != \unstableOrNoise }
            } and: {
                [\stableTone, \vibratoTone, \externalFollow, \micScene].includes(cls)
                or: { allowScene and: { [\chordCloud, \songScene].includes(cls) } }
                or: { [\samePcOffsetExternal, \samePcLatchedExternal, \externalNonSamePcDuet, \externalOnly, \accepted, \externalFollow, \fullBlend].includes(reason) }
            }
        }
    };

    at[\activateMicReleaseHold] = { |oldSources, reason=\micSceneCleared|
        var activePcs, realSources;
        if((cfg[\micScene][\externalReleaseHoldEnabled] ? true).not) { nil } {
            oldSources = oldSources ? Array.new;
            realSources = oldSources.select { |src| at[\micReleaseHoldRealSource].(src) };
            if(realSources.notEmpty) {
                activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
                st[\micReleaseHoldActive] = true;
                st[\micReleaseHoldPhase] = st[\nodePhase].copy;
                st[\micReleaseHoldTargetPhase] = (st[\targetPhase] ? st[\nodePhase]).copy;
                st[\micReleaseHoldActivePcs] = activePcs.copy;
                st[\micReleaseHoldSources] = realSources.collect { |src| src.copy };
                st[\micReleaseHoldAt] = Main.elapsedTime;
                st[\micReleaseHoldReason] = reason;
                st[\micReleaseHoldReleasedBy] = nil;
                st[\lastFieldAction] = \micReleaseHold;
                if(cfg[\micScene][\sceneLog] ? false) {
                    ("[at-mic-release-hold] active pcs=" ++ activePcs.asString ++ " sources=" ++ realSources.size.asString).postln;
                };
            };
        };
        st[\micReleaseHoldActive] == true
    };

    at[\clearMicReleaseHold] = { |reason=\clear|
        if(st[\micReleaseHoldActive] == true) {
            st[\micReleaseHoldReleasedBy] = reason;
            if(cfg[\micScene][\sceneLog] ? false) {
                ("[at-mic-release-hold] cleared by " ++ reason.asString).postln;
            };
        };
        st[\micReleaseHoldActive] = false;
        st[\micReleaseHoldPhase] = nil;
        st[\micReleaseHoldActivePcs] = Array.new;
        st[\micReleaseHoldSources] = Array.new;
        st[\micReleaseHoldAt] = nil;
        st[\micReleaseHoldReason] = nil;
    };

    at[\samePcSet] = { |a, b|
        (a ? Array.new).as(Set) == (b ? Array.new).as(Set)
    };

    at[\micReleaseHoldShouldHold] = { |activePcs, externalSources, reason=\resolve|
        var holdPcs, samePcs;
        if((st[\micReleaseHoldActive] == true).not) { false } {
            if((externalSources ? Array.new).notEmpty) {
                at[\clearMicReleaseHold].(\newExternalEvidence);
                false
            } {
                holdPcs = st[\micReleaseHoldActivePcs] ? Array.new;
                samePcs = at[\samePcSet].(activePcs ? Array.new, holdPcs);
                if(samePcs.not) {
                    at[\clearMicReleaseHold].(\activePcChanged);
                    false
                } {
                    true
                }
            }
        }
    };

    at[\applyMicReleaseHoldIfNeeded] = { |activePcs, externalSources, reason=\resolve|
        var phase;
        if(at[\micReleaseHoldShouldHold].(activePcs, externalSources, reason)) {
            phase = st[\micReleaseHoldPhase] ? st[\nodePhase];
            st[\nodePhase] = phase.copy;
            st[\targetPhase] = phase.copy;
            st[\lastSolvedPhase] = phase.copy;
            st[\targetValid] = false;
            st[\motionActive] = false;
            st[\fieldHadSolvedEvidence] = true;
            st[\lastFieldAction] = \micReleaseHold;
            st[\stateLabel] = \micReleaseHold;
            if(at[\clearDescriptors].notNil) { at[\clearDescriptors].(); };
            if(at[\pushBuses].notNil) { at[\pushBuses].(); };
            true
        } {
            false
        }
    };

    "[at-mic-external-memory] acoustic release hold loaded".postln;
};
)
