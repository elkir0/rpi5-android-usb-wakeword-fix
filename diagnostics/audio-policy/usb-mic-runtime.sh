#!/system/bin/sh

# Late, non-blocking runtime setup for the HNHK USB microphone. This does not
# edit Audio Policy XML. All AudioSystem preferences disappear on reboot.

log_file=/data/local/tmp/usb-mic-runtime.log
route_apk=${ROUTE_APK:-/vendor/etc/usb-mic-route.apk}
: > "$log_file"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_file"
}

find_mic_card() {
    for card in 0 1 2 3 4 5 6 7; do
        controls=$(/vendor/bin/amixer -c "$card" scontrols 2>/dev/null)
        if printf '%s\n' "$controls" | grep -q "Auto Gain Control" && \
           printf '%s\n' "$controls" | grep -q "'Mic'"; then
            printf '%s\n' "$card"
            return 0
        fi
    done
    return 1
}

mic_card=
attempt=0
while [ "$attempt" -lt 30 ]; do
    mic_card=$(find_mic_card) && break
    attempt=$((attempt + 1))
    sleep 1
done

if [ -z "$mic_card" ]; then
    log "ERROR: USB microphone mixer not found"
    exit 1
fi

log "USB microphone mixer is ALSA card $mic_card"
/vendor/bin/amixer -c "$mic_card" set Mic 20 >> "$log_file" 2>&1
/vendor/bin/amixer -c "$mic_card" set "Auto Gain Control" on >> "$log_file" 2>&1

if [ ! -r "$route_apk" ]; then
    log "ERROR: route helper not readable: $route_apk"
    exit 1
fi

route_ok=false
attempt=0
while [ "$attempt" -lt 15 ]; do
    log "AudioSystem routing attempt $((attempt + 1))"
    CLASSPATH="$route_apk" /system/bin/app_process /system/bin \
        local.raspberry.speechtest.RouteMic >> "$log_file" 2>&1
    if grep -q 'preset=1999 preferred USB result=0' "$log_file" && \
       grep -q 'preset=6 preferred USB result=0' "$log_file"; then
        route_ok=true
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ "$route_ok" != true ]; then
    log "ERROR: AudioSystem USB preferences were not applied"
    exit 1
fi

/system/bin/cmd voiceinteraction disable false >> "$log_file" 2>&1
/system/bin/cmd voiceinteraction restart-detection >> "$log_file" 2>&1

attempt=0
while [ "$attempt" -lt 15 ]; do
    if /system/bin/dumpsys media.audio_policy | \
       grep -A12 'Inputs (' | grep -q 'AUDIO_DEVICE_IN_USB_DEVICE'; then
        log "OK: active Android input is routed to the USB microphone"
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 1
done

log "ERROR: HOTWORD did not become active on USB within 15 seconds"
exit 1
