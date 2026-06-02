(
// AT_epiano_sample_host.scd
// Real electric-piano sample host for the electricPiano profile.
// v3D38 preserves the jRhodes3d source-root pitch fix and also selects
// EP keygroups by nearest native source-root zones. EP_### file tags are
// AT selection/keygroup tags; sourceRoot is the native pitch of the copied
// jRhodes source file used for PlayBuf rate calculation.
// This file intentionally does not synthesize fake Rhodes source material.
// v6 ships samples/epiano populated with a cleaned mda ePiano-derived
// open-source electric-piano floor. The v6 source assets are de-barked and
// mellowed to target a cleaner modern/classic Rhodes direction rather than
// the crunchier Wurlitzer-like edge of the raw floor.
// User-owned high-quality Rhodes/electric-piano samples can replace those files
// using the same filenames printed by Library.at(\at)[\api][\epianoAssetReport].();
// v3D15b also accepts .flac keygroups produced directly from jRhodes3d,
// so the direct installer can add real Rhodes material without fake synthesis
// or fragile external audio converters.
//
// mda source notice: mda VST plug-ins, Copyright (c) 2008 Paul Kellett.
// The mda sources are released under the MIT license or GPL v2-or-later.
// The bundled WAV anchors are derived from that open-source mda ePiano data,
// post-processed for a cleaner Rhodes-style floor, and included as fallback
// source material, not as a flagship final Rhodes capture.
// MIT notice retained: Permission is hereby granted, free of charge, to any
// person obtaining a copy of this software and associated documentation files
// to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, subject to inclusion of the copyright and
// permission notice. THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

var build, at, cfg, st, api, diag, ui;
var rootDir, sampleDir, slots, loadedCount, requiredCount, missing, makeSlot, loadLayer;

build = ~atBuild;

if(build.isNil) {
    "[at-epiano-assets] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };

    rootDir = at[\baseDir] ? (PathName(thisProcess.nowExecutingPath).pathOnly +/+ "../../..");
    sampleDir = cfg[\render][\epianoSamplesDir] ? (rootDir +/+ "samples/epiano");
    cfg[\render][\epianoSamplesDir] = sampleDir;

    loadedCount = 0;
    requiredCount = 0;
    missing = List.new;

    makeSlot = { |keygroupRootMidi, highMidi, sourceRootMidi, sourceStem, legacyHighMidi=nil|
        var tag, slot, targetRoot, nativeRoot, legacyHigh;
        targetRoot = keygroupRootMidi.asInteger;
        nativeRoot = (sourceRootMidi ? keygroupRootMidi).asInteger;
        legacyHigh = (legacyHighMidi ? highMidi).asInteger;
        tag = targetRoot.asString;
        if(targetRoot < 100) { tag = "0" ++ tag; };
        if(targetRoot < 10) { tag = "0" ++ tag; };
        slot = IdentityDictionary.new;

        // root is retained as the AT keygroup/tag root for compatibility with
        // existing reports.  sourceRoot is the actual native pitch of the
        // jRhodes3d file copied into that keygroup.  PlayBuf must use
        // sourceRoot.midicps as rootFreq; otherwise some chromatic neighbors
        // collapse, e.g. Eb4 and E4 can both land near D4.
        slot[\root] = targetRoot;
        slot[\keygroupRoot] = targetRoot;
        slot[\sourceRoot] = nativeRoot;
        slot[\sourceStem] = sourceStem ? ("A_" ++ nativeRoot.asString);
        // high is the performance-selection upper bound. v3D38 uses nearest
        // native source-root midpoints, not the older EP_### keygroup midpoint.
        // This keeps chromatic neighbors such as Eb/E in the same native source
        // zone when appropriate and reduces timbre/inharmonicity seams that can
        // be perceived as bad pitch even when the playback rate is correct.
        slot[\high] = highMidi.asInteger;
        slot[\nativeZoneHigh] = highMidi.asInteger;
        slot[\legacyKeygroupHigh] = legacyHigh;
        slot[\zoneBoundaryPolicy] = \nearestNativeSourceRootMidpoints;
        slot[\rootFreq] = nativeRoot.midicps;
        slot[\keygroupRootFreq] = targetRoot.midicps;
        slot[\sourceRootFreq] = nativeRoot.midicps;
        slot[\formerWrongRootErrorCents] = ((nativeRoot - targetRoot) * 100).asInteger;
        slot[\rootSemantics] = \jRhodes3dNearestNativeSourceZone;
        slot[\buffers] = IdentityDictionary.new;
        slot[\fileStems] = IdentityDictionary.newFrom([
            \soft, "EP_" ++ tag ++ "_soft",
            \med,  "EP_" ++ tag ++ "_med",
            \hard, "EP_" ++ tag ++ "_hard"
        ]);
        slot[\files] = IdentityDictionary.newFrom([
            \soft, "EP_" ++ tag ++ "_soft.wav",
            \med,  "EP_" ++ tag ++ "_med.wav",
            \hard, "EP_" ++ tag ++ "_hard.wav"
        ]);
        slot[\loaded] = 0;
        slot
    };

    slots = [
        // v3D38 high bounds are nearest-source-root midpoint zones:
        // 35/45=>40, 45/50=>47, 50/55=>52, 55/59=>57, 59/65=>62,
        // 65/71=>68, 71/81=>76, 81/86=>83, 86/91=>88, 91/96=>93.
        // The final argument is the old keygroup high retained for diagnosis.
        makeSlot.(36, 40, 35, "A_035__B1", 39),
        makeSlot.(43, 47, 45, "A_045__A2", 45),
        makeSlot.(48, 52, 50, "A_050__D3", 51),
        makeSlot.(55, 57, 55, "A_055__G3", 57),
        makeSlot.(60, 62, 59, "A_059__B3", 63),
        makeSlot.(67, 68, 65, "A_065__F4", 69),
        makeSlot.(72, 76, 71, "A_071__B4", 75),
        makeSlot.(79, 83, 81, "A_081__A5", 81),
        makeSlot.(84, 88, 86, "A_086__D6", 87),
        makeSlot.(91, 93, 91, "A_091__G6", 93),
        makeSlot.(96, 999, 96, "A_096__C7", 999)
    ];

    loadLayer = { |slot, layer|
        var path, stem, candidates, found;
        requiredCount = requiredCount + 1;
        stem = slot[\fileStems][layer];
        candidates = [slot[\files][layer], stem ++ ".flac"];
        found = candidates.detect { |fn| File.exists(sampleDir +/+ fn) };
        if(found.notNil) {
            path = sampleDir +/+ found;
            // Read channel 0 only. Stereo DI/cab support can be added later, but mono
            // dry anchors are the correct first source layer for Adaptive Temperament.
            // Buffer.readChannel can read WAV and, on normal SuperCollider/libsndfile
            // builds, FLAC. v3D15 uses this to route jRhodes3d directly.
            slot[\buffers][layer] = Buffer.readChannel(s, path, channels: [0]);
            slot[\loaded] = (slot[\loaded] ? 0) + 1;
            loadedCount = loadedCount + 1;
        } {
            missing.add(sampleDir +/+ slot[\fileStems][layer] ++ ".wav or .flac");
        };
    };

    slots.do { |slot|
        loadLayer.(slot, \soft);
        loadLayer.(slot, \med);
        loadLayer.(slot, \hard);
    };

    at[\epianoAssets] = IdentityDictionary.new;
    at[\epianoAssets][\sampleDir] = sampleDir;
    at[\epianoAssets][\slots] = slots;
    at[\epianoAssets][\loadedLayerCount] = loadedCount;
    at[\epianoAssets][\requiredLayerCount] = requiredCount;
    at[\epianoAssets][\missing] = missing;
    at[\epianoAssets][\rootSemantics] = \keygroupRootSeparateFromNativeSourceRoot;
    at[\epianoAssets][\sourceRootPolicy] = \jRhodes3dNativeSourceStemPitch;
    at[\epianoAssets][\zoneBoundaryPolicy] = \nearestNativeSourceRootMidpoints;
    at[\epianoAssets][\pitchAuthorityEligible] = false;
    at[\epianoAssets][\status] = if(loadedCount == requiredCount) { \complete } { if(loadedCount > 0) { \partial } { \missing } };

    at[\epianoSlotForMidi] = { |midi=60|
        var m, found;
        m = midi.asInteger.clip(0, 127);
        found = slots.detect { |slot| m <= slot[\high] };
        if(found.isNil) { slots.last } { found };
    };

    at[\epianoSlotReady] = { |slot|
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

    at[\epianoAssetReport] = {
        "".postln;
        "[AT EPIANO ASSET REPORT]".postln;
        ("sampleDir=" ++ sampleDir).postln;
        ("status=" ++ at[\epianoAssets][\status].asString
            ++ " loaded=" ++ loadedCount.asString
            ++ "/" ++ requiredCount.asString).postln;
        if(loadedCount < requiredCount) {
            "Missing expected files:".postln;
            slots.do { |slot|
                ("  keygroupRoot " ++ slot[\keygroupRoot].asString
                    ++ " sourceRoot=" ++ slot[\sourceRoot].asString
                    ++ " high<=" ++ slot[\high].asString
                    ++ " legacyHigh<=" ++ slot[\legacyKeygroupHigh].asString
                    ++ " :: " ++ slot[\fileStems][\soft] ++ ".wav/.flac"
                    ++ ", " ++ slot[\fileStems][\med] ++ ".wav/.flac"
                    ++ ", " ++ slot[\fileStems][\hard] ++ ".wav/.flac").postln;
            };
            "".postln;
            "ElectricPiano will be unavailable/neutral only if no complete sample source is present. v5 normally ships with a bundled mda-derived EP floor in this folder.".postln;
        };
        at[\epianoAssets]
    };
    api[\epianoAssetReport] = { at[\epianoAssetReport].() };

    at[\epianoPitchMapReport] = { |midiList|
        var notes, rows, maxFormerError, maxNativeDistance, rep;
        notes = if(midiList.isNil) { [60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 72, 84] } { midiList };
        rows = notes.collect { |m|
            var midi, slot, keyRoot, sourceRoot, correctedRootFreq, correctedRate, formerError, nativeDistance, keygroupDistance;
            midi = (m ? 60).asInteger.clip(0, 127);
            slot = at[\epianoSlotForMidi].(midi);
            keyRoot = if(slot.notNil) { slot[\keygroupRoot] ? slot[\root] } { midi };
            sourceRoot = if(slot.notNil) { slot[\sourceRoot] ? keyRoot } { midi };
            correctedRootFreq = if(slot.notNil) { slot[\rootFreq] ? sourceRoot.midicps } { midi.midicps };
            correctedRate = midi.midicps / correctedRootFreq.max(20.0);
            formerError = (sourceRoot - keyRoot) * 100;
            nativeDistance = (midi - sourceRoot) * 100;
            keygroupDistance = (midi - keyRoot) * 100;
            (
                midi: midi,
                pc: midi % 12,
                keygroupRoot: keyRoot,
                slotHigh: if(slot.notNil) { slot[\high] } { nil },
                legacyKeygroupHigh: if(slot.notNil) { slot[\legacyKeygroupHigh] } { nil },
                nativeZoneHigh: if(slot.notNil) { slot[\nativeZoneHigh] } { nil },
                sourceRoot: sourceRoot,
                nativeDistanceCents: nativeDistance.asInteger,
                keygroupDistanceCents: keygroupDistance.asInteger,
                selectedBy: if(slot.notNil) { slot[\zoneBoundaryPolicy] ? \legacyKeygroupMidpoints } { \none },
                sourceStem: if(slot.notNil) { slot[\sourceStem] } { nil },
                selectedMedStem: if(slot.notNil) { slot[\fileStems][\med] } { nil },
                correctedRootFreq: correctedRootFreq.round(0.01),
                correctedPlaybackRate: correctedRate.round(0.0001),
                formerWrongRootErrorCents: formerError.asInteger,
                correctedExpectedErrorCents: 0.0,
                pitchAuthorityEligible: false
            )
        };
        maxFormerError = 0.0;
        maxNativeDistance = 0.0;
        rows.do { |row|
            var e, nd;
            e = (row[\formerWrongRootErrorCents] ? 0).abs;
            if(e > maxFormerError) { maxFormerError = e; };
            nd = (row[\nativeDistanceCents] ? 0).abs;
            if(nd > maxNativeDistance) { maxNativeDistance = nd; };
        };
        rep = (
            toneProfile: \electricPiano,
            rootSemantics: \keygroupRootSeparateFromNativeSourceRoot,
            sourceRootPolicy: \jRhodes3dNativeSourceStemPitch,
            zoneBoundaryPolicy: \nearestNativeSourceRootMidpoints,
            status: at[\epianoAssets][\status],
            sampleDir: sampleDir,
            checkedMidi: notes,
            rows: rows,
            maxFormerWrongRootErrorCents: maxFormerError.asInteger,
            maxSelectedNativeDistanceCents: maxNativeDistance.asInteger,
            correctedExpectedErrorCents: 0.0,
            explainsChromaticCollapse: maxFormerError >= 100,
            pitchAuthorityEligible: false,
            note: "EP_### is a selection tag; sourceRoot is the native jRhodes pitch. v3D38 chooses zones by nearest native source root to reduce chromatic timbre/pitch seams."
        );
        at[\epianoAssets][\lastPitchMapReport] = rep;
        "".postln;
        "[AT EPIANO PITCH MAP REPORT]".postln;
        ("status=" ++ rep[\status].asString
            ++ " rootSemantics=" ++ rep[\rootSemantics].asString
            ++ " boundaryPolicy=" ++ rep[\zoneBoundaryPolicy].asString
            ++ " maxNativeDistance=" ++ maxNativeDistance.asInteger.asString ++ "c"
            ++ " maxFormerWrongRootError=" ++ maxFormerError.asInteger.asString ++ "c pitchAuthority=false").postln;
        rows.do { |row|
            ("midi=" ++ row[\midi].asString
                ++ " keygroupRoot=" ++ row[\keygroupRoot].asString
                ++ " sourceRoot=" ++ row[\sourceRoot].asString
                ++ " high<=" ++ row[\slotHigh].asString
                ++ " legacyHigh<=" ++ row[\legacyKeygroupHigh].asString
                ++ " nativeDist=" ++ row[\nativeDistanceCents].asString ++ "c"
                ++ " oldError=" ++ row[\formerWrongRootErrorCents].asString ++ "c"
                ++ " correctedRate=" ++ row[\correctedPlaybackRate].asString
                ++ " stem=" ++ row[\sourceStem].asString).postln;
        };
        rep
    };
    api[\epianoPitchMapReport] = { |midiList| at[\epianoPitchMapReport].(midiList) };

    if(loadedCount == requiredCount) {
        ("[at-epiano-assets] complete: loaded " ++ loadedCount.asString ++ " electric-piano source layers from samples/epiano; source-root pitch map + nearest native zone map active").postln;
    } {
        ("[at-epiano-assets] missing/partial: loaded " ++ loadedCount.asString ++ "/" ++ requiredCount.asString
            ++ " source layers from " ++ sampleDir).warn;
        "[at-epiano-assets] No complete sample source found. Run Library.at(\at)[\api][\installDirectRhodesSamples].(); then reboot, or add legal EP keygroups manually.".postln;
    };
};
)
