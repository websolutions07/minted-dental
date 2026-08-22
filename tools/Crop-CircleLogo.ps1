<#
.SYNOPSIS
  Crops the circular badge out of a square logo image and writes a transparent PNG.

.DESCRIPTION
  Auto-detects the circle by finding the bounding box of non-background pixels
  (the dark corner gradient is treated as background), then masks everything
  outside the inscribed circle to transparent with antialiased edges.

.EXAMPLE
  .\tools\Crop-CircleLogo.ps1 -In "C:\Users\Moon\Downloads\minted dental logo.jpg" -Out "assets\img\brand-badge.png" -Size 512
#>
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$Size = 512,
    [int]$Inset = 2
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $In)) { throw "Input not found: $In" }

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $In).Path)
Write-Host "source: $($src.Width) x $($src.Height)"

# ---- detect the light badge disc -------------------------------------------
# The badge is light (high brightness); the surrounding gradient is dark.
$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
$step = 2
for ($y = 0; $y -lt $src.Height; $y += $step) {
    for ($x = 0; $x -lt $src.Width; $x += $step) {
        $p = $src.GetPixel($x, $y)
        $lum = (0.299 * $p.R + 0.587 * $p.G + 0.114 * $p.B)
        if ($lum -gt 150) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt 0) { throw "Could not detect a light badge region in the image." }

$w = $maxX - $minX
$h = $maxY - $minY
Write-Host "detected disc bbox: x=$minX y=$minY w=$w h=$h"

# use the inscribed circle of the detected box
$diam = [Math]::Min($w, $h) - ($Inset * 2)
$cx = $minX + ($w / 2.0)
$cy = $minY + ($h / 2.0)
$srcX = $cx - ($diam / 2.0)
$srcY = $cy - ($diam / 2.0)

# ---- render the circular crop ----------------------------------------------
$dst = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(0, 0, $Size, $Size)
$g.SetClip($path)

$destRect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
$g.DrawImage($src, $destRect, [float]$srcX, [float]$srcY, [float]$diam, [float]$diam, [System.Drawing.GraphicsUnit]::Pixel)

$g.Dispose()

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$dst.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

$dst.Dispose()
$src.Dispose()

Write-Host "wrote: $Out ($Size x $Size, transparent outside the circle)" -ForegroundColor Green
