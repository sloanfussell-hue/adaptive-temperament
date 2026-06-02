(
// AT_direct_sample_installer.scd
// v3D38 direct sample bootstrap: fetches usable sources and builds AT-routable keygroups automatically before hosts load.
// This replaces the old EP manual-loop with a direct jRhodes3d download/build path and records the split between AT keygroup roots and jRhodes native source roots.
// It does not bundle restricted samples in the zip, fabricate fake Rhodes material,
// change tone engines, alter pitch/render behavior, write cylinder residuals, or
// authorize Sethares/cylinder pitch pressure.

var build, at, cfg, st, api, q, sq, pianoUrl, jRhodesUrl, root, pianoDir, epDir;
var jRhodesLicense, buildEpianoCommand, pianoCommand, allCommand, keygroupMap, layerNames, runInstallCommand, statusReport;

build = ~atBuild;

if(build.isNil) {
    "[AT DIRECT SAMPLE INSTALLER] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];

    if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
    if(st[\directSampleInstaller].isNil) { st[\directSampleInstaller] = IdentityDictionary.new; };

    q = { |s| "\"" ++ s.asString.replace("\\", "\\\\").replace("\"", "\\\"") ++ "\"" };
    // Full bash -lc scripts must be single-quoted at the launcher level.
    // Otherwise the parent shell can expand $TARGET/$EPDIR before bash receives the script.
    sq = { |s| "'" ++ s.asString.replace("'", "'\"'\"'") ++ "'" };

    root = cfg[\render][\sampleLibraryRoot] ? (Platform.userHomeDir +/+ "AdaptiveTemperament_samples");
    pianoDir = cfg[\render][\pianoSamplesDir] ? (root +/+ "piano/slender_salamander");
    epDir = cfg[\render][\epianoSamplesDir] ? (root +/+ "electric_piano/keygroups");
    pianoUrl = "https://musical-artifacts.com/artifacts/534/SlenderSalamander44khz16bit.zip";
    jRhodesUrl = "https://github.com/sfzinstruments/jlearman.jRhodes3d/archive/refs/heads/master.zip";
    jRhodesLicense = "jRhodes3d samples: CC BY-NC 4.0; control files/music-use terms: CC0; noncommercial sample redistribution unless licensed by Jeffrey Learman";

    keygroupMap = [
        (targetRoot: 36, sourceRoot: 35, sourceStem: "A_035__B1"),
        (targetRoot: 43, sourceRoot: 45, sourceStem: "A_045__A2"),
        (targetRoot: 48, sourceRoot: 50, sourceStem: "A_050__D3"),
        (targetRoot: 55, sourceRoot: 55, sourceStem: "A_055__G3"),
        (targetRoot: 60, sourceRoot: 59, sourceStem: "A_059__B3"),
        (targetRoot: 67, sourceRoot: 65, sourceStem: "A_065__F4"),
        (targetRoot: 72, sourceRoot: 71, sourceStem: "A_071__B4"),
        (targetRoot: 79, sourceRoot: 81, sourceStem: "A_081__A5"),
        (targetRoot: 84, sourceRoot: 86, sourceStem: "A_086__D6"),
        (targetRoot: 91, sourceRoot: 91, sourceStem: "A_091__G6"),
        (targetRoot: 96, sourceRoot: 96, sourceStem: "A_096__C7")
    ];
    layerNames = [\soft, \med, \hard];

    pianoCommand = {
        var shell;
        shell = "set -e\n"
            ++ "TARGET=" ++ q.(pianoDir) ++ "\n"
            ++ "ZIP=\"$TARGET/SlenderSalamander44khz16bit.zip\"\n"
            ++ "SAMPLEDIR=\"$TARGET/SlenderSalamander44khz16bit/samples\"\n"
            ++ "mkdir -p \"$TARGET\"\n"
            ++ "echo 'AT direct piano install target:' \"$TARGET\"\n"
            ++ "set +e\n"
            ++ "python3 - \"$SAMPLEDIR\" <<'PY'\n"
            ++ "import os, sys, glob\n"
            ++ "sample_dir = sys.argv[1]\n"
            ++ "count = len(glob.glob(os.path.join(sample_dir, '*.wav'))) if os.path.isdir(sample_dir) else 0\n"
            ++ "print('AT existing Slender sample wav count:', count, 'folder:', sample_dir)\n"
            ++ "raise SystemExit(0 if count >= 90 else 2)\n"
            ++ "PY\n"
            ++ "STATUS=$?\n"
            ++ "set -e\n"
            ++ "if [ \"$STATUS\" = \"0\" ]; then\n"
            ++ "  echo 'AT Slender already complete; skipping piano download.'\n"
            ++ "else\n"
            ++ "  curl -L --fail --retry 3 --retry-delay 2 -o \"$ZIP\" " ++ q.(pianoUrl) ++ "\n"
            ++ "  unzip -o \"$ZIP\" -d \"$TARGET\"\n"
            ++ "fi\n"
            ++ "python3 - \"$TARGET\" <<'PY'\n"
            ++ "import os, sys, glob\n"
            ++ "target = sys.argv[1]\n"
            ++ "sample_dir = os.path.join(target, 'SlenderSalamander44khz16bit', 'samples')\n"
            ++ "files = glob.glob(os.path.join(sample_dir, '*.wav'))\n"
            ++ "print('AT Slender sample wav count:', len(files), 'folder:', sample_dir)\n"
            ++ "if len(files) < 90:\n"
            ++ "    raise SystemExit('Slender install incomplete: expected at least 90 wav files, got %d' % len(files))\n"
            ++ "PY\n"
            ++ "echo 'AT Slender direct-add install complete. Reboot AdaptiveTemperament_run.scd to load piano samples.'\n";
        "bash -lc " ++ sq.(shell);
    }.();

    buildEpianoCommand = {
        var py, shell;
        py = "import os, sys, glob, shutil, re, json\n"
            ++ "epdir = sys.argv[1]\n"
            ++ "download_dir = sys.argv[2]\n"
            ++ "os.makedirs(epdir, exist_ok=True)\n"
            ++ "existing = glob.glob(os.path.join(epdir, 'EP_*_*.flac')) + glob.glob(os.path.join(epdir, 'EP_*_*.wav'))\n"
            ++ "if len(existing) >= 33:\n"
            ++ "    print('AT EP keygroups already complete:', len(existing), 'target:', epdir)\n"
            ++ "    raise SystemExit(0)\n"
            ++ "sfz_files = glob.glob(os.path.join(download_dir, '**', 'jRhodes3d-mono.sfz'), recursive=True)\n"
            ++ "if not sfz_files:\n"
            ++ "    raise SystemExit('jRhodes3d-mono.sfz not found after unzip; check curl/unzip output and archive layout')\n"
            ++ "sfz = sfz_files[0]\n"
            ++ "root_dir = os.path.dirname(sfz)\n"
            ++ "text = open(sfz, 'r', encoding='utf-8', errors='ignore').read()\n"
            ++ "m = re.search(r'prefix_sfz_path=([^\\s]+)', text)\n"
            ++ "prefix = m.group(1).strip().strip('\\\"') if m else 'jRhodes3d-mono/'\n"
            ++ "src_dirs = [os.path.join(root_dir, prefix), os.path.join(root_dir, 'jRhodes3d-mono')]\n"
            ++ "src_dirs += [p for p in glob.glob(os.path.join(os.path.dirname(root_dir), '**', 'jRhodes3d-mono'), recursive=True) if os.path.isdir(p)]\n"
            ++ "file_index = {}\n"
            ++ "for d in src_dirs + [root_dir, os.path.dirname(root_dir)]:\n"
            ++ "    if os.path.isdir(d):\n"
            ++ "        for f in glob.glob(os.path.join(d, '**', '*.flac'), recursive=True):\n"
            ++ "            file_index.setdefault(os.path.basename(f), f)\n"
            ++ "print('AT jRhodes3d sfz:', sfz)\n"
            ++ "print('AT jRhodes3d discovered flac count:', len(file_index))\n"
            ++ "mapping = [(36,35,'A_035__B1'),(43,45,'A_045__A2'),(48,50,'A_050__D3'),(55,55,'A_055__G3'),(60,59,'A_059__B3'),(67,65,'A_065__F4'),(72,71,'A_071__B4'),(79,81,'A_081__A5'),(84,86,'A_086__D6'),(91,91,'A_091__G6'),(96,96,'A_096__C7')]\n"
            ++ "layers = {'soft':['5','4','3','2','1'], 'med':['3','4','2','5','1'], 'hard':['1','2','3','4','5']}\n"
            ++ "copied = []\n"
            ++ "missing = []\n"
            ++ "for target_root, source_root, stem in mapping:\n"
            ++ "    tag = f'{target_root:03d}'\n"
            ++ "    for layer, choices in layers.items():\n"
            ++ "        picked = None\n"
            ++ "        picked_name = None\n"
            ++ "        for suffix in choices:\n"
            ++ "            name = f'{stem}_{suffix}.flac'\n"
            ++ "            if name in file_index:\n"
            ++ "                picked = file_index[name]\n"
            ++ "                picked_name = name\n"
            ++ "                break\n"
            ++ "        target = os.path.join(epdir, f'EP_{tag}_{layer}.flac')\n"
            ++ "        if picked is None:\n"
            ++ "            missing.append(f'{stem}_{choices[0]}.flac -> {target}')\n"
            ++ "        else:\n"
            ++ "            shutil.copy2(picked, target)\n"
            ++ "            copied.append((picked_name, target))\n"
            ++ "manifest = {'format':'AT_epiano_keygroups_v3D38','rootSemantics':'EP_### is the AT keygroup/selection root, not always the native source pitch','sourceRootPolicy':'sourceRootMidi from jRhodes3d source stem is used by the host as rootFreq','zoneBoundaryPolicy':'host chooses nearest native source-root zones, not only EP tag midpoints','mapping':[{'targetRoot':t,'sourceRoot':s,'sourceStem':stem,'formerWrongRootErrorCents':(s-t)*100} for (t,s,stem) in mapping]}\n"
            ++ "with open(os.path.join(epdir, 'AT_epiano_keygroup_manifest.json'), 'w', encoding='utf-8') as mf:\n"
            ++ "    json.dump(manifest, mf, indent=2, sort_keys=True)\n"
            ++ "lics = glob.glob(os.path.join(download_dir, '**', 'LICENSE'), recursive=True)\n"
            ++ "if lics:\n"
            ++ "    shutil.copy2(lics[0], os.path.join(epdir, 'jRhodes3d_LICENSE_CC_BY_NC.txt'))\n"
            ++ "if missing:\n"
            ++ "    raise SystemExit('missing jRhodes3d source samples: ' + '; '.join(missing))\n"
            ++ "print('AT target example EP_060_med.flac from A_059__B3; host rootFreq uses native sourceRootMidi=59 and v3D38 chooses nearest native source zones')\n"
            ++ "print('AT jRhodes3d keygroups copied:', len(copied), 'target:', epdir)\n"
            ++ "print('AT jRhodes3d middle examples:', [x for x in copied if 'EP_060' in x[1]])\n";
        shell = "set -e\n"
            ++ "ROOT=" ++ q.(root) ++ "\n"
            ++ "EPDIR=" ++ q.(epDir) ++ "\n"
            ++ "DL=\"$ROOT/_downloads\"\n"
            ++ "mkdir -p \"$DL\" \"$EPDIR\"\n"
            ++ "echo 'AT direct Rhodes install target:' \"$EPDIR\"\n"
            ++ "set +e\n"
            ++ "python3 - \"$EPDIR\" <<'PY'\n"
            ++ "import os, sys, glob\n"
            ++ "epdir = sys.argv[1]\n"
            ++ "files = glob.glob(os.path.join(epdir, 'EP_*_*.flac')) + glob.glob(os.path.join(epdir, 'EP_*_*.wav'))\n"
            ++ "print('AT existing EP keygroup count:', len(files), 'folder:', epdir)\n"
            ++ "raise SystemExit(0 if len(files) >= 33 else 2)\n"
            ++ "PY\n"
            ++ "STATUS=$?\n"
            ++ "set -e\n"
            ++ "if [ \"$STATUS\" = \"0\" ]; then\n"
            ++ "  echo 'AT EP keygroups already complete; skipping jRhodes download/build.'\n"
            ++ "else\n"
            ++ "  cd \"$DL\"\n"
            ++ "  curl -L --fail --retry 3 --retry-delay 2 -o jRhodes3d-master.zip " ++ q.(jRhodesUrl) ++ "\n"
            ++ "  rm -rf jlearman.jRhodes3d-master jRhodes3d-master\n"
            ++ "  unzip -o jRhodes3d-master.zip\n"
            ++ "  python3 - \"$EPDIR\" \"$DL\" <<'PY'\n" ++ py ++ "PY\n"
            ++ "fi\n"
            ++ "python3 - \"$EPDIR\" <<'PY'\n"
            ++ "import os, sys, glob\n"
            ++ "epdir = sys.argv[1]\n"
            ++ "files = glob.glob(os.path.join(epdir, 'EP_*_*.flac')) + glob.glob(os.path.join(epdir, 'EP_*_*.wav'))\n"
            ++ "print('AT EP keygroup count:', len(files), 'folder:', epdir)\n"
            ++ "if len(files) < 33:\n"
            ++ "    raise SystemExit('EP keygroup build incomplete: expected 33 keygroups, got %d' % len(files))\n"
            ++ "PY\n"
            ++ "echo 'AT jRhodes3d direct-add build complete. Reboot AdaptiveTemperament_run.scd to load EP keygroups.'\n";
        "bash -lc " ++ sq.(shell);
    };

    runInstallCommand = { |cmd, label="direct sample install"|
        var output;
        ("[AT DIRECT SAMPLE INSTALL] running blocking shell command: " ++ label.asString).postln;
        "Do not reboot until this command returns and prints completion/verification lines.".postln;
        output = (cmd ++ " 2>&1").unixCmdGetStdOut;
        output.postln;
        st[\directSampleInstaller][\lastInstallOutput] = output;
        output;
    };

    api[\directSampleInstallerReport] = {
        var rep;
        rep = (
            pianoDirectAdd: true,
            pianoSource: \slenderSalamander,
            pianoUrl: pianoUrl,
            pianoTargetDir: pianoDir,
            electricPianoDirectAdd: true,
            electricPianoSource: \jRhodes3d,
            electricPianoUrl: jRhodesUrl,
            electricPianoTargetDir: epDir,
            electricPianoExpectedLayers: 33,
            electricPianoLicense: jRhodesLicense,
            keygroupFormat: "EP_###_(soft|med|hard).flac; EP_### is a selection tag; sourceRoot is native jRhodes pitch; host chooses nearest native source zones; EP host also accepts legacy .wav",
            noFakeSamples: true,
            pitchAuthorityEligible: false,
            note: "Direct-add means AT can fetch, unpack, build host-compatible keygroups, and verify after reboot. No pitch/render behavior changes."
        );
        st[\directSampleInstaller][\lastReport] = rep;
        "".postln;
        "[AT DIRECT SAMPLE INSTALLER REPORT]".postln;
        ("piano=slender direct=true epiano=jRhodes3d direct=true expectedEP=33 pitchAuthority=false").postln;
        rep;
    };

    api[\directSampleInstallPlan] = {
        var epCmd, rep;
        epCmd = buildEpianoCommand.();
        allCommand = pianoCommand ++ " ; " ++ epCmd;
        rep = (
            pianoCommand: pianoCommand,
            epianoCommand: epCmd,
            allCommand: allCommand,
            pianoSource: \slenderSalamander,
            electricPianoSource: \jRhodes3d,
            electricPianoExpectedLayers: 33,
            electricPianoTargetDir: epDir,
            electricPianoRootSemantics: \keygroupRootSeparateFromNativeSourceRoot,
            electricPianoZoneBoundaryPolicy: \nearestNativeSourceRootMidpoints,
            keygroupMap: keygroupMap,
            layerNames: layerNames,
            licenseNote: jRhodesLicense,
            noGeneratedFakeSamples: true,
            noFakePiano: true,
            noFakeEpiano: true,
            pitchAuthorityEligible: false,
            samplePlaybackRootFix: \sourceRootMidiUsedForRootFreq,
            samplePlaybackZoneFix: \nearestNativeSourceRootMidpoints,
            rebootRequired: true,
            note: "Run installDirectAdaptiveTemperamentSamples on a machine with internet; v3D15c skips already-complete caches, runs piano/Rhodes as independent blocking steps, waits for curl/unzip/python verification, then requires reboot."
        );
        st[\directSampleInstaller][\lastPlan] = rep;
        "".postln;
        "[AT DIRECT SAMPLE INSTALL PLAN]".postln;
        ("piano=slender epiano=jRhodes3d epLayers=33 target=" ++ epDir.asString ++ " pitchAuthority=false").postln;
        rep;
    };

    api[\installDirectPianoSamples] = {
        var plan;
        plan = api[\directSampleInstallPlan].();
        "".postln;
        "[AT DIRECT PIANO INSTALL]".postln;
        "Downloading Slender Salamander directly into the global piano cache. Reboot after completion.".postln;
        runInstallCommand.(plan[\pianoCommand], \piano);
        plan;
    };

    api[\installDirectRhodesSamples] = {
        var plan;
        plan = api[\directSampleInstallPlan].();
        "".postln;
        "[AT DIRECT RHODES INSTALL]".postln;
        "Downloading jRhodes3d and building AT EP_###_(soft|med|hard).flac keygroups. Reboot after completion.".postln;
        runInstallCommand.(plan[\epianoCommand], \electricPiano);
        plan;
    };

    api[\installDirectAdaptiveTemperamentSamples] = { |includePiano=true, includeRhodes=true|
        var plan;
        plan = api[\directSampleInstallPlan].();
        "".postln;
        "[AT DIRECT SAMPLE INSTALL]".postln;
        "Installing direct-add sample sources into the stable global cache as independent blocking steps.".postln;
        "Do not reboot until the requested piano/Rhodes step(s) return completion or error output.".postln;
        if(includePiano == true) {
            runInstallCommand.(plan[\pianoCommand], \piano)
        };
        if(includeRhodes == true) {
            runInstallCommand.(plan[\epianoCommand], \electricPiano)
        };
        st[\directSampleInstaller][\lastInstallStarted] = plan;
        api[\directSampleInstallStatusReport].();
        plan;
    };

    // Backward-compatible alias: older handoffs used installAdaptiveTemperamentSamples.
    // v3D15 makes that command actually install the direct Rhodes source too.
    api[\installAdaptiveTemperamentSamples] = { |includeRhodes=true|
        api[\installDirectAdaptiveTemperamentSamples].(true, includeRhodes)
    };

    api[\downloadJRhodes3dSource] = { api[\installDirectRhodesSamples].() };

    statusReport = {
        var pianoSampleDir, pianoCount, epPathExists, epFiles, epCount, rep;
        pianoSampleDir = pianoDir +/+ "SlenderSalamander44khz16bit/samples";
        pianoCount = if(File.exists(pianoSampleDir)) {
            PathName(pianoSampleDir).files.count { |f| f.fullPath.asString.find(".wav").notNil }
        } { 0 };
        epPathExists = File.exists(epDir);
        epFiles = if(epPathExists) {
            PathName(epDir).files.select { |f|
                (f.fileName.asString.find("EP_") == 0 and: {
                    f.fullPath.asString.find(".flac").notNil or: { f.fullPath.asString.find(".wav").notNil }
                })
            }
        } { [] };
        epCount = epFiles.size;
        rep = (
            pianoDir: pianoDir,
            pianoSampleCount: pianoCount,
            pianoComplete: pianoCount >= 90,
            epianoDir: epDir,
            epianoKeygroupCount: epCount,
            epianoComplete: epCount >= 33,
            rebootRequiredAfterInstall: true,
            pitchAuthorityEligible: false,
            note: "filesystem status only; manual install after hosts load requires reboot, but first-boot auto-bootstrap runs before hosts so the same boot can load newly installed buffers"
        );
        st[\directSampleInstaller][\lastStatusReport] = rep;
        "".postln;
        "[AT DIRECT SAMPLE INSTALL STATUS REPORT]".postln;
        ("pianoFiles=" ++ pianoCount.asString ++ "/90 epianoKeygroups=" ++ epCount.asString ++ "/33 pitchAuthority=false").postln;
        rep;
    };

    api[\directSampleInstallStatusReport] = { statusReport.() };


    api[\autoInstallDirectSamplesIfMissing] = { |includePiano=true, includeRhodes=true, force=false|
        var status, plan, needsPiano, needsRhodes, rep;
        status = api[\directSampleInstallStatusReport].();
        needsPiano = includePiano == true and: { (force == true) or: { status[\pianoComplete] != true } };
        needsRhodes = includeRhodes == true and: { (force == true) or: { status[\epianoComplete] != true } };
        rep = (
            autoBootstrap: true,
            bootSafeBeforeHosts: true,
            includePiano: includePiano,
            includeRhodes: includeRhodes,
            neededPiano: needsPiano,
            neededRhodes: needsRhodes,
            pitchAuthorityEligible: false,
            note: "This is the normal first-boot sample bootstrap. It should run before piano/EP sample hosts load, so no manual install/reboot loop is required when internet is available."
        );
        st[\directSampleInstaller][\lastAutoBootstrapReport] = rep;
        "".postln;
        "[AT DIRECT SAMPLE AUTO-BOOTSTRAP]".postln;
        ("neededPiano=" ++ needsPiano.asString ++ " neededRhodes=" ++ needsRhodes.asString ++ " pitchAuthority=false").postln;
        if(needsPiano or: { needsRhodes }) {
            "Missing direct-add samples detected. Running blocking first-boot installer before sample hosts load.".postln;
            "This replaces the old manual command loop; wait for completion/errors in the post window.".postln;
            plan = api[\directSampleInstallPlan].();
            if(needsPiano) { runInstallCommand.(plan[\pianoCommand], \autoPiano) };
            if(needsRhodes) { runInstallCommand.(plan[\epianoCommand], \autoElectricPiano) };
            status = api[\directSampleInstallStatusReport].();
            rep = rep.put(\afterInstallStatus, status);
            st[\directSampleInstaller][\lastAutoBootstrapReport] = rep;
            if(status[\pianoComplete] == true and: { status[\epianoComplete] == true }) {
                "[AT DIRECT SAMPLE AUTO-BOOTSTRAP] complete. Because this ran before sample hosts loaded, this same boot can load the buffers.".postln;
            } {
                "[AT DIRECT SAMPLE AUTO-BOOTSTRAP] incomplete. Hosts will fall back honestly; inspect last install output above.".warn;
            };
        } {
            "Direct-add sample cache already complete or skipped by settings; no download/build needed.".postln;
        };
        rep;
    };

    api[\directSampleNoPitchProofReport] = {
        var oldNode, oldResidual, a, b, sameNode, sameResidual;
        oldNode = st[\nodePhase].copy;
        oldResidual = (st[\perceptualCylinderResidualCents] ? Array.new).collect { |row| (row ? Array.new).copy };
        a = api[\directSampleInstallerReport].();
        b = api[\directSampleInstallPlan].();
        api[\directSampleInstallStatusReport].();
        sameNode = st[\nodePhase] == oldNode;
        sameResidual = st[\perceptualCylinderResidualCents] == oldResidual;
        (
            reportsOk: a.notNil and: { b.notNil },
            nodePhaseUnchanged: sameNode,
            residualGridUnchanged: sameResidual,
            pitchAuthorityEligible: false,
            note: "direct installer reports/commands are sample material workflow only; they do not retune the field"
        )
    };

    "[AT DIRECT SAMPLE INSTALLER] v3D16b loaded: first-boot direct Slender + jRhodes3d auto-bootstrap installer; no pitch/render behavior changed.".postln;
};
)
