#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/usb-mic-zips.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT

install_stage="$staging_dir/install"
disable_stage="$staging_dir/disable"
mkdir -p "$install_stage/payload" "$disable_stage"

cp -R "$project_dir/recovery-install-usb-mic-runtime/META-INF" "$install_stage/"
cp "$project_dir/diagnostics/audio-policy/usb-mic-runtime.rc" \
    "$install_stage/payload/usb-mic-runtime.rc"
cp "$project_dir/diagnostics/audio-policy/usb-mic-runtime.sh" \
    "$install_stage/payload/usb-mic-runtime.sh"
cp "$project_dir/diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk" \
    "$install_stage/payload/usb-mic-route.apk"

cp -R "$project_dir/recovery-usb-mic-runtime/META-INF" "$disable_stage/"
chmod +x "$install_stage/META-INF/com/google/android/update-binary"
chmod +x "$disable_stage/META-INF/com/google/android/update-binary"

(
    cd "$install_stage"
    zip -qr "$staging_dir/install-usb-mic-boot-automation-rpi5.zip" META-INF payload
)
(
    cd "$disable_stage"
    zip -qr "$staging_dir/disable-usb-mic-boot-automation-rpi5.zip" META-INF
)

mv "$staging_dir/install-usb-mic-boot-automation-rpi5.zip" "$project_dir/"
mv "$staging_dir/disable-usb-mic-boot-automation-rpi5.zip" "$project_dir/"

shasum -a 256 \
    "$project_dir/install-usb-mic-boot-automation-rpi5.zip" \
    "$project_dir/disable-usb-mic-boot-automation-rpi5.zip"
