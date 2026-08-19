# v0.1.0-test1

Experimental package reproducing the USB microphone wakeword method validated
on a Raspberry Pi 5 running KonstaKANG LineageOS 23.2 / Android 16 build dated
2026-05-20.

## Asset

`rpi5-android-usb-wakeword-fix-lineageos23.2-20260520-test1.zip`

SHA-256:

```text
dc9d2f0d5a28c4b9d4f7e53ef9462b21c81ee8323f0db7860cad82c15bdea78f
```

The 5.9 MiB archive contains a compatibility/rollback guide, Apache-2.0
license, per-file checksums and three nested TWRP packages:

- `install-usb-mic-boot-automation-rpi5.zip`
- `disable-usb-mic-boot-automation-rpi5.zip`
- `install-audio-apex-input-sync-rpi5.zip`

## Compatibility warning

The audio APEX package is only for the exact tested build. Its installer checks
the stock APEX SHA-256 and aborts on an unknown file. Do not bypass this check.
Keep a verified TWRP `/vendor` backup available before testing.

No stock KonstaKANG APEX is redistributed. Roll back by restoring the
pre-install TWRP `/vendor` backup or reflashing the official matching OTA from
the official source.

This is a pre-release test artifact, not an official KonstaKANG package.
