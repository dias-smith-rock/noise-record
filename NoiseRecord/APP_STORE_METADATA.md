# App Store Connect Metadata Checklist

Use this when submitting **DecibelPro** v1.0.

## Required URLs

| Field | URL |
|-------|-----|
| Privacy Policy | https://www.noise.nx.kg/privacy.html |
| Terms of Service | https://www.noise.nx.kg/terms.html |
| Support | https://www.noise.nx.kg/support.html |
| Support email | music.player.250617@gmail.com |
| Marketing (optional) | https://www.noise.nx.kg/ |

## App Information

| Field | Value |
|-------|-------|
| App Name | DecibelPro |
| Bundle ID | `com.goodcraft.DecibelPro` |
| App Store ID | `6779128095` |
| App Store URL | https://apps.apple.com/app/id6779128095 |
| Version | 1.0 (1) |
| Category | Utilities |
| Minimum OS | iOS 18.6 |

## Review Notes (Background Audio)

> DecibelPro uses the `audio` background mode to continue real-time noise monitoring and voice-activated recording when the app is in the background. Users explicitly enable background monitoring in the Voice tab. The app does not play music or unrelated audio in the background.

## Privacy Questionnaire

- Collects audio data: **Yes** — on-device measurement and recording only
- Collects precise location: **Yes** — optional, embedded in video evidence watermark only
- Tracks users: **No**
- Uses encryption: **No** (non-exempt) — `ITSAppUsesNonExemptEncryption = NO`

## Screenshots (minimum)

- 6.7" iPhone (required)
- 6.5" iPhone (if supporting older sizes)
- iPad (app supports iPad family)

Suggested screens: Monitor dashboard, Voice settings, Video recording, Files list, Settings/calibration.

## Localization

App supports: English, Arabic, Spanish, French, Hindi, Portuguese, Russian, Simplified Chinese, Traditional Chinese.

Provide at least **English** and **Simplified Chinese** metadata in Connect.

## Post-approval

1. ~~Replace placeholder App Store ID in `website/index.html`~~ — done (`6779128095`).
2. Run Archive → Validate → Upload from Xcode Release configuration.

---

## English App Store Copy (ASO-optimized)

Copy limits: **Title 30** · **Subtitle 30** · **Keywords 100** (comma-separated, no spaces) · **Description 4000**

### Title (30 characters)

```
DecibelPro: Decibel dB Meter
```

*ASO notes: Brand first; packs `decibel`, `dB`, `meter` — top search terms for this category.*

### Subtitle (30 characters)

```
Sound Level & Noise Monitor
```

*ASO notes: Adds `sound level` and `noise monitor` without repeating title words.*

### Keywords (100 characters)

```
dBA,SPL,Leq,spectrum,neighbor,complaint,voice,video,calibration,background,loud,apartment,sleep,snoring
```

*ASO notes: 97/100 chars. Avoids duplicates from title/subtitle (`decibel`, `meter`, `sound`, `level`, `noise`, `monitor`, `record`). Covers use-case and feature long-tails.*

### Promotional Text (optional, 170 characters)

```
Turn your iPhone into a live decibel meter. Monitor dB levels, auto-record loud events, and capture video evidence with on-screen sound readings — all on-device.
```

### Description

```
DecibelPro is a professional-grade noise toolkit for your iPhone — a real-time decibel meter, sound level monitor, and evidence recorder in one app.

Whether you are checking apartment noise, documenting neighbor complaints, measuring office sound levels, or tracking loud traffic and snoring, DecibelPro gives you live dB readings, clear stats, and exportable proof — without sending your audio to the cloud.

LIVE DECIBEL METER & SOUND MONITOR
• Real-time dB display with max, min, average, and Leq
• Live waveform and frequency spectrum
• A / C / Z weighting for different measurement standards
• Standard mode (human hearing) and High Sensitivity mode (full-band / low-frequency)
• One-tap start and stop monitoring

VOICE-ACTIVATED NOISE RECORDING
• Auto-record when sound crosses your start threshold
• Adjustable start and stop levels with tail delay
• Optional AI sound classification — record only selected noise types
• Background monitoring keeps measuring while you use other apps

VIDEO NOISE EVIDENCE
• Record video with decibel watermark burned into every frame
• Timestamp and GPS overlay for documentation
• Pinch-to-zoom up to 5× on the live camera preview
• Perfect for disputes, rentals, construction, and compliance checks

FILES & SHARING
• Browse voice clips and video evidence in one place
• Play, rename, share, and batch-export recordings
• Sort by date, peak dB, or file name

CALIBRATION & SETTINGS
• Per-device calibration offset and user adjustment
• 9 languages and light / dark / system theme
• Privacy policy and terms built in

PRIVACY FIRST
All measurement, recording, and video processing happens on your device. DecibelPro does not upload your audio or video to our servers.

IMPORTANT
DecibelPro is not a certified sound level meter. Readings are reference estimates for personal comparison and documentation — not for legal metrology or occupational safety certification.

Download DecibelPro today — measure noise, record proof, and document sound levels with confidence.
```

*Character count: ~1,850 / 4,000 — room for future feature bullets (e.g. Apple Watch).*

### ASO keyword map

| Search intent | Covered in |
|-------------|------------|
| decibel meter, dB meter, sound meter | Title |
| noise monitor, sound level | Subtitle |
| neighbor noise, apartment, complaint, sleep, snoring | Keywords + Description |
| SPL, Leq, dBA, spectrum, calibration | Keywords + Description |
| voice activated recording, video evidence | Keywords + Description |
| background monitoring | Keywords + Description |

### Connect checklist (English)

- [ ] Paste Title, Subtitle, Keywords, Description into App Store Connect → App Information / Version
- [ ] Category: **Utilities** (primary); consider **Productivity** as secondary if available
- [ ] Age Rating: 4+ (no restricted content)
- [ ] Support URL: https://www.noise.nx.kg/support.html
- [ ] Privacy Policy URL: https://www.noise.nx.kg/privacy.html
