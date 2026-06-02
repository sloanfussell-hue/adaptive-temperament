(
// AT_sample_source_registry.scd
// v3D16b curated sample-source registry + stable global cache + first-boot auto-bootstrap flag.
// This is a planning/import/verification layer only. It does not bundle samples,
// download restricted community libraries, synthesize fake keygroups, authorize
// pitch movement, write cylinder residuals, or change the solver.

var build, at, cfg, st, api, q, defaultRoot, registry, categoryMatch;
var updateConfiguredDirs, pathExists, source, sourceIds, rootReport;

build = ~atBuild;

if(build.isNil) {
    "[AT SAMPLE SOURCE REGISTRY] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(st[\sampleSourceRegistry].isNil) { st[\sampleSourceRegistry] = IdentityDictionary.new; };
    if(cfg[\render][\autoInstallDirectSamplesOnBoot].isNil) { cfg[\render][\autoInstallDirectSamplesOnBoot] = true; };

    q = { |s| "\"" ++ s.asString.replace("\\", "\\\\").replace("\"", "\\\"") ++ "\"" };
    pathExists = { |p| p.notNil and: { File.exists(p.asString) } };

    defaultRoot = cfg[\render][\sampleLibraryRoot] ? (Platform.userHomeDir +/+ "AdaptiveTemperament_samples");

    updateConfiguredDirs = { |root|
        var r;
        r = root.asString;
        cfg[\render][\sampleLibraryRoot] = r;
        // These are stable across candidate zips. The current hosts only read
        // these two routable formats; other curated sources are import/future-map
        // sources until a verifier/converter explicitly supports them.
        cfg[\render][\pianoSamplesDir] = r +/+ "piano/slender_salamander";
        cfg[\render][\epianoSamplesDir] = r +/+ "electric_piano/keygroups";
        cfg[\render][\sampleLibraryReadmeDir] = r +/+ "_source_registry";
        r;
    };

    updateConfiguredDirs.(defaultRoot);

    source = { |id, tone, rank, sourceName, role, license, url, auto, manual, routable, redistributable, note|
        (
            id: id,
            tone: tone,
            rank: rank,
            sourceName: sourceName,
            role: role,
            license: license,
            url: url,
            autoInstallAllowed: auto,
            manualImportRequired: manual,
            currentlyRoutableByAT: routable,
            redistributionAllowedByAT: redistributable,
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: note
        )
    };

    registry = IdentityDictionary.new;
    registry[\slenderSalamander] = source.(
        \slenderSalamander, \piano, 1,
        "Slender Salamander Grand Piano / Salamander Yamaha C5 reduction",
        "current best automatic/free piano baseline for this AT host; phase-aligned three-layer set",
        "CC BY 3.0 attribution required",
        "https://sig-ex.com/2017/11/11/slender-salmander-grand-piano/",
        true, false, true, true,
        "Routable now by AT_piano_sample_host; use as the automatic baseline and spectrum-truth source."
    );
    registry[\salamanderFull] = source.(
        \salamanderFull, \piano, 2,
        "Salamander Grand Piano v3 / Yamaha C5 full source",
        "higher-resolution free source; preferred future import if the host is extended beyond the Slender layout",
        "CC BY 3.0 attribution required",
        "https://sfzinstruments.github.io/pianos/salamander/",
        false, true, false, true,
        "Better source depth than Slender, but not mapped by the current AT piano host. Manual/import-future only."
    );
    registry[\pianoIn162] = source.(
        \pianoIn162, \piano, 3,
        "Ivy Audio Piano in 162 / Steinway Model B",
        "best optional high-detail manual piano import candidate",
        "free for use; sample-content redistribution is restricted/handle manually",
        "https://sfzinstruments.github.io/pianos/in_162/",
        false, true, false, false,
        "Very strong piano candidate, but manual/import-only; do not bundle or repack sample content."
    );
    registry[\iowaPiano] = source.(
        \iowaPiano, \piano, 4,
        "University of Iowa Musical Instrument Samples / piano",
        "research/reference source, not the default performance piano",
        "freely usable without restrictions per Iowa MIS page",
        "https://theremin.music.uiowa.edu/MIS.html",
        true, false, false, true,
        "Good legal research/reference material; prior listening made it unsuitable as AT's default piano voice."
    );
    registry[\jRhodes3d] = source.(
        \jRhodes3d, \electricPiano, 1,
        "jRhodes3d / 1977 Rhodes Mark I Stage 73",
        "direct-add sampled Rhodes target; full-length unlooped FLAC source converted/routed as AT keygroups",
        "samples: CC BY-NC 4.0; control files/music-use terms: CC0; noncommercial sample redistribution unless licensed",
        "https://github.com/sfzinstruments/jlearman.jRhodes3d/archive/refs/heads/master.zip",
        true, false, true, false,
        "Best immediate direct-add electric-piano source. Installer downloads GitHub archive and creates host-compatible EP_###_(soft|med|hard).flac keygroups. Commercial redistribution needs separate permission."
    );
    registry[\mattsFenderRhodes] = source.(
        \mattsFenderRhodes, \electricPiano, 2,
        "Matt's Fender Rhodes / Pianobook",
        "best clean Rhodes-style manual import target",
        "Pianobook/community license must be checked and retained by user import",
        "https://www.pianobook.co.uk/packs/matts-fender-rhodes/",
        false, true, false, false,
        "Clean Rhodes target. Manual import only; AT cannot redistribute or assume Pianobook login downloads."
    );
    registry[\mRhodes] = source.(
        \mRhodes, \electricPiano, 3,
        "mRhodes / Fender Rhodes Mark II / Pianobook",
        "character Rhodes manual import target",
        "Pianobook/community license must be checked and retained by user import",
        "https://www.pianobook.co.uk/packs/mrhodes/",
        false, true, false, false,
        "Character EP target, likely more colored/quirky than the clean Rhodes target. Manual import only."
    );
    registry[\mdaEPiano] = source.(
        \mdaEPiano, \electricPiano, 4,
        "mda ePiano source",
        "emergency open-source procedural fallback source, not final Rhodes samples",
        "MIT or GPL-2.0-or-later source terms depending on distribution path",
        "https://sourceforge.net/projects/mda-vst/files/mda-vst/mda-vst-src-2010-02-14.zip/download",
        true, false, false, true,
        "Fetchable source only. It does not create production Rhodes keygroups without a verified render/conversion step."
    );
    registry[\iowaStrings] = source.(
        \iowaStrings, \strings, 1,
        "University of Iowa Musical Instrument Samples / strings",
        "legal unrestricted string research/reference source; not a final cinematic strings product",
        "freely usable without restrictions per Iowa MIS page",
        "https://theremin.music.uiowa.edu/MIS.html",
        true, false, false, true,
        "External/user-supplied strings remain the performance path; this is for honest spectrum/reference evidence."
    );
    registry[\iowaMetals] = source.(
        \iowaMetals, \bellLike, 1,
        "University of Iowa Musical Instrument Samples / bells, crotales, gongs, vibraphone, metals",
        "best legal source family for real non-ordinary metallic/bell-like spectrum evidence",
        "freely usable without restrictions per Iowa MIS page",
        "https://theremin.music.uiowa.edu/MIS.html",
        true, false, false, true,
        "Use for Sethares/cylinder research on real inharmonic spectra before any pitch authority is considered."
    );

    at[\sampleSourceRegistry] = registry;
    at[\sampleSourceRegistryIds] = registry.keys.asArray.sort;

    categoryMatch = { |entry, requested|
        var req;
        req = (requested ? \all).asSymbol;
        (req == \all) or: { entry[\tone] == req or: { entry[\id] == req } };
    };

    rootReport = {
        (
            root: cfg[\render][\sampleLibraryRoot],
            pianoSamplesDir: cfg[\render][\pianoSamplesDir],
            electricPianoSamplesDir: cfg[\render][\epianoSamplesDir],
            sourceRegistryDir: cfg[\render][\sampleLibraryReadmeDir],
            rootExists: pathExists.(cfg[\render][\sampleLibraryRoot]),
            pianoDirExists: pathExists.(cfg[\render][\pianoSamplesDir]),
            electricPianoDirExists: pathExists.(cfg[\render][\epianoSamplesDir]),
            stableAcrossZips: true,
            pitchAuthorityEligible: false,
            note: "v3D14b uses a stable global cache so samples are not lost every time a new candidate zip is extracted."
        )
    };

    api[\sampleLibraryRootReport] = {
        var rep;
        rep = rootReport.();
        st[\sampleSourceRegistry][\lastRootReport] = rep;
        "".postln;
        "[AT SAMPLE LIBRARY ROOT REPORT]".postln;
        ("root=" ++ rep[\root].asString ++ " piano=" ++ rep[\pianoSamplesDir].asString ++ " epiano=" ++ rep[\electricPianoSamplesDir].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\setSampleLibraryRoot] = { |path|
        var rep;
        if(path.isNil) {
            "[AT SAMPLE LIBRARY ROOT] nil path ignored; keeping current root".warn;
        } {
            updateConfiguredDirs.(path.asString);
        };
        rep = api[\sampleLibraryRootReport].();
        rep[\note] = rep[\note] ++ " Reboot after changing root so sample buffers reload.";
        rep;
    };

    api[\sampleSourceRegistryReport] = { |category=\all|
        var req, selected, rep;
        req = (category ? \all).asSymbol;
        selected = List.new;
        registry.keysValuesDo { |id, entry|
            if(categoryMatch.(entry, req)) { selected.add(entry); };
        };
        rep = (
            requested: req,
            count: selected.size,
            sources: selected.asArray,
            root: cfg[\render][\sampleLibraryRoot],
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Curated source registry only. Restricted/manual sources are not auto-downloaded or redistributed."
        );
        st[\sampleSourceRegistry][\lastRegistryReport] = rep;
        "".postln;
        "[AT SAMPLE SOURCE REGISTRY REPORT]".postln;
        ("requested=" ++ req.asString ++ " count=" ++ rep[\count].asString ++ " root=" ++ rep[\root].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceRecommendationReport] = { |tone=\all|
        var t, rep;
        t = (tone ? \all).asSymbol;
        rep = (
            requestedTone: t,
            piano: (
                currentAutoRoutable: \slenderSalamander,
                higherDetailManual: \pianoIn162,
                futureFullFreeImport: \salamanderFull,
                researchReference: \iowaPiano,
                reason: "Slender is the current routable free baseline; Piano in 162 is the stronger manual high-detail target; full Salamander needs a mapper."
            ),
            electricPiano: (
                directAddTarget: \jRhodes3d,
                cleanManualTarget: \mattsFenderRhodes,
                characterManualTarget: \mRhodes,
                emergencySourceOnlyFallback: \mdaEPiano,
                reason: "jRhodes3d is the immediate direct-add Rhodes path; Pianobook Rhodes remain optional manual targets; mda is source-only/fallback."
            ),
            strings: (
                legalReference: \iowaStrings,
                performancePolicy: \externalOnly,
                reason: "Do not reintroduce fake built-in strings; use legal reference samples for analysis or premium/external strings for performance."
            ),
            bellLike: (
                legalReference: \iowaMetals,
                reason: "Real metallic/inharmonic samples are the correct research material for non-ordinary Sethares/cylinder behavior."
            ),
            noFakeSamples: true,
            pitchAuthorityEligible: false
        );
        st[\sampleSourceRegistry][\lastRecommendationReport] = rep;
        "".postln;
        "[AT SAMPLE SOURCE RECOMMENDATION REPORT]".postln;
        ("tone=" ++ t.asString ++ " piano=slender/pianoIn162 epiano=jRhodes3d/mattsRhodes pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceInstallPlan] = { |sourceId=\slenderSalamander|
        var id, entry, root, pianoDir, epSrcDir, cmd, rep;
        id = (sourceId ? \slenderSalamander).asSymbol;
        entry = registry[id];
        root = cfg[\render][\sampleLibraryRoot];
        pianoDir = cfg[\render][\pianoSamplesDir];
        epSrcDir = cfg[\render][\epianoSamplesDir] +/+ "_mda_source";
        if(entry.isNil) { entry = registry[\slenderSalamander]; id = \slenderSalamander; };
        cmd = "manual-import-required";
        if(id == \slenderSalamander) {
            cmd = "mkdir -p " ++ q.(pianoDir) ++ " && curl -L --fail -o " ++ q.(pianoDir +/+ "SlenderSalamander44khz16bit.zip") ++ " " ++ q.("https://musical-artifacts.com/artifacts/534/SlenderSalamander44khz16bit.zip") ++ " && unzip -o " ++ q.(pianoDir +/+ "SlenderSalamander44khz16bit.zip") ++ " -d " ++ q.(pianoDir);
        };
        if(id == \jRhodes3d) {
            cmd = if(api[\directSampleInstallPlan].notNil) { api[\directSampleInstallPlan].()[\epianoCommand] } { "direct installer not loaded yet" };
        };
        if(id == \mdaEPiano) {
            cmd = "mkdir -p " ++ q.(epSrcDir) ++ " && curl -L --fail -o " ++ q.(epSrcDir +/+ "mda-vst-src-2010-02-14.zip") ++ " " ++ q.(entry[\url]);
        };
        rep = (
            sourceId: id,
            sourceName: entry[\sourceName],
            autoInstallAllowed: entry[\autoInstallAllowed],
            manualImportRequired: entry[\manualImportRequired],
            command: cmd,
            root: root,
            targetDir: if(id == \mdaEPiano) { epSrcDir } { if(entry[\tone] == \electricPiano) { cfg[\render][\epianoSamplesDir] } { pianoDir } },
            currentlyRoutableByAT: entry[\currentlyRoutableByAT],
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Install plans do not run automatically and do not imply render or pitch readiness."
        );
        st[\sampleSourceRegistry][\lastInstallPlan] = rep;
        "".postln;
        "[AT SAMPLE SOURCE INSTALL PLAN]".postln;
        ("source=" ++ id.asString ++ " auto=" ++ rep[\autoInstallAllowed].asString ++ " routable=" ++ rep[\currentlyRoutableByAT].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceImportPlan] = { |sourceId=\mattsFenderRhodes|
        var id, entry, rep;
        id = (sourceId ? \mattsFenderRhodes).asSymbol;
        entry = registry[id];
        if(entry.isNil) { entry = registry[\mattsFenderRhodes]; id = \mattsFenderRhodes; };
        rep = (
            sourceId: id,
            sourceName: entry[\sourceName],
            manualImportRequired: true,
            redistributionAllowedByAT: entry[\redistributionAllowedByAT],
            targetGlobalRoot: cfg[\render][\sampleLibraryRoot],
            expectedCurrentEpianoKeygroupNames: ["EP_060_soft.wav", "EP_060_med.wav", "EP_060_hard.wav"],
            expectedCurrentPianoLayout: "SlenderSalamander44khz16bit/samples/<note>v1-PA.wav, <note>v8.5-PA.wav, <note>v16.wav",
            currentlyRoutableByAT: entry[\currentlyRoutableByAT],
            needsVerifierOrConverter: entry[\currentlyRoutableByAT].not,
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: entry[\note]
        );
        st[\sampleSourceRegistry][\lastImportPlan] = rep;
        "".postln;
        "[AT SAMPLE SOURCE IMPORT PLAN]".postln;
        ("source=" ++ id.asString ++ " manual=true needsVerifier=" ++ rep[\needsVerifierOrConverter].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceVerificationReport] = { |tone=\piano, path=nil|
        var t, assets, dir, loaded, required, status, complete, rep;
        t = (tone ? \piano).asSymbol;
        assets = if(t == \electricPiano) { at[\epianoAssets] } { if(t == \piano) { at[\pianoAssets] } { nil } };
        dir = path;
        if(dir.isNil) {
            dir = if(t == \electricPiano) { cfg[\render][\epianoSamplesDir] } { cfg[\render][\pianoSamplesDir] };
        };
        loaded = if(assets.notNil) { assets[\loadedLayerCount] ? 0 } { 0 };
        required = if(assets.notNil) { assets[\requiredLayerCount] ? if(t == \electricPiano) { 33 } { 90 } } { if(t == \electricPiano) { 33 } { 90 } };
        status = if(assets.notNil) { assets[\status] ? \missing } { \unknown };
        complete = status == \complete;
        rep = (
            toneProfile: t,
            path: dir,
            pathExists: pathExists.(dir),
            assetStatus: status,
            loadedLayerCount: loaded,
            requiredLayerCount: required,
            complete: complete,
            currentlyRoutableByAT: [\piano, \electricPiano].includes(t),
            readyForRenderedSpectrumCapture: complete,
            pitchAuthorityEligible: false,
            note: "Verification follows loaded AT assets; manual sources need converters/verifiers before they become routable."
        );
        st[\sampleSourceRegistry][\lastVerificationReport] = rep;
        "".postln;
        "[AT SAMPLE SOURCE VERIFICATION REPORT]".postln;
        ("tone=" ++ t.asString ++ " status=" ++ status.asString ++ " loaded=" ++ loaded.asString ++ "/" ++ required.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceCacheMigrationPlan] = {
        var rep;
        rep = (
            globalRoot: cfg[\render][\sampleLibraryRoot],
            oldLocalSampleRoot: at[\baseDir] +/+ "samples",
            copyPianoCommand: "mkdir -p " ++ q.(cfg[\render][\pianoSamplesDir]) ++ " && cp -R " ++ q.(at[\baseDir] +/+ "samples/piano/.") ++ " " ++ q.(cfg[\render][\pianoSamplesDir]) ++ "/",
            copyEpianoCommand: "mkdir -p " ++ q.(cfg[\render][\epianoSamplesDir]) ++ " && cp -R " ++ q.(at[\baseDir] +/+ "samples/epiano/.") ++ " " ++ q.(cfg[\render][\epianoSamplesDir]) ++ "/",
            rebootRequiredAfterCopy: true,
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Use only if a previous candidate folder already contains legal samples you want to preserve in the global cache."
        );
        st[\sampleSourceRegistry][\lastMigrationPlan] = rep;
        "".postln;
        "[AT SAMPLE SOURCE CACHE MIGRATION PLAN]".postln;
        ("from=" ++ rep[\oldLocalSampleRoot].asString ++ " to=" ++ rep[\globalRoot].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleSourceLicenseReport] = {
        var rep;
        rep = (
            slenderSalamander: registry[\slenderSalamander][\license],
            salamanderFull: registry[\salamanderFull][\license],
            pianoIn162: registry[\pianoIn162][\license],
            iowaMIS: registry[\iowaPiano][\license],
            mattRhodes: registry[\mattsFenderRhodes][\license],
            mRhodes: registry[\mRhodes][\license],
            jRhodes3d: registry[\jRhodes3d][\license],
            mdaEPiano: registry[\mdaEPiano][\license],
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Keep source/license attribution with any sample-bearing package; manual community downloads are not bundled by AT."
        );
        st[\sampleSourceRegistry][\lastLicenseReport] = rep;
        "".postln;
        "[AT SAMPLE SOURCE LICENSE REPORT]".postln;
        "slender=CC-BY pianoIn162=manual/no-bundle jRhodes=CC-BY-NC pianobook=manual mda=MIT/GPL iowa=unrestricted pitchAuthority=false".postln;
        rep;
    };

    api[\sampleSourceNoPitchProofReport] = {
        var oldNode, oldResidual, a, b, c, d, sameNode, sameResidual;
        oldNode = st[\nodePhase].copy;
        oldResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        a = api[\sampleLibraryRootReport].();
        b = api[\sampleSourceRegistryReport].(\all);
        c = api[\sampleSourceRecommendationReport].(\all);
        d = api[\sampleSourceLicenseReport].();
        sameNode = st[\nodePhase] == oldNode;
        sameResidual = st[\perceptualCylinderResidualCents] == oldResidual;
        (
            reportsOk: a.notNil and: { b.notNil and: { c.notNil and: { d.notNil } } },
            nodePhaseUnchanged: sameNode,
            residualGridUnchanged: sameResidual,
            pitchAuthorityEligible: false,
            note: "sample-source registry is planning/verification only and cannot retune the instrument"
        )
    };

    "[AT SAMPLE SOURCE REGISTRY] v3D15c loaded: curated source registry + stable global cache + direct-add jRhodes target; no pitch/render behavior changed.".postln;
};
)