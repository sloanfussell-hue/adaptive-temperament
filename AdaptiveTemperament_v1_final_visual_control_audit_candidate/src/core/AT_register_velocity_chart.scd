(
// AT_register_velocity_chart.scd — v63 chord-local register/velocity harmonic chart selector.
// Core behavior: active chord tones choose a local harmonic basis from register
// and velocity authority. This is not key detection and does not add pitch
// authority; it changes the internal active-chord source weights used by the
// solver once a chart is selected.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[AT REGISTER/VELOCITY CHART] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(cfg[\registerVelocity].isNil) {
        cfg[\registerVelocity] = (
            enabled: true,
            registerAmount: 1.0,
            velocityAmount: 1.0,
            registerSpanSemitones: 16.0,
            velocityCurve: 1.25,
            continuityBonus: 0.04,
            selectedBasisWeight: 1.65,
            nonBasisWeight: 1.0,
            samePcReinforcement: 0.18,
            decisionMargin: 0.035,
            tieBreak: \register,
            postProfiles: false
        );
    };

    at[\registerVelocityNormalizeNotes] = { |notes=nil|
        var src, arr;
        src = notes ? at[\notesArray].();
        arr = Array.new;
        (src ? Array.new).do { |n|
            var midi, vel, pc;
            if(n.notNil) {
                midi = n[\midi] ? 60;
                vel = (n[\velocity] ? n[\vel] ? 0.7).clip(0.0, 1.0);
                pc = n[\pc] ? (midi % 12);
                arr = arr.add((midi: midi, velocity: vel, pc: pc));
            };
        };
        arr;
    };

    at[\registerVelocityAnalyzeNotes] = { |notes=nil, scenario=\current, post=false|
        var rcfg, noteArr, pcs, lowestMidi, highestVel, span, regAmount, velAmount, velCurve, margin, tieBreak;
        var profiles, bestPc, bestScore, bestReg, bestVel, registerWinnerPc, velocityWinnerPc, registerBest, velocityBest;
        var selectedName, registerWinnerName, velocityWinnerName, reason, report;

        rcfg = cfg[\registerVelocity] ? ();
        noteArr = at[\registerVelocityNormalizeNotes].(notes);
        pcs = noteArr.collect { |n| n[\pc] }.as(Set).asArray.sort;

        if(noteArr.isEmpty or: { pcs.isEmpty }) {
            report = (
                version: \v63b_registerVelocityChordAuthority,
                status: \noActiveChord,
                scenario: scenario,
                chordLocalOnly: true,
                keyDetection: false,
                selectedPc: nil,
                selectedName: \none,
                activePcs: Array.new,
                profiles: Array.new,
                pitchAuthorityAdded: false
            );
            if(post == true) {
                "[AT REGISTER/VELOCITY CHART] status=noActiveChord chordLocalOnly=true keyDetection=false".postln;
            };
            st[\lastRegisterVelocityChartReport] = report;
            report;
        } {
            lowestMidi = noteArr.collect { |n| n[\midi] }.minItem;
            highestVel = noteArr.collect { |n| n[\velocity] }.maxItem.max(0.0001);
            span = (rcfg[\registerSpanSemitones] ? 16.0).max(1.0);
            regAmount = (rcfg[\registerAmount] ? 1.0).clip(0.0, 4.0);
            velAmount = (rcfg[\velocityAmount] ? 1.0).clip(0.0, 4.0);
            velCurve = (rcfg[\velocityCurve] ? 1.25).clip(0.2, 4.0);
            margin = (rcfg[\decisionMargin] ? 0.035).abs;
            tieBreak = rcfg[\tieBreak] ? \register;

            profiles = Array.new;
            bestPc = pcs[0];
            bestScore = -999999.0;
            bestReg = -999999.0;
            bestVel = -999999.0;

            pcs.do { |pc|
                var pcNotes, low, maxVel, count, registerScore, velocityScore, continuity, samePcReinforcement, score, profile;
                pcNotes = noteArr.select { |n| n[\pc] == pc };
                low = pcNotes.collect { |n| n[\midi] }.minItem;
                maxVel = pcNotes.collect { |n| n[\velocity] }.maxItem;
                count = pcNotes.size;
                registerScore = ((lowestMidi + span - low) / span).clip(0.0, 1.0);
                velocityScore = ((maxVel / highestVel).clip(0.0, 1.0) ** velCurve).clip(0.0, 1.0);
                continuity = if(st[\lastRegisterVelocitySelectedPc] == pc) { rcfg[\continuityBonus] ? 0.0 } { 0.0 };
                samePcReinforcement = ((count - 1).max(0) * (rcfg[\samePcReinforcement] ? 0.18)).clip(0.0, 0.5);
                score = (regAmount * registerScore) + (velAmount * velocityScore) + continuity + samePcReinforcement;
                profile = (
                    pc: pc,
                    name: pitchClassNames[pc],
                    lowestMidi: low,
                    maxVelocity: maxVel.round(0.001),
                    voiceCount: count,
                    registerScore: registerScore.round(0.001),
                    velocityScore: velocityScore.round(0.001),
                    score: score.round(0.001)
                );
                profiles = profiles.add(profile);

                if(
                    (score > (bestScore + margin)) or: {
                        ((score - bestScore).abs <= margin) and: {
                            if(tieBreak == \velocity) {
                                velocityScore > bestVel
                            } {
                                registerScore > bestReg
                            }
                        }
                    }
                ) {
                    bestPc = pc;
                    bestScore = score;
                    bestReg = registerScore;
                    bestVel = velocityScore;
                };
            };

            registerWinnerPc = profiles[0][\pc];
            velocityWinnerPc = profiles[0][\pc];
            registerBest = -999999.0;
            velocityBest = -999999.0;
            profiles.do { |p|
                if((p[\registerScore] ? 0.0) > registerBest) {
                    registerBest = p[\registerScore] ? 0.0;
                    registerWinnerPc = p[\pc];
                };
                if((p[\velocityScore] ? 0.0) > velocityBest) {
                    velocityBest = p[\velocityScore] ? 0.0;
                    velocityWinnerPc = p[\pc];
                };
            };

            selectedName = pitchClassNames[bestPc];
            registerWinnerName = pitchClassNames[registerWinnerPc];
            velocityWinnerName = pitchClassNames[velocityWinnerPc];
            reason = if((bestPc == registerWinnerPc) and: { bestPc == velocityWinnerPc }) {
                \registerVelocityAgree
            } {
                if(bestPc == registerWinnerPc) {
                    \registerDominates
                } {
                    if(bestPc == velocityWinnerPc) { \velocityDominates } { \coherenceTieBreak }
                }
            };

            report = (
                version: \v63b_registerVelocityChordAuthority,
                status: \ok,
                scenario: scenario,
                chordLocalOnly: true,
                keyDetection: false,
                selectedPc: bestPc,
                selectedName: selectedName,
                selectedChart: selectedName,
                reason: reason,
                registerWinnerPc: registerWinnerPc,
                registerWinnerName: registerWinnerName,
                velocityWinnerPc: velocityWinnerPc,
                velocityWinnerName: velocityWinnerName,
                registerAmount: regAmount,
                velocityAmount: velAmount,
                activePcs: pcs.copy,
                profiles: profiles,
                normalizedSolveWeights: nil,
                pitchAuthorityAdded: false
            );

            st[\lastRegisterVelocitySelectedPc] = bestPc;
            st[\lastRegisterVelocityChartReport] = report;

            if(post == true) {
                "".postln;
                ("[AT REGISTER/VELOCITY CHART] status=ok scenario=" ++ scenario.asString
                    ++ " selectedChart=" ++ selectedName.asString
                    ++ " reason=" ++ reason.asString
                    ++ " registerWinner=" ++ registerWinnerName.asString
                    ++ " velocityWinner=" ++ velocityWinnerName.asString
                    ++ " registerAmount=" ++ regAmount.round(0.001).asString
                    ++ " velocityAmount=" ++ velAmount.round(0.001).asString
                    ++ " chordLocalOnly=true keyDetection=false pitchAuthorityAdded=false").postln;
                if((rcfg[\postProfiles] ? false) or: { post == \verbose }) {
                    profiles.do { |p|
                        ("[AT REGISTER/VELOCITY PROFILE] pc=" ++ (p[\name] ? \none).asString
                            ++ " lowestMidi=" ++ (p[\lowestMidi] ? \none).asString
                            ++ " maxVelocity=" ++ (p[\maxVelocity] ? 0.0).asString
                            ++ " registerScore=" ++ (p[\registerScore] ? 0.0).asString
                            ++ " velocityScore=" ++ (p[\velocityScore] ? 0.0).asString
                            ++ " score=" ++ (p[\score] ? 0.0).asString).postln;
                    };
                };
            };
            report;
        };
    };

    at[\registerVelocityChartWeights] = { |activePcs, rawWeights, report=nil|
        var rcfg, weights, selectedPc, basisW, otherW;
        rcfg = cfg[\registerVelocity] ? ();
        if((rcfg[\enabled] ? true).not or: { (activePcs ? Array.new).size < 2 }) {
            rawWeights;
        } {
            selectedPc = if(report.notNil) { report[\selectedPc] } { nil };
            if(selectedPc.isNil) { selectedPc = at[\registerVelocityAnalyzeNotes].(nil, \liveChord, false)[\selectedPc] };
            if(selectedPc.isNil) {
                rawWeights;
            } {
                basisW = (rcfg[\selectedBasisWeight] ? 1.65).clip(0.2, 4.0);
                otherW = (rcfg[\nonBasisWeight] ? 1.0).clip(0.05, 4.0);
                weights = Array.fill(cfg[\solver][\numNodes], 0.0);
                (activePcs ? Array.new).do { |pc|
                    weights[pc] = if(pc == selectedPc) { basisW } { otherW };
                };
                if(report.notNil) { report[\normalizedSolveWeights] = weights.copy; st[\lastRegisterVelocityChartReport] = report; };
                weights;
            };
        };
    };

    api[\setRegisterVelocityAuthority] = { |registerAmount=1.0, velocityAmount=1.0|
        var rcfg;
        rcfg = cfg[\registerVelocity] ? ();
        rcfg[\registerAmount] = registerAmount.clip(0.0, 4.0);
        rcfg[\velocityAmount] = velocityAmount.clip(0.0, 4.0);
        cfg[\registerVelocity] = rcfg;
        ("[AT REGISTER/VELOCITY AUTHORITY] registerAmount=" ++ rcfg[\registerAmount].round(0.001).asString
            ++ " velocityAmount=" ++ rcfg[\velocityAmount].round(0.001).asString
            ++ " chordLocalOnly=true keyDetection=false").postln;
        if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        rcfg;
    };
    at[\setRegisterVelocityAuthority] = { |registerAmount=1.0, velocityAmount=1.0| api[\setRegisterVelocityAuthority].(registerAmount, velocityAmount); };

    api[\registerVelocityChartReport] = { |post=true|
        at[\registerVelocityAnalyzeNotes].(nil, \current, post);
    };
    at[\registerVelocityChartReport] = { |post=true| api[\registerVelocityChartReport].(post); };



    "[AT REGISTER/VELOCITY CHART] v63b loaded: chord-local register/velocity harmonic chart authority; no key detection".postln;
};
)
