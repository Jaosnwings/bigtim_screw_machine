# Live read-only I/O grid for the FX5S (Modbus TCP 502): redraws every 0.5 s and
# appends a line to the log whenever X or Y changes. Never writes to the PLC.
# The PLC has a single MODBUS/TCP connection slot, so run only one reader at a time.
# Usage: powershell -File io_grid.ps1 [-Log <path>] [-Plc <ip>]
param([string]$Log = "$PSScriptRoot\2026-11-02_io_monitor.log", [string]$Plc = '192.168.1.21')

$names = @{}
Import-Csv -Path "$PSScriptRoot\..\IO_device_comment_v3_1.csv" -Header Dev, Name -Encoding UTF8 |
    Where-Object { $_.Dev -match '^[XY][0-7]+$' } | ForEach-Object { $names[$_.Dev] = $_.Name }

$script:cli = $null
$script:tid = 0
function Read-Bits([int]$fc, [int]$n) {
    if (-not $script:cli -or -not $script:cli.Connected) {
        $script:cli = New-Object Net.Sockets.TcpClient($Plc, 502)
        $script:cli.GetStream().ReadTimeout = 2000
    }
    try {
        $s = $script:cli.GetStream()
        $script:tid = ($script:tid + 1) % 65536
        $req = [byte[]]([byte]($script:tid -shr 8), [byte]($script:tid -band 255), 0, 0, 0, 6, 1, $fc, 0, 0, 0, $n)
        $s.Write($req, 0, $req.Length)
        $buf = New-Object byte[] 64
        $got = 0
        while ($got -lt 9 -or $got -lt (9 + $buf[8])) {
            $r = $s.Read($buf, $got, 64 - $got)
            if ($r -le 0) { throw 'connection closed by PLC' }
            $got += $r
        }
        if ($buf[7] -ge 0x80) { throw "Modbus exception $($buf[8])" }
        $o = @()
        for ($i = 0; $i -lt $n; $i++) { $o += [int](($buf[9 + [math]::Floor($i / 8)] -shr ($i % 8)) -band 1) }
        return , $o
    } catch {
        $script:cli.Close(); $script:cli = $null
        throw
    }
}

function On-List($pre, $bits) {
    $out = @()
    for ($i = 0; $i -lt $bits.Count; $i++) { if ($bits[$i]) { $out += $pre + [Convert]::ToString($i, 8) } }
    if ($out.Count) { $out -join ' ' } else { '-' }
}

function Write-Cell($dev, $v) {
    $name = $names[$dev]; if (-not $name) { $name = '' }
    Write-Host ('{0,-4}' -f $dev) -NoNewline
    if ($v) { Write-Host ' ON  ' -NoNewline -ForegroundColor Black -BackgroundColor Green }
    else { Write-Host ' off ' -NoNewline -ForegroundColor DarkGray }
    # pad by display width: CJK characters take two columns
    $w = 0; foreach ($ch in $name.ToCharArray()) { $w += $(if ([int]$ch -gt 0x2E80) { 2 } else { 1 }) }
    Write-Host (' ' + $name + (' ' * [math]::Max(0, 30 - $w))) -NoNewline
}

$prev = ''
$y5hist = New-Object System.Collections.ArrayList
$lastErr = ''
Add-Content -Path $Log -Value "$(Get-Date -Format 'HH:mm:ss.fff') grid start ($Plc)" -Encoding UTF8
[Console]::CursorVisible = $false
Clear-Host
while ($true) {
    try {
        $x = Read-Bits 2 16
        $y = Read-Bits 1 16
        $lastErr = ''
    } catch {
        $lastErr = $_.Exception.Message
    }
    [Console]::SetCursorPosition(0, 0)
    Write-Host ("FX5S {0}   {1}   (0.5 s, read-only)          " -f $Plc, (Get-Date -Format 'HH:mm:ss.f'))
    if ($lastErr) { Write-Host ("READ ERROR: {0}" -f $lastErr).PadRight(78) -ForegroundColor Red }
    else { Write-Host (' ' * 78) }
    Write-Host ('{0,-41}{1}' -f 'INPUT', 'OUTPUT')
    if ($x -and $y) {
        for ($i = 0; $i -lt 16; $i++) {
            $o = [Convert]::ToString($i, 8)
            Write-Cell "X$o" $x[$i]
            Write-Cell "Y$o" $y[$i]
            Write-Host ''
        }
        # change log (Y5 blinks under the program's warning: ignore its toggling)
        [void]$y5hist.Add($y[5]); if ($y5hist.Count -gt 6) { $y5hist.RemoveAt(0) }
        $blink = (@($y5hist | Sort-Object -Unique)).Count -gt 1
        $yy = @($y); if ($blink) { $yy[5] = 0 }
        $ys = On-List 'Y' $yy; if ($blink) { $ys = (($ys -replace '^-$', '') + ' Y5~blink').Trim() }
        $line = "X ON: $(On-List 'X' $x) | Y ON: $ys"
        if ($line -ne $prev) {
            Add-Content -Path $Log -Value "$(Get-Date -Format 'HH:mm:ss.fff') $line" -Encoding UTF8
            $prev = $line
        }
        Write-Host ''
        Write-Host ("last change: {0}" -f $prev).PadRight(78)
    }
    Start-Sleep -Milliseconds 500
}
