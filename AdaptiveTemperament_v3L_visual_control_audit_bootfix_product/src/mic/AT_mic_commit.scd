(
// AT_mic_commit.scd
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
    		st[\micSelfIgnoreFramesRemaining] = 0;
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

    	at[\markMicSelfIgnore] = { |frames=nil|
    		var n;
    		n = if(frames.isNil) { cfg[\mic][\selfIgnoreFrames] } { frames };
    		st[\micSelfIgnoreFramesRemaining] = n.asInteger.max(0);
    	};

    	at[\updateCommittedExternalSources] = { |candidates|
    		var activePcs, blocked, proposedByPc, limit, activateFrames, releaseFrames;
    		var proposedPublished, currentPublished, proposedKey, currentKey, immediateCommit;

    		activePcs = at[\activePcsFromWeights].(at[\pcWeights].());
    		blocked = at[\micInfluenceBlocked].(activePcs);
    		st[\micInfluenceBlocked] = blocked;
    		st[\micCommitCooldown] = (st[\micCommitCooldown] - 1).max(0);

    		if(blocked) {
    			st[\micPcWarmCounts] = Array.fill(cfg[\solver][\numNodes], 0);
    			st[\micPcCoolCounts] = Array.fill(cfg[\solver][\numNodes], 0);
    			st[\micCommittedByPc] = Array.fill(cfg[\solver][\numNodes], { nil });
    			currentPublished = st[\externalSources] ? Array.new;
    			if(currentPublished.notEmpty) {
    				st[\externalSources] = Array.new;
    				st[\micCommitCooldown] = cfg[\mic][\commitCooldownFrames].asInteger.max(0);
    			};
    			^st[\externalSources];
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
    			^st[\externalSources];
    		};

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
    								stability: (((cand[\stableFrames] ? st[\micPcWarmCounts][pc]).asFloat) / (cfg[\mic][\stableFrames] ? 4).asFloat.max(1.0)).clip(0.0, 1.0),
    								phaseVelocity: at[\wrapSigned].((cand[\phase] ? old[\phase]) - (old[\phase] ? cand[\phase])).abs,
    								age: ((old[\age] ? 0).asInteger + 1).max(0),
    								sourceRole: \externalMic,
    								active: true
    						)));
    					} {
    						if(st[\micPcWarmCounts][pc] >= activateFrames) {
    							st[\micCommittedByPc][pc] = at[\normalizeExternalSource].(cand.copy.putAll((
    								stableFrames: st[\micPcWarmCounts][pc],
    									stability: (st[\micPcWarmCounts][pc].asFloat / (cfg[\mic][\stableFrames] ? 4).asFloat.max(1.0)).clip(0.0, 1.0),
    									phaseVelocity: 0.0,
    									age: 0,
    									sourceRole: \externalMic,
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

};
)
