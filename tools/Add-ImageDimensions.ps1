<#
.SYNOPSIS
  Adds real width/height attributes to every <img> in _source/, fixing the
  "page scrolls by itself" bug.

.DESCRIPTION
  The template ships 49 of 50 images as loading="lazy" with no width/height and no CSS
  aspect-ratio. Until an image loads it occupies ~0 height; when it loads it expands, the
  document reflows, and the browser's scroll anchoring bumps scrollY to compensate. The
  visible result is the page scrolling on its own while you read.

  Browsers derive an intrinsic aspect-ratio from the width/height attributes and reserve
  the right space before the bytes arrive, which removes the reflow. CSS still controls
  the rendered size, so layout is unchanged.

  Dimensions are read from the actual files on disk, so they are exact.

.EXAMPLE
  .\tools\Add-ImageDimensions.ps1 -DryRun
  .\tools\Add-ImageDimensions.ps1
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$s) { [System.IO.File]::WriteAllText($p, $s, $utf8NoBom) }

# GDI+ on Windows cannot read WebP, and ~half this template's images are .webp,
# so parse the RIFF/VP8 header directly for those.
function Get-WebpSize([string]$path) {
    $b = [System.IO.File]::ReadAllBytes($path)
    if ($b.Length -lt 30) { return $null }
    if ([System.Text.Encoding]::ASCII.GetString($b, 0, 4) -ne 'RIFF') { return $null }
    if ([System.Text.Encoding]::ASCII.GetString($b, 8, 4) -ne 'WEBP') { return $null }
    $fourcc = [System.Text.Encoding]::ASCII.GetString($b, 12, 4)

    switch ($fourcc) {
        'VP8 ' {
            # lossy: 16-bit width/height at 26/28, low 14 bits significant
            $w = ([int]$b[26] -bor ([int]$b[27] -shl 8)) -band 0x3FFF
            $h = ([int]$b[28] -bor ([int]$b[29] -shl 8)) -band 0x3FFF
            return @{ W = $w; H = $h }
        }
        'VP8L' {
            # lossless: 14-bit (width-1) then 14-bit (height-1), packed from byte 21
            $bits = [uint32]$b[21] -bor ([uint32]$b[22] -shl 8) -bor ([uint32]$b[23] -shl 16) -bor ([uint32]$b[24] -shl 24)
            $w = [int]($bits -band 0x3FFF) + 1
            $h = [int](($bits -shr 14) -band 0x3FFF) + 1
            return @{ W = $w; H = $h }
        }
        'VP8X' {
            # extended: 24-bit little-endian (canvas-1) at 24 and 27
            $w = ([int]$b[24] -bor ([int]$b[25] -shl 8) -bor ([int]$b[26] -shl 16)) + 1
            $h = ([int]$b[27] -bor ([int]$b[28] -shl 8) -bor ([int]$b[29] -shl 16)) + 1
            return @{ W = $w; H = $h }
        }
    }
    return $null
}

# cache dimensions so each file is opened once
$dims = @{}
function Get-Dim([string]$relPath) {
    if ($dims.ContainsKey($relPath)) { return $dims[$relPath] }
    $disk = $relPath -replace '/', '\'
    # variant-blue pages reference assets/... relative to their own folder
    $candidates = @($disk, (Join-Path 'variant-blue' $disk))
    foreach ($c in $candidates) {
        if (-not (Test-Path $c -PathType Leaf)) { continue }
        $full = (Resolve-Path $c).Path
        $v = $null
        if ($full -match '\.webp$') {
            $v = Get-WebpSize $full
        }
        else {
            try {
                $img = [System.Drawing.Image]::FromFile($full)
                $v = @{ W = $img.Width; H = $img.Height }
                $img.Dispose()
            }
            catch { $v = $null }
        }
        if ($v) { $dims[$relPath] = $v; return $v }
    }
    $dims[$relPath] = $null
    return $null
}

$files = Get-ChildItem '_source\*.html', '_source\variant-blue\*.html'
$totalAdded = 0
$totalMissing = 0

foreach ($f in $files) {
    $html = Read-Text $f.FullName
    $added = 0
    $missing = 0

    # Always recompute from the file on disk and overwrite any existing width/height.
    # Skipping already-sized tags made this non-self-healing: swapping an image for one with a
    # different aspect ratio left the old dimensions in place, so the browser reserved the wrong
    # box and the layout distorted. Recomputing every run keeps it correct and still idempotent.
    $out = [regex]::Replace($html, '<img\b[^>]*>', {
            param($m)
            $tag = $m.Value

            $sm = [regex]::Match($tag, '\ssrc="([^"]+)"')
            if (-not $sm.Success) { return $tag }
            $src = $sm.Groups[1].Value
            if ($src -match '^(https?:|data:)') { return $tag }

            $d = Get-Dim $src
            if ($null -eq $d) { return $tag }

            # drop any existing width/height, then restate them from the real file
            $clean = $tag -replace '\s(width|height)="[^"]*"', ''
            return ($clean -replace '^<img', ('<img width="' + $d.W + '" height="' + $d.H + '"'))
        })

    # the scriptblock can't close over locals cleanly, so recount from the result
    $missing = ([regex]::Matches($out, '<img\b(?![^>]*\swidth=)')).Count
    $added = ([regex]::Matches($out, '<img\b[^>]*\swidth=')).Count
    $corrected = if ($html -eq $out) { 0 } else { 1 }

    $totalAdded += $added
    $totalMissing += $missing

    if ($DryRun) {
        Write-Host ("  [dry] {0,-40} {1} sized, {2} unsized{3}" -f $f.Name, $added, $missing, $(if($corrected){" (CORRECTED)"}else{""}))
    }
    else {
        Write-Text $f.FullName $out
        Write-Host ("  ok    {0,-40} {1} sized, {2} unsized{3}" -f $f.Name, $added, $missing, $(if($corrected){" (CORRECTED)"}else{""})) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Added dimensions to $totalAdded images. $totalMissing left unsized (file not found on disk)." -ForegroundColor Cyan
Write-Host "Now run: .\Build-Site.ps1"
