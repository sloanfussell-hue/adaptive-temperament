(
// AT_diag.scd — v67b final product diagnostics only.
// Minimal logging/state inspection kept for runtime support; no regression suites or test harnesses.
var build, at, cfg, st, api, diag, ui;

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

    diag[\log] = { |msg|
        if(st[\logEnabled]) {
            ("[AT] " ++ msg).postln;
        };
    };

    diag[\dumpState] = {
        var snap;
        snap = if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { st.copy };
        "--- Adaptive Temperament State ---".postln;
        snap.keysValuesDo { |k, v|
            (k.asString ++ ": " ++ v.asString).postln;
        };
        snap;
    };

    at[\debugState] = { diag[\dumpState].(); };
    at[\reset] = { if(api[\reset].notNil) { api[\reset].() } };
    at[\hardReset] = { if(api[\hardReset].notNil) { api[\hardReset].() } };

    "[at-diag] final product diagnostics loaded".postln;
};
)
