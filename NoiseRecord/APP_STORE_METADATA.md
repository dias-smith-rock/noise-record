# App Store Connect Metadata Checklist

Use this when submitting **NoiseRecord** v1.0.

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
| Bundle ID | `com.goodcraft.NoiseRecord` |
| App Store ID | `6779128095` |
| App Store URL | https://apps.apple.com/app/id6779128095 |
| Version | 1.0 (1) |
| Category | Utilities |
| Minimum OS | iOS 18.6 |

## Review Notes (Background Audio)

> NoiseRecord uses the `audio` background mode to continue real-time noise monitoring and voice-activated recording when the app is in the background. Users explicitly enable background monitoring in the Voice tab. The app does not play music or unrelated audio in the background.

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
