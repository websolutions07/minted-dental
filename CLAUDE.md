# Lumora Dental — project notes

A premium dental clinic website. **Origin:** a de-branded, rebuilt version of a Webflow HTML
template (originally "Smilifye" by author "Flowfye"). Every Webflow/template trace has been
stripped and all assets localized so the site is fully self-contained and indistinguishable as
an original build.

## Handoff / reproduction (preferred method — 14 Jun 2026)
The repo is **public** and **the source of truth**. The reliable one-shot is now **`CLONE_AND_DEPLOY.md`**:
it tells any agent to `git clone https://github.com/toprmrproducer/lumora-dental`, run it, and deploy it
(GitHub Pages / Netlify drop / Vercel) — **no rebuild, no framework, no image generation** (all 37 AI
`gen_*.jpg` photos are committed, so a clean clone always looks finished). This replaces the old
embedded-code `ONESHOT_PROMPT.md`, which executing agents kept "improving" into a Vite/React app with
random stock images. Cross-platform (Mac/Windows/Linux). `ONESHOT_PROMPT.md` is kept for reference but
clone-and-deploy is the recommended path.

**Image guard (14 Jun 2026):** every one of the 18 HTML pages now has a tiny inline `<script>` before
`</body>` (search "image guard:") that swaps any failed/empty `<img>` to an on-brand gradient SVG card
(teal `#24a3b1`→`#011f23` at root, blue `#2f80ff`→`#06182e` in `variant-blue/`). So even if someone
deletes images during a re-skin, nothing ever shows a broken/gray/red box — it reads as intentional.

## Structure
- `index.html` — home (was `Dental.html`)
- `about.html`, `service.html`, `blog.html` — main pages
- `privacy.html`, `terms.html` — hand-built legal pages (share `assets/css/lumora.css` + inline styles)
- `assets/css/lumora.css` — the (renamed) Webflow design system; all `url()`s point to `../img/`
- `assets/js/` — Webflow IX2 runtime (`webflow.*.js`), `jquery-3.5.1.min.js`, GSAP (`gsap.min.js`,
  `ScrollTrigger.min.js`, `SplitText.min.js`). **Do not delete** — these drive all 39 interactions.
- `assets/img/` — all photos + the new brand assets: `lumora-logo.svg`, `lumora-logo-dark.svg`
  (footer), `favicon.svg`, `webclip.png`. ~149 files (incl. responsive `-p-500/800/1080…` variants).
- `.bak/` — original Webflow exports, kept for reference.

## Brand
- Name: **Lumora Dental**. Accent teal `#24a3b1`; deep teal `#011f23` / `#022f34`. Font: Sora.
- Email: `hello@lumoradental.com` (placeholder). Phone in footer is template placeholder.

