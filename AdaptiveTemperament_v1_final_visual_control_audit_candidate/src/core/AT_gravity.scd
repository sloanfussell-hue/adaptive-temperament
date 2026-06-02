(
// AT_gravity.scd
// Soft key-center / home-field gravity.
// Gravity is independent of the microphone. It is not a scale mapper and not a
// chord recognizer. It applies a bounded global gauge pull toward a home pitch-
// class phase, preserving internal interval relationships while giving the
// floating field a gentle center of mass.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;
if(build.isNil) {
    "[at-gravity] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(cfg[\gravity].isNil) {
        cfg[\gravity] = (
            enabled: false,
            homePc: 0,
            homeCents: 0.0,
            strength: 0.18,
            maxPullCents: 6.0,
            applyWithoutActive: false,
            debug: false
        );
    };

    st[\gravityHomePc] = cfg[\gravity][\homePc] ? 0;
    st[\gravityHomeCents] = cfg[\gravity][\homeCents] ? 0.0;
    st[\gravityHomePhase] = at[\wrap01].((st[\etPhase][st[\gravityHomePc]] ? 0.0) + (st[\gravityHomeCents] / 1200.0));
    st[\gravityLastApplied] = false;
    st[\gravityLastShift] = 0.0;
    st[\gravityLastShiftCents] = 0.0;
    st[\gravityLastReason] = nil;
    st[\gravityLastActivePcs] = Array.new;

    at[\gravityNameForPc] = { |pc|
        pitchClassNames[pc % 12] ? pc.asString;
    };

    at[\setGravityHome] = { |pc=0, cents=0.0|
        pc = pc.asInteger.clip(0, 11);
        cents = cents.asFloat.clip(-1200.0, 1200.0);
        cfg[\gravity][\homePc] = pc;
        cfg[\gravity][\homeCents] = cents;
        st[\gravityHomePc] = pc;
        st[\gravityHomeCents] = cents;
        st[\gravityHomePhase] = at[\wrap01].((st[\etPhase][pc] ? (pc / 12.0)) + (cents / 1200.0));
        st[\gravityLastReason] = \setHome;
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\gravityHome); };
        st[\gravityHomePhase];
    };

    at[\clearGravity] = {
        cfg[\gravity][\enabled] = false;
        st[\gravityLastApplied] = false;
        st[\gravityLastShift] = 0.0;
        st[\gravityLastShiftCents] = 0.0;
        st[\gravityLastReason] = \clear;
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\gravityClear); };
    };

    at[\applyGravityBias] = { |evidencePhase, activePcs=nil, reason=\solve|
        var gcfg, homePc, homePhase, pcs, strength, maxPull, diff, step, out, allowed;
        gcfg = cfg[\gravity] ? ();
        if((gcfg[\enabled] ? false).not) {
            st[\gravityLastApplied] = false;
            st[\gravityLastShift] = 0.0;
            st[\gravityLastShiftCents] = 0.0;
            st[\gravityLastReason] = \disabled;
            evidencePhase;
        } {
            pcs = activePcs ? Array.new;
            allowed = pcs.notEmpty or: { gcfg[\applyWithoutActive] ? false };
            if(allowed.not) {
                st[\gravityLastApplied] = false;
                st[\gravityLastShift] = 0.0;
                st[\gravityLastShiftCents] = 0.0;
                st[\gravityLastReason] = \noActiveEvidence;
                evidencePhase;
            } {
                homePc = st[\gravityHomePc] ? (gcfg[\homePc] ? 0);
                homePhase = st[\gravityHomePhase] ? at[\wrap01].((st[\etPhase][homePc] ? (homePc / 12.0)) + ((gcfg[\homeCents] ? 0.0) / 1200.0));
                strength = (gcfg[\strength] ? 0.18).clip(0.0, 1.0);
                maxPull = ((gcfg[\maxPullCents] ? 6.0) / 1200.0).max(0.0);

                // Global gauge pull: move the whole field together toward the
                // home phase. This gives key-center gravity without changing
                // the internal chord/ratio shape created by the free core.
                diff = at[\wrapSigned].(homePhase - evidencePhase[homePc]);
                step = (diff * strength).clip(maxPull.neg, maxPull);
                out = evidencePhase.collect { |p| at[\wrap01].(p + step) };

                st[\gravityLastApplied] = step.abs > 0.0000001;
                st[\gravityLastHomePc] = homePc;
                st[\gravityLastHomePhase] = homePhase;
                st[\gravityLastHomeCents] = st[\gravityHomeCents] ? (gcfg[\homeCents] ? 0.0);
                st[\gravityLastShift] = step;
                st[\gravityLastShiftCents] = step * 1200.0;
                st[\gravityLastDistanceToHomeCents] = diff * 1200.0;
                st[\gravityLastActivePcs] = pcs.copy;
                st[\gravityLastReason] = reason;
                st[\gravityLastAt] = Main.elapsedTime;
                if(gcfg[\debug] ? false) {
                    ("[at-gravity] home=" ++ at[\gravityNameForPc].(homePc) ++ " shift=" ++ (step * 1200.0).round(0.01).asString ++ "c reason=" ++ reason.asString).postln;
                };
                out;
            };
        };
    };

    api[\setGravityEnabled] = { |flag=true|
        cfg[\gravity][\enabled] = flag.asBoolean;
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\gravityEnabled); };
        if(api[\resolveNow].notNil) { api[\resolveNow].(\gravityEnabled); };
        cfg[\gravity][\enabled];
    };

    api[\setGravityHome] = { |pc=0, cents=0.0|
        at[\setGravityHome].(pc, cents);
        if(api[\resolveNow].notNil) { api[\resolveNow].(\gravityHome); };
        st[\gravityHomePhase];
    };

    api[\setGravityStrength] = { |x=0.18|
        cfg[\gravity][\strength] = x.asFloat.clip(0.0, 1.0);
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\gravityStrength); };
        if(api[\resolveNow].notNil) { api[\resolveNow].(\gravityStrength); };
        cfg[\gravity][\strength];
    };

    api[\setGravityMaxPullCents] = { |x=6.0|
        cfg[\gravity][\maxPullCents] = x.asFloat.clip(0.0, 120.0);
        if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\gravityMaxPull); };
        cfg[\gravity][\maxPullCents];
    };

    api[\gravityReport] = {
        var rep, pc;
        pc = st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? 0);
        rep = (
            enabled: cfg[\gravity][\enabled] ? false,
            homePc: pc,
            homeName: at[\gravityNameForPc].(pc),
            homeCents: st[\gravityHomeCents] ? (cfg[\gravity][\homeCents] ? 0.0),
            homePhase: st[\gravityHomePhase],
            strength: cfg[\gravity][\strength] ? 0.0,
            maxPullCents: cfg[\gravity][\maxPullCents] ? 0.0,
            lastApplied: st[\gravityLastApplied] ? false,
            lastShiftCents: (st[\gravityLastShiftCents] ? 0.0).round(0.01),
            lastDistanceToHomeCents: (st[\gravityLastDistanceToHomeCents] ? 0.0).round(0.01),
            lastReason: st[\gravityLastReason],
            lastActivePcs: st[\gravityLastActivePcs] ? Array.new
        );
        rep.postln;
        rep;
    };

    at[\gravityReport] = { api[\gravityReport].(); };

    "[at-gravity] soft key-center gravity loaded; disabled by default".postln;
};
)
