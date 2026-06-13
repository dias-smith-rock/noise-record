# DecibelPro Performance Notes

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

Filter these in Instruments → Points of Interest.

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
- Instrument with Instruments (Time Profiler + SwiftUI + Energy) before each release and record T1–T8 numbers here.
