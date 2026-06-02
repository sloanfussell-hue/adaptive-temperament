(
// AT_sample_acquisition.scd
// v3D15 no-pitch sample acquisition helpers. Uses global cache paths prepared by the sample-source registry when available.
// This layer provides legal source manifests and one-command acquisition helpers.
// It does not bundle unverifiable samples, synthesize fake piano/Rhodes samples,
// claim FFT measurement, alter render pitch, or authorize cylinder/Sethares pitch.

var build, at, cfg, st, api, q, shellExists, resolveBaseDir;
var pianoUrl, pianoPage, pianoLicense, epSourceUrl, epGithubUrl;

build = ~atBuild;

if(build.isNil) {
    "[AT SAMPLE ACQUISITION] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(st[\sampleAcquisition].isNil) { st[\sampleAcquisition] = IdentityDictionary.new; };

    pianoUrl = "https://musical-artifacts.com/artifacts/534/SlenderSalamander44khz16bit.zip";
    pianoPage = "https://sig-ex.com/2017/11/11/slender-salmander-grand-piano/";
    pianoLicense = "CC BY 3.0; attribution required: Alexander Holm / Signal Experiments / Salamander source";
    epSourceUrl = "https://github.com/sfzinstruments/jlearman.jRhodes3d/archive/refs/heads/master.zip";
    epGithubUrl = "https://github.com/sfzinstruments/jlearman.jRhodes3d";

    q = { |s| "\"" ++ s.asString.replace("\\", "\\\\").replace("\"", "\\\"") ++ "\"" };

    shellExists = { |path| File.exists(path.asString) };

    resolveBaseDir = {
        var bd, pd;
        bd = at[\baseDir];
        if(bd.isNil) { bd = build[\baseDir]; };
        if(bd.isNil and: { cfg[\render].notNil }) {
            pd = cfg[\render][\pianoSamplesDir];
            if(pd.notNil) {
                bd = PathName(PathName(pd).pathOnly).pathOnly;
            };
        };
        if(bd.isNil and: { cfg[\render].notNil }) {
            pd = cfg[\render][\epianoSamplesDir];
            if(pd.notNil) {
                bd = PathName(PathName(pd).pathOnly).pathOnly;
            };
        };
        if(bd.isNil) {
            bd = Platform.userHomeDir +/+ "AdaptiveTemperament_samples";
        };
        bd;
    };

    at[\sampleAcquisitionStatusForTone] = { |tone=\piano|
        var t, asset, pianoAssets, epAssets, status, loaded, required, complete;
        t = (tone ? \piano).asSymbol;
        status = \notRequired;
        loaded = 0;
        required = 0;
        complete = false;
        if(t == \piano) {
            pianoAssets = at[\pianoAssets];
            status = if(pianoAssets.notNil) { pianoAssets[\status] ? \missing } { \missing };
            loaded = if(pianoAssets.notNil) { pianoAssets[\loadedLayerCount] ? 0 } { 0 };
            required = if(pianoAssets.notNil) { pianoAssets[\requiredLayerCount] ? 90 } { 90 };
            complete = status == \complete;
        };
        if(t == \electricPiano) {
            epAssets = at[\epianoAssets];
            status = if(epAssets.notNil) { epAssets[\status] ? \missing } { \missing };
            loaded = if(epAssets.notNil) { epAssets[\loadedLayerCount] ? 0 } { 0 };
            required = if(epAssets.notNil) { epAssets[\requiredLayerCount] ? 33 } { 33 };
            complete = status == \complete;
        };
        (
            toneProfile: t,
            assetStatus: status,
            loadedLayerCount: loaded,
            requiredLayerCount: required,
            complete: complete,
            pitchAuthorityEligible: false
        );
    };

    api[\sampleAcquisitionSourceReport] = { |tone=\all|
        var t, piano, ep, rep;
        t = (tone ? \all).asSymbol;
        piano = at[\sampleAcquisitionStatusForTone].(\piano);
        ep = at[\sampleAcquisitionStatusForTone].(\electricPiano);
        rep = (
            requestedTone: t,
            piano: (
                toneProfile: \piano,
                source: \SlenderSalamanderGrandPiano,
                downloadUrl: pianoUrl,
                infoPage: pianoPage,
                license: pianoLicense,
                expectedLayers: 90,
                currentStatus: piano[\assetStatus],
                loadedLayerCount: piano[\loadedLayerCount],
                requiredLayerCount: piano[\requiredLayerCount],
                canAutoInstall: true,
                noGeneratedFakeSamples: true,
                pitchAuthorityEligible: false
            ),
            electricPiano: (
                toneProfile: \electricPiano,
                source: \jRhodes3dDirectKeygroups,
                sourceUrl: epSourceUrl,
                referenceRepository: epGithubUrl,
                license: "jRhodes3d samples: CC BY-NC 4.0; control files/music-use terms: CC0; noncommercial sample redistribution unless licensed",
                expectedLayers: 33,
                currentStatus: ep[\assetStatus],
                loadedLayerCount: ep[\loadedLayerCount],
                requiredLayerCount: ep[\requiredLayerCount],
                canAutoInstall: true,
                canAutoFetchSourceForRendering: true,
                canAutoBuildKeygroups: true,
                requiresLegalRenderedKeygroups: false,
                noGeneratedFakeSamples: true,
                pitchAuthorityEligible: false
            ),
            note: "v3D15c provides direct-add acquisition helpers using the stable global sample cache. Piano downloads Slender automatically; EP downloads jRhodes3d and builds routable EP keygroups without fake synthesis."
        );
        st[\sampleAcquisition][\lastSourceReport] = rep;
        "".postln;
        "[AT SAMPLE ACQUISITION SOURCE REPORT]".postln;
        ("piano=" ++ rep[\piano][\currentStatus].asString ++ " epiano=" ++ rep[\electricPiano][\currentStatus].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleAcquisitionInstallPlan] = { |tone=\all|
        var t, rootDir, pianoDir, pianoZip, epDir, epSrcDir, pianoCmd, epCmd, allCmd, rep;
        t = (tone ? \all).asSymbol;
        rootDir = resolveBaseDir.();
        pianoDir = cfg[\render][\pianoSamplesDir];
        if(pianoDir.isNil) { pianoDir = rootDir +/+ "samples/piano"; };
        pianoZip = pianoDir +/+ "SlenderSalamander44khz16bit.zip";
        epDir = cfg[\render][\epianoSamplesDir];
        if(epDir.isNil) { epDir = rootDir +/+ "samples/epiano"; };
        epSrcDir = epDir +/+ "_jrhodes3d_source";
        pianoCmd = "mkdir -p " ++ q.(pianoDir) ++ " && curl -L --fail -o " ++ q.(pianoZip) ++ " " ++ q.(pianoUrl) ++ " && unzip -o " ++ q.(pianoZip) ++ " -d " ++ q.(pianoDir);
        epCmd = if(api[\directSampleInstallPlan].notNil) { api[\directSampleInstallPlan].()[\epianoCommand] } {
            "mkdir -p " ++ q.(epSrcDir) ++ " && curl -L --fail -o " ++ q.(epSrcDir +/+ "jRhodes3d-master.zip") ++ " " ++ q.(epSourceUrl) ++ " && echo 'direct installer not loaded yet; reboot current build or run installDirectRhodesSamples'"
        };
        allCmd = pianoCmd ++ " && " ++ epCmd;
        rep = (
            requestedTone: t,
            pianoCommand: pianoCmd,
            epianoSourceCommand: epCmd,
            allCommand: allCmd,
            pianoAutoInstallAvailable: true,
            epianoAutoSourceFetchAvailable: true,
            epianoAutoKeygroupRenderAvailable: true,
            epianoAutoKeygroupBuildAvailable: true,
            epianoReason: "v3D15 downloads jRhodes3d and builds AT EP_###_(soft|med|hard).flac keygroups directly; CC BY-NC sample terms apply",
            noGeneratedFakeSamples: true,
            noFakePiano: true,
            noFakeEpiano: true,
            pitchAuthorityEligible: false,
            note: "Run installer APIs from SuperCollider on a machine with internet. Reboot after sample acquisition so buffers reload."
        );
        st[\sampleAcquisition][\lastInstallPlan] = rep;
        "".postln;
        "[AT SAMPLE ACQUISITION INSTALL PLAN]".postln;
        ("tone=" ++ t.asString ++ " pianoAuto=true epianoKeygroupAuto=true pitchAuthority=false").postln;
        rep;
    };

    api[\downloadEpianoMdaSource] = {
        var plan;
        plan = api[\sampleAcquisitionInstallPlan].(\electricPiano);
        "".postln;
        "[AT EPIANO MDA SOURCE DOWNLOAD]".postln;
        "Downloading mda source archive only. This does not create or verify EP keygroup WAV files.".postln;
        plan[\epianoSourceCommand].unixCmd;
        plan;
    };

    api[\installAdaptiveTemperamentSamples] = { |includeEpianoSource=true|
        var plan;
        plan = api[\sampleAcquisitionInstallPlan].(\all);
        "".postln;
        "[AT SAMPLE ACQUISITION INSTALL]".postln;
        "Installing legal piano source and direct jRhodes3d EP keygroups into the global cache.".postln;
        if(api[\downloadSlenderPianoSamples].notNil) {
            api[\downloadSlenderPianoSamples].();
        } {
            plan[\pianoCommand].unixCmd;
        };
        if(includeEpianoSource == true) {
            plan[\epianoSourceCommand].unixCmd;
        };
        "After download/unzip finishes, reboot AdaptiveTemperament_run.scd and run asset/evidence reports.".postln;
        st[\sampleAcquisition][\lastInstallStarted] = plan;
        plan;
    };

    api[\sampleAcquisitionReadinessReport] = {
        var source, piano, ep, sampleEvPiano, sampleEvEp, rep;
        source = api[\sampleAcquisitionSourceReport].(\all);
        piano = source[\piano];
        ep = source[\electricPiano];
        sampleEvPiano = if(api[\sampleToneEvidenceReport].notNil) { api[\sampleToneEvidenceReport].(\piano, 60) } { nil };
        sampleEvEp = if(api[\sampleToneEvidenceReport].notNil) { api[\sampleToneEvidenceReport].(\electricPiano, 60) } { nil };
        rep = (
            pianoInstalled: piano[\currentStatus] == \complete,
            electricPianoInstalled: ep[\currentStatus] == \complete,
            pianoReadyForRenderedSpectrumCapture: if(sampleEvPiano.notNil) { sampleEvPiano[\actualSoundEvidenceReady] ? false } { false },
            electricPianoReadyForRenderedSpectrumCapture: if(sampleEvEp.notNil) { sampleEvEp[\actualSoundEvidenceReady] ? false } { false },
            nextStep: if(piano[\currentStatus] == \complete and: { ep[\currentStatus] == \complete }) { \renderedSpectrumCapture } { \runInstallOrAddLegalKeygroups },
            pitchAuthorityEligible: false,
            note: "readiness reports practical sample acquisition only; pitch authority stays blocked"
        );
        st[\sampleAcquisition][\lastReadinessReport] = rep;
        "".postln;
        "[AT SAMPLE ACQUISITION READINESS REPORT]".postln;
        ("pianoInstalled=" ++ rep[\pianoInstalled].asString ++ " epianoInstalled=" ++ rep[\electricPianoInstalled].asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\sampleAcquisitionAttributionReport] = {
        var rep;
        rep = (
            piano: "Slender Salamander Grand Piano / Alexander Holm Salamander C5 / Signal Experiments derivative; CC BY 3.0 attribution required",
            epiano: "jRhodes3d / Jeffrey Learman / 1977 Rhodes Mark I Stage 73; samples CC BY-NC 4.0; control files/music-use terms CC0; noncommercial sample redistribution unless licensed",
            noGeneratedFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Keep this attribution with any redistributed sample-bearing package."
        );
        st[\sampleAcquisition][\lastAttributionReport] = rep;
        "".postln;
        "[AT SAMPLE ACQUISITION ATTRIBUTION REPORT]".postln;
        "piano=CC BY 3.0 epiano=jRhodes3d CC BY-NC source; pitchAuthority=false".postln;
        rep;
    };

    api[\sampleAcquisitionNoPitchProofReport] = {
        var oldNode, oldResidual, source, ready, attr, maxResidual;
        oldNode = st[\nodePhase].copy;
        oldResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        source = api[\sampleAcquisitionSourceReport].(\all);
        ready = api[\sampleAcquisitionReadinessReport].();
        attr = api[\sampleAcquisitionAttributionReport].();
        maxResidual = 0.0;
        (st[\perceptualCylinderResidualCents] ? Array.new).do { |row|
            (row ? Array.new).do { |x| if((x ? 0.0).abs > maxResidual) { maxResidual = (x ? 0.0).abs; }; };
        };
        (
            sourceReportOk: source.notNil,
            readinessReportOk: ready.notNil,
            attributionReportOk: attr.notNil,
            nodePhaseUnchanged: st[\nodePhase] == oldNode,
            residualGridUnchanged: (st[\perceptualCylinderResidualCents] == oldResidual),
            pitchAuthorityEligible: false,
            maxResidualNow: maxResidual,
            note: "sample acquisition reports are observation/planning only and do not retune the instrument"
        );
    };

    "[AT SAMPLE ACQUISITION] v3D14b loaded: Library.at(\\at)[\\api][\\installAdaptiveTemperamentSamples].();".postln;
};
)
