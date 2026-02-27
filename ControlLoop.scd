////////////////////////////////////////////////////////////
// CONTROL LOOP — HARMONIC INTEGRATOR (ACTUALLY CORRECT)
////////////////////////////////////////////////////////////

(
~makeControlLoop = {

    (
        activeRate: 300,
        idleRate: 60,
        running: false,

        ////////////////////////////////////////////////////////////
        // ACTIVITY LEVEL
        ////////////////////////////////////////////////////////////

        activityLevel: { |self|

            var field, dominance, anyActive;

            field = ~at[\field];
            if(field.isNil) { ^0 };

            dominance = field[\dominance] ? 0;

            anyActive =
                field[\active]
                    .detect({ |flag| flag })
                    .notNil;

            ^ dominance
                .max(anyActive.if(1.0, 0.0))
                .clip(0, 1);
        },

        ////////////////////////////////////////////////////////////
        // STEP
        ////////////////////////////////////////////////////////////

        step: { |self|

            var field, vm, activity, rate;

            field = ~at[\field];
            vm    = ~at[\voiceManager];

            activity = self[\activityLevel].value(self);

            rate =
                self[\idleRate]
                + ((self[\activeRate]
                    - self[\idleRate])
                    * activity);

            rate = rate.max(1);

            if(field.notNil) {
                field.step;
            };
            if(vm.notNil) {
                vm.updateFromField;
            };

            ^ (1.0 / rate);
        },

        ////////////////////////////////////////////////////////////
        // INTERNAL TICK
        ////////////////////////////////////////////////////////////

        _tick: { |self|

            var interval;

            if(self[\running].not) { ^nil };

            interval = self[\step].value(self);

            if(interval.isNil or: { interval <= 0 }) {
                interval = 0.01;
            };

            AppClock.sched(interval, {
                self[\_tick].value(self);
                nil;
            });

        },

        ////////////////////////////////////////////////////////////
        // START
        ////////////////////////////////////////////////////////////

        start: { |self|

            if(self[\running]) { ^nil };

            self[\running] = true;

            AppClock.sched(0.0, {
                self[\_tick].value(self);
                nil;
            });

        },

        ////////////////////////////////////////////////////////////
        // STOP
        ////////////////////////////////////////////////////////////

        stop: { |self|

            self[\running] = false;

        }

    );

};

~at[\controlLoop] = ~makeControlLoop.();
)