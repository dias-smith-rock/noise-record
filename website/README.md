# Decibel Meter Website

Static product landing site for the Decibel Meter iOS app. Lives alongside the Xcode project in this monorepo and deploys independently via GitHub Pages.

## Structure

```text
website/
├── index.html          # Product landing page
├── privacy.html        # Privacy policy
├── terms.html          # Terms of service
├── support.html        # FAQ & contact
├── robots.txt          # Crawler directives
├── sitemap.xml         # URL index for search engines
├── assets/
│   ├── css/style.css
│   ├── js/main.js
│   └── images/         # App screenshots / icon
├── CNAME               # Custom domain: decibelmeterpro.com
├── CNAME.example       # Template reference
└── README.md
```

## Local preview

No build step required:

```bash
cd website
python3 -m http.server 8080
```

Open [http://localhost:8080](http://localhost:8080).

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

## SEO files

| File | Purpose |
|------|---------|
| `robots.txt` | Allows all crawlers; points to sitemap |
| `sitemap.xml` | Lists index, privacy, terms, support |
| `index.html` `<head>` | Canonical URL, JSON-LD, Smart App Banner |

## Updating content

| Task | File |
|------|------|
| Hero / features copy | `index.html` |
| Privacy policy | `privacy.html` |
| Terms of service | `terms.html` |
| FAQ / support | `support.html` |
| Styles | `assets/css/style.css` |
| App Store link | `index.html` — `#app-store-link` href |

## App screenshots

Export PNGs from the iOS Simulator or device and place them in `assets/images/`. Reference them in `index.html` when ready.