## Wiring
- Nav/footer links are local `.html` files. All "Book/Get Appointment" CTAs (×6) →
  `https://calendly.com/shreyasrajsony11` (Shreyas's connected Calendly).

## Interactions
- Webflow IX2 (jQuery-dependent) + GSAP/ScrollTrigger/SplitText + inline GSAP (animated counters
  on `.about-hero_info-item_title`).
- **IMPORTANT — IX2 reveals don't fire on the export.** Webflow baked every reveal element's hidden
  state into inline styles (`opacity:0` + `transform:translateY` + `filter:blur`), to be animated by
  IX2 — but the exported IX2 data never applies them, so without a fix all that text/imagery stays
  invisible/blurred. Fix = the **"Lumora reveal engine v2"** `<script>` before `</body>` on every page:
  it finds `[data-w-id][style*="opacity:0"]` (outside the nav) and fades+slides them in via GSAP
  ScrollTrigger, with a 2.6s safety net that force-shows anything still hidden. **No blur** is used.
- All inline `filter:blur(...)` has been stripped from the HTML (it was leaving images permanently
  blurred when triggers misfired). Do NOT reintroduce blur in reveals.
- Sliders are native Webflow `w-slider` (story_slider, testimonial_slider) — fully functional (drag +
  dots + arrows). The story slider's arrows had `is-hide` (removed) so prev/next are now visible.

## Run locally
```
cd "~/Library/Mobile Documents/com~apple~CloudDocs/website/lumora-dental"
python3 -m http.server 8123 --bind 127.0.0.1
# open http://127.0.0.1:8123/index.html
```

## De-brand invariant (keep it true)
Final grep across HTML+CSS must stay **0** for: `webflow.com`, `website-files.com`, `pagifye`,
`flowfye`, `smilifye`, `data-wf-domain/page/site`, `name="generator"`. (`data-wf--button-primary--variant`
is a CSS variant and is fine to keep.)

## AI imagery (Magnific)
- All visible photos were regenerated with Magnific (model `gpt-2`, quality `low`, resolution `1k`,
  ~15 credits each) so the site is not a copy of the original stock. Sources live as `assets/img/gen_<token>.jpg`.
- Mechanism: every old Webflow filename (incl. all `-p-500/800/...` srcset variants) was remapped to the
  single `gen_<token>.jpg` across HTML+CSS. To regenerate one image, drop a new `gen_<token>.jpg` in place.
- Magnific is driven over its HTTP API from the keychain OAuth token (see `/tmp/mcp_magnific.py` pattern):
  `images_generate` (mode=gpt-2, quality=low, resolution=1k) -> `creations_get` for the `url:` -> download
  -> `sips -s format jpeg`. WebP encode is NOT available locally (sips/cwebp), so everything is written as JPG.
- Not regenerated (decorative, low-visibility): awards, job, location, success-item images; CSS
  testimonial-background + home-hero-mobile-image. Regenerate later if wanted.

## TODO / open
- AI image regeneration: DONE (see "AI imagery" above; 32 `gen_*.jpg`). Not yet regenerated:
  decorative awards/job/location/success images + CSS mobile-hero — optional.
- LIVE on GitHub Pages: https://toprmrproducer.github.io/lumora-dental/ (teal) and /variant-blue/ (blue). Repo is public.
- Optional polish: real clinic phone number, real OG image, real social profile URLs (currently `#`).

## Variants, legal, deploy, prompt (added 14 Jun 2026)
- `variant-blue/` = full copy recolored teal->bright blue (`--primary-*` overrides + hex sweep),
  4-point sparkle eyebrow icon. Same layout/animations.
- Legal pages: `privacy/terms/cookies/licenses/404.html` (hand-built, on-brand, all footer-linked).
- Footer credit: "Crafted by RapidXAI" + "© 2026 Lumora Dental".
- GitHub: private repo `toprmrproducer/lumora-dental`.
- Netlify: site `lumora-dental-blue.netlify.app` created but deploy BLOCKED (account credits exhausted).
- `ONESHOT_PROMPT.md` = comprehensive prompt to regenerate this site from scratch with [PLACEHOLDERS].

## Conversion + content updates (14 Jun 2026)
- Phone is `+91 93007512816` everywhere (display + tel: + wa.me 9193007512816).
- Hero **lead-capture form** (`.lead-form_card`, "Book a visit", name+phone) on both variants. On
  submit it opens a prefilled WhatsApp to the clinic and shows a success state. ALWAYS visible (not
  gated by reveal). Handler `leadSubmit()` injected before </body> on index pages; CSS in lumora.css.
- Closing CTA (`.section_cta`) now has a photo background (`gen_about-hero-image.jpg`) + dark overlay
  (teal vs blue per variant); footer has an accent top-border. Fixes the "bland footer".
- All em dashes removed from copy/titles (titles use `|`).
- Fixed a regression: the 404 footer + navbar anchors were mangled to `` `4.html `` by a bad perl
  backref; both restored to `404.html`.
- `ONESHOT_PROMPT.md` expanded to ~1080 lines (full design system, component code, full CSS sheet,
  responsive rules, all page copy, full legal text, image prompts, variant recipe, QA, deploy).

## Hero carousel + form placement fix (14 Jun 2026)
- Hero background is a 4-image rotating carousel (`.hero-carousel-img`, crossfade every 5s): the
  original hero + `gen_hero-2/3/4.jpg` (new Magnific gpt-2 images). CSS + cycler JS in place, both variants.
- Lead form was mistakenly inserted in the navbar; moved into `home-hero_content` right after the hero
  Book Appointment button (anchored on data-w-id 123dbd0a...). Now stacks: headline, button, form (left).

## Testimonial card background (14 Jun 2026)
- `.testimonial-slider_card` now uses `gen_testimonial-bg.jpg` (clinic + greenery) under a cyan/teal overlay (blue overlay on the blue variant); card text forced white. CSS cache-bust at `?v=20260614c`.

## Team section background (14 Jun 2026)
- `.section_team` now uses `gen_team-bg.jpg` (clinic + window plants) under a cyan/teal overlay (blue on variant). Header text (`.home-team_header-title/-para`, `.section_tag`) forced white; `.text-highlighted` lightened. Doctor name plates stay dark. CSS cache-bust `?v=20260614d`.

## Template system (19 Aug 2026) — READ BEFORE EDITING

The site is now re-brandable through a build step. **Do not hand-edit the HTML at the repo root** —
it is generated output and gets overwritten on the next build.

```
_source/            pristine master copy of every page + both CSS files. Never edited by the build.
brand.config.json   the only file you normally edit
Build-Site.ps1      _source/ + config  ->  the live pages at the root
Serve.ps1           local static preview (no Python/Node on this machine)
tools/Crop-CircleLogo.ps1   crops a circular badge out of a square image, transparent outside
README-TEMPLATE.md  full usage guide
```

Run: `powershell -ExecutionPolicy Bypass -File .\Build-Site.ps1` (`-DryRun`, `-Restore` available).

**Why it is built this way.** An earlier session edited the root HTML in place with repeated
regex passes and PowerShell's default ANSI encoding. That double-encoded UTF-8 (`'`->`â€™`,
`★`->`â˜…`, `&nbsp;`->`Â`), prepended BOMs, and finally deleted 1,987 lines from `index.html`,
leaving a 2.5KB fragment with a mangled `<script>` spliced into `<head>`. Both `index.html` and
`variant-blue/index.html` were destroyed.

