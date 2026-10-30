# 把 shots.js 的每一張步驟圖輸出成 png\<id>.png（840×512，Chrome headless）
$ErrorActionPreference = 'Stop'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$here = $PSScriptRoot
$out = Join-Path $here 'png'
New-Item -ItemType Directory -Force $out | Out-Null
$src = Get-Content -Raw -Encoding utf8 (Join-Path $here 'shots.js')
$ids = [regex]::Matches($src, '(?m)^\s{2}(\w+):\s*\{') | ForEach-Object { $_.Groups[1].Value }
$page = 'file:///' + ((Join-Path $here 'shots.html') -replace '\\', '/')
foreach ($id in $ids) {
    $png = Join-Path $out "$id.png"
    & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --allow-file-access-from-files --virtual-time-budget=2000 `
        --window-size=840,512 --screenshot="$png" "$page`?$id" 2>$null | Out-Null
}
"$($ids.Count) shots -> $out"
