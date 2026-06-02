(
// AT_mic_synth.scd
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
    				\pitchAmpThreshold, cfg[\mic][\pitchAmpThreshold] ? 0.01
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
