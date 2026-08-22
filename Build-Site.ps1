<#
.SYNOPSIS
  Rebuilds the whole website from the pristine _source/ snapshot using brand.config.json.

.DESCRIPTION
  Edit brand.config.json, then run this. It ALWAYS reads from _source/ (never from its own
  previous output), so running it 100 times gives the exact same result and can never
  progressively corrupt the site.

  All file I/O is UTF-8 without BOM. That is what prevents the smart-quote / star-icon
  mojibake that corrupted earlier edits.

.EXAMPLE
  .\Build-Site.ps1
  .\Build-Site.ps1 -DryRun
  .\Build-Site.ps1 -Restore
#>
[CmdletBinding()]
param(
    [string]$Config = "brand.config.json",
    [switch]$DryRun,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$p) {
    return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}

function Write-Text([string]$p, [string]$s) {
    $dir = Split-Path -Parent $p
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($p, $s, $utf8NoBom)
}

function ConvertTo-Rgb([string]$hex) {
    $h = $hex.TrimStart('#')
    if ($h.Length -eq 3) { $h = "$($h[0])$($h[0])$($h[1])$($h[1])$($h[2])$($h[2])" }
    return @(
        [Convert]::ToInt32($h.Substring(0, 2), 16),
        [Convert]::ToInt32($h.Substring(2, 2), 16),
        [Convert]::ToInt32($h.Substring(4, 2), 16)
    )
}

function ConvertTo-Rgba([string]$hex, [string]$alpha) {
    $c = ConvertTo-Rgb $hex
    return "rgba($($c[0]),$($c[1]),$($c[2]),$alpha)"
}

# --------------------------------------------------------------- sanity checks
if (-not (Test-Path "_source")) {
    Write-Host "ERROR: _source/ is missing. It holds the pristine, never-edited site." -ForegroundColor Red
    Write-Host "Recover with:  git checkout -- .   then re-create the _source snapshot." -ForegroundColor Red
    exit 1
}

$pages = @('404', 'about', 'blog', 'cookies', 'faq', 'index', 'insurance', 'licenses',
    'membership', 'privacy', 'service', 'terms')

# --------------------------------------------------------------- restore mode
if ($Restore) {
    foreach ($p in $pages) {
        Write-Text "$p.html" (Read-Text "_source\$p.html")
        Write-Text "variant-blue\$p.html" (Read-Text "_source\variant-blue\$p.html")
    }
    Write-Text "assets\css\lumora.css" (Read-Text "_source\assets\css\lumora.css")
    Write-Text "variant-blue\assets\css\lumora.css" (Read-Text "_source\variant-blue\assets\css\lumora.css")
    Write-Host "Restored the original site from _source/." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $Config)) {
    Write-Host "ERROR: $Config not found." -ForegroundColor Red
    exit 1
}
try {
    $cfg = Read-Text $Config | ConvertFrom-Json
}
catch {
    Write-Host ""
    Write-Host "ERROR: $Config is not valid JSON, so nothing was built." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message.Split([char]10)[0])" -ForegroundColor DarkGray
    Write-Host "  Usual cause: a trailing comma after the last item in a { } block," -ForegroundColor Yellow
    Write-Host "  a missing comma between items, or a smart quote pasted from a document." -ForegroundColor Yellow
    Write-Host "  Your existing site at the repo root is untouched." -ForegroundColor Green
    exit 1
}

# --------------------------------------------------------------- config validation
# A missing key used to be silent: Add-Rule skips null values, so deleting (say) the whole
# "booking" block still "succeeded" and shipped 11 raw calendly.com links to the live pages.
# Fail loudly instead, naming exactly what is missing.
$required = @(
    'brand.name', 'brand.shortName', 'brand.copyrightYear',
    'contact.phoneDisplay', 'contact.phoneTel', 'contact.email',
    'booking.url', 'booking.buttonText',
    'theme.primary', 'theme.primaryHover', 'theme.primaryMuted',
    'theme.dark', 'theme.darkAlt', 'theme.darker', 'theme.accent'
)
$missingKeys = @()
foreach ($path in $required) {
    $parts = $path.Split('.')
    $node = $cfg
    foreach ($p in $parts) {
        if ($null -eq $node) { break }
        $node = $node.PSObject.Properties[$p].Value
    }
    if ($null -eq $node -or ([string]$node).Trim() -eq '') { $missingKeys += $path }
}
if ($missingKeys.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: $Config is missing required setting(s):" -ForegroundColor Red
    foreach ($k in $missingKeys) { Write-Host "  - $k" -ForegroundColor Red }
    Write-Host "  Without these the build leaves raw template placeholders (calendly.com links," -ForegroundColor Yellow
    Write-Host "  'Lumora', the old phone number) in the live pages. Nothing was built." -ForegroundColor Yellow
    Write-Host "  Your existing site at the repo root is untouched." -ForegroundColor Green
    exit 1
}

# --------------------------------------------------------------- deploy-facing checks
$siteUrl = ([string]$cfg.brand.siteUrl).TrimEnd('/')

