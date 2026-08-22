$ErrorActionPreference = 'Stop'
$root = "c:/Users/Administrator/Desktop/website dev/minted-dental/_source"
$files = Get-ChildItem -Path $root -Recurse -Include *.html

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $newText = $text
    $newText = $newText -replace 'assets/img/gen_team-image-6\.jpg', 'assets/img/doctor1.jpeg'
    $newText = $newText -replace 'assets/img/gen_team-image-1\.jpg', 'assets/img/doctor2.jpeg'
    $newText = $newText -replace 'assets/img/gen_team-image-3\.jpg', 'assets/img/doctor3.jpeg'
    $newText = $newText -replace 'assets/img/gen_team-image-2\.jpg', 'assets/img/doctor4.jpeg'
    $newText = $newText -replace 'hello@lumoradental\.com', 'hello@minteddental.com'
    $newText = $newText -replace 'smile@lumoradental\.com', 'smile@minteddental.com'
    $newText = $newText -replace '\. Crafted by RapidXAI', ''
    
    if ($text -cne $newText) {
        [System.IO.File]::WriteAllText($file.FullName, $newText, $utf8NoBom)
        Write-Host "Updated $($file.FullName)"
    }
}

$cssPath = "$root/assets/css/lumora.css"
$cssAdd = @"

/* Responsive team grid */
.team_list {
    display: grid;
    grid-template-columns: 1fr;
    gap: 2rem;
}
@media screen and (min-width: 768px) {
    .team_list {
        grid-template-columns: repeat(2, 1fr);
    }
}
@media screen and (min-width: 992px) {
    .team_list {
        grid-template-columns: repeat(4, 1fr);
    }
}
.team_image {
    object-fit: cover;
    background-color: #f3f6ff;
    width: 100%;
    height: 100%;
}
"@

$cssText = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
if (-not $cssText.Contains(".team_list {")) {
    [System.IO.File]::AppendAllText($cssPath, $cssAdd, $utf8NoBom)
    Write-Host "Updated lumora.css"
}

Write-Host "Done"
