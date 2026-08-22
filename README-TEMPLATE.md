| `booking` | Destination behind all 6 booking CTAs (currently a `tel:` link), and the CTA button label || `contact` | Display phone, `tel:` link, email |# Using this site as a template

This is a plain static site (HTML + one CSS + vanilla JS + GSAP + jQuery + the Webflow IX2
runtime). No build step, no npm, no bundler. It is now also a **safely re-brandable template**.

Currently built as: **Minted Dental**.

---

## The one thing to understand

```
_source/          <- the pristine, never-edited site. THE MASTER COPY.
brand.config.json <- the only file you edit
Build-Site.ps1    <- reads _source/ + your config, writes the live pages at the root
```

**Every build regenerates the pages from `_source/`.** It never edits its own previous output.
That means you can run it a hundred times, change your mind, change it back, and never
accumulate damage. It is the fix for what broke this site before: the old script did repeated
in-place edits and read UTF-8 files as ANSI, which turned `'` into `â€™`, `★` into `â˜…`, and
eventually deleted 1,987 lines out of `index.html`.

Do not hand-edit the files at the root. They are build output and get overwritten.
Edit `brand.config.json`, or edit `_source/` for structural changes.

---

## Everyday workflow

```bash
notepad brand.config.json
```

```bash
powershell -ExecutionPolicy Bypass -File .\Build-Site.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File .\Serve.ps1
```

Then open <http://127.0.0.1:8123/index.html>.

Useful flags:

| Command | What it does |
| :-- | :-- |
| `.\Build-Site.ps1` | Build the site from your config |
| `.\Build-Site.ps1 -DryRun` | Show what would change, write nothing |
| `.\Build-Site.ps1 -Restore` | Put the original unbranded site back |
| `.\Serve.ps1 -Port 8200` | Preview on a different port |

---

## What `brand.config.json` controls

| Block | Controls |
| :-- | :-- |
| `brand` | Clinic name, short name, tagline, meta description, copyright year, footer credit |
| `contact` | Display phone, `tel:` link, email |
| `booking` | Destination behind all 6 booking CTAs (currently a `tel:` link), and the CTA button label |
| `social` | Facebook / Instagram / Twitter links in the nav dropdown and footer |
| `assets` | Logo, favicon, webclip — see below |
| `theme` | All brand colours |
| `themeVariantBlue` | Optional separate palette for the `variant-blue/` copy. Delete the block to make it inherit `theme`. |
| `text` | Free-form copy replacement: `"existing text on the page": "your text"` |
| `build.includeVariantBlue` | Set `false` to stop building the second colour variant |

### Changing copy

Add a line to `text`. Left side must match the page text exactly:

```json
"text": {
  "Trusted Dental Care for Every Generation": "Gentle Dentistry in Kochi",
  "We combine modern technology with heartfelt service": "Comfort-first care for the whole family"
}
```

### Changing colours

Change `theme.primary` and the rest follows — the build rewrites the CSS custom properties, the
testimonial gradient, the footer, and the button glow.

```json
"theme": {
  "primary": "#398a6a",
  "primaryHover": "#2d6f55",
  "primaryMuted": "#6f9a86",
  "dark": "#0d2b21",
  "darkAlt": "#123a2c",
  "darker": "#08201a",
  "accent": "#9ed9bb"
}
```

### Changing the logo

Two modes, set by `assets.generateLogo`:

**Your own logo file** (what this build uses):
```json
"generateLogo": false,
"logoStyle": "badge",
"logo": "assets/img/brand-badge.png",
"logoDark": "assets/img/brand-badge.png",
"favicon": "assets/img/brand-badge.png",
"webclip": "assets/img/brand-badge.png"
```
`logoStyle: "badge"` sizes a square/circular logo correctly in the nav (48px) and footer (72px).
Use `"wordmark"` instead for a wide horizontal logo. The build automatically mirrors your logo
file into `variant-blue/`.

**Auto-generated wordmark** — set `"generateLogo": true` and the build draws an SVG wordmark
and favicon from `brand.shortName` in your theme colours. Handy before you have real artwork.

### Cropping a circular logo

The circular Minted badge was cut out of a square JPG (dark gradient corners removed, edges
antialiased, transparent outside the circle) with:

```bash
powershell -ExecutionPolicy Bypass -File .\tools\Crop-CircleLogo.ps1 -In "C:\Users\Moon\Downloads\minted dental logo.jpg" -Out "assets\img\brand-badge.png" -Size 512
```

### Booking + contact actions

There is no backend and no third-party service. All 6 "Call To Book" CTAs point at whatever
`booking.url` is set to; it is currently `tel:+919307512816`, so they dial the clinic directly.
Set it to a Calendly/booking URL and rebuild if you ever want online booking back.

The hero lead-capture form and its WhatsApp handoff have been removed, along with the careers
Google Form and the Google WebFont loader. The site now makes no third-party calls except
Google Fonts (`fonts.googleapis.com`) and whatever social links you set.

### Swapping photos

Drop a replacement at the same path and filename in `assets/img/` (most visible photos are
`gen_<token>.jpg`). Keep the aspect ratio. Every page has an inline image guard that renders an
on-brand gradient card if an image ever fails, so nothing shows a broken-image icon.

---

## Structural edits

For anything the config cannot express — new sections, changed layout, different page order —
edit the file in **`_source/`**, not at the root. Then rebuild. If you edit the root copy, your
next build overwrites it.

Safe rules when editing `_source/`:
- Don't delete anything in `assets/js/` — jQuery, GSAP, and the Webflow IX2 runtime drive all
  the animations.
- Don't add inline `filter: blur(...)`; it leaves elements permanently blurred if a scroll
  trigger misfires.
- Reveal animations key off `[data-w-id]` with an inline `opacity:0`. Keep that pattern and new
  sections will fade in like the rest.

---

## Deploying

It is a static site, so anything works.

- **Netlify** — drag the folder onto <https://app.netlify.com/drop>. No build command.
- **GitHub Pages** — push, then Settings → Pages → Deploy from branch → `main` / `/ (root)`.
  A `.nojekyll` file is already committed.
- **Vercel** — `npx vercel --prod`, framework "Other", no build command, output directory `.`.

### Keep the tooling out of the deploy

`_source/`, `tools/`, `brand.config.json`, `CLAUDE.md` and the `.ps1` files are for editing, not
for the web. **Static hosts serve every file you upload** — nothing is "ignored" — so if you
upload the whole folder, anyone can read them at e.g. `yoursite.com/_source/index.html`. That
matters here because `_source/` is the pre-rebrand master: it still says "Lumora Dental", carries
the old email and phone, and points every CTA at someone else's personal Calendly.

Two of the three deploy routes above upload the working folder regardless of git:

| Route | What excludes the tooling |
| :-- | :-- |
| Netlify | `netlify.toml` in this repo already excludes it |
| Vercel | `.vercelignore` in this repo already excludes it |
| GitHub Pages | `_source/` is untracked, so it never reaches the repo. Keep it that way. |
| Manual upload / FTP | Upload only `*.html`, `assets/`, `variant-blue/`, `.nojekyll`, `robots.txt` |

`robots.txt` additionally tells crawlers to skip those paths, as a second line of defence.

---

## What was removed

- Hero lead-capture form + its WhatsApp handoff (`lumoraLead`)
- Calendly booking links on all CTAs -> now `tel:`
- Careers Google Form on `about.html` -> now `tel:`
- Google WebFont loader script (redundant; Sora already loads via the fonts `<link>`)
- Broken link `https://about#team-members` -> fixed to `about.html#team-members`
- `_old-broken-system/` and the stale legacy docs
