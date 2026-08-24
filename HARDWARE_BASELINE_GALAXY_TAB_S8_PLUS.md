# Galaxy Tab S8+ hardware baseline

Measured on 2026-08-07 against upstream SideScreen `a651a81b7d6468c7a564c038551872d3346a2d55` (release 0.11.1 source), the locally built 0.11.1 development client and the previously installed Android client 0.9.1.

This file records observed behavior, not vendor promises. It is the baseline for the Pen V1 and high-refresh work.

## Test setup

- Mac: Apple M4, macOS 26, Xcode 26.6 (17F113)
- Tablet: Samsung Galaxy Tab S8+ Wi-Fi, `SM-X800`, Snapdragon 8 Gen 1
- Tablet OS: Android 16 / API 36
- Connection: USB-C with ADB reverse, `tcp:54321`
- Host profile: 1920x1200, HiDPI off, 120 Hz, touch enabled, ultra-low preset, 1 Mbps
- Capture: ScreenCaptureKit (`SCStream`)
- Video: HEVC hardware encode/decode

## Reproducible environment

- Android Studio 2026.1.3.7
- Android Platform Tools 37.0.1
- Android platform 34
- Android build-tools 34.0.0
- Gradle wrapper 8.6
- JDK 17.0.20 from Homebrew

Android Studio's bundled JBR reports Java 25.0.2. The repository's current Gradle/Kotlin stack fails during settings evaluation on that runtime. Use JDK 17 for builds.

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
cd AndroidClient
./gradlew --no-daemon testDebugUnitTest assembleDebug
```

Verified baseline results:

- macOS: 35 tests passed, 0 failed; universal app and DMG built successfully
- Android: 12 tests passed, 0 failed; debug APK built successfully

Verified SideScreen Flow MVP results after Pen V1 implementation:

- macOS: 41 tests passed, 0 failed; universal app and DMG built successfully;
- Android: unit tests and debug APK build passed with JDK 17;
- Pen V1 capability negotiation was acknowledged by the host;
- Excalidraw rendered visibly pressure-dependent S Pen strokes;
- observed normalized pressure during the compatibility run ranged from about 0.046 to 0.988;
- hover/proximity, contact transitions and the primary S Pen button (`buttons=32`) reached the host;
- moving-content host telemetry typically reached about 99-111 fps with 0 dropped frames in sampled windows and about 6-8 ms average frame age.
- the accepted Retina profile uses a `1400x876` logical desktop with a native `2800x1752` HEVC stream at 120 Hz;
- the browser Pen Probe observed changing `tiltX` and `tiltY`, while Chromium classified the synthetic pointer as `mouse`;
- directional checks found and corrected both the initial 90-degree conversion error and a remaining CoreGraphics X-axis sign inversion; Android stylus orientation is measured clockwise from screen-up (`0=up`, `-pi/2=left`, `pi/2=right`), while injected macOS X tilt needs the opposite sign;
- `AXIS_ORIENTATION` is stylus azimuth, not barrel rotation, so it is no longer forwarded as a false `twist` value;
- direct finger input, two-finger pinch and pressure-sensitive Excalidraw strokes passed interactive testing;
- sampled finger contacts were commonly about 4-17 touch-major units, while broad palm-like contacts reached about 24-30, leaving a possible device-specific rejection threshold near 22 for later calibration.

## Display and stream evidence

The Mac created a real extended display reported by macOS as:

- name: `SideScreen`
- resolution: 1920x1200
- refresh rate: 120.00 Hz
- mirroring: off

Android reported the built-in panel in physical mode 120.00001 Hz with active render frame rate 120.00001 Hz. The panel exposes two real modes: 120 Hz and 60 Hz; it does not report adaptive-refresh support.

The Qualcomm HEVC capability query reported three hardware decoders supporting 1920x1200 at 120 fps, including `c2.qti.hevc.decoder.low_latency`. The running client selected `c2.qti.hevc.decoder`.

Observed decoder telemetry during moving content:

- initial stream rate: about 119 fps
- later samples: about 95-106 fps
- average decoder latency: about 6-7 ms per 60-sample window
- observed decoder latency maxima: about 9-27 ms
- dropped decoder buffers: 0 in the sampled windows

The old client/host run reported about 91 FPS in one moving sample. The local 0.11.1 development client then sustained about 108-111 received frames per second in a longer moving run, while the host UI reported 108.5 FPS. Most 60-frame decoder windows dropped no frames; occasional transitions dropped one or two frames and requested a new keyframe. Static content deliberately falls to near-zero FPS because the capture/encoder pipeline is content-driven. Therefore the 120 Hz mode is proven, but stable 120 fps delivery is not yet proven.

`dumpsys gfxinfo` marked many frames as janky. This metric includes Android view/UI work and is not a reliable video-surface frame-pacing measurement. Gate B needs timestamps from the SideScreen pipeline or SurfaceFlinger presentation data.

## S Pen evidence

The kernel exposes `sec_e-pen` as a touchscreen/stylus input device with:

- absolute X/Y
- pressure, raw range 0-4095
- distance/hover, raw range 0-255
- orientation
- tilt X/Y, raw range -63 to 63
- contact state and stylus button events

A live `getevent -lt` trace while drawing showed samples approximately every 2.0-2.2 ms (roughly 450-500 Hz), including hover distance, contact transitions, continuously changing pressure and tilt. This is comfortably above a 120 Hz display cadence.

Android `MotionEvent` can expose the normalized and semantic form of these values. The current SideScreen touch packet does not carry them to macOS, so the missing behavior is an application/protocol gap rather than a tablet hardware limitation.

The Samsung input dump did not report an active palm-rejection implementation for this application. Pen mode must therefore explicitly ignore or classify concurrent finger contacts instead of assuming the OS will always reject them.

## Installed-client caveat

The tablet contained SideScreen 0.9.1 signed by a different Android debug certificate than both the official 0.11.1 release asset and this machine's local debug build. Android correctly rejected an in-place update.

No existing application data was deleted. The fork's debug build now uses `com.sidescreen.app.dev` and is labeled `SideScreen Flow Dev`, so it can coexist with the old baseline client. Release builds retain the upstream identifier while the user-facing product name is SideScreen Flow.

## Remaining gates

1. Record controlled 60/90/120 Hz motion traces and end-to-end latency.
2. Finish interactive acceptance for Direct Touch, two-finger gestures and palm rejection.
3. Verify tilt and button behavior in an AppKit probe and generic browser Pointer Events.
4. Extend the compatibility matrix beyond the verified Excalidraw pressure path to FigJam/Figma and at least one native macOS drawing application.
