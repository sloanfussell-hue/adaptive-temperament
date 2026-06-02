(
// AT_render_profiles.scd
// Usable tone-profile SynthDefs for Adaptive Temperament.
// These voices all obey the same pitch spine: baseFreq * 2 ** adaptiveDeviation.
// The current probe/test sound is preserved as \atvoice_probe; the other profiles
// are musical bodies that can later receive shared adaptive-tone controls.

var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
	"[at-render-profiles] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
	at = build[\at];
	cfg = build[\cfg];
	st = build[\state];
	api = build[\api];
	diag = build[\diag];
	ui = build[\ui];

	if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
	cfg[\render][\toneProfiles] = [\probe, \pure, \piano, \electricPiano, \organ, \pad, \synth];
	if(cfg[\render][\toneProfile].isNil) { cfg[\render][\toneProfile] = \organ; };
	if(cfg[\render][\toneBody].isNil) { cfg[\render][\toneBody] = 0.62; };
	if(cfg[\render][\toneBrightness].isNil) { cfg[\render][\toneBrightness] = 0.50; };
	if(cfg[\render][\toneAir].isNil) { cfg[\render][\toneAir] = 0.18; };
	if(cfg[\render][\toneEdge].isNil) { cfg[\render][\toneEdge] = 0.12; };
	if(cfg[\render][\toneWidth].isNil) { cfg[\render][\toneWidth] = 0.20; };
	if(cfg[\render][\toneLow].isNil) { cfg[\render][\toneLow] = 0.50; };
	if(cfg[\render][\toneMid].isNil) { cfg[\render][\toneMid] = 0.50; };
	if(cfg[\render][\toneHigh].isNil) { cfg[\render][\toneHigh] = 0.50; };

	at[\toneProfileDefName] = { |profile|
		var p;
		p = (profile ? \organ).asSymbol;
		switch(p,
			\probe, { \atvoice_probe },
			\pure, { \atvoice_pure },
			\piano, { \atvoice_piano_sample },
			\electricPiano, { \atvoice_electric_piano_sample },
			\epiano, { \atvoice_electric_piano_sample },
			\organ, { \atvoice_organ },
			\strings, { \atvoice_pure },
			\pad, { \atvoice_pad },
			\synth, { \atvoice_synth },
			{ \atvoice_organ }
		)
	};

	at[\validToneProfile] = { |profile|
		var p;
		p = (profile ? \organ).asSymbol;
		if(cfg[\render][\toneProfiles].includes(p)) { p } {
			if(p == \epiano) { \electricPiano } { \organ }
		}
	};

	// ------------------------------------------------------------
	// Probe / diagnostic profile. Kept intentionally plain.
	// ------------------------------------------------------------
	SynthDef(\atvoice_probe, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.03, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.12,
		adaptiveMode=0, adaptiveAmount=0, body=0.5, brightness=0.5, air=0, edge=0, width=0, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, freq, sig, env, eqLowDb, eqMidDb, eqHighDb;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		freq = (baseFreq * (2 ** dev)).max(20.0);
		sig = SinOsc.ar(freq, 0.0, 1.0);
		env = EnvGen.kr(Env.asr(0.004, 1.0, releaseTime.clip(0.02, 2.0)), gate, doneAction: 2);

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env, 0.0));
	}).add;

	// ------------------------------------------------------------
	// Pure: clear musical reference tone with very light harmonic body.
	// ------------------------------------------------------------
	SynthDef(\atvoice_pure, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.03, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.18,
		adaptiveMode=0, adaptiveAmount=0, body=0.5, brightness=0.5, air=0.0, edge=0.0, width=0.0, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, coh, conflict, mode, amt, bloom, breath, ed, br, sig, env, cutoff, pan, eqLowDb, eqMidDb, eqHighDb;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(20.0);
		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.25]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.35]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.25)).clip(0, 1), conflict * 0.25]) * amt;
		br = (brightness + (bloom * 0.18) + (breath * 0.12) + (ed * 0.20)).clip(0, 1.5);
		sig = SinOsc.ar(freq, 0, 1.0)
			+ (SinOsc.ar(freq * 2.0, 0, 0.20 + (body.clip(0, 1) * 0.10)))
			+ (SinOsc.ar(freq * 3.0, 0, 0.06 + (br * 0.08)));
		sig = sig / 1.35;
		sig = sig + (BPF.ar(WhiteNoise.ar(1.0), (freq * 2.0).clip(120, 9000), 0.12) * (air + breath) * 0.025);
		cutoff = (1200 + (br * 5200) + (coh * 1400)).clip(250, 14000);
		sig = LPF.ar(sig, cutoff);
		env = EnvGen.kr(Env.asr(0.012, 1.0, releaseTime.clip(0.03, 2.0)), gate, doneAction: 2);
		pan = LFNoise1.kr(0.25).range(-0.12, 0.12) * width.clip(0, 1) * panMotionAmount;

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env, pan));
	}).add;

	// ------------------------------------------------------------
	// Piano: real-sample host for Slender Salamander / Yamaha C5 source.
	//
	// v4 correction: use the real Slender Salamander source as the truth.
	// No Iowa default, no fake piano oscillator, no synthetic body goo.
	// This voice only handles Adaptive Temperament pitch playback, conservative
	// voicing, and final simple L/M/H EQ.
	// ------------------------------------------------------------
	SynthDef(\atvoice_piano_sample, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.004, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.22,
		adaptiveMode=0, adaptiveAmount=0, body=0.58, brightness=0.45, air=0.08, edge=0.04, width=0.18,
		lowEQ=0.5, midEQ=0.5, highEQ=0.5,
		softBuf=0, medBuf=0, hardBuf=0, rootFreq=440, strikeVel=0.5, startFrame=0|
		var dev, align, motion, stab, tension, freq, rate, vel, layerIndex, keyPos, lowKey;
		var coh, conflict, mode, amt, bloom, breath, ed, bodyCtl, brCtl, airCtl, widthCtl;
		var soft, med, hard, left, right, sig, env, releaseTrig, releaseNoise;
		var eqLowDb, eqMidDb, eqHighDb, mid, side, safeStart;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);

		freq = (baseFreq * (2 ** dev)).max(20.0);
		rate = (freq / rootFreq.max(20.0)).clip(0.45, 2.2);
		vel = strikeVel.clip(0.02, 1.0);
		keyPos = ((freq.cpsmidi - 21) / 87).clip(0.0, 1.0);
		lowKey = 1.0 - keyPos;

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.08]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.10]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.08)).clip(0, 1), conflict * 0.05]) * amt;

		bodyCtl = body.clip(0.0, 1.0);
		brCtl = ((brightness.clip(0.0, 1.0) * brightnessAmount.clip(0.0, 2.0)) + (bloom * 0.04) + (breath * 0.03)).clip(0.0, 1.10);
		airCtl = (air.clip(0.0, 1.0) + (breath * 0.035)).clip(0.0, 0.45);
		widthCtl = (width.clip(0.0, 1.0) + (breath * 0.02)).clip(0.0, 0.70);

		// Real p/m/f source selection from the phase-aligned Slender Salamander set.
		// Keep layers discrete to avoid phase-smear and artificial combing.
		layerIndex = ((vel > 0.44) + (vel > 0.82)).clip(0, 2);
		safeStart = startFrame.clip(0, 2500);
		soft = PlayBuf.ar(2, softBuf, rate * BufRateScale.kr(softBuf), trigger: 1, startPos: safeStart, loop: 0);
		med = PlayBuf.ar(2, medBuf, rate * BufRateScale.kr(medBuf), trigger: 1, startPos: safeStart, loop: 0);
		hard = PlayBuf.ar(2, hardBuf, rate * BufRateScale.kr(hardBuf), trigger: 1, startPos: safeStart, loop: 0);
		left = Select.ar(layerIndex, [soft[0], med[0], hard[0]]);
		right = Select.ar(layerIndex, [soft[1], med[1], hard[1]]);
		sig = [left, right];

		// Minimal studio-grand cleanup. Do not impose a synthetic piano body over the
		// real Slender sample; only remove rumble/mud and tame excessive edge.
		sig = HPF.ar(sig, 28);
		sig = BLowShelf.ar(sig, 100, 0.85, (-0.7 + (bodyCtl * 0.90) + (lowKey * 0.30)).clip(-2.0, 1.6));
		sig = BPeakEQ.ar(sig, 300, 0.80, (-1.15 + (bodyCtl * 0.15)).clip(-2.8, -0.2));
		sig = BPeakEQ.ar(sig, 900, 0.90, -0.55);
		sig = BPeakEQ.ar(sig, 2600 + (keyPos * 500), 0.85, (-0.55 + (brCtl * 0.38) + (ed * 0.08)).clip(-1.8, 0.55));
		sig = BHiShelf.ar(sig, 6800, 0.75, (-1.35 + (airCtl * 0.85) + (brCtl * 0.16)).clip(-3.5, 0.25));
		sig = LPF.ar(sig, (10800 + (brCtl * 1500) + (keyPos * 600)).clip(7600, 14500));
		sig = LeakDC.ar(sig);

		// Very low key-off noise only; the real sample tail/release is preferred.
		releaseTrig = Trig1.kr(1 - gate, 0.025);
		releaseNoise = HPF.ar(PinkNoise.ar(1.0!2), 1200 + (keyPos * 1800))
			* Decay2.kr(releaseTrig, 0.001, 0.025 + (lowKey * 0.020))
			* (0.00025 + (vel * 0.0008));
		sig = sig + releaseNoise;

		// Preserve the stereo image. This is not chorus/pan; it is mild M/S trim.
		mid = (sig[0] + sig[1]) * 0.5;
		side = (sig[0] - sig[1]) * (0.78 + (widthCtl * 0.35));
		sig = [mid + side, mid - side];

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);

		env = EnvGen.kr(Env.asr(0.0002, 1.0, releaseTime.clip(0.04, 1.6), curve: -4), gate, doneAction: 2);
		Out.ar(out, sig * amp * masterAmp * env * 1.00);
	}).add;

	// ------------------------------------------------------------
	// Piano: synthesized hammer + resonant string body. Not a sample model.
	// ------------------------------------------------------------
	SynthDef(\atvoice_piano, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.025, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.32,
		adaptiveMode=0, adaptiveAmount=0, body=0.55, brightness=0.55, air=0.08, edge=0.10, width=0.10, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, coh, conflict, mode, amt, bloom, ed, br, hammer, env, bodyEnv, sig, cutoff, pan, eqLowDb, eqMidDb, eqHighDb;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(20.0);
		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.15]) * amt;
		ed = Select.kr(mode, [0, 0, 0, conflict + (tension * 0.15), conflict * 0.15]).clip(0, 1) * amt;
		br = (brightness + (bloom * 0.10) + (ed * 0.35)).clip(0, 1.5);
		env = EnvGen.kr(Env.adsr(0.002, 0.45, 0.08, releaseTime.clip(0.04, 2.0), curve: -4), gate, doneAction: 2);
		bodyEnv = EnvGen.kr(Env.perc(0.003, (1.2 + (body.clip(0, 1) * 2.6)).clip(0.5, 4.5), curve: -5));
		hammer = EnvGen.kr(Env.perc(0.001, 0.035), 1);
		sig = Mix.ar([
			SinOsc.ar(freq, 0, 1.0),
			SinOsc.ar(freq * 2.01, 0, 0.32),
			SinOsc.ar(freq * 3.02, 0, 0.12),
			SinOsc.ar(freq * 4.01, 0, 0.045 + (br * 0.04))
		]);
		sig = (sig * bodyEnv) + (BPF.ar(WhiteNoise.ar(1), (freq * (8 + (br * 12))).clip(900, 12000), 0.4) * hammer * (0.12 + (br * 0.25)));
		cutoff = (900 + (br * 7600)).clip(400, 14000);
		sig = LPF.ar(sig, cutoff);
		pan = LFNoise1.kr(0.2).range(-0.08, 0.08) * width.clip(0, 1) * panMotionAmount;

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env * 1.2, pan));
	}).add;

	// ------------------------------------------------------------
	// Electric piano: real sample/keygroup host.
	// This profile intentionally no longer fabricates Rhodes-like source waves.
	// Professional Rhodes instruments are built from captured electromechanical
	// source behavior or calibrated physical models. This SynthDef renders legal
	// keygroup/velocity samples loaded by AT_epiano_sample_host.scd, then applies
	// Adaptive Temperament pitch, pickup/preamp shaping, subtle suitcase motion,
	// and final simple L/M/H EQ.
	// ------------------------------------------------------------
	SynthDef(\atvoice_electric_piano_sample, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.025, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.28,
		adaptiveMode=0, adaptiveAmount=0, body=0.62, brightness=0.50, air=0.12, edge=0.14, width=0.20,
		lowEQ=0.5, midEQ=0.5, highEQ=0.5,
		softBuf=0, medBuf=0, hardBuf=0, rootFreq=440, strikeVel=0.5|
		var dev, align, motion, stab, tension, freq, rate, vel, layerX, keyPos, lowKey;
		var coh, conflict, mode, amt, bloom, breath, ed, bodyCtl, brCtl, edgeCtl, airCtl, widthCtl;
		var soft, med, hard, sig, env, releaseTrig, releaseNoise, pickupDrive, asym, tremDepth, trem, pan;
		var eqLowDb, eqMidDb, eqHighDb;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);

		freq = (baseFreq * (2 ** dev)).max(20.0);
		rate = (freq / rootFreq.max(20.0)).clip(0.25, 4.0);
		vel = strikeVel.clip(0.02, 1.0);
		layerX = vel.linlin(0.02, 1.0, 0.0, 2.0).clip(0.0, 2.0);
		keyPos = ((freq.cpsmidi - 36) / 60).clip(0.0, 1.0);
		lowKey = 1.0 - keyPos;

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.15]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.20]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.18)).clip(0, 1), conflict * 0.16]) * amt;

		bodyCtl = body.clip(0.0, 1.0);
		brCtl = ((brightness.clip(0.0, 1.0) * brightnessAmount.clip(0.0, 2.0)) + (bloom * 0.10) + (breath * 0.08)).clip(0.0, 1.20);
		// Clean Rhodes defaults: brightness and edge must be conservative.
		// The MDA source already contains enough tine/reed bite; added edge should
		// stay subtle unless an adaptive mode deliberately asks for it.
		edgeCtl = ((edge.clip(0.0, 1.0) * 0.16) + (ed * 0.22) + ((vel * vel) * 0.035)).clip(0.0, 0.55) * roughnessAmount.clip(0.0, 1.20);
		airCtl = (air.clip(0.0, 1.0) + (breath * 0.08) + ((vel * vel) * 0.018)).clip(0.0, 0.55);
		widthCtl = (width.clip(0.0, 1.0) + (breath * 0.035)).clip(0.0, 0.62);

		// Clean-Rhodes source selection. The bundled MDA floor has a barky/hard layer
		// that reads closer to Wurlitzer when overused, so the default voicing lives
		// mostly in soft/medium layers and reserves the hard layer for extreme strike
		// plus explicit edge/adaptive pressure. This is deliberately conservative.
		layerX = (((vel * vel)) * (1.06 + (edgeCtl * 0.24) + (ed * 0.18))).clip(0.0, 1.42);
		soft = PlayBuf.ar(1, softBuf, rate * BufRateScale.kr(softBuf), trigger: 1, startPos: 0, loop: 0);
		med = PlayBuf.ar(1, medBuf, rate * BufRateScale.kr(medBuf), trigger: 1, startPos: 0, loop: 0);
		hard = PlayBuf.ar(1, hardBuf, rate * BufRateScale.kr(hardBuf), trigger: 1, startPos: 0, loop: 0);
		sig = SelectX.ar(layerX, [soft, med, hard]);

		// Clean pickup/preamp layer. Rhodes bark should appear as gentle pickup
		// compression, not obvious distortion. Keep this almost linear by default.
		pickupDrive = (1.0 + (edgeCtl * 0.18) + ((vel * vel) * 0.045) + (ed * 0.08)).clip(1.0, 1.32);
		asym = sig - ((sig.max(0) * sig.max(0)) * (0.010 + (edgeCtl * 0.020)));
		sig = tanh(asym * pickupDrive) / pickupDrive;
		sig = LeakDC.ar(sig);

		// Tiny damper/key-off layer until dedicated release samples are added. Keep
		// it low for the modern-clean Rhodes preset.
		releaseTrig = Trig1.kr(1 - gate, 0.030);
		releaseNoise = HPF.ar(PinkNoise.ar(1.0), 750 + (keyPos * 1500))
			* Decay2.kr(releaseTrig, 0.001, 0.020 + (lowKey * 0.014))
			* (0.0012 + (vel * 0.0018));
		sig = sig + releaseNoise;

		// Clean modern/classic Rhodes DI+suitcase tone. This specifically removes
		// the Wurlitzer-like honk/crunch zone and keeps the bell smooth rather than
		// fizzy. Pitch remains clear for Adaptive Temperament.
		sig = HPF.ar(sig, 34);
		sig = BLowShelf.ar(sig, 145, 0.90, (-0.4 + (bodyCtl * 1.9) + (lowKey * 0.7) + (bloom * 0.25)).clip(-3.5, 3.6));
		sig = BPeakEQ.ar(sig, 410, 0.82, (-2.2 + (bodyCtl * 0.45) - (vel * 0.15)).clip(-4.5, 0.6));
		sig = BPeakEQ.ar(sig, 980, 0.75, (-1.8 - (vel * 0.28) - (edgeCtl * 0.35)).clip(-4.0, 0.0));
		sig = BPeakEQ.ar(sig, 2200 + (keyPos * 520), 0.85, (-1.15 + (brCtl * 0.85) - (vel * 0.20)).clip(-3.5, 1.2));
		sig = BHiShelf.ar(sig, 5600, 0.80, (-0.9 + (airCtl * 1.40) + (brCtl * 0.35)).clip(-3.0, 1.4));
		sig = LPF.ar(sig, (6900 + (brCtl * 2350) + (airCtl * 700) + (keyPos * 1200)).clip(4700, 11800));
		sig = Compander.ar(sig, sig, 0.52, 1.0, 0.88, 0.006, 0.115);

		// Very subtle suitcase-style motion only. Clean Rhodes defaults should not
		// sound like chorus, phaser, or detune.
		tremDepth = ((widthCtl * 0.006) + (breath * 0.004)).clip(0.0, 0.018);
		trem = SinOsc.kr(4.08 + Rand(-0.035, 0.035), Rand(0, 6.28318), tremDepth, 1.0);
		sig = sig * trem;
		pan = (SinOsc.kr(0.13 + Rand(-0.018, 0.018), Rand(0, 6.28318), 0.045) + Rand(-0.010, 0.010))
			* widthCtl * panMotionAmount.clip(0.0, 2.0);

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);

		env = EnvGen.kr(Env.asr(0.001, 1.0, releaseTime.clip(0.06, 1.4), curve: -5), gate, doneAction: 2);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env * 1.22, pan));
	}).add;

	// ------------------------------------------------------------
	// Organ: Hammond/B-3 / Leslie-focused tonewheel voice.
	//
	// v2 correction: the previous organ was a dry per-note drawbar stack with only
	// a tiny scanner/pan approximation. It was functional, but not enough to read
	// as a finished Hammond B-3. A recognizable B-3 sound is usually the coupled
	// system: tonewheel drawbars + key contacts/click + percussion + preamp +
	// rotating speaker. This voice still keeps AT pitch sacred and does not add a
	// full global 91-wheel engine, but it makes the default organ a finished,
	// Leslie-forward B-3 style voice rather than a plain additive synth.
	// ------------------------------------------------------------
	SynthDef(\atvoice_organ, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.018, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.10,
		adaptiveMode=0, adaptiveAmount=0, body=0.70, brightness=0.42, air=0.14, edge=0.10, width=0.24, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, coh, conflict, mode, amt, bloom, breath, ed, br;
		var keyPos, vel, bodyCtl, brCtl, edgeCtl, airCtl, widthCtl, voiceLevel;
		var d16, d8, d513, d4, d223, d2, d135, d113, d1;
		var f16, f8, f513, f4, f223, f2, f135, f113, f1;
		var tone, leakage, clickEnv, click, percEnv, perc, sig, drive, pre, env;
		var horn, drum, hornRate, drumRate, hornPan, drumPan, hornAM, drumAM, hornDelayL, hornDelayR, drumDelayL, drumDelayR;
		var hornL, hornR, drumL, drumR, room, stereo, eqLowDb, eqMidDb, eqHighDb;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(20.0);

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.22]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.18]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.22)).clip(0, 1), conflict * 0.14]) * amt;

		bodyCtl = body.clip(0.0, 1.0);
		brCtl = ((brightness.clip(0.0, 1.0) * brightnessAmount.clip(0.0, 2.0)) + (bloom * 0.10) + (breath * 0.06)).clip(0.0, 1.20);
		edgeCtl = ((edge.clip(0.0, 1.0) * 0.38) + (ed * 0.32)).clip(0.0, 0.85) * roughnessAmount.clip(0.0, 1.20);
		airCtl = (air.clip(0.0, 1.0) + (breath * 0.07) + (brCtl * 0.08)).clip(0.0, 0.72);
		widthCtl = (width.clip(0.0, 1.0) + (breath * 0.07)).clip(0.0, 0.85);

		// Velocity mostly changes key-contact click/percussion, not organ loudness.
		vel = ((amp - 0.03) / 0.22).clip(0.0, 1.0);
		voiceLevel = (0.082 + (vel * 0.020)).clip(0.075, 0.112);
		keyPos = ((freq.clip(48, 4200).log2 - 5.58) / 6.15).clip(0, 1);

		// A fuller B-3 default registration: strong 16/8/5 1/3/4 body with controlled
		// upper drawbars. This reads more like a classic console through a Leslie than
		// the old thin additive test-organ profile.
		d16 = (0.78 + (bodyCtl * 0.18) - (keyPos * 0.10)).clip(0.35, 0.96);
		d8 = 1.00;
		d513 = (0.72 + (bodyCtl * 0.16)).clip(0.45, 0.92);
		d4 = (0.66 + (bodyCtl * 0.08) + (brCtl * 0.08)).clip(0.38, 0.86);
		d223 = (0.10 + (brCtl * 0.23) + (bloom * 0.08)).clip(0.04, 0.40);
		d2 = (0.045 + (brCtl * 0.13)).clip(0.015, 0.24);
		d135 = (0.012 + (airCtl * 0.065) + (ed * 0.035)).clip(0.0, 0.14);
		d113 = (0.008 + (airCtl * 0.045)).clip(0.0, 0.10);
		d1 = (0.004 + (airCtl * 0.030) + (ed * 0.018)).clip(0.0, 0.07);

		// Foldback-style tempering: avoid brittle ultrasonic partial stacks while keeping
		// the same harmonic identity inside the playable range.
		f16 = (freq * 0.5).clip(20, 5200);
		f8 = freq.clip(20, 5600);
		f513 = (freq * 1.5).clip(20, 5600);
		f4 = (freq * 2).clip(20, 6000);
		f223 = Select.kr((freq * 3) > 6200, [freq * 3, freq * 1.5]);
		f2 = Select.kr((freq * 4) > 6400, [freq * 4, freq * 2]);
		f135 = Select.kr((freq * 5) > 6600, [freq * 5, freq * 2.5]);
		f113 = Select.kr((freq * 6) > 6800, [freq * 6, freq * 3]);
		f1 = Select.kr((freq * 8) > 7000, [freq * 8, freq * 4]);

		// Already-running-wheel illusion: random phase per contact, plus tiny non-perfect
		// wheel balance. This is still per-note, but avoids reset-phase synth organ.
		tone = Mix.ar([
			SinOsc.ar(f16 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d16 * Rand(0.985, 1.015)),
			SinOsc.ar(f8 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d8 * Rand(0.985, 1.015)),
			SinOsc.ar(f513 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d513 * Rand(0.985, 1.015)),
			SinOsc.ar(f4 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d4 * Rand(0.985, 1.015)),
			SinOsc.ar(f223 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d223 * Rand(0.980, 1.020)),
			SinOsc.ar(f2 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d2 * Rand(0.980, 1.020)),
			SinOsc.ar(f135 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d135),
			SinOsc.ar(f113 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d113),
			SinOsc.ar(f1 * Rand(0.9997, 1.0003), Rand(0, 6.28318), d1)
		]);
		tone = tone / (d16 + d8 + d513 + d4 + d223 + d2 + d135 + d113 + d1 + 0.001);

		// Leakage/crosstalk bed. Very low, but important for non-sterile tonewheel body.
		leakage = Mix.ar([
			SinOsc.ar((freq * 0.4987).clip(20, 5200), Rand(0, 6.28318), 0.010),
			SinOsc.ar((freq * 1.997).clip(20, 6200), Rand(0, 6.28318), 0.007),
			SinOsc.ar((freq * 3.012).clip(20, 7000), Rand(0, 6.28318), 0.003),
			BPF.ar(PinkNoise.ar(1.0), (freq * 2.7).clip(160, 5000), 0.20, 0.0025)
		]) * (0.34 + (bodyCtl * 0.34) + (airCtl * 0.18));

		// Contact/key click: short, bright, touch-dependent. This is the organ's attack,
		// not a piano envelope.
		clickEnv = EnvGen.kr(Env.perc(0.00035, 0.006 + (vel * 0.010), curve: -7), 1);
		click = (HPF.ar(WhiteNoise.ar(1.0), 2100 + (keyPos * 2700))
			+ BPF.ar(WhiteNoise.ar(1.0), 6200 + (keyPos * 2100), 0.55))
			* clickEnv
			* (0.0065 + (vel * 0.015) + (edgeCtl * 0.010));

		// B-3 jazz percussion color. Still per-note, but softer and more authentic than
		// a generic bright pluck. Full single-trigger manual logic should be global later.
		percEnv = EnvGen.kr(Env.perc(0.0015, (0.30 - (brCtl * 0.055)).clip(0.18, 0.36), curve: -6), 1);
		perc = SinOsc.ar(freq * 3.0, Rand(0, 6.28318))
			* percEnv
			* (0.018 + (vel * 0.010) + (brCtl * 0.006))
			* (1.0 - (bodyCtl * 0.20));

		sig = tone + leakage + click + perc;

		// AO-28 / transformer-ish preamp authority. Keep clean by default, but remove
		// the sterile direct-organ edge.
		sig = HPF.ar(sig, 36);
		sig = BLowShelf.ar(sig, 115, 0.90, (0.9 + (bodyCtl * 1.8)).clip(-1.0, 3.2));
		sig = BPeakEQ.ar(sig, 360, 0.76, (-1.3 + (bodyCtl * 0.25)).clip(-2.6, 0.2));
		sig = BPeakEQ.ar(sig, 880, 0.70, (-0.35 + (edgeCtl * 0.35)).clip(-1.4, 0.8));
		sig = BHiShelf.ar(sig, 3100, 0.82, (-0.20 + (brCtl * 1.00) + (airCtl * 0.80)).clip(-1.6, 2.0));
		sig = LPF.ar(sig, (7200 + (brCtl * 2200) + (airCtl * 600)).clip(5000, 10600));

		drive = (1.10 + (edgeCtl * 0.48) + (ed * 0.44)).clip(1.02, 2.10);
		pre = tanh((sig + (sig * sig * 0.018)) * drive) / drive;
		sig = LeakDC.ar((sig * 0.74) + (pre * 0.26));

		// Leslie-style split. This is the missing finished-sound stage: horn and drum are
		// separated, moved, filtered, and recombined instead of just panning the mono organ.
		horn = HPF.ar(sig, 760);
		drum = LPF.ar(sig, 760);
		hornRate = (0.78 + (breath * 1.85) + (widthCtl * 0.12)).clip(0.45, 3.8);
		drumRate = (0.38 + (breath * 0.72) + (widthCtl * 0.06)).clip(0.22, 1.55);
		hornPan = SinOsc.kr(hornRate, Rand(0, 6.28318));
		drumPan = SinOsc.kr(drumRate, Rand(0, 6.28318));
		hornAM = 0.74 + (hornPan.abs * (0.16 + (widthCtl * 0.08)));
		drumAM = 0.83 + (drumPan.abs * (0.08 + (widthCtl * 0.05)));
		hornDelayL = 0.0042 + (hornPan * 0.00125);
		hornDelayR = 0.0042 - (hornPan * 0.00125);
		drumDelayL = 0.0065 + (drumPan * 0.00075);
		drumDelayR = 0.0065 - (drumPan * 0.00075);
		hornL = DelayC.ar(horn, 0.012, hornDelayL.clip(0.0015, 0.010)) * (1.0 - (hornPan * 0.23)) * hornAM;
		hornR = DelayC.ar(horn, 0.012, hornDelayR.clip(0.0015, 0.010)) * (1.0 + (hornPan * 0.23)) * hornAM;
		drumL = DelayC.ar(drum, 0.014, drumDelayL.clip(0.0025, 0.012)) * (1.0 - (drumPan * 0.10)) * drumAM;
		drumR = DelayC.ar(drum, 0.014, drumDelayR.clip(0.0025, 0.012)) * (1.0 + (drumPan * 0.10)) * drumAM;

		// Directional/cabinet coloration: horn moves brighter when aimed, drum stays warm.
		hornL = BPeakEQ.ar(hornL, 2450 + (hornPan.range(0, 1) * 620), 0.72, 1.15 + (airCtl * 0.7));
		hornR = BPeakEQ.ar(hornR, 2450 + ((1 - hornPan).range(0, 1) * 620), 0.72, 1.15 + (airCtl * 0.7));
		drumL = BLowShelf.ar(drumL, 190, 0.85, 1.15 + (bodyCtl * 0.65));
		drumR = BLowShelf.ar(drumR, 190, 0.85, 1.15 + (bodyCtl * 0.65));
		stereo = [hornL + drumL, hornR + drumR];

		// Small cabinet/room glue; not reverb-heavy, just less DI/test-tone.
		room = DelayC.ar(stereo.reverse, 0.030, [0.017, 0.023]) * (0.030 + (widthCtl * 0.030));
		stereo = (stereo * (0.92 + (widthCtl * 0.05))) + room;
		stereo = LeakDC.ar(stereo);
		stereo = Limiter.ar(stereo, 0.92, 0.006);

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		stereo = BLowShelf.ar(stereo, 180, 1.0, eqLowDb);
		stereo = BPeakEQ.ar(stereo, 1000, 1.0, eqMidDb);
		stereo = BHiShelf.ar(stereo, 3600, 1.0, eqHighDb);

		env = EnvGen.kr(Env.asr(0.0025 + (vel * 0.003), 1.0, releaseTime.clip(0.025, 1.2), curve: -3), gate, doneAction: 2);
		Out.ar(out, stereo * masterAmp * env * voiceLevel * 1.42);
	}).add;

	// ------------------------------------------------------------
	// Strings: VSCO sample/model hybrid chamber section.
	//
	// This is the serious string route: real bowed section sustain samples are the
	// primary source identity, while the model layer only adds controllable bow air,
	// body glue, and Adaptive Temperament-aware timbre. Pitch still comes from the
	// AT field through playback-rate retuning.
	// ------------------------------------------------------------
	SynthDef(\atvoice_strings_sample, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.018, alignLag=0.06, motionLag=0.05, stabLag=0.06, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.86,
		adaptiveMode=0, adaptiveAmount=0, body=0.68, brightness=0.39, air=0.16, edge=0.11, width=0.34,
		lowEQ=0.5, midEQ=0.5, highEQ=0.5,
		sourceBuf=0, rootFreq=440, stringKind=1, strikeVel=0.6, startFrame=0|
		var dev, align, motion, stab, tension, freq, rate, midi, keyPos, lowKey, highKey, vel;
		var coh, conflict, mode, amt, bloom, breath, ed;
		var bodyCtl, brCtl, airCtl, edgeCtl, widthCtl, sig, dry, env, attackTime, rosinEnv, rosin, bodyWarm, chamber;
		var mid, side, eqLowDb, eqMidDb, eqHighDb, safeStart, celloMix, violinMix, warmth, harshCut, topCut;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(24.0);
		rate = (freq / rootFreq.max(20.0)).clip(0.50, 1.92);
		midi = freq.cpsmidi;
		keyPos = ((midi - 36.0) / 48.0).clip(0.0, 1.0);
		lowKey = (1.0 - keyPos).clip(0.0, 1.0);
		highKey = keyPos.clip(0.0, 1.0);
		vel = strikeVel.clip(0.02, 1.0);

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.16]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.24]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.22)).clip(0, 1), conflict * 0.08]) * amt;

		// v3 voicing: warm chamber strings, not bright sample playback. The VSCO
		// source provides bow/section identity; the processing removes the brittle,
		// hollow, plasticky edge instead of adding synth harmonics.
		bodyCtl = (body.clip(0, 1) + 0.18 + (bloom * 0.10)).clip(0.0, 1.25);
		brCtl = ((brightness.clip(0, 1) * 0.72 * brightnessAmount.clip(0, 2)) + (bloom * 0.03) + (breath * 0.04) + (ed * 0.06)).clip(0.0, 0.86);
		airCtl = ((air.clip(0, 1) * 0.42) + (breath * 0.08) + (ed * 0.035) - (bloom * 0.025)).clip(0.0, 0.32);
		edgeCtl = ((edge.clip(0, 1) * 0.36) + (ed * 0.18) + (breath * 0.025)).clip(0.0, 0.38);
		widthCtl = ((width.clip(0, 1) * 0.42) + (breath * 0.035)).clip(0.0, 0.46);

		safeStart = startFrame.clip(0, 2500);
		dry = PlayBuf.ar(2, sourceBuf, rate * BufRateScale.kr(sourceBuf), trigger: 1, startPos: safeStart, loop: 0);
		dry = LeakDC.ar(dry);
		celloMix = (1.0 - stringKind.clip(0, 1));
		violinMix = stringKind.clip(0, 1);

		// Start from a darker, closer, more solid section sound.
		sig = HPF.ar(dry, 42 + (violinMix * 18));
		sig = BLowShelf.ar(sig, 120, 0.72, (1.10 + (bodyCtl * 1.15) + (celloMix * 0.55)).clip(0.0, 3.2));
		sig = BPeakEQ.ar(sig, 240 + (celloMix * 25), 0.82, (0.85 + (bodyCtl * 0.90)).clip(0.0, 2.2));
		sig = BPeakEQ.ar(sig, 430 + (keyPos * 70), 0.78, (0.35 + (bodyCtl * 0.50)).clip(0.0, 1.2));
		sig = BPeakEQ.ar(sig, 760 + (keyPos * 120), 0.78, (-1.35 + (bloom * 0.15)).clip(-2.4, -0.25));
		sig = BPeakEQ.ar(sig, 1180 + (keyPos * 170), 0.92, (-1.65 + (bodyCtl * 0.10)).clip(-2.7, -0.7));
		sig = BPeakEQ.ar(sig, 2150 + (keyPos * 360), 0.88, (-2.65 + (edgeCtl * 0.35)).clip(-3.8, -1.25));
		sig = BPeakEQ.ar(sig, 3600 + (keyPos * 720), 0.92, (-3.40 + (airCtl * 0.60) + (edgeCtl * 0.32)).clip(-4.8, -1.35));
		sig = BHiShelf.ar(sig, 5200, 0.78, (-4.40 + (airCtl * 0.95) + (edgeCtl * 0.25)).clip(-6.2, -2.1));
		topCut = (5200 + (brCtl * 1700) + (violinMix * 700) + (edgeCtl * 600)).clip(3900, 8200);
		sig = LPF.ar(sig, topCut);

		// Body thickening from the real sample only; no audible oscillator stack. This
		// fills the hollow center that makes small string samples sound toy-like.
		warmth = BPF.ar(sig, (freq * 0.52).clip(75, 290), 0.58) * (0.040 + (bodyCtl * 0.060) + (celloMix * 0.025));
		warmth = warmth + (BPF.ar(sig, (freq * 0.98).clip(115, 850), 0.42) * (0.016 + (bodyCtl * 0.030)));
		warmth = warmth + (BPF.ar(sig, (freq * 1.48).clip(180, 1450), 0.34) * (0.006 + (bodyCtl * 0.010)));
		sig = sig + warmth;

		// Very restrained bow air. v2 added too much bright synthetic rosin; v3 keeps
		// the bow cue dark and transient so it reads as friction, not plastic noise.
		rosinEnv = EnvGen.kr(Env.perc(0.010, (0.10 + ((1.0 - vel) * 0.15)).clip(0.07, 0.28), 1.0, -4), 1);
		rosin = BPF.ar(PinkNoise.ar(1!2), (720 + (freq * (0.55 + (edgeCtl * 0.55)))).clip(420, 2400), 0.55)
			* ((0.0009 + (airCtl * 0.0035) + (edgeCtl * 0.0035) + (breath * 0.0028)) * (0.65 + (vel * 0.35)));
		rosin = rosin + (BPF.ar(PinkNoise.ar(1!2), (1200 + (freq * 0.70)).clip(700, 2900), 0.42) * rosinEnv * (0.0035 + (edgeCtl * 0.0045)));
		sig = sig + rosin;

		// Replace the hollow allpass wash with darker, shorter early reflections.
		chamber = DelayC.ar(LPF.ar(sig.reverse, 4200), 0.040, [0.011, 0.017]) * (0.018 + (widthCtl * 0.018));
		chamber = chamber + (DelayC.ar(LPF.ar(sig, 3600), 0.050, [0.027, 0.034]) * (0.012 + (widthCtl * 0.010)));
		sig = sig + chamber;

		// Narrower image than v2. Wide M/S on small samples was making the sound hollow.
		mid = (sig[0] + sig[1]) * 0.5;
		side = (sig[0] - sig[1]) * (0.52 + (widthCtl * 0.30));
		sig = [mid + side, mid - side];

		// Gentle final glue and user EQ. Defaults remain neutral from the UI, while
		// the profile's internal voice is now warm/dark enough to be usable.
		sig = BPeakEQ.ar(sig, 520, 0.90, 0.25);
		sig = BPeakEQ.ar(sig, 2500, 0.90, -0.75);
		sig = BHiShelf.ar(sig, 6200, 0.80, -1.1);
		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		sig = LeakDC.ar(sig);
		sig = Limiter.ar(sig, 0.90, 0.012);

		attackTime = (0.055 + ((1.0 - vel) * 0.090) + (celloMix * 0.018)).clip(0.045, 0.170);
		env = EnvGen.kr(Env.asr(attackTime, 1.0, releaseTime.clip(0.28, 3.2), curve: -3), gate, doneAction: 2);
		Out.ar(out, sig * amp * masterAmp * env * 1.05);
	}).add;

	// ------------------------------------------------------------
	// Strings: Adaptive Temperament-native bowed ensemble.
	//
	// v4 correction: no VSCO / no baked sample vibrato as the serious voice.
	// This is deliberately not a fake orchestral library and not a synth-string
	// pad. It is a warm, modern, pitch-clear bowed-resonant ensemble designed for
	// Adaptive Temperament: bow pressure, body, rosin, chamber depth, and very
	// restrained motion. Static mode has no obvious vibrato.
	// ------------------------------------------------------------
	SynthDef(\atvoice_strings_native, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.030, alignLag=0.06, motionLag=0.05, stabLag=0.06, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.95,
		adaptiveMode=0, adaptiveAmount=0, body=0.72, brightness=0.34, air=0.10, edge=0.08, width=0.24,
		lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, midi, keyPos, lowKey, highKey, vel;
		var coh, conflict, mode, amt, bloom, breath, ed;
		var bodyCtl, brCtl, airCtl, edgeCtl, widthCtl, bowPressure, bowStart, bowEnv, sustainEnv;
		var detuneCents, slowCents, vibCents, vibRise, deskFreq, pressureJitter, bowWidth;
		var rawBow, darkBow, noiseBow, string, bodySig, desks, stereo, rosin, onset, room, env;
		var cutoff, rq, mid, side, eqLowDb, eqMidDb, eqHighDb, gainTrim;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(24.0);
		midi = freq.cpsmidi;
		keyPos = ((midi - 36.0) / 48.0).clip(0.0, 1.0);
		lowKey = (1.0 - keyPos).clip(0.0, 1.0);
		highKey = keyPos.clip(0.0, 1.0);
		vel = ((amp - 0.03) / 0.18).clip(0.0, 1.0);

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.16]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.22]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.22)).clip(0, 1), conflict * 0.08]) * amt;

		// Darker defaults. The previous string versions sounded cheap because the
		// source was bright and vibrato-heavy. This voice keeps static mode almost
		// non-vibrato, relying on bow/body movement rather than pitch wobble.
		bodyCtl = (body.clip(0, 1) + 0.22 + (bloom * 0.10)).clip(0.0, 1.30);
		brCtl = ((brightness.clip(0, 1) * 0.58 * brightnessAmount.clip(0, 2)) + (bloom * 0.035) + (breath * 0.030) + (ed * 0.045)).clip(0.0, 0.62);
		airCtl = ((air.clip(0, 1) * 0.34) + (breath * 0.075) + (ed * 0.030)).clip(0.0, 0.26);
		edgeCtl = ((edge.clip(0, 1) * 0.30) + (ed * 0.16) + (breath * 0.018)).clip(0.0, 0.32);
		widthCtl = ((width.clip(0, 1) * 0.45) + (breath * 0.030)).clip(0.0, 0.42);
		bowPressure = (0.50 + (bodyCtl * 0.22) + (vel * 0.05) + (ed * 0.10) - (bloom * 0.025)).clip(0.38, 0.88);

		// Four quiet desks. Micro-detune is sub-cent-ish: enough to avoid a single
		// oscillator, not enough to smear Adaptive Temperament pitch.
		detuneCents = [-0.52, -0.16, 0.18, 0.49];
		slowCents = LFNoise1.kr([0.11, 0.09, 0.075, 0.065]).range(-0.10, 0.10);
		vibRise = LagUD.kr(gate, 1.20 + ((1.0 - vel) * 0.45), 0.12);
		vibCents = SinOsc.kr([4.82, 5.07, 5.24, 5.41], [0.0, 1.5, 3.2, 4.6])
			* ((breath * 0.85) + (ed * 0.38)).clip(0.0, 1.45) * vibRise;
		deskFreq = (freq * (2 ** ((detuneCents + slowCents + vibCents) / 1200.0))).clip(24.0, 12000.0);

		bowStart = (0.090 + ((1.0 - vel) * 0.110) + (lowKey * 0.035)).clip(0.055, 0.240);
		bowEnv = EnvGen.kr(Env([0.0, 1.10, 0.92, 1.0], [bowStart, 0.38, 1.20], [-3, -5, -2]), gate);
		sustainEnv = LagUD.kr(gate, bowStart, 0.24);
		pressureJitter = LFNoise1.kr([0.42, 0.36, 0.29, 0.23]).range(0.88, 1.10);
		bowWidth = (0.18 + (bowPressure * 0.18) + LFNoise1.kr([0.19, 0.17, 0.13, 0.10]).range(-0.025, 0.025)).clip(0.12, 0.42);

		// Bowed source: a dark stick/slip core excited by filtered noise and a small
		// non-saw periodic component. The comb is fed continuously, so the tone is
		// sustained but not organ-stable.
		rawBow = VarSaw.ar(deskFreq, [0.11, 0.37, 0.61, 0.83], bowWidth, 0.19)
			+ (LFPulse.ar(deskFreq, [0.21, 0.49, 0.72, 0.93], (0.11 + (bowPressure * 0.08)).clip(0.08, 0.22), 0.045));
		rawBow = tanh(rawBow * (1.45 + (bowPressure * 0.65))) * 0.34;
		noiseBow = RLPF.ar(PinkNoise.ar(1!4), (deskFreq * (1.35 + (brCtl * 0.45))).clip(120, 3600), 0.42)
			* (0.055 + (airCtl * 0.070) + (edgeCtl * 0.045)) * pressureJitter;
		darkBow = RLPF.ar(rawBow + noiseBow, (900 + (brCtl * 2400) + (highKey * 1600)).clip(520, 5200), 0.34 + (bloom * 0.08));
		string = CombC.ar(darkBow, 0.060, (1.0 / deskFreq).clip(0.00032, 0.052), (0.42 + (lowKey * 0.42) + (bodyCtl * 0.30)).clip(0.34, 1.30));
		desks = ((darkBow * 0.58) + (string * (0.30 + (bodyCtl * 0.16)))) * bowEnv * sustainEnv;

		// Instrument-family body: cello/viola/violin cues by register, but all dark and
		// close. Avoid the 2–5 kHz plasticky zone that made VSCO feel toy-like.
		cutoff = (1450 + (brCtl * 2300) + (highKey * 1500) + (ed * 700)).clip(760, 6200);
		rq = (0.46 - (edgeCtl * 0.10) + (bloom * 0.08)).clip(0.28, 0.68);
		desks = RLPF.ar(desks, cutoff, rq);
		desks = BPeakEQ.ar(desks, 185 + (lowKey * 55), 0.78, 1.10 + (bodyCtl * 1.05));
		desks = BPeakEQ.ar(desks, 330 + (keyPos * 65), 0.82, 0.72 + (bodyCtl * 0.78));
		desks = BPeakEQ.ar(desks, 590 + (keyPos * 85), 0.78, 0.22 + (bodyCtl * 0.32));
		desks = BPeakEQ.ar(desks, 980 + (keyPos * 180), 0.88, -1.20 + (bloom * 0.18));
		desks = BPeakEQ.ar(desks, 1650 + (keyPos * 260), 0.94, -1.45 + (edgeCtl * 0.22));
		desks = BPeakEQ.ar(desks, 2800 + (highKey * 620), 0.90, -2.65 + (edgeCtl * 0.35));
		desks = BHiShelf.ar(desks, 5200, 0.80, -4.40 + (airCtl * 0.75));
		desks = LPF.ar(desks, (4800 + (brCtl * 1400) + (highKey * 700)).clip(3600, 7000));

		stereo = Splay.ar(desks, (0.18 + (widthCtl * 0.34)).clip(0.12, 0.48), 1.0, 0.0);

		// Bow onset and rosin are dark and mostly transient. No baked sample vibrato,
		// no bright constant hiss.
		onset = EnvGen.kr(Env.perc(0.004, (0.16 + ((1.0 - vel) * 0.10)).clip(0.10, 0.30), 1.0, -4), gate);
		rosin = BPF.ar(PinkNoise.ar(1!2), (520 + (freq * 0.72)).clip(360, 1550), 0.62)
			* onset * (0.008 + (edgeCtl * 0.010) + (vel * 0.004));
		rosin = rosin + (BPF.ar(BrownNoise.ar(1!2), (900 + (freq * 0.45)).clip(540, 2100), 0.48)
			* (0.0015 + (airCtl * 0.0035) + (breath * 0.0025)) * sustainEnv);
		stereo = stereo + rosin;

		// Short, dark chamber glue. This is not a big reverb and not a phasey widening
		// trick; it just prevents the model from sounding DI and flat.
		room = DelayC.ar(LPF.ar(stereo.reverse, 2800), 0.045, [0.012, 0.019]) * (0.026 + (widthCtl * 0.016));
		room = room + (DelayC.ar(LPF.ar(stereo, 2400), 0.060, [0.031, 0.043]) * (0.014 + (widthCtl * 0.012)));
		stereo = stereo + room;

		// Keep image controlled. Wide fake strings sound hollow fast.
		mid = (stereo[0] + stereo[1]) * 0.5;
		side = (stereo[0] - stereo[1]) * (0.62 + (widthCtl * 0.26));
		stereo = [mid + side, mid - side];

		// Profile voicing and final user EQ.
		stereo = BLowShelf.ar(stereo, 150, 0.82, 1.05 + (bodyCtl * 0.55));
		stereo = BPeakEQ.ar(stereo, 410, 0.85, 0.35);
		stereo = BPeakEQ.ar(stereo, 1250, 0.82, -0.80);
		stereo = BPeakEQ.ar(stereo, 2450, 0.90, -1.25);
		stereo = BHiShelf.ar(stereo, 5600, 0.78, -1.65);
		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		stereo = BLowShelf.ar(stereo, 180, 1.0, eqLowDb);
		stereo = BPeakEQ.ar(stereo, 1000, 1.0, eqMidDb);
		stereo = BHiShelf.ar(stereo, 3600, 1.0, eqHighDb);
		stereo = LeakDC.ar(stereo);
		stereo = Limiter.ar(stereo, 0.90, 0.010);

		env = EnvGen.kr(Env.asr(bowStart, 1.0, releaseTime.clip(0.24, 3.6), curve: -3), gate, doneAction: 2);
		gainTrim = 1.06 + (lowKey * 0.10) - (highKey * 0.05);
		Out.ar(out, stereo * amp * masterAmp * env * gainTrim);
	}).add;

	// ------------------------------------------------------------
	// Retired internal bowed-resonant experiment. Not exposed as a main tone profile.
	//
	// This is not marketed as a realistic orchestral string library. The real
	// "strings" profile is reserved for a future premium external/user-supplied
	// string source. This experiment stayed too pad-like to expose as an instrument,
	// warm, smooth, pitch-clear, and free of cheap baked sample vibrato.
	// No comb/pluck topology is used here; the v4 resonator design was too sitar-
	// like. This voice uses a dark continuous excitation, slow formant/body motion,
	// restrained desk spread, and adaptive bow-pressure/air macros.
	// ------------------------------------------------------------
	SynthDef(\atvoice_adaptive_bowed, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.035, alignLag=0.08, motionLag=0.06, stabLag=0.08, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=1.15,
		adaptiveMode=0, adaptiveAmount=0, body=0.78, brightness=0.28, air=0.10, edge=0.05, width=0.28,
		lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, midi, keyPos, lowKey, highKey, vel;
		var coh, conflict, mode, amt, bloom, breath, ed;
		var bodyCtl, brCtl, airCtl, edgeCtl, widthCtl, bowCtl, attack, env, speakEnv;
		var deskCents, drift, vib, vibDepth, deskFreq, phase, slowAmp, harmonic, breathNoise, bowNoise;
		var desk, desks, stereo, bodyMove, lowBody, midBody, upper, room, mid, side;
		var eqLowDb, eqMidDb, eqHighDb, cutoff, gainTrim;

		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(24.0);
		midi = freq.cpsmidi;
		keyPos = ((midi - 36.0) / 48.0).clip(0.0, 1.0);
		lowKey = (1.0 - keyPos).clip(0.0, 1.0);
		highKey = keyPos.clip(0.0, 1.0);
		vel = ((amp - 0.03) / 0.18).clip(0.0, 1.0);

		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.20]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.24]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.22)).clip(0, 1), conflict * 0.10]) * amt;

		bodyCtl = (body.clip(0, 1) + 0.20 + (bloom * 0.10)).clip(0.0, 1.25);
		brCtl = ((brightness.clip(0, 1) * 0.44 * brightnessAmount.clip(0, 2)) + (bloom * 0.025) + (breath * 0.030) + (ed * 0.040)).clip(0.0, 0.55);
		airCtl = ((air.clip(0, 1) * 0.30) + (breath * 0.080) + (ed * 0.025)).clip(0.0, 0.28);
		edgeCtl = ((edge.clip(0, 1) * 0.20) + (ed * 0.12) + (breath * 0.012)).clip(0.0, 0.24);
		widthCtl = ((width.clip(0, 1) * 0.55) + (breath * 0.025)).clip(0.0, 0.46);
		bowCtl = (0.48 + (bodyCtl * 0.18) + (vel * 0.06) + (ed * 0.07) - (bloom * 0.035)).clip(0.38, 0.78);

		// Restrained desks: tiny motion, no chorus wash, no baked vibrato. Vibrato is
		// nearly absent in static mode and grows only from adaptive motion/edge.
		deskCents = [-0.42, -0.17, 0.15, 0.39];
		drift = LFNoise1.kr([0.07, 0.09, 0.06, 0.08]).range(-0.12, 0.12);
		vibDepth = ((breath * 0.45) + (ed * 0.18)).clip(0.0, 0.85);
		vib = SinOsc.kr([4.55, 4.78, 5.02, 5.19], [0.0, 1.7, 3.3, 4.4]) * vibDepth;
		deskFreq = (freq * (2 ** ((deskCents + drift + vib) / 1200.0))).clip(24.0, 11000.0);

		attack = (0.145 + ((1.0 - vel) * 0.105) + (lowKey * 0.045)).clip(0.085, 0.300);
		speakEnv = EnvGen.kr(Env([0, 0.72, 1.0], [attack, 0.65], [-3, -5]), gate);
		env = EnvGen.kr(Env.asr(attack, 1.0, releaseTime.clip(0.35, 4.0), curve: -3), gate, doneAction: 2);
		slowAmp = LFNoise1.kr([0.31, 0.27, 0.23, 0.19]).range(0.88, 1.06);
		phase = [0.0, 1.6, 3.2, 4.8];

		// Smooth bowed body. Mostly sine/triangle partials with filtered excitation;
		// no combs, no pulses, no pluck-like feedback, so it should not become sitar.
		harmonic = (SinOsc.ar(deskFreq, phase, 0.58)
			+ SinOsc.ar(deskFreq * 2.002, phase + 0.4, 0.20 + (bodyCtl * 0.04))
			+ SinOsc.ar(deskFreq * 3.006, phase + 0.9, 0.080 + (brCtl * 0.030))
			+ SinOsc.ar(deskFreq * 4.012, phase + 1.6, 0.030 + (edgeCtl * 0.025)));
		harmonic = harmonic * slowAmp * speakEnv;

		breathNoise = RLPF.ar(PinkNoise.ar(1!4), (deskFreq * (1.10 + (brCtl * 0.35))).clip(120, 3000), 0.58)
			* (0.020 + (airCtl * 0.040) + (edgeCtl * 0.018)) * speakEnv;
		bowNoise = BPF.ar(BrownNoise.ar(1!4), (420 + (freq * 0.38)).clip(260, 1500), 0.62)
			* (0.006 + (edgeCtl * 0.010)) * EnvGen.kr(Env.perc(0.006, 0.24 + ((1.0 - vel) * 0.12), 1.0, -5), gate);

		desk = tanh((harmonic + breathNoise + bowNoise) * (0.80 + (bowCtl * 0.22))) * (0.72 + (bodyCtl * 0.08));

		// Dark, broad, moving body. Broad filters only: no resonant comb string.
		bodyMove = LFNoise1.kr([0.10, 0.08, 0.075, 0.065]).range(-35, 35);
		lowBody = BPF.ar(desk, (185 + (lowKey * 55) + bodyMove).clip(120, 280), 0.92) * (0.22 + (bodyCtl * 0.10));
		midBody = BPF.ar(desk, (360 + (keyPos * 80) + bodyMove).clip(260, 520), 1.15) * (0.18 + (bodyCtl * 0.08));
		upper = LPF.ar(desk, (1550 + (brCtl * 2100) + (highKey * 950) + (ed * 450)).clip(900, 4800));
		desks = (upper * 0.78) + lowBody + midBody;
		desks = BPeakEQ.ar(desks, 850 + (keyPos * 120), 0.80, -1.35);
		desks = BPeakEQ.ar(desks, 1650 + (keyPos * 220), 0.92, -1.25 + (edgeCtl * 0.20));
		desks = BPeakEQ.ar(desks, 2700 + (highKey * 520), 0.90, -2.95 + (edgeCtl * 0.25));
		desks = BHiShelf.ar(desks, 5200, 0.80, -5.20 + (airCtl * 0.85));
		cutoff = (4300 + (brCtl * 1050) + (highKey * 500)).clip(3200, 6200);
		desks = LPF.ar(desks, cutoff);

		stereo = Splay.ar(desks, (0.16 + (widthCtl * 0.30)).clip(0.10, 0.40), 1.0, 0.0);
		room = DelayC.ar(LPF.ar(stereo.reverse, 2300), 0.050, [0.013, 0.021]) * (0.020 + (widthCtl * 0.012));
		room = room + (DelayC.ar(LPF.ar(stereo, 2100), 0.065, [0.033, 0.046]) * (0.012 + (widthCtl * 0.008)));
		stereo = stereo + room;

		mid = (stereo[0] + stereo[1]) * 0.5;
		side = (stereo[0] - stereo[1]) * (0.56 + (widthCtl * 0.22));
		stereo = [mid + side, mid - side];

		// Built-in voicing: warm/dark modern bowed ensemble. User L/M/H remains last.
		stereo = BLowShelf.ar(stereo, 150, 0.82, 1.15 + (bodyCtl * 0.45));
		stereo = BPeakEQ.ar(stereo, 430, 0.90, 0.32);
		stereo = BPeakEQ.ar(stereo, 1150, 0.82, -1.05);
		stereo = BPeakEQ.ar(stereo, 2350, 0.92, -1.75);
		stereo = BHiShelf.ar(stereo, 5600, 0.78, -2.15);
		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		stereo = BLowShelf.ar(stereo, 180, 1.0, eqLowDb);
		stereo = BPeakEQ.ar(stereo, 1000, 1.0, eqMidDb);
		stereo = BHiShelf.ar(stereo, 3600, 1.0, eqHighDb);
		stereo = LeakDC.ar(stereo);
		stereo = Limiter.ar(stereo, 0.90, 0.010);
		gainTrim = 0.88 + (lowKey * 0.10) - (highKey * 0.04);
		Out.ar(out, stereo * amp * masterAmp * env * gainTrim);
	}).add;

	// ------------------------------------------------------------
	// Pad: slow harmonic cloud, still pitch-readable.
	// ------------------------------------------------------------
	SynthDef(\atvoice_pad, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.045, alignLag=0.08, motionLag=0.06, stabLag=0.08, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.9,
		adaptiveMode=0, adaptiveAmount=0, body=0.62, brightness=0.38, air=0.20, edge=0.10, width=0.35, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, coh, conflict, mode, amt, bloom, breath, ed, br, sig, env, cutoff, pan, slow, eqLowDb, eqMidDb, eqHighDb;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(20.0);
		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.35]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.55]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.35)).clip(0, 1), conflict * 0.18]) * amt;
		br = (brightness + (bloom * 0.35) + (breath * 0.18) + (ed * 0.28)).clip(0, 1.5);
		slow = LFNoise1.kr([0.07, 0.09]).range(0.995, 1.005);
		sig = Mix.ar([
			VarSaw.ar(freq * slow[0], 0, 0.42, 0.38),
			VarSaw.ar(freq * 2.0 * slow[1], 0, 0.40, 0.18),
			SinOsc.ar(freq * 0.5, 0, 0.16 * body.clip(0, 1)),
			SinOsc.ar(freq * 3.0, 0, 0.07 + (br * 0.09))
		]);
		sig = sig + (BPF.ar(PinkNoise.ar(1), (freq * 4.0).clip(300, 9000), 0.2) * (air + breath) * 0.05);
		cutoff = (700 + (br * 6800) + (bloom * 1400)).clip(250, 13000);
		sig = RLPF.ar(sig, cutoff, 0.35 + (coh * 0.18));
		env = EnvGen.kr(Env.asr(0.38, 1.0, releaseTime.clip(0.2, 4.0)), gate, doneAction: 2);
		pan = LFNoise1.kr(0.12).range(-0.42, 0.42) * (width + (breath * 0.15)).clip(0, 1) * panMotionAmount;

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env * 0.72, pan));
	}).add;

	// ------------------------------------------------------------
	// Synth: subtractive voice for more obvious adaptive color later.
	// ------------------------------------------------------------
	SynthDef(\atvoice_synth, {
		|out=0, gate=1, baseFreq=440, pc=0, devBus=0, alignBus=0, motionBus=0, stabBus=0, tensionBus=0,
		amp=0.12, pitchLag=0.025, alignLag=0.04, motionLag=0.03, stabLag=0.04, brightnessAmount=1.0,
		roughnessAmount=1.0, panMotionAmount=1.0, masterAmp=1.0, releaseTime=0.25,
		adaptiveMode=0, adaptiveAmount=0, body=0.55, brightness=0.55, air=0.08, edge=0.18, width=0.25, lowEQ=0.5, midEQ=0.5, highEQ=0.5|
		var dev, align, motion, stab, tension, freq, coh, conflict, mode, amt, bloom, breath, ed, br, sig, env, cutoff, rq, pan, pulse, eqLowDb, eqMidDb, eqHighDb;
		dev = Lag.kr(In.kr(devBus + pc), pitchLag.max(0.001));
		align = Lag.kr(In.kr(alignBus + pc), alignLag.max(0.001)).clip(0, 1);
		motion = Lag.kr(In.kr(motionBus + pc), motionLag.max(0.001)).clip(0, 1);
		stab = Lag.kr(In.kr(stabBus + pc), stabLag.max(0.001)).clip(0, 1);
		tension = In.kr(tensionBus).clip(0, 1);
		freq = (baseFreq * (2 ** dev)).max(20.0);
		coh = ((align + stab) * 0.5).clip(0, 1);
		conflict = (1.0 - stab).clip(0, 1);
		mode = adaptiveMode.clip(0, 4);
		amt = adaptiveAmount.clip(0, 1);
		bloom = Select.kr(mode, [0, coh, 0, 0, coh * 0.20]) * amt;
		breath = Select.kr(mode, [0, 0, motion, 0, motion * 0.35]) * amt;
		ed = Select.kr(mode, [0, 0, 0, (conflict + (tension * 0.4)).clip(0, 1), conflict * 0.2]) * amt;
		br = (brightness + (bloom * 0.20) + (breath * 0.20) + (ed * 0.60)).clip(0, 1.5);
		pulse = LFPulse.ar(freq, 0, 0.48 + (body.clip(0, 1) * 0.10), 0.28);
		sig = (Saw.ar(freq, 0.65) + pulse + SinOsc.ar(freq * 0.5, 0, 0.12 * body.clip(0, 1))) * 0.55;
		sig = sig + (BPF.ar(WhiteNoise.ar(1), (freq * 7).clip(600, 10000), 0.3) * (air + breath) * 0.04);
		cutoff = (450 + (br * 8200)).clip(160, 14000);
		rq = (0.75 - (edge.clip(0, 1) * 0.25) - (ed * 0.20)).clip(0.15, 0.9);
		sig = RLPF.ar(sig, cutoff, rq);
		sig = tanh(sig * (1.0 + (ed * 2.5) + (edge.clip(0, 1) * 0.8)));
		env = EnvGen.kr(Env.asr(0.018, 1.0, releaseTime.clip(0.03, 2.0)), gate, doneAction: 2);
		pan = LFNoise1.kr(0.45).range(-0.35, 0.35) * (width + (breath * 0.15)).clip(0, 1) * panMotionAmount;

		eqLowDb = lowEQ.clip(0, 1).linlin(0, 1, -12, 12);
		eqMidDb = midEQ.clip(0, 1).linlin(0, 1, -10, 10);
		eqHighDb = highEQ.clip(0, 1).linlin(0, 1, -12, 12);
		sig = BLowShelf.ar(sig, 180, 1.0, eqLowDb);
		sig = BPeakEQ.ar(sig, 1000, 1.0, eqMidDb);
		sig = BHiShelf.ar(sig, 3600, 1.0, eqHighDb);
		Out.ar(out, Pan2.ar(sig * amp * masterAmp * env * 0.82, pan));
	}).add;

	"[at-render-profiles] loaded Probe/Pure/Piano/EP/Organ/Pad/Synth profiles; Strings are external-only and hidden from the built-in tone menu".postln;
};
)
