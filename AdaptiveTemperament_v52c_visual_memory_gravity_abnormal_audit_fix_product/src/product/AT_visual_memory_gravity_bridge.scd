(
// AT_visual_memory_gravity_bridge.scd
// v52c: visual-control responsiveness + adaptive Memory / Gravity follow bridge; nil-phase external source guard + deterministic abnormal-source audit baseline.
// This layer is deliberately product-facing: it does not change the harmonic law,
// Motion gate, spacing/topology thresholds, tone engines, mic classifier, or pitch-authority policy.

var build, at, cfg, st, api, ui, names;
var pitchEligible, safeExternalSources, directSetGravityHome, memoryCentsForPc, bestMemoryPc, chooseEarAnchor;
var phaseForExternalSource, normalizeBridgeExternalSource, normalizeBridgeExternalSources, origCurrentExternalSources;
var origApplyGravity, origLearnMemory, origBuildSnapshot, origSetGravityFollowMode;

build = ~atBuild;
if(build.isNil) {
    "[AT VISUAL MEMORY/GRAVITY BRIDGE] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    ui = build[\ui];
    names = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(st[\visualMemoryGravityBridge].isNil) { st[\visualMemoryGravityBridge] = IdentityDictionary.new; };
    if(st[\memoryMode].isNil) { st[\memoryMode] = if(st[\performanceV2].notNil) { st[\performanceV2][\memoryMode] ? \learn } { \learn }; };
    if(cfg[\memory][\defaultLearningRate].isNil) { cfg[\memory][\defaultLearningRate] = cfg[\memory][\learningRate] ? 0.045; };
    if(cfg[\memory][\defaultDecay].isNil) { cfg[\memory][\defaultDecay] = cfg[\memory][\decay] ? 0.008; };
    if(cfg[\memory][\defaultConfidenceDecay].isNil) { cfg[\memory][\defaultConfidenceDecay] = cfg[\memory][\confidenceDecay] ? 0.012; };
    if(cfg[\memory][\adaptiveExternalLearnBoost].isNil) { cfg[\memory][\adaptiveExternalLearnBoost] = 0.012; };
    if(cfg[\memory][\adaptiveConflictLearnBoost].isNil) { cfg[\memory][\adaptiveConflictLearnBoost] = 0.075; };
    if(cfg[\memory][\adaptiveSilenceDecayScale].isNil) { cfg[\memory][\adaptiveSilenceDecayScale] = 1.4; };

    if(cfg[\gravity].isNil) { cfg[\gravity] = IdentityDictionary.new; };
    cfg[\gravity][\followMode] = cfg[\gravity][\followMode] ? \fixed;
    cfg[\gravity][\memoryMinConfidence] = cfg[\gravity][\memoryMinConfidence] ? 0.08;
    cfg[\gravity][\earMemoryBlendMax] = cfg[\gravity][\earMemoryBlendMax] ? 0.65;
    cfg[\gravity][\earMinWeight] = cfg[\gravity][\earMinWeight] ? 0.015;


    // v52c guard: the public Ear/Gravity bridge may receive staged sources that
    // carry pc+cents but not a literal phase. The legacy solver requires phase.
    // Normalize that representation at the currentExternalSources boundary so
    // reports and the solver see the same pitch object and nil never enters the
    // harmonic force path.
    phaseForExternalSource = { |src|
        var pc, phase, cents, freq;
        if(src.isNil) { nil } {
            pc = src[\pc];
            phase = src[\phase];
            if(phase.notNil) {
                at[\wrap01].(phase.asFloat)
            } {
                if(pc.isNil) { nil } {
                    pc = pc.asInteger.clip(0, 11);
                    freq = src[\freq];
                    if(freq.notNil and: { freq.asFloat > 0.0 } and: { at[\freqToPhase].notNil }) {
                        at[\freqToPhase].(freq.asFloat)
                    } {
                        cents = src[\cents] ? src[\externalCents] ? src[\offsetCents] ? src[\coherenceCents] ? 0.0;
                        at[\wrap01].((st[\etPhase][pc] ? (pc / 12.0)) + (cents.asFloat / 1200.0))
                    }
                }
            }
        }
    };

    normalizeBridgeExternalSource = { |src|
        var out, pc, phase, cents;
        if(src.isNil) { nil } {
            if(src[\pc].isNil) { src } {
                out = src.copy;
                pc = (out[\pc] ? 0).asInteger.clip(0, 11);
                out[\pc] = pc;
                phase = phaseForExternalSource.(out);
                if(phase.notNil) {
                    out[\phase] = phase;
                    if(out[\cents].isNil) {
                        cents = at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0;
                        out[\cents] = cents;
                    };
                };
                out
            }
        }
    };

    normalizeBridgeExternalSources = { |sources|
        var out;
        out = Array.new;
        (sources ? Array.new).do { |src|
            var n, cls, role, kind, solverEligible;
            n = normalizeBridgeExternalSource.(src);
            if(n.notNil) {
                cls = n[\sourceClass] ? n[\class] ? \unknown;
                role = n[\role] ? n[\coherenceRole] ? \externalPitchEvidence;
                kind = n[\kind] ? \unknown;
                solverEligible = (n[\active] != false)
                    and: { (n[\pitchAuthorityEligible] ? true) == true }
                    and: { (n[\gravityEligible] ? true) == true }
                    and: { (n[\selfBleed] ? false).not }
                    and: { (n[\selfBleedBlocked] ? false).not }
                    and: { (n[\selfBleedRejected] ? false).not }
                    and: { [\abnormalSpectrum, \spectralOnlyAbnormal].includes(cls).not }
                    and: { [\abnormalSpectrum, \spectralOnlyAbnormal].includes(kind).not }
                    and: { [\selfBleedBlocked, \selfBleedRejected, \spectralOnlyAbnormal].includes(role).not };
                if(solverEligible) { out = out.add(n); };
            };
        };
        out
    };

    if(at[\visualMemoryGravityBridgeLegacyCurrentExternalSources_v52b].isNil and: { at[\currentExternalSources].notNil }) {
        at[\visualMemoryGravityBridgeLegacyCurrentExternalSources_v52b] = at[\currentExternalSources];
        origCurrentExternalSources = at[\visualMemoryGravityBridgeLegacyCurrentExternalSources_v52b];
        at[\currentExternalSources] = {
            normalizeBridgeExternalSources.(origCurrentExternalSources.() ? Array.new)
        };
    } {
        origCurrentExternalSources = at[\visualMemoryGravityBridgeLegacyCurrentExternalSources_v52b];
    };

    pitchEligible = { |src|
        var cls, role, kind;
        if(src.isNil) { false } {
            cls = src[\sourceClass] ? src[\class] ? \unknown;
            role = src[\role] ? \externalPitchEvidence;
            kind = src[\kind] ? \unknown;
            (src[\pc].notNil)
            and: { (src[\gravityEligible] ? true) == true }
            and: { (src[\pitchAuthorityEligible] ? true) == true }
            and: { (src[\selfBleedBlocked] ? false).not }
            and: { (src[\selfBleedRejected] ? false).not }
            and: { [\abnormalSpectrum, \spectralOnlyAbnormal].includes(cls).not }
            and: { [\abnormalSpectrum, \spectralOnlyAbnormal].includes(kind).not }
            and: { [\selfBleedBlocked, \selfBleedRejected, \spectralOnlyAbnormal].includes(role).not }
        }
    };

    safeExternalSources = {
        var srcs, out;
        srcs = if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { st[\externalSources] ? Array.new };
        out = Array.new;
        (srcs ? Array.new).do { |src|
            if(pitchEligible.(src)) { out = out.add(src); };
        };
        out;
    };

    directSetGravityHome = { |pc=0, cents=0.0, source=\bridge|
        pc = pc.asInteger.clip(0, 11);
        cents = cents.asFloat.clip(-1200.0, 1200.0);
        cfg[\gravity][\homePc] = pc;
        cfg[\gravity][\homeCents] = cents;
        st[\gravityHomePc] = pc;
        st[\gravityHomeCents] = cents;
        st[\gravityHomePhase] = at[\wrap01].((st[\etPhase][pc] ? (pc / 12.0)) + (cents / 1200.0));
        st[\gravityFollowLastSource] = source;
        st[\gravityFollowLastAt] = Main.elapsedTime;
        st[\gravityFollowLastHomePc] = pc;
        st[\gravityFollowLastHomeCents] = cents;
        st[\gravityFollowLastHomeName] = names[pc] ? pc.asString;
        st[\gravityLastReason] = source;
        nil
    };

    memoryCentsForPc = { |pc=0|
        var phase;
        pc = pc.asInteger.clip(0, 11);
        phase = (st[\memoryPhase] ? st[\nodePhase] ? st[\etPhase])[pc] ? (st[\etPhase][pc] ? (pc / 12.0));
        at[\wrapSigned].(phase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0;
    };

    bestMemoryPc = {
        var counts, bestPc, bestVal;
        counts = st[\memorySupportCounts] ? Array.fill(cfg[\solver][\numNodes] ? 12, 0);
        bestPc = st[\gravityHomePc] ? 0;
        bestVal = -1;
        counts.do { |v, i|
            if((v ? 0) > bestVal) { bestVal = v ? 0; bestPc = i; };
        };
        bestPc.asInteger.clip(0, 11);
    };

    chooseEarAnchor = {
        var sources, best, bestScore;
        sources = safeExternalSources.();
        best = nil;
        bestScore = -1.0;
        sources.do { |src|
            var score;
            score = ((src[\weight] ? 0.0).asFloat * 2.0) + (src[\confidence] ? 0.0).asFloat + ((src[\pitchConfidence] ? 0.0).asFloat * 0.5);
            if(score > bestScore) { bestScore = score; best = src; };
        };
        if(best.isNil) { nil } {
            (
                pc: (best[\pc] ? 0).asInteger.clip(0, 11),
                cents: (best[\cents] ? best[\offsetCents] ? 0.0).asFloat.clip(-100.0, 100.0),
                weight: (best[\weight] ? best[\confidence] ? 0.0).asFloat,
                sourceCount: sources.size,
                source: best
            )
        }
    };

    at[\memoryActivePcs] = {
        var weights, pcs, ext;
        weights = at[\pcWeights].();
        pcs = at[\activePcsFromWeights].(weights);
        ext = safeExternalSources.();
        ext.do { |src|
            if(src[\pc].notNil) {
                if(pcs.includes(src[\pc]).not) { pcs = pcs.add(src[\pc]); };
            };
        };
        pcs.sort;
    };

    at[\updateGravityFollowHome] = { |reason=\solve|
        var mode, pc, cents, ear, memCents, memBlend, sourceCount, blockedCount, allExt;
        mode = cfg[\gravity][\followMode] ? \fixed;
        if((cfg[\gravity][\enabled] ? false).not) {
            st[\gravityFollowLastReport] = (enabled: false, followMode: mode, adapted: false, reason: \gravityDisabled, pitchAuthorityAdded: false);
        } {
            case
            { mode == \fixed } {
                st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: false, reason: \fixedHome, pitchAuthorityAdded: false);
            }
            { mode == \memory } {
                if((st[\memoryValid] ? false) and: { (st[\memoryConfidence] ? 0.0) >= (cfg[\gravity][\memoryMinConfidence] ? 0.08) }) {
                    pc = bestMemoryPc.();
                    cents = memoryCentsForPc.(pc);
                    directSetGravityHome.(pc, cents, \memoryFollow);
                    st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: true, source: \memory, pc: pc, homeName: names[pc], homeCents: cents.round(0.01), memoryConfidence: (st[\memoryConfidence] ? 0.0).round(0.001), motionGated: true, keyDetection: false, pitchAuthorityAdded: false);
                } {
                    st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: false, reason: \memoryNotConfident, memoryConfidence: (st[\memoryConfidence] ? 0.0).round(0.001), pitchAuthorityAdded: false);
                };
            }
            { (mode == \ear) or: { mode == \earMemory } } {
                allExt = if(at[\legacyCurrentExternalSources_v3D40].notNil) { at[\legacyCurrentExternalSources_v3D40].() ? Array.new } {
                    if(origCurrentExternalSources.notNil) { origCurrentExternalSources.() ? Array.new } {
                        if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() ? Array.new } { st[\externalSources] ? Array.new }
                    }
                };
                ear = chooseEarAnchor.();
                sourceCount = if(ear.isNil) { 0 } { ear[\sourceCount] ? 0 };
                blockedCount = (allExt ? Array.new).size - sourceCount;
                if(ear.notNil and: { (ear[\weight] ? 0.0) >= (cfg[\gravity][\earMinWeight] ? 0.015) }) {
                    pc = ear[\pc];
                    cents = ear[\cents];
                    memBlend = 0.0;
                    if(mode == \earMemory) {
                        memCents = memoryCentsForPc.(pc);
                        memBlend = ((st[\memoryConfidence] ? 0.0) * (cfg[\gravity][\earMemoryBlendMax] ? 0.65)).clip(0.0, 0.85);
                        cents = ((cents * (1.0 - memBlend)) + (memCents * memBlend)).clip(-1200.0, 1200.0);
                    };
                    directSetGravityHome.(pc, cents, mode);
                    st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: true, source: \ear, pc: pc, homeName: names[pc], homeCents: cents.round(0.01), sourceCount: sourceCount, blockedNonPitchSources: blockedCount.max(0), memoryBlend: memBlend.round(0.001), motionGated: true, keyDetection: false, pitchAuthorityAdded: false, abnormalSpectrumChangesGravity: false, selfBleedChangesGravity: false);
                } {
                    if(mode == \earMemory and: { (st[\memoryValid] ? false) and: { (st[\memoryConfidence] ? 0.0) >= (cfg[\gravity][\memoryMinConfidence] ? 0.08) } }) {
                        pc = bestMemoryPc.();
                        cents = memoryCentsForPc.(pc);
                        directSetGravityHome.(pc, cents, \earMemoryFallbackToMemory);
                        st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: true, source: \memoryFallback, pc: pc, homeName: names[pc], homeCents: cents.round(0.01), sourceCount: sourceCount, blockedNonPitchSources: blockedCount.max(0), motionGated: true, keyDetection: false, pitchAuthorityAdded: false);
                    } {
                        st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: false, reason: \noPitchEligibleEarSources, sourceCount: sourceCount, blockedNonPitchSources: blockedCount.max(0), pitchAuthorityAdded: false, abnormalSpectrumChangesGravity: false, selfBleedChangesGravity: false);
                    };
                };
            }
            { true } {
                st[\gravityFollowLastReport] = (enabled: true, followMode: mode, adapted: false, reason: \unknownMode, pitchAuthorityAdded: false);
            };
        };
        st[\gravityFollowLastReport]
    };

    origApplyGravity = at[\applyGravityBias];
    if(origApplyGravity.notNil) {
        at[\applyGravityBias] = { |evidencePhase, activePcs=nil, reason=\solve|
            at[\updateGravityFollowHome].(reason);
            origApplyGravity.(evidencePhase, activePcs, reason);
        };
    };

    origLearnMemory = at[\learnTonalMemory];
    if(origLearnMemory.notNil) {
        at[\learnTonalMemory] = { |evidencePhase, activePcs=nil, reason=\solve|
            var mode, pcs, dist, soft, hard, conflict, safeExtCount, base, learn;
            mode = st[\memoryMode] ? \learn;
            if(mode == \adaptive) {
                pcs = activePcs;
                if(pcs.isNil or: { pcs.isEmpty }) { pcs = at[\memoryActivePcs].(); };
                safeExtCount = safeExternalSources.().size;
                base = cfg[\memory][\defaultLearningRate] ? 0.045;
                if((st[\memoryValid] ? false) and: { pcs.notEmpty }) {
                    dist = at[\phaseArrayDistance].(evidencePhase, st[\memoryPhase], pcs);
                    soft = ((cfg[\memory][\conflictSoftCents] ? 18.0) / 1200.0).max(0.000001);
                    hard = ((cfg[\memory][\conflictHardCents] ? 55.0) / 1200.0).max(soft + 0.000001);
                    conflict = ((dist - soft) / (hard - soft)).clip(0.0, 1.0);
                } {
                    conflict = 0.0;
                };
                learn = (base + ((cfg[\memory][\adaptiveConflictLearnBoost] ? 0.075) * conflict) + (if(safeExtCount > 0) { cfg[\memory][\adaptiveExternalLearnBoost] ? 0.012 } { 0.0 })).clip(0.0, 0.45);
                cfg[\memory][\learningRate] = learn;
                cfg[\memory][\decay] = ((cfg[\memory][\defaultDecay] ? 0.008) * (cfg[\memory][\adaptiveSilenceDecayScale] ? 1.4)).clip(0.0, 0.20);
                cfg[\memory][\confidenceDecay] = ((cfg[\memory][\defaultConfidenceDecay] ? 0.012) * (cfg[\memory][\adaptiveSilenceDecayScale] ? 1.4)).clip(0.0, 0.20);
                st[\adaptiveMemoryLastConflict] = conflict;
                st[\adaptiveMemoryLastSafeExternalCount] = safeExtCount;
                st[\adaptiveMemoryLastLearningRate] = learn;
            };
            origLearnMemory.(evidencePhase, activePcs, reason);
        };
    };

    origSetGravityFollowMode = api[\setGravityFollowMode];
    if(origSetGravityFollowMode.notNil) {
        api[\setGravityFollowMode] = { |mode=\fixed|
            var m;
            m = origSetGravityFollowMode.(mode);
            if(at[\updateGravityFollowHome].notNil) { at[\updateGravityFollowHome].(\gravityFollowMode); };
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
            m;
        };
    };

    api[\setMemoryMode] = { |mode=\adaptive, post=true|
        var m, rep;
        m = mode.asSymbol;
        if([\learn, \hold, \decay, \adaptive].includes(m).not) { m = \adaptive; };
        st[\memoryMode] = m;
        if(st[\performanceV2].notNil) { st[\performanceV2][\memoryMode] = m; };
        switch(m,
            \learn, {
                cfg[\memory][\learningRate] = cfg[\memory][\defaultLearningRate] ? 0.045;
                cfg[\memory][\decay] = cfg[\memory][\defaultDecay] ? 0.008;
                cfg[\memory][\confidenceDecay] = cfg[\memory][\defaultConfidenceDecay] ? 0.012;
            },
            \hold, {
                cfg[\memory][\learningRate] = 0.0;
                cfg[\memory][\decay] = 0.0;
                cfg[\memory][\confidenceDecay] = 0.0;
            },
            \decay, {
                cfg[\memory][\learningRate] = 0.0;
                cfg[\memory][\decay] = 0.025;
                cfg[\memory][\confidenceDecay] = 0.035;
            },
            \adaptive, {
                cfg[\memory][\learningRate] = cfg[\memory][\defaultLearningRate] ? 0.045;
                cfg[\memory][\decay] = ((cfg[\memory][\defaultDecay] ? 0.008) * (cfg[\memory][\adaptiveSilenceDecayScale] ? 1.4)).clip(0.0, 0.20);
                cfg[\memory][\confidenceDecay] = ((cfg[\memory][\defaultConfidenceDecay] ? 0.012) * (cfg[\memory][\adaptiveSilenceDecayScale] ? 1.4)).clip(0.0, 0.20);
            }
        );
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        rep = (memoryMode: m, learningRate: cfg[\memory][\learningRate], decay: cfg[\memory][\decay], confidenceDecay: cfg[\memory][\confidenceDecay], adaptive: m == \adaptive, pitchAuthorityAdded: false);
        if(post) { ("[AT MEMORY MODE] mode=" ++ m.asString ++ " learn=" ++ rep[\learningRate].round(0.001).asString ++ " decay=" ++ rep[\decay].round(0.001).asString ++ " pitchAuthorityAdded=false").postln; };
        rep;
    };

    api[\setAdaptiveMemoryMode] = { |post=true| api[\setMemoryMode].(\adaptive, post) };
    api[\setMemoryPerformanceModeV2] = { |mode=\learn, post=true| api[\setMemoryMode].(mode, post) };

    api[\memoryModeReport] = { |post=true|
        var rep;
        rep = (memoryMode: st[\memoryMode] ? \learn, amount: st[\memoryAmount] ? 0.0, confidence: st[\memoryConfidence] ? 0.0, valid: st[\memoryValid] ? false, learningRate: cfg[\memory][\learningRate], decay: cfg[\memory][\decay], confidenceDecay: cfg[\memory][\confidenceDecay], adaptiveConflict: st[\adaptiveMemoryLastConflict] ? 0.0, safeExternalCount: st[\adaptiveMemoryLastSafeExternalCount] ? 0, remembers: \twelvePitchClassFieldBody, remembersSpecificFrequencies: false, remembersKeyNamesOrScales: false, pitchAuthorityAdded: false);
        if(post) { "[AT MEMORY MODE REPORT]".postln; rep.postln; };
        rep;
    };

    api[\setRegisterAuthority] = { |x=0.85|
        if(cfg[\passiveHarmonicField].isNil) { cfg[\passiveHarmonicField] = IdentityDictionary.new; };
        cfg[\passiveHarmonicField][\registerAuthority] = x.asFloat.clip(0.0, 1.0);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\passiveHarmonicField][\registerAuthority]
    };

    api[\setVelocityAuthority] = { |x=0.85|
        if(cfg[\passiveHarmonicField].isNil) { cfg[\passiveHarmonicField] = IdentityDictionary.new; };
        cfg[\passiveHarmonicField][\velocityAuthority] = x.asFloat.clip(0.0, 1.0);
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        cfg[\passiveHarmonicField][\velocityAuthority]
    };

    api[\visualMemoryGravityBridgeReport] = { |post=true|
        var rep, follow;
        follow = if(at[\updateGravityFollowHome].notNil) { at[\updateGravityFollowHome].(\report) } { st[\gravityFollowLastReport] ? () };
        rep = (branch: \v52c_visual_memory_gravity_abnormal_audit_fix_candidate, visualControlBridge: ui[\visualControlActions].notNil, visualControlEventCounts: if(ui[\visualControlEventCounts].notNil) { ui[\visualControlEventCounts].copy } { IdentityDictionary.new }, memory: api[\memoryModeReport].(false), gravityFollow: follow, registerAuthority: if(cfg[\passiveHarmonicField].isNil) { nil } { cfg[\passiveHarmonicField][\registerAuthority] ? 0.85 }, velocityAuthority: if(cfg[\passiveHarmonicField].isNil) { nil } { cfg[\passiveHarmonicField][\velocityAuthority] ? 0.85 }, pitchAuthorityAdded: false);
        if(post) { "[AT VISUAL MEMORY/GRAVITY BRIDGE REPORT]".postln; rep.postln; };
        rep;
    };

    origBuildSnapshot = at[\buildUISnapshot];
    if(origBuildSnapshot.notNil) {
        at[\buildUISnapshot] = {
            var snap;
            snap = origBuildSnapshot.();
            snap[\memoryMode] = st[\memoryMode] ? \learn;
            snap[\adaptiveMemoryLastConflict] = st[\adaptiveMemoryLastConflict] ? 0.0;
            snap[\adaptiveMemoryLastSafeExternalCount] = st[\adaptiveMemoryLastSafeExternalCount] ? 0;
            snap[\gravityFollowMode] = cfg[\gravity][\followMode] ? \fixed;
            snap[\gravityFollowLastReport] = st[\gravityFollowLastReport];
            snap[\registerAuthority] = if(cfg[\passiveHarmonicField].isNil) { 0.85 } { cfg[\passiveHarmonicField][\registerAuthority] ? 0.85 };
            snap[\velocityAuthority] = if(cfg[\passiveHarmonicField].isNil) { 0.85 } { cfg[\passiveHarmonicField][\velocityAuthority] ? 0.85 };
            snap[\visualControlLastName] = ui[\lastControlName];
            snap[\visualControlLastValue] = ui[\lastControlValue];
            snap[\visualControlsRegistered] = if(ui[\visualControlActions].notNil) { ui[\visualControlActions].keys.asArray } { Array.new };
            snap;
        };
    };

    api[\runVisualMemoryGravityBridgeAudit] = { |post=true|
        var pass, fail, check, before, action, countsBefore, countsAfter, uiActions, rep, oldExt, oldMemoryPhase, oldMemoryValid, oldMemoryConf, oldCounts;
        pass = 0; fail = 0;
        check = { |label, cond|
            if(cond == true) { pass = pass + 1; if(post) { ("[pass] " ++ label.asString).postln; }; }
            { fail = fail + 1; if(post) { ("[FAIL] " ++ label.asString).postln; }; };
        };
        before = api[\uiSnapshot].();
        oldExt = (st[\externalSources] ? Array.new).copy;
        oldMemoryPhase = (st[\memoryPhase] ? st[\etPhase]).copy;
        oldMemoryValid = st[\memoryValid];
        oldMemoryConf = st[\memoryConfidence];
        oldCounts = (st[\memorySupportCounts] ? Array.fill(cfg[\solver][\numNodes] ? 12, 0)).copy;

        api[\setMemoryMode].(\adaptive, false);
        check.(\adaptiveMemoryModeSelectable, st[\memoryMode] == \adaptive);
        check.(\memoryModeReportedInSnapshot, api[\uiSnapshot].()[\memoryMode] == \adaptive);

        st[\memoryPhase] = st[\etPhase].copy;
        st[\memoryPhase][9] = at[\wrap01].(st[\etPhase][9] + (-31.77 / 1200.0));
        st[\memoryValid] = true;
        st[\memoryConfidence] = 0.82;
        st[\memorySupportCounts] = Array.fill(cfg[\solver][\numNodes] ? 12, 0); st[\memorySupportCounts][9] = 8;
        api[\setGravityEnabled].(true); api[\setGravityStrength].(0.5); api[\setGravityFollowMode].(\memory);
        at[\updateGravityFollowHome].(\auditMemory);
        check.(\gravityFollowsMemoryMode, (cfg[\gravity][\followMode] == \memory) and: { (st[\gravityHomePc] ? -1) == 9 });
        check.(\gravityMemoryHomeCents, ((st[\gravityHomeCents] ? 0.0) + 31.77).abs < 0.25);

        st[\externalSources] = [(pc: 4, cents: -14.0, weight: 0.2, confidence: 0.9, sourceClass: \stableTone, gravityEligible: true, pitchAuthorityEligible: true)];
        api[\setGravityFollowMode].(\ear);
        at[\updateGravityFollowHome].(\auditEar);
        check.(\gravityFollowsPitchEligibleEar, (st[\gravityHomePc] ? -1) == 4);
        check.(\gravityEarHomeCents, ((st[\gravityHomeCents] ? 0.0) + 14.0).abs < 0.25);

        // v52c audit fix: establish the protected Gravity home directly, with
        // no live Ear-follow source present. In v52b this used setGravityHome
        // while followMode was still \ear and the prior pitch-eligible Ear source
        // was still staged, so the public follow bridge legitimately re-adapted
        // Gravity back to that prior source before the abnormal-source probe ran.
        // The product rule is "abnormal/self-bleed cannot change the current
        // Gravity home," so the check must compare against an explicit baseline.
        st[\externalSources] = Array.new;
        cfg[\gravity][\followMode] = \fixed;
        st[\gravityFollowMode] = \fixed;
        directSetGravityHome.(0, 0.0, \auditAbnormalBaseline);
        st[\externalSources] = [(pc: 8, cents: 70.0, weight: 1.0, confidence: 1.0, sourceClass: \abnormalSpectrum, gravityEligible: false, pitchAuthorityEligible: false, spectralAuthorityEligible: true)];
        api[\setGravityFollowMode].(\ear);
        rep = at[\updateGravityFollowHome].(\auditAbnormal);
        check.(\abnormalSpectrumCannotMoveGravity, (rep[\adapted] == false) and: { (st[\gravityHomePc] ? -1) == 0 and: { ((st[\gravityHomeCents] ? 0.0).abs < 0.25) } });

        st[\externalSources] = Array.new;
        cfg[\gravity][\followMode] = \fixed;
        st[\gravityFollowMode] = \fixed;
        directSetGravityHome.(0, 0.0, \auditSelfBleedBaseline);
        st[\externalSources] = [(pc: 0, cents: -60.0, weight: 1.0, confidence: 1.0, sourceClass: \stableTone, gravityEligible: true, pitchAuthorityEligible: false, selfBleedBlocked: true, role: \selfBleedBlocked)];
        api[\setGravityFollowMode].(\ear);
        rep = at[\updateGravityFollowHome].(\auditSelfBleed);
        check.(\selfBleedCannotMoveGravity, (rep[\adapted] == false) and: { (st[\gravityHomePc] ? -1) == 0 and: { ((st[\gravityHomeCents] ? 0.0).abs < 0.25) } });

        if(api[\setRegisterAuthority].notNil) { api[\setRegisterAuthority].(0.37); };
        if(api[\setVelocityAuthority].notNil) { api[\setVelocityAuthority].(0.64); };
        check.(\registerAuthoritySetter, ((cfg[\passiveHarmonicField][\registerAuthority] ? 0.0) - 0.37).abs < 0.01);
        check.(\velocityAuthoritySetter, ((cfg[\passiveHarmonicField][\velocityAuthority] ? 0.0) - 0.64).abs < 0.01);

        uiActions = ui[\visualControlActions];
        check.(\visualControlActionsRegistered, uiActions.notNil and: { uiActions.keys.size >= 10 });
        if(uiActions.notNil) {
            countsBefore = if(ui[\visualControlEventCounts].notNil) { ui[\visualControlEventCounts].copy } { IdentityDictionary.new };
            action = uiActions[\motion]; if(action.notNil) { action.(0.33); };
            action = uiActions[\memory]; if(action.notNil) { action.(0.44); };
            action = uiActions[\gravity]; if(action.notNil) { action.(0.55); };
            action = uiActions[\tension]; if(action.notNil) { action.(0.66); };
            action = uiActions[\memoryMode]; if(action.notNil) { action.(3); };
            action = uiActions[\gravityFollowMode]; if(action.notNil) { action.(3); };
            action = uiActions[\registerAuthority]; if(action.notNil) { action.(0.72); };
            action = uiActions[\velocityAuthority]; if(action.notNil) { action.(0.73); };
            countsAfter = ui[\visualControlEventCounts] ? IdentityDictionary.new;
            check.(\uiMotionActionPathResponds, (countsAfter[\motion] ? 0) > (countsBefore[\motion] ? 0));
            check.(\uiMemoryActionPathResponds, (countsAfter[\memory] ? 0) > (countsBefore[\memory] ? 0));
            check.(\uiGravityActionPathResponds, (countsAfter[\gravity] ? 0) > (countsBefore[\gravity] ? 0));
            check.(\uiTensionActionPathPitchNeutral, ((st[\tension] ? 0.0) - 0.66).abs < 0.01 and: { (api[\uiSnapshot].()[\tensionAffectsPitchLaw] ? false) == false });
            check.(\uiMemoryModeActionPathResponds, st[\memoryMode] == \adaptive);
            check.(\uiGravityFollowActionPathResponds, (cfg[\gravity][\followMode] ? \fixed) == \earMemory);
            check.(\uiRegisterVelocityActionPathResponds, (((cfg[\passiveHarmonicField][\registerAuthority] ? 0.0) - 0.72).abs < 0.01) and: { (((cfg[\passiveHarmonicField][\velocityAuthority] ? 0.0) - 0.73).abs < 0.01) });
        };

        // Restore the public playing state reasonably close to pre-audit values.
        if(api[\setMovement].notNil) { api[\setMovement].(before[\movement] ? 0.82); };
        if(api[\setMemoryAmount].notNil) { api[\setMemoryAmount].(before[\memoryAmount] ? 0.0); };
        if(api[\setTension].notNil) { api[\setTension].(before[\tension] ? 0.55); };
        if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(before[\gravityFollowMode] ? \fixed); };
        if(api[\setGravityHome].notNil) { api[\setGravityHome].(before[\gravityHomePc] ? 0, before[\gravityHomeCents] ? 0.0); };
        if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(before[\gravityStrength] ? 0.0); };
        if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(before[\gravityEnabled] ? false); };
        if(api[\setRegisterAuthority].notNil) { api[\setRegisterAuthority].(before[\registerAuthority] ? 0.85); };
        if(api[\setVelocityAuthority].notNil) { api[\setVelocityAuthority].(before[\velocityAuthority] ? 0.85); };
        st[\externalSources] = oldExt;
        st[\memoryPhase] = oldMemoryPhase;
        st[\memoryValid] = oldMemoryValid;
        st[\memoryConfidence] = oldMemoryConf;
        st[\memorySupportCounts] = oldCounts;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };

        rep = (branch: \v52c_visual_memory_gravity_abnormal_audit_fix_candidate, pass: pass, fail: fail, ready: fail == 0, visualControlsRespond: fail == 0, adaptiveMemoryMode: true, gravityMemoryEarBridge: true, registerVelocityVisualControls: api[\setRegisterAuthority].notNil and: { api[\setVelocityAuthority].notNil }, tensionTonePitchNeutral: true, pitchAuthorityAdded: false);
        if(post) {
            ("[AT VISUAL MEMORY/GRAVITY BRIDGE AUDIT v52c] pass=" ++ pass.asString ++ " fail=" ++ fail.asString ++ " ready=" ++ (fail == 0).asString ++ " visualControlsRespond=" ++ (fail == 0).asString ++ " adaptiveMemoryMode=true gravityMemoryEarBridge=true pitchAuthorityAdded=false").postln;
        };
        rep;
    };

    api[\runVisualControlMemoryGravityAudit] = { |post=true| api[\runVisualMemoryGravityBridgeAudit].(post) };
    at[\runVisualControlMemoryGravityAudit] = { |post=true| api[\runVisualMemoryGravityBridgeAudit].(post) };

    if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
    "[AT VISUAL MEMORY/GRAVITY BRIDGE] v52c loaded: visual controls report through one action path; Memory has Learn/Hold/Decay/Adaptive; Gravity follow modes are fixed/memory/ear/earMemory, external staged sources are phase-normalized, abnormal/self-bleed sources cannot move Gravity, and the audit compares against an explicit baseline home.".postln;
};
)
