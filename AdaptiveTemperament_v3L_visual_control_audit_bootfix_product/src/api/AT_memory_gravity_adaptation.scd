(
// AT_memory_gravity_adaptation.scd
// v3K product-level Memory + Adaptive Gravity demo-source ordering and memory-seed clarity.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;
if(build.isNil) { "[at-memory-gravity] ~atBuild missing".warn; } {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api]; diag = build[\diag]; ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(cfg[\gravity].isNil) { cfg[\gravity] = IdentityDictionary.new; };
    cfg[\gravity][\followMode] = cfg[\gravity][\followMode] ? \fixed;
    cfg[\gravity][\followRate] = cfg[\gravity][\followRate] ? 0.10;
    cfg[\gravity][\followMaxStepCents] = cfg[\gravity][\followMaxStepCents] ? 2.0;
    cfg[\gravity][\followMinConfidence] = cfg[\gravity][\followMinConfidence] ? 0.20;
    cfg[\gravity][\memoryFollowMinConfidence] = cfg[\gravity][\memoryFollowMinConfidence] ? 0.06;
    cfg[\gravity][\earFollowPreferCoherenceApplied] = cfg[\gravity][\earFollowPreferCoherenceApplied] ? true;
    cfg[\gravity][\earFollowRate] = cfg[\gravity][\earFollowRate] ? 0.16;
    cfg[\gravity][\earFollowMaxStepCents] = cfg[\gravity][\earFollowMaxStepCents] ? 3.0;
    cfg[\gravity][\hybridFixedLeashCents] = cfg[\gravity][\hybridFixedLeashCents] ? 42.0;
    st[\gravityFollowMode] = cfg[\gravity][\followMode];
    st[\gravityAdaptiveLastCandidate] = nil;
    st[\gravityAdaptiveLastApplied] = false;
    st[\gravityAdaptiveLastReason] = nil;
    st[\gravityFixedHomePc] = st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? 9);
    st[\gravityFixedHomeCents] = st[\gravityHomeCents] ? (cfg[\gravity][\homeCents] ? 0.0);

    api[\clearAdaptiveGravityState] = {
        st[\gravityAdaptiveLastCandidate] = nil;
        st[\gravityAdaptiveLastApplied] = false;
        st[\gravityAdaptiveLastReason] = \clear;
        nil
    };


    // Product/demo helper: after real music has been played, seed the leaky
    // memory basin from the current playable surface so Gravity-follow-Memory
    // can demonstrate the learned surface even after the notes have released.
    // This does not create a key label or ET snap; it records the current
    // continuous pitch-class surface through the existing memory path.
    api[\seedMemoryFromCurrentSurface] = { |pcs=nil, reason=\manualMemorySurfaceSeed|
        var surf, cleanPcs, counts, conf;
        surf = if(st[\nodePhase].notNil) { st[\nodePhase].copy } { (st[\etPhase] ? Array.fill(12, { |i| i / 12.0 })).copy };
        cleanPcs = (pcs ? Array.new).collect { |pc| pc.asInteger.clip(0, 11) }.select { |pc| pc.notNil };
        if(cleanPcs.isEmpty) { cleanPcs = [st[\worldRootPc] ? st[\lastAnchorPc] ? st[\gravityHomePc] ? 0].collect { |pc| pc.asInteger.clip(0, 11) }; };
        if(at[\learnTonalMemory].notNil) { at[\learnTonalMemory].(surf, cleanPcs, reason); };
        st[\memoryValid] = true;
        conf = ((st[\memoryConfidence] ? 0.0).asFloat.max(cfg[\gravity][\memoryFollowMinConfidence] ? 0.06).max(0.12)).clip(0.0, 1.0);
        st[\memoryConfidence] = conf;
        counts = st[\memorySupportCounts] ? Array.fill(12, 0);
        cleanPcs.do { |pc| counts[pc] = (counts[pc] ? 0).asInteger + 1; };
        st[\memorySupportCounts] = counts;
        st[\memoryLastReason] = reason;
        (source: \currentPlayableSurface, pcs: cleanPcs, confidence: conf, reason: reason)
    };

    at[\pcName] = { |pc| pitchClassNames[pc.asInteger % 12] ? pc.asString };
    at[\pcCentsFromPhase] = { |pc, phase| (at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0).clip(-600.0, 600.0) };

    at[\memoryDominantPc] = {
        var counts, bestPc, bestCount;
        counts = st[\memorySupportCounts] ? Array.fill(12, 0);
        bestPc = nil; bestCount = -1;
        counts.do { |count, pc|
            var c;
            c = count ? 0;
            if(c > bestCount) { bestCount = c; bestPc = pc; };
        };
        if(bestCount > 0) { bestPc } { nil }
    };

    at[\gravitySetHomeSmooth] = { |candidate, rate=nil, maxStepCents=nil, reason=\adaptiveGravity|
        var pc, cents, curPc, curCents, r, maxStep, nextCents, diff;
        if(candidate.isNil) { nil } {
            pc = (candidate[\pc] ? (st[\gravityHomePc] ? 9)).asInteger.clip(0, 11);
            cents = (candidate[\cents] ? 0.0).asFloat.clip(-1200.0, 1200.0);
            curPc = (st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? pc)).asInteger.clip(0, 11);
            curCents = (st[\gravityHomeCents] ? (cfg[\gravity][\homeCents] ? 0.0)).asFloat;
            r = (rate ? (cfg[\gravity][\followRate] ? 0.10)).asFloat.clip(0.0, 1.0);
            maxStep = (maxStepCents ? (cfg[\gravity][\followMaxStepCents] ? 2.0)).asFloat.max(0.0);
            if(pc != curPc) { nextCents = cents.clip(maxStep.neg, maxStep); } {
                diff = cents - curCents;
                nextCents = curCents + ((diff * r).clip(maxStep.neg, maxStep));
            };
            if(at[\setGravityHome].notNil) { at[\setGravityHome].(pc, nextCents); };
            st[\gravityAdaptiveLastApplied] = true;
            st[\gravityAdaptiveLastReason] = reason;
            st[\gravityAdaptiveLastCandidate] = candidate.copy;
            candidate
        }
    };

    at[\gravityCandidateFromMemory] = { |activePcs=nil, reason=\memoryFollow|
        var pc, phase, cents, conf, valid;
        valid = st[\memoryValid] == true;
        conf = (st[\memoryConfidence] ? 0.0).asFloat.clip(0.0, 1.0);
        if(valid.not or: { conf < (cfg[\gravity][\memoryFollowMinConfidence] ? (cfg[\gravity][\followMinConfidence] ? 0.20)) }) { nil } {
            pc = nil;
            if((activePcs ? Array.new).notEmpty) { pc = (activePcs ? [nil]).first; };
            if(pc.isNil and: { at[\memoryDominantPc].notNil }) { pc = at[\memoryDominantPc].(); };
            pc = pc ? st[\worldRootPc] ? st[\lastAnchorPc] ? st[\gravityHomePc] ? 9;
            pc = pc.asInteger.clip(0, 11);
            phase = if(st[\memoryPhase].notNil and: { st[\memoryPhase].size > pc }) { st[\memoryPhase][pc] } { st[\etPhase][pc] ? (pc / 12.0) };
            cents = at[\pcCentsFromPhase].(pc, phase);
            (pc: pc, pcName: at[\pcName].(pc), cents: cents, confidence: conf, source: \memory, reason: reason)
        }
    };

    at[\gravityCandidateFromEar] = { |reason=\earFollow|
        var applied, sources, usable, best, pc, phase, cents, conf, w, preferApplied;
        applied = (st[\externalCoherenceAppliedSources] ? Array.new).select { |src| src.notNil and: { src[\active] != false } };
        preferApplied = (cfg[\gravity][\earFollowPreferCoherenceApplied] ? true) and: { applied.notEmpty };
        sources = if(preferApplied) { applied } { if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() ? Array.new } { st[\externalSources] ? Array.new } };
        usable = sources.select { |src|
            var role, abnormal, selfBleed, conf0, weight0, coherentApplied;
            role = src[\coherenceRole] ? src[\role] ? src[\sourceRole] ? \stableExternalPitch;
            coherentApplied = src[\externalCoherenceBoundedAuthority].notNil or: { src[\externalCoherenceScenario].notNil };
            abnormal = ((src[\spectrumAbnormality] ? 0.0).asFloat >= 0.62) or: { role == \abnormalSpectrum };
            selfBleed = (src[\selfBleed] ? false) or: { role == \selfBleed };
            conf0 = (src[\confidence] ? 0.0).asFloat;
            weight0 = (src[\weight] ? src[\amp] ? 0.0).asFloat;
            selfBleed.not and: { abnormal.not and: { conf0 >= (cfg[\gravity][\followMinConfidence] ? 0.20) and: { weight0 > 0.0001 and: { coherentApplied or: { [\stableExternalPitch, \etInstrument, \externalCoherenceBounded, \externalSinger, \expressiveVoice].includes(role) } } } } }
        };
        if(usable.isEmpty) { nil } {
            // If external coherence published a bounded scene, trust that coherent
            // scene ordering over raw microphone strength. This prevents a stray
            // singer/formant partial from becoming Gravity while an ET instrument
            // context is already published as C/E/G, etc.
            best = if(preferApplied) { usable.first } {
                usable.maxItem { |src| ((src[\weight] ? src[\amp] ? 0.0).asFloat * (src[\confidence] ? 0.0).asFloat * ((src[\stability] ? 0.65).asFloat.max(0.25))) }
            };
            pc = (best[\pc] ? 9).asInteger.clip(0, 11);
            phase = best[\phase] ? at[\wrap01].((st[\etPhase][pc] ? (pc / 12.0)) + ((best[\cents] ? 0.0) / 1200.0));
            cents = at[\pcCentsFromPhase].(pc, phase);
            conf = (best[\confidence] ? 0.0).asFloat.clip(0.0, 1.0);
            w = (best[\weight] ? best[\amp] ? 0.0).asFloat.clip(0.0, 1.0);
            (pc: pc, pcName: at[\pcName].(pc), cents: cents, confidence: conf, weight: w, source: \ear, sourceSet: if(preferApplied) { \externalCoherenceApplied } { \rawMic }, role: best[\coherenceRole] ? best[\role] ? best[\sourceRole], scenario: best[\externalCoherenceScenario], reason: reason)
        }
    };

    at[\applyHybridGravityLeash] = { |candidate|
        var fixedPc, fixedCents, leash, c;
        if(candidate.isNil) { nil } {
            fixedPc = st[\gravityFixedHomePc] ? 9;
            fixedCents = st[\gravityFixedHomeCents] ? -31.766653633429;
            leash = (cfg[\gravity][\hybridFixedLeashCents] ? 42.0).asFloat.max(0.0);
            c = candidate.copy;
            if((c[\pc] ? fixedPc) == fixedPc) { c[\cents] = (c[\cents] ? 0.0).asFloat.clip(fixedCents - leash, fixedCents + leash); };
            c[\hybridFixedPc] = fixedPc; c[\hybridFixedCents] = fixedCents; c[\hybridLeashCents] = leash; c
        }
    };

    at[\updateAdaptiveGravityHome] = { |activePcs=nil, reason=\solve|
        var mode, cand, rate, step;
        mode = (cfg[\gravity][\followMode] ? st[\gravityFollowMode] ? \fixed).asSymbol;
        st[\gravityFollowMode] = mode;
        if((cfg[\gravity][\enabled] ? false).not or: { mode == \off or: { mode == \fixed } }) {
            st[\gravityAdaptiveLastApplied] = false; st[\gravityAdaptiveLastReason] = mode; nil
        } {
            cand = nil;
            if(mode == \memory) { cand = at[\gravityCandidateFromMemory].(activePcs, reason); };
            if(mode == \ear) { cand = at[\gravityCandidateFromEar].(reason); };
            if(mode == \hybrid) { cand = at[\gravityCandidateFromEar].(reason); if(cand.isNil) { cand = at[\gravityCandidateFromMemory].(activePcs, reason); }; cand = at[\applyHybridGravityLeash].(cand); };
            if(cand.notNil) {
                rate = if(cand[\source] == \ear) { cfg[\gravity][\earFollowRate] ? 0.16 } { cfg[\gravity][\followRate] ? 0.10 };
                step = if(cand[\source] == \ear) { cfg[\gravity][\earFollowMaxStepCents] ? 3.0 } { cfg[\gravity][\followMaxStepCents] ? 2.0 };
                at[\gravitySetHomeSmooth].(cand, rate, step, reason);
            } { st[\gravityAdaptiveLastApplied] = false; st[\gravityAdaptiveLastReason] = \noAdaptiveCandidate; st[\gravityAdaptiveLastCandidate] = nil; };
            cand
        }
    };

    api[\setGravityFollowMode] = { |mode=\fixed|
        var m;
        m = mode.asSymbol;
        if([\off, \fixed, \memory, \ear, \hybrid].includes(m).not) { m = \fixed; };
        cfg[\gravity][\followMode] = m; st[\gravityFollowMode] = m;
        if(m == \off) { if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(false); }; } { if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(true); }; };
        if(m == \fixed or: { m == \hybrid }) { st[\gravityFixedHomePc] = st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? 9); st[\gravityFixedHomeCents] = st[\gravityHomeCents] ? (cfg[\gravity][\homeCents] ? 0.0); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        m
    };

    api[\setGravityFollowRate] = { |x=0.10| cfg[\gravity][\followRate] = x.asFloat.clip(0.0, 1.0); cfg[\gravity][\followRate] };
    api[\setGravityMemoryFollowMinConfidence] = { |x=0.06| cfg[\gravity][\memoryFollowMinConfidence] = x.asFloat.clip(0.0, 1.0); cfg[\gravity][\memoryFollowMinConfidence] };
    api[\setGravityEarFollowRate] = { |x=0.16| cfg[\gravity][\earFollowRate] = x.asFloat.clip(0.0, 1.0); cfg[\gravity][\earFollowRate] };
    api[\setGravityHybridLeashCents] = { |x=42.0| cfg[\gravity][\hybridFixedLeashCents] = x.asFloat.clip(0.0, 240.0); cfg[\gravity][\hybridFixedLeashCents] };
    api[\setMemoryHalfLifeSeconds] = { |x=42.0| cfg[\memory][\halfLifeSeconds] = x.asFloat.clip(1.0, 600.0); cfg[\memory][\halfLifeSeconds] };

    api[\applyGravityFollow] = { |amount=nil|
        var oldRate, oldEarRate, amt, cand;
        amt = if(amount.isNil) { 1.0 } { amount.asFloat.clip(0.0, 1.0) };
        oldRate = cfg[\gravity][\followRate] ? 0.10; oldEarRate = cfg[\gravity][\earFollowRate] ? 0.16;
        cfg[\gravity][\followRate] = (oldRate * amt).clip(0.0, 1.0); cfg[\gravity][\earFollowRate] = (oldEarRate * amt).clip(0.0, 1.0);
        cand = at[\updateAdaptiveGravityHome].(if(at[\memoryActivePcs].notNil) { at[\memoryActivePcs].() } { Array.new }, \manualApplyGravityFollow);
        cfg[\gravity][\followRate] = oldRate; cfg[\gravity][\earFollowRate] = oldEarRate;
        if(api[\resolveNow].notNil) { api[\resolveNow].(\manualApplyGravityFollow); };
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        api[\gravityAdaptiveReport].()
    };

    api[\gravityAdaptiveReport] = {
        var base;
        base = if(api[\gravityReport].notNil) { api[\gravityReport].() } { () };
        base[\followMode] = cfg[\gravity][\followMode] ? \fixed;
        base[\adaptiveLastApplied] = st[\gravityAdaptiveLastApplied] ? false;
        base[\adaptiveLastReason] = st[\gravityAdaptiveLastReason];
        base[\adaptiveLastCandidate] = st[\gravityAdaptiveLastCandidate];
        base[\memoryDominantPc] = if(at[\memoryDominantPc].notNil) { at[\memoryDominantPc].() } { nil };
        base[\memoryDominantName] = if(base[\memoryDominantPc].notNil) { at[\pcName].(base[\memoryDominantPc]) } { nil };
        base[\fixedHomePc] = st[\gravityFixedHomePc];
        base[\fixedHomeCents] = st[\gravityFixedHomeCents];
        base[\role] = \softHomeReferenceFixedOrAdaptive;
        base
    };

    at[\memoryGravitySemanticReport] = { (memory: if(at[\memoryReport].notNil) { at[\memoryReport].() } { (available: false) }, gravity: if(api[\gravityAdaptiveReport].notNil) { api[\gravityAdaptiveReport].() } { (available: false) }, semantics: (memory: \leakyContinuousPitchClassSurface, memoryDoesNotStore: [\keyLabels, \scaleNames, \rawFrequencyList], gravity: \softHomeReference, gravityModes: [\off, \fixed, \memory, \ear, \hybrid], earMemoryPolicy: \coherentExternalCanInfluence_unstableVoiceWeak_abnormalSpectrumRejectedForPitch, motionBoundary: \gravityChoosesHome_motionMovesSound)) };
    api[\memoryGravityReport] = { at[\memoryGravitySemanticReport].().postln };

    api[\runMemoryGravityAudit] = {
        var pass=0, fail=0, check, et, shifted, beforeConf, afterConf, fixedBefore, memRep, gravRep, oldSources, oldCurrentExternal, oldMode;
        check = { |name, cond, detail=""| if(cond) { pass = pass + 1; ("[AT MEMORY/GRAVITY PASS] " ++ name.asString ++ " :: " ++ detail.asString).postln; } { fail = fail + 1; ("[AT MEMORY/GRAVITY FAIL] " ++ name.asString ++ " :: " ++ detail.asString).warn; }; };
        et = st[\etPhase] ? Array.fill(12, { |i| i / 12.0 });
        oldSources = st[\externalSources]; oldCurrentExternal = at[\currentExternalSources]; oldMode = cfg[\gravity][\followMode] ? \fixed;
        if(at[\clearTonalMemory].notNil) { at[\clearTonalMemory].(); };
        if(at[\setGravityHome].notNil) { at[\setGravityHome].(9, -31.766653633429); };
        if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(0.35); }; if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(5.0); };
        shifted = et.collect { |p, i| at[\wrap01].(p + (if(i == 0 or: { i == 4 or: { i == 7 } }) { 14.0 } { 0.0 } / 1200.0)) };
        at[\learnTonalMemory].(shifted, [0,4,7], \auditKeyC); beforeConf = st[\memoryConfidence] ? 0.0; st[\memoryLastUpdateAt] = Main.elapsedTime - 20.0; at[\memoryDecayNoEvidence].(); afterConf = st[\memoryConfidence] ? 0.0;
        check.(\memoryIsLeaky, afterConf < beforeConf, "before=" ++ beforeConf.round(0.001) ++ " after=" ++ afterConf.round(0.001));
        memRep = at[\memoryReport].(); check.(\memoryStoresSurfaceNotKeyLabel, (memRep[\remembersGaugeAndPitchClassSurface] == true) and: { memRep[\remembersKeyLabels] == false }, memRep[\role].asString);
        st[\memoryAmount] = 0.75; cfg[\memory][\amount] = 0.75;
        shifted = et.collect { |p, i| at[\wrap01].(p + (if(i == 4 or: { i == 8 or: { i == 11 } }) { -12.0 } { 0.0 } / 1200.0)) };
        at[\learnTonalMemory].(shifted, [4,8,11], \auditModulationE); check.(\memoryModulationLearnsWithoutAccumulatingForever, (st[\memoryLastLearnRate] ? 0.0) > 0.0, "learn=" ++ (st[\memoryLastLearnRate] ? 0.0).round(0.0001));
        api[\setGravityFollowMode].(\fixed); fixedBefore = [st[\gravityHomePc], (st[\gravityHomeCents] ? 0.0).round(0.01)];
        st[\externalSources] = [(pc: 0, phase: et[0], cents: 0.0, weight: 0.8, confidence: 0.9, stability: 0.9, role: \stableExternalPitch, active: true)]; at[\currentExternalSources] = { st[\externalSources] ? Array.new };
        at[\updateAdaptiveGravityHome].([0,4,7], \auditFixedIgnoresEar); check.(\fixedGravityStaysFixed, (st[\gravityHomePc] == fixedBefore[0]) and: { ((st[\gravityHomeCents] ? 0.0).round(0.01) == fixedBefore[1]) }, "home=" ++ at[\pcName].(st[\gravityHomePc]) ++ " cents=" ++ (st[\gravityHomeCents] ? 0.0).round(0.01));
        st[\worldRootPc] = 4; api[\setGravityFollowMode].(\memory); at[\updateAdaptiveGravityHome].([4,8,11], \auditMemoryFollow); gravRep = api[\gravityAdaptiveReport].(); check.(\gravityFollowsMemoryWhenModeMemory, gravRep[\followMode] == \memory and: { gravRep[\adaptiveLastCandidate].notNil and: { gravRep[\adaptiveLastCandidate][\source] == \memory } }, gravRep.asString);
        st[\externalSources] = [(pc: 9, phase: at[\wrap01].(et[9] + (-31.766653633429/1200.0)), cents: -31.766653633429, weight: 0.8, confidence: 0.95, stability: 0.9, role: \stableExternalPitch, active: true)]; api[\setGravityFollowMode].(\ear); at[\updateAdaptiveGravityHome].([9], \auditEarFollowA432); gravRep = api[\gravityAdaptiveReport].(); check.(\gravityFollowsCoherentEar, gravRep[\followMode] == \ear and: { gravRep[\adaptiveLastCandidate].notNil and: { gravRep[\adaptiveLastCandidate][\pc] == 9 } }, gravRep.asString);
        st[\externalSources] = [(pc: 10, phase: et[10], cents: 0.0, weight: 1.0, confidence: 0.95, stability: 0.9, role: \abnormalSpectrum, spectrumAbnormality: 1.0, active: true)]; at[\updateAdaptiveGravityHome].([10], \auditRejectAbnormal); gravRep = api[\gravityAdaptiveReport].(); check.(\gravityRejectsAbnormalSpectrumAsPitchHome, (gravRep[\adaptiveLastCandidate].isNil) or: { gravRep[\adaptiveLastCandidate][\pc] != 10 }, gravRep.asString);
        st[\externalSources] = [(pc: 9, phase: at[\wrap01].(et[9] + (-22.0/1200.0)), cents: -22.0, weight: 0.8, confidence: 0.9, stability: 0.9, role: \stableExternalPitch, active: true)]; api[\setGravityFollowMode].(\hybrid); at[\updateAdaptiveGravityHome].([9], \auditHybrid); gravRep = api[\gravityAdaptiveReport].(); check.(\hybridGravityHasFixedLeashAndAdaptiveCandidate, gravRep[\followMode] == \hybrid and: { gravRep[\adaptiveLastCandidate].notNil }, gravRep.asString);
        cfg[\gravity][\followMode] = oldMode; st[\gravityFollowMode] = oldMode; st[\externalSources] = oldSources; at[\currentExternalSources] = oldCurrentExternal; if(api[\clearAdaptiveGravityState].notNil) { api[\clearAdaptiveGravityState].(); };
        ("[AT MEMORY/GRAVITY AUDIT v3K] pass=" ++ pass ++ " fail=" ++ fail ++ " readyForFinalProduct=" ++ (fail == 0).asString).postln;
        (pass: pass, fail: fail, readyForFinalProduct: fail == 0, report: at[\memoryGravitySemanticReport].())
    };

    if(at[\originalApplyGravityBias_v3G].isNil and: { at[\applyGravityBias].notNil }) {
        at[\originalApplyGravityBias_v3G] = at[\applyGravityBias];
        at[\applyGravityBias] = { |evidencePhase, activePcs=nil, reason=\solve| if(at[\updateAdaptiveGravityHome].notNil) { at[\updateAdaptiveGravityHome].(activePcs, reason); }; at[\originalApplyGravityBias_v3G].(evidencePhase, activePcs, reason) };
    };
    "[at-memory-gravity] v3K adaptive gravity/memory semantics loaded: fixed, memory, ear, hybrid gravity; demo memory-seeding and coherent Ear source discipline available.".postln;
};
)
