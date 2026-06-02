(
// AT_solver_body.scd
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


    // v2h: live-audition runtime guard. Some product builds load the legacy
    // event solver without the old split-core helper file. Install the small
    // numeric helpers here so the background live field cannot leak nil through
    // passive ghost/context-break bookkeeping during audible auditions.
    if(at[\medianSignedDeviation].isNil) {
        at[\medianSignedDeviation] = {
            var n, ph, et, devs, sorted, idx;
            n = cfg[\solver][\numNodes] ? 12;
            ph = st[\nodePhase] ? Array.fill(n, { |i| i / n.asFloat });
            et = st[\etPhase] ? Array.fill(n, { |i| i / n.asFloat });
            devs = Array.fill(n, { |i| at[\wrapSigned].((ph[i] ? (et[i] ? (i / n.asFloat))) - (et[i] ? (i / n.asFloat))) });
            sorted = devs.copy.sort;
            idx = (sorted.size / 2).floor.clip(0, sorted.size - 1);
            if(sorted.isEmpty) { 0.0 } { sorted[idx] ? 0.0 }
        };
    };

    if(at[\activeMaxDeviationCents].isNil) {
        at[\activeMaxDeviationCents] = { |activePcs|
            var n, ph, et, vals;
            n = cfg[\solver][\numNodes] ? 12;
            ph = st[\nodePhase] ? Array.fill(n, { |i| i / n.asFloat });
            et = st[\etPhase] ? Array.fill(n, { |i| i / n.asFloat });
            vals = (activePcs ? Array.new).collect { |pc|
                var p;
                p = (pc ? 0).asInteger % n;
                (at[\wrapSigned].((ph[p] ? (et[p] ? (p / n.asFloat))) - (et[p] ? (p / n.asFloat))) * 1200.0).abs
            };
            if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 }
        };
    };

    if(at[\passiveMaxDeviationCents].isNil) {
        at[\passiveMaxDeviationCents] = { |activePcs|
            var n, ph, et, activeSet, vals;
            n = cfg[\solver][\numNodes] ? 12;
            ph = st[\nodePhase] ? Array.fill(n, { |i| i / n.asFloat });
            et = st[\etPhase] ? Array.fill(n, { |i| i / n.asFloat });
            activeSet = IdentitySet.new;
            (activePcs ? Array.new).do { |pc| activeSet.add((pc ? 0).asInteger % n); };
            vals = Array.new;
            n.do { |pc|
                if(activeSet.includes(pc).not) {
                    vals = vals.add((at[\wrapSigned].((ph[pc] ? (et[pc] ? (pc / n.asFloat))) - (et[pc] ? (pc / n.asFloat))) * 1200.0).abs);
                };
            };
            if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 }
        };
    };

    if(at[\commonToneDriftFromFrozenCents].isNil) {
        at[\commonToneDriftFromFrozenCents] = { |activePcs|
            var n, ph, frozen, commonPcs, vals;
            n = cfg[\solver][\numNodes] ? 12;
            if((st[\frozenValid] ? false).not or: { st[\frozenPhase].isNil }) {
                0.0
            } {
                ph = st[\nodePhase] ? Array.fill(n, { |i| i / n.asFloat });
                frozen = st[\frozenPhase] ? ph;
                commonPcs = (activePcs ? Array.new).select { |pc| (st[\lastFrozenActivePcs] ? Array.new).includes(pc) };
                vals = commonPcs.collect { |pc|
                    var p;
                    p = (pc ? 0).asInteger % n;
                    (at[\wrapSigned].((ph[p] ? (frozen[p] ? (p / n.asFloat))) - (frozen[p] ? (p / n.asFloat))) * 1200.0).abs
                };
                if(vals.isEmpty) { 0.0 } { vals.maxItem ? 0.0 }
            }
        };
    };

    	at[\activeCentroidCents] = { |activePcs|
    		var vals, sum;
    		vals = Array.new;
    		(activePcs ? Array.new).do { |pc| vals = vals.add(at[\devArray].()[pc] * 1200.0); };
    		if(vals.isEmpty) { 0.0 } {
    			sum = 0.0;
    			vals.do { |x| sum = sum + x; };
    			sum / vals.size.asFloat.max(1.0)
    		}
    	};

    	at[\numArrayMeanAbs] = { |vals|
    		var sum;
    		if((vals ? Array.new).isEmpty) { 0.0 } {
    			sum = 0.0;
    			vals.do { |x| sum = sum + x.abs; };
    			sum / vals.size.asFloat.max(1.0)
    		}
    	};

    	at[\numArrayMaxAbs] = { |vals|
    		var m;
    		m = 0.0;
    		(vals ? Array.new).do { |x| m = m.max(x.abs); };
    		m
    	};

    	at[\numArrayCentroid] = { |vals|
    		var sum;
    		if((vals ? Array.new).isEmpty) { 0.0 } {
    			sum = 0.0;
    			vals.do { |x| sum = sum + x; };
    			sum / vals.size.asFloat.max(1.0)
    		}
    	};

    	at[\numArraySpread] = { |vals|
    		at[\numArrayMaxAbs].(vals) - at[\numArrayMeanAbs].(vals)
    	};

    	at[\numArrayLargest] = { |vals, pcs|
    		var maxAbs, signed, pc;
    		maxAbs = 0.0;
    		signed = 0.0;
    		pc = nil;
    		(vals ? Array.new).do { |x, i|
    			if(x.abs > maxAbs) {
    				maxAbs = x.abs;
    				signed = x;
    				pc = (pcs ? Array.new)[i];
    			};
    		};
    		(pc: pc, signed: signed, maxAbs: maxAbs)
    	};

    	at[\forceValsFor] = { |forces, activePcs|
    		(activePcs ? Array.new).collect { |pc| forces[pc] ? 0.0 }
    	};

    	at[\bodyWeightedMean] = { |vals, activePcs, pcWeights|
    		var weightedSum, totalWeight, weight;
    		weightedSum = 0.0;
    		totalWeight = 0.0;
    		(vals ? Array.new).do { |x, i|
    			var pc;
    			pc = (activePcs ? Array.new)[i];
    			weight = if(pcWeights.isNil or: { pc.isNil }) { 1.0 } { ((pcWeights[pc] ? 0.0).max(0.15)) };
    			weightedSum = weightedSum + (x * weight);
    			totalWeight = totalWeight + weight;
    		};
    		if(totalWeight <= 0.000001) { 0.0 } { weightedSum / totalWeight }
    	};

    	at[\bodyProjectValues] = { |vals, activePcs, pcWeights, shapeScale, strongShapeScale, thresholdCentsOrNil=nil, unitsPerCent=1.0|
    		var mean, devs, maxDev, threshold, effectiveScale;
    		mean = at[\bodyWeightedMean].(vals, activePcs, pcWeights);
    		devs = (vals ? Array.new).collect { |x| x - mean };
    		maxDev = at[\numArrayMaxAbs].(devs);
    		threshold = if(thresholdCentsOrNil.isNil) { 999999.0 } { thresholdCentsOrNil * unitsPerCent };
    		effectiveScale = if(maxDev > threshold) { strongShapeScale } { shapeScale };
    		(
    			mean: mean,
    			maxDev: maxDev,
    			effectiveScale: effectiveScale,
    			values: devs.collect { |d| mean + (d * effectiveScale) }
    		)
    	};

    	at[\r15kActiveBodyReport] = { |label, activePcs, beforeVals, afterVals, extra=nil|
    		var beforeLargest, afterLargest, report;
    		beforeLargest = at[\numArrayLargest].(beforeVals, activePcs);
    		afterLargest = at[\numArrayLargest].(afterVals, activePcs);
    		report = (
    			timestamp: Main.elapsedTime,
    			mode: label,
    			activePcs: (activePcs ? Array.new).copy,
    			beforeMaxAbs: at[\numArrayMaxAbs].(beforeVals),
    			afterMaxAbs: at[\numArrayMaxAbs].(afterVals),
    			beforeMeanAbs: at[\numArrayMeanAbs].(beforeVals),
    			afterMeanAbs: at[\numArrayMeanAbs].(afterVals),
    			beforeSpread: at[\numArraySpread].(beforeVals),
    			afterSpread: at[\numArraySpread].(afterVals),
    			beforeCentroid: at[\numArrayCentroid].(beforeVals),
    			afterCentroid: at[\numArrayCentroid].(afterVals),
    			beforeLargestPc: beforeLargest[\pc],
    			beforeLargestValue: beforeLargest[\signed],
    			afterLargestPc: afterLargest[\pc],
    			afterLargestValue: afterLargest[\signed]
    		);
    		if(extra.notNil) {
    			extra.keysValuesDo { |k, v| report[k] = v; };
    		};
    		report
    	};

    	at[\r15kActiveBodyForceProjection] = { |forces, activePcs, pcWeights|
    		var out, activeCount, vals, projected, shapeScale, strongScale, passiveGauge, mean;
    		out = forces.copy;
    		activePcs = activePcs ? Array.new;
    		activeCount = activePcs.size;
    		if(((cfg[\solver][\activeBodyBalanceEnabled] ? true) == false) or: { activeCount <= 1 }) {
    			out
    		} {
    			vals = at[\forceValsFor].(forces, activePcs);
    			shapeScale = (cfg[\solver][\activeForceSpreadScale] ? 0.44).clip(0.05, 1.0);
    			strongScale = (shapeScale * 0.72).clip(0.05, shapeScale);
    			projected = at[\bodyProjectValues].(vals, activePcs, pcWeights, shapeScale, strongScale, nil, 1.0);
    			mean = projected[\mean] ? 0.0;
    			activePcs.do { |apc, idx| out[apc] = projected[\values][idx]; };
    			passiveGauge = (cfg[\solver][\activeForceGaugeToPassive] ? 0.25).clip(0.0, 1.0);
    			if(passiveGauge > 0.0) {
    				cfg[\solver][\numNodes].do { |j|
    					if(activePcs.includes(j).not) { out[j] = (out[j] ? 0.0) + (mean * passiveGauge); };
    				};
    			};
    			if(cfg[\solver][\diagnosticSolverReports] ? false) {
    				st[\lastActiveForceBodyReport] = at[\r15kActiveBodyReport].(
    					\forceProjection,
    					activePcs,
    					vals,
    					activePcs.collect { |apc| out[apc] ? 0.0 },
    					(mean: mean, shapeScale: shapeScale, passiveGauge: passiveGauge)
    				);
    			};
    			out
    		}
    	};

    	at[\r15kProjectActiveDeltaBody] = { |delta, activePcs, pcWeights, reason=\event|
    		var out, activeCount, vals, projected, shapeScale, strongScale, threshold, passiveGauge, mean, afterVals;
    		out = delta.copy;
    		activePcs = activePcs ? Array.new;
    		activeCount = activePcs.size;
    		if(((cfg[\solver][\activeDeltaProjectionEnabled] ? true) == false) or: { activeCount <= 1 }) {
    			out
    		} {
    			vals = activePcs.collect { |pc| delta[pc] ? 0.0 };
    			shapeScale = (cfg[\solver][\activeDeltaShapeScale] ? 0.56).clip(0.05, 1.0);
    			strongScale = (cfg[\solver][\activeDeltaStrongShapeScale] ? 0.34).clip(0.05, shapeScale);
    			threshold = cfg[\solver][\activeDeltaOutlierThresholdCents] ? 5.5;
    			projected = at[\bodyProjectValues].(vals, activePcs, pcWeights, shapeScale, strongScale, threshold, 1.0 / 1200.0);
    			mean = projected[\mean] ? 0.0;
    			activePcs.do { |apc, idx| out[apc] = projected[\values][idx]; };
    			passiveGauge = (cfg[\solver][\activeDeltaGaugeToPassive] ? 0.20).clip(0.0, 1.0);
    			if(passiveGauge > 0.0) {
    				cfg[\solver][\numNodes].do { |j|
    					if(activePcs.includes(j).not) { out[j] = (out[j] ? 0.0) + (mean * passiveGauge); };
    				};
    			};
    			afterVals = activePcs.collect { |apc| out[apc] ? 0.0 };
    			if(cfg[\solver][\diagnosticSolverReports] ? false) {
    				st[\lastActiveBodyProjectionReport] = at[\r15kActiveBodyReport].(
    					\deltaProjection,
    					activePcs,
    					vals.collect { |x| x * 1200.0 },
    					afterVals.collect { |x| x * 1200.0 },
    					(reason: reason, meanCents: mean * 1200.0, shapeScale: projected[\effectiveScale], passiveGauge: passiveGauge)
    				);
    			};
    			out
    		}
    	};

    	// Backwards-compatible entry point used by older code paths.

    	at[\activeForceBodyBalance] = { |forces, activePcs, pcWeights|
    		at[\r15kActiveBodyForceProjection].(forces, activePcs, pcWeights)
    	};

    	at[\applySoftAnchorGauge] = { |anchorPc, anchorPhase, activePcs=nil, pcWeights=nil, mode=\event|
    		var offset, strength, maxOffset, step;
    		if(((cfg[\solver][\softAnchorEnabled] ? true) == false) or: { anchorPc.isNil or: { anchorPhase.isNil } }) {
    			0.0
    		} {
    			offset = at[\wrapSigned].((anchorPhase ? (st[\etPhase][anchorPc] ? 0.0)) - (st[\nodePhase][anchorPc] ? (st[\etPhase][anchorPc] ? 0.0)));
    			strength = if(mode == \continuous) {
    				cfg[\solver][\softAnchorContinuousStrength] ? 0.04
    			} {
    				cfg[\solver][\softAnchorIterStrength] ? 0.11
    			};
    			maxOffset = ((cfg[\solver][\softAnchorMaxCents] ? 0.0) / 1200.0).max(0.0);
    			step = offset * strength.clip(0.0, 1.0);
    			if(maxOffset > 0.0) { step = step.clip(maxOffset.neg, maxOffset); };
    			if(step.abs > 0.0000000001) {
    				st[\nodePhase] = st[\nodePhase].collect { |p| at[\wrap01].((p ? 0.0) + (step ? 0.0)) };
    			};
    			if((cfg[\solver][\diagnosticSolverReports] ? false) or: { (mode == \continuous) and: { cfg[\solver][\diagnosticContinuousReports] ? false } }) {
    				st[\lastSoftAnchorReport] = (
    					timestamp: Main.elapsedTime,
    					mode: mode,
    					pc: anchorPc,
    					rawOffsetCents: offset * 1200.0,
    					appliedCents: step * 1200.0,
    					strength: strength
    				);
    			};
    			step
    		}
    	};

    	at[\activeMotionStatsFrom] = { |activePcs, previousPhases|
    		var maxAbs, sumAbs, count, pcOfMax, signedOfMax, centroid, vals;
    		maxAbs = 0.0;
    		sumAbs = 0.0;
    		count = 0.0;
    		pcOfMax = nil;
    		signedOfMax = 0.0;
    		vals = Array.new;
    		(activePcs ? Array.new).do { |pc|
    			var signed;
    			signed = at[\wrapSigned].((st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)) - (previousPhases[pc] ? (st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)))) * 1200.0;
    			vals = vals.add(signed);
    			sumAbs = sumAbs + signed.abs;
    			count = count + 1.0;
    			if(signed.abs > maxAbs) {
    				maxAbs = signed.abs;
    				pcOfMax = pc;
    				signedOfMax = signed;
    			};
    		};
    		centroid = if(vals.isEmpty) { 0.0 } { vals.sum / vals.size.asFloat.max(1.0) };
    		(
    			maxAbsCents: maxAbs,
    			meanAbsCents: if(count <= 0.0) { 0.0 } { sumAbs / count },
    			spreadCents: maxAbs - (if(count <= 0.0) { 0.0 } { sumAbs / count }),
    			pcOfMax: pcOfMax,
    			signedOfMaxCents: signedOfMax,
    			centroidCents: centroid,
    			motions: vals
    		)
    	};

    	at[\applyActiveFloatingGauge] = { |activePcs, pcWeights, previousPhases, reason=\event|
    		var enabled, before, after, totalWeight, weightedOffset, weight, offset, strength, gauge, applied, activeCount, transportReason;
    		enabled = cfg[\solver][\activeFloatingGaugeEnabled] ? true;
    		activePcs = activePcs ? Array.new;
    		activeCount = activePcs.size;
    		if((enabled == false) or: { activeCount <= 1 or: { previousPhases.isNil } }) {
    			0.0
    		} {
    			before = at[\activeMotionStatsFrom].(activePcs, previousPhases);
    			weightedOffset = 0.0;
    			totalWeight = 0.0;
    			activePcs.do { |pc|
    				weight = if(pcWeights.isNil) { 1.0 } { ((pcWeights[pc] ? 0.0).max(0.20)) };
    				offset = at[\wrapSigned].((previousPhases[pc] ? (st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0))) - (st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)));
    				weightedOffset = weightedOffset + (offset * weight);
    				totalWeight = totalWeight + weight;
    			};
    			if(totalWeight <= 0.000001) { gauge = 0.0 } { gauge = weightedOffset / totalWeight };
    			strength = if(reason == \contextBreak) {
    				cfg[\solver][\activeFloatingGaugeContextStrength] ? 0.68
    			} {
    				cfg[\solver][\activeFloatingGaugeStrength] ? 0.52
    			};
    			transportReason = if(reason == \contextBreak) { \contextBreak } { \activeBody };
    			applied = at[\applyCoherentGaugeTransport].(gauge, transportReason, strength, 1.0, 1.0, nil);
    			after = at[\activeMotionStatsFrom].(activePcs, previousPhases);
    			st[\lastActiveChordBodyReport] = (
    				timestamp: Main.elapsedTime,
    				reason: reason,
    				activePcs: activePcs.copy,
    				floatingGaugeCents: applied * 1200.0,
    				requestedGaugeCents: gauge * 1200.0,
    				positionCapCents: nil,
    				strength: strength,
    				beforeMaxMotionCents: before[\maxAbsCents],
    				afterMaxMotionCents: after[\maxAbsCents],
    				beforeMeanMotionCents: before[\meanAbsCents],
    				afterMeanMotionCents: after[\meanAbsCents],
    				beforeSpreadCents: before[\spreadCents],
    				afterSpreadCents: after[\spreadCents],
    				largestMoverPc: after[\pcOfMax],
    				largestMoverCents: after[\signedOfMaxCents],
    				activeCentroidCents: at[\activeCentroidCents].(activePcs)
    			);
    			applied
    		}
    	};

    	at[\applyActiveStrainLimiter] = { |activePcs, pcWeights, previousPhases, reason=\event|
    		var enabled, stats, threshold, excess, amount, maxPerCall, pc, signed, correction, share, count;
    		enabled = cfg[\solver][\activeStrainLimiterEnabled] ? true;
    		activePcs = activePcs ? Array.new;
    		if((enabled == false) or: { activePcs.size <= 2 or: { previousPhases.isNil } }) {
    			0.0
    		} {
    			stats = at[\activeMotionStatsFrom].(activePcs, previousPhases);
    			threshold = cfg[\solver][\activeStrainOutlierThresholdCents] ? 5.5;
    			excess = (stats[\maxAbsCents] - threshold).max(0.0);
    			if(excess <= 0.0001) {
    				st[\lastActiveStrainLimiterReport] = nil;
    				0.0
    			} {
    				pc = stats[\pcOfMax];
    				signed = stats[\signedOfMaxCents] ? 0.0;
    				maxPerCall = cfg[\solver][\activeStrainLimiterMaxCents] ? 8.0;
    				amount = (excess * (cfg[\solver][\activeStrainLimiterStrength] ? 0.72)).clip(0.0, maxPerCall);
    				correction = (0.0 - signed.sign) * (amount / 1200.0);
    				st[\nodePhase][pc] = at[\wrap01].((st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)) + (correction ? 0.0));
    				count = (activePcs.size - 1).max(1).asFloat;
    				share = (correction.neg * (cfg[\solver][\activeStrainLimiterShare] ? 0.55)) / count;
    				activePcs.do { |otherPc|
    					if(otherPc != pc) { st[\nodePhase][otherPc] = at[\wrap01].((st[\nodePhase][otherPc] ? (st[\etPhase][otherPc] ? 0.0)) + (share ? 0.0)); };
    				};
    				st[\lastActiveStrainLimiterReport] = (
    					timestamp: Main.elapsedTime,
    					reason: reason,
    					pc: pc,
    					largestMoverCents: signed,
    					beforeSpreadCents: stats[\spreadCents],
    					appliedCents: correction * 1200.0,
    					sharedCents: share * 1200.0,
    					activePcs: activePcs.copy
    				);
    				correction
    			}
    		}
    	};


    	// r15m passive ghosts follow the active/external body; they do not lead it.

    	at[\applyPassiveGhostDissipation] = { |activePcs, reason=\event, externalSources=nil|
    		var enabled, activeSet, vals, gauge, blend, target, off, beforePassive, afterPassive;
    		enabled = cfg[\solver][\passiveGhostDissipationEnabled] ? true;
    		activePcs = activePcs ? Array.new;
    		if((enabled == false) or: { activePcs.isEmpty }) {
    			0.0
    		} {
    			activeSet = IdentitySet.new;
    			activePcs.do { |pc| activeSet.add((pc ? 0).asInteger % (cfg[\solver][\numNodes] ? 12)); };
    			vals = activePcs.collect { |pc| var p; p = (pc ? 0).asInteger % (cfg[\solver][\numNodes] ? 12); at[\wrapSigned].((st[\nodePhase][p] ? (st[\etPhase][p] ? 0.0)) - (st[\etPhase][p] ? 0.0)) };
    			gauge = if(vals.isEmpty) { at[\medianSignedDeviation].() } { vals.sum / vals.size.asFloat.max(1.0) };
    			blend = if(reason == \continuous) {
    				cfg[\solver][\passiveGhostContinuousDissipation] ? 0.018
    			} {
    				if((externalSources ? Array.new).notEmpty) {
    					cfg[\solver][\passiveGhostExternalDissipation] ? 0.16
    				} {
    					if(reason == \contextBreak) { cfg[\solver][\passiveGhostContextDissipation] ? 0.42 } { cfg[\solver][\passiveGhostDissipation] ? 0.10 }
    				}
    			};
    			blend = blend.clip(0.0, 1.0);
    			beforePassive = (if(at[\passiveMaxDeviationCents].notNil) { at[\passiveMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    			if(blend > 0.0) {
    				cfg[\solver][\numNodes].do { |pc|
    					if(activeSet.includes(pc).not) {
    						target = at[\wrap01].((st[\etPhase][pc] ? (pc / (cfg[\solver][\numNodes] ? 12).asFloat)) + (gauge ? 0.0));
    						off = at[\wrapSigned].((target ? (st[\etPhase][pc] ? 0.0)) - (st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)));
    						st[\nodePhase][pc] = at[\wrap01].((st[\nodePhase][pc] ? (st[\etPhase][pc] ? 0.0)) + ((off ? 0.0) * (blend ? 0.0)));
    					};
    				};
    			};
    			afterPassive = (if(at[\passiveMaxDeviationCents].notNil) { at[\passiveMaxDeviationCents].(activePcs) } { 0.0 }) ? 0.0;
    			if((reason != \continuous) or: { cfg[\solver][\diagnosticContinuousReports] ? false }) {
    				st[\lastPassiveGhostReport] = (
    					timestamp: Main.elapsedTime,
    					reason: reason,
    					gaugeCents: gauge * 1200.0,
    					blend: blend,
    					beforePassiveMaxCents: beforePassive,
    					afterPassiveMaxCents: afterPassive,
    					activePcs: activePcs.copy
    				);
    			};
    			(afterPassive ? 0.0) - (beforePassive ? 0.0)
    		}
    	};


    	// batch solvers
    	// ------------------------------------------------------------

};
)
