# Decibel Meter Website

Static product landing site for the Decibel Meter iOS app. Lives alongside the Xcode project in this monorepo and deploys independently via GitHub Pages.

## Structure

```text
website/
├── index.html                    # Product landing page
├── apartment-noise-complaint-guide/
│   └── index.html                # Mega SEO landing page
├── knowledge/
│   ├── index.html                # Guides hub
│   ├── how-to-sue-neighbor-small-claims-court-noise/
│   │   └── index.html            # Small claims court spoke article
│   └── science-of-hearing-and-noise-monitoring/
│       └── index.html            # Hearing science & monitoring modes spoke
├── privacy.html
├── terms.html
├── support.html
├── robots.txt
├── sitemap.xml
├── assets/
│   ├── css/style.css
│   ├── js/
│   │   ├── main.js
│   │   └── firebase-analytics.js # Firebase GA4 (project website-decibelmeter)
│   └── images/
├── CNAME
├── CNAME.example
└── README.md
```

## Local preview

No build step required:

```bash
cd website
python3 -m http.server 8080
```

Open [http://localhost:8080](http://localhost:8080).

SEO guide pages (after starting the server):

- [http://localhost:8080/apartment-noise-complaint-guide/](http://localhost:8080/apartment-noise-complaint-guide/)
- [http://localhost:8080/knowledge/](http://localhost:8080/knowledge/)
- [http://localhost:8080/knowledge/how-to-sue-neighbor-small-claims-court-noise/](http://localhost:8080/knowledge/how-to-sue-neighbor-small-claims-court-noise/)
- [http://localhost:8080/knowledge/science-of-hearing-and-noise-monitoring/](http://localhost:8080/knowledge/science-of-hearing-and-noise-monitoring/)

## Deployment (GitHub Pages)

1. Push to `main` — the workflow [`.github/workflows/deploy-website.yml`](../.github/workflows/deploy-website.yml) deploys `website/` automatically when files change.
2. In the GitHub repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. After the first successful run, the site is available at:
   `https://dias-smith-rock.github.io/noise-record/`

You can also trigger a manual deploy from the **Actions** tab → **Deploy Website** → **Run workflow**.

## Custom domain

**Configured domain:** `www.decibelmeterpro.com` (see `CNAME` file)

> Use CNAME on `www` pointing to `dias-smith-rock.github.io`. Configure apex `decibelmeterpro.com` to 301-redirect to `www` at your DNS provider (GoDaddy forwarding) to avoid duplicate-content SEO issues.

### Step 1 — DNS at GoDaddy (zone `decibelmeterpro.com`)

| Type  | NAME | Value                     |
|-------|------|---------------------------|
| CNAME | www  | dias-smith-rock.github.io |

Optional: set up domain forwarding on `@` (apex) → `https://www.decibelmeterpro.com`.

### Step 2 — GitHub Pages settings

1. Push `website/CNAME` to `main` (content must be exactly `www.decibelmeterpro.com`).
2. Wait for **Deploy Website** workflow to finish.
3. Repo **Settings → Pages → Custom domain** — enter `www.decibelmeterpro.com` (must match `CNAME` file).
4. Click **Check again** after deploy.
5. Enable **Enforce HTTPS** once the warning clears.

### Step 3 — Verify

```bash
dig www.decibelmeterpro.com CNAME +short
# Expected: dias-smith-rock.github.io.
```

Site URL: **https://www.decibelmeterpro.com**

### HTTPS / SSL checklist (post-deploy)

After DNS and GitHub Pages custom domain are configured:

1. **GitHub Pages** — Repo **Settings → Pages** → enable **Enforce HTTPS** (available once DNS verification completes).
2. **GoDaddy apex redirect** — Forward `decibelmeterpro.com` (`@`) with **301** to `https://www.decibelmeterpro.com` so crawlers see a single canonical host.
3. **Smoke test** — Visit `http://www.decibelmeterpro.com` and `http://decibelmeterpro.com`; both should redirect to `https://www.decibelmeterpro.com`.
4. **SSL Labs** — Re-test at [SSL Labs](https://www.ssllabs.com/ssltest/) after changes propagate.

All site HTML uses root-relative asset paths (`/assets/...`) and HTTPS canonical URLs.

## Analytics (Firebase / GA4)

Every page loads `assets/js/firebase-analytics.js` as an ES module at the end of `<body>`, before any other Firebase services.

- **Firebase project:** `website-decibelmeter`
- **Measurement ID:** `G-WG20DNR6DY`
- **Config file:** `assets/js/firebase-analytics.js`

After deploy, verify in browser DevTools → **Network** → filter `google-analytics` or `firebase`.

To rotate keys or add Firebase products, edit `firebase-analytics.js` in [Firebase Console](https://console.firebase.google.com/) → **website-decibelmeter** → Project settings → Your apps.

## SEO files

| File | Purpose |
|------|---------|
| `robots.txt` | Allows all crawlers; points to sitemap |
| `sitemap.xml` | Lists homepage, SEO guides, privacy, terms, support |
| `index.html` `<head>` | Canonical URL, JSON-LD, Smart App Banner, Open Graph |
| `assets/js/firebase-analytics.js` | Firebase Analytics (GA4) module |

## Updating content

| Task | File |
|------|------|
| Hero / features copy | `index.html` |
| Apartment noise mega guide | `apartment-noise-complaint-guide/index.html` |
| Knowledge hub & spoke articles | `knowledge/` |
| Privacy policy | `privacy.html` |
| Terms of service | `terms.html` |
| FAQ / support | `support.html` |
| Article / guide styles | `assets/css/style.css` |
| App Store link | `index.html` — `#app-store-link` href |

## App screenshots

Export PNGs from the iOS Simulator or device and place them in `assets/images/`. Reference them in `index.html` when ready.
