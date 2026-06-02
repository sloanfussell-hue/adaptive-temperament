(
// AT_musical_gauge_authority.scd
// v30: musical gauge-authority layer.
// Internal interval pressure may bend relationships, but it cannot move the
// whole pitch world unless external/gravity/memory/context authority exists.
var build, at, cfg, st;

build = ~atBuild;

if(build.isNil) {
    "[at-v30] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];

    at[\activeSetSymmetryReport] = { |activePcs=nil|
        var pcs, n, gaps, i, diff, gap, regular, kind, symmetry, highSymmetry;
        pcs = (activePcs ? Array.new).collect { |p| p.asInteger % 12 }.as(Set).asArray.sort;
        n = pcs.size;
        gaps = Array.new;
        if(n > 0) {
            n.do { |idx|
                diff = pcs.wrapAt(idx + 1) - pcs.wrapAt(idx);
                if(diff <= 0) { diff = diff + 12; };
                gaps = gaps.add(diff);
            };
        };
        gap = if(gaps.isEmpty) { 0 } { gaps[0] };
        regular = (n >= 3) and: { (gap * n) == 12 } and: { gaps.every { |g| g == gap } };
        kind = \none;
        if(regular) {
            if((n == 4) and: { gap == 3 }) { kind = \diminishedSeventh; };
            if((n == 3) and: { gap == 4 }) { kind = \augmentedTriad; };
            if((n == 6) and: { gap == 2 }) { kind = \wholeTone; };
            if(kind == \none) { kind = \equalCycle; };
        };
        if((n == 2) and: { gap == 6 }) { kind = \tritoneDyad; };
        highSymmetry = regular or: { kind == \tritoneDyad };
        symmetry = if(regular) { 1.0 } { if(kind == \tritoneDyad) { 0.72 } { 0.0 } };
        (
            activePcs: pcs,
            count: n,
            gaps: gaps,
            regularCycle: regular,
            kind: kind,
            highSymmetry: highSymmetry,
            symmetry: symmetry
        )
    };

    at[\activePhraseIntervalAmbiguity] = { |pcStep=0|
        var step, kind, ambiguous, symmetry;
        step = pcStep.asInteger.abs % 12;
        kind = \none;
        ambiguous = false;
        symmetry = 0.0;
        if(step == 2) { kind = \wholeToneCycleInterval; ambiguous = true; symmetry = 0.82; };
        if(step == 3) { kind = \diminishedCycleInterval; ambiguous = true; symmetry = 0.92; };
        if(step == 4) { kind = \augmentedCycleInterval; ambiguous = true; symmetry = 0.92; };
        if(step == 6) { kind = \tritoneSymmetry; ambiguous = true; symmetry = 0.72; };
        (pcStep: step, kind: kind, ambiguous: ambiguous, symmetry: symmetry)
    };

    at[\musicalGaugeAuthorityReport] = { |reason=\internal, activePcs=nil, externalSources=nil, intervalPcStep=nil|
        var enabled, pcs, sources, extSources, src, sourceStrength, confidence, extAuthority;
        var gravityAuthority, memoryAuthority, common, memoryAmount, memoryPower;
        var authority, minAuthority, requiresAuthority, blockedUnanchored, blockedSymmetric, transportScale;
        var symmetry, ambiguity, tags, reasonSym;
        enabled = cfg[\solver][\musicalGaugeAuthorityEnabled] ? true;
        pcs = (activePcs ? at[\activePcsFromWeights].(at[\pcWeights].())).collect { |p| p.asInteger % 12 }.as(Set).asArray.sort;
        extSources = externalSources ? at[\currentExternalSources].();
        tags = Array.new;
        extAuthority = 0.0;
        (extSources ? Array.new).do { |s|
            src = s;
            sourceStrength = if(at[\sourceStrength].notNil) { at[\sourceStrength].(src) ? 0.0 } { src[\strength] ? (src[\weight] ? 0.0) };
            confidence = (src[\confidence] ? sourceStrength).clip(0.0, 1.0);
            extAuthority = extAuthority.max((sourceStrength / 0.45).clip(0.0, 1.0) * confidence.sqrt);
        };
        if(extAuthority > 0.000001) { tags = tags.add(\external); };

        gravityAuthority = if(cfg[\gravity].isNil) { 0.0 } {
            if(cfg[\gravity][\enabled] ? false) { ((cfg[\gravity][\strength] ? 0.0) * (cfg[\solver][\musicalGaugeGravityScale] ? 1.0)).clip(0.0, 1.0) } { 0.0 }
        };
        if(gravityAuthority > 0.000001) { tags = tags.add(\gravity); };

        memoryAmount = (st[\memoryAmount] ? (cfg[\perf][\memoryContinuityMacro] ? 0.0)).clip(0.0, 1.0);
        common = if(at[\commonToneRatioWithFrozen].notNil) { at[\commonToneRatioWithFrozen].(pcs) } { 0.0 };
        memoryPower = cfg[\solver][\musicalGaugeMemoryCommonTonePower] ? 1.35;
        memoryAuthority = (memoryAmount * (cfg[\solver][\musicalGaugeMemoryScale] ? 0.72) * common.clip(0.0, 1.0).pow(memoryPower.max(0.01))).clip(0.0, 1.0);
        if(memoryAuthority > 0.000001) { tags = tags.add(\memory); };

        authority = extAuthority.max(gravityAuthority).max(memoryAuthority).clip(0.0, 1.0);
        minAuthority = (cfg[\solver][\musicalGaugeAuthorityMin] ? 0.12).clip(0.0, 1.0);
        reasonSym = if(reason.isNil) { \internal } { reason.asSymbol };
        requiresAuthority = false;
        if(reasonSym == \activePhrase) { requiresAuthority = cfg[\solver][\activePhraseRequiresGaugeAuthority] ? true; };
        if(reasonSym == \activeBody) { requiresAuthority = cfg[\solver][\activeBodyRequiresGaugeAuthority] ? true; };
        symmetry = at[\activeSetSymmetryReport].(pcs);
        ambiguity = if(intervalPcStep.isNil) { (pcStep: 0, kind: \none, ambiguous: false, symmetry: 0.0) } { at[\activePhraseIntervalAmbiguity].(intervalPcStep) };
        blockedUnanchored = enabled and: { requiresAuthority and: { authority < minAuthority } };
        blockedSymmetric = blockedUnanchored and: { (symmetry[\highSymmetry] ? false) or: { ambiguity[\ambiguous] ? false } };
        transportScale = 1.0;
        if(enabled and: { blockedUnanchored }) { transportScale = cfg[\solver][\unanchoredInternalGaugeTransportScale] ? 0.0; };
        if(enabled and: { blockedSymmetric }) { transportScale = transportScale.min(cfg[\solver][\symmetricInternalGaugeTransportScale] ? 0.0); };
        (
            timestamp: Main.elapsedTime,
            enabled: enabled,
            reason: reasonSym,
            activePcs: pcs,
            externalCount: (extSources ? Array.new).size,
            sources: tags,
            authority: authority,
            minAuthority: minAuthority,
            requiresAuthority: requiresAuthority,
            blockedUnanchored: blockedUnanchored,
            blockedSymmetric: blockedSymmetric,
            transportScale: transportScale.clip(0.0, 1.0),
            externalAuthority: extAuthority,
            gravityAuthority: gravityAuthority,
            memoryAuthority: memoryAuthority,
            memoryCommonToneRatio: common,
            symmetry: symmetry,
            intervalAmbiguity: ambiguity,
            description: \internalRatioPressureCannotMoveWorldWithoutAuthority
        )
    };

    at[\transportSupportScale] = { |reason=\internal, activePcs=nil, externalSources=nil|
        var hasExternal, common, support, activeCount, ecology, minFreedom, denom, freeScale, phraseSupport;
        var gaugeAuthorityReport, transportScale, pendingPcStep;
        activePcs = activePcs ? at[\activePcsFromWeights].(at[\pcWeights].());
        externalSources = externalSources ? at[\currentExternalSources].();
        hasExternal = externalSources.notEmpty;
        activeCount = activePcs.size;

        if((cfg[\solver][\causalTransportEnabled] ? true) == false) {
            1.0
        } {
            if(hasExternal or: { reason == \externalEvidence }) {
                cfg[\solver][\causalExternalSupport] ? 1.0
            } {
                if(reason == \activePhrase) {
                    pendingPcStep = st[\activePhraseTransportPendingPcStep];
                    gaugeAuthorityReport = st[\activePhraseTransportPendingGaugeAuthorityReport] ? at[\musicalGaugeAuthorityReport].(\activePhrase, activePcs, externalSources, pendingPcStep);
                    transportScale = gaugeAuthorityReport[\transportScale] ? 1.0;
                    ((st[\activePhraseTransportPendingSupport] ? 0.0) * transportScale).clip(0.0, 1.0)
                } {
                    if(reason == \lowerOnset) {
                        cfg[\solver][\causalLowerOnsetSupport] ? 0.72
                    } {
                        common = at[\commonToneRatioWithFrozen].(activePcs);
                        support = if(activeCount <= 1) {
                            cfg[\solver][\causalInternalUnsupportedSupport] ? 0.10
                        } {
                            ((cfg[\solver][\causalInternalUnsupportedSupport] ? 0.10)
                                + ((cfg[\solver][\causalInternalCommonToneFloor] ? 0.20) * common)
                                + ((cfg[\solver][\causalInternalCommonToneBoost] ? 0.62) * (common * common))).clip(0.0, 1.0)
                        };
                        if(reason == \contextBreak) {
                            support = support * (cfg[\solver][\causalContextBreakSupportScale] ? 0.42);
                        };
                        if(reason == \activeBody) {
                            ecology = at[\transportEcologySnapshot].();
                            minFreedom = (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54).clip(0.0, 0.98);
                            denom = (1.0 - minFreedom).max(0.001);
                            freeScale = (((ecology[\freedom] ? 0.0) - minFreedom) / denom).clip(0.0, 1.0);
                            phraseSupport = ((cfg[\solver][\activePhraseTransportBodyBoost] ? 0.86) * freeScale * (ecology[\carry] ? 0.0).sqrt * (ecology[\motion] ? 0.0).sqrt).clip(0.0, 1.0);
                            support = (support * (cfg[\solver][\causalActiveBodySupportScale] ? 0.62)).max(phraseSupport);
                            gaugeAuthorityReport = at[\musicalGaugeAuthorityReport].(\activeBody, activePcs, externalSources, nil);
                            support = support * (gaugeAuthorityReport[\transportScale] ? 1.0);
                            st[\lastMusicalGaugeAuthorityReport] = gaugeAuthorityReport;
                        };
                        support.clip(0.0, 1.0)
                    }
                }
            }
        }
    };

    at[\applyCoherentGaugeTransport] = { |rawOffset, reason=\internal, strength=1.0, response=1.0, authority=1.0, inertia=nil|
        var enabled, now, move, inert, prevVel, desired, offset, damping;
        var activePcs, externalSources, support, effectivePrevVel, velDecay, sourceAuth, exponent;
        var gaugeAuthorityReport, transportScale;
        enabled = cfg[\solver][\coherentTransportEnabled] ? true;
        rawOffset = rawOffset ? 0.0;
        if(enabled == false) {
            desired = rawOffset * strength * response * authority;
            if(desired.abs > 0.0000000001) { st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + desired) }; };
            desired
        } {
            now = Main.elapsedTime;
            activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
            externalSources = at[\currentExternalSources].();
            gaugeAuthorityReport = if(at[\musicalGaugeAuthorityReport].notNil) {
                at[\musicalGaugeAuthorityReport].(reason, activePcs, externalSources, st[\activePhraseTransportPendingPcStep])
            } { (authority: 1.0, transportScale: 1.0, blockedUnanchored: false, blockedSymmetric: false, sources: Array.new) };
            transportScale = gaugeAuthorityReport[\transportScale] ? 1.0;
            support = at[\transportSupportScale].(reason, activePcs, externalSources).clip(0.0, 1.0);
            move = (st[\movement] ? 0.0).clip(0.0, 1.0);
            inert = if(inertia.isNil) {
                if(reason == \externalEvidence) { cfg[\solver][\coherentTransportExternalInertia] ? 0.34 } {
                    if(reason == \contextBreak) { cfg[\solver][\coherentTransportContextInertia] ? 0.46 } { cfg[\solver][\coherentTransportInertia] ? 0.52 }
                }
            } { inertia };
            inert = inert.clip(0.0, 0.98);
            damping = (cfg[\solver][\coherentTransportVelocityDamping] ? 0.72).clip(0.0, 1.0);
            prevVel = st[\fieldGaugeVelocity] ? 0.0;
            if((reason != \externalEvidence) and: { support < 0.25 }) {
                velDecay = cfg[\solver][\causalVelocityUnsupportedDecay] ? 0.22;
            } {
                if((reason != \externalEvidence) and: { support < 0.55 }) {
                    velDecay = cfg[\solver][\causalVelocityPartialDecay] ? 0.58;
                } {
                    velDecay = 1.0;
                };
            };
            effectivePrevVel = prevVel * velDecay.clip(0.0, 1.0);
            if(transportScale <= 0.000001) { effectivePrevVel = 0.0; };
            sourceAuth = 1.0;
            if((cfg[\solver][\transportFreshSupportEnabled] ? true) and: { reason != \externalEvidence }) {
                exponent = if(reason == \activeBody) {
                    cfg[\solver][\transportActiveBodySupportExponent] ? 2.15
                } {
                    if(reason == \contextBreak) {
                        cfg[\solver][\transportContextBreakSupportExponent] ? 2.0
                    } {
                        if(reason == \lowerOnset) {
                            cfg[\solver][\transportLowerSupportExponent] ? 0.55
                        } {
                            if(reason == \continuous) { cfg[\solver][\transportContinuousSupportExponent] ? 1.25 } { cfg[\solver][\transportFreshSupportExponent] ? 1.65 }
                        }
                    }
                };
                sourceAuth = support.clip(0.0, 1.0).pow(exponent.max(0.0));
            };
            sourceAuth = sourceAuth * transportScale.clip(0.0, 1.0);
            desired = rawOffset * strength.clip(0.0, 2.0) * response.clip(0.0, 1.5) * authority.clip(0.0, 2.0) * sourceAuth * (0.12 + (move * 0.88));
            offset = (desired * (1.0 - inert)) + (effectivePrevVel * inert);
            offset = offset * (if(at[\globalMotionGateAmount].notNil) { at[\globalMotionGateAmount].() } { (st[\movement] ? 0.0).clip(0.0, 1.0) });
            st[\fieldGaugeVelocity] = (offset * damping) + (effectivePrevVel * (1.0 - damping));
            st[\fieldGaugeLastOffset] = offset;
            st[\fieldGaugeLastTime] = now;
            if(offset.abs > 0.0000000001) {
                st[\fieldTrueGaugeCents] = (st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0)) + (offset * 1200.0);
                st[\fieldTrueGaugeVelocityCents] = offset * 1200.0;
                st[\fieldGaugeCents] = st[\fieldTrueGaugeCents];
                st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + offset) };
            } {
                st[\fieldGaugeCents] = st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0);
            };
            if((cfg[\solver][\coherentTransportReportEnabled] ? true) and: { ((reason != \continuous) or: { cfg[\solver][\diagnosticContinuousReports] ? false }) }) {
                st[\lastCoherentTransportReport] = (
                    timestamp: now,
                    reason: reason,
                    rawOffsetCents: rawOffset * 1200.0,
                    desiredCents: desired * 1200.0,
                    appliedCents: offset * 1200.0,
                    velocityCents: (st[\fieldGaugeVelocity] ? 0.0) * 1200.0,
                    fieldGaugeCents: (st[\fieldGaugeCents] ? 0.0),
                    support: support,
                    sourceAuth: sourceAuth,
                    velocityDecay: velDecay,
                    strength: strength,
                    response: response,
                    authority: authority,
                    inertia: inert,
                    movement: move,
                    musicalGaugeAuthority: gaugeAuthorityReport[\authority] ? 0.0,
                    musicalGaugeTransportScale: transportScale,
                    musicalGaugeBlockedUnanchored: gaugeAuthorityReport[\blockedUnanchored] ? false,
                    musicalGaugeBlockedSymmetric: gaugeAuthorityReport[\blockedSymmetric] ? false,
                    musicalGaugeAuthorityReport: gaugeAuthorityReport
                );
            };
            st[\lastMusicalGaugeAuthorityReport] = gaugeAuthorityReport;
            at[\updateCausalTransportState].(activePcs, externalSources, reason);
            offset
        }
    };

    at[\applyActivePhraseTransportOnset] = { |midi, pc, prevMidis=nil, prevCount=0, velocity=0.8|
        var enabled, now, last, window, interval, ratioInfo, intervalSupport, ecology, minFreedom, freeScale, denom;
        var support, strength, cents, rawOffset, applied, oldPending, oldPendingPcStep, oldPendingReport, lowerMidi, lowerAuthority, velWeight;
        var recent, closedPairFactor, prevPrev, prevInterval, ratioError, gaugeAuthorityReport, transportScale, activePcs;
        enabled = cfg[\solver][\activePhraseTransportEnabled] ? true;
        now = Main.elapsedTime;
        last = st[\lastActivePhraseOnset];
        window = cfg[\solver][\activePhraseTransportWindow] ? 0.85;
        if(enabled == false) {
            st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
            0.0
        } {
            if(last.isNil or: { (now - (last[\timestamp] ? now)) > window }) {
                st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
                st[\lastActivePhraseTransportReport] = (timestamp: now, appliedCents: 0.0, support: 0.0, intervalPressureCents: 0.0, reason: \noRecentInterval, transportScale: 1.0, blockedByGaugeAuthority: false, blockedBySymmetry: false, gaugeAuthority: 0.0);
                0.0
            } {
                interval = midi.asInteger - (last[\midi] ? midi).asInteger;
                if(interval == 0) {
                    st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi]));
                    0.0
                } {
                    ratioInfo = at[\activeIntervalRatioInfo].(interval);
                    ratioError = ratioInfo[\ratioErrorCents] ? 0.0;
                    intervalSupport = ratioInfo[\support] ? 0.0;
                    ecology = at[\transportEcologySnapshot].();
                    minFreedom = (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54).clip(0.0, 0.98);
                    denom = (1.0 - minFreedom).max(0.001);
                    freeScale = (((ecology[\freedom] ? 0.0) - minFreedom) / denom).clip(0.0, 1.0);
                    lowerMidi = midi.asInteger.min((last[\midi] ? midi).asInteger);
                    lowerAuthority = (1.0 + (((64 - lowerMidi).clip(-24, 36) / 72.0) * (cfg[\solver][\activePhraseLowerAuthority] ? 0.32))).clip(0.72, 1.22);
                    velWeight = velocity.clip(0.1, 1.0).sqrt;
                    closedPairFactor = 1.0;
                    recent = last[\previous];
                    if(recent.notNil) {
                        prevPrev = recent[\midi];
                        prevInterval = (last[\midi] ? midi).asInteger - (prevPrev ? (last[\midi] ? midi)).asInteger;
                        if((prevPrev.notNil) and: { midi.asInteger == prevPrev.asInteger and: { interval == (prevInterval * -1) } }) {
                            closedPairFactor = cfg[\solver][\activePhraseClosedPairTransport] ? 0.18;
                        };
                    };
                    activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
                    gaugeAuthorityReport = at[\musicalGaugeAuthorityReport].(\activePhrase, activePcs, at[\currentExternalSources].(), ratioInfo[\pcStep] ? 0);
                    transportScale = gaugeAuthorityReport[\transportScale] ? 1.0;
                    support = (intervalSupport * freeScale * (ecology[\carry] ? 0.0).sqrt * (ecology[\motion] ? 0.0).sqrt * closedPairFactor * transportScale).clip(0.0, 1.0);
                    strength = cfg[\solver][\activePhraseRatioTransportStrength] ? (cfg[\solver][\activePhraseTransportStrength] ? 0.24);
                    cents = ratioError * strength.clip(0.0, 1.5) * support * velWeight * lowerAuthority;
                    rawOffset = cents / 1200.0;
                    oldPending = st[\activePhraseTransportPendingSupport];
                    oldPendingPcStep = st[\activePhraseTransportPendingPcStep];
                    oldPendingReport = st[\activePhraseTransportPendingGaugeAuthorityReport];
                    st[\activePhraseTransportPendingSupport] = support;
                    st[\activePhraseTransportPendingPcStep] = ratioInfo[\pcStep] ? 0;
                    st[\activePhraseTransportPendingGaugeAuthorityReport] = gaugeAuthorityReport;
                    applied = if(rawOffset.abs > 0.0000000001) { at[\applyCoherentGaugeTransport].(rawOffset, \activePhrase, 1.0, 1.0, 1.0, cfg[\solver][\activePhraseTransportInertia] ? 0.0) } { 0.0 };
                    st[\activePhraseTransportPendingSupport] = oldPending;
                    st[\activePhraseTransportPendingPcStep] = oldPendingPcStep;
                    st[\activePhraseTransportPendingGaugeAuthorityReport] = oldPendingReport;
                    st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi]));
                    st[\lastMusicalGaugeAuthorityReport] = gaugeAuthorityReport;
                    st[\lastActivePhraseTransportReport] = (
                        timestamp: now,
                        interval: interval,
                        pcStep: ratioInfo[\pcStep] ? 0,
                        pureCents: ratioInfo[\pureCents] ? 0.0,
                        etCents: ratioInfo[\etCents] ? 0.0,
                        intervalPressureCents: ratioError,
                        intervalSupport: intervalSupport,
                        freedom: ecology[\freedom] ? 0.0,
                        freeScale: freeScale,
                        support: support,
                        closedPairFactor: closedPairFactor,
                        lowerAuthority: lowerAuthority,
                        requestedCents: cents,
                        appliedCents: applied * 1200.0,
                        fieldTrueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                        selectableSetting: false,
                        reason: \directedIntervalRatioPressure,
                        gaugeAuthority: gaugeAuthorityReport[\authority] ? 0.0,
                        gaugeAuthoritySources: gaugeAuthorityReport[\sources] ? Array.new,
                        transportScale: transportScale,
                        blockedByGaugeAuthority: gaugeAuthorityReport[\blockedUnanchored] ? false,
                        blockedBySymmetry: gaugeAuthorityReport[\blockedSymmetric] ? false,
                        musicalGaugeAuthorityReport: gaugeAuthorityReport
                    );
                    if((cfg[\solver][\activePhraseTransportReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
                        ("[at-transport-v30] interval-law interval=" ++ interval.asString ++ " pressure=" ++ ratioError.round(0.01).asString ++ "c authority=" ++ (gaugeAuthorityReport[\authority] ? 0.0).round(0.001).asString ++ " scale=" ++ transportScale.round(0.001).asString ++ " applied=" ++ (applied*1200.0).round(0.01).asString ++ "c").postln;
                    };
                    applied
                }
            }
        }
    };

    "[at-v30] musical gauge authority loaded: unanchored internal interval pressure cannot rotate trueGauge.".postln;
};
)
