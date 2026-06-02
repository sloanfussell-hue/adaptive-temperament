(
// AT_pitch_identity_runtime_guard.scd
// v3C clean runtime guard: keeps the named 12-pitch-class surface playable.
// Not ET snapping, not a chord/key detector, not a new mode.

var build, at, cfg, st, api;

build = ~atBuild;

if(build.isNil) {
    "[at-pitch-identity] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api];

    if(cfg[\pitchIdentityRuntimeGuard].isNil) {
        cfg[\pitchIdentityRuntimeGuard] = (
            enabled: true,
            passiveNeighborFloorCents: 72.0,
            activeNeighborFloorCents: 84.0,
            maxNeighborGapCents: 158.0,
            emergencyFloorCents: 58.0,
            preserveActiveAnchor: true,
            debug: false
        );
    };
    if(st[\pitchIdentityRuntimeGuardInterventionCount].isNil) { st[\pitchIdentityRuntimeGuardInterventionCount] = 0; };

    at[\pitchIdentityRuntimeActivePcs] = {
        (st[\activeNotes] ? IdentityDictionary.new).values.asArray.collect { |n| n[\pc] ? 0 }.as(Set).asArray.sort;
    };

    at[\pitchIdentityRuntimeOrderIsRotation] = { |order|
        var pcs, ok;
        pcs = order.collect { |e| e[\pc] ? 0 };
        if(pcs.size != 12) { false } {
            ok = false;
            12.do { |start|
                var good;
                good = true;
                12.do { |i| if((pcs[i] ? -1) != ((start + i) % 12)) { good = false } };
                if(good) { ok = true };
            };
            ok
        }
    };

    at[\pitchIdentityRuntimeAssess] = { |phases, reason=\candidate, activePcs=nil|
        var p, active, activeSet, entries, gaps, minGap, maxGap, activeMin, close, stretch, orderOk, cfgG, passFloor, actFloor, maxAllowed, emergency, needs;
        p = (phases ? (st[\nodePhase] ? st[\etPhase])).copy;
        active = activePcs ? at[\pitchIdentityRuntimeActivePcs].();
        activeSet = IdentitySet.new;
        active.do { |pc| activeSet.add(pc.asInteger % 12) };
        cfgG = cfg[\pitchIdentityRuntimeGuard] ? ();
        passFloor = (cfgG[\passiveNeighborFloorCents] ? 72.0) / 1200.0;
        actFloor = (cfgG[\activeNeighborFloorCents] ? 84.0) / 1200.0;
        maxAllowed = (cfgG[\maxNeighborGapCents] ? 158.0) / 1200.0;
        emergency = (cfgG[\emergencyFloorCents] ? 58.0) / 1200.0;
        entries = Array.fill(12, { |pc| (pc: pc, phase: at[\wrap01].(p[pc] ? (pc/12.0))) });
        entries = entries.sort { |a,b| (a[\phase] ? 0.0) < (b[\phase] ? 0.0) };
        orderOk = at[\pitchIdentityRuntimeOrderIsRotation].(entries);
        gaps = Array.fill(12, { |pc| at[\wrap01].((p[(pc+1)%12] ? ((pc+1)/12.0)) - (p[pc] ? (pc/12.0))) });
        minGap = gaps.minItem ? (1.0/12.0); maxGap = gaps.maxItem ? (1.0/12.0);
        activeMin = nil; close = Array.new; stretch = Array.new;
        12.do { |pc|
            var next, gap, floor, activeInvolved;
            next = (pc+1)%12; gap = gaps[pc] ? (1.0/12.0);
            activeInvolved = activeSet.includes(pc) or: { activeSet.includes(next) };
            floor = if(activeInvolved) { actFloor } { passFloor };
            if(activeInvolved) { activeMin = if(activeMin.isNil) { gap } { activeMin.min(gap) } };
            if((gap < floor) or: { gap < emergency }) { close = close.add((pc:pc,nextPc:next,gapCents:(gap*1200.0).round(0.01),active:activeInvolved)) };
            if(gap > maxAllowed) { stretch = stretch.add((pc:pc,nextPc:next,gapCents:(gap*1200.0).round(0.01),active:activeInvolved)) };
        };
        needs = (orderOk.not) or: { close.notEmpty or: { stretch.notEmpty } };
        (
            reason: reason, activePcs: active, orderPreserved: orderOk,
            minGapCents: (minGap*1200.0).round(0.01), maxGapCents: (maxGap*1200.0).round(0.01),
            activeMinGapCents: if(activeMin.isNil) { nil } { (activeMin*1200.0).round(0.01) },
            closeRisks: close, stretchRisks: stretch, needsAction: needs,
            compact: "order=" ++ orderOk.asString ++ " min=" ++ (minGap*1200.0).round(0.01).asString ++ "c max=" ++ (maxGap*1200.0).round(0.01).asString ++ "c close=" ++ close.size.asString ++ " stretch=" ++ stretch.size.asString
        )
    };

    at[\pitchIdentityRuntimeAdjustGaps] = { |rawGaps, activePcs=nil|
        var active, activeSet, cfgG, passFloor, actFloor, maxAllowed, minGaps, maxGaps, gaps, sum, eps, iter;
        active = activePcs ? at[\pitchIdentityRuntimeActivePcs].();
        activeSet = IdentitySet.new;
        active.do { |pc| activeSet.add(pc.asInteger % 12) };
        cfgG = cfg[\pitchIdentityRuntimeGuard] ? ();
        passFloor = (cfgG[\passiveNeighborFloorCents] ? 72.0) / 1200.0;
        actFloor = (cfgG[\activeNeighborFloorCents] ? 84.0) / 1200.0;
        maxAllowed = (cfgG[\maxNeighborGapCents] ? 158.0) / 1200.0;
        minGaps = Array.fill(12, { |pc| if(activeSet.includes(pc) or: { activeSet.includes((pc+1)%12) }) { actFloor } { passFloor } });
        maxGaps = Array.fill(12, { maxAllowed.max(actFloor) });
        if((minGaps.sum > 0.995) or: { maxGaps.sum < 1.005 }) { ^Array.fill(12, { 1.0/12.0 }) };
        gaps = Array.fill(12, { |i| (rawGaps[i] ? (1.0/12.0)).clip(minGaps[i], maxGaps[i]) });
        eps = 0.0000001; iter = 0;
        while { iter < 48 } {
            sum = gaps.sum;
            if((sum - 1.0).abs <= eps) { iter = 48 } {
                if(sum > 1.0) {
                    var surplus, room, total;
                    surplus = sum - 1.0; room = Array.fill(12, { |i| (gaps[i] - minGaps[i]).max(0.0) }); total = room.sum;
                    if(total <= eps) { gaps = Array.fill(12, { 1.0/12.0 }); iter = 48 } { 12.do { |i| gaps[i] = gaps[i] - (surplus * (room[i]/total)).min(room[i]) } };
                } {
                    var deficit, room, total;
                    deficit = 1.0 - sum; room = Array.fill(12, { |i| (maxGaps[i] - gaps[i]).max(0.0) }); total = room.sum;
                    if(total <= eps) { gaps = Array.fill(12, { 1.0/12.0 }); iter = 48 } { 12.do { |i| gaps[i] = gaps[i] + (deficit * (room[i]/total)).min(room[i]) } };
                };
                iter = iter + 1;
            };
        };
        gaps
    };

    at[\pitchIdentityRuntimeProject] = { |candidatePhase, activePcs=nil|
        var p, active, rawGaps, gaps, anchor, out, i, pc, prev;
        p = (candidatePhase ? (st[\nodePhase] ? st[\etPhase])).copy;
        active = activePcs ? at[\pitchIdentityRuntimeActivePcs].();
        rawGaps = Array.fill(12, { |pc| at[\wrap01].((p[(pc+1)%12] ? ((pc+1)/12.0)) - (p[pc] ? (pc/12.0))) });
        gaps = at[\pitchIdentityRuntimeAdjustGaps].(rawGaps, active);
        anchor = if(((cfg[\pitchIdentityRuntimeGuard] ? ())[\preserveActiveAnchor] ? true) and: { active.notEmpty }) { active[0].asInteger % 12 } { 0 };
        out = Array.fill(12, 0.0);
        out[anchor] = at[\wrap01].(p[anchor] ? (anchor/12.0));
        i = 1;
        while { i < 12 } {
            pc = (anchor+i) % 12; prev = (pc+11) % 12;
            out[pc] = at[\wrap01].((out[prev] ? 0.0) + (gaps[prev] ? (1.0/12.0)));
            i = i + 1;
        };
        out
    };

    at[\pitchIdentityRuntimeUnwrappedFromProjection] = { |candidatePhase, candidateUnwrapped, projectedPhase|
        var cand, un, proj;
        cand = (candidatePhase ? (st[\etPhase])).copy; un = (candidateUnwrapped ? cand).copy; proj = (projectedPhase ? cand).copy;
        Array.fill(12, { |pc| (un[pc] ? cand[pc]) + at[\wrapSigned].((proj[pc] ? cand[pc]) - (cand[pc] ? 0.0)) });
    };

    at[\applyPitchIdentityTopologyGuard] = { |oldPhase, solvedPhase, solvedUnwrapped=nil, reason=\resolve, oldUnwrapped=nil|
        var enabled, oldP, cand, candUn, oldUn, active, assess, oldAssess, out, outUn, action, strategy, report;
        enabled = (cfg[\pitchIdentityRuntimeGuard] ? (enabled:true))[\enabled] ? true;
        oldP = (oldPhase ? (st[\nodePhase] ? st[\etPhase])).copy;
        cand = (solvedPhase ? oldP).copy; candUn = (solvedUnwrapped ? cand).copy; oldUn = (oldUnwrapped ? oldP).copy;
        active = at[\pitchIdentityRuntimeActivePcs].();
        assess = at[\pitchIdentityRuntimeAssess].(cand, reason, active);
        oldAssess = at[\pitchIdentityRuntimeAssess].(oldP, \previousField, active);
        out = cand.copy; outUn = candUn.copy; action = false; strategy = \none;
        if(enabled and: { assess[\needsAction] == true }) {
            var projected, projectedAssess;
            projected = at[\pitchIdentityRuntimeProject].(cand, active);
            projectedAssess = at[\pitchIdentityRuntimeAssess].(projected, \runtimeGuardProjection, active);
            action = true;
            if(projectedAssess[\needsAction] == false) {
                strategy = \elasticKeyboardSurface;
                out = projected.copy; outUn = at[\pitchIdentityRuntimeUnwrappedFromProjection].(cand, candUn, out); assess = projectedAssess;
            } {
                if(oldAssess[\needsAction] == false) {
                    strategy = \preservePreviousLegibleField; out = oldP.copy; outUn = oldUn.copy; assess = oldAssess;
                } {
                    strategy = \uniformKeyboardSurfaceFallback;
                    out = Array.fill(12, { |pc| at[\wrap01].((pc/12.0) + (cand[0] ? 0.0)) });
                    outUn = at[\pitchIdentityRuntimeUnwrappedFromProjection].(cand, candUn, out);
                    assess = at[\pitchIdentityRuntimeAssess].(out, \runtimeGuardUniformFallback, active);
                };
            };
            st[\pitchIdentityRuntimeGuardInterventionCount] = (st[\pitchIdentityRuntimeGuardInterventionCount] ? 0) + 1;
        };
        report = (
            role: \pitchIdentityRuntimeGuard, reason: reason, acted: action, strategy: strategy, activePcs: active,
            outputCompact: assess[\compact], candidateCompact: at[\pitchIdentityRuntimeAssess].(cand, \candidate, active)[\compact],
            interventionCount: st[\pitchIdentityRuntimeGuardInterventionCount] ? 0,
            pitchAuthorityAdded: false,
            note: if(action) { "Keyboard surface protected: pitch classes may adapt, but named notes cannot collapse/cross." } { "Keyboard surface already safe." }
        );
        st[\lastPitchIdentityRuntimeGuard] = report;
        if(action and: { ((cfg[\pitchIdentityRuntimeGuard] ? ())[\debug] ? false) }) {
            ("[AT PITCH IDENTITY RUNTIME GUARD] acted=true strategy=" ++ strategy.asString ++ " reason=" ++ reason.asString ++ " output=" ++ report[\outputCompact].asString).postln;
        };
        (phase: out, unwrapped: outUn, changed: action, report: report)
    };

    api[\pitchIdentityRuntimeGuardReport] = { st[\lastPitchIdentityRuntimeGuard] ? (role: \pitchIdentityRuntimeGuard, acted: false, note: \noReportYet) };

    "[at-pitch-identity] v3C runtime keyboard-surface guard loaded; not ET snapping, not chord/key detection.".postln;
};
)
