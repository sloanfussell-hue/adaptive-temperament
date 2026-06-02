(
// AT_api.scd — v67b final product controls + public performance API support
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
	// API setters
	// ------------------------------------------------------------

	// Defensive defaults for visual/performance controls.  Older bundles may not
	// have cfg[\perf] yet, but the visual layer must never crash while opening.
	if(cfg[\perf].isNil) {
		cfg[\perf] = (
			performanceProfile: \expressive,
			fieldResponseMacro: 0.55,
			memoryContinuityMacro: 0.58,
			externalInfluenceMacro: 0.48,
			uiSlowRefreshDt: 0.28
		);
	};


	// ------------------------------------------------------------
	// Performance-face wrappers: Power / Brain / macro controls
	// ------------------------------------------------------------
	if(st[\brainEnabled].isNil) { st[\brainEnabled] = true; };
	if(st[\powerEnabled].isNil) { st[\powerEnabled] = true; };
	if(st[\backingFieldEnabled].isNil) { st[\backingFieldEnabled] = cfg[\field][\enabled] ? true; };
	if(cfg[\mic][\trust].isNil) { cfg[\mic][\trust] = 0.70; };
	if(st[\macros].isNil) { st[\macros] = IdentityDictionary.new; };
	st[\macros][\motion] = st[\movement] ? 0.82;
	st[\macros][\carry] = if(cfg[\solver][\contextGaugeEnabled] ? true) { ((cfg[\solver][\contextGaugeStrength] ? 1.0) / 1.4).clip(0.0, 1.0) } { 0.0 };
	st[\macros][\memory] = st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.35);
	st[\macros][\gravity] = if(cfg[\gravity].notNil and: { cfg[\gravity][\enabled] ? false }) { cfg[\gravity][\strength] ? 0.18 } { 0.0 };
	st[\macros][\tension] = st[\tension] ? 0.55;

	at[\effectiveMasterAmp] = {
		if(st[\powerEnabled] == false) { 0.0 } { cfg[\render][\masterAmp] ? 1.0 }
	};

	api[\setPowerEnabled] = { |flag=true|
		st[\powerEnabled] = flag.asBoolean;
		if(at[\setActiveVoiceParam].notNil) {
			at[\setActiveVoiceParam].(\masterAmp, at[\effectiveMasterAmp].());
		};
		api[\refreshUISnapshot].();
	};

	api[\setBrainEnabled] = { |flag=true|
		var enabled;
		enabled = flag.asBoolean;
		st[\brainEnabled] = enabled;
		if(enabled) {
			cfg[\field][\enabled] = st[\backingFieldEnabled] ? true;
			if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\brainEnabled); };
			if(api[\resolveNow].notNil) { api[\resolveNow].(\brainEnabled); };
		} {
			st[\backingFieldEnabled] = cfg[\field][\enabled] ? true;
			cfg[\field][\enabled] = false;
			if(at[\resetToET].notNil) { at[\resetToET].(); };
			if(at[\pushBuses].notNil) { at[\pushBuses].(); };
		};
		api[\refreshUISnapshot].();
	};

	api[\setMicTrust] = { |x|
		var v;
		v = x.clip(0.0, 1.0);
		cfg[\mic][\trust] = v;
		cfg[\mic][\minConfidence] = (0.18 - (v * 0.14)).clip(0.02, 0.18);
		st[\lastMicKey] = nil;
		if(at[\clearMicEvidence].notNil) { at[\clearMicEvidence].(); };
		if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
		api[\refreshUISnapshot].();
	};

	api[\setMacro] = { |name, value|
		var n, v;
		n = name.asSymbol;
		v = value.clip(0.0, 1.0);
		if(st[\macros].isNil) { st[\macros] = IdentityDictionary.new; };
		st[\macros][n] = v;
		switch(n,
			\motion, { api[\setMovement].(v); },
			\carry, {
				api[\setContextGaugeEnabled].(v > 0.01);
				api[\setContextGaugeStrength].((0.15 + (v * 1.25)).clip(0.0, 1.5));
				api[\setContextGaugeMaxCents].((3.0 + (v * 27.0)).clip(0.0, 48.0));
			},
			\memory, { api[\setMemoryAmount].(v); },
			\gravity, {
				if(api[\setGravityEnabled].notNil) { api[\setGravityEnabled].(v > 0.01); };
				if(api[\setGravityStrength].notNil) { api[\setGravityStrength].(v); };
				if(api[\setGravityMaxPullCents].notNil) { api[\setGravityMaxPullCents].(2.0 + (v * 18.0)); };
			},
			\tension, { api[\setTension].(v); },
			\micAmount, { api[\setMicWeight].((v * 1.2).clip(0.0, 1.5)); },
			\micTrust, { api[\setMicTrust].(v); }
		);
		api[\refreshUISnapshot].();
	};

	api[\setFieldResponseMacro] = { |x|
		var v;
		v = x.clip(0.0, 1.0);
		cfg[\perf][\fieldResponseMacro] = v;
		// Macro meaning: core firmness / passive harmonic pull.  Keep bounded.
		if(cfg[\solver].notNil) { cfg[\solver][\passiveScale] = (0.08 + (v * 0.62)).clip(0.0, 1.0); };
		api[\resolveNow].(\fieldResponseMacroChange);
		api[\refreshUISnapshot].();
	};

	api[\setMemoryContinuityMacro] = { |x|
		var v;
		v = x.clip(0.0, 1.0);
		cfg[\perf][\memoryContinuityMacro] = v;
		api[\setMemoryAmount].(v);
	};

	api[\setExternalInfluenceMacro] = { |x|
		var v;
		v = x.clip(0.0, 1.0);
		cfg[\perf][\externalInfluenceMacro] = v;
		if(cfg[\mic].notNil) { cfg[\mic][\weight] = (0.02 + (v * 0.78)).clip(0.0, 1.5); };
		if(cfg[\solver].notNil) { cfg[\solver][\externalGaugeCarryStrength] = (v * 0.85).clip(0.0, 1.5); };
		st[\lastMicKey] = nil;
		if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
		api[\refreshUISnapshot].();
	};

	api[\applyPerformanceProfile] = { |profile=\expressive|
		var p, core, mem, mic, move, tens;
		p = profile.asSymbol;
		if((p != \transparent) and: { p != \vocal } and: { p != \ensemble } and: { p != \experimental }) { p = \expressive; };
		cfg[\perf][\performanceProfile] = p;
		case
		{ p == \transparent } { core = 0.38; mem = 0.25; mic = 0.25; move = 0.72; tens = 0.35; }
		{ p == \vocal } { core = 0.50; mem = 0.70; mic = 0.42; move = 0.58; tens = 0.45; }
		{ p == \ensemble } { core = 0.52; mem = 0.55; mic = 0.70; move = 0.62; tens = 0.48; }
		{ p == \experimental } { core = 0.72; mem = 0.25; mic = 0.62; move = 0.92; tens = 0.78; }
		{ true } { core = 0.55; mem = 0.58; mic = 0.48; move = 0.82; tens = 0.55; };
		api[\setFieldResponseMacro].(core);
		api[\setMemoryContinuityMacro].(mem);
		api[\setExternalInfluenceMacro].(mic);
		api[\setMovement].(move);
		api[\setTension].(tens);
		api[\refreshUISnapshot].();
	};

	api[\setContextGaugeResponse] = { |x| cfg[\solver][\contextGaugeResponse] = x.clip(0.05, 1.0); api[\refreshUISnapshot].(); };
	api[\setContextGaugeUpperHeldDamping] = { |x| cfg[\solver][\contextGaugeUpperHeldDamping] = x.clip(0.10, 1.0); api[\refreshUISnapshot].(); };
	api[\setContextGaugeReversalDamping] = { |x| cfg[\solver][\contextGaugeReversalDamping] = x.clip(0.10, 1.0); api[\refreshUISnapshot].(); };

	api[\setExternalGaugeCarryEnabled] = { |flag| cfg[\solver][\externalGaugeCarryEnabled] = flag.asBoolean; api[\refreshUISnapshot].(); };
	api[\setExternalGaugeCarryStrength] = { |x| cfg[\solver][\externalGaugeCarryStrength] = x.clip(0.0, 1.5); api[\refreshUISnapshot].(); };
	api[\setExternalGaugeCarryMaxCents] = { |x| cfg[\solver][\externalGaugeCarryMaxCents] = x.clip(0.0, 36.0); api[\refreshUISnapshot].(); };
	api[\setExternalGaugeCarryResponse] = { |x| cfg[\solver][\externalGaugeCarryResponse] = x.clip(0.05, 1.0); api[\refreshUISnapshot].(); };
	api[\setExternalGaugeCarryReversalDamping] = { |x| cfg[\solver][\externalGaugeCarryReversalDamping] = x.clip(0.10, 1.0); api[\refreshUISnapshot].(); };

	api[\setMicSourceRoleMode] = { |mode=\auto|
		var symbol;
		symbol = mode.asSymbol;
		if([\auto, \singer, \bass, \melody, \drone, \ensemble, \piano, \percussive, \unknown].includes(symbol).not) { symbol = \auto; };
		cfg[\mic][\sourceRoleMode] = symbol;
		api[\refreshUISnapshot].();
	};

	api[\clearExternalEvidence] = {
		st[\lastMicKey] = nil;
		if(at[\clearMicEvidence].notNil) { at[\clearMicEvidence].(); };
		api[\resolveNow].(\clearExternalEvidence);
		api[\refreshUISnapshot].();
	};

	api[\freezeField] = {
		st[\motionActive] = false;
		st[\fieldFrozen] = true;
		st[\lastFieldAction] = \uiFreeze;
		if(st[\nodePhase].notNil) { st[\targetPhase] = st[\nodePhase].copy; };
		api[\refreshUISnapshot].();
	};

	api[\reconnectMIDI] = {
		if(at[\installMIDI].notNil) { at[\installMIDI].(); };
		api[\refreshUISnapshot].();
	};

	api[\setTension] = { |x|
		// v65: Tension is an expressive timbre/strain control. It updates
		// the render tension bus but intentionally does not resolve/retune
		// the harmonic field.
		st[\tension] = x.clip(0.0, 1.0);
		cfg[\render][\tension] = st[\tension];
		if(at[\pushBuses].notNil) { at[\pushBuses].(); };
		api[\refreshUISnapshot].();
	};


	// ------------------------------------------------------------
	// v67b final public controls: adaptive gravity follow + bounded spectrum accordion
	// ------------------------------------------------------------
	if(cfg[\finalControls].isNil) { cfg[\finalControls] = IdentityDictionary.new; };
	if(cfg[\finalControls][\earGravityFollowMode].isNil) { cfg[\finalControls][\earGravityFollowMode] = \off; };
	if(cfg[\finalControls][\earGravityFollowStrength].isNil) { cfg[\finalControls][\earGravityFollowStrength] = 1.0; };
	if(cfg[\finalControls][\spectrumAccordionAmount].isNil) { cfg[\finalControls][\spectrumAccordionAmount] = 0.0; };
	if(cfg[\finalControls][\spectrumAccordionProfile].isNil) { cfg[\finalControls][\spectrumAccordionProfile] = \harmonic; };
	cfg[\finalControls][\finalDemoUsesPublicControlsOnly] = true;
	cfg[\finalControls][\finalDemoExternalException] = \realSpeakerToMic;
	cfg[\finalControls][\finalDemoNoHiddenExternalInjection] = true;

	api[\finalProductControlReport] = { |post=true|
		var rep;
		rep = (
			version: \v67o_finalInstrumentDemo,
			gravityFollowMode: cfg[\finalControls][\earGravityFollowMode] ? \off,
			gravityFollowStrength: cfg[\finalControls][\earGravityFollowStrength] ? 1.0,
			spectrumAccordionAmount: cfg[\finalControls][\spectrumAccordionAmount] ? 0.0,
			spectrumAccordionProfile: cfg[\finalControls][\spectrumAccordionProfile] ? \harmonic,
			publicControlsOnly: true,
			externalStimulusMode: \realSpeakerToMic,
			pitchAuthorityAdded: false
		);
		if(post == true) {
			("[AT FINAL PRODUCT CONTROLS] gravityFollow=" ++ rep[\gravityFollowMode].asString
				++ " spectrumAccordion=" ++ (rep[\spectrumAccordionAmount] ? 0.0).round(0.001).asString
				++ " profile=" ++ rep[\spectrumAccordionProfile].asString
				++ " externalStimulus=realSpeakerToMic"
				++ " publicControlsOnly=true"
				++ " pitchAuthorityAdded=false").postln;
		};
		rep;
	};

	api[\setGravityFollowMode] = { |mode=\off, strength=1.0|
		var m;
		m = (mode ? \off).asSymbol;
		if([\off, \fixed, \memory, \ear].includes(m).not) { m = \off; };
		cfg[\finalControls][\earGravityFollowMode] = m;
		cfg[\finalControls][\earGravityFollowStrength] = strength.asFloat.clip(0.0, 1.0);
		api[\refreshUISnapshot].();
		("[AT GRAVITY FOLLOW CONTROL] mode=" ++ m.asString
			++ " strength=" ++ (cfg[\finalControls][\earGravityFollowStrength] ? 1.0).round(0.001).asString
			++ " publicControl=true").postln;
		m;
	};

		api[\applyGravityFollow] = { |reason=\manual, post=true|
		var mode, src, pc, cents, memPc, memPhase, rep, ok, scene, rawSources, usedSources, centerPc, centerCents;
		var roles, best, etLike, voiceCount, abnormalCount, boundedAuthority, singleStableOk, multiSceneOk, abnormalSceneOk, trustedEarCenter, trustReason;
		mode = cfg[\finalControls][\earGravityFollowMode] ? \off;
		ok = false;
		pc = nil;
		cents = 0.0;
		trustReason = \none;
		case
		{ mode == \ear } {
			// Ear-follow gravity should be adaptive, but not gullible.
			// It may follow a stable single external reference (A432), or a coherent
			// multi-source musical scene. It must not chase sparse physical mic artifacts
			// such as one overtone plus one unstable partial.
			scene = st[\externalCoherenceSceneReport];
			rawSources = if(scene.isNil) { 0 } { scene[\rawSources] ? 0 };
			usedSources = if(scene.isNil) { 0 } { scene[\usedSources] ? 0 };
			centerPc = if(scene.isNil) { nil } { scene[\centerPc] };
			roles = if(scene.isNil) { Array.new } { scene[\roles] ? Array.new };
			best = if(scene.isNil) { \none } { scene[\best] ? \none };
			etLike = if(scene.isNil) { false } { scene[\etLike] ? false };
			voiceCount = if(scene.isNil) { 0 } { scene[\voiceCount] ? 0 };
			abnormalCount = if(scene.isNil) { 0 } { scene[\abnormal] ? 0 };
			boundedAuthority = if(scene.isNil) { 0.0 } { scene[\boundedAuthority] ? 0.0 };
			singleStableOk = (rawSources == 1) and: { usedSources == 1 } and: { roles.any { |r| [\stableExternalPitch, \stableETLikeExternalContext].includes(r[\role] ? \none) } };
			// Trust coherent multi-source scenes, including voice-bearing scenes that are
			// slightly lower authority because the singer is intentionally imperfect.
			multiSceneOk = (usedSources >= 3) and: {
				((boundedAuthority >= 0.12) and: {
					etLike or: { best == \boundedCoherence or: { best == \pcLocalExternalContext } }
				}) or: {
					(voiceCount > 0) and: { boundedAuthority >= 0.10 } and: { best == \boundedCoherence or: { best == \pcLocalExternalContext } }
				}
			};
			abnormalSceneOk = (abnormalCount > 0) and: { usedSources >= 1 } and: { boundedAuthority >= 0.07 };
			trustedEarCenter = centerPc.notNil and: { singleStableOk or: { multiSceneOk or: { abnormalSceneOk } } };
			if(trustedEarCenter) {
				pc = centerPc.asInteger.clip(0, 11);
				centerCents = scene[\meanExternalCents] ? 0.0;
				cents = centerCents.asFloat.clip(-100.0, 100.0);
				ok = true;
				trustReason = if(singleStableOk) { \singleStableExternal } {
					if(abnormalSceneOk) { \abnormalSceneCenter } {
						if(voiceCount > 0) { \voiceAwareCoherentExternalScene } { \coherentExternalScene }
					}
				};
			} {
				// Do not fall back to the strongest partial. Holding the previous gravity
				// home is safer and more musical than following an untrusted mic fragment.
				ok = false;
				trustReason = \untrustedExternalSceneHeld;
			};
		}
		{ mode == \memory } {
			memPc = st[\worldRootPc] ? st[\worldBassPc] ? st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? 0);
			pc = memPc.asInteger.clip(0, 11);
			memPhase = if(st[\memoryPhase].notNil) { st[\memoryPhase][pc] } { nil };
			cents = if(memPhase.notNil) { (at[\wrapSigned].(memPhase - (st[\etPhase][pc] ? (pc / 12.0))) * 1200.0).clip(-100.0, 100.0) } { 0.0 };
			ok = true;
		}
		{ mode == \fixed } {
			pc = st[\gravityHomePc] ? (cfg[\gravity][\homePc] ? 0);
			cents = st[\gravityHomeCents] ? (cfg[\gravity][\homeCents] ? 0.0);
			ok = true;
		}
		{ true } { ok = false; };
		if(ok) { api[\setGravityHome].(pc, cents); };
		rep = (
			version: \v67o_finalInstrumentDemo,
			mode: mode,
			applied: ok,
			homePc: pc,
			homeName: if(pc.isNil) { \none } { (pitchClassNames[pc] ? pc.asString).asSymbol },
			homeCents: cents.round(0.01),
			reason: reason,
			trustReason: trustReason,
			pitchAuthorityAdded: false
		);
		if(post == true) {
			("[AT GRAVITY FOLLOW] mode=" ++ mode.asString
				++ " applied=" ++ ok.asString
				++ " home=" ++ rep[\homeName].asString
				++ " cents=" ++ cents.round(0.01).asString
				++ " reason=" ++ reason.asString
				++ " trust=" ++ trustReason.asString
				++ " pitchAuthorityAdded=false").postln;
		};
		rep;
	};

	api[\setSpectrumAccordionAmount] = { |x=0.0, profile=\bellLike|
		var amt, prof, midis, rep;
		amt = (x ? 0.0).asFloat.clip(0.0, 1.0);
		prof = (profile ? \bellLike).asSymbol;
		cfg[\finalControls][\spectrumAccordionAmount] = amt;
		cfg[\finalControls][\spectrumAccordionProfile] = prof;
		if(cfg[\perceptualCylinder].notNil) {
			cfg[\perceptualCylinder][\enabled] = true;
			cfg[\perceptualCylinder][\amount] = amt;
			cfg[\perceptualCylinder][\accordionAuthorityEnabled] = amt > 0.0001;
			cfg[\perceptualCylinder][\accordionRenderHookEnabled] = amt > 0.0001;
			cfg[\perceptualCylinder][\accordionProtectActive] = false;
			cfg[\perceptualCylinder][\accordionProtectExternal] = true;
			cfg[\perceptualCylinder][\accordionAuthorityLimitCents] = (2.0 + (amt * 10.0)).clip(0.0, 14.0);
		};
		if(cfg[\perceptualSpectrum].notNil) {
			cfg[\perceptualSpectrum][\enabled] = true;
			cfg[\perceptualSpectrum][\amount] = (amt * 0.35).clip(0.0, 0.35);
			if(at[\perceptualSpectrumProfiles].notNil and: { at[\perceptualSpectrumProfiles][prof].notNil }) { cfg[\perceptualSpectrum][\defaultProfile] = prof; };
		};
		midis = if(st[\activeNotes].notNil) { st[\activeNotes].keys.asArray } { Array.new };
		if(amt <= 0.0001) {
			if(api[\clearPerceptualCylinder].notNil) { api[\clearPerceptualCylinder].(); };
			st[\perceptualCylinderAuthorityLastReport] = (maxAbsAppliedCents: 0.0, amount: 0.0, profile: prof, pitchAuthorityAdded: false);
		} {
			if(api[\applyPerceptualCylinderAccordionAuthority].notNil and: { midis.notEmpty }) {
				api[\applyPerceptualCylinderAccordionAuthority].(midis, prof, amt);
			};
		};
		rep = api[\spectrumAccordionReport].(false);
		("[AT SPECTRUM ACCORDION CONTROL] amount=" ++ amt.round(0.001).asString
			++ " profile=" ++ prof.asString
			++ " bounded=true explicit=true renderHook=" ++ ((cfg[\perceptualCylinder][\accordionRenderHookEnabled] ? false).asString)
			++ " maxApplied=" ++ (rep[\maxAbsAppliedCents] ? 0.0).asString ++ "c").postln;
		api[\refreshUISnapshot].();
		rep;
	};

	api[\spectrumAccordionReport] = { |post=true|
		var ccfg, rep, maxApplied;
		ccfg = cfg[\perceptualCylinder] ? ();
		maxApplied = if(st[\perceptualCylinderAuthorityLastReport].notNil) { st[\perceptualCylinderAuthorityLastReport][\maxAbsAppliedCents] ? 0.0 } { 0.0 };
		rep = (
			version: \v67o_finalInstrumentDemo,
			amount: cfg[\finalControls][\spectrumAccordionAmount] ? 0.0,
			profile: cfg[\finalControls][\spectrumAccordionProfile] ? \harmonic,
			enabled: ccfg[\accordionAuthorityEnabled] ? false,
			renderHookEnabled: ccfg[\accordionRenderHookEnabled] ? false,
			bounded: true,
			maxAbsAppliedCents: maxApplied,
			pitchAuthorityAdded: false
		);
		if(post == true) {
			("[AT SPECTRUM ACCORDION REPORT] amount=" ++ (rep[\amount] ? 0.0).round(0.001).asString
				++ " profile=" ++ rep[\profile].asString
				++ " enabled=" ++ (rep[\enabled] ? false).asString
				++ " renderHook=" ++ (rep[\renderHookEnabled] ? false).asString
				++ " bounded=true maxApplied=" ++ (rep[\maxAbsAppliedCents] ? 0.0).asString ++ "c"
				++ " pitchAuthorityAdded=false").postln;
		};
		rep;
	};
	api[\setMovement] = { |x|
		st[\movement] = x.clip(0.0, 1.0);
		if(at[\nudgeMotionAfterMovementChange].notNil) { at[\nudgeMotionAfterMovementChange].(\setMovement); };
		api[\refreshUISnapshot].();
	};

	api[\setMemoryAmount] = { |x|
		st[\memoryAmount] = x.clip(0.0, 1.0);
		cfg[\memory][\amount] = st[\memoryAmount];
		api[\resolveNow].(\memoryAmountChange);
		api[\refreshUISnapshot].();
	};

	api[\setMemoryLearnRate] = { |x|
		cfg[\memory][\learningRate] = x.clip(0.0, 0.45);
		api[\refreshUISnapshot].();
	};

	api[\clearTonalMemory] = {
		if(at[\clearTonalMemory].notNil) { at[\clearTonalMemory].(); };
		api[\refreshUISnapshot].();
	};

	api[\setPassiveScale] = { |x|
		cfg[\solver][\passiveScale] = x.clip(0.0, 1.0);
		api[\resolveNow].(\passiveScaleChange);
		api[\refreshUISnapshot].();
	};

	api[\setMaxStep] = { |x|
		cfg[\solver][\maxStep] = x.clip(0.0005, 0.03);
		api[\resolveNow].(\maxStepChange);
		api[\refreshUISnapshot].();
	};

	api[\setContextGaugeEnabled] = { |flag|
		cfg[\solver][\contextGaugeEnabled] = flag.asBoolean;
		api[\refreshUISnapshot].();
	};

	api[\setContextGaugeStrength] = { |x|
		cfg[\solver][\contextGaugeStrength] = x.clip(0.0, 1.5);
		api[\refreshUISnapshot].();
	};

	api[\setContextGaugeMaxCents] = { |x|
		cfg[\solver][\contextGaugeMaxCents] = x.clip(0.0, 48.0);
		api[\refreshUISnapshot].();
	};

	api[\setContextGaugeWindow] = { |x|
		cfg[\solver][\contextGaugeRecentWindow] = x.clip(0.02, 1.5);
		api[\refreshUISnapshot].();
	};

	api[\setShowIntervalLinks] = { |flag|
		cfg[\ui][\showIntervalLinks] = flag.asBoolean;
		api[\refreshUISnapshot].();
	};

	api[\setFrozenGhostAlpha] = { |x|
		cfg[\ui][\frozenGhostAlpha] = x.clip(0.0, 1.0);
		api[\refreshUISnapshot].();
	};

	api[\setUIFps] = { |x|
		cfg[\ui][\fps] = x.clip(4.0, 30.0);
		api[\refreshUISnapshot].();
	};

	api[\setFieldContinuousResolveEnabled] = { |flag|
		cfg[\field][\continuousResolveEnabled] = flag.asBoolean;
		api[\refreshUISnapshot].();
	};

	api[\setFieldContinuousResolveInterval] = { |x|
		cfg[\field][\continuousResolveInterval] = x.clip(0.05, 2.0);
		api[\refreshUISnapshot].();
	};

	api[\setWorldScoringEnabled] = { |flag|
		cfg[\world][\enabled] = flag.asBoolean;
		st[\worldEnabled] = cfg[\world][\enabled];
		api[\resolveNow].(\worldScoringChanged);
		api[\refreshUISnapshot].();
	};

	api[\setWorldScoringBlend] = { |x|
		cfg[\world][\targetBlend] = x.clip(0.0, 0.8);
		api[\resolveNow].(\worldBlendChanged);
		api[\refreshUISnapshot].();
	};


	api[\setMicEnabled] = { |flag|
		cfg[\mic][\enabled] = flag.asBoolean;

		if(cfg[\mic][\enabled]) {
			if(st[\micSynth].isNil) {
				at[\spawnMicSynth].();
			} {
				at[\rebuildMicSynth].();
			};
			st[\lastMicKey] = nil;
			st[\micSelfIgnoreFramesRemaining] = 0;
			at[\clearMicEvidence].();
			at[\refreshMicObservation].();
			api[\resolveNow].(\micEnabled);
			api[\refreshUISnapshot].();
		} {
			at[\freeMicSynth].();
			st[\lastMicKey] = nil;
			st[\micDiagKey] = nil;
			st[\micSelfIgnoreFramesRemaining] = 0;
			at[\clearMicEvidence].();
			at[\refreshMicObservation].();
			api[\resolveNow].(\micDisabled);
			api[\refreshUISnapshot].();
		};
	};

	api[\setMicMode] = { |mode|
		var symbol;
		symbol = mode.asSymbol;
		if(symbol != \polyPc) {
			symbol = \mono;
		};
		cfg[\mic][\mode] = symbol;
		st[\lastMicKey] = nil;
		st[\micDiagKey] = nil;
		at[\clearMicEvidence].();
		at[\rebuildMicSynth].();
		at[\refreshMicObservation].();
		diag[\log].("mic mode set to " ++ symbol.asString);
		api[\resolveNow].(\micModeChange);
		api[\refreshUISnapshot].();
	};

	api[\setMicInputMode] = { |mode|
		var symbol;
		symbol = mode.asSymbol;
		if((symbol != \ch0) and: { symbol != \ch1 }) {
			symbol = \sum01;
		};
		cfg[\mic][\inputMode] = symbol;
		st[\micInputMode] = symbol;
		st[\lastMicKey] = nil;
		st[\micDiagKey] = nil;
		at[\clearMicEvidence].();
		at[\rebuildMicSynth].();
		at[\refreshMicObservation].();
		diag[\log].("mic input mode set to " ++ symbol.asString);
		api[\refreshUISnapshot].();
	};

	api[\setMicInfluencePolicy] = { |policy|
		var symbol;
		symbol = policy.asSymbol;
		if((symbol != \duetSafe) and: { symbol != \fullBlend } and: { symbol != \debugRaw } and: { symbol != \externalFollow }) {
			symbol = \externalOnly;
		};
		cfg[\mic][\influencePolicy] = symbol;
		st[\lastMicKey] = nil;
		at[\clearMicEvidence].();
		at[\refreshMicObservation].();
		diag[\log].("mic influence policy set to " ++ symbol.asString);
		api[\resolveNow].(\micPolicyChange);
		api[\refreshUISnapshot].();
	};

	api[\setMicGain] = { |x|
		cfg[\mic][\gain] = x.clip(0.0, 32.0);
		if(st[\micSynth].notNil) {
			st[\micSynth].set(\micGain, cfg[\mic][\gain]);
		};
	};

	api[\setMicPitchAmpThreshold] = { |x|
		cfg[\mic][\pitchAmpThreshold] = x.clip(0.00001, 0.1);
		if(st[\micSynth].notNil) {
			st[\micSynth].set(\pitchAmpThreshold, cfg[\mic][\pitchAmpThreshold]);
		};
	};

	api[\setMicPitchDetectGain] = { |x|
		cfg[\mic][\pitchDetectGain] = x.clip(1.0, 64.0);
		if(st[\micSynth].notNil) {
			st[\micSynth].set(\pitchDetectGain, cfg[\mic][\pitchDetectGain]);
		};
	};

	api[\setMicZeroCrossFallback] = { |flag|
		cfg[\mic][\zeroCrossFallback] = if(flag == false) { false } { true };
		if(st[\micSynth].notNil) {
			st[\micSynth].set(\zeroCrossFallback, if(cfg[\mic][\zeroCrossFallback]) { 1 } { 0 });
		};
	};

	api[\setMicZeroCrossAmpThreshold] = { |x|
		cfg[\mic][\zeroCrossAmpThreshold] = x.clip(0.00001, 0.1);
		if(st[\micSynth].notNil) {
			st[\micSynth].set(\zeroCrossAmpThreshold, cfg[\mic][\zeroCrossAmpThreshold]);
		};
	};

	api[\setMicDuetSamePcSelfCents] = { |x|
		cfg[\mic][\duetSamePcSelfCents] = x.clip(0.0, 24.0);
		api[\refreshUISnapshot].();
	};

	api[\setMicDuetSamePcTuningScale] = { |x|
		cfg[\mic][\duetSamePcTuningScale] = x.clip(0.0, 2.0);
		api[\refreshUISnapshot].();
	};

	api[\setMicWeight] = { |x|
		cfg[\mic][\weight] = x.clip(0.0, 1.5);
		st[\lastMicKey] = nil;
		at[\refreshMicObservation].();
		api[\refreshUISnapshot].();
	};

	api[\setMicThreshold] = { |x|
		cfg[\mic][\ampThreshold] = x.clip(0.0, 0.2);
		st[\lastMicKey] = nil;
		at[\refreshMicObservation].();
		api[\refreshUISnapshot].();
	};

	api[\setRenderMode] = { |mode|
		var symbol;
		symbol = mode.asSymbol;
		if(symbol != \reference) {
			symbol = \production;
		};
		st[\renderMode] = symbol;
		cfg[\render][\mode] = symbol;
		diag[\log].("render mode set to " ++ symbol.asString ++ " (applies to new voices)");
		api[\refreshUISnapshot].();
	};

	api[\setPitchLag] = { |x|
		cfg[\render][\pitchLag] = x.clip(0.001, 0.2);
		at[\setActiveVoiceParam].(\pitchLag, cfg[\render][\pitchLag]);
		api[\refreshUISnapshot].();
	};

	api[\setBrightnessAmount] = { |x|
		cfg[\render][\brightnessAmount] = x.clip(0.05, 3.0);
		at[\setActiveVoiceParam].(\brightnessAmount, cfg[\render][\brightnessAmount]);
		api[\refreshUISnapshot].();
	};

	api[\setRoughnessAmount] = { |x|
		cfg[\render][\roughnessAmount] = x.clip(0.0, 3.0);
		at[\setActiveVoiceParam].(\roughnessAmount, cfg[\render][\roughnessAmount]);
		api[\refreshUISnapshot].();
	};

	api[\setPanMotionAmount] = { |x|
		cfg[\render][\panMotionAmount] = x.clip(0.0, 2.0);
		at[\setActiveVoiceParam].(\panMotionAmount, cfg[\render][\panMotionAmount]);
		api[\refreshUISnapshot].();
	};

	api[\setMasterAmp] = { |x|
		cfg[\render][\masterAmp] = x.clip(0.0, 2.0);
		at[\setActiveVoiceParam].(\masterAmp, if(st[\powerEnabled] == false) { 0.0 } { cfg[\render][\masterAmp] });
		api[\refreshUISnapshot].();
	};

	api[\setReleaseTime] = { |x|
		cfg[\render][\releaseTime] = x.clip(0.01, 2.0);
		at[\setActiveVoiceParam].(\releaseTime, cfg[\render][\releaseTime]);
		api[\refreshUISnapshot].();
	};

	api[\hardReset] = {
		api[\setMicEnabled].(false);
		st[\sustainDown] = false;
		at[\allVoicesOff].();
		st[\activeNotes].clear;
			st[\singletonReentryPending] = nil;
			st[\lastOnsetInfo] = nil;
			st[\lastGaugeCarry] = nil;
			st[\diagnosticRootByActiveSet] = Dictionary.new;
			st[\diagnosticRootLastPc] = nil;
			st[\restFreezeMonitor] = nil;
			st[\lastRestFreezeReport] = nil;
			st[\lastReentryReport] = nil;
			st[\lastMultiReentryReport] = nil;
			st[\lastSurvivorReport] = nil;
			st[\lastRestFreezePhase] = nil;
			st[\lastReentryAt] = nil;
			st[\phraseCurrentWorld] = nil;
			st[\phrasePreviousDistinctWorld] = nil;
			st[\phraseHomeWorld] = nil;
			st[\phraseHomeConfidence] = 0.0;
			st[\phrasePendingDominant] = nil;
			st[\phrasePendingDiminished] = nil;
			st[\phraseLastResolution] = nil;
			st[\phraseFunction] = nil;
			st[\phraseFunctionConfidence] = 0.0;
			st[\phraseTags] = Array.new;
			st[\phraseLastAt] = nil;
			st[\phraseObservedSignature] = nil;
			st[\phraseObservedSince] = nil;
			st[\phraseObservedAge] = 0.0;
			st[\phraseObservedStable] = false;
		st[\frozenValid] = false;
		st[\lastMicKey] = nil;
		st[\micDiagKey] = nil;
		at[\clearMicEvidence].();
		at[\clearMicBuses].();
		at[\resetToET].();
		at[\pushBuses].();
		diag[\log].("hard reset");
		api[\refreshUISnapshot].();
	};

	api[\reset] = {
		at[\allVoicesOff].();
		st[\activeNotes].clear;
			st[\singletonReentryPending] = nil;
			st[\lastOnsetInfo] = nil;
			st[\lastGaugeCarry] = nil;
			st[\diagnosticRootByActiveSet] = Dictionary.new;
			st[\diagnosticRootLastPc] = nil;
			st[\restFreezeMonitor] = nil;
			st[\lastRestFreezeReport] = nil;
			st[\lastReentryReport] = nil;
			st[\lastMultiReentryReport] = nil;
			st[\lastSurvivorReport] = nil;
			st[\lastRestFreezePhase] = nil;
			st[\lastReentryAt] = nil;
			st[\phraseCurrentWorld] = nil;
			st[\phrasePreviousDistinctWorld] = nil;
			st[\phraseHomeWorld] = nil;
			st[\phraseHomeConfidence] = 0.0;
			st[\phrasePendingDominant] = nil;
			st[\phrasePendingDiminished] = nil;
			st[\phraseLastResolution] = nil;
			st[\phraseFunction] = nil;
			st[\phraseFunctionConfidence] = 0.0;
			st[\phraseTags] = Array.new;
			st[\phraseLastAt] = nil;
			st[\phraseObservedSignature] = nil;
			st[\phraseObservedSince] = nil;
			st[\phraseObservedAge] = 0.0;
			st[\phraseObservedStable] = false;
		st[\frozenValid] = false;
		st[\lastMicKey] = nil;
		at[\clearMicEvidence].();
		at[\clearMicBuses].();
		at[\resetToET].();
		at[\pushBuses].();
		diag[\log].("reset");
		api[\refreshUISnapshot].();
	};

	api[\dumpState] = {
		diag[\dumpState].();
	};

	// ------------------------------------------------------------
	// UI snapshot / product state reports
	// ------------------------------------------------------------

	at[\buildUISnapshot] = {
		var activePcs, micRawCandidates, micCandidates, externalSources, maxDevCents, strongestRawCandidate, strongestCandidate, strongestExternal, coreAuthority;
		activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
		micRawCandidates = (st[\micRawCandidates] ? Array.new).collect { |src| src.copy };
		micCandidates = (st[\micCandidates] ? Array.new).collect { |src| src.copy };
		externalSources = (st[\externalSources] ? Array.new).collect { |src| src.copy };
		maxDevCents = (at[\devArray].().collect { |x| (x * 1200.0).abs }.maxItem) ? 0.0;
		strongestRawCandidate = at[\strongestExternalSource].(micRawCandidates);
		strongestCandidate = at[\strongestExternalSource].(micCandidates);
		strongestExternal = at[\strongestExternalSource].(externalSources);
		coreAuthority = if(at[\coreAuthoritySnapshot].notNil) { at[\coreAuthoritySnapshot].() } { (inhibition: 0.0, freedom: 1.0) };

		(
			state: st[\stateLabel],
			brainEnabled: st[\brainEnabled] ? true,
			powerEnabled: st[\powerEnabled] ? true,
			mode: if(st[\brainEnabled] == false) { \equalTemperament } { \adaptive },
			macros: if(st[\macros].isNil) { IdentityDictionary.new } { st[\macros].copy },
			activeNotes: st[\activeNotes].keys.asArray.sort,
			activePcs: activePcs,
			nodePhase: st[\nodePhase].copy,
			targetPhase: (st[\targetPhase] ? st[\nodePhase]).copy,
			targetValid: st[\targetValid],
			motionActive: st[\motionActive],
			targetReason: st[\targetReason],
			frozenPhase: st[\frozenPhase].copy,
			etPhase: st[\etPhase].copy,
			etDeviationCents: at[\devArray].().collect { |x| x * 1200.0 },
			maxDevCents: maxDevCents,
			soleAnchorPc: st[\soleAnchorPc],
			soleAnchorPhase: st[\soleAnchorPhase],
			frozenValid: st[\frozenValid],
			frozenFromEvidence: st[\frozenFromEvidence],
			musicalRestValid: st[\musicalRestValid],
			fieldHadSolvedEvidence: st[\fieldHadSolvedEvidence],
			maxLastDelta: st[\lastDelta].collect { |x| x.abs }.maxItem,
			maxNodeMotion: st[\nodeMotion].collect { |x| x.abs }.maxItem,
			nodeAlignment: st[\nodeAlignment].copy,
			nodeStability: st[\nodeStability].copy,
			tension: st[\tension],
			movement: st[\movement],
			memoryAmount: st[\memoryAmount],
			memoryValid: st[\memoryValid],
			memoryConfidence: st[\memoryConfidence],
			memoryPhase: if(st[\memoryPhase].isNil) { st[\etPhase].copy } { st[\memoryPhase].copy },
			memoryLastDistanceCents: if(st[\memoryLastDistance].isNil) { nil } { st[\memoryLastDistance] * 1200.0 },
			memoryLastInfluence: st[\memoryLastInfluence],
			memoryLastLearnRate: st[\memoryLastLearnRate],
			memoryLastReason: st[\memoryLastReason],
			fieldEnabled: cfg[\field][\enabled],
			fieldContinuousResolveEnabled: cfg[\field][\continuousResolveEnabled],
				fieldResolveOnEvidenceChange: cfg[\field][\resolveOnEvidenceChange],
				fieldFreezeOnNoEvidence: cfg[\field][\freezeOnNoEvidence],
				fieldFrozen: st[\fieldFrozen],
				lastFieldTickAt: st[\lastFieldTickAt],
				lastFieldHadEvidence: st[\lastFieldHadEvidence],
				lastFieldAction: st[\lastFieldAction],
				micReleaseHoldActive: st[\micReleaseHoldActive] ? false,
				micReleaseHoldReason: st[\micReleaseHoldReason],
				micReleaseHoldActivePcs: st[\micReleaseHoldActivePcs] ? Array.new,
				micReleaseHoldSourceCount: (st[\micReleaseHoldSources] ? Array.new).size,
				micReleaseHoldReleasedBy: st[\micReleaseHoldReleasedBy],
				fieldTickCount: st[\fieldTickCount],
				targetUpdatedByTick: st[\targetUpdatedByTick],
			worldEnabled: cfg[\world][\enabled],
			worldLabel: st[\worldLabel],
			worldScore: st[\worldScore],
			worldChosenAnchorPc: st[\worldChosenAnchorPc],
			worldRootPc: st[\worldRootPc],
			worldBassPc: st[\worldBassPc],
			worldBassMidi: st[\worldBassMidi],
			worldInversion: st[\worldInversion],
			worldFamily: st[\worldFamily],
			worldFunction: st[\worldFunction],
			worldAmbiguityIndex: st[\worldAmbiguityIndex],
			worldScoreGap: st[\worldScoreGap],
			worldLastBlend: st[\worldLastBlend],
			worldLastReason: st[\worldLastReason],
			worldTopWorlds: st[\worldTopWorlds],
			worldFamilyTopWorlds: st[\worldFamilyTopWorlds],
			phraseEnabled: cfg[\phrase][\enabled],
			phraseFunction: st[\phraseFunction],
			phraseFunctionConfidence: st[\phraseFunctionConfidence],
			phraseTags: st[\phraseTags],
			phraseHomeWorld: st[\phraseHomeWorld],
			phraseHomeConfidence: st[\phraseHomeConfidence],
			phrasePendingDominant: st[\phrasePendingDominant],
			phrasePendingDiminished: st[\phrasePendingDiminished],
			phraseLastResolution: st[\phraseLastResolution],
			phraseCurrentWorld: st[\phraseCurrentWorld],
			phrasePreviousDistinctWorld: st[\phrasePreviousDistinctWorld],
			phraseObservedSignature: st[\phraseObservedSignature],
			phraseObservedAge: st[\phraseObservedAge],
			phraseObservedStable: st[\phraseObservedStable],
			fieldContinuousResolveInterval: cfg[\field][\continuousResolveInterval],
			evidenceDirty: st[\evidenceDirty],
			evidenceDirtyReason: st[\evidenceDirtyReason],
			lastFieldResolveAt: st[\lastFieldResolveAt],
			passiveScale: cfg[\solver][\passiveScale],
			maxStep: cfg[\solver][\maxStep],
			contextGaugeEnabled: cfg[\solver][\contextGaugeEnabled],
			contextGaugeStrength: cfg[\solver][\contextGaugeStrength],
			contextGaugeMaxCents: cfg[\solver][\contextGaugeMaxCents],
			contextGaugeRecentWindow: cfg[\solver][\contextGaugeRecentWindow],
			coreAuthority: coreAuthority,
			coreInhibition: coreAuthority[\inhibition] ? 0.0,
			nakedCoreFreedom: coreAuthority[\freedom] ? 1.0,
			gravityEnabled: if(cfg[\gravity].isNil) { false } { cfg[\gravity][\enabled] ? false },
			gravityHomePc: st[\gravityHomePc],
			gravityHomeCents: st[\gravityHomeCents],
			gravityStrength: if(cfg[\gravity].isNil) { 0.0 } { cfg[\gravity][\strength] ? 0.0 },
			gravityMaxPullCents: if(cfg[\gravity].isNil) { 0.0 } { cfg[\gravity][\maxPullCents] ? 0.0 },
			gravityLastApplied: st[\gravityLastApplied] ? false,
			gravityLastShiftCents: st[\gravityLastShiftCents] ? 0.0,
			gravityLastReason: st[\gravityLastReason],
			lastGaugeCarry: st[\lastGaugeCarry],
			lastGaugeCarryCents: if(st[\lastGaugeCarry].isNil) { nil } { st[\lastGaugeCarry][\cents] },
			showIntervalLinks: cfg[\ui][\showIntervalLinks],
			frozenGhostAlpha: cfg[\ui][\frozenGhostAlpha],
			uiFps: cfg[\ui][\fps],
			renderReleaseTime: cfg[\render][\releaseTime],
			renderMode: st[\renderMode],
			toneProfile: if(cfg[\render].isNil) { \organ } { cfg[\render][\toneProfile] ? \organ },
			toneProfiles: if(cfg[\render].isNil) { [\probe, \pure, \piano, \electricPiano, \organ, \pad, \synth] } { cfg[\render][\toneProfiles] ? [\probe, \pure, \piano, \electricPiano, \organ, \pad, \synth] },
			toneLow: if(cfg[\render].isNil) { 0.5 } { cfg[\render][\toneLow] ? 0.5 },
			toneMid: if(cfg[\render].isNil) { 0.5 } { cfg[\render][\toneMid] ? 0.5 },
			toneHigh: if(cfg[\render].isNil) { 0.5 } { cfg[\render][\toneHigh] ? 0.5 },
			adaptiveToneMode: if(cfg[\render].isNil) { \static } { cfg[\render][\adaptiveToneMode] ? \static },
			adaptiveToneModes: if(cfg[\render].isNil) { [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening] } { cfg[\render][\adaptiveToneModes] ? [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening] },
			adaptiveToneAmount: if(cfg[\render].isNil) { 0.0 } { cfg[\render][\adaptiveToneAmount] ? 0.0 },
			registerVelocityEnabled: if(cfg[\registerVelocity].isNil) { false } { cfg[\registerVelocity][\enabled] ? true },
			registerVelocityRegisterAmount: if(cfg[\registerVelocity].isNil) { 0.0 } { cfg[\registerVelocity][\registerAmount] ? 1.0 },
			registerVelocityVelocityAmount: if(cfg[\registerVelocity].isNil) { 0.0 } { cfg[\registerVelocity][\velocityAmount] ? 1.0 },
			registerVelocityLastReport: st[\lastRegisterVelocityChartReport],
			earGravityFollowMode: if(cfg[\finalControls].isNil) { \off } { cfg[\finalControls][\earGravityFollowMode] ? \off },
			earGravityFollowStrength: if(cfg[\finalControls].isNil) { 1.0 } { cfg[\finalControls][\earGravityFollowStrength] ? 1.0 },
			spectrumAccordionAmount: if(cfg[\finalControls].isNil) { 0.0 } { cfg[\finalControls][\spectrumAccordionAmount] ? 0.0 },
			spectrumAccordionProfile: if(cfg[\finalControls].isNil) { \harmonic } { cfg[\finalControls][\spectrumAccordionProfile] ? \harmonic },
			tensionSemanticRole: if(cfg[\render].isNil) { \harmonicStrainTimbre } { cfg[\render][\tensionSemanticRole] ? \harmonicStrainTimbre },
			tensionPitchAuthority: false,
			adaptiveTimbrePitchAuthority: false,
			micEnabled: cfg[\mic][\enabled],
			micMode: cfg[\mic][\mode],
			micInputMode: cfg[\mic][\inputMode],
			micInfluencePolicy: cfg[\mic][\influencePolicy],
			micTrust: cfg[\mic][\trust] ? 0.70,
			micInfluenceBlocked: st[\micInfluenceBlocked],
			micCommitCooldown: st[\micCommitCooldown],
			micSelfIgnoreFramesRemaining: st[\micSelfIgnoreFramesRemaining],
			micTickCount: st[\micTickCount],
			micRawFreq: st[\micRawFreq],
			micRawAmp: st[\micRawAmp],
			micAnalyzedAmp: st[\micAnalyzedAmp],
			micInputAmp0: st[\micInputAmp0],
			micInputAmp1: st[\micInputAmp1],
			micSignalPresent: st[\micSignalPresent],
			micVoiced: st[\micVoiced],
			micPc: st[\micPc],
			micPhase: st[\micPhase],
			micConfidence: st[\micConfidence],
			rawCandidateCount: micRawCandidates.size,
			stabilizedCandidateCount: micCandidates.size,
			candidateCount: micCandidates.size,
			externalCount: externalSources.size,
			micRawCandidates: micRawCandidates,
			micCandidates: micCandidates,
			micStabilizedCandidates: micCandidates,
			externalSources: externalSources,
			strongestRawCandidate: if(strongestRawCandidate.isNil) { nil } { strongestRawCandidate.copy },
			strongestCandidate: if(strongestCandidate.isNil) { nil } { strongestCandidate.copy },
			strongestExternal: if(strongestExternal.isNil) { nil } { strongestExternal.copy }
		)
	};

	api[\refreshUISnapshot] = {
		st[\uiSnapshotCache] = at[\buildUISnapshot].();
		st[\uiSnapshotCache]
	};

	api[\uiSnapshot] = {
		if(st[\uiSnapshotCache].isNil) {
			api[\refreshUISnapshot].();
		};
		st[\uiSnapshotCache]
	};

	api[\fieldReport] = {
		var snap, dev, targetDev, frozenDev, memoryDev, held, report;
		snap = api[\uiSnapshot].();
		dev = snap[\nodePhase].collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) };
		targetDev = snap[\targetPhase].collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) };
		frozenDev = snap[\frozenPhase].collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) };
		memoryDev = (st[\memoryPhase] ? st[\etPhase]).collect { |p, i| (at[\wrapSigned].(p - st[\etPhase][i]) * 1200.0).round(0.01) };
		held = at[\notesArray].().collect { |n|
			var pc, initPhase, protectedPhase, currentPhase, targetPhase;
			pc = n[\pc];
			initPhase = n[\heldInitialPhase] ? (n[\protectedPhase] ? st[\nodePhase][pc]);
			protectedPhase = n[\protectedPhase] ? st[\nodePhase][pc];
			currentPhase = st[\nodePhase][pc];
			targetPhase = st[\targetPhase][pc];
			(
				midi: n[\midi],
				pc: pc,
				age: at[\noteAge].(n).round(0.01),
				initialDevCents: (at[\wrapSigned].(initPhase - st[\etPhase][pc]) * 1200.0).round(0.01),
				protectedDevCents: (at[\wrapSigned].(protectedPhase - st[\etPhase][pc]) * 1200.0).round(0.01),
				currentDevCents: (at[\wrapSigned].(currentPhase - st[\etPhase][pc]) * 1200.0).round(0.01),
				targetDevCents: (at[\wrapSigned].(targetPhase - st[\etPhase][pc]) * 1200.0).round(0.01),
				protectedShiftCents: (at[\wrapSigned].(protectedPhase - initPhase) * 1200.0).round(0.01),
				currentDriftCents: (at[\wrapSigned].(currentPhase - initPhase) * 1200.0).round(0.01),
				targetPullFromProtectedCents: (at[\wrapSigned].(targetPhase - protectedPhase) * 1200.0).round(0.01),
				elasticAccum: (n[\heldElasticAccum] ? 0.0).round(0.001),
				elasticPressureCents: (n[\heldElasticLastPressureCents] ? 0.0).round(0.01),
				elasticPeakPressureCents: (n[\heldElasticPeakPressureCents] ? 0.0).round(0.01),
				elasticIntegratedPressureCentsSec: (n[\heldElasticIntegratedPressureCentsSec] ? 0.0).round(0.01),
				elasticYieldCents: (n[\heldElasticYieldCents] ? 0.0).round(0.01),
				elasticTotalYieldCents: (n[\heldElasticTotalYieldCents] ? 0.0).round(0.01)
			)
		};
		report = (
			state: snap[\state],
			activeNotes: snap[\activeNotes],
			activePcs: snap[\activePcs],
			targetValid: snap[\targetValid],
			motionActive: snap[\motionActive],
			fieldFrozen: snap[\fieldFrozen],
			lastFieldAction: snap[\lastFieldAction],
			fieldHadSolvedEvidence: snap[\fieldHadSolvedEvidence],
			frozenFromEvidence: snap[\frozenFromEvidence],
			musicalRestValid: snap[\musicalRestValid],
			memoryValid: snap[\memoryValid],
			memoryConfidence: snap[\memoryConfidence],
			memoryDistanceCents: snap[\memoryLastDistanceCents],
			memoryLastInfluence: snap[\memoryLastInfluence],
			memoryLastLearnRate: snap[\memoryLastLearnRate],
			memoryLastReason: snap[\memoryLastReason],
			lastWorldSource: snap[\lastFieldAction],
			targetReason: snap[\targetReason],
			worldEnabled: snap[\worldEnabled],
			worldLabel: snap[\worldLabel],
			worldScore: snap[\worldScore],
			worldChosenAnchorPc: snap[\worldChosenAnchorPc],
			worldRootPc: snap[\worldRootPc],
			worldBassPc: snap[\worldBassPc],
			worldBassMidi: snap[\worldBassMidi],
			worldInversion: snap[\worldInversion],
			worldFamily: snap[\worldFamily],
			worldFunction: snap[\worldFunction],
			worldAmbiguityIndex: snap[\worldAmbiguityIndex],
			worldScoreGap: snap[\worldScoreGap],
			worldLastBlend: snap[\worldLastBlend],
			worldLastReason: snap[\worldLastReason],
			gravityEnabled: snap[\gravityEnabled],
			gravityHomePc: snap[\gravityHomePc],
			gravityHomeCents: snap[\gravityHomeCents],
			gravityStrength: snap[\gravityStrength],
			gravityMaxPullCents: snap[\gravityMaxPullCents],
			gravityLastApplied: snap[\gravityLastApplied],
			gravityLastShiftCents: snap[\gravityLastShiftCents],
			gravityLastReason: snap[\gravityLastReason],
			worldTopWorlds: snap[\worldTopWorlds],
			worldFamilyTopWorlds: snap[\worldFamilyTopWorlds],
			phraseEnabled: snap[\phraseEnabled],
			phraseFunction: snap[\phraseFunction],
			phraseFunctionConfidence: snap[\phraseFunctionConfidence],
			phraseTags: snap[\phraseTags],
			phraseHomeWorld: snap[\phraseHomeWorld],
			phraseHomeConfidence: snap[\phraseHomeConfidence],
			phrasePendingDominant: snap[\phrasePendingDominant],
			phrasePendingDiminished: snap[\phrasePendingDiminished],
			phraseLastResolution: snap[\phraseLastResolution],
			phraseCurrentWorld: snap[\phraseCurrentWorld],
			phrasePreviousDistinctWorld: snap[\phrasePreviousDistinctWorld],
			phraseObservedSignature: snap[\phraseObservedSignature],
			phraseObservedAge: snap[\phraseObservedAge],
			phraseObservedStable: snap[\phraseObservedStable],
			devCents: dev,
			memoryDevCents: memoryDev,
			targetDevCents: targetDev,
			frozenDevCents: frozenDev,
			heldElastic: held
		);
		report.postln;
		report
	};

	at[\fieldReport] = { api[\fieldReport].(); };

	// ------------------------------------------------------------
	// UI placeholders (defined by AdaptiveTemperament_visual.scd)
	// ------------------------------------------------------------

	api[\closeUI] = {
		if(ui[\refreshRoutine].notNil) {
			ui[\refreshRoutine].stop;
			ui[\refreshRoutine] = nil;
		};
		if(ui[\window].notNil) {
			ui[\window].close;
			ui[\window] = nil;
		};
		"[at] visual layer not loaded".postln;
	};

	api[\openUI] = {
		"[at] visual layer not loaded. Load AdaptiveTemperament_visual.scd after the core.".postln;
	};

	// ------------------------------------------------------------
	// Sound-first probes
	// ------------------------------------------------------------

	api[\rawBeep] = { |freq=440, amp=0.16, dur=0.35|
		("[at-audio] rawBeep freq=" ++ freq.asString).postln;
		Synth(\atbeep, [
			\out, cfg[\render][\out] ? 0,
			\freq, freq,
			\amp, amp,
			\dur, dur,
			\masterAmp, cfg[\render][\masterAmp]
		]);
	};

	api[\soundCheck] = { |midi=60, velocity=0.9, dur=0.65|
		("[at-audio] soundCheck midi=" ++ midi.asString).postln;
		at[\noteOn].(midi, velocity, nil, false);
		{ at[\noteOff].(midi); }.defer(dur);
	};

	at[\rawBeep] = { |freq=440, amp=0.16, dur=0.35| api[\rawBeep].(freq, amp, dur); };
	at[\soundCheck] = { |midi=60, velocity=0.9, dur=0.65| api[\soundCheck].(midi, velocity, dur); };

	// flat compatibility
	at[\openUI] = { api[\openUI].(); };
	at[\closeUI] = { api[\closeUI].(); };

	// additional flat compatibility wrappers
	at[\setPowerEnabled] = { |flag| api[\setPowerEnabled].(flag) };
	at[\setBrainEnabled] = { |flag| api[\setBrainEnabled].(flag) };
	at[\setMacro] = { |name, value| api[\setMacro].(name, value) };
	at[\setMicTrust] = { |x| api[\setMicTrust].(x) };
	at[\setMicEnabled] = { |flag| api[\setMicEnabled].(flag) };
	at[\setMemoryAmount] = { |x| api[\setMemoryAmount].(x) };
	at[\clearTonalMemoryApi] = { api[\clearTonalMemory].() };
	at[\setMicMode] = { |mode| api[\setMicMode].(mode) };
	at[\setMicInputMode] = { |mode| api[\setMicInputMode].(mode) };
	at[\setMicInfluencePolicy] = { |policy| api[\setMicInfluencePolicy].(policy) };
	at[\setMicGain] = { |x| api[\setMicGain].(x) };
	at[\setMicWeight] = { |x| api[\setMicWeight].(x) };
	at[\setMicThreshold] = { |x| api[\setMicThreshold].(x) };
	at[\setMicDuetSamePcSelfCents] = { |x| api[\setMicDuetSamePcSelfCents].(x) };
	at[\setMicDuetSamePcTuningScale] = { |x| api[\setMicDuetSamePcTuningScale].(x) };
	at[\setMicPitchAmpThreshold] = { |x| api[\setMicPitchAmpThreshold].(x) };
	at[\setMicPitchDetectGain] = { |x| api[\setMicPitchDetectGain].(x) };
	at[\setMicZeroCrossFallback] = { |flag| api[\setMicZeroCrossFallback].(flag) };
	at[\setMicZeroCrossAmpThreshold] = { |x| api[\setMicZeroCrossAmpThreshold].(x) };
	at[\setRenderMode] = { |mode| api[\setRenderMode].(mode) };
	at[\setPitchLag] = { |x| api[\setPitchLag].(x) };
	at[\setBrightnessAmount] = { |x| api[\setBrightnessAmount].(x) };
	at[\setRoughnessAmount] = { |x| api[\setRoughnessAmount].(x) };
	at[\setPanMotionAmount] = { |x| api[\setPanMotionAmount].(x) };
	at[\setMasterAmp] = { |x| api[\setMasterAmp].(x) };
	at[\setReleaseTime] = { |x| api[\setReleaseTime].(x) };
	at[\setMovement] = { |x| api[\setMovement].(x) };
	at[\setTension] = { |x| api[\setTension].(x) };
	at[\setGravityFollowMode] = { |mode, strength=1.0| api[\setGravityFollowMode].(mode, strength) };
	at[\applyGravityFollow] = { |reason=\manual| api[\applyGravityFollow].(reason) };
	at[\setSpectrumAccordionAmount] = { |x=0.0, profile=\bellLike| api[\setSpectrumAccordionAmount].(x, profile) };
	at[\spectrumAccordionReport] = { |post=true| api[\spectrumAccordionReport].(post) };
	at[\setFieldContinuousResolveEnabled] = { |flag| api[\setFieldContinuousResolveEnabled].(flag) };
	at[\setFieldContinuousResolveInterval] = { |x| api[\setFieldContinuousResolveInterval].(x) };
	at[\setPassiveScale] = { |x| api[\setPassiveScale].(x) };
	at[\setMaxStep] = { |x| api[\setMaxStep].(x) };
	at[\setContextGaugeEnabled] = { |flag| api[\setContextGaugeEnabled].(flag) };
	at[\setContextGaugeStrength] = { |x| api[\setContextGaugeStrength].(x) };
	at[\setContextGaugeMaxCents] = { |x| api[\setContextGaugeMaxCents].(x) };
	at[\setContextGaugeWindow] = { |x| api[\setContextGaugeWindow].(x) };
	at[\authorityReport] = { api[\authorityReport].() };
	at[\setShowIntervalLinks] = { |flag| api[\setShowIntervalLinks].(flag) };
	at[\setFrozenGhostAlpha] = { |x| api[\setFrozenGhostAlpha].(x) };
	at[\setUIFps] = { |x| api[\setUIFps].(x) };


};
)
