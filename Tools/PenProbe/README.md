# SideScreen Flow Pen Probe

Local, dependency-free canvas for checking the complete SideScreen Flow pen path:

`Galaxy Tab S Pen -> Android MotionEvent -> SideScreen Flow protocol -> macOS CGEvent -> browser PointerEvent`

## Run

From the repository root:

```bash
./scripts/run_pen_probe.sh
```

Then open <http://127.0.0.1:8765> in a Mac browser and move that browser window onto the SideScreen display.

## Acceptance check

1. Draw with light and heavy pressure. The line width and `Pressure` value should change.
2. Lean the S Pen toward each screen edge. The purple dot must follow the physical lean: `L`, `R`, `U`, `D`.
3. Draw a recognizable shape.
4. Hold the S Pen side button and move the pen. `Interaction mode` should show `pan canvas`, `Buttons` should include bit 2 (`4`), and the existing shape should move without adding a stroke.
5. Release the side button. `Interaction mode` returns to `hover`; the next contact draws normally.

`Pointer type: mouse` is an expected limitation of the current CoreGraphics injection path. Pressure and tilt can still be present. `Barrel twist` is intentionally marked unsupported because Android `AXIS_ORIENTATION` is pen azimuth, not rotation around the pen barrel.
