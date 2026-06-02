(
// AT_state.scd
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
	// runtime state
	// ------------------------------------------------------------

	st.putAll((
		stateLabel: \neutral,
		brainEnabled: true,
		powerEnabled: true,
		sustainDown: false,
		frozenValid: false,
		soleAnchorPc: nil,
		soleAnchorPhase: nil,
		singletonReentryPending: nil,
		diagnosticRootByActiveSet: Dictionary.new,
		diagnosticRootLastPc: nil,
		lastDelta: Array.fill(cfg[\solver][\numNodes], 0.0),

		etPhase: Array.fill(cfg[\solver][\numNodes], { |i| i / 12.0 }),
		nodePhase: nil,
		frozenPhase: nil,
		targetPhase: nil,
		targetCoreUnwrappedPhase: nil,
		targetValid: false,
		lastSolvedPhase: nil,
		lastSolveTotalMotion: Array.fill(cfg[\solver][\numNodes], 0.0),
		motionActive: false,

		nodeMotion: Array.fill(cfg[\solver][\numNodes], 0.0),
		nodeAlignment: Array.fill(cfg[\solver][\numNodes], 1.0),
		nodeStability: Array.fill(cfg[\solver][\numNodes], 1.0),

		activeNotes: IdentityDictionary.new,
		voices: IdentityDictionary.new,

		devBus: Bus.control(s, cfg[\solver][\numNodes]),
		alignBus: Bus.control(s, cfg[\solver][\numNodes]),
		motionBus: Bus.control(s, cfg[\solver][\numNodes]),
		stabBus: Bus.control(s, cfg[\solver][\numNodes]),
		tensionBus: Bus.control(s, 1),
		micBus: Bus.control(s, 2),
		micPolyBus: Bus.control(s, cfg[\mic][\polyBinsPerOct] * cfg[\mic][\polyOctaves]),
		micLevelBus: Bus.control(s, 1),
		micMeterBus: Bus.control(s, 4),

		micSynth: nil,
		controlRoutine: nil,

		lastEvidence: nil,
		lastEvidenceKey: nil,
		evidenceDirty: false,
		evidenceDirtyReason: nil,
		evidenceDirtyAt: nil,
		lastFieldTickAt: nil,
		lastFieldResolveAt: nil,
		lastFieldAction: nil,
		fieldTickCount: 0,
		fieldFrozen: false,
		fieldFrozenAt: nil,
		// True only after the solver has installed a target from real MIDI/mic evidence.
		// This prevents boot-time equal-tempered silence from being treated as
		// a meaningful musical rest world for singleton reentry.
		fieldHadSolvedEvidence: false,
		frozenFromEvidence: false,
		musicalRestValid: false,
		lastFieldHadEvidence: false,
		targetUpdatedByTick: false,
		targetUpdatedByTickAt: nil,

		polyBinCount: cfg[\mic][\polyBinsPerOct] * cfg[\mic][\polyOctaves],
		polyBinFreqs: nil,
		polyBinPhases: nil,
		polyBinPcs: nil,
		polyBinBiases: nil,

		micRawFreq: 0.0,
		micRawAmp: 0.0,
		micAnalyzedAmp: 0.0,
		micInputAmp0: 0.0,
		micInputAmp1: 0.0,
		micSignalPresent: false,
		micInputMode: cfg[\mic][\inputMode],
		micVoiced: false,
		micPc: nil,
		micPhase: nil,
		micConfidence: 0.0,
		micStableCount: 0,
		micDiagKey: nil,
		lastMicKey: nil,
		micTickCount: 0,
		micRawCandidates: Array.new,
		micCandidates: Array.new,
		micStabilizedCandidates: Array.new,
		externalSources: Array.new,
		micInfluenceBlocked: false,
		micCommitCooldown: 0,
		micSelfIgnoreFramesRemaining: 0,

		micPcStableCounts: Array.fill(cfg[\solver][\numNodes], 0),
		micPcPrevPhases: Array.fill(cfg[\solver][\numNodes], { nil }),
		micPcPrevFreqs: Array.fill(cfg[\solver][\numNodes], { nil }),
		micPcScores: Array.fill(cfg[\solver][\numNodes], 0.0),
		micPcVisible: Array.fill(cfg[\solver][\numNodes], false),
		micPcActive: Array.fill(cfg[\solver][\numNodes], false),
		micPcWarmCounts: Array.fill(cfg[\solver][\numNodes], 0),
		micPcCoolCounts: Array.fill(cfg[\solver][\numNodes], 0),
		micCommittedByPc: Array.fill(cfg[\solver][\numNodes], { nil }),

		renderMode: cfg[\render][\mode],
		tension: cfg[\render][\tension],
		logEnabled: false,
		uiSnapshotCache: nil,

		// acceptance-diagnostic mirrors only; they do not own tuning behavior
		movement: 0.82,
			lastOnsetInfo: nil,

			// Core path transport state. This is not tonal-basin memory; it is
			// the current lived field remembering the immediately played path
			// so non-closing harmonic cycles naturally carry the whole world.
			lastCorePathOnset: nil,
			lastCoreTransport: nil,
			coreTransportHistory: Array.new,
			pitchIdentityNoteHistory: Array.new,
			// Lived covering-space copy of the pitch-class field. nodePhase is the
			// audible octave-wrapped surface; coreUnwrappedPhase is the naked core's
			// path-continuous body. This is not the optional memory layer.
			coreUnwrappedPhase: Array.fill(cfg[\solver][\numNodes], { |i| i / 12.0 }),
			frozenCoreUnwrappedPhase: nil,
			lastGaugeCarry: nil,
			previousVoiceSnapshot: IdentityDictionary.new,
			lastNoteCount: 0,
			restFreezeMonitor: nil,
			lastRestFreezeReport: nil,
			lastReentryReport: nil,
			lastMultiReentryReport: nil,
			lastSurvivorReport: nil,
			lastRestFreezePhase: nil,
			lastReentryAt: nil,

			// Candidate-world scoring diagnostics. This layer is advisory and
			// optional; the accepted harmonic solver remains the fallback.
			worldEnabled: true,
			worldActiveWorld: nil,
			worldTopWorlds: Array.new,
			worldFamilyTopWorlds: Array.new,
			worldAmbiguityIndex: 0.0,
			worldScoreGap: nil,
			worldChosenAnchorPc: nil,
			worldRootPc: nil,
			worldBassPc: nil,
			worldBassMidi: nil,
			worldInversion: nil,
			worldFamily: nil,
			worldFunction: nil,
			worldLabel: nil,
			worldScore: nil,
			worldLastReason: nil,
			worldLastBlend: 0.0,
			worldLastAt: nil,

			// Phrase-function diagnostics. Advisory only: phrase memory tags
			// contextual function without owning the tuning engine.
			phraseEnabled: true,
			phraseCurrentWorld: nil,
			phrasePreviousDistinctWorld: nil,
			phraseHomeWorld: nil,
			phraseHomeConfidence: 0.0,
			phrasePendingDominant: nil,
			phrasePendingDiminished: nil,
			phraseLastResolution: nil,
			phraseFunction: nil,
			phraseFunctionConfidence: 0.0,
			phraseTags: Array.new,
			phraseLastAt: nil
	));

	st[\nodePhase] = st[\etPhase].copy;
	st[\frozenPhase] = st[\etPhase].copy;
	st[\targetPhase] = st[\etPhase].copy;
	st[\lastSolvedPhase] = st[\etPhase].copy;
	st[\polyBinFreqs] = Array.fill(st[\polyBinCount], { |i|
		cfg[\mic][\polyBaseFreq] * (2 ** (i / cfg[\mic][\polyBinsPerOct].asFloat))
	});
	st[\polyBinPhases] = st[\polyBinFreqs].collect { |f|
		var p;
		p = ((f / 8.1757989156).log2) % 1.0;
		if(p < 0.0) { p = p + 1.0; };
		p;
	};
	st[\polyBinPcs] = st[\polyBinPhases].collect { |phase|
		((phase * 12.0).round.asInteger) % 12
	};
	st[\polyBinBiases] = st[\polyBinFreqs].collect { |f|
		(cfg[\mic][\polyRefFreq] / f).sqrt.clip(cfg[\mic][\polyBiasMin], cfg[\mic][\polyBiasMax])
	};

	// ratio candidates: [phaseOffset, simplicityWeight]
	at[\ratioChoices] = [
		[[0.0, 1.0]],
		[[0.09310940439148145, 1.0], [0.058893689053568614, 0.6]],
		[[0.16992500144231237, 1.0], [0.15200309344505006, 0.8]],
		[[0.2630344058337938, 1.0], [0.22239242133644802, 0.6]],
		[[0.32192809488736235, 1.0], [0.33985000288462475, 0.55]],
		[[0.41503749927884376, 1.0]],
		[[0.4918530963296747, 0.7], [0.48542682717024166, 0.85], [0.5081469036703253, 0.55]],
		[[0.5849625007211562, 1.0]],
		[[0.6780719051126377, 1.0], [0.7369655941662062, 0.35]],
		[[0.7369655941662062, 1.0], [0.7548875021634686, 0.55]],
		[[0.8479969065549501, 0.75], [0.8300749985576875, 0.7], [0.8073549220576041, 0.95]],
		[[0.9068905956085185, 1.0]]
	];

};
)
