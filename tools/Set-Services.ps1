<#
.SYNOPSIS
  Rebuilds the service cards on index.html and the service accordion on service.html from
  one data table, so both always agree.

.DESCRIPTION
  Content is taken from Minted Dental's own service pages (minteddental.com). The template
  shipped four generic services; the practice actually offers seven.

  Both components are uniform repeated blocks, so - as with Set-Doctors.ps1 - this works on
  line ranges: take the first block as a template, stamp out one per service, swap the whole
  region in. A global find/replace cannot be used because every block is identical markup.

  Also fixes a real defect inherited from the Webflow export: all four service.html blocks
  carried the SAME id="w-node-...". Duplicate ids are invalid HTML. Each block now gets a
  unique suffix.

.EXAMPLE
  .\tools\Set-Services.ps1 -DryRun
  .\tools\Set-Services.ps1
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$s) { [System.IO.File]::WriteAllText($p, $s, $utf8NoBom) }

# The seven services Minted Dental actually offers, in the order shown on their own site.
$services = @(
    @{ Title = 'General Dentistry'; Bg = '#f3f6ff'; Img = 'gen_service-thumbnail-image.jpg'
        Short = 'Primary dental procedures for children and adults, from routine checkups and cleanings to fillings, with appointments that fit the whole family into one trip.'
        Trig  = 'Comprehensive care for you and your family, with appointments that accommodate everyone in one visit.'
        Tags  = @('Checkups', 'Cleanings', 'Fillings', 'Family Care')
    },
    @{ Title = 'Emergency Care'; Bg = '#fef5ec'; Img = 'gen_service-thumbnail-image-2.jpg'
        Short = 'From broken fillings to cracked teeth, we strive to provide urgent care in a timely manner, with same-day appointments wherever possible.'
        Trig  = 'Toothache, cracked tooth or lost dental work? Call us and we will do our best to see you the same day.'
        Tags  = @('Same-Day', 'Toothache', 'Broken Tooth', 'Lost Crown')
    },
    @{ Title = 'Cosmetic Dentistry'; Bg = '#effff7'; Img = 'gen_service-thumbnail-image-3.jpg'
        Short = 'Designing your smile with both artistry and functionality, correcting discoloration, chips, gaps and irregularities.'
        Trig  = 'Bonding, veneers, bleaching, reshaping and crowns, chosen around the condition of your teeth and what you want to change.'
        Tags  = @('Veneers', 'Bonding', 'Reshaping', 'Crowns')
    },
    @{ Title = 'Invisalign'; Bg = '#f7efff'; Img = 'gen_service-thumbnail-image-4.jpg'
        Short = 'The clear alternative to braces. No metal brackets or wires, and the aligners are removable so you can eat, brush and floss normally.'
        Trig  = 'Virtually invisible aligners for teens and adults. Most patients finish in about six months, and consultations are free.'
        Tags  = @('Clear Aligners', 'Teens &amp; Adults', 'Free Consult', 'About 6 Months')
    },
    @{ Title = 'Restorative Dentistry'; Bg = '#f3f6ff'; Img = 'gen_service-thumbnail-image.jpg'
        Short = 'Restoring a tooth&rsquo;s structure and aesthetics back to its optimal shape and health, for broken and missing teeth alike.'
        Trig  = 'Fillings, bridges, partial and full dentures, and implants that look and feel like natural teeth.'
        Tags  = @('Fillings', 'Crowns', 'Bridges', 'Implants')
    },
    @{ Title = 'Holistic Dentistry'; Bg = '#effff7'; Img = 'gen_service-thumbnail-image-3.jpg'
        Short = 'A natural approach to dental care. Holistic and biologic dentistry that treats the root cause, not just the symptom.'
        Trig  = 'Mercury-free dentistry, safe amalgam removal under the SMART protocol, and biocompatible materials chosen to suit your body.'
        Tags  = @('Mercury-Free', 'SMART Protocol', 'Biocompatible', 'Preventive')
    },
    @{ Title = 'Teeth Whitening'; Bg = '#fef5ec'; Img = 'gen_service-thumbnail-image-2.jpg'
        Short = 'Professional-strength whitening to lift stains from coffee, tea, wine and smoking, in the chair or at home.'
        Trig  = 'In-office whitening brightens up to 10 shades in a single visit; take-home trays give a gradual result over two to three weeks.'
        Tags  = @('In-Office', 'Take-Home', '10 Shades', 'Custom Trays')
    }
)

