(
// AT_solver_transport.scd
// Behavior-preserving split from AT_solver.scd.
var build, at, cfg, st, api, diag, ui, pitchClassNames;

build = ~atBuild;

if(build.isNil) {
    "[at] ~atBuild missing. Load AdaptiveTemperament_run.scd first.".warn;
} {
    at = build[\at];
    cfg = build[\cfg];
    st = build[\state];
    api = build[\api];
    diag = build[\diag];
    ui = build[\ui];
    pitchClassNames = at[\pitchClassNames];

    	at[\transportActiveCentroidCents] = { |activePcs|
    		var vals, sum;
    		vals = Array.new;
    		(activePcs ? Array.new).do { |pc| vals = vals.add(at[\wrapSigned].(st[\nodePhase][pc] - st[\etPhase][pc]) * 1200.0); };
    		if(vals.isEmpty) { 0.0 } {
    			sum = 0.0;
    			vals.do { |x| sum = sum + x; };
    			sum / vals.size.asFloat.max(1.0)
    		}
    	};


    	// v2j: product-safe common-tone continuity helper. Several split-core
    	// transport paths query common-tone continuity during background live
    	// catch-up. In older monolithic builds this helper could be present from
    	// a different load path; in this product build it must be total here.
    	// No frozen context means no common-tone support, not nil arithmetic.
    	// v2j: transport-live numerical totality. The audible timbre audition
    	// exercises background live catch-up with real sustained chords. In this
    	// product load path some older split-core memory/transport helpers may be
    	// absent. These fallbacks are intentionally conservative: missing evidence
    	// becomes 0 support or reduced raw target, never nil arithmetic and never
    	// new pitch/tuning authority.
    	at[\safeNumber] = at[\safeNumber] ? { |x=nil, fallback=0.0|
    		if(x.isNumber) { x } { fallback }
    	};

    	at[\commonToneRatioWithFrozen] = at[\commonToneRatioWithFrozen] ? { |activePcs=nil|
    		var cur, prev, hits, denom;
    		cur = (activePcs ? Array.new).collect { |p| p.asInteger % 12 }.as(Set).asArray;
    		prev = (st[\lastFrozenActivePcs] ? Array.new).collect { |p| p.asInteger % 12 }.as(Set).asArray;
    		if(cur.isEmpty or: { prev.isEmpty }) {
    			0.0
    		} {
    			hits = 0;
    			cur.do { |pc| if(prev.includes(pc)) { hits = hits + 1; }; };
    			denom = cur.size.asFloat.max(1.0);
    			(hits.asFloat / denom).clip(0.0, 1.0)
    		}
    	};

    	at[\selectiveMemoryGaugeCents] = at[\selectiveMemoryGaugeCents] ? { |activePcs=nil, rawCents=0.0, support=0.0, reason=\internal|
    		var safeRaw, safeSupport, chosen;
    		safeRaw = at[\safeNumber].(rawCents, 0.0);
    		safeSupport = at[\safeNumber].(support, 0.0).clip(0.0, 1.0);
    		chosen = safeRaw * safeSupport;
    		st[\lastSelectiveMemoryReport] = (
    			timestamp: Main.elapsedTime,
    			reason: reason ? \internal,
    			rawCents: safeRaw,
    			support: safeSupport,
    			exactMemoryCents: nil,
    			commonToneGaugeCents: nil,
    			chosenGaugeCents: chosen,
    			activePcs: (activePcs ? Array.new).copy,
    			fallback: \reducedRawNoMemoryHelper
    		);
    		chosen
    	};

		// at17bg: control ecology readout for transport decisions. This is diagnostic
		// and functional glue, not a selectable mode. High freedom means the existing
		// controls are permissive: high Motion, low memory/gravity/mic/tension.
		at[\transportEcologySnapshot] = {
			var motion, carry, memory, gravity, mic, tension, freedom, inhibition;
			motion = (st[\movement] ? 0.82).clip(0.0, 1.0);
			// v38 final demo: Carry is not a separate musical principle here. Keep
			// the legacy value reportable, but do not let freedom depend on it.
			carry = (st[\carryAmount] ? 0.0).clip(0.0, 1.0);
			memory = (st[\memoryAmount] ? (cfg[\perf][\memoryContinuityMacro] ? 0.58)).clip(0.0, 1.0);
			gravity = if(cfg[\gravity].isNil) { 0.0 } { if(cfg[\gravity][\enabled] ? false) { (cfg[\gravity][\strength] ? 0.0).clip(0.0, 1.0) } { 0.0 } };
			mic = if(cfg[\mic][\enabled] ? false) { ((cfg[\mic][\weight] ? 0.0) / 1.2).clip(0.0, 1.0) } { 0.0 };
			tension = (cfg[\solver][\tensionPitchReference] ? 0.55).clip(0.0, 1.0); // v2f: pitch-law reference only; UI Tension is timbre-only
			freedom = ((motion * 0.56) + ((1.0 - memory) * 0.20) + ((1.0 - gravity) * 0.14) + ((1.0 - tension) * 0.06) + ((1.0 - mic) * 0.04)).clip(0.0, 1.0);
			inhibition = (1.0 - freedom).clip(0.0, 1.0);
			(
				freedom: freedom,
				inhibition: inhibition,
				motion: motion,
				carry: carry,
				memory: memory,
				gravity: gravity,
				micAuthority: mic,
				tension: tension
			)
		};

			// at17bh: interval-law transport. This is not a mode and not a chord
			// detector. Fresh onset chains may carry the gauge only according to
			// directed interval ratio-error: pureRatioCents(interval) - ET cents.
			// Thus upward minor thirds tend positive, upward major thirds tend
			// negative, and closed two-note alternations cancel/settle naturally.
			at[\activePhraseIntervalSupport] = { |interval=0|
				var pcStep, table, support;
				pcStep = interval.asInteger.abs % 12;
				// Support/simplicity only. Direction comes from ratio-error below.
				table = [0.0, 0.16, 0.62, 0.88, 0.90, 0.94, 0.32, 1.0, 0.78, 0.78, 0.62, 0.22];
				support = table.wrapAt(pcStep) ? 0.0;
				if(interval.asInteger.abs >= 12) { support = support * 0.78; };
				support.clip(0.0, 1.0)
			};

			at[\activeIntervalRatioInfo] = { |interval=0|
				var semis, sign, absSemis, octs, pcStep, pureTable, purePc, etAbs, pureAbs, signedPure, signedEt, ratioError, support;
				semis = interval.asInteger;
				if(semis == 0) {
					(interval: 0, pcStep: 0, pureCents: 0.0, etCents: 0.0, ratioErrorCents: 0.0, support: 0.0)
				} {
					sign = semis.sign;
					absSemis = semis.abs;
					octs = (absSemis / 12).floor.asInteger;
					pcStep = absSemis % 12;
					// Pure simple-ratio cents for ascending interval classes.
					// 1:16/15, 2:9/8, 3:6/5, 4:5/4, 5:4/3, 6:45/32,
					// 7:3/2, 8:8/5, 9:5/3, 10:16/9, 11:15/8.
					pureTable = [0.0, 111.731, 203.910, 315.641, 386.314, 498.045, 590.224, 701.955, 813.686, 884.359, 996.090, 1088.269];
					purePc = pureTable.wrapAt(pcStep) ? (pcStep * 100.0);
					etAbs = absSemis * 100.0;
					pureAbs = (octs * 1200.0) + purePc;
					signedPure = sign * pureAbs;
					signedEt = sign * etAbs;
					ratioError = signedPure - signedEt;
					support = at[\activePhraseIntervalSupport].(semis);
					(interval: semis, pcStep: pcStep, pureCents: signedPure, etCents: signedEt, ratioErrorCents: ratioError, support: support)
				}
			};

			at[\activePhraseFreedomScale] = {
				var ecology, minFreedom, denom;
				ecology = at[\transportEcologySnapshot].();
				minFreedom = (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54).clip(0.0, 0.98);
				denom = (1.0 - minFreedom).max(0.001);
				(((ecology[\freedom] ? 0.0) - minFreedom) / denom).clip(0.0, 1.0)
			};

			at[\applyActivePhraseTransportOnset] = { |midi, pc, prevMidis=nil, prevCount=0, velocity=0.8|
				var enabled, now, last, window, interval, ratioInfo, intervalSupport, ecology, minFreedom, freeScale, denom;
				var support, strength, cents, rawOffset, applied, oldPending, lowerMidi, lowerAuthority, velWeight;
				var recent, closedPairFactor, prevPrev, prevInterval, ratioError;
				enabled = cfg[\solver][\activePhraseTransportEnabled] ? true;
				now = Main.elapsedTime;
				last = st[\lastActivePhraseOnset];
				window = cfg[\solver][\activePhraseTransportWindow] ? 0.85;
				if(enabled == false) {
					st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
					0.0
				} {
					if(last.isNil or: { (now - (last[\timestamp] ? now)) > window }) {
						st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity);
						st[\lastActivePhraseTransportReport] = (timestamp: now, appliedCents: 0.0, support: 0.0, intervalPressureCents: 0.0, reason: \noRecentInterval);
						0.0
					} {
						interval = midi.asInteger - (last[\midi] ? midi).asInteger;
						if(interval == 0) {
							st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi]));
							0.0
						} {
							ratioInfo = at[\activeIntervalRatioInfo].(interval);
							ratioError = ratioInfo[\ratioErrorCents] ? 0.0;
							intervalSupport = ratioInfo[\support] ? 0.0;
							ecology = at[\transportEcologySnapshot].();
							minFreedom = (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54).clip(0.0, 0.98);
							denom = (1.0 - minFreedom).max(0.001);
							freeScale = (((ecology[\freedom] ? 0.0) - minFreedom) / denom).clip(0.0, 1.0);
							lowerMidi = midi.asInteger.min((last[\midi] ? midi).asInteger);
							lowerAuthority = (1.0 + (((64 - lowerMidi).clip(-24, 36) / 72.0) * (cfg[\solver][\activePhraseLowerAuthority] ? 0.32))).clip(0.72, 1.22);
							velWeight = velocity.clip(0.1, 1.0).sqrt;
							closedPairFactor = 1.0;
							recent = last[\previous];
							if(recent.notNil) {
								prevPrev = recent[\midi];
								prevInterval = (last[\midi] ? midi).asInteger - (prevPrev ? (last[\midi] ? midi)).asInteger;
								if((prevPrev.notNil) and: { midi.asInteger == prevPrev.asInteger and: { interval == (prevInterval * -1) } }) {
									closedPairFactor = cfg[\solver][\activePhraseClosedPairTransport] ? 0.18;
								};
							};
							support = (intervalSupport * freeScale * (ecology[\carry] ? 0.0).sqrt * (ecology[\motion] ? 0.0).sqrt * closedPairFactor).clip(0.0, 1.0);
							strength = cfg[\solver][\activePhraseRatioTransportStrength] ? (cfg[\solver][\activePhraseTransportStrength] ? 0.24);
							cents = ratioError * strength.clip(0.0, 1.5) * support * velWeight * lowerAuthority;
							rawOffset = cents / 1200.0;
							oldPending = st[\activePhraseTransportPendingSupport];
							st[\activePhraseTransportPendingSupport] = support;
							applied = if(rawOffset.abs > 0.0000000001) { at[\applyCoherentGaugeTransport].(rawOffset, \activePhrase, 1.0, 1.0, 1.0, cfg[\solver][\activePhraseTransportInertia] ? 0.0) } { 0.0 };
							st[\activePhraseTransportPendingSupport] = oldPending;
							st[\lastActivePhraseOnset] = (midi: midi, pc: pc, timestamp: now, velocity: velocity, previous: (midi: last[\midi]));
							st[\lastActivePhraseTransportReport] = (
								timestamp: now,
								interval: interval,
								pcStep: ratioInfo[\pcStep] ? 0,
								pureCents: ratioInfo[\pureCents] ? 0.0,
								etCents: ratioInfo[\etCents] ? 0.0,
								intervalPressureCents: ratioError,
								intervalSupport: intervalSupport,
								freedom: ecology[\freedom] ? 0.0,
								freeScale: freeScale,
								support: support,
								closedPairFactor: closedPairFactor,
								lowerAuthority: lowerAuthority,
								requestedCents: cents,
								appliedCents: applied * 1200.0,
								fieldTrueGaugeCents: st[\fieldTrueGaugeCents] ? 0.0,
								selectableSetting: false,
								reason: \directedIntervalRatioPressure
							);
							if((cfg[\solver][\activePhraseTransportReportEnabled] ? true) and: { (cfg[\perf][\liveDiagnostics] ? false) == true }) {
								("[at-transport] interval-law interval=" ++ interval.asString ++ " pressure=" ++ ratioError.round(0.01).asString ++ "c support=" ++ support.round(0.001).asString ++ " applied=" ++ (applied*1200.0).round(0.01).asString ++ "c").postln;
							};
							applied
						}
					}
				}
			};

    	at[\transportSupportScale] = { |reason=\internal, activePcs=nil, externalSources=nil|
    		var hasExternal, common, support, activeCount, ecology, minFreedom, denom, freeScale, phraseSupport;
    		activePcs = activePcs ? at[\activePcsFromWeights].(at[\pcWeights].());
    		externalSources = externalSources ? at[\currentExternalSources].();
    		hasExternal = externalSources.notEmpty;
    		activeCount = activePcs.size;

    		if((cfg[\solver][\causalTransportEnabled] ? true) == false) {
    			1.0
    		} {
    			if(hasExternal or: { reason == \externalEvidence }) {
    				cfg[\solver][\causalExternalSupport] ? 1.0
    			} {
    				if(reason == \activePhrase) {
    					(st[\activePhraseTransportPendingSupport] ? 0.0).clip(0.0, 1.0)
    				} {
    					if(reason == \lowerOnset) {
    						cfg[\solver][\causalLowerOnsetSupport] ? 0.72
    					} {
    						common = (if(at[\commonToneRatioWithFrozen].notNil) { at[\commonToneRatioWithFrozen].(activePcs) } { 0.0 }) ? 0.0;
    						support = if(activeCount <= 1) {
    							cfg[\solver][\causalInternalUnsupportedSupport] ? 0.10
    						} {
    							((cfg[\solver][\causalInternalUnsupportedSupport] ? 0.10)
    								+ ((cfg[\solver][\causalInternalCommonToneFloor] ? 0.20) * common)
    								+ ((cfg[\solver][\causalInternalCommonToneBoost] ? 0.62) * (common * common))).clip(0.0, 1.0)
    						};
    						if(reason == \contextBreak) {
    							support = support * (cfg[\solver][\causalContextBreakSupportScale] ? 0.42);
    						};
    						if(reason == \activeBody) {
    							ecology = at[\transportEcologySnapshot].();
    							minFreedom = (cfg[\solver][\activePhraseTransportMinFreedom] ? 0.54).clip(0.0, 0.98);
    							denom = (1.0 - minFreedom).max(0.001);
    							freeScale = (((ecology[\freedom] ? 0.0) - minFreedom) / denom).clip(0.0, 1.0);
    							phraseSupport = ((cfg[\solver][\activePhraseTransportBodyBoost] ? 0.86) * freeScale * (ecology[\carry] ? 0.0).sqrt * (ecology[\motion] ? 0.0).sqrt).clip(0.0, 1.0);
    							support = (support * (cfg[\solver][\causalActiveBodySupportScale] ? 0.62)).max(phraseSupport);
    						};
    						support.clip(0.0, 1.0)
    					}
    				}
    			}
    		}
    	};

    		at[\causalGaugeForContextRebase] = { |activePcs, externalSources=nil, info=nil|
    		var raw, support, supported, blend, gaugeCents, hasExternal, extGauge;
    		hasExternal = (externalSources ? Array.new).notEmpty;
    		extGauge = if(at[\fieldExternalGaugeCents].notNil) { at[\fieldExternalGaugeCents].(externalSources ? Array.new) } { nil };
    		raw = if(hasExternal and: { extGauge.notNil }) { extGauge } { st[\fieldTrueGaugeCents] ? 0.0 };
    		if((cfg[\solver][\causalContextRebaseEnabled] ? true) == false) {
    			raw / 1200.0
    		} {
    			if(hasExternal and: { extGauge.notNil }) {
    				// External acoustic evidence is real gauge transport. Do not censor it.
    				support = 1.0;
    				supported = raw;
    				blend = 0.0;
    				gaugeCents = raw;
    			} {
    				// r16: context-break rebase uses the separated true gauge, not the
    				// previous nodePhase centroid. This removes old absolute residue while
    				// preserving genuine external/transport gauge when present.
    				support = at[\transportSupportScale].(\contextBreak, activePcs, externalSources);
    				supported = st[\fieldTrueGaugeCents] ? 0.0;
    				blend = 1.0;
    				gaugeCents = supported;
    			};
    			st[\lastCausalTransportReport] = (
    				timestamp: Main.elapsedTime,
    				reason: \contextRebaseGauge,
    				rawGaugeCents: raw,
    				supportedGaugeCents: supported,
    				chosenGaugeCents: gaugeCents,
    				support: support,
    				blend: blend,
    				activePcs: (activePcs ? Array.new).copy,
    				externalCount: (externalSources ? Array.new).size
    			);
    			gaugeCents / 1200.0
    		}
    	};

    	at[\updateCausalTransportState] = { |activePcs=nil, externalSources=nil, reason=\continuous|
    		var centroid, prev, support, follow, next, decay, target, residue, residueThresh, residueDiss;
    		activePcs = activePcs ? at[\activePcsFromWeights].(at[\pcWeights].());
    		activePcs = activePcs ? Array.new;
    		externalSources = externalSources ? at[\currentExternalSources].();
    		externalSources = externalSources ? Array.new;
    		if((cfg[\solver][\causalTransportEnabled] ? true) == true and: { activePcs.notEmpty or: { externalSources.notEmpty } }) {
    			centroid = if(activePcs.notEmpty) { at[\transportActiveCentroidCents].(activePcs) } { at[\medianSignedDeviation].() * 1200.0 };
    			centroid = at[\safeNumber].(centroid, 0.0);
    			prev = at[\safeNumber].(st[\causalTransportGaugeCents], centroid);
    			support = at[\safeNumber].(at[\transportSupportScale].(reason, activePcs, externalSources), 0.0).clip(0.0, 1.0);
    			follow = if(externalSources.notEmpty or: { reason == \externalEvidence }) {
    				cfg[\solver][\causalGaugeExternalFollow] ? 0.34
    			} {
    				if(reason == \lowerOnset) { cfg[\solver][\causalGaugeLowerFollow] ? 0.18 } { cfg[\solver][\causalGaugeFollow] ? 0.08 }
    			};
    			follow = (at[\safeNumber].(follow, 0.0) * support).clip(0.0, 1.0);
    			target = if(externalSources.notEmpty or: { reason == \externalEvidence }) {
    				centroid
    			} {
    				if(at[\selectiveMemoryGaugeCents].notNil) {
    					at[\selectiveMemoryGaugeCents].(activePcs, centroid, support, reason)
    				} {
    					centroid * support
    				}
    			};
    			target = at[\safeNumber].(target, centroid * support);
    			residueThresh = at[\safeNumber].(cfg[\solver][\transportResidueCentroidThreshold], 14.0);
    			residue = externalSources.isEmpty and: { support < 0.38 and: { (centroid - target).abs > residueThresh } };
    			if((cfg[\solver][\transportResidueDissipationEnabled] ? true) and: { residue }) {
    				residueDiss = at[\safeNumber].(cfg[\solver][\transportResidueDissipation], 0.72);
    				follow = follow.max(residueDiss.clip(0.0, 1.0));
    			};
    			next = at[\safeNumber].(prev + ((target - prev) * follow), prev);
    			st[\causalTransportGaugeCents] = next;
    			st[\causalTransportSupport] = support;
    			st[\causalTransportLastCentroid] = centroid;
    			st[\causalTransportLastReason] = reason;
    			if(support < 0.25 and: { externalSources.isEmpty }) {
    				decay = cfg[\solver][\causalVelocityUnsupportedDecay] ? 0.22;
    				st[\fieldGaugeVelocity] = (st[\fieldGaugeVelocity] ? 0.0) * decay.clip(0.0, 1.0);
    			} {
    				if(support < 0.55 and: { externalSources.isEmpty }) {
    					decay = cfg[\solver][\causalVelocityPartialDecay] ? 0.58;
    					st[\fieldGaugeVelocity] = (st[\fieldGaugeVelocity] ? 0.0) * decay.clip(0.0, 1.0);
    				};
    			};
    			if(cfg[\solver][\causalTransportReportEnabled] ? true) {
    				st[\lastCausalTransportReport] = (
    					timestamp: Main.elapsedTime,
    					reason: reason,
    					centroidCents: centroid,
    					targetGaugeCents: target,
    					previousGaugeCents: prev,
    					gaugeCents: next,
    					support: support,
    					follow: follow,
    					residueDissipated: residue,
    					velocityCents: (st[\fieldGaugeVelocity] ? 0.0) * 1200.0,
    					activePcs: activePcs.copy,
    					externalCount: externalSources.size
    				);
    			};
    			next
    		} {
    			st[\causalTransportGaugeCents] ? 0.0
    		}
    	};

    	at[\contextBreakInfo] = { |activePcs, pcWeights=nil, externalSources=nil, phase=\pre|
    		var activeCount, hasExternal, prevPcs, commonRatio, eligible, threshold, minCount, isBreak, reason, activeMax, passiveMax, commonDrift, breakStrength;
    		activePcs = activePcs ? Array.new;
    		activeCount = activePcs.size;
    		hasExternal = (externalSources ? Array.new).notEmpty;
    		prevPcs = st[\lastFrozenActivePcs] ? Array.new;
    		commonRatio = (if(at[\commonToneRatioWithFrozen].notNil) { at[\commonToneRatioWithFrozen].(activePcs) } { 0.0 }) ? 0.0;
    		threshold = cfg[\solver][\contextBreakCommonToneThreshold] ? 0.34;
    		minCount = cfg[\solver][\contextBreakMinActiveCount] ? 3;
    		activeMax = (if(at[\activeMaxDeviationCents].notNil) { at[\activeMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    		passiveMax = (if(at[\passiveMaxDeviationCents].notNil) { at[\passiveMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    		commonDrift = (if(at[\commonToneDriftFromFrozenCents].notNil) { at[\commonToneDriftFromFrozenCents].(activePcs) } { 0.0 }) ? 0.0;
    		eligible = (cfg[\solver][\contextBreakRebaseEnabled] ? true)
    			and: { activeCount >= minCount }
    			and: { prevPcs.notEmpty }
    			and: { st[\frozenValid] == true }
    			and: { ((cfg[\solver][\contextBreakSkipWithExternal] ? true).not) or: { hasExternal.not } };

    		isBreak = false;
    		reason = \none;
    		breakStrength = 0.0;

    		if(eligible) {
    			if(commonRatio <= threshold) {
    				isBreak = true;
    				reason = \lowCommonTone;
    				breakStrength = ((threshold - commonRatio) / threshold.max(0.001)).clip(0.0, 1.0);
    			};
    			if((phase == \pre) and: { activeMax >= (cfg[\solver][\contextBreakPreActiveMaxTriggerCents] ? 18.0) }) {
    				isBreak = true;
    				reason = if(reason == \none) { \preActiveMax } { reason };
    				breakStrength = breakStrength.max(((activeMax - (cfg[\solver][\contextBreakPreActiveMaxTriggerCents] ? 18.0)) / 14.0).clip((cfg[\solver][\contextBreakPreActiveBoostFloor] ? 0.32), 1.0));
    			};
    			if((phase == \pre) and: { commonDrift >= (cfg[\solver][\contextBreakCommonDriftTriggerCents] ? 14.0) }) {
    				isBreak = true;
    				reason = if(reason == \none) { \preCommonDrift } { reason };
    				breakStrength = breakStrength.max(((commonDrift - (cfg[\solver][\contextBreakCommonDriftTriggerCents] ? 14.0)) / 18.0).clip((cfg[\solver][\contextBreakCommonDriftBoostFloor] ? 0.28), 1.0));
    			};
    			if((phase == \post) and: { activeMax >= (cfg[\solver][\contextBreakActiveMaxTriggerCents] ? 18.0) }) {
    				isBreak = true;
    				reason = \postActiveMax;
    				breakStrength = breakStrength.max(((activeMax - (cfg[\solver][\contextBreakActiveMaxTriggerCents] ? 18.0)) / 12.0).clip(0.25, 1.0));
    			};
    			if((phase == \post) and: { passiveMax >= (cfg[\solver][\contextBreakPassiveMaxTriggerCents] ? 28.0) }) {
    				isBreak = true;
    				reason = if(reason == \none) { \postPassiveGhost } { reason };
    				breakStrength = breakStrength.max(((passiveMax - (cfg[\solver][\contextBreakPassiveMaxTriggerCents] ? 28.0)) / 14.0).clip(0.20, 1.0));
    			};
    			if((phase == \post) and: { commonDrift >= (cfg[\solver][\contextBreakCommonDriftTriggerCents] ? 14.0) }) {
    				isBreak = true;
    				reason = if(reason == \none) { \postCommonDrift } { reason };
    				breakStrength = breakStrength.max(((commonDrift - (cfg[\solver][\contextBreakCommonDriftTriggerCents] ? 14.0)) / 18.0).clip(0.20, 1.0));
    			};
    		};

    		(
    			timestamp: Main.elapsedTime,
    			phase: phase,
    			activePcs: activePcs.copy,
    			prevPcs: prevPcs.copy,
    			activeCount: activeCount,
    			hasExternal: hasExternal,
    			commonToneRatio: commonRatio,
    			activeMaxCents: activeMax,
    			passiveMaxCents: passiveMax,
    			commonDriftCents: commonDrift,
    			eligible: eligible,
    			isBreak: isBreak,
    			breakStrength: breakStrength,
    			reason: reason
    		)
    	};

    	at[\applyContextBreakRebase] = { |activePcs, pcWeights=nil, externalSources=nil, info=nil, mode=\pre|
    		var gauge, activeSet, activeBlend, passiveBlend, beforeActive, beforePassive, target, off;
    		if(info.isNil) { info = at[\contextBreakInfo].(activePcs, pcWeights, externalSources, mode); };
    		activePcs = activePcs ? Array.new;
    		activeSet = IdentitySet.new;
    		activePcs.do { |pc| activeSet.add(pc); };
    		gauge = at[\causalGaugeForContextRebase].(activePcs, externalSources, info);
    		beforeActive = (if(at[\activeMaxDeviationCents].notNil) { at[\activeMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    		beforePassive = (if(at[\passiveMaxDeviationCents].notNil) { at[\passiveMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;

    		activeBlend = if(mode == \post) { cfg[\solver][\contextBreakRescueActiveBlend] ? 0.92 } { cfg[\solver][\contextBreakActiveBlend] ? 0.82 };
    		passiveBlend = if(mode == \post) { cfg[\solver][\contextBreakRescuePassiveBlend] ? 0.72 } { cfg[\solver][\contextBreakPassiveBlend] ? 0.58 };
    		activeBlend = activeBlend.clip(0.0, 1.0);
    		passiveBlend = passiveBlend.clip(0.0, 1.0);

    		// r15m: context break is not a gauge limit and not an ET reset.
    		// It removes unsupported local residue around the current robust gauge,
    		// while allowing the whole field to travel anywhere over time.
    		cfg[\solver][\numNodes].do { |pc|
    			target = at[\wrap01].((st[\etPhase][pc] ? (pc / (cfg[\solver][\numNodes] ? 12).asFloat)) + (gauge ? 0.0));
    			off = at[\wrapSigned].((target ? (st[\etPhase][pc] ? 0.0)) - (st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)));
    			if(activeSet.includes(pc)) {
    				st[\nodePhase][pc] = at[\wrap01].((st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)) + ((off ? 0.0) * (activeBlend ? 0.0)));
    			} {
    				st[\nodePhase][pc] = at[\wrap01].((st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)) + ((off ? 0.0) * (passiveBlend ? 0.0)));
    			};
    		};

    		st[\lastContextBreakReport] = info.copy;
    		st[\lastContextBreakReport][\applied] = true;
    		st[\lastContextBreakReport][\mode] = mode;
    		st[\lastContextBreakReport][\gaugeCents] = gauge * 1200.0;
    		st[\lastContextBreakReport][\beforeActiveMaxCents] = beforeActive;
    		st[\lastContextBreakReport][\beforePassiveMaxCents] = beforePassive;
    		st[\lastContextBreakReport][\afterActiveMaxCents] = (if(at[\activeMaxDeviationCents].notNil) { at[\activeMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    		st[\lastContextBreakReport][\afterPassiveMaxCents] = (if(at[\passiveMaxDeviationCents].notNil) { at[\passiveMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    		st[\lastContextBreakReport][\positionCapCents] = nil;
    		true
    	};

    	// r15v coherent transport: no position cap, but inherited gauge velocity
    	// now has provenance. External evidence, lower structural onset, and coherent
    	// common-tone motion may carry velocity. Unsupported internal residue decays.

    	at[\applyCoherentGaugeTransport] = { |rawOffset, reason=\internal, strength=1.0, response=1.0, authority=1.0, inertia=nil|
    		var enabled, now, move, inert, prevVel, desired, offset, damping;
    		var activePcs, externalSources, support, effectivePrevVel, velDecay, sourceAuth, exponent;
    		enabled = cfg[\solver][\coherentTransportEnabled] ? true;
    		rawOffset = rawOffset ? 0.0;
    		if(enabled == false) {
    			desired = rawOffset * strength * response * authority;
    			if(desired.abs > 0.0000000001) { st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + desired) }; };
    			desired
    		} {
    			now = Main.elapsedTime;
    			activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
    			externalSources = at[\currentExternalSources].();
    			support = at[\transportSupportScale].(reason, activePcs, externalSources).clip(0.0, 1.0);
    			move = (st[\movement] ? 0.0).clip(0.0, 1.0);
    			inert = if(inertia.isNil) {
    				if(reason == \externalEvidence) { cfg[\solver][\coherentTransportExternalInertia] ? 0.34 } {
    					if(reason == \contextBreak) { cfg[\solver][\coherentTransportContextInertia] ? 0.46 } { cfg[\solver][\coherentTransportInertia] ? 0.52 }
    				}
    			} { inertia };
    			inert = inert.clip(0.0, 0.98);
    			damping = (cfg[\solver][\coherentTransportVelocityDamping] ? 0.72).clip(0.0, 1.0);
    			prevVel = st[\fieldGaugeVelocity] ? 0.0;
    			if((reason != \externalEvidence) and: { support < 0.25 }) {
    				velDecay = cfg[\solver][\causalVelocityUnsupportedDecay] ? 0.22;
    			} {
    				if((reason != \externalEvidence) and: { support < 0.55 }) {
    					velDecay = cfg[\solver][\causalVelocityPartialDecay] ? 0.58;
    				} {
    					velDecay = 1.0;
    				};
    			};
    			effectivePrevVel = prevVel * velDecay.clip(0.0, 1.0);
    			sourceAuth = 1.0;
    			if((cfg[\solver][\transportFreshSupportEnabled] ? true) and: { reason != \externalEvidence }) {
    				exponent = if(reason == \activeBody) {
    					cfg[\solver][\transportActiveBodySupportExponent] ? 2.15
    				} {
    					if(reason == \contextBreak) {
    						cfg[\solver][\transportContextBreakSupportExponent] ? 2.0
    					} {
    						if(reason == \lowerOnset) {
    							cfg[\solver][\transportLowerSupportExponent] ? 0.55
    						} {
    							if(reason == \continuous) { cfg[\solver][\transportContinuousSupportExponent] ? 1.25 } { cfg[\solver][\transportFreshSupportExponent] ? 1.65 }
    						}
    					}
    				};
    				sourceAuth = support.clip(0.0, 1.0).pow(exponent.max(0.0));
    			};
    			desired = rawOffset * strength.clip(0.0, 2.0) * response.clip(0.0, 1.5) * authority.clip(0.0, 2.0) * sourceAuth * (0.12 + (move * 0.88));
    			// No distance cap: supported evidence can carry the field indefinitely.
    			// Unsupported internal gauge requests are provenance-filtered so memory residue
    			// does not masquerade as current musical transport.
    			offset = (desired * (1.0 - inert)) + (effectivePrevVel * inert);
    			offset = offset * (if(at[\globalMotionGateAmount].notNil) { at[\globalMotionGateAmount].() } { (st[\movement] ? 0.0).clip(0.0, 1.0) });
    			st[\fieldGaugeVelocity] = (offset * damping) + (effectivePrevVel * (1.0 - damping));
    			st[\fieldGaugeLastOffset] = offset;
    			st[\fieldGaugeLastTime] = now;
    			// at17bg: coherent transport is true whole-field transport. Earlier builds
    			// moved nodePhase and compatibility fieldGaugeCents, but fieldTrueGaugeCents
    			// was then preserved at zero by the gauge/shape barrier. That correctly
    			// prevented residue ratchet, but it also hid legitimate fresh active phrase
    			// transport in the uninhibited control ecology. Commit supported transport
    			// to trueGauge here; unsupported residue is still filtered by sourceAuth.
    			if(offset.abs > 0.0000000001) {
    				st[\fieldTrueGaugeCents] = (st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0)) + (offset * 1200.0);
    				st[\fieldTrueGaugeVelocityCents] = offset * 1200.0;
    				st[\fieldGaugeCents] = st[\fieldTrueGaugeCents];
    				st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].(p + offset) };
    			} {
    				st[\fieldGaugeCents] = st[\fieldTrueGaugeCents] ? (st[\fieldGaugeCents] ? 0.0);
    			};
    			if((cfg[\solver][\coherentTransportReportEnabled] ? true) and: { ((reason != \continuous) or: { cfg[\solver][\diagnosticContinuousReports] ? false }) }) {
    				st[\lastCoherentTransportReport] = (
    					timestamp: now,
    					reason: reason,
    					rawOffsetCents: rawOffset * 1200.0,
    					desiredCents: desired * 1200.0,
    					appliedCents: offset * 1200.0,
    					velocityCents: (st[\fieldGaugeVelocity] ? 0.0) * 1200.0,
    					fieldGaugeCents: (st[\fieldGaugeCents] ? 0.0),
    					support: support,
    					sourceAuth: sourceAuth,
    					velocityDecay: velDecay,
    					strength: strength,
    					response: response,
    					authority: authority,
    					inertia: inert,
    					movement: move
    				);
    			};
    			at[\updateCausalTransportState].(activePcs, externalSources, reason);
    			offset
    		}
    	};

    	at[\applyLowerOnsetGaugeCarry] = { |activePcs, pcWeights|
    		var info, now, recentWindow, enabled, shouldCarry, move, strength, response, upperHeldDamping, reversalDamping;
    		var pc, midi, currentPhase, desiredPhase, rawOffset, offset, factor, prevMidis, heldAbove, lastOffset, reversing;

    		info = st[\lastOnsetInfo];
    		now = Main.elapsedTime;
    		recentWindow = cfg[\solver][\contextGaugeRecentWindow] ? 0.35;
    		enabled = cfg[\solver][\contextGaugeEnabled] ? true;

    		shouldCarry =
    			enabled
    			and: { info.notNil }
    			and: { (info[\consumed] ? false).not }
    			and: { (now - (info[\timestamp] ? now)) <= recentWindow }
    			and: { (info[\wasLowerOnset] ? false) == true }
    			and: { activePcs.size > 1 }
    			and: { activePcs.includes(info[\pc]) };

    		if(shouldCarry) {
    			move = (st[\movement] ? 0.0).clip(0.0, 1.0);
    			strength = (cfg[\solver][\contextGaugeStrength] ? 1.0).clip(0.0, 1.5);
    			response = (cfg[\solver][\contextGaugeResponse] ? 0.52).clip(0.05, 1.0);
    			upperHeldDamping = (cfg[\solver][\contextGaugeUpperHeldDamping] ? 0.70).clip(0.10, 1.0);
    			reversalDamping = (cfg[\solver][\contextGaugeReversalDamping] ? 0.42).clip(0.10, 1.0);
    			pc = info[\pc];
    			midi = info[\midi];
    			prevMidis = info[\prevMidis] ? Array.new;
    			heldAbove = prevMidis.any { |m| m > midi };
    			currentPhase = st[\nodePhase][pc];
    			desiredPhase = if(info[\prevNodePhase].notNil) { info[\prevNodePhase][pc] } { st[\nodePhase][pc] };
    			rawOffset = at[\wrapSigned].(desiredPhase - currentPhase);

    			factor = move * strength * response;
    			if(heldAbove) { factor = factor * upperHeldDamping; };

    			lastOffset = if(st[\lastGaugeCarry].isNil) { 0.0 } { st[\lastGaugeCarry][\offset] ? 0.0 };
    			reversing = (lastOffset.abs > 0.0000001) and: { rawOffset.abs > 0.0000001 } and: { lastOffset.sign != rawOffset.sign };
    			if(reversing) { factor = factor * reversalDamping; };

    			// r15m: no lower-onset cent cap; lower context carry is motion-shaped by coherent transport.
    			offset = at[\applyCoherentGaugeTransport].(rawOffset, \lowerOnset, strength, response * (if(heldAbove) { upperHeldDamping } { 1.0 }) * (if(reversing) { reversalDamping } { 1.0 }), 1.0, cfg[\solver][\coherentTransportContextInertia] ? 0.46);

    			info[\consumed] = true;
    			st[\lastOnsetInfo] = info;
    			st[\lastGaugeCarryDirection] = offset.sign;
    			st[\lastGaugeCarry] = (
    				timestamp: now,
    				midi: midi,
    				pc: pc,
    				desiredPhase: desiredPhase,
    				previousPhase: currentPhase,
    				rawOffset: rawOffset,
    				offset: offset,
    				cents: offset * 1200.0,
    						deltaCents: offset * 1200.0,
    				movement: move,
    				strength: strength,
    				response: response,
    				heldAbove: heldAbove,
    				reversing: reversing,
    				factor: factor,
    				reason: \lowerOnsetFieldContextGauge
    			);
    		} {
    			if(info.notNil and: { (info[\consumed] ? false).not } and: { (now - (info[\timestamp] ? now)) > recentWindow }) {
    				info[\consumed] = true;
    				st[\lastOnsetInfo] = info;
    			};
    		};
    	};

    	at[\applyExternalGaugeCarry] = { |activePcs, pcWeights, externalSources=nil|
    		var sources, src, now, enabled, rawOffset, offset, move, strength, response, authority, lastOffset, reversing, reversalDamping;
    		var pc, phase, currentPhase, sourceStrength, confidence, rawAuthority;
    		var errorCents, trustWindow, farWindow, farScale, errorScale, behaviorScale, denom;
    		var key, sourceTarget, desiredOffset;

    		sources = externalSources ? Array.new;
    		enabled = cfg[\solver][\externalGaugeCarryEnabled] ? true;

    		if(sources.isEmpty) {
    			st[\externalGaugeCarryKey] = nil;
    			st[\externalGaugeCarryAccumOffset] = 0.0;
    			st[\lastExternalGaugeCarry] = nil;
    		};

    		if(enabled and: { activePcs.notNil } and: { activePcs.size > 0 } and: { sources.notEmpty }) {
    			src = at[\strongestExternalSource].(sources);
    			sourceStrength = if(src.isNil) { 0.0 } { (at[\sourceStrength].(src) ? 0.0).clip(0.0, 1.2) };
    			if(src.notNil and: { src[\pc].notNil } and: { src[\phase].notNil } and: { sourceStrength > 0.000001 }) {
    				now = Main.elapsedTime;
    				pc = src[\pc];
    				phase = src[\phase];
    				currentPhase = st[\nodePhase][pc];
    				rawOffset = at[\wrapSigned].(phase - currentPhase);
    				errorCents = rawOffset.abs * 1200.0;
    				move = (st[\movement] ? 0.0).clip(0.0, 1.0);
    				strength = (cfg[\solver][\externalGaugeCarryStrength] ? 0.42).clip(0.0, 1.5);
    				response = (cfg[\solver][\externalGaugeCarryResponse] ? 0.62).clip(0.05, 1.0);
    				reversalDamping = (cfg[\solver][\externalGaugeCarryReversalDamping] ? 0.55).clip(0.10, 1.0);
    				confidence = (src[\confidence] ? 0.0).clip(0.0, 1.0);
    				rawAuthority = (sourceStrength / 0.45).clip(0.0, 1.0);

    				// r15m: distance changes trust, not an absolute travel budget. Stable external
    				// evidence may carry the field indefinitely over repeated coherent transport.
    				trustWindow = (cfg[\solver][\externalGaugeTrustWindowCents] ? 8.0).max(0.0);
    				farWindow = (cfg[\solver][\externalGaugeFarWindowCents] ? 32.0).max(trustWindow + 0.001);
    				farScale = (cfg[\solver][\externalGaugeFarScale] ? 0.18).clip(0.0, 1.0);
    				denom = (farWindow - trustWindow).max(0.001);
    				errorScale = if(errorCents <= trustWindow) {
    					1.0
    				} {
    					if(errorCents >= farWindow) {
    						farScale
    					} {
    						farScale + ((1.0 - farScale) * ((farWindow - errorCents) / denom))
    					}
    				};

    				behaviorScale = at[\externalBehaviorScale].(src);
    				authority = rawAuthority.pow(1.35) * confidence.sqrt * errorScale * behaviorScale * at[\externalRoleGaugeScale].(src, activePcs);
    				lastOffset = if(st[\lastExternalGaugeCarry].isNil) { 0.0 } { st[\lastExternalGaugeCarry][\offset] ? 0.0 };
    				reversing = (lastOffset.abs > 0.0000001) and: { rawOffset.abs > 0.0000001 } and: { lastOffset.sign != rawOffset.sign };
    				if(reversing) { authority = authority * reversalDamping; };

    				desiredOffset = rawOffset * move * strength * response * authority;
    				offset = at[\applyCoherentGaugeTransport].(rawOffset, \externalEvidence, strength, response, authority, cfg[\solver][\coherentTransportExternalInertia] ? 0.34);
    				st[\externalGaugeCarryAccumOffset] = (st[\externalGaugeCarryAccumOffset] ? 0.0) + offset;

    				sourceTarget = src[\targetMidi] ? pc;
    				key = (src[\id] ? \external).asString ++ ":" ++ sourceTarget.asString ++ ":" ++ pc.asString;
    				st[\externalGaugeCarryKey] = key;
    				st[\lastExternalGaugeCarry] = (
    					timestamp: now,
    					pc: pc,
    					phase: phase,
    					previousPhase: currentPhase,
    					rawOffset: rawOffset,
    					offset: offset,
    					cents: offset * 1200.0,
    					deltaCents: offset * 1200.0,
    					desiredOffset: desiredOffset,
    					desiredCents: desiredOffset * 1200.0,
    					accumOffset: st[\externalGaugeCarryAccumOffset],
    					accumCents: (st[\externalGaugeCarryAccumOffset] ? 0.0) * 1200.0,
    					totalCents: (st[\externalGaugeCarryAccumOffset] ? 0.0) * 1200.0,
    					totalCapCents: nil,
    					key: key,
    					movement: move,
    					strength: strength,
    					response: response,
    					sourceStrength: sourceStrength,
    					confidence: confidence,
    					authority: authority,
    					errorCents: errorCents,
    					errorScale: errorScale,
    					behaviorScale: behaviorScale,
    					reversing: reversing,
    					factor: move * strength * response * authority,
    					reason: \externalEvidenceGaugeCarryUnboundedCoherent
    				);
    			};
    		};
    	};


    	// ------------------------------------------------------------
    	// force construction
    	// ------------------------------------------------------------

};
)
