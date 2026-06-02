(
// AT_pitch_identity_spacing_guard.scd
// v3D24c: musical pitch-identity spacing / strain guard with repeated fieldTick log suppression.
//
// v3D21b prevents pitch identities from crossing/folding.
// v3D23 proved that topology safety alone is not the musical invariant:
// raw fish-core path transport could still compress the wrapped 12-note
// keyboard ring to unusable spacing while remaining ordered.
//
// v3D24c adds the missing field-commit invariant.  The adaptive field may
// transport, bend, and breathe, but the named pitch-class map must remain a
// playable chromatic keyboard surface.  This is not an equal-temperament clamp:
// it preserves order, gauge/sheet transport, and safe active offsets while
// elastically redistributing local strain when a candidate field crumples.

var build, at, cfg, st, api;

build = ~atBuild;

if(build.isNil) {
    "[AT PITCH IDENTITY SPACING GUARD] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(st[\pitchIdentitySpacingGuard].isNil) { st[\pitchIdentitySpacingGuard] = IdentityDictionary.new; };
    if(cfg[\pitchIdentitySpacingGuard].isNil) {
        cfg[\pitchIdentitySpacingGuard] = (
            enabled: true,
            passiveNeighborFloorCents: 75.0,
            activeNeighborFloorCents: 85.0,
            maxNeighborGapCents: 155.0,
            absoluteEmergencyFloorCents: 60.0,
            preserveActiveAnchor: true,
            debug: false,
            suppressRepeatedTickPosts: true,
            quietPostReasons: [\fieldTick, \motionStep, \micFieldResponseAcceptance, \micPolyResponseAcceptance, \newMidiAfterMicHold]
        );
    };
    if(st[\pitchIdentitySpacingGuardInterventionCount].isNil) { st[\pitchIdentitySpacingGuardInterventionCount] = 0; };

    // v3D24c makes the audit thresholds match the musical rule: even raw
    // fishCoreDiagnostic may be uninhibited in authority, but it may not crumple
    // the wrapped keyboard surface.  Sheet transport remains available through
    // coreUnwrappedPhase.
    if(cfg[\pitchIdentitySpacing].notNil) {
        cfg[\pitchIdentitySpacing][\diagnosticNeighborFloorCents] = (cfg[\pitchIdentitySpacingGuard][\passiveNeighborFloorCents] ? 75.0);
        cfg[\pitchIdentitySpacing][\diagnosticActiveNeighborFloorCents] = (cfg[\pitchIdentitySpacingGuard][\activeNeighborFloorCents] ? 85.0);
        cfg[\pitchIdentitySpacing][\diagnosticMaxNeighborGapCents] = (cfg[\pitchIdentitySpacingGuard][\maxNeighborGapCents] ? 155.0);
        cfg[\pitchIdentitySpacing][\absoluteEmergencyFloorCents] = (cfg[\pitchIdentitySpacingGuard][\absoluteEmergencyFloorCents] ? 60.0);
        cfg[\pitchIdentitySpacing][\fishCoreDiagnosticMayCompress] = false;
    };

    at[\pitchIdentitySpacingGuardActivePcs] = {
        if(at[\pitchIdentityGuardActivePcs].notNil) {
            at[\pitchIdentityGuardActivePcs].()
        } {
            if(at[\pitchIdentityActivePcs].notNil) { at[\pitchIdentityActivePcs].() } { Array.new }
        }
    };

    at[\pitchIdentitySpacingGuardPcName] = { |pc|
        if(at[\pitchIdentityPcName].notNil) { at[\pitchIdentityPcName].(pc) } { pc.asString }
    };

    at[\pitchIdentitySpacingGuardThresholds] = {
        var g;
        g = cfg[\pitchIdentitySpacingGuard] ? ();
        (
            passiveNeighborFloorCents: g[\passiveNeighborFloorCents] ? 75.0,
            activeNeighborFloorCents: g[\activeNeighborFloorCents] ? 85.0,
            maxNeighborGapCents: g[\maxNeighborGapCents] ? 155.0,
            absoluteEmergencyFloorCents: g[\absoluteEmergencyFloorCents] ? 60.0
        )
    };

    at[\pitchIdentitySpacingGuardAssess] = { |phases, label=\spacingCandidate, activePcs=nil|
        var activeSet, active, order, th, gaps, activeRisks, passiveRisks, emergencyRisks, stretchRisks, allRisks, needsAction, compact;
        phases = (phases ? (st[\nodePhase] ? st[\etPhase])).copy;
        active = activePcs ? at[\pitchIdentitySpacingGuardActivePcs].();
        activeSet = IdentitySet.new;
        active.do { |pc| activeSet.add(pc.asInteger % 12) };
        th = at[\pitchIdentitySpacingGuardThresholds].();
        order = if(at[\pitchIdentityOrderForPhases].notNil) {
            at[\pitchIdentityOrderForPhases].(phases, label, active)
        } {
            (pcOrderPreserved: true, neighborGapsCents: Array.fill(12, { 100.0 }), minNeighborDistanceCents: 100.0, maxNeighborDistanceCents: 100.0, minActiveNeighborDistanceCents: nil, collisions: Array.new, activeCollisions: Array.new)
        };
        gaps = order[\neighborGapsCents] ? Array.fill(12, { 100.0 });
        activeRisks = Array.new;
        passiveRisks = Array.new;
        emergencyRisks = Array.new;
        stretchRisks = Array.new;
        12.do { |pc|
            var next, gap, activeInvolved, rec;
            next = (pc + 1) % 12;
            gap = gaps[pc] ? 0.0;
            activeInvolved = activeSet.includes(pc) or: { activeSet.includes(next) };
            rec = (
                pc: pc, nextPc: next,
                pcName: at[\pitchIdentitySpacingGuardPcName].(pc),
                nextPcName: at[\pitchIdentitySpacingGuardPcName].(next),
                gapCents: gap.round(0.01),
                activeInvolved: activeInvolved
            );
            if(activeInvolved) {
                if(gap < (th[\activeNeighborFloorCents] ? 85.0)) { activeRisks = activeRisks.add(rec) };
            } {
                if(gap < (th[\passiveNeighborFloorCents] ? 75.0)) { passiveRisks = passiveRisks.add(rec) };
            };
            if(gap < (th[\absoluteEmergencyFloorCents] ? 60.0)) { emergencyRisks = emergencyRisks.add(rec) };
            if(gap > (th[\maxNeighborGapCents] ? 155.0)) { stretchRisks = stretchRisks.add(rec) };
        };
        allRisks = activeRisks ++ passiveRisks ++ emergencyRisks ++ stretchRisks;
        needsAction = (order[\pcOrderPreserved] != true)
            or: { (order[\collisions] ? Array.new).notEmpty }
            or: { (order[\activeCollisions] ? Array.new).notEmpty }
            or: { allRisks.notEmpty };
        compact = "order=" ++ (order[\pcOrderPreserved] == true).asString
            ++ " min=" ++ (order[\minNeighborDistanceCents] ? nil).asString ++ "c"
            ++ " max=" ++ (order[\maxNeighborDistanceCents] ? nil).asString ++ "c"
            ++ " activeMin=" ++ (order[\minActiveNeighborDistanceCents] ? nil).asString ++ "c"
            ++ " activeRisks=" ++ activeRisks.size.asString
            ++ " passiveRisks=" ++ passiveRisks.size.asString
            ++ " stretchRisks=" ++ stretchRisks.size.asString
            ++ " emergency=" ++ emergencyRisks.size.asString;
        (
            label: label,
            activePcs: active,
            activePcNames: active.collect { |pc| at[\pitchIdentitySpacingGuardPcName].(pc) },
            thresholds: th,
            orderReport: order,
            pcOrderPreserved: order[\pcOrderPreserved],
            minNeighborDistanceCents: order[\minNeighborDistanceCents],
            maxNeighborDistanceCents: order[\maxNeighborDistanceCents],
            minActiveNeighborDistanceCents: order[\minActiveNeighborDistanceCents],
            activeTerritoryRisks: activeRisks,
            passiveTerritoryRisks: passiveRisks,
            emergencySpacingRisks: emergencyRisks,
            excessiveStretchRisks: stretchRisks,
            needsAction: needsAction,
            compact: compact
        )
    };

    at[\pitchIdentitySpacingGuardChooseAnchorPc] = { |candidatePhase, activePcs=nil|
        var active;
        active = activePcs ? at[\pitchIdentitySpacingGuardActivePcs].();
        if(((cfg[\pitchIdentitySpacingGuard] ? ())[\preserveActiveAnchor] ? true) and: { active.notEmpty }) {
            active.asArray.sort[0].asInteger % 12
        } {
            0
        }
    };

    at[\pitchIdentitySpacingGuardAdjustGaps] = { |rawGaps, activePcs=nil|
        var th, activeSet, minGaps, maxGaps, gaps, sum, iter, surplus, deficit, reducible, expandable, total, eps, idx, room;
        activePcs = activePcs ? at[\pitchIdentitySpacingGuardActivePcs].();
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc.asInteger % 12) };
        th = at[\pitchIdentitySpacingGuardThresholds].();
        minGaps = Array.fill(12, { |pc|
            var next;
            next = (pc + 1) % 12;
            if(activeSet.includes(pc) or: { activeSet.includes(next) }) {
                (th[\activeNeighborFloorCents] ? 85.0) / 1200.0
            } {
                (th[\passiveNeighborFloorCents] ? 75.0) / 1200.0
            }
        });
        maxGaps = Array.fill(12, { ((th[\maxNeighborGapCents] ? 155.0) / 1200.0).max((th[\activeNeighborFloorCents] ? 85.0) / 1200.0) });
        // If the configured floors/caps somehow become infeasible, fall back to
        // a uniform keyboard surface rather than producing a broken map.
        if((minGaps.sum > 0.999) or: { maxGaps.sum < 1.001 }) {
            ^Array.fill(12, { 1.0 / 12.0 });
        };
        gaps = Array.fill(12, { |i| (rawGaps[i] ? (1.0 / 12.0)).clip(minGaps[i], maxGaps[i]) });
        eps = 0.0000001;
        iter = 0;
        while { iter < 32 } {
            sum = gaps.sum;
            if((sum - 1.0).abs <= eps) { iter = 32 } {
                if(sum > 1.0) {
                    surplus = sum - 1.0;
                    reducible = Array.fill(12, { |i| (gaps[i] - minGaps[i]).max(0.0) });
                    total = reducible.sum;
                    if(total <= eps) {
                        gaps = Array.fill(12, { 1.0 / 12.0 });
                        iter = 32;
                    } {
                        12.do { |i| gaps[i] = gaps[i] - (surplus * (reducible[i] / total)).min(reducible[i]) };
                    };
                } {
                    deficit = 1.0 - sum;
                    expandable = Array.fill(12, { |i| (maxGaps[i] - gaps[i]).max(0.0) });
                    total = expandable.sum;
                    if(total <= eps) {
                        gaps = Array.fill(12, { 1.0 / 12.0 });
                        iter = 32;
                    } {
                        12.do { |i| gaps[i] = gaps[i] + (deficit * (expandable[i] / total)).min(expandable[i]) };
                    };
                };
                iter = iter + 1;
            };
        };
        // Close any tiny floating drift on the largest available gap.
        sum = gaps.sum;
        if((sum - 1.0).abs > eps) {
            if(sum < 1.0) {
                idx = 0;
                12.do { |i| if((maxGaps[i] - gaps[i]) > (maxGaps[idx] - gaps[idx])) { idx = i } };
                room = (maxGaps[idx] - gaps[idx]).max(0.0);
                gaps[idx] = gaps[idx] + (1.0 - sum).min(room);
            } {
                idx = 0;
                12.do { |i| if((gaps[i] - minGaps[i]) > (gaps[idx] - minGaps[idx])) { idx = i } };
                room = (gaps[idx] - minGaps[idx]).max(0.0);
                gaps[idx] = gaps[idx] - (sum - 1.0).min(room);
            };
        };
        gaps
    };

    at[\pitchIdentitySpacingGuardProject] = { |candidatePhase, activePcs=nil|
        var active, anchor, rawGaps, adjustedGaps, out, i, pc, prev;
        active = activePcs ? at[\pitchIdentitySpacingGuardActivePcs].();
        candidatePhase = (candidatePhase ? (st[\nodePhase] ? st[\etPhase])).copy;
        rawGaps = Array.fill(12, { |pc| at[\wrap01].((candidatePhase[(pc + 1) % 12] ? ((pc + 1) / 12.0)) - (candidatePhase[pc] ? (pc / 12.0))) });
        adjustedGaps = at[\pitchIdentitySpacingGuardAdjustGaps].(rawGaps, active);
        anchor = at[\pitchIdentitySpacingGuardChooseAnchorPc].(candidatePhase, active);
        out = Array.fill(12, 0.0);
        out[anchor] = at[\wrap01].(candidatePhase[anchor] ? (anchor / 12.0));
        i = 1;
        while { i < 12 } {
            pc = (anchor + i) % 12;
            prev = (pc + 11) % 12;
            out[pc] = at[\wrap01].((out[prev] ? 0.0) + (adjustedGaps[prev] ? (1.0 / 12.0)));
            i = i + 1;
        };
        out
    };

    at[\pitchIdentitySpacingGuardUnwrappedFromProjection] = { |candidatePhase, candidateUnwrapped, projectedPhase|
        candidatePhase = (candidatePhase ? st[\etPhase]).copy;
        candidateUnwrapped = (candidateUnwrapped ? candidatePhase).copy;
        projectedPhase = (projectedPhase ? candidatePhase).copy;
        Array.fill(12, { |pc|
            (candidateUnwrapped[pc] ? candidatePhase[pc]) + at[\wrapSigned].((projectedPhase[pc] ? candidatePhase[pc]) - (candidatePhase[pc] ? 0.0))
        })
    };

    at[\pitchIdentitySpacingGuardMaxDeltaCents] = { |a, b|
        Array.fill(12, { |i| at[\wrapSigned].((a[i] ? 0.0) - (b[i] ? 0.0)).abs * 1200.0 }).maxItem ? 0.0
    };

    at[\applyPitchIdentitySpacingGuard] = { |oldPhase, candidatePhase, candidateUnwrapped=nil, reason=\fieldCommit, oldUnwrapped=nil, topologyOut=nil|
        var enabled, activePcs, candidateAssess, projectedPhase, projectedUnwrapped, projectedAssess, oldAssess, outPhase, outUnwrapped, action, strategy, report, maxDelta, shouldPost, quietRepeated, quietReason, quietReasons, postSignature;
        enabled = (cfg[\pitchIdentitySpacingGuard] ? (enabled: true))[\enabled] ? true;
        activePcs = at[\pitchIdentitySpacingGuardActivePcs].();
        oldPhase = (oldPhase ? (st[\nodePhase] ? st[\etPhase])).copy;
        oldUnwrapped = (oldUnwrapped ? oldPhase).copy;
        candidatePhase = (candidatePhase ? oldPhase).copy;
        candidateUnwrapped = (candidateUnwrapped ? candidatePhase).copy;
        outPhase = candidatePhase.copy;
        outUnwrapped = candidateUnwrapped.copy;
        action = false;
        strategy = \none;
        candidateAssess = at[\pitchIdentitySpacingGuardAssess].(candidatePhase, \spacingCandidate, activePcs);
        oldAssess = at[\pitchIdentitySpacingGuardAssess].(oldPhase, \spacingPreviousField, activePcs);

        if(enabled and: { candidateAssess[\needsAction] == true }) {
            projectedPhase = at[\pitchIdentitySpacingGuardProject].(candidatePhase, activePcs);
            projectedUnwrapped = at[\pitchIdentitySpacingGuardUnwrappedFromProjection].(candidatePhase, candidateUnwrapped, projectedPhase);
            projectedAssess = at[\pitchIdentitySpacingGuardAssess].(projectedPhase, \spacingGuardOutput, activePcs);
            if(projectedAssess[\needsAction] == false) {
                action = true;
                strategy = \elasticBoundedKeyboardSurface;
                outPhase = projectedPhase.copy;
                outUnwrapped = projectedUnwrapped.copy;
            } {
                if(oldAssess[\needsAction] == false) {
                    action = true;
                    strategy = \preservePreviousLegibleField;
                    outPhase = oldPhase.copy;
                    outUnwrapped = oldUnwrapped.copy;
                    projectedAssess = oldAssess;
                } {
                    action = true;
                    strategy = \uniformKeyboardSurfaceFallback;
                    outPhase = Array.fill(12, { |pc| ((pc / 12.0) + (candidatePhase[0] ? 0.0)).wrap(0.0, 1.0) });
                    outUnwrapped = at[\pitchIdentitySpacingGuardUnwrappedFromProjection].(candidatePhase, candidateUnwrapped, outPhase);
                    projectedAssess = at[\pitchIdentitySpacingGuardAssess].(outPhase, \spacingGuardUniformFallback, activePcs);
                };
            };
        } {
            projectedAssess = candidateAssess;
        };

        maxDelta = at[\pitchIdentitySpacingGuardMaxDeltaCents].(outPhase, candidatePhase).round(0.01);
        if(action) { st[\pitchIdentitySpacingGuardInterventionCount] = (st[\pitchIdentitySpacingGuardInterventionCount] ? 0) + 1; };
        report = (
            branch: \v3D24c_pitch_identity_spacing_guard,
            enabled: enabled,
            acted: action,
            strategy: strategy,
            reason: reason,
            activePcs: activePcs,
            activePcNames: activePcs.collect { |pc| at[\pitchIdentitySpacingGuardPcName].(pc) },
            candidateNeedsAction: candidateAssess[\needsAction],
            candidateCompact: candidateAssess[\compact],
            previousFieldLegible: oldAssess[\needsAction].not,
            previousCompact: oldAssess[\compact],
            outputNeedsAction: projectedAssess[\needsAction],
            outputCompact: projectedAssess[\compact],
            maxGuardDeltaCents: maxDelta,
            interventionCount: st[\pitchIdentitySpacingGuardInterventionCount] ? 0,
            suppressedRepeatedPostCount: st[\pitchIdentitySpacingGuardSuppressedPostCount] ? 0,
            pitchAuthority: false,
            topologyAuthority: false,
            spacingAuthority: action,
            topologyReport: if(topologyOut.notNil) { topologyOut[\report] ? topologyOut } { nil },
            note: if(action) { "Rejected or elastically redistributed an over-compressed pitch-identity field commit; the keyboard surface remains legible." } { "No spacing guard intervention; field commit retained ordinary pitch-identity territory." }
        );
        st[\lastPitchIdentitySpacingGuard] = report;
        if(action) { st[\lastPitchIdentitySpacingGuardAction] = report; };

        // v3D24c: deterministic mic/regression suites can intentionally create
        // many tiny unsafe intermediate candidates while proving other behavior.
        // The guard still acts, counts interventions, and keeps latest/last reports,
        // but quiet internal tick/acceptance reasons do not flood the post window
        // unless debug is explicitly enabled.
        postSignature = reason.asString ++ "|" ++ strategy.asString ++ "|" ++ candidateAssess[\compact].asString ++ "|" ++ projectedAssess[\compact].asString;
        quietReasons = (cfg[\pitchIdentitySpacingGuard] ? ())[\quietPostReasons] ? [\fieldTick, \motionStep];
        quietReason = quietReasons.includes(reason)
            and: { ((cfg[\pitchIdentitySpacingGuard] ? ())[\suppressRepeatedTickPosts] ? true) == true }
            and: { ((cfg[\pitchIdentitySpacingGuard] ? ())[\debug] ? false).not };
        quietRepeated = ([\fieldTick, \motionStep].includes(reason))
            and: { ((cfg[\pitchIdentitySpacingGuard] ? ())[\suppressRepeatedTickPosts] ? true) == true }
            and: { ((cfg[\pitchIdentitySpacingGuard] ? ())[\debug] ? false).not };
        shouldPost = (action or: { (cfg[\pitchIdentitySpacingGuard] ? ())[\debug] ? false });
        if(shouldPost and: { quietReason }) {
            st[\pitchIdentitySpacingGuardSuppressedPostCount] = (st[\pitchIdentitySpacingGuardSuppressedPostCount] ? 0) + 1;
            shouldPost = false;
        } {
            if(shouldPost and: { quietRepeated }) {
                if(postSignature == st[\lastPitchIdentitySpacingGuardPostSignature]) {
                    st[\pitchIdentitySpacingGuardSuppressedPostCount] = (st[\pitchIdentitySpacingGuardSuppressedPostCount] ? 0) + 1;
                    shouldPost = false;
                } {
                    st[\lastPitchIdentitySpacingGuardPostSignature] = postSignature;
                    st[\pitchIdentitySpacingGuardSuppressedPostCount] = 0;
                };
            };
        };
        if(shouldPost) {
            ("[AT PITCH IDENTITY SPACING GUARD] acted=" ++ action.asString
                ++ " strategy=" ++ strategy.asString
                ++ " reason=" ++ reason.asString
                ++ " candidate=" ++ candidateAssess[\compact].asString
                ++ " output=" ++ projectedAssess[\compact].asString
                ++ " maxDelta=" ++ maxDelta.asString ++ "c").postln;
        };
        (phase: outPhase, unwrapped: outUnwrapped, changed: action, report: report)
    };

    // Wrap the already-installed topology guard so every field commit path that
    // was made topology-safe in v3D21b also becomes spacing-safe in v3D24.
    if(((st[\pitchIdentitySpacingGuard][\topologyGuardWrapped] ? false).not) and: { at[\applyPitchIdentityTopologyGuard].notNil }) {
        at[\applyPitchIdentityTopologyGuardWithoutSpacing] = at[\applyPitchIdentityTopologyGuard];
        at[\applyPitchIdentityTopologyGuard] = { |oldPhase, solvedPhase, solvedUnwrapped=nil, reason=\resolve, oldUnwrapped=nil|
            var topOut, spacingOut, combined;
            topOut = at[\applyPitchIdentityTopologyGuardWithoutSpacing].(oldPhase, solvedPhase, solvedUnwrapped, reason, oldUnwrapped);
            if(at[\applyPitchIdentitySpacingGuard].notNil) {
                spacingOut = at[\applyPitchIdentitySpacingGuard].(oldPhase, topOut[\phase] ? solvedPhase, topOut[\unwrapped] ? solvedUnwrapped, reason, oldUnwrapped, topOut);
                combined = (
                    phase: spacingOut[\phase] ? (topOut[\phase] ? solvedPhase),
                    unwrapped: spacingOut[\unwrapped] ? (topOut[\unwrapped] ? solvedUnwrapped),
                    changed: ((topOut[\changed] ? false) or: { spacingOut[\changed] ? false }),
                    report: topOut[\report],
                    topologyReport: topOut[\report],
                    spacingReport: spacingOut[\report]
                );
                combined
            } {
                topOut
            }
        };
        st[\pitchIdentitySpacingGuard][\topologyGuardWrapped] = true;
    };

    api[\pitchIdentitySpacingGuardReport] = {
        var rep;
        rep = st[\lastPitchIdentitySpacingGuard] ? (
            branch: \v3D24c_pitch_identity_spacing_guard,
            enabled: (cfg[\pitchIdentitySpacingGuard] ? (enabled: true))[\enabled] ? true,
            acted: false,
            strategy: \none,
            interventionCount: st[\pitchIdentitySpacingGuardInterventionCount] ? 0,
            suppressedRepeatedPostCount: st[\pitchIdentitySpacingGuardSuppressedPostCount] ? 0,
            lastActionStrategy: if(st[\lastPitchIdentitySpacingGuardAction].notNil) { st[\lastPitchIdentitySpacingGuardAction][\strategy] } { nil },
            lastActionReason: if(st[\lastPitchIdentitySpacingGuardAction].notNil) { st[\lastPitchIdentitySpacingGuardAction][\reason] } { nil },
            pitchAuthority: false,
            topologyAuthority: false,
            spacingAuthority: false,
            note: "No spacing guard report has been generated yet."
        );
        if(rep[\lastActionStrategy].isNil and: { st[\lastPitchIdentitySpacingGuardAction].notNil }) {
            rep[\lastActionStrategy] = st[\lastPitchIdentitySpacingGuardAction][\strategy];
            rep[\lastActionReason] = st[\lastPitchIdentitySpacingGuardAction][\reason];
        };
        "".postln;
        "[AT PITCH IDENTITY SPACING GUARD REPORT]".postln;
        ("enabled=" ++ (rep[\enabled] ? true).asString
            ++ " acted=" ++ (rep[\acted] ? false).asString
            ++ " strategy=" ++ (rep[\strategy] ? \none).asString
            ++ " interventions=" ++ (rep[\interventionCount] ? 0).asString
            ++ " lastAction=" ++ (rep[\lastActionStrategy] ? \none).asString
            ++ " spacingAuthority=" ++ (rep[\spacingAuthority] ? false).asString).postln;
        rep
    };

    api[\pitchIdentitySpacingGuardPlan] = {
        (
            branch: \v3D24c_pitch_identity_spacing_guard,
            invariant: "The field may move, but the keyboard must remain a keyboard.",
            enabled: (cfg[\pitchIdentitySpacingGuard] ? (enabled: true))[\enabled] ? true,
            passiveNeighborFloorCents: (cfg[\pitchIdentitySpacingGuard] ? ())[\passiveNeighborFloorCents] ? 75.0,
            activeNeighborFloorCents: (cfg[\pitchIdentitySpacingGuard] ? ())[\activeNeighborFloorCents] ? 85.0,
            maxNeighborGapCents: (cfg[\pitchIdentitySpacingGuard] ? ())[\maxNeighborGapCents] ? 155.0,
            absoluteEmergencyFloorCents: (cfg[\pitchIdentitySpacingGuard] ? ())[\absoluteEmergencyFloorCents] ? 60.0,
            notEqualTemperamentClamp: true,
            preservesSheetTransport: true,
            suppressRepeatedTickPosts: (cfg[\pitchIdentitySpacingGuard] ? ())[\suppressRepeatedTickPosts] ? true,
            quietPostReasons: (cfg[\pitchIdentitySpacingGuard] ? ())[\quietPostReasons] ? [\fieldTick, \motionStep],
            pitchAuthority: false,
            topologyAuthority: false,
            spacingAuthority: true
        )
    };

    "[AT PITCH IDENTITY SPACING GUARD] Loaded v3D24c bounded keyboard-surface strain guard with deterministic mic/regression post quieting; no samples, tones, mic policy, Sethares/cylinder authority, or visual art changed.".postln;
};
)
