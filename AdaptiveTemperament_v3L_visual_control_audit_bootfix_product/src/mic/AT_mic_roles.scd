(
// AT_mic_roles.scd
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

    	at[\micScenePolicyToLegacy] = { |policy|
		var p;
		p = (policy ? \duetSafe).asSymbol;
		if(p == \duetSafe) { \accompany } {
			if(p == \externalOnly) { \listenAlone } {
				if(p == \fullBlend) { \blend } {
					if(p == \externalFollow) { \blend } {
						if(p == \monitor) { \listenAlone } {
							if(p == \off) { \listenAlone } {
								if(p == \debugRaw) { \debugRaw } {
									if(p == \accompany) { \accompany } {
										if(p == \blend) { \blend } {
											if(p == \listenAlone) { \listenAlone } { \accompany }
										}
									}
								}
							}
						}
					}
				}
			}
		}
	};

	at[\currentMicInfluencePolicy] = {
		var p, sceneOn;
		p = (cfg[\mic][\influencePolicy] ? \duetSafe).asSymbol;
		sceneOn = cfg[\micScene].notNil and: { cfg[\micScene][\enabled] ? true };
		if(sceneOn) {
			if(p == \accompany) { \duetSafe } {
				if(p == \blend) { \fullBlend } {
					if(p == \listenAlone) { \externalOnly } { p }
				}
			}
		} {
			at[\micScenePolicyToLegacy].(p)
		}
	};

    	at[\micCanonicalRoleFromMode] = { |mode|
    		var m;
    		m = if(mode.isNil) { \auto } { mode.asSymbol };
    		if(at[\normalizeExternalRole].notNil) { at[\normalizeExternalRole].(m) } {
    			if(m == \bass) { \externalBass } { if(m == \singer) { \externalSinger } { if(m == \melody) { \externalMelody } { if(m == \drone) { \externalDrone } { if(m == \ensemble) { \externalEnsemble } { if(m == \piano) { \externalPianoLike } { if(m == \percussive) { \externalPercussive } { \externalUnknown } } } } } } }
    		}
    	};

    	at[\micRoleForSource] = { |src|
    		var mode, freq, age, stability, role;
    		mode = cfg[\mic][\sourceRoleMode] ? \auto;
    		if(mode != \auto) {
    			at[\micCanonicalRoleFromMode].(mode)
    		} {
    			freq = src[\freq] ? 0.0;
    			age = (src[\age] ? 0).asInteger.max(0);
    			stability = (src[\stability] ? 0.0).clip(0.0, 1.0);
    			role = if((freq > 0.0) and: { freq <= (cfg[\mic][\autoBassMaxFreq] ? 185.0) }) {
    				\externalBass
    			} {
    				if((age >= (cfg[\mic][\autoDroneMinAge] ? 18)) and: { stability >= 0.78 }) {
    					\externalDrone
    				} {
    					if(cfg[\mic][\mode] == \mono) { \externalSinger } { \externalUnknown }
    				}
    			};
    			role
    		}
    	};

    	at[\effectiveExternalSourceLimit] = { |activePcs=nil|
    		var pcs;
    		pcs = if(activePcs.isNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { activePcs };
    		if(at[\currentMicInfluencePolicy].() == \debugRaw) {
    			cfg[\mic][\debugRawMaxExternalSources].asInteger.max(1)
    		} {
    			if(([\accompany, \duetSafe].includes(at[\currentMicInfluencePolicy].())) and: { pcs.notEmpty }) {
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
    				if((policy == \debugRaw) or: { [\blend, \fullBlend, \externalFollow, \duetSafe, \externalOnly, \monitor].includes(policy) }) {
    					false
    				} {
    					if(st[\micSelfIgnoreFramesRemaining] > 0) {
    						true
    					} {
    						if((policy == \listenAlone) or: { policy == \externalOnly }) {
    							pcs.notEmpty
    						} {
    							false
    						}
    					}
    				}
    			}
    		};

    	at[\applyMicSelfMatchPenalty] = { |src, activePcs=nil|
    		var out, pcs, policy, factor, role, structuralExternal;
    		if(src.isNil) {
    			nil
    		} {
    			out = src.copy;
    			pcs = if(activePcs.isNil) { at[\activePcsFromWeights].(at[\pcWeights].()) } { activePcs };
    			policy = at[\currentMicInfluencePolicy].();
    			factor = 1.0;
    			role = if(at[\micRoleForSource].notNil) { at[\micRoleForSource].(out) } { out[\sourceRole] ? out[\role] };
    			role = if(at[\normalizeExternalRole].notNil) { at[\normalizeExternalRole].(role) } { role };
    			structuralExternal = (role == \externalDrone) or: { role == \externalBass } or: { role == \externalPianoLike };

    			if((policy == \accompany) and: { pcs.notEmpty }) {
    				if(structuralExternal) {
    					// r17ae: explicit structural external roles must be allowed to carry gauge even
    					// when they share a pitch-class with held notes. The old self-match penalty
    					// reduced a stable external drone/bass/piano-like C to near-zero support, so
    					// the mic could be heard but trueGauge stayed frozen. Singer/melody/auto
    					// evidence still uses the anti-feedback self penalty below.
    					factor = 1.0;
    					out[\weight] = ((out[\weight] ? 0.0) * factor).clip(0.0, 1.5);
    					out[\confidence] = ((out[\confidence] ? 0.0) * factor).clip(0.0, 1.0);
    				} {
    					factor = cfg[\mic][\selfGeneralPenalty].clip(0.05, 1.0);
    					if(pcs.includes(out[\pc])) {
    						factor = factor * cfg[\mic][\selfMatchPenalty].clip(0.05, 1.0);
    					};
    					out[\weight] = ((out[\weight] ? 0.0) * factor * cfg[\mic][\duetWeightScale]).clip(0.0, 1.5);
    					out[\confidence] = ((out[\confidence] ? 0.0) * factor).clip(0.0, 1.0);
    				};
    				out[\active] = (out[\active] == true) and: { (out[\weight] ? 0.0) > 0.0 } and: { (out[\confidence] ? 0.0) >= cfg[\mic][\minConfidence] };
    			};

    			at[\normalizeExternalSource].(out)
    		}
    	};

};
)