The current build avoids that structurally:
- always reads from `_source/`, never from its own previous output, so it is idempotent
- all I/O is `System.IO.File` with `UTF8Encoding($false)` — correct encoding, no BOM
- brand replacements are case-sensitive, so `lumora.css` / `lumora-logo.svg` / `lumoraLead`
  are never caught by the `Lumora` -> brand rules

Structural changes go in `_source/`, then rebuild.

Current brand: **Minted Dental**, green `#398a6a` on deep green `#0d2b21`, circular badge logo at
`assets/img/brand-badge.png`. `variant-blue/` keeps its own blue palette via `themeVariantBlue`.

`_old-broken-system/` holds the previous attempt (`update-site.ps1`, `editor.html`,
`site.config.json`, `lumora-core.js`, `site-config.js`). Nothing references it. Safe to delete.

## Third-party integrations removed (19 Aug 2026)

At the user's request the site now has **zero backend and no third-party services**:
- hero lead-capture form + `lumoraLead` WhatsApp handoff — removed from `_source/index.html`
  and `_source/variant-blue/index.html` (div balance verified 723/723)
- Calendly (48 links) and the careers Google Form (6 links) — both repointed via
  `booking.url`, currently `tel:+919307512816`
- Google WebFont loader (`ajax.googleapis.com/.../webfont.js`, 8 files) — redundant, Sora
  already loads from the `fonts.googleapis.com` `<link>`; verified Sora still renders
- fixed a pre-existing broken link: `https://about#team-members` -> `about.html#team-members`
- fixed `tel:+91 9307512816` (space in the href) — all 64 tel: links now use one dial-safe form
  while the visible copy keeps the readable `+91 9307512816`

Only remaining external calls: Google Fonts, and the social URLs set in the config.

**Gotcha for future edits:** `_source/` is now uniformly CRLF (re-verified 19 Aug 2026 across
all 18 pages and both CSS files); it was briefly mixed after some files were restored via
`git show`. Still write regexes over `_source/` as `\r?\n` rather than `\n`, so a future LF
file cannot silently skip.

## Real Minted Dental content (19 Aug 2026)

Placeholder template content replaced with the clinic's real data, all in `_source/`:
- **Team**: 4 real doctors (Patel, Wilson, Goodman, Woodmansee) via `tools/Set-Doctors.ps1`,
  which rewrites the uniform 31-line `w-dyn-item` cards by line range (a global find/replace
  would hit every card at once, since all cards share identical markup). Index went 3->4 cards,
  about went 6->4. Desktop team grid forced to 4 columns in the generated CSS so the 4th card
  does not orphan; tablet/mobile keep the existing 2-column fallback.
