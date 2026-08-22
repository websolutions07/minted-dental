$ErrorActionPreference = 'Stop'
$root = "c:/Users/Administrator/Desktop/website dev/minted-dental/_source"
$files = Get-ChildItem -Path $root -Recurse -Include *.html

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    
    # Replace Kristin Watson's avatar
    $newText = $text -replace '\./assets/testimonials/gen_testimonial-author-1\.jpg', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&amp;auto=format&amp;fit=crop&amp;q=80'
    
    # Replace Michael Carter's avatar
    $newText = $newText -replace '\./assets/testimonials/gen_testimonial-author-2\.jpg', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&amp;auto=format&amp;fit=crop&amp;q=80'
    
    if ($text -cne $newText) {
        [System.IO.File]::WriteAllText($file.FullName, $newText, $utf8NoBom)
        Write-Host "Updated HTML $($file.FullName)"
    }
}
Write-Host "Done"
