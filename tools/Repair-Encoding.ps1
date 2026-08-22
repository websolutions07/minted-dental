<#
.SYNOPSIS
  Repairs double-encoded UTF-8 (mojibake) in the site's HTML, and reports anything it
  cannot confidently fix.

.DESCRIPTION
  Mojibake here is the classic CP1252 round-trip: correct UTF-8 bytes (e.g. E2 80 99 for a
  right single quote) were read as CP1252, producing the three characters "a-circumflex,
  euro, trademark", and then written back out as UTF-8. The result is C3 A2 E2 82 AC E2 84 A2
  where three bytes should be.

  The fix is a targeted reverse map rather than a blanket CP1252 round-trip of the whole file,
  because a blanket conversion would also damage any character that is correctly encoded.

  Run against _source/ (the masters). Rebuild afterwards.

.EXAMPLE
  .\tools\Repair-Encoding.ps1 -DryRun
  .\tools\Repair-Encoding.ps1
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$s) { [System.IO.File]::WriteAllText($p, $s, $utf8NoBom) }

# mojibake sequence -> the character it should be.
# Longest first: "a-circ euro" + a trailing byte must be tried before the bare pair.
$map = [ordered]@{
    ("$([char]0xE2)$([char]0x20AC)$([char]0x2122)") = [char]0x2019  # '
    ("$([char]0xE2)$([char]0x20AC)$([char]0x0153)") = [char]0x201C  # "
    ("$([char]0xE2)$([char]0x20AC)$([char]0x009D)") = [char]0x201D  # "
    ("$([char]0xE2)$([char]0x20AC)$([char]0x201C)") = [char]0x2013  # en dash
    ("$([char]0xE2)$([char]0x20AC)$([char]0x201D)") = [char]0x2014  # em dash
    ("$([char]0xE2)$([char]0x20AC)$([char]0x00A6)") = [char]0x2026  # ellipsis
    ("$([char]0xE2)$([char]0x02DC)$([char]0x2026)") = [char]0x2605  # star
    ("$([char]0xC2)$([char]0x00A0)")                = [char]0x00A0  # nbsp
    ("$([char]0xC3)$([char]0xA9)")                  = [char]0x00E9  # e-acute
}

$targets = @()
$targets += Get-ChildItem '_source\*.html'
$targets += Get-ChildItem '_source\variant-blue\*.html'
$targets += Get-ChildItem '_content\*.html' -ErrorAction SilentlyContinue

$totalFixed = 0
$stillBad = @()

foreach ($f in $targets) {
    $text = Read-Text $f.FullName
    $orig = $text
    $fixedHere = 0

    foreach ($bad in $map.Keys) {
        $count = ([regex]::Matches($text, [regex]::Escape($bad))).Count
        if ($count -gt 0) {
            $text = $text.Replace($bad, [string]$map[$bad])
            $fixedHere += $count
        }
    }

    # anything left that still looks like mojibake
    $leftovers = [regex]::Matches($text, "$([char]0xE2)$([char]0x20AC).|$([char]0xC3)[$([char]0xA2)-$([char]0xBF)]")
    if ($leftovers.Count -gt 0) {
        $stillBad += ("  {0}: {1} unmapped sequence(s)" -f $f.Name, $leftovers.Count)
    }

    if ($fixedHere -gt 0) {
        $totalFixed += $fixedHere
        if ($DryRun) { Write-Host ("  [dry] {0,-40} would fix {1}" -f $f.FullName.Replace("$root\", ''), $fixedHere) }
        else {
            Write-Text $f.FullName $text
            Write-Host ("  ok    {0,-40} fixed {1}" -f $f.FullName.Replace("$root\", ''), $fixedHere) -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Repaired $totalFixed mojibake sequence(s)." -ForegroundColor Cyan
if ($stillBad.Count -gt 0) {
    Write-Host "STILL SUSPICIOUS - add these to the map:" -ForegroundColor Red
    $stillBad | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
}
else { Write-Host "No unmapped mojibake remains." -ForegroundColor Green }