function Set-Region {
    param([string]$File, [string]$StartPattern, [scriptblock]$Stamp)

    if (-not (Test-Path $File)) { Write-Host "  skip (missing): $File" -ForegroundColor Yellow; return }
    $text = Read-Text $File
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $lines = [regex]::Split($text, "`r?`n")

    $starts = @()
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $StartPattern) { $starts += $i } }
    if ($starts.Count -lt 2) { Write-Host "  WARNING: <2 blocks matched in $File" -ForegroundColor Yellow; return }

    $blockLen = $starts[1] - $starts[0]
    $regionStart = $starts[0]

    # Do NOT assume the last block is the same length as the gap between the others. The gap
    # includes any separator lines, so on service.html the final block ends two lines earlier
    # than blockLen suggests, and a fixed window swallowed two closing divs belonging to the
    # parent section. Walk div depth from the last block start and stop when it returns to 0.
    $depth = 0
    $regionEnd = -1
    for ($i = $starts[-1]; $i -lt $lines.Count; $i++) {
        $depth += ([regex]::Matches($lines[$i], '<div\b')).Count
        $depth -= ([regex]::Matches($lines[$i], '</div>')).Count
        if ($depth -le 0) { $regionEnd = $i; break }
    }
    if ($regionEnd -lt 0) { Write-Host "  WARNING: could not close final block in $File" -ForegroundColor Yellow; return }

    # template = the FIRST block, closed the same way (depth-matched), not a fixed slice
    $tDepth = 0; $tEnd = -1
    for ($i = $regionStart; $i -lt $lines.Count; $i++) {
        $tDepth += ([regex]::Matches($lines[$i], '<div\b')).Count
        $tDepth -= ([regex]::Matches($lines[$i], '</div>')).Count
        if ($tDepth -le 0) { $tEnd = $i; break }
    }
    if ($tEnd -lt 0) { Write-Host "  WARNING: could not close first block in $File" -ForegroundColor Yellow; return }
    $template = ($lines[$regionStart..$tEnd]) -join $nl
    $blocks = @()
    for ($n = 0; $n -lt $services.Count; $n++) { $blocks += (& $Stamp $template $services[$n] $n) }

    $head = if ($regionStart -gt 0) { $lines[0..($regionStart - 1)] } else { @() }
    $tail = $lines[($regionEnd + 1)..($lines.Count - 1)]
    $out = (@($head) + @($blocks -join $nl) + @($tail)) -join $nl

    $d = ([regex]::Matches($out, '<div')).Count
    $c = ([regex]::Matches($out, '</div>')).Count
    $flag = if ($d -eq $c) { '' } else { "  <-- DIV MISMATCH $d/$c" }

    if ($DryRun) {
        Write-Host ("  [dry] {0,-38} {1} blocks -> {2} (block={3} lines){4}" -f $File, $starts.Count, $services.Count, $blockLen, $flag)
    }
    else {
        Write-Text $File $out
        Write-Host ("  ok    {0,-38} {1} blocks -> {2}{3}" -f $File, $starts.Count, $services.Count, $flag) -ForegroundColor Green
    }
}

# ---- replace the four service tag chips inside a block with this service's four ----
function Set-Tags([string]$block, [string[]]$tags) {
    $i = 0
    return [regex]::Replace($block, '(<div class="service-tag_icon">.*?</div>\s*</div>\s*<div>)([^<]*)(</div>)', {
            param($m)
            $v = if ($i -lt $tags.Count) { $tags[$i] } else { $m.Groups[2].Value }
            $script:i = $i + 1
            $m.Groups[1].Value + $v + $m.Groups[3].Value
        }, 'Singleline')
}

foreach ($variant in @('_source', '_source\variant-blue')) {

    # ---------- home page cards ----------
    Set-Region -File (Join-Path $variant 'index.html') -StartPattern 'class="service_item-wrap w-dyn-item"' -Stamp {
        param($tpl, $svc, $n)
        $b = $tpl
        $b = [regex]::Replace($b, 'background-color:#[0-9a-fA-F]{6}', ('background-color:' + $svc.Bg))
        $b = [regex]::Replace($b, '(<div class="service-item_number_text">)\d{2}(</div>)', ('${1}' + ('{0:00}' -f ($n + 1)) + '${2}'))
        $b = [regex]::Replace($b, '(<div class="service-item_info-title">)[^<]*(</div>)', ('${1}' + $svc.Title + '${2}'))
        $b = [regex]::Replace($b, '(<div class="service-item_info-title">[^<]*</div>\s*<p>)[^<]*(</p>)', ('${1}' + $svc.Short + '${2}'), 'Singleline')
        return $b
    }

    # ---------- services page accordion ----------
    Set-Region -File (Join-Path $variant 'service.html') -StartPattern 'class="service-item_wrap"' -Stamp {
        param($tpl, $svc, $n)
        $b = $tpl
        $b = [regex]::Replace($b, '(<h3 class="service-trigger_title">)[^<]*(</h3>)', ('${1}' + $svc.Title + '${2}'))
        $b = [regex]::Replace($b, '(<p class="service-trigger_para">)[^<]*(</p>)', ('${1}' + $svc.Trig + '${2}'))
        $b = [regex]::Replace($b, 'gen_service-thumbnail-image(-\d)?\.jpg', $svc.Img)
        $b = [regex]::Replace($b, 'alt=""', ('alt="' + $svc.Title + ' at Lumora Dental"'))
        # unique id per block: the export repeated one id across every block (invalid HTML)
        $b = [regex]::Replace($b, 'id="w-node-[^"]*"', ('id="service-item-' + ($n + 1) + '"'))
        $script:i = 0
        $b = Set-Tags $b $svc.Tags
        return $b
    }
}

Write-Host ""
Write-Host "Services updated in _source/. Now run: .\Build-Site.ps1" -ForegroundColor Cyan
