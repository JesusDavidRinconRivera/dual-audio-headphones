# 99c - remote-api-probe.ps1
# ---------------------------------------------------------------
# Small probe used during development to identify:
#   * the Voicemeeter build (type + version),
#   * which strip index is the virtual input (reads each strip label),
#   * whether GetParameterFloat("Strip[3].A1") reads back what we set.
#
# Useful to confirm the strip mapping if your layout differs from
# the default Vanilla layout (HW1-HW3 + VAIO + AUX => strip 3 = VAIO).
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\99c-remote-api-probe.ps1
# ---------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class VM3 {
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Login", CallingConvention = CallingConvention.StdCall)]
    public static extern int Login();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_Logout", CallingConvention = CallingConvention.StdCall)]
    public static extern void Logout();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_SetParameters", CallingConvention = CallingConvention.StdCall)]
    public static extern int SetParameters(string p);
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetParameterFloat", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetParameterFloat([MarshalAs(UnmanagedType.LPStr)] string type, ref float value);
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetParameterStringW", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetParameterStringW([MarshalAs(UnmanagedType.LPWStr)] string type, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int max);
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetVoicemeeterType", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetVoicemeeterType();
    [DllImport(@"C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll", EntryPoint = "VBVMR_GetVoicemeeterVersion", CallingConvention = CallingConvention.StdCall)]
    public static extern int GetVoicemeeterVersion();
}
'@

$login = [VM3]::Login()
Write-Output "Login: $login"
if ($login -ne 0) { exit 1 }

$type = [VM3]::GetVoicemeeterType()
$ver  = [VM3]::GetVoicemeeterVersion()
Write-Output ("Type: {0} (1=Vainilla, 2=Banana, 3=Potato)  Version: 0x{1:X}" -f $type, $ver)

# Write then read back to validate GetParameterFloat(string name).
$hr = [VM3]::SetParameters("Strip[3].A2=1`nStrip[3].A1=0")
Write-Output ("Set Strip[3] A2/A1 hr: {0}" -f $hr)
Start-Sleep -Milliseconds 300
$v = [float]0
$hrg = [VM3]::GetParameterFloat("Strip[3].A2", [ref]$v)
Write-Output ("GetParameterFloat('Strip[3].A2') hr={0} value={1}" -f $hrg, $v)

# Print strip labels to identify the virtual input index.
foreach ($i in 0..4) {
    $sb = New-Object System.Text.StringBuilder 512
    $hrs = [VM3]::GetParameterStringW(("Strip[{0}].label" -f $i), $sb, $sb.Capacity)
    Write-Output ("Strip[{0}].label hr={1} => '{2}'" -f $i, $hrs, $sb.ToString())
}

[VM3]::Logout()