# Social links ship as bare platform homepages in the template. Left unfilled they are worse
# than absent: the doctor cards attach an Instagram/X icon to a NAMED clinician, so a visitor
# clicking it lands on a login wall having been told that person has a profile there.
# Setting a social value to "" removes those anchors entirely; leaving the placeholder warns.
$socialPlaceholders = @{
    facebook  = 'https://www.facebook.com'
    instagram = 'https://www.instagram.com'
    twitter   = 'https://www.twitter.com'
}
$unfilledSocial = @()
$emptySocial = @()
foreach ($k in $socialPlaceholders.Keys) {
    $v = [string]$cfg.social.$k
    if ($v -eq $socialPlaceholders[$k]) { $unfilledSocial += $k }
    elseif ($v.Trim() -eq '') { $emptySocial += $k }
}

# --------------------------------------------------------------- html escaping
# Config values are pasted straight into markup. A clinic called "Smith & Jones Dental" was
# emitting a raw & into <title> and every heading. Escape the three characters that matter,
# but leave existing entities (&amp; &copy; &#39;) alone so nothing gets double-escaped.
function Protect-Html($s) {
    if ($null -eq $s) { return $s }
    $t = [string]$s
    $t = [regex]::Replace($t, '&(?!(?:[a-zA-Z][a-zA-Z0-9]{1,10}|#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6});)', '&amp;')
    return ($t -replace '<', '&lt;' -replace '>', '&gt;')
}

# --------------------------------------------------------------- replacement map
# ORDER MATTERS. Most specific first.
$map = New-Object System.Collections.Generic.List[object]

function Add-Rule([string]$from, $to) {
    if ($null -eq $to) { return }
    $s = [string]$to
    if ($s -eq '' -or $s -eq $from) { return }
    $map.Add([pscustomobject]@{ From = $from; To = $s })
}

# 0. generated brand marks (logo + favicon drawn from brand.shortName and theme colours)
$genLogo = $false
if ($cfg.assets -and $null -ne $cfg.assets.generateLogo) { $genLogo = [bool]$cfg.assets.generateLogo }

$logoLight = $cfg.assets.logo
$logoDark = $cfg.assets.logoDark
$faviconPath = $cfg.assets.favicon

if ($genLogo) {
    $logoLight = 'assets/img/brand-logo.svg'
    $logoDark = 'assets/img/brand-logo-dark.svg'
    $faviconPath = 'assets/img/brand-favicon.svg'
}

# 1. asset paths (all lowercase, so the Brand rules below can never touch them)
Add-Rule 'assets/img/lumora-logo-dark.svg' $logoDark
Add-Rule 'assets/img/lumora-logo.svg'      $logoLight
Add-Rule 'assets/img/favicon.svg'          $faviconPath
Add-Rule 'assets/img/webclip.png'          $cfg.assets.webclip

# 2. booking + contact
Add-Rule 'https://calendly.com/shreyasrajsony11' $cfg.booking.url
# both label variants exist in the template; unify them on booking.buttonText.
# Verified: every occurrence sits inside a .button_text div, never in body copy.
Add-Rule 'Book An Appointment'                   (Protect-Html $cfg.booking.buttonText)
Add-Rule 'Get Appointment'                       (Protect-Html $cfg.booking.buttonText)
Add-Rule 'Book Appointment'                      (Protect-Html $cfg.booking.buttonText)
Add-Rule 'hello@lumoradental.com'                $cfg.contact.email
Add-Rule 'smile@lumoradental.com'                $cfg.contact.emailSecondary
# The template ships two tel: formats, one of them spaced. Both must resolve to the
# dial-safe number BEFORE the display-format rule below, or the space leaks into the href.
Add-Rule 'tel:+91 9307512816'                    ("tel:" + $cfg.contact.phoneTel)
Add-Rule 'tel:+919307512816'                     ("tel:" + $cfg.contact.phoneTel)
Add-Rule '+91 9307512816'                        (Protect-Html $cfg.contact.phoneDisplay)

# 2b. the careers "Apply Now" Google Form on about.html. This must NOT fall back to the
#     booking URL -- a job application should not open appointment scheduling.
$careersUrl = $cfg.careers.url
if (-not $careersUrl) { $careersUrl = 'mailto:' + $cfg.contact.email + '?subject=Careers' }
Add-Rule 'https://docs.google.com/forms/' $careersUrl

# 3. social. EXACTLY ONE rule per network. The template also shipped insecure
#    http://instagram.com/ and http://twitter.com/ variants; those are now normalised in
#    _source/ to the https form instead of getting their own rules. Two rules per network
#    was a real bug: the first rule's output ("https://www.instagram.com/minteddental")
#    still contains the second rule's search text, so the handle was appended twice
#    ("/minteddental/minteddental"). Keep it one rule per network.
Add-Rule 'https://www.facebook.com'  $cfg.social.facebook
Add-Rule 'https://www.instagram.com' $cfg.social.instagram
Add-Rule 'https://www.twitter.com'   $cfg.social.twitter

