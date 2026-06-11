# NoiseRecord Performance Notes

## Profiling summary (v1.0)

Primary bottlenecks identified on the monitoring hot path:

| Area | Before | After |
|------|--------|-------|
| UI publish rate | ~50 Hz (20 ms) | 15 Hz |
| Spectrum FFT | ~50 Hz + array churn | ~5 Hz + ring buffer |
| Waveform history | `append` + `removeFirst` on main actor | Ring buffer snapshot on audio queue |
| Spectrum UI | 128 `Rectangle` views / frame | Single `Canvas` + `drawingGroup` |
| Waveform UI | `Path` in `GeometryReader` | `Canvas` decimated to screen width |
| Measurement persist | `onChange(currentDB)` ~50 Hz + prune every second | 1 Hz timer + prune every 60 s |
| Video overlay sync | Every UI tick | 4–10 Hz while previewing |

## Tuning constants

Located in `NoiseMonitorEngine.Performance`:

- `uiInterval` = 1/15 s — dashboard dB / stats refresh
- `spectrumEveryNthUIFrame` = 3 — FFT roughly every 5 Hz

## Manual regression checks

1. Start monitoring on a real device for 5+ minutes — scroll dashboard, switch tabs; UI should stay responsive.
2. Enable voice + background monitoring — confirm recordings still trigger.
3. Record video evidence — watermark dB should update smoothly without stutter.
4. Files tab with 50+ clips — list scrolling should remain smooth (SwiftData query separate from monitor path).

## Future work

- Coalesce `@MainActor` UI tasks when audio queue runs ahead.
- Downsample `RecordingListView` `@Query` updates when not on Files tab.
- Instrument with Instruments (Time Profiler + SwiftUI) before major releases.
