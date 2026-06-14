# DecibelPro Performance Notes

## Profiling summary (v1.2)

### Cold-start milestones

`LaunchPerformance` records one-shot milestones (console `[Launch]`, Firebase `launch_milestone`, Instruments `Launch` signposts):

| Step | Trigger |
|------|---------|
| `launchAppInit` | `NoiseRecordApp.init` after `FirebaseApp.configure()` |
| `launchFirebaseConfigure` | Immediately after Firebase configure in `App.init` |
| `launchDelegateEntry` | `UIApplicationDelegate.didFinishLaunching` entry |
| `launchWindowAppear` | `WindowGroup` root `onAppear` |
| `launchSwiftDataInit` | `ModelContainer` created in `App.init` |
| `launchContentViewAppear` | `ContentView.onAppear` |
| `launchFirstInteractive` | `DashboardView.onAppear` (T8 stopwatch) |
| `launchAdMobStartRequested` | `MobileAds.shared.start` (deferred until after first interactive) |
| `launchAdMobStartCompleted` | AdMob start callback |

**Pre-optimization baseline (device Debug, cold launch × 1):**

| Segment | Duration | Notes |
|---------|----------|-------|
| App init → Firebase configure | 13,450 ms | Delegate not yet run; correlated with Networking subprocess ~13.5 s |
| Firebase configure → SwiftData | 109 ms | Healthy |
| SwiftData → ContentView appear | 18,636 ms | TabView built all 5 tabs + AdMob contention |
| ContentView → first interactive | 103 ms | Dashboard itself is light |
| **Total → first interactive** | **32,298 ms** | Far above T8 target |

**v1.2 optimizations applied:**

1. Firebase configure moved to earliest `App.init` (eliminates `I-COR000003`).
2. `ModelContainer` created eagerly in `App.init` (removed `ProgressView` gate).
3. AdMob `start` + `loadAd` deferred until `launchFirstInteractive`.
4. Cold-start ad `showAdIfAvailable` deferred until `launchFirstInteractive`.
5. Tab lazy mount (`mountedTabs`) — only Monitor tab on cold start.
6. Files badge uses `fetchCount` instead of dual `@Query`.

**T8 measurement protocol (Release, real device):**

1. Product → Scheme → Edit Scheme → Run → Build Configuration: **Release**.
2. Delete app, reboot device (or wait 30 s), cold launch × 3.
3. Filter Xcode console for `[Launch]`; record `launchFirstInteractive` `elapsed_ms` (exclude ad fullscreen time).
4. Pass: mean **< 2000 ms**.
5. Optional: Instruments → App Launch + Points of Interest (`com.goodcraft.NoiseRecord` / `Performance`).

Record Release means here after on-device verification:

| Run | `launchFirstInteractive` (ms) |
|-----|-------------------------------|
| 1 | _pending device test_ |
| 2 | _pending device test_ |
| 3 | _pending device test_ |
| Mean | _pending device test_ |

---

## Profiling summary (v1.1)

Primary bottlenecks identified on the monitoring hot path:

| Area | v1.0 | v1.1 |
|------|------|------|
| UI publish rate | ~50 Hz | 15 Hz + generation coalescing |
| Spectrum FFT | ~50 Hz + array churn | ~5 Hz + ring buffer |
| Waveform history | `append` + `removeFirst` on main actor | Ring buffer snapshot on audio queue |
| Spectrum UI | 128 `Rectangle` views / frame | Single `Canvas` + `drawingGroup` |
| Measurement persist | `onChange(currentDB)` ~50 Hz + prune every second | 5 s interval + prune every 60 s |
| Video overlay sync | Every UI tick | 4–10 Hz while previewing |
| Video Tab camera/GPS | Could stay active after leaving tab | `isTabActive` teardown |
| Settings sample count | Full `@Query` on every save | `fetchCount` on tab visit |
| TabBar monitor icon | ~30 fps + scene tree walk | ~15 fps + cached `UITabBarController` |
| SlidingAverage | O(n) `removeFirst` per tap | O(1) ring buffer |
| Calibration offset | `uname()` + UserDefaults per tap | Cached on engine |
| AI classification | Every audio buffer | Every 3rd buffer |
| Voice file flush | Every tap (~43 Hz) | Every 200 ms |
| Video watermark meta | Reformatted every frame | Cached 0.5 s |
| Prune overflow | Fetch 86,001 models | Fetch only overflow count |

## Tuning constants

Located in `NoiseMonitorEngine.Performance`:

- `uiInterval` = 1/15 s — dashboard dB / stats refresh
- `spectrumEveryNthUIFrame` = 3 — FFT roughly every 5 Hz

Other constants:

- `DashboardView.measurementPersistInterval` = 5 s
- `VoiceActivatedRecorder.flushInterval` = 0.2 s
- `VideoNoiseRecorder.metaRefreshInterval` = 0.5 s
- TabBar waveform animation = 66 ms (~15 fps)

## Instruments signposts

`PerformanceSignpost` (`com.goodcraft.NoiseRecord` / `Performance`) marks:

- `processBuffer`
- `publishUI`
- `processVideoSample`
- `drawWatermark`
- `tabBarIconApply`
- `persistMeasurement`
- `launchSwiftDataInit`

Filter these in Instruments → Points of Interest. Launch milestones appear under the `Launch` signpost name.

## Manual regression matrix (T1–T8)

| ID | Scenario | Pass criteria |
|----|----------|---------------|
| T1 | Monitor 10 min on Dashboard | CPU mean stable; no sustained main-thread frames > 16 ms |
| T2 | Rotate all 5 tabs every 30 s for 10 min | No redraw spikes on inactive tabs |
| T3 | Voice armed + monitoring 10 min | Tab icon animates at ~15 fps without blank icon |
| T4 | T3 + AI classification | CPU increase documented; UI still responsive |
| T5 | Record video 3 min with monitoring | CPU < 60%; preview smooth |
| T6 | Monitor 2 h, open Settings occasionally | Settings opens < 500 ms |
| T7 | Files with 50+ clips, scroll list | Smooth scrolling |
| T8 | Cold launch + return from background | Interactive < 2 s (excluding ad display) |

## Microbenchmarks

`NoiseRecordTests/PerformanceMicrobenchmarkTests.swift` — `SPLCalculator` throughput and `VideoNoiseTimeline` lookup.

`NoiseRecordTests/SlidingAverageTests.swift` — ring-buffer average correctness.

## Future work

- Downsample `RecordingListView` `@Query` when Files tab inactive (manual fetch).
- Pre-render TabBar waveform sprite sheet instead of per-frame `UIGraphicsImageRenderer`.
- Record T8 Release means in the table above after each release.
