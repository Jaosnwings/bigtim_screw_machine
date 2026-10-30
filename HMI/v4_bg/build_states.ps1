# 把 states.html 裡的每個狀態輸出成剛好零件大小的 PNG（states\<id>.png）
$ErrorActionPreference = 'Stop'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
$out = Join-Path $here 'states'
New-Item -ItemType Directory -Force $out | Out-Null
$src = Get-Content -Raw -Encoding utf8 (Join-Path $here 'states.html')
$items = [regex]::Matches($src, '(?m)^\s*(\w+):\s*\[(\d+),\s*(\d+),')
foreach ($m in $items) {
    $id = $m.Groups[1].Value; $w = $m.Groups[2].Value; $h = $m.Groups[3].Value
    $url = 'file:///' + ((Join-Path $here 'states.html') -replace '\\', '/') + "?$id"
    $png = Join-Path $out "$id.png"
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --window-size="$w,$h" --screenshot="$png" $url 2>$null | Out-Null
}
"$($items.Count) states -> $out"
