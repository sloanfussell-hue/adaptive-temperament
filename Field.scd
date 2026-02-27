////////////////////////////////////////////////////////////
// FIELD — HARMONIC MANIFOLD (STABLE + HARDENED)
////////////////////////////////////////////////////////////

(
~at = ~at ? IdentityDictionary.new;

~makeField = {

    var field;

    field = (

        ////////////////////////////////////////////////////////////
        // PARAMETERS
        ////////////////////////////////////////////////////////////

        H: 6,
        p: 1.7,
        beta: 30.0,

        etaActive: 0.006,
        etaSilent: 0.01,

        lambdaMax: 0.15,

        biasMin: 0.3,
        biasMax: 0.9,
        biasGamma: 1.6,

        dominanceSmoothing: 0.05,
        etaDominanceAmount: 0.4,
        lagAsymmetry: 0.15,

		harmonicBias: 1.0,
		subharmonicBias: 0.3,

        ////////////////////////////////////////////////////////////
        // STATE
        ////////////////////////////////////////////////////////////

        x: Array.fill(88, 0.0),
		vel: Array.fill(88, 0.0),
		damping: 0.85,
        grad: Array.fill(88, 0.0),

		// POLYPHONIC EXTERNAL EMISSION
		externalLogs: Array.new,
		externalStrengths: Array.new,

        active: Array.fill(88, false),

        envTarget: Array.fill(88, 0.0),
        envConf: Array.fill(88, 0.0),

        ratios: nil,
        weights: nil,

        dominance: 0.0,

        ////////////////////////////////////////////////////////////
        // INIT
        ////////////////////////////////////////////////////////////

        init: { |self|

			var ratioList, weightList;
			var hi, ki, h, k, r, baseWeight;

			ratioList  = List.new;
			weightList = List.new;

			self[\H].do { |hi|
				h = hi + 1;

				self[\H].do { |ki|
					k = ki + 1;

					if(h > k and: { h.gcd(k) == 1 }) {

						r = h / k;

						baseWeight = (h * k).pow(self[\p].neg);

						// True harmonic (h/k)
						ratioList.add((h / k).log);
						weightList.add(baseWeight * self[\harmonicBias]);

						// Subharmonic (k/h)
						ratioList.add((k / h).log);
						weightList.add(baseWeight * self[\subharmonicBias]);

					};

				};
			};

            self[\ratios]  = ratioList.asArray;
            self[\weights] = weightList.asArray;

			self[\H].postln;

        },

        ////////////////////////////////////////////////////////////
        // INTERNAL BIAS
        ////////////////////////////////////////////////////////////

        currentInternalBias: { |self|

            var vm, avg, shaped;

            vm = ~at[\voiceManager];

            if(vm.isNil) {
                ^ self[\biasMin];
            };

            avg    = vm.averageVelocity.clip(0, 1);
            shaped = avg.pow(self[\biasGamma]);

            ^ self[\biasMin]
              + ((self[\biasMax] - self[\biasMin]) * shaped);

        },

        ////////////////////////////////////////////////////////////
        // SETTERS
        ////////////////////////////////////////////////////////////

        setActive: { |self, midi, isOn|
            self[\active][midi] = isOn;
        },

        setEnv: { |self, midi, logFreq, confidence|
            self[\envTarget][midi] = logFreq;
            self[\envConf][midi]   = confidence.clip(0, self[\lambdaMax]);
        },

        baseLogFreq: { |self, midi|
            ^ 440.log + ((midi - 69) * (2.log / 12));
        },

		velocityPower: { |self, midi|

			var vm, vel;

			vm = ~at[\voiceManager];
			if(vm.isNil) { ^ 0.0 };

			vel = vm.velocities[midi] ? 0.0;

			^ vel.clip(0, 1).pow(1.5);
		},
		////////////////////////////////////////////////////////
		// EXTERNAL PRESSURE (POLYPHONIC)
		////////////////////////////////////////////////////////

		applyExternalPressure: { |self, logs, strengths|

			// Ensure arrays
			if(logs.isNil or: { strengths.isNil }) {
				self[\externalLogs] = [];
				self[\externalStrengths] = [];
				^self;
			};

			if(logs.size != strengths.size) {
				self[\externalLogs] = [];
				self[\externalStrengths] = [];
				^self;
			};

			// Store copies to avoid mutation issues
			self[\externalLogs] = logs.copy;
			self[\externalStrengths] = strengths.copy;

		},

		////////////////////////////////////////////////////////
		// STEP — TRUE ENERGY MANIFOLD (HARDENED)
		////////////////////////////////////////////////////////

		step: { |self|

			var n,
			ratios, weights, beta, ratioCount,
			log2,
			absX,
			xi, xj, delta, deltaWrapped,
			r, w, diff, e, force,
			v,
			dominance, rawDominance,
			externalEnergy, internalEnergy,
			avgVel,
			baseEta, etaScale, eta;

			n = 88;

			ratios     = self[\ratios];
			weights    = self[\weights];
			beta       = self[\beta];
			ratioCount = ratios.size;

			log2 = 2.log;

			externalEnergy =
			(self[\externalStrengths] ? []).sum ? 0.0;

			internalEnergy = 0.0;
			avgVel = 0.0;

			////////////////////////////////////////////////////////////
			// RESET GRADIENT EACH FRAME
			////////////////////////////////////////////////////////////

			self[\grad] = Array.fill(n, 0.0);

			////////////////////////////////////////////////////////////
			// BUILD ABSOLUTE LOG POSITIONS
			////////////////////////////////////////////////////////////

			absX = Array.fill(n, { |i|
				self[\baseLogFreq].value(self, i) + self[\x][i]
			});

			if(~at[\voiceManager].notNil) {
				internalEnergy =
				~at[\voiceManager].velocities.values.sum ? 0;
			};

			////////////////////////////////////////////////////////////
			// HARMONIC FORCES
			////////////////////////////////////////////////////////////

			n.do { |ii|

				((ii + 1) .. (n - 1)).do { |jj|

					var activeI, activeJ;
					var emitI, emitJ, totalEmit;

					activeI = self[\active][ii];
					activeJ = self[\active][jj];

					if(activeI or: { activeJ }) {

						emitI = activeI.if({ self.velocityPower(ii) }, { 0.0 });
						emitJ = activeJ.if({ self.velocityPower(jj) }, { 0.0 });

						totalEmit = emitI + emitJ;

						if(totalEmit > 0.0) {

							xi = absX[ii];
							xj = absX[jj];
							delta = xi - xj;

							if(delta.abs > 1e-12) {

								force = 0.0;

								ratioCount.do { |kk|

									r = ratios[kk];
									w = weights[kk];

									deltaWrapped =
									delta - ((delta / log2).round * log2);

									diff = deltaWrapped - r;

									e = (beta * diff.squared).neg.exp;

									force = force + (2 * beta * w * diff * e);
								};

								self[\grad][ii] =
								self[\grad][ii]
								+ (force * (emitJ / (totalEmit + 1e-9)));

								self[\grad][jj] =
								self[\grad][jj]
								- (force * (emitI / (totalEmit + 1e-9)));
							};
						};
					};
				};
			};

			////////////////////////////////////////////////////////////
			// EXTERNAL EMISSION
			////////////////////////////////////////////////////////////

			if(self[\externalLogs].notNil and: { self[\externalLogs].size > 0 }) {

				self[\externalLogs].size.do { |k|

					var xExt, emitExt;

					xExt    = self[\externalLogs][k];
					emitExt = self[\externalStrengths][k];

					if(emitExt > 0.0001) {

						n.do { |ii|

							delta = absX[ii] - xExt;

							if(delta.abs > 1e-12) {

								force = 0.0;

								ratioCount.do { |kk|

									r = ratios[kk];
									w = weights[kk];

									deltaWrapped =
									delta - ((delta / log2).round * log2);

									diff = deltaWrapped - r;

									e = (beta * diff.squared).neg.exp;

									force = force + (2 * beta * w * diff * e);
								};

								self[\grad][ii] =
								self[\grad][ii] + (force * emitExt);
							};
						};
					};
				};
			};

			////////////////////////////////////////////////////////////
			// DOMINANCE + INTEGRATION
			////////////////////////////////////////////////////////////

			rawDominance =
			externalEnergy
			/ (externalEnergy
				+ (internalEnergy * self.currentInternalBias)
				+ 1e-6);

			self[\dominance] =
			self[\dominance]
			+ (self[\dominanceSmoothing]
				* (rawDominance - self[\dominance]));

			dominance = self[\dominance];

			n.do { |idx|

				baseEta =
				self[\active][idx]
				.if({ self[\etaActive] }, { self[\etaSilent] });

				etaScale =
				1 + (self[\etaDominanceAmount] * dominance);

				eta = baseEta * etaScale;

				v =
				(self[\vel][idx] * self[\damping])
				- (eta * self[\grad][idx]);

				self[\vel][idx] = v;
				self[\x][idx]   = self[\x][idx] + v;
			};

		}

    );

    field.init;
    field;

};

~at[\field] = ~makeField.();
)