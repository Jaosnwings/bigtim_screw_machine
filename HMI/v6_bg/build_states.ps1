# v6 狀態圖：states.html 每個項目輸出成剛好零件大小的 PNG 與 24 位元 BMP（states\<id>.png/.bmp）
$ErrorActionPreference = 'Continue'   # Chrome 會往 stderr 印無害警告
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
$out = Join-Path $here 'states'
New-Item -ItemType Directory -Force $out | Out-Null
Add-Type -AssemblyName System.Drawing
$src = Get-Content -Raw -Encoding utf8 (Join-Path $here 'states.html')
$page = 'file:///' + (Join-Path $here 'states.html').Replace('\', '/')
$items = [regex]::Matches($src, '(?m)^\s*(\w+):\s*(?:\[(\d+),\s*(\d+),|N\()')
foreach ($m in $items) {
    $id = $m.Groups[1].Value
    if ($m.Groups[2].Success) { $w = [int]$m.Groups[2].Value; $h = [int]$m.Groups[3].Value } else { $w = 678; $h = 56 }
    $png = Join-Path $out "$id.png"
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        "--window-size=$w,$h" "--screenshot=$png" "$page`?$id" 2>$null | Out-Null
    $img = [Drawing.Image]::FromFile($png)
    $bmp = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, $w, $h); $g.Dispose()
    "$id  png=$($img.Width)x$($img.Height)"
    $img.Dispose()
    $bmp.Save((Join-Path $out "$id.bmp"), [Drawing.Imaging.ImageFormat]::Bmp); $bmp.Dispose()
}
"$($items.Count) states -> $out"
