(
// AT_living_active_field.scd
// v2d: live-authority Motion-gate runtime guard: target law remains active at Motion 0; nil authority reports fall back safely.
// v45: passive-world proof cleanup: released arpeggios move the silent harmonic field as well as gauge.
//
// v36 still treated interval pressure as local/phrase-current shape. v38 restores
// the core arpeggiated interval stream law: any non-octave interval stream
// transports the instrument; tritones are reduced/ambiguous. This is distinct
// from static chord/gauge authority and from local note wiggle. v38 separates:
//   - trueGauge: world location, still blocked by v30 without authority
//   - nodeShape: visible/rendered living field
//   - phraseCurrent: persistent phrase-local interval momentum
//
// Repeated directed arpeggios accumulate phrase current. Two-note back-and-forth
// loops are recognized and decay/settle instead of walking forever.
var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
    "[at-v36] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\solver].isNil) { cfg[\solver] = IdentityDictionary.new; };

    cfg[\solver][\livingActiveFieldEnabled] = cfg[\solver][\livingActiveFieldEnabled] ? true;
    cfg[\solver][\livingActiveFieldStrength] = cfg[\solver][\livingActiveFieldStrength] ? 0.94;
    cfg[\solver][\livingActiveFieldCentroidRemoval] = cfg[\solver][\livingActiveFieldCentroidRemoval] ? 1.0;
    cfg[\solver][\livingActiveFieldMinFreedom] = cfg[\solver][\livingActiveFieldMinFreedom] ? (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54);
    cfg[\solver][\livingActiveFieldReportEnabled] = cfg[\solver][\livingActiveFieldReportEnabled] ? true;
    cfg[\solver][\livingActiveVoiceChainEnabled] = cfg[\solver][\livingActiveVoiceChainEnabled] ? true;
    cfg[\solver][\livingActiveVoiceChainWindow] = cfg[\solver][\livingActiveVoiceChainWindow] ? 1.85;
    cfg[\solver][\livingActiveVoiceChainMaxNotes] = cfg[\solver][\livingActiveVoiceChainMaxNotes] ? 12;
    cfg[\solver][\livingActiveVoiceChainGain] = cfg[\solver][\livingActiveVoiceChainGain] ? 1.35;
    cfg[\solver][\livingActiveVoiceChainMaxStepCents] = cfg[\solver][\livingActiveVoiceChainMaxStepCents] ? 24.0;
    cfg[\solver][\livingActiveVoiceChainMinVisibleCents] = cfg[\solver][\livingActiveVoiceChainMinVisibleCents] ? 10.0;

    // v36 phrase-current settings. phraseCurrent is a span target in cents,
    // not a gauge offset. It is centered before being written to nodeShape.
    cfg[\solver][\livingPhraseCurrentEnabled] = cfg[\solver][\livingPhraseCurrentEnabled] ? true;
    cfg[\solver][\livingPhraseCurrentMaxSpanCents] = cfg[\solver][\livingPhraseCurrentMaxSpanCents] ? 84.0;
    cfg[\solver][\livingPhraseCurrentDecay] = cfg[\solver][\livingPhraseCurrentDecay] ? 0.965;
    cfg[\solver][\livingPhraseCurrentContraryDecay] = cfg[\solver][\livingPhraseCurrentContraryDecay] ? 0.42;
    cfg[\solver][\livingPhraseCurrentTwoNoteDecay] = cfg[\solver][\livingPhraseCurrentTwoNoteDecay] ? 0.62;
    cfg[\solver][\livingPhraseCurrentMinFramePcs] = cfg[\solver][\livingPhraseCurrentMinFramePcs] ? 3;
    cfg[\solver][\livingPhraseCurrentMaxFramePcs] = cfg[\solver][\livingPhraseCurrentMaxFramePcs] ? 8;

    // v39: first-class arpeggiated interval stream transport. This bypasses
    // the v30 *static/internal-gauge* block only for a live onset-to-onset
    // interval stream. Octaves are neutral. Tritones are reduced because they
    // are self-opposed/symmetric. All other intervals transport continuously
    // according to pure/simple-ratio cents - equal-tempered cents.
    cfg[\solver][\arpeggiatedIntervalStreamTransportEnabled] = cfg[\solver][\arpeggiatedIntervalStreamTransportEnabled] ? true;
    cfg[\solver][\arpeggiatedIntervalStreamTransportStrength] = cfg[\solver][\arpeggiatedIntervalStreamTransportStrength] ? 0.56;
    cfg[\solver][\arpeggiatedIntervalStreamMaxStepCents] = cfg[\solver][\arpeggiatedIntervalStreamMaxStepCents] ? 18.0;
    cfg[\solver][\arpeggiatedIntervalStreamTritoneScale] = cfg[\solver][\arpeggiatedIntervalStreamTritoneScale] ? 0.12;
    cfg[\solver][\arpeggiatedIntervalStreamMinFreedom] = cfg[\solver][\arpeggiatedIntervalStreamMinFreedom] ? (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54);
    cfg[\solver][\arpeggiatedIntervalStreamReportEnabled] = cfg[\solver][\arpeggiatedIntervalStreamReportEnabled] ? true;

    // v39: first-note harmonic-origin seeding. A single note is not "nothing";
    // it is the source that tunes the rest of the 12-note world around itself.
    // This is Motion, not Memory, Gravity, or Carry.
    cfg[\solver][\singleNoteHarmonicOriginEnabled] = cfg[\solver][\singleNoteHarmonicOriginEnabled] ? true;
    cfg[\solver][\singleNoteHarmonicOriginStrength] = cfg[\solver][\singleNoteHarmonicOriginStrength] ? 1.0;
    cfg[\solver][\singleNoteHarmonicOriginMinMotion] = cfg[\solver][\singleNoteHarmonicOriginMinMotion] ? 0.05;
    cfg[\solver][\singleNoteHarmonicOriginReportEnabled] = cfg[\solver][\singleNoteHarmonicOriginReportEnabled] ? true;

    // v40: passive/silent harmonic responder field. Active notes are evidence;
    // silent pitch classes are not evidence sources, but they must move as the
    // implied twelve-note harmony. This prevents the visual field from being
    // only active-note motion against an ET scaffold.
    cfg[\solver][\passiveHarmonicResponderEnabled] = cfg[\solver][\passiveHarmonicResponderEnabled] ? true;
    cfg[\solver][\passiveHarmonicResponderBlend] = cfg[\solver][\passiveHarmonicResponderBlend] ? 1.0;
    cfg[\solver][\passiveHarmonicResponderReportEnabled] = cfg[\solver][\passiveHarmonicResponderReportEnabled] ? true;

    // v44 demo rule: one note seeds the world idempotently; the same origin
    // confirms the existing world. A held two-note relationship is complete and
    // does not move active notes or transport the world. A released monophonic
    // arpeggio can move the harmonic world by interval pressure. Active-note
    // negotiation begins only with 3+ simultaneous active notes. Passive/silent
    // notes respond to evidence but never create pressure by themselves.
    cfg[\solver][\activeNegotiationMinActiveNotes] = cfg[\solver][\activeNegotiationMinActiveNotes] ? 3;
    cfg[\solver][\passiveResponderVelocityExponent] = cfg[\solver][\passiveResponderVelocityExponent] ? 0.65;
    cfg[\solver][\passiveResponderRegisterWeight] = cfg[\solver][\passiveResponderRegisterWeight] ? 0.36;

    // v45: arpeggiated interval-stream transport must not be proven only by gauge.
    // A released arpeggio is active evidence that moves/reprojects the silent
    // harmonic world. The current note is protected; recent phrase notes may
    // act as evidence, but silent responders never create pressure themselves.
    cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderEnabled] = cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderEnabled] ? true;
    cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderBlend] = cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderBlend] ? 1.0;

    at[\livingActiveEnsureField] = {
        var n;
        n = cfg[\solver][\numNodes] ? 12;
        if(at[\fieldEnsureState].notNil) { at[\fieldEnsureState].() };
        if(st[\nodeShapeCents].isNil or: { st[\nodeShapeCents].size != n }) { st[\nodeShapeCents] = Array.fill(n, 0.0); };
        if(st[\targetNodeShapeCents].isNil or: { st[\targetNodeShapeCents].size != n }) { st[\targetNodeShapeCents] = st[\nodeShapeCents].copy; };
        if(st[\nodeShapeVelocityCents].isNil or: { st[\nodeShapeVelocityCents].size != n }) { st[\nodeShapeVelocityCents] = Array.fill(n, 0.0); };
        if(st[\fieldTrueGaugeCents].isNil) { st[\fieldTrueGaugeCents] = 0.0; };
        if(st[\fieldGaugeCents].isNil) { st[\fieldGaugeCents] = st[\fieldTrueGaugeCents] ? 0.0; };
        nil
    };

    at[\livingActiveArrayIncludes] = { |arr, val|
        if(arr.isNil) { false } { arr.detectIndex { |x| x == val }.notNil }
    };

    at[\livingActiveFieldStats] = { |pcs=nil|
        var n, shape, list, vals, total, centroid, maxAbs, minVal, maxVal;
        n = cfg[\solver][\numNodes] ? 12;
        at[\livingActiveEnsureField].();
        shape = st[\nodeShapeCents] ? Array.fill(n, 0.0);
        list = pcs ? ((0..(n-1)));
        vals = list.collect { |pc| shape[pc.asInteger % n] ? 0.0 };
        total = vals.size.max(1);
        centroid = vals.sum / total;
        maxAbs = if(vals.isEmpty) { 0.0 } { vals.collect { |x| x.abs }.maxItem ? 0.0 };
        minVal = if(vals.isEmpty) { 0.0 } { vals.minItem ? 0.0 };
        maxVal = if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 };
        (centroidCents: centroid, maxAbsCents: maxAbs, minCents: minVal, maxCents: maxVal, spanCents: maxVal - minVal, pcs: list.copy)
    };

    at[\livingActiveVoiceChainPrune] = { |now=nil|
        var chain, window, maxNotes, start;
        now = now ? Main.elapsedTime;
        window = cfg[\solver][\livingActiveVoiceChainWindow] ? 1.85;
        maxNotes = (cfg[\solver][\livingActiveVoiceChainMaxNotes] ? 12).asInteger.max(2);
        chain = st[\livingActiveVoiceChain] ? Array.new;
        chain = chain.select { |ev| (now - (ev[\timestamp] ? now)) <= window };
        if(chain.size > maxNotes) {
            start = (chain.size - maxNotes).max(0);
            chain = chain.copyRange(start, chain.size - 1);
        };
        st[\livingActiveVoiceChain] = chain;
        chain
    };

    at[\livingActiveVoiceChainReset] = { |baseShape=nil|
        var n;
        n = cfg[\solver][\numNodes] ? 12;
        st[\livingActiveVoiceChain] = Array.new;
        st[\livingActiveVoiceChainBaseShapeCents] = (baseShape ? (st[\nodeShapeCents] ? Array.fill(n, 0.0))).copy;
        st[\livingPhraseCurrentCents] = 0.0;
        st[\livingPhraseCurrentSign] = 0;
        st[\livingPhraseFramePcs] = Array.new;
        st[\livingPhraseFrameKind] = nil;
        nil
    };

    at[\arpeggiatedIntervalStreamScale] = { |ratioInfo=nil|
        var pcStep, scale;
        pcStep = if(ratioInfo.isNil) { 0 } { (ratioInfo[\pcStep] ? 0).asInteger.abs % 12 };
        scale = 1.0;
        if(pcStep == 0) { scale = 0.0; }; // octave/unison identity: no transport
        if(pcStep == 6) { scale = cfg[\solver][\arpeggiatedIntervalStreamTritoneScale] ? 0.12; };
        scale.clip(0.0, 1.0)
    };

    at[\basicHarmonicOffsetCentsForStep] = { |pcStep=0|
        var table, step;
        // Root-relative simple-ratio offsets against 12-ET. This table is
        // anti-symmetric around the tritone, so a single note establishes a
        // coherent harmonic world without inventing gauge rotation.
        table = [
            0.0,      // unison/octave
            11.731,   // 16/15 minor second
            3.910,    // 9/8 major second
            15.641,   // 6/5 minor third
            -13.686,  // 5/4 major third
            -1.955,   // 4/3 fourth
            0.0,      // tritone equilibrium / self-opposed
            1.955,    // 3/2 fifth
            13.686,   // 8/5 minor sixth
            -15.641,  // 5/3 major sixth
            -3.910,   // 16/9 minor seventh
            -11.731   // 15/8 major seventh
        ];
        step = pcStep.asInteger % 12;
        table[step]
    };

    at[\basicHarmonicOriginShapeCents] = { |rootPc=0|
        var n, r;
        n = cfg[\solver][\numNodes] ? 12;
        r = rootPc.asInteger % n;
        Array.fill(n, { |pc| at[\basicHarmonicOffsetCentsForStep].((pc.asInteger - r) % n) })
    };

    at[\passiveHarmonicResponderTarget] = { |baseShape=nil, activeTargetShape=nil, sourcePcs=nil, protectPcs=nil, blend=1.0|
        var n, enabled, sources, protect, out, pc, sourcePc, sourceVal, prediction, sum, totalWeight, weight, activeNotes, sourceWeights, maxSourceWeight, registerWeight, velWeight;
        var beforeShape, afterShape, silentPcs, silentMoveMax, activeMoveMax, baseVal, targetVal, b;
        n = cfg[\solver][\numNodes] ? 12;
        enabled = cfg[\solver][\passiveHarmonicResponderEnabled] ? true;
        b = blend.clip(0.0, 1.0);
        beforeShape = baseShape ? Array.fill(n, 0.0);
        afterShape = activeTargetShape ? beforeShape.copy;
        if(beforeShape.size != n) { beforeShape = Array.fill(n, 0.0); };
        if(afterShape.size != n) { afterShape = beforeShape.copy; };
        if(enabled.not) {
            afterShape.copy
        } {
            sources = (sourcePcs ? Array.new).collect { |x| x.asInteger % n }.as(Set).asArray.sort;
            protect = (protectPcs ? Array.new).collect { |x| x.asInteger % n }.as(Set).asArray.sort;
            sourceWeights = IdentityDictionary.new;
            activeNotes = if(st[\activeNotes].notNil) { st[\activeNotes].values.asArray } { Array.new };
            activeNotes.do { |note|
                var spc, midiVal, velVal, w;
                midiVal = note[\midi] ? 60;
                spc = (note[\pc] ? (midiVal.asInteger % n)).asInteger % n;
                velVal = (note[\velocity] ? 0.75).asFloat.clip(0.05, 1.0);
                velWeight = velVal ** (cfg[\solver][\passiveResponderVelocityExponent] ? 0.65);
                registerWeight = (1.0 + (((64 - midiVal.asInteger).clip(-24, 36) / 72.0) * (cfg[\solver][\passiveResponderRegisterWeight] ? 0.36))).clip(0.65, 1.35);
                w = (velWeight * registerWeight).clip(0.05, 2.0);
                sourceWeights[spc] = (sourceWeights[spc] ? 0.0) + w;
            };
            maxSourceWeight = 0.0;
            sources.do { |spc| maxSourceWeight = maxSourceWeight.max(sourceWeights[spc] ? 1.0) };
            if(sources.isEmpty) {
                afterShape.copy
            } {
                out = afterShape.copy;
                (0..(n-1)).do { |pc|
                    if(at[\livingActiveArrayIncludes].(protect, pc)) {
                        // Active/current evidence notes keep their explicitly computed positions.
                    } {
                        sum = 0.0;
                        totalWeight = 0.0;
                        sources.do { |sourcePc|
                            sourceVal = afterShape[sourcePc] ? (beforeShape[sourcePc] ? 0.0);
                            prediction = sourceVal + at[\basicHarmonicOffsetCentsForStep].((pc - sourcePc) % n);
                            // Silent responders weight active evidence by register and velocity,
                            // but silent notes never become evidence sources by themselves.
                            weight = (sourceWeights[sourcePc] ? 1.0).clip(0.05, 2.0);
                            sum = sum + (prediction * weight);
                            totalWeight = totalWeight + weight;
                        };
                        targetVal = if(totalWeight <= 0.0) { afterShape[pc] ? 0.0 } { sum / totalWeight };
                        baseVal = afterShape[pc] ? (beforeShape[pc] ? 0.0);
                        out[pc] = (baseVal * (1.0 - b)) + (targetVal * b);
                    };
                };
                silentPcs = (0..(n-1)).reject { |pc| at[\livingActiveArrayIncludes].(protect, pc) };
                silentMoveMax = if(silentPcs.isEmpty) { 0.0 } { silentPcs.collect { |spc| ((out[spc] ? 0.0) - (beforeShape[spc] ? 0.0)).abs }.maxItem ? 0.0 };
                activeMoveMax = if(protect.isEmpty) { 0.0 } { protect.collect { |apc| ((out[apc] ? 0.0) - (beforeShape[apc] ? 0.0)).abs }.maxItem ? 0.0 };
                st[\lastPassiveHarmonicResponderReport] = (
                    timestamp: Main.elapsedTime, status: \passiveHarmonicResponderApplied,
                    sources: sources.copy, protectedActivePcs: protect.copy, silentPcs: silentPcs.copy,
                    silentMoveMaxCents: silentMoveMax, activeMoveMaxCents: activeMoveMax,
                    blend: b, writesTrueGauge: false,
                    rule: \activeNotesInfluenceSilentNotesRespondWeightedByRegisterVelocity, sourceWeights: sourceWeights.copy
                );
                out
            }
        }
    };

    api[\passiveHarmonicResponderReport] = { st[\lastPassiveHarmonicResponderReport] };

    at[\basicHarmonicOriginReport] = { st[\basicHarmonicOriginReport] };

    at[\basicHarmonicOriginSeedWorld] = { |midi=60, pc=0, velocity=0.8, reason=\singleNoteHarmonicOrigin|
        var now, enabled, n, motion, memory, gravity, mic, minMotion, strength, scale, rootPc;
        var targetShape, beforeShape, deltaArr, maxDelta, gauge, lastPc, lastShape, sameOrigin, restoreShape;
        now = Main.elapsedTime;
        enabled = cfg[\solver][\singleNoteHarmonicOriginEnabled] ? true;
        n = cfg[\solver][\numNodes] ? 12;
        rootPc = pc.asInteger % n;
        motion = (st[\movement] ? 0.0).clip(0.0, 1.0);
        memory = (st[\memoryAmount] ? (cfg[\perf][\memoryContinuityMacro] ? 0.0)).clip(0.0, 1.0);
        gravity = if(cfg[\gravity].isNil) { 0.0 } { if(cfg[\gravity][\enabled] ? false) { (cfg[\gravity][\strength] ? 0.0).clip(0.0, 1.0) } { 0.0 } };
        mic = if(cfg[\mic][\enabled] ? false) { ((cfg[\mic][\weight] ? 0.0) / 1.2).clip(0.0, 1.0) } { 0.0 };
        minMotion = (cfg[\solver][\singleNoteHarmonicOriginMinMotion] ? 0.05).clip(0.0, 1.0);
        strength = (cfg[\solver][\singleNoteHarmonicOriginStrength] ? 1.0).clip(0.0, 1.5);
        if(enabled.not) {
            st[\basicHarmonicOriginReport] = (timestamp: now, status: \disabled, motion: motion, applied: false);
            0.0
        } {
            at[\livingActiveEnsureField].();
            beforeShape = (st[\nodeShapeCents] ? Array.fill(n, 0.0)).copy;
            // Memory/gravity/ear resist origin reseeding; in the demo they are all off,
            // so the first note establishes the full naked harmonic world. The same
            // origin is idempotent: it confirms the world, not another deformation.
            scale = (strength * (1.0 - memory).clip(0.0, 1.0).sqrt * (1.0 - gravity).clip(0.0, 1.0).sqrt * (1.0 - mic).clip(0.0, 1.0).sqrt).clip(0.0, 1.5);
            targetShape = at[\basicHarmonicOriginShapeCents].(rootPc).collect { |x| x * scale };
            lastPc = st[\lastHarmonicOriginPc];
            lastShape = st[\lastHarmonicOriginShapeCents];
            sameOrigin = lastPc.notNil and: { lastPc.asInteger == rootPc };
            restoreShape = if(sameOrigin and: { lastShape.notNil and: { lastShape.size == n } }) { lastShape.copy } { targetShape.copy };
            st[\nodeShapeCents] = restoreShape.copy;
            st[\targetNodeShapeCents] = restoreShape.copy;
            gauge = st[\fieldTrueGaugeCents] ? 0.0;
            st[\fieldTrueGaugeCents] = gauge;
            st[\fieldGaugeCents] = gauge;
            if(sameOrigin) {
                st[\nodeShapeVelocityCents] = Array.fill(n, 0.0);
                maxDelta = 0.0;
            } {
                st[\nodeShapeVelocityCents] = Array.fill(n, { |i| (restoreShape[i] ? 0.0) - (beforeShape[i] ? 0.0) });
                deltaArr = Array.fill(n, { |i| ((restoreShape[i] ? 0.0) - (beforeShape[i] ? 0.0)).abs });
                maxDelta = if(deltaArr.isEmpty) { 0.0 } { deltaArr.maxItem ? 0.0 };
                st[\lastHarmonicOriginPc] = rootPc;
                st[\lastHarmonicOriginShapeCents] = restoreShape.copy;
                st[\lastHarmonicOriginScale] = scale;
            };
            if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].() };
            st[\uiSnapshotCache] = nil;
            st[\fieldDirty] = false;
            st[\fieldDirtyReason] = \singleNoteHarmonicOriginStable;
            // Keep release/return behavior coherent: the harmonic-origin world is the
            // world that should be held after release.
            st[\frozenShapeCents] = restoreShape.copy;
            st[\frozenGaugeCents] = gauge;
            st[\frozenPhase] = st[\nodePhase].copy;
            st[\frozenValid] = true;
            st[\basicHarmonicOriginReport] = (
                timestamp: now, status: if(sameOrigin) { \singleNoteHarmonicOriginConfirmed } { \singleNoteHarmonicOriginSeeded },
                midi: midi.asInteger, pc: rootPc, reason: reason,
                motion: motion, memory: memory, gravity: gravity, micAuthority: mic,
                strength: strength, scale: scale, maxDeltaCents: maxDelta,
                shapeCents: restoreShape.copy, trueGaugeCents: gauge,
                carryUsed: false, writesTrueGauge: false,
                idempotentSameOrigin: sameOrigin,
                description: if(sameOrigin) { \sameOriginConfirmsExistingWorld } { \firstNoteTunesTheTwelveNoteWorldAroundIt }
            );
            if((cfg[\solver][\singleNoteHarmonicOriginReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
                ("[at-v45] single-note harmonic origin midi=" ++ midi.asString ++ " pc=" ++ rootPc.asString ++ " status=" ++ (st[\basicHarmonicOriginReport][\status]).asString ++ " maxDelta=" ++ maxDelta.round(0.01).asString ++ "c").postln;
            };
            maxDelta
        }
    };

    at[\applyArpeggiatedIntervalStreamTransport] = { |midi, pc, last, ratioInfo=nil, ecology=nil, velocity=0.8, lowerAuthority=1.0|
        var now, enabled, ratioError, intervalSupport, pcStep, streamScale, motion, carry, freedom, minFreedom, denom, freeScale;
        var velWeight, strength, support, requestedCents, maxStep, appliedCents, oldGauge, oldVelocity, offset;
        var n, beforeShape, targetShape, passiveSources, passiveProtect, passiveReport, passiveEnabled, passiveBlend;
        now = Main.elapsedTime;
        enabled = cfg[\solver][\arpeggiatedIntervalStreamTransportEnabled] ? true;
        if(enabled == false or: { ratioInfo.isNil }) {
            st[\lastArpeggiatedIntervalStreamTransportReport] = (timestamp: now, status: \disabledOrNoInterval, appliedCents: 0.0);
            0.0
        } {
            ratioError = ratioInfo[\ratioErrorCents] ? 0.0;
            intervalSupport = ratioInfo[\support] ? 0.0;
            pcStep = (ratioInfo[\pcStep] ? 0).asInteger.abs % 12;
            streamScale = at[\arpeggiatedIntervalStreamScale].(ratioInfo);
            motion = if(ecology.isNil) { st[\movement] ? 0.0 } { ecology[\motion] ? (st[\movement] ? 0.0) };
            carry = if(ecology.isNil) { st[\carryAmount] ? 0.0 } { ecology[\carry] ? (st[\carryAmount] ? 0.0) };
            freedom = if(ecology.isNil) { 0.0 } { ecology[\freedom] ? 0.0 };
            minFreedom = (cfg[\solver][\arpeggiatedIntervalStreamMinFreedom] ? (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54)).clip(0.0, 0.98);
            denom = (1.0 - minFreedom).max(0.001);
            freeScale = ((freedom - minFreedom) / denom).clip(0.0, 1.0);
            velWeight = velocity.clip(0.1, 1.0).sqrt;
            strength = cfg[\solver][\arpeggiatedIntervalStreamTransportStrength] ? 0.56;
            support = (intervalSupport * freeScale * velWeight * lowerAuthority * streamScale).clip(0.0, 1.5);
            requestedCents = ratioError * strength.clip(0.0, 2.0) * support;
            maxStep = (cfg[\solver][\arpeggiatedIntervalStreamMaxStepCents] ? 18.0).max(0.0);
            appliedCents = requestedCents.clip(maxStep.neg, maxStep);
            if(appliedCents.abs <= 0.000001) {
                st[\lastArpeggiatedIntervalStreamTransportReport] = (
                    timestamp: now, status: if(pcStep == 0) { \octaveNeutralNoTransport } { if(pcStep == 6) { \tritoneReducedOrNeutral } { \zeroSupportNoTransport } },
                    interval: ratioInfo[\interval], pcStep: pcStep, intervalPressureCents: ratioError,
                    requestedCents: requestedCents, appliedCents: 0.0, support: support, streamScale: streamScale,
                    motion: motion, carry: carry, carryUsed: false, freedom: freedom, writesTrueGauge: false
                );
                0.0
            } {
                at[\livingActiveEnsureField].();
                oldGauge = st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0);
                oldVelocity = st[\fieldTrueGaugeVelocityCents] ? 0.0;
                st[\fieldTrueGaugeCents] = oldGauge + appliedCents;
                st[\fieldGaugeCents] = st[\fieldTrueGaugeCents];
                st[\fieldTrueGaugeVelocityCents] = appliedCents;
                st[\fieldGaugeVelocity] = appliedCents / 1200.0;
                st[\fieldGaugeLastOffset] = appliedCents / 1200.0;
                st[\fieldGaugeLastTime] = now;
                if(at[\fieldComposeFromShapeGauge].notNil) {
                    at[\fieldComposeFromShapeGauge].();
                } {
                    offset = appliedCents / 1200.0;
                    if(st[\nodePhase].notNil) { st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + offset) }; };
                };

                // v45: a released arpeggio moving the instrument must also move
                // the passive/silent harmonic field. Gauge is transport, not the
                // whole proof of harmony. The active current note is protected;
                // the recent previous note may be used as phrase evidence.
                passiveReport = nil;
                passiveEnabled = cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderEnabled] ? true;
                if(passiveEnabled and: { at[\passiveHarmonicResponderTarget].notNil }) {
                    n = cfg[\solver][\numNodes] ? 12;
                    beforeShape = (st[\nodeShapeCents] ? Array.fill(n, 0.0)).copy;
                    targetShape = beforeShape.copy;
                    passiveSources = [pc.asInteger % n];
                    if(last.notNil) {
                        passiveSources = passiveSources.add(((last[\pc] ? ((last[\midi] ? midi).asInteger % n)).asInteger % n));
                    };
                    passiveSources = passiveSources.as(Set).asArray.sort;
                    passiveProtect = [pc.asInteger % n];
                    passiveBlend = (cfg[\solver][\arpeggiatedIntervalStreamPassiveResponderBlend] ? (cfg[\solver][\passiveHarmonicResponderBlend] ? 1.0)).clip(0.0, 1.0);
                    targetShape = at[\passiveHarmonicResponderTarget].(beforeShape, targetShape, passiveSources, passiveProtect, passiveBlend);
                    st[\nodeShapeCents] = targetShape.copy;
                    st[\targetNodeShapeCents] = targetShape.copy;
                    st[\nodeShapeVelocityCents] = Array.fill(n, { |i| (targetShape[i] ? 0.0) - (beforeShape[i] ? 0.0) });
                    if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].(); };
                    passiveReport = st[\lastPassiveHarmonicResponderReport];
                };
                st[\uiSnapshotCache] = nil;
                st[\fieldDirty] = true;
                st[\lastArpeggiatedIntervalStreamTransportReport] = (
                    timestamp: now, status: \arpeggiatedIntervalStreamTransportApplied,
                    interval: ratioInfo[\interval], pcStep: pcStep,
                    intervalPressureCents: ratioError, pureCents: ratioInfo[\pureCents], etCents: ratioInfo[\etCents],
                    requestedCents: requestedCents, appliedCents: appliedCents, support: support, streamScale: streamScale,
                    oldGaugeCents: oldGauge, newGaugeCents: st[\fieldTrueGaugeCents], oldVelocityCents: oldVelocity,
                    passiveHarmonicResponderReport: passiveReport,
                    passiveSilentMoveMaxCents: if(passiveReport.isNil) { 0.0 } { passiveReport[\silentMoveMaxCents] ? 0.0 },
                    passiveStatus: if(passiveReport.isNil) { \none } { passiveReport[\status] ? \none },
                    motion: motion, carry: carry, carryUsed: false, freedom: freedom, lowerAuthority: lowerAuthority, velocity: velocity,
                    octaveNeutral: pcStep == 0, tritoneReduced: pcStep == 6,
                    writesTrueGauge: true, reason: \arpeggiatedIntervalStream,
                    description: \nonOctaveArpeggiatedIntervalsTransportTheInstrument
                );
                if((cfg[\solver][\arpeggiatedIntervalStreamReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
                    ("[at-v38] arpeggio interval-stream interval=" ++ (ratioInfo[\interval]).asString ++ " pressure=" ++ ratioError.round(0.01).asString ++ "c applied=" ++ appliedCents.round(0.01).asString ++ "c gauge=" ++ (st[\fieldTrueGaugeCents] ? 0.0).round(0.01).asString).postln;
                };
                appliedCents
            }
        }
    };

    at[\livingActiveApplyVoiceChainShape] = { |midi, pc, last, ratioInfo=nil, ecology=nil, localSupport=0.0|
        var now, n, enabled, result, report, currentShape, baseShape, chain, resetNeeded, lastEvent;
        var prevMidi, prevPc, intervalSupport, ratioError, motion, carry, freedom, minFreedom, denom, freeScale;
        var voiceSupport, gain, maxStep, stepCents, maxNotes, touched, offsets, beforeShape, beforeStats, afterStats;
        var targetShape, deltaArr, oldGauge, maxAbs, minVal, maxVal, span, chainKind, monotonicDirection;
        var frame, maxFrame, minFrame, frameKind, oldKind, oldCurrent, current, currentSign, stepSign, phraseEligible;
        var twoNoteBackForth, prevPrev, prevInterval, recent, decay, maxSpan, center, norm, m, idx, frameChanged, framePcsForReport;
        now = Main.elapsedTime;
        n = cfg[\solver][\numNodes] ? 12;
        enabled = (cfg[\solver][\livingActiveFieldEnabled] ? true) and: { cfg[\solver][\livingActiveVoiceChainEnabled] ? true };
        result = 0.0;

        if(enabled == false or: { last.isNil }) {
            st[\lastLivingActiveFieldReport] = (timestamp: now, status: \disabledOrNoRecent, appliedCents: 0.0, localSupport: localSupport);
            result = 0.0;
        } {
            at[\livingActiveEnsureField].();
            pc = pc.asInteger % n;
            prevMidi = last[\midi];
            prevPc = (last[\pc] ? if(prevMidi.isNil) { pc } { prevMidi.asInteger % n }).asInteger % n;
            currentShape = (st[\nodeShapeCents] ? Array.fill(n, 0.0)).copy;

            motion = if(ecology.isNil) { st[\movement] ? 0.0 } { ecology[\motion] ? (st[\movement] ? 0.0) };
            carry = if(ecology.isNil) { st[\carryAmount] ? 0.0 } { ecology[\carry] ? (st[\carryAmount] ? 0.0) };
            freedom = if(ecology.isNil) { 0.0 } { ecology[\freedom] ? 0.0 };
            minFreedom = (cfg[\solver][\livingActiveFieldMinFreedom] ? (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54)).clip(0.0, 0.98);
            denom = (1.0 - minFreedom).max(0.001);
            freeScale = ((freedom - minFreedom) / denom).clip(0.0, 1.0);
            intervalSupport = if(ratioInfo.isNil) { localSupport } { ratioInfo[\support] ? localSupport };
            ratioError = if(ratioInfo.isNil) { 0.0 } { ratioInfo[\ratioErrorCents] ? 0.0 };
            voiceSupport = (intervalSupport * freeScale).clip(0.0, 1.0);
            gain = cfg[\solver][\livingActiveVoiceChainGain] ? 1.35;
            maxStep = (cfg[\solver][\livingActiveVoiceChainMaxStepCents] ? 24.0).max(1.0);
            stepCents = (ratioError * voiceSupport * gain).clip(maxStep.neg, maxStep);

            if((pc == prevPc) or: { stepCents.abs <= 0.000001 or: { voiceSupport <= 0.000001 } }) {
                st[\lastLivingActiveFieldReport] = (
                    timestamp: now, status: if(pc == prevPc) { \samePcNoPhraseCurrent } { \zeroSupportNoPhraseCurrent },
                    appliedCents: 0.0, stepCents: stepCents, voiceSupport: voiceSupport,
                    localSupport: localSupport, pc: pc, prevPc: prevPc, motion: motion, carry: carry, carryUsed: false, freedom: freedom,
                    intervalPressureCents: ratioError
                );
                result = 0.0;
            } {
                chain = at[\livingActiveVoiceChainPrune].(now);
                resetNeeded = chain.isEmpty;
                if(chain.notEmpty) {
                    lastEvent = chain[chain.size - 1];
                    if((lastEvent[\midi] ? prevMidi).asInteger != prevMidi.asInteger) { resetNeeded = true; };
                };
                if(resetNeeded) {
                    baseShape = currentShape.copy;
                    chain = Array.new;
                    chain = chain.add((midi: prevMidi, pc: prevPc, timestamp: last[\timestamp] ? now, cumulativeCents: 0.0, stepCents: 0.0, seed: true));
                    st[\livingActiveVoiceChainBaseShapeCents] = baseShape.copy;
                    st[\livingPhraseCurrentCents] = 0.0;
                    st[\livingPhraseCurrentSign] = 0;
                    st[\livingPhraseFramePcs] = [prevPc];
                    st[\livingPhraseFrameKind] = nil;
                } {
                    baseShape = st[\livingActiveVoiceChainBaseShapeCents] ? currentShape.copy;
                    if(baseShape.size != n) { baseShape = currentShape.copy; };
                };

                chain = chain.add((
                    midi: midi, pc: pc, timestamp: now,
                    interval: if(ratioInfo.isNil) { nil } { ratioInfo[\interval] },
                    pcStep: if(ratioInfo.isNil) { nil } { ratioInfo[\pcStep] },
                    ratioErrorCents: ratioError, stepCents: stepCents,
                    voiceSupport: voiceSupport
                ));
                maxNotes = (cfg[\solver][\livingActiveVoiceChainMaxNotes] ? 12).asInteger.max(2);
                if(chain.size > maxNotes) { chain = chain.copyRange(chain.size - maxNotes, chain.size - 1); };
                st[\livingActiveVoiceChain] = chain;

                chainKind = if((ratioInfo.notNil) and: { (ratioInfo[\pcStep] ? 0) == 3 }) { \minorThirdChain } {
                    if((ratioInfo.notNil) and: { (ratioInfo[\pcStep] ? 0) == 4 }) { \majorThirdChain } {
                        if((ratioInfo.notNil) and: { (ratioInfo[\pcStep] ? 0) == 2 }) { \wholeToneChain } { \intervalChain }
                    }
                };
                stepSign = stepCents.sign.asInteger;
                monotonicDirection = if(stepSign > 0) { \ascendingPressure } { if(stepSign < 0) { \descendingPressure } { \neutralPressure } };

                frame = st[\livingPhraseFramePcs] ? Array.new;
                if(frame.isEmpty) { frame = [prevPc] };
                if(at[\livingActiveArrayIncludes].(frame, pc) == false) { frame = frame.add(pc) };
                maxFrame = (cfg[\solver][\livingPhraseCurrentMaxFramePcs] ? 8).asInteger.max(3).min(n);
                if(frame.size > maxFrame) { frame = frame.copyRange(frame.size - maxFrame, frame.size - 1) };
                minFrame = (cfg[\solver][\livingPhraseCurrentMinFramePcs] ? 3).asInteger.max(3);
                oldKind = st[\livingPhraseFrameKind];
                frameChanged = (oldKind.notNil and: { oldKind != chainKind });
                if(frameChanged) {
                    frame = [prevPc, pc];
                    st[\livingPhraseCurrentCents] = 0.0;
                    st[\livingPhraseCurrentSign] = 0;
                };
                st[\livingPhraseFrameKind] = chainKind;
                st[\livingPhraseFramePcs] = frame.copy;
                framePcsForReport = frame.copy;

                recent = last[\previous];
                twoNoteBackForth = false;
                if(recent.notNil) {
                    prevPrev = recent[\midi];
                    prevInterval = (last[\midi] ? midi).asInteger - (prevPrev ? (last[\midi] ? midi)).asInteger;
                    if((prevPrev.notNil) and: { midi.asInteger == prevPrev.asInteger and: { (ratioInfo[\interval] ? 0) == (prevInterval * -1) } }) {
                        twoNoteBackForth = true;
                    };
                };

                phraseEligible = (cfg[\solver][\livingPhraseCurrentEnabled] ? true) and: { frame.size >= minFrame and: { twoNoteBackForth == false } };
                oldCurrent = st[\livingPhraseCurrentCents] ? 0.0;
                currentSign = st[\livingPhraseCurrentSign] ? 0;
                maxSpan = (cfg[\solver][\livingPhraseCurrentMaxSpanCents] ? 84.0).max(6.0);
                if(phraseEligible) {
                    if((currentSign != 0) and: { stepSign != 0 and: { currentSign != stepSign } }) {
                        oldCurrent = oldCurrent * (cfg[\solver][\livingPhraseCurrentContraryDecay] ? 0.42);
                    };
                    decay = cfg[\solver][\livingPhraseCurrentDecay] ? 0.965;
                    current = ((oldCurrent * decay) + stepCents).clip(maxSpan.neg, maxSpan);
                    st[\livingPhraseCurrentCents] = current;
                    st[\livingPhraseCurrentSign] = if(current.abs > 0.0001) { current.sign.asInteger } { 0 };
                } {
                    current = (oldCurrent * (cfg[\solver][\livingPhraseCurrentTwoNoteDecay] ? 0.62)).clip(maxSpan.neg, maxSpan);
                    st[\livingPhraseCurrentCents] = current;
                    if(current.abs <= 0.0001) { st[\livingPhraseCurrentSign] = 0 };
                };

                offsets = Array.fill(n, 0.0);
                touched = frame.copy;
                if(phraseEligible) {
                    m = frame.size.max(1);
                    center = (m - 1) / 2.0;
                    frame.do { |tpc, i|
                        norm = if(m <= 1) { 0.0 } { (i - center) / (m - 1) };
                        offsets[tpc.asInteger % n] = norm * current;
                    };
                } {
                    // First two notes get an interval relationship, but no walking current.
                    offsets[prevPc] = stepCents * -0.5;
                    offsets[pc] = stepCents * 0.5;
                    touched = [prevPc, pc].as(Set).asArray.sort;
                };

                // Exact centroid removal over touched notes only. This prevents ET-wheel rotation
                // while preserving the phrase-current gradient.
                if(touched.notEmpty) {
                    var mean;
                    mean = touched.collect { |tpc| offsets[tpc.asInteger % n] ? 0.0 }.sum / touched.size.max(1);
                    touched.do { |tpc| offsets[tpc.asInteger % n] = (offsets[tpc.asInteger % n] ? 0.0) - mean };
                };

                beforeShape = currentShape.copy;
                beforeStats = at[\livingActiveFieldStats].(touched);
                targetShape = baseShape.copy;
                touched.do { |tpc| targetShape[tpc.asInteger % n] = (baseShape[tpc.asInteger % n] ? 0.0) + (offsets[tpc.asInteger % n] ? 0.0); };
                // v40: active notes are evidence; silent notes are the responding harmony.
                // Do not leave untouched pitch classes as an ET/passive scaffold.
                if(at[\passiveHarmonicResponderTarget].notNil) {
                    targetShape = at[\passiveHarmonicResponderTarget].(
                        baseShape,
                        targetShape,
                        touched,
                        touched,
                        cfg[\solver][\passiveHarmonicResponderBlend] ? 1.0
                    );
                };
                deltaArr = Array.fill(n, { |i| (targetShape[i] ? 0.0) - (beforeShape[i] ? 0.0) });
                oldGauge = st[\fieldTrueGaugeCents] ? 0.0;
                st[\nodeShapeCents] = targetShape.copy;
                st[\targetNodeShapeCents] = targetShape.copy;
                st[\nodeShapeVelocityCents] = deltaArr.copy;
                st[\fieldTrueGaugeCents] = oldGauge;
                st[\fieldGaugeCents] = oldGauge;
                if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].() };
                st[\lastDelta] = deltaArr.collect { |x| x / 1200.0 };
                st[\nodeMotion] = st[\lastDelta].collect { |x| (x.abs / (cfg[\solver][\maxStep] ? 0.01)).clip(0.0, 1.0) };
                if(st[\nodeAlignment].isNil or: { st[\nodeAlignment].size != n }) { st[\nodeAlignment] = Array.fill(n, 1.0); };
                st[\nodeStability] = Array.fill(n, { |i| ((st[\nodeAlignment][i] ? 1.0) * (1.0 - (st[\nodeMotion][i] ? 0.0))).clip(0.0, 1.0) });
                st[\uiSnapshotCache] = nil;
                st[\fieldDirty] = true;

                afterStats = at[\livingActiveFieldStats].(touched);
                maxAbs = 0.0; minVal = 0.0; maxVal = 0.0;
                touched.do { |tpc|
                    var val;
                    val = offsets[tpc.asInteger % n] ? 0.0;
                    maxAbs = maxAbs.max(val.abs);
                    minVal = minVal.min(val);
                    maxVal = maxVal.max(val);
                };
                span = maxVal - minVal;
                report = (
                    timestamp: now,
                    status: if(phraseEligible) { \phraseCurrentTransportApplied } { \pairRelationshipOnlyNoWalkingCurrent },
                    chainKind: chainKind, monotonicDirection: monotonicDirection,
                    phraseEligible: phraseEligible, twoNoteBackForth: twoNoteBackForth,
                    pc: pc, prevPc: prevPc, midi: midi, prevMidi: prevMidi,
                    interval: if(ratioInfo.isNil) { nil } { ratioInfo[\interval] },
                    pcStep: if(ratioInfo.isNil) { nil } { ratioInfo[\pcStep] },
                    intervalPressureCents: ratioError, stepCents: stepCents,
                    phraseCurrentCents: current,
                    appliedCents: maxAbs, spanCents: span,
                    localSupport: localSupport, voiceSupport: voiceSupport, freedom: freedom, motion: motion, carry: carry, carryUsed: false,
                    activePcs: touched.copy, framePcs: framePcsForReport.copy, chainSize: chain.size, chain: chain.copy,
                    offsetsCents: offsets.copy, passiveHarmonicResponderReport: st[\lastPassiveHarmonicResponderReport],
                    silentFieldResponds: true, trueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                    beforeCentroidCents: beforeStats[\centroidCents] ? 0.0,
                    afterCentroidCents: afterStats[\centroidCents] ? 0.0,
                    beforeMaxAbsCents: beforeStats[\maxAbsCents] ? 0.0,
                    afterMaxAbsCents: afterStats[\maxAbsCents] ? 0.0,
                    maxDeltaCents: if(deltaArr.isEmpty) { 0.0 } { deltaArr.collect { |x| x.abs }.maxItem ? 0.0 },
                    writesTrueGauge: false,
                    authoritativeLayer: \nodeShapeCents,
                    movingObject: \phraseCurrentLivingFieldNotEtWheel,
                    wiggleNoTransport: false
                );
                st[\lastLivingActiveFieldReport] = report;
                if((cfg[\solver][\livingActiveFieldReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
                    ("[at-v38] phrase-current/local " ++ chainKind.asString ++ " pc=" ++ prevPc.asString ++ "->" ++ pc.asString ++ " pressure=" ++ ratioError.round(0.01).asString ++ "c step=" ++ stepCents.round(0.01).asString ++ "c current=" ++ current.round(0.01).asString ++ "c span=" ++ span.round(0.01).asString ++ "c").postln;
                };
                result = maxAbs;
            };
        };
        result
    };

    at[\livingActiveApplyIntervalShapeKick] = { |midi, pc, last, requestedCents=0.0, localSupport=0.0, ratioInfo=nil, ecology=nil|
        at[\livingActiveApplyVoiceChainShape].(midi, pc, last, ratioInfo, ecology, localSupport)
    };

    // Override active phrase transport so internal pressure feeds phrase-current even when v30 blocks trueGauge.
    at[\applyActivePhraseTransportOnset] = { |midi, pc, prevMidis=nil, prevCount=0, velocity=0.8|
        var enabled, now, last, window, interval, ratioInfo, intervalSupport, ecology, minFreedom, freeScale, denom;
        var localSupport, gaugeSupport, strength, cents, rawOffset, applied, streamApplied, oldPending, oldPendingPcStep, oldPendingReport, lowerMidi, lowerAuthority, velWeight;
        var recent, closedPairFactor, prevPrev, prevInterval, ratioError, gaugeAuthorityReport, transportScale, activePcs, localApplied;
        enabled = cfg[\solver][\activePhraseTransportEnabled] ? true;
        now = Main.elapsedTime;
        last = st[\lastActivePhraseOnset];
        window = cfg[\solver][\activePhraseTransportWindow] ? 0.85;
        localApplied = 0.0;
        if(enabled == false) {
            st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
            0.0
        } {
            if(last.isNil or: { (now - (last[\timestamp] ? now)) > window }) {
                st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
                st[\lastActivePhraseTransportReport] = (timestamp: now, appliedCents: 0.0, localAppliedCents: 0.0, support: 0.0, localSupport: 0.0, intervalPressureCents: 0.0, reason: \noRecentInterval, transportScale: 1.0, blockedByGaugeAuthority: false, blockedBySymmetry: false, gaugeAuthority: 0.0);
                0.0
            } {
                interval = midi.asInteger - (last[\midi] ? midi).asInteger;
                if(interval == 0) {
                    st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi], previous: last[\previous]));
                    0.0
                } {
                    ratioInfo = at[\activeIntervalRatioInfo].(interval);
                    ratioError = ratioInfo[\ratioErrorCents] ? 0.0;
                    intervalSupport = ratioInfo[\support] ? 0.0;

                    // v44 final-demo context classifier:
                    // A held two-note relationship is already a complete ratio relation;
                    // neither active note should move and the world must not transport.
                    // A released onset-to-onset arpeggio is different: it has no sustained
                    // anchor, so the harmonic world may travel/reproject by the interval
                    // stream while the single active note itself remains stable. Rich 3+
                    // active contexts are the first place active notes can negotiate.
                    if(prevCount.asInteger < 2) {
                        if(prevCount.asInteger == 1) {
                            if(at[\livingActiveVoiceChainReset].notNil) { at[\livingActiveVoiceChainReset].(st[\nodeShapeCents]); };
                            st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi], previous: last[\previous]));
                            st[\lastArpeggiatedIntervalStreamTransportReport] = (
                                timestamp: now, status: \heldSingleAnchorNoTransport,
                                interval: interval, pcStep: ratioInfo[\pcStep] ? 0,
                                intervalPressureCents: ratioError,
                                appliedCents: 0.0, support: 0.0,
                                writesTrueGauge: false,
                                reason: \heldSingleAnchorDyadPlacedInExistingWorld
                            );
                            st[\lastLivingActiveFieldReport] = (
                                timestamp: now, status: \heldSingleAnchorNoWorldMotion,
                                appliedCents: 0.0, localSupport: 0.0,
                                intervalPressureCents: ratioError,
                                prevCount: prevCount,
                                activeNegotiationAllowed: false,
                                worldTransportAllowed: false,
                                description: \heldTwoNoteRelationshipDoesNotMoveActiveNotes
                            );
                            st[\lastActivePhraseTransportReport] = (
                                timestamp: now,
                                interval: interval,
                                pcStep: ratioInfo[\pcStep] ? 0,
                                pureCents: ratioInfo[\pureCents] ? 0.0,
                                etCents: ratioInfo[\etCents] ? 0.0,
                                intervalPressureCents: ratioError,
                                intervalSupport: intervalSupport,
                                support: 0.0,
                                localSupport: 0.0,
                                requestedCents: 0.0,
                                localAppliedCents: 0.0,
                                appliedCents: 0.0,
                                fieldTrueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                                selectableSetting: false,
                                reason: \heldSingleAnchorDyadPlacedInExistingWorld,
                                gaugeAuthority: 0.0,
                                transportScale: 0.0,
                                blockedByHeldAnchor: true,
                                blockedByInsufficientActiveContext: false,
                                releasedIntervalStream: false,
                                activeNegotiationAllowed: false,
                                carryUsed: false
                            );
                            0.0
                        } {
                            ecology = at[\transportEcologySnapshot].();
                            lowerMidi = midi.asInteger.min((last[\midi] ? midi).asInteger);
                            lowerAuthority = (1.0 + (((64 - lowerMidi).clip(-24, 36) / 72.0) * (cfg[\solver][\activePhraseLowerAuthority] ? 0.32))).clip(0.72, 1.22);
                            streamApplied = at[\applyArpeggiatedIntervalStreamTransport].(midi, pc, last, ratioInfo, ecology, velocity, lowerAuthority);
                            st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi], previous: last[\previous]));
                            st[\lastLivingActiveFieldReport] = (
                                timestamp: now, status: \releasedIntervalStreamMovesWorldNoActiveNegotiation,
                                appliedCents: 0.0, localSupport: 0.0,
                                intervalPressureCents: ratioError,
                                prevCount: prevCount,
                                streamAppliedCents: streamApplied,
                                activeNegotiationAllowed: false,
                                worldTransportAllowed: true,
                                description: \releasedArpeggioMovesHarmonicWorldButNotActiveDyad
                            );
                            st[\lastActivePhraseTransportReport] = (
                                timestamp: now,
                                interval: interval,
                                pcStep: ratioInfo[\pcStep] ? 0,
                                pureCents: ratioInfo[\pureCents] ? 0.0,
                                etCents: ratioInfo[\etCents] ? 0.0,
                                intervalPressureCents: ratioError,
                                intervalSupport: intervalSupport,
                                support: 0.0,
                                localSupport: 0.0,
                                requestedCents: 0.0,
                                localAppliedCents: 0.0,
                                appliedCents: streamApplied,
                                fieldTrueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                                selectableSetting: false,
                                reason: \releasedArpeggiatedIntervalStreamWorldTransport,
                                gaugeAuthority: 0.0,
                                transportScale: 1.0,
                                blockedByHeldAnchor: false,
                                blockedByInsufficientActiveContext: true,
                                releasedIntervalStream: true,
                                activeNegotiationAllowed: false,
                                arpeggiatedIntervalStreamReport: st[\lastArpeggiatedIntervalStreamTransportReport],
                                carryUsed: false
                            );
                            streamApplied / 1200.0
                        }
                    } {
                    ecology = at[\transportEcologySnapshot].();
                    minFreedom = (cfg[\solver][\livingActiveFieldMinFreedom] ? (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54)).clip(0.0, 0.98);
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
                    gaugeAuthorityReport = if(at[\musicalGaugeAuthorityReport].notNil) {
                        at[\musicalGaugeAuthorityReport].(\activePhrase, activePcs, at[\currentExternalSources].() ? Array.new, ratioInfo[\pcStep] ? 0)
                    } { nil };
                    if(gaugeAuthorityReport.isNil) {
                        gaugeAuthorityReport = (authority: 1.0, transportScale: 1.0, blockedUnanchored: false, blockedSymmetric: false, sources: Array.new, fallback: true);
                    };
                    transportScale = gaugeAuthorityReport[\transportScale] ? 1.0;
                    // v2d: Motion is the realized actuator after target selection. Do not multiply target-law support by Motion here.
                    localSupport = (intervalSupport * freeScale * closedPairFactor).clip(0.0, 1.0);
                    gaugeSupport = (localSupport * transportScale).clip(0.0, 1.0);
                    strength = cfg[\solver][\activePhraseRatioTransportStrength] ? (cfg[\solver][\activePhraseTransportStrength] ? 0.24);
                    cents = ratioError * strength.clip(0.0, 1.5) * localSupport * velWeight * lowerAuthority;

                    localApplied = at[\livingActiveApplyIntervalShapeKick].(midi, pc, last, cents * (cfg[\solver][\livingActiveFieldStrength] ? 0.94), localSupport, ratioInfo, ecology);
                    if(at[\registerVelocityChordAuthorityApply].notNil) {
                        var rvAuthority;
                        rvAuthority = at[\registerVelocityChordAuthorityApply].(\liveThreePlusActiveContext, true);
                        if(st[\lastLivingActiveFieldReport].notNil) {
                            st[\lastLivingActiveFieldReport][\registerVelocityChordAuthorityReport] = rvAuthority;
                        };
                    };
                    if(st[\lastLivingActiveFieldReport].notNil) {
                        st[\lastLivingActiveFieldReport][\status] = \threeNoteContextNegotiationApplied;
                        st[\lastLivingActiveFieldReport][\activeContextCount] = prevCount.asInteger + 1;
                        st[\lastLivingActiveFieldReport][\contextRule] = \activeNegotiationRequiresThreeOrMoreNotes;
                    };

                    // v44: once 3+ notes are active, the behavior is active harmonic
                    // negotiation by register/velocity, not hidden arpeggio stream/gauge travel.
                    // Released monophonic arpeggios transport the world in the prevCount==0 branch;
                    // held dyads are blocked in prevCount==1; 3+ active contexts use local shape.
                    streamApplied = 0.0;
                    st[\lastArpeggiatedIntervalStreamTransportReport] = (
                        timestamp: now, status: \threeNoteContextUsesActiveNegotiationNoStreamTransport,
                        interval: interval, pcStep: ratioInfo[\pcStep] ? 0,
                        intervalPressureCents: ratioError, appliedCents: 0.0, support: 0.0,
                        writesTrueGauge: false, reason: \threePlusActiveContextUsesRegisterVelocityNegotiation
                    );
                    rawOffset = 0.0;
                    applied = rawOffset;
                    st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi], previous: last[\previous]));
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
                        support: gaugeSupport,
                        localSupport: localSupport,
                        closedPairFactor: closedPairFactor,
                        lowerAuthority: lowerAuthority,
                        requestedCents: cents,
                        localAppliedCents: localApplied,
                        appliedCents: applied * 1200.0,
                        fieldTrueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
                        selectableSetting: false,
                        reason: \directedIntervalRatioPressure,
                        gaugeAuthority: gaugeAuthorityReport[\authority] ? 0.0,
                        gaugeAuthoritySources: gaugeAuthorityReport[\sources] ? Array.new,
                        transportScale: transportScale,
                        blockedByGaugeAuthority: gaugeAuthorityReport[\blockedUnanchored] ? false,
                        blockedBySymmetry: gaugeAuthorityReport[\blockedSymmetric] ? false,
                        musicalGaugeAuthorityReport: gaugeAuthorityReport,
                        livingActiveFieldReport: st[\lastLivingActiveFieldReport],
                        arpeggiatedIntervalStreamReport: st[\lastArpeggiatedIntervalStreamTransportReport],
                        intervalStreamAppliedCents: streamApplied
                    );
                    if((cfg[\solver][\activePhraseTransportReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
                        ("[at-v38] interval=" ++ interval.asString ++ " pressure=" ++ ratioError.round(0.01).asString ++ "c local=" ++ localApplied.round(0.01).asString ++ "c gauge=" ++ (applied*1200.0).round(0.01).asString ++ "c authority=" ++ (gaugeAuthorityReport[\authority] ? 0.0).round(0.001).asString).postln;
                    };
                    applied
                    }
                }
            }
        }
    };

    api[\livingActiveFieldReport] = { st[\lastLivingActiveFieldReport] };

    // v44: all-notes-off after a single-note harmonic origin must hold the exact
    // seeded harmonic-origin world. The generic release freezer can reinterpret a
    // single active pc as new raw evidence; this wrapper keeps same-origin release
    // idempotent while leaving all richer contexts to the original release freezer.
    if(at[\v43OriginalFreezeFromReleaseBurstNow].isNil and: { at[\freezeFromReleaseBurstNow].notNil }) {
        at[\v43OriginalFreezeFromReleaseBurstNow] = at[\freezeFromReleaseBurstNow];
    };
    at[\freezeFromReleaseBurstNow] = { |fallbackPrevMidis, fallbackReferenceNodePhase|
        var burst, prev, n, pc, originPc, originShape, gauge, shouldHoldOrigin;
        n = cfg[\solver][\numNodes] ? 12;
        burst = st[\releaseBurst];
        prev = if(burst.notNil and: { burst[\prevMidis].notNil }) { burst[\prevMidis] } { fallbackPrevMidis ? Array.new };
        originPc = st[\lastHarmonicOriginPc];
        originShape = st[\lastHarmonicOriginShapeCents];
        shouldHoldOrigin = false;
        if(prev.size == 1 and: { originPc.notNil and: { originShape.notNil and: { originShape.size == n } } }) {
            pc = prev[0].asInteger % n;
            shouldHoldOrigin = (pc == originPc.asInteger);
        };
        if(shouldHoldOrigin) {
            at[\livingActiveEnsureField].();
            gauge = st[\fieldTrueGaugeCents] ? 0.0;
            st[\nodeShapeCents] = originShape.copy;
            st[\targetNodeShapeCents] = originShape.copy;
            st[\nodeShapeVelocityCents] = Array.fill(n, 0.0);
            st[\fieldTrueGaugeCents] = gauge;
            st[\fieldGaugeCents] = gauge;
            if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].() };
            st[\frozenShapeCents] = originShape.copy;
            st[\frozenGaugeCents] = gauge;
            st[\frozenPhase] = st[\nodePhase].copy;
            st[\frozenValid] = true;
            st[\lastFrozenActivePcs] = [pc];
            st[\singletonReentryPending] = nil;
            st[\releaseBurst] = nil;
            st[\pendingNoteOffBatch] = nil;
            st[\uiSnapshotCache] = nil;
            st[\lastSolveProfile] = (
                timestamp: Main.elapsedTime, status: \singleOriginReleaseHeld,
                reason: \noteOff, mode: \liveIncremental,
                elapsedMs: 0.0, iterations: 0, chunks: 0,
                activePcs: Array.new, externalCount: 0
            );
            if(at[\pushBuses].notNil) { at[\pushBuses].() };
            if(at[\beginRestFreezeMonitorIfNeeded].notNil) { at[\beginRestFreezeMonitorIfNeeded].(prev) };
            nil
        } {
            at[\v43OriginalFreezeFromReleaseBurstNow].(fallbackPrevMidis, fallbackReferenceNodePhase)
        }
    };

    "[at-v46] motion-only harmonic context state machine loaded: same-origin is idempotent; one/two active notes hold; released arpeggios move gauge and passive silent world; 3+ active notes negotiate; active-note stability report available.".postln;
};
)
