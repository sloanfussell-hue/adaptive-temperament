(
// AT_runtime.scd
// Mirror-only runtime bridge. It wraps UI snapshot refresh so the held-context and stress
// batteries can see world-shaped diagnostics, without recomputing or installing tuning.
var build, at, cfg, st, api, diag, ui, oldRefresh, oldSnapshot;

build = ~atBuild;
if(build.isNil) {
    "[at-runtime] ~atBuild missing".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    st[\runtimeRunning] = false;

    oldRefresh = api[\refreshUISnapshot];
    oldSnapshot = api[\uiSnapshot];

    api[\refreshUISnapshot] = { |force=true|
        var snap;
        if(at[\syncWorldMirrorsFromLegacy].notNil) {
            at[\syncWorldMirrorsFromLegacy].(\uiRefresh);
        };
        snap = if(oldRefresh.notNil) {
            oldRefresh.value;
        } {
            IdentityDictionary.new;
        };
        if(at[\syncWorldSnapshotFieldsInto].notNil) {
            at[\syncWorldSnapshotFieldsInto].(snap);
        };
        st[\uiSnapshotCache] = snap;
        snap
    };

    api[\uiSnapshot] = {
        if(st[\uiSnapshotCache].isNil) {
            api[\refreshUISnapshot].();
        };
        st[\uiSnapshotCache]
    };

    at[\runtimeTick] = { |dt=0.0|
        if(at[\syncWorldMirrorsFromLegacy].notNil) {
            at[\syncWorldMirrorsFromLegacy].(\runtimeTick);
        };
        nil
    };

    "[at-runtime] mirror diagnostics loaded; legacy event solver owns solve path".postln;
};
)