# 3b. copyright year. MUST be anchored to the copyright string and MUST run before the brand
#     rules below (which rewrite the trailing "Lumora Dental"). A bare '2026' rule instead
#     matches the CSS cache-bust token (?v=20260614f) and digits inside SVG path data
#     (8.20265 -> 8.20275), silently corrupting a phone icon. Verified by test.
Add-Rule '&copy; 2026 Lumora Dental' ('&copy; ' + $cfg.brand.copyrightYear + ' Lumora Dental')

# 4. brand name. "Lumora Dental" MUST come before bare "Lumora".
#    Replace() is case-sensitive, so lumora.css / lumora-logo.svg / lumoraLead are safe.
Add-Rule 'Lumora Dental' (Protect-Html $cfg.brand.name)
Add-Rule 'Lumora'        (Protect-Html $cfg.brand.shortName)

# 5. credit
Add-Rule 'RapidXAI' (Protect-Html $cfg.brand.credit)

# 6. free-form copy overrides -> brand.config.json "text" block
# These run AFTER the brand rename, so the page no longer says "Lumora" by the time they
# apply. Someone copying a phrase out of _source/ would write the Lumora wording and get
# silence. Translate such keys into the current brand wording so both forms work, and
# remember them so an unmatched rule can be reported instead of failing quietly.
$userTextKeys = @()
if ($cfg.text) {
    foreach ($prop in $cfg.text.PSObject.Properties) {
        if ($prop.Name -like '_*') { continue }
        $key = $prop.Name
        if ($key -like '*Lumora*') {
            $key = $key.Replace('Lumora Dental', [string]$cfg.brand.name).Replace('Lumora', [string]$cfg.brand.shortName)
        }
        Add-Rule $key (Protect-Html $prop.Value)
        # only worth reporting if it would actually change something; an entry whose value
        # equals its key is a deliberate no-op placeholder and Add-Rule skips it by design
        $val = [string]$prop.Value
        if ($val -ne '' -and $val -ne $key) { $userTextKeys += $key }
    }
}

# --------------------------------------------------------------- theme
$t = $cfg.theme

$tealMap = [ordered]@{
    '#24a3b1' = $t.primary
    '#1c91a1' = $t.primaryHover
    '#587d81' = $t.primaryMuted
    '#022f34' = $t.darkAlt
    '#002124' = $t.darker
    '#011f23' = $t.dark
    '#7fe3ef' = $t.accent
}

# variant-blue can carry its own palette. If "themeVariantBlue" is absent from the
# config, it simply inherits the main theme.
$tb = $t
if ($cfg.themeVariantBlue) { $tb = $cfg.themeVariantBlue }

$blueMap = [ordered]@{
    '#2f80ff' = $tb.primary
    '#1f6fe5' = $tb.primaryHover
    '#5b76a8' = $tb.primaryMuted
    '#0b2a55' = $tb.darkAlt
    '#07203f' = $tb.darker
    '#06182e' = $tb.dark
    '#6aa8ff' = $tb.accent
    '#24a3b1' = $tb.primary
    '#011f23' = $tb.dark
}

