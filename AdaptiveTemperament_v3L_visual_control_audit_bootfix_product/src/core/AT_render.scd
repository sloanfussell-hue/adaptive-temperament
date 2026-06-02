(
// AT_render.scd
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
	"[at] ~atBuild missing. Load AdaptiveTemperament_run_core.scd or AdaptiveTemperament_run_with_ui.scd.".warn;
} {
	at = build[\at];
	cfg = build[\cfg];
	st = build[\state];
	api = build[\api];
	diag = build[\diag];
	ui = build[\ui];
	pitchClassNames = at[\pitchClassNames];

	// ------------------------------------------------------------
	// audio layer
	// ------------------------------------------------------------

// ------------------------------------------------------------
	// audio layer
	// ------------------------------------------------------------

	SynthDef(\atbeep, {
		|out=0, freq=440, amp=0.12, dur=0.35, masterAmp=1.0|
		var env, sig;
		env = EnvGen.kr(Env.perc(0.005, dur.max(0.03), 1.0, -4), doneAction: 2);
		sig = SinOsc.ar(freq.max(20.0), 0, amp * masterAmp) * env;
		Out.ar(out, Pan2.ar(sig, 0.0));
	}).add;

	SynthDef(\atvoice_ref, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.03, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.12|
		var dev, freq, sig, env;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		freq = (baseFreq * (2 ** dev)).max(20.0);
		sig = SinOsc.ar(freq, 0.0, amp * masterAmp);
		env = EnvGen.kr(Env.asr(0.005, 1.0, releaseTime), gate, doneAction: 2);
		Out.ar(out, Pan2.ar(sig * env, 0.0));
	}).add;

	SynthDef(\atvoice_prod, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.03, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.12|
		var dev, align, motion, stab, tension, freq, rough, sig, env, pan, cutoff, brightCore, tine;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0.0, 1.0);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0.0, 1.0);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0.0, 1.0);
		tension = In.kr(tensionBus).clip(0.0, 1.0);

		freq = (baseFreq * (2 ** dev)).max(20.0);
		// v3F: final product tone is intentionally conservative and pitch-legible.
		// Adaptive timbre changes brightness/body only; no random panning or noisy roughness is allowed
		// to masquerade as harmony during the product demo.
		rough = ((((1.0 - stab) * 0.055) + (motion * 0.025)) * roughnessAmount).clip(0.0, 0.10);
		brightCore = ((align * 1200.0) + (tension * 950.0) + (brightnessAmount.clip(0.2, 2.0) * 950.0));
		cutoff = (950.0 + brightCore).clip(450.0, 7800.0);

		// Clean electric-piano/organ-like harmonic tone. The deliberately low partial weights
		// make interval errors audible as harmony instead of as noisy/random texture.
		tine = SinOsc.ar(freq * 2.01, 0.0, 0.105 * brightnessAmount.clip(0.35, 1.8));
		sig = SinOsc.ar(freq, 0.0, 1.0)
			+ SinOsc.ar(freq * 2.0, 0.0, 0.22)
			+ SinOsc.ar(freq * 3.0, 0.0, 0.105)
			+ SinOsc.ar(freq * 4.0, 0.0, 0.045)
			+ tine;
		sig = LPF.ar(sig / 1.48, cutoff);
		// Noise is essentially off; this tiny filtered component only gives attack/body when tension is high.
		sig = sig + (BPF.ar(PinkNoise.ar(rough * 0.18), (freq * 2.2).clip(120.0, 9000.0), 0.28) * rough * 0.006);

		env = EnvGen.kr(Env.asr(0.006, 1.0, releaseTime.max(0.18)), gate, doneAction: 2);
		pan = 0.0; // no random stereo motion in the final product demo
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env, pan));
	}).add;

	SynthDef(\atmictracker, {
		|freqBus=0, ampBus=0, meterBus=0, micGain=1.0, inputMode=2,
		 pitchAmpThreshold=0.00025, pitchDetectGain=10.0, zeroCrossFallback=1, zeroCrossAmpThreshold=0.00018,
		 pitchMedian=3, pitchMinFreq=35.0, pitchMaxFreq=2200.0, pitchExecFreq=50.0|
		var ch0, ch1, rawSig, detectSig, rawAmp, detectAmp, amp0, amp1;
		var pitch, hasPitch, pitchFreq, zcFreq, zcOk, useZc, freq;
		ch0 = SoundIn.ar(0) * micGain;
		ch1 = SoundIn.ar(1) * micGain;
		rawSig = Select.ar(inputMode.clip(0, 2), [ch0, ch1, (ch0 + ch1) * 0.5]);
		rawSig = LeakDC.ar(rawSig);
		rawSig = HPF.ar(rawSig, 35);

		// Separate musical input gain from detection gain. A quiet phone tone can be
		// visible on the meter but too small for Pitch.kr. This preamps only the
		// detector path, then limits it so bad mic settings do not explode.
		detectSig = Limiter.ar(rawSig * pitchDetectGain.clip(1.0, 64.0), 0.95);
		detectSig = LPF.ar(detectSig, pitchMaxFreq.clip(100, 8000) * 1.5);

		rawAmp = Amplitude.kr(rawSig, 0.01, 0.16);
		detectAmp = Amplitude.kr(detectSig, 0.01, 0.16);
		amp0 = Amplitude.kr(ch0, 0.01, 0.16);
		amp1 = Amplitude.kr(ch1, 0.01, 0.16);

		pitch = Pitch.kr(
			detectSig,
			ampThreshold: pitchAmpThreshold.clip(0.00001, 0.1),
			median: pitchMedian.clip(1, 15),
			minFreq: pitchMinFreq.clip(20, 800),
			maxFreq: pitchMaxFreq.clip(100, 8000),
			execFreq: pitchExecFreq.clip(5, 120)
		);
		hasPitch = pitch[1].clip(0, 1);
		pitchFreq = pitch[0].clip(0, 10000);

		// Fallback for pure phone/sine tones. ZeroCrossing is not ideal for complex
		// voice, but it is reliable for the calibration tone that failed Pitch.kr.
		zcFreq = Lag.kr(A2K.kr(ZeroCrossing.ar(detectSig)), 0.08).clip(0, 10000);
		zcOk = (zeroCrossFallback > 0.5) * (detectAmp >= zeroCrossAmpThreshold.clip(0.00001, 0.1)) *
			(zcFreq >= pitchMinFreq.clip(20, 800)) * (zcFreq <= pitchMaxFreq.clip(100, 8000));
		useZc = (1 - hasPitch) * zcOk;
		freq = (pitchFreq * hasPitch) + (zcFreq * useZc);

		Out.kr(freqBus, freq);
		// Publish detector amplitude so language-side voiced gate matches detector.
		// Raw input amplitude remains available in meterBus[0].
		Out.kr(ampBus, detectAmp);
		Out.kr(meterBus, [rawAmp, amp0, amp1, inputMode.clip(0, 2)]);
	}).add;
	SynthDef(\atmicpolytracker, {
		|binBus=0, ampBus=0, meterBus=0, micGain=1.0, inputMode=2|
		var ch0, ch1, sig, amp, amp0, amp1, filtered, envs;
		var freqs = st[\polyBinFreqs];
		var bias = st[\polyBinBiases];
		ch0 = SoundIn.ar(0) * micGain;
		ch1 = SoundIn.ar(1) * micGain;
		sig = Select.ar(inputMode.clip(0, 2), [ch0, ch1, (ch0 + ch1) * 0.5]);
		sig = LeakDC.ar(sig);
		sig = HPF.ar(sig, 35);
		sig = LPF.ar(sig, (st[\polyBinFreqs].last * 1.35).clip(800.0, 8000.0));
		amp = Amplitude.kr(sig, 0.02, 0.1);
		amp0 = Amplitude.kr(ch0, 0.02, 0.1);
		amp1 = Amplitude.kr(ch1, 0.02, 0.1);
		filtered = BPF.ar(sig, freqs, cfg[\mic][\polyRq]);
		envs = Amplitude.kr(filtered, cfg[\mic][\polyAttack], cfg[\mic][\polyRelease]) * bias;
		Out.kr(binBus, envs);
		Out.kr(ampBus, amp);
		Out.kr(meterBus, [amp, amp0, amp1, inputMode.clip(0, 2)]);
	}).add;

	// s.sync intentionally skipped during boot; SynthDefs are sent asynchronously.

	// ------------------------------------------------------------
	// voice management
	// ------------------------------------------------------------

	at[\setActiveVoiceParam] = { |key, value|
		st[\voices].keysValuesDo { |midi, synth|
			synth.set(key, value);
		};
	};

	at[\spawnVoice] = { |midi, velocity|
		var pc, baseFreq, synth, defName, voiceAmp;
		pc = midi % 12;
		baseFreq = at[\midiToFreq].(midi);
		voiceAmp = ((velocity * 0.135) + 0.025).clip(0.025, 0.18);
		defName = if(st[\renderMode] == \reference) { \atvoice_ref } { \atvoice_prod };

		st[\lastVoiceSpawn] = (
			midi: midi,
			pc: pc,
			baseFreq: baseFreq,
			defName: defName,
			velocity: velocity,
			amp: voiceAmp,
			timestamp: Main.elapsedTime
		);
		if((cfg[\input][\postMidiEvents] ? true) == true) {
			("[at-audio] spawnVoice midi=" ++ midi.asString ++ " pc=" ++ pc.asString ++ " def=" ++ defName.asString ++ " freq=" ++ baseFreq.round(0.01).asString).postln;
		};

		synth = Synth(defName, [
			\out, cfg[\render][\out] ? 0,
			\baseFreq, baseFreq,
			\pc, pc,
			\devBus, st[\devBus].index,
			\alignBus, st[\alignBus].index,
			\motionBus, st[\motionBus].index,
			\stabBus, st[\stabBus].index,
			\tensionBus, st[\tensionBus].index,
			\amp, voiceAmp,
			\pitchLag, cfg[\render][\pitchLag],
			\alignLag, cfg[\render][\alignLag],
			\motionLag, cfg[\render][\motionLag],
			\stabLag, cfg[\render][\stabilityLag],
			\brightnessAmount, cfg[\render][\brightnessAmount],
			\roughnessAmount, cfg[\render][\roughnessAmount],
			\panMotionAmount, cfg[\render][\panMotionAmount],
			\masterAmp, if(st[\powerEnabled] == false) { 0.0 } { cfg[\render][\masterAmp] },
			\releaseTime, cfg[\render][\releaseTime]
		]);

		st[\voices][midi] = synth;
		synth;
	};

	at[\releaseVoice] = { |midi|
		var synth;
		synth = st[\voices][midi];
		if(synth.notNil) {
			synth.set(\gate, 0);
			st[\voices].removeAt(midi);
		};
	};

	at[\allVoicesOff] = {
		st[\voices].keysValuesDo { |midi, synth|
			synth.set(\gate, 0);
		};
		st[\voices].clear;
	};

};
)
