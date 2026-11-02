# Follows the io_grid log and prints only changes that are not X10 flicker alone
# (X10 = RC75 READY toggles every few seconds). Reads the log only, no PLC access.
param([string]$Log = "$PSScriptRoot\2026-11-02_io_monitor.log")
$prev = ''
Get-Content -Path $Log -Encoding UTF8 -Tail 0 -Wait | ForEach-Object {
    if ($_ -notmatch 'X ON:') { Write-Output $_; return }
    $key = ($_ -replace '^\S+\s+', '') -replace '\b(X10|X7)\b ?', ''
    if ($key -ne $prev) { Write-Output $_; $prev = $key }
}
