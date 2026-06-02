(
// AT_adaptive_tone.scd — v65 semantic adaptive timbre audit support
// Shared adaptive-tone layer. This is intentionally semantic: profile SynthDefs
// receive small musical macro controls instead of raw solver/mic internals.

var build, at, cfg, st, api, diag, ui;

build = ~atBuild;

if(build.isNil) {
	"[at-adaptive-tone] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
	at = build[\at];
	cfg = build[\cfg];
	st = build[\state];
	api = build[\api];
	diag = build[\diag];
	ui = build[\ui];

	if(cfg[\render].isNil) { cfg[\render] = IdentityDictionary.new; };
	cfg[\render][\adaptiveToneModes] = [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening];
	if(cfg[\render][\adaptiveToneMode].isNil) { cfg[\render][\adaptiveToneMode] = \static; };
	if(cfg[\render][\adaptiveToneAmount].isNil) { cfg[\render][\adaptiveToneAmount] = 0.0; };
	if(st[\adaptiveToneLast].isNil) { st[\adaptiveToneLast] = IdentityDictionary.new; };

	at[\validAdaptiveToneMode] = { |mode|
		var m;
		m = (mode ? \static).asSymbol;
		if(cfg[\render][\adaptiveToneModes].includes(m)) { m } { \static }
	};

	at[\adaptiveToneModeIndex] = { |mode|
		var m;
		m = at[\validAdaptiveToneMode].(mode);
		switch(m,
			\static, { 0 },
			\coherenceBloom, { 1 },
			\motionBreath, { 2 },
			\tensionEdge, { 3 },
			\listening, { 4 },
			{ 0 }
		)
	};

	at[\buildAdaptiveToneSnapshot] = {
		var activePcs, alignVals, stabVals, motionVals, coherence, stability, motion, conflict, density, externalPressure, gravity, memory, mode, amount;
		var tension, targetDistance, registerVelocityConflict, abnormalExternal, strain, brightnessPush, edgePush, breathPush, bloomPush;
		activePcs = if(st[\activeNotes].notNil) { st[\activeNotes].keys.collect { |m| m % 12 }.asSet.asArray } { Array.new };
		alignVals = activePcs.collect { |pc| st[\nodeAlignment][pc] ? 1.0 };
		stabVals = activePcs.collect { |pc| st[\nodeStability][pc] ? 1.0 };
		motionVals = activePcs.collect { |pc| st[\nodeMotion][pc] ? 0.0 };
		coherence = if(alignVals.size > 0) { alignVals.sum / alignVals.size } { 1.0 };
		stability = if(stabVals.size > 0) { stabVals.sum / stabVals.size } { 1.0 };
		motion = if(motionVals.size > 0) { motionVals.sum / motionVals.size } { 0.0 };
		conflict = (1.0 - stability).clip(0.0, 1.0);
		density = (activePcs.size / 6.0).clip(0.0, 1.0);
		externalPressure = if(st[\externalSources].notNil) { (st[\externalSources].size / 3.0).clip(0.0, 1.0) } { 0.0 };
		gravity = if(cfg[\gravity].notNil and: { cfg[\gravity][\enabled] ? false }) { cfg[\gravity][\strength] ? 0.0 } { 0.0 };
		memory = st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.0);
		mode = cfg[\render][\adaptiveToneMode] ? \static;
		amount = cfg[\render][\adaptiveToneAmount] ? 0.0;
		tension = st[\tension] ? (cfg[\render][\tension] ? 0.0);
		targetDistance = if(at[\motionTargetDistance].notNil) { (at[\motionTargetDistance].(st[\targetPhase]) * 1200.0).abs.clip(0.0, 80.0) / 80.0 } { 0.0 };
		registerVelocityConflict = if(st[\lastRegisterVelocityChartReport].notNil) {
			if((st[\lastRegisterVelocityChartReport][\registerWinnerPc] ? -1) == (st[\lastRegisterVelocityChartReport][\velocityWinnerPc] ? -1)) { 0.0 } { 1.0 }
		} { 0.0 };
		abnormalExternal = if(st[\lastExternalCoherenceSceneReport].notNil) { ((st[\lastExternalCoherenceSceneReport][\abnormal] ? 0) / 3.0).clip(0.0, 1.0) } { 0.0 };
		strain = ((conflict * 0.30) + (targetDistance * 0.22) + (registerVelocityConflict * 0.16) + (externalPressure * 0.12) + (abnormalExternal * 0.10) + (tension * 0.10)).clip(0.0, 1.0);
		bloomPush = (coherence * amount).clip(0.0, 1.0);
		breathPush = (motion + targetDistance).clip(0.0, 1.0) * amount;
		edgePush = (strain * amount).clip(0.0, 1.0);
		brightnessPush = ((strain * 0.65) + (coherence * 0.20) + (tension * 0.15)).clip(0.0, 1.0) * amount;
		(
			mode: mode,
			modeIndex: at[\adaptiveToneModeIndex].(mode),
			amount: amount,
			coherence: coherence.clip(0.0, 1.0),
			stability: stability.clip(0.0, 1.0),
			motion: motion.clip(0.0, 1.0),
			conflict: conflict.clip(0.0, 1.0),
			density: density,
			externalPressure: externalPressure,
			gravity: gravity.clip(0.0, 1.0),
			memory: memory.clip(0.0, 1.0),
			tension: tension.clip(0.0, 1.0),
			targetDistance: targetDistance.clip(0.0, 1.0),
			registerVelocityConflict: registerVelocityConflict.clip(0.0, 1.0),
			abnormalExternal: abnormalExternal.clip(0.0, 1.0),
			semanticStrain: strain.clip(0.0, 1.0),
			bloomPush: bloomPush.clip(0.0, 1.0),
			breathPush: breathPush.clip(0.0, 1.0),
			edgePush: edgePush.clip(0.0, 1.0),
			brightnessPush: brightnessPush.clip(0.0, 1.0),
			pitchAuthorityAdded: false
		)
	};

	at[\refreshAdaptiveToneSnapshot] = {
		st[\adaptiveToneLast] = at[\buildAdaptiveToneSnapshot].();
		st[\adaptiveToneLast]
	};

	at[\adaptiveToneReport] = {
		var snap;
		snap = at[\refreshAdaptiveToneSnapshot].();
		"".postln;
		"[AT ADAPTIVE TONE REPORT]".postln;
		("mode=" ++ snap[\mode].asString
			++ " amount=" ++ snap[\amount].round(0.001).asString
			++ " coherence=" ++ snap[\coherence].round(0.001).asString
			++ " motion=" ++ snap[\motion].round(0.001).asString
			++ " strain=" ++ (snap[\semanticStrain] ? 0.0).round(0.001).asString
			++ " edge=" ++ (snap[\edgePush] ? 0.0).round(0.001).asString
			++ " breath=" ++ (snap[\breathPush] ? 0.0).round(0.001).asString
			++ " external=" ++ snap[\externalPressure].round(0.001).asString
			++ " pitchAuthorityAdded=false").postln;
		snap
	};

	api[\setAdaptiveToneMode] = { |mode=\static|
		var m;
		m = at[\validAdaptiveToneMode].(mode);
		cfg[\render][\adaptiveToneMode] = m;
		st[\adaptiveToneMode] = m;
		if(at[\setActiveVoiceParam].notNil) {
			at[\setActiveVoiceParam].(\adaptiveMode, at[\adaptiveToneModeIndex].(m));
		};
		if(diag[\log].notNil) { diag[\log].("adaptive tone mode set to " ++ m.asString); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setAdaptiveToneAmount] = { |x=0.0|
		var v;
		v = x.clip(0.0, 1.0);
		cfg[\render][\adaptiveToneAmount] = v;
		st[\adaptiveToneAmount] = v;
		if(at[\setActiveVoiceParam].notNil) { at[\setActiveVoiceParam].(\adaptiveAmount, v); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};

	api[\setAdaptiveToneEnabled] = { |flag=true|
		api[\setAdaptiveToneAmount].(if(flag.asBoolean) { cfg[\render][\adaptiveToneAmount].max(0.5) } { 0.0 });
	};

	api[\adaptiveToneReport] = { at[\adaptiveToneReport].() };
	"[at-adaptive-tone] v65b loaded modes: static/coherenceBloom/motionBreath/tensionEdge/listening; adaptive timbre remains pitch-neutral".postln;
};
)
