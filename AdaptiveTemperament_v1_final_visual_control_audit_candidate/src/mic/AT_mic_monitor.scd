(
// AT_mic_monitor.scd
// Human-readable raw → track → class → policy → pressure → field monitor.
var build, at, cfg, st, api, pitchClassNames;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-monitor] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api]; pitchClassNames = at[\pitchClassNames];

    at[\micTrackSummary] = { |tr|
        if(tr.isNil) { nil } {
            (
                id: tr[\id],
                pc: tr[\pc],
                pcName: pitchClassNames[tr[\pc]] ? tr[\pc].asString,
                cents: if(tr[\phase].isNil) { nil } { at[\phaseToPcCents].(tr[\phase], tr[\pc]).round(0.01) },
                freq: (tr[\freq] ? 0.0).round(0.01),
                weight: (tr[\weight] ? 0.0).round(0.001),
                confidence: (tr[\confidence] ? 0.0).round(0.001),
                amp: (tr[\amp] ? 0.0).round(0.001),
                ageSec: (tr[\ageSec] ? 0.0).round(0.01),
                stableFrames: tr[\stableFrames] ? 0,
                missingFrames: tr[\missingFrames] ? 0,
                jitterCents: (tr[\jitterCents] ? 0.0).round(0.01),
                motionCentsPerSec: (tr[\motionCentsPerSec] ? 0.0).round(0.01),
                sourceClass: tr[\sourceClass] ? \unknown,
                stableLock: tr[\stableLock] ? false,
                stableClassHeld: tr[\stableClassHeld] ? false,
                policyDecision: tr[\policyDecision] ? \unknown,
                policyReason: tr[\policyReason] ? \none,
                policyWeight: (tr[\policyWeight] ? 0.0).round(0.001),
                policyConfidence: (tr[\policyConfidence] ? 0.0).round(0.001),
                externalLatch: tr[\externalLatch] ? false,
                externalLatchReason: tr[\externalLatchReason]
            )
        }
    };

    at[\micSourceSummary] = { |src|
        if(src.isNil) { nil } {
            (
                id: src[\id],
                pc: src[\pc],
                pcName: pitchClassNames[src[\pc]] ? src[\pc].asString,
                cents: if(src[\phase].isNil) { nil } { at[\phaseToPcCents].(src[\phase], src[\pc]).round(0.01) },
                freq: (src[\freq] ? 0.0).round(0.01),
                weight: (src[\weight] ? 0.0).round(0.001),
                confidence: (src[\confidence] ? 0.0).round(0.001),
                sourceClass: src[\sourceClass] ? src[\kind] ? \unknown,
                policyDecision: src[\policyDecision] ? \unknown,
                policyReason: src[\policyReason] ? \none,
                trackAgeSec: (src[\trackAgeSec] ? 0.0).round(0.01),
                jitterCents: (src[\jitterCents] ? 0.0).round(0.01),
                motionCentsPerSec: (src[\motionCentsPerSec] ? 0.0).round(0.01)
            )
        }
    };

    at[\buildMicSceneReport] = {
        var snap, raw, tracks, pressure, suppressed, activePcs, dev, held;
        snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { () };
        raw = (st[\micRawCandidates] ? Array.new).collect { |src| at[\micSourceSummary].(src) };
        tracks = (st[\micSceneLastTracks] ? Array.new).collect { |tr| at[\micTrackSummary].(tr) };
        pressure = (st[\externalSources] ? Array.new).collect { |src| at[\micSourceSummary].(src) };
        suppressed = (st[\micSceneSuppressedTracks] ? Array.new).collect { |src| at[\micSourceSummary].(src) };
        activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
        dev = at[\devArray].().collect { |x| (x * 1200.0).round(0.01) };
        held = at[\notesArray].().collect { |n|
            var pc;
            pc = n[\pc];
            (
                midi: n[\midi],
                pc: pc,
                pcName: pitchClassNames[pc] ? pc.asString,
                currentDevCents: dev[pc],
                targetDevCents: if(st[\targetPhase].notNil) { (at[\wrapSigned].(st[\targetPhase][pc] - st[\etPhase][pc]) * 1200.0).round(0.01) } { nil },
                protectedDevCents: if(n[\protectedPhase].notNil) { (at[\wrapSigned].(n[\protectedPhase] - st[\etPhase][pc]) * 1200.0).round(0.01) } { nil },
                elasticYieldCents: (n[\heldElasticYieldCents] ? 0.0).round(0.01)
            )
        };
        (
            policy: at[\currentMicInfluencePolicy].(),
            mode: cfg[\mic][\mode],
            enabled: cfg[\mic][\enabled],
            inputAmp0: (st[\micInputAmp0] ? 0.0).round(0.0001),
            inputAmp1: (st[\micInputAmp1] ? 0.0).round(0.0001),
            rawFreq: (st[\micRawFreq] ? 0.0).round(0.01),
            rawAmp: (st[\micRawAmp] ? 0.0).round(0.0001),
            analyzedAmp: (st[\micAnalyzedAmp] ? 0.0).round(0.0001),
            raw: raw,
            tracks: tracks,
            sceneClass: st[\micSceneClass] ? \none,
            sceneDensity: st[\micSceneDensity] ? 0,
            candidateDensity: st[\micSceneCandidateDensity] ? 0,
            suppressed: suppressed,
            pressure: pressure,
            activePcs: activePcs,
            held: held,
            devCents: dev,
            blocked: st[\micInfluenceBlocked] ? false,
            dirtySuppressedCount: st[\micSceneDirtySuppressedCount] ? 0,
            micReleaseHoldActive: st[\micReleaseHoldActive] ? false,
            micReleaseHoldReason: st[\micReleaseHoldReason],
            micReleaseHoldActivePcs: st[\micReleaseHoldActivePcs] ? Array.new,
            micReleaseHoldSourceCount: (st[\micReleaseHoldSources] ? Array.new).size,
            micReleaseHoldAgeSec: if(st[\micReleaseHoldAt].notNil) { (Main.elapsedTime - st[\micReleaseHoldAt]).round(0.01) } { nil },
            micReleaseHoldReleasedBy: st[\micReleaseHoldReleasedBy],
            lastPressureReason: st[\micSceneLastPressureReason],
            lastPressureAt: st[\micSceneLastPressureAt],
            evidenceDirty: st[\evidenceDirty],
            evidenceDirtyReason: st[\evidenceDirtyReason]
        )
    };

    api[\micSceneReport] = {
        var report;
        report = at[\buildMicSceneReport].();
        report.postln;
        report
    };

    at[\micSceneReport] = { api[\micSceneReport].(); };
    at[\micSceneSummary] = { at[\buildMicSceneReport].(); };

    "[at-mic-monitor] mic scene monitor loaded".postln;
};
)
