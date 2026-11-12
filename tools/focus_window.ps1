# Restore one top-level window whose title contains every keyword, and bring it to the front.
# Does not start or close any program. If several windows match, the first one is used and all are listed.
# Usage: powershell -ExecutionPolicy Bypass -File tools\focus_window.ps1 "GP-Pro EX" "v6_PLCv3_14"
param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Keywords)

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class FW {
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    public static List<KeyValuePair<IntPtr, string>> List() {
        var r = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((h, p) => {
            if (!IsWindowVisible(h)) return true;
            var sb = new StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (sb.Length > 0) r.Add(new KeyValuePair<IntPtr, string>(h, sb.ToString()));
            return true;
        }, IntPtr.Zero);
        return r;
    }
}
"@

$hits = [FW]::List() | Where-Object {
    $t = $_.Value
    -not ($Keywords | Where-Object { $t.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -lt 0 })
}
if (-not $hits) { Write-Output "No visible window matches: $($Keywords -join ' + ')"; exit 1 }
foreach ($h in $hits) {
    $procId = 0; [void][FW]::GetWindowThreadProcessId($h.Key, [ref]$procId)
    $pn = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
    Write-Output ("match: 0x{0:X} [{1}] {2}" -f $h.Key.ToInt64(), $pn, $h.Value)
}
$target = @($hits)[0].Key
[void][FW]::ShowWindowAsync($target, 3)   # SW_SHOWMAXIMIZED
Start-Sleep -Milliseconds 200
$ok = [FW]::SetForegroundWindow($target)
Write-Output ("restored 0x{0:X}, SetForegroundWindow={1}" -f $target.ToInt64(), $ok)
