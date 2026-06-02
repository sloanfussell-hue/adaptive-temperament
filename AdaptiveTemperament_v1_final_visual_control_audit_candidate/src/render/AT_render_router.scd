(
// AT_render_router.scd
// Overrides the legacy spawnVoice with a profile-aware router. This does not touch
// the solver, mic, memory, gravity, or UI drawing layers.

var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
	"[at-render-router] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
	at = build[\at];
	cfg = build[\cfg];
	st = build[\state];
	api = build[\api];
	diag = build[\diag];
	ui = build[\ui];

	if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
	if(cfg[\render][\toneProfile].isNil) { cfg[\render][\toneProfile] = \organ; };
	if(cfg[\render][\adaptiveToneMode].isNil) { cfg[\render][\adaptiveToneMode] = \static; };
	if(cfg[\render][\adaptiveToneAmount].isNil) { cfg[\render][\adaptiveToneAmount] = 0.0; };
	if(cfg[\render][\toneBody].isNil) { cfg[\render][\toneBody] = 0.62; };
	if(cfg[\render][\toneBrightness].isNil) { cfg[\render][\toneBrightness] = 0.50; };
	if(cfg[\render][\toneAir].isNil) { cfg[\render][\toneAir] = 0.18; };
	if(cfg[\render][\toneEdge].isNil) { cfg[\render][\toneEdge] = 0.12; };
	if(cfg[\render][\toneWidth].isNil) { cfg[\render][\toneWidth] = 0.20; };
	if(cfg[\render][\toneLow].isNil) { cfg[\render][\toneLow] = 0.50; };
	if(cfg[\render][\toneMid].isNil) { cfg[\render][\toneMid] = 0.50; };
	if(cfg[\render][\toneHigh].isNil) { cfg[\render][\toneHigh] = 0.50; };

	api[\setToneProfile] = { |profile=\organ|
		var p, requested;
		requested = (profile ? \organ).asSymbol;
		if(requested == \strings) {
			"[at-strings] Strings is not a built-in selectable sound in this build. It is reserved for future external/premium/user-supplied strings, so the current tone profile was left unchanged.".warn;
			p = cfg[\render][\toneProfile] ? \organ;
		} {
			p = if(at[\validToneProfile].notNil) { at[\validToneProfile].(requested) } { requested };
			cfg[\render][\toneProfile] = p;
			st[\toneProfile] = p;
			if(diag[\log].notNil) { diag[\log].("tone profile set to " ++ p.asString ++ " (new notes only)"); };
		};
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneBody] = { |x=0.5|
		cfg[\render][\toneBody] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\body, cfg[\render][\toneBody]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneBrightness] = { |x=0.5|
		cfg[\render][\toneBrightness] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\brightness, cfg[\render][\toneBrightness]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneAir] = { |x=0.1|
		cfg[\render][\toneAir] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\air, cfg[\render][\toneAir]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneEdge] = { |x=0.1|
		cfg[\render][\toneEdge] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\edge, cfg[\render][\toneEdge]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneWidth] = { |x=0.2|
		cfg[\render][\toneWidth] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\width, cfg[\render][\toneWidth]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneLow] = { |x=0.5|
		cfg[\render][\toneLow] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\lowEQ, cfg[\render][\toneLow]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneMid] = { |x=0.5|
		cfg[\render][\toneMid] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\midEQ, cfg[\render][\toneMid]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneHigh] = { |x=0.5|
		cfg[\render][\toneHigh] = x.clip(0.0, 1.0);
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\highEQ, cfg[\render][\toneHigh]); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setToneEQ] = { |low=0.5, mid=0.5, high=0.5|
		api[\setToneLow].(low);
		api[\setToneMid].(mid);
		api[\setToneHigh].(high);
	};

	at[\toneReport] = {
		var profile, mode, snap;
		profile = cfg[\render][\toneProfile] ? \organ;
		mode = cfg[\render][\adaptiveToneMode] ? \static;
		snap = if(at[\refreshAdaptiveToneSnapshot].notNil) { at[\refreshAdaptiveToneSnapshot].() } { nil };
		"".postln;
		"[AT TONE REPORT]".postln;
		("profile=" ++ profile.asString
			++ " def=" ++ (if(at[\toneProfileDefName].notNil) { at[\toneProfileDefName].(profile) } { \legacy }).asString
			++ " adaptiveMode=" ++ mode.asString
			++ " adaptiveAmount=" ++ (cfg[\render][\adaptiveToneAmount] ? 0.0).round(0.001).asString).postln;
		("body=" ++ (cfg[\render][\toneBody] ? 0.0).round(0.001).asString
			++ " brightness=" ++ (cfg[\render][\toneBrightness] ? 0.0).round(0.001).asString
			++ " air=" ++ (cfg[\render][\toneAir] ? 0.0).round(0.001).asString
			++ " edge=" ++ (cfg[\render][\toneEdge] ? 0.0).round(0.001).asString
			++ " width=" ++ (cfg[\render][\toneWidth] ? 0.0).round(0.001).asString).postln;
		("EQ L=" ++ (cfg[\render][\toneLow] ? 0.5).round(0.001).asString
			++ " M=" ++ (cfg[\render][\toneMid] ? 0.5).round(0.001).asString
			++ " H=" ++ (cfg[\render][\toneHigh] ? 0.5).round(0.001).asString).postln;
		(
			profile: profile,
			adaptiveMode: mode,
			adaptiveAmount: cfg[\render][\adaptiveToneAmount] ? 0.0,
			body: cfg[\render][\toneBody] ? 0.0,
			brightness: cfg[\render][\toneBrightness] ? 0.0,
			air: cfg[\render][\toneAir] ? 0.0,
			edge: cfg[\render][\toneEdge] ? 0.0,
			width: cfg[\render][\toneWidth] ? 0.0,
			toneLow: cfg[\render][\toneLow] ? 0.5,
			toneMid: cfg[\render][\toneMid] ? 0.5,
			toneHigh: cfg[\render][\toneHigh] ? 0.5,
			adaptiveSnapshot: snap
		)
	};
	api[\toneReport] = { at[\toneReport].() };

	at[\spawnVoice] = { |midi, velocity|
		var pc, baseFreq, synth, defName, voiceAmp, profile, adaptiveMode, adaptiveIndex, adaptiveAmount;
		var epSlot, epReady, pianoSlot, pianoReady, synthArgs;
		pc = midi % 12;
		baseFreq = if(at[\perceptualCylinderFrequencyForMidi].notNil) { at[\perceptualCylinderFrequencyForMidi].(midi) } { at[\midiToFreq].(midi) };
		voiceAmp = ((velocity * 0.18) + 0.03).clip(0.03, 0.25);
		profile = if(at[\validToneProfile].notNil) { at[\validToneProfile].(cfg[\render][\toneProfile]) } { cfg[\render][\toneProfile] ? \organ };
		defName = if(at[\toneProfileDefName].notNil) { at[\toneProfileDefName].(profile) } { \atvoice_prod };
		epSlot = nil;
		epReady = false;
		pianoSlot = nil;
		pianoReady = false;

		// Piano is now a real-sample host. If the Slender/real samples are missing,
		// do NOT use the bad synthesized piano fallback; use the neutral pure tone
		// and print the download command. Acoustic piano cannot be faked cheaply.
		if(profile == \piano) {
			if(at[\pianoSlotForMidi].notNil) {
				pianoSlot = at[\pianoSlotForMidi].(midi);
				pianoReady = if(at[\pianoSlotReady].notNil) { at[\pianoSlotReady].(pianoSlot) } { false };
			};
			if(pianoReady) {
				defName = \atvoice_piano_sample;
			} {
				defName = \atvoice_pure;
				if((cfg[\render][\pianoMissingWarned] ? false) == false) {
					cfg[\render][\pianoMissingWarned] = true;
					"[at-piano] missing complete real piano keygroups; using neutral pure fallback, not fake piano synthesis.".warn;
					"[at-piano] Run Library.at(\\at)[\\api][\\downloadSlenderPianoSamples].(); then reboot.".postln;
					if(api[\pianoAssetReport].notNil) { api[\pianoAssetReport].(); };
				};
			};
		};

		// Professional strings are reserved for a future external/premium/user-supplied
		// string source. Do not substitute a fake built-in bowed/string-pad tone.
		if(profile == \strings) {
			defName = \atvoice_pure;
			if((cfg[\render][\stringsExternalWarned] ? false) == false) {
				cfg[\render][\stringsExternalWarned] = true;
				"[at-strings] professional strings are external/premium/user-supplied only in this build; using neutral pure fallback, not fake strings.".warn;
			};
		};

		// ElectricPiano is now a real sample/model host. If complete legal samples
		// are not present, do not synthesize a fake Rhodes; use the neutral pure
		// fallback and print a one-time asset warning.
		if(profile == \electricPiano) {
			if(at[\epianoSlotForMidi].notNil) {
				epSlot = at[\epianoSlotForMidi].(midi);
				epReady = if(at[\epianoSlotReady].notNil) { at[\epianoSlotReady].(epSlot) } { false };
			};
			if(epReady) {
				defName = \atvoice_electric_piano_sample;
			} {
				defName = \atvoice_pure;
				if((cfg[\render][\epianoMissingWarned] ? false) == false) {
					cfg[\render][\epianoMissingWarned] = true;
					"[at-epiano] missing complete legal sample keygroups; electricPiano is using neutral pure fallback, not fake Rhodes synthesis.".warn;
					if(api[\epianoAssetReport].notNil) { api[\epianoAssetReport].(); };
				};
			};
		};

		adaptiveMode = if(at[\validAdaptiveToneMode].notNil) { at[\validAdaptiveToneMode].(cfg[\render][\adaptiveToneMode]) } { \static };
		adaptiveIndex = if(at[\adaptiveToneModeIndex].notNil) { at[\adaptiveToneModeIndex].(adaptiveMode) } { 0 };
		adaptiveAmount = cfg[\render][\adaptiveToneAmount] ? 0.0;

		st[\lastVoiceSpawn] = (
			midi: midi,
			pc: pc,
			baseFreq: baseFreq,
			defName: defName,
			profile: profile,
			adaptiveMode: adaptiveMode,
			adaptiveAmount: adaptiveAmount,
			velocity: velocity,
			amp: voiceAmp,
			pianoSlotRoot: if(pianoSlot.notNil) { pianoSlot[\root] } { nil },
			pianoAssetReady: pianoReady,
			stringEngine: if(profile == \strings) { \externalPremiumSlot } { nil },
			epianoSlotRoot: if(epSlot.notNil) { epSlot[\root] } { nil },
			epianoSourceRoot: if(epSlot.notNil) { epSlot[\sourceRoot] ? epSlot[\root] } { nil },
			epianoEffectiveRoot: if(epSlot.notNil) { epSlot[\effectiveRoot] ? (epSlot[\sourceRoot] ? epSlot[\root]) } { nil },
			epianoRootDecision: if(epSlot.notNil) { epSlot[\layerRootDecision] ? (epSlot[\measuredRootDecision] ? \unmeasured) } { nil },
			epianoPlaybackRate: if(epSlot.notNil) { baseFreq / ((epSlot[\effectiveRootFreq] ? (epSlot[\sourceRootFreq] ? epSlot[\rootFreq])).max(20.0)) } { nil },
			epianoSourceStem: if(epSlot.notNil) { epSlot[\sourceStem] } { nil },
			epianoAssetReady: epReady,
			timestamp: Main.elapsedTime
		);

		if((cfg[\input][\postMidiEvents] ? true) == true) {
			("[at-audio] spawnVoice midi=" ++ midi.asString
				++ " pc=" ++ pc.asString
				++ " profile=" ++ profile.asString
				++ " adaptive=" ++ adaptiveMode.asString
				++ " def=" ++ defName.asString
				++ " freq=" ++ baseFreq.round(0.01).asString).postln;
		};

		synthArgs = [
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
			\releaseTime, cfg[\render][\releaseTime],
			\adaptiveMode, adaptiveIndex,
			\adaptiveAmount, adaptiveAmount,
			\body, cfg[\render][\toneBody] ? 0.62,
			\brightness, cfg[\render][\toneBrightness] ? 0.50,
			\air, cfg[\render][\toneAir] ? 0.18,
			\edge, cfg[\render][\toneEdge] ? 0.12,
			\width, cfg[\render][\toneWidth] ? 0.20,
			\lowEQ, cfg[\render][\toneLow] ? 0.50,
			\midEQ, cfg[\render][\toneMid] ? 0.50,
			\highEQ, cfg[\render][\toneHigh] ? 0.50
		];

		if(pianoReady) {
			synthArgs = synthArgs ++ [
				\softBuf, pianoSlot[\buffers][\soft].bufnum,
				\medBuf, pianoSlot[\buffers][\med].bufnum,
				\hardBuf, pianoSlot[\buffers][\hard].bufnum,
				\rootFreq, pianoSlot[\rootFreq],
				\strikeVel, velocity.clip(0.0, 1.0),
				\startFrame, cfg[\render][\pianoStartFrame] ? 1450
			];
		};

		if(epReady) {
			synthArgs = synthArgs ++ [
				\softBuf, epSlot[\buffers][\soft].bufnum,
				\medBuf, epSlot[\buffers][\med].bufnum,
				\hardBuf, epSlot[\buffers][\hard].bufnum,
				\rootFreq, epSlot[\effectiveRootFreq] ? (epSlot[\sourceRootFreq] ? epSlot[\rootFreq]),
				\strikeVel, velocity.clip(0.0, 1.0)
			];
		};

		synth = Synth(defName, synthArgs);

		st[\voices][midi] = synth;
		synth;
	};

	"[at-render-router] profile-aware voice router installed".postln;
};
)
