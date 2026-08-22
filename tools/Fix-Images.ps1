$ErrorActionPreference = 'Stop'
$root = "c:/Users/Administrator/Desktop/website dev/minted-dental"

# 1. Update doctor3 image
Copy-Item "C:\Users\Administrator\Downloads\doctor3.jpeg" "$root\assets\img\doctor3.jpeg" -Force

# 2. Move testimonial images
New-Item -ItemType Directory -Path "$root\assets\testimonials" -Force -ErrorAction SilentlyContinue | Out-Null
Move-Item "$root\assets\img\gen_testimonial-author-*.jpg" "$root\assets\testimonials\" -Force -ErrorAction SilentlyContinue | Out-Null

# 3. Update HTML files for testimonial image paths
$files = Get-ChildItem -Path "$root\_source" -Recurse -Include *.html
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $newText = $text -replace 'src="assets/img/gen_testimonial-author', 'src="./assets/testimonials/gen_testimonial-author'
    if ($text -cne $newText) {
        [System.IO.File]::WriteAllText($file.FullName, $newText, $utf8NoBom)
        Write-Host "Updated HTML $($file.FullName)"
    }
}

# 4. Update CSS for testimonial images
$cssAdd = @"

/* Testimonial avatar formatting */
.testimonial-author_image-wrap {
    position: relative;
    width: 4.5rem;
    height: 4.5rem;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
}
.testimonial-author_image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: center;
}
"@

$cssPath = "$root\_source\assets\css\lumora.css"
$cssText = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
if (-not $cssText.Contains(".testimonial-author_image-wrap {")) {
    [System.IO.File]::AppendAllText($cssPath, $cssAdd, $utf8NoBom)
    Write-Host "Updated CSS $cssPath"
}

$cssPathBlue = "$root\_source\variant-blue\assets\css\lumora.css"
if (Test-Path $cssPathBlue) {
    $cssTextBlue = [System.IO.File]::ReadAllText($cssPathBlue, [System.Text.Encoding]::UTF8)
    if (-not $cssTextBlue.Contains(".testimonial-author_image-wrap {")) {
        [System.IO.File]::AppendAllText($cssPathBlue, $cssAdd, $utf8NoBom)
        Write-Host "Updated CSS $cssPathBlue"
    }
}

Write-Host "Refactoring complete."