- **Photos are still AI-generated placeholders**, chosen only so apparent gender matches each
  doctor. NOT the real people — replace `gen_team-image-{6,1,3,2}.jpg` with real headshots.
- **Doctor bios NOT yet placed** — the user supplied full bios but the template has no bio
  component (cards carry name + designation only). Needs either per-doctor pages or a new
  bio section on about.html.
- **Hours**: Mon 9-5, Tue 9-6, Wed 9-4, Thu 8-4, Fri 8-3, Sat/Sun closed (6 `our-info_block`
  rows on both index pages, was 2).
- **Locations**: Desert Ridge + Scottsdale. The about-page marquee was 4 groups x 3 cities;
  the London item was deleted from each group, leaving 8 items alternating the two real clinics.
- **Careers**: `Apply Now` gets its own `careers.url` config key (mailto), deliberately NOT
  `booking.url` — an earlier pass wrongly sent job applicants to appointment scheduling.
- Job listings now read "Desert Ridge, Phoenix AZ" instead of the New York address.

Config now: booking `https://flexbook.me/minted` ("Schedule Appointment"), phone 480.400.1794
(`tel:+14804001794`), email hello@minteddental.com. Scottsdale's 480.697.4997 is not yet wired
to a second contact block.

**Gotcha:** team cards are byte-identical to each other. Never use a global replace on
`team-menmber_name` / `team-menuber_designation` — use the line-range approach in Set-Doctors.ps1.

## Wordmark, hours revert, per-location phones, hero restore (19 Aug 2026)

- **Brand wordmark beside the logo**: `<span class="brand_wordmark">` after the logo img on all
  16 pages that have a logo (404 has none). Font Fraunces 600 (matches the serif drawn in the
  badge), colour `#398a6a` sampled directly out of `brand-badge.png` — it is exactly theme.primary.
  Config keys `brand.wordmarkColor` / `brand.wordmarkColorOnDark` override it.
- **REGRESSION FOUND AND FIXED — Sora was never loading.** This template has no Google Fonts
  stylesheet, only `preconnect` hints; Sora came from the `WebFont.load()` script removed on
  19 Aug. The earlier "verified Sora still renders" check read `getComputedStyle().fontFamily`,
  which only reports the CSS declaration, not whether the face loaded — so the whole site had
  been falling back to the browser default serif. Now loaded properly via a real
  `<link href="...css2?family=Sora:wght@300..800&family=Fraunces...">` on all 18 pages.
  **To test a webfont, compare canvas text width against a bogus family name** — equal widths
  mean the font is NOT loading. `document.fonts.check()` alone is not proof.
- **Hours reverted** to the template's original Mon-Fri 8:00-17:00 / Sat-Sun 9:30-17:30 at the
  user's explicit request, replacing the real clinic hours. Real hours are in git history and in
  the section above if they ever want them back.
- **Per-location phones** on the about-page location cards: Desert Ridge (480) 400-1794,
  Scottsdale (480) 697-4997, as `.location_phone` tel: links. Main display phone is now
  `(480) 400-1794`.
- **Hero size restored.** Removing the lead-capture card cost the hero 344px (320px card +
  24px margin): 919px -> 576px at 1440w. Fixed with measured `min-height` on
  `.home-hero_content` — 631px desktop / 677px <=991 / 620px <=767, taken by rendering the
  pristine git index at each width. Hero measures 919px again.
- **Hero carousel is now slide+fade** instead of a plain crossfade: `.is-leaving` slides the
  outgoing image to -6% while the incoming one comes in from +6%. `prefers-reduced-motion`
  falls back to a plain fade. Verified running: 15 distinct transition states over 14s.

**Gotcha:** the hero carousel ticks every 5s. Sample for >10s before concluding it is broken,
and note that a hidden browser pane throttles timers so the interval appears stalled.

## Robustness audit + fixes (19 Aug 2026)

Adversarially tested the build for things that silently break when someone edits the site.
Six real defects found, all reproduced with a failing test first, then fixed and re-tested.

1. **`Add-Rule '2026'` corrupted SVG and the CSS link.** A bare year rule also matched the
   cache-bust token (`?v=20260614f`) and digits inside SVG path data — setting the year to 2027
   turned `8.20265` into `8.20275`, silently deforming the phone icon. Now anchored as
   `'&copy; 2026 Lumora Dental'` and moved BEFORE the brand rules (it must run first, or the
   trailing name is already rewritten and the anchor never matches).
