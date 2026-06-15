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

## In-App Purchase (Remove Ads)

Product ID: `com.decibelpro.removeads.lifetime` (Non-Consumable) · Bundle ID: `com.goodcraft.NoiseRecord`

### Local StoreKit testing (simulator / Xcode Run)

- [ ] `DecibelPro.storekit` visible in Xcode Project Navigator (if Scheme dropdown is empty, file is not registered in the project)
- [ ] Scheme **NoiseRecord** → Run → Options → StoreKit Configuration = `DecibelPro.storekit`
- [ ] Settings banner shows **Store price loaded from App Store** (green), not marketing fallback
- [ ] Purchase completes → success alert → banner disappears → `isAdsRemoved` true
- [ ] Cancel purchase → **Purchase Cancelled** alert (not silent)
- [ ] Restore Purchases works after reinstall / new simulator

### App Store Connect sandbox (optional, after ASC setup)

- [ ] IAP created under app `com.goodcraft.NoiseRecord`, type Non-Consumable, price $2.99, Cleared for Sale
- [ ] Paid Applications Agreement active in ASC
- [ ] Sandbox tester created; signed in on device/simulator (Settings → App Store → Sandbox Account)
- [ ] Clear sandbox purchase history before re-testing non-consumable (Settings → Developer → Sandbox Account → Manage)
- [ ] If purchase spins then stops: check Xcode console for `iap.purchase_user_cancelled` vs `iap.purchase_verified`

## Storage & Recovery

- [ ] Measurement samples pruned (no unbounded growth after long session)
- [ ] Reinstall app — existing media paths repaired when files remain in Documents (if applicable)

## Sign-off

| Tester | Device | iOS | Date | Pass |
|--------|--------|-----|------|------|
| | | | | |
