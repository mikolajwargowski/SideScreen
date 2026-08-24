# SideScreen Pen / Direct Touch — discovery techniczne i plan realizacji

> Data discovery: 2026-08-07
> Baza: `tranvuongquocdat/SideScreen`, commit `a651a81b7d6468c7a564c038551872d3346a2d55`
> Docelowy sprzęt: Mac mini M4 + Samsung Galaxy Tab S8+
> Status rekomendacji: **MVP technicznie potwierdzone** — 2026-08-07 SideScreen Flow przesłał pełny nacisk S Pena do Excalidraw, a realny panel i wirtualny display pracowały w trybie 120 Hz. Do zamknięcia pozostają testy akceptacyjne Direct Touch/palm rejection, szersza macierz aplikacji oraz stabilność frame pacing przy 120 fps.

> Uwaga aktualizacyjna: tabela środowiska poniżej opisuje stan na początku discovery. Xcode 26.6, JDK 17, Android SDK 34, ADB i Galaxy Tab S8+ zostały następnie przygotowane i zweryfikowane. Aktualne pomiary oraz wyniki buildów znajdują się w `HARDWARE_BASELINE_GALAXY_TAB_S8_PLUS.md`, a stan implementacji w `PEN_DIRECT_TOUCH_ROADMAP.md`.

## 1. Cel produktu

Tablet ma działać jako:

1. prawdziwy rozszerzony ekran macOS;
2. ekran HiDPI o wysokim odświeżaniu;
3. powierzchnia z bezwzględnym sterowaniem palcem;
4. powierzchnia z pełnym S Penem: hover, pressure, tilt, orientation, przycisk, eraser i palm rejection.

Główne zastosowania to FigJam, Figma, tldraw, Obsidian + Excalidraw i podobne canvasy. Priorytetem nie jest ilustracja artystyczna, tylko precyzyjne sterowanie, diagramy, szkice procesów i projektowanie UI.

Nie próbujemy robić z macOS natywnego systemu dotykowego. Palec będzie mapowany na dobrze zaprojektowane zdarzenia myszy/scroll/zoom. Pen ma korzystać z tabletowych pól CoreGraphics/AppKit.

## 2. Co zostało zweryfikowane

### Repo i licencja

- Oficjalny upstream został sklonowany lokalnie do `SideScreen/`.
- Baza to aktywny branch `main`, licencja MIT.
- Host macOS jest napisany w Swift/Swift Package Manager.
- Klient Android jest napisany w Kotlinie, `minSdk 26`, `targetSdk 34`, Gradle 8.4, Kotlin 1.9.22.
- Pipeline obrazu już istnieje: prywatny `CGVirtualDisplay` → ScreenCaptureKit → VideoToolbox → TCP/ADB reverse → MediaCodec → Surface.
- USB i Wi-Fi używają wspólnego protokołu strumieniowego.

### Stan lokalnego środowiska

| Element | Stan | Wniosek |
|---|---|---|
| Mac | Mac mini M4, 16 GB, macOS 26.5.2 | odpowiedni |
| Repo | sklonowane, czysty `main` | gotowe do discovery |
| `swift build` hosta | **PASS** | host kompiluje się z obecnym CLI toolchainem poza sandboxem |
| `swift test` | **BLOCKED**: brak modułu `XCTest` | potrzebny pełny Xcode / zgodny toolchain testowy |
| Xcode | brak pełnego Xcode; aktywne Command Line Tools | build działa, testy i wygodny profiling nie są gotowe |
| Java | brak runtime | Android nie zbuduje się lokalnie |
| Android Studio / SDK 34 | brak | Android nie zbuduje się lokalnie |
| ADB | brak | nie da się zainstalować APK ani uruchomić USB reverse |
| Galaxy Tab S8+ | niepodłączony w czasie discovery | brak baseline'u sprzętowego |

### Aktualny input

Androidowy `MainActivity.handleTouch()` redukuje wejście do:

- znormalizowanego `x/y`;
- maksymalnie dwóch pointerów;
- `down/move/up`;
- predykcji pozycji o 12 ms dla jednego pointera.

`StreamClient.sendTouch()` wysyła pakiet typu `2`. Host parsuje go w `StreamingServer`, a `AppDelegate` mapuje go na mysz, scroll, pinch i long-press drag.

Nie są przesyłane: tool type, pointer ID, pressure, orientation, tilt, distance, button state, eraser, timestamps ani próbki historyczne.

### Aktualny pipeline 120 Hz

