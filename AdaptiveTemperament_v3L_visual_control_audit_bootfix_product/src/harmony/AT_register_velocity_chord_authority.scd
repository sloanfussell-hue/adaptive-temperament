(
// AT_register_velocity_chord_authority.scd
// v2b: live chord audition bootfix: safe active-note collection for chord-internal register/velocity authority.
// This is not key detection, not chord-label logic, and not a global center.
// It decides which active note has authority inside the current active harmony.
var build, at, cfg, st, api, diag, ui, pcNames;

build = ~atBuild;

if(build.isNil) {
    "[at-register-velocity] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pcNames = at[\pitchClassNames];

    if(cfg[\solver].isNil) { cfg[\solver] = IdentityDictionary.new; };

    cfg[\solver][\registerVelocityChordAuthorityEnabled] = cfg[\solver][\registerVelocityChordAuthorityEnabled] ? true;
    cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] = cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] ? 0.46;
    cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] = cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] ? 0.54;
    cfg[\solver][\registerVelocityChordAuthorityStrength] = cfg[\solver][\registerVelocityChordAuthorityStrength] ? 0.72;
    cfg[\solver][\registerVelocityChordAuthorityMinActiveNotes] = cfg[\solver][\registerVelocityChordAuthorityMinActiveNotes] ? 3;
    cfg[\solver][\registerVelocityChordAuthorityMinContrast] = cfg[\solver][\registerVelocityChordAuthorityMinContrast] ? 0.035;
    cfg[\solver][\registerVelocityChordAuthorityMaxStepCents] = cfg[\solver][\registerVelocityChordAuthorityMaxStepCents] ? 28.0;
    cfg[\solver][\registerVelocityChordAuthorityPassiveBlend] = cfg[\solver][\registerVelocityChordAuthorityPassiveBlend] ? 0.80;

    at[\registerVelocityChordAuthorityPcName] = { |pc=0|
        var names;
        names = pcNames ? ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"];
        names[pc.asInteger % 12]
    };

    at[\registerVelocityChordAuthorityOffsetCentsForStep] = { |pcStep=0|
        var table, step;
        table = [
            0.0,
            11.731,
            3.910,
            15.641,
            -13.686,
            -1.955,
            0.0,
            1.955,
            13.686,
            -15.641,
            -3.910,
            -11.731
        ];
        step = pcStep.asInteger % 12;
        table[step]
    };

    at[\registerVelocityChordAuthorityActiveNotes] = {
        var notes;
        notes = Array.new;
        if(st[\activeNotes].notNil) {
            st[\activeNotes].values.asArray.do { |note|
                var midi, pc, vel;
                midi = (note[\midi] ? 60).asInteger;
                pc = (note[\pc] ? (midi % 12)).asInteger % 12;
                vel = (note[\velocity] ? 0.7).asFloat.clip(0.0, 1.0);
                notes = notes.add((midi: midi, pc: pc, velocity: vel, onsetTime: note[\onsetTime] ? 0.0));
            };
        };
        // v2b: do not call sortBy here. During live note-on, SuperCollider can evaluate
        // the sort key as nil for transient Event values in st[\activeNotes], causing
        // nil <= nil inside SequenceableCollection:mergeSort before the authority
        // analyzer has copied/scored the notes. Ordering is not musically authoritative;
        // register/velocity scoring below decides the winner.
        notes
    };

    at[\registerVelocityChordAuthorityAnalyze] = { |notes=nil, label=\analysis|
        var now, list, n, regAmt, velAmt, totalAmt, minMidi, maxMidi, minVel, maxVel, midiSpan, velSpan;
        var scored, best, second, contrast, uniquePcs, status, orientationOffsets, targetByPc, changedPcs;
        now = Main.elapsedTime;
        list = notes ? at[\registerVelocityChordAuthorityActiveNotes].();
        list = list.collect { |note|
            var midi, pc, vel;
            midi = (note[\midi] ? 60).asInteger;
            pc = (note[\pc] ? (midi % 12)).asInteger % 12;
            vel = (note[\velocity] ? 0.7).asFloat.clip(0.0, 1.0);
            (midi: midi, pc: pc, pcName: at[\registerVelocityChordAuthorityPcName].(pc), velocity: vel, onsetTime: note[\onsetTime] ? 0.0)
        };
        n = list.size;
        regAmt = (cfg[\solver][\registerVelocityChordAuthorityRegisterAmount] ? 0.46).asFloat.clip(0.0, 1.0);
        velAmt = (cfg[\solver][\registerVelocityChordAuthorityVelocityAmount] ? 0.54).asFloat.clip(0.0, 1.0);
        totalAmt = (regAmt + velAmt).max(0.001);
        regAmt = regAmt / totalAmt;
        velAmt = velAmt / totalAmt;
        if(n <= 0) {
            status = \noActiveNotes;
            (timestamp: now, label: label, status: status, activeCount: 0, applied: false, reason: \noActiveNotes)
        } {
            minMidi = list.collect { |x| x[\midi] }.minItem;
            maxMidi = list.collect { |x| x[\midi] }.maxItem;
            minVel = list.collect { |x| x[\velocity] }.minItem;
            maxVel = list.collect { |x| x[\velocity] }.maxItem;
            midiSpan = (maxMidi - minMidi).asFloat.max(1.0);
            velSpan = (maxVel - minVel).asFloat.max(0.0001);
            scored = list.collect { |note|
                var regNorm, velNorm, score, e;
                regNorm = ((maxMidi - note[\midi]).asFloat / midiSpan).clip(0.0, 1.0);
                velNorm = ((note[\velocity] - minVel).asFloat / velSpan).clip(0.0, 1.0);
                if((maxVel - minVel).abs <= 0.0001) { velNorm = 0.5; };
                if((maxMidi - minMidi).abs <= 0.0001) { regNorm = 0.5; };
                score = ((regNorm * regAmt) + (velNorm * velAmt) + (regNorm * 0.0001)).clip(0.0, 1.0001);
                e = note.copy;
                e[\registerNorm] = regNorm;
                e[\velocityNorm] = velNorm;
                e[\authorityScore] = score;
                e
            };
            scored = scored.sort { |a, b| (a[\authorityScore] ? 0.0) > (b[\authorityScore] ? 0.0) };
            best = scored[0];
            second = if(scored.size > 1) { scored[1] } { nil };
            contrast = (best[\authorityScore] ? 0.0) - if(second.isNil) { 0.0 } { second[\authorityScore] ? 0.0 };
            uniquePcs = list.collect { |x| x[\pc] }.as(Set).asArray.sort;
            targetByPc = IdentityDictionary.new;
            uniquePcs.do { |pc|
                targetByPc[pc] = at[\registerVelocityChordAuthorityOffsetCentsForStep].((pc.asInteger - (best[\pc] ? 0).asInteger) % 12);
            };
            changedPcs = uniquePcs.reject { |pc| pc.asInteger == (best[\pc] ? 0).asInteger };
            status = if(n < (cfg[\solver][\registerVelocityChordAuthorityMinActiveNotes] ? 3).asInteger) { \relationshipOnlyBelowActiveNegotiationThreshold } { \registerVelocityChordAuthorityResolved };
            orientationOffsets = uniquePcs.collect { |pc| [pc, targetByPc[pc] ? 0.0] };
            (
                timestamp: now,
                label: label,
                status: status,
                activeCount: n,
                activeMidis: list.collect { |x| x[\midi] },
                activePcs: uniquePcs.copy,
                activePcNames: uniquePcs.collect { |pc| at[\registerVelocityChordAuthorityPcName].(pc) },
                authorityMidi: best[\midi],
                authorityPc: best[\pc],
                authorityPcName: at[\registerVelocityChordAuthorityPcName].(best[\pc]),
                authorityVelocity: best[\velocity],
                registerAmount: regAmt,
                velocityAmount: velAmt,
                authorityScore: best[\authorityScore],
                secondAuthorityMidi: if(second.isNil) { nil } { second[\midi] },
                secondAuthorityPc: if(second.isNil) { nil } { second[\pc] },
                secondAuthorityScore: if(second.isNil) { 0.0 } { second[\authorityScore] ? 0.0 },
                authorityContrast: contrast,
                scoredNotes: scored.copy,
                orientationOffsetsByPc: orientationOffsets,
                targetByPc: targetByPc,
                changedPcs: changedPcs,
                changedPcNames: changedPcs.collect { |pc| at[\registerVelocityChordAuthorityPcName].(pc) },
                chordLocalNotKey: true,
                keyDetectionUsed: false,
                octaveAffectsAuthorityThroughRegisterOnly: true
            )
        }
    };

    api[\registerVelocityChordAuthorityReport] = { |notes=nil, label=\manual|
        var report;
        report = at[\registerVelocityChordAuthorityAnalyze].(notes, label);
        st[\lastRegisterVelocityChordAuthorityReport] = report;
        report
    };

    at[\registerVelocityChordAuthorityApply] = { |reason=\liveThreePlusActiveContext, apply=true|
        var enabled, notes, report, minNotes, n, strength, contrastScale, blend, maxStep, baseShape, targetShape, beforeShape;
        var authPc, authVal, changed, deltaArr, protectPcs, passiveBlend;
        enabled = cfg[\solver][\registerVelocityChordAuthorityEnabled] ? true;
        minNotes = (cfg[\solver][\registerVelocityChordAuthorityMinActiveNotes] ? 3).asInteger.max(3);
        notes = at[\registerVelocityChordAuthorityActiveNotes].();
        report = at[\registerVelocityChordAuthorityAnalyze].(notes, reason);
        st[\lastRegisterVelocityChordAuthorityReport] = report;
        if(enabled.not or: { (report[\activeCount] ? 0) < minNotes }) {
            report[\appliedToField] = false;
            report[\reason] = if(enabled.not) { \disabled } { \insufficientActiveContext };
            report
        } {
            if(apply.not) {
                report[\appliedToField] = false;
                report[\reason] = \reportOnly;
                report
            } {
                if(at[\livingActiveEnsureField].notNil) { at[\livingActiveEnsureField].() };
                n = cfg[\solver][\numNodes] ? 12;
                beforeShape = (st[\nodeShapeCents] ? Array.fill(n, 0.0)).copy;
                targetShape = beforeShape.copy;
                authPc = (report[\authorityPc] ? 0).asInteger % n;
                authVal = beforeShape[authPc] ? 0.0;
                strength = (cfg[\solver][\registerVelocityChordAuthorityStrength] ? 0.72).asFloat.clip(0.0, 1.0);
                contrastScale = (((report[\authorityContrast] ? 0.0) - (cfg[\solver][\registerVelocityChordAuthorityMinContrast] ? 0.035)) / 0.35).clip(0.25, 1.0);
                blend = (strength * contrastScale).clip(0.0, 1.0);
                maxStep = (cfg[\solver][\registerVelocityChordAuthorityMaxStepCents] ? 28.0).asFloat.max(0.5);
                protectPcs = report[\activePcs] ? Array.new;
                protectPcs.do { |pc|
                    var target, before, delta;
                    target = authVal + at[\registerVelocityChordAuthorityOffsetCentsForStep].((pc.asInteger - authPc) % n);
                    before = targetShape[pc.asInteger % n] ? 0.0;
                    delta = ((target - before) * blend).clip(maxStep.neg, maxStep);
                    targetShape[pc.asInteger % n] = before + delta;
                };
                if((cfg[\solver][\passiveHarmonicResponderEnabled] ? true) and: { at[\passiveHarmonicResponderTarget].notNil }) {
                    passiveBlend = (cfg[\solver][\registerVelocityChordAuthorityPassiveBlend] ? 0.80).clip(0.0, 1.0);
                    targetShape = at[\passiveHarmonicResponderTarget].(beforeShape, targetShape, protectPcs, protectPcs, passiveBlend);
                };
                st[\nodeShapeCents] = targetShape.copy;
                st[\targetNodeShapeCents] = targetShape.copy;
                deltaArr = Array.fill(n, { |i| (targetShape[i] ? 0.0) - (beforeShape[i] ? 0.0) });
                st[\nodeShapeVelocityCents] = deltaArr.copy;
                if(at[\fieldComposeFromShapeGauge].notNil) { at[\fieldComposeFromShapeGauge].() };
                st[\uiSnapshotCache] = nil;
                st[\fieldDirty] = true;
                changed = if(protectPcs.isEmpty) { 0.0 } { protectPcs.collect { |pc| ((targetShape[pc] ? 0.0) - (beforeShape[pc] ? 0.0)).abs }.maxItem ? 0.0 };
                report[\appliedToField] = true;
                report[\reason] = reason;
                report[\blend] = blend;
                report[\activeMaxDeltaCents] = changed;
                report[\passiveReport] = st[\lastPassiveHarmonicResponderReport];
                st[\lastRegisterVelocityChordAuthorityReport] = report;
                if(at[\pushBuses].notNil) { at[\pushBuses].() };
                report
            }
        }
    };

    api[\applyRegisterVelocityChordAuthorityNow] = { |reason=\manual|
        at[\registerVelocityChordAuthorityApply].(reason, true)
    };


    "[at-register-velocity] clean chord-internal register/velocity authority loaded; no key detection.".postln;
};
)
