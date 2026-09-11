# Running RadarME on the Android emulator

Verified working on 2026-09-10: Windows 11, Flutter 3.47.2, Pixel 9 API 37.1
emulator, app running as `me.radarme.app`.

The README's "Getting it running" covers first-time scaffolding. **This file is
the day-to-day loop** and the exact toolchain versions this project needs.

---

## 0. Why the extra setup

Nothing is on `PATH` on this machine, and Flutter 3.47.2 enforces hard minimum
versions for the Android build. Both are handled below — read §1 once, then §2
is all you need day to day.

---

## 1. Shell setup (per terminal)

Nothing is on `PATH`, so export it each time you open a new terminal.

### PowerShell

```powershell
$env:PATH = "C:\Users\Edvin\flutter\bin;C:\Users\Edvin\AppData\Local\Android\Sdk\platform-tools;C:\Users\Edvin\AppData\Local\Android\Sdk\emulator;$env:PATH"
```

### Git Bash

```bash
export PATH="/c/Users/Edvin/flutter/bin:/c/Users/Edvin/AppData/Local/Android/Sdk/platform-tools:/c/Users/Edvin/AppData/Local/Android/Sdk/emulator:$PATH"
```

You do **not** need to set `JAVA_HOME`. `android/gradle.properties` pins the JDK
via `org.gradle.java.home`, which overrides it. See §6.

---

## 2. Run the app

### Start the emulator

Skip this if it is already running (Android Studio > Device Manager > play).

```powershell
emulator -avd Pixel_9
```

That command holds the terminal. To launch it detached in PowerShell:

```powershell
Start-Process emulator -ArgumentList "-avd","Pixel_9"
```

### Confirm the device is visible

```powershell
adb devices
```

Expected — wait for `device`, not `offline`:

```
List of devices attached
emulator-5554   device
```

### Launch

```powershell
cd C:\Users\Edvin\Desktop\RadarMe
flutter run -d emulator-5554
```

Keep this terminal attached to get the hot-reload keys:

| Key | Action |
|-----|--------|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Quit and stop the app on the device |
| `d` | Detach, leave the app running |

> Run `flutter run` in the **foreground**. Backgrounding it or piping its output
> to a file disables the hot-reload keys, and the run ends with
> `Lost connection to device` as soon as the app process is replaced.

---

## 3. Expected timings

| Build | Time |
|---|---|
| First build, or after `flutter clean` | **8-15 min** |
| Incremental rebuild | ~1-2 min |
| Hot reload (`r`) | < 1 s |

The first build is slow because Gradle resolves Firebase, geolocator,
background-service and notification plugins, and may auto-install missing SDK
components. Progress looks frozen at `Running Gradle task 'assembleDebug'...`
because that line is an in-place spinner — it is not hung. To confirm real
progress, watch a Gradle worker accumulate CPU:

```powershell
Get-Process java | Select-Object Id,CPU,@{n='RAM_MB';e={[math]::Round($_.WS/1MB)}}
```

---

## 4. Screenshots

```powershell
adb exec-out screencap -p > screen.png
```

> Use `exec-out` and redirect, **not** `adb shell screencap -p /sdcard/x.png`.
> Under Git Bash, MSYS rewrites the device path `/sdcard/...` into a Windows
> path, and `screencap` then just prints its usage text.

---

## 5. Useful commands

```powershell
flutter devices                  # list targets Flutter can see
flutter doctor                   # toolchain health
flutter clean                    # wipe build/ (forces a full rebuild)
flutter analyze                  # static analysis
flutter test                     # unit tests, no device needed
adb shell pidof me.radarme.app   # is the app alive?
adb logcat -s flutter            # app logs only
adb uninstall me.radarme.app     # remove from device
```

Validate the Gradle config **without** a full compile — this runs Flutter's
version checks in under a minute and is the fast way to test a version bump:

```powershell
cd android
.\gradlew.bat :app:help
```

Stop Gradle daemons (they idle at several hundred MB):

```powershell
cd android
.\gradlew.bat --stop
```

`--stop` only stops daemons matching the wrapper's current Gradle version.
Daemons from another version, or from Android Studio's own sync, survive it and
must be killed by PID.

---

## 6. Toolchain version floors

Flutter 3.47.2 **fails the build** below any of these. Enforced in
`C:\Users\Edvin\flutter\packages\flutter_tools\gradle\src\main\kotlin\DependencyVersionChecker.kt` —
check that file after a Flutter upgrade, since it reports only one violation at
a time.

| Component | Required | Set to | Where |
|---|---|---|---|
| Gradle | >= 8.14.0 | 8.14.3 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | >= 8.11.1 | 8.11.1 | `android/settings.gradle.kts` |
| Kotlin | >= 2.2.20 | 2.2.20 | `android/settings.gradle.kts` |
| JDK | >= 17 | 21 | `android/gradle.properties` |
| minSdk | >= 23 | 24 (Flutter default) | `android/app/build.gradle.kts` |

### The JDK trap

Android Studio bundles **JDK 25** (`Android Studio\jbr`). Gradle 8.14's
`JavaVersion` enum only knows up to Java 24, so building with the bundled JBR
fails with an error whose entire message is the bare version string:

```
* What went wrong:
25.0.3
```

That is a JDK-too-new error. `android/gradle.properties` therefore pins:

```properties
org.gradle.java.home=C:/Users/Edvin/Desktop/RadarMe/.tooling/jdk/jdk-21.0.12.1+1
```

**This line is an absolute path and is machine-specific.** It is correct only on
this machine. Before committing or moving to another machine, move it to your
user-level `%USERPROFILE%\.gradle\gradle.properties` instead.

A Microsoft JDK 17 also exists at `C:\Users\Edvin\jdk-17` and satisfies the
floor equally well — pointing `org.gradle.java.home` there lets you delete
`.tooling/` (~500 MB).

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `What went wrong: 25.0.3` | JDK too new for Gradle | Pin JDK 17/21 (§6) |
| `Gradle version ... lower than Flutter's minimum` | Old wrapper | Bump `distributionUrl` |
| `Android Gradle Plugin version ... lower than` | Old AGP | Bump in `settings.gradle.kts` |
| `No supported devices connected` | Emulator not booted | `adb devices`, wait for `device` |
| Device stuck `offline` | Still booting | Wait, or `adb kill-server; adb start-server` |
| Map renders blank grey | OSM tiles still fetching | Wait a few seconds; it is not an error |
| `Lost connection to device` | App process replaced | Expected if detached; rerun `flutter run` |
| `screencap` prints usage text | Git Bash path rewriting | Use `adb exec-out` (§4) |
| Build wedged after a version change | Stale daemon | `.\gradlew.bat --stop`, then rerun |

### Firebase

There is no `google-services.json` in the repo. `android/app/build.gradle.kts`
applies the Google Services plugin **only if that file exists**, so the app
builds fine without it and reads the bundled `assets/data/radars.json`. Add
Firebase config via `flutterfire configure` when you need the live backend.

---

## 8. Not yet verified

Confirmed working: build, install, launch, map screen, radar detail screen with
OSM tiles.

Not exercised on the emulator — proximity alarm (tone/vibration/notification),
background tracking, and the Firestore path. Emulators do not move, so testing
the alarm needs mock locations:

```powershell
adb emu geo fix 19.325939 43.343472
```

The emulator's default location is Mountain View, CA, which is why the nearest
radar shows as ~10238 km away on a fresh boot.
