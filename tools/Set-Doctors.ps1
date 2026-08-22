<#
.SYNOPSIS
  One-off content edit: replaces the template's placeholder doctors with the real
  Minted Dental team, in _source/ (the master copy). Run Build-Site.ps1 afterwards.

.DESCRIPTION
  Every team card is identical markup, so a global find/replace would hit all of them
  at once. The cards are uniform 31-line <div role="listitem"> blocks, so this works on
  line ranges: it takes the first card as a template, stamps out one card per doctor,
  and swaps the whole team region in. Card count adapts automatically (3 -> 4, 6 -> 4).
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$s) { [System.IO.File]::WriteAllText($p, $s, $utf8NoBom) }

# The real team, in display order.
# NOTE: these photos are AI-generated placeholders from the template, picked only so the
# apparent gender matches each doctor. They are NOT the real people. Replace each file in
# assets/img/ with a real headshot (same filename, same aspect ratio) before going live.
$doctors = @(
    @{ Name = 'Dr. Onika Patel';      Role = 'General &amp; Cosmetic Dentist, MAGD'; Img = 'gen_team-image-6.jpg' },
    @{ Name = 'Dr. Angela Wilson';    Role = 'Cosmetic &amp; Restorative Dentist';   Img = 'gen_team-image-1.jpg' },
    @{ Name = 'Dr. Rachel Goodman';   Role = 'General &amp; Restorative Dentist';    Img = 'gen_team-image-3.jpg' },
    @{ Name = 'Dr. Brent Woodmansee'; Role = 'IV Sedation &amp; Wisdom Teeth';       Img = 'gen_team-image-2.jpg' }
)

$files = @(
    '_source\index.html', '_source\variant-blue\index.html',
    '_source\about.html', '_source\variant-blue\about.html'
)

foreach ($file in $files) {
    if (-not (Test-Path $file)) { Write-Host "  skip (missing): $file" -ForegroundColor Yellow; continue }

    $text = Read-Text $file
    $nl = "`n"
    if ($text -match "`r`n") { $nl = "`r`n" }
    $lines = [regex]::Split($text, "`r?`n")

    # team cards only: a listitem line immediately followed by a team_item line
    $starts = @()
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '<div class="team_item">' -and $lines[$i - 1] -match 'role="listitem"') {
            $starts += ($i - 1)
        }
    }
    if ($starts.Count -lt 2) { Write-Host "  WARNING: team cards not found in $file" -ForegroundColor Yellow; continue }

    $cardLen = $starts[1] - $starts[0]
    $regionStart = $starts[0]
    $regionEnd = $starts[-1] + $cardLen - 1      # inclusive
    $oldCount = $starts.Count

    # sanity: the region must not run past the file
    if ($regionEnd -ge $lines.Count) { Write-Host "  WARNING: team region overruns $file" -ForegroundColor Yellow; continue }

    $template = $lines[$regionStart..($regionStart + $cardLen - 1)] -join $nl

    $cards = @()
    foreach ($d in $doctors) {
        $b = $template
        $b = [regex]::Replace($b, 'alt="[^"]*"', ('alt="' + $d.Name + '"'))
        $b = [regex]::Replace($b, '(<h3 class="team-menmber_name">)[^<]*(</h3>)', ('${1}' + $d.Name + '${2}'))
        $b = [regex]::Replace($b, '(<p class="team-menuber_designation">)[^<]*(</p>)', ('${1}' + $d.Role + '${2}'))
        $b = [regex]::Replace($b, 'assets/img/gen_team-image-\d\.jpg', ('assets/img/' + $d.Img))
        $cards += $b
    }

    $head = if ($regionStart -gt 0) { $lines[0..($regionStart - 1)] } else { @() }
    $tail = $lines[($regionEnd + 1)..($lines.Count - 1)]
    $newText = (@($head) + @($cards -join $nl) + @($tail)) -join $nl

    if ($DryRun) {
        Write-Host ("  [dry] {0,-38} {1} cards -> {2}  (card = {3} lines)" -f $file, $oldCount, $doctors.Count, $cardLen)
    }
    else {
        Write-Text $file $newText
        Write-Host ("  ok    {0,-38} {1} cards -> {2}" -f $file, $oldCount, $doctors.Count) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Doctors updated in _source/. Now run: .\Build-Site.ps1" -ForegroundColor Cyan
