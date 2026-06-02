(
// AT_mic_sources.scd
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

    		at[\normalizeExternalSource] = { |src|
    			if(src.isNil) {
    				nil;
    			} {
    				(
    					id: src[\id] ? ((src[\kind] ? \external).asString ++ "-" ++ src[\pc].asString),
    					kind: src[\kind] ? \external,
    					pc: src[\pc],
    					phase: at[\wrap01].(src[\phase]),
    					freq: (src[\freq] ? 0.0).clip(0.0, 24000.0),
    					weight: (src[\weight] ? 0.0).clip(0.0, 1.5),
    					confidence: (src[\confidence] ? 0.0).clip(0.0, 1.0),
    					amp: (src[\amp] ? 0.0).clip(0.0, 10.0),
    					stableFrames: src[\stableFrames] ? 0,
    					stability: (src[\stability] ? (((src[\stableFrames] ? 0).asFloat / (cfg[\mic][\stableFrames] ? 4).asFloat.max(1.0)).clip(0.0, 1.0))).clip(0.0, 1.0),
    					phaseVelocity: (src[\phaseVelocity] ? 0.0).abs,
    					age: (src[\age] ? 0).asInteger.max(0),
    					sourceRole: if(at[\micRoleForSource].notNil) { at[\micRoleForSource].(src) } { src[\sourceRole] ? \externalUnknown },
    					targetMidi: src[\targetMidi],
    					active: src[\active] ? true
    				)
    			};
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

    	// ------------------------------------------------------------
    	// mic synth control
    	// ------------------------------------------------------------

};
)
