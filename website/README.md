# NoiseRecord Website

Static product landing site for the NoiseRecord iOS app. Lives alongside the Xcode project in this monorepo and deploys independently via GitHub Pages.

## Structure

```text
website/
├── index.html          # Product landing page
├── privacy.html        # Privacy policy
├── support.html        # FAQ & contact
├── assets/
│   ├── css/style.css
│   ├── js/main.js
│   └── images/         # Add App screenshots / icon here
├── CNAME               # Custom domain: noise.nx.kg
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

**Configured domain:** `noise.nx.kg` (see `CNAME` file)

### Step 1 — DNS at your registrar (nx.kg)

Add a CNAME record for the `noise` subdomain:

| Type  | Name  | Value                     |
|-------|-------|---------------------------|
| CNAME | noise | dias-smith-rock.github.io |

> Some panels use `noise` as the host name; others want the full `noise.nx.kg`. Do not include `https://`.

### Step 2 — GitHub Pages settings

1. Push `website/CNAME` to `main` and wait for the deploy workflow to finish.
2. Repo **Settings → Pages → Custom domain** — enter `noise.nx.kg`.
3. Enable **Enforce HTTPS** once DNS has propagated (may take minutes to 48 hours).

### Step 3 — Verify

```bash
dig noise.nx.kg +short
# Expected: dias-smith-rock.github.io. (then GitHub IPs)
```

Site URL: **https://noise.nx.kg**

## Updating content

| Task | File |
|------|------|
| Hero / features copy | `index.html` |
| Privacy policy | `privacy.html` |
| FAQ / support | `support.html` |
| Styles | `assets/css/style.css` |
| App Store link | `index.html` — replace the disabled button `href` and remove `btn-disabled` |

## App screenshots

Export PNGs from the iOS Simulator or device and place them in `assets/images/`. Reference them in `index.html` when ready.
