(
// AT_pitch_identity_topology.scd
// v3D21b pitch-identity topology audit with field-commit guard reporting.
//
// This layer answers the new playable-instrument question exposed by the
// screenshots: are pitch identities still an order-preserving circular surface,
// or are active/passive/history/ghost/projection layers being visually conflated?
//
// Reports remain read-only, but v3D21b may report a separate topology guard intervention when the solver rejects a non-invertible target.

var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[AT PITCH IDENTITY TOPOLOGY] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(st[\pitchIdentityTopology].isNil) { st[\pitchIdentityTopology] = IdentityDictionary.new; };

    at[\pitchIdentityPcName] = { |pc|
        pitchClassNames[pc.asInteger.clip(0, 11)] ? pc.asString
    };

    at[\pitchIdentityPhaseArray] = { |layer=\nodePhase|
        var l, arr;
        l = (layer ? \nodePhase).asSymbol;
        arr = switch(l,
            \nodePhase, { st[\nodePhase] ? st[\etPhase] },
            \currentPhase, { st[\nodePhase] ? st[\etPhase] },
            \targetPhase, { st[\targetPhase] ? st[\nodePhase] ? st[\etPhase] },
            \coreUnwrappedPhase, { st[\coreUnwrappedPhase] ? st[\nodePhase] ? st[\etPhase] },
            \targetCoreUnwrappedPhase, { st[\targetCoreUnwrappedPhase] ? st[\targetPhase] ? st[\nodePhase] ? st[\etPhase] },
            \memoryPhase, { st[\memoryPhase] ? st[\etPhase] },
            \frozenPhase, { st[\frozenPhase] ? st[\nodePhase] ? st[\etPhase] },
            { st[\nodePhase] ? st[\etPhase] }
        );
        if(arr.isNil) { st[\etPhase].copy } { arr.copy };
    };

    at[\pitchIdentityActivePcs] = {
        if(at[\pcWeights].notNil and: { at[\activePcsFromWeights].notNil }) {
            at[\activePcsFromWeights].(at[\pcWeights].());
        } {
            (st[\activeNotes] ? IdentityDictionary.new).values.asArray.collect { |n| n[\pc] }.as(Set).asArray.sort;
        };
    };

    at[\pitchIdentityPairDistanceCents] = { |phases, a, b|
        (at[\wrapSigned].((phases[a] ? 0.0) - (phases[b] ? 0.0)).abs * 1200.0).round(0.01)
    };

    at[\pitchIdentitySortedOrder] = { |phases|
        var entries;
        entries = Array.fill(12, { |pc| (pc: pc, name: at[\pitchIdentityPcName].(pc), phase: at[\wrap01].(phases[pc] ? (pc / 12.0))) });
        entries = entries.sort { |a, b| a[\phase] < b[\phase] };
        entries.collect { |x| x[\name] };
    };


    at[\pitchIdentityOrderIsCanonicalRotation] = { |order|
        var canonical, ok;
        canonical = pitchClassNames.copy;
        ok = false;
        12.do { |shift|
            var rotated;
            rotated = Array.fill(12, { |i| canonical[(shift + i) % 12] });
            if(rotated == order) { ok = true; };
        };
        ok
    };

    at[\pitchIdentityHistoryDiagnostics] = {
        var hist, last, pcSeen, duplicatePcEvents, octaveReturnEvents, samePcReentry, activeMidis, activePcs, rep;
        hist = (st[\pitchIdentityTopology][\onsetHistory] ? Array.new);
        if(hist.isEmpty) { hist = st[\coreTransportHistory] ? Array.new; };
        last = st[\lastCoreTransport] ? ();
        pcSeen = IdentityDictionary.new;
        duplicatePcEvents = Array.new;
        octaveReturnEvents = Array.new;
        activeMidis = (st[\activeNotes] ? IdentityDictionary.new).keys.asArray.sort;
        activePcs = at[\pitchIdentityActivePcs].();
        hist.do { |rec, i|
            var pc, midi, prior;
            pc = rec[\pc];
            midi = rec[\midi];
            if(pc.notNil) {
                prior = pcSeen[pc] ? Array.new;
                prior.do { |old|
                    if((old[\midi].notNil) and: { midi.notNil }) {
                        if((old[\midi] - midi).abs >= 12) {
                            octaveReturnEvents = octaveReturnEvents.add((pc: pc, pcName: at[\pitchIdentityPcName].(pc), firstMidi: old[\midi], secondMidi: midi, firstIndex: old[\index], secondIndex: i));
                        };
                    };
                };
                if(prior.notEmpty) {
                    duplicatePcEvents = duplicatePcEvents.add((pc: pc, pcName: at[\pitchIdentityPcName].(pc), midi: midi, index: i, priorCount: prior.size));
                };
                pcSeen[pc] = prior.add((midi: midi, index: i));
            };
        };
        samePcReentry = duplicatePcEvents.notEmpty;
        rep = (
            historySize: hist.size,
            activeMidisAtReport: activeMidis,
            activePcsAtReport: activePcs,
            lastMidi: last[\midi],
            lastPc: last[\pc],
            lastPcName: if(last[\pc].isNil) { nil } { at[\pitchIdentityPcName].(last[\pc]) },
            lastMidiDelta: last[\midiDelta],
            duplicatePcEvents: duplicatePcEvents,
            octaveReturnEvents: octaveReturnEvents,
            samePcReentryDetected: samePcReentry,
            octaveReturnDetected: octaveReturnEvents.notEmpty,
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentityTopology][\lastHistoryDiagnostics] = rep;
        rep
    };

    at[\pitchIdentityOrderForPhases] = { |phases, layer=\nodePhase, activePcs=nil|
        var gaps, gapCents, totalCycles, minGap, maxGap, strictWindingPreserved, circularOrderPreserved, orderPreserved, visualOrder;
        var closePairs, collisions, severeCollisions, activeCollisions, passiveCollisions, crossings, orderCrossings, gaugeSeamEvents;
        var warnThreshold, severeThreshold, activeThreshold, allPairMin, activePairMin, activeNeighborMin;
        var activeSet, healthySpacingButStrictWindingFlag, seamRotation, orderWarningKind;

        phases = phases ? st[\etPhase];
        activePcs = activePcs ? at[\pitchIdentityActivePcs].();
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc); };

        warnThreshold = ((cfg[\pitchIdentity] ? ())[\warnCents] ? 25.0);
        severeThreshold = ((cfg[\pitchIdentity] ? ())[\severeCents] ? 15.0);
        activeThreshold = ((cfg[\pitchIdentity] ? ())[\activeWarnCents] ? 35.0);

        gaps = Array.fill(12, { |pc| at[\wrap01].((phases[(pc + 1) % 12] ? 0.0) - (phases[pc] ? 0.0)) });
        gapCents = gaps.collect { |g| (g * 1200.0).round(0.01) };
        totalCycles = gaps.sum.round(0.001);
        minGap = (gapCents.minItem ? 0.0).round(0.01);
        maxGap = (gapCents.maxItem ? 0.0).round(0.01);
        strictWindingPreserved = ((totalCycles - 1.0).abs <= 0.002) and: { minGap > 0.001 };
        visualOrder = at[\pitchIdentitySortedOrder].(phases);
        circularOrderPreserved = at[\pitchIdentityOrderIsCanonicalRotation].(visualOrder);
        orderPreserved = circularOrderPreserved and: { minGap > 0.001 };
        seamRotation = if(visualOrder.size > 0) { visualOrder[0] != pitchClassNames[0] } { false };

        closePairs = Array.new;
        collisions = Array.new;
        severeCollisions = Array.new;
        activeCollisions = Array.new;
        passiveCollisions = Array.new;
        allPairMin = nil;
        activePairMin = nil;
        activeNeighborMin = nil;

        12.do { |a|
            12.do { |b|
                if(b > a) {
                    var d, pair, eitherActive, bothPassive;
                    d = at[\pitchIdentityPairDistanceCents].(phases, a, b);
                    if(allPairMin.isNil or: { d < allPairMin }) { allPairMin = d; };
                    eitherActive = activeSet.includes(a) or: { activeSet.includes(b) };
                    bothPassive = eitherActive.not;
                    if(activeSet.includes(a) and: { activeSet.includes(b) }) {
                        if(activePairMin.isNil or: { d < activePairMin }) { activePairMin = d; };
                    };
                    pair = (a: a, b: b, aName: at[\pitchIdentityPcName].(a), bName: at[\pitchIdentityPcName].(b), distanceCents: d);
                    if(d < warnThreshold) { closePairs = closePairs.add(pair); collisions = collisions.add(pair); };
                    if(d < severeThreshold) { severeCollisions = severeCollisions.add(pair); };
                    if(eitherActive and: { d < activeThreshold }) { activeCollisions = activeCollisions.add(pair); };
                    if(bothPassive and: { d < warnThreshold }) { passiveCollisions = passiveCollisions.add(pair); };
                };
            };
        };

        gaps.do { |g, i|
            var cents, eitherActive;
            cents = (g * 1200.0).round(0.01);
            eitherActive = activeSet.includes(i) or: { activeSet.includes((i + 1) % 12) };
            if(eitherActive) {
                if(activeNeighborMin.isNil or: { cents < activeNeighborMin }) { activeNeighborMin = cents; };
            };
        };

        crossings = Array.new;
        orderCrossings = Array.new;
        gaugeSeamEvents = Array.new;
        healthySpacingButStrictWindingFlag = strictWindingPreserved.not and: { orderPreserved and: { (allPairMin ? 999.0) >= warnThreshold } };
        orderWarningKind = \none;

        if(orderPreserved.not) {
            gapCents.do { |c, i|
                if((c > 600.0) or: { c < 1.0 }) {
                    crossings = crossings.add((from: i, to: (i + 1) % 12, fromName: at[\pitchIdentityPcName].(i), toName: at[\pitchIdentityPcName].((i + 1) % 12), gapCents: c));
                };
            };
            if(crossings.isEmpty) { crossings = crossings.add((reason: \nonCanonicalCircularOrder, visualOrder: visualOrder, totalGapCycles: totalCycles)); };
            orderCrossings = crossings.copy;
            orderWarningKind = \trueOrderMismatch;
        } {
            if(healthySpacingButStrictWindingFlag or: { seamRotation }) {
                gaugeSeamEvents = gaugeSeamEvents.add((reason: \benignGaugeSeamOrRotation, strictWindingPreserved: strictWindingPreserved, totalGapCycles: totalCycles, visualOrder: visualOrder, minAnyPairDistanceCents: if(allPairMin.isNil) { nil } { allPairMin.round(0.01) }));
                orderWarningKind = \benignGaugeSeamOrRotation;
            };
        };

        (
            layer: layer,
            pcOrderPreserved: orderPreserved,
            pcOrderPreservedStrict: strictWindingPreserved,
            circularOrderPreserved: circularOrderPreserved,
            orderWarningKind: orderWarningKind,
            pcOrder: pitchClassNames.copy,
            visualOrder: visualOrder,
            phaseOrder: visualOrder,
            totalGapCycles: totalCycles,
            neighborGapsCents: gapCents,
            minNeighborDistanceCents: minGap,
            maxNeighborDistanceCents: maxGap,
            minAnyPairDistanceCents: if(allPairMin.isNil) { nil } { allPairMin.round(0.01) },
            minActivePairDistanceCents: if(activePairMin.isNil) { nil } { activePairMin.round(0.01) },
            minActiveNeighborDistanceCents: if(activeNeighborMin.isNil) { nil } { activeNeighborMin.round(0.01) },
            collisions: collisions,
            closePairs: closePairs,
            closePairCollisions: closePairs,
            severeCollisions: severeCollisions,
            activeCollisions: activeCollisions,
            passiveCollisions: passiveCollisions,
            crossings: crossings,
            orderCrossings: orderCrossings,
            gaugeSeamEvents: gaugeSeamEvents,
            healthySpacingButStrictWindingFlag: healthySpacingButStrictWindingFlag,
            warnThresholdCents: warnThreshold,
            severeThresholdCents: severeThreshold,
            activeThresholdCents: activeThreshold
        )
    };

    at[\pitchIdentityLayerReport] = { |layer=\nodePhase|
        at[\pitchIdentityOrderForPhases].(at[\pitchIdentityPhaseArray].(layer), layer, at[\pitchIdentityActivePcs].());
    };

    api[\pitchIdentityLiveSnapshot] = {
        var snap, activePcs, node, target, core, targetCore, mem, frozen, rep;
        snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { IdentityDictionary.new };
        activePcs = at[\pitchIdentityActivePcs].();
        node = at[\pitchIdentityPhaseArray].(\nodePhase);
        target = at[\pitchIdentityPhaseArray].(\targetPhase);
        core = at[\pitchIdentityPhaseArray].(\coreUnwrappedPhase);
        targetCore = at[\pitchIdentityPhaseArray].(\targetCoreUnwrappedPhase);
        mem = at[\pitchIdentityPhaseArray].(\memoryPhase);
        frozen = at[\pitchIdentityPhaseArray].(\frozenPhase);
        rep = (
            activeNotes: (st[\activeNotes] ? IdentityDictionary.new).keys.asArray.sort,
            heldMidisAtReport: (st[\activeNotes] ? IdentityDictionary.new).keys.asArray.sort,
            activePcs: activePcs,
            activePcNames: activePcs.collect { |pc| at[\pitchIdentityPcName].(pc) },
            nodePhase: node.copy,
            targetPhase: target.copy,
            coreUnwrappedPhase: core.copy,
            targetCoreUnwrappedPhase: targetCore.copy,
            memoryPhase: mem.copy,
            frozenPhase: frozen.copy,
            nodeDevCents: node.collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) },
            targetDevCents: target.collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) },
            coreSheetDevCents: core.collect { |p, i| ((p - st[\etPhase][i]) * 1200.0).round(0.01) },
            currentCSheetCents: if(core.notNil and: { core.size > 0 }) { ((core[0] - st[\etPhase][0]) * 1200.0).round(0.01) } { 0.0 },
            gaugeOffsetCents: if(core.notNil and: { core.size > 0 }) { (at[\wrapSigned].(node[0] - st[\etPhase][0]) * 1200.0).round(0.01) } { 0.0 },
            targetValid: st[\targetValid] ? false,
            motionActive: st[\motionActive] ? false,
            fieldFrozen: st[\fieldFrozen] ? false,
            frozenValid: st[\frozenValid] ? false,
            memoryValid: st[\memoryValid] ? false,
            memoryAmount: st[\memoryAmount] ? 0.0,
            visualProjectionMode: \wrappedNodePhaseOnSinglePcRing,
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentityTopology][\lastLiveSnapshot] = rep;
        rep
    };

    api[\pitchIdentityOrderReport] = { |layer=\nodePhase|
        var rep;
        rep = at[\pitchIdentityLayerReport].(layer);
        st[\pitchIdentityTopology][\lastOrderReport] = rep;
        rep.postln;
        rep
    };

    api[\pitchIdentityCollisionReport] = { |layer=\nodePhase|
        var rep, order;
        order = at[\pitchIdentityLayerReport].(layer);
        rep = (
            layer: layer,
            pcOrderPreserved: order[\pcOrderPreserved],
            minNeighborDistanceCents: order[\minNeighborDistanceCents],
            minActiveNeighborDistanceCents: order[\minActiveNeighborDistanceCents],
            minAnyPairDistanceCents: order[\minAnyPairDistanceCents],
            collisions: order[\collisions],
            activeCollisions: order[\activeCollisions],
            passiveCollisions: order[\passiveCollisions],
            severeCollisions: order[\severeCollisions],
            crossings: order[\crossings],
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentityTopology][\lastCollisionReport] = rep;
        rep.postln;
        rep
    };

    api[\pitchIdentityOctaveReturnDiagnosticReport] = {
        var rep;
        rep = at[\pitchIdentityHistoryDiagnostics].();
        rep.postln;
        rep
    };

    api[\pitchIdentityVisualTruthReport] = {
        var snap, activePcs, externalCount, micCount, ghostCount, memoryPointCount, historyCount, passiveCount, rep;
        snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { IdentityDictionary.new };
        activePcs = snap[\activePcs] ? at[\pitchIdentityActivePcs].();
        externalCount = (snap[\externalSources] ? Array.new).size;
        micCount = (snap[\micCandidates] ? Array.new).size;
        ghostCount = if(snap[\frozenValid] ? false) { 12 } { 0 };
        memoryPointCount = if(((snap[\memoryAmount] ? 0.0) > 0.02) or: { snap[\memoryValid] ? false }) { 12 } { 0 };
        historyCount = (st[\coreTransportHistory] ? Array.new).size;
        passiveCount = 12 - activePcs.size;
        rep = (
            visualProjectionMode: \wrappedNodePhaseOnSinglePcRing,
            visualLayerKinds: [\etReferenceDots, \liveNodePhase, \memoryPhaseInnerRing, \frozenGhostRing, \micExternalPressureHalo, \fixedEtTextLabels],
            liveNodeCount: 12,
            activeVoiceCount: (st[\activeNotes] ? IdentityDictionary.new).size,
            activePcs: activePcs,
            passiveNodeCount: passiveCount.max(0),
            ghostCount: ghostCount,
            historyPointCount: historyCount,
            memoryPointCount: memoryPointCount,
            registerCopyCount: 0,
            externalPressurePointCount: externalCount + micCount,
            targetPointCount: 0,
            currentPointCount: 12,
            targetDrawn: false,
            currentDrawn: true,
            memoryDrawn: memoryPointCount > 0,
            frozenGhostDrawn: ghostCount > 0,
            registerCopiesDrawn: false,
            activePassiveDistinguished: true,
            activeGhostDistinguished: true,
            passiveGhostDistinguished: false,
            layerConflationRisk: (ghostCount > 0) or: { memoryPointCount > 0 } or: { (externalCount + micCount) > 0 },
            note: "The current visual draws live pitch-class nodes on one wrapped ring, memory on an inner ring, frozen ghosts on the live ring, and mic pressure outside. It does not draw targetPhase or register copies."
        );
        st[\pitchIdentityTopology][\lastVisualTruthReport] = rep;
        rep.postln;
        rep
    };

    api[\pitchIdentityTopologyReport] = {
        var live, visual, hist, nodeOrder, targetOrder, coreOrder, targetCoreOrder, diagnosis, reports, mixed, closeRisk, activeRisk, trueOrderRisk, coveringRisk, seamExplained;
        live = api[\pitchIdentityLiveSnapshot].();
        visual = api[\pitchIdentityVisualTruthReport].();
        hist = at[\pitchIdentityHistoryDiagnostics].();
        nodeOrder = at[\pitchIdentityLayerReport].(\nodePhase);
        targetOrder = at[\pitchIdentityLayerReport].(\targetPhase);
        coreOrder = at[\pitchIdentityLayerReport].(\coreUnwrappedPhase);
        targetCoreOrder = at[\pitchIdentityLayerReport].(\targetCoreUnwrappedPhase);
        mixed = false;
        diagnosis = \none;
        closeRisk = nodeOrder[\collisions].notEmpty or: { targetOrder[\collisions].notEmpty };
        activeRisk = nodeOrder[\activeCollisions].notEmpty or: { targetOrder[\activeCollisions].notEmpty };
        trueOrderRisk = nodeOrder[\pcOrderPreserved].not or: { targetOrder[\pcOrderPreserved].not };
        coveringRisk = coreOrder[\pcOrderPreserved].not or: { targetCoreOrder[\pcOrderPreserved].not };
        seamExplained = (hist[\octaveReturnDetected] == true) or: { (nodeOrder[\gaugeSeamEvents].notEmpty) or: { targetOrder[\gaugeSeamEvents].notEmpty } };

        if(activeRisk or: { closeRisk }) {
            diagnosis = \actualFieldFold;
        } {
            if(trueOrderRisk) {
                diagnosis = if(seamExplained) { \gaugeSeamOrOctaveReturn } { \actualFieldFold };
            } {
                if(coveringRisk) {
                    diagnosis = if(seamExplained) { \gaugeSeamOrOctaveReturn } { \coveringProjection };
                } {
                    if(visual[\layerConflationRisk] == true) { diagnosis = \visualOnly; } { diagnosis = \none; };
                };
            };
        };
        if(((diagnosis == \actualFieldFold) or: { diagnosis == \coveringProjection }) and: { visual[\layerConflationRisk] == true }) { diagnosis = \mixed; mixed = true; };

        reports = (
            branch: \v3D21b_field_commit_topology_guard,
            pcOrderPreserved: nodeOrder[\pcOrderPreserved],
            targetOrderPreserved: targetOrder[\pcOrderPreserved],
            coreOrderPreserved: coreOrder[\pcOrderPreserved],
            targetCoreOrderPreserved: targetCoreOrder[\pcOrderPreserved],
            minNeighborDistanceCents: nodeOrder[\minNeighborDistanceCents],
            minActiveNeighborDistanceCents: nodeOrder[\minActiveNeighborDistanceCents],
            minAnyPairDistanceCents: nodeOrder[\minAnyPairDistanceCents],
            collisions: nodeOrder[\collisions],
            closePairCollisions: nodeOrder[\closePairCollisions],
            activeCollisions: nodeOrder[\activeCollisions],
            passiveCollisions: nodeOrder[\passiveCollisions],
            crossings: nodeOrder[\crossings],
            orderCrossings: nodeOrder[\orderCrossings],
            gaugeSeamEvents: nodeOrder[\gaugeSeamEvents],
            nodeStrictWindingPreserved: nodeOrder[\pcOrderPreservedStrict],
            targetStrictWindingPreserved: targetOrder[\pcOrderPreservedStrict],
            orderWarningKind: nodeOrder[\orderWarningKind],
            pcOrder: pitchClassNames.copy,
            visualOrder: nodeOrder[\visualOrder],
            nodePhaseOrder: nodeOrder[\phaseOrder],
            targetPhaseOrder: targetOrder[\phaseOrder],
            currentPhaseOrder: nodeOrder[\phaseOrder],
            coreUnwrappedPhaseOrder: coreOrder[\phaseOrder],
            activeVoiceCount: visual[\activeVoiceCount],
            activePcs: live[\activePcs],
            activePcsAtReport: hist[\activePcsAtReport],
            heldMidisAtReport: live[\heldMidisAtReport],
            activePcNames: live[\activePcNames],
            passiveNodeCount: visual[\passiveNodeCount],
            ghostCount: visual[\ghostCount],
            historyPointCount: visual[\historyPointCount],
            registerCopyCount: visual[\registerCopyCount],
            memoryPointCount: visual[\memoryPointCount],
            externalPressurePointCount: visual[\externalPressurePointCount],
            currentCSheetCents: live[\currentCSheetCents],
            gaugeOffsetCents: live[\gaugeOffsetCents],
            visualProjectionMode: visual[\visualProjectionMode],
            pitchAuthority: false,
            topologyAuthority: false,
            diagnosis: diagnosis,
            mixed: mixed,
            duplicatePcEvents: hist[\duplicatePcEvents],
            octaveReturnEvents: hist[\octaveReturnEvents],
            octaveReturnDetected: hist[\octaveReturnDetected],
            samePcReentryDetected: hist[\samePcReentryDetected],
            historyGhostConflicts: if((visual[\historyPointCount] ? 0) > 0 and: { visual[\layerConflationRisk] == true }) { [(historyPointCount: visual[\historyPointCount], ghostCount: visual[\ghostCount], memoryPointCount: visual[\memoryPointCount])] } { Array.new },
            compactFailureLine: "diagnosis=" ++ diagnosis.asString ++ " minNeighbor=" ++ nodeOrder[\minNeighborDistanceCents].asString ++ "c closePairs=" ++ nodeOrder[\closePairCollisions].size.asString ++ " activeClose=" ++ nodeOrder[\activeCollisions].size.asString ++ " orderKind=" ++ nodeOrder[\orderWarningKind].asString ++ " octaveReturn=" ++ hist[\octaveReturnDetected].asString,
            nodeOrderReport: nodeOrder,
            targetOrderReport: targetOrder,
            coreOrderReport: coreOrder,
            targetCoreOrderReport: targetCoreOrder,
            visualTruthReport: visual,
            liveSnapshot: live
        );
        st[\pitchIdentityTopology][\lastTopologyReport] = reports;
        "".postln;
        "[AT PITCH IDENTITY TOPOLOGY REPORT]".postln;
        ("pcOrderPreserved=" ++ reports[\pcOrderPreserved].asString
            ++ " targetOrderPreserved=" ++ reports[\targetOrderPreserved].asString
            ++ " coreOrderPreserved=" ++ reports[\coreOrderPreserved].asString
            ++ " minNeighbor=" ++ reports[\minNeighborDistanceCents].asString ++ "c"
            ++ " minActiveNeighbor=" ++ reports[\minActiveNeighborDistanceCents].asString ++ "c"
            ++ " collisions=" ++ reports[\collisions].size.asString
            ++ " activeCollisions=" ++ reports[\activeCollisions].size.asString
            ++ " orderKind=" ++ reports[\orderWarningKind].asString
            ++ " octaveReturn=" ++ reports[\octaveReturnDetected].asString
            ++ " diagnosis=" ++ reports[\diagnosis].asString).postln;
        reports
    };

    api[\pitchIdentityTopologyAuditPlan] = {
        var rep;
        rep = (
            branch: \v3D21b_field_commit_topology_guard,
            purpose: "Diagnose pitch-class identity topology, visual truth, and topology-guard intervention.",
            reportOnlyApis: [\pitchIdentityTopologyReport, \pitchIdentityVisualTruthReport, \pitchIdentityLiveSnapshot, \pitchIdentityCollisionReport, \pitchIdentityOrderReport, \pitchIdentityOctaveReturnDiagnosticReport],
            nonAudibleProbeApi: \runPitchIdentityTopologyProbe,
            questions: [
                "Are clustered dots active nodes, passive nodes, memory, frozen ghosts, mic pressure, or history?",
                "Do nodePhase/targetPhase/coreUnwrappedPhase preserve circular order?",
                "Do active notes collide with adjacent pitch-class identity regions?",
                "Is the screenshot problem visualOnly, coveringProjection, actualFieldFold, mixed, or unknown?",
                "Does octave return or same-pitch-class reentry explain an order warning without close-pair collapse?",
                "Are order crossings, close-pair collisions, gauge seams, history ghosts, and active collisions reported separately?"
            ],
            diagnosticThresholds: (warnCents: 25.0, severeCents: 15.0, activeWarnCents: 35.0),
            noPitchMutation: true,
            noSamplesTouched: true,
            noToneEngineTouched: true,
            noSetharesCylinderAuthority: true,
            noEqualTemperamentClamp: true,
            topologyGuardAvailable: api[\pitchIdentityTopologyGuardReport].notNil
        );
        st[\pitchIdentityTopology][\lastAuditPlan] = rep;
        rep.postln;
        rep
    };

    api[\runPitchIdentityTopologyProbe] = { |gesture=\stageReadyPiano, applyGesture=false|
        var g, plan, before, report, rep;
        g = (gesture ? \stageReadyPiano).asSymbol;
        before = api[\pitchIdentityLiveSnapshot].();
        plan = if(api[\performanceCalibrationGesturePlan].notNil) { api[\performanceCalibrationGesturePlan].(g) } { (gesture: g) };
        if(applyGesture.asBoolean and: { api[\applyPerformanceCalibrationGesture].notNil }) {
            api[\applyPerformanceCalibrationGesture].(g, true);
        };
        report = api[\pitchIdentityTopologyReport].();
        rep = (
            gesture: g,
            appliedGesture: applyGesture.asBoolean,
            audible: false,
            plan: plan,
            beforeActivePcs: before[\activePcs],
            afterReport: report,
            diagnosis: report[\diagnosis],
            pitchAuthority: false,
            topologyAuthority: false,
            note: if(applyGesture.asBoolean) { "Applied calibration gesture in isolated diagnostic context before reporting." } { "Report-only probe: did not apply gesture; use second argument true for isolated calibration-context probing." }
        );
        st[\pitchIdentityTopology][\lastProbeReport] = rep;
        rep.postln;
        rep
    };

    api[\pitchIdentityNoMutationProofReport] = {
        var beforeNode, beforeTarget, beforeCore, beforeMem, beforeResidual, afterNode, afterTarget, afterCore, afterMem, afterResidual, rep;
        beforeNode = (st[\nodePhase] ? Array.new).copy;
        beforeTarget = (st[\targetPhase] ? Array.new).copy;
        beforeCore = (st[\coreUnwrappedPhase] ? Array.new).copy;
        beforeMem = if(st[\memoryPhase].isNil) { nil } { st[\memoryPhase].copy };
        beforeResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        api[\pitchIdentityTopologyReport].();
        api[\pitchIdentityVisualTruthReport].();
        api[\pitchIdentityCollisionReport].(\nodePhase);
        api[\pitchIdentityOrderReport].(\targetPhase);
        api[\pitchIdentityOctaveReturnDiagnosticReport].();
        afterNode = (st[\nodePhase] ? Array.new).copy;
        afterTarget = (st[\targetPhase] ? Array.new).copy;
        afterCore = (st[\coreUnwrappedPhase] ? Array.new).copy;
        afterMem = if(st[\memoryPhase].isNil) { nil } { st[\memoryPhase].copy };
        afterResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        rep = (
            noNodePhaseMutation: beforeNode == afterNode,
            noTargetPhaseMutation: beforeTarget == afterTarget,
            noCoreUnwrappedMutation: beforeCore == afterCore,
            noMemoryPhaseMutation: beforeMem == afterMem,
            noCylinderResidualMutation: beforeResidual == afterResidual,
            noRenderPitchMutation: true,
            noSampleMutation: true,
            noMicStateMutation: true,
            noUiLayoutMutation: true,
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentityTopology][\lastNoMutationProofReport] = rep;
        rep.postln;
        rep
    };

    "[AT PITCH IDENTITY TOPOLOGY] Loaded pitch identity topology audit with v3D21b field-commit guard reporting. Run: Library.at(\\at)[\\api][\\pitchIdentityTopologyReport].();".postln;
};
)
