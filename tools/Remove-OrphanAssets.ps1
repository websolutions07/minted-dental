<#
.SYNOPSIS
  Deletes image files that nothing references, and the stale internal notes copy that was
  shipping inside variant-blue/.

.DESCRIPTION
  The site was rebranded off a Webflow template. Every visible photo was replaced with a
  gen_*.jpg, but the ORIGINAL template images were left on disk - 106 files, ~39MB across the
  two asset trees, referenced by nothing. Five of them still carry the original template's name
  in the filename (…_flowfye.svg, …_smilifye-logo-dark.svg, …_smilifye-favicon.png, etc), which
  defeats the project's de-brand invariant the moment the folder is uploaded anywhere.

  A file is treated as referenced if its basename appears in ANY text file in the project
  (html/css/js/json/ps1/md/xml/txt/webmanifest), which covers <img src>, srcset, CSS url('../img/..'),
  inline scripts and the build config. Anything not matched is dead weight.

  gen_* files are KEPT even when unreferenced - they are our own on-brand photography and make
  useful spares (e.g. the doctor headshots not currently assigned).

.EXAMPLE
  .\tools\Remove-OrphanAssets.ps1 -DryRun
  .\tools\Remove-OrphanAssets.ps1
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

# ---------------------------------------------------------------- build the referenced set
$textExt = @('*.html', '*.css', '*.js', '*.json', '*.ps1', '*.md', '*.xml', '*.txt', '*.webmanifest')
$textFiles = Get-ChildItem -Recurse -File -Include $textExt |
Where-Object { $_.FullName -notlike '*\.git\*' }

$referenced = New-Object 'System.Collections.Generic.HashSet[string]'
$rx = [regex]'[A-Za-z0-9._@%+-]+\.(?:jpg|jpeg|png|webp|svg|gif|ico|avif)'
foreach ($tf in $textFiles) {
    $body = [System.IO.File]::ReadAllText($tf.FullName, [System.Text.Encoding]::UTF8)
    foreach ($m in $rx.Matches($body)) { [void]$referenced.Add($m.Value.ToLower()) }
}
Write-Host "Scanned $($textFiles.Count) text files -> $($referenced.Count) distinct image names referenced." -ForegroundColor Cyan

# ---------------------------------------------------------------- find the dead ones
$imgDirs = @('assets\img', 'variant-blue\assets\img') | Where-Object { Test-Path $_ }
$dead = @()
$keptGen = @()
foreach ($dir in $imgDirs) {
    foreach ($f in Get-ChildItem $dir -File) {
        if ($referenced.Contains($f.Name.ToLower())) { continue }
        if ($f.Name -like 'gen_*') { $keptGen += $f; continue }   # our own art: keep as spares
        $dead += $f
    }
}

$bytes = ($dead | Measure-Object -Property Length -Sum).Sum
$branded = @($dead | Where-Object { $_.Name -match 'flowfye|smilifye|pagifye' })

Write-Host ""
Write-Host ("Unreferenced, safe to delete : {0} files ({1:N1} MB)" -f $dead.Count, ($bytes / 1MB)) -ForegroundColor Yellow
Write-Host "  of which leak the template name: $($branded.Count)" -ForegroundColor Yellow
Write-Host "Unreferenced gen_* kept as spares: $($keptGen.Count)" -ForegroundColor DarkGray
if ($branded.Count -gt 0) {
    Write-Host ""
    Write-Host "  template-name leaks being removed:" -ForegroundColor DarkGray
    $branded | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------- internal notes inside the deploy folder
$strays = @('variant-blue\CLAUDE.md') | Where-Object { Test-Path $_ }

if ($DryRun) {
    Write-Host ""
    Write-Host "[dry run] nothing deleted." -ForegroundColor Cyan
    if ($strays) { $strays | ForEach-Object { Write-Host "[dry run] would also delete $_" -ForegroundColor Cyan } }
    exit 0
}

foreach ($f in $dead) { Remove-Item $f.FullName -Force }
foreach ($s in $strays) {
    Remove-Item $s -Force
    Write-Host "Deleted $s (stale internal notes; was publicly readable once deployed)." -ForegroundColor Green
}

Write-Host ""
Write-Host ("Removed {0} files, reclaimed {1:N1} MB." -f $dead.Count, ($bytes / 1MB)) -ForegroundColor Green
Write-Host "Re-run .\Build-Site.ps1 and confirm the site still renders." -ForegroundColor Cyan
