<#
.SYNOPSIS
  Generates full site pages from the body fragments in _content/ , reusing the real nav,
  footer, scripts and <head> from an existing page so new pages are indistinguishable
  from the originals.

.DESCRIPTION
  Writes into _source/ (and _source/variant-blue/), NOT into the built output. Run
  Build-Site.ps1 afterwards to brand and publish them.

  Chrome donor is service.html: everything before <main class="main-wrapper"> and
  everything from </main> onward is copied verbatim, so a nav or footer change made to
  the template automatically flows into these pages on the next run.

  DE-BRANDING: _source/ is the pre-rebrand master. Every page there says "Lumora", and
  Build-Site.ps1 rewrites that to whatever brand.config.json specifies. The fragments in
  _content/ are written in readable present-day wording ("Minted Dental", "Minted
  Membership"), so this script converts them back to the Lumora token on the way in.
  Without that step the new pages would hard-code the brand and stop being re-brandable.
  The lowercase "minted" in https://flexbook.me/minted is untouched: the replace is
  case-sensitive and the booking URL has its own rule in the build.

.EXAMPLE
  .\tools\Build-ContentPages.ps1
  .\tools\Build-ContentPages.ps1 -DryRun
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$s) { [System.IO.File]::WriteAllText($p, $s, $utf8NoBom) }

function ConvertTo-BrandToken([string]$s) {
    # order matters: longest first, and case-sensitive so the booking URL survives
    $s = $s.Replace('Minted Dental', 'Lumora Dental')
    $s = $s.Replace('Minted Membership', 'Lumora Membership')
    $s = $s.Replace('Minted ', 'Lumora ')
    return $s
}

function Get-Marker([string]$body, [string]$name, [string]$fallback) {
    $m = [regex]::Match($body, "(?m)^\s*$name`:\s*(.+?)\s*$")
    if ($m.Success) { return $m.Groups[1].Value }
    return $fallback
}

$fragments = Get-ChildItem '_content\*.html' -ErrorAction SilentlyContinue
if (-not $fragments) { Write-Host "No fragments in _content/." -ForegroundColor Yellow; exit 0 }

$variants = @(
    @{ Key = 'root'; Donor = '_source\service.html'; Out = '_source' },
    @{ Key = 'blue'; Donor = '_source\variant-blue\service.html'; Out = '_source\variant-blue' }
)

foreach ($v in $variants) {
    if (-not (Test-Path $v.Donor)) { Write-Host "  skip $($v.Key): donor missing" -ForegroundColor Yellow; continue }
    $donor = Read-Text $v.Donor

    $openIdx = $donor.IndexOf('<main class="main-wrapper">')
    $closeIdx = $donor.LastIndexOf('</main>')
    if ($openIdx -lt 0 -or $closeIdx -lt 0) {
        Write-Host "  ERROR: could not find <main> boundaries in $($v.Donor)" -ForegroundColor Red
        continue
    }
    $head = $donor.Substring(0, $openIdx + '<main class="main-wrapper">'.Length)
    $tail = $donor.Substring($closeIdx)

    # the donor is the Services page; drop its "current page" marker so the new pages
    # do not light up Services in the nav
    $head = $head -replace '\s+aria-current="page"', ''
    $head = $head -replace '\s+w--current', ''

    foreach ($frag in $fragments) {
        $body = Read-Text $frag.FullName
        $name = $frag.BaseName

        $title = ConvertTo-BrandToken (Get-Marker $body 'PAGE_TITLE' "$name | Lumora Dental")
        $desc = ConvertTo-BrandToken (Get-Marker $body 'PAGE_DESC' '')

        # strip the leading HTML comment block (it is authoring metadata, not page content)
        $body = [regex]::Replace($body, '(?s)^\s*<!--.*?-->\s*', '')
        $body = ConvertTo-BrandToken $body

        $page = $head + "`r`n" + $body.TrimEnd() + "`r`n            " + $tail

        # retitle + re-describe
        $page = [regex]::Replace($page, '(?s)<title>.*?</title>', ('<title>' + $title + '</title>'))
        if ($desc) {
            $page = [regex]::Replace($page, '<meta content="[^"]*" name="description"/>', ('<meta content="' + $desc + '" name="description"/>'))
            $page = [regex]::Replace($page, '<meta content="[^"]*" property="og:description"/>', ('<meta content="' + $desc + '" property="og:description"/>'))
            $page = [regex]::Replace($page, '<meta content="[^"]*" name="twitter:description"/>', ('<meta content="' + $desc + '" name="twitter:description"/>'))
        }
        $page = [regex]::Replace($page, '<meta content="[^"]*" property="og:title"/>', ('<meta content="' + $title + '" property="og:title"/>'))
        $page = [regex]::Replace($page, '<meta content="[^"]*" name="twitter:title"/>', ('<meta content="' + $title + '" name="twitter:title"/>'))

        $outPath = Join-Path $v.Out "$name.html"
        $d = ([regex]::Matches($page, '<div')).Count
        $c = ([regex]::Matches($page, '</div>')).Count

        if ($DryRun) {
            Write-Host ("  [dry] {0,-34} {1,7} bytes  div {2}/{3}" -f $outPath, $page.Length, $d, $c)
        }
        else {
            Write-Text $outPath $page
            $flag = if ($d -eq $c) { '' } else { "  <-- DIV MISMATCH" }
            Write-Host ("  ok    {0,-34} {1,7} bytes  div {2}/{3}{4}" -f $outPath, $page.Length, $d, $c, $flag) -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Pages generated into _source/. Add them to `$pages in Build-Site.ps1, then rebuild." -ForegroundColor Cyan
