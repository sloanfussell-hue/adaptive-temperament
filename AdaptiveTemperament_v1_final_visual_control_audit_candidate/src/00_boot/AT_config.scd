(
// AT_config.scd — v67b first full product final instrument demo runtime bootfix
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

	pitchClassNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
	at[\pitchClassNames] = pitchClassNames;

	"".postln;
	"[at] production shell booting around verified event-driven tuning core".postln;

	// ------------------------------------------------------------
	// configuration
	// ------------------------------------------------------------

	cfg[\solver] = (
		numNodes: 12,
		eventSingleIter: 700,
		eventMultiIter: 1200,
		micIter: 120,
		eventEps: 0.0000005,
		singleAlpha: 0.18,
		multiAlpha: 0.12,
		maxStep: 0.01,
		passiveScale: 0.32,
		topologyMinGap: 0.015,
		// Pitch-identity topology guard: a structural spacing floor for active
		// pitch classes. This is not an ET clamp or cent cap; it only prevents
		// adjacent pitch identities from collapsing into the active note's name.
		topologyGuardEnabled: false,
		topologyActiveMinGapCents: 42.0,

		// Narrow context-gauge carry: if a new note arrives below the currently
		// held material, it may carry the absolute field toward its reference
		// placement. This makes held upper notes move with lower harmonic context
		// without changing ratio solving, rest freeze, or singleton inheritance.
		contextGaugeEnabled: true,
		contextGaugeStrength: 1.0,
		contextGaugeRecentWindow: 0.35,
		contextGaugeMaxCents: 18.0,
		contextGaugeResponse: 0.52,
		contextGaugeUpperHeldDamping: 0.70,
		contextGaugeReversalDamping: 0.42,

		// External/mic carry is a UI-exposed macro path. It is disabled by
		// default so older bundles keep their exact sound-first behavior until
		// the user intentionally enables mic/external influence.
		externalGaugeCarryEnabled: false,
		externalGaugeCarryStrength: 0.42,
		externalGaugeCarryMaxCents: 4.0,
		externalGaugeCarryResponse: 0.62,
		externalGaugeCarryReversalDamping: 0.55,

		// v65: Tension is sound/timbre expression, not pitch authority.
		// Preserve the prior default solver response with a fixed reference factor
		// rather than letting the Tension slider retune active chords.
		tensionAffectsPitch: false,
		tensionPitchReference: 0.55,
		tensionTopologyReferenceScale: 0.8075
	);

	cfg[\mic] = (
		enabled: false,
		mode: \mono,
		influencePolicy: \externalOnly,
		gain: 8.0,
		weight: 0.35,
		ampThreshold: 0.0012,
		meterThreshold: 0.0006,
		pitchAmpThreshold: 0.00025,
		pitchDetectGain: 10.0,
		zeroCrossFallback: true,
		zeroCrossAmpThreshold: 0.00018,
		pitchMedian: 3,
		pitchMinFreq: 35.0,
		pitchMaxFreq: 2200.0,
		pitchExecFreq: 50.0,
		ampConfidenceSpan: 0.018,
		inputMode: \sum01,
		pollDt: 0.05,
		stableFrames: 4,
		maxExternalSources: 3,
		duetMaxExternalSources: 2,
		minConfidence: 0.06,
		commitCooldownFrames: 3,
		activateFrames: 3,
		releaseFrames: 5,
		selfIgnoreFrames: 6,
		selfGeneralPenalty: 0.55,
		selfMatchPenalty: 0.18,
		duetWeightScale: 0.85,
		duetSamePcSelfCents: 4.0,
		duetSamePcUsefulCents: 80.0,
		duetSamePcTuningScale: 1.15,
		duetSamePcConfidenceScale: 1.0,
		debugRawMaxExternalSources: 1,
		rawCandidateLimit: 8,

		polyBinsPerOct: 24,
		polyOctaves: 5,
		polyBaseFreq: 55.0,
		polyRefFreq: 220.0,
		polyRq: 0.045,
		polyAttack: 0.01,
		polyRelease: 0.12,
		polyPeakThreshold: 0.30,
		polyAbsThreshold: 0.0012,
		polyCandidateLimit: 6,
		polyBiasMin: 0.4,
		polyBiasMax: 1.6,
		polyMeanThresholdScale: 2.6,
		polyScoreAttack: 0.62,
		polyScoreRelease: 0.22,
		polyVisibleThreshold: 0.03,
		polyVisibleRelease: 0.015,
		polyActiveThreshold: 0.11,
		polyActiveRelease: 0.06,
		polyPhaseAlpha: 0.45,
		polyFreqAlpha: 0.35,
		polyMinStableFrames: 2,
		polyHarmonicTolerance: 0.028,
		polyHarmonicSuppress: 0.72,
		polyMaxHarmonic: 6,
		keyPhaseQuant: 0.004,
		keyWeightQuant: 0.08,
		keyConfidenceQuant: 0.08
	);

	cfg[\render] = (
		mode: \production,
		out: 0,
		tension: 0.55,
		pitchLag: 0.03,
		alignLag: 0.04,
		motionLag: 0.03,
		stabilityLag: 0.04,
		brightnessAmount: 1.0,
		roughnessAmount: 1.0,
		panMotionAmount: 1.0,
		releaseTime: 0.12,
		masterAmp: 1.0,
		// v65 semantic contract: Tone/Tension/Adaptive Tone are audible color
		// controls only. They may read harmonic strain but must not add pitch
		// authority or mutate the tuning circle.
		tensionSemanticRole: \harmonicStrainTimbre,
		adaptiveTimbrePitchAuthority: false
	);


	cfg[\input] = (
		chordDebounce: 0.022,
		immediateDirectNoteCalls: false,
		postMidiEvents: true
	);


	// Chord-local register/velocity chart authority. This is core harmonic
	// source selection for active chords, not key detection and not added
	// pitch authority. Lower register and stronger velocity can select the
	// local harmonic basis/slash/inversion chart used by the solver.
	cfg[\registerVelocity] = (
		enabled: true,
		registerAmount: 1.0,
		velocityAmount: 1.0,
		registerSpanSemitones: 16.0,
		velocityCurve: 1.25,
		continuityBonus: 0.04,
		selectedBasisWeight: 1.65,
		nonBasisWeight: 1.0,
		samePcReinforcement: 0.18,
		decisionMargin: 0.035,
		tieBreak: \register,
		postProfiles: false
	);

	// Naked harmonic field path constants. These are not a user mode and
	// not a transport effect layered onto equal temperament. They define
	// how long the free core treats successive note onsets as one lived
	// harmonic path before memory/gravity/mic/context stabilizers interpret
	// or constrain that path.
	cfg[\coreTransport] = (
		pathWindow: 4.0,
		minCents: 0.25,
		maxMidiLeap: 24,
		allowDuringPolyphony: true
	);

	cfg[\field] = (
		enabled: true,
		continuousResolveEnabled: true,
		continuousResolveInterval: 0.08,
		freezeOnNoEvidence: true,
		resolveOnEvidenceChange: true,
			// Final demo/product posture: while evidence is present, current field
			// must be committed immediately enough that the response appears during
			// the sound, not after release. Release preserves; it does not chase a
			// stale target.
			commitCurrentOnActiveTick: true,
			cancelTargetMotionOnRelease: true,
		logEvidenceTicks: false
	);

	cfg[\motion] = (
		enabled: true,
		dt: 0.025,
		baseMaxCentsPerTick: 4.0,
		heldMaxCentsPerTick: 0.85,
		freshMaxCentsPerTick: 7.0,
		passiveMaxCentsPerTick: 5.5,
		heldAgeThreshold: 0.65,
		heldInertiaStrength: 0.92,
		heldTargetMaxCents: 4.0,
		// Elastic held-note yielding. Long-held notes resist sudden target changes,
		// but persistent harmonic pressure slowly migrates their protected phase
		// toward the new world instead of dead-clamping them forever.
		heldElasticEnabled: true,
		heldElasticPressureCents: 1.25,
		heldElasticAttack: 0.09,
		heldElasticDecay: 0.045,
		heldElasticYieldRateCents: 0.16,
		heldElasticMaxExtraCents: 18.0,
		settleEpsilonCents: 0.015,
		forceSnapWhenSilent: true
	);

	cfg[\memory] = (
		enabled: true,
		amount: 0.35,
		learningRate: 0.045,
		modulationAdapt: 0.18,
		decay: 0.008,
		confidenceLearn: 0.10,
		confidenceDecay: 0.012,
		maxBiasCents: 18.0,
		conflictSoftCents: 18.0,
		conflictHardCents: 55.0,
		minActiveWeight: 0.0001,
		includePassiveNodes: true
	);

	cfg[\phrase] = (
		enabled: true,
		debug: true,
		homeLearnRate: 0.18,
		homeDecay: 0.04,
		dominantFunctionalConfidence: 0.74,
		dominantColorConfidence: 0.78,
		passingDiminishedConfidence: 0.72,
		dominantFunctionDiminishedConfidence: 0.68,
		functionalResolutionWindow: 6.0,
		passingResolutionWindow: 6.0,
		// Same-root dominant color is only inferred from a recent, stable
		// same-root home/context world. This prevents stale home memory from
		// turning every dominant into a blues/color dominant.
		sameRootColorWindow: 4.0,
		// Chromatic passing diminished may be inferred from a recent tonal world
		// one semitone below the diminished root. It outranks generic dominant-
		// function diminished when the local phrase context supports it.
		passingSourceWindow: 5.0,
		// Phrase logic only commits worlds after the active pitch-class set has
		// stabilized. This prevents note-by-note chord construction from causing
		// fake resolutions or stale dominant/diminished states.
		minStableSeconds: 0.30
	);

	cfg[\world] = (
		enabled: true,
		debug: true,
		maxWorlds: 14,
		topReportCount: 6,
		familyReportCount: 5,
		targetBlend: 0.28,
		passiveBlendScale: 0.12,
		hysteresis: 0.35,
		ambiguityGap: 1.25,
		familyAmbiguityGap: 0.65,
		clearTriadAmbiguity: 0.16,
		inversionAmbiguity: 0.34,
		diminishedAmbiguityFloor: 0.72,
		dominantAmbiguityFloor: 0.55,
		ambiguityBlend: 0.55,
		familyWeight: 1.25,
		rootPresentWeight: 0.18,
		bassRootWeight: 0.24,
		inversionWeight: 0.28,
		colorVariantWeight: 0.06,
		symmetryVariantWeight: 0.08,
		memoryWeight: 0.35,
		continuityWeight: 0.45,
		heldCostWeight: 0.65,
		bassWeight: 0.55,
		simplicityWeight: 0.35,
		motionCostWeight: 0.40,
		solvedFitWeight: 0.18,
		externalWeight: 0.25,
		minActivePcs: 2
	);


	cfg[\perf] = (
		performanceProfile: \expressive,
		fieldResponseMacro: 0.55,
		memoryContinuityMacro: 0.58,
		externalInfluenceMacro: 0.48,
		uiSlowRefreshDt: 0.28
	);

	cfg[\coreFreedom] = (
		heldGuardsEnabled: true
	);

	// Authority polarity map. These are not modes. They classify how existing
	// authorities affect the naked core at the extremes:
	// - raw harmonic law is always present; it is not a setting.
	// - memory/gravity/world/phrase/held guards inhibit free transport when they
	//   have earned or intentional authority.
	// - carry/movement/external following are not treated as simple inhibitors.
	// The solver reads this only to decide how much of the raw covering-space
	// path is allowed to appear when stabilizing authorities are present.
	cfg[\authority] = (
		memoryInhibitionWeight: 0.52,
		gravityInhibitionWeight: 0.30,
		worldInhibitionWeight: 0.10,
		phraseInhibitionWeight: 0.08,
		heldGuardInhibitionWeight: 0.10,
		externalInhibitionWeight: 0.12,
		perceptualInhibitionWeight: 0.10,
		maxInhibition: 0.97,
		motionLimitInhibitionDepth: 0.86,
		minMotionFreedom: 0.04,
		// Path freedom is intentionally nonlinear: high stabilizing authority
		// should make non-closing raw harmonic paths barely appear, while zero
		// authority still exposes the naked fish-core exactly. This is not a
		// mode; it is the consequence of embodied authority resisting movement.
		pathFreedomExponent: 2.0,
		minPathFreedom: 0.0
	);

	// Perceptual coherence is Sethares-inspired but deliberately not the master
	// tuning law. It adds a soft, optional pressure toward lower perceived
	// beating/roughness across the whole current sonority. It must not replace
	// the naked fish core: default amount is zero, and presets can enable
	// it as a real-world compromise authority.
	cfg[\perceptual] = (
		enabled: true,
		amount: 0.0,
		passiveBlend: 0.36,
		activeBlend: 0.06,
		externalBlend: 0.0,
		roughnessSoftCents: 18.0,
		continuityWeight: 0.42,
		complexityWeight: 0.10,
		externalWeightScale: 1.20,
		activeWeightScale: 0.72,
		maxMoveCents: 7.0,
		candidateRatioLimit: 3,
		debug: false
	);

	// Perceptual-spectrum authority is the full Sethares-style extension layer.
	// It is loaded but inert by default. When enabled with nonzero amount, it
	// adds actual partial-by-partial sensory roughness to the existing
	// whole-sonority perceptual layer. This keeps the current keeper safe:
	// amount=0 is a no-op, fishCoreDiagnostic clears it, and the raw harmonic
	// field remains the source of naked-core behavior.
	cfg[\perceptualSpectrum] = (
		enabled: true,
		amount: 0.0,
		defaultProfile: \harmonic,
		passiveCandidateWeight: 0.42,
		candidateCostWeight: 3.6,
		maxPartialsPerSource: 8,
		minPartialAmp: 0.015,
		maxFrequency: 9000.0,
		baseFrequency: 261.625565,
		activeBlendScale: 1.0,
		passiveBlendScale: 1.0,
		debug: false
	);

	cfg[\gravity] = (
		enabled: false,
		homePc: 0,
		homeCents: 0.0,
		strength: 0.18,
		maxPullCents: 6.0,
		applyWithoutActive: false,
		debug: false
	);

	cfg[\ui] = (
		openOnBoot: true,
		fps: 14,
		ringRadius: 170,
		minNodeSize: 8,
		maxNodeSize: 18,
		showIntervalLinks: true,
		rightPanelWidth: 420,
		fieldPadding: 12,
		frozenGhostAlpha: 0.45,
		rawHaloOffset: 14,
		candidateHaloOffset: 24,
		externalHaloOffset: 36
	);

};
)
