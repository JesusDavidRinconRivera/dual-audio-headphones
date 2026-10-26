# 🎧 Dual Headphones Audio (Windows)

**Haz que dos audífonos suenen al mismo tiempo en una PC con Windows**, sin instalar programas sospechosos y con control total del ruteo.

## 📌 Descripción general

Windows nativamente **no permite** que una misma aplicación envíe audio a dos dispositivos de salida a la vez. Solo existe un dispositivo de reproducción predeterminado. Este proyecto resuelve esa limitación creando un **hub de audio virtual** con [Voicemeeter](https://vb-audio.com/Voicemeeter/) y automatizando toda su configuración mediante scripts **PowerShell** que hablan con:

- la **Windows Core Audio API** (interfaces COM `IMMDeviceEnumerator` / `IMMDevice`) para enumerar salidas,
- la **Voicemeeter Remote API** (`VoicemeeterRemote64.dll`) para el ruteo y la selección de dispositivos,
- la interfaz **`IPolicyConfig`** para cambiar el dispositivo de reproducción predeterminado.

> **Resultado:** cualquier app (YouTube, Discord, juegos, Spotify…) reproduce el mismo sonido **a la vez** en el audífono cableado y en el audífono Bluetooth.

---

## 🧠 El problema

Windows usa el concepto de **dispositivo de salida predeterminado**: un solo endpoint por app (el que elige el sistema). No existe `setTwoOutputsAsync()`. Para duplicar el audio se necesitan routers/interfaces intermedias.

**Voicemeeter** resuelve esto con una arquitectura de "enrutador":

```
                     ┌──────────────────────────────────────────┐
  Spotify/YouTube ──▶│  Voicemeeter Input (virtual) --- Strip    │
  Discord/Juego ────▶│  Voicemeeter Aux Input (virtual)          │──▶ A1 ──▶ AUDÍFONO CABLEADO
                     │                                          │──▶ A2 ──▶ AUDÍFONO BLUETOOTH
                     │   (controlador virtual de audio)         │
                     └──────────────────────────────────────────┘
```

- Los **virtual inputs** aparecen en Windows como dispositivos de *reproducción* (p. ej. `Voicemeeter Input`).
- Cada strip (canal) puede enviarse a varias **salidas físicas a la vez** activando los botones A1/A2/A3.
- A1 y A2 son **salidas físicas** (USB, mini-jack, Bluetooth…) elegidas por el usuario o por API.

El detalle clave: cuando activas **A1 y A2 en el mismo strip**, el audio del strip se duplica en ambas salidas **simultáneamente**.

---

## ⚙️ Requisitos

| Requisito | Detalle |
|---|---|
| Windows 10/11 x64 | Probado en Windows 11 |
| [Voicemeeter](https://vb-audio.com/Voicemeeter/) | Versión estándar ("Vanilla") o superior. Este proyecto usó v1.1.x (instalador `voicemeetersetup.exe`) |
| PowerShell 5.1+ | Viene con Windows; ejecutar como usuario normal |
| Dos audífonos conectados | Uno por salida física distinta (mini-jack y Bluetooth, o dos USB, etc.) |

---

## 🔧 Cómo se hizo (paso a paso)

### 1. Análisis de los dispositivos de audio conectados

Se identificaron las salidas activas por tres vías complementarias:

- **WMI / PnP** (`Win32_SoundDevice`, `Win32_PnPEntity`): vista de controladores de audio instalados (Realtek / AMD HDMI / USB…).
- **Registro `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render`**: cada endpoint de salida está registrado como GUID con su estado (`1=activo`, `8=desconectado`, `4=no presente`).
- **Windows Core Audio API (COM)**: enumeración robusta de endpoints con nombre amable, ID de dispositivo (`{0.0.0.00000000}.{guid}`) y estado, mediante la interfaz `IMMDeviceEnumerator`.

Resultado del análisis real de la máquina:

```
Headphones   | {0.0.0.00000000}.{f71f2190-...} | State=1   ← audífono cableado
Inalambricos | {0.0.0.00000000}.{7629fb4c-...} | State=1   ← audífono Bluetooth
Altavoces    | {0.0.0.00000000}.{38d114c5-...} | State=1
... (además S/PDIF, HDMI, y los nuevos virtuales de Voicemeeter)
```

> ⚠️ Detalle técnico: el *nombre amable* se lee de la propiedad `{a45c254e-df1c-4efd-8020-67d146a850e0},2` dentro de la clave `Properties` del endpoint (es la propiedad `PKEY_Device_FriendlyName`).

### 2. Instalación de Voicemeeter

El instalador necesita **privilegios de administrador** para registrar el driver de audio virtual (`vbaudio_vmvaio…sys`) y crear los endpoints. Tras instalarlo quedan dos "puntos de entrada" virtuales claves para nuestro caso:

- `Voicemeeter Input` → strip **VAIO** (nuestra entrada principal para Windows).
- `Voicemeeter Aux Input` → strip **AUX** (segunda entrada opcional).

### 3. Automatización con la Voicemeeter Remote API

Todo el control se hace por **P/Invoke** desde PowerShell hacia `VoicemeeterRemote64.dll`. Funciones usadas:

| Función | Propósito |
|---|---|
| `VBVMR_Login` / `VBVMR_Logout` | Conectar/desconectar con la app corriendo |
| `VBVMR_SetParameters(...)` | Texto de comandos estilo *run-bar* (`Strip[3].A1=1`, `OUT A1 "..."`) |
| `VBVMR_GetParameterFloat(...)` | Leer valor de un parámetro (verificación) |
| `VBVMR_GetVoicemeeterType` | Detectar variante (1=Vanilla / 2=Banana / 3=Potato) |

**Configuración aplicada:**

```powershell
# 1) El strip virtual (strip 3 = VAIO en el layout Vanilla) se envía a A1 y a A2
Strip[3].A1=1
Strip[3].A2=1

# 2) Las salidas físicas se eligen por nombre
OUT A1 "Headphones"
OUT A2 "Inalambricos"
```

### 4. Cambio del dispositivo predeterminado

Para que **todas** las apps usen Voicemeeter se cambia el default playback a `Voicemeeter Input` con la interfaz COM `IPolicyConfig.SetDefaultEndpoint(deviceId, role)` para los tres roles (`eConsole`, `eMultimedia`, `eCommunications`).

> ⚠️ En esta máquina `IPolicyConfig` no estaba registrado en COM (`0x80040154 REGDB_E_CLASSNOTREG`). Alternativas: marcarlo en *Configuración → Sonido*, con `SoundVolumeView`/`nircmd setdefaultsounddevice`, o hacerlo la propia Voicemeeter tras instalarse. Está documentado en "Próximas mejoras".

### 5. Uso final

1. Abre Voicemeeter (se auto-lanza con el script 01).
2. Aplica el ruteo (script 02).
3. Confirma en la ventana de Voicemeeter que **A1 = "Headphones"** y **A2 = "Inalambricos"** y que el strip VAIO tiene los botones **A1 y A2** encendidos.
4. Pon **Voicemeeter Input** como dispositivo predeterminado.
5. Reproduce lo que quieras… ¡y suena en los dos audífonos! 🔊🔊

---

## 📁 Estructura del repositorio

```
dual-audio-headphones/
├── README.md
└── scripts/
    ├── 01-enumerate-audio-devices.ps1   # Lista endpoints de salida + abre Voicemeeter
    ├── 02-configure-voicemeeter.ps1     # Ruteo A1+A2 + selección de dispositivos
    ├── 03-verify-routing.ps1            # Verifica el ruteo leído desde la API
    ├── 99a-inspect-remote-dll-exports.ps1 # ¿Qué VBVMR_* existen en la DLL? (GetProcAddress)
    ├── 99b-parse-pe-exports.ps1         # Parseo del PE para listar exports sin herramientas
    └── 99c-remote-api-probe.ps1         # Sondeo: tipo de Voicemeeter + etiquetas de strips
```

### Uso rápido

```powershell
# 1. enumerar dispositivos (y abrir Voicemeeter si no está abierto)
powershell -ExecutionPolicy Bypass -File .\scripts\01-enumerate-audio-devices.ps1

# 2. configurar ruteo (necesita el tipo [VM.AudioDevice], se carga dot-sourcing del paso 1)
powershell -ExecutionPolicy Bypass -Command ". .\scripts\01-enumerate-audio-devices.ps1; .\scripts\02-configure-voicemeeter.ps1"

# 3. verificar
powershell -ExecutionPolicy Bypass -File .\scripts\03-verify-routing.ps1
```

---

## 🎯 Puntos clave (lo más importante que se aprendió)

1. **Windows no duplica salidas de audio por diseño.** Cualquier solución pasa por un mezclador/ruteador virtual (Voicemeeter, VB-Cable + reenvío, *Stereo Mix + "Escuchar este dispositivo"*, etc.).
2. **Dos salidas físicas ⇐ un solo strip virtual.** Activar A1 y A2 en el mismo strip de Voicemeeter = duplicación simultánea.
3. **Los endpoints de Windows se guardan en `MMDevices\Audio\Render`** con estado e información útil para troubleshooting.
4. **Las interfaces COM de Core Audio no tienen binding nativo en PowerShell**: se definen con `Add-Type` (C# incrustado) y `[ComImport]`/`Marshal`.
5. **La API remota de Voicemeeter es la puerta de automatización**: `P/Invoke` a `VoicemeeterRemote64.dll` con la firma correcta.
6. **Nada de lo anterior sirve sin conocer los exports reales del DLL** (ver sección de debugging).

---

## 🐛 Debugging: problemas encontrados y cómo se resolvieron

| Problema | Síntoma | Solución |
|---|---|---|
| Interfaces COM con IIDs intercambiados | `E_NOINTERFACE 0x80004002` al crear `IMMDeviceEnumerator` | Usar los IIDs correctos del SDK: enumerador `A95664D2…`, colección `0BD7A1BE…`, device `D666063F…`, y declarar los 5 métodos del enumerador (vtable) |
| Máscara de estado inválida | `E_INVALIDARG 0x80070057` en `EnumAudioEndpoints` | `0x1F` no existe: usar `0xF` (ACTIVE\|DISABLED\|NOTPRESENT\|UNPLUGGED) |
| Ruta de registro "mágica" con fallos | `Registry.GetValue` devolvía `null`/excepción | Prefijo correcto `HKEY_LOCAL_MACHINE\` (no `HKLM:\`, es de PowerShell) y **conservar las llaves `{}`** en el GUID de la clave |
| Export no existe | `EntryPointNotFoundException: VBVMR_GetParameters` | Enumerar los exports reales con `GetProcAddress` y con un **parseador PE propio** (script 99a/99b): en esta DLL no existe `VBVMR_GetParameters` |
| `SetDefaultEndpoint` vía COM | `0x80040154 REGDB_E_CLASSNOTREG` | El `CPolicyConfigClient` no está registrado en ese sistema; fallback manual o `SoundVolumeView` (documentado) |
| Lectura de parámetro por nombre | Valor en `0` pese a `SetParameters` OK | La lectura por texto (`GetParameters`) no existe en esta build; verificar con `GetParameterFloat`/GUI o el probe 99c |

---

## 🚀 Próximas mejoras

- [ ] **Port a Python** (`ctypes` → `VoicemeeterRemote64.dll` y `comtypes`/`pycaw` para Core Audio) para un script 100% Python y multiplataforma de lectura.
- [ ] **Selección de dispositivos por índice**: usar `VBVMR_Output_GetDeviceNumber/GetDeviceDesc` para detectar y asignar nombres automáticamente.
- [ ] **Cambio de default sin IPolicyConfig**: integración con `SoundVolumeView` o `nircmd setdefaultsounddevice 'Voicemeeter Input'`.
- [ ] **Instalación silenciosa** de Voicemeeter desde el propio script (encontrar el flag del instalador de VB-Audio).
- [ ] **Configuración persistente / perfil**: guardar y restaurar el estado de Voicemeeter (fijar volúmenes, mutes).
- [ ] **Detección de latencia**: medir y compensar para que el audiófilo más exigente no note diferencias entre A1 y A2.
- [ ] **GUI mínima** en PowerShell (WinForms) para elegir los dos audífonos con comboboxes.
- [ ] **Soporte para 3+ dispositivos** (A3 / Banana / Potato) y para duplicar también el micrófono.
- [ ] **Documentación en video**: demo de YouTube + Spotify sonando en ambos audífonos a la vez.

---

## 📜 Licencia

Uso libre con fines educativos/portfolio. Voicemeeter y sus librerías son de [VB-Audio](https://vb-audio.com/); respeta su licencia para uso profesional.

---

## 🐧 Dual Audio Headphones en Linux (PipeWire/PulseAudio)

Este mismo proyecto ahora también funciona en **Linux** con **PipeWire** o **PulseAudio** usando `module-combine-sink`. No necesitas Voicemeeter, con `pactl` es suficiente.

### ¿Cómo funciona?

Se crea un sink virtual llamado `dual-audio-combined` que mezcla dos salidas físicas al mismo tiempo. Al ponerlo como salida por defecto, todo el audio irá a ambos auriculares simultáneamente.

### Requisitos

- Linux con **PipeWire** o **PulseAudio**
- `pactl` instalado (`pipewire-pulse` o `pulseaudio-utils`)
- Dos salidas de audio conectadas al mismo tiempo

### Ver salidas disponibles

```bash
pactl list sinks short
```

### ACTIVAR - Hacer que suenen los dos auriculares a la vez

Tienes dos opciones desde el repositorio:

```bash
cd ~/dual-audio-headphones
chmod +x scripts/dual-audio-linux-combine.sh scripts/combine-now.sh
./scripts/dual-audio-linux-combine.sh
# o
./scripts/combine-now.sh
```

Esto hará lo siguiente:
1. Creará el sink virtual `dual-audio-combined`
2. Lo combinará con ambos auriculares
3. Lo establecerá como salida por defecto
4. Guardará el ID del módulo en `~/.local/state/dual-audio-module.id`

### DESACTIVAR - Volver a usar solo un auricular

**Opción 1: Con script local (si lo tienes configurado)**

```bash
~/.local/bin/dual-audio-restore.sh
```

**Opción 2: Manual con el ID guardado**

```bash
MODULE_ID=$(cat ~/.local/state/dual-audio-module.id 2>/dev/null)
[ -n "$MODULE_ID" ] && pactl unload-module "$MODULE_ID"
rm -f ~/.local/state/dual-audio-module.id
pactl set-default-sink alsa_output.usb-Beibinghe_Technology_GAMING_HEADSET_GT808_433132353134352E-00.analog-stereo
```

**Opción 3: Elegir manualmente qué sink usar**

```bash
pactl list sinks short
pactl set-default-sink NOMBRE_DEL_SINK_QUE_QUIERAS_USAR
```

### Comprobar que funciona

1. Reproduce cualquier audio
2. Debería escucharse en **ambos auriculares al mismo tiempo**
3. Puedes verlo en `pavucontrol` → `Reproducción` (aparecerán las apps en `Dual Audio - Auriculares Combinados`)

### Configuración actual (este equipo)

En este sistema está configurado para combinar:

- `alsa_output.usb-Beibinghe_Technology_GAMING_HEADSET_GT808_433132353134352E-00.analog-stereo` (GAMING HEADSET GT808)
- `alsa_output.pci-0000_00_14.2.analog-stereo` (Audio Interno Estéreo analógico)

### Notas para Linux

- Funciona con **PipeWire** y **PulseAudio**
- Si alguna app mantiene su salida antigua, cámbiala desde `pavucontrol`
- Si desconectas un auricular, vuelve a ejecutar el script para recrear la combinación
- Puedes activar autoinicio con `systemctl --user enable --now dual-audio.service`

### Scripts para Linux

| Archivo | Descripción |
| --- | --- |
| `scripts/combine-now.sh` | **ACTIVAR** - Combina los dos auriculares configurados |
| `scripts/dual-audio-linux-combine.sh` | **ACTIVAR** - Misma función, nombre más descriptivo |

