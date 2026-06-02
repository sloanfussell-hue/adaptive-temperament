# Adaptive Temperament — v67o First Full Product Final Instrument Demo Physical Capture Stabilization

This is the cleaned first-version final product package with the final demo launched safely inside a Routine.

## What is included

- `AdaptiveTemperament_run.scd`
- `README_FIRST.md`
- `src/`
- One official final product demo: `Library.at(\at)[\api][\runFinalInstrumentDemo].();`

## What is intentionally not included

- regression harnesses and historical debug suites
- historical release notes
- old package manifests
- stale logs
- deprecated diagnostics
- extra demo branches

## Final stack

- EP rendered pitch verification remains in the runtime stack
- external coherence scene engine
- register/velocity chord-local harmonic chart authority
- Movement/Motion global slew gate
- visual controls from the v65b keeper
- pitch-neutral Tension/adaptive timbre
- explicit Ear → Gravity follow control
- explicit bounded Spectrum Accordion control
- real speaker-to-mic external stimulus scenes for the final demo

## Run

1. Open SuperCollider.
2. Evaluate `AdaptiveTemperament_run.scd`.
3. Confirm the UI opens.
4. Run:

```supercollider
Library.at(\at)[\api][\runFinalInstrumentDemo].();
```

The final demo uses actual public controls and actual instrument note playback. The only thing the demo does that a single player could not do manually is generate the external speaker stimuli used for the Ear scenes. Those external scenes are real audio through the output device and are meant to be heard by the laptop microphone; they are not hidden injected external evidence.

## v67o note

The official demo polls/advances the live instrument while notes and speaker stimuli are sounding, verifies physical mic input before claiming Ear behavior, and avoids stale post-stimulus no-evidence reports. Ear→Gravity is adaptive but trust-gated: it follows a stable single reference, coherent multi-source external music, or a voice-aware coherent external scene, and it holds the previous gravity home instead of chasing sparse mic artifacts. The final combined physical scene now retries with a stronger isolated C context if the first mic frame misses it, and the summary file reports `physicalWarnings` plus `finalFreezeReady` so hardware-mic misses are visible instead of silently treated as a finished freeze.


## v67o note

Non-critical Section 12 warm-up ET C/F physical probe misses no longer make the final product freeze gate fail. The demo still requires the critical C-resolve, singer/voice, stretched-spectrum, and final combined capture gates before running the corresponding internal response. The final freeze decision remains strict: `finalFreezeReady=true` only when critical physical warnings are zero.

## v67o note

The singer scene now avoids same-pitch-class masking by using a C/G external band and a separate flat/vibrato singer on E. If the first voice capture is missed, the demo makes one stronger voice retry before counting a critical physical warning. The stretched-spectrum scene also retries once with stronger inharmonic stimulus before counting a critical warning. Critical skipped internal responses now increment the final physical warning counter, so `finalFreezeReady=true` means the critical physical capture gates actually passed.


## Final visual-control audit candidate

This package is a separate audit branch derived from the frozen Version 1 Final Product Keeper. It does not replace the keeper. It adds one optional read-only/non-musical audit command to verify that the visual control surface maps to public API state and UI snapshots.

Run after boot/UI opens:

```supercollider
Library.at(\at)[\api][\runFinalVisualControlAudit].();
```

Expected summary:

```text
[AT FINAL VISUAL CONTROL AUDIT] pass=<n> fail=0 visualControlsRespond=true pitchAuthorityAdded=false
```

The audit saves the current control state, sweeps the same public APIs used by the visual controls, checks the UI snapshot/control state, and restores the previous state. It does not change harmonic law, Motion, Memory, Gravity, Ear, Spectrum Accordion bounds, samples, UI layout, or the final demo.
