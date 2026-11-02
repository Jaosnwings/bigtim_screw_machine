# IO 側錄（只讀，不寫 PLC）：FX5S MODBUS/TCP 502，預設每 0.1 秒讀 X0～X17、Y0～Y15，
# 有任何點變化就寫一行 CSV（UTF-8 BOM，Excel 可直接開），每 10 秒另寫一行 alive 方便看出斷線空檔。
# PLC 只有一個 MODBUS 連線位：側錄時不要同時跑 io_grid.ps1 或其他 Modbus 工具。
# 用法：powershell -File io_rec.ps1 [-Tag 治具測試] [-IntervalMs 100] [-HoldStart 0 -HoldCount 0] [-Plc 192.168.1.21]
#   -HoldStart/-HoldCount：另外記錄 holding register（0 = D7000）。v3.2 把步序 D100 等複製到 D7xxx 後再用。
# 停止：Ctrl+C。
param(
    [string]$Plc = '192.168.1.21',
    [int]$Port = 502,
    [int]$IntervalMs = 100,
    [string]$Tag = '',
    [string]$Out = '',
    [int]$HoldStart = -1,
    [int]$HoldCount = 0
)
$ErrorActionPreference = 'Stop'
if (-not $Out) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $suffix = if ($Tag) { "_$Tag" } else { '' }
    $Out = Join-Path $PSScriptRoot "io_rec_$stamp$suffix.csv"
}

$xNames = 0..15 | ForEach-Object { 'X' + [Convert]::ToString($_, 8) }                  # X0..X7, X10..X17
$yIdx = @(0..7) + @(8..13)                                                              # Y0..Y7, Y10..Y15（Y16/Y17 沒有實體點）
$yNames = $yIdx | ForEach-Object { 'Y' + [Convert]::ToString($_, 8) }
$hNames = if ($HoldCount -gt 0) { 0..($HoldCount - 1) | ForEach-Object { 'D' + (7000 + $HoldStart + $_) } } else { @() }

$script:cli = $null
$script:tid = 0
function Read-Modbus([int]$fc, [int]$addr, [int]$n) {
    if (-not $script:cli -or -not $script:cli.Connected) {
        $script:cli = New-Object Net.Sockets.TcpClient($Plc, $Port)
        $script:cli.NoDelay = $true
        $script:cli.GetStream().ReadTimeout = 2000
    }
    try {
        $s = $script:cli.GetStream()
        $script:tid = ($script:tid + 1) % 65536
        $req = [byte[]]([byte]($script:tid -shr 8), [byte]($script:tid -band 255), 0, 0, 0, 6, 1, $fc,
                        [byte]($addr -shr 8), [byte]($addr -band 255), [byte]($n -shr 8), [byte]($n -band 255))
        $s.Write($req, 0, $req.Length)
        $buf = New-Object byte[] 300
        $got = 0
        while ($got -lt 9 -or $got -lt (9 + $buf[8])) {
            $r = $s.Read($buf, $got, 300 - $got)
            if ($r -le 0) { throw 'connection closed by PLC' }
            $got += $r
        }
        if ($buf[7] -ge 0x80) { throw "Modbus exception $($buf[8])" }
        $o = New-Object int[] $n
        if ($fc -le 2) {
            for ($i = 0; $i -lt $n; $i++) { $o[$i] = ($buf[9 + [math]::Floor($i / 8)] -shr ($i % 8)) -band 1 }
        } else {
            for ($i = 0; $i -lt $n; $i++) { $o[$i] = [int16](($buf[9 + 2 * $i] -shl 8) -bor $buf[10 + 2 * $i]) }
        }
        return , $o
    } catch {
        if ($script:cli) { $script:cli.Close() }
        $script:cli = $null
        throw
    }
}

$w = New-Object IO.StreamWriter($Out, $false, (New-Object Text.UTF8Encoding($true)))
$w.AutoFlush = $true
$w.WriteLine((@('time', 'ms', 'event', 'changed') + $xNames + $yNames + $hNames) -join ',')
$sw = [Diagnostics.Stopwatch]::StartNew()
function Write-Row($event, $changed, $vals) {
    $t = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $w.WriteLine((@($t, $sw.ElapsedMilliseconds, $event, $changed) + $vals) -join ',')
}

Write-Host "IO 側錄 → $Out"
Write-Host "PLC $Plc，每 $IntervalMs ms 讀一次；Ctrl+C 停止。"
$prev = $null
$rows = 0; $polls = 0; $errs = 0
$lastAlive = 0; $lastErr = ''
$winStart = $sw.ElapsedMilliseconds; $winPolls = 0
try {
    while ($true) {
        $t0 = $sw.ElapsedMilliseconds
        try {
            $x = Read-Modbus 2 0 16
            $yAll = Read-Modbus 1 0 16
            $y = $yIdx | ForEach-Object { $yAll[$_] }
            $h = if ($HoldCount -gt 0) { @(Read-Modbus 3 $HoldStart $HoldCount) } else { @() }
            $vals = @($x) + @($y) + @($h)
            $polls++; $winPolls++
            if ($lastErr) { Write-Row 'reconnect' $lastErr $vals; $rows++; $lastErr = '' }
            if ($null -eq $prev) {
                Write-Row 'start' '' $vals; $rows++
            } else {
                $ch = @()
                $names = $xNames + $yNames + $hNames
                for ($i = 0; $i -lt $vals.Count; $i++) {
                    if ($vals[$i] -ne $prev[$i]) {
                        if ($i -lt 30) { $ch += $names[$i] + $(if ($vals[$i]) { '↑' } else { '↓' }) }
                        else { $ch += "$($names[$i])=$($vals[$i])" }
                    }
                }
                if ($ch.Count) { Write-Row 'change' ($ch -join ' ') $vals; $rows++; $lastChange = "$(Get-Date -Format 'HH:mm:ss.fff') $($ch -join ' ')" }
                elseif ($t0 - $lastAlive -ge 10000) { Write-Row 'alive' '' $vals; $rows++; $lastAlive = $t0 }
            }
            $prev = $vals
        } catch {
            $errs++
            $msg = $_.Exception.Message -replace ',', ';'
            if ($msg -ne $lastErr) { Write-Row 'error' $msg @(); $rows++ }
            $lastErr = $msg
            Start-Sleep -Milliseconds 1000
        }
        if ($sw.ElapsedMilliseconds - $winStart -ge 2000) {
            $rate = [math]::Round(($sw.ElapsedMilliseconds - $winStart) / [math]::Max(1, $winPolls))
            $status = "{0}  讀 {1} 次  寫 {2} 列  錯誤 {3}  實際間隔 ~{4} ms  最後變化：{5}" -f (Get-Date -Format 'HH:mm:ss'), $polls, $rows, $errs, $rate, $lastChange
            Write-Host ("`r" + $status.PadRight(110).Substring(0, 110)) -NoNewline
            $winStart = $sw.ElapsedMilliseconds; $winPolls = 0
        }
        $left = $IntervalMs - ($sw.ElapsedMilliseconds - $t0)
        if ($left -gt 0) { Start-Sleep -Milliseconds $left }
    }
} finally {
    $w.Close()
    if ($script:cli) { $script:cli.Close() }
    Write-Host ''
    Write-Host "已停止，CSV：$Out"
}
