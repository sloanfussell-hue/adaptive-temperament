(
// AT_solver.scd
// Corrected target-world solver. Evidence and harmonic force construction live in AT_evidence;
// AT_motion owns how the audible/current world travels to the target.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at-solver] ~atBuild missing. Load AdaptiveTemperament_run.scd.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    at[\pushBuses] = {
        st[\devBus].setn(at[\devArray].());
        st[\alignBus].setn(st[\nodeAlignment]);
        st[\motionBus].setn(st[\nodeMotion]);
        st[\stabBus].setn(st[\nodeStability]);
        st[\tensionBus].set(st[\tension]);
    };

    at[\clearDescriptors] = {
        st[\lastDelta] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\nodeMotion] = Array.fill(cfg[\solver][\numNodes], 0.0);
        st[\nodeAlignment] = Array.fill(cfg[\solver][\numNodes], 1.0);
        st[\nodeStability] = Array.fill(cfg[\solver][\numNodes], 1.0);
    };

    at[\resetToET] = {
        st[\nodePhase] = st[\etPhase].copy;
        st[\targetPhase] = st[\etPhase].copy;
        st[\targetCoreUnwrappedPhase] = st[\etPhase].copy;
        st[\lastSolvedPhase] = st[\etPhase].copy;
        st[\coreUnwrappedPhase] = st[\etPhase].copy;
        st[\frozenCoreUnwrappedPhase] = nil;
        st[\targetValid] = false;
        st[\motionActive] = false;
        st[\frozenValid] = false;
        st[\fieldFrozen] = false;
        st[\fieldFrozenAt] = nil;
        st[\fieldHadSolvedEvidence] = false;
        st[\frozenFromEvidence] = false;
        st[\musicalRestValid] = false;
        st[\lastFieldAction] = \reset;
        at[\clearDescriptors].();
        st[\soleAnchorPc] = nil;
        st[\soleAnchorPhase] = nil;
        st[\singletonReentryPending] = nil;
        st[\lastCorePathOnset] = nil;
        st[\lastCoreTransport] = nil;
        st[\coreTransportHistory] = Array.new;
        st[\diagnosticRootByActiveSet] = Dictionary.new;
        st[\diagnosticRootLastPc] = nil;
        st[\stateLabel] = \neutral;
        if(at[\clearTonalMemory].notNil) { at[\clearTonalMemory].(); };
    };

    at[\freezeCurrentField] = {
        var meaningful;
        meaningful = (st[\fieldHadSolvedEvidence] ? false) or: { st[\memoryValid] == true };
        st[\nodePhase] = st[\nodePhase].copy;
        st[\frozenPhase] = st[\nodePhase].copy;
        st[\frozenCoreUnwrappedPhase] = (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy;
        st[\targetPhase] = st[\nodePhase].copy;
        st[\lastSolvedPhase] = st[\nodePhase].copy;
        st[\targetValid] = false;
        st[\motionActive] = false;
        st[\frozenValid] = true;
        st[\fieldFrozen] = true;
        st[\fieldFrozenAt] = Main.elapsedTime;
        st[\frozenFromEvidence] = meaningful;
        st[\musicalRestValid] = meaningful;
        st[\lastFieldAction] = if(meaningful) { \freeze } { \neutralFreeze };
        st[\soleAnchorPc] = nil;
        st[\soleAnchorPhase] = nil;
        st[\singletonReentryPending] = nil;
        at[\clearDescriptors].();
        st[\stateLabel] = if(meaningful) { \frozen } { \neutralFrozen };
        if(meaningful and: { at[\memoryDecayNoEvidence].notNil }) { at[\memoryDecayNoEvidence].(); };
        diag[\log].("field frozen meaningful=" ++ meaningful.asString);
    };

    at[\restoreFrozenField] = {
        var oldPhase, oldUnwrapped, candidatePhase, candidateUnwrapped, guardOut;
        if(st[\frozenValid]) {
            oldPhase = st[\nodePhase].copy;
            oldUnwrapped = (st[\coreUnwrappedPhase] ? oldPhase).copy;
            candidatePhase = st[\frozenPhase].copy;
            candidateUnwrapped = if(st[\frozenCoreUnwrappedPhase].notNil) { st[\frozenCoreUnwrappedPhase].copy } { candidatePhase.copy };
            if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                guardOut = at[\applyPitchIdentityFieldCommitGuard].(candidatePhase, candidateUnwrapped, \restoreFrozen, oldPhase, oldUnwrapped);
                candidatePhase = guardOut[\phase] ? candidatePhase;
                candidateUnwrapped = guardOut[\unwrapped] ? candidateUnwrapped;
            };
            st[\nodePhase] = candidatePhase.copy;
            st[\targetPhase] = candidatePhase.copy;
            st[\lastSolvedPhase] = candidatePhase.copy;
            st[\coreUnwrappedPhase] = candidateUnwrapped.copy;
            st[\targetCoreUnwrappedPhase] = candidateUnwrapped.copy;
            st[\targetValid] = false;
            st[\motionActive] = false;
            st[\fieldFrozen] = true;
            st[\lastFieldAction] = \restoreFrozen;
            st[\soleAnchorPc] = nil;
            st[\soleAnchorPhase] = nil;
            at[\clearDescriptors].();
            st[\stateLabel] = \frozen;
            diag[\log].("frozen field restored");
        };
    };

    at[\ensureCoreUnwrapped] = {
        if(st[\coreUnwrappedPhase].isNil or: { st[\coreUnwrappedPhase].size != cfg[\solver][\numNodes] }) {
            st[\coreUnwrappedPhase] = st[\nodePhase].copy;
        };
        st[\coreUnwrappedPhase];
    };

    at[\coreAuthoritySnapshot] = {
        var acfg, memorySetting, memoryConfidence, memoryAuthority, gravityAuthority, worldAuthority, phraseAuthority;
        var heldAuthority, externalAuthority, perceptualAuthority, inhibition, freedom, carryAuthority, movementFreedom, activeCount, externalCount;
        acfg = cfg[\authority] ? ();

        // Memory is earned: high memory amount does not inhibit the naked core
        // until the instrument has actually learned a recent field.
        memorySetting = if(cfg[\memory][\enabled] ? true) { st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0) } { 0.0 };
        memoryConfidence = if(st[\memoryValid] == true) { st[\memoryConfidence] ? 0.0 } { 0.0 };
        memoryAuthority = (memorySetting * memoryConfidence).clip(0.0, 1.0);

        // Gravity is intentional: it only inhibits free motion when explicitly enabled.
        gravityAuthority = if(cfg[\gravity].notNil and: { cfg[\gravity][\enabled] ? false }) {
            cfg[\gravity][\strength] ? 0.0
        } { 0.0 };
        gravityAuthority = gravityAuthority.clip(0.0, 1.0);

        // World/phrase are interpretive human/contextual authorities. They are
        // not raw core law, so they are counted only when enabled and confident.
        worldAuthority = if(cfg[\world].notNil and: { cfg[\world][\enabled] ? false }) {
            ((st[\worldLastBlend] ? (cfg[\world][\targetBlend] ? 0.0)) / 0.8).clip(0.0, 1.0)
        } { 0.0 };
        phraseAuthority = if(cfg[\phrase].notNil and: { cfg[\phrase][\enabled] ? false }) {
            ((st[\phraseFunctionConfidence] ? 0.0).max(st[\phraseHomeConfidence] ? 0.0)).clip(0.0, 1.0)
        } { 0.0 };

        activeCount = st[\activeNotes].size;
        heldAuthority = if(((cfg[\coreFreedom] ? ())[\heldGuardsEnabled] ? true) and: { activeCount > 0 }) { 1.0 } { 0.0 };

        externalCount = if(at[\currentExternalSources].notNil) { (at[\currentExternalSources].() ? Array.new).size } { 0 };
        externalAuthority = if((cfg[\mic][\enabled] ? false) and: { externalCount > 0 }) {
            (cfg[\mic][\weight] ? 0.0).clip(0.0, 1.0)
        } { 0.0 };

        // Perceptual coherence is a real compromise authority only when the
        // user/preset gives it nonzero amount. It is not raw harmonic law and
        // it is not allowed to define the fish core by default.
        perceptualAuthority = if((cfg[\perceptual][\enabled] ? true) and: { (cfg[\perceptual][\amount] ? 0.0) > 0.0 }) {
            (cfg[\perceptual][\amount] ? 0.0).clip(0.0, 1.0)
        } { 0.0 };
        if(cfg[\perceptualSpectrum].notNil and: { (cfg[\perceptualSpectrum][\enabled] ? true) and: { (cfg[\perceptualSpectrum][\amount] ? 0.0) > 0.0 } }) {
            perceptualAuthority = perceptualAuthority.max((cfg[\perceptualSpectrum][\amount] ? 0.0).clip(0.0, 1.0));
        };

        // Carry/movement are deliberately reported separately. Carry is a
        // transport/enabling authority, not a stabilizer. Movement is a motion
        // openness macro, not a harmonic law.
        carryAuthority = if(cfg[\solver][\contextGaugeEnabled] ? false) {
            ((cfg[\solver][\contextGaugeStrength] ? 0.0) / 1.5).abs.clip(0.0, 1.0)
        } { 0.0 };
        movementFreedom = (st[\movement] ? 1.0).clip(0.0, 1.0);

        inhibition = (
            (memoryAuthority * (acfg[\memoryInhibitionWeight] ? 0.52))
            + (gravityAuthority * (acfg[\gravityInhibitionWeight] ? 0.30))
            + (worldAuthority * (acfg[\worldInhibitionWeight] ? 0.10))
            + (phraseAuthority * (acfg[\phraseInhibitionWeight] ? 0.08))
            + (heldAuthority * (acfg[\heldGuardInhibitionWeight] ? 0.10))
            + (externalAuthority * (acfg[\externalInhibitionWeight] ? 0.12))
            + (perceptualAuthority * (acfg[\perceptualInhibitionWeight] ? 0.10))
        ).clip(0.0, acfg[\maxInhibition] ? 0.97);
        freedom = (1.0 - inhibition).clip(0.0, 1.0);

        (
            memoryAuthority: memoryAuthority,
            gravityAuthority: gravityAuthority,
            worldAuthority: worldAuthority,
            phraseAuthority: phraseAuthority,
            heldAuthority: heldAuthority,
            externalAuthority: externalAuthority,
            perceptualAuthority: perceptualAuthority,
            carryAuthority: carryAuthority,
            movementFreedom: movementFreedom,
            inhibition: inhibition,
            freedom: freedom,
            activeCount: activeCount,
            externalCount: externalCount
        )
    };

    api[\authorityReport] = {
        var rep;
        rep = at[\coreAuthoritySnapshot].();
        "".postln;
        "[AT AUTHORITY REPORT]".postln;
        ("memoryAuthority=" ++ (rep[\memoryAuthority] ? 0.0).round(0.001).asString
            ++ " gravityAuthority=" ++ (rep[\gravityAuthority] ? 0.0).round(0.001).asString
            ++ " worldAuthority=" ++ (rep[\worldAuthority] ? 0.0).round(0.001).asString
            ++ " phraseAuthority=" ++ (rep[\phraseAuthority] ? 0.0).round(0.001).asString).postln;
        ("heldAuthority=" ++ (rep[\heldAuthority] ? 0.0).round(0.001).asString
            ++ " externalAuthority=" ++ (rep[\externalAuthority] ? 0.0).round(0.001).asString
            ++ " perceptualAuthority=" ++ (rep[\perceptualAuthority] ? 0.0).round(0.001).asString
            ++ " carryAuthority=" ++ (rep[\carryAuthority] ? 0.0).round(0.001).asString
            ++ " movementFreedom=" ++ (rep[\movementFreedom] ? 0.0).round(0.001).asString).postln;
        ("coreInhibition=" ++ (rep[\inhibition] ? 0.0).round(0.001).asString
            ++ " nakedCoreFreedom=" ++ (rep[\freedom] ? 1.0).round(0.001).asString).postln;
        rep;
    };
    at[\authorityReport] = { api[\authorityReport].(); };

    at[\rotateWholeFieldTo] = { |pc, phase|
        var off;
        at[\ensureCoreUnwrapped].();
        off = at[\wrapSigned].(phase - st[\nodePhase][pc]);
        st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + off) };
        st[\coreUnwrappedPhase] = st[\coreUnwrappedPhase].collect { |p| p + off };
    };

    at[\shiftLivedFieldBy] = { |offset, reason=\corePathTransport|
        var off;
        off = offset ? 0.0;
        if(off.abs > 0.000000001) {
            at[\ensureCoreUnwrapped].();
            st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + off) };
            st[\coreUnwrappedPhase] = st[\coreUnwrappedPhase].collect { |p| p + off };
            if(st[\targetPhase].notNil) { st[\targetPhase] = st[\targetPhase].collect { |p| at[\wrap01].(p + off) }; };
            if(st[\lastSolvedPhase].notNil) { st[\lastSolvedPhase] = st[\lastSolvedPhase].collect { |p| at[\wrap01].(p + off) }; };
            if(st[\frozenPhase].notNil) { st[\frozenPhase] = st[\frozenPhase].collect { |p| at[\wrap01].(p + off) }; };
            st[\activeNotes].keysValuesDo { |midi, note|
                if(note.notNil) {
                    if(note[\protectedPhase].notNil) { note[\protectedPhase] = at[\wrap01].(note[\protectedPhase] + off); };
                    if(note[\heldInitialPhase].notNil) { note[\heldInitialPhase] = at[\wrap01].(note[\heldInitialPhase] + off); };
                    st[\activeNotes][midi] = note;
                };
            };
            st[\lastFieldAction] = reason;
            at[\pushBuses].();
        };
        off;
    };

    at[\corePathIntervalTarget] = { |midiDelta|
        var direction, k, targetAbs, choices;
        if(midiDelta == 0) {
            0.0;
        } {
            direction = if(midiDelta >= 0) { 1.0 } { -1.0 };
            k = midiDelta.abs.asInteger % 12;
            if(k == 0) {
                0.0;
            } {
                choices = at[\ratioChoices][k];
                targetAbs = choices[0][0];
                direction * targetAbs;
            }
        }
    };

    at[\setCorePathPhaseForPc] = { |pc, unwrappedPhase, reason=\coreFreePath|
        var oldPhase, oldUnwrapped, baseTarget, baseTargetU, candidatePhase, candidateUnwrapped, guardOut;
        at[\ensureCoreUnwrapped].();
        oldPhase = st[\nodePhase].copy;
        oldUnwrapped = st[\coreUnwrappedPhase].copy;
        baseTarget = (st[\targetPhase] ? oldPhase).copy;
        baseTargetU = (st[\targetCoreUnwrappedPhase] ? oldUnwrapped).copy;
        candidatePhase = baseTarget.copy;
        candidateUnwrapped = baseTargetU.copy;
        candidateUnwrapped[pc] = unwrappedPhase;
        candidatePhase[pc] = at[\wrap01].(unwrappedPhase);
        if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
            guardOut = at[\applyPitchIdentityFieldCommitGuard].(candidatePhase, candidateUnwrapped, reason, oldPhase, oldUnwrapped, [pc]);
            candidatePhase = guardOut[\phase] ? candidatePhase;
            candidateUnwrapped = guardOut[\unwrapped] ? candidateUnwrapped;
        };
        st[\targetPhase] = candidatePhase.copy;
        st[\targetCoreUnwrappedPhase] = candidateUnwrapped.copy;
        st[\lastSolvedPhase] = candidatePhase.copy;
        st[\targetValid] = true;
        st[\motionActive] = true;
        st[\targetReason] = reason;
        st[\targetSetAt] = Main.elapsedTime;
        st[\lastFieldAction] = reason;
        if(at[\motionStepToTarget].notNil) { at[\motionStepToTarget].() } { at[\pushBuses].() };
        st[\nodePhase][pc];
    };

    at[\prepareCorePathOnset] = { |midi, pc, prevCount=0, now=nil|
        var c, prev, dt, midiDelta, targetSigned, prevU, rawDesiredU, desiredU, currentU, currentPhaseBefore, phase, centsAudible, sheetCents, shouldPath, rec, hist, auth, freedom, pathFreedom, acfg, pathExp;
        c = cfg[\coreTransport] ? ();
        now = now ? Main.elapsedTime;
        at[\ensureCoreUnwrapped].();
        prev = st[\lastCorePathOnset];
        currentU = st[\coreUnwrappedPhase][pc] ? st[\nodePhase][pc];
        currentPhaseBefore = st[\nodePhase][pc];
        desiredU = currentU;
        targetSigned = 0.0;
        midiDelta = 0;
        shouldPath = prev.notNil
            and: { midi.notNil }
            and: { pc.notNil }
            and: { (prev[\pc] ? pc) != pc };

        if(shouldPath) {
            dt = now - (prev[\timestamp] ? now);
            midiDelta = midi - (prev[\midi] ? midi);
            shouldPath = (dt >= 0.0)
                and: { dt <= (c[\pathWindow] ? 4.0) }
                and: { midiDelta.abs <= (c[\maxMidiLeap] ? 24) }
                and: { ((c[\allowDuringPolyphony] ? true) == true) or: { prevCount <= 1 } };
        };

        if(shouldPath) {
            targetSigned = at[\corePathIntervalTarget].(midiDelta);
            prevU = prev[\unwrappedPhase] ? (st[\coreUnwrappedPhase][prev[\pc]] ? st[\nodePhase][prev[\pc]]);
            rawDesiredU = prevU + targetSigned;
            auth = if(at[\coreAuthoritySnapshot].notNil) { at[\coreAuthoritySnapshot].() } { (freedom: 1.0, inhibition: 0.0) };
            freedom = (auth[\freedom] ? 1.0).clip(0.0, 1.0);
            acfg = cfg[\authority] ? ();
            pathExp = (acfg[\pathFreedomExponent] ? 1.0).max(1.0);
            pathFreedom = (freedom.pow(pathExp)).max(acfg[\minPathFreedom] ? 0.0).clip(0.0, 1.0);

            // Free core: rawDesiredU is installed exactly.
            // Stabilized core: earned/intentional authorities inhibit how much
            // of that raw path is allowed to appear. This is not a diminished
            // mode and not an added transport effect; it is the same raw core
            // being constrained by real authorities. High authority uses a
            // nonlinear resistance curve so the field really barely moves at
            // the fully embodied pole, while zero authority remains exact.
            desiredU = currentU + ((rawDesiredU - currentU) * pathFreedom);
            phase = at[\setCorePathPhaseForPc].(pc, desiredU, \coreFreePath);
            desiredU = if(st[\targetCoreUnwrappedPhase].notNil) { st[\targetCoreUnwrappedPhase][pc] ? desiredU } { st[\coreUnwrappedPhase][pc] ? desiredU };
            centsAudible = at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0;
            sheetCents = (desiredU - st[\etPhase][pc]) * 1200.0;
            rec = (
                timestamp: now,
                prevMidi: prev[\midi], prevPc: prev[\pc], prevUnwrappedPhase: prevU,
                midi: midi, pc: pc, midiDelta: midiDelta,
                targetSigned: targetSigned,
                rawDesiredUnwrappedPhase: rawDesiredU,
                authorityInhibition: auth[\inhibition] ? 0.0,
                coreFreedom: freedom,
                pathFreedom: pathFreedom,
                desiredUnwrappedPhase: desiredU,
                currentUnwrappedBefore: currentU,
                currentPhaseBefore: currentPhaseBefore,
                audiblePhase: phase,
                audibleDevCents: centsAudible,
                sheetDevCents: sheetCents,
                dt: dt,
                reason: \coreFreePath
            );
            st[\lastCoreTransport] = rec;
            hist = st[\coreTransportHistory] ? Array.new;
            hist = hist.add(rec);
            if(hist.size > 64) { hist = hist.copyRange(hist.size - 64, hist.size - 1); };
            st[\coreTransportHistory] = hist;
        } {
            phase = st[\nodePhase][pc];
            desiredU = st[\coreUnwrappedPhase][pc] ? phase;
            st[\lastCoreTransport] = (
                timestamp: now, midi: midi, pc: pc,
                audiblePhase: phase, desiredUnwrappedPhase: desiredU,
                audibleDevCents: at[\wrapSigned].(phase - st[\etPhase][pc]) * 1200.0,
                sheetDevCents: (desiredU - st[\etPhase][pc]) * 1200.0,
                applied: false, reason: \newPathOrIneligible
            );
        };

        st[\lastCorePathOnset] = (
            timestamp: now, midi: midi, pc: pc,
            phase: st[\nodePhase][pc],
            unwrappedPhase: desiredU
        );
        st[\lastCoreTransport];
    };

    // Backward-compatible diagnostic name. This no longer shifts the whole field
    // as a separate effect; it interprets the new onset as part of the naked
    // harmonic path and places that pitch-class node on its lived sheet.
    at[\applyCorePathTransportOnNoteOn] = { |midi, pc, prevCount=0, now=nil|
        at[\prepareCorePathOnset].(midi, pc, prevCount, now);
    };

    api[\coreTransportReport] = {
        var u, audible, sheet;
        at[\ensureCoreUnwrapped].();
        u = st[\coreUnwrappedPhase][0] ? st[\nodePhase][0];
        audible = at[\wrapSigned].(st[\nodePhase][0] - st[\etPhase][0]) * 1200.0;
        sheet = (u - st[\etPhase][0]) * 1200.0;
        "".postln;
        "[AT CORE TRANSPORT REPORT]".postln;
        ("last=" ++ (st[\lastCoreTransport] ? nil).asString).postln;
        ("historySize=" ++ ((st[\coreTransportHistory] ? Array.new).size).asString).postln;
        ("currentCDeviationCents=" ++ audible.round(0.001).asString).postln;
        ("currentCSheetCents=" ++ sheet.round(0.001).asString).postln;
        st[\lastCoreTransport];
    };

    at[\promoteToSingleAnchor] = { |pc, phase|
        st[\soleAnchorPc] = pc;
        st[\soleAnchorPhase] = phase;
        at[\rotateWholeFieldTo].(pc, phase);
        at[\clearDescriptors].();
        st[\stateLabel] = \single;
    };

    at[\singletonContinuityAnchor] = { |pc, externalSources|
        var primaryExternal, pending;
        primaryExternal = at[\strongestExternalSource].(externalSources ? Array.new);
        if(primaryExternal.notNil and: { at[\sourceStrength].(primaryExternal) > 0.000001 }) {
            nil
        } {
            pending = st[\singletonReentryPending];
            if(pending.notNil and: { pending[\pc] == pc } and: { pending[\anchorPhase].notNil }) {
                pending[\anchorPhase]
            } {
                if((st[\frozenValid] == true) and: { st[\frozenFromEvidence] == true }) { st[\frozenPhase][pc] } { nil }
            }
        }
    };

    at[\singleAnchorPhaseWithExternal] = { |pc, defaultPhase, externalSources|
        var primary, influence;
        primary = at[\strongestExternalSource].(externalSources ? Array.new);
        if(primary.notNil and: { primary[\pc] == pc }) {
            influence = ((primary[\weight] ? 0.0) * (primary[\confidence] ? 1.0)).clip(0.0, 1.0) * 0.55;
            at[\phaseBlend].(defaultPhase, primary[\phase], influence);
        } {
            defaultPhase;
        };
    };

    at[\protectedHeldTargetPhase] = { |pc, oldPhase, solvedPhase|
        var oldest, oldestAge, maxCents, maxPhase, refPhase, diff, clamped;
        var now, dt, pressureCents, pressureThreshold, sign, prevSign, accum, attack, decay;
        var elasticEnabled, yieldRate, yieldStep, yieldScale, extraMax, ageThreshold;
        oldest = nil;
        oldestAge = 0.0;
        at[\notesArray].().do { |note|
            var age;
            if(note[\pc] == pc) {
                age = at[\noteAge].(note);
                if(age > oldestAge) {
                    oldest = note;
                    oldestAge = age;
                };
            };
        };

        ageThreshold = cfg[\motion][\heldAgeThreshold] ? 0.65;
        if(oldest.notNil and: { oldestAge >= ageThreshold }) {
            refPhase = oldest[\protectedPhase] ? oldPhase;
            diff = at[\wrapSigned].(solvedPhase - refPhase);
            extraMax = 0.0;

            elasticEnabled = cfg[\motion][\heldElasticEnabled] ? true;
            if(elasticEnabled) {
                now = Main.elapsedTime;
                dt = if(oldest[\heldElasticLastAt].isNil) {
                    cfg[\field][\continuousResolveInterval] ? 0.08
                } {
                    (now - oldest[\heldElasticLastAt]).clip(0.0, 0.25)
                };
                yieldScale = (dt / (cfg[\field][\continuousResolveInterval] ? 0.08)).clip(0.15, 3.0);
                pressureCents = diff.abs * 1200.0;
                pressureThreshold = cfg[\motion][\heldElasticPressureCents] ? 1.25;
                sign = if(diff >= 0.0) { 1 } { -1 };
                prevSign = oldest[\heldElasticSign];
                accum = oldest[\heldElasticAccum] ? 0.0;
                attack = cfg[\motion][\heldElasticAttack] ? 0.09;
                decay = cfg[\motion][\heldElasticDecay] ? 0.045;

                if(pressureCents >= pressureThreshold) {
                    if(prevSign.notNil and: { prevSign != sign }) {
                        accum = accum * 0.35;
                    };
                    accum = (accum + (attack * yieldScale)).clip(0.0, 1.0);
                } {
                    accum = (accum - (decay * yieldScale)).clip(0.0, 1.0);
                };

                yieldRate = ((cfg[\motion][\heldElasticYieldRateCents] ? 0.16) / 1200.0) * yieldScale;
                yieldStep = diff.clip(yieldRate.neg, yieldRate) * accum;
                if(yieldStep.abs > 0.00000001) {
                    refPhase = at[\wrap01].(refPhase + yieldStep);
                    oldest[\protectedPhase] = refPhase;
                };
                oldest[\heldElasticAccum] = accum;
                oldest[\heldElasticSign] = sign;
                oldest[\heldElasticLastAt] = now;
                oldest[\heldElasticLastPressureCents] = pressureCents;
                oldest[\heldElasticYieldCents] = yieldStep * 1200.0;
                oldest[\heldElasticIntegratedPressureCentsSec] = (oldest[\heldElasticIntegratedPressureCentsSec] ? 0.0) + (pressureCents * dt);
                oldest[\heldElasticTotalYieldCents] = (oldest[\heldElasticTotalYieldCents] ? 0.0) + (yieldStep * 1200.0);
                oldest[\heldElasticPeakPressureCents] = ((oldest[\heldElasticPeakPressureCents] ? 0.0).max(pressureCents));
                if(oldest[\midi].notNil) { st[\activeNotes][oldest[\midi]] = oldest; };
                extraMax = (cfg[\motion][\heldElasticMaxExtraCents] ? 18.0) * accum;
                diff = at[\wrapSigned].(solvedPhase - refPhase);
            };

            maxCents = (cfg[\motion][\heldTargetMaxCents] ? 4.0) + extraMax;
            maxPhase = (maxCents / 1200.0).max(0.0);
            clamped = diff.clip(maxPhase.neg, maxPhase);
            at[\wrap01].(refPhase + clamped);
        } {
            solvedPhase;
        };
    };

    at[\applyHeldTargetGuards] = { |oldPhase, solvedPhase|
        var guarded, weights, activePcs;
        if(((cfg[\coreFreedom] ? ())[\heldGuardsEnabled] ? true).not) {
            solvedPhase;
        } {
            guarded = solvedPhase.copy;
            weights = at[\pcWeights].();
            activePcs = at[\activePcsFromWeights].(weights);
            activePcs.do { |pc|
                guarded[pc] = at[\protectedHeldTargetPhase].(pc, oldPhase[pc], guarded[pc]);
            };
            guarded;
        };
    };

    at[\applyLowerOnsetGaugeCarry] = { |activePcs, pcWeights|
        var info, now, recentWindow, enabled, shouldCarry, move, strength, polarity, pc, midi, currentPhase, desiredPhase, rawOffset, maxOffset, offset;
        info = st[\lastOnsetInfo];
        now = Main.elapsedTime;
        recentWindow = cfg[\solver][\contextGaugeRecentWindow] ? 0.35;
        enabled = cfg[\solver][\contextGaugeEnabled] ? true;
        shouldCarry = enabled
            and: { info.notNil }
            and: { (info[\consumed] ? false).not }
            and: { (now - (info[\timestamp] ? now)) <= recentWindow }
            and: { (info[\wasLowerOnset] ? false) == true }
            and: { activePcs.size > 1 }
            and: { activePcs.includes(info[\pc]) };
        if(shouldCarry) {
            move = (st[\movement] ? 0.0).clip(0.0, 1.0);
            strength = (cfg[\solver][\contextGaugeStrength] ? 1.0).abs.clip(0.0, 1.5);
            polarity = (cfg[\solver][\contextGaugePolarity] ? 1.0).clip(-1.0, 1.0);
            pc = info[\pc];
            midi = info[\midi];
            currentPhase = st[\nodePhase][pc];
            desiredPhase = at[\freqToPhase].(at[\midiToFreq].(midi));
            rawOffset = at[\wrapSigned].(desiredPhase - currentPhase);
            maxOffset = ((cfg[\solver][\contextGaugeMaxCents] ? 18.0) / 1200.0).max(0.0);
            offset = (rawOffset * strength * polarity).clip(maxOffset.neg, maxOffset);
            if(offset.abs > 0.0000001) {
                st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + offset) };
            };
            info[\consumed] = true;
            st[\lastOnsetInfo] = info;
            st[\lastGaugeCarry] = (
                timestamp: now, midi: midi, pc: pc, desiredPhase: desiredPhase,
                previousPhase: currentPhase, rawOffset: rawOffset, offset: offset,
                cents: offset * 1200.0, movement: move, strength: strength,
                polarity: polarity, signedCarry: (strength * polarity),
                reason: \lowerOnsetContextGauge
            );
        } {
            if(info.notNil and: { (info[\consumed] ? false).not } and: { (now - (info[\timestamp] ? now)) > recentWindow }) {
                info[\consumed] = true;
                st[\lastOnsetInfo] = info;
            };
        };
    };

    at[\settleSingle] = { |pc, anchorPhase, pcWeights, externalSources=nil, maxIter=nil|
        var iterMax, eps, delta, forces, i, singleWeights, alpha;
        iterMax = if(maxIter.isNil) { cfg[\solver][\eventSingleIter] } { maxIter };
        eps = cfg[\solver][\eventEps];
        alpha = cfg[\solver][\singleAlpha] * (0.55 + ((cfg[\solver][\solverTension] ? 0.55) * 0.9));
        singleWeights = Array.fill(cfg[\solver][\numNodes], 0.0);
        singleWeights[pc] = (pcWeights[pc] ? 0.0).max(0.2);
        at[\promoteToSingleAnchor].(pc, anchorPhase);
        delta = Array.fill(cfg[\solver][\numNodes], 0.0);
        i = 0;
        while { i < iterMax } {
            forces = at[\computeForces].([pc], singleWeights, externalSources);
            forces[pc] = 0.0;
            delta = forces.collect { |f| (f * alpha).clip(cfg[\solver][\maxStep].neg, cfg[\solver][\maxStep]) };
            delta[pc] = 0.0;
            at[\applyDelta].(delta);
            at[\rotateWholeFieldTo].(pc, anchorPhase);
            if(at[\maxAbs].(delta) < eps) { i = iterMax } { i = i + 1 };
        };
        at[\updateDescriptors].([pc], singleWeights, externalSources, delta);
        st[\stateLabel] = if((externalSources ? Array.new).notEmpty) { \mixedSingle } { \single };
    };

    at[\settleMulti] = { |activePcs, pcWeights, externalSources=nil, maxIter=nil|
        var iterMax, eps, anchorPc, anchorPhase, forces, delta, alpha, i, mean;
        iterMax = if(maxIter.isNil) { cfg[\solver][\eventMultiIter] } { maxIter };
        eps = cfg[\solver][\eventEps];
        alpha = cfg[\solver][\multiAlpha] * (0.5 + ((cfg[\solver][\solverTension] ? 0.55) * 0.8));
        anchorPc = at[\chooseAnchorPc].(activePcs, pcWeights);
        anchorPhase = st[\nodePhase][anchorPc];
        st[\soleAnchorPc] = nil;
        st[\soleAnchorPhase] = nil;
        delta = Array.fill(cfg[\solver][\numNodes], 0.0);
        i = 0;
        while { i < iterMax } {
            forces = at[\computeForces].(activePcs, pcWeights, externalSources);
            mean = activePcs.collect { |pc| forces[pc] }.sum / activePcs.size.max(1);
            forces = forces.collect { |f| f - mean };
            delta = forces.collect { |f| (f * alpha).clip(cfg[\solver][\maxStep].neg, cfg[\solver][\maxStep]) };
            at[\applyDelta].(delta);
            at[\rotateWholeFieldTo].(anchorPc, anchorPhase);
            if(at[\maxAbs].(delta) < eps) { i = iterMax } { i = i + 1 };
        };
        at[\updateDescriptors].(activePcs, pcWeights, externalSources, delta);
        at[\applyLowerOnsetGaugeCarry].(activePcs, pcWeights);
        st[\stateLabel] = if((externalSources ? Array.new).notEmpty) { \mixedMulti } { \multi };
    };

    at[\settleExternalOnly] = { |externalSources, maxIter=nil|
        var sources, activePcs, pcWeights, iterMax, eps, alpha, anchorSrc, anchorPc, anchorPhase, forces, delta, i, mean;
        sources = at[\takeStrongestSources].((externalSources ? Array.new), cfg[\mic][\maxExternalSources]);
        if(sources.isEmpty) {
            at[\freezeCurrentField].();
        } {
            if(sources.size == 1) {
                pcWeights = at[\pcWeightsForExternalSources].(sources);
                at[\settleSingle].(sources[0][\pc], sources[0][\phase], pcWeights, sources, if(maxIter.isNil) { cfg[\solver][\micIter] } { maxIter });
                st[\stateLabel] = \external;
            } {
                activePcs = sources.collect { |src| src[\pc] }.as(Set).asArray.sort;
                iterMax = if(maxIter.isNil) { cfg[\solver][\micIter] } { maxIter };
                eps = cfg[\solver][\eventEps];
                alpha = cfg[\solver][\multiAlpha] * (0.46 + ((cfg[\solver][\solverTension] ? 0.55) * 0.72));
                anchorSrc = at[\strongestExternalSource].(sources);
                anchorPc = anchorSrc[\pc];
                anchorPhase = anchorSrc[\phase];
                st[\soleAnchorPc] = nil;
                st[\soleAnchorPhase] = nil;
                delta = Array.fill(cfg[\solver][\numNodes], 0.0);
                i = 0;
                while { i < iterMax } {
                    forces = at[\computeForcesFromSourceList].(sources, activePcs);
                    mean = activePcs.collect { |pc| forces[pc] }.sum / activePcs.size.max(1);
                    forces = forces.collect { |f| f - mean };
                    delta = forces.collect { |f| (f * alpha).clip(cfg[\solver][\maxStep].neg, cfg[\solver][\maxStep]) };
                    at[\applyDelta].(delta);
                    at[\rotateWholeFieldTo].(anchorPc, anchorPhase);
                    if(at[\maxAbs].(delta) < eps) { i = iterMax } { i = i + 1 };
                };
                at[\updateDescriptorsFromSources].(sources, activePcs, delta);
                st[\stateLabel] = \external;
            };
        };
    };

    at[\installSolvedTarget] = { |oldPhase, solvedPhase, reason=\resolve, oldUnwrapped=nil, solvedUnwrapped=nil|
        var guardOut;
        if(at[\applyWorldScoringBias].notNil) { solvedPhase = at[\applyWorldScoringBias].(oldPhase, solvedPhase, reason); solvedUnwrapped = nil; };
        if(at[\learnTonalMemory].notNil) { at[\learnTonalMemory].(solvedPhase, at[\memoryActivePcs].(), reason); };
        if(at[\applyTonalMemoryBias].notNil) { solvedPhase = at[\applyTonalMemoryBias].(solvedPhase, at[\memoryActivePcs].(), reason); };
        if(at[\applyGravityBias].notNil) { solvedPhase = at[\applyGravityBias].(solvedPhase, at[\memoryActivePcs].(), reason); };
        if(at[\applyPerceptualCoherenceBias].notNil) { solvedPhase = at[\applyPerceptualCoherenceBias].(solvedPhase, at[\memoryActivePcs].(), reason); solvedUnwrapped = nil; };
        solvedPhase = at[\applyHeldTargetGuards].(oldPhase, solvedPhase);
        if(at[\applyPitchIdentityTopologyGuard].notNil) {
            guardOut = at[\applyPitchIdentityTopologyGuard].(oldPhase, solvedPhase, solvedUnwrapped, reason, oldUnwrapped);
            solvedPhase = guardOut[\phase] ? solvedPhase;
            solvedUnwrapped = guardOut[\unwrapped];
        };
        st[\targetPhase] = solvedPhase.copy;
        st[\lastSolvedPhase] = solvedPhase.copy;
        st[\targetCoreUnwrappedPhase] = (solvedUnwrapped ? solvedPhase).copy;
        st[\targetValid] = true;
        st[\fieldHadSolvedEvidence] = true;
        st[\frozenFromEvidence] = false;
        st[\musicalRestValid] = false;
        st[\targetReason] = reason;
        st[\targetSetAt] = Main.elapsedTime;
        st[\fieldFrozen] = false;
        st[\lastFieldAction] = reason;
        st[\nodePhase] = oldPhase.copy;
        st[\coreUnwrappedPhase] = (oldUnwrapped ? oldPhase).copy;
        if(at[\motionStepToTarget].notNil) { at[\motionStepToTarget].() } { at[\pushBuses].() };
    };

    at[\settleForCurrentConstraints] = { |reason=\resolve|
        var ev, pcWeights, activePcs, externalSources, primaryExternal, onlyPc, onlyNote, anchorPhase, continuityAnchor;
        var oldPhase, solvedPhase, oldUnwrapped, solvedUnwrapped, installTarget, guardOut;
        oldPhase = st[\nodePhase].copy;
        if(at[\ensureCoreUnwrapped].notNil) { at[\ensureCoreUnwrapped].(); };
        oldUnwrapped = (st[\coreUnwrappedPhase] ? oldPhase).copy;
        installTarget = false;
        ev = if(at[\collectEvidence].notNil) { at[\collectEvidence].() } {
            (
                pcWeights: at[\pcWeights].(),
                activePcs: at[\activePcsFromWeights].(at[\pcWeights].()),
                externalSources: if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { Array.new }
            )
        };
        st[\lastEvidence] = ev;
        pcWeights = ev[\pcWeights];
        activePcs = ev[\activePcs];
        externalSources = ev[\externalSources] ? Array.new;
        primaryExternal = at[\strongestExternalSource].(externalSources);
        if(at[\applyMicReleaseHoldIfNeeded].notNil and: { at[\applyMicReleaseHoldIfNeeded].(activePcs, externalSources, reason) }) {
            installTarget = false;
        } {
            if(activePcs.size == 0) {
                if(primaryExternal.notNil) {
                    at[\settleExternalOnly].(externalSources, cfg[\solver][\micIter]);
                    st[\stateLabel] = \external;
                    installTarget = true;
                } {
                    at[\freezeCurrentField].();
                    installTarget = false;
                };
            } {
                if(activePcs.size == 1) {
                onlyPc = activePcs[0];
                onlyNote = at[\notesArray].().detect { |n| n[\pc] == onlyPc };
                continuityAnchor = at[\singletonContinuityAnchor].(onlyPc, externalSources);
                if(continuityAnchor.notNil) {
                    at[\restoreFrozenField].();
                    at[\promoteToSingleAnchor].(onlyPc, continuityAnchor);
                    at[\clearDescriptors].();
                    st[\stateLabel] = \singleReentry;
                    st[\singletonReentryPending] = nil;
                    installTarget = false;
                } {
                    if(onlyNote.notNil and: { onlyNote[\referenceFreq].notNil }) {
                        anchorPhase = at[\freqToPhase].(onlyNote[\referenceFreq]);
                    } {
                        anchorPhase = if(onlyNote.notNil and: { onlyNote[\coreAnchorPhase].notNil }) {
                            onlyNote[\coreAnchorPhase]
                        } {
                            st[\nodePhase][onlyPc]
                        };
                    };
                    anchorPhase = at[\singleAnchorPhaseWithExternal].(onlyPc, anchorPhase, externalSources);
                    at[\settleSingle].(onlyPc, anchorPhase, pcWeights, externalSources, cfg[\solver][\eventSingleIter]);
                    installTarget = true;
                };
                } {
                    at[\settleMulti].(activePcs, pcWeights, externalSources, cfg[\solver][\eventMultiIter]);
                    installTarget = true;
                };
            };
        };
        if(installTarget) {
            solvedPhase = st[\nodePhase].copy;
            solvedUnwrapped = (st[\coreUnwrappedPhase] ? solvedPhase).copy;
            at[\installSolvedTarget].(oldPhase, solvedPhase, reason, oldUnwrapped, solvedUnwrapped);
        } {
            if(at[\applyPitchIdentityFieldCommitGuard].notNil) {
                guardOut = at[\applyPitchIdentityFieldCommitGuard].(st[\nodePhase].copy, (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy, reason, oldPhase, oldUnwrapped, activePcs);
                st[\nodePhase] = (guardOut[\phase] ? st[\nodePhase]).copy;
                st[\coreUnwrappedPhase] = if(guardOut[\unwrapped].notNil) { guardOut[\unwrapped].copy } { (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy };
            };
            st[\targetPhase] = st[\nodePhase].copy;
            st[\targetCoreUnwrappedPhase] = (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy;
            st[\targetValid] = false;
            st[\motionActive] = false;
            at[\pushBuses].();
        };
    };

    api[\resolveNow] = { |reason=\manual|
        diag[\log].("resolve reason=" ++ reason.asString);
        at[\settleForCurrentConstraints].(reason);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
    };
};
)
