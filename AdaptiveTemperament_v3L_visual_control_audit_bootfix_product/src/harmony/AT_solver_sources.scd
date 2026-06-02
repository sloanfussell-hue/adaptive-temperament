(
// AT_solver_sources.scd
// v2d: runtime guard for live Motion proof: internal/external source phases and weights fall back numerically instead of leaking nil into solver force paths.
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

    	at[\singletonContinuityAnchor] = { |pc, externalSources|
    		var primaryExternal, pending;
    		primaryExternal = at[\strongestExternalSource].(externalSources ? Array.new);

    		if(primaryExternal.notNil and: { at[\sourceStrength].(primaryExternal) > 0.000001 }) {
    			nil
    		} {
    			pending = st[\singletonReentryPending];
    			if(pending.notNil and: { pending[\pc] == pc } and: { pending[\anchorPhase].notNil }) {
    				pending[\anchorPhase]
    			} {
    				if(st[\frozenValid] == true) {
    					st[\frozenPhase][pc]
    				} {
    					nil
    				}
    			}
    		}
    	};

    	at[\chooseAnchorPc] = { |activePcs, pcWeights, externalSources=nil|
    		var info, now, recentWindow, pc, commonPcs, structuralExternal, bestExternalTrust, externalTrust, externalStability, notes, lowestNote;
    		activePcs = activePcs ? Array.new;
    		if(activePcs.isEmpty) { nil } {
    			info = st[\lastOnsetInfo];
    			now = Main.elapsedTime;
    			recentWindow = cfg[\solver][\contextGaugeRecentWindow] ? 0.35;

    			if((cfg[\solver][\lowerOnsetResettleEnabled] ? true)
    				and: { info.notNil }
    				and: { (info[\wasLowerOnset] ? false) == true }
    				and: { (now - (info[\timestamp] ? now)) <= recentWindow }
    				and: { activePcs.includes(info[\pc]) }) {
    				pc = info[\pc];
    				st[\lastAnchorChoice] = (timestamp: now, pc: pc, reason: \lowerOnsetResettle, activePcs: activePcs.copy);
    				pc
    			} {
    				// r15i: if a stable external structural bass/source agrees with an active pitch class,
    				// let it anchor the local episode before falling back to internal strength.
    				structuralExternal = nil;
    				bestExternalTrust = 0.0;
    				(externalSources ? Array.new).do { |src|
    					if(src.notNil and: { src[\pc].notNil } and: { activePcs.includes(src[\pc]) }) {
    						externalTrust = at[\externalEvidenceTrustScale].(src);
    						externalStability = (src[\stability] ? 0.0).clip(0.0, 1.0);
    						if((externalTrust > bestExternalTrust) and: { externalTrust > 0.32 } and: { externalStability > 0.55 }) {
    							structuralExternal = src;
    							bestExternalTrust = externalTrust;
    						};
    					};
    				};

    				if(structuralExternal.notNil) {
    					pc = structuralExternal[\pc];
    					st[\lastAnchorChoice] = (timestamp: now, pc: pc, reason: \externalStructuralSource, activePcs: activePcs.copy, trust: bestExternalTrust);
    					pc
    				} {
    					commonPcs = activePcs.select { |x| (st[\lastFrozenActivePcs] ? Array.new).includes(x) };
    					if((commonPcs.size == 1) and: { (st[\lastContextBreakReport].notNil) and: { (st[\lastContextBreakReport][\isBreak] ? false).not } }) {
    						pc = commonPcs[0];
    						st[\lastAnchorChoice] = (timestamp: now, pc: pc, reason: \stableCommonTone, activePcs: activePcs.copy);
    						pc
    					} {
    						// Prefer actual lowest internal note when it is unambiguous; this is a musical anchor,
    						// not an ET truth source. Fall back to strongest pitch-class weight.
    						notes = at[\notesArray].().select { |n| activePcs.includes(n[\pc]) };
    						lowestNote = if(notes.isEmpty) { nil } { notes.sort { |a, b| a[\midi] < b[\midi] }[0] };
    						if(lowestNote.notNil and: { activePcs.includes(lowestNote[\pc]) }) {
    							pc = lowestNote[\pc];
    							st[\lastAnchorChoice] = (timestamp: now, pc: pc, reason: \lowestInternalNote, activePcs: activePcs.copy, midi: lowestNote[\midi]);
    							pc
    						} {
    							pc = at[\strongestPc].(activePcs, pcWeights);
    							st[\lastAnchorChoice] = (timestamp: now, pc: pc, reason: \strongestActive, activePcs: activePcs.copy);
    							pc
    						}
    					}
    				}
    			}
    		}
    	};

    	at[\chooseAnchorPhase] = { |anchorPc|
    		var info, now, recentWindow, blend, prevPhase, currentPhase;
    		currentPhase = if(anchorPc.isNil) { nil } { (st[\nodePhase][anchorPc] ? st[\etPhase][anchorPc]) };
    		info = st[\lastOnsetInfo];
    		now = Main.elapsedTime;
    		recentWindow = cfg[\solver][\contextGaugeRecentWindow] ? 0.35;
    		if((cfg[\solver][\lowerOnsetResettleEnabled] ? true)
    			and: { info.notNil }
    			and: { (info[\wasLowerOnset] ? false) == true }
    			and: { info[\pc] == anchorPc }
    			and: { info[\prevNodePhase].notNil }
    			and: { (now - (info[\timestamp] ? now)) <= recentWindow }) {
    			prevPhase = info[\prevNodePhase][anchorPc];
    			blend = (cfg[\solver][\lowerOnsetAnchorBlend] ? 0.62).clip(0.0, 1.0);
    			at[\wrap01].(currentPhase + (at[\wrapSigned].(prevPhase - currentPhase) * blend))
    		} {
    			currentPhase
    		}
    	};



    	// v2b bootfix: this split source module can be loaded without the old
    	// AT_solver_core helper module. Keep ratio-choice scoring numerically
    	// defined by installing the same tension simplicity exponent fallback here.
    	// This is not a tuning-law change; it only prevents nil.pow during live
    	// single-note/external target calculation.
    	if(at[\tensionSimplicityExponent].isNil) {
    		at[\tensionSimplicityExponent] = {
    			(0.65 + (((cfg[\solver][\tensionPitchReference] ? 0.55).clip(0.0, 1.0)) * 0.85)).clip(0.50, 1.60)
    		};
    	};

    	// ------------------------------------------------------------
    	// r15i context-break rebase: release incompatible inherited local shape
    	// while preserving broad global gauge. This is deliberately not an ET reset.
    	// ------------------------------------------------------------

    	at[\bestChoiceFor] = { |currentDiff, pcDistance|
    		var choices, bestPhase, bestWeight, bestCost;
    		choices = at[\ratioChoices][pcDistance];
    		bestPhase = choices[0][0];
    		bestWeight = choices[0][1];
    		bestCost = (at[\wrapSigned].(currentDiff - bestPhase)).abs / ((bestWeight.max(0.000001)).pow(at[\tensionSimplicityExponent].()) + 0.000001);

    		choices.do { |pair|
    			var phase, weight, cost;
    			phase = pair[0];
    			weight = pair[1];
    			cost = (at[\wrapSigned].(currentDiff - phase)).abs / ((weight.max(0.000001)).pow(at[\tensionSimplicityExponent].()) + 0.000001);
    			if(cost < bestCost) {
    				bestCost = cost;
    				bestPhase = phase;
    				bestWeight = weight;
    			};
    		};

    		[bestPhase, bestWeight];
    	};

    	at[\buildSources] = { |activePcs, pcWeights, externalSources=nil|
    		var sources;
    		sources = Array.new;
        activePcs = activePcs ? Array.new;
        pcWeights = pcWeights ? Array.fill(cfg[\solver][\numNodes] ? 12, 0.0);

    		activePcs.do { |pc|
            pc = pc.asInteger % (cfg[\solver][\numNodes] ? 12);
    			sources = sources.add((
    				pc: pc,
    				phase: st[\nodePhase][pc] ? st[\etPhase][pc],
    				weight: (pcWeights[pc] ? 0.0).clip(0.05, 2.0),
    				isInternal: true,
    				kind: \internal
    			));
    		};

    		(externalSources ? Array.new).do { |src|
    			if(src.notNil and: { src[\pc].notNil } ) {
    				var trust, roleScale, effectiveWeight, epc;
                epc = src[\pc].asInteger % (cfg[\solver][\numNodes] ? 12);
    				trust = if(at[\externalEvidenceTrustScale].notNil) { at[\externalEvidenceTrustScale].(src) ? 0.0 } { 1.0 };
    				roleScale = if(at[\externalRoleRelationalScale].notNil) { at[\externalRoleRelationalScale].(src, activePcs) ? 1.0 } { 1.0 };
    				effectiveWeight = ((src[\weight] ? 0.0).clip(0.0, 1.5) * trust * roleScale).clip(0.0, 1.5);
    				sources = sources.add((
    					pc: epc,
    					phase: src[\phase] ? (st[\nodePhase][epc] ? st[\etPhase][epc]),
    					weight: effectiveWeight,
    					rawWeight: (src[\weight] ? 0.0).clip(0.0, 1.5),
    					trustScale: trust,
    					roleScale: roleScale,
    					sourceRole: src[\sourceRole] ? \externalMic,
    					isInternal: false,
    					isExternal: true,
    					confidence: src[\confidence] ? 1.0,
    					kind: src[\kind] ? \external
    				));
    			};
    		};

    		if(at[\gravityPitchClassSources].notNil) {
    			sources = sources ++ at[\gravityPitchClassSources].(activePcs, pcWeights, externalSources);
    		};
    		sources = sources ++ at[\buildMemorySources].(activePcs, pcWeights, externalSources);
    		sources;
    	};

};
)
