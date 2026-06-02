(
// AT_external_stimulus.scd
// Speaker-output physical stimulus layer for the final instrument demo.
// This intentionally produces real audio through the output device. It does NOT
// inject mic candidates, externalSources, or scene objects into the field.

var build, at, cfg, st, api, stim, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[AT EXTERNAL STIMULUS] ~atBuild missing. Boot AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

    if(cfg[\externalStimulus].isNil) {
        cfg[\externalStimulus] = (
            out: cfg[\render][\out] ? 0,
            masterAmp: 1.0,
            defaultAmp: 0.105,
            calibrationAmp: 0.12,
            duetAmp: 0.105,
            chordAmp: 0.065,
            songAmp: 0.055,
            stressAmp: 0.07,
            expectedHoldSec: 2.0,
            protectLimiter: 0.92,
            postEvents: true
        );
    };

    stim = IdentityDictionary.new;
    at[\externalStimulus] = stim;
    if(api.notNil) { api[\externalStimulus] = stim; };

    stim[\activeSynths] = Array.new;
    stim[\routines] = Array.new;
    stim[\group] = nil;
    stim[\expectedId] = 0;

    SynthDef(\at_ext_stim_tone, {
        |out=0, freq=440, freq2=440, dur=1.0, amp=0.08, ampEnd=0.08, pan=0.0,
         timbre=0, vibCents=0.0, vibHz=5.0, bendCents=0.0, bendPeak=0.5,
         noiseMix=0.0, attack=0.02, release=0.08, masterAmp=1.0, limiter=0.92|
        var env, ampLine, baseFreq, vib, bend, f, sine, singer, reed, piano, sig, noise;

        env = EnvGen.kr(Env.linen(attack.max(0.001), dur.max(0.02), release.max(0.005), 1.0, -4), doneAction: 2);
        ampLine = Line.kr(amp.max(0.0), ampEnd.max(0.0), dur.max(0.02));
        baseFreq = XLine.kr(freq.max(20.0), freq2.max(20.0), dur.max(0.02));
        vib = SinOsc.kr(vibHz.max(0.01), 0, vibCents / 1200.0);
        bend = EnvGen.kr(Env([0.0, bendCents / 1200.0, 0.0], [(dur * bendPeak.clip(0.05, 0.95)).max(0.01), (dur * (1.0 - bendPeak.clip(0.05, 0.95))).max(0.01)], \sin));
        f = (baseFreq * (2 ** (vib + bend))).clip(20.0, 16000.0);

        sine = SinOsc.ar(f);
        singer = Mix.fill(5, { |i|
            var h;
            h = i + 1;
            SinOsc.ar(f * h, 0, 1.0 / (h * h.sqrt));
        }) / 1.9;
        reed = Mix.fill(7, { |i|
            var h;
            h = i + 1;
            SinOsc.ar(f * h, 0, if(h.odd) { 1.0 / h } { 0.28 / h });
        }) / 1.6;
        piano = Mix.fill(6, { |i|
            var h;
            h = i + 1;
            SinOsc.ar((f * h) * (1.0 + (h * 0.0009)), 0, 1.0 / (h * h));
        }) / 1.2;

        sig = Select.ar(timbre.clip(0, 3), [sine, singer, reed, piano]);
        noise = BPF.ar(PinkNoise.ar(noiseMix.clip(0.0, 1.0)), (f * 2.1).clip(120.0, 12000.0), 0.18) * 0.22;
        sig = LeakDC.ar(sig + noise);
        sig = Limiter.ar(sig * ampLine * masterAmp, limiter.clip(0.15, 0.99));
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1.0, 1.0)));
    }).add;

    SynthDef(\at_ext_stim_noise, {
        |out=0, dur=1.0, amp=0.06, pan=0.0, kind=0, attack=0.005, release=0.08, masterAmp=1.0, limiter=0.92|
        var env, white, pink, thump, sig;
        env = EnvGen.kr(Env.linen(attack.max(0.001), dur.max(0.02), release.max(0.005), 1.0, -4), doneAction: 2);
        white = HPF.ar(WhiteNoise.ar, 600.0);
        pink = BPF.ar(PinkNoise.ar, 1200.0, 0.5);
        thump = SinOsc.ar(55.0) * EnvGen.kr(Env.perc(0.002, 0.18, 1.0, -6));
        sig = Select.ar(kind.clip(0, 2), [white, pink, thump + (white * 0.15)]);
        sig = Limiter.ar(sig * amp.max(0.0) * masterAmp, limiter.clip(0.15, 0.99));
        Out.ar(out, Pan2.ar(sig * env, pan.clip(-1.0, 1.0)));
    }).add;

    stim[\ensureGroup] = {
        if(stim[\group].isNil) {
            stim[\group] = Group.head(s);
        };
        stim[\group]
    };

    stim[\addSynth] = { |synth|
        stim[\activeSynths] = (stim[\activeSynths] ? Array.new).add(synth);
        synth
    };

    stim[\addRoutine] = { |routine|
        stim[\routines] = (stim[\routines] ? Array.new).add(routine);
        routine
    };

    stim[\freqForMidi] = { |midi=60, cents=0.0|
        440.0 * (2 ** (((midi - 69).asFloat / 12.0) + (cents.asFloat / 1200.0)))
    };

    stim[\pcName] = { |pc| pitchClassNames[pc ? 0] ? (pc ? "?").asString };

    stim[\setMasterAmp] = { |amp=1.0|
        cfg[\externalStimulus][\masterAmp] = amp.asFloat.clip(0.05, 3.0);
        ("[AT EXT STIM] masterAmp=" ++ cfg[\externalStimulus][\masterAmp].round(0.01).asString).postln;
        cfg[\externalStimulus][\masterAmp]
    };

    stim[\setExpected] = { |label="stimulus", kind=\tone, tones=nil, dur=1.0|
        var ev, list, now;
        now = Main.elapsedTime;
        stim[\expectedId] = (stim[\expectedId] ? 0) + 1;
        ev = (
            id: stim[\expectedId],
            label: label,
            kind: kind,
            tones: (tones ? Array.new).copy,
            startTime: now,
            endTime: now + dur
        );
        st[\externalStimulusExpected] = ev;
        list = (st[\externalStimulusExpectedList] ? Array.new).reject { |e| (e[\endTime] ? 0.0) < (now - 0.15) };
        st[\externalStimulusExpectedList] = list.add(ev);
    };

    stim[\clearExpectedLater] = { |dur=1.0|
        var r, hold, id;
        hold = cfg[\externalStimulus][\expectedHoldSec] ? 2.0;
        id = stim[\expectedId] ? 0;
        r = Routine({
            (dur + hold).wait;
            if(st[\externalStimulusExpected].notNil) {
                if((st[\externalStimulusExpected][\id] ? -1) == id) {
                    if((st[\externalStimulusExpected][\endTime] ? 0.0) <= (Main.elapsedTime - 0.02)) {
                        st[\externalStimulusExpected] = nil;
                    };
                };
            };
            if(st[\externalStimulusExpectedList].notNil) {
                st[\externalStimulusExpectedList] = (st[\externalStimulusExpectedList] ? Array.new).reject { |e|
                    ((e[\id] ? -999) == id) or: { (e[\endTime] ? 0.0) <= (Main.elapsedTime - 0.02) }
                };
            };
        }).play(SystemClock);
        stim[\addRoutine].(r);
    };

    stim[\describeTone] = { |midi=nil, freq=440.0, cents=0.0, label="tone"|
        var pc;
        pc = if(midi.isNil) { nil } { midi % 12 };
        (
            label: label,
            midi: midi,
            pc: pc,
            pcName: if(pc.isNil) { nil } { stim[\pcName].(pc) },
            cents: cents,
            freq: freq
        )
    };

    stim[\playToneFreq] = { |freq=440.0, dur=1.0, amp=nil, timbre=0, label="tone", pan=0.0,
        pc=nil, cents=0.0, freq2=nil, vibCents=0.0, vibHz=5.0, bendCents=0.0,
        ampEnd=nil, noiseMix=0.0, kind=\tone, publishExpected=true|
        var group, synth, a, ae, f2, toneDesc;
        group = stim[\ensureGroup].();
        a = amp ? (cfg[\externalStimulus][\defaultAmp] ? 0.08);
        ae = ampEnd ? a;
        f2 = freq2 ? freq;
        toneDesc = (label: label, pc: pc, pcName: if(pc.isNil) { nil } { stim[\pcName].(pc) }, cents: cents, freq: freq, freq2: f2);
        if(publishExpected == true) {
            stim[\setExpected].(label, kind, [toneDesc], dur);
            stim[\clearExpectedLater].(dur);
        };
        if((cfg[\externalStimulus][\postEvents] ? true) == true) {
            ("[AT EXT STIM] " ++ label.asString ++ " freq=" ++ freq.round(0.01).asString ++ " -> " ++ f2.round(0.01).asString ++ " dur=" ++ dur.asString ++ " amp=" ++ a.asString).postln;
        };
        synth = Synth.head(group, \at_ext_stim_tone, [
            \out, cfg[\externalStimulus][\out] ? (cfg[\render][\out] ? 0),
            \freq, freq,
            \freq2, f2,
            \dur, dur,
            \amp, a,
            \ampEnd, ae,
            \pan, pan,
            \timbre, timbre.asInteger.clip(0, 3),
            \vibCents, vibCents,
            \vibHz, vibHz,
            \bendCents, bendCents,
            \noiseMix, noiseMix,
            \masterAmp, cfg[\externalStimulus][\masterAmp] ? 1.0,
            \limiter, cfg[\externalStimulus][\protectLimiter] ? 0.92
        ]);
        stim[\addSynth].(synth)
    };

    stim[\playNote] = { |midi=60, cents=0.0, dur=1.0, amp=nil, timbre=0, label=nil, pan=0.0|
        var freq, pc, lab;
        pc = midi % 12;
        freq = stim[\freqForMidi].(midi, cents);
        lab = label ? ("note " ++ stim[\pcName].(pc) ++ " " ++ cents.round(0.01).asString ++ "c");
        stim[\playToneFreq].(freq, dur, amp, timbre, lab, pan, pc, cents, freq, 0.0, 5.0, 0.0, nil, 0.0, \note)
    };

    stim[\playVibratoNote] = { |midi=60, centerCents=0.0, vibCents=15.0, vibHz=5.0, dur=2.0, amp=nil, timbre=1, label=nil|
        var freq, pc, lab;
        pc = midi % 12;
        freq = stim[\freqForMidi].(midi, centerCents);
        lab = label ? ("vibrato " ++ stim[\pcName].(pc) ++ " center=" ++ centerCents.round(0.01).asString ++ "c vib=" ++ vibCents.round(0.01).asString ++ "c");
        stim[\playToneFreq].(freq, dur, amp, timbre, lab, 0.0, pc, centerCents, freq, vibCents, vibHz, 0.0, nil, 0.03, \vibratoTone)
    };

    stim[\playGlide] = { |startMidi=59, startCents=0.0, endMidi=60, endCents=0.0, dur=2.0, amp=nil, timbre=1, label=nil|
        var f1, f2, pc, lab;
        f1 = stim[\freqForMidi].(startMidi, startCents);
        f2 = stim[\freqForMidi].(endMidi, endCents);
        pc = endMidi % 12;
        lab = label ? ("glide " ++ stim[\pcName].(startMidi % 12) ++ "→" ++ stim[\pcName].(pc));
        stim[\playToneFreq].(f1, dur, amp, timbre, lab, 0.0, pc, endCents, f2, 0.0, 5.0, 0.0, nil, 0.04, \movingTone)
    };

    stim[\playBend] = { |midi=67, bendCents=50.0, dur=2.0, amp=nil, timbre=2, label=nil|
        var freq, pc, lab;
        pc = midi % 12;
        freq = stim[\freqForMidi].(midi, 0.0);
        lab = label ? ("bend " ++ stim[\pcName].(pc) ++ " +" ++ bendCents.round(0.01).asString ++ "c");
        stim[\playToneFreq].(freq, dur, amp, timbre, lab, 0.0, pc, 0.0, freq, 0.0, 5.0, bendCents, nil, 0.02, \guitarBend)
    };

    stim[\playChord] = { |specs, dur=2.0, amp=nil, timbre=3, label="chord", stagger=0.0|
        var group, tones, a, r;
        group = stim[\ensureGroup].();
        a = amp ? (cfg[\externalStimulus][\chordAmp] ? 0.045);
        tones = specs.collect { |sp|
            var midi, cents, freq, pc;
            midi = sp[\midi] ? 60;
            cents = sp[\cents] ? 0.0;
            pc = midi % 12;
            freq = stim[\freqForMidi].(midi, cents);
            (label: stim[\pcName].(pc), midi: midi, pc: pc, pcName: stim[\pcName].(pc), cents: cents, freq: freq)
        };
        stim[\setExpected].(label, \chord, tones, dur + ((specs.size - 1).max(0) * stagger));
        stim[\clearExpectedLater].(dur + ((specs.size - 1).max(0) * stagger));
        if((cfg[\externalStimulus][\postEvents] ? true) == true) {
            ("[AT EXT STIM] chord " ++ label.asString ++ " tones=" ++ tones.collect { |t| t[\pcName].asString ++ " " ++ t[\cents].round(0.01).asString ++ "c" }.asString).postln;
        };
        if(stagger <= 0.0) {
            specs.do { |sp, i|
                stim[\playToneFreq].(tones[i][\freq], dur, sp[\amp] ? a, sp[\timbre] ? timbre, label.asString ++ " " ++ tones[i][\pcName].asString, ((i / specs.size.max(1)) * 1.2 - 0.6).clip(-0.7, 0.7), tones[i][\pc], tones[i][\cents], tones[i][\freq], sp[\vibCents] ? 0.0, sp[\vibHz] ? 5.0, 0.0, nil, sp[\noiseMix] ? 0.0, \chordTone, false);
            };
        } {
            r = Routine({
                specs.do { |sp, i|
                    stim[\playToneFreq].(tones[i][\freq], dur, sp[\amp] ? a, sp[\timbre] ? timbre, label.asString ++ " " ++ tones[i][\pcName].asString, ((i / specs.size.max(1)) * 1.2 - 0.6).clip(-0.7, 0.7), tones[i][\pc], tones[i][\cents], tones[i][\freq], sp[\vibCents] ? 0.0, sp[\vibHz] ? 5.0, 0.0, nil, sp[\noiseMix] ? 0.0, \chordTone, false);
                    stagger.wait;
                };
            }).play(SystemClock);
            stim[\addRoutine].(r);
        };
        tones
    };

    stim[\playNoise] = { |dur=1.0, amp=nil, kind=0, label="noise/drums", pan=0.0|
        var group, synth, a;
        group = stim[\ensureGroup].();
        a = amp ? (cfg[\externalStimulus][\stressAmp] ? 0.07);
        stim[\setExpected].(label, \noise, [ (label: label, kind: kind) ], dur);
        stim[\clearExpectedLater].(dur);
        if((cfg[\externalStimulus][\postEvents] ? true) == true) { ("[AT EXT STIM] " ++ label ++ " dur=" ++ dur.asString ++ " amp=" ++ a.asString).postln; };
        synth = Synth.head(group, \at_ext_stim_noise, [
            \out, cfg[\externalStimulus][\out] ? (cfg[\render][\out] ? 0),
            \dur, dur,
            \amp, a,
            \kind, kind.asInteger.clip(0, 2),
            \pan, pan,
            \masterAmp, cfg[\externalStimulus][\masterAmp] ? 1.0,
            \limiter, cfg[\externalStimulus][\protectLimiter] ? 0.92
        ]);
        stim[\addSynth].(synth)
    };

    stim[\stop] = {
        (stim[\routines] ? Array.new).do { |r| if(r.notNil) { r.stop } };
        stim[\routines] = Array.new;
        // Do not individually free remembered Synth handles here. Many stimulus
        // synths auto-free through doneAction:2, and re-freeing stale Node IDs
        // spams "Node not found" in the post window. The group cleanup below is
        // enough for live synths that still exist.
        stim[\activeSynths] = Array.new;
        if(stim[\group].notNil) {
            stim[\group].freeAll;
            stim[\group].free;
            stim[\group] = nil;
        };
        st[\externalStimulusExpected] = nil;
        st[\externalStimulusExpectedList] = Array.new;
        "[AT EXT STIM] stopped / cleaned.".postln;
    };

    stim[\panic] = { stim[\stop].() };

    "[AT EXTERNAL STIMULUS] Loaded real speaker stimulus layer. Stop: Library.at(\\at)[\\externalStimulus][\\stop].();".postln;
};
)
