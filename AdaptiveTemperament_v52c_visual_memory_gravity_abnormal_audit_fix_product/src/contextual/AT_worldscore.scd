(
// AT_worldscore.scd
// Optional candidate-world interpretation layer, v2.
// This layer remains advisory: the accepted solver still produces the base target.
// v2 separates musical root from bass/register, reports inversion/function/family,
// and computes ambiguity from distinct interpretation families rather than duplicate variants.
var build, at, cfg, st, api, diag, ui, pitchNames;

build = ~atBuild;
if(build.isNil) {
    "[at-world] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    at[\worldRoleForDist] = { |dist|
        var roles;
        roles = [\root, \b2, \two, \b3, \three, \four, \tritone, \five, \b6, \six, \b7, \seven];
        roles[dist % 12]
    };

    at[\worldUniquePcs] = { |pcs|
        var out, seen;
        out = Array.new;
        seen = IdentitySet.new;
        (pcs ? Array.new).do { |pc|
            if(pc.notNil and: { seen.includes(pc).not }) {
                seen.add(pc);
                out = out.add(pc);
            };
        };
        out;
    };

    at[\worldBassInfo] = { |activePcs, pcWeights|
        var lowMidi, lowPc, strongest;
        lowMidi = nil;
        lowPc = nil;
        at[\notesArray].().do { |note|
            if((activePcs ? Array.new).includes(note[\pc])) {
                if(lowMidi.isNil or: { note[\midi] < lowMidi }) {
                    lowMidi = note[\midi];
                    lowPc = note[\pc];
                };
            };
        };
        strongest = at[\strongestPc].(activePcs, pcWeights);
        if(lowPc.isNil) { lowPc = strongest; };
        (pc: lowPc, midi: lowMidi, strongestPc: strongest)
    };

    at[\worldChoiceFor] = { |dist, variant, refDiff|
        var choices, idx, best, bestCost, c, cost;
        choices = at[\ratioChoices][dist % 12];
        idx = nil;

        if(variant == \simple) { idx = 0; };
        if((variant == \harmonicSeventh) and: { dist == 10 and: { choices.size >= 3 } }) { idx = 2; };
        if((variant == \temperedSeventh) and: { dist == 10 and: { choices.size >= 2 } }) { idx = 1; };
        if((variant == \wideSeventh) and: { dist == 10 }) { idx = 0; };

        if(idx.notNil) {
            choices[idx.min(choices.size - 1)];
        } {
            best = choices[0];
            bestCost = 999999.0;
            choices.do { |pair|
                c = at[\wrapSigned].((refDiff ? 0.0) - pair[0]).abs;
                cost = c / ((pair[1] ? 0.5) + 0.000001);
                if(cost < bestCost) {
                    bestCost = cost;
                    best = pair;
                };
            };
            best;
        };
    };

    at[\worldHasDists] = { |rootPc, activePcs, dists|
        var ok;
        ok = true;
        dists.do { |d|
            if((activePcs ? Array.new).includes((rootPc + d) % 12).not) { ok = false; };
        };
        ok;
    };

    at[\worldFamilyFor] = { |rootPc, activePcs, variant|
        var fam;
        fam = \context;
        if(at[\worldHasDists].(rootPc, activePcs, [0, 3, 6, 9]) or: { variant == \diminishedSymmetry }) {
            fam = \diminishedSymmetry;
        } {
            if(at[\worldHasDists].(rootPc, activePcs, [0, 4, 7, 10, 1])) {
                fam = \dominantB9;
            } {
                if(at[\worldHasDists].(rootPc, activePcs, [0, 4, 7, 10])) {
                    fam = if(variant == \harmonicSeventh) { \harmonicSeventhColor } { \dominantSeventh };
                } {
                    if(at[\worldHasDists].(rootPc, activePcs, [0, 4, 7])) {
                        fam = \majorTriad;
                    } {
                        if(at[\worldHasDists].(rootPc, activePcs, [0, 3, 7])) {
                            fam = \minorTriad;
                        };
                    };
                };
            };
        };
        fam;
    };

    at[\worldFamilyShort] = { |fam|
        if(fam == \majorTriad) { "maj" } {
        if(fam == \minorTriad) { "min" } {
        if(fam == \dominantSeventh) { "7" } {
        if(fam == \harmonicSeventhColor) { "7harm" } {
        if(fam == \dominantB9) { "7b9" } {
        if(fam == \diminishedSymmetry) { "dimSym" } { "context" }}}}}}
    };

    at[\worldInversionFor] = { |rootPc, bassPc, fam|
        var dist, inv;
        inv = \unknown;
        if(bassPc.notNil) {
            dist = (bassPc - rootPc) % 12;
            inv = if(dist == 0) { \rootPosition } {
                if((fam == \majorTriad) and: { dist == 4 }) { \first } {
                if((fam == \minorTriad) and: { dist == 3 }) { \first } {
                if((fam == \majorTriad or: { fam == \minorTriad or: { fam == \dominantSeventh or: { fam == \dominantB9 or: { fam == \harmonicSeventhColor } } } }) and: { dist == 7 }) { \second } {
                if((fam == \dominantSeventh or: { fam == \dominantB9 or: { fam == \harmonicSeventhColor } }) and: { dist == 10 }) { \third } { \nonChordBass }}}}
            };
        };
        inv;
    };

    at[\worldFunctionFor] = { |fam, variant, inv|
        if(fam == \dominantB9) { \dominantFunctionCandidate } {
        if(fam == \dominantSeventh) { \dominantCandidate } {
        if(fam == \harmonicSeventhColor) { \colorDominantCandidate } {
        if(fam == \diminishedSymmetry) { \diminishedAmbiguity } {
        if(inv == \first or: { inv == \second or: { inv == \third } }) { \inversion } { fam }}}}}
    };

    at[\worldFamilyBase] = { |fam|
        if(fam == \majorTriad) { 1.0 } {
        if(fam == \minorTriad) { 1.0 } {
        if(fam == \dominantSeventh) { 0.86 } {
        if(fam == \harmonicSeventhColor) { 0.82 } {
        if(fam == \dominantB9) { 0.78 } {
        if(fam == \diminishedSymmetry) { 0.64 } { 0.22 }}}}}}
    };

    at[\worldVariantListForRoot] = { |rootPc, activePcs|
        var variants, hasSeventh, diminishedish;
        variants = [\context, \simple];
        hasSeventh = (activePcs ? Array.new).includes((rootPc + 10) % 12);
        if(hasSeventh) {
            variants = variants.add(\temperedSeventh);
            variants = variants.add(\harmonicSeventh);
            variants = variants.add(\wideSeventh);
        };
        diminishedish = at[\worldHasDists].(rootPc, activePcs, [0, 3, 6, 9]);
        if(diminishedish) { variants = variants.add(\diminishedSymmetry); };
        variants;
    };

    at[\worldLabelFor] = { |rootPc, bassPc, fam|
        var label;
        label = pitchNames[rootPc] ++ ":" ++ at[\worldFamilyShort].(fam);
        if(bassPc.notNil and: { bassPc != rootPc }) {
            label = label ++ "/" ++ pitchNames[bassPc];
        };
        label;
    };

    at[\worldGenerateCandidate] = { |rootPc, variant, activePcs, pcWeights, externalSources, oldPhase, solvedPhase, bassInfo, reason|
        var proposal, ratioMap, rootPhase, sumSimp, count, motionSum, memorySum, solvedFitSum, heldSum, extSupport;
        var avgSimp, motionCents, memoryCents, solvedFitCents, heldCents, score, label, continuityBonus, bassBonus, prevWorld;
        var bassPc, bassMidi, fam, inv, func, familyBase, rootPresentBonus, inversionBonus, variantBonus;
        proposal = solvedPhase.copy;
        ratioMap = Array.new;
        bassPc = bassInfo[\pc];
        bassMidi = bassInfo[\midi];
        fam = at[\worldFamilyFor].(rootPc, activePcs, variant);
        inv = at[\worldInversionFor].(rootPc, bassPc, fam);
        func = at[\worldFunctionFor].(fam, variant, inv);
        rootPhase = solvedPhase[rootPc] ? oldPhase[rootPc];
        proposal[rootPc] = rootPhase;
        sumSimp = 0.0;
        count = 0;
        motionSum = 0.0;
        memorySum = 0.0;
        solvedFitSum = 0.0;
        heldSum = 0.0;
        extSupport = 0.0;
        prevWorld = st[\worldActiveWorld];

        (activePcs ? Array.new).do { |pc|
            var dist, refDiff, choice, targetPhase, simp, role, prot, protectedWeight;
            dist = (pc - rootPc) % 12;
            refDiff = at[\wrapSigned].(solvedPhase[pc] - rootPhase);
            choice = at[\worldChoiceFor].(dist, variant, refDiff);
            targetPhase = at[\wrap01].(rootPhase + choice[0]);
            simp = choice[1] ? 0.5;
            proposal[pc] = targetPhase;
            role = at[\worldRoleForDist].(dist);
            ratioMap = ratioMap.add((
                pc: pc,
                role: role,
                dist: dist,
                cents: (choice[0] * 1200.0).round(0.01),
                simplicity: simp.round(0.01)
            ));
            sumSimp = sumSimp + simp;
            count = count + 1;
            motionSum = motionSum + (at[\wrapSigned].(targetPhase - oldPhase[pc]).abs * 1200.0);
            solvedFitSum = solvedFitSum + (at[\wrapSigned].(targetPhase - solvedPhase[pc]).abs * 1200.0);
            if(st[\memoryValid] == true) {
                memorySum = memorySum + (at[\wrapSigned].(targetPhase - st[\memoryPhase][pc]).abs * 1200.0);
            };
            prot = nil;
            protectedWeight = 0.0;
            at[\notesArray].().do { |note|
                if(note[\pc] == pc) {
                    prot = note[\protectedPhase] ? oldPhase[pc];
                    protectedWeight = protectedWeight.max((at[\noteAge].(note) / 2.0).clip(0.0, 1.0));
                };
            };
            if(prot.notNil) {
                heldSum = heldSum + (at[\wrapSigned].(targetPhase - prot).abs * 1200.0 * protectedWeight);
            };
        };

        (externalSources ? Array.new).do { |src|
            if(src[\pc] == rootPc) {
                extSupport = extSupport + ((src[\weight] ? 0.0) * (src[\confidence] ? 1.0));
            };
        };

        avgSimp = if(count <= 0) { 0.0 } { sumSimp / count };
        motionCents = if(count <= 0) { 0.0 } { motionSum / count };
        memoryCents = if((count <= 0) or: { st[\memoryValid] != true }) { 0.0 } { memorySum / count };
        solvedFitCents = if(count <= 0) { 0.0 } { solvedFitSum / count };
        heldCents = if(count <= 0) { 0.0 } { heldSum / count };

        familyBase = at[\worldFamilyBase].(fam);
        rootPresentBonus = if((activePcs ? Array.new).includes(rootPc)) { cfg[\world][\rootPresentWeight] ? 0.18 } { 0.0 };
        bassBonus = if(rootPc == bassPc) { cfg[\world][\bassRootWeight] ? 0.24 } { 0.0 };
        inversionBonus = if((rootPc != bassPc) and: { [\first, \second, \third].includes(inv) }) { cfg[\world][\inversionWeight] ? 0.28 } { 0.0 };
        variantBonus = 0.0;
        if(variant == \harmonicSeventh and: { fam == \harmonicSeventhColor }) { variantBonus = cfg[\world][\colorVariantWeight] ? 0.06; };
        if(variant == \diminishedSymmetry) { variantBonus = cfg[\world][\symmetryVariantWeight] ? 0.08; };
        continuityBonus = if(prevWorld.notNil and: { (prevWorld[\rootPc] ? prevWorld[\anchorPc]) == rootPc }) { cfg[\world][\continuityWeight] ? 0.45 } { 0.0 };

        score = 0.0;
        score = score + (familyBase * (cfg[\world][\familyWeight] ? 1.25));
        score = score + (avgSimp * 2.2 * (cfg[\world][\simplicityWeight] ? 0.35));
        score = score + rootPresentBonus + bassBonus + inversionBonus + continuityBonus + variantBonus;
        score = score + (extSupport * (cfg[\world][\externalWeight] ? 0.25));
        score = score - ((motionCents / 24.0) * (cfg[\world][\motionCostWeight] ? 0.40));
        score = score - ((solvedFitCents / 18.0) * (cfg[\world][\solvedFitWeight] ? 0.18));
        score = score - ((memoryCents / 24.0) * (cfg[\world][\memoryWeight] ? 0.35));
        score = score - ((heldCents / 18.0) * (cfg[\world][\heldCostWeight] ? 0.65));

        label = at[\worldLabelFor].(rootPc, bassPc, fam);
        (
            rootPc: rootPc,
            rootName: pitchNames[rootPc],
            anchorPc: rootPc,
            anchorName: pitchNames[rootPc],
            bassPc: bassPc,
            bassName: if(bassPc.isNil) { nil } { pitchNames[bassPc] },
            bassMidi: bassMidi,
            inversion: inv,
            family: fam,
            function: func,
            variant: variant,
            label: label,
            proposal: proposal,
            ratioMap: ratioMap,
            score: score,
            scoreRounded: score.round(0.001),
            avgSimplicity: avgSimp.round(0.001),
            motionCostCents: motionCents.round(0.01),
            memoryCostCents: memoryCents.round(0.01),
            solvedFitCents: solvedFitCents.round(0.01),
            heldCostCents: heldCents.round(0.01),
            familySupport: familyBase.round(0.001),
            bassSupport: bassBonus.round(0.001),
            inversionSupport: inversionBonus.round(0.001),
            continuitySupport: continuityBonus.round(0.001),
            externalSupport: extSupport.round(0.001),
            reason: reason
        )
    };

    at[\scoreCandidateWorlds] = { |activePcs, pcWeights, externalSources, oldPhase, solvedPhase, reason=\world|
        var roots, bassInfo, prevWorld, worlds, maxGen, sorted;
        bassInfo = at[\worldBassInfo].(activePcs, pcWeights);
        prevWorld = st[\worldActiveWorld];
        roots = Array.new;
        if(prevWorld.notNil and: { (prevWorld[\rootPc] ? prevWorld[\anchorPc]).notNil }) { roots = roots.add(prevWorld[\rootPc] ? prevWorld[\anchorPc]); };
        roots = roots ++ (activePcs ? Array.new);
        if(bassInfo[\strongestPc].notNil) { roots = roots.add(bassInfo[\strongestPc]); };
        roots = at[\worldUniquePcs].(roots);
        worlds = Array.new;
        maxGen = (cfg[\world][\maxWorlds] ? 12).max(1);
        roots.do { |rootPc|
            at[\worldVariantListForRoot].(rootPc, activePcs).do { |variant|
                if(worlds.size < (maxGen * 5)) {
                    worlds = worlds.add(at[\worldGenerateCandidate].(rootPc, variant, activePcs, pcWeights, externalSources, oldPhase, solvedPhase, bassInfo, reason));
                };
            };
        };
        sorted = worlds.sort { |a, b| (a[\score] ? -999999.0) > (b[\score] ? -999999.0) };
        if(sorted.size > maxGen) { sorted.copyRange(0, maxGen - 1) } { sorted };
    };

    at[\worldFamilyKey] = { |w|
        ((w[\rootPc] ? -1).asString ++ ":" ++ (w[\family] ? \unknown).asString ++ ":" ++ (w[\inversion] ? \unknown).asString)
    };

    at[\worldFamilyLeaders] = { |worlds|
        var leaders, keys, key, out;
        leaders = IdentityDictionary.new;
        keys = Array.new;
        (worlds ? Array.new).do { |w|
            key = at[\worldFamilyKey].(w);
            if(leaders[key].isNil) {
                leaders[key] = w;
                keys = keys.add(key);
            } {
                if((w[\score] ? -999999.0) > (leaders[key][\score] ? -999999.0)) { leaders[key] = w; };
            };
        };
        out = keys.collect { |k| leaders[k] };
        out.sort { |a, b| (a[\score] ? -999999.0) > (b[\score] ? -999999.0) };
    };


    at[\worldIsCompleteKnownFamily] = { |w, activePcs|
        var fam, root, required, pcs, ok;
        fam = w[\family];
        root = w[\rootPc] ? w[\anchorPc];
        required = nil;
        if(fam == \majorTriad) { required = [0, 4, 7]; };
        if(fam == \minorTriad) { required = [0, 3, 7]; };
        if(fam == \dominantSeventh or: { fam == \harmonicSeventhColor }) { required = [0, 4, 7, 10]; };
        if(fam == \dominantB9) { required = [0, 1, 4, 7, 10]; };
        if(fam == \diminishedSymmetry) { required = [0, 3, 6, 9]; };
        if(required.isNil or: { root.isNil }) {
            false;
        } {
            pcs = activePcs ? Array.new;
            ok = pcs.size == required.size;
            required.do { |d|
                if(pcs.includes((root + d) % 12).not) { ok = false; };
            };
            ok;
        };
    };

    at[\worldMeaningfulFamilyLeaders] = { |families, best, activePcs|
        var out, bestFam;
        bestFam = if(best.isNil) { nil } { best[\family] };
        out = Array.new;
        (families ? Array.new).do { |w|
            var keep;
            keep = true;
            if(bestFam.notNil and: { bestFam != \context and: { w[\family] == \context } }) {
                if(at[\worldIsCompleteKnownFamily].(best, activePcs)) { keep = false; };
            };
            if(keep) { out = out.add(w); };
        };
        if(out.isEmpty and: { best.notNil }) { out = [best] } { out };
    };

    at[\worldAmbiguityFor] = { |best, families, activePcs|
        var meaningful, secondFam, gap, ambiguity, fam, complete, inv;
        if(best.isNil) {
            (gap: nil, ambiguity: 0.0, meaningfulFamilies: Array.new);
        } {
            meaningful = at[\worldMeaningfulFamilyLeaders].(families, best, activePcs);
            secondFam = if(meaningful.size > 1) { meaningful[1] } { nil };
            gap = if(secondFam.notNil) { ((best[\score] ? 0.0) - (secondFam[\score] ? 0.0)).max(0.0) } { 999.0 };
            ambiguity = (1.0 - (gap / (cfg[\world][\familyAmbiguityGap] ? 0.65)).clip(0.0, 1.0)).clip(0.0, 1.0);
            fam = best[\family];
            inv = best[\inversion];
            complete = at[\worldIsCompleteKnownFamily].(best, activePcs);
            if(complete and: { [\majorTriad, \minorTriad].includes(fam) }) {
                if(inv == \rootPosition) {
                    ambiguity = ambiguity.min(cfg[\world][\clearTriadAmbiguity] ? 0.16);
                } {
                    ambiguity = ambiguity.min(cfg[\world][\inversionAmbiguity] ? 0.34);
                };
            };
            if(fam == \diminishedSymmetry) {
                ambiguity = ambiguity.max(cfg[\world][\diminishedAmbiguityFloor] ? 0.72);
            };
            if([\dominantSeventh, \harmonicSeventhColor, \dominantB9].includes(fam)) {
                ambiguity = ambiguity.max(cfg[\world][\dominantAmbiguityFloor] ? 0.55);
            };
            (gap: gap, ambiguity: ambiguity.clip(0.0, 1.0), meaningfulFamilies: meaningful);
        };
    };

    at[\worldReportLabel] = { |w|
        var label, variant;
        label = (w[\label] ? "nil").asString;
        variant = w[\variant];
        if(variant.notNil and: { [\context, \simple].includes(variant).not }) {
            label = label ++ "(" ++ variant.asString ++ ")";
        };
        label;
    };

    at[\familyIsTonalRestCandidate] = { |fam|
        (fam == \majorTriad) or: { fam == \minorTriad }
    };

    at[\familyIsDominant] = { |fam|
        (fam == \dominantSeventh) or: { fam == \harmonicSeventhColor or: { fam == \dominantB9 } }
    };

    at[\familyIsDiminished] = { |fam|
        fam == \diminishedSymmetry
    };

    at[\nextFifthPc] = { |rootPc|
        if(rootPc.isNil) { nil } { (rootPc + 5) % 12 }
    };

    at[\nextStepPc] = { |rootPc|
        if(rootPc.isNil) { nil } { (rootPc + 2) % 12 }
    };

    at[\nearSemitoneAbove] = { |a, b|
        if(a.isNil or: { b.isNil }) { false } { ((b - a) % 12) == 1 }
    };

    at[\dimSupportsDominantRoot] = { |activePcs, rootPc|
        var pcs, ok;
        pcs = activePcs ? Array.new;
        if(rootPc.isNil) {
            false
        } {
            ok = true;
            [1, 4, 7, 10].do { |d|
                if(pcs.includes((rootPc + d) % 12).not) { ok = false; };
            };
            ok
        }
    };

    at[\findDominantRootForDimPcs] = { |activePcs|
        var pcs, found, prefer;
        pcs = activePcs ? Array.new;
        found = nil;

        // Prefer phrase context when a symmetrical diminished set supports
        // several dominant roots. Example: B-D-F-Ab after G7b9 should report
        // dominantRoot=G, not C#/Db just because it is the first numeric match.
        prefer = [
            if(st[\phrasePendingDominant].notNil) { st[\phrasePendingDominant][\rootPc] } { nil },
            if(st[\phraseCurrentWorld].notNil and: { at[\familyIsDominant].(st[\phraseCurrentWorld][\family]) }) { st[\phraseCurrentWorld][\rootPc] } { nil },
            if(st[\phrasePreviousDistinctWorld].notNil and: { at[\familyIsDominant].(st[\phrasePreviousDistinctWorld][\family]) }) { st[\phrasePreviousDistinctWorld][\rootPc] } { nil },
            if(st[\phraseHomeWorld].notNil and: { at[\familyIsDominant].(st[\phraseHomeWorld][\family]) }) { st[\phraseHomeWorld][\rootPc] } { nil }
        ];
        prefer.do { |r|
            if(found.isNil and: { at[\dimSupportsDominantRoot].(pcs, r) }) { found = r; };
        };

        12.do { |r|
            if(found.isNil and: { at[\dimSupportsDominantRoot].(pcs, r) }) { found = r; };
        };
        found
    };

    at[\rawWorldSummary] = { |w|
        if(w.isNil) { nil } {
            (
                label: w[\label],
                rootPc: w[\rootPc],
                bassPc: w[\bassPc],
                family: w[\family],
                function: w[\function],
                phraseFunction: w[\phraseFunction] ? w[\function],
                inversion: w[\inversion],
                at: Main.elapsedTime
            )
        }
    };

    at[\resetPhraseTrace] = {
        st[\phraseCurrentWorld] = nil;
        st[\phrasePreviousDistinctWorld] = nil;
        st[\phraseHomeWorld] = nil;
        st[\phraseHomeConfidence] = 0.0;
        st[\phrasePendingDominant] = nil;
        st[\phrasePendingDiminished] = nil;
        st[\phraseLastResolution] = nil;
        st[\phraseFunction] = nil;
        st[\phraseFunctionConfidence] = 0.0;
        st[\phraseTags] = Array.new;
        st[\phraseLastAt] = nil;
        st[\phraseObservedSignature] = nil;
        st[\phraseObservedSince] = nil;
        st[\phraseObservedAge] = 0.0;
        st[\phraseObservedStable] = false;
    };

    at[\phraseSignatureFor] = { |w, activePcs|
        var pcs;
        pcs = (activePcs ? Array.new).sort;
        if(w.isNil) {
            "nil|" ++ pcs.asString
        } {
            (w[\label] ? "nil").asString
            ++ "|r=" ++ (w[\rootPc] ? "nil").asString
            ++ "|b=" ++ (w[\bassPc] ? "nil").asString
            ++ "|f=" ++ (w[\family] ? "nil").asString
            ++ "|i=" ++ (w[\inversion] ? "nil").asString
            ++ "|pcs=" ++ pcs.asString
        }
    };

    at[\phraseStableGate] = { |w, activePcs|
        var sig, now, since, age, minStable;
        now = Main.elapsedTime;
        minStable = cfg[\phrase][\minStableSeconds] ? 0.30;
        sig = at[\phraseSignatureFor].(w, activePcs);
        if(st[\phraseObservedSignature] != sig) {
            st[\phraseObservedSignature] = sig;
            st[\phraseObservedSince] = now;
            st[\phraseObservedAge] = 0.0;
            st[\phraseObservedStable] = false;
            (stable: false, age: 0.0, signature: sig)
        } {
            since = st[\phraseObservedSince] ? now;
            age = now - since;
            st[\phraseObservedAge] = age;
            st[\phraseObservedStable] = age >= minStable;
            (stable: st[\phraseObservedStable], age: age, signature: sig)
        }
    };

    at[\rememberPhraseWorld] = { |w|
        var summary, cur, changed, fam;
        if((cfg[\phrase][\enabled] ? true).not or: { w.isNil }) { nil } {
            summary = at[\rawWorldSummary].(w);
            cur = st[\phraseCurrentWorld];
            changed = cur.isNil or: {
                (cur[\rootPc] != summary[\rootPc]) or: {
                    (cur[\bassPc] != summary[\bassPc]) or: {
                        (cur[\family] != summary[\family]) or: { cur[\label] != summary[\label] }
                    }
                }
            };
            if(changed) {
                if(cur.notNil) { st[\phrasePreviousDistinctWorld] = cur; };
                st[\phraseCurrentWorld] = summary;
            } {
                st[\phraseCurrentWorld] = summary;
            };
            fam = summary[\family];
            if(at[\familyIsTonalRestCandidate].(fam)) {
                st[\phraseHomeWorld] = summary;
                st[\phraseHomeConfidence] = ((st[\phraseHomeConfidence] ? 0.0) + (cfg[\phrase][\homeLearnRate] ? 0.18)).clip(0.0, 1.0);
            } {
                st[\phraseHomeConfidence] = ((st[\phraseHomeConfidence] ? 0.0) - (cfg[\phrase][\homeDecay] ? 0.04)).clip(0.0, 1.0);
            };
            st[\phraseLastAt] = Main.elapsedTime;
            summary
        }
    };

    at[\resolvePhraseFunction] = { |w, activePcs|
        var fam, root, prev, prevDistinct, home, pendingDom, pendingDim, phraseFunction, confidence, tags, now, res, domRoot, colorSource, passingSource, colorWindow, passingWindow;
        if((cfg[\phrase][\enabled] ? true).not or: { w.isNil }) {
            (function: if(w.isNil) { nil } { w[\function] }, confidence: 0.0, tags: Array.new, resolution: st[\phraseLastResolution])
        } {
            fam = w[\family];
            root = w[\rootPc];
            prev = st[\phraseCurrentWorld];
            prevDistinct = st[\phrasePreviousDistinctWorld];
            home = st[\phraseHomeWorld];
            pendingDom = st[\phrasePendingDominant];
            pendingDim = st[\phrasePendingDiminished];
            phraseFunction = w[\function];
            confidence = 0.0;
            tags = Array.new;
            now = Main.elapsedTime;
            colorWindow = cfg[\phrase][\sameRootColorWindow] ? 4.0;
            passingWindow = cfg[\phrase][\passingSourceWindow] ? 5.0;
            res = nil;

            colorSource = nil;
            [prev, prevDistinct].do { |src|
                if(colorSource.isNil and: { src.notNil and: { src[\rootPc] == root and: { ((now - (src[\at] ? now)).abs <= colorWindow) and: {
                    at[\familyIsTonalRestCandidate].(src[\family]) or: { src[\family] == \context }
                } } } }) { colorSource = src; };
            };

            passingSource = nil;
            [prev, prevDistinct, home].do { |src|
                if(passingSource.isNil and: { src.notNil and: { at[\familyIsTonalRestCandidate].(src[\family]) and: { at[\nearSemitoneAbove].(src[\rootPc], root) and: {
                    ((now - (src[\at] ? now)).abs <= passingWindow)
                } } } }) { passingSource = src; };
            };

            if(pendingDom.notNil and: { (now - (pendingDom[\startedAt] ? now)) > (cfg[\phrase][\functionalResolutionWindow] ? 6.0) }) {
                st[\phrasePendingDominant] = nil;
                pendingDom = nil;
            };
            if(pendingDim.notNil and: { (now - (pendingDim[\startedAt] ? now)) > (cfg[\phrase][\passingResolutionWindow] ? 6.0) }) {
                st[\phrasePendingDiminished] = nil;
                pendingDim = nil;
            };

            if(at[\familyIsDominant].(fam)) {
                st[\phrasePendingDominant] = (
                    rootPc: root,
                    targetPc: at[\nextFifthPc].(root),
                    label: w[\label],
                    family: fam,
                    variant: w[\variant],
                    startedAt: now
                );
                if(fam == \dominantB9) {
                    phraseFunction = \dominantFunctionDiminished;
                    confidence = cfg[\phrase][\dominantFunctionDiminishedConfidence] ? 0.68;
                    tags = tags.add(\dominantB9UpperDiminished);
                } {
                    if(colorSource.notNil) {
                        phraseFunction = \colorDominantCandidate;
                        confidence = cfg[\phrase][\dominantColorConfidence] ? 0.78;
                        tags = tags.add(\sameRootColorDominant);
                    } {
                        phraseFunction = \functionalDominantCandidate;
                        confidence = cfg[\phrase][\dominantFunctionalConfidence] ? 0.74;
                        tags = tags.add(\dominantTendency);
                    };
                };
            };

            if(at[\familyIsDiminished].(fam)) {
                domRoot = at[\findDominantRootForDimPcs].(activePcs);
                if(passingSource.notNil) {
                    phraseFunction = \passingDiminishedCandidate;
                    confidence = cfg[\phrase][\passingDiminishedConfidence] ? 0.72;
                    tags = tags.add(\chromaticPassingDiminished);
                    st[\phrasePendingDiminished] = (
                        rootPc: root,
                        fromPc: passingSource[\rootPc],
                        targetPc: at[\nextStepPc].(passingSource[\rootPc]),
                        label: w[\label],
                        startedAt: now
                    );
                } {
                    if(domRoot.notNil) {
                        phraseFunction = \dominantFunctionDiminishedCandidate;
                        confidence = cfg[\phrase][\dominantFunctionDiminishedConfidence] ? 0.68;
                        tags = tags.add(\upperStructureDominantDiminished);
                        tags = tags.add((dominantRoot: domRoot));
                    };
                };
            };

            if(at[\familyIsTonalRestCandidate].(fam)) {
                if(pendingDom.notNil and: { pendingDom[\rootPc].notNil }) {
                    if(root == pendingDom[\targetPc]) {
                        res = (kind: \functionalDominant, fromPc: pendingDom[\rootPc], toPc: root, confidence: cfg[\phrase][\dominantFunctionalConfidence] ? 0.74, at: now);
                        st[\phraseLastResolution] = res;
                        st[\phrasePendingDominant] = nil;
                        tags = tags.add(\resolvedDominant);
                    } {
                        if(root == pendingDom[\rootPc]) {
                            res = (kind: \colorDominantReturn, fromPc: pendingDom[\rootPc], toPc: root, confidence: cfg[\phrase][\dominantColorConfidence] ? 0.78, at: now);
                            st[\phraseLastResolution] = res;
                            st[\phrasePendingDominant] = nil;
                            tags = tags.add(\resolvedColorDominant);
                        };
                    };
                };
                if(pendingDim.notNil and: { pendingDim[\targetPc].notNil and: { root == pendingDim[\targetPc] } }) {
                    res = (kind: \passingDiminished, fromPc: pendingDim[\fromPc], throughPc: pendingDim[\rootPc], toPc: root, confidence: cfg[\phrase][\passingDiminishedConfidence] ? 0.72, at: now);
                    st[\phraseLastResolution] = res;
                    st[\phrasePendingDiminished] = nil;
                    tags = tags.add(\resolvedPassingDiminished);
                };
            };

            if(res.notNil) { confidence = confidence.max(res[\confidence] ? 0.0); };
            (function: phraseFunction, confidence: confidence, tags: tags, resolution: st[\phraseLastResolution])
        }
    };

    at[\finalizePhraseWorld] = { |w, activePcs|
        var info, out, gate;
        if(w.isNil) { nil } {
            out = w.copy;
            gate = at[\phraseStableGate].(out, activePcs);
            out[\phraseStableAge] = gate[\age] ? 0.0;
            out[\phraseStable] = gate[\stable] ? false;

            if((cfg[\phrase][\enabled] ? true).not or: { gate[\stable] == true }) {
                info = at[\resolvePhraseFunction].(out, activePcs);
                out[\phraseFunction] = info[\function];
                out[\function] = info[\function];
                out[\phraseFunctionConfidence] = info[\confidence];
                out[\phraseTags] = info[\tags];
                out[\phraseLastResolution] = info[\resolution];
                at[\rememberPhraseWorld].(out);
            } {
                // The chord/world is still being constructed. Report the harmonic
                // family, but do not update phrase memory or resolve pending
                // dominants/diminisheds from transient subsets.
                out[\phraseFunction] = out[\function];
                out[\phraseFunctionConfidence] = 0.0;
                out[\phraseTags] = [\phraseUnstable];
                out[\phraseLastResolution] = st[\phraseLastResolution];
            };

            st[\phraseFunction] = out[\phraseFunction];
            st[\phraseFunctionConfidence] = out[\phraseFunctionConfidence];
            st[\phraseTags] = out[\phraseTags];
            out
        }
    };


    at[\worldCompactReport] = { |worlds|
        var keep, arr;
        keep = (cfg[\world][\topReportCount] ? 5).asInteger.max(1);
        arr = worlds ? Array.new;
        if(arr.isEmpty) { Array.new } {
            arr.copyRange(0, (arr.size - 1).min(keep - 1)).collect { |w|
                (
                    label: at[\worldReportLabel].(w),
                    rawLabel: w[\label],
                    rootPc: w[\rootPc],
                    bassPc: w[\bassPc],
                    inversion: w[\inversion],
                    family: w[\family],
                    function: w[\function],
                    phraseFunction: w[\phraseFunction] ? w[\function],
                    phraseFunctionConfidence: w[\phraseFunctionConfidence],
                    phraseTags: w[\phraseTags],
                    anchorPc: w[\anchorPc],
                    variant: w[\variant],
                    score: (w[\score] ? 0.0).round(0.001),
                    motion: w[\motionCostCents],
                    memory: w[\memoryCostCents],
                    held: w[\heldCostCents],
                    solvedFit: w[\solvedFitCents],
                    ratios: w[\ratioMap]
                )
            }
        }
    };

    at[\worldCompactFamilyReport] = { |worlds|
        var keep, leaders;
        keep = (cfg[\world][\familyReportCount] ? 5).asInteger.max(1);
        leaders = at[\worldFamilyLeaders].(worlds);
        if(leaders.isEmpty) { Array.new } {
            leaders.copyRange(0, (leaders.size - 1).min(keep - 1)).collect { |w|
                (
                    label: at[\worldReportLabel].(w),
                    rawLabel: w[\label],
                    rootPc: w[\rootPc],
                    bassPc: w[\bassPc],
                    inversion: w[\inversion],
                    family: w[\family],
                    function: w[\function],
                    phraseFunction: w[\phraseFunction] ? w[\function],
                    phraseFunctionConfidence: w[\phraseFunctionConfidence],
                    score: (w[\score] ? 0.0).round(0.001)
                )
            }
        }
    };

    at[\applyWorldScoringBias] = { |oldPhase, solvedPhase, reason=\resolve|
        var ev, activePcs, pcWeights, externalSources, worlds, best, prevWorld, sticky, families, ambiguityInfo, gap, ambiguity, blend, out, passiveBlend;
        if((cfg[\world][\enabled] ? true).not) {
            st[\worldEnabled] = false;
            solvedPhase;
        } {
            ev = if(at[\collectEvidence].notNil) { at[\collectEvidence].() } { st[\lastEvidence] };
            activePcs = ev[\activePcs] ? Array.new;
            pcWeights = ev[\pcWeights] ? at[\pcWeights].();
            externalSources = ev[\externalSources] ? Array.new;
            if(activePcs.size < (cfg[\world][\minActivePcs] ? 2)) {
                st[\worldEnabled] = true;
                st[\worldActiveWorld] = nil;
                st[\worldTopWorlds] = Array.new;
                st[\worldFamilyTopWorlds] = Array.new;
                st[\worldAmbiguityIndex] = 0.0;
                st[\worldScoreGap] = nil;
                st[\worldChosenAnchorPc] = nil;
                st[\worldRootPc] = nil;
                st[\worldBassPc] = nil;
                st[\worldBassMidi] = nil;
                st[\worldInversion] = nil;
                st[\worldFamily] = nil;
                st[\worldFunction] = nil;
                st[\worldLabel] = nil;
                st[\worldScore] = nil;
                st[\worldLastBlend] = 0.0;
                solvedPhase;
            } {
                worlds = at[\scoreCandidateWorlds].(activePcs, pcWeights, externalSources, oldPhase, solvedPhase, reason);
                families = at[\worldFamilyLeaders].(worlds);
                best = if(families.isEmpty) { if(worlds.isEmpty) { nil } { worlds[0] } } { families[0] };
                prevWorld = st[\worldActiveWorld];
                sticky = nil;
                if(prevWorld.notNil and: { (prevWorld[\rootPc] ? prevWorld[\anchorPc]).notNil }) {
                    families.do { |w|
                        if(((w[\rootPc] ? w[\anchorPc]) == (prevWorld[\rootPc] ? prevWorld[\anchorPc])) and: { w[\family] == prevWorld[\family] }) { sticky = w; };
                    };
                    if(sticky.notNil and: { best.notNil and: { ((best[\score] ? 0.0) - (sticky[\score] ? -999999.0)) <= (cfg[\world][\hysteresis] ? 0.35) } }) {
                        best = sticky;
                    };
                };

                if(best.isNil) {
                    solvedPhase;
                } {
                    best = at[\finalizePhraseWorld].(best, activePcs);
                    ambiguityInfo = at[\worldAmbiguityFor].(best, families, activePcs);
                    gap = ambiguityInfo[\gap] ? 999.0;
                    ambiguity = ambiguityInfo[\ambiguity] ? 0.0;
                    blend = (cfg[\world][\targetBlend] ? 0.28) * (1.0 - (ambiguity * (cfg[\world][\ambiguityBlend] ? 0.55)));
                    passiveBlend = blend * (cfg[\world][\passiveBlendScale] ? 0.12);
                    out = solvedPhase.copy;
                    cfg[\solver][\numNodes].do { |pc|
                        if(activePcs.includes(pc)) {
                            out[pc] = at[\phaseBlend].(solvedPhase[pc], best[\proposal][pc], blend);
                        } {
                            if(passiveBlend > 0.0) {
                                out[pc] = at[\phaseBlend].(solvedPhase[pc], best[\proposal][pc], passiveBlend);
                            };
                        };
                    };
                    st[\worldEnabled] = true;
                    st[\worldActiveWorld] = best.copy;
                    st[\worldTopWorlds] = at[\worldCompactReport].(worlds);
                    st[\worldFamilyTopWorlds] = at[\worldCompactFamilyReport].(worlds);
                    st[\worldAmbiguityIndex] = ambiguity;
                    st[\worldScoreGap] = gap;
                    st[\worldChosenAnchorPc] = best[\rootPc] ? best[\anchorPc];
                    st[\worldRootPc] = best[\rootPc] ? best[\anchorPc];
                    st[\worldBassPc] = best[\bassPc];
                    st[\worldBassMidi] = best[\bassMidi];
                    st[\worldInversion] = best[\inversion];
                    st[\worldFamily] = best[\family];
                    st[\worldFunction] = best[\function];
                    st[\phraseFunction] = best[\phraseFunction] ? best[\function];
                    st[\phraseFunctionConfidence] = best[\phraseFunctionConfidence] ? 0.0;
                    st[\phraseTags] = best[\phraseTags] ? Array.new;
                    st[\worldLabel] = best[\label];
                    st[\worldScore] = best[\score];
                    st[\worldLastReason] = reason;
                    st[\worldLastBlend] = blend;
                    st[\worldLastAt] = Main.elapsedTime;
                    out;
                };
            };
        };
    };

    "[at-world] optional candidate-world scoring layer v6 phrase-context-precedence loaded".postln;
};
)
