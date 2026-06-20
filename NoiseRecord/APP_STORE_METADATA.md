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

## Firebase

| Service | SDK | Purpose |
|---------|-----|---------|
| Firebase Analytics | `FirebaseAnalytics` | Event logging (`app_launch`, `monitoring_state`, `app_error`, etc.) |
| Firebase Crashlytics | `FirebaseCrashlytics` | Crash reports + breadcrumb logs |

- Config: [`NoiseRecord/GoogleService-Info.plist`](NoiseRecord/GoogleService-Info.plist)
- Bootstrap: `FirebaseAppDelegate` + `AppTelemetry`
- dSYM upload: **Upload Crashlytics Symbols** build phase (Release Archive)

Enable **Crashlytics** and **Google Analytics** in [Firebase Console](https://console.firebase.google.com/) for project `noiserecord-a7860` if not already on.

## AdMob

| Field | Value |
|-------|-------|
| App ID | `ca-app-pub-2283581832994740~9865795031` |
| Cold start (App Open) | `ca-app-pub-2283581832994740/5926550020` (`openning_cold`) |
| Hot start (Interstitial) | `ca-app-pub-2283581832994740/7790296034` (`interstitial_hot`) |

- SDK: `GoogleMobileAds` + `GoogleUserMessagingPlatform` (UMP) via SPM
- Config: [`AdMob-Info.plist`](AdMob-Info.plist) (GADApplicationIdentifier + SKAdNetworkItems)
- Consent: `AdConsentManager` — UMP GDPR + IDFA Explainer (ATT triggered by UMP, not manual)
- Managers: `AppOpenAdManager` (cold), `HotStartAdManager` (hot)
- Debug builds use [Google test ad units](https://developers.google.com/admob/ios/test-ads)
- Analytics events: `ad_cold_load/show/fail`, `ad_hot_load/fail`, `ad_lifecycle` channel `consent`

### AdMob Privacy & messaging (manual — required before Release)

In [AdMob → Privacy & messaging](https://admob.google.com/) for App ID `ca-app-pub-2283581832994740~9865795031`:

1. Create and **Publish** a **GDPR / EEA consent** message (TCF).
2. Create and **Publish** an **IDFA explainer** message (links to Apple ATT after user taps Continue/Consent).
3. Confirm both messages are assigned to this app.

Without published messages, UMP will not show forms and `canRequestAds` may stay false in EEA.

**UMP + ATT test checklist (Release / TestFlight)**

| Step | Action |
|------|--------|
| 1 | Fresh install on device; wait for UI, UMP form should appear before ads load |
| 2 | EEA: GDPR form → Consent → system ATT dialog |
| 3 | Non-EEA: IDFA explainer → Continue → system ATT dialog |
| 4 | Second launch: no form if consent cached; ad on first user interaction only |
| 5 | Settings → **Ad Privacy Choices** (when required) reopens UMP privacy options |
| 6 | Remove Ads IAP: no UMP, no AdMob, no ATT |

Debug UMP: uncomment `DebugSettings` in `AdConsentManager.makeRequestParameters()`; add test device hash from Xcode log; set `geography = .EEA` to force GDPR path.

App Store Connect privacy questionnaire: declare **Advertising Data** and **Device ID** for third-party advertising (AdMob).

## In-App Purchase (Remove Ads)

| Field | Value |
|-------|-------|
| Product ID | `com.decibelpro.removeads.lifetime` |
| Type | Non-Consumable (lifetime) |
| Reference price | $2.99 (marketing strikethrough $3.99 in-app) |
| Manager | `IAPManager` (StoreKit 2) |
| Local testing | [`DecibelPro.storekit`](DecibelPro.storekit) — linked in **NoiseRecord** scheme Run options |

**App Store Connect checklist**

1. Create IAP under app bundle **`com.goodcraft.NoiseRecord`** (must match Xcode `PRODUCT_BUNDLE_IDENTIFIER`).
2. Product ID must exactly match `com.decibelpro.removeads.lifetime`.
3. Set price tier ($2.99), add localization, status **Cleared for Sale**.
4. Sign **Paid Applications Agreement**.
5. For sandbox: create Sandbox Tester; clear purchase history before re-testing non-consumable.

**Analytics events:** `iap_lifecycle` (step: `purchase_verified`, `purchase_user_cancelled`, `product_load_not_found`, etc.)


> DecibelPro uses the `audio` background mode to continue real-time noise monitoring and voice-activated recording when the app is in the background. Users explicitly enable background monitoring in the Voice tab. The app does not play music or unrelated audio in the background.

## Privacy Questionnaire

- Collects audio data: **Yes** — on-device measurement and recording only
- Collects precise location: **Yes** — optional, embedded in video evidence watermark only
- Third-party advertising (AdMob): **Yes** — app open + interstitial ads; device identifiers for ad delivery
- Tracks users: **Yes** — AdMob may use IDFA for personalized ads / ad measurement when user grants ATT (UMP IDFA explainer)
- Uses encryption: **No** (non-exempt) — `ITSAppUsesNonExemptEncryption = NO`
- Privacy Choices URL (optional): https://www.noise.nx.kg/privacy.html — document in-app **Settings → Ad Privacy Choices**

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

**Apple Watch (v1.1+):** Standalone noise monitoring on wrist — current dB, session stats, standard / high-sensitivity modes. Not a certified sound level meter; readings are reference estimates only.

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
