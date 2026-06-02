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

	at[\noteOn] = { |midi, velocity=0.8, explicitFreq=nil, suppressVoice=false|
		var note, prevCount, pc, pendingAnchor, prevMidis, prevMinMidi, now, protectedPhase, pathRec, coreAnchorPhase, coreUnwrappedPhase;
		prevCount = st[\activeNotes].size;
		prevMidis = at[\activeMidisSorted].();
		prevMinMidi = if(prevMidis.isEmpty) { nil } { prevMidis.minItem };
		pc = midi % 12;
		now = Main.elapsedTime;
		pendingAnchor = nil;

		// Natural naked-core path interpretation. This does not shift the world as
		// a separate effect and it is not a mode: the new note enters the lived
		// harmonic field on the sheet implied by the immediately played path.
		pathRec = if(at[\prepareCorePathOnset].notNil) {
			at[\prepareCorePathOnset].(midi, pc, prevCount, now)
		} { nil };
		coreAnchorPhase = if(pathRec.notNil and: { pathRec[\audiblePhase].notNil }) { pathRec[\audiblePhase] } { st[\nodePhase][pc] };
		coreUnwrappedPhase = if(pathRec.notNil and: { pathRec[\desiredUnwrappedPhase].notNil }) { pathRec[\desiredUnwrappedPhase] } { (st[\coreUnwrappedPhase] ? st[\nodePhase])[pc] };

		if(prevCount == 0) {
			at[\finalizeRestFreezeBeforeReentry].();
			if(st[\frozenValid] == true) {
				pendingAnchor = st[\frozenPhase][pc];
			};
		};

		protectedPhase = if((prevCount == 0) and: { (st[\frozenValid] == true) and: { st[\frozenFromEvidence] == true } }) {
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
			// Absolute phase captured at note entry. Long-held active notes
			// use this as a total-drift guard during later harmonic changes.
			protectedPhase: protectedPhase,
			heldInitialPhase: protectedPhase,
			heldInitialDevCents: (at[\wrapSigned].(protectedPhase - st[\etPhase][pc]) * 1200.0),
			heldElasticIntegratedPressureCentsSec: 0.0,
			heldElasticTotalYieldCents: 0.0,
			heldElasticPeakPressureCents: 0.0
		);

		st[\activeNotes][midi] = note;
		if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\noteOn); };

		st[\lastOnsetInfo] = (
			midi: midi,
			pc: pc,
			timestamp: now,
			prevCount: prevCount,
			prevMidis: prevMidis.copy,
			prevMinMidi: prevMinMidi,
			wasLowerOnset: (prevCount > 0) and: { prevMinMidi.notNil and: { midi < prevMinMidi } },
			consumed: false
		);

		if((prevCount == 0) and: { (st[\frozenValid] == true) and: { st[\frozenFromEvidence] == true } }) {
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

	at[\noteOff] = { |midi|
		var note, prevMidis, prevVoices;
		note = st[\activeNotes][midi];
		prevMidis = at[\activeMidisSorted].();
		prevVoices = st[\voices].copy;

		if(note.notNil) {
			if(st[\sustainDown]) {
				note[\held] = false;
				note[\sustainHeld] = true;
				st[\activeNotes][midi] = note;
			} {
				st[\activeNotes].removeAt(midi);
				if(at[\markEvidenceDirty].notNil) { at[\markEvidenceDirty].(\noteOff); };
				if(st[\activeNotes].size == 0) { st[\singletonReentryPending] = nil; };
				at[\releaseVoice].(midi);
				if(at[\markMicSelfIgnore].notNil) { at[\markMicSelfIgnore].(); };
				diag[\log].("noteOff " ++ midi.asString);
				if((cfg[\input][\immediateDirectNoteCalls] ? false) == true) { api[\resolveNow].(\noteOff); };
				at[\recordSurvivorContinuityIfNeeded].(prevMidis, prevVoices);
				at[\beginRestFreezeMonitorIfNeeded].(prevMidis);
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

		// Deterministic mic/source acceptance tests inject candidates directly into
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
