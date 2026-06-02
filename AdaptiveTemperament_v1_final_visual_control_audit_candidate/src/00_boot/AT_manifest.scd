(
// AT_manifest.scd — v1 final visual control audit candidate manifest.
// Audit candidate branch: final keeper plus one optional visual-control audit module; no tests, no historical release docs.


~atBoot = { |baseDir, openUI=true, autoDemo=false|
    var at, cfg, st, api, diag, ui, load, path, files;

    at = IdentityDictionary.new;
    cfg = IdentityDictionary.new;
    st = IdentityDictionary.new;
    api = IdentityDictionary.new;
    diag = IdentityDictionary.new;
    ui = IdentityDictionary.new;

    at[\baseDir] = baseDir;
    at[\cfg] = cfg;
    at[\state] = st;
    at[\api] = api;
    at[\API] = api;
    at[\diag] = diag;
    at[\ui] = ui;
    at[\pitchClassNames] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    ~atBuild = (at: at, cfg: cfg, state: st, api: api, diag: diag, ui: ui);
    ~at = at;
    Library.put(\at, at);

    load = { |rel|
        path = baseDir +/+ rel;
        if(File.exists(path)) {
            path.load;
        } {
            ("[AT boot] missing module: " ++ rel).warn;
        };
    };

    files = [
        "src/00_boot/AT_config.scd",
        "src/00_boot/AT_state.scd",

        "src/core/AT_helpers.scd",
        "src/core/AT_register_velocity_chart.scd",
        "src/core/AT_diag.scd",
        "src/core/AT_memory.scd",
        "src/core/AT_gravity.scd",
        "src/core/AT_world.scd",
        "src/core/AT_motion.scd",
        "src/core/AT_evidence.scd",
        "src/core/AT_worldscore.scd",
        "src/core/AT_legibility.scd",
        "src/core/AT_perceptual_coherence.scd",
        "src/core/AT_perceptual_spectrum.scd",
        "src/core/AT_perceptual_cylinder.scd",
        "src/core/AT_solver.scd",

        "src/render/AT_sample_source_registry.scd",
        "src/render/AT_direct_sample_installer.scd",
        "src/render/AT_epiano_sample_host.scd",
        "src/render/AT_piano_sample_host.scd",
        "src/render/AT_render.scd",
        "src/render/AT_render_profiles.scd",
        "src/render/AT_adaptive_tone.scd",
        "src/render/AT_render_router.scd",
        "src/render/AT_sample_tone_evidence.scd",
        "src/render/AT_sample_acquisition.scd",

        "src/mic/AT_mic_scene.scd",
        "src/mic/AT_mic_tracker.scd",
        "src/mic/AT_mic_classifier.scd",
        "src/mic/AT_mic_policy.scd",
        "src/mic/AT_mic_external_memory.scd",
        "src/mic/AT_mic_pressure.scd",
        "src/mic/AT_mic_monitor.scd",
        "src/mic/AT_mic_field_response.scd",
        "src/mic/AT_mic_poly_response.scd",
        "src/mic/AT_mic.scd",
        "src/mic/AT_external_coherence_scene_engine.scd",

        "src/demo/AT_external_stimulus.scd",
        "src/demo/AT_external_stimulus_scenarios.scd",


        "src/core/AT_runtime.scd",
        "src/core/AT_input.scd",
        "src/core/AT_api.scd",
        "src/ui/AdaptiveTemperament_visual.scd",
        "src/demo/AT_final_instrument_demo.scd",
        "src/audit/AT_final_visual_control_audit.scd"
    ];

    files.do { |rel| load.(rel) };

    // Final demo APIs are defined by AT_final_instrument_demo.scd.

    "[at] Adaptive Temperament v1 final visual control audit candidate loaded".postln;

    if(openUI == true and: { api[\openUI].notNil }) {
        api[\openUI].();
    };

    if(autoDemo == true and: { api[\runFinalInstrumentDemo].notNil }) {
        {
            "[AT FINAL INSTRUMENT DEMO AUTORUN] starting official final instrument demonstration via Routine (explicit autoDemo=true)".postln;
            api[\runFinalInstrumentDemo].();
        }.defer(1.5);
    };

    at
};
)
