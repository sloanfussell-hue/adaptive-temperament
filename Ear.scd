////////////////////////////////////////////////////////////
// EAR — POLYPHONIC FLOATING SENSOR (CLEAN)
////////////////////////////////////////////////////////////

(
~makeEar = {

    (

        ////////////////////////////////////////////////////////////
        // PARAMETERS
        ////////////////////////////////////////////////////////////

        replyRate: 30,
        ampSmooth: 0.1,

        ////////////////////////////////////////////////////////////
        // STATE
        ////////////////////////////////////////////////////////////

        micAmp: 0.0,
        synth: nil,

        ////////////////////////////////////////////////////////////
        // START
        ////////////////////////////////////////////////////////////

        start: { |self|

            if(self[\synth].notNil) {
                self[\synth].free;
            };

            self[\synth] = Synth(\atEarInput, [
                \replyRate, self[\replyRate]
            ]);
        },

        ////////////////////////////////////////////////////////////
        // STOP
        ////////////////////////////////////////////////////////////

        stop: { |self|

            if(self[\synth].notNil) {
                self[\synth].free;
                self[\synth] = nil;
            };
        },

        ////////////////////////////////////////////////////////////
        // HANDLE PEAKS
        ////////////////////////////////////////////////////////////

        handlePeaks: { |self, msg|

            var field, data, ampGlobal;
            var logs, strengths;

            field = ~at[\field];
            if(field.isNil) { ^nil };

            data = msg.copyToEnd(3);
            if(data.size < 2) { ^nil };

            ampGlobal = data.last;
            data = data.copyRange(0, data.size - 2);

            ////////////////////////////////////////////////////////
            // Smooth amplitude
            ////////////////////////////////////////////////////////

            self[\micAmp] =
                (self[\micAmp] * (1 - self[\ampSmooth]))
                + (ampGlobal * self[\ampSmooth]);

            logs = List.new;
            strengths = List.new;

            ////////////////////////////////////////////////////////
            // Build polyphonic external data
            ////////////////////////////////////////////////////////

            data.do { |freq|

                if(freq > 20) {

                    var logF = freq.log;

                    var strength =
                        self[\micAmp]
                        .linlin(0.0, 0.3, 0.0, field[\lambdaMax])
                        .clip(0, field[\lambdaMax])
                        .squared;

                    if(strength > 0.0001) {
                        logs.add(logF);
                        strengths.add(strength);
                    };
                };
            };

            ////////////////////////////////////////////////////////
            // Send to field (no internal mutation)
            ////////////////////////////////////////////////////////

            if(logs.isEmpty) {
                field.applyExternalPressure([], []);
            } {
                field.applyExternalPressure(
                    logs.asArray,
                    strengths.asArray
                );
            };

        }

    );

};

////////////////////////////////////////////////////////////
// INSTALL OSC HANDLER
////////////////////////////////////////////////////////////

if(OSCdef(\earPeaks).notNil) {
    OSCdef(\earPeaks).free;
};

OSCdef(\earPeaks, { |msg|
    if(~at[\ear].notNil) {
        ~at[\ear].handlePeaks(msg);
    };
}, '/earPeaks');

~at[\ear] = ~makeEar.();
)