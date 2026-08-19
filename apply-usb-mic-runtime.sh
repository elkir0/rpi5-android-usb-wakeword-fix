#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
adb_bin=${ADB_BIN:-adb}
serial=${1:-}
apk="$script_dir/diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk"
remote_apk=/data/local/tmp/speech-route.apk

find_mic_card() {
  local card controls
  for card in 0 1 2 3 4 5 6 7; do
    controls=$("$adb_bin" -s "$serial" shell "/vendor/bin/amixer -c $card scontrols" 2>/dev/null || true)
    if grep -q 'Auto Gain Control' <<<"$controls" && grep -q "'Mic'" <<<"$controls"; then
      printf '%s\n' "$card"
      return 0
    fi
  done
  return 1
}

if [[ ! -f "$apk" ]]; then
  printf 'APK de routage introuvable: %s\n' "$apk" >&2
  printf 'Reconstruire avec: cd diagnostics/speech-test && gradle :app:assembleDebug --no-daemon\n' >&2
  exit 1
fi

if [[ -z "$serial" ]]; then
  serial=$("$adb_bin" devices | awk '$2 == "device" { print $1; exit }')
fi

if [[ -z "$serial" ]]; then
  printf 'Aucun appareil ADB disponible. Fournir le serial ou IP:PORT en argument.\n' >&2
  exit 1
fi

printf 'Appareil: %s\n' "$serial"
"$adb_bin" -s "$serial" get-state >/dev/null
"$adb_bin" -s "$serial" push "$apk" "$remote_apk" >/dev/null
"$adb_bin" -s "$serial" shell chmod 0644 "$remote_apk"

if ! mic_card=$(find_mic_card); then
  printf 'Carte ALSA du microphone USB introuvable.\n' >&2
  exit 1
fi
printf 'Carte ALSA du microphone USB: %s\n' "$mic_card"

# Le niveau 20 correspond a +18 dB. Le niveau 30 (+33 dB) saturait les phrases
# longues pendant l'enrolement Voice Match.
"$adb_bin" -s "$serial" shell "/vendor/bin/amixer -c $mic_card set Mic 20 >/dev/null"
"$adb_bin" -s "$serial" shell "/vendor/bin/amixer -c $mic_card set 'Auto Gain Control' on >/dev/null"

set +e
route_output=$("$adb_bin" -s "$serial" shell \
  "CLASSPATH=$remote_apk app_process /system/bin local.raspberry.speechtest.RouteMic" 2>&1)
route_status=$?
set -e
printf '%s\n' "$route_output"

# app_process peut etre termine par Android apres System.exit(), mais les appels
# AudioSystem doivent avoir confirme les trois presets utiles.
for preset in 1 6 1999; do
  if ! grep -q "preset=$preset preferred USB result=0" <<<"$route_output"; then
    printf 'Echec du routage USB pour le preset %s (app_process=%s).\n' \
      "$preset" "$route_status" >&2
    exit 1
  fi
done

"$adb_bin" -s "$serial" shell cmd voiceinteraction disable false
"$adb_bin" -s "$serial" shell cmd voiceinteraction restart-detection

for _ in {1..10}; do
  policy=$("$adb_bin" -s "$serial" shell dumpsys media.audio_policy)
  if grep -q 'Source: 1999' <<<"$policy" && \
     grep -q 'Devices: AUDIO_DEVICE_IN_USB_DEVICE' <<<"$policy"; then
    printf 'OK: HOTWORD actif sur le microphone USB, gain +18 dB, AGC actif.\n'
    exit 0
  fi
  sleep 1
done

printf 'Le routage est applique, mais le flux HOTWORD ne s est pas active sous 10 secondes.\n' >&2
exit 2
