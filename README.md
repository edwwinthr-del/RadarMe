# RadarME

Flutter app (Android + iOS) that warns drivers when they approach a traffic
enforcement camera in Montenegro. It tracks GPS in real time and raises a
configurable alarm — tone, vibration and notification — inside a configurable
radius (300 m by default), in the foreground and in the background.

Data: **88 enforcement locations**, extracted from the SAT-TRAKT V8 technical
design document (`radarMe.pdf`) into `assets/data/radars.json`.

---

## Getting it running

The repository contains all source, configuration and assets. Three things are
machine-generated and are not checked in — the Gradle wrapper, the Xcode
project, and the Firebase config files.

### 1. Generate the platform tooling

```bash
flutter create --project-name=radarme --org=me.radarme --platforms=android,ios .
flutter pub get
```

`flutter create` fills in `android/gradle/**`, `ios/Runner.xcodeproj`,
`ios/Runner/Base.lproj/**` and similar scaffolding.

> **It may also overwrite `android/app/src/main/AndroidManifest.xml` and
> `ios/Runner/Info.plist`.** Both carry required configuration (see
> [Platform configuration](#platform-configuration)). Check them afterwards and
> restore them if the permissions or `UIBackgroundModes` entries are gone. If
> you would rather not risk it, run `flutter create` into an empty directory and
> copy only the missing generated folders across.

### 2. Firebase (optional to run, required for the remote dataset)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`. The app reads them natively — there is no
generated `firebase_options.dart` to import.

**The app runs fine without this.** `Firebase.initializeApp()` is wrapped in a
try/catch and `RadarProvider` falls back to the bundled `radars.json`; the
Android Gradle config only applies the Google Services plugin once
`google-services.json` actually exists.

### 3. Seed Firestore (once, after step 2)

```bash
flutter run -t tool/seed_firestore.dart
```

Writes all 88 documents into `radars/` plus `app_config/settings` in one batch.
Re-running it is idempotent.

### 4. Launcher icons

```bash
dart run flutter_launcher_icons
```

Android mipmaps and the adaptive icon are already committed; this regenerates
them and produces the iOS icon set.

### 5. Run

```bash
flutter run
```

Test on a real device — emulators have limited GPS. On the iOS simulator use
**Features → Location → Custom Location**.

---

## Architecture

```
lib/
├── main.dart                 Firebase init, provider graph, background service registration
├── app.dart                  MaterialApp, themes, routes
├── config/                   constants · theme · routes
├── models/                   radar (+ RadarType/RadarStatus/CameraUnit/SpeedZone) · user_settings
├── providers/                radar · location · proximity · settings · filter
├── services/                 location · alarm · firestore · background · proximity_engine
├── screens/                  splash · main_shell · home(map) · radar_list · radar_detail
│                             · speed_zone · settings
├── widgets/                  radar_marker · radar_bottom_sheet · alarm_banner · capability_chip
│                             · filter_bar · radar_list_tile · distance_indicator · speed_zone_card
└── utils/                    distance_calculator · capability_icons · formatters
```

State is Provider. `ProximityProvider` is a `ChangeNotifierProxyProvider3` over
radars, settings and location.

### The proximity alarm

`services/proximity_engine.dart` holds the algorithm, and **both** the UI
isolate and the background isolate run that same instance of it, so foreground
and background alarms cannot drift apart.

On each fix (every 10 m of movement):

1. **Bounding-box prefilter** — radars outside ±0.05° latitude / ±0.07°
   longitude (~5.5 km) are dropped with two subtractions, before any
   trigonometry. Nothing inside the 1 km maximum radius can be missed.
2. Distances are measured with `Geolocator.distanceBetween` and sorted.
3. **Release, then announce.** A radar already announced is forgotten only once
   it is beyond `radius + 100 m` — the hysteresis buffer. Without it a car
   waiting at a light on the radius boundary would re-trigger every time GPS
   noise nudged it across.
4. New entrants raise the alarm and the banner; the nearest radar of any type
   feeds the always-on distance readout.

### Foreground / background arbitration

With background tracking on, two isolates see the same GPS feed, so the naive
version announces every radar twice. The UI publishes its visibility to the
service and owns the alarms while it is on screen; the service stays quiet.

The handshake is **fail-safe**: visibility is a ping re-sent every 30 s and
expiring after 60 s, so if the UI dies without saying goodbye the service starts
alarming again on its own. It fails towards warning the driver, never towards
silence.

### Average-speed corridors

27 A↔B pairs. Coming within 500 m of a point A starts a session; ground distance
is accumulated from consecutive fixes, so the average keeps falling while the car
is stopped — which is how the enforcement system actually measures. Reaching
500 m of point B finalises it and alarms if over the limit, then suppresses that
corridor until the driver leaves its point A (short zones would otherwise restart
instantly). Sessions expire after an hour.

Limits are configurable, defaulting to 50 km/h in built-up sections and 80 km/h
elsewhere.

### Offline behaviour

`RadarProvider` tries Firestore with a 10 s timeout and falls back to the bundled
`assets/data/radars.json`. The background isolate *always* reads the bundled copy
— it must work with no network and without waiting on Firestore. The settings
screen reports which source is live.

---

## Platform configuration

### Android

`AndroidManifest.xml` declares `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`,
`POST_NOTIFICATIONS` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, plus `<queries>`
entries for the navigate and share actions.

It also re-declares the plugin's service with
`android:foregroundServiceType="location"` and `tools:replace` — Android 14
refuses to start an untyped foreground service that reads GPS.

`minSdk` is 21 as specified; core library desugaring is on for
`flutter_local_notifications`. The settings screen requests the battery
optimisation exemption when background tracking is switched on.

### iOS

`Info.plist` carries `NSLocationWhenInUseUsageDescription`,
`NSLocationAlwaysAndWhenInUseUsageDescription`,
`NSLocationAlwaysUsageDescription`, `UIBackgroundModes`
(`location`, `fetch`, `processing`, `audio`), the
`BGTaskSchedulerPermittedIdentifiers` entry the background service schedules
under, and `LSApplicationQueriesSchemes` for the maps apps.

`AppleSettings` sets `allowBackgroundLocationUpdates` and
`showBackgroundLocationIndicator`, so the blue status-bar indicator appears while
tracking. The `Podfile` enables the `PERMISSION_LOCATION` and
`PERMISSION_NOTIFICATIONS` compile flags that `permission_handler` requires.

Alarms are played through `audioplayers` with the audio session set to
`AVAudioSessionCategory.playback`, so they sound **even with the ringer switch
off**. The notification itself is silent, to avoid a doubled tone.

---

## Data

`assets/data/radars.json` — 88 records:

| | |
|---|---|
| Cities | 21 |
| Intersection enforcement | 5 |
| Road enforcement point | 29 |
| Average speed A / B | 27 / 27 |
| Active (`ZAVRŠENO`) / planned | 12 / 76 |
| Locations with camera hardware | 11 (33 units) |

Each record carries `id`, `name`, `city`, `type`, `status`, `lat`, `lng`,
`capabilities` (16 possible AI detection keys), `cameras` and `pairedWith`.

Extraction and validation are documented in [`progress.md`](progress.md).

---

## Notes on dependencies

- `flutter_map_tile_layer` from the original spec is not a real pub.dev package
  — `TileLayer` ships inside `flutter_map`, which is what is used.
- `url_launcher` and `share_plus` were added; the detail screen's "Navigiraj"
  and "Podijeli" actions need them.
