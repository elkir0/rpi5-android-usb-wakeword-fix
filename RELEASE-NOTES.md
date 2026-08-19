# v0.1.0-test1

Experimental package reproducing the USB microphone wakeword method validated
on a Raspberry Pi 5 running KonstaKANG LineageOS 23.2 / Android 16 build dated
2026-05-20.

## Asset

`KonstaKANG-RPi5-USB-Wakeword-method-20260819.zip`

SHA-256:

```text
092c3961eff400f2401525f5e5ea3729c607c561241538c08aa40067fdda646c
```

The 12 MiB archive contains the source patch, runtime helper source, full
documentation, Apache-2.0 license, per-file checksums and four nested TWRP
packages:

- `install-usb-mic-boot-automation-rpi5.zip`
- `disable-usb-mic-boot-automation-rpi5.zip`
- `install-audio-apex-input-sync-rpi5.zip`
- `restore-stock-audio-apex-rpi5.zip`

## Compatibility warning

The audio APEX package is only for the exact tested build. Its installer checks
the stock APEX SHA-256 and aborts on an unknown file. Do not bypass this check.
Keep the rollback package and a `/vendor` backup available before testing.

This is a pre-release test artifact, not an official KonstaKANG package.
