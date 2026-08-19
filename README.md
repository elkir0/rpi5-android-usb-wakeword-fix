# Raspberry Pi 5 Android USB wakeword fix

Source patch, runtime USB routing helper and reproducible notes for a method
that made the Google wakeword and the complete Gemini voice interaction path
work reliably with a USB microphone on a Raspberry Pi 5.

This is a report of a method that worked on one real setup. It is not an
official KonstaKANG release and is not claimed to be a universal Android fix.

## Validated setup

- Raspberry Pi 5
- KonstaKANG LineageOS 23.2 / Android 16 build dated 2026-05-20
- MindTheGapps 16.0 ARM64
- Google account, Voice Match and Gemini configured
- mono HNHK AI-Voice USB microphone, S16_LE at 44.1/48 kHz

Validation on 2026-08-19 survived a cold reboot and produced:

- no further `incomplete data received` or inserted-silence messages;
- AudioFlinger `readErrors=0` and `silenced=false` after millions of frames;
- Google hotword score `0.979187`;
- speaker verification score `0.734375`;
- Assistant/Gemini opened and played its voice response.

## Root cause

The working method has two complementary layers.

### 1. Runtime USB routing

The tested build advertises a non-functional built-in microphone. Some Google
capture presets selected it instead of the working USB input. Android's
`AudioSystem` preferences are also volatile and disappear on reboot.

The late boot service in `diagnostics/audio-policy/`:

- prefers USB for MIC (1), VOICE_RECOGNITION (6) and HOTWORD (1999);
- marks the non-functional built-in microphone unavailable;
- sets the tested microphone gain to 20/30 and enables AGC;
- restarts software hotword detection after boot completes.

### 2. Synchronous ALSA input

The Android 16 Raspberry Vanilla `StreamAlsa` input path uses a background ALSA
reader and a non-blocking `MonoPipe`. With the 5 ms / 240-frame blocks used by
the hotword path, AudioFlinger can read before the pipe has been filled. The
HAL then replaces the missing block with silence:

```text
AHAL_StreamAlsa: transfer: incomplete data received, inserting 240 frames of silence
```

`patches/0002-audio-alsa-read-input-synchronously.patch` changes input only:

- input reads synchronously with `proxy_read_with_retries()` in `transfer()`;
- the existing asynchronous implementation remains unchanged for output;
- no Audio Policy XML is modified.

This is a narrow backport of the input architecture already used by the
Raspberry Vanilla Android 17 branch. The previous
`ro.audio.usb.period_us=20000` experiment did not remove the race and is not
used by the final method.

## Repository contents

```text
patches/                         Android 16 StreamAlsa source patch
diagnostics/audio-policy/        late boot routing service and script
diagnostics/speech-test/         source for the AudioSystem routing helper
recovery-*/META-INF/             source for the TWRP installers
docs/TUTORIEL-FR.md              full investigation and procedure in French
apply-usb-mic-runtime.sh         temporary ADB diagnostic helper
build-usb-mic-recovery-zips.sh   runtime TWRP package builder
```

Compiled APEX files, Android images, backups, GApps, Widevine, recordings and
signing material are intentionally excluded from Git history.

## Experimental TWRP test package

The exact package tested on the device is available from the
[GitHub Releases page](https://github.com/elkir0/rpi5-android-usb-wakeword-fix/releases).
It includes:

- runtime USB routing install and disable ZIPs;
- patched audio APEX install ZIP;
- a short compatibility/rollback guide, Apache-2.0 license and SHA-256
  manifest.

The package is **strictly build-specific**. The APEX installer accepts only the
known stock APEX SHA-256
`ccf26258c38acdb741566023eefff0a2f288d807f69439904f08ac319b831f9a`
or the already patched APEX, and refuses an unknown build.

### Test order

1. Have a working TWRP installation.
2. Make and verify a TWRP `/vendor` backup.
3. Flash `install-usb-mic-boot-automation-rpi5.zip`.
4. Flash `install-audio-apex-input-sync-rpi5.zip`.
5. Reboot to System.

Do not force the package onto another build. Rebuild and sign the APEX against
the matching source tree instead.

The public package does not redistribute the stock KonstaKANG APEX. Roll back
by restoring the pre-install `/vendor` backup or reflashing the official
matching KonstaKANG OTA obtained from its official source.

## Rebuild the Android 16 audio APEX

The validated source base is:

- AOSP tag: `android-16.0.0_r4`
- Raspberry Vanilla local manifest branch: `android-16.0`
- `raspberry-vanilla/android_device_brcm_rpi5`
- base commit: `8a59d09024b7fba6a7bce619e178c8c0d8e87c7d`
- lunch target: `aosp_rpi5-bp4a-userdebug`
- module: `com.android.hardware.audio.rpi`

Initialize the official Raspberry Vanilla tree:

```sh
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-16.0.0_r4
curl -o .repo/local_manifests/manifest_brcm_rpi.xml -L \
  https://raw.githubusercontent.com/raspberry-vanilla/android_local_manifest/android-16.0/manifest_brcm_rpi.xml \
  --create-dirs
repo sync
```

Apply and build:

```sh
git -C device/brcm/rpi5 checkout \
  8a59d09024b7fba6a7bce619e178c8c0d8e87c7d
git -C device/brcm/rpi5 apply \
  /path/to/patches/0002-audio-alsa-read-input-synchronously.patch

source build/envsetup.sh
lunch aosp_rpi5-bp4a-userdebug
OUT_DIR=out-audio m com.android.hardware.audio.rpi -j8
```

The validated build completed all `9,032/9,032` actions. A rebuilt APEX must
use signing identities compatible with the target build; matching Android
versions or package names alone is not sufficient.

## Build the routing helper

```sh
cd diagnostics/speech-test
gradle :app:assembleDebug --no-daemon
cd ../..
./build-usb-mic-recovery-zips.sh
```

On another Android version, verify the hidden API signatures used by
`AudioSystem.setDevicesRoleForCapturePreset()` and
`AudioSystem.setDeviceConnectionState()` before deployment.

## Runtime verification

```sh
adb -s SERIAL root
adb -s SERIAL shell getprop ro.audio.usb.period_us
adb -s SERIAL shell sha256sum /vendor/apex/com.android.hardware.audio.rpi.apex
adb -s SERIAL shell cat /data/local/tmp/usb-mic-runtime.log
adb -s SERIAL shell dumpsys media.audio_policy
adb -s SERIAL shell dumpsys voiceinteraction
adb -s SERIAL shell dumpsys media.audio_flinger
```

Expected results include:

- `ro.audio.usb.period_us` is empty;
- HOTWORD is routed to `AUDIO_DEVICE_IN_USB_DEVICE`;
- `mPerformingSoftwareHotwordDetection=true`;
- AudioFlinger shows real frames, `readErrors=0`, `silenced=false`;
- no repeated 240-frame inserted-silence warning.

The complete install, enrollment, validation and rollback notes are in
[`docs/TUTORIEL-FR.md`](docs/TUTORIEL-FR.md).

## License and redistribution

The modified AOSP file retains its Android Open Source Project Apache-2.0
header. The source patch and local routing helper are distributed under the
Apache License 2.0; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

This repository does not mirror a KonstaKANG build and contains no full Android
image, GApps or Widevine files. Release binaries are experimental,
build-specific test artifacts and are not official KonstaKANG packages.
