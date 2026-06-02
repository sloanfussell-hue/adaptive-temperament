(
// AT_mic.scd
// Compatibility loader for split microphone pipeline modules.
// r17ba: loads the stable legacy detector first, then the opt-out mic-scene
// layer: persistent tracks -> classification -> policy -> pressure -> field response.
var path, dir, loadLocal;
path = thisProcess.nowExecutingPath;
if(path.isNil) {
    "[at-mic] AT_mic.scd must be loaded from a saved file.".warn;
} {
    dir = PathName(path).pathOnly;
    loadLocal = { |name|
        var full;
        full = dir +/+ name;
        if(File.exists(full)) { full.load } { Error("[at-mic] missing split module: " ++ full).throw; };
    };

    // Legacy, verified detector/commit path. Kept as fallback.
    loadLocal.("AT_mic_commit.scd");
    loadLocal.("AT_mic_roles.scd");
    loadLocal.("AT_mic_sources.scd");
    loadLocal.("AT_mic_observation.scd");
    loadLocal.("AT_mic_synth.scd");

    // r17ba scene layer. These modules do not replace the audio detector;
    // they interpret detector candidates as a musical acoustic scene.
    loadLocal.("AT_mic_scene.scd");
    loadLocal.("AT_mic_tracker.scd");
    loadLocal.("AT_mic_classifier.scd");
    loadLocal.("AT_mic_policy.scd");
    loadLocal.("AT_mic_external_memory.scd");
    loadLocal.("AT_mic_pressure.scd");
    loadLocal.("AT_mic_monitor.scd");
    loadLocal.("AT_mic_field_response.scd");
    loadLocal.("AT_mic_poly_response.scd");

    "[at-mic] legacy detector + scene mic modules loaded.".postln;
};
)
