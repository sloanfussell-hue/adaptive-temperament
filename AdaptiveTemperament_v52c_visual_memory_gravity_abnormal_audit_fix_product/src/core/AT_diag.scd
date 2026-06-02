(
// AT_diag.scd
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
	// diagnostics helpers
	// ------------------------------------------------------------

	diag[\log] = { |msg|
		if(st[\logEnabled]) {
			("[AT] " ++ msg).postln;
		};
	};


diag[\dumpState] = {
		var snap;
		snap = api[\uiSnapshot].();
		"--- Adaptive Temperament State ---".postln;
		snap.keysValuesDo { |k, v|
			(k.asString ++ ": " ++ v.asString).postln;
		};
	};

	diag[\dumpFrozen] = {
		(
			frozenValid: st[\frozenValid],
			frozenPhase: st[\frozenPhase].collect { |x| x.round(0.0001) }
		).postln;
	};

	at[\resetDiagnosticSandbox] = {
		st[\stateLabel] = \neutral;
		st[\sustainDown] = false;
		st[\frozenValid] = false;
		st[\soleAnchorPc] = nil;
		st[\soleAnchorPhase] = nil;
		st[\singletonReentryPending] = nil;
		st[\activeNotes] = IdentityDictionary.new;
		st[\voices] = IdentityDictionary.new;
		st[\nodePhase] = st[\etPhase].copy;
		st[\frozenPhase] = st[\etPhase].copy;
		st[\targetPhase] = st[\etPhase].copy;
		st[\lastSolvedPhase] = st[\etPhase].copy;
		st[\targetValid] = false;
		st[\motionActive] = false;
		st[\lastDelta] = Array.fill(cfg[\solver][\numNodes], 0.0);
		st[\nodeMotion] = Array.fill(cfg[\solver][\numNodes], 0.0);
		st[\nodeAlignment] = Array.fill(cfg[\solver][\numNodes], 1.0);
		st[\nodeStability] = Array.fill(cfg[\solver][\numNodes], 1.0);
		st[\lastOnsetInfo] = nil;
		st[\lastGaugeCarry] = nil;
		st[\lastEvidence] = nil;
		st[\lastEvidenceKey] = nil;
		st[\evidenceDirty] = false;
		st[\lastFieldResolveAt] = nil;
		if(at[\clearTonalMemory].notNil) { at[\clearTonalMemory].(); };
	};

	at[\withDiagnosticSandbox] = { |fn|
		var saved, result;
		saved = IdentityDictionary.new;
		[
			\stateLabel, \sustainDown, \frozenValid, \soleAnchorPc, \soleAnchorPhase,
			\singletonReentryPending, \activeNotes, \voices, \nodePhase, \frozenPhase,
			\targetPhase, \lastSolvedPhase, \targetValid, \motionActive, \lastDelta,
			\nodeMotion, \nodeAlignment, \nodeStability, \memoryPhase, \memoryValid,
			\memoryConfidence, \memoryLastUpdateAt, \memoryLastDistance, \memoryLastInfluence,
			\memoryLastLearnRate, \memoryLastReason, \memorySupportCounts, \lastOnsetInfo,
			\lastGaugeCarry, \lastEvidence, \lastEvidenceKey, \evidenceDirty,
			\evidenceDirtyReason, \evidenceDirtyAt, \lastFieldResolveAt,
			\diagnosticRootByActiveSet, \diagnosticRootLastPc, \lastRestFreezeReport,
			\lastReentryReport, \lastMultiReentryReport, \lastSurvivorReport,
			\lastRestFreezePhase, \lastReentryAt
		].do { |key|
			var val;
			val = st[key];
			if(val.respondsTo(\copy)) { val = val.copy; };
			saved[key] = val;
		};

		at[\resetDiagnosticSandbox].();
		result = fn.value;

		saved.keysValuesDo { |key, val| st[key] = val; };
		if(at[\pushBuses].notNil) { at[\pushBuses].(); };
		if(api[\refreshUISnapshot].notNil) { api[\refreshUISnapshot].(); };
		result;
	};

	diag[\runSingleNoteTest] = {
		at[\withDiagnosticSandbox].({
			var snap, devCents, pc;
			at[\noteOn].(60, 0.8, nil, true);
			if(at[\snapCurrentToTarget].notNil) { at[\snapCurrentToTarget].(\diagnostic); };
			snap = api[\uiSnapshot].();
			pc = 60 % 12;
			devCents = snap[\etDeviationCents][pc];
			("[single-note-test/sandbox] pc=" ++ pc.asString ++ " devCents=" ++ devCents.round(0.001).asString ++
				" maxLastDelta=" ++ snap[\maxLastDelta].round(0.000001).asString).postln;
		});
	};

	diag[\runTriadTest] = {
		at[\withDiagnosticSandbox].({
			var root, third, fifth, cToE, eToG, cToG;
			at[\noteOn].(60, 0.8, nil, true);
			at[\noteOn].(64, 0.8, nil, true);
			at[\noteOn].(67, 0.8, nil, true);
			if(at[\snapCurrentToTarget].notNil) { at[\snapCurrentToTarget].(\diagnostic); };

			root = st[\nodePhase][0];
			third = st[\nodePhase][4];
			fifth = st[\nodePhase][7];

			cToE = (at[\wrapSigned].(third - root) * 1200.0).round(0.01);
			eToG = (at[\wrapSigned].(fifth - third) * 1200.0).round(0.01);
			cToG = (at[\wrapSigned].(fifth - root) * 1200.0).round(0.01);

			("[triad-test/sandbox] C-E=" ++ cToE.asString ++ "  E-G=" ++ eToG.asString ++ "  C-G=" ++ cToG.asString ++
				"  maxMotion=" ++ st[\nodeMotion].maxItem.round(0.000001).asString).postln;
		});
	};

	diag[\runFifthChainTest] = {
		at[\withDiagnosticSandbox].({
			var pcs, initialPhase, finalIsolated, finalTied, i;
			pcs = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5, 0];

			initialPhase = st[\nodePhase][0];
			pcs.do { |pc|
				at[\noteOn].(60 + pc, 0.8, nil, true);
				if(at[\snapCurrentToTarget].notNil) { at[\snapCurrentToTarget].(\diagnostic); };
				at[\noteOff].(60 + pc);
			};

			finalIsolated = (at[\wrapSigned].(st[\nodePhase][0] - initialPhase) * 1200.0).round(0.01);

			at[\resetDiagnosticSandbox].();
			initialPhase = st[\nodePhase][0];

			i = 0;
			while { i < (pcs.size - 1) } {
				var a, b;
				a = 60 + pcs[i];
				b = 60 + pcs[i + 1];
				at[\noteOn].(a, 0.8, nil, true);
				at[\noteOn].(b, 0.8, nil, true);
				if(at[\snapCurrentToTarget].notNil) { at[\snapCurrentToTarget].(\diagnostic); };
				at[\noteOff].(a);
				i = i + 1;
			};
			at[\noteOff].(60 + pcs.last);

			finalTied = (at[\wrapSigned].(st[\nodePhase][0] - initialPhase) * 1200.0).round(0.01);

			("[fifth-chain-test/sandbox] isolated=" ++ finalIsolated.asString ++ " cents, tied=" ++ finalTied.asString ++ " cents").postln;
		});
	};

	diag[\runMicSanityTest] = {
		at[\refreshMicObservation].();
		("[mic-sanity] enabled=" ++ cfg[\mic][\enabled].asString ++
			" mode=" ++ cfg[\mic][\mode].asString ++
			" voiced=" ++ st[\micVoiced].asString ++
			" freq=" ++ st[\micRawFreq].round(0.1).asString ++
			" amp=" ++ st[\micRawAmp].round(0.0001).asString ++
			" pc=" ++ st[\micPc].asString ++
			" conf=" ++ st[\micConfidence].round(0.001).asString ++
			" candidates=" ++ (st[\micCandidates] ? Array.new).size.asString ++
			" activeExternal=" ++ (st[\externalSources] ? Array.new).size.asString).postln;
	};

	// flat compatibility
	at[\debugState] = { diag[\dumpState].(); };
	at[\reset] = { api[\reset].(); };
	at[\hardReset] = { api[\hardReset].(); };


		// ------------------------------------------------------------
		// acceptance battery report helpers
		// Diagnostics only; they do not alter tuning state.
		// ------------------------------------------------------------
		diag[\printLastSurvivorReport] = {
			var r;
			r = st[\lastSurvivorReport];
			if(r.isNil) { "[AT BATTERY] survivor report: nil".postln } { ("[AT BATTERY] survivor report: " ++ r.asString).postln };
			r
		};
	
		diag[\assertLastSurvivorReportPasses] = {
			var r;
			r = st[\lastSurvivorReport];
			r.notNil and: { r[\survivorKeptSameInstance] == true } and: { r[\releasedAllGone] == true }
		};
	
		diag[\printLastRestFreezeReport] = {
			var r;
			r = st[\lastRestFreezeReport];
			if(r.isNil) { "[AT BATTERY] rest freeze report: nil".postln } { ("[AT BATTERY] rest freeze report: " ++ r.asString).postln };
			r
		};
	
		diag[\assertLastRestFreezeReportPasses] = {
			var r;
			r = st[\lastRestFreezeReport];
			r.notNil and: { r[\freezeHeld] == true }
		};
	
		diag[\printLastReentryReport] = {
			var r;
			r = st[\lastReentryReport];
			if(r.isNil) { "[AT BATTERY] single reentry report: nil".postln } { ("[AT BATTERY] single reentry report: " ++ r.asString).postln };
			r
		};
	
		diag[\assertLastReentryReportPasses] = {
			var r;
			r = st[\lastReentryReport];
			r.notNil and: { r[\installedMatchedRest] == true } and: { r[\restWasNonEt] == true }
		};
	
		diag[\printLastMultiReentryReport] = {
			var r;
			r = st[\lastMultiReentryReport];
			if(r.isNil) { "[AT BATTERY] multi reentry report: nil".postln } { ("[AT BATTERY] multi reentry report: " ++ r.asString).postln };
			r
		};
	
		diag[\assertLastMultiReentryReportPasses] = {
			var r;
			r = st[\lastMultiReentryReport];
			r.notNil and: { r[\anchorMatchedRest] == true } and: { r[\currentCloserToRestThanEt] == true } and: { r[\restWasNonEt] == true }
		};
};
)