function Build-ThemeBlock($t) {
    $g1 = ConvertTo-Rgba $t.darkAlt '.86'
    $g2 = ConvertTo-Rgba $t.primary '.80'
    $sh = ConvertTo-Rgba $t.dark '.30'
    # Wordmark beside the logo. Defaults to the logo's own green (theme.primary); the main
    # navbar is transparent over a dark hero, so brand.wordmarkColorOnDark overrides it there.
    $wm = $cfg.brand.wordmarkColor
    if (-not $wm) { $wm = $t.primary }
    $wmDark = $cfg.brand.wordmarkColorOnDark
    if (-not $wmDark) { $wmDark = $wm }
    return @"

/* =====================================================================
   GENERATED BY Build-Site.ps1 - do not edit below this line.
   Change colours in brand.config.json -> "theme", then re-run the build.
   ===================================================================== */
:root{
  --primitive-color--primary-400: $($t.primaryMuted);
  --primitive-color--primary-500: $($t.primary);
  --primitive-color--primary-600: $($t.primaryHover);
  --primitive-color--primary-700: $($t.darkAlt);
  --primitive-color--primary-800: $($t.darker);
  --primitive-color--primary-900: $($t.dark);
  --brand-accent: $($t.accent);
}
.text-highlighted{color:$($t.primary);}
.section_team .text-highlighted{color:$($t.accent)!important;}
.testimonial-slider_card{
  background-image:linear-gradient(160deg, $g1, $g2), url('../img/gen_testimonial-bg.jpg')!important;
  background-size:cover!important;background-position:center!important;background-repeat:no-repeat!important;
}
.section_footer{background:$($t.dark)!important;border-top:3px solid $($t.primary)!important;}
.section_footer .footer-external_link{color:$($t.primary)!important;}
.button_primary{box-shadow:0 6px 24px $sh;}

/* four doctors: keep them on one desktop row instead of orphaning the fourth card.
   Tablet/mobile already fall back to 2 columns, giving a clean 2x2. */
@media(min-width:992px){.team_list{grid-template-columns:repeat(4,1fr);}}

/* Brand name beside the logo, in the logo's own serif face and colour.
   Fraunces matches the wordmark drawn in the badge; Georgia is the offline fallback. */
.brand_wordmark{
  font-family:'Fraunces',Georgia,'Times New Roman',serif;
  font-weight:600;font-size:1.4rem;line-height:1;letter-spacing:-.01em;
  white-space:nowrap;color:$wmDark;
}
.navbar_logo{max-width:none!important;width:auto!important;display:flex!important;align-items:center;gap:10px;}
/* legal pages sit on white, so the wordmark uses the logo green there */
.legal-nav a{display:inline-flex;align-items:center;gap:9px;text-decoration:none;}
.legal-nav .brand_wordmark{color:$wm;}
@media(max-width:991px){.brand_wordmark{font-size:1.15rem;}}
@media(max-width:479px){.brand_wordmark{display:none;}}

/* Hero size restore. Removing the lead-capture card cost the hero 344px (320px card +
   24px margin), leaving it noticeably short. These min-heights are the measured original
   content heights at each breakpoint, so the hero keeps its full size without the form. */
.home-hero_content{min-height:631px;}
@media(max-width:991px){.home-hero_content{min-height:677px;}}
@media(max-width:767px){.home-hero_content{min-height:620px;}}

/* Hero carousel: slide + fade instead of a plain crossfade. */
.hero-carousel-img{
  opacity:0;transform:translateX(6%);
  transition:opacity 1.1s ease, transform 1.5s cubic-bezier(.22,.61,.36,1);
}
.hero-carousel-img.is-active{opacity:1;transform:translateX(0);}
.hero-carousel-img.is-leaving{opacity:0;transform:translateX(-6%);}
@media(prefers-reduced-motion:reduce){
  .hero-carousel-img{transition:opacity .4s ease;transform:none;}
  .hero-carousel-img.is-active,.hero-carousel-img.is-leaving{transform:none;}
}

/* ---------- content pages: FAQ / insurance / membership ---------- */
/* Sized in rem and clamp() so everything reflows on a phone without a media query. */
.info-prose{max-width:70ch;margin:0 auto 2.5rem;}
.info-prose p{margin:0 0 1.1rem;font-size:1.0625rem;line-height:1.7;}
.inline-link{color:$($t.primary);text-decoration:underline;text-underline-offset:3px;}
.inline-link:hover{color:$($t.primaryHover);}

/* jump nav: horizontally scrollable on narrow screens instead of wrapping into a wall */
.faq-jump{display:flex;flex-wrap:wrap;gap:.5rem;justify-content:center;margin:0 0 3rem;}
.faq-jump_link{
  display:inline-block;padding:.5rem 1rem;border-radius:999px;font-size:.9rem;font-weight:600;
  text-decoration:none;color:$($t.dark);background:$($t.accent);opacity:.9;transition:opacity .2s,transform .2s;
}
.faq-jump_link:hover{opacity:1;transform:translateY(-1px);}

.faq-acc_group{max-width:60rem;margin:0 auto 3.5rem;scroll-margin-top:6rem;}
.faq-acc_heading{font-size:clamp(1.5rem,3vw,2rem);margin:0 0 1.25rem;color:$($t.dark);}
.faq-acc_item{
  border:1px solid rgba(0,0,0,.10);border-radius:14px;background:#fff;
  margin-bottom:.75rem;overflow:hidden;transition:border-color .2s,box-shadow .2s;
}
.faq-acc_item[open]{border-color:$($t.primary);box-shadow:0 4px 20px rgba(0,0,0,.06);}
.faq-acc_q{
  cursor:pointer;list-style:none;padding:1.15rem 3rem 1.15rem 1.25rem;position:relative;
  font-weight:600;font-size:1.0625rem;line-height:1.45;color:$($t.dark);
  /* generous tap target on touch devices */
  min-height:3rem;display:flex;align-items:center;
}
.faq-acc_q::-webkit-details-marker{display:none;}
.faq-acc_q::after{
  content:"";position:absolute;right:1.25rem;top:50%;width:.65rem;height:.65rem;
  border-right:2px solid $($t.primary);border-bottom:2px solid $($t.primary);
  transform:translateY(-70%) rotate(45deg);transition:transform .25s ease;
}
.faq-acc_item[open] .faq-acc_q::after{transform:translateY(-30%) rotate(-135deg);}
.faq-acc_q:focus-visible{outline:3px solid $($t.primary);outline-offset:-3px;}
.faq-acc_a{padding:0 1.25rem 1.25rem;}
.faq-acc_a p{margin:0;font-size:1rem;line-height:1.7;color:#3d4a45;}

/* Smooth expand. Native <details> snaps open; ::details-content + interpolate-size lets it
   animate to auto height. Browsers without support simply snap open as before - the panel
   still works, it just is not animated. Honours reduced-motion. */
@supports (interpolate-size: allow-keywords){
  :root{interpolate-size:allow-keywords;}
}
@supports selector(::details-content){
  .faq-acc_item::details-content{
    block-size:0;overflow:hidden;
    transition:block-size .32s cubic-bezier(.4,0,.2,1), content-visibility .32s allow-discrete;
  }
  .faq-acc_item[open]::details-content{block-size:auto;}
}
@media (prefers-reduced-motion: reduce){
  .faq-acc_item::details-content{transition:none;}
  .faq-acc_q::after{transition:none;}
}

/* plan list: auto-fits from 1 column on a phone up to 4 on a desktop, no breakpoints */
.plan-grid{
  list-style:none;padding:0;margin:0 0 3rem;display:grid;gap:.6rem;
  grid-template-columns:repeat(auto-fill,minmax(min(100%,14rem),1fr));
}
.plan-grid_item{
  background:#fff;border:1px solid rgba(0,0,0,.09);border-radius:10px;
  padding:.85rem 1rem;font-size:.95rem;font-weight:500;color:$($t.dark);
}
.insurance_heading{font-size:clamp(1.5rem,3vw,2.1rem);margin:0 0 .75rem;color:$($t.dark);}
.insurance_note{max-width:70ch;margin:0 0 1.5rem;font-size:.95rem;color:#5a6963;}

.callout-card{
  display:flex;flex-wrap:wrap;gap:1.25rem;align-items:center;justify-content:space-between;
  background:$($t.dark);color:#fff;border-radius:18px;padding:1.75rem;margin:0 0 3rem;
}
.callout-card_title{font-size:1.25rem;font-weight:700;margin-bottom:.35rem;}
.callout-card_body p{margin:0;opacity:.85;line-height:1.6;}
.callout-card_btn{
  flex:0 0 auto;background:$($t.primary);color:#fff;text-decoration:none;font-weight:600;
  padding:.85rem 1.5rem;border-radius:999px;transition:background .2s,transform .2s;
}
.callout-card_btn:hover{background:$($t.primaryHover);transform:translateY(-1px);}

.benefit-grid{display:grid;gap:1.25rem;grid-template-columns:repeat(auto-fit,minmax(min(100%,20rem),1fr));margin:0 0 3.5rem;}
.benefit-card{background:#fff;border:1px solid rgba(0,0,0,.09);border-radius:18px;padding:1.75rem;}
.benefit-card.is-featured{border-color:$($t.primary);box-shadow:0 8px 30px rgba(0,0,0,.07);}
.benefit-card_tag{font-size:.8rem;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:$($t.primary);margin-bottom:1rem;}
.benefit-list{list-style:none;padding:0;margin:0;}
.benefit-list_item{position:relative;padding-left:1.75rem;margin-bottom:.8rem;line-height:1.6;color:$($t.dark);}
.benefit-list_item::before{
  content:"";position:absolute;left:0;top:.45rem;width:.55rem;height:.3rem;
  border-left:2px solid $($t.primary);border-bottom:2px solid $($t.primary);transform:rotate(-45deg);
}

.step-list{list-style:none;padding:0;margin:0 0 3rem;display:grid;gap:1.25rem;}
.step-list_item{display:flex;gap:1.1rem;align-items:flex-start;background:#fff;border:1px solid rgba(0,0,0,.09);border-radius:16px;padding:1.4rem;}
.step-list_num{
  flex:0 0 auto;width:2.25rem;height:2.25rem;border-radius:50%;background:$($t.primary);color:#fff;
  display:flex;align-items:center;justify-content:center;font-weight:700;
}
.step-list_title{font-weight:700;margin-bottom:.3rem;color:$($t.dark);}
.step-list_body p{margin:0;line-height:1.65;color:#3d4a45;}

.section_faqpage,.section_insurance,.section_membership{background:#f7faf8;}

/* per-location email on the about-page location cards */
.location_email{
  display:block;margin-top:4px;color:#fff;text-decoration:none;font-size:.9rem;opacity:.9;
  overflow-wrap:anywhere;
}
.location_email:hover{opacity:1;text-decoration:underline;}

/* per-location phone on the about-page location cards */
.location_phone{
  display:inline-block;margin-top:6px;color:#fff;text-decoration:none;
  font-weight:600;font-size:.95rem;letter-spacing:.01em;
  border-bottom:1px solid rgba(255,255,255,.45);padding-bottom:1px;
}
.location_phone:hover{border-bottom-color:#fff;}
"@
}

function Build-LogoBlock([string]$style) {
    if ($style -ne 'badge') { return '' }
    return @"

/* square / circular logo sizing (assets.logoStyle = "badge") */
.navbar_logo .logo_image{height:48px!important;width:48px!important;object-fit:contain;border-radius:50%;}
.brand_logo,.section_footer .brand_logo,.section_footer .logo_image{height:72px!important;width:72px!important;object-fit:contain;border-radius:50%;}
@media(max-width:991px){
  .navbar_logo .logo_image{height:42px!important;width:42px!important;}
  .brand_logo,.section_footer .brand_logo{height:60px!important;width:60px!important;}
}
"@
}

# --------------------------------------------------------------- brand marks
# Regenerates the wordmark + favicon from brand.shortName and the theme colours, so a
# rebrand actually changes the visible logo instead of leaving the old one behind.
$toothPath = 'M17 2.2c5.4 0 9.4 3.8 9.4 9.1 0 4.1-1.3 6.6-2.6 11.2-1 3.5-1.7 7.3-3.9 7.3-1.8 0-1.9-3.1-2.9-3.1s-1.1 3.1-2.9 3.1c-2.2 0-2.9-3.8-3.9-7.3C8.9 17.9 7.6 15.4 7.6 11.3 7.6 6 11.6 2.2 17 2.2Z'
$toothPathBig = 'M32 12c8.2 0 14.2 5.7 14.2 13.8 0 6.2-2 10-3.9 16.9-1.5 5.3-2.6 11-5.9 11-2.7 0-2.9-4.7-4.4-4.7s-1.7 4.7-4.4 4.7c-3.3 0-4.4-5.7-5.9-11C19.8 35.8 17.8 32 17.8 25.8 17.8 17.7 23.8 12 32 12Z'

function Escape-Xml([string]$s) {
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Build-Wordmark($t, [string]$word, [string]$fullName, [string]$textColor, [string]$c1, [string]$c2, [string]$gid) {
    $w = [int](38 + ($word.Length * 11.6) + 10)
    if ($w -lt 120) { $w = 120 }
    $safe = Escape-Xml $word
    $safeFull = Escape-Xml $fullName
    return @"
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="34" viewBox="0 0 $w 34" fill="none" role="img" aria-label="$safeFull">
  <defs>
    <linearGradient id="$gid" x1="0" y1="0" x2="34" y2="34" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="$c1"/>
      <stop offset="1" stop-color="$c2"/>
    </linearGradient>
  </defs>
  <path d="$toothPath" fill="url(#$gid)"/>
  <circle cx="22.4" cy="9.4" r="2.1" fill="#ffffff" opacity="0.88"/>
  <text x="38" y="23" font-family="Sora, 'Helvetica Neue', Arial, sans-serif" font-size="20" font-weight="600" letter-spacing="-0.3" fill="$textColor">$safe</text>
</svg>
"@
}

function Build-Favicon($t) {
    return @"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">
  <defs>
    <linearGradient id="fv" x1="0" y1="0" x2="64" y2="64" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="$($t.primary)"/>
      <stop offset="1" stop-color="$($t.dark)"/>
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="16" fill="url(#fv)"/>
  <path d="$toothPathBig" fill="#ffffff"/>
  <circle cx="40" cy="24" r="3.4" fill="$($t.primary)"/>
</svg>
"@
}

if ($genLogo -and -not $DryRun) {
    $word = $cfg.brand.shortName
    if (-not $word) { $word = $cfg.brand.name }

    $lightSvg = Build-Wordmark $t $word $cfg.brand.name $t.dark    $t.primary $t.darkAlt 'bm-l'
    $darkSvg = Build-Wordmark $t $word $cfg.brand.name '#ffffff'  $t.accent  $t.primary 'bm-d'
    $favSvg = Build-Favicon $t

    foreach ($base in @('assets\img', 'variant-blue\assets\img')) {
        if (-not (Test-Path $base)) { continue }
        Write-Text "$base\brand-logo.svg"      $lightSvg
        Write-Text "$base\brand-logo-dark.svg" $darkSvg
        Write-Text "$base\brand-favicon.svg"   $favSvg
    }
    Write-Host "  ok    generated brand marks (logo, logo-dark, favicon)" -ForegroundColor Green
}

# --------------------------------------------------------------- apply
$script:ruleHits = @{}
function Invoke-Rules([string]$text) {
    foreach ($r in $map) {
        if ($text.Contains($r.From)) {
            if (-not $script:ruleHits.ContainsKey($r.From)) { $script:ruleHits[$r.From] = 0 }
            $script:ruleHits[$r.From] += 1
        }
        $text = $text.Replace($r.From, $r.To)
    }
    return $text
}

function Invoke-HexSwap([string]$text, $hexMap) {
    foreach ($k in $hexMap.Keys) {
        $v = $hexMap[$k]
        if (-not $v) { continue }
        $text = [regex]::Replace($text, [regex]::Escape($k), $v, 'IgnoreCase')
    }
    return $text
}

$targets = @()
foreach ($p in $pages) { $targets += , @("_source\$p.html", "$p.html", 'html', $null) }
$targets += , @("_source\assets\css\lumora.css", "assets\css\lumora.css", 'css', $tealMap, $t)

$doBlue = $true
if ($cfg.build -and $null -ne $cfg.build.includeVariantBlue) { $doBlue = [bool]$cfg.build.includeVariantBlue }
if ($doBlue) {
    foreach ($p in $pages) { $targets += , @("_source\variant-blue\$p.html", "variant-blue\$p.html", 'html', $null) }
    $targets += , @("_source\variant-blue\assets\css\lumora.css", "variant-blue\assets\css\lumora.css", 'css', $blueMap, $tb)
}

Write-Host ""
Write-Host "Building '$($cfg.brand.name)' from _source/  ($($map.Count) text rules)" -ForegroundColor Cyan
Write-Host ""

$changedTotal = 0

# Cache-bust: the pages ship a hard-coded "lumora.css?v=20260614f". Nothing ever bumped it, so
# after a colour or logo change a browser kept serving the cached stylesheet and the edit looked
# like it had done nothing. Hash the generated CSS and stamp that into every page instead.
# CSS targets are processed first so the hash exists before any page is written.
$cssHash = @{}
function Get-ShortHash([string]$s) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))
    $md5.Dispose()
    return (([System.BitConverter]::ToString($bytes)) -replace '-', '').Substring(0, 10).ToLower()
}
$targets = @($targets | Where-Object { $_[2] -eq 'css' }) + @($targets | Where-Object { $_[2] -ne 'css' })

foreach ($tgt in $targets) {
    $src = $tgt[0]
    $out = $tgt[1]
    $kind = $tgt[2]
    $hexMap = $tgt[3]
    $themeFor = $t
    if ($tgt.Count -gt 4 -and $tgt[4]) { $themeFor = $tgt[4] }
    $variantKey = if ($out -like 'variant-blue*') { 'blue' } else { 'root' }

    if (-not (Test-Path $src)) {
        Write-Host "  skip (missing source): $src" -ForegroundColor Yellow
        continue
    }

    $orig = Read-Text $src
    $new = Invoke-Rules $orig
    if ($kind -eq 'css') {
        $new = Invoke-HexSwap $new $hexMap
        $new = $new + (Build-ThemeBlock $themeFor) + (Build-LogoBlock $cfg.assets.logoStyle)
        $cssHash[$variantKey] = Get-ShortHash $new
    }
    else {
        $h = $cssHash[$variantKey]
        if ($h) { $new = [regex]::Replace($new, 'lumora\.css\?v=[^"]*', "lumora.css?v=$h") }

        # A social network set to "" in config means "we have no account there". Remove the
        # whole <a> rather than leaving an icon that lands on a login wall -- which is worst
        # on the doctor cards, where it implies a named clinician has that profile.
        foreach ($net in $emptySocial) {
            $host_ = switch ($net) {
                'facebook' { 'www\.facebook\.com' }
                'instagram' { '(?:www\.)?instagram\.com' }
                'twitter' { '(?:www\.)?twitter\.com' }
            }
            $new = [regex]::Replace($new, '\s*<a\b[^>]*href="https?://' + $host_ + '[^"]*"[^>]*>.*?</a>', '', 'Singleline')
        }

        # og:image / twitter:image must be ABSOLUTE. The template ships them as relative
        # "assets/img/..." paths, which every social platform fails to resolve, so shared links
        # preview with no image. Only the meta tags are touched -- the same filename also appears
        # as a normal <img src> further down the page and must stay relative there.
        if ($siteUrl) {
            $prefix = $siteUrl
            if ($variantKey -eq 'blue') { $prefix = "$siteUrl/variant-blue" }
            $new = [regex]::Replace(
                $new,
                '(<meta content=")(assets/[^"]+)("\s+(?:property="og:image"|name="twitter:image")\s*/?>)',
                { param($m) $m.Groups[1].Value + $prefix + '/' + $m.Groups[2].Value + $m.Groups[3].Value })
        }
    }

    $n = 0
    foreach ($r in $map) {
        $n += ([regex]::Matches($orig, [regex]::Escape($r.From))).Count
    }
    $changedTotal += $n

    if ($DryRun) {
        Write-Host ("  [dry] {0,-36} {1} replacements" -f $out, $n)
    }
    else {
        Write-Text $out $new
        Write-Host ("  ok    {0,-36} {1} replacements" -f $out, $n) -ForegroundColor Green
    }
}

# --------------------------------------------------------------- assets: check + mirror
$assetList = @($cfg.assets.logo, $cfg.assets.logoDark, $cfg.assets.favicon, $cfg.assets.webclip) |
Select-Object -Unique

foreach ($a in $assetList) {
    if (-not $a -or ($a -match '^https?://')) { continue }
    if (-not (Test-Path $a)) {
        Write-Host "  WARNING: asset referenced but not found on disk -> $a" -ForegroundColor Yellow
        continue
    }
    # variant-blue pages use the same relative paths, so mirror the file across
    if ($doBlue -and -not $DryRun) {
        $mirror = Join-Path 'variant-blue' $a
        $mirrorDir = Split-Path -Parent $mirror
        if (-not (Test-Path $mirrorDir)) { New-Item -ItemType Directory -Force -Path $mirrorDir | Out-Null }
        Copy-Item $a $mirror -Force
    }
}

# --------------------------------------------------------------- unmatched copy overrides
# A "text" entry that matches nothing is the quietest failure in this system: the build reports
# success and the page is simply unchanged. Name the ones that never matched.
if (-not $DryRun -and $userTextKeys.Count -gt 0) {
    $dead = @($userTextKeys | Where-Object { -not $script:ruleHits.ContainsKey($_) })
    if ($dead.Count -gt 0) {
        Write-Host ""
        Write-Host "WARNING: these `"text`" overrides matched nothing and did nothing:" -ForegroundColor Yellow
        foreach ($d in $dead) {
            $show = if ($d.Length -gt 68) { $d.Substring(0, 65) + '...' } else { $d }
            Write-Host "  `"$show`"" -ForegroundColor Yellow
        }
        Write-Host "  The left-hand side must match the page text exactly, including punctuation" -ForegroundColor DarkGray
        Write-Host "  and capitalisation. Curly quotes are a common mismatch." -ForegroundColor DarkGray
    }
}

# --------------------------------------------------------------- deploy-readiness warnings
if (-not $DryRun) {
    if (-not $siteUrl) {
        Write-Host ""
        Write-Host "NOTE: brand.siteUrl is blank, so og:image / twitter:image stay relative." -ForegroundColor Yellow
        Write-Host "  Shared links will preview WITHOUT an image on Facebook, LinkedIn, WhatsApp and X." -ForegroundColor DarkGray
        Write-Host "  Set it to your live URL (e.g. https://minteddental.com) and rebuild." -ForegroundColor DarkGray
    }
    if ($unfilledSocial.Count -gt 0) {
        Write-Host ""
        Write-Host ("NOTE: social link(s) still on the template default: {0}" -f ($unfilledSocial -join ', ')) -ForegroundColor Yellow
        Write-Host "  These render as icons that go to the network's homepage / login wall - including" -ForegroundColor DarkGray
        Write-Host "  the icons under each named doctor, which implies that person has a profile there." -ForegroundColor DarkGray
        Write-Host '  Put the real profile URL in brand.config.json, or set the value to "" to remove the icons.' -ForegroundColor DarkGray
    }
}

# --------------------------------------------------------------- encoding guard
# This project has a history of double-encoded UTF-8: correct bytes (E2 80 99 for a right
# single quote) get read as CP1252 and rewritten, becoming C3 A2 E2 82 AC E2 84 A2 - which
# renders as "aEUR(tm)" on the live page. It is silent, it survives a rebuild, and it spreads,
# so treat it as a hard failure rather than a warning. tools/Repair-Encoding.ps1 fixes it.
if (-not $DryRun) {
    $mojiPattern = "$([char]0xE2)$([char]0x20AC).|$([char]0xC3)$([char]0xA2)|$([char]0xC2)$([char]0x00A0)"
    $mojiHits = [ordered]@{}
    foreach ($tgt in $targets) {
        $outFile = $tgt[1]
        if (-not (Test-Path $outFile)) { continue }
        $n = ([regex]::Matches((Read-Text $outFile), $mojiPattern)).Count
        if ($n -gt 0) { $mojiHits[$outFile] = $n }
    }
    if ($mojiHits.Count -gt 0) {
        Write-Host ""
        Write-Host "ERROR: double-encoded UTF-8 (mojibake) found in the built output:" -ForegroundColor Red
        foreach ($k in $mojiHits.Keys) { Write-Host ("  {0,-40} {1} sequence(s)" -f $k, $mojiHits[$k]) -ForegroundColor Red }
        Write-Host "  Fix the masters with:  .\tools\Repair-Encoding.ps1   then rebuild." -ForegroundColor Yellow
        exit 1
    }
}

# --------------------------------------------------------------- placeholder leak guard
# Last line of defence. If a rule ever stops matching -- a renamed config key, an edit to
# _source that changes the anchor text, a new page added without the usual markup -- the old
# template placeholder silently ships. Scan the real output and say so loudly.
if (-not $DryRun) {
    $leakPatterns = [ordered]@{
        'calendly.com'          = 'booking.url did not apply'
        'lumoradental.com'      = 'contact.email did not apply'
        '+91 9307512816'        = 'contact.phoneDisplay did not apply'
        'Lumora'                = 'brand.name / brand.shortName did not apply'
        'docs.google.com/forms' = 'careers.url did not apply'
    }
    $leaks = [ordered]@{}
    foreach ($tgt in $targets) {
        $outFile = $tgt[1]
        if (-not (Test-Path $outFile)) { continue }
        $body = Read-Text $outFile
        foreach ($pat in $leakPatterns.Keys) {
            $c = ([regex]::Matches($body, [regex]::Escape($pat))).Count
            if ($c -gt 0) {
                if (-not $leaks.Contains($pat)) { $leaks[$pat] = 0 }
                $leaks[$pat] += $c
            }
        }
    }
    if ($leaks.Count -gt 0) {
        Write-Host ""
        Write-Host "WARNING: template placeholders survived into the built site:" -ForegroundColor Red
        foreach ($pat in $leaks.Keys) {
            Write-Host ("  {0,-24} x{1,-4} {2}" -f $pat, $leaks[$pat], $leakPatterns[$pat]) -ForegroundColor Yellow
        }
        Write-Host "  Check those settings in $Config, then rebuild." -ForegroundColor Yellow
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete. $changedTotal replacements would be made. Nothing written." -ForegroundColor Cyan
}
else {
    Write-Host "Done. $changedTotal replacements across $($targets.Count) files." -ForegroundColor Cyan
    Write-Host "Preview with:  .\Serve.ps1" -ForegroundColor Cyan
}
Write-Host ""
