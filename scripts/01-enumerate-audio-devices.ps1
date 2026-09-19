# 01 - enumerate-audio-devices.ps1
# ---------------------------------------------------------------
# Enumerates every Windows audio RENDER (playback) endpoint with its
# friendly name, device ID and state, using the Core Audio
# MMDevice API via COM interop defined with Add-Type (C# in PowerShell).
#
# Why C# here: PowerShell has no native bindings for IMMDeviceEnumerator,
# so we define the COM interfaces once and reuse them from the other scripts.
#
# It also launches Voicemeeter if it is not already running.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\01-enumerate-audio-devices.ps1
# ---------------------------------------------------------------

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace VM {
    public enum EDataFlow { eRender = 0, eCapture = 1, eAll = 2 }
    public enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2 }

    // IIDs below match the Windows SDK (Mmdeviceapi.h).
    [Guid("d666063f-1587-4e43-81f1-b948e807363f"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice {
        [PreserveSig] int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        [PreserveSig] int OpenPropertyStore(int stgmAccess, out IntPtr ppProperties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        [PreserveSig] int GetState(out int pdwState);
    }

    [Guid("0bd7a1be-7a1a-44db-8397-cc5392387b5e"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection {
        [PreserveSig] int GetCount(out int pcDevices);
        [PreserveSig] int Item(int nDevice, out IMMDevice ppDevice);
    }

    [Guid("a95664d2-9614-4f35-a746-de8db63617e6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(EDataFlow dataFlow, int dwStateMask, out IMMDeviceCollection ppDevices);
        [PreserveSig] int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppDevice);
        [PreserveSig] int GetDevice(string pwstrId, out IMMDevice ppDevice);
        [PreserveSig] int RegisterEndpointNotificationCallback(object pClient);
        [PreserveSig] int UnregisterEndpointNotificationCallback(object pClient);
    }

    // Used to set the default playback endpoint (step that changes the
    // default output so every app plays through Voicemeeter).
    [Guid("294935CE-F637-4E7C-A41B-AB255460B862"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPolicyConfig {
        [PreserveSig] int GetMixFormat(string pszDeviceName, IntPtr ppFormat);
        [PreserveSig] int GetDeviceFormat(string pszDeviceName, int bDefault, IntPtr ppFormat);
        [PreserveSig] int ResetDeviceFormat(string pszDeviceName);
        [PreserveSig] int SetDeviceFormat(string pszDeviceName, IntPtr pEndpointFormat, IntPtr MixFormat);
        [PreserveSig] int GetProcessingPeriod(string pszDeviceName, int bDefault, IntPtr pmftDefaultPeriod, IntPtr pmftMinimumPeriod);
        [PreserveSig] int SetProcessingPeriod(string pszDeviceName, IntPtr pmftPeriod);
        [PreserveSig] int GetShareMode(string pszDeviceName, IntPtr pMode);
        [PreserveSig] int SetShareMode(string pszDeviceName, IntPtr mode);
        [PreserveSig] int GetPropertyValue(string pszDeviceName, int fxStore, IntPtr key, IntPtr pv);
        [PreserveSig] int SetPropertyValue(string pszDeviceName, int fxStore, IntPtr key, IntPtr pv);
        [PreserveSig] int SetDefaultEndpoint(string pszDeviceName, ERole role);
        [PreserveSig] int SetEndpointVisibility(string pszDeviceName, int bVisible);
    }

    public static class AudioDevice {
        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(ref Guid rclsid, IntPtr pUnkOuter, uint dwClsContext, ref Guid riid, out IntPtr ppv);

        private static T ComObj<T>(Guid clsid) where T : class {
            Guid i = typeof(T).GUID;
            IntPtr pv;
            // 0x1 = CLSCTX_INPROC_SERVER
            int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 0x1, ref i, out pv);
            if (hr != 0) throw new COMException("CoCreateInstance " + typeof(T).Name + " failed hr=0x" + hr.ToString("X8"));
            return (T)Marshal.GetObjectForIUnknown(pv);
        }

        public static List<string[]> GetRenderDevices() {
            var list = new List<string[]>();
            // CLSID_MMDeviceEnumerator
            var enumerator = ComObj<IMMDeviceEnumerator>(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"));
            IMMDeviceCollection coll;
            // dwStateMask = 0xF -> ACTIVE | DISABLED | NOTPRESENT | UNPLUGGED
            int hr = enumerator.EnumAudioEndpoints(EDataFlow.eRender, 0xF, out coll);
            if (hr != 0 || coll == null) throw new Exception("EnumAudioEndpoints hr=" + hr.ToString("X8"));
            int count;
            coll.GetCount(out count);
            for (int i = 0; i < count; i++) {
                try {
                    IMMDevice dev;
                    coll.Item(i, out dev);
                    string id;
                    dev.GetId(out id);
                    int state;
                    dev.GetState(out state);
                    list.Add(new string[] { GetFriendlyName(id), id, state.ToString() });
                } catch { }
            }
            return list;
        }

        // Friendly name lives in the Properties subkey of the endpoint GUID
        // under HKLM\...\MMDevices\Audio\Render\{guid}\Properties
        private static string GetFriendlyName(string id) {
            var m = Regex.Match(id, @"\{([0-9a-fA-F-]+)\}");
            if (!m.Success) return id;
            string gid = "{" + m.Groups[1].Value + "}";
            string key = @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\" + gid + @"\Properties";
            var obj = Registry.GetValue(key, "{a45c254e-df1c-4efd-8020-67d146a850e0},2", null);
            return obj == null ? id : obj.ToString();
        }

        public static int SetDefault(string deviceId) {
            // CLSID for CPolicyConfigClient (may not be registered on all systems).
            var policy = ComObj<IPolicyConfig>(new Guid("F8679F50-850A-41CF-9C72-430F290290C8"));
            int hr = policy.SetDefaultEndpoint(deviceId, ERole.eConsole);
            if (hr == 0) hr = policy.SetDefaultEndpoint(deviceId, ERole.eMultimedia);
            if (hr == 0) hr = policy.SetDefaultEndpoint(deviceId, ERole.eCommunications);
            return hr;
        }
    }
}
'@

Write-Output "=== RENDER (PLAYBACK) DEVICES ==="
$devs = [VM.AudioDevice]::GetRenderDevices()
if ($null -eq $devs) { Write-Output "No devices found." } else {
    $devs | ForEach-Object { Write-Output ("{0} | {1} | State={2}" -f $_[0], $_[1], $_[2]) }
}

Write-Output ""
Write-Output "=== LAUNCHING VOICEMEETER (if not running) ==="
$vm = Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'voicemeeter' }
if (-not $vm) {
    Start-Process "C:\Program Files (x86)\VB\Voicemeeter\voicemeeter_x64.exe"
    Write-Output "Voicemeeter launched."
} else {
    Write-Output "Voicemeeter already running (PID $($vm.ProcessId))."
}