# 03 - verify-routing.ps1
# ---------------------------------------------------------------
# Reads back the current routing state from the Voicemeeter Remote
# API. On the standard/Vanilla layout Strip[3] is the virtual
# "Voicemeeter VAIO" input; A1/A2 are the hardware output buses.
#
# If your strip mapping differs, run script 99c (remote API probe)
# to print each strip label and adjust the index.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\03-verify-routing.ps1
# ---------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class VMRemote4 {
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Login", CallingConvention = CallingConvention.StdCall)]
    public static extern int Login();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Logout", CallingConvention = CallingConvention.StdCall)]
    public static extern void Logout();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetParameterFloat", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetParameterFloat([MarshalAs(UnmanagedType.LPStr)] string type, ref float value);
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetVoicemeeterType", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetVoicemeeterType();
}
'@

$login = [VMRemote4]::Login()
if ($login -ne 0) { Write-Output "Cannot connect to Voicemeeter."; exit 1 }

$t = [VMRemote4]::GetVoicemeeterType()
Write-Output ("Voicemeeter type: {0} (1=Vainilla, 2=Banana, 3=Potato)" -f $t)

$vA1 = [float]0; $vA2 = [float]0
[VMRemote4]::GetParameterFloat("Strip[3].A1", [ref]$vA1) | Out-Null
[VMRemote4]::GetParameterFloat("Strip[3].A2", [ref]$vA2) | Out-Null

Write-Output ("Strip[3].A1 (HW output 1) = {0}   -> should be 1" -f $vA1)
Write-Output ("Strip[3].A2 (HW output 2) = {0}   -> should be 1" -f $vA2)

if ($vA1 -eq 1 -and $vA2 -eq 1) {
    Write-Output "OK: virtual input is routed to BOTH hardware outputs."
} else {
    Write-Output "WARNING: routing is not set. Run script 02, or check strip index with 99c."
}

[VMRemote4]::Logout()