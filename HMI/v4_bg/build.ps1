# 用 Chrome headless 把各頁 HTML 轉成 800×480 背景圖（bg_*.png）與比對用的樣本圖（demo_*.png）
$ErrorActionPreference = 'Stop'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
$pages = @('auto', 'host', 'manual', 'alarm', 'io') | Where-Object { Test-Path (Join-Path $here "$_.html") }
foreach ($p in $pages) {
    foreach ($mode in 'bg', 'demo') {
        $url = 'file:///' + ((Join-Path $here "$p.html") -replace '\\', '/')
        if ($mode -eq 'demo') { $url += '?demo' }
        $out = Join-Path $here "${mode}_$p.png"
        & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
            --window-size=800,480 --screenshot="$out" $url 2>$null | Out-Null
        Start-Sleep -Milliseconds 300
        "$out  $((Get-Item $out).Length) bytes"
    }
}
# GP-Pro EX 背景圖用 24 位元 BMP（相容性最好）
Add-Type -AssemblyName System.Drawing
foreach ($p in $pages) {
    $png = Join-Path $here "bg_$p.png"
    $img = [Drawing.Image]::FromFile($png)
    $bmp = New-Object Drawing.Bitmap 800, 480, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, 800, 480); $g.Dispose(); $img.Dispose()
    $bmp.Save((Join-Path $here "bg_$p.bmp"), [Drawing.Imaging.ImageFormat]::Bmp); $bmp.Dispose()
}
