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

## SideScreen Flow MVP checkpoint — 2026-08-07

Implemented on `codex/pen-direct-touch-foundation`:

- negotiated, opt-in Pen V1 capability handshake (`12`) and length-prefixed pen packets (`13`);
- matching Kotlin and Swift codecs with a shared 49-byte golden vector and malformed-input tests;
- Android S Pen collection for hover/proximity, contact, historical samples, pressure, tilt,
  orientation, distance, buttons, tool type, timestamps and sequence numbers;
- macOS tablet-point injection with both tablet and mouse pressure fields, correctly oriented
  tilt axes, buttons and teardown-safe mouse-up;
- app-level palm rejection while the pen is in range;
- Direct Touch as the default finger profile, with Legacy Touch still selectable on the Mac;
- a development application ID so SideScreen Flow Dev can coexist with an older signed client.

Measured end-to-end on the Galaxy Tab S8+ and Excalidraw: hover/contact packets arrived,
pressure ranged from about `0.046` to `0.988`, the S Pen button arrived as Android mask `32`,
and Excalidraw visibly rendered pressure-dependent stroke width. This closes the primary
CoreGraphics/Chromium pressure-compatibility risk for the MVP. Direct Touch and palm rejection
remain in interactive acceptance testing.

The local browser Pen Probe additionally verified live `tiltX` and `tiltY`. A directional test
then exposed a 90-degree axis error (`pen left` appeared as `vector up`): Android stylus azimuth
is clockwise from screen-up, not from screen-right. The macOS conversion now maps the four screen
directions explicitly and is covered by cardinal-direction unit tests. Live S8+ calibration found
that CoreGraphics exposes the injected X component with the opposite sign, while the Y component
matches the Android screen direction; this platform-boundary correction is now explicit. Android `AXIS_ORIENTATION`
is azimuth, not barrel rotation, so it must not be reported as Pointer Events `twist`; S Pen barrel
rotation remains unsupported unless the device exposes an independent sensor. Chromium currently
identifies the synthetic CoreGraphics event as `pointerType: mouse`, even though pressure and tilt
survive. Raw tablet-button metadata does not
surface as Pointer Events `buttons`, so SideScreen Flow needs an explicit mapping. The prepared
mapping offers Pan Canvas (middle-button drag, default), Right Click and Native modes; it still
requires a fresh Swift test/build after the local execution quota resets.

The accepted Retina profile is logical `1400x876` at 2x backing resolution: the host captures and
encodes `2800x1752`, matching the Galaxy Tab S8+ panel. The client is now configured with the
physical encoded size before its first keyframe. Direct Touch uses a 170 ms decision window so a
second finger or approaching S Pen can cancel the pending click before a drawing app creates a dot.

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

A standalone macOS probe or an end-to-end application test must verify pressure, tilt, hover and buttons in:

- [x] at least one primary workflow: Excalidraw (pressure verified end-to-end);
- [ ] AppKit test canvas;
- [ ] generic Chrome Pointer Events probe / tldraw;
- [ ] Figma or FigJam.

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
