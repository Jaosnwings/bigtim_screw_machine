# GP-Pro EX Simulator: Screen Capture > Copy to Clipboard (menu id 32802), then save the clipboard image (800x480) as PNG.
# Usage: powershell -STA -ExecutionPolicy Bypass -File toolssim_capture.ps1 -out HMI6_bgsim_xxx.png
# The simulator window = main window of process Simulator.exe.
param([string]$out)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class CC { [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t); }
"@
[System.Windows.Forms.Clipboard]::Clear()
$sim = (Get-Process Simulator -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowHandle; if ($sim -eq $null) { $sim = [IntPtr]::Zero }; if ($sim -eq [IntPtr]::Zero) { "simulator window not found"; exit 1 }
[void][CC]::SendMessage($sim, 0x0111, [IntPtr]32802, [IntPtr]::Zero)   # WM_COMMAND Copy to Clipboard
Start-Sleep -Milliseconds 800
$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($img -eq $null) { "no image on clipboard"; exit 1 }
$img.Save($out, [Drawing.Imaging.ImageFormat]::Png)
"$out $($img.Width)x$($img.Height) $((Get-Item $out).Length) bytes"
