(
// AT_mic_field_response.scd
// Mic Field Response v2.
// This layer sits after the mic scene model.  It does not decide whether a
// mic source is real; it decides how an already accepted, classified external
// source should pull the harmonic field, and it reports that translation.
//
// Main musical law:
//   duetSafe = negotiate with the external source.
//   externalFollow = follow the external source much more directly.
//
// A same-PC external source should pull from the current/protected musical
// state toward the heard source. It should not be measured only against the
// equal-tempered reference pitch, because that makes the field rubber-band
// back toward ET whenever the mic source is weak.
var build, at, cfg, st, api, pitchClassNames, oldBuildReport;

build = ~atBuild;
if(build.isNil) {
    "[at-mic-field-response] ~atBuild missing".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api]; pitchClassNames = at[\pitchClassNames];

    if(cfg[\micResponse].isNil) {
        cfg[\micResponse] = (
            enabled: true,

            // For same-PC duetSafe pressure, use a firm target-anchor blend.
            // Held-note protection still limits audible motion, so this should
            // make the target move in the correct direction without snapping.
            duetSamePcAnchorBlend: 0.68,
            duetSamePcMinConfidence: 0.18,
            duetSamePcMinWeight: 0.008,
            duetSamePcStableBonus: 0.10,
            duetSamePcLatchBonus: 0.08,
            duetSamePcMaxBlend: 0.82,

            // externalFollow is calibration / special-use behavior.
            externalFollowAnchorBlend: 0.96,

            // If a held note exists, pull from its protected/current lived
            // phase rather than from ET reference. This is the critical fix.
            useHeldProtectedAsBase: true,
            useCurrentFieldAsBase: true,

            // Diagnostics.
            directionWarnCents: 0.25,
            reportEnabled: true
        );
    };

    at[\micResponseSamePcReasons] = {
        [\samePcOffsetExternal, \samePcLatchedExternal, \samePcFarExternal, \externalFollow]
    };

    at[\micResponseSourceForPc] = { |pc, sources|
        var list;
        list = (sources ? Array.new).select { |src|
            src.notNil and: {
                (src[\active] != false) and: {
                    src[\pc] == pc and: { src[\phase].notNil }
                }
            }
        };
        if(list.isEmpty) { nil } {
            list.sort { |a, b| (at[\sourceStrength].(a) ? 0.0) > (at[\sourceStrength].(b) ? 0.0) }[0]
        }
    };

    at[\micResponsePhaseCents] = { |phase, pc|
        if(phase.isNil or: { pc.isNil }) { nil } {
            (at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0)
        }
    };

    at[\micResponseNoteForPc] = { |pc|
        at[\notesArray].().detect { |n| n[\pc] == pc }
    };

    at[\micResponseBasePhaseForPc] = { |pc, defaultPhase|
        var note, base;
        note = at[\micResponseNoteForPc].(pc);
        base = defaultPhase;
        if((cfg[\micResponse][\useHeldProtectedAsBase] ? true) and: { note.notNil and: { note[\protectedPhase].notNil } }) {
            base = note[\protectedPhase];
        } {
            if((cfg[\micResponse][\useCurrentFieldAsBase] ? true) and: { st[\nodePhase].notNil }) {
                base = st[\nodePhase][pc];
            };
        };
        base;
    };

    at[\micResponseBlendForSource] = { |src|
        var reason, cls, policy, conf, weight, blend;
        if(src.isNil) { 0.0 } {
            reason = src[\policyReason] ? \unknown;
            cls = src[\sourceClass] ? \unknown;
            policy = at[\currentMicInfluencePolicy].();
            conf = src[\confidence] ? src[\policyConfidence] ? 0.0;
            weight = src[\weight] ? src[\policyWeight] ? 0.0;

            if(policy == \externalFollow or: { reason == \externalFollow }) {
                blend = cfg[\micResponse][\externalFollowAnchorBlend] ? 0.96;
            } {
                if(at[\micResponseSamePcReasons].().includes(reason)) {
                    if(conf < (cfg[\micResponse][\duetSamePcMinConfidence] ? 0.18) or: { weight < (cfg[\micResponse][\duetSamePcMinWeight] ? 0.008) }) {
                        blend = 0.0;
                    } {
                        blend = cfg[\micResponse][\duetSamePcAnchorBlend] ? 0.68;
                        if([\stableTone, \vibratoTone].includes(cls)) {
                            blend = blend + (cfg[\micResponse][\duetSamePcStableBonus] ? 0.10);
                        };
                        if(src[\policyReason] == \samePcLatchedExternal or: { src[\externalLatch] == true }) {
                            blend = blend + (cfg[\micResponse][\duetSamePcLatchBonus] ? 0.08);
                        };
                        blend = blend.clip(0.0, cfg[\micResponse][\duetSamePcMaxBlend] ? 0.82);
                    };
                } {
                    blend = 0.0;
                };
            };
            blend.clip(0.0, 1.0)
        }
    };

    at[\micResponseBuildReport] = { |pc, defaultPhase, basePhase, externalSrc, legacyPhase, responsePhase, blend|
        var extC, baseC, defC, legacyC, outC, currentC, targetDir, actualDir, toward;
        extC = if(externalSrc.notNil) { at[\micResponsePhaseCents].(externalSrc[\phase], pc) } { nil };
        baseC = at[\micResponsePhaseCents].(basePhase, pc);
        defC = at[\micResponsePhaseCents].(defaultPhase, pc);
        legacyC = at[\micResponsePhaseCents].(legacyPhase, pc);
        outC = at[\micResponsePhaseCents].(responsePhase, pc);
        currentC = at[\micResponsePhaseCents].(st[\nodePhase][pc], pc);
        targetDir = if(extC.notNil and: { baseC.notNil }) { (extC - baseC).sign } { 0 };
        actualDir = if(outC.notNil and: { baseC.notNil }) { (outC - baseC).sign } { 0 };
        toward = (targetDir == 0) or: { actualDir == 0 } or: { targetDir == actualDir };
        (
            timestamp: Main.elapsedTime,
            pc: pc,
            pcName: pitchClassNames[pc] ? pc.asString,
            policy: at[\currentMicInfluencePolicy].(),
            sourceId: if(externalSrc.notNil) { externalSrc[\id] } { nil },
            sourceClass: if(externalSrc.notNil) { externalSrc[\sourceClass] } { nil },
            policyReason: if(externalSrc.notNil) { externalSrc[\policyReason] } { nil },
            sourceWeight: if(externalSrc.notNil) { (externalSrc[\weight] ? 0.0).round(0.001) } { nil },
            sourceConfidence: if(externalSrc.notNil) { (externalSrc[\confidence] ? 0.0).round(0.001) } { nil },
            externalCents: if(extC.notNil) { extC.round(0.01) } { nil },
            defaultCents: if(defC.notNil) { defC.round(0.01) } { nil },
            baseCents: if(baseC.notNil) { baseC.round(0.01) } { nil },
            currentCents: if(currentC.notNil) { currentC.round(0.01) } { nil },
            legacyCents: if(legacyC.notNil) { legacyC.round(0.01) } { nil },
            responseCents: if(outC.notNil) { outC.round(0.01) } { nil },
            blend: blend.round(0.001),
            desiredDirection: targetDir,
            responseDirection: actualDir,
            responseTowardExternal: toward,
            responseDeltaFromBaseCents: if(outC.notNil and: { baseC.notNil }) { (outC - baseC).round(0.01) } { nil },
            externalDistanceFromBaseCents: if(extC.notNil and: { baseC.notNil }) { (extC - baseC).round(0.01) } { nil }
        )
    };

    if(at[\legacySingleAnchorPhaseWithExternal_MicResponse].isNil and: { at[\singleAnchorPhaseWithExternal].notNil }) {
        at[\legacySingleAnchorPhaseWithExternal_MicResponse] = at[\singleAnchorPhaseWithExternal];
    };

    at[\singleAnchorPhaseWithExternal] = { |pc, defaultPhase, externalSources|
        var legacy, src, blend, basePhase, responsePhase;
        if((cfg[\micResponse][\enabled] ? true).not) {
            at[\legacySingleAnchorPhaseWithExternal_MicResponse].(pc, defaultPhase, externalSources);
        } {
            legacy = at[\legacySingleAnchorPhaseWithExternal_MicResponse].(pc, defaultPhase, externalSources);
            src = at[\micResponseSourceForPc].(pc, externalSources ? Array.new);
            blend = at[\micResponseBlendForSource].(src);
            if(src.isNil or: { blend <= 0.0 }) {
                st[\lastMicFieldResponse] = at[\micResponseBuildReport].(pc, defaultPhase, defaultPhase, src, legacy, legacy, 0.0);
                legacy;
            } {
                basePhase = at[\micResponseBasePhaseForPc].(pc, defaultPhase);
                responsePhase = at[\phaseBlend].(basePhase, src[\phase], blend);
                st[\lastMicFieldResponse] = at[\micResponseBuildReport].(pc, defaultPhase, basePhase, src, legacy, responsePhase, blend);
                responsePhase;
            };
        };
    };



    // Post-memory / post-held-guard reassertion.
    // The earlier singleAnchorPhaseWithExternal hook proves the requested
    // mic response direction, but the normal install path can still dilute it
    // through tonal memory and held-note protection.  This final correction is
    // deliberately late: it changes only the target field after the ordinary
    // solver/memory/held guards have done their work.  Audible motion is still
    // limited by AT_motion, so this cannot snap the sounding note.
    if(cfg[\micResponse][\postTargetReassertEnabled].isNil) { cfg[\micResponse][\postTargetReassertEnabled] = true };
    if(cfg[\micResponse][\duetPostTargetBlend].isNil) { cfg[\micResponse][\duetPostTargetBlend] = 0.58 };
    if(cfg[\micResponse][\externalFollowPostTargetBlend].isNil) { cfg[\micResponse][\externalFollowPostTargetBlend] = 0.92 };
    if(cfg[\micResponse][\postTargetRotateSingle].isNil) { cfg[\micResponse][\postTargetRotateSingle] = true };
    if(cfg[\micResponse][\postTargetMaxCorrectionCents].isNil) { cfg[\micResponse][\postTargetMaxCorrectionCents] = 36.0 };
    if(cfg[\micResponse][\postTargetMinExternalDistanceCents].isNil) { cfg[\micResponse][\postTargetMinExternalDistanceCents] = 1.0 };

    at[\micResponsePhaseFromCents] = { |pc, cents|
        if(pc.isNil or: { cents.isNil }) { nil } {
            at[\wrap01].(st[\etPhase][pc] + (cents / 1200.0))
        }
    };

    at[\micResponsePostTargetBlendForReport] = { |mfr|
        var policy, reason;
        policy = at[\currentMicInfluencePolicy].();
        reason = mfr[\policyReason] ? \unknown;
        if(policy == \externalFollow or: { reason == \externalFollow }) {
            cfg[\micResponse][\externalFollowPostTargetBlend] ? 0.92
        } {
            cfg[\micResponse][\duetPostTargetBlend] ? 0.58
        }
    };

    at[\micResponsePostCorrectTarget] = { |reason=\resolve|
        var mfr, pc, responseCents, responsePhase, oldTargetPhase, oldTargetCents;
        var desiredDir, oldDir, blend, maxCorr, rawNew, rawOffset, clampedOffset, newTarget;
        var activePcs, rotateWhole, finalCents, toward, extCents, dist, shouldCorrect;
        mfr = st[\lastMicFieldResponse];
        if((cfg[\micResponse][\postTargetReassertEnabled] ? true).not or: { mfr.isNil }) {
            st[\lastMicTargetReassert] = (status: \disabledOrNoResponse);
            false
        } {
            pc = mfr[\pc];
            responseCents = mfr[\responseCents];
            extCents = mfr[\externalCents];
            shouldCorrect = (pc.notNil)
                and: { responseCents.notNil }
                and: { st[\targetPhase].notNil }
                and: { (mfr[\responseTowardExternal] == true) }
                and: { at[\micResponseSamePcReasons].().includes(mfr[\policyReason] ? \unknown) };
            if(shouldCorrect.not) {
                st[\lastMicTargetReassert] = (status: \skipped, reason: reason, micFieldResponse: mfr);
                false
            } {
                responsePhase = at[\micResponsePhaseFromCents].(pc, responseCents);
                oldTargetPhase = st[\targetPhase][pc];
                oldTargetCents = at[\micResponsePhaseCents].(oldTargetPhase, pc);
                dist = if(extCents.notNil and: { oldTargetCents.notNil }) { (extCents - oldTargetCents).abs } { 0.0 };
                if(dist < (cfg[\micResponse][\postTargetMinExternalDistanceCents] ? 1.0)) {
                    st[\lastMicTargetReassert] = (status: \alreadyClose, pc: pc, pcName: pitchClassNames[pc] ? pc.asString, targetCents: oldTargetCents, externalCents: extCents, distanceCents: dist.round(0.01));
                    false
                } {
                    blend = at[\micResponsePostTargetBlendForReport].(mfr).clip(0.0, 1.0);
                    rawNew = at[\phaseBlend].(oldTargetPhase, responsePhase, blend);
                    rawOffset = at[\wrapSigned].(rawNew - oldTargetPhase);
                    maxCorr = ((cfg[\micResponse][\postTargetMaxCorrectionCents] ? 36.0) / 1200.0).abs;
                    clampedOffset = rawOffset.clip(maxCorr.neg, maxCorr);
                    newTarget = at[\wrap01].(oldTargetPhase + clampedOffset);
                    activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
                    rotateWhole = (cfg[\micResponse][\postTargetRotateSingle] ? true) and: { activePcs.size == 1 and: { activePcs[0] == pc } };
                    if(rotateWhole) {
                        st[\targetPhase] = st[\targetPhase].collect { |p| at[\wrap01].(p + clampedOffset) };
                        st[\lastSolvedPhase] = (st[\lastSolvedPhase] ? st[\targetPhase]).collect { |p| at[\wrap01].(p + clampedOffset) };
                    } {
                        st[\targetPhase][pc] = newTarget;
                        if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase][pc] = newTarget; };
                    };
                    finalCents = at[\micResponsePhaseCents].(st[\targetPhase][pc], pc);
                    desiredDir = if(extCents.notNil and: { oldTargetCents.notNil }) { (extCents - oldTargetCents).sign } { 0 };
                    oldDir = if(finalCents.notNil and: { oldTargetCents.notNil }) { (finalCents - oldTargetCents).sign } { 0 };
                    toward = (desiredDir == 0) or: { oldDir == 0 } or: { desiredDir == oldDir };
                    st[\lastMicTargetReassert] = (
                        status: \applied,
                        reason: reason,
                        pc: pc,
                        pcName: pitchClassNames[pc] ? pc.asString,
                        policy: mfr[\policy],
                        policyReason: mfr[\policyReason],
                        sourceClass: mfr[\sourceClass],
                        externalCents: extCents,
                        responseCents: responseCents,
                        oldTargetCents: if(oldTargetCents.notNil) { oldTargetCents.round(0.01) } { nil },
                        finalTargetCents: if(finalCents.notNil) { finalCents.round(0.01) } { nil },
                        correctionCents: (clampedOffset * 1200.0).round(0.01),
                        blend: blend.round(0.001),
                        rotateWholeField: rotateWhole,
                        towardExternal: toward
                    );
                    true
                }
            }
        }
    };

    if(at[\legacyInstallSolvedTarget_MicResponse].isNil and: { at[\installSolvedTarget].notNil }) {
        at[\legacyInstallSolvedTarget_MicResponse] = at[\installSolvedTarget];
        at[\installSolvedTarget] = { |oldPhase, solvedPhase, reason=\resolve|
            at[\legacyInstallSolvedTarget_MicResponse].(oldPhase, solvedPhase, reason);
            at[\micResponsePostCorrectTarget].(reason);
            st[\targetPhase]
        };
    };

    // Wrapper for fieldReport/uiSnapshot diagnostics if a report builder exists.
    oldBuildReport = at[\buildMicSceneReport];
    if(oldBuildReport.notNil and: { at[\legacyBuildMicSceneReport_MicResponse].isNil }) {
        at[\legacyBuildMicSceneReport_MicResponse] = oldBuildReport;
        at[\buildMicSceneReport] = {
            var rep, mfr;
            rep = at[\legacyBuildMicSceneReport_MicResponse].();
            mfr = st[\lastMicFieldResponse];
            rep[\micFieldResponse] = mfr;
            rep[\micFieldResponseTowardExternal] = if(mfr.notNil) { mfr[\responseTowardExternal] } { nil };
            rep[\micFieldResponseBlend] = if(mfr.notNil) { mfr[\blend] } { nil };
            rep[\micFieldResponseExternalCents] = if(mfr.notNil) { mfr[\externalCents] } { nil };
            rep[\micFieldResponseCurrentCents] = if(mfr.notNil) { mfr[\currentCents] } { nil };
            rep[\micFieldResponseTargetCents] = if(mfr.notNil) { mfr[\responseCents] } { nil };
            rep[\micTargetReassert] = st[\lastMicTargetReassert];
            rep;
        };
    };

    api[\micFieldResponseReport] = {
        var rep;
        rep = st[\lastMicFieldResponse] ? (status: \none, message: "No mic field response has been computed yet.");
        if(rep.isKindOf(Event) or: { rep.isKindOf(Dictionary) }) { rep[\targetReassert] = st[\lastMicTargetReassert] };
        rep.postln;
        rep
    };
    at[\micFieldResponseReport] = { api[\micFieldResponseReport].(); };

    "[at-mic-field-response] mic field response loaded".postln;
};
)
