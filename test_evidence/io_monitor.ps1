# Read-only I/O monitor: polls the FX5S every 0.5 s over Modbus TCP
# (FC1 coils = Y, FC2 inputs = X) and prints/logs a line whenever X or Y changes.
# Never writes to the PLC. ASCII only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
# Usage: powershell -File io_monitor.ps1 [-Log <path>]
param([string]$Log = "$PSScriptRoot\2026-11-02_io_monitor.log", [string]$Plc = '192.168.1.21')

# One persistent connection (the PLC drops some replies when a new socket is opened
# every poll); reconnect only after an error.
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
            if ($r -le 0) { throw "connection closed by PLC" }
            $got += $r
        }
        if ($buf[7] -ge 0x80) { throw "Modbus exception $($buf[8])" }
        $o = @()
        for ($i = 0; $i -lt $n; $i++) { $o += [int](($buf[9 + [math]::Floor($i / 8)] -shr ($i % 8)) -band 1) }
        return ,$o
    } catch {
        $script:cli.Close(); $script:cli = $null
        throw
    }
}

function Fmt($pre, $bits) {
    $out = @()
    for ($i = 0; $i -lt $bits.Count; $i++) { if ($bits[$i]) { $out += $pre + [Convert]::ToString($i, 8) } }
    if ($out.Count) { $out -join ' ' } else { '-' }
}

function Emit($text) {
    $line = "$(Get-Date -Format 'HH:mm:ss.fff') $text"
    Write-Output $line
    Add-Content -Path $Log -Value $line -Encoding UTF8
}

# Y5 (yellow lamp) blinks under the program's warning: if it changed within the last
# 3 s it is shown as "Y5~blink" and its toggling is not treated as a change.
$prev = ''
$y5hist = New-Object System.Collections.ArrayList
Emit "monitor start ($Plc)"
while ($true) {
    try {
        $x = Read-Bits 2 16
        $y = Read-Bits 1 16
        [void]$y5hist.Add($y[5]); if ($y5hist.Count -gt 6) { $y5hist.RemoveAt(0) }
        $blink = (@($y5hist | Sort-Object -Unique)).Count -gt 1
        if ($blink) { $y[5] = 0 }
        $ys = Fmt 'Y' $y
        if ($blink) { $ys = (($ys -replace '^-$', '') + ' Y5~blink').Trim() }
        $line = "X ON: $(Fmt 'X' $x) | Y ON: $ys"
        if ($line -ne $prev) { Emit $line; $prev = $line }
    } catch {
        $e = "read error: $($_.Exception.Message)"
        if ($e -ne $prev) { Emit $e; $prev = $e }
    }
    Start-Sleep -Milliseconds 500
}
