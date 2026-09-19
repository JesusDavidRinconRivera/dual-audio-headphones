# 02 - configure-voicemeeter.ps1
# ---------------------------------------------------------------
# Drives Voicemeeter through its Remote API (VoicemeeterRemote64.dll)
# using P/Invoke.
#
# What it does:
#   1. Logs into the Voicemeeter Remote API.
#   2. Routes the virtual input strip ("Voicemeeter VAIO", Strip[3] in the
#      standard/Vanilla layout: HW1-HW3 + VAIO + AUX) to BOTH hardware
#      outputs A1 and A2 at the same time -> same audio in two headphones.
#   3. Selects the two physical output devices by name
#      ("Headphones" wired, "Inalambricos" wireless).
#   4. Tries to set "Voicemeeter Input" as the Windows default playback
#      device (through the [VM.AudioDevice] helper defined in script 01).
#
# NOTE: dot-source script 01 first so the [VM.AudioDevice] type exists.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -Command ". .\01-enumerate-audio-devices.ps1; .\02-configure-voicemeeter.ps1"
# ---------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class VMRemote {
    // Export names verified against the actual DLL (see 99a / 99b).
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Login", CallingConvention = CallingConvention.StdCall)]
    public static extern int Login();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Logout", CallingConvention = CallingConvention.StdCall)]
    public static extern void Logout();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_SetParameters", CallingConvention = CallingConvention.StdCall)]
    public static extern int SetParameters(string parameters);
}
'@

$login = [VMRemote]::Login()
Write-Output "Login result: $login (0 = OK)"
if ($login -ne 0) { Write-Output "ERROR: cannot connect to Voicemeeter. Is it running?"; exit 1 }

# --- Step 1: route the virtual VAIO strip to A1 and A2 --------------------
$script = @"
Strip[3].A1=1
Strip[3].A2=1
"@
$hr = [VMRemote]::SetParameters($script)
Write-Output ("Routing VAIO strip -> A1/A2  hr: 0x{0:X}  (0 = OK)" -f $hr)

# --- Step 2: pick the two physical output devices by name -----------------
$scriptDev = @"
OUT A1 "Headphones"
OUT A2 "Inalambricos"
"@
$hrDev = [VMRemote]::SetParameters($scriptDev)
Write-Output ("Select OUT A1='Headphones', OUT A2='Inalambricos'  hr: 0x{0:X}  (0 = OK)" -f $hrDev)

[VMRemote]::Logout()

# --- Step 3: make Voicemeeter Input the default playback device -----------
Write-Output ""
Write-Output "Setting default playback device to 'Voicemeeter Input'..."
$devId = '{0.0.0.00000000}.{3b1a5411-fc5c-4d44-82ee-159f3c99d8c3}'
try {
    $hrDefault = [VM.AudioDevice]::SetDefault($devId)
    Write-Output ("SetDefault hr: 0x{0:X}  (0 = OK)" -f $hrDefault)
    if ($hrDefault -ne 0) {
        Write-Output "TIP: set it manually: Settings > Sound > Playback > 'Voicemeeter Input'."
    }
} catch {
    Write-Output "SetDefault error: $_"
    Write-Output "TIP: set it manually: Settings > Sound > Playback > 'Voicemeeter Input'."
}