2. **CSS cache-bust never changed.** `?v=20260614f` was hard-coded, so after a colour change a
   browser served the stale stylesheet and the edit looked like it did nothing. The build now
   hashes the generated CSS (MD5, 10 chars) and stamps it into every page. CSS targets are
   processed before HTML so the hash exists first. Root and variant-blue get different tokens.
3. **Missing config key shipped placeholders silently.** Deleting the `booking` block still
   "succeeded" and put 11 raw calendly.com links into the live pages. Added up-front validation
   of 15 required keys that fails with the exact list, plus a post-build leak guard scanning the
   real output for `calendly.com`, `lumoradental.com`, `+91 9307512816`, `Lumora`,
   `docs.google.com/forms`. Verified it catches a forgotten email (40 hits).
4. **Malformed JSON dumped a raw PowerShell exception.** Now a clean message naming the likely
   cause (trailing comma / smart quote) and confirming the live site is untouched.
5. **`text` overrides keyed on `_source` wording did nothing.** They run after the brand rename,
   so a phrase copied out of `_source/` ("Lumora Dental is...") never matched and the build still
   reported success. Such keys are now translated into the current brand wording, and any
   override that matches nothing is named in a warning. No-op entries (value == key) are
   excluded so they do not false-positive.
6. **Config values were not HTML-escaped.** A clinic named "Smith & Jones Dental" emitted a raw
   `&` into `<title>` and every heading. `Protect-Html` now escapes `& < >` on the text-bound
   values while leaving existing entities alone (no double-escaping; `&copy;` / `&#x27;` intact).

Also fixed in `tools/Add-ImageDimensions.ps1`: it skipped tags that already had width/height, so
**swapping an image for one with a different aspect ratio left stale dimensions** and the browser
reserved the wrong box. Verified: a 1024x1536 image replaced by 400x900 kept `width="1024"` and
re-running the tool fixed nothing. It now always recomputes from disk — self-healing and still
idempotent. Re-run it after replacing any image, then rebuild.

Verified good, no change needed: `-Restore` round-trips byte-identically; the build is idempotent;
all 18 pages stay balanced with no BOM and no mojibake; `_source` line endings are uniform.

## Bug sweep + cleanup (19 Aug 2026)

Ran a 6-dimension adversarial audit (each finding re-checked by a skeptic told to refute it).
Most reported findings were correctly rejected as style preferences or generated-output-by-design.
What survived, plus what I found directly, is fixed below.

1. **106 orphan template images x2 trees = 212 files, 39.5 MB.** The rebrand replaced every visible
   photo with a `gen_*.jpg` but left the ORIGINAL Webflow images on disk, referenced by nothing.
   Ten of them carried `flowfye` / `smilifye` in the filename, defeating the de-brand invariant the
   moment the folder is uploaded. Removed via `tools/Remove-OrphanAssets.ps1`, which treats a file
   as referenced if its basename appears in ANY project text file (covers `<img src>`, srcset,
   CSS `url('../img/..')`, inline scripts, build config). `gen_*` files are kept even when unused --
   they are our own art and make useful spares. assets/ went 28M -> 8.8M, variant-blue 28M -> 9.4M.
   Verified after deletion: 754 asset references still resolve, 0 missing; all 13 servable pages
   return 200 with 0 broken images.
2. **`variant-blue/CLAUDE.md`** was a stale 68-line copy of these internal notes sitting inside the
   deployable folder -- publicly readable at `/variant-blue/CLAUDE.md`, and it names the original
   template and Magnific API details. Deleted.
