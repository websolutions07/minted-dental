<#
.SYNOPSIS
  Tiny static file server for previewing the site. No Python or Node required.

.EXAMPLE
  .\Serve.ps1
  .\Serve.ps1 -Port 8200
#>
param(
    [int]$Port = 8123
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.png'  = 'image/png'
    '.webp' = 'image/webp'
    '.gif'  = 'image/gif'
    '.ico'  = 'image/x-icon'
    '.woff' = 'font/woff'
    '.woff2' = 'font/woff2'
    '.ttf'  = 'font/ttf'
    '.txt'  = 'text/plain; charset=utf-8'
    '.map'  = 'application/json'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try {
    $listener.Start()
}
catch {
    Write-Host "Could not bind port $Port. Try another:  .\Serve.ps1 -Port 8200" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Serving $root" -ForegroundColor Cyan
Write-Host "  http://127.0.0.1:$Port/index.html" -ForegroundColor Green
Write-Host "  http://127.0.0.1:$Port/variant-blue/index.html" -ForegroundColor Green
Write-Host ""
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        # One malformed or aborted request must never take the whole preview down.
        try {

        $rel = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
        if ($rel -eq '') { $rel = 'index.html' }
        $path = Join-Path $root ($rel -replace '/', '\')

        if ((Test-Path $path) -and (Get-Item $path).PSIsContainer) {
            $path = Join-Path $path 'index.html'
        }

        # A HEAD request must carry the headers but NO body. Writing one anyway throws
        # ProtocolViolationException ("bytes exceed the Content-Length specified"), which
        # used to kill the whole server on the first HEAD any tool sent.
        $isHead = ($req.HttpMethod -eq 'HEAD')

        if (Test-Path $path -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($path).ToLower()
            $ct = $mime[$ext]
            if (-not $ct) { $ct = 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $res.StatusCode = 200
            $res.ContentType = $ct
            $res.Headers.Add('Cache-Control', 'no-store')
            $res.ContentLength64 = $bytes.Length
            if (-not $isHead) { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
            Write-Host ("  {0}  {1}" -f $(if ($isHead) { '200H' } else { '200 ' }), $rel) -ForegroundColor DarkGray
        }
        else {
            $res.StatusCode = 404
            $fourOhFour = Join-Path $root '404.html'
            if (Test-Path $fourOhFour) {
                $bytes = [System.IO.File]::ReadAllBytes($fourOhFour)
                $res.ContentType = 'text/html; charset=utf-8'
            }
            else {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                $res.ContentType = 'text/plain; charset=utf-8'
            }
            $res.ContentLength64 = $bytes.Length
            if (-not $isHead) { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
            Write-Host ("  404  " + $rel) -ForegroundColor Yellow
        }
        $res.OutputStream.Close()

        }
        catch {
            Write-Host ("  ERR  " + $_.Exception.Message.Split([char]10)[0]) -ForegroundColor Red
            try { $res.OutputStream.Close() } catch { }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
