(
// AT_pitch_identity_spacing_legibility.scd
// v3D24: pitch-identity spacing / musical-legibility audit plus guard-aware thresholds.
//
// v3D21b made the 12 pitch identities topology-safe: the circle cannot fold.
// v3D23 asks the stricter musical-instrument question: even when the circle
// remains ordered, does the chromatic keyboard surface keep enough pitch
// territory to remain playable and legible? This file remains report-oriented; v3D24c loads a separate spacing guard after it to enforce the same musical floors at field commit.

var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[AT PITCH IDENTITY SPACING] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(st[\pitchIdentitySpacing].isNil) { st[\pitchIdentitySpacing] = IdentityDictionary.new; };
    if(cfg[\pitchIdentitySpacing].isNil) {
        cfg[\pitchIdentitySpacing] = (
            ordinaryNeighborFloorCents: 75.0,
            ordinaryActiveNeighborFloorCents: 85.0,
            ordinaryMaxNeighborGapCents: 155.0,
            diagnosticNeighborFloorCents: 75.0,
            diagnosticActiveNeighborFloorCents: 85.0,
            diagnosticMaxNeighborGapCents: 155.0,
            absoluteEmergencyFloorCents: 60.0,
            fishCoreDiagnosticMayCompress: false
        );
    };

    at[\pitchIdentitySpacingThresholds] = { |context=\ordinary|
        var c, sp, diagnostic;
        c = (context ? \ordinary).asSymbol;
        sp = cfg[\pitchIdentitySpacing] ? ();
        diagnostic = [\fishCoreDiagnostic, \rawDiagnostic, \diagnosticOnly].includes(c);
        if(diagnostic) {
            (
                context: c,
                diagnosticOnly: true,
                ordinaryNeighborFloorCents: sp[\ordinaryNeighborFloorCents] ? 75.0,
                passiveNeighborFloorCents: sp[\diagnosticNeighborFloorCents] ? 75.0,
                activeNeighborFloorCents: sp[\diagnosticActiveNeighborFloorCents] ? 85.0,
                maxNeighborGapCents: sp[\diagnosticMaxNeighborGapCents] ? 155.0,
                absoluteEmergencyFloorCents: sp[\absoluteEmergencyFloorCents] ? 60.0
            )
        } {
            (
                context: c,
                diagnosticOnly: false,
                ordinaryNeighborFloorCents: sp[\ordinaryNeighborFloorCents] ? 75.0,
                passiveNeighborFloorCents: sp[\ordinaryNeighborFloorCents] ? 75.0,
                activeNeighborFloorCents: sp[\ordinaryActiveNeighborFloorCents] ? 85.0,
                maxNeighborGapCents: sp[\ordinaryMaxNeighborGapCents] ? 155.0,
                absoluteEmergencyFloorCents: sp[\absoluteEmergencyFloorCents] ? 60.0
            )
        }
    };

    at[\pitchIdentitySpacingNeighborRecords] = { |order, activePcs=nil|
        var activeSet, gaps;
        activePcs = activePcs ? at[\pitchIdentityActivePcs].();
        activeSet = IdentitySet.new;
        activePcs.do { |pc| activeSet.add(pc.asInteger) };
        gaps = order[\neighborGapsCents] ? Array.fill(12, { 100.0 });
        Array.fill(12, { |pc|
            var next, gap, activeInvolved;
            next = (pc + 1) % 12;
            gap = gaps[pc] ? 0.0;
            activeInvolved = activeSet.includes(pc) or: { activeSet.includes(next) };
            (
                pc: pc,
                nextPc: next,
                pcName: at[\pitchIdentityPcName].(pc),
                nextPcName: at[\pitchIdentityPcName].(next),
                gapCents: gap.round(0.01),
                activeInvolved: activeInvolved,
                leftActive: activeSet.includes(pc),
                rightActive: activeSet.includes(next),
                bothPassive: activeInvolved.not
            )
        })
    };

    at[\pitchIdentitySpacingLayerReport] = { |layer=\nodePhase, context=\ordinary, activePcs=nil|
        var order, thresholds, records, activeRisks, passiveRisks, stretchRisks, emergencyRisks, passiveTerritoryRisks;
        var topologySafe, ordinaryHealthy, diagnosticCompression, diagnosis, minNeighbor, maxNeighbor, minActiveNeighbor, compact;
        activePcs = activePcs ? at[\pitchIdentityActivePcs].();
        order = if(at[\pitchIdentityLayerReport].notNil) {
            at[\pitchIdentityLayerReport].(layer)
        } {
            (layer: layer, pcOrderPreserved: true, neighborGapsCents: Array.fill(12, { 100.0 }), minNeighborDistanceCents: 100.0, maxNeighborDistanceCents: 100.0, minActiveNeighborDistanceCents: nil)
        };
        thresholds = at[\pitchIdentitySpacingThresholds].(context);
        records = at[\pitchIdentitySpacingNeighborRecords].(order, activePcs);

        activeRisks = records.select { |r| r[\activeInvolved] and: { (r[\gapCents] ? 0.0) < thresholds[\activeNeighborFloorCents] } };
        passiveRisks = records.select { |r| r[\bothPassive] and: { (r[\gapCents] ? 0.0) < thresholds[\passiveNeighborFloorCents] } };
        stretchRisks = records.select { |r| (r[\gapCents] ? 0.0) > thresholds[\maxNeighborGapCents] };
        emergencyRisks = records.select { |r| (r[\gapCents] ? 0.0) < thresholds[\absoluteEmergencyFloorCents] };
        passiveTerritoryRisks = records.select { |r| r[\bothPassive] and: { (r[\gapCents] ? 0.0) < thresholds[\ordinaryNeighborFloorCents] } };

        topologySafe = (order[\pcOrderPreserved] == true) and: { (order[\collisions] ? Array.new).isEmpty and: { (order[\activeCollisions] ? Array.new).isEmpty } };
        minNeighbor = order[\minNeighborDistanceCents] ? 0.0;
        maxNeighbor = order[\maxNeighborDistanceCents] ? 0.0;
        minActiveNeighbor = order[\minActiveNeighborDistanceCents];
        diagnosticCompression = (thresholds[\diagnosticOnly] == true) and: { minNeighbor < thresholds[\ordinaryNeighborFloorCents] };

        diagnosis = if(topologySafe.not) {
            \topologyUnsafe
        } {
            if(activeRisks.notEmpty) {
                \activeIdentityTerritoryRisk
            } {
                if(emergencyRisks.notEmpty and: { thresholds[\diagnosticOnly].not }) {
                    \topologySafeButMusicallyCompressed
                } {
                    if(diagnosticCompression) {
                        \diagnosticOnlyFishCoreCompression
                    } {
                        if(passiveRisks.notEmpty) {
                            \passiveFieldBunching
                        } {
                            if(stretchRisks.notEmpty) {
                                \excessiveKeyboardStrain
                            } {
                                \healthyOrdinarySpacing
                            }
                        }
                    }
                }
            }
        };

        ordinaryHealthy = (diagnosis == \healthyOrdinarySpacing);
        compact = "context=" ++ context.asString
            ++ " layer=" ++ layer.asString
            ++ " diagnosis=" ++ diagnosis.asString
            ++ " min=" ++ minNeighbor.round(0.01).asString ++ "c"
            ++ " max=" ++ maxNeighbor.round(0.01).asString ++ "c"
            ++ " activeMin=" ++ minActiveNeighbor.asString ++ "c"
            ++ " activeRisks=" ++ activeRisks.size.asString
            ++ " passiveRisks=" ++ passiveRisks.size.asString
            ++ " stretchRisks=" ++ stretchRisks.size.asString;

        (
            branch: \v3D24c_pitch_identity_spacing_guard,
            context: context,
            layer: layer,
            thresholds: thresholds,
            topologySafe: topologySafe,
            pcOrderPreserved: order[\pcOrderPreserved],
            ordinarySpacingHealthy: ordinaryHealthy,
            diagnosticOnly: thresholds[\diagnosticOnly],
            diagnosticCompression: diagnosticCompression,
            diagnosis: diagnosis,
            minNeighborDistanceCents: minNeighbor.round(0.01),
            maxNeighborDistanceCents: maxNeighbor.round(0.01),
            minActiveNeighborDistanceCents: if(minActiveNeighbor.isNil) { nil } { minActiveNeighbor.round(0.01) },
            minAnyPairDistanceCents: order[\minAnyPairDistanceCents],
            neighborGapsCents: order[\neighborGapsCents],
            neighborRecords: records,
            activePcs: activePcs,
            activePcNames: activePcs.collect { |pc| at[\pitchIdentityPcName].(pc) },
            activeTerritoryRisks: activeRisks,
            passiveTerritoryRisks: passiveTerritoryRisks,
            passiveBunchingRisks: passiveRisks,
            excessiveStretchRisks: stretchRisks,
            emergencySpacingRisks: emergencyRisks,
            newNoteInheritanceRisk: passiveTerritoryRisks.notEmpty,
            compactLine: compact,
            pitchAuthority: false,
            topologyAuthority: false,
            orderReport: order
        )
    };

    api[\pitchIdentitySpacingLegibilityReport] = { |context=\ordinary|
        var node, target, core, visual, topology, diagnosis, reports, visualRisk, ordinaryOk;
        context = (context ? \ordinary).asSymbol;
        topology = if(api[\pitchIdentityTopologyReport].notNil) { api[\pitchIdentityTopologyReport].() } { () };
        visual = if(api[\pitchIdentityVisualTruthReport].notNil) { api[\pitchIdentityVisualTruthReport].() } { () };
        node = at[\pitchIdentitySpacingLayerReport].(\nodePhase, context);
        target = at[\pitchIdentitySpacingLayerReport].(\targetPhase, context);
        core = at[\pitchIdentitySpacingLayerReport].(\coreUnwrappedPhase, context);
        visualRisk = (visual[\layerConflationRisk] == true) and: { (node[\ordinarySpacingHealthy] == true) };

        diagnosis = if(node[\diagnosis] != \healthyOrdinarySpacing) {
            node[\diagnosis]
        } {
            if(target[\diagnosis] != \healthyOrdinarySpacing) {
                target[\diagnosis]
            } {
                if(core[\diagnosis] == \topologyUnsafe) {
                    \coveringProjectionSpacingRisk
                } {
                    if(visualRisk) { \visualLayerOverlapOnly } { \healthyOrdinarySpacing }
                }
            }
        };

        if((node[\diagnosis] == \diagnosticOnlyFishCoreCompression) or: { target[\diagnosis] == \diagnosticOnlyFishCoreCompression }) {
            diagnosis = \diagnosticOnlyFishCoreCompression;
        };

        ordinaryOk = (diagnosis == \healthyOrdinarySpacing) or: { diagnosis == \visualLayerOverlapOnly };

        reports = (
            branch: \v3D24c_pitch_identity_spacing_guard,
            context: context,
            diagnosis: diagnosis,
            ordinarySpacingHealthy: ordinaryOk,
            diagnosticOnly: node[\diagnosticOnly],
            topologySafe: node[\topologySafe] and: { target[\topologySafe] },
            pcOrderPreserved: node[\pcOrderPreserved],
            targetOrderPreserved: target[\pcOrderPreserved],
            coreOrderPreserved: core[\pcOrderPreserved],
            minNeighborDistanceCents: node[\minNeighborDistanceCents],
            maxNeighborDistanceCents: node[\maxNeighborDistanceCents],
            minActiveNeighborDistanceCents: node[\minActiveNeighborDistanceCents],
            activeTerritoryRisks: node[\activeTerritoryRisks],
            passiveTerritoryRisks: node[\passiveTerritoryRisks],
            passiveBunchingRisks: node[\passiveBunchingRisks],
            excessiveStretchRisks: node[\excessiveStretchRisks],
            emergencySpacingRisks: node[\emergencySpacingRisks],
            newNoteInheritanceRisk: node[\newNoteInheritanceRisk],
            visualLayerOverlapRisk: visualRisk,
            compactLine: "diagnosis=" ++ diagnosis.asString
                ++ " context=" ++ context.asString
                ++ " min=" ++ node[\minNeighborDistanceCents].asString ++ "c"
                ++ " max=" ++ node[\maxNeighborDistanceCents].asString ++ "c"
                ++ " activeMin=" ++ node[\minActiveNeighborDistanceCents].asString ++ "c"
                ++ " activeRisks=" ++ node[\activeTerritoryRisks].size.asString
                ++ " passiveRisks=" ++ node[\passiveTerritoryRisks].size.asString
                ++ " stretchRisks=" ++ node[\excessiveStretchRisks].size.asString,
            pitchAuthority: false,
            topologyAuthority: false,
            nodeSpacingReport: node,
            targetSpacingReport: target,
            coreSpacingReport: core,
            topologyReport: topology,
            visualTruthReport: visual
        );
        st[\pitchIdentitySpacing][\lastReport] = reports;
        "".postln;
        "[AT PITCH IDENTITY SPACING REPORT]".postln;
        reports[\compactLine].postln;
        reports
    };

    api[\pitchIdentitySpacingLegibilityAuditPlan] = {
        var sp, rep;
        sp = cfg[\pitchIdentitySpacing] ? ();
        rep = (
            branch: \v3D24c_pitch_identity_spacing_guard,
            purpose: "Audit whether the topology-safe pitch-class circle remains a musically legible keyboard surface instead of bunching into close-to-collision spacing.",
            reportOnlyApis: [\pitchIdentitySpacingLegibilityReport, \pitchIdentitySpacingNoMutationProofReport],
            ordinaryThresholds: (
                passiveNeighborFloorCents: sp[\ordinaryNeighborFloorCents] ? 75.0,
                activeNeighborFloorCents: sp[\ordinaryActiveNeighborFloorCents] ? 85.0,
                maxNeighborGapCents: sp[\ordinaryMaxNeighborGapCents] ? 155.0
            ),
            diagnosticThresholds: (
                passiveNeighborFloorCents: sp[\diagnosticNeighborFloorCents] ? 75.0,
                activeNeighborFloorCents: sp[\diagnosticActiveNeighborFloorCents] ? 85.0,
                maxNeighborGapCents: sp[\diagnosticMaxNeighborGapCents] ? 155.0
            ),
            classificationKinds: [\healthyOrdinarySpacing, \topologySafeButMusicallyCompressed, \activeIdentityTerritoryRisk, \passiveFieldBunching, \newNoteInheritanceRisk, \diagnosticOnlyFishCoreCompression, \visualLayerOverlapOnly, \nonOrdinarySpectrumOnly],
            noPitchMutation: true,
            noSamplesTouched: true,
            noToneEngineTouched: true,
            noMicPolicyChange: true,
            noSetharesCylinderAuthority: true,
            noEqualTemperamentClamp: true,
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentitySpacing][\lastAuditPlan] = rep;
        rep.postln;
        rep
    };

    api[\pitchIdentitySpacingNoMutationProofReport] = {
        var beforeNode, beforeTarget, beforeCore, beforeMem, beforeResidual, beforeExternal;
        var afterNode, afterTarget, afterCore, afterMem, afterResidual, afterExternal, rep;
        beforeNode = (st[\nodePhase] ? Array.new).copy;
        beforeTarget = (st[\targetPhase] ? Array.new).copy;
        beforeCore = (st[\coreUnwrappedPhase] ? Array.new).copy;
        beforeMem = if(st[\memoryPhase].isNil) { nil } { st[\memoryPhase].copy };
        beforeResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        beforeExternal = (st[\externalSources] ? Array.new).collect { |src| src.copy };
        api[\pitchIdentitySpacingLegibilityReport].(\ordinary);
        api[\pitchIdentitySpacingLegibilityReport].(\fishCoreDiagnostic);
        afterNode = (st[\nodePhase] ? Array.new).copy;
        afterTarget = (st[\targetPhase] ? Array.new).copy;
        afterCore = (st[\coreUnwrappedPhase] ? Array.new).copy;
        afterMem = if(st[\memoryPhase].isNil) { nil } { st[\memoryPhase].copy };
        afterResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        afterExternal = (st[\externalSources] ? Array.new).collect { |src| src.copy };
        rep = (
            noNodePhaseMutation: beforeNode == afterNode,
            noTargetPhaseMutation: beforeTarget == afterTarget,
            noCoreUnwrappedMutation: beforeCore == afterCore,
            noMemoryPhaseMutation: beforeMem == afterMem,
            noCylinderResidualMutation: beforeResidual == afterResidual,
            noExternalSourceMutation: beforeExternal == afterExternal,
            noRenderPitchMutation: true,
            noSampleMutation: true,
            noToneEngineMutation: true,
            noMicPolicyChange: true,
            noUiLayoutMutation: true,
            pitchAuthority: false,
            topologyAuthority: false
        );
        st[\pitchIdentitySpacing][\lastNoMutationProofReport] = rep;
        rep.postln;
        rep
    };

    "[AT PITCH IDENTITY SPACING] Loaded v3D24c guard-aware musical spacing / keyboard legibility audit. Run: Library.at(\\at)[\\api][\\pitchIdentitySpacingLegibilityReport].();".postln;
};
)
