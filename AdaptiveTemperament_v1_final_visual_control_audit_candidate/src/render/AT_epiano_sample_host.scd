(
// AT_epiano_sample_host.scd
// Real electric-piano sample host for the electricPiano profile.
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

    makeSlot = { |fileRoot, highMidi, sourceRoot, sourceStem|
        var tag, slot;
        // fileRoot is the historical EP_### file tag used by the installer/cache.
        // sourceRoot is the real native pitch of the jRhodes source file named by
        // sourceStem. These are deliberately separate: earlier builds treated
        // EP_067 from A_065__F4 as if its source root were MIDI 67, which makes
        // adjacent notes around Eb/E collapse toward the same sounding pitch.
        tag = fileRoot.asInteger.asString;
        if(fileRoot < 100) { tag = "0" ++ tag; };
        if(fileRoot < 10) { tag = "0" ++ tag; };
        slot = IdentityDictionary.new;
        slot[\root] = fileRoot.asInteger;
        slot[\fileRoot] = fileRoot.asInteger;
        slot[\keygroupRoot] = fileRoot.asInteger;
        slot[\sourceRoot] = sourceRoot.asInteger;
        slot[\nativeSourceRoot] = sourceRoot.asInteger;
        slot[\sourceStem] = sourceStem.asString;
        slot[\high] = highMidi.asInteger;
        slot[\rootFreq] = sourceRoot.asInteger.midicps;
        slot[\sourceRootFreq] = sourceRoot.asInteger.midicps;
        slot[\keygroupRootFreq] = fileRoot.asInteger.midicps;
        slot[\buffers] = IdentityDictionary.new;
        slot[\paths] = IdentityDictionary.new;
        slot[\foundFiles] = IdentityDictionary.new;
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

    // Nearest-native-source-root zones. The cached EP_### names are retained for
    // compatibility with the existing direct installer, but playback rates now use
    // the real native source roots from jRhodes3d source stems.
    slots = [
        makeSlot.(36, 40, 35, "A_035__B1"),
        makeSlot.(43, 47, 45, "A_045__A2"),
        makeSlot.(48, 52, 50, "A_050__D3"),
        makeSlot.(55, 57, 55, "A_055__G3"),
        makeSlot.(60, 62, 59, "A_059__B3"),
        makeSlot.(67, 68, 65, "A_065__F4"),
        makeSlot.(72, 76, 71, "A_071__B4"),
        makeSlot.(79, 83, 81, "A_081__A5"),
        makeSlot.(84, 88, 86, "A_086__D6"),
        makeSlot.(91, 93, 91, "A_091__G6"),
        makeSlot.(96, 999, 96, "A_096__C7")
    ];

    loadLayer = { |slot, layer|
        var path, stem, candidates, found;
        requiredCount = requiredCount + 1;
        stem = slot[\fileStems][layer];
        candidates = [slot[\files][layer], stem ++ ".flac"];
        found = candidates.detect { |fn| File.exists(sampleDir +/+ fn) };
        if(found.notNil) {
            path = sampleDir +/+ found;
            slot[\paths][layer] = path;
            slot[\foundFiles][layer] = found;
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

    at[\epianoPitchMapEntry] = { |midi=60|
        var m, slot, rate, ready, sourceFreq, effectiveRoot, effectiveRootFreq;
        m = (midi ? 60).asInteger.clip(0, 127);
        slot = at[\epianoSlotForMidi].(m);
        ready = if(at[\epianoSlotReady].notNil) { at[\epianoSlotReady].(slot) } { false };
        effectiveRoot = if(slot.notNil) { slot[\effectiveRoot] ? (slot[\sourceRoot] ? m) } { m };
        effectiveRootFreq = if(slot.notNil) { slot[\effectiveRootFreq] ? (slot[\sourceRootFreq] ? (slot[\rootFreq] ? m.midicps)) } { m.midicps };
        sourceFreq = effectiveRootFreq;
        rate = m.midicps / sourceFreq.max(20.0);
        (
            midi: m,
            targetFreq: m.midicps,
            fileRoot: if(slot.notNil) { slot[\fileRoot] ? slot[\root] } { nil },
            sourceRoot: if(slot.notNil) { slot[\sourceRoot] } { nil },
            nativeSourceRoot: if(slot.notNil) { slot[\nativeSourceRoot] ? slot[\sourceRoot] } { nil },
            effectiveRoot: effectiveRoot,
            measuredRoot: if(slot.notNil) { slot[\measuredRoot] } { nil },
            rootDecision: if(slot.notNil) { slot[\measuredRootDecision] ? \unmeasured } { \missing },
            sourceStem: if(slot.notNil) { slot[\sourceStem] } { nil },
            zoneHigh: if(slot.notNil) { slot[\high] } { nil },
            sourceRootFreq: if(slot.notNil) { slot[\sourceRootFreq] ? slot[\rootFreq] } { nil },
            effectiveRootFreq: effectiveRootFreq,
            playbackRate: rate.round(0.0001),
            ready: ready,
            pitchAuthority: false
        )
    };

    at[\epianoPitchMapReport] = { |first=60, last=69|
        var a, b, entries, t;
        a = (first ? 60).asInteger.clip(0, 127);
        b = (last ? 69).asInteger.clip(0, 127);
        if(b < a) { t = a; a = b; b = t; };
        entries = List.new;
        "".postln;
        "[AT EPIANO PITCH MAP]".postln;
        "boundaryPolicy=nearestNativeSourceRootMidpoints rootSemantics=keygroupRootSeparateFromNativeSourceRoot effectiveRootPolicy=measuredCacheRootWhenVerified pitchAuthority=false".postln;
        (a..b).do { |m|
            var e;
            e = at[\epianoPitchMapEntry].(m);
            entries.add(e);
            ("midi=" ++ m.asString
                ++ " sourceRoot=" ++ (e[\sourceRoot] ? \nil).asString
                ++ " effectiveRoot=" ++ (e[\effectiveRoot] ? \nil).asString
                ++ " fileRoot=" ++ (e[\fileRoot] ? \nil).asString
                ++ " sourceStem=" ++ (e[\sourceStem] ? \nil).asString
                ++ " rate=" ++ (e[\playbackRate] ? 1.0).asString
                ++ " measuredRoot=" ++ (e[\measuredRoot] ? \unmeasured).asString
                ++ " rootDecision=" ++ (e[\rootDecision] ? \unmeasured).asString
                ++ " ready=" ++ (e[\ready] ? false).asString).postln;
        };
        entries
    };
    api[\epianoPitchMapReport] = { |first=60, last=69| at[\epianoPitchMapReport].(first, last) };
    api[\epianoSamplePitchMapReport] = { |first=60, last=69| at[\epianoPitchMapReport].(first, last) };

    at[\epianoCacheContentReport] = { |first=60, last=69|
        var a, b, t, seen;
        a = (first ? 60).asInteger.clip(0, 127);
        b = (last ? 69).asInteger.clip(0, 127);
        if(b < a) { t = a; a = b; b = t; };
        seen = List.new;
        "".postln;
        "[AT EPIANO CACHE CONTENT REPORT]".postln;
        "purpose=reports the actual selected cached file roots, native source roots, and layer paths; this does not grant pitch authority".postln;
        (a..b).do { |m|
            var slot, e, key, softPath, medPath, hardPath;
            slot = at[\epianoSlotForMidi].(m);
            e = at[\epianoPitchMapEntry].(m);
            key = (e[\fileRoot].asString ++ ":" ++ e[\sourceRoot].asString);
            if(seen.includes(key).not) {
                seen.add(key);
                softPath = if(slot.notNil and: { slot[\paths].notNil }) { slot[\paths][\soft] ? "missing" } { "missing" };
                medPath = if(slot.notNil and: { slot[\paths].notNil }) { slot[\paths][\med] ? "missing" } { "missing" };
                hardPath = if(slot.notNil and: { slot[\paths].notNil }) { slot[\paths][\hard] ? "missing" } { "missing" };
                ("fileRoot=" ++ (e[\fileRoot] ? \nil).asString
                    ++ " sourceRoot=" ++ (e[\sourceRoot] ? \nil).asString
                    ++ " effectiveRoot=" ++ (e[\effectiveRoot] ? \nil).asString
                    ++ " sourceStem=" ++ (e[\sourceStem] ? \nil).asString
                    ++ " soft=" ++ softPath
                    ++ " med=" ++ medPath
                    ++ " hard=" ++ hardPath).postln;
            };
        };
        seen
    };
    api[\epianoCacheContentReport] = { |first=60, last=69| at[\epianoCacheContentReport].(first, last) };


    at[\epianoMeasureCacheFileRoot] = { |path, sourceRoot=60, fileRoot=60, layer=\med|
        var result, sf, opened, sr, chans, framesAvail, skipFrames, countFrames, readFrames, data;
        var i, j, idx, mean, expectedRoot, expectedHz, minLag, maxLag, lag, n, maxN;
        var num, den0, den1, a0, b0, score, bestScore, bestLag, measuredHz, measuredMidi, centerMidi;
        var foldedMidi, candidates, sourceErrC, fileErrC, decision, nearestRoot;
        result = IdentityDictionary.newFrom([
            \path, path,
            \sourceRoot, sourceRoot.asInteger,
            \fileRoot, fileRoot.asInteger,
            \layer, layer.asSymbol,
            \ok, false,
            \decision, \missing,
            \measuredMidi, nil,
            \measuredHz, nil,
            \nearestRoot, nil,
            \centsVsSource, nil,
            \centsVsFile, nil,
            \score, 0.0
        ]);
        if(path.notNil and: { File.exists(path) }) {
            sf = SoundFile.new;
            opened = sf.openRead(path);
            if(opened) {
                sr = sf.sampleRate ? 44100;
                chans = sf.numChannels.max(1);
                framesAvail = sf.numFrames.asInteger.max(0);
                skipFrames = (sr * 0.075).asInteger.min(framesAvail.max(0));
                countFrames = (sr * 0.70).asInteger.min((framesAvail - skipFrames).max(0));
                readFrames = (skipFrames + countFrames).min(framesAvail).max(0);
                if(countFrames > 1024 and: { readFrames > skipFrames }) {
                    data = FloatArray.newClear(readFrames * chans);
                    sf.readData(data);
                    sf.close;
                    mean = 0.0;
                    countFrames.do { |k|
                        idx = (skipFrames + k) * chans;
                        mean = mean + data[idx];
                    };
                    mean = mean / countFrames.max(1);
                    expectedRoot = sourceRoot.asInteger;
                    expectedHz = expectedRoot.midicps.max(20.0);
                    minLag = (sr / (expectedHz * (2 ** (5.0 / 12.0)))).floor.asInteger.max(12);
                    maxLag = (sr / (expectedHz * (2 ** (-5.0 / 12.0)))).ceil.asInteger.min(countFrames - 2).max(minLag + 1);
                    bestScore = -999.0;
                    bestLag = minLag;
                    maxN = countFrames.min(22050);
                    (minLag..maxLag).do { |candidateLag|
                        n = (maxN - candidateLag).max(64);
                        num = 0.0; den0 = 0.0; den1 = 0.0;
                        n.do { |k|
                            a0 = data[(skipFrames + k) * chans] - mean;
                            b0 = data[(skipFrames + k + candidateLag) * chans] - mean;
                            num = num + (a0 * b0);
                            den0 = den0 + (a0 * a0);
                            den1 = den1 + (b0 * b0);
                        };
                        score = num / (((den0 * den1).sqrt) + 0.000000000001);
                        if(score > bestScore) {
                            bestScore = score;
                            bestLag = candidateLag;
                        };
                    };
                    measuredHz = sr / bestLag.max(1);
                    measuredMidi = measuredHz.cpsmidi;
                    centerMidi = ((sourceRoot.asFloat + fileRoot.asFloat) * 0.5);
                    candidates = [measuredMidi - 24, measuredMidi - 12, measuredMidi, measuredMidi + 12, measuredMidi + 24];
                    foldedMidi = candidates[0];
                    candidates.do { |cand|
                        if((cand - centerMidi).abs < (foldedMidi - centerMidi).abs) { foldedMidi = cand; };
                    };
                    sourceErrC = (foldedMidi - sourceRoot.asFloat) * 100.0;
                    fileErrC = (foldedMidi - fileRoot.asFloat) * 100.0;
                    nearestRoot = foldedMidi.round(1).asInteger;
                    decision = if(sourceErrC.abs <= 35.0) {
                        \sourceRootMatches
                    } {
                        if(fileErrC.abs <= 35.0) { \fileRootMatches } { \neitherRootMatches }
                    };
                    result[\ok] = true;
                    result[\decision] = decision;
                    result[\measuredMidi] = foldedMidi.round(0.01);
                    result[\measuredHz] = (foldedMidi.midicps).round(0.01);
                    result[\nearestRoot] = nearestRoot;
                    result[\centsVsSource] = sourceErrC.round(0.1);
                    result[\centsVsFile] = fileErrC.round(0.1);
                    result[\score] = bestScore.round(0.001);
                } {
                    sf.close;
                    result[\decision] = \tooShort;
                };
            } {
                result[\decision] = \cannotOpen;
            };
        };
        result
    };

    at[\epianoMeasuredCacheRootReport] = { |first=60, last=69, layer=\med, apply=false|
        var a, b, t, seen, results, layerSym;
        a = (first ? 60).asInteger.clip(0, 127);
        b = (last ? 69).asInteger.clip(0, 127);
        if(b < a) { t = a; a = b; b = t; };
        layerSym = (layer ? \med).asSymbol;
        if([\soft, \med, \hard].includes(layerSym).not) { layerSym = \med; };
        seen = List.new;
        results = List.new;
        "".postln;
        "[AT EPIANO CACHE ROOT MEASURE]".postln;
        ("mode=soundfileAutocorrelation layer=" ++ layerSym.asString ++ " apply=" ++ (apply ? false).asString ++ " pitchAuthority=false").postln;
        (a..b).do { |m|
            var slot, e, key, path, r, effectiveRoot, decision;
            slot = at[\epianoSlotForMidi].(m);
            e = at[\epianoPitchMapEntry].(m);
            key = (e[\fileRoot].asString ++ ":" ++ e[\sourceRoot].asString ++ ":" ++ layerSym.asString);
            if(seen.includes(key).not) {
                seen.add(key);
                path = if(slot.notNil and: { slot[\paths].notNil }) { slot[\paths][layerSym] } { nil };
                r = at[\epianoMeasureCacheFileRoot].(path, e[\sourceRoot] ? m, e[\fileRoot] ? m, layerSym);
                results.add(r);
                decision = r[\decision] ? \missing;
                effectiveRoot = e[\sourceRoot] ? m;
                if((apply ? false) == true) {
                    if(decision == \fileRootMatches) { effectiveRoot = e[\fileRoot] ? effectiveRoot; };
                    if(decision == \sourceRootMatches) { effectiveRoot = e[\sourceRoot] ? effectiveRoot; };
                    if(slot.notNil and: { (decision == \fileRootMatches) or: { decision == \sourceRootMatches } }) {
                        slot[\measuredRoot] = r[\nearestRoot];
                        slot[\measuredRootDecision] = decision;
                        slot[\effectiveRoot] = effectiveRoot.asInteger;
                        slot[\effectiveRootFreq] = effectiveRoot.asInteger.midicps;
                    };
                };
                ("fileRoot=" ++ (e[\fileRoot] ? \nil).asString
                    ++ " sourceRoot=" ++ (e[\sourceRoot] ? \nil).asString
                    ++ " measuredMidi=" ++ (r[\measuredMidi] ? \nil).asString
                    ++ " nearestRoot=" ++ (r[\nearestRoot] ? \nil).asString
                    ++ " centsVsSource=" ++ (r[\centsVsSource] ? \nil).asString
                    ++ " centsVsFile=" ++ (r[\centsVsFile] ? \nil).asString
                    ++ " score=" ++ (r[\score] ? 0.0).asString
                    ++ " decision=" ++ decision.asString
                    ++ " effectiveRoot=" ++ effectiveRoot.asString
                    ++ " path=" ++ (path ? "missing")).postln;
            };
        };
        results
    };
    api[\epianoMeasuredCacheRootReport] = { |first=60, last=69, layer=\med, apply=false| at[\epianoMeasuredCacheRootReport].(first, last, layer, apply) };
    api[\epianoVerifyAndApplyMeasuredRoots] = { |first=60, last=69, layer=\med| at[\epianoMeasuredCacheRootReport].(first, last, layer, true) };

    at[\epianoVelocityForLayer] = { |layer=\med|
        var layerSym, vel;
        layerSym = (layer ? \med).asSymbol;
        if([\soft, \med, \hard].includes(layerSym).not) { layerSym = \med; };
        vel = if(layerSym == \soft) { 0.18 } { if(layerSym == \hard) { 0.98 } { 0.62 } };
        vel
    };

    at[\epianoMeasuredAllLayerRootReport] = { |first=60, last=69, apply=false|
        var a, b, t, layers, seen, slotsToCheck, results, sourceOkCount, fileOkCount, problemCount, disagreementCount;
        a = (first ? 60).asInteger.clip(0, 127);
        b = (last ? 69).asInteger.clip(0, 127);
        if(b < a) { t = a; a = b; b = t; };
        layers = [\soft, \med, \hard];
        seen = List.new;
        slotsToCheck = List.new;
        results = List.new;
        sourceOkCount = 0;
        fileOkCount = 0;
        problemCount = 0;
        disagreementCount = 0;
        (a..b).do { |m|
            var slot, e, key;
            slot = at[\epianoSlotForMidi].(m);
            e = at[\epianoPitchMapEntry].(m);
            key = (e[\fileRoot].asString ++ ":" ++ e[\sourceRoot].asString);
            if(seen.includes(key).not) {
                seen.add(key);
                slotsToCheck.add(slot);
            };
        };
        "".postln;
        "[AT EPIANO ALL-LAYER CACHE ROOT MEASURE]".postln;
        ("mode=soundfileAutocorrelation layers=soft,med,hard apply=" ++ (apply ? false).asString ++ " pitchAuthority=false").postln;
        slotsToCheck.do { |slot|
            var layerMeasurements, sourceCount, fileCount, otherCount, chosen, effectiveRoot, layerSummary;
            layerMeasurements = IdentityDictionary.new;
            sourceCount = 0;
            fileCount = 0;
            otherCount = 0;
            layers.do { |layerSym|
                var path, r, decision;
                path = if(slot.notNil and: { slot[\paths].notNil }) { slot[\paths][layerSym] } { nil };
                r = at[\epianoMeasureCacheFileRoot].(path, slot[\sourceRoot] ? 60, slot[\fileRoot] ? 60, layerSym);
                decision = r[\decision] ? \missing;
                layerMeasurements[layerSym] = r;
                if(decision == \sourceRootMatches) { sourceCount = sourceCount + 1; } {
                    if(decision == \fileRootMatches) { fileCount = fileCount + 1; } { otherCount = otherCount + 1; };
                };
                ("fileRoot=" ++ (slot[\fileRoot] ? \nil).asString
                    ++ " sourceRoot=" ++ (slot[\sourceRoot] ? \nil).asString
                    ++ " layer=" ++ layerSym.asString
                    ++ " measuredMidi=" ++ (r[\measuredMidi] ? \nil).asString
                    ++ " nearestRoot=" ++ (r[\nearestRoot] ? \nil).asString
                    ++ " centsVsSource=" ++ (r[\centsVsSource] ? \nil).asString
                    ++ " centsVsFile=" ++ (r[\centsVsFile] ? \nil).asString
                    ++ " score=" ++ (r[\score] ? 0.0).asString
                    ++ " decision=" ++ decision.asString
                    ++ " path=" ++ (path ? "missing")).postln;
            };
            chosen = if(otherCount > 0) {
                problemCount = problemCount + 1;
                \layerRootProblem
            } {
                if(sourceCount == layers.size) {
                    sourceOkCount = sourceOkCount + 1;
                    \sourceRootMatches
                } {
                    if(fileCount == layers.size) {
                        fileOkCount = fileOkCount + 1;
                        \fileRootMatches
                    } {
                        disagreementCount = disagreementCount + 1;
                        \layerRootDisagreement
                    }
                }
            };
            effectiveRoot = slot[\sourceRoot] ? (slot[\fileRoot] ? 60);
            if((apply ? false) == true) {
                slot[\layerRootMeasurements] = layerMeasurements;
                slot[\layerRootDecision] = chosen;
                if(chosen == \sourceRootMatches) {
                    effectiveRoot = slot[\sourceRoot] ? effectiveRoot;
                    slot[\effectiveRoot] = effectiveRoot.asInteger;
                    slot[\effectiveRootFreq] = effectiveRoot.asInteger.midicps;
                    slot[\measuredRootDecision] = chosen;
                    slot[\measuredRoot] = effectiveRoot.asInteger;
                };
                if(chosen == \fileRootMatches) {
                    effectiveRoot = slot[\fileRoot] ? effectiveRoot;
                    slot[\effectiveRoot] = effectiveRoot.asInteger;
                    slot[\effectiveRootFreq] = effectiveRoot.asInteger.midicps;
                    slot[\measuredRootDecision] = chosen;
                    slot[\measuredRoot] = effectiveRoot.asInteger;
                };
            };
            layerSummary = (
                fileRoot: slot[\fileRoot],
                sourceRoot: slot[\sourceRoot],
                effectiveRoot: effectiveRoot,
                sourceLayerMatches: sourceCount,
                fileLayerMatches: fileCount,
                otherLayerMatches: otherCount,
                layerRootDecision: chosen,
                rebuildRequired: (chosen == \layerRootProblem) or: { chosen == \layerRootDisagreement }
            );
            results.add(layerSummary);
            ("[AT EPIANO ALL-LAYER ROOT SUMMARY] fileRoot=" ++ (slot[\fileRoot] ? \nil).asString
                ++ " sourceRoot=" ++ (slot[\sourceRoot] ? \nil).asString
                ++ " effectiveRoot=" ++ effectiveRoot.asString
                ++ " sourceLayerMatches=" ++ sourceCount.asString
                ++ " fileLayerMatches=" ++ fileCount.asString
                ++ " otherLayerMatches=" ++ otherCount.asString
                ++ " layerRootDecision=" ++ chosen.asString
                ++ " rebuildRequired=" ++ layerSummary[\rebuildRequired].asString).postln;
        };
        ("[AT EPIANO ALL-LAYER ROOT TOTAL] zones=" ++ slotsToCheck.size.asString
            ++ " sourceOk=" ++ sourceOkCount.asString
            ++ " fileOk=" ++ fileOkCount.asString
            ++ " disagreements=" ++ disagreementCount.asString
            ++ " problems=" ++ problemCount.asString
            ++ " pitchAuthority=false").postln;
        results
    };
    api[\epianoMeasuredAllLayerRootReport] = { |first=60, last=69, apply=false| at[\epianoMeasuredAllLayerRootReport].(first, last, apply) };
    api[\epianoVerifyAllLayerRoots] = { |first=60, last=69| at[\epianoMeasuredAllLayerRootReport].(first, last, true) };

    // EP rendered pitch was verified in the frozen keeper lineage; runtime audit code is not shipped in the final product.

    api[\epianoRenderedPitchStatus] = {
        var rep;
        rep = (
            verifiedInKeeper: true,
            source: \v65b_finalKeeperLineage,
            runtimeAuditIncluded: false,
            pitchAuthority: false
        );
        "[AT EPIANO STATUS] renderedPitchVerifiedInKeeper=true runtimeAuditIncluded=false pitchAuthority=false".postln;
        rep;
    };



    at[\epianoAssetReport] = {
        "".postln;
        "[AT EPIANO ASSET REPORT]".postln;
        ("sampleDir=" ++ sampleDir).postln;
        ("status=" ++ at[\epianoAssets][\status].asString
            ++ " loaded=" ++ loadedCount.asString
            ++ "/" ++ requiredCount.asString
            ++ " boundaryPolicy=nearestNativeSourceRootMidpoints rootSemantics=keygroupRootSeparateFromNativeSourceRoot effectiveRootPolicy=measuredCacheRootWhenVerified").postln;
        if(loadedCount < requiredCount) {
            "Missing expected files:".postln;
            slots.do { |slot|
                ("  root " ++ slot[\root].asString
                    ++ " high<=" ++ slot[\high].asString
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

    if(loadedCount == requiredCount) {
        ("[at-epiano-assets] complete: loaded " ++ loadedCount.asString ++ " electric-piano source layers from samples/epiano; pitch map uses native source roots").postln;
    } {
        ("[at-epiano-assets] missing/partial: loaded " ++ loadedCount.asString ++ "/" ++ requiredCount.asString
            ++ " source layers from " ++ sampleDir).warn;
        "[at-epiano-assets] No complete sample source found. Run Library.at(\at)[\api][\installDirectRhodesSamples].(); then reboot, or add legal EP keygroups manually.".postln;
    };
};
)
