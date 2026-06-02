(
// AT_piano_sample_host.scd
// Acoustic piano sample/model host for the piano profile.
//
// v4 correction: the Iowa Steinway B set proved too slow and too poor for this
// instrument. Do not use it as the default piano source. The piano host now
// targets Slender Salamander Grand Piano: a phase-aligned, 3-layer reduced
// version of Alexander Holm's Salamander Yamaha C5 library.
//
// This is still a sample host, not a fake synth. If samples are missing, piano
// routes to the neutral pure fallback and prints a clear command.
//
// Run after boot if samples are missing:
//   Library.at(\at)[\api][\downloadSlenderPianoSamples].();
// Then wait for curl/unzip to finish and reboot AdaptiveTemperament_run.scd.

var build, at, cfg, st, api, diag, ui;
var rootDir, sampleDir, zipPath, slots, loadedCount, requiredCount, missing, makeSlot, loadLayer;
var noteName, q, downloadUrl, downloadCommand, possibleDirs, findFile;

build = ~atBuild;

if(build.isNil) {
    "[at-piano-assets] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };

    // Slender Salamander is already edited/phase-aligned and should speak
    // immediately. Default start is zero; allow tiny trim if a controller feels
    // sluggish, but do not bake Iowa's 33ms delay into this engine.
    cfg[\render][\pianoStartFrame] = cfg[\render][\pianoStartFrame] ? 0;

    rootDir = at[\baseDir] ? (PathName(thisProcess.nowExecutingPath).pathOnly +/+ "../../..");
    sampleDir = cfg[\render][\pianoSamplesDir] ? (rootDir +/+ "samples/piano");
    cfg[\render][\pianoSamplesDir] = sampleDir;

    downloadUrl = "https://musical-artifacts.com/artifacts/534/SlenderSalamander44khz16bit.zip";
    zipPath = sampleDir +/+ "SlenderSalamander44khz16bit.zip";

    q = { |s| "\"" ++ s.asString.replace("\\", "\\\\").replace("\"", "\\\"") ++ "\"" };

    noteName = { |midi|
        var names, pc, oct;
        names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        pc = midi.asInteger % 12;
        oct = (midi.asInteger div: 12) - 1;
        names[pc] ++ oct.asString
    };

    possibleDirs = [
        sampleDir,
        sampleDir +/+ "samples",
        sampleDir +/+ "SlenderSalamander44khz16bit/samples",
        sampleDir +/+ "SlenderSalamander44khz16bit/SlenderSalamander44khz16bit/samples"
    ];

    findFile = { |fileName|
        var found;
        found = possibleDirs.detect { |dir| File.exists(dir +/+ fileName) };
        if(found.notNil) { found +/+ fileName } { sampleDir +/+ "SlenderSalamander44khz16bit/samples" +/+ fileName };
    };

    loadedCount = 0;
    requiredCount = 0;
    missing = List.new;

    makeSlot = { |rootMidi, highMidi|
        var slot, note, mk;
        note = noteName.(rootMidi);
        mk = { |suffix| note ++ suffix ++ ".wav" };
        slot = IdentityDictionary.new;
        slot[\root] = rootMidi.asInteger;
        slot[\note] = note;
        slot[\high] = highMidi.asInteger;
        slot[\rootFreq] = rootMidi.midicps;
        slot[\buffers] = IdentityDictionary.new;
        slot[\files] = IdentityDictionary.newFrom([
            \soft, mk.("v1-PA"),
            \med,  mk.("v8.5-PA"),
            \hard, mk.("v16")
        ]);
        slot[\loaded] = 0;
        slot
    };

    // Slender/Salamander roots: sampled every minor third from A0.
    slots = List.new;
    (21, 24 .. 108).do { |rootMidi, i|
        var nextRoot, highMidi;
        nextRoot = rootMidi + 3;
        highMidi = if(nextRoot <= 108) { nextRoot - 1 } { 999 };
        slots.add(makeSlot.(rootMidi, highMidi));
    };

    loadLayer = { |slot, layer|
        var path;
        requiredCount = requiredCount + 1;
        path = findFile.(slot[\files][layer]);
        if(File.exists(path)) {
            slot[\buffers][layer] = Buffer.read(s, path);
            slot[\loaded] = (slot[\loaded] ? 0) + 1;
            loadedCount = loadedCount + 1;
        } {
            missing.add(path);
        };
    };

    slots.do { |slot|
        loadLayer.(slot, \soft);
        loadLayer.(slot, \med);
        loadLayer.(slot, \hard);
    };

    at[\pianoAssets] = IdentityDictionary.new;
    at[\pianoAssets][\sampleDir] = sampleDir;
    at[\pianoAssets][\source] = \slenderSalamanderC5;
    at[\pianoAssets][\sourceName] = "Slender Salamander Grand Piano / Alexander Holm Salamander C5";
    at[\pianoAssets][\license] = "CC BY 3.0";
    at[\pianoAssets][\slots] = slots;
    at[\pianoAssets][\loadedLayerCount] = loadedCount;
    at[\pianoAssets][\requiredLayerCount] = requiredCount;
    at[\pianoAssets][\missing] = missing;
    at[\pianoAssets][\downloadUrl] = downloadUrl;
    at[\pianoAssets][\status] = if(loadedCount == requiredCount) { \complete } { if(loadedCount > 0) { \partial } { \missing } };

    at[\pianoSlotForMidi] = { |midi=60|
        var m, found;
        m = midi.asInteger.clip(0, 127);
        found = slots.detect { |slot| m <= slot[\high] };
        if(found.isNil) { slots.last } { found };
    };

    at[\pianoSlotReady] = { |slot|
        slot.notNil and: {
            slot[\buffers].notNil and: {
                slot[\buffers][\soft].notNil and: {
                    slot[\buffers][\med].notNil and: {
                        slot[\buffers][\hard].notNil
                    }
                }
            }
        }
    };

    at[\pianoAssetReport] = {
        "".postln;
        "[AT PIANO ASSET REPORT]".postln;
        ("sampleDir=" ++ sampleDir).postln;
        "source=Slender Salamander Grand Piano / Salamander C5, phase-aligned 3-layer set".postln;
        "license=CC BY 3.0; attribution required: Alexander Holm / Signal Experiments / Salamander source".postln;
        ("status=" ++ at[\pianoAssets][\status].asString
            ++ " loaded=" ++ loadedCount.asString
            ++ "/" ++ requiredCount.asString).postln;
        if(loadedCount < requiredCount) {
            "".postln;
            "Piano source samples are missing. This build does NOT use the bad Iowa set by default and does NOT generate fake piano waves.".postln;
            "To fetch the Slender Salamander C5 source, run:".postln;
            "  Library.at(\\at)[\\api][\\downloadSlenderPianoSamples].();".postln;
            "Then wait for curl/unzip to finish and reboot AdaptiveTemperament_run.scd.".postln;
            "".postln;
            ("downloadUrl=" ++ downloadUrl).postln;
            "Expected sample examples after unzip:".postln;
            "  samples/piano/SlenderSalamander44khz16bit/samples/C4v1-PA.wav".postln;
            "  samples/piano/SlenderSalamander44khz16bit/samples/C4v8.5-PA.wav".postln;
            "  samples/piano/SlenderSalamander44khz16bit/samples/C4v16.wav".postln;
        };
        at[\pianoAssets]
    };
    api[\pianoAssetReport] = { at[\pianoAssetReport].() };

    at[\pianoTimingReport] = {
        "".postln;
        "[AT PIANO TIMING REPORT]".postln;
        ("pianoStartFrame=" ++ (cfg[\render][\pianoStartFrame] ? 0).asString).postln;
        ("approxStartMs=" ++ (((cfg[\render][\pianoStartFrame] ? 0) / 44.1).round(0.1)).asString).postln;
        "Slender Salamander default is 0 ms because it should not contain the Iowa leading delay.".postln;
        "Use Library.at(\\at)[\\api][\\setPianoStartMs].(ms) only for tiny trims.".postln;
        cfg[\render][\pianoStartFrame]
    };
    api[\pianoTimingReport] = { at[\pianoTimingReport].() };

    api[\setPianoStartMs] = { |ms=0|
        var frames;
        frames = (ms.asFloat.clip(0, 40) * 44.1).round(1).asInteger;
        cfg[\render][\pianoStartFrame] = frames;
        ("[at-piano] start trim set to " ++ ms.asFloat.round(0.1).asString ++ " ms (" ++ frames.asString ++ " frames); affects new notes").postln;
        frames
    };

    downloadCommand = "mkdir -p " ++ q.(sampleDir) ++ " && curl -L --fail -o " ++ q.(zipPath) ++ " " ++ q.(downloadUrl) ++ " && unzip -o " ++ q.(zipPath) ++ " -d " ++ q.(sampleDir);

    at[\pianoDownloadCommands] = {
        "".postln;
        "[AT PIANO SLENDER DOWNLOAD COMMAND]".postln;
        downloadCommand.postln;
        downloadCommand
    };
    api[\pianoDownloadCommands] = { at[\pianoDownloadCommands].() };

    at[\downloadSlenderPianoSamples] = {
        "".postln;
        "[AT PIANO SLENDER DOWNLOAD]".postln;
        "Downloading Slender Salamander Grand Piano 44.1k/16-bit zip and unzipping into samples/piano.".postln;
        "This is a larger download; wait for curl/unzip output to finish, then reboot AdaptiveTemperament_run.scd.".postln;
        downloadCommand.unixCmd;
        "After it finishes, run AdaptiveTemperament_run.scd again, then Library.at(\\at)[\\api][\\pianoAssetReport].();".postln;
        downloadCommand
    };
    api[\downloadSlenderPianoSamples] = { at[\downloadSlenderPianoSamples].() };

    // Backward-compatible alias, but make clear Iowa is intentionally no longer
    // the default source.
    at[\downloadIowaPianoSamples] = {
        "[at-piano] Iowa is disabled as the default because it sounded late and poor here. Downloading Slender Salamander instead.".warn;
        at[\downloadSlenderPianoSamples].()
    };
    api[\downloadIowaPianoSamples] = { at[\downloadIowaPianoSamples].() };

    if(loadedCount == requiredCount) {
        ("[at-piano-assets] complete: loaded " ++ loadedCount.asString ++ " Slender Salamander C5 piano source layers from samples/piano").postln;
    } {
        ("[at-piano-assets] missing/partial: loaded " ++ loadedCount.asString ++ "/" ++ requiredCount.asString
            ++ " Slender Salamander layers from " ++ sampleDir).warn;
        "[at-piano-assets] Run: Library.at(\\at)[\\api][\\downloadSlenderPianoSamples].(); then reboot.".postln;
    };
};
)
