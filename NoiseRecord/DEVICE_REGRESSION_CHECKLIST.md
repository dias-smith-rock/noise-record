# Device Regression Checklist (Pre-Release)

Run on a **physical iPhone** before submitting to App Review.

## Install & Permissions

- [ ] Fresh install shows microphone permission dialog
- [ ] Deny microphone → alert offers **Open Settings**
- [ ] Allow microphone → monitoring starts successfully
- [ ] Video tab: deny camera → permission alert with Settings link
- [ ] Video tab: deny location → optional GPS alert; recording still works

## Monitoring

- [ ] Start / Stop monitoring from Monitor tab FAB
- [ ] Max / Min / Avg / Leq update while monitoring
- [ ] Waveform and spectrum render
- [ ] Export CSV succeeds; failure shows alert when no data
- [ ] Stop with active voice recordings → Keep / Discard / Continue dialog

## Background

- [ ] Enable background monitoring in Voice tab
- [ ] Start monitoring, send app to background 10+ minutes
- [ ] Voice-activated clip still created when threshold exceeded
- [ ] Return to foreground — UI recovers without crash

## Voice Recording

- [ ] Voice tab shows **Monitoring Required** banner when monitoring off
- [ ] **Start Monitoring** button from Voice tab works
- [ ] Threshold sliders enforce start > stop
- [ ] AI filter labels persist after app restart
- [ ] Recording status badge updates (standby / recording / tail)

## Video Evidence

- [ ] Camera preview loads; pinch zoom and double-tap 1x/2x work
- [ ] dB watermark updates live
- [ ] Record → Stop & Save → **Preview Recording** plays clip
- [ ] Saved clip appears in Files → Video tab
- [ ] Leave Video tab → monitoring pipeline restores if it was running

## Files

- [ ] Audio playback and stop
- [ ] Video fullscreen playback
- [ ] Share single item (audio and video)
- [ ] Multi-select → Share Selected
- [ ] Multi-select → Delete
- [ ] Rename failure shows alert
- [ ] SHA-256 badge visible when hash present
- [ ] Export Recording Log (CSV) from audio tab

## Settings

- [ ] Calibration with reference SPL 10–140 dB
- [ ] Version number displayed
- [ ] Privacy Policy and Terms of Service open in Safari; Support opens Mail to music.player.250617@gmail.com
- [ ] Clear Measurement History works

## Storage & Recovery

- [ ] Measurement samples pruned (no unbounded growth after long session)
- [ ] Reinstall app — existing media paths repaired when files remain in Documents (if applicable)

## Sign-off

| Tester | Device | iOS | Date | Pass |
|--------|--------|-----|------|------|
| | | | | |
