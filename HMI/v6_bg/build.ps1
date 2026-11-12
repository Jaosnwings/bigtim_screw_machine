# v6：Chrome headless 把 HTML 轉成 800x480 圖。
#   home.html   -> bg_home.png/.bmp（背景）、home_preview.png（?demo 範例值）
#   detail.html -> bg_detail.png/.bmp（詳細頁 Base 6 背景 = v4 自動頁 + 標題改字 + 回首頁鈕）
$ErrorActionPreference = 'Continue'   # Chrome 會往 stderr 印無害警告
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
Add-Type -AssemblyName System.Drawing

function Shot([string]$page, [string]$query, [string]$outName) {
    $path = Join-Path $here $page
    $url = 'file:///' + $path.Replace('\', '/') + $query
    $out = Join-Path $here $outName
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --window-size=800,480 "--screenshot=$out" $url 2>$null | Out-Null
    Start-Sleep -Milliseconds 300
    "$out  $((Get-Item $out).Length) bytes"
}
function ToBmp([string]$name) {
    $img = [Drawing.Image]::FromFile((Join-Path $here "$name.png"))
    $bmp = New-Object Drawing.Bitmap 800, 480, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($bmp); $g.DrawImage($img, 0, 0, 800, 480); $g.Dispose(); $img.Dispose()
    $bmp.Save((Join-Path $here "$name.bmp"), [Drawing.Imaging.ImageFormat]::Bmp); $bmp.Dispose()
}

Shot 'home.html' '' 'bg_home.png'
Shot 'home.html' '?demo' 'home_preview.png'
Shot 'detail.html' '' 'bg_detail.png'
ToBmp 'bg_home'
ToBmp 'bg_detail'
