(
// AT_mic.scd
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
	// microphone observation
	// ------------------------------------------------------------

	at[\clearMicEvidence] = {
		st[\micPc] = nil;
		st[\micPhase] = nil;
		st[\micConfidence] = 0.0;
		st[\micStableCount] = 0;
		st[\micDiagKey] = nil;
		st[\micRawCandidates] = Array.new;
		st[\micCandidates] = Array.new;
		st[\micStabilizedCandidates] = Array.new;
		st[\externalSources] = Array.new;
		st[\micInfluenceBlocked] = false;
		st[\micCommitCooldown] = 0;
		st[\micPcStableCounts] = Array.fill(cfg[\solver][\numNodes], 0);
		st[\micPcPrevPhases] = Array.fill(cfg[\solver][\numNodes], { nil });
		st[\micPcPrevFreqs] = Array.fill(cfg[\solver][\numNodes], { nil });
		st[\micPcScores] = Array.fill(cfg[\solver][\numNodes], 0.0);
		st[\micPcVisible] = Array.fill(cfg[\solver][\numNodes], false);
		st[\micPcActive] = Array.fill(cfg[\solver][\numNodes], false);
		st[\micPcWarmCounts] = Array.fill(cfg[\solver][\numNodes], 0);
		st[\micPcCoolCounts] = Array.fill(cfg[\solver][\numNodes], 0);
		st[\micCommittedByPc] = Array.fill(cfg[\solver][\numNodes], { nil });
	};

	at[\micInputModeIndex] = {
		var mode;
		mode = cfg[\mic][\inputMode] ? \sum01;
		if(mode == \ch0) { 0 } {
			if(mode == \ch1) { 1 } { 2 }
		}
	};

	at[\refreshMicMeters] = {
		var vals;
		vals = st[\micMeterBus].getnSynchronous(4);
		st[\micInputAmp0] = vals[1] ? 0.0;
		st[\micInputAmp1] = vals[2] ? 0.0;
		st[\micInputMode] = cfg[\mic][\inputMode];
		st[\micSignalPresent] = ((vals[0] ? 0.0) >= (cfg[\mic][\meterThreshold] ? 0.001));
		vals
	};

	at[\normalizeExternalSource] = { |src|
		var out;
		if(src.isNil) {
			nil;
		} {
			// v50: normalize the common live-source fields without throwing away
			// scene identity.  The final demo's staged speaker-to-mic sources carry
			// sourceClass/kind/spectrum/eligibility metadata that External Coherence
			// needs in order to distinguish ET instruments, flat voices, abnormal
			// spectra, and self bleed.
			out = src.copy;
			out[\id] = src[\id] ? ((src[\kind] ? \mic).asString ++ "-" ++ (src[\pc] ? 0).asString);
			out[\kind] = src[\kind] ? \mic;
			out[\pc] = src[\pc];
			out[\phase] = at[\wrap01].(src[\phase]);
			out[\freq] = (src[\freq] ? 0.0).clip(0.0, 24000.0);
			out[\weight] = (src[\weight] ? 0.0).clip(0.0, 1.5);
			out[\confidence] = (src[\confidence] ? 0.0).clip(0.0, 1.0);
			out[\amp] = (src[\amp] ? 0.0).clip(0.0, 10.0);
			out[\stableFrames] = src[\stableFrames] ? 0;
			out[\active] = src[\active] ? true;
			out
		};
	};

	at[\markMicSelfIgnore] = { |frames=nil|
		var n;
		n = if(frames.isNil) { cfg[\mic][\selfIgnoreFrames] } { frames };
		st[\micSelfIgnoreFramesRemaining] = n.asInteger.max(0);
	};

	at[\currentMicInfluencePolicy] = {
		cfg[\mic][\influencePolicy] ? \externalOnly
	};

	at[\effectiveExternalSourceLimit] = { |activePcs=nil|
		var pcs;
		pcs = if(activePcs.isNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { activePcs };
		if(at[\currentMicInfluencePolicy].() == \debugRaw) {
			cfg[\mic][\debugRawMaxExternalSources].asInteger.max(1)
		} {
			if((at[\currentMicInfluencePolicy].() == \duetSafe) and: { pcs.notEmpty }) {
				cfg[\mic][\duetMaxExternalSources].asInteger.max(1)
			} {
				cfg[\mic][\maxExternalSources].asInteger.max(1)
			}
		}
	};

	at[\micInfluenceBlocked] = { |activePcs=nil|
		var pcs, policy;
		pcs = if(activePcs.isNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { activePcs };
		policy = at[\currentMicInfluencePolicy].();

		if(cfg[\mic][\enabled].not) {
			true
		} {
			if(policy == \debugRaw) {
				false
			} {
				if(([\fullBlend, \externalFollow].includes(policy).not) and: { (st[\micSceneBypassSelfIgnore] ? false).not } and: { st[\micSelfIgnoreFramesRemaining] > 0 }) {
					true
				} {
					if(policy == \externalOnly) {
						pcs.notEmpty
					} {
						false
					}
				}
			}
		}
	};

	at[\applyMicSelfMatchPenalty] = { |src, activePcs=nil|
		var out, pcs, policy, weightFactor, confFactor, srcPc, diffCents;
		if(src.isNil) {
			nil
		} {
			out = src.copy;
			pcs = if(activePcs.isNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { activePcs };
			policy = at[\currentMicInfluencePolicy].();
			weightFactor = 1.0;
			confFactor = 1.0;

			if((policy == \duetSafe) and: { pcs.notEmpty }) {
				srcPc = out[\pc];

				if(pcs.includes(srcPc)) {
					// Same-pitch-class mic is ambiguous: it may be speaker bleed or it may be
					// a real singer/instrument slightly flat/sharp of the internal tone.
					// If it is almost identical to the current internal phase, suppress it as
					// probable self-bleed. If it differs musically, keep it as tuning pressure.
					diffCents = (at[\wrapSigned].((out[\phase] ? st[\nodePhase][srcPc]) - st[\nodePhase][srcPc]).abs * 1200.0);
					if(diffCents <= (cfg[\mic][\duetSamePcSelfCents] ? 4.0)) {
						weightFactor = 0.0;
						confFactor = 0.0;
						out[\active] = false;
					} {
						if(diffCents <= (cfg[\mic][\duetSamePcUsefulCents] ? 80.0)) {
							weightFactor = cfg[\mic][\duetSamePcTuningScale].clip(0.05, 2.0);
							confFactor = cfg[\mic][\duetSamePcConfidenceScale].clip(0.05, 1.5);
						} {
							weightFactor = cfg[\mic][\selfGeneralPenalty].clip(0.05, 1.0);
							confFactor = weightFactor;
						};
					};
				} {
					weightFactor = cfg[\mic][\selfGeneralPenalty].clip(0.05, 1.0);
					confFactor = weightFactor;
				};

				out[\weight] = ((out[\weight] ? 0.0) * weightFactor * cfg[\mic][\duetWeightScale]).clip(0.0, 1.5);
				out[\confidence] = ((out[\confidence] ? 0.0) * confFactor).clip(0.0, 1.0);
				out[\active] = (out[\active] == true) and: { (out[\weight] ? 0.0) > 0.0 } and: { (out[\confidence] ? 0.0) >= cfg[\mic][\minConfidence] };
			};

			at[\normalizeExternalSource].(out)
		}
	};

	at[\sourceSetImmediateChange] = { |oldSources, newSources|
		var oldStrong, newStrong;
		oldSources = oldSources ? Array.new;
		newSources = newSources ? Array.new;

		if(oldSources.size != newSources.size) {
			true
		} {
			oldStrong = at[\strongestExternalSource].(oldSources);
			newStrong = at[\strongestExternalSource].(newSources);

			if(oldStrong.isNil or: { newStrong.isNil }) {
				oldStrong != newStrong
			} {
				((oldStrong[\pc] ? -1) != (newStrong[\pc] ? -1)) or: {
					(((oldStrong[\weight] ? 0.0) - (newStrong[\weight] ? 0.0)).abs > 0.18)
				}
			}
		}
	};

	at[\updateCommittedExternalSources] = { |candidates|
		var activePcs, blocked, proposedByPc, limit, activateFrames, releaseFrames;
		var proposedPublished, currentPublished, proposedKey, currentKey, immediateCommit, shouldProcess;

		activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
		blocked = at[\micInfluenceBlocked].(activePcs);
		st[\micInfluenceBlocked] = blocked;
		st[\micCommitCooldown] = (st[\micCommitCooldown] - 1).max(0);
		shouldProcess = true;

		if(blocked) {
			st[\micPcWarmCounts] = Array.fill(cfg[\solver][\numNodes], 0);
			st[\micPcCoolCounts] = Array.fill(cfg[\solver][\numNodes], 0);
			st[\micCommittedByPc] = Array.fill(cfg[\solver][\numNodes], { nil });
			currentPublished = st[\externalSources] ? Array.new;
			if(currentPublished.notEmpty) {
				st[\externalSources] = Array.new;
				st[\micCommitCooldown] = cfg[\mic][\commitCooldownFrames].asInteger.max(0);
			};
			shouldProcess = false;
		};

		if(at[\currentMicInfluencePolicy].() == \debugRaw) {
			proposedPublished = at[\takeStrongestSources].(
				(candidates ? Array.new).select { |src|
					src.notNil and: { (src[\confidence] ? 0.0) >= (cfg[\mic][\minConfidence] * 0.35) }
				},
				at[\effectiveExternalSourceLimit].(activePcs)
			);
			currentPublished = st[\externalSources] ? Array.new;
			if(at[\micKeyForSources].(proposedPublished) != at[\micKeyForSources].(currentPublished)) {
				st[\externalSources] = proposedPublished.collect { |src|
					at[\normalizeExternalSource].(src.copy.putAll((
						weight: ((src[\weight] ? 0.0) * 0.55).clip(0.0, 1.5),
						confidence: ((src[\confidence] ? 0.0) * 0.85).clip(0.0, 1.0),
						active: true
					)))
				};
			};
			shouldProcess = false;
		};

		if(shouldProcess) {
			proposedByPc = Array.fill(cfg[\solver][\numNodes], { nil });
		(candidates ? Array.new).do { |src|
			if(src.notNil and: { src[\pc].notNil }) {
				proposedByPc[src[\pc]] = src;
			};
		};

		limit = at[\effectiveExternalSourceLimit].(activePcs);
		activateFrames = cfg[\mic][\activateFrames].asInteger.max(1);
		releaseFrames = cfg[\mic][\releaseFrames].asInteger.max(1);

		cfg[\solver][\numNodes].do { |pc|
			var cand, old, smoothedFreq, smoothedWeight, smoothedConf;
			cand = proposedByPc[pc];
			old = st[\micCommittedByPc][pc];

			if(cand.notNil and: { cand[\active] == true }) {
				cand = at[\applyMicSelfMatchPenalty].(cand, activePcs);

				if((cand[\active] == true) and: { (cand[\confidence] ? 0.0) >= cfg[\mic][\minConfidence] }) {
					st[\micPcWarmCounts][pc] = st[\micPcWarmCounts][pc] + 1;
					st[\micPcCoolCounts][pc] = 0;

					if(old.notNil) {
						smoothedFreq = (old[\freq] ? cand[\freq]) + (((cand[\freq] ? old[\freq]) - (old[\freq] ? cand[\freq])) * 0.35);
						smoothedWeight = (((old[\weight] ? 0.0) * 0.6) + ((cand[\weight] ? 0.0) * 0.4)).clip(0.0, 1.5);
						smoothedConf = (((old[\confidence] ? 0.0) * 0.55) + ((cand[\confidence] ? 0.0) * 0.45)).clip(0.0, 1.0);

						st[\micCommittedByPc][pc] = at[\normalizeExternalSource].(old.copy.putAll((
							phase: at[\phaseBlend].(old[\phase], cand[\phase], 0.35),
							freq: smoothedFreq,
							weight: smoothedWeight,
							confidence: smoothedConf,
							amp: cand[\amp],
							stableFrames: (cand[\stableFrames] ? 0).max(st[\micPcWarmCounts][pc]),
							active: true
						)));
					} {
						if(st[\micPcWarmCounts][pc] >= activateFrames) {
							st[\micCommittedByPc][pc] = at[\normalizeExternalSource].(cand.copy.putAll((
								stableFrames: st[\micPcWarmCounts][pc],
								active: true
							)));
						};
					};
				} {
					st[\micPcWarmCounts][pc] = 0;
					if(old.notNil) {
						st[\micPcCoolCounts][pc] = st[\micPcCoolCounts][pc] + 1;
						if(st[\micPcCoolCounts][pc] < releaseFrames) {
							st[\micCommittedByPc][pc] = at[\normalizeExternalSource].(old.copy.putAll((
								weight: ((old[\weight] ? 0.0) * 0.82),
								confidence: ((old[\confidence] ? 0.0) * 0.9),
								active: true
							)));
						} {
							st[\micPcCoolCounts][pc] = 0;
							st[\micCommittedByPc][pc] = nil;
						};
					};
				};
			} {
				st[\micPcWarmCounts][pc] = 0;
				if(old.notNil) {
					st[\micPcCoolCounts][pc] = st[\micPcCoolCounts][pc] + 1;
					if(st[\micPcCoolCounts][pc] < releaseFrames) {
						st[\micCommittedByPc][pc] = at[\normalizeExternalSource].(old.copy.putAll((
							weight: ((old[\weight] ? 0.0) * 0.82),
							confidence: ((old[\confidence] ? 0.0) * 0.9),
							active: true
						)));
					} {
						st[\micPcCoolCounts][pc] = 0;
						st[\micCommittedByPc][pc] = nil;
					};
				} {
					st[\micPcCoolCounts][pc] = 0;
				};
			};
		};

		proposedPublished = st[\micCommittedByPc].select { |src|
			src.notNil and: { (src[\confidence] ? 0.0) >= cfg[\mic][\minConfidence] }
		};
		proposedPublished = at[\takeStrongestSources].(proposedPublished, limit);
		currentPublished = st[\externalSources] ? Array.new;
		proposedKey = at[\micKeyForSources].(proposedPublished);
		currentKey = at[\micKeyForSources].(currentPublished);
		immediateCommit = at[\sourceSetImmediateChange].(currentPublished, proposedPublished);

		if((proposedKey != currentKey) and: { immediateCommit or: { st[\micCommitCooldown] <= 0 } }) {
			st[\externalSources] = proposedPublished.collect { |src| src.copy };
			st[\micCommitCooldown] = cfg[\mic][\commitCooldownFrames].asInteger.max(0);
		};

		};

		st[\externalSources];
	};

	at[\updateMicSummaryFromCandidates] = { |candidates, fallbackFreq=0.0|
		var strongestCandidate, strongestActive, summary;
		strongestCandidate = at[\strongestExternalSource].(candidates);
		strongestActive = at[\strongestExternalSource].(st[\externalSources]);
		summary = if(strongestActive.notNil) { strongestActive } { strongestCandidate };

		if(summary.notNil) {
			st[\micPc] = summary[\pc];
			st[\micPhase] = summary[\phase];
			st[\micConfidence] = summary[\confidence] ? 0.0;
			st[\micStableCount] = summary[\stableFrames] ? 0;
			st[\micRawFreq] = if((summary[\freq] ? 0.0) > 0.0) { summary[\freq] } { fallbackFreq };
		} {
			st[\micPc] = nil;
			st[\micPhase] = nil;
			st[\micConfidence] = 0.0;
			st[\micStableCount] = 0;
			st[\micRawFreq] = fallbackFreq;
		};

		summary;
	};


at[\phaseBlend] = { |prevPhase, nextPhase, alpha=0.5|
		if(prevPhase.isNil) {
			at[\wrap01].(nextPhase);
		} {
			at[\wrap01].(prevPhase + (at[\wrapSigned].(nextPhase - prevPhase) * alpha.clip(0.0, 1.0)));
		}
	};

	at[\sortPeaksByFreq] = { |peaks|
		(peaks ? Array.new).sort { |a, b| (a[\freq] ? 0.0) < (b[\freq] ? 0.0) };
	};

	at[\suppressMicHarmonicPeaks] = { |peaks|
		var sorted, kept, tol, maxH, suppress;
		sorted = at[\sortPeaksByFreq].(peaks);
		kept = Array.new;
		tol = cfg[\mic][\polyHarmonicTolerance];
		maxH = cfg[\mic][\polyMaxHarmonic].asInteger.max(3);
		suppress = cfg[\mic][\polyHarmonicSuppress].clip(0.0, 0.95);

		sorted.do { |peak|
			var adj, pfreq;
			adj = peak[\energy] ? 0.0;
			pfreq = peak[\freq] ? 0.0;

			kept.do { |base|
				var bfreq, ratio, harm, logErr, baseEnergy, factor;
				bfreq = base[\freq] ? 0.0;

				if((adj > 0.0) and: { pfreq > 0.0 } and: { bfreq > 0.0 } and: { pfreq > bfreq }) {
					ratio = pfreq / bfreq;
					harm = ratio.round.asInteger;

					if(harm >= 3 and: { harm <= maxH }) {
						logErr = ((ratio.log2) - harm.asFloat.log2).abs;

						if(logErr <= tol) {
							baseEnergy = (base[\energyAdj] ? (base[\energy] ? 0.0)).max(0.0);
							if(baseEnergy > 0.0) {
								factor = 1.0 - (((baseEnergy / (adj + 0.000001)).clip(0.0, 1.0)) * suppress / harm.sqrt);
								adj = adj * factor.clip(0.18, 1.0);
							};
						};
					};
				};
			};

			if(adj >= (cfg[\mic][\polyAbsThreshold] * 0.55)) {
				kept = kept.add((
					bin: peak[\bin],
					energy: peak[\energy],
					energyAdj: adj,
					freq: peak[\freq],
					phase: peak[\phase],
					pc: peak[\pc]
				));
			};
		};

		kept;
	};

at[\refreshMicObservationMono] = {
		var vals, meterVals, freq, amp, rawAmp, voiced, phase, pc, diagKey, conf, ampNorm, src, candidates;

		vals = st[\micBus].getnSynchronous(2);
		meterVals = at[\refreshMicMeters].();
		freq = vals[0] ? 0.0;
		amp = vals[1] ? 0.0;
		rawAmp = meterVals[0] ? amp;
		voiced = (freq > 0.0) and: { amp >= cfg[\mic][\ampThreshold] };

		st[\micRawFreq] = freq;
		st[\micRawAmp] = rawAmp;
		st[\micAnalyzedAmp] = amp;
		st[\micVoiced] = voiced;

		if(voiced) {
			phase = at[\freqToPhase].(freq);
			pc = ((phase * 12).round.asInteger) % 12;
			diagKey = [pc, phase.round(0.0005)];

			if(diagKey == st[\micDiagKey]) {
				st[\micStableCount] = st[\micStableCount] + 1;
			} {
				st[\micDiagKey] = diagKey;
				st[\micStableCount] = 1;
			};

			ampNorm = ((amp - cfg[\mic][\ampThreshold]) / (cfg[\mic][\ampConfidenceSpan] ? 0.018)).clip(0.0, 1.0);
			conf = (ampNorm * (st[\micStableCount] / cfg[\mic][\stableFrames]).clip(0.0, 1.0)).clip(0.0, 1.0);

			src = at[\normalizeExternalSource].((
				id: "mic-0",
				kind: \mic,
				pc: pc,
				phase: phase,
				freq: freq,
				weight: (amp * cfg[\mic][\weight]).clip(0.0, 1.5),
				amp: rawAmp,
				confidence: conf,
				stableFrames: st[\micStableCount],
				active: (conf >= cfg[\mic][\minConfidence]) and: { amp > 0.0 }
			));

			candidates = [src];
			st[\micRawCandidates] = candidates.collect { |item| item.copy };
			st[\micCandidates] = candidates.copy;
			st[\micStabilizedCandidates] = candidates.copy;
			at[\updateCommittedExternalSources].(candidates);
			at[\updateMicSummaryFromCandidates].(candidates, freq);
		} {
			st[\micRawFreq] = 0.0;
			st[\micRawAmp] = rawAmp;
			st[\micAnalyzedAmp] = amp;
			st[\micVoiced] = false;
			st[\micRawCandidates] = Array.new;
			st[\micCandidates] = Array.new;
			st[\micStabilizedCandidates] = Array.new;
			at[\updateCommittedExternalSources].(Array.new);
			at[\updateMicSummaryFromCandidates].(Array.new, 0.0);
		};
	};


at[\refreshMicObservationPoly] = {
		var vals, ampVals, meterVals, amp, rawAmp, voiced, total, maxVal, maxIndex, ampNorm, peakThreshold, meanThreshold, rawPeaks, presentMask;
		var rawCandidates, candidates, phaseTol, candidateLimit, rawLimit;
		var filteredPeaks, filteredMax, filteredTotal, instantScores, instantPhases, instantFreqs;

		vals = st[\micPolyBus].getnSynchronous(st[\polyBinCount]).collect { |x| x.max(0.0) };
		ampVals = st[\micLevelBus].getnSynchronous(1);
		meterVals = at[\refreshMicMeters].();
		amp = ampVals[0] ? 0.0;
		rawAmp = meterVals[0] ? amp;

		total = vals.sum;
		maxVal = vals.maxItem ? 0.0;
		maxIndex = vals.indexOf(maxVal);
		voiced = (amp >= cfg[\mic][\ampThreshold]) or: { maxVal >= cfg[\mic][\polyAbsThreshold] };

		st[\micRawAmp] = rawAmp;
		st[\micAnalyzedAmp] = amp;
		st[\micVoiced] = voiced;

		if(voiced.not) {
			// Preserve mic-scene dropout hysteresis: a brief low-energy poly frame
			// should decay existing tracks through updateCommittedExternalSources([]),
			// not hard-clear the whole acoustic scene.
			st[\micRawFreq] = 0.0;
			st[\micRawAmp] = rawAmp;
			st[\micAnalyzedAmp] = amp;
			st[\micVoiced] = false;
			st[\micRawCandidates] = Array.new;
			st[\micCandidates] = Array.new;
			st[\micStabilizedCandidates] = Array.new;
			at[\updateCommittedExternalSources].(Array.new);
			at[\updateMicSummaryFromCandidates].(Array.new, 0.0);
			nil;
		} {
			ampNorm = ((amp - cfg[\mic][\ampThreshold]) / 0.08).clip(0.0, 1.0);
			ampNorm = ampNorm.max((maxVal / (cfg[\mic][\polyAbsThreshold] * 10.0 + 0.000001)).clip(0.0, 1.0));

			meanThreshold = (total / (vals.size.max(1).asFloat)) * cfg[\mic][\polyMeanThresholdScale];
			peakThreshold = (maxVal * cfg[\mic][\polyPeakThreshold]).max(cfg[\mic][\polyAbsThreshold]).max(meanThreshold);

			phaseTol = 1.0 / (cfg[\mic][\polyBinsPerOct] * 1.5);
			candidateLimit = cfg[\mic][\polyCandidateLimit].asInteger.max(1);
			rawLimit = cfg[\mic][\rawCandidateLimit].asInteger.max(candidateLimit);

			rawPeaks = Array.new;
			vals.size.do { |i|
				var v, left, right;
				v = vals[i];
				left = if(i > 0) { vals[i - 1] } { 0.0 };
				right = if(i < (vals.size - 1)) { vals[i + 1] } { 0.0 };

				if((v >= peakThreshold) and: { v >= left } and: { v > right }) {
					rawPeaks = rawPeaks.add((
						bin: i,
						energy: v,
						freq: st[\polyBinFreqs][i],
						phase: st[\polyBinPhases][i],
						pc: st[\polyBinPcs][i]
					));
				};
			};

			if(rawPeaks.isEmpty and: { maxVal >= cfg[\mic][\polyAbsThreshold] } and: { maxIndex.notNil }) {
				rawPeaks = [(
					bin: maxIndex,
					energy: maxVal,
					freq: st[\polyBinFreqs][maxIndex],
					phase: st[\polyBinPhases][maxIndex],
					pc: st[\polyBinPcs][maxIndex]
				)];
			};

			filteredPeaks = at[\suppressMicHarmonicPeaks].(rawPeaks);
			filteredMax = 0.0;
			filteredTotal = 0.0;
			filteredPeaks.do { |peak|
				var e;
				e = peak[\energyAdj] ? 0.0;
				filteredTotal = filteredTotal + e;
				if(e > filteredMax) { filteredMax = e; };
			};

			instantScores = Array.fill(cfg[\solver][\numNodes], 0.0);
			instantPhases = Array.fill(cfg[\solver][\numNodes], { nil });
			instantFreqs = Array.fill(cfg[\solver][\numNodes], { nil });
			presentMask = Array.fill(cfg[\solver][\numNodes], false);

			cfg[\solver][\numNodes].do { |pc|
				var group;
				group = filteredPeaks.select { |peak| peak[\pc] == pc };

				if(group.notEmpty) {
					var best, sumEnergy, relPeak, relMass, lowBonus, score;
					presentMask[pc] = true;

					best = group.sort { |a, b| ((a[\energyAdj] ? 0.0) > (b[\energyAdj] ? 0.0)) }.first;
					sumEnergy = group.collect { |peak| peak[\energyAdj] ? 0.0 }.sum;
					relPeak = (sumEnergy > 0.0).if({ ((best[\energyAdj] ? 0.0) / (filteredMax + 0.000001)).clip(0.0, 1.0) }, { 0.0 });
					relMass = (sumEnergy / (filteredTotal + 0.000001)).clip(0.0, 1.0);
					lowBonus = ((cfg[\mic][\polyRefFreq] / ((best[\freq] ? cfg[\mic][\polyRefFreq]).max(1.0))).log2.clip(-1.0, 2.0).max(0.0) * 0.08).clip(0.0, 0.16);
					score = ((((relPeak * 0.58) + (relMass * 0.42)) * ampNorm) + lowBonus).clip(0.0, 1.0);

					instantScores[pc] = score;
					instantPhases[pc] = best[\phase];
					instantFreqs[pc] = best[\freq];
				};
			};

			rawCandidates = Array.new;
			cfg[\solver][\numNodes].do { |pc|
				if((instantScores[pc] ? 0.0) > 0.0 and: { instantPhases[pc].notNil }) {
					rawCandidates = rawCandidates.add(at[\normalizeExternalSource].((
						id: "raw-" ++ pc.asString,
						kind: \mic,
						pc: pc,
						phase: instantPhases[pc],
						freq: instantFreqs[pc] ? 0.0,
						weight: (((instantScores[pc] ? 0.0) * cfg[\mic][\weight] * 1.25)).clip(0.0, 1.5),
						amp: instantScores[pc] ? 0.0,
						confidence: (((instantScores[pc] ? 0.0) * 0.85) + (ampNorm * 0.15)).clip(0.0, 1.0),
						stableFrames: st[\micPcStableCounts][pc] ? 0,
						active: false
					)));
				};
			};
			rawCandidates = at[\takeStrongestSources].(rawCandidates, rawLimit);

			candidates = Array.new;
			cfg[\solver][\numNodes].do { |pc|
				var targetScore, prevScore, scoreAlpha, score, prevPhase, prevFreq, newPhase, newFreq;
				var stableCount, stableFactor, conf, weight, visibleNow, activeNow, phaseDelta;

				targetScore = instantScores[pc];
				prevScore = st[\micPcScores][pc];
				scoreAlpha = if(targetScore > prevScore) { cfg[\mic][\polyScoreAttack] } { cfg[\mic][\polyScoreRelease] };
				score = prevScore + ((targetScore - prevScore) * scoreAlpha.clip(0.0, 1.0));
				st[\micPcScores][pc] = score;

				prevPhase = st[\micPcPrevPhases][pc];
				prevFreq = st[\micPcPrevFreqs][pc];

				if(targetScore > 0.0 and: { instantPhases[pc].notNil }) {
					phaseDelta = if(prevPhase.notNil) { at[\wrapSigned].(instantPhases[pc] - prevPhase).abs } { 0.0 };

					if(prevPhase.notNil and: { st[\micPcVisible][pc] } and: { phaseDelta <= phaseTol }) {
						stableCount = st[\micPcStableCounts][pc] + 1;
					} {
						stableCount = 1;
					};

					newPhase = at[\phaseBlend].(prevPhase, instantPhases[pc], cfg[\mic][\polyPhaseAlpha]);
					newFreq = if(prevFreq.isNil) {
						instantFreqs[pc];
					} {
						prevFreq + ((instantFreqs[pc] - prevFreq) * cfg[\mic][\polyFreqAlpha].clip(0.0, 1.0))
					};

					st[\micPcPrevPhases][pc] = newPhase;
					st[\micPcPrevFreqs][pc] = newFreq;
				} {
					stableCount = 0;
					newPhase = prevPhase;
					newFreq = prevFreq;
				};

				st[\micPcStableCounts][pc] = stableCount;

				visibleNow = if(st[\micPcVisible][pc]) {
					score >= cfg[\mic][\polyVisibleRelease]
				} {
					score >= cfg[\mic][\polyVisibleThreshold]
				};

				activeNow = if(st[\micPcActive][pc]) {
					score >= cfg[\mic][\polyActiveRelease]
				} {
					(score >= cfg[\mic][\polyActiveThreshold]) and: { stableCount >= cfg[\mic][\polyMinStableFrames] }
				};

				st[\micPcVisible][pc] = visibleNow;
				st[\micPcActive][pc] = activeNow;

				if(visibleNow and: { newPhase.notNil }) {
					stableFactor = (stableCount / cfg[\mic][\stableFrames]).clip(0.0, 1.0);
					conf = (((score * 0.75) + (stableFactor * 0.25))).clip(0.0, 1.0);
					weight = (((score.squared * 0.8) + (score * 0.2)) * cfg[\mic][\weight] * 1.55).clip(0.0, 1.5);

					candidates = candidates.add(at[\normalizeExternalSource].((
						id: "mic-" ++ pc.asString,
						kind: \mic,
						pc: pc,
						phase: newPhase,
						freq: newFreq ? 0.0,
						weight: weight,
						amp: targetScore,
						confidence: conf,
						stableFrames: stableCount,
						active: activeNow and: { conf >= cfg[\mic][\minConfidence] } and: { weight > 0.0 }
					)));
				} {
					st[\micPcPrevPhases][pc] = nil;
					st[\micPcPrevFreqs][pc] = nil;
				};
			};

			candidates = at[\takeStrongestSources].(candidates, candidateLimit);
			st[\micRawCandidates] = rawCandidates.copy;
			st[\micCandidates] = candidates.copy;
			st[\micStabilizedCandidates] = candidates.copy;
			at[\updateCommittedExternalSources].(candidates);
			at[\updateMicSummaryFromCandidates].(candidates, st[\polyBinFreqs][maxIndex] ? 0.0);
		};
	};

	at[\refreshMicObservation] = {
		st[\micTickCount] = (st[\micTickCount] ? 0) + 1;
		if(cfg[\mic][\enabled].not) {
			st[\micRawFreq] = 0.0;
			st[\micRawAmp] = 0.0;
			st[\micVoiced] = false;
			at[\clearMicEvidence].();
			nil;
		} {
			if(cfg[\mic][\mode] == \polyPc) {
				at[\refreshMicObservationPoly].();
			} {
				at[\refreshMicObservationMono].();
			};
		};
	};

	at[\currentExternalSources] = {
		(st[\externalSources] ? Array.new).select { |src| src.notNil and: { src[\active] != false } };
	};

	at[\currentMicSource] = {
		var sources;
		sources = at[\currentExternalSources].();
		if(sources.isEmpty) {
			nil;
		} {
			at[\sortSourcesByStrength].(sources).first
		};
	};

	at[\micKeyForSources] = { |sources|
		var ordered;
		if(sources.isNil or: { sources.isEmpty }) {
			nil;
		} {
			ordered = (sources ? Array.new).sort { |a, b| (a[\pc] ? 0) < (b[\pc] ? 0) };
			ordered.collect { |src|
				[
					src[\pc],
					(src[\phase] ? 0.0).round(cfg[\mic][\keyPhaseQuant]),
					(src[\weight] ? 0.0).round(cfg[\mic][\keyWeightQuant]),
					(src[\confidence] ? 0.0).round(cfg[\mic][\keyConfidenceQuant])
				]
			}
		}
	};

	at[\strongestExternalSource] = { |sources|
		if(sources.isNil or: { sources.isEmpty }) {
			nil;
		} {
			at[\sortSourcesByStrength].(sources).first
		}
	};

	// harmonic force construction moved to AT_evidence.scd; mic now only publishes external pressure.

	// ------------------------------------------------------------
	// mic synth control
	// ------------------------------------------------------------

	at[\clearMicBuses] = {
		st[\micBus].setn([0.0, 0.0]);
		st[\micLevelBus].set(0.0);
		st[\micMeterBus].setn([0.0, 0.0, 0.0, 0.0]);
		st[\micPolyBus].setn(Array.fill(st[\polyBinCount], 0.0));
	};

	at[\freeMicSynth] = {
		if(st[\micSynth].notNil) {
			st[\micSynth].free;
			st[\micSynth] = nil;
		};
		at[\clearMicBuses].();
	};

	at[\spawnMicSynth] = {
		if(cfg[\mic][\mode] == \polyPc) {
			st[\micSynth] = Synth(\atmicpolytracker, [
				\binBus, st[\micPolyBus].index,
				\ampBus, st[\micLevelBus].index,
				\meterBus, st[\micMeterBus].index,
				\inputMode, at[\micInputModeIndex].(),
				\micGain, cfg[\mic][\gain]
			]);
		} {
			st[\micSynth] = Synth(\atmictracker, [
				\freqBus, st[\micBus].index,
				\ampBus, st[\micBus].index + 1,
				\meterBus, st[\micMeterBus].index,
				\inputMode, at[\micInputModeIndex].(),
				\micGain, cfg[\mic][\gain],
				\pitchAmpThreshold, cfg[\mic][\pitchAmpThreshold] ? 0.00025,
				\pitchDetectGain, cfg[\mic][\pitchDetectGain] ? 10.0,
				\zeroCrossFallback, if((cfg[\mic][\zeroCrossFallback] ? true) == true) { 1 } { 0 },
				\zeroCrossAmpThreshold, cfg[\mic][\zeroCrossAmpThreshold] ? 0.00018,
				\pitchMedian, cfg[\mic][\pitchMedian] ? 3,
				\pitchMinFreq, cfg[\mic][\pitchMinFreq] ? 35.0,
				\pitchMaxFreq, cfg[\mic][\pitchMaxFreq] ? 2200.0,
				\pitchExecFreq, cfg[\mic][\pitchExecFreq] ? 50.0
			]);
		};
	};

	at[\rebuildMicSynth] = {
		if(cfg[\mic][\enabled]) {
			at[\freeMicSynth].();
			at[\spawnMicSynth].();
		};
	};

};
)
