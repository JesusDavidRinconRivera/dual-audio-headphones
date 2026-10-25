# Dual Audio Headphones - Linux (PipeWire/PulseAudio)

Versión adaptada de [dual-audio-headphones](https://github.com/JesusDavidRinconRivera/dual-audio-headphones) para **Linux** usando PipeWire/PulseAudio con `module-combine-sink`.

Con esto puedes hacer que **dos salidas de audio suenen al mismo tiempo** (ideal para tener dos auriculares reproduciendo lo mismo).

## Dispositivos configurados en este sistema

En mi caso con los siguientes auriculares:

- `alsa_output.usb-Beibinghe_Technology_GAMING_HEADSET_GT808_...-00.analog-stereo` → **GAMING HEADSET GT808**
- `alsa_output.pci-0000_00_14.2.analog-stereo` → **Audio Interno Estéreo analógico**

## ¿Cómo funciona?

Se crea un *sink* virtual llamado `dual-audio-combined` que mezcla ambas salidas físicas. Al ponerlo como salida por defecto, **cualquier aplicación** enviará el audio a ambos auriculares simultáneamente.

## Requisitos

- Linux con **PipeWire** o **PulseAudio**
- `pactl` instalado (normalmente viene con `pipewire-pulse` o `pulseaudio-utils`)
- **Dos salidas de audio activadas** al mismo tiempo (dos auriculares, auricular + altavoces, etc.)

## Uso rápido

### 1) Ver salidas disponibles

```bash
pactl list sinks short
```

### 2) Combinar ambos auriculares

Desde el directorio del repositorio:

```bash
cd ~/dual-audio-headphones
chmod +x scripts/dual-audio-linux-combine.sh
./scripts/dual-audio-linux-combine.sh
```

O directamente:

```bash
./scripts/combine-now.sh
```

Con eso automáticamente:
- Crea el sink `dual-audio-combined`
- Lo establece como **salida por defecto**
- Envía el audio a ambos auriculares al mismo tiempo

### 3) Restaurar a un solo auricular

Si quieres volver a usar solo el auricular USB:

```bash
MODULE_ID=$(cat ~/.local/state/dual-audio-module.id 2>/0)
pactl unload-module $MODULE_ID 2>/dev/null
rm -f ~/.local/state/dual-audio-module.id
pactl set-default-sink alsa_output.usb-Beibinghe_Technology_GAMING_HEADSET_GT808_433132353134352E-00.analog-stereo
```

O simplemente con:
```bash
~/.local/bin/dual-audio-restore.sh
```

## Verificar funcionamiento

1. Reproduce cualquier audio (YouTube, Spotify, VLC...)
2. Debería escucharse **en los dos auriculares al mismo tiempo**
3. Puedes verificarlo con `pavucontrol` → Pestaña **Reproducción** (verás las apps en `Dual Audio - Auriculares Combinados`)

## Notas

- Si desconectas uno de los auriculares mientras está combinado, puede haber un pequeño corte. Solo vuelve a ejecutar el script para recrearlo.
- Algunas aplicaciones guardan su propia ruta de salida. Si alguna no va al combinado, cámbiala manualmente desde `pavucontrol`.
- Funciona tanto con **PipeWire** como con **PulseAudio puro**.
- El servicio `systemctl --user enable dual-audio.service` intenta hacerlo automático al inicio de sesión.

## Scripts incluidos

| Archivo | Descripción |
| --- | --- |
| `scripts/combine-now.sh` | Combina los dos auriculares configurados para este equipo |
| `scripts/dual-audio-linux-combine.sh` | Copia funcional con nombres claros |
| `scripts/01-enumerate-audio-devices.ps1` | Original Windows (PowerShell) |
| `scripts/02-configure-voicemeeter.ps1` | Original Windows (Voicemeeter) |

**Créditos:** Basado en el proyecto original para Windows con Voicemeeter. Adaptado a Linux con PipeWire/PulseAudio.
