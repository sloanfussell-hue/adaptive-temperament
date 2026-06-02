(
// AT_helpers.scd
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at] ~atBuild missing. Load AdaptiveTemperament_run.scd.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    at[\wrap01] = { |x|
        var y;
        y = x % 1.0;
        if(y < 0.0) { y = y + 1.0; };
        y;
    };

    at[\wrapSigned] = { |x|
        var y;
        y = x % 1.0;
        if(y >= 0.5) { y = y - 1.0; };
        if(y < -0.5) { y = y + 1.0; };
        y;
    };

    at[\midiToFreq] = { |midi|
        440.0 * (2 ** ((midi - 69) / 12.0));
    };

    at[\freqToPhase] = { |freq|
        at[\wrap01].((freq / 8.1757989156).log2);
    };

    at[\maxAbs] = { |arr|
        var m;
        m = 0.0;
        (arr ? Array.new).do { |x| if(x.abs > m) { m = x.abs; }; };
        m;
    };

    at[\devArray] = {
        Array.fill(cfg[\solver][\numNodes], { |i|
            at[\wrapSigned].(st[\nodePhase][i] - st[\etPhase][i]);
        });
    };

    at[\notesArray] = {
        st[\activeNotes].values.asArray;
    };

    at[\noteAge] = { |note|
        Main.elapsedTime - (note[\onsetTime] ? note[\timestamp] ? Main.elapsedTime)
    };

    at[\pcWeightForNote] = { |note|
        var octave, reg, ageBoost;
        octave = (note[\midi] / 12).floor;
        reg = (1.15 - ((octave - 1).max(0) * 0.08)).clip(0.55, 1.15);
        ageBoost = (1.0 + (at[\noteAge].(note) / 5.0).clip(0.0, 0.25));
        (note[\velocity] * reg * ageBoost).clip(0.05, 1.7);
    };

    at[\pcWeights] = {
        var weights;
        weights = Array.fill(cfg[\solver][\numNodes], 0.0);
        at[\notesArray].().do { |note|
            var pc;
            pc = note[\pc];
            weights[pc] = weights[pc] + at[\pcWeightForNote].(note);
        };
        weights;
    };

    at[\activePcsFromWeights] = { |weights|
        var pcs;
        pcs = Array.new;
        cfg[\solver][\numNodes].do { |i|
            if((weights[i] ? 0.0) > 0.0001) { pcs = pcs.add(i); };
        };
        pcs;
    };

    at[\strongestPc] = { |pcs, weights|
        var bestPc, bestW;
        if(pcs.isNil or: { pcs.isEmpty }) { nil } {
            bestPc = pcs[0];
            bestW = weights[bestPc] ? 0.0;
            pcs.do { |pc|
                if(((weights[pc] ? 0.0) > bestW) or: { ((weights[pc] ? 0.0) == bestW) and: { pc < bestPc } }) {
                    bestPc = pc;
                    bestW = weights[pc] ? 0.0;
                };
            };
            bestPc;
        };
    };

    at[\heldAgeForPc] = { |pc|
        var maxAge;
        maxAge = 0.0;
        at[\notesArray].().do { |note|
            if(note[\pc] == pc) { maxAge = maxAge.max(at[\noteAge].(note)); };
        };
        maxAge;
    };

    at[\lowestMidiForPc] = { |pc|
        var best;
        best = nil;
        at[\notesArray].().do { |note|
            if(note[\pc] == pc) {
                if(best.isNil or: { note[\midi] < best }) { best = note[\midi] };
            };
        };
        best;
    };

    at[\chooseAnchorPc] = { |pcs, weights|
        var bestPc, bestScore, lowestMidi;
        if(pcs.isNil or: { pcs.isEmpty }) { nil } {
            lowestMidi = nil;
            at[\notesArray].().do { |note|
                if(lowestMidi.isNil or: { note[\midi] < lowestMidi }) { lowestMidi = note[\midi] };
            };
            bestPc = pcs[0];
            bestScore = -999999.0;
            pcs.do { |pc|
                var score, w, age, low, bassBonus, heldBonus, continuityBonus;
                w = (weights[pc] ? 0.0).max(0.0);
                age = at[\heldAgeForPc].(pc);
                low = at[\lowestMidiForPc].(pc);
                bassBonus = if(low.notNil and: { lowestMidi.notNil and: { low == lowestMidi } }) { 0.42 } { 0.0 };
                heldBonus = (age / 2.5).clip(0.0, 1.0) * 0.38;
                continuityBonus = if(st[\soleAnchorPc] == pc) { 0.18 } { 0.0 };
                score = w + bassBonus + heldBonus + continuityBonus;
                if((score > bestScore) or: { (score == bestScore) and: { pc < bestPc } }) {
                    bestScore = score;
                    bestPc = pc;
                };
            };
            bestPc;
        };
    };

    at[\sourceStrength] = { |src| ((src[\weight] ? 0.0) * (src[\confidence] ? 1.0)); };

    at[\sortSourcesByStrength] = { |sources|
        (sources ? Array.new).sort { |a, b| (at[\sourceStrength].(a) ? 0.0) > (at[\sourceStrength].(b) ? 0.0) };
    };

    at[\takeStrongestSources] = { |sources, count|
        var sorted, keepCount;
        sorted = at[\sortSourcesByStrength].(sources);
        keepCount = count.max(0).min(sorted.size);
        if(keepCount <= 0) { Array.new } { sorted.copyRange(0, keepCount - 1) };
    };

    at[\pcWeightsForExternalSources] = { |sources|
        var weights;
        weights = Array.fill(cfg[\solver][\numNodes], 0.0);
        (sources ? Array.new).do { |src|
            if(src.notNil and: { src[\pc].notNil }) {
                weights[src[\pc]] = weights[src[\pc]] + ((src[\weight] ? 0.0).clip(0.0, 1.5));
            };
        };
        weights;
    };

    at[\phasePoint] = { |phase, center, radius|
        var angle;
        angle = (phase * 2pi) - (pi / 2);
        Point(center.x + (radius * cos(angle)), center.y + (radius * sin(angle)));
    };
};
)
