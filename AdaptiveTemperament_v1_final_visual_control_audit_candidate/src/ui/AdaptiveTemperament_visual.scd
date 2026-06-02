(
// Adaptive Temperament visual cockpit v67b final product
// Visual-only refinement v46: leave eye/brain/teeth/gums stable; replace ear with reference-style open monoline icon.
// Main is a performance face. Mic/Render/Advanced expose final product controls.
var at, api, diag, ui, cfg, st, pitchClassNames;

at = Library.at(\at);

if(at.isNil) {
	"[at-ui] core not loaded. Load AdaptiveTemperament_run.scd first.".warn;
} {
	var panelBg, cardBg, controlBg, controlHi, ink, subtle, accent, accent2, danger, warm, success, dark, dark2, micBlue, memoryCol, gum, gumDark, gumHi;

	api = at[\api];
	diag = at[\diag];
	ui = at[\ui];
	cfg = at[\cfg];
	st = at[\state];
	pitchClassNames = at[\pitchClassNames] ? ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];

	panelBg = Color(0.86, 0.76, 0.67, 1.0);
	cardBg = panelBg;
	controlBg = Color(0.95, 0.90, 0.83, 1.0);
	controlHi = Color(0.99, 0.94, 0.86, 1.0);
	ink = Color(0.08, 0.055, 0.045, 1.0);
	subtle = Color(0.30, 0.23, 0.20, 1.0);
	accent = Color(0.05, 0.08, 0.10, 1.0);
	accent2 = Color(0.23, 0.48, 0.88, 1.0);
	danger = Color(0.66, 0.12, 0.10, 1.0);
	warm = Color(0.94, 0.67, 0.16, 1.0);
	success = Color(0.30, 0.66, 0.44, 1.0);
	dark = Color(0.015, 0.022, 0.030, 1.0);
	dark2 = Color(0.035, 0.055, 0.080, 1.0);
	micBlue = Color(0.20, 0.95, 0.95, 1.0);
	memoryCol = Color(0.62, 0.72, 0.95, 1.0);
	gum = Color(0.47, 0.18, 0.17, 1.0);
	gumDark = Color(0.22, 0.055, 0.055, 1.0);
	gumHi = Color(0.70, 0.34, 0.32, 1.0);

	api[\closeUI] = {
		var win;
		if(ui[\refreshRoutine].notNil) {
			ui[\refreshRoutine].stop;
			ui[\refreshRoutine] = nil;
		};
		win = ui[\window];
		ui[\window] = nil;
		ui[\snapshot] = nil;
		ui[\eyeView] = nil;
		ui[\keyboardView] = nil;
		ui[\openingUi] = false;
		ui[\uiOpening] = false;
		ui[\uiOpen] = false;
		if(win.notNil and: { win.isClosed.not }) {
			win.onClose_(nil);
			win.close;
		};
	};

	api[\openUI] = {
		var win;
		if((ui[\openingUi] == true) or: { ui[\uiOpening] == true }) {
			"[at-ui] openUI ignored while already opening".postln;
		} {
			if(ui[\window].notNil and: { ui[\window].isClosed.not }) {
				ui[\window].front;
			} {
				ui[\openingUi] = true;
				ui[\uiOpening] = true;
				"[at-api] openUI requested".postln;
				{
					try {
						var screen, winW, winH, outerPad, gap, leftW, keyH, topH, rightW;
						var leftPanel, rightPanel, keyboardPanel, topStrip, brainCard, earCard, toneCard, displayCard;
						var statusTitle, statusLine, statusLine2, powerButton, brainButton, earButton, tonesButton, panicButton;
						var motionSlider, carrySlider, memorySlider, gravitySlider, tensionSlider, micAmountSlider, micTrustSlider;
						var motionNum, carryNum, memoryNum, gravityNum, tensionNum, micAmountNum, micTrustNum;
						var micModeMenu, toneProfileMenu, adaptiveToneModeMenu, toneLowSlider, toneMidSlider, toneHighSlider, adaptiveToneAmountSlider, adaptiveToneAmountNum, eyeView, keyboardView;
						var registerAuthoritySlider, velocityAuthoritySlider, registerAuthorityValue, velocityAuthorityValue;
						var gravityFollowMenu, spectrumAccordionSlider, spectrumAccordionValue;
						var tabs, tabButtons, pages, micPage, renderPage, advPage, activeTab;
						var micInfo, renderInfo, advInfo, y;
						var makeLabel, makeCard, makeButton, makeToggle, makeIconToggle, makeSliderRow, makePopupRow, setPage, fmtPcList, fmtMidiList, fmtNum;
						var drawEye, drawKeyboard, refreshUI, currentSnap, keyboardRangeStart, keyboardRangeEnd;

						"[at-api] openUI deferred enter".postln;
						screen = Window.screenBounds;
						winW = (screen.width - 240).clip(980, 1180).asInteger;
						winH = (screen.height - 120).clip(690, 790).asInteger;
						outerPad = 12;
						gap = 10;
						leftW = 330;
						keyH = 165;
						topH = winH - keyH - (outerPad * 3);
						rightW = winW - leftW - (outerPad * 2) - gap;
						keyboardRangeStart = 36;
						keyboardRangeEnd = 84;
						activeTab = 0;

						makeLabel = { |parent, rect, text, color=nil, size=10, align=\left, bold=false|
							var t, f;
							t = StaticText(parent, rect);
							t.string_(text);
							t.stringColor_(color ? ink);
							f = Font.default.size_(size);
							if(bold) { f = f.boldVariant; };
							t.font_(f);
							if(align == \center) { t.align_(\center); };
							if(align == \right) { t.align_(\right); };
							t;
						};

						makeCard = { |parent, rect, title=nil|
							var v;
							v = CompositeView(parent, rect);
							v.background_(cardBg);
							if(title.notNil) { makeLabel.(v, Rect(12, 8, rect.width - 24, 18), title, ink, 12, \left, true); };
							v;
						};

						makeButton = { |parent, rect, label, action, color=nil|
							var b;
							b = Button(parent, rect);
							b.states_([[label, ink, color ? controlBg]]);
							b.action_({ action.value(b); });
							b;
						};

						makeToggle = { |parent, rect, offLabel, onLabel, init, action|
							var b;
							b = Button(parent, rect);
							b.states_([[offLabel, ink, controlBg], [onLabel, Color(1, 1, 1, 1), accent]]);
							b.value_(if(init == true) { 1 } { 0 });
							b.action_({ action.value(b.value == 1); });
							b;
						};

						
						makeIconToggle = { |parent, rect, kind, stateFunc, action|
							var v;
							v = UserView(parent, rect);
							v.background_(panelBg);
							v.drawFunc_({ |view|
								var b, on, cx, cy, tileCol, iconCol, foldCol, tileRect;
								b = view.bounds;
								on = stateFunc.value == true;
								cx = b.width * 0.5;
								cy = b.height * 0.5;
								tileRect = Rect(0, 0, b.width, b.height);
								tileCol = if(on) { Color(0.012, 0.020, 0.026, 1.0) } { Color(0.055, 0.044, 0.038, 1.0) };
								iconCol = if(on) { Color(0.98, 0.92, 0.80, 0.98) } { Color(0.72, 0.64, 0.54, 0.72) };
								foldCol = if(on) { Color(0.08, 0.055, 0.045, 0.78) } { Color(0.055, 0.044, 0.038, 0.68) };

								Pen.fillColor = tileCol;
								Pen.fillRect(tileRect);
								Pen.strokeColor = if(on) { Color(0.98, 0.92, 0.80, 0.30) } { Color(0.98, 0.92, 0.80, 0.10) };
								Pen.width = 1.25;
								Pen.strokeRect(tileRect.insetBy(0.5, 0.5));

								if(kind == \brain) {
									// Graphic brain tile: one cream mass, center split, a few soft folds.
									Pen.fillColor = iconCol;
									Pen.fillOval(Rect.aboutPoint(Point(cx - 16, cy - 8), 20, 25));
									Pen.fillOval(Rect.aboutPoint(Point(cx + 16, cy - 8), 20, 25));
									Pen.fillOval(Rect.aboutPoint(Point(cx - 10, cy - 23), 18, 14));
									Pen.fillOval(Rect.aboutPoint(Point(cx + 10, cy - 23), 18, 14));
									Pen.fillOval(Rect.aboutPoint(Point(cx - 13, cy + 13), 18, 17));
									Pen.fillOval(Rect.aboutPoint(Point(cx + 13, cy + 13), 18, 17));
									Pen.fillRect(Rect(cx - 16, cy - 24, 32, 49));
									Pen.strokeColor = tileCol;
									Pen.width = 2.2;
									Pen.moveTo(Point(cx, cy - 31));
									Pen.curveTo(Point(cx, cy + 28), Point(cx - 2, cy - 4), Point(cx + 2, cy + 9));
									Pen.stroke;
									Pen.strokeColor = foldCol;
									Pen.width = 2.0;
									Pen.moveTo(Point(cx - 25, cy - 13)); Pen.curveTo(Point(cx - 9, cy - 26), Point(cx - 24, cy - 2), Point(cx - 6, cy - 6)); Pen.stroke;
									Pen.moveTo(Point(cx - 24, cy + 9)); Pen.curveTo(Point(cx - 8, cy + 1), Point(cx - 20, cy + 22), Point(cx - 4, cy + 16)); Pen.stroke;
									Pen.moveTo(Point(cx + 6, cy - 7)); Pen.curveTo(Point(cx + 24, cy - 7), Point(cx + 9, cy - 26), Point(cx + 25, cy - 14)); Pen.stroke;
									Pen.moveTo(Point(cx + 4, cy + 16)); Pen.curveTo(Point(cx + 21, cy + 21), Point(cx + 8, cy + 2), Point(cx + 25, cy + 9)); Pen.stroke;
								} {
										// Ear tile v46: direct vector trace of the provided ear reference.
										// This is not an interpreted/abstract ear; it is the supplied icon shape rewritten as Pen paths.
										iconCol = Color(0.98, 0.92, 0.80, 1.0);
										Pen.strokeColor = iconCol;
										Pen.fillColor = iconCol;
										Pen.width = 0.1;

										// Outer stroke body: vector-traced from the supplied reference ear symbol.
										Pen.moveTo(Point(b.width * 0.38605, b.height * 0.10427));
										Pen.lineTo(Point(b.width * 0.29767, b.height * 0.14692));
										Pen.lineTo(Point(b.width * 0.23721, b.height * 0.20853));
										Pen.lineTo(Point(b.width * 0.20000, b.height * 0.30332));
										Pen.lineTo(Point(b.width * 0.20000, b.height * 0.38863));
										Pen.lineTo(Point(b.width * 0.22326, b.height * 0.45024));
										Pen.lineTo(Point(b.width * 0.25116, b.height * 0.48815));
										Pen.lineTo(Point(b.width * 0.37209, b.height * 0.58294));
										Pen.lineTo(Point(b.width * 0.40465, b.height * 0.62085));
										Pen.lineTo(Point(b.width * 0.42326, b.height * 0.66825));
										Pen.lineTo(Point(b.width * 0.42791, b.height * 0.74408));
										Pen.lineTo(Point(b.width * 0.45581, b.height * 0.80569));
										Pen.lineTo(Point(b.width * 0.50233, b.height * 0.84360));
										Pen.lineTo(Point(b.width * 0.56279, b.height * 0.85308));
										Pen.lineTo(Point(b.width * 0.62791, b.height * 0.82938));
										Pen.lineTo(Point(b.width * 0.68837, b.height * 0.76777));
										Pen.lineTo(Point(b.width * 0.70698, b.height * 0.70616));
										Pen.lineTo(Point(b.width * 0.68837, b.height * 0.61611));
										Pen.lineTo(Point(b.width * 0.64651, b.height * 0.57346));
										Pen.lineTo(Point(b.width * 0.62791, b.height * 0.57820));
										Pen.lineTo(Point(b.width * 0.66977, b.height * 0.65877));
										Pen.lineTo(Point(b.width * 0.66977, b.height * 0.71090));
										Pen.lineTo(Point(b.width * 0.65581, b.height * 0.74408));
										Pen.lineTo(Point(b.width * 0.59535, b.height * 0.80095));
										Pen.lineTo(Point(b.width * 0.56744, b.height * 0.81043));
										Pen.lineTo(Point(b.width * 0.51163, b.height * 0.80095));
										Pen.lineTo(Point(b.width * 0.46977, b.height * 0.74882));
										Pen.lineTo(Point(b.width * 0.46512, b.height * 0.64929));
										Pen.lineTo(Point(b.width * 0.45116, b.height * 0.60664));
										Pen.lineTo(Point(b.width * 0.40000, b.height * 0.54502));
										Pen.lineTo(Point(b.width * 0.32558, b.height * 0.49289));
										Pen.lineTo(Point(b.width * 0.26977, b.height * 0.43602));
										Pen.lineTo(Point(b.width * 0.25116, b.height * 0.39810));
										Pen.lineTo(Point(b.width * 0.24186, b.height * 0.32701));
										Pen.lineTo(Point(b.width * 0.25581, b.height * 0.27014));
										Pen.lineTo(Point(b.width * 0.29302, b.height * 0.21327));
										Pen.lineTo(Point(b.width * 0.38140, b.height * 0.15640));
										Pen.lineTo(Point(b.width * 0.46512, b.height * 0.14692));
										Pen.lineTo(Point(b.width * 0.54419, b.height * 0.17536));
										Pen.lineTo(Point(b.width * 0.59535, b.height * 0.23223));
										Pen.lineTo(Point(b.width * 0.61395, b.height * 0.29384));
										Pen.lineTo(Point(b.width * 0.63721, b.height * 0.28436));
										Pen.lineTo(Point(b.width * 0.63721, b.height * 0.24171));
										Pen.lineTo(Point(b.width * 0.60465, b.height * 0.17062));
										Pen.lineTo(Point(b.width * 0.55349, b.height * 0.12796));
										Pen.lineTo(Point(b.width * 0.46512, b.height * 0.09953));
										Pen.lineTo(Point(b.width * 0.38605, b.height * 0.10427));
										Pen.fillStroke;

										// Inner fold stroke body: vector-traced from the supplied reference ear symbol.
										Pen.moveTo(Point(b.width * 0.43256, b.height * 0.27488));
										Pen.lineTo(Point(b.width * 0.39535, b.height * 0.31754));
										Pen.lineTo(Point(b.width * 0.39535, b.height * 0.38389));
										Pen.lineTo(Point(b.width * 0.50233, b.height * 0.46445));
										Pen.lineTo(Point(b.width * 0.51163, b.height * 0.48815));
										Pen.lineTo(Point(b.width * 0.48837, b.height * 0.54028));
										Pen.lineTo(Point(b.width * 0.49302, b.height * 0.55924));
										Pen.lineTo(Point(b.width * 0.52558, b.height * 0.59716));
										Pen.lineTo(Point(b.width * 0.56279, b.height * 0.60190));
										Pen.lineTo(Point(b.width * 0.58140, b.height * 0.57820));
										Pen.lineTo(Point(b.width * 0.53953, b.height * 0.55924));
										Pen.lineTo(Point(b.width * 0.53023, b.height * 0.54028));
										Pen.lineTo(Point(b.width * 0.56744, b.height * 0.48815));
										Pen.lineTo(Point(b.width * 0.56744, b.height * 0.45972));
										Pen.lineTo(Point(b.width * 0.53023, b.height * 0.39810));
										Pen.lineTo(Point(b.width * 0.46977, b.height * 0.36967));
										Pen.lineTo(Point(b.width * 0.44651, b.height * 0.34597));
										Pen.lineTo(Point(b.width * 0.44651, b.height * 0.32701));
										Pen.lineTo(Point(b.width * 0.47907, b.height * 0.30332));
										Pen.lineTo(Point(b.width * 0.51628, b.height * 0.30806));
										Pen.lineTo(Point(b.width * 0.53023, b.height * 0.29858));
										Pen.lineTo(Point(b.width * 0.53023, b.height * 0.28436));
										Pen.lineTo(Point(b.width * 0.49767, b.height * 0.26540));
										Pen.lineTo(Point(b.width * 0.43256, b.height * 0.27488));
										Pen.fillStroke;
								};
							});
							v.mouseDownAction_({ action.value((stateFunc.value == true).not); v.refresh; });
							v;
						};

makeSliderRow = { |parent, yy, label, value, action|
							var s, n, v;
							v = (value ? 0.0).clip(0.0, 1.0);
							makeLabel.(parent, Rect(115, yy - 1, 62, 16), label, subtle, 10);
							s = Slider(parent, Rect(176, yy + 1, 88, 14));
							n = NumberBox(parent, Rect(268, yy - 2, 34, 18));
							n.clipLo_(0.0); n.clipHi_(1.0); n.decimals_(2); n.value_(v);
							s.value_(v);
							s.action_({ n.value_(s.value); action.value(s.value); });
							n.action_({ var x; x = n.value.clip(0.0, 1.0); n.value_(x); s.value_(x); action.value(x); });
							(slider: s, number: n, nextY: yy + 29);
						};

						makePopupRow = { |parent, yy, label, items, idx, action|
							var p;
							makeLabel.(parent, Rect(115, yy, 62, 16), label, subtle, 10);
							p = PopUpMenu(parent, Rect(176, yy - 2, 126, 20));
							p.items_(items);
							p.value_(idx);
							p.action_({ action.value(p.value); });
							(menu: p, nextY: yy + 27);
						};

						fmtNum = { |x, q=0.01| ((x ? 0.0).round(q)).asString };
						fmtPcList = { |arr|
							if(arr.isNil or: { arr.isEmpty }) { "-" } { arr.collect { |pc| pitchClassNames[(pc ? 0).asInteger.clip(0, 11)] }.join(", ") }
						};
						fmtMidiList = { |arr|
							if(arr.isNil or: { arr.isEmpty }) { "-" } { arr.collect { |m| pitchClassNames[(m.asInteger % 12)] ++ m.asString }.join(", ") }
						};

						win = Window("Adaptive Temperament", Rect(screen.left + ((screen.width - winW) * 0.5), screen.top + ((screen.height - winH) * 0.5), winW, winH));
						win.background_(panelBg);

						leftPanel = CompositeView(win, Rect(outerPad, outerPad, leftW, topH));
						leftPanel.background_(panelBg);
						rightPanel = CompositeView(win, Rect(outerPad + leftW + gap, outerPad, rightW, topH));
						rightPanel.background_(panelBg);
						keyboardPanel = CompositeView(win, Rect(outerPad, outerPad + topH + gap, winW - (outerPad * 2), keyH));
						keyboardPanel.background_(panelBg);

						topStrip = makeCard.(leftPanel, Rect(0, 0, leftW, 62), nil);
						powerButton = makeToggle.(topStrip, Rect(12, 14, 104, 32), "Power Off", "Power On", st[\powerEnabled] ? true, { |flag| api[\setPowerEnabled].(flag); });
						tonesButton = makeButton.(topStrip, Rect(126, 14, 104, 32), "Tones", { setPage.(2); });
						panicButton = makeButton.(topStrip, Rect(246, 19, 58, 22), "Panic", {
							if(at[\allVoicesOff].notNil) { at[\allVoicesOff].(); };
							if(st[\activeNotes].notNil) { st[\activeNotes].clear; };
							api[\refreshUISnapshot].();
						}, danger);

						brainCard = makeCard.(leftPanel, Rect(0, 72, leftW, 226), "Brain");
						brainButton = makeIconToggle.(brainCard, Rect(14, 42, 86, 86), \brain, { st[\brainEnabled] ? true }, { |flag| api[\setBrainEnabled].(flag); });
						y = 42;
						motionSlider = makeSliderRow.(brainCard, y, "Motion", st[\movement] ? 0.82, { |v| api[\setMacro].(\motion, v); }); motionNum = motionSlider[\number]; y = motionSlider[\nextY];
						carrySlider = makeSliderRow.(brainCard, y, "Carry", if(cfg[\solver][\contextGaugeEnabled] ? true) { ((cfg[\solver][\contextGaugeStrength] ? 1.0) / 1.4).clip(0.0, 1.0) } { 0.0 }, { |v| api[\setMacro].(\carry, v); }); carryNum = carrySlider[\number]; y = carrySlider[\nextY];
						memorySlider = makeSliderRow.(brainCard, y, "Memory", st[\memoryAmount] ? (cfg[\memory][\amount] ? 0.35), { |v| api[\setMacro].(\memory, v); }); memoryNum = memorySlider[\number]; y = memorySlider[\nextY];
						gravitySlider = makeSliderRow.(brainCard, y, "Gravity", if(cfg[\gravity].notNil and: { cfg[\gravity][\enabled] ? false }) { cfg[\gravity][\strength] ? 0.18 } { 0.0 }, { |v| api[\setMacro].(\gravity, v); }); gravityNum = gravitySlider[\number]; y = gravitySlider[\nextY];
						tensionSlider = makeSliderRow.(brainCard, y, "Tension", st[\tension] ? 0.55, { |v| api[\setMacro].(\tension, v); }); tensionNum = tensionSlider[\number];

						earCard = makeCard.(leftPanel, Rect(0, 308, leftW, 162), "Ear");
						earButton = makeIconToggle.(earCard, Rect(14, 42, 86, 86), \ear, { cfg[\mic][\enabled] ? false }, { |flag| api[\setMicEnabled].(flag); });
						y = 42;
						micAmountSlider = makeSliderRow.(earCard, y, "Amount", ((cfg[\mic][\weight] ? 0.35) / 1.2).clip(0.0, 1.0), { |v| api[\setMacro].(\micAmount, v); }); micAmountNum = micAmountSlider[\number]; y = micAmountSlider[\nextY];
						micTrustSlider = makeSliderRow.(earCard, y, "Trust", cfg[\mic][\trust] ? 0.70, { |v| api[\setMacro].(\micTrust, v); }); micTrustNum = micTrustSlider[\number]; y = micTrustSlider[\nextY];
						micModeMenu = makePopupRow.(earCard, y, "Mode", ["External Only", "Duet Safe", "Full Blend", "External Follow"],
							switch(cfg[\mic][\influencePolicy] ? \externalOnly, \duetSafe, 1, \fullBlend, 2, \externalFollow, 3, 0),
							{ |idx| api[\setMicInfluencePolicy].([\externalOnly, \duetSafe, \fullBlend, \externalFollow][idx]); }
						)[\menu];

						toneCard = makeCard.(leftPanel, Rect(0, 480, leftW, topH - 480), "Tone");

						// Tone section: instrument body + simple L/M/H EQ + separate adaptive-tone behavior.
						makeLabel.(toneCard, Rect(14, 33, 48, 16), "Profile", subtle, 9);
						toneProfileMenu = PopUpMenu(toneCard, Rect(63, 30, 104, 20));
						toneProfileMenu.items_(["Probe", "Pure", "Piano", "E Piano", "Organ", "Pad", "Synth"]);
						toneProfileMenu.value_(switch((cfg[\render][\toneProfile] ? \organ), \probe, 0, \pure, 1, \piano, 2, \electricPiano, 3, \organ, 4, \pad, 5, \synth, 6, 4));
						toneProfileMenu.action_({ |menu|
							var profiles;
							profiles = [\probe, \pure, \piano, \electricPiano, \organ, \pad, \synth];
							if(api[\setToneProfile].notNil) { api[\setToneProfile].(profiles[menu.value.clip(0, profiles.size - 1)]); };
						});

						makeLabel.(toneCard, Rect(178, 33, 42, 16), "Adapt", subtle, 9);
						adaptiveToneModeMenu = PopUpMenu(toneCard, Rect(220, 30, 92, 20));
						adaptiveToneModeMenu.items_(["Static", "Bloom", "Breath", "Edge", "Listen"]);
						adaptiveToneModeMenu.value_(switch((cfg[\render][\adaptiveToneMode] ? \static), \static, 0, \coherenceBloom, 1, \motionBreath, 2, \tensionEdge, 3, \listening, 4, 0));
						adaptiveToneModeMenu.action_({ |menu|
							var modes;
							modes = [\static, \coherenceBloom, \motionBreath, \tensionEdge, \listening];
							if(api[\setAdaptiveToneMode].notNil) { api[\setAdaptiveToneMode].(modes[menu.value.clip(0, modes.size - 1)]); };
						});

						makeLabel.(toneCard, Rect(14, 61, 16, 14), "L", ink, 10, \center, true);
						toneLowSlider = Slider(toneCard, Rect(31, 62, 62, 14));
						toneLowSlider.value_(cfg[\render][\toneLow] ? 0.5);
						toneLowSlider.action_({ |sl| if(api[\setToneLow].notNil) { api[\setToneLow].(sl.value); }; });
						makeLabel.(toneCard, Rect(103, 61, 16, 14), "M", ink, 10, \center, true);
						toneMidSlider = Slider(toneCard, Rect(121, 62, 62, 14));
						toneMidSlider.value_(cfg[\render][\toneMid] ? 0.5);
						toneMidSlider.action_({ |sl| if(api[\setToneMid].notNil) { api[\setToneMid].(sl.value); }; });
						makeLabel.(toneCard, Rect(194, 61, 16, 14), "H", ink, 10, \center, true);
						toneHighSlider = Slider(toneCard, Rect(212, 62, 62, 14));
						toneHighSlider.value_(cfg[\render][\toneHigh] ? 0.5);
						toneHighSlider.action_({ |sl| if(api[\setToneHigh].notNil) { api[\setToneHigh].(sl.value); }; });
						makeLabel.(toneCard, Rect(278, 59, 34, 16), "EQ", subtle, 8, \center);

						makeLabel.(toneCard, Rect(14, 88, 52, 16), "Amount", subtle, 9);
						adaptiveToneAmountSlider = Slider(toneCard, Rect(70, 90, 128, 14));
						adaptiveToneAmountSlider.value_(cfg[\render][\adaptiveToneAmount] ? 0.0);
						adaptiveToneAmountNum = NumberBox(toneCard, Rect(204, 86, 38, 18));
						adaptiveToneAmountNum.clipLo_(0.0); adaptiveToneAmountNum.clipHi_(1.0); adaptiveToneAmountNum.decimals_(2);
						adaptiveToneAmountNum.value_(cfg[\render][\adaptiveToneAmount] ? 0.0);
						adaptiveToneAmountSlider.action_({ |sl|
							adaptiveToneAmountNum.value_(sl.value);
							if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(sl.value); };
						});
						adaptiveToneAmountNum.action_({ |nb|
							var x;
							x = nb.value.clip(0.0, 1.0);
							nb.value_(x); adaptiveToneAmountSlider.value_(x);
							if(api[\setAdaptiveToneAmount].notNil) { api[\setAdaptiveToneAmount].(x); };
						});
						makeLabel.(toneCard, Rect(247, 87, 65, 16), "separate", subtle, 8, \center);

						displayCard = makeCard.(rightPanel, Rect(0, 0, rightW, topH), nil);
						statusTitle = makeLabel.(displayCard, Rect(18, 10, rightW - 36, 20), "Adaptive Field", ink, 15, \left, true);
						statusLine = makeLabel.(displayCard, Rect(18, 34, rightW - 36, 17), "Mode: -", subtle, 10);
						statusLine2 = makeLabel.(displayCard, Rect(18, 52, rightW - 36, 17), "State: -", subtle, 10);
						eyeView = UserView(displayCard, Rect(18, 76, rightW - 36, topH - 96));
						eyeView.background_(panelBg);

						tabs = ["Mic", "Render", "Advanced"];
						tabButtons = Array.newClear(tabs.size);
						pages = Array.newClear(tabs.size);
						tabs.do { |name, idx|
							tabButtons[idx] = Button(keyboardPanel, Rect(12 + (idx * 88), 8, 78, 22));
							tabButtons[idx].states_([[name, subtle, controlBg], [name, ink, controlHi]]);
							tabButtons[idx].action_({ setPage.(idx); });
						};
						keyboardView = UserView(keyboardPanel, Rect(12, 70, keyboardPanel.bounds.width - 24, keyboardPanel.bounds.height - 82));
						keyboardView.background_(panelBg);

						micPage = CompositeView(keyboardPanel, Rect(370, 6, keyboardPanel.bounds.width - 382, 58));
						renderPage = CompositeView(keyboardPanel, Rect(370, 6, keyboardPanel.bounds.width - 382, 58));
						advPage = CompositeView(keyboardPanel, Rect(370, 6, keyboardPanel.bounds.width - 382, 58));
						pages[0] = micPage; pages[1] = renderPage; pages[2] = advPage;
						pages.do { |p| p.background_(panelBg); };
						micInfo = makeLabel.(micPage, Rect(0, 4, micPage.bounds.width, 16), "Mic: pressure, not truth.", subtle, 9);
						renderInfo = makeLabel.(renderPage, Rect(0, 4, renderPage.bounds.width, 16), "Render: production tone controls remain in the API.", subtle, 9);
						advInfo = makeLabel.(advPage, Rect(0, 0, 250, 11), "Chord / Gravity / Spectrum", subtle, 9);
						makeLabel.(advPage, Rect(0, 13, 28, 12), "Reg", subtle, 8);
						registerAuthoritySlider = Slider(advPage, Rect(29, 13, 86, 12));
						registerAuthoritySlider.value_(((cfg[\registerVelocity][\registerAmount] ? 1.0) / 2.0).clip(0.0, 1.0));
						registerAuthorityValue = makeLabel.(advPage, Rect(118, 12, 34, 13), (cfg[\registerVelocity][\registerAmount] ? 1.0).round(0.01).asString, subtle, 8);
						makeLabel.(advPage, Rect(162, 13, 28, 12), "Vel", subtle, 8);
						velocityAuthoritySlider = Slider(advPage, Rect(191, 13, 86, 12));
						velocityAuthoritySlider.value_(((cfg[\registerVelocity][\velocityAmount] ? 1.0) / 2.0).clip(0.0, 1.0));
						velocityAuthorityValue = makeLabel.(advPage, Rect(280, 12, 34, 13), (cfg[\registerVelocity][\velocityAmount] ? 1.0).round(0.01).asString, subtle, 8);
						registerAuthoritySlider.action_({ |sl|
							var reg, vel;
							reg = (sl.value * 2.0).clip(0.0, 2.0);
							vel = cfg[\registerVelocity][\velocityAmount] ? 1.0;
							registerAuthorityValue.string_(reg.round(0.01).asString);
							if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(reg, vel); };
						});
						velocityAuthoritySlider.action_({ |sl|
							var reg, vel;
							reg = cfg[\registerVelocity][\registerAmount] ? 1.0;
							vel = (sl.value * 2.0).clip(0.0, 2.0);
							velocityAuthorityValue.string_(vel.round(0.01).asString);
							if(api[\setRegisterVelocityAuthority].notNil) { api[\setRegisterVelocityAuthority].(reg, vel); };
						});
						ui[\registerVelocityControlsVisible] = true;

						makeLabel.(advPage, Rect(0, 36, 58, 12), "GravFollow", subtle, 8);
						gravityFollowMenu = PopUpMenu(advPage, Rect(61, 34, 80, 16));
						gravityFollowMenu.items_(["Off", "Fixed", "Memory", "Ear"]);
						gravityFollowMenu.value_(switch((cfg[\finalControls][\earGravityFollowMode] ? \off), \fixed, 1, \memory, 2, \ear, 3, 0));
						gravityFollowMenu.action_({ |menu|
							var mode;
							mode = [\off, \fixed, \memory, \ear].wrapAt(menu.value);
							if(api[\setGravityFollowMode].notNil) { api[\setGravityFollowMode].(mode, 1.0); };
						});
						makeLabel.(advPage, Rect(154, 36, 56, 12), "Accordion", subtle, 8);
						spectrumAccordionSlider = Slider(advPage, Rect(213, 36, 72, 12));
						spectrumAccordionSlider.value_(cfg[\finalControls][\spectrumAccordionAmount] ? 0.0);
						spectrumAccordionValue = makeLabel.(advPage, Rect(290, 35, 34, 13), (cfg[\finalControls][\spectrumAccordionAmount] ? 0.0).round(0.01).asString, subtle, 8);
						spectrumAccordionSlider.action_({ |sl|
							var amt;
							amt = sl.value.clip(0.0, 1.0);
							spectrumAccordionValue.string_(amt.round(0.01).asString);
							if(api[\setSpectrumAccordionAmount].notNil) { api[\setSpectrumAccordionAmount].(amt, \bellLike); };
						});

						setPage = { |idx|
							activeTab = idx.clip(0, tabs.size - 1);
							pages.do { |p, i| p.visible_(i == activeTab); };
							tabButtons.do { |b, i| b.value_(if(i == activeTab) { 1 } { 0 }); };
						};
						setPage.(0);

						drawEye = { |view|
							var snap, b, cx, cy, r, activePcs, brainOn, earOn, powerOn, pcCount, maxDev, micCandidates, extSources;
							var rootPc, gravityOn, gravPc, memAmt, gravAmt, eyeW, eyeH, leftX, rightX, topY, botY, scleraCol, lidCol;
							snap = ui[\snapshot] ? (api[\uiSnapshot].());
							b = view.bounds;
							cx = b.width * 0.5;
							cy = b.height * 0.47;
							r = b.height.min(b.width) * 0.265; // larger whole eye, same visual language
							activePcs = snap[\activePcs] ? Array.new;
							brainOn = snap[\brainEnabled] ? true;
							earOn = snap[\micEnabled] ? false;
							powerOn = snap[\powerEnabled] ? true;
							pcCount = cfg[\solver][\numNodes] ? 12;
							maxDev = snap[\maxDevCents] ? 0.0;
							micCandidates = snap[\micCandidates] ? Array.new;
							extSources = snap[\externalSources] ? Array.new;
							rootPc = snap[\worldRootPc] ? (snap[\gravityHomePc] ? 0);
							gravityOn = snap[\gravityEnabled] ? false;
							gravPc = snap[\gravityHomePc] ? 0;
							memAmt = (snap[\memoryAmount] ? 0.0).clip(0.0, 1.0);
							gravAmt = (snap[\gravityStrength] ? 0.0).clip(0.0, 1.0);
							eyeW = r * 5.10;
							eyeH = r * 2.72;
							leftX = cx - (eyeW * 0.5);
							rightX = cx + (eyeW * 0.5);
							topY = cy - (eyeH * 0.5);
							botY = cy + (eyeH * 0.5);
							scleraCol = if(brainOn) { Color(0.94, 0.88, 0.76, 1.0) } { Color(0.80, 0.73, 0.66, 1.0) };
							lidCol = if(brainOn) { Color(0.20, 0.095, 0.075, 0.88) } { Color(0.20, 0.14, 0.12, 0.40) };

							// One continuous skin-tone surface: no visible screen/card behind the eye.
							Pen.fillColor = panelBg;
							Pen.fillRect(b);
							Pen.fillColor = Color(0.70, 0.54, 0.44, 0.055);
							Pen.fillOval(Rect.aboutPoint(Point(cx, cy + (eyeH * 0.18)), eyeW * 0.54, eyeH * 0.44));

								// Clean symbolic eye: filled almond opening around the iris, no decorative crossing lid lines.
								Pen.fillColor = scleraCol;
								Pen.strokeColor = Color(0.18, 0.085, 0.062, if(brainOn) { 0.36 } { 0.15 });
								Pen.width = 1.2;
								Pen.moveTo(Point(leftX, cy));
								Pen.curveTo(Point(rightX, cy), Point(cx - (eyeW * 0.31), cy - (eyeH * 0.55)), Point(cx + (eyeW * 0.31), cy - (eyeH * 0.55)));
								Pen.curveTo(Point(leftX, cy), Point(cx + (eyeW * 0.35), cy + (eyeH * 0.53)), Point(cx - (eyeW * 0.35), cy + (eyeH * 0.53)));
								Pen.fillStroke;

							// Iris shadow, then iris.
							Pen.fillColor = Color(0.10, 0.06, 0.04, if(brainOn) { 0.16 } { 0.06 });
							Pen.fillOval(Rect.aboutPoint(Point(cx, cy + 4), r * 1.045, r * 1.045));
							Pen.fillColor = Color(0.020, 0.050, 0.082, if(brainOn) { 0.98 } { 0.50 });
							Pen.fillOval(Rect.aboutPoint(Point(cx, cy), r, r));
							Pen.strokeColor = Color(0.18, 0.36, 0.58, if(brainOn) { 0.74 } { 0.22 });
							Pen.width = 2.0;
							Pen.addOval(Rect.aboutPoint(Point(cx, cy), r, r));
							Pen.stroke;

							// Subtle iris depth rings.
							4.do { |i|
								var rr;
								rr = r * (0.28 + (i * 0.18));
								Pen.strokeColor = Color(0.34, 0.48, 0.66, if(brainOn) { 0.10 } { 0.04 });
								Pen.width = 1.0;
								Pen.addOval(Rect.aboutPoint(Point(cx, cy), rr, rr));
								Pen.stroke;
							};

							// Pupil.
							Pen.fillColor = Color(0, 0, 0, if(powerOn) { 0.96 } { 0.45 });
							Pen.fillOval(Rect.aboutPoint(Point(cx, cy + 2), r * 0.18, r * 0.18));
							Pen.fillColor = Color(0.88, 0.86, 0.80, if(powerOn) { 0.70 } { 0.20 });
							Pen.fillOval(Rect.aboutPoint(Point(cx - (r * 0.10), cy - (r * 0.10)), 3.0, 2.2));

							// Mic pressure halo.
							if(earOn) {
								(extSources ++ micCandidates).do { |src|
									var pc, cent, ang, weight, p1, p2;
									pc = (src[\pc] ? src[\pitchClass] ? src[\nearestPc] ? 0).asInteger.clip(0, 11);
									cent = (src[\cents] ? src[\offsetCents] ? 0.0) / 1200.0;
									weight = (src[\weight] ? src[\confidence] ? 0.25).clip(0.0, 1.0);
									ang = (((pc / 12.0) + cent) * 2pi) - (pi / 2);
									p1 = Point(cx + (ang.cos * (r + 36)), cy + (ang.sin * (r + 36)));
									p2 = Point(cx + (ang.cos * (r + 8)), cy + (ang.sin * (r + 8)));
									Pen.strokeColor = Color(0.20, 0.95, 0.95, 0.10 + (weight * 0.38));
									Pen.width = 1.0 + (weight * 2.0);
									Pen.moveTo(p1); Pen.lineTo(p2); Pen.stroke;
									Pen.fillColor = Color(0.20, 0.95, 0.95, 0.12 + (weight * 0.46));
									Pen.fillOval(Rect.aboutPoint(p1, 4.0 + (weight * 5.0), 4.0 + (weight * 5.0)));
								};
							};

							// Pitch-class nodes and labels.
							pcCount.do { |pc|
								var etPhase, livePhase, frozenPhase, memPhase, etAng, liveAng, labAng, etPt, livePt, labPt, frozenPt, memPt;
								var active, size, align, dev, nodeAlpha;
								etPhase = (snap[\etPhase] ? st[\etPhase])[pc] ? (pc / 12.0);
								active = activePcs.includes(pc);
								// Onset-first demo truth: silent pitch classes respond immediately
								// to the currently sounding frequency as passive harmonic potential.
								// They are small/passive glyphs, not pressure sources, but they are not fixed ET dots.
								livePhase = if(brainOn) { (snap[\nodePhase] ? st[\nodePhase])[pc] ? etPhase } { etPhase };
								frozenPhase = (snap[\frozenPhase] ? st[\frozenPhase])[pc] ? livePhase;
								memPhase = (snap[\memoryPhase] ? (snap[\nodePhase] ? st[\nodePhase]))[pc] ? livePhase;
								etAng = (etPhase * 2pi) - (pi / 2);
								liveAng = (livePhase * 2pi) - (pi / 2);
								labAng = (pc / 12.0 * 2pi) - (pi / 2);
								etPt = Point(cx + (etAng.cos * r), cy + (etAng.sin * r));
								livePt = Point(cx + (liveAng.cos * r), cy + (liveAng.sin * r));
								labPt = Point(cx + (labAng.cos * (r + 23)), cy + (labAng.sin * (r + 23)));
								frozenPt = Point(cx + (((frozenPhase * 2pi) - (pi / 2)).cos * r), cy + (((frozenPhase * 2pi) - (pi / 2)).sin * r));
								memPt = Point(cx + (((memPhase * 2pi) - (pi / 2)).cos * (r - 13)), cy + (((memPhase * 2pi) - (pi / 2)).sin * (r - 13)));
								align = ((snap[\nodeAlignment] ? [])[pc] ? 1.0).clip(0.0, 1.0);
								dev = (((snap[\etDeviationCents] ? [])[pc] ? 0.0).abs / 36.0).clip(0.0, 1.0);
								nodeAlpha = if(brainOn) { 0.68 } { 0.22 };

								if(brainOn and: { memAmt > 0.02 }) {
									Pen.strokeColor = Color(0.62, 0.72, 0.95, memAmt * 0.24);
									Pen.width = 1.0;
									Pen.addOval(Rect.aboutPoint(memPt, 4.5, 4.5));
									Pen.stroke;
								};

								if(brainOn and: { snap[\frozenValid] ? false }) {
									Pen.strokeColor = Color(0.98, 0.82, 0.28, snap[\frozenGhostAlpha] ? 0.28);
									Pen.addOval(Rect.aboutPoint(frozenPt, 4.5, 4.5));
									Pen.stroke;
								};

								Pen.fillColor = Color(0.12, 0.17, 0.23, if(brainOn) { 0.26 } { 0.15 });
								Pen.fillOval(Rect.aboutPoint(etPt, 2.6, 2.6));
								if(brainOn and: { dev > 0.01 }) {
									Pen.strokeColor = Color(0.58, 0.72, 1.0, 0.07 + (dev * 0.30));
									Pen.width = 1.0;
									Pen.moveTo(etPt); Pen.lineTo(livePt); Pen.stroke;
								};
								size = if(active) { 9.5 + (align * 6.5) } { 2.8 };
								Pen.fillColor = if(active) { Color(0.62 + (align * 0.20), 0.78 + (align * 0.12), 1.0, if(powerOn) { 0.98 } { 0.35 }) } { Color(0.16, 0.20, 0.25, if(brainOn) { 0.34 } { 0.16 }) };
								Pen.fillOval(Rect.aboutPoint(livePt, size, size));
								Pen.strokeColor = if(active) { Color(1, 1, 1, 0.95) } { Color(0.78, 0.82, 0.90, if(brainOn) { 0.20 } { 0.08 }) };
								Pen.width = if(active) { 1.6 } { 0.65 };
								Pen.addOval(Rect.aboutPoint(livePt, size, size)); Pen.stroke;
								Pen.color = Color(0.10, 0.08, 0.065, if(brainOn) { 0.82 } { 0.30 });
								Pen.stringAtPoint(pitchClassNames[pc], labPt - Point(8, 7));
							};

							if(brainOn and: { gravityOn and: { gravAmt > 0.0 } }) {
								var gphase, gang, gp;
								gphase = ((snap[\etPhase] ? st[\etPhase])[gravPc] ? (gravPc / 12.0)) + ((snap[\gravityHomeCents] ? 0.0) / 1200.0);
								gang = (gphase * 2pi) - (pi / 2);
								gp = Point(cx + (gang.cos * (r + 48)), cy + (gang.sin * (r + 48)));
								Pen.fillColor = Color(0.95, 0.67, 0.16, 0.14 + (gravAmt * 0.34));
								Pen.fillOval(Rect.aboutPoint(gp, 16, 16));
								Pen.fillColor = Color(0.95, 0.67, 0.16, 0.92);
								Pen.fillOval(Rect.aboutPoint(gp, 5, 5));
							};

								// Graphic lid outline drawn last: strong upper lid, soft lower lid, no iris-crossing line.
								Pen.strokeColor = lidCol;
								Pen.width = 4.8;
								Pen.moveTo(Point(leftX, cy));
								Pen.curveTo(Point(rightX, cy), Point(cx - (eyeW * 0.31), cy - (eyeH * 0.55)), Point(cx + (eyeW * 0.31), cy - (eyeH * 0.55)));
								Pen.stroke;
								Pen.strokeColor = Color(0.22, 0.11, 0.085, if(brainOn) { 0.34 } { 0.14 });
								Pen.width = 1.7;
								Pen.moveTo(Point(leftX, cy));
								Pen.curveTo(Point(rightX, cy), Point(cx - (eyeW * 0.35), cy + (eyeH * 0.53)), Point(cx + (eyeW * 0.35), cy + (eyeH * 0.53)));
								Pen.stroke;
						};
						drawKeyboard = { |view|
							var snap, b, whiteNotes, whiteW, blackW, blackH, activeNotes, activePcs, isBlack, whiteIndexForMidi, toothBounds;
							snap = ui[\snapshot] ? (api[\uiSnapshot].());
							b = view.bounds;
							activeNotes = snap[\activeNotes] ? Array.new;
							activePcs = snap[\activePcs] ? Array.new;
							isBlack = { |m| [1, 3, 6, 8, 10].includes(m % 12) };
							whiteNotes = Array.new;
							(keyboardRangeStart..keyboardRangeEnd).do { |m| if(isBlack.(m).not) { whiteNotes = whiteNotes.add(m); } };
							whiteW = b.width / whiteNotes.size.max(1);
							blackW = whiteW * 0.50;
							blackH = b.height * 0.30;
							whiteIndexForMidi = { |m|
								var count;
								count = 0;
								(keyboardRangeStart..m).do { |n| if(isBlack.(n).not) { count = count + 1; } };
								count - 1;
							};

							// v28 gum-and-teeth keyboard: gums unchanged; white teeth visibly longer in the middle and shorter/blunter at the edges.
							Pen.fillColor = panelBg;
							Pen.fillRect(b);
							blackW = whiteW * 0.68;
							blackH = b.height * 0.39;

							// Continuous gum ridge: thicker and more present than v26, not tiny red trim.
							Pen.fillColor = Color(0.31, 0.070, 0.062, 1.0);
							Pen.fillRect(Rect(0, 0, b.width, 10));
							Pen.fillColor = Color(0.54, 0.145, 0.125, 1.0);
							Pen.fillRect(Rect(0, 9, b.width, 18));
							Pen.fillColor = Color(0.80, 0.33, 0.28, 0.16);
							Pen.fillRect(Rect(0, 12, b.width, 3));

							// Subtle scalloped gum lower edge where the tooth-keys emerge.
							whiteNotes.do { |m, i|
								var x, centerDist, edgeLift;
								x = i * whiteW;
								centerDist = ((i - ((whiteNotes.size - 1) * 0.5)).abs / ((whiteNotes.size - 1) * 0.5)).clip(0.0, 1.0);
								edgeLift = centerDist.squared * 3.0;
								Pen.fillColor = Color(0.61, 0.19, 0.16, 0.34);
								Pen.fillOval(Rect.aboutPoint(Point(x + (whiteW * 0.50), 28 - edgeLift), whiteW * 0.48, 5));
							};

							// v34 white teeth: draw a tight continuous ivory tooth-key row, not separated dangling slots.
							// The seam positions still imply keyboard keys, but the visible row behaves like teeth:
							// wide/short molars at the ends, a smooth inward transition, and a clean central front pair.
							{
								var weights, leftTotal, rightTotal, acc, frontPairA, frontPairB, frontBoundary;
								frontPairA = 13; // B3: adjacent to C4, no gum/black-key block between the front pair
								frontPairB = 14; // C4
								frontBoundary = b.width * 0.5;
								weights = Array.newClear(whiteNotes.size);
								leftTotal = 0.0;
								rightTotal = 0.0;
								whiteNotes.do { |m, i|
									var distFromFront, maxDist, molar, frontTooth, lateral, w;
									if(i <= frontPairA) {
										distFromFront = (frontPairA - i).abs;
										maxDist = frontPairA.max(1);
									} {
										distFromFront = (i - frontPairB).abs;
										maxDist = ((whiteNotes.size - 1) - frontPairB).max(1);
									};
									molar = (distFromFront / maxDist).clip(0.0, 1.0).pow(0.82);
									frontTooth = ((i == frontPairA) or: { i == frontPairB });
									lateral = (distFromFront <= 2) and: { frontTooth.not };
									// Ends are visibly thicker; inner teeth get thinner. Front pair stays broad, not needle-like.
									w = 0.98 + (molar * 0.38);
									if(lateral) { w = w * 0.96 };
									if(frontTooth) { w = w * 1.03 };
									weights.put(i, w);
									if(i <= frontPairA) { leftTotal = leftTotal + w } { rightTotal = rightTotal + w };
								};
								toothBounds = Array.newClear(whiteNotes.size + 1);
								toothBounds.put(0, 0.0);
								acc = 0.0;
								(0..frontPairA).do { |i|
									acc = acc + ((weights.at(i) / leftTotal.max(0.0001)) * frontBoundary);
									toothBounds.put(i + 1, acc);
								};
								toothBounds.put(frontPairB, frontBoundary);
								acc = frontBoundary;
								(frontPairB..(whiteNotes.size - 1)).do { |i|
									acc = acc + ((weights.at(i) / rightTotal.max(0.0001)) * (b.width - frontBoundary));
									toothBounds.put(i + 1, acc);
								};
							}.value;

							whiteNotes.do { |m, i|
								var left, right, centerX, pc, active, top, bottom, distFromFront, maxDist, molar, frontTooth, lateral, corner, seam, cLabelY, toothW, frontPairA, frontPairB;
								frontPairA = 13; frontPairB = 14;
								left = toothBounds.at(i);
								right = toothBounds.at(i + 1);
								centerX = (left + right) * 0.5;
								toothW = right - left;
								pc = m % 12;
								active = activeNotes.includes(m) or: { activePcs.includes(pc) };
								if(i <= frontPairA) {
									distFromFront = (frontPairA - i).abs;
									maxDist = frontPairA.max(1);
								} {
									distFromFront = (i - frontPairB).abs;
									maxDist = ((whiteNotes.size - 1) - frontPairB).max(1);
								};
								molar = (distFromFront / maxDist).clip(0.0, 1.0).pow(1.08);
								frontTooth = ((i == frontPairA) or: { i == frontPairB });
								lateral = (distFromFront <= 2) and: { frontTooth.not };
								top = 27;
								// Smooth contour: molars shorter/blunter; front pair only slightly longest, no sudden dropped blocks.
								bottom = b.height - (8.0 + (molar * 13.5));
								if(lateral) { bottom = bottom - 0.8 };
								if(frontTooth) { bottom = b.height - 7.0 };
								corner = (3.8 + (molar * 5.4)).min(toothW * 0.23);
								if(frontTooth) { corner = 4.2.min(toothW * 0.18) };
								// Near-zero gap: seams are drawn by strokes, not by skin-colored holes.
								seam = 0.06;
								left = left + seam;
								right = right - seam;

								Pen.fillColor = if(active) { Color(0.64, 0.80, 1.0, 1.0) } { Color(1.0, 0.965, 0.858, 1.0) };
								Pen.strokeColor = Color(0.18, 0.105, 0.082, 0.42);
								Pen.width = 0.62;
								Pen.moveTo(Point(left, top));
								Pen.lineTo(Point(right, top));
								Pen.lineTo(Point(right, bottom - corner));
								Pen.curveTo(Point(right - corner, bottom), Point(right, bottom - (corner * 0.34)), Point(right - (corner * 0.34), bottom));
								Pen.lineTo(Point(left + corner, bottom));
								Pen.curveTo(Point(left, bottom - corner), Point(left + (corner * 0.34), bottom), Point(left, bottom - (corner * 0.34)));
								Pen.lineTo(Point(left, top));
								Pen.fillStroke;

								// Subtle crown highlight, shared across the row rather than separate dangling strips.
								Pen.fillColor = Color(1.0, 0.985, 0.92, 0.08);
								Pen.fillRect(Rect(left + 1.5, top + 2, (right - left - 3).max(1), 5));
								if(((m % 12) == 0) and: { frontTooth.not }) {
									Pen.color = Color(0.16, 0.11, 0.10, 0.52);
									cLabelY = (bottom + 2).min(b.height - 16);
									Pen.stringAtPoint("C" ++ (m.div(12) - 1).asString, Point(left + 2, cLabelY));
								};
							};
							// Gum-colored accidentals: bigger, stronger, and embedded into the gum ridge.
							(keyboardRangeStart..keyboardRangeEnd).do { |m|
								var pc, wi, x, active, top, bottom;
								if(isBlack.(m)) {
									pc = m % 12;
									wi = whiteIndexForMidi.(m - 1);
									x = (toothBounds.at((wi + 1).clip(0, toothBounds.size - 1)) ? ((wi + 1) * whiteW)) - (blackW * 0.5);
									active = activeNotes.includes(m) or: { activePcs.includes(pc) };
									top = 0; bottom = blackH;
									Pen.fillColor = if(active) { Color(0.77, 0.30, 0.26, 1.0) } { Color(0.43, 0.085, 0.074, 1.0) };
									Pen.strokeColor = Color(0.14, 0.040, 0.036, 0.50);
									Pen.width = 1.0;
									Pen.moveTo(Point(x + 2.0, top));
									Pen.lineTo(Point(x + blackW - 2.0, top));
									Pen.lineTo(Point(x + blackW - 4.0, bottom - 6));
									Pen.curveTo(Point(x + 4.0, bottom - 6), Point(x + blackW - 6.0, bottom + 1.0), Point(x + 6.0, bottom + 1.0));
									Pen.lineTo(Point(x + 2.0, top));
									Pen.fillStroke;
									Pen.fillColor = if(active) { Color(0.98, 0.58, 0.52, 0.20) } { Color(0.70, 0.24, 0.22, 0.18) };
									Pen.fillRect(Rect(x + 5.0, bottom - 11, blackW - 10, 4));
								};
							};
						};
						eyeView.drawFunc_(drawEye);
						keyboardView.drawFunc_(drawKeyboard);

						refreshUI = {
							var snap, brainOn, earOn, powerOn, policyIdx, gravVal, carryVal, toneIdx, adaptIdx;
							snap = api[\uiSnapshot].();
							ui[\snapshot] = snap;
							brainOn = snap[\brainEnabled] ? true;
							earOn = snap[\micEnabled] ? false;
							powerOn = snap[\powerEnabled] ? true;
							powerButton.value_(if(powerOn) { 1 } { 0 });
								brainButton.refresh;
								earButton.refresh;
							motionSlider[\slider].enabled_(brainOn); carrySlider[\slider].enabled_(brainOn); memorySlider[\slider].enabled_(brainOn); gravitySlider[\slider].enabled_(brainOn); tensionSlider[\slider].enabled_(brainOn);
							motionNum.enabled_(brainOn); carryNum.enabled_(brainOn); memoryNum.enabled_(brainOn); gravityNum.enabled_(brainOn); tensionNum.enabled_(brainOn);
							micAmountSlider[\slider].enabled_(earOn); micTrustSlider[\slider].enabled_(earOn); micModeMenu.enabled_(earOn);
							micAmountNum.enabled_(earOn); micTrustNum.enabled_(earOn);
							carryVal = if(snap[\contextGaugeEnabled] ? false) { ((snap[\contextGaugeStrength] ? 1.0) / 1.4).clip(0.0, 1.0) } { 0.0 };
							gravVal = if(snap[\gravityEnabled] ? false) { snap[\gravityStrength] ? 0.0 } { 0.0 };
							motionSlider[\slider].value_(snap[\movement] ? 0.0); motionNum.value_(snap[\movement] ? 0.0);
							carrySlider[\slider].value_(carryVal); carryNum.value_(carryVal);
							memorySlider[\slider].value_(snap[\memoryAmount] ? 0.0); memoryNum.value_(snap[\memoryAmount] ? 0.0);
							gravitySlider[\slider].value_(gravVal); gravityNum.value_(gravVal);
							tensionSlider[\slider].value_(snap[\tension] ? 0.0); tensionNum.value_(snap[\tension] ? 0.0);
							micAmountSlider[\slider].value_(((cfg[\mic][\weight] ? 0.35) / 1.2).clip(0.0, 1.0)); micAmountNum.value_(((cfg[\mic][\weight] ? 0.35) / 1.2).clip(0.0, 1.0));
							micTrustSlider[\slider].value_(snap[\micTrust] ? 0.70); micTrustNum.value_(snap[\micTrust] ? 0.70);
							policyIdx = switch(snap[\micInfluencePolicy] ? \externalOnly, \duetSafe, 1, \fullBlend, 2, \externalFollow, 3, 0);
							micModeMenu.value_(policyIdx);
							toneIdx = switch(snap[\toneProfile] ? \organ, \probe, 0, \pure, 1, \piano, 2, \electricPiano, 3, \organ, 4, \pad, 5, \synth, 6, 4);
							adaptIdx = switch(snap[\adaptiveToneMode] ? \static, \static, 0, \coherenceBloom, 1, \motionBreath, 2, \tensionEdge, 3, \listening, 4, 0);
							toneProfileMenu.value_(toneIdx);
							adaptiveToneModeMenu.value_(adaptIdx);
							toneLowSlider.value_(snap[\toneLow] ? 0.5);
							toneMidSlider.value_(snap[\toneMid] ? 0.5);
							toneHighSlider.value_(snap[\toneHigh] ? 0.5);
							adaptiveToneAmountSlider.value_(snap[\adaptiveToneAmount] ? 0.0);
							if(registerAuthoritySlider.notNil) {
								registerAuthoritySlider.value_(((snap[\registerVelocityRegisterAmount] ? 1.0) / 2.0).clip(0.0, 1.0));
								registerAuthorityValue.string_((snap[\registerVelocityRegisterAmount] ? 1.0).round(0.01).asString);
							};
							if(velocityAuthoritySlider.notNil) {
								velocityAuthoritySlider.value_(((snap[\registerVelocityVelocityAmount] ? 1.0) / 2.0).clip(0.0, 1.0));
								velocityAuthorityValue.string_((snap[\registerVelocityVelocityAmount] ? 1.0).round(0.01).asString);
							};
							if(gravityFollowMenu.notNil) {
								gravityFollowMenu.value_(switch(snap[\earGravityFollowMode] ? \off, \fixed, 1, \memory, 2, \ear, 3, 0));
							};
							if(spectrumAccordionSlider.notNil) {
								spectrumAccordionSlider.value_(snap[\spectrumAccordionAmount] ? 0.0);
								spectrumAccordionValue.string_((snap[\spectrumAccordionAmount] ? 0.0).round(0.01).asString);
							};
							adaptiveToneAmountNum.value_(snap[\adaptiveToneAmount] ? 0.0);
							statusLine.string_("Mode: " ++ (if(brainOn) { "Adaptive" } { "Equal Temperament" }) ++ "   Power: " ++ (if(powerOn) { "On" } { "Muted" }) ++ "   Mic: " ++ (if(earOn) { "On" } { "Off" }));
							statusLine2.string_("State: " ++ (snap[\state] ? \neutral).asString ++ "   Active: " ++ fmtPcList.(snap[\activePcs]) ++ "   Notes: " ++ fmtMidiList.(snap[\activeNotes]));
							micInfo.string_("Mic: " ++ (if(earOn) { (snap[\micInfluencePolicy] ? \externalOnly).asString } { "off" }) ++ "   raw/stable/external: " ++ (snap[\rawCandidateCount] ? 0).asString ++ "/" ++ (snap[\stabilizedCandidateCount] ? 0).asString ++ "/" ++ (snap[\externalCount] ? 0).asString ++ "   amp: " ++ fmtNum.(snap[\micRawAmp], 0.0001));
							renderInfo.string_("Tone: " ++ (snap[\toneProfile] ? \organ).asString ++ "   Adaptive: " ++ (snap[\adaptiveToneMode] ? \static).asString ++ " " ++ fmtNum.(snap[\adaptiveToneAmount], 0.01) ++ "   EQ L/M/H " ++ fmtNum.(snap[\toneLow], 0.01) ++ "/" ++ fmtNum.(snap[\toneMid], 0.01) ++ "/" ++ fmtNum.(snap[\toneHigh], 0.01));
							advInfo.string_("Advanced: register/velocity, gravity follow, spectrum accordion");
							eyeView.refresh;
							keyboardView.refresh;
						};

						ui[\window] = win;
						ui[\eyeView] = eyeView;
						ui[\keyboardView] = keyboardView;
						ui[\snapshot] = api[\uiSnapshot].();
						refreshUI.value;

						ui[\refreshRoutine] = Routine({
							inf.do {
								if(ui[\window].notNil and: { ui[\window].isClosed.not }) { refreshUI.value; };
								(1.0 / (cfg[\ui][\fps] ? 15)).wait;
							};
						}).play(AppClock);

						win.onClose_({
							if(ui[\refreshRoutine].notNil) { ui[\refreshRoutine].stop; ui[\refreshRoutine] = nil; };
							ui[\window] = nil;
							ui[\uiOpen] = false;
							ui[\openingUi] = false;
							ui[\uiOpening] = false;
						});

						win.front;
						ui[\uiOpen] = true;
						ui[\openingUi] = false;
						ui[\uiOpening] = false;
						"[at-ui] main window opened".postln;
					} { |err|
						ui[\openingUi] = false;
						ui[\uiOpening] = false;
						ui[\uiOpen] = false;
						"[at-ui] UI failed safely; engine remains active.".warn;
						err.reportError;
					};
				}.defer(0.01);
			};
		};
	};

	at[\openUI] = { api[\openUI].(); };
	at[\closeUI] = { api[\closeUI].(); };
};
)
