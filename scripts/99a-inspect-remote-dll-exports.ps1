# 99a - inspect-remote-dll-exports.ps1
# ---------------------------------------------------------------
# Shows which VBVMR_* functions actually exist in
# VoicemeeterRemote64.dll. This is how the correct API export names
# were discovered during the project (the name that "everyone uses"
# is not always present on every Voicemeeter build).
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\99a-inspect-remote-dll-exports.ps1
# ---------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class L {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, SetLastError=true)]
    public static extern IntPtr GetProcAddress(IntPtr h, string name);
}
'@

$dll = "C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll"
$h = [L]::LoadLibraryEx($dll, [IntPtr]::Zero, 0)
if ($h -eq [IntPtr]::Zero) { Write-Output "LoadLibraryEx failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 1 }

$names = @(
'VBVMR_Login','VBVMR_Logout',
'VBVMR_SetParameters','VBVMR_SetParametersA','VBVMR_SetParametersW',
'VBVMR_GetParameters','VBVMR_GetParametersA','VBVMR_GetParametersW',
'VBVMR_SetParameterFloat','VBVMR_SetParameterFloatA','VBVMR_SetParameterFloatW',
'VBVMR_GetParameterFloat','VBVMR_GetParameterFloatA','VBVMR_GetParameterFloatW',
'VBVMR_SetParameterString','VBVMR_SetParameterStringA','VBVMR_SetParameterStringW',
'VBVMR_GetParameterString','VBVMR_GetParameterStringA','VBVMR_GetParameterStringW',
'VBVMR_IsParametersDirty','VBVMR_IsParametersDirtyA','VBVMR_IsParametersDirtyW',
'VBVMR_GetVoicemeeterType','VBVMR_GetVoicemeeterVersion',
'VBVMR_Output_GetDeviceNumber','VBVMR_Output_GetDeviceDescA','VBVMR_Output_GetDeviceDescW',
'VBVMR_Input_GetDeviceNumber','VBVMR_Input_GetDeviceDescA','VBVMR_Input_GetDeviceDescW',
'VBVMR_RunVoicemeeter'
)
foreach ($n in $names) {
    $p = [L]::GetProcAddress($h, $n)
    Write-Output ("{0,-32} {1}" -f $n, ($p -ne [IntPtr]::Zero))
}