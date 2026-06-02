(
var runPath, baseDir, loadFile, initialize;
var at, cfg, st, api, diag, ui;

runPath = thisProcess.nowExecutingPath;
if(runPath.isNil) {
    Error("[at-run] AdaptiveTemperament_run.scd must be executed from a saved file").throw;
};

baseDir = PathName(runPath).pathOnly;

loadFile = { |relPath|
    var fullPath, flatPath, chosenPath;
    fullPath = baseDir +/+ relPath;
    flatPath = baseDir +/+ PathName(relPath).fileName;
    chosenPath = if(File.exists(fullPath)) {
        fullPath
    } {
        if(File.exists(flatPath)) {
            flatPath
        } {
            Error("[at-run] missing file: " ++ relPath ++ " (also tried " ++ flatPath ++ ")").throw;
        }
    };
    chosenPath.load;
    nil
};

initialize = {
    at = IdentityDictionary.new;
    cfg = IdentityDictionary.new;
    st = IdentityDictionary.new;
    api = IdentityDictionary.new;
    diag = IdentityDictionary.new;
    ui = IdentityDictionary.new;

    ~atBuild = IdentityDictionary.newFrom([
        \at, at,
        \cfg, cfg,
        \state, st,
        \api, api,
        \diag, diag,
        \ui, ui,
        \baseDir, baseDir
    ]);

    Library.put(\at, at);

    at[\cfg] = cfg;
    at[\state] = st;
    at[\st] = st;
    at[\api] = api;
    at[\diag] = diag;
    at[\ui] = ui;
    at[\baseDir] = baseDir;

    // Product boot: runtime, tones, UI, mic, signed Carry, spacing/topology guards, real-play fast path, and corrected EP source-root playback, nearest-native source-zone selection, and the v50 external-scene-truth/log-hygiene final demo layer plus v3D42 motion-rate gate and register/velocity harmonic-chart authority.
    // Deep acceptance/regression suites and old demo/test harnesses are intentionally not packaged.

    // Authoritative legacy event-driven core. World/runtime are mirror-only diagnostics.
    loadFile.("src/core/AT_config.scd");
    loadFile.("src/core/AT_state.scd");
    loadFile.("src/core/AT_helpers.scd");
    loadFile.("src/core/AT_memory.scd");
    loadFile.("src/core/AT_gravity.scd");
    loadFile.("src/core/AT_world.scd");
    loadFile.("src/core/AT_motion.scd");
    loadFile.("src/contextual/AT_evidence.scd");
    loadFile.("src/contextual/AT_worldscore.scd");
    loadFile.("src/core/AT_solver.scd");
    loadFile.("src/core/AT_render.scd");
    loadFile.("src/core/AT_input.scd");
    loadFile.("src/core/AT_diag.scd");
    loadFile.("src/core/AT_api.scd");
    loadFile.("src/core/AT_legibility.scd");
    loadFile.("src/core/AT_perceptual_coherence.scd");
    loadFile.("src/core/AT_perceptual_spectrum.scd");
    loadFile.("src/core/AT_perceptual_cylinder.scd");

    // Render profile layer: real playable tones plus reusable adaptive-tone modes.
    // Loaded after the legacy API so it can add profile setters and safely override
    // spawnVoice without touching solver/mic/gravity/memory behavior.
    // v3D16 loads registry + direct installer before sample hosts. If required
    // direct-add samples are missing and internet is available, the first-boot
    // bootstrap runs here, before the hosts scan/load buffers. This removes
    // the old manual install/reboot loop.
    loadFile.("src/render/AT_sample_source_registry.scd");
    loadFile.("src/render/AT_direct_sample_installer.scd");
    if((cfg[\render][\autoInstallDirectSamplesOnBoot] ? true) and: { api[\autoInstallDirectSamplesIfMissing].notNil }) {
        api[\autoInstallDirectSamplesIfMissing].(true, true, false);
    };
    loadFile.("src/render/profiles/AT_epiano_sample_host.scd");
    loadFile.("src/render/profiles/AT_piano_sample_host.scd");
    // Strings are intentionally external/premium/user-supplied only.
    // VSCO/free-sample and fake native string paths were rejected as too cheap.
    loadFile.("src/render/profiles/AT_render_profiles.scd");
    loadFile.("src/render/adaptive/AT_adaptive_tone.scd");
    loadFile.("src/render/AT_render_router.scd");
    loadFile.("src/render/AT_sample_tone_evidence.scd");
    loadFile.("src/render/AT_sample_acquisition.scd");
    loadFile.("src/core/AT_pitch_identity_topology.scd");
    loadFile.("src/core/AT_pitch_identity_topology_guard.scd");
    loadFile.("src/core/AT_pitch_identity_spacing_legibility.scd");
    loadFile.("src/core/AT_pitch_identity_spacing_guard.scd");



    loadFile.("src/mic/AT_mic.scd");
    // Mic Scene Model v1: the raw physical mic stream is converted into
    // persistent, classified, policy-approved acoustic pressure before it
    // reaches the harmonic field. These files intentionally load after
    // AT_mic.scd so they can wrap/override the legacy commitment layer
    // without disturbing the accepted audio/MIDI/field baseline.
    loadFile.("src/mic/AT_mic_scene.scd");
    loadFile.("src/mic/AT_mic_tracker.scd");
    loadFile.("src/mic/AT_mic_classifier.scd");
    loadFile.("src/mic/AT_mic_policy.scd");
    loadFile.("src/mic/AT_mic_external_memory.scd");
    loadFile.("src/mic/AT_mic_pressure.scd");
    loadFile.("src/mic/AT_mic_monitor.scd");
    loadFile.("src/mic/AT_mic_field_response.scd");
    loadFile.("src/mic/AT_mic_poly_response.scd");
    loadFile.("src/mic/AT_external_coherence_world_model.scd");

    // v3D27 signed carry + v3D26c real-play fast path: hard-realtime sound-first / gesture-idle deferred-heavy-solve scheduler.
    // Loaded after mic/render/solver/spacing guard and before the latency profiler
    // so the profiler measures the final live-play path.
    loadFile.("src/performance/AT_real_play_fast_path.scd");


    // Performance hardening wrappers: manual physical-room proof commands,
    // freeze/readiness report, and panic helpers. This layer does not alter
    // deterministic regression, solver, mic policy, tone engines, or UI art.
    loadFile.("src/product/AT_product_status.scd");
    loadFile.("src/product/AT_passive_harmonic_field.scd");
    loadFile.("src/product/AT_final_demo_scenario.scd");
    loadFile.("src/product/AT_performance_product_v2.scd");
    loadFile.("src/product/AT_visual_memory_gravity_bridge.scd");

    loadFile.("src/core/AT_runtime.scd");
    loadFile.("src/ui/AdaptiveTemperament_visual.scd");

    // Sound-first boot barrier. SynthDef.add is asynchronous; without a sync,
    // the MIDI path can create voices before the server knows the voice SynthDefs.
    // initialize is run inside a Routine below so this yield is legal.
    s.sync;

    at[\resetToET].();
    at[\pushBuses].();
    api[\refreshUISnapshot].();

    // MIDI must be installed after the final MIDIClient.init/connectAll step.
    // A second MIDIClient.init after MIDIIn.connectAll can leave callbacks alive
    // but sources disconnected, which looks exactly like "UI works, keys are silent".
    if(at[\installMIDI].notNil) {
        at[\installMIDI].();
    } {
        MIDIClient.init;
        MIDIIn.connectAll;
        "[at-midi] fallback MIDIClient.init + MIDIIn.connectAll".postln;
    };

    at[\start].();

    if((cfg[\ui][\openOnBoot] ? true) and: { api[\openUI].notNil }) {
        { api[\openUI].(); }.defer(0.15);
    };

    api[\refreshUISnapshot].();

    "[at] Adaptive Temperament v52c visual-control adaptive-memory-gravity bridge abnormal audit fix candidate loaded".postln;
    nil
};
"[at] Adaptive Temperament v52c visual-control adaptive-memory-gravity bridge abnormal audit fix candidate booting".postln;
s.waitForBoot({
    Routine({
        initialize.value;
        nil
    }).play(AppClock);
    nil
});
)