3. **README-TEMPLATE.md claimed the tooling is "ignored by static hosts".** That is false -- static
   hosts serve every uploaded file, so `_source/` (the PRE-REBRAND master: old brand name, old
   email, old phone, someone else's Calendly) would be readable at `/_source/index.html`. Rewrote
   that section and added real exclusions: `netlify.toml` (404s /_source/ and /tools/),
   `.vercelignore`, and `robots.txt`. `_source/` is untracked so GitHub Pages was never affected.
4. **og:image / twitter:image were relative paths**, which no social platform can resolve -- shared
   links previewed with no image. Added `brand.siteUrl`; the build now absolutises just those two
   meta tags (variant-blue gets its own prefix) and leaves the identical filename relative where it
   appears as a normal `<img src>`. Blank siteUrl warns instead of silently shipping broken tags.
5. **Social links are still template defaults** (bare facebook/instagram/twitter homepages), and the
   worst instance is the four doctor cards -- an Instagram icon under a named clinician that lands
   on a login wall. Cannot be fixed without the real URLs, so the build now warns by name. Setting a
   social value to "" is the documented way to drop those anchors.
6. **`Serve.ps1` died on any HEAD request.** It set Content-Length then wrote the body anyway ->
   ProtocolViolationException killed the whole listener; this is why the preview server kept
   exiting mid-verification. HEAD now sends headers only, and each request is wrapped so one bad
   request cannot take the server down. Verified: GET 200, HEAD 200, HEAD-404, server still alive.

**Zip note:** Windows PowerShell 5.1 `Compress-Archive` writes entry paths with BACKSLASHES, which
violates the ZIP spec. Extracted on macOS/Linux the tree collapses into flat files literally named
`assets\css\lumora.css`. Always build the archive with explicit `CreateEntryFromFile` and
`.Replace('\','/')` on the relative path. Verified by extracting and serving the result.

## Synced with the real minteddental.com (19 Aug 2026)

Read the live practice site and brought this one in line. All copy below is theirs, not invented.

**Three new pages**, generated by `tools/Build-ContentPages.ps1` from body fragments in
`_content/`. The generator copies the real nav/footer/scripts from `service.html`, so a chrome
change flows into them automatically. It also converts "Minted ..." back to the "Lumora" token
on the way into `_source/`, keeping the pages re-brandable.
- `faq.html` - 28 questions in six groups. The General Dentistry and Invisalign answers are
  verbatim from their service pages; the rest are drawn from their insurance, membership,
  emergency and contact pages. Native `<details>`/`<summary>` accordions: no JS, keyboard
  accessible, 61px minimum tap target, smooth expand via `::details-content` +
  `interpolate-size` where supported (snaps open otherwise), and honours reduced-motion.
- `insurance.html` - their copy plus all 27 in-network plans.
- `membership.html` - the eight membership benefits and the three-step enrolment.

**Services** went from 4 template placeholders to their real 7 (General, Emergency, Cosmetic,
Invisalign, Restorative, Holistic, Whitening) via `tools/Set-Services.ps1`, which drives both
the home cards and the services accordion from one table. It also gives each accordion block a
unique id, fixing the duplicate-id defect inherited from the Webflow export.

**Contacts**: two clinics wired end to end - Desert Ridge (480) 400-1794 / hello@, Scottsdale
(480) 697-4997 / smile@. Both emails are config-driven (`contact.email`, `contact.emailSecondary`)
and a `contact.clinics` array records the full details.

**Hours** restored to the real published ones (Mon 9-5, Tue 9-6, Wed 9-4, Thu 8-4, Fri 8-3,
weekend closed) after confirming with the user - the template hours had the clinic open at
weekends.

**Social** now uses their real profiles. Twitter is set to `""` because they have no public
account, and the build now STRIPS those anchors rather than linking to a login wall.

### Two real bugs found and fixed while doing this

1. **Chained social replacement.** Two rules per network meant the first rule's output
   (`https://www.instagram.com/minteddental`) still contained the second rule's search text,
   producing `.../minteddental/minteddental` on 16 links. Now exactly ONE rule per network,
   with the insecure `http://` variants normalised in `_source/` instead.
2. **Double-encoded UTF-8 appeared in four masters** (48 sequences: `'`, `"`, `"`, star).
   Verified against `git show HEAD` that the originals were correct, repaired with the new
   `tools/Repair-Encoding.ps1`, and confirmed the result now matches HEAD byte-for-byte.
   **I could not reproduce the cause** - perl in-place, the .NET UTF-8 read/write helper,
   Set-Services and Add-ImageDimensions were each replayed against a clean copy from git and
   all left it intact. Because the cause is unknown, `Build-Site.ps1` now FAILS the build on
   any mojibake in the output (verified by injecting a sequence). Do not downgrade that to a
   warning until the cause is understood.

Mobile: verified 0 horizontal overflow on all 8 tested pages at 375px, and the new grids
reflow 1 -> 3 -> 5 columns with no media queries.
