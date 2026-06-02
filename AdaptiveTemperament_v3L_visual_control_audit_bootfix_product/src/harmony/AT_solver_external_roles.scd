(
// AT_solver_external_roles.scd
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

    	at[\externalBehaviorScale] = { |src|
    		var stability, phaseVelocity, centsPerTick, unstableScale, stableScale, driftScale, stableBlend, driftAmount;
    		if(src.isNil) {
    			0.0
    		} {
    			stability = (src[\stability] ? (((src[\stableFrames] ? 0).asFloat / (cfg[\mic][\stableFrames] ? 4).asFloat.max(1.0)).clip(0.0, 1.0))).clip(0.0, 1.0);
    			phaseVelocity = (src[\phaseVelocity] ? 0.0).abs;
    			centsPerTick = phaseVelocity * 1200.0;
    			unstableScale = (cfg[\solver][\externalGaugeUnstableScale] ? 0.30).clip(0.0, 1.0);
    			stableScale = (cfg[\solver][\externalGaugeStableScale] ? 1.0).clip(0.0, 1.2);
    			driftScale = (cfg[\solver][\externalGaugeDriftScale] ? 0.70).clip(0.0, 1.0);
    			stableBlend = unstableScale + ((stableScale - unstableScale) * stability);
    			driftAmount = (centsPerTick / 10.0).clip(0.0, 1.0);
    			(stableBlend * (1.0 - driftAmount)) + ((stableBlend * driftScale) * driftAmount)
    		}
    	};

    	at[\externalEvidenceTrustScale] = { |src|
    		var pc, currentPhase, phase, rawOffset, errorCents, trustWindow, farWindow, farScale, denom, errorScale;
    		var confidence, sourceStrength, rawAuthority, behaviorScale, minScale;
    		if(src.isNil) {
    			0.0
    		} {
    			pc = src[\pc];
    			phase = src[\phase];
    			if(pc.isNil or: { phase.isNil }) {
    				0.0
    			} {
    				currentPhase = st[\nodePhase][pc];
    				rawOffset = at[\wrapSigned].(phase - currentPhase);
    				errorCents = rawOffset.abs * 1200.0;
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

    				confidence = (src[\confidence] ? 0.0).clip(0.0, 1.0);
    				sourceStrength = (at[\sourceStrength].(src) ? 0.0).clip(0.0, 1.2);
    				rawAuthority = (sourceStrength / 0.45).clip(0.0, 1.0);
    				behaviorScale = at[\externalBehaviorScale].(src);
    				minScale = (cfg[\solver][\externalRelationalMinTrust] ? 0.0).clip(0.0, 0.25);
    				(minScale + ((1.0 - minScale) * (rawAuthority.pow(1.10) * confidence.sqrt * errorScale * behaviorScale))).clip(0.0, 1.0)
    			}
    		}
    	};


    	// ------------------------------------------------------------
    	// r15i context-break rebase: adaptive memory, bass role, anchor choice
    	// ------------------------------------------------------------

    	at[\normalizeExternalRole] = { |role|
    		var r;
    		r = if(role.isNil) { \externalUnknown } { role.asSymbol };
    		if((r == \singer) or: { r == \externalSinger }) { \externalSinger } {
    			if((r == \bass) or: { r == \externalBass }) { \externalBass } {
    				if((r == \melody) or: { r == \externalMelody }) { \externalMelody } {
    					if((r == \drone) or: { r == \externalDrone }) { \externalDrone } {
    						if((r == \ensemble) or: { r == \externalEnsemble }) { \externalEnsemble } {
    							if((r == \piano) or: { r == \externalPianoLike }) { \externalPianoLike } {
    								if((r == \percussive) or: { r == \externalPercussive }) { \externalPercussive } { \externalUnknown }
    							}
    						}
    					}
    				}
    			}
    		}
    	};

    	at[\externalRoleSustain] = { |src|
    		var stability, age, minAge;
    		stability = (src[\stability] ? 0.0).clip(0.0, 1.0);
    		age = (src[\age] ? 0).asFloat.max(0.0);
    		minAge = (cfg[\solver][\externalRoleMinSustainAge] ? 3).asFloat.max(1.0);
    		((age / minAge).clip(0.0, 1.0) * 0.45 + (stability * 0.55)).clip(0.0, 1.0)
    	};

    	at[\externalRoleAuthority] = { |src, activePcs|
    		var role, pc, trust, stability, sustain, shapeScale, gaugeScale, label;
    		role = at[\normalizeExternalRole].(src[\sourceRole] ? \externalUnknown);
    		pc = src[\pc];
    		trust = at[\externalEvidenceTrustScale].(src);
    		stability = (src[\stability] ? 0.0).clip(0.0, 1.0);
    		sustain = at[\externalRoleSustain].(src);
    		shapeScale = cfg[\solver][\externalRoleUnknownShapeScale] ? 0.34;
    		gaugeScale = cfg[\solver][\externalRoleUnknownGaugeScale] ? 0.26;
    		label = role;

    		if((cfg[\solver][\bassRoleEnabled] ? true) and: { role == \externalBass }) {
    			if((trust < 0.05) or: { stability < 0.20 }) {
    				label = \unstableBass;
    				shapeScale = cfg[\solver][\bassRoleUnstableScale] ? 0.04;
    				gaugeScale = (cfg[\solver][\externalBassGaugeScale] ? 0.72) * 0.20;
    			} {
    				if((activePcs ? Array.new).includes(pc)) {
    					label = \structuralBass;
    					shapeScale = cfg[\solver][\bassRoleStructuralScale] ? 0.58;
    				} {
    					if((activePcs ? Array.new).size >= 3) {
    						label = \passingBass;
    						shapeScale = cfg[\solver][\bassRolePassingScale] ? 0.24;
    					} {
    						label = \inversionBass;
    						shapeScale = cfg[\solver][\bassRoleInversionScale] ? 0.46;
    					}
    				};
    				gaugeScale = (cfg[\solver][\externalBassGaugeScale] ? 0.72) * (0.35 + (0.65 * sustain));
    			};

    			st[\lastBassRoleReport] = (
    				timestamp: Main.elapsedTime,
    				pc: pc,
    				targetMidi: src[\targetMidi],
    				role: label,
    				trust: trust,
    				stability: stability,
    				sustain: sustain,
    				scale: shapeScale,
    				gaugeScale: gaugeScale,
    				activePcs: (activePcs ? Array.new).copy
    			);
    		} {
    			if(role == \externalSinger) {
    				shapeScale = (cfg[\solver][\externalRoleSingerAttackScale] ? 0.16) + (((cfg[\solver][\externalRoleSingerSustainShapeScale] ? 0.72) - (cfg[\solver][\externalRoleSingerAttackScale] ? 0.16)) * sustain);
    				gaugeScale = ((cfg[\solver][\externalRoleSingerAttackScale] ? 0.16) * 0.55) + (((cfg[\solver][\externalRoleSingerSustainGaugeScale] ? 0.42) - ((cfg[\solver][\externalRoleSingerAttackScale] ? 0.16) * 0.55)) * sustain);
    			} {
    				if(role == \externalMelody) {
    					shapeScale = cfg[\solver][\externalRoleMelodyShapeScale] ? 0.58;
    					gaugeScale = cfg[\solver][\externalRoleMelodyGaugeScale] ? 0.22;
    				} {
    					if(role == \externalDrone) {
    						shapeScale = (cfg[\solver][\externalRoleDroneShapeScale] ? 0.70) * (0.35 + (0.65 * sustain));
    						gaugeScale = (cfg[\solver][\externalRoleDroneGaugeScale] ? 0.82) * (0.30 + (0.70 * sustain));
    					} {
    						if(role == \externalEnsemble) {
    							shapeScale = cfg[\solver][\externalRoleEnsembleShapeScale] ? 0.62;
    							gaugeScale = cfg[\solver][\externalRoleEnsembleGaugeScale] ? 0.58;
    						} {
    							if(role == \externalPianoLike) {
    								shapeScale = cfg[\solver][\externalRolePianoShapeScale] ? 0.46;
    								gaugeScale = cfg[\solver][\externalRolePianoGaugeScale] ? 0.68;
    							} {
    								if(role == \externalPercussive) {
    									shapeScale = cfg[\solver][\externalRolePercussiveShapeScale] ? 0.08;
    									gaugeScale = cfg[\solver][\externalRolePercussiveGaugeScale] ? 0.02;
    								} {
    									shapeScale = cfg[\solver][\externalRoleUnknownShapeScale] ? 0.34;
    									gaugeScale = cfg[\solver][\externalRoleUnknownGaugeScale] ? 0.26;
    								}
    							}
    						}
    					}
    				}
    			}
    		};

    		shapeScale = shapeScale.clip(0.0, 1.2);
    		gaugeScale = gaugeScale.clip(0.0, 1.2);
    		st[\lastExternalRoleReport] = (
    			timestamp: Main.elapsedTime,
    			pc: pc,
    			sourceRole: role,
    			roleLabel: label,
    			trust: trust,
    			stability: stability,
    			sustain: sustain,
    			shapeScale: shapeScale,
    			gaugeScale: gaugeScale,
    			activePcs: (activePcs ? Array.new).copy
    		);
    		(shapeScale: shapeScale, gaugeScale: gaugeScale, role: role, label: label, sustain: sustain)
    	};

    	at[\externalRoleRelationalScale] = { |src, activePcs|
    		if(src.isNil) { 0.0 } { (at[\externalRoleAuthority].(src, activePcs)[\shapeScale] ? 0.0).clip(0.0, 1.2) }
    	};

    	at[\externalRoleGaugeScale] = { |src, activePcs|
    		if(src.isNil) { 0.0 } { (at[\externalRoleAuthority].(src, activePcs)[\gaugeScale] ? 0.0).clip(0.0, 1.2) }
    	};

    	at[\passiveContextScale] = { |src, activePcs, externalSources|
    		var scale, role;
    		scale = 1.0;
    		role = src[\sourceRole];
    		if(role.isNil) { role = src[\kind] ? \internal; };
    		if((src[\isExternal] == true) and: { role == \externalBass }) {
    			scale = scale * (cfg[\solver][\passiveExternalAmbiguousScale] ? 0.18).clip(0.0, 1.0);
    		} {
    			if(((externalSources ? Array.new).size > 1) or: { (activePcs ? Array.new).size >= 5 }) {
    				scale = scale * (cfg[\solver][\passiveAmbiguousScale] ? 0.22).clip(0.0, 1.0);
    			};
    		};
    		scale.clip(0.0, 1.0)
    	};

};
)