Upstream ma już wszystkie podstawowe elementy:

- wirtualny display przyjmuje `refreshRate` do 120 Hz;
- ScreenCaptureKit ustawia `minimumFrameInterval = 1/fps`;
- VideoToolbox ustawia `ExpectedFrameRate`, brak B-frames i `MaxFrameDelayCount = 0`;
- Android ustawia `KEY_LOW_LATENCY`, `KEY_PRIORITY` i `KEY_OPERATING_RATE`;
- klient mierzy odebrane FPS oraz timing renderowanych klatek;
- decoder sprawdza `areSizeAndRateSupported()`.

Braki:

- Surface nie wywołuje `setFrameRate()`;
- `display.refreshRate` jest odczytywane jednorazowo, bez obserwowania zmiany trybu;
- UI nie rozróżnia FPS: capture, encode, wire, decode, render i faktycznego trybu panelu;
- statyczny ekran nie jest dobrym testem FPS, bo ScreenCaptureKit może nie dostarczać nowych klatek;
- nie ma powtarzalnego test patternu do pomiaru 120 Hz;
- nie ma pomiaru input-to-photon.

## 3. Ważne odkrycia z upstreamu

Istnieją dwa otwarte PR-y, których nie należy ignorować:

- [PR #33 — pressure, tilt i hover](https://github.com/tranvuongquocdat/SideScreen/pull/33) — prototyp jest konfliktowy względem obecnego `main` i nie ma pełnych CI checks.
- [PR #51 — Pen / Draw Mode](https://github.com/tranvuongquocdat/SideScreen/pull/51) — dobry prototyp bezpośredniego drag oraz zabezpieczenia przed „stuck mouse button”; nie przesyła danych stylusa.

### Co warto przejąć z PR #51

- osobny tryb direct draw;
- natychmiastowe `mouseDown → dragged → mouseUp`;
- zwalnianie przycisku przy disconnect, stop serwera, wyłączeniu touch i wejściu drugiego pointera;
- zachowanie dwupalcowego scroll/pinch;
- logikę double-click w direct mode.

### Dlaczego PR #33 nie powinien zostać włączony wprost

1. Rozszerza istniejący pakiet typu `2` bez negocjacji wersji. Stary host oczekuje 14/22 bajtów, a nowy klient wysyła 26–50 bajtów, więc strumień wejściowy może się rozjechać.
2. Przesyła tylko jeden skalar `tilt`, bez orientation. Nie da się z niego poprawnie wyznaczyć `tiltX/tiltY`.
3. Ustawia tylko `tabletEventPointPressure`.
4. Nie przenosi buttons, eraser, distance, timestamps, sequence ani historycznych próbek.
5. Palm rejection opiera się w dużej części na heurystykach rozmiaru kontaktu zamiast najpierw respektować `ACTION_CANCEL` i `FLAG_CANCELED`.
6. Łączy pełny pen z rozbudową gestów 3/4-finger, zwiększając zakres i ryzyko jednego PR-a.

### Wynik lokalnego probe CoreGraphics/AppKit

Izolowany test potwierdził, że subtype tablet point, tilt i button mask przechodzą z `CGEvent` do `NSEvent`.

Wykrył też ważną pułapkę:

- dla `.mouseMoved` i `.leftMouseUp` `NSEvent.pressure` odczytuje ustawione `tabletEventPointPressure`;
- dla `.leftMouseDown` i `.leftMouseDragged` domyślne `mouseEventPressure` wynosi `1.0`, więc samo ustawienie `tabletEventPointPressure = 0.625` daje w AppKit **pressure = 1.0**;
- po ustawieniu także `mouseEventPressure = 0.625`, AppKit odczytuje około `0.624`.

Wniosek: injector V1 musi dla down/drag ustawiać **oba** pola pressure. PR #33 najpewniej dawałby binarny/pełny nacisk podczas kreski w aplikacjach czytających `NSEvent.pressure`, w tym w ścieżce używanej przez Chromium.

Probe nie dowodzi jeszcze, że event po `CGEvent.post()` będzie zaakceptowany przez każdą aplikację. To pozostaje Gate A.

## 4. Docelowa architektura

```text
Android MotionEvent
  ├─ FingerInputRouter ───────────────┐
  └─ StylusCollector                 │
       ├─ current sample             │
       ├─ historical samples         │
       ├─ hover / proximity          │
       ├─ pressure / tilt / orient.  │
       ├─ buttons / eraser           │
       └─ cancel / palm              │
                    ↓                │
           InputProtocol V1          │ legacy touch type 2
                    ↓ TCP / ADB      │
             StreamingServer         │
                    ↓                │
         PenEventStateMachine        │
                    ↓                ↓
           PenEventInjector     TouchGestureRouter
                    ↓                ↓
             CGEvent tablet      mouse/scroll/zoom
                    ↓
       AppKit / Chromium / aplikacja
```

Zasady:

- pipeline obrazu zostaje bez dużego refactoru;
- istniejący touch type `2` pozostaje kompatybilny;
- pen dostaje osobny, wersjonowany protokół;
- finger mode i pen mode są niezależne;
- raw pen samples nie używają obecnej predykcji 12 ms;
- każda utrata połączenia kończy aktywny stroke i zwalnia buttons.

## 5. Protokół Pen V1

### Negocjacja

Nowe typy wiadomości należy dobrać po sprawdzeniu aktualnej tabeli; na obecnym `main` zajęte są `0,1,2,4,5,6,7,8,9,10,11`.

Proponowany handshake:

1. nowy klient wysyła jedną payload-free wiadomość `CLIENT_CAPABILITIES_V1`;
2. stary host konsumuje nieznany jeden bajt i nie traci synchronizacji;
3. nowy host odpowiada `SERVER_CAPABILITIES_V1` tylko klientowi, który się zgłosił;
4. klient wysyła pakiety pena dopiero po potwierdzeniu;
5. stary klient nigdy nie dostaje nieznanego typu serwerowego.

Nie należy kopiować hacku z payload bytes z ustawionym high bit jako trwałego formatu pena. Po handshake używamy normalnego length-prefixed message.

### Rama

```text
messageType      UInt8
protocolVersion  UInt8
flags            UInt16 LE
payloadLength    UInt16 LE
sequence         UInt32 LE
sampleCount      UInt8
samples[]        PenSample
```

`payloadLength` pozwala pominąć pola dodane w kolejnej wersji i ograniczyć szkody po błędzie parsera. Parser musi mieć limit maksymalnego pakietu i maksymalnej liczby próbek.

### PenSample

```text
timestampDeltaUs UInt32
pointerId        UInt16
phase            UInt8   // proximityEnter, hover, down, move, up, cancel, proximityExit
tool             UInt8   // stylus, eraser
sampleFlags      UInt16
buttons          UInt32
x                Float32 // normalized 0...1
y                Float32
pressure         Float32 // normalized/clamped 0...1
tiltRadians      Float32 // Android raw
orientationRad   Float32 // Android raw
distance         Float32 // optional diagnostic/use later
```

Uwagi:

- wysyłamy raw `tilt + orientation`; `tiltX/tiltY` obliczamy i kalibrujemy po stronie hosta;
- historyczne próbki są porządkowane od najstarszej do najnowszej;
- batch ma twardy limit, np. 32 próbki;
- `timestampDeltaUs` służy do kolejności i diagnostyki, nie do porównania zegarów Android/macOS;
- malformed length, NaN, Infinity, wartości poza zakresem i regresja sequence muszą być obsłużone bez crasha;
- protocol codec powinien być czystym modułem z golden vectors współdzielonymi przez testy Kotlin/Swift.

## 6. Model wejścia i state machine

### Finger profiles

`Legacy Touch`:

- zachowuje dzisiejsze zachowanie SideScreen;
- 1 finger move = scroll;
- long press = drag;
- 2 fingers = scroll/pinch.

`Direct Touch`:

- 1 finger down/move/up = left mouse down/drag/up w pozycji absolutnej;
- 2 fingers = scroll/pan/pinch;
- cancel/disconnect/mode change = bezwarunkowe zwolnienie przycisku.

### Pen

- hover = pointer move bez button down;
- tip down = tablet/mouse down;
- move = tablet/mouse dragged;
- up/cancel/proximity exit/disconnect = up + reset state;
- eraser = osobny tool lub konfigurowalny fallback;
- S Pen button = mapowanie konfigurowalne, początkowo right-click lub modifier;
- finger jest blokowany zgodnie z profilem palm rejection, kiedy pen jest w proximity.

### Palm rejection

Kolejność źródeł prawdy:

1. `ACTION_CANCEL`;
2. `FLAG_CANCELED` na Androidzie 13+;
3. tool type i aktywne proximity pena;
4. dopiero na końcu heurystyki `touchMajor/toolMajor/size`.

Profile:

- `Strict`: pen w proximity blokuje wszystkie finger events;
- `Balanced`: pen w proximity blokuje pojedynczy finger/palm, ale jawny dwupalcowy gesture może być dopuszczony;
- `Off`: bez dodatkowego filtrowania.

Domyślnie `Balanced`, ale pierwsze testy powinny używać `Strict`, bo jest deterministyczny.

## 7. macOS PenEventInjector

### V1: CoreGraphics/AppKit

Każdy event pena powinien ustawiać co najmniej:

- `mouseEventSubtype = tabletPoint`;
- `tabletEventPointPressure`;
- `mouseEventPressure` dla down/drag;
- `tabletEventTiltX/Y`;
- `tabletEventPointButtons`;
- spójny mouse type: moved/down/dragged/up;
- click state tam, gdzie wymaga tego aplikacja;
- event location po poprawnym mapowaniu display/rotation/flip.

Pressure trzeba clampować i kalibrować. Tilt wymaga testu znaków i osi dla landscape/portrait oraz flip H/V. Chromium mnoży AppKit tilt z zakresu `-1...1` przez 90 stopni, więc nie wolno wstawiać tam surowych radianów tak jak w PR #33.

### Proximity

Nie zakładamy, że samo `.mouseMoved + tabletPoint` odtworzy wszystkie zachowania hover. Osobny spike ma porównać:

- tabletPoint mouseMoved;
- tabletProximity subtype / proximity sequence;
- zachowanie kursora i web `pointerenter/pointerleave`;
- wymagane device/unique ID fields.

### V2 fallback: virtual HID

Virtual HID nie wchodzi do MVP. Rozważamy go tylko, gdy ważne aplikacje ignorują syntetyczny CGEvent albo wymagają realnego urządzenia digitizer.

Koszt fallbacku:

- HID report descriptor dla digitizera;
- CoreHID `HIDVirtualDevice` albo HIDDriverKit;
- entitlement Apple i signing/provisioning;
- większy koszt dystrybucji, testów i utrzymania.

## 8. Plan realizacji i gates

### Faza 0 — kompletne środowisko i baseline

1. Zainstalować pełny Xcode zgodny z macOS 26 i wskazać go przez `xcode-select`.
2. Zainstalować Android Studio z JBR/JDK 17 i Android SDK 34.
3. Zainstalować Android Platform Tools (`adb`).
4. Podłączyć S8+, włączyć Developer Options i USB debugging, zaakceptować klucz RSA.
5. Uruchomić:
   - `swift build`;
   - `swift test`;
   - `./gradlew assembleDebug`;
   - testy Android;
   - lint Swift/Kotlin zgodny z CI.
6. Zbudować i zainstalować niezmieniony upstream.
7. Nadać macOS Screen Recording i Accessibility.
8. Zweryfikować `adb reverse tcp:8888 tcp:8888`.
9. Zebrać baseline dla 60/90/120 oraz 3 presetów rozdzielczości.

**Gate 0:** oba buildy i testy przechodzą, upstream działa przez USB, touch działa, logi i exact device mode są zapisane.

### Faza 1 — dwa eksperymenty rozstrzygające

#### Gate A: kompatybilność event injection

Zbudować mały macOS `PenEventProbe` niezależny od sieci i Androida:

- suwaki/generator pressure i tilt;
- postowanie moved/down/drag/up;
- event monitor pokazujący wartości po przejściu do AppKit;
- test `mouseEventPressure` vs `tabletEventPointPressure`;
- test proximity i buttons;
- bezpieczny watchdog zwalniający button.

Sprawdzić:

- natywny AppKit test canvas;
- Chrome + lokalna strona Pointer Events;
- tldraw;
- Figma/FigJam;
- Obsidian + Excalidraw;
- opcjonalnie Krita jako aplikację referencyjną dla pressure/tilt.

**Gate A PASS:** co najmniej AppKit, Chrome/tldraw i jeden główny workflow widzą ciągłe pressure oraz poprawny hover; nie ma stuck button.

**Gate A FAIL:** jeśli wartości giną albo aplikacje odrzucają CGEvent, robimy time-boxed spike CoreHID. Nie zaczynamy pełnej implementacji na fałszywym założeniu.

#### Gate B: 120 Hz baseline

Na niezmienionym upstreamie i S8+ uruchomić dynamiczny test pattern:

- `1400×876 HiDPI → 2800×1752 physical @120`;
- `1280×800 HiDPI → 2560×1600 physical @120`;
- `1400×876 HiDPI @90`;
- referencyjnie 60 Hz.

Zebrać przez minimum 5 minut na profil:

- aktywny `Display.Mode` i refresh rate;
- capture FPS;
- encoded/sent/received/decoded/rendered FPS;
- frame-time median/P95/P99 i jitter;
- decoder latency median/P95/P99;
- dropped frames i queue depth;
- CPU/GPU/thermal state;
- bitrate;
- RTT osobno od input-to-photon.

**Gate B PASS dla 120:** panel pozostaje w 120 Hz, rendered FPS ≥115 w ruchu, P95 frame time ≤12 ms, brak narastającej kolejki i brak thermal collapse przez 5 minut.

Jeśli native physical nie przejdzie, wybieramy 2560×1600@120 lub 2800×1752@90. Stabilność i latency mają pierwszeństwo przed dokładnym native pixel mapping.

### Faza 2 — protocol foundation

1. Spisać `InputProtocol.md` z tabelą typów i byte order.
2. Dodać handshake capabilities.
3. Dodać Swift/Kotlin codec bez podpinania do UI.
4. Dodać golden vectors, truncated packet, bad length, NaN, unknown version i coalesced TCP reads.
5. Fuzzować parser hosta w granicach pakietu.

**Gate 2:** nowy↔nowy, nowy klient↔stary host i stary klient↔nowy host nie rozjeżdżają strumienia.

### Faza 3 — Android StylusCollector

1. Rozdzielić finger i stylus przed predykcją.
2. Obsłużyć stylus/eraser, hover enter/move/exit, pressure, tilt, orientation, distance i buttons.
3. Batchować `MotionEvent` history.
4. Zero/mało alokacji na hot path; używać bufora wielokrotnego użytku.
5. Dodać raw diagnostic overlay/log eksportowalny do pliku.
6. Dodać Androidowe testy transformacji współrzędnych i flag cancel.

**Gate 3:** log z S8+ pokazuje ciągłe pressure, obie składowe tilt po konwersji, hover, button transitions i uporządkowane timestamps.

### Faza 4 — macOS injector i Direct Touch

1. Dodać `PenEventStateMachine` i `PenEventInjector` jako osobne typy.
2. Podpiąć V1 z wyniku Gate A.
3. Dodać cleanup wszystkich aktywnych buttons przy każdym teardown.
4. Przenieść sprawdzone elementy PR #51 do osobnego, małego commit/PR.
5. Zachować Legacy Touch jako default; Direct Touch jako opt-in.
6. Nie dodawać gestów 3/4-finger w tym etapie.

**Gate 4:** macOS nie zostaje ze stuck input po cable pull, kill klienta, cancel, mode switch ani drugim pointerze.

### Faza 5 — 120 Hz hardening i telemetria

1. Na API 31+ wywołać `Surface.setFrameRate(120, compatibility, strategy)`; na API 30 użyć dostępnego wariantu; na starszych bezpieczny no-op.
2. Obserwować `DisplayManager` i aktywny `Display.Mode`.
3. Nie pokazywać „120 Hz” tylko dlatego, że ustawienie zostało wybrane.
4. Rozdzielić wskaźniki capture/stream/decode/render/display.
5. Dodać preset `2800×1752 HiDPI 120` jako logiczne `1400×876`, ale bez hardkodowania modelu Samsung.
6. Dodać automatyczną rekomendację fallbacku, nie automatyczne przełączenie bez komunikatu.

### Faza 6 — UX pena i compatibility matrix

1. Local Pen Cursor na Androidzie jako overlay; nie modyfikuje wysyłanych raw samples.
2. Profile palm rejection.
3. Konfigurowalny S Pen button.
4. Kalibracja orientation/tilt dla 0/90/180/270 i H/V flip.
5. Test matrix aplikacji z jednoznacznym wynikiem każdej funkcji.
6. Profil długiego testu: 30 minut rysowania/drag + reconnect + sleep/wake.

### Faza 7 — packaging i upstream

1. Podzielić pracę na małe PR-y: protocol, Android collector, mac injector, direct touch, 120 Hz diagnostics, UX.
2. Nie mieszać nowych gestów systemowych z pen protocol.
3. Zachować MIT attribution.
4. Ustalić z maintainerem, czy rozwijamy fork prywatny, czy upstream-first.
5. Dopiero po działającym prywatnym buildzie rozważyć signing/notarization.

## 9. Kryteria akceptacji MVP

### Obraz

- extended display działa przez USB;
- wybrany stabilny profil osiąga uzgodnione FPS bez narastającej latencji;
- UI pokazuje faktyczny tryb panelu i rendered FPS;
- reconnect i sleep/wake nie wymagają restartu całego stanowiska.

### Pen

- pozycja jest absolutna i zgodna z rotacją/flip;
- hover porusza wskaźnikiem bez rysowania;
- pressure w test harnessie i Chrome jest ciągłe, nie tylko 0/1;
- tilt X/Y zmienia się poprawnie w czterech orientacjach;
- side button ma stabilne down/up i nie zostaje wciśnięty;
- `ACTION_CANCEL`, proximity exit, disconnect i kill kończą stroke;
- historyczne próbki nie zmieniają kolejności;
- nie ma predykcji w danych pena.

### Touch

- Legacy Touch nie ma regresji;
- Direct Touch pozwala tap, double tap, drag;
- 2-finger scroll/pinch nadal działa;
- palm rejection nie blokuje pena i nie generuje przypadkowych kliknięć.

### Kompatybilność aplikacji

Minimalny zestaw MVP:

- tldraw w Chrome;
- Figma lub FigJam;
- Obsidian + Excalidraw;
- macOS UI do ogólnego sterowania.

Pressure/tilt może być oznaczone jako „best effort per app”, ale hover, dokładna pozycja i direct drag muszą być niezawodne w zestawie MVP.

## 10. Największe luki i ryzyka

| Ryzyko | Wpływ | Jak zamykamy |
|---|---:|---|
| Aplikacja ignoruje syntetyczny tablet CGEvent | bardzo duży | Gate A przed pełną implementacją |
| Pressure down/drag staje się 1.0 | duży | ustawienie obu pól pressure; test AppKit/Chrome |
| Private `CGVirtualDisplay` łamie się po update macOS | duży | pin kompatybilnych wersji, test po update, zaakceptowany prywatny fork |
| S8+ nie dekoduje 2800×1752@120 stabilnie | duży | Gate B i fallback 2560×1600@120 / native@90 |
| Brak zgodności protokołu | duży | capability handshake + osobny typ + golden vectors |
| Stuck mouse/pen button | duży | central state machine + cleanup na wszystkich teardown paths |
| Tilt ma złe osie/znaki po rotacji | średni | raw tilt+orientation + macierz testów orientacji |
| Palm heurystyki dają false positives | średni | cancel flags i proximity jako źródła nadrzędne |
| Scope rozrośnie się o gesty 3/4-finger | średni | poza MVP |
| Brak notarization/signing | mały dla prywatnego użytku | rozwiązać dopiero po działającym MVP |

## 11. Rekomendowana kolejność decyzji

1. Uzupełnić środowisko i uruchomić upstream na S8+.
2. Wykonać Gate A i Gate B.
3. Jeśli oba przejdą: budować V1 na CoreGraphics z osobnym protokołem.
4. Jeśli Gate A nie przejdzie: oszacować CoreHID/entitlement przed dalszą pracą.
5. Jeśli Gate B nie przejdzie tylko dla native@120: kontynuować na stabilnym profilu 90/120; nie jest to blocker pena.
6. Dopiero po MVP dodać local cursor, rozbudowane profile i packaging.

## 12. Źródła pierwotne

- [SideScreen upstream](https://github.com/tranvuongquocdat/SideScreen)
- [Android: advanced stylus features](https://developer.android.com/develop/ui/views/touch-and-input/stylus-input/advanced-stylus-features)
- [Android MotionEvent](https://developer.android.com/reference/android/view/MotionEvent)
- [Android Surface.setFrameRate](https://developer.android.com/reference/android/view/Surface#setFrameRate(float,%20int,%20int))
- [Apple CGEvent tablet pressure](https://developer.apple.com/documentation/coregraphics/cgeventfield/tableteventpointpressure)
- [Apple NSEvent tablet point](https://developer.apple.com/documentation/appkit/nsevent/eventtype/tabletpoint)
- [Apple NSEvent tilt](https://developer.apple.com/documentation/appkit/nsevent/tilt)
- [Apple CoreHID HIDVirtualDevice](https://developer.apple.com/documentation/corehid/hidvirtualdevice)
- [Chromium macOS Pointer Event conversion](https://chromium.googlesource.com/chromium/src/+/refs/tags/137.0.7118.0/components/input/web_input_event_builders_mac.mm)
- [OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver)
