(
// AT_mic_observation.scd
// Behavior-preserving split from AT_mic.scd.
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

    			ampNorm = ((amp - cfg[\mic][\ampThreshold]) / 0.08).clip(0.0, 1.0);
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
    				st[\micRawFreq] = 0.0;
    				st[\micRawAmp] = rawAmp;
    				st[\micAnalyzedAmp] = amp;
    				st[\micVoiced] = false;
    				if(cfg[\micScene].notNil and: { cfg[\micScene][\enabled] ? true }) {
    					st[\micRawCandidates] = Array.new;
    					st[\micCandidates] = Array.new;
    					st[\micStabilizedCandidates] = Array.new;
    					at[\updateCommittedExternalSources].(Array.new);
    					at[\updateMicSummaryFromCandidates].(Array.new, 0.0);
    				} {
    					at[\clearMicEvidence].();
    				};
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

};
)
