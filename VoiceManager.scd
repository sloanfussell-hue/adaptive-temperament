////////////////////////////////////////////////////////////
// VOICE MANAGER — MANIFOLD PROJECTION LAYER (FIXED)
////////////////////////////////////////////////////////////

(
~makeVoiceManager = {

    (

        ////////////////////////////////////////////////////////////
        // STATE
        ////////////////////////////////////////////////////////////

        sustainDown: false,

        voices: IdentityDictionary.new,
        velocities: IdentityDictionary.new,
        sustainedNotes: IdentitySet.new,

        ////////////////////////////////////////////////////////////
        // NOTE ON
        ////////////////////////////////////////////////////////////

        noteOn: { |self, midi, velocity|

            var field, voice, baseFreq, velNorm;

            field = ~at[\field];

            // remove from sustain set if retriggered
            self[\sustainedNotes].remove(midi);

            baseFreq = 440 * (2 ** ((midi - 69) / 12));

            voice = self[\voices][midi];

            if(voice.isNil or: { voice.isRunning.not }) {

                voice = Synth(\adaptiveVoice, [
                    \freq, baseFreq,
                    \amp, 0,
                    \gate, 1
                ]);

                self[\voices][midi] = voice;

            } {
                voice.set(\gate, 1);
            };

            velNorm = velocity.clip(1,127) / 127;
            self[\velocities][midi] = velNorm;

            if(field.notNil) {
                field.setActive(midi, true);
            };

            voice.set(
                \freq, baseFreq,
                \amp, velNorm.linexp(0,1,0.02,0.4)
            );
        },

        ////////////////////////////////////////////////////////////
        // NOTE OFF
        ////////////////////////////////////////////////////////////

        noteOff: { |self, midi|

            var voice, field;

            voice = self[\voices][midi];
            field = ~at[\field];

            if(self[\sustainDown]) {

                self[\sustainedNotes].add(midi);

            } {

                if(voice.notNil) {
                    voice.set(\gate, 0);
                };

                self[\velocities].removeAt(midi);

                if(field.notNil) {
                    field.setActive(midi, false);
                };

            };
        },

        ////////////////////////////////////////////////////////////
        // SUSTAIN
        ////////////////////////////////////////////////////////////

        setSustain: { |self, isDown|

            var field;

            field = ~at[\field];
            self[\sustainDown] = isDown;

            if(isDown.not) {

                self[\sustainedNotes].do { |midi|

                    var voice;

                    voice = self[\voices][midi];

                    if(voice.notNil) {
                        voice.set(\gate, 0);
                    };

                    self[\velocities].removeAt(midi);

                    if(field.notNil) {
                        field.setActive(midi, false);
                    };

                };

                self[\sustainedNotes].clear;

            };
        },

        ////////////////////////////////////////////////////////////
        // UPDATE FROM FIELD
        ////////////////////////////////////////////////////////////

        updateFromField: { |self|

            var field, deadKeys;

            field = ~at[\field];
            if(field.isNil) { ^nil };

            deadKeys = List.new;

            self[\voices].keysValuesDo { |midi, voice|

                var baseLog, offset, freq;

                if(voice.isRunning.not) {

                    deadKeys.add(midi);

                } {

                    baseLog = field.baseLogFreq(midi);
                    offset  = field[\x][midi] ? 0.0;

                    freq = (baseLog + offset).exp.clip(20, 20000);

                    voice.set(\freq, freq);
                };

            };

            // remove dead voices safely after iteration
            deadKeys.do { |midi|
                self[\voices].removeAt(midi);
            };

        },

        ////////////////////////////////////////////////////////////
        // AVERAGE VELOCITY
        ////////////////////////////////////////////////////////////

        averageVelocity: { |self|

            if(self[\velocities].isEmpty) { ^0 };
            ^ self[\velocities].values.mean;
        },

        ////////////////////////////////////////////////////////////
        // PANIC
        ////////////////////////////////////////////////////////////

        panic: { |self|

            var field;

            field = ~at[\field];

            self[\voices].values.do { |voice|
                voice.free;
            };

            self[\voices].clear;
            self[\velocities].clear;
            self[\sustainedNotes].clear;
            self[\sustainDown] = false;

            if(field.notNil) {
                88.do { |i|
                    field.setActive(i, false);
                };
            };
        }

    );

};

~at[\voiceManager] = ~makeVoiceManager.();
)