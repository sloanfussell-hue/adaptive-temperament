(
// AT_input.scd
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
	// notes / sustain / mic controls
	// ------------------------------------------------------------

	at[\activeMidisSorted] = {
		st[\activeNotes].keys.asArray.sort;
	};

	at[\activeMidisForPc] = { |pc, excludeMidi=nil|
		var out;
		out = Array.new;
		st[\activeNotes].keysValuesDo { |midi, note|
			if((midi != excludeMidi) and: { note.notNil and: { note[\pc] == pc } }) {
				out = out.add(midi);
			};
		};
		out.sort;
	};

	at[\acceptSamePcEvidenceKeyWithoutResolve] = { |reason=\samePcVoiceWeightChange|
		var ev;
		if(at[\collectEvidence].notNil) {
			ev = at[\collectEvidence].();
			st[\lastEvidence] = ev;
			st[\lastEvidenceKey] = ev[\key];
		};
		st[\evidenceDirty] = false;
		st[\evidenceDirtyReason] = reason;
		st[\lastSamePcEvidenceAcceptedAt] = Main.elapsedTime;
		nil;
	};

	at[\recordSurvivorContinuityIfNeeded] = { |prevMidis, prevVoices|
		var currentMidis, survivorMidi, releasedMidis, releasedStillPresent, prevSynth, currSynth;
		currentMidis = at[\activeMidisSorted].();

		if((prevMidis.size > 1) and: { currentMidis.size == 1 }) {
			survivorMidi = currentMidis[0];
			releasedMidis = prevMidis.select { |m| currentMidis.includes(m).not };
			releasedStillPresent = releasedMidis.select { |m| st[\voices][m].notNil };
			prevSynth = prevVoices[survivorMidi];
			currSynth = st[\voices][survivorMidi];

			st[\lastSurvivorReport] = (
				timestamp: Main.elapsedTime,
				previousMidis: prevMidis.copy,
				currentMidis: currentMidis.copy,
				survivorMidi: survivorMidi,
				survivorKeptSameInstance: prevSynth.notNil and: { currSynth.notNil } and: { prevSynth === currSynth },
				releasedMidis: releasedMidis.copy,
				releasedStillPresent: releasedStillPresent.copy,
				releasedAllGone: releasedStillPresent.isEmpty
			);
		};
	};

	at[\beginRestFreezeMonitorIfNeeded] = { |prevMidis|
		if((prevMidis.size > 0) and: { st[\activeNotes].size == 0 }) {
			st[\restFreezeMonitor] = (
				startedAt: Main.elapsedTime,
				referenceNodePhase: st[\nodePhase].copy,
				referenceFrozenPhase: st[\frozenPhase].copy,
				frozenValidAtStart: st[\frozenValid]
			);
			st[\lastRestFreezeReport] = nil;
		};
	};

	at[\finalizeRestFreezeBeforeReentry] = {
		var mon, maxNodeDrift, maxFrozenDrift;
		mon = st[\restFreezeMonitor];
		if(mon.notNil) {
			maxNodeDrift = Array.fill(cfg[\solver][\numNodes], { |i|
				at[\wrapSigned].(st[\nodePhase][i] - mon[\referenceNodePhase][i]).abs;
			}).maxItem ? 0.0;
			maxFrozenDrift = Array.fill(cfg[\solver][\numNodes], { |i|
				at[\wrapSigned].(st[\frozenPhase][i] - mon[\referenceFrozenPhase][i]).abs;
			}).maxItem ? 0.0;

			st[\lastRestFreezePhase] = mon[\referenceFrozenPhase].copy;
			st[\lastRestFreezeReport] = (
				startedAt: mon[\startedAt],
				finishedAt: Main.elapsedTime,
				frozenValidAtStart: mon[\frozenValidAtStart],
				frozenValidAtFinish: st[\frozenValid],
				maxNodeDrift: maxNodeDrift,
				maxFrozenDrift: maxFrozenDrift,
				freezeHeld: (st[\frozenValid] == true) and: { maxNodeDrift <= 0.000001 } and: { maxFrozenDrift <= 0.000001 }
			);
			st[\restFreezeMonitor] = nil;
		};
	};

	at[\recordSingleReentryReportIfNeeded] = { |prevCount, midi, pc, expectedAnchor|
		var installedPhase, etPhase, restWasNonEt, installedMatchedRest;
		if((prevCount == 0) and: { expectedAnchor.notNil }) {
			installedPhase = st[\nodePhase][pc];
			etPhase = st[\etPhase][pc];
			restWasNonEt = at[\wrapSigned].(expectedAnchor - etPhase).abs > 0.000001;
			installedMatchedRest = at[\wrapSigned].(installedPhase - expectedAnchor).abs <= 0.000001;
			st[\lastReentryAt] = Main.elapsedTime;
			st[\lastReentryReport] = (
				timestamp: Main.elapsedTime,
				midi: midi,
				pc: pc,
				expectedRestAnchorPhase: expectedAnchor,
				expectedEtPhase: etPhase,
				installedAnchorPhase: installedPhase,
				installedMatchedRest: installedMatchedRest,
				installedVsEtDelta: at[\wrapSigned].(installedPhase - etPhase),
				restVsEtDelta: at[\wrapSigned].(expectedAnchor - etPhase),
				restWasNonEt: restWasNonEt,
				stateLabel: st[\stateLabel]
			);
		};
	};

	at[\recordMultiReentryReportIfNeeded] = { |prevCount|
		var activePcs, refPhase, anchorPc, anchorMatched, currentCloserToRestThanEt, currentVsRest, currentVsEt;
		activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
		if((prevCount == 1) and: { activePcs.size >= 2 } and: { st[\lastRestFreezePhase].notNil }) {
			refPhase = st[\lastRestFreezePhase];
			anchorPc = at[\strongestPc].(activePcs, at[\pcWeights].());
			anchorMatched = at[\wrapSigned].(st[\nodePhase][anchorPc] - refPhase[anchorPc]).abs <= 0.000001;
			currentVsRest = activePcs.collect { |pc| at[\wrapSigned].(st[\nodePhase][pc] - refPhase[pc]).abs }.sum / activePcs.size;
			currentVsEt = activePcs.collect { |pc| at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]).abs }.sum / activePcs.size;
			currentCloserToRestThanEt = currentVsRest <= currentVsEt;
			st[\lastMultiReentryReport] = (
				timestamp: Main.elapsedTime,
				activePcs: activePcs.copy,
				chosenAnchorPc: anchorPc,
				referenceRestAnchorPhase: refPhase[anchorPc],
				currentAnchorPhase: st[\nodePhase][anchorPc],
				anchorMatchedRest: anchorMatched,
				currentVsRestDistance: currentVsRest,
				currentVsEtDistance: currentVsEt,
				currentCloserToRestThanEt: currentCloserToRestThanEt,
				restWasNonEt: currentVsEt > 0.000001
			);
		};
	};

	at[\resolveOnsetFirstFieldNow] = { |midi=nil, reason=\noteOnOnsetFirst|
		// A frequency entering the world is the causal event. The active note
		// has already been registered before this runs, so silent pitch
		// classes respond immediately as passive harmonic possibility.
		// Only active/heard material pushes; passive response does not push.
		if(at[\timedOnsetFirstResolve].notNil) {
			at[\timedOnsetFirstResolve].(midi, reason);
		} {
			if(at[\settleForCurrentConstraints].notNil) {
				at[\settleForCurrentConstraints].(reason);
				if(at[\forceCurrentFieldToTargetNow].notNil) { at[\forceCurrentFieldToTargetNow].(reason); };
			};
		};
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
		nil;
	};

	// ------------------------------------------------------------
	// onset batching and onset-first current commit
	// ------------------------------------------------------------

	at[\beginOnsetBatch] = { |reason=\batchOnset|
		st[\noteOnBatchActive] = true;
		st[\noteOnBatchReason] = reason;
		st[\noteOnBatchPendingMidis] = Array.new;
		nil;
	};

	at[\flushOnsetBatch] = { |reason=\batchedChordOnsetFirst|
		var pending;
		pending = (st[\noteOnBatchPendingMidis] ? Array.new).copy;
		st[\noteOnBatchActive] = false;
		st[\noteOnBatchPendingMidis] = Array.new;
		if(pending.notEmpty) {
			if(at[\finalizeRestFreezeBeforeReentry].notNil) { at[\finalizeRestFreezeBeforeReentry].(); };
			if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(reason); };
			if(at[\resolveOnsetFirstFieldNow].notNil) { at[\resolveOnsetFirstFieldNow].(pending[0], reason); };
			pending.do { |midi|
				var note, pc;
				note = st[\activeNotes][midi];
				if(note.notNil) {
					pc = note[\pc];
					if(st[\nodePhase].notNil) {
						note[\protectedPhase] = st[\nodePhase][pc];
						note[\heldInitialPhase] = st[\nodePhase][pc];
						note[\heldInitialDevCents] = (at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0);
						st[\activeNotes][midi] = note;
					};
					if(st[\voices][midi].isNil) { at[\spawnVoice].(midi, note[\velocity]); };
				};
			};
			if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
			if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
			st[\lastOnsetBatchReport] = (timestamp: Main.elapsedTime, pendingMidis: pending.copy, reason: reason, activeCount: st[\activeNotes].size);
		};
		pending;
	};

	at[\endOnsetBatch] = { |reason=\batchedChordOnsetFirst|
		at[\flushOnsetBatch].(reason);
	};

	at[\cancelResidualTargetMotionForRelease] = { |reason=\beforeReleasePreserve|
		if((cfg[\field][\cancelTargetMotionOnRelease] ? true) and: { st[\motionActive] == true }) {
			// Release is not a tuning cause. Preserve the current field exactly
			// instead of letting a stale target keep charging after the sound left.
			st[\targetPhase] = st[\nodePhase].copy;
			st[\targetCoreUnwrappedPhase] = (st[\coreUnwrappedPhase] ? st[\nodePhase]).copy;
			st[\lastSolvedPhase] = st[\nodePhase].copy;
			st[\motionActive] = false;
			st[\lastFieldAction] = reason;
			if(at[\pushBuses].notNil) { at[\pushBuses].(); };
		};
		nil;
	};

	at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
		var note, prevCount, pc, pendingAnchor, prevMidis, prevMinMidi, now, protectedPhase, pathRec, coreAnchorPhase, coreUnwrappedPhase, batchActive, samePcAlreadyActive;
		prevCount = st[\activeNotes].size;
		prevMidis = at[\activeMidisSorted].();
		prevMinMidi = if(prevMidis.isEmpty) { nil } { prevMidis.minItem };
		pc = midi % 12;
		now = Main.elapsedTime;
		pendingAnchor = nil;
		batchActive = (st[\noteOnBatchActive] ? false) == true;
		samePcAlreadyActive = prevMidis.any { |m| (m % 12) == pc };

		// A batched chord onset is one harmonic object, not a fake arpeggio path.
		// A same-pitch-class octave duplicate is also not a melodic/transport path;
		// it reinforces the same pc center as another register voice.
		pathRec = if(batchActive or: { samePcAlreadyActive or: { at[\motionAmount].notNil and: { at[\motionAmount].() <= 0.0 } } }) {
			nil;
		} {
			if(at[\prepareCorePathOnset].notNil) {
				at[\prepareCorePathOnset].(midi, pc, prevCount, now)
			} { nil }
		};
		coreAnchorPhase = if(pathRec.notNil and: { pathRec[\audiblePhase].notNil }) {
			pathRec[\audiblePhase]
		} {
			if((prevCount == 0) and: { at[\presentTenseEntryPhase].notNil }) { at[\presentTenseEntryPhase].(midi, pc, explicitFreq) } { st[\nodePhase][pc] }
		};
		coreUnwrappedPhase = if(pathRec.notNil and: { pathRec[\desiredUnwrappedPhase].notNil }) {
			pathRec[\desiredUnwrappedPhase]
		} {
			if((prevCount == 0) and: { at[\presentTenseEntryPhase].notNil }) { at[\presentTenseEntryPhase].(midi, pc, explicitFreq) } { (st[\coreUnwrappedPhase] ? st[\nodePhase])[pc] }
		};

		if(prevCount == 0) {
			at[\finalizeRestFreezeBeforeReentry].();
			if(st[\frozenValid] == true) {
				pendingAnchor = st[\frozenPhase][pc];
			};
		};

		protectedPhase = if((prevCount == 0) and: { at[\hasContinuityGlue].notNil and: { at[\hasContinuityGlue].(if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { Array.new }) } and: { (st[\frozenValid] == true) and: { st[\frozenFromEvidence] == true } } }) {
			st[\frozenPhase][pc]
		} {
			coreAnchorPhase
		};

		note = (
			midi: midi,
			pc: pc,
			velocity: velocity.clip(0.0, 1.0),
			referenceFreq: explicitFreq,
			coreAnchorPhase: coreAnchorPhase,
			coreUnwrappedPhase: coreUnwrappedPhase,
			held: true,
			sustainHeld: false,
			onsetTime: now,
			timestamp: now,
			protectedPhase: protectedPhase,
			heldInitialPhase: protectedPhase,
			heldInitialDevCents: (at[\wrapSigned].(protectedPhase - st[\etPhase][pc]) * 1200.0),
			heldElasticIntegratedPressureCentsSec: 0.0,
			heldElasticTotalYieldCents: 0.0,
			heldElasticPeakPressureCents: 0.0
		);

		st[\activeNotes][midi] = note;
		{
			var hist;
			hist = st[\pitchIdentityNoteHistory] ? Array.new;
			hist = hist.add((timestamp: now, midi: midi, pc: pc, pcName: pitchClassNames[pc], coreAnchorPhase: coreAnchorPhase, coreUnwrappedPhase: coreUnwrappedPhase, batched: batchActive));
			if(hist.size > 64) { hist = hist.copyRange(hist.size - 64, hist.size - 1); };
			st[\pitchIdentityNoteHistory] = hist;
		}.value;
		if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(if(batchActive) { \batchedNoteOn } { \noteOn }); };

		st[\lastOnsetInfo] = (
			midi: midi,
			pc: pc,
			timestamp: now,
			prevCount: prevCount,
			prevMidis: prevMidis.copy,
			prevMinMidi: prevMinMidi,
			wasLowerOnset: (prevCount > 0) and: { prevMinMidi.notNil and: { midi < prevMinMidi } },
			batched: batchActive,
			consumed: samePcAlreadyActive
		);

		if(batchActive) {
			st[\noteOnBatchPendingMidis] = (st[\noteOnBatchPendingMidis] ? Array.new).add(midi);
		} {
			if(samePcAlreadyActive) {
				// Same-pitch-class octave/register duplication is not a new harmonic
				// center and not a phrase interval. It adds a voice/register weight
				// to the existing pc center without causing transport or passive drift.
				if((suppressVoice.not) and: { st[\voices][midi].isNil }) {
					at[\spawnVoice].(midi, note[\velocity]);
				};
				at[\acceptSamePcEvidenceKeyWithoutResolve].(\samePcDuplicateOnset);
				st[\lastSamePcOctaveReport] = (
					timestamp: Main.elapsedTime,
					event: \noteOnDuplicate,
					midi: midi,
					pc: pc,
					survivorMidis: at[\activeMidisForPc].(pc, midi),
					activeVoiceCount: st[\activeNotes].size,
					activePcCount: at[\activePcsFromWeights].(at[\pcWeights].()).size,
					transportSuppressed: true,
					reason: \samePcOctaveReinforcement
				);
				if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
				diag[\log].("noteOn samePcDuplicate " ++ midi.asString);
				if(at[\pushBuses].notNil) { at[\pushBuses].(); };
				if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
			} {
				at[\resolveOnsetFirstFieldNow].(midi, \noteOnOnsetFirst);
				if(st[\activeNotes][midi].notNil) {
					note = st[\activeNotes][midi];
					if(st[\nodePhase].notNil) {
						note[\protectedPhase] = st[\nodePhase][pc];
						note[\heldInitialPhase] = st[\nodePhase][pc];
						note[\heldInitialDevCents] = (at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0);
						st[\activeNotes][midi] = note;
					};
				};

				if((prevCount == 0) and: { at[\hasContinuityGlue].notNil and: { at[\hasContinuityGlue].(if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { Array.new }) } and: { (st[\frozenValid] == true) and: { st[\frozenFromEvidence] == true } } }) {
					st[\singletonReentryPending] = (
						midi: midi,
						pc: pc,
						anchorPhase: st[\frozenPhase][pc],
						timestamp: Main.elapsedTime
					);
				} {
					st[\singletonReentryPending] = nil;
				};

				if((suppressVoice.not) and: { st[\voices][midi].isNil }) {
					at[\spawnVoice].(midi, note[\velocity]);
				};

				if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
				diag[\log].("noteOn " ++ midi.asString);
				if((cfg[\input][\immediateDirectNoteCalls] ? false) == true) { api[\resolveNow].(\noteOn); };
				at[\recordSingleReentryReportIfNeeded].(prevCount, midi, pc, pendingAnchor);
				at[\recordMultiReentryReportIfNeeded].(prevCount);
			};
		};
	};

	at[\noteOff] = { |midi|
		var note, prevMidis, prevVoices, pc, samePcSurvivors;
		note = st[\activeNotes][midi];
		prevMidis = at[\activeMidisSorted].();
		prevVoices = st[\voices].copy;
		pc = if(note.notNil) { note[\pc] } { midi % 12 };
		samePcSurvivors = if(note.notNil) { at[\activeMidisForPc].(pc, midi) } { Array.new };

		// A release is not the causal tuning event. Stop any residual target
		// chase before removing evidence, so the world does not appear to tune
		// after the frequency has left.
		if(at[\cancelResidualTargetMotionForRelease].notNil) { at[\cancelResidualTargetMotionForRelease].(\noteOffPreserveCurrent); };

		if(note.notNil) {
			if(st[\sustainDown]) {
				note[\held] = false;
				note[\sustainHeld] = true;
				st[\activeNotes][midi] = note;
			} {
				st[\activeNotes].removeAt(midi);
				at[\releaseVoice].(midi);

				if(samePcSurvivors.notEmpty) {
					// Releasing one octave/register duplicate while another same-PC
					// voice is still held does not remove the pitch-class evidence.
					// It changes voice count, not harmonic center, and must not trigger
					// a new solve, phrase transport, rest freeze, or release drift.
					at[\acceptSamePcEvidenceKeyWithoutResolve].(\samePcDuplicateRelease);
					st[\lastSamePcOctaveReport] = (
						timestamp: Main.elapsedTime,
						event: \noteOffDuplicate,
						midi: midi,
						pc: pc,
						survivorMidis: samePcSurvivors.copy,
						activeVoiceCount: st[\activeNotes].size,
						activePcCount: at[\activePcsFromWeights].(at[\pcWeights].()).size,
						transportSuppressed: true,
						reason: \samePcOctaveReleasePreservesCenter
					);
					if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
					diag[\log].("noteOff samePcDuplicate " ++ midi.asString);
					at[\recordSurvivorContinuityIfNeeded].(prevMidis, prevVoices);
					if(at[\pushBuses].notNil) { at[\pushBuses].(); };
					if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
				} {
					if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\noteOff); };
					if(st[\activeNotes].size == 0) { st[\singletonReentryPending] = nil; };
					if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
					diag[\log].("noteOff " ++ midi.asString);
					if((cfg[\input][\immediateDirectNoteCalls] ? false) == true) { api[\resolveNow].(\noteOff); };
					at[\recordSurvivorContinuityIfNeeded].(prevMidis, prevVoices);
					at[\beginRestFreezeMonitorIfNeeded].(prevMidis);
					if(st[\activeNotes].size == 0) {
						if(at[\freezeCurrentField].notNil) { at[\freezeCurrentField].(); };
						if(at[\pushBuses].notNil) { at[\pushBuses].(); };
						if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(true); };
					};
				};
			};
		};
	};
	at[\removeInactiveSustainNotes] = {
		var toDrop, prevMidis, prevVoices;
		toDrop = Array.new;
		prevMidis = at[\activeMidisSorted].();
		prevVoices = st[\voices].copy;

		st[\activeNotes].keysValuesDo { |midi, note|
			if(note[\held].not and: { note[\sustainHeld] }) {
				toDrop = toDrop.add(midi);
			};
		};

		if(toDrop.notEmpty) {
			if(at[\cancelResidualTargetMotionForRelease].notNil) { at[\cancelResidualTargetMotionForRelease].(\sustainReleasePreserveCurrent); };
		};

		toDrop.do { |midi|
			st[\activeNotes].removeAt(midi);
			if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\sustainRelease); };
			at[\releaseVoice].(midi);
		};

		if(st[\activeNotes].size == 0) { st[\singletonReentryPending] = nil; };

		if(toDrop.notEmpty) {
			if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
			diag[\log].("sustain release dropped " ++ toDrop.asString);
			if((cfg[\input][\immediateDirectNoteCalls] ? false) == true) { api[\resolveNow].(\sustainRelease); };
			at[\recordSurvivorContinuityIfNeeded].(prevMidis, prevVoices);
			at[\beginRestFreezeMonitorIfNeeded].(prevMidis);
		};
	};

	at[\micStep] = {
		var sources, key, primaryExternal;

		if(st[\micSelfIgnoreFramesRemaining] > 0) {
			st[\micSelfIgnoreFramesRemaining] = st[\micSelfIgnoreFramesRemaining] - 1;
		};

		// Deterministic mic/source demo helpers may install candidates directly into
		// updateCommittedExternalSources. While that test flag is true, do not let
		// the physical mic polling path immediately overwrite/clear committed
		// sources with an empty live-input frame. Normal live mic operation is unchanged.
		if((st[\micManualCandidateFeed] ? false).not) {
			if(at[\refreshMicObservation].notNil) { at[\refreshMicObservation].(); };
		};
		sources = if(at[\currentExternalSources].notNil) { at[\currentExternalSources].() } { Array.new };
		primaryExternal = at[\strongestExternalSource].(sources);
		key = at[\micKeyForSources].(sources);

		if(key != st[\lastMicKey]) {
			st[\lastMicKey] = key;
			if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\micChanged); };
			if(primaryExternal.isNil) {
				diag[\log].("mic external cleared policy=" ++ cfg[\mic][\influencePolicy].asString);
			} {
				diag[\log].("mic evidence changed count=" ++ sources.size.asString ++ " strongestPc=" ++ primaryExternal[\pc].asString ++ " freq=" ++ st[\micRawFreq].round(0.1).asString ++ " mode=" ++ cfg[\mic][\mode].asString ++ " policy=" ++ cfg[\mic][\influencePolicy].asString);
			};
		};

		if(api[\refreshUISnapshot].notNil) {
			api[\refreshUISnapshot].();
		};
	};

	at[\start] = {
		if(st[\controlRoutine].notNil) {
			st[\controlRoutine].stop;
		};

		at[\pushBuses].();
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };

		st[\controlRoutine] = Routine({
			inf.do {
				if(cfg[\mic][\enabled]) {
					at[\micStep].();
				};
				if(at[\fieldTick].notNil) {
					at[\fieldTick].();
				};
				if(at[\motionStepToTarget].notNil and: { st[\motionActive] == true }) {
					at[\motionStepToTarget].();
				};
				if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
				(cfg[\motion][\dt] ? cfg[\mic][\pollDt]).wait;
			};
		}).play(SystemClock);
	};

	at[\stop] = {
		if(st[\controlRoutine].notNil) {
			st[\controlRoutine].stop;
			st[\controlRoutine] = nil;
		};
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
	};


	// ------------------------------------------------------------
	// MIDI
	// ------------------------------------------------------------

	at[\installMIDI] = {
		var sources;
		MIDIClient.init;
		MIDIIn.connectAll;

		// Reinstall definitions after connectAll so repeated reloads do not leave
		// stale responders or disconnected sources. This is the authoritative live
		// MIDI entry point; diagnostics must not mutate it.
		MIDIdef(\atnoteon).free;
		MIDIdef(\atnoteoff).free;
		MIDIdef(\atcc).free;

		MIDIdef.noteOn(\atnoteon, { |vel, num, chan, src|
			st[\lastMidiEvent] = (
				type: \noteOn,
				vel: vel,
				num: num,
				chan: chan,
				src: src,
				timestamp: Main.elapsedTime
			);
			if((cfg[\input][\postMidiEvents] ? true) == true) {
				("[at-midi] noteOn num=" ++ num.asString ++ " vel=" ++ vel.asString ++ " chan=" ++ chan.asString).postln;
			};
			if(vel > 0) {
				at[\noteOn].(num, vel / 127.0, nil);
			} {
				at[\noteOff].(num);
			};
		});

		MIDIdef.noteOff(\atnoteoff, { |vel, num, chan, src|
			st[\lastMidiEvent] = (
				type: \noteOff,
				vel: vel,
				num: num,
				chan: chan,
				src: src,
				timestamp: Main.elapsedTime
			);
			if((cfg[\input][\postMidiEvents] ? true) == true) {
				("[at-midi] noteOff num=" ++ num.asString ++ " vel=" ++ vel.asString ++ " chan=" ++ chan.asString).postln;
			};
			at[\noteOff].(num);
		});

		MIDIdef.cc(\atcc, { |val, num, chan, src|
			var x;
			st[\lastMidiEvent] = (
				type: \cc,
				val: val,
				num: num,
				chan: chan,
				src: src,
				timestamp: Main.elapsedTime
			);

			x = val / 127.0;

			if(num == 1) {
				api[\setTension].(x.clip(0.0, 1.0));
			};

			if(num == 3) {
				api[\setMicGain].(x.linexp(0.0, 1.0, 0.25, 6.0));
			};

			if(num == 4) {
				api[\setMicEnabled].(x > 0.5);
			};

			if(num == 5) {
				api[\setMicWeight].(x.clip(0.0, 1.0));
			};

			if(num == 64) {
				if(val >= 64) {
					st[\sustainDown] = true;
				} {
					st[\sustainDown] = false;
					at[\removeInactiveSustainNotes].();
				};
			};

			if(num == 123) {
				st[\sustainDown] = false;
				st[\activeNotes].clear;
				st[\singletonReentryPending] = nil;
					if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\allNotesOff); };
					at[\allVoicesOff].();
				if((cfg[\input][\immediateDirectNoteCalls] ? false) == true) { api[\resolveNow].(\allNotesOff); };
			};
		});

		sources = MIDIClient.sources;
		("[at-midi] installed; sources=" ++ sources.collect { |ep| ep.device ++ ":" ++ ep.name }.asString).postln;
		nil
	};

};
)
