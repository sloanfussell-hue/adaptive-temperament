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
        \ui, ui
    ]);

    Library.put(\at, at);
    ~at = at;
    ~atApi = api;

    at[\cfg] = cfg;
    at[\state] = st;
    at[\st] = st;
    at[\api] = api;
    at[\diag] = diag;
    at[\ui] = ui;

    loadFile.("src/config/AT_config.scd");
    loadFile.("src/core/AT_state.scd");
    loadFile.("src/core/AT_helpers.scd");
    loadFile.("src/core/AT_field.scd");
    loadFile.("src/gravity/AT_gravity.scd");
    loadFile.("src/harmony/AT_memory.scd");
    loadFile.("src/diagnostics/AT_world_mirror.scd");
    loadFile.("src/harmony/AT_pitch_identity_runtime_guard.scd");
    loadFile.("src/harmony/AT_solver.scd");
    loadFile.("src/harmony/AT_solver_external_roles.scd");
    loadFile.("src/harmony/AT_solver_sources.scd");
    loadFile.("src/harmony/AT_solver_forces.scd");
    loadFile.("src/harmony/AT_solver_body.scd");
    loadFile.("src/harmony/AT_solver_transport.scd");
    loadFile.("src/harmony/AT_living_active_field.scd");
    loadFile.("src/harmony/AT_global_motion_rate_gate.scd");
    loadFile.("src/harmony/AT_musical_surface_contract.scd");
    loadFile.("src/harmony/AT_register_velocity_chord_authority.scd");
    loadFile.("src/harmony/AT_musical_gauge_authority.scd");
    loadFile.("src/harmony/AT_perceptual_roughness.scd");
    loadFile.("src/harmony/AT_perceptual_spectra.scd");
    loadFile.("src/harmony/AT_perceptual_cylinder.scd");
    loadFile.("src/harmony/AT_actual_spectrum.scd");
    loadFile.("src/core/AT_render.scd");
    loadFile.("src/core/AT_input.scd");
    loadFile.("src/api/AT_api.scd");
    loadFile.("src/api/AT_visual_tension_timbre.scd");
    loadFile.("src/api/AT_adaptive_timbre_presets.scd");
    loadFile.("src/api/AT_memory_gravity_adaptation.scd");
    loadFile.("src/mic/AT_mic.scd");
    loadFile.("src/mic/AT_external_coherence_world_model.scd");
    loadFile.("src/diagnostics/AT_runtime_mirror.scd");
    loadFile.("src/diagnostics/AT_runtime_performance_hardening.scd");
    loadFile.("src/core/AT_scheduler.scd");
    loadFile.("src/ui/AdaptiveTemperament_visual.scd");
    loadFile.("src/api/AT_final_demo_scenario.scd");
    loadFile.("src/api/AT_visual_full_system_control_audit.scd");

    if(api[\applyPerformanceProfile].notNil) { api[\applyPerformanceProfile].(\expressive); };
    at[\resetToET].();
    api[\refreshUISnapshot].();
    if(api[\connectMIDI].notNil) { api[\connectMIDI].() };
    AppClock.sched(0.75, { if(api[\connectMIDI].notNil) { api[\connectMIDI].() }; nil });
    at[\start].();
    api[\refreshUISnapshot].();

    AppClock.sched(0.20, {
        if(api[\openUI].notNil) {
            api[\openUI].();
        } {
            "[at-run] openUI API missing after boot; visual not opened".warn;
        };
        nil
    });

    "[at] Adaptive Temperament v3L visual control audit bootfix product loaded: frozen v3J Memory/Gravity source order retained; visual control coverage audit available.".postln;
    nil
};

"[at] Adaptive Temperament v3L visual control audit bootfix product booting".postln;
s.waitForBoot({
    initialize.value;
    nil
});
)
