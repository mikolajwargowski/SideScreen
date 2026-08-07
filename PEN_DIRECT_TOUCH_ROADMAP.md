# Pen / Direct Touch roadmap

This fork extends SideScreen into a high-refresh-rate Android pen display for macOS.

The primary goal is not an artist-only graphics tablet. It is a macOS extended display with precise direct manipulation for FigJam, Figma, tldraw, Excalidraw and general UI work, plus full active-stylus data where applications support it.

## Delivery principles

- Preserve the existing video pipeline until measurements identify a real bottleneck.
- Keep legacy touch behavior backward compatible.
- Negotiate a separate, versioned pen protocol before sending variable-length packets.
- Treat finger input and stylus input as independent modes.
- Use CoreGraphics/AppKit tablet events first. Investigate virtual HID only if application compatibility tests fail.
- Measure actual display mode, rendered FPS and latency; do not equate a selected 120 FPS setting with proven 120 Hz output.

## Delivery gates

### Gate 0 — baseline

- [x] macOS build and tests pass;
- [x] Android build and tests pass with JDK 17;
- [x] an authorized Galaxy Tab S8+ connects through ADB reverse;
- [x] unmodified SideScreen streams over USB;
- [x] Screen Recording and Accessibility permissions are verified;
- [ ] controlled 60/90/120 FPS baseline metrics are recorded.

See [HARDWARE_BASELINE_GALAXY_TAB_S8_PLUS.md](HARDWARE_BASELINE_GALAXY_TAB_S8_PLUS.md) for the measured device, decoder, display and S Pen evidence.

### Gate A — pen event compatibility

A standalone macOS probe must verify pressure, tilt, hover and buttons in:

- AppKit test canvas;
- Chrome Pointer Events / tldraw;
- at least one primary workflow: Figma, FigJam or Excalidraw.

For mouse-down and mouse-drag tablet events, set both `tabletEventPointPressure` and `mouseEventPressure`. Local discovery showed that AppKit otherwise reports pressure `1.0` for these event types.

### Gate B — high refresh

Test on the real tablet:

- 1400×876 HiDPI / 2800×1752 physical at 120 Hz;
- 1280×800 HiDPI / 2560×1600 physical at 120 Hz;
- 1400×876 HiDPI at 90 Hz;
- a 60 Hz reference profile.

Prefer stable frame pacing and low latency over native physical resolution.

## Planned workstreams

1. Capability handshake and length-prefixed Pen V1 codec with shared golden vectors.
2. Android stylus collector for historical samples, pressure, tilt, orientation, hover, buttons, eraser and cancel semantics.
3. macOS pen state machine and CoreGraphics injector with teardown safety.
4. Optional Direct Touch finger profile while preserving Legacy Touch.
5. Surface frame-rate request, active `Display.Mode` observation and stage-specific diagnostics.
6. Palm rejection profiles, local Android pen cursor and application compatibility matrix.

## Explicitly outside the first MVP

- DriverKit or virtual HID without evidence that CoreGraphics is insufficient;
- three- and four-finger system gestures;
- App Store distribution and notarization;
- rewriting the capture, encode or transport pipeline without measurements.
