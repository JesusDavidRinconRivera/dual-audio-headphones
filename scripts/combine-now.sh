#!/usr/bin/env bash
COMBINED="dual-audio-combined"
MODULE_FILE="$HOME/.local/state/dual-audio-module.id"
mkdir -p "$(dirname "$MODULE_FILE")"

# Remove old if exists
if [ -f "$MODULE_FILE" ]; then
    OLD_ID=$(cat "$MODULE_FILE")
    pactl unload-module "$OLD_ID" 2>/dev/null
    rm -f "$MODULE_FILE"
fi

SINK1="alsa_output.usb-Beibinghe_Technology_GAMING_HEADSET_GT808_433132353134352E-00.analog-stereo"
SINK2="alsa_output.pci-0000_00_14.2.analog-stereo"

echo "[INFO] Combinando:"
echo "  1) $SINK1 (GAMING HEADSET GT808)"
echo "  2) $SINK2 (Audio Interno Estéreo analógico)"
echo ""

ID=$(pactl load-module module-combine-sink \
    sink_name="$COMBINED" \
    sink_properties=device.description="Dual\ Audio\ -\ Auriculares\ Combinados" \
    slaves="$SINK1,$SINK2" \
    adjust_time=1 2>&1)

echo "$ID" > "$MODULE_FILE"
sleep 1
pactl set-default-sink "$COMBINED"
echo "[OK] Módulo cargado: ID=$ID"
echo "[OK] '$COMBINED' establecido como salida por defecto"
pactl list sinks short | grep -E "dual-audio|$SINK1|$SINK2"
