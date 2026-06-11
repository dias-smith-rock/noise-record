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

**Configured domain:** `www.noise.nx.kg` (see `CNAME` file)

> The DNS zone is `noise.nx.kg`. Use CNAME on `www` — not CNAME on `@` (conflicts with SOA/NS).

### Step 1 — DNS at Stackryze (zone `noise.nx.kg`)

| Type  | NAME | Value                     |
|-------|------|---------------------------|
| CNAME | www  | dias-smith-rock.github.io |

Preview must show **`www.noise.nx.kg`**, not `noise.noise.nx.kg`.

Optional: remove any **A** record on `@` if GitHub still reports apex `noise.nx.kg` errors (www-only setup does not need apex A records).

### Step 2 — GitHub Pages settings

1. Push `website/CNAME` to `main` (content must be exactly `www.noise.nx.kg`).
2. Wait for **Deploy Website** workflow to finish.
3. Repo **Settings → Pages → Custom domain** — enter `www.noise.nx.kg` (must match `CNAME` file).
4. Click **Check again** after deploy.
5. Enable **Enforce HTTPS** once the warning clears.

### Step 3 — Verify

```bash
dig www.noise.nx.kg CNAME +short
# Expected: dias-smith-rock.github.io.
```

Site URL: **https://www.noise.nx.kg**

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
