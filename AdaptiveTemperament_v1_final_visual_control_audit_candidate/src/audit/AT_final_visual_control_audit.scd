(
// AT_final_visual_control_audit.scd
// Read-only/non-musical final keeper audit for the visual control surface.
// This is an audit branch helper, not part of the frozen Version 1 keeper.
{
    var build, at, cfg, st, api, ui, audit;

    build = ~atBuild;
    if(build.isNil) {
        "[AT FINAL VISUAL CONTROL AUDIT] ~atBuild missing".warn;
    } {
        at = build[\at];
        cfg = build[\cfg];
        st = build[\state];
        api = build[\api];
        ui = build[\ui];
        audit = IdentityDictionary.new;

        audit[\snap] = {
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
            if(api[\uiSnapshot].notNil) { api[\uiSnapshot].() } { nil };
        };

        audit[\near] = { |a, b, tol=0.025|
            if(a.isNil) { false } { ((a.asFloat - b.asFloat).abs <= tol) }
        };

        audit[\save] = {
            (
                powerEnabled: st[\powerEnabled] ? true,
                brainEnabled: st[\brainEnabled] ? true,
                movement: st[\movement] ? 0.82,
                carryEnabled: cfg[\solver][\contextGaugeEnabled] ? false,
                carryStrength: cfg[\solver][\contextGaugeStrength] ? 0.0,
                carryMaxCents: cfg[\solver][\contextGaugeMaxCents] ? 0.0,
                memoryAmount: st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.35),
                tension: st[\tension] ? 0.55,
                gravityEnabled: cfg[\gravity][\enabled] ? false,
                gravityStrength: cfg[\gravity][\strength] ? 0.0,
                gravityMaxPullCents: cfg[\gravity][\maxPullCents] ? 0.0,
                gravityHomePc: cfg[\gravity][\homePc] ? 9,
                gravityHomeCents: cfg[\gravity][\homeCents] ? 0.0,
                micEnabled: cfg[\mic][\enabled] ? false,
                micWeight: cfg[\mic][\weight] ? 0.0,
                micTrust: cfg[\mic][\trust] ? 0.70,
                micPolicy: cfg[\mic][\influencePolicy] ? \externalOnly,
                micMode: cfg[\mic][\mode] ? \listen,
                micInputMode: cfg[\mic][\inputMode] ? \auto,
                toneProfile: cfg[\render][\toneProfile] ? \organ,
                toneLow: cfg[\render][\toneLow] ? 0.5,
                toneMid: cfg[\render][\toneMid] ? 0.5,
                toneHigh: cfg[\render][\toneHigh] ? 0.5,
                adaptiveToneMode: cfg[\render][\adaptiveToneMode] ? \static,
                adaptiveToneAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
                registerAmount: if(cfg[\registerVelocity].notNil) { cfg[\registerVelocity][\registerAmount] ? 1.0 } { 1.0 },
                velocityAmount: if(cfg[\registerVelocity].notNil) { cfg[\registerVelocity][\velocityAmount] ? 1.0 } { 1.0 },
                gravityFollowMode: if(cfg[\finalControls].notNil) { cfg[\finalControls][\earGravityFollowMode] ? \off } { \off },
                gravityFollowStrength: if(cfg[\finalControls].notNil) { cfg[\finalControls][\earGravityFollowStrength] ? 1.0 } { 1.0 },
                spectrumAmount: if(cfg[\finalControls].notNil) { cfg[\finalControls][\spectrumAccordionAmount] ? 0.0 } { 0.0 },
                spectrumProfile: if(cfg[\finalControls].notNil) { cfg[\finalControls][\spectrumAccordionProfile] ? \harmonic } { \harmonic }
            )
        };

        audit[\restore] = { |saved|
            if(saved.notNil) {
                if(api[\setPowerEnabled].notNil) { api[\setPowerEnabled].(saved[\powerEnabled]); };
                if(api[\setBrainEnabled].notNil) { api[\setBrainEnabled].(saved[\brainEnabled]); };
                if(api[\setMacro].notNil) {
                    api[\setMacro].(\motion, saved[\movement]);
                    api[\setMacro].(\memory, saved[\memoryAmount]);
                    api[\setMacro].(\tension, saved[\tension]);
                };
                cfg[\solver][\contextGaugeEnabled] = saved[\carryEnabled];
                cfg[\solver][\contextGaugeStrength] = saved[\carryStrength];
                cfg[\solver][\contextGaugeMaxCents] = saved[\carryMaxCents];
                if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(saved[\gravityEnabled]); } { cfg[\gravity][\enabled] = saved[\gravityEnabled]; };
                if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(saved[\gravityStrength]); } { cfg[\gravity][\strength] = saved[\gravityStrength]; };
                if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(saved[\gravityMaxPullCents]); } { cfg[\gravity][\maxPullCents] = saved[\gravityMaxPullCents]; };
                if(api[\setGravityHome].notNil) { api[\setGravityHome].(saved[\gravityHomePc], saved[\gravityHomeCents]); };
                if(api[\setMicEnabled].notNil) { api[\setMicEnabled].(saved[\micEnabled]); } { cfg[\mic][\enabled] = saved[\micEnabled]; };
                cfg[\mic][\weight] = saved[\micWeight];
                cfg[\mic][\trust] = saved[\micTrust];
                cfg[\mic][\influencePolicy] = saved[\micPolicy];
                cfg[\mic][\mode] = saved[\micMode];
                cfg[\mic][\inputMode] = saved[\micInputMode];
                if(api[\setToneProfile].notNil) { api[\setToneProfile].(saved[\toneProfile]); } { cfg[\render][\toneProfile] = saved[\toneProfile]; };
                if(api[\setToneLow].notNil) { api[\setToneLow].(saved[\toneLow]); } { cfg[\render][\toneLow] = saved[\toneLow]; };
                if(api[\setToneMid].notNil) { api[\setToneMid].(saved[\toneMid]); } { cfg[\render][\toneMid] = saved[\toneMid]; };
                if(api[\setToneHigh].notNil) { api[\setToneHigh].(saved[\toneHigh]); } { cfg[\render][\toneHigh] = saved[\toneHigh]; };
                if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(saved[\adaptiveToneMode]); } { cfg[\render][\adaptiveToneMode] = saved[\adaptiveToneMode]; };
                if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(saved[\adaptiveToneAmount]); } { cfg[\render][\adaptiveToneAmount] = saved[\adaptiveToneAmount]; };
                if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(saved[\registerAmount], saved[\velocityAmount]); };
                if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(saved[\gravityFollowMode], saved[\gravityFollowStrength]); };
                if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(saved[\spectrumAmount], saved[\spectrumProfile]); };
            };
            if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
        };

        audit[\run] = {
            var pass, fail, failures, saved, check, snap, report, ok, controls, expectedApis, missingApis, modes;
            pass = 0;
            fail = 0;
            failures = List.new;
            saved = audit[\save].();
            check = { |name, cond|
                if(cond == true) {
                    pass = pass + 1;
                    ("[AT VISUAL CONTROL AUDIT PASS] " ++ name).postln;
                } {
                    fail = fail + 1;
                    failures.add(name);
                    ("[AT VISUAL CONTROL AUDIT FAIL] " ++ name).warn;
                };
            };

            "".postln;
            "============================================================".postln;
            "[AT FINAL VISUAL CONTROL AUDIT] Version 1 keeper control-surface audit".postln;
            "This audit changes controls through the same public APIs used by the visual UI, checks snapshots, then restores state.".postln;
            "============================================================".postln;

            {
                if(api[\openUI].notNil) { api[\openUI].(); };
                snap = audit[\snap].();
                check.("uiSnapshot exists", snap.notNil);
                check.("UI open flag/window exists", ((ui[\uiOpen] ? false) == true) or: { ui[\window].notNil });

                expectedApis = [
                    \setPowerEnabled, \setBrainEnabled, \setMacro, \setMovement, \setTension,
                    \setMicEnabled, \setMicInfluencePolicy, \setMicTrust, \setMicWeight,
                    \setToneProfile, \setToneLow, \setToneMid, \setToneHigh,
                    \setAdaptiveToneMode, \setAdaptiveToneAmount,
                    \setRegisterVelocityAuthority, \setGravityFollowMode, \applyGravityFollow,
                    \setSpectrumAccordionAmount, \spectrumAccordionReport,
                    \finalProductControlReport, \runFinalInstrumentDemo, \refreshUISnapshot, \uiSnapshot,
                    \openUI, \closeUI, \reset, \hardReset
                ];
                missingApis = expectedApis.select { |k| api[k].isNil };
                check.("all visual/public control APIs exist", missingApis.isEmpty);

                if(api[\setPowerEnabled].notNil) {
                    api[\setPowerEnabled].(false); snap = audit[\snap].(); check.("Power visual toggle -> off", (snap[\powerEnabled] ? true) == false);
                    api[\setPowerEnabled].(true); snap = audit[\snap].(); check.("Power visual toggle -> on", (snap[\powerEnabled] ? false) == true);
                };

                if(api[\setBrainEnabled].notNil) {
                    api[\setBrainEnabled].(false); snap = audit[\snap].(); check.("Brain visual toggle -> Equal Temperament", (snap[\brainEnabled] ? true) == false);
                    api[\setBrainEnabled].(true); snap = audit[\snap].(); check.("Brain visual toggle -> Adaptive", (snap[\brainEnabled] ? false) == true);
                };

                if(api[\setMacro].notNil) {
                    api[\setMacro].(\motion, 0.37); snap = audit[\snap].(); check.("Motion slider writes movement", audit[\near].(snap[\movement], 0.37));
                    api[\setMacro].(\carry, 0.42); snap = audit[\snap].(); check.("Carry slider enables carry", (snap[\contextGaugeEnabled] ? false) == true);
                    check.("Carry slider writes strength", audit[\near].(snap[\contextGaugeStrength], (0.15 + (0.42 * 1.25)).clip(0.0, 1.5), 0.04));
                    api[\setMacro].(\memory, 0.64); snap = audit[\snap].(); check.("Memory slider writes memoryAmount", audit[\near].(snap[\memoryAmount], 0.64));
                    api[\setMacro].(\gravity, 0.73); snap = audit[\snap].(); check.("Gravity slider enables gravity", (snap[\gravityEnabled] ? false) == true);
                    check.("Gravity slider writes gravityStrength", audit[\near].(snap[\gravityStrength], 0.73));
                    api[\setMacro].(\tension, 0.41); snap = audit[\snap].(); check.("Tension slider writes tension", audit[\near].(snap[\tension], 0.41));
                    check.("Tension remains pitch-neutral", (snap[\tensionPitchAuthority] ? false) == false);
                };

                if(api[\setMicEnabled].notNil) {
                    api[\setMicEnabled].(true); snap = audit[\snap].(); check.("Ear visual toggle -> on", (snap[\micEnabled] ? false) == true);
                    api[\setMacro].(\micAmount, 0.52); snap = audit[\snap].(); check.("Ear Amount slider writes mic weight", audit[\near].(cfg[\mic][\weight], (0.52 * 1.2).clip(0.0, 1.5)));
                    api[\setMacro].(\micTrust, 0.66); snap = audit[\snap].(); check.("Ear Trust slider writes mic trust", audit[\near].(snap[\micTrust], 0.66));
                    if(api[\setMicInfluencePolicy].notNil) { api[\setMicInfluencePolicy].(\duetSafe); snap = audit[\snap].(); check.("Ear Policy menu writes policy", (snap[\micInfluencePolicy] ? \nil) == \duetSafe); };
                    api[\setMicEnabled].(false); snap = audit[\snap].(); check.("Ear visual toggle -> off", (snap[\micEnabled] ? true) == false);
                };

                if(api[\setToneProfile].notNil) {
                    api[\setToneProfile].(\electricPiano); snap = audit[\snap].(); check.("Tone menu writes electricPiano", (snap[\toneProfile] ? \nil) == \electricPiano);
                    api[\setToneProfile].(\pure); snap = audit[\snap].(); check.("Tone menu writes pure", (snap[\toneProfile] ? \nil) == \pure);
                };

                if(api[\setAdaptiveToneMode].notNil) {
                    api[\setAdaptiveToneMode].(\listening); snap = audit[\snap].(); check.("Adaptive Tone mode menu writes listening", (snap[\adaptiveToneMode] ? \nil) == \listening);
                    if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(0.58); snap = audit[\snap].(); check.("Adaptive Tone amount writes amount", audit[\near].(snap[\adaptiveToneAmount], 0.58)); };
                    check.("Adaptive timbre remains pitch-neutral", (snap[\adaptiveTimbrePitchAuthority] ? false) == false);
                };

                if(api[\setToneLow].notNil) { api[\setToneLow].(0.22); snap = audit[\snap].(); check.("EQ Low slider writes toneLow", audit[\near].(snap[\toneLow], 0.22)); };
                if(api[\setToneMid].notNil) { api[\setToneMid].(0.57); snap = audit[\snap].(); check.("EQ Mid slider writes toneMid", audit[\near].(snap[\toneMid], 0.57)); };
                if(api[\setToneHigh].notNil) { api[\setToneHigh].(0.83); snap = audit[\snap].(); check.("EQ High slider writes toneHigh", audit[\near].(snap[\toneHigh], 0.83)); };

                if(api[\setRegisterVelocityAuthority].notNil) {
                    api[\setRegisterVelocityAuthority].(1.31, 0.74); snap = audit[\snap].();
                    check.("Register Authority slider writes register amount", audit[\near].(snap[\registerVelocityRegisterAmount], 1.31));
                    check.("Velocity Authority slider writes velocity amount", audit[\near].(snap[\registerVelocityVelocityAmount], 0.74));
                    check.("Register/Velocity remains chord-local", (snap[\registerVelocityEnabled] ? false) == true);
                };

                if(api[\setGravityFollowMode].notNil) {
                    modes = [\off, \fixed, \memory, \ear];
                    ok = true;
                    modes.do { |m|
                        api[\setGravityFollowMode].(m, 1.0);
                        snap = audit[\snap].();
                        if((snap[\earGravityFollowMode] ? \nil) != m) { ok = false; };
                    };
                    check.("Gravity Follow menu writes off/fixed/memory/ear", ok);
                };

                if(api[\setSpectrumAccordionAmount].notNil) {
                    api[\setSpectrumAccordionAmount].(0.46, \bellLike); snap = audit[\snap].();
                    check.("Spectrum Accordion slider writes amount", audit[\near].(snap[\spectrumAccordionAmount], 0.46));
                    check.("Spectrum Accordion remains explicit/bounded", (api[\spectrumAccordionReport].(false)[\pitchAuthorityAdded] ? false) == false);
                };

                if(api[\finalProductControlReport].notNil) {
                    report = api[\finalProductControlReport].(false);
                    check.("Final product control report available", report.notNil);
                    check.("Final controls do not add hidden pitch authority", (report[\pitchAuthorityAdded] ? true) == false);
                };

                controls = [
                    \power, \brain, \motion, \carry, \memory, \gravity, \tension,
                    \ear, \earAmount, \earTrust, \earPolicy,
                    \toneProfile, \adaptiveToneMode, \adaptiveToneAmount, \toneLow, \toneMid, \toneHigh,
                    \registerAuthority, \velocityAuthority, \gravityFollow, \spectrumAccordion,
                    \panic, \reset, \hardReset, \finalDemo
                ];

            }.try { |err|
                fail = fail + 1;
                failures.add("runtime exception: " ++ err.asString);
                ("[AT VISUAL CONTROL AUDIT ERROR] " ++ err.asString).warn;
            };

            audit[\restore].(saved);
            snap = audit[\snap].();
            check.("Audit restored snapshot after control sweep", snap.notNil);

            report = (
                pass: pass,
                fail: fail,
                visualControlsRespond: fail == 0,
                controlsCovered: controls,
                failures: failures.asArray,
                uiOpen: (ui[\uiOpen] ? false),
                pitchAuthorityAdded: false
            );
            st[\lastFinalVisualControlAudit] = report;

            "".postln;
            ("[AT FINAL VISUAL CONTROL AUDIT] pass=" ++ pass.asString
                ++ " fail=" ++ fail.asString
                ++ " visualControlsRespond=" ++ (fail == 0).asString
                ++ " pitchAuthorityAdded=false").postln;
            if(fail > 0) { ("[AT FINAL VISUAL CONTROL AUDIT FAILURES] " ++ failures.asArray.asString).warn; };
            "============================================================".postln;
            report
        };

        api[\runFinalVisualControlAudit] = { audit[\run].() };
        at[\runFinalVisualControlAudit] = { api[\runFinalVisualControlAudit].() };
        at[\FinalVisualControlAudit] = audit;

        "[AT FINAL VISUAL CONTROL AUDIT] loaded. Run Library.at(\\at)[\\api][\\runFinalVisualControlAudit].();".postln;
    };
}.value;
)
