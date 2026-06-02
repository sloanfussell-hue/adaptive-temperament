(
// AT_external_stimulus_scenarios.scd
// Named real-audio scenes for the speaker→room→microphone path.
// These functions only create sound. They do not publish mic evidence.

var build, at, cfg, st, api, stim, scn;

build = ~atBuild;

if(build.isNil) {
    "[AT EXT STIM SCENARIOS] ~atBuild missing. Boot AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at]; cfg = build[\cfg]; st = build[\state]; api = build[\api];
    stim = at[\externalStimulus];

    if(stim.isNil) {
        "[AT EXT STIM SCENARIOS] externalStimulus missing. Load AT_external_stimulus.scd first.".warn;
    } {
        scn = IdentityDictionary.new;
        at[\externalStimulusScenarios] = scn;
        if(api.notNil) { api[\externalStimulusScenarios] = scn; };

        scn[\calibrationSilence] = { |dur=1.2|
            stim[\setExpected].("silence", \silence, Array.new, dur);
            stim[\clearExpectedLater].(dur);
            "[AT EXT SCENE] silence / room noise only".postln;
        };

        scn[\calibrationC4] = { |dur=1.8, amp=nil|
            stim[\playNote].(60, 0.0, dur, amp ? (cfg[\externalStimulus][\calibrationAmp] ? 0.12), 0, "calibration C4 0c", 0.0)
        };

        scn[\calibrationA4] = { |dur=1.8, amp=nil|
            stim[\playNote].(69, 0.0, dur, amp ? (cfg[\externalStimulus][\calibrationAmp] ? 0.12), 0, "calibration A4 0c", 0.0)
        };

        scn[\calibrationCSharp20] = { |dur=1.8, amp=nil|
            stim[\playNote].(60, 20.0, dur, amp ? (cfg[\externalStimulus][\calibrationAmp] ? 0.12), 0, "calibration C4 +20c", 0.0)
        };

        scn[\calibrationCFlat30] = { |dur=1.8, amp=nil|
            stim[\playNote].(60, -30.0, dur, amp ? (cfg[\externalStimulus][\calibrationAmp] ? 0.12), 0, "calibration C4 -30c", 0.0)
        };

        scn[\amplitudeRampC] = { |dur=2.5|
            var freq;
            freq = stim[\freqForMidi].(60, 0.0);
            stim[\playToneFreq].(freq, dur, 0.018, 0, "calibration C amplitude ramp", 0.0, 0, 0.0, freq, 0.0, 5.0, 0.0, cfg[\externalStimulus][\calibrationAmp] ? 0.12, 0.0, \amplitudeRamp)
        };

        scn[\monoDuetCSharp20] = { |dur=2.8|
            stim[\playNote].(60, 20.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "mono duet external C +20c", 0.0)
        };

        scn[\monoDuetCFlat35] = { |dur=2.8|
            stim[\playNote].(60, -35.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "mono duet external C -35c", 0.0)
        };

        scn[\monoDuetEFlat14] = { |dur=2.8|
            stim[\playNote].(64, -14.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "mono duet external E -14c", 0.0)
        };

        scn[\vibratoSingerC15] = { |dur=3.2|
            stim[\playVibratoNote].(60, 0.0, 15.0, 5.2, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "singer C ±15c vibrato")
        };

        scn[\vibratoSingerC35] = { |dur=3.2|
            stim[\playVibratoNote].(60, 0.0, 35.0, 5.1, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "singer C ±35c wide vibrato")
        };

        scn[\vibratoSingerCFlat20] = { |dur=3.2|
            stim[\playVibratoNote].(60, -20.0, 15.0, 5.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "singer C -20c center with vibrato")
        };

        scn[\glideBtoC] = { |dur=2.6|
            stim[\playGlide].(59, 0.0, 60, 0.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "glide B→C")
        };

        scn[\glideCtoCSharp] = { |dur=2.6|
            stim[\playGlide].(60, 0.0, 61, 0.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 1, "glide C→C#")
        };

        scn[\glideGtoC] = { |dur=2.8|
            stim[\playGlide].(67, 0.0, 72, 0.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.07, 1, "glide G→C")
        };

        scn[\guitarBendG50] = { |dur=2.4|
            stim[\playBend].(67, 50.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 2, "guitar bend G +50c return")
        };

        scn[\guitarBendE100] = { |dur=2.4|
            stim[\playBend].(64, 100.0, dur, cfg[\externalStimulus][\duetAmp] ? 0.105, 2, "guitar bend E +100c return")
        };

        scn[\etCMajor] = { |dur=3.0|
            stim[\playChord].([ (midi: 60, cents: 0.0), (midi: 64, cents: 0.0), (midi: 67, cents: 0.0) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 3, "ET piano C-E-G", 0.0)
        };

        scn[\etFMajor] = { |dur=3.0|
            stim[\playChord].([ (midi: 65, cents: 0.0), (midi: 69, cents: 0.0), (midi: 72, cents: 0.0) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 3, "ET piano F-A-C", 0.0)
        };

        scn[\etG7] = { |dur=3.0|
            stim[\playChord].([ (midi: 67, cents: 0.0), (midi: 71, cents: 0.0), (midi: 74, cents: 0.0), (midi: 77, cents: 0.0) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.058, 3, "ET-ish G7", 0.0)
        };

        scn[\etCDom7] = { |dur=3.0|
            stim[\playChord].([ (midi: 60, cents: 0.0), (midi: 64, cents: 0.0), (midi: 67, cents: 0.0), (midi: 70, cents: 0.0) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.058, 3, "ET C-E-G-Bb", 0.0)
        };

        scn[\jiCMajor] = { |dur=3.2|
            stim[\playChord].([ (midi: 60, cents: 0.0, timbre: 1), (midi: 64, cents: -13.69, timbre: 1), (midi: 67, cents: 1.96, timbre: 1) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 1, "JI strings C major", 0.0)
        };

        // A clearer physical poly probe: sine-like chord tones, slightly staggered.
        // This is still real speaker audio, not injected evidence. It gives the
        // laptop mic/filterbank a better chance to expose several pitch classes.
        scn[\jiCMajorProbe] = { |dur=3.4|
            stim[\playChord].([
                (midi: 60, cents: 0.0, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 1.15),
                (midi: 64, cents: -13.69, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 1.05),
                (midi: 67, cents: 1.96, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 1.0)
            ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 0, "JI sine-probe C major", 0.035)
        };


        // A second physical poly probe for laptop speakers/mics that under-report
        // the fifth of a triad. It is still real speaker audio, not injected evidence:
        // the G is emphasized and the tone starts are staggered further so the tracker
        // has a better chance to see C/E/G instead of substituting alien PCs.
        scn[\jiCMajorProbeGEmphasis] = { |dur=3.8|
            stim[\playChord].([
                (midi: 60, cents: 0.0, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 0.95),
                (midi: 64, cents: -13.69, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 0.98),
                (midi: 67, cents: 1.96, timbre: 0, amp: (cfg[\externalStimulus][\chordAmp] ? 0.065) * 1.45)
            ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 0, "JI sine-probe C major G-lift", 0.075)
        };

        scn[\jiFMajor] = { |dur=3.2|
            stim[\playChord].([ (midi: 65, cents: 0.0, timbre: 1), (midi: 69, cents: -13.69, timbre: 1), (midi: 72, cents: 1.96, timbre: 1) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 1, "JI strings F major", 0.0)
        };

        scn[\jiGDom] = { |dur=3.2|
            stim[\playChord].([ (midi: 67, cents: 0.0, timbre: 1), (midi: 71, cents: -13.69, timbre: 1), (midi: 74, cents: 1.96, timbre: 1), (midi: 77, cents: -31.17, timbre: 1) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.058, 1, "JI horn/string G dominant", 0.0)
        };

        scn[\jiCMinor] = { |dur=3.2|
            stim[\playChord].([ (midi: 60, cents: 0.0, timbre: 1), (midi: 63, cents: 15.64, timbre: 1), (midi: 67, cents: 1.96, timbre: 1) ], dur, cfg[\externalStimulus][\chordAmp] ? 0.065, 1, "JI-ish C minor", 0.0)
        };

        scn[\conflictingE] = { |dur=3.3|
            stim[\playChord].([ (midi: 64, cents: 0.0, timbre: 3, amp: 0.045), (midi: 64, cents: -13.69, timbre: 1, amp: 0.045), (midi: 64, cents: 20.0, timbre: 2, amp: 0.035) ], dur, nil, 1, "conflicting ensemble E: ET/JI/singer", 0.0)
        };

        scn[\miniBand_C_F_G_C] = { |tempo=1.0|
            var r, chordDur, gap, amp;
            stim[\stop].();
            chordDur = (2.4 / tempo).clip(1.2, 5.0);
            gap = (0.18 / tempo).clip(0.05, 0.5);
            amp = cfg[\externalStimulus][\songAmp] ? 0.055;
            r = Routine({
                "[AT EXT SCENE] procedural mini-band C → F → G7 → C".postln;
                stim[\playChord].([ (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.2), (midi: 60, cents: 0.0, timbre: 3, amp: amp), (midi: 64, cents: 0.0, timbre: 3, amp: amp), (midi: 67, cents: 0.0, timbre: 1, amp: amp) ], chordDur, amp, 3, "mini-band C", 0.015);
                (chordDur + gap).wait;
                stim[\playChord].([ (midi: 53, cents: 0.0, timbre: 2, amp: amp*1.2), (midi: 65, cents: 0.0, timbre: 3, amp: amp), (midi: 69, cents: 0.0, timbre: 3, amp: amp), (midi: 72, cents: 0.0, timbre: 1, amp: amp) ], chordDur, amp, 3, "mini-band F", 0.015);
                (chordDur + gap).wait;
                stim[\playChord].([ (midi: 55, cents: 0.0, timbre: 2, amp: amp*1.2), (midi: 67, cents: 0.0, timbre: 3, amp: amp), (midi: 71, cents: 0.0, timbre: 3, amp: amp), (midi: 74, cents: 0.0, timbre: 1, amp: amp), (midi: 77, cents: -31.17, timbre: 1, amp: amp*0.85) ], chordDur, amp, 3, "mini-band G7", 0.015);
                (chordDur + gap).wait;
                stim[\playChord].([ (midi: 48, cents: 0.0, timbre: 2, amp: amp*1.2), (midi: 60, cents: 0.0, timbre: 3, amp: amp), (midi: 64, cents: -13.69, timbre: 1, amp: amp), (midi: 67, cents: 1.96, timbre: 1, amp: amp) ], chordDur, amp, 3, "mini-band C resolve", 0.015);
            }).play(SystemClock);
            stim[\addRoutine].(r);
        };

        scn[\miniBand_jazzTurnaround] = { |tempo=1.0|
            var r, chordDur, gap, amp;
            stim[\stop].();
            chordDur = (2.0 / tempo).clip(1.0, 4.0);
            gap = (0.15 / tempo).clip(0.04, 0.4);
            amp = cfg[\externalStimulus][\songAmp] ? 0.055;
            r = Routine({
                "[AT EXT SCENE] procedural mini-band Dm7 → G7 → C".postln;
                stim[\playChord].([ (midi: 50, cents: 0.0), (midi: 62, cents: 0.0), (midi: 65, cents: 15.64), (midi: 69, cents: 1.96), (midi: 72, cents: -31.17) ], chordDur, amp, 1, "mini-band Dm7", 0.01);
                (chordDur + gap).wait;
                stim[\playChord].([ (midi: 55, cents: 0.0), (midi: 67, cents: 0.0), (midi: 71, cents: -13.69), (midi: 74, cents: 1.96), (midi: 77, cents: -31.17) ], chordDur, amp, 1, "mini-band G7", 0.01);
                (chordDur + gap).wait;
                stim[\playChord].([ (midi: 48, cents: 0.0), (midi: 60, cents: 0.0), (midi: 64, cents: -13.69), (midi: 67, cents: 1.96), (midi: 72, cents: 0.0) ], chordDur * 1.2, amp, 1, "mini-band C", 0.01);
            }).play(SystemClock);
            stim[\addRoutine].(r);
        };

        scn[\stressDense] = { |dur=4.0|
            var r, amp;
            stim[\stop].();
            amp = cfg[\externalStimulus][\stressAmp] ? 0.06;
            r = Routine({
                stim[\playChord].([ (midi: 48, cents: 0.0), (midi: 52, cents: 0.0), (midi: 55, cents: 0.0), (midi: 59, cents: 0.0), (midi: 62, cents: 0.0), (midi: 65, cents: 0.0), (midi: 69, cents: 0.0) ], dur, amp * 0.38, 3, "stress dense backing", 0.0);
                0.25.wait;
                stim[\playNoise].(dur * 0.75, amp * 0.35, 1, "stress broadband noise", 0.0);
            }).play(SystemClock);
            stim[\addRoutine].(r);
        };

        scn[\stressFastChanges] = { |tempo=1.0|
            var r, d, amp;
            stim[\stop].();
            d = (0.65 / tempo).clip(0.35, 1.2);
            amp = cfg[\externalStimulus][\stressAmp] ? 0.06;
            r = Routine({
                6.do { |i|
                    var root;
                    root = [60, 65, 67, 69, 62, 64].wrapAt(i);
                    stim[\playChord].([ (midi: root, cents: 0.0), (midi: root+4, cents: 0.0), (midi: root+7, cents: 0.0) ], d, amp * 0.45, 3, "stress fast chord " ++ i.asString, 0.0);
                    (d * 0.82).wait;
                };
            }).play(SystemClock);
            stim[\addRoutine].(r);
        };

        scn[\stressNoiseOnly] = { |dur=3.0|
            stim[\playNoise].(dur, cfg[\externalStimulus][\stressAmp] ? 0.06, 0, "stress noise/drums only", 0.0)
        };

        scn[\stop] = { stim[\stop].() };

        "[AT EXT STIM SCENARIOS] Loaded generated external speaker scenes.".postln;
    };
};
)
