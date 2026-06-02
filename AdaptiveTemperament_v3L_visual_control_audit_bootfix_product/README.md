# Adaptive Temperament v3L — Visual Full-System Control Audit Product

This package starts from the frozen v3J Memory/Adaptive Gravity Source Order keeper.

It adds a product-facing visual/control audit and completes the final visual surface for the features added late in the project: adaptive Gravity follow mode, Memory learn/seed control, Spectrum Accordion amount, Memory/Gravity audit, Visual audit, and quick final-demo launch.

Main commands:

```supercollider
"AdaptiveTemperament_run.scd".load;
~at[\api][\runVisualFullSystemControlAudit].();
~at[\api][\runMemoryGravityAudit].();
~atFinalDemoScenario[\quick].();
```

Expected visual audit line:

```text
[AT VISUAL FULL SYSTEM CONTROL AUDIT v3L] pass=... fail=0 visualControlsComplete=true pitchAuthorityAdded=false
```

This is an audit/control-surface branch. It does not change the harmonic law, Motion gate, Memory/Gravity source order, Ear policy, musical surface contract, adaptive timbre tuning-neutrality, or final demo musical ordering.
