# v6 首頁：Chrome headless 把 home.html 轉成 800×480 背景圖 bg_home.png（+ 24 位元 BMP）與範例預覽 home_preview.png
$ErrorActionPreference = 'Continue'   # Chrome 會往 stderr 印無害警告
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
$url = 'file:///' + ((Join-Path $here 'home.html') -replace '\\', '/')
foreach ($pair in @(@('bg_home.png', $url), @('home_preview.png', "$url`?demo"))) {
    $out = Join-Path $here $pair[0]
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --window-size=800,480 --screenshot="$out" $pair[1] 2>$null | Out-Null
    Start-Sleep -Milliseconds 300
    "$out  $((Get-Item $out).Length) bytes"
}
Add-Type -AssemblyName System.Drawing
$img = [Drawing.Image]::FromFile((Join-Path $here 'bg_home.png'))
$bmp = New-Object Drawing.Bitmap 800, 480, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, 800, 480); $g.Dispose(); $img.Dispose()
$bmp.Save((Join-Path $here 'bg_home.bmp'), [Drawing.Imaging.ImageFormat]::Bmp); $bmp.Dispose()
