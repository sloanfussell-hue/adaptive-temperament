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

    // r16e: preserve uiSnapshot(true) force semantics after the runtime mirror wrap.
    // r16d's AT_api version accepted a force argument, but this mirror-only runtime
    // bridge accidentally erased it. Diagnostics/gauntlets need forced snapshots to
    // pass through the r16d field barrier and report trueGauge/shape morph state now.
    api[\uiSnapshot] = { |force=false|
        if(force.asBoolean or: { st[\uiSnapshotCache].isNil }) {
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
