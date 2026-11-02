# Watches the io_grid log (no PLC access) and prints one line for every X0 OFF -> ON
# edge. Standing rule (user, 2026-11-02): each X0 rise -> pulse Y3 ON ~1 s then OFF.
# -Once exits after the first rise.
param([string]$Log = "$PSScriptRoot\2026-11-02_io_monitor.log", [switch]$Once)
$all = @(Get-Content -Path $Log -Encoding UTF8)
$start = $all.Count
# start from the current X0 state so an edge already in progress is not missed
$last = $all | Where-Object { $_ -match 'X ON:' } | Select-Object -Last 1
$wasOff = $last -and ($last -notmatch 'X ON:[^|]*\bX0\b')
while ($true) {
    $lines = @(Get-Content -Path $Log -Encoding UTF8 | Select-Object -Skip $start)
    foreach ($l in $lines) {
        if ($l -notmatch 'X ON:') { continue }
        $on = $l -match 'X ON:[^|]*\bX0\b'
        if (-not $on) { $wasOff = $true }
        elseif ($wasOff) {
            Write-Output "X0 RISE: $l"
            $wasOff = $false
            if ($Once) { exit 0 }
        }
    }
    $start += $lines.Count
    Start-Sleep -Milliseconds 200
}
