# Recompiler l’APEX audio Pi 5 pour Android 16

## Base validée

- AOSP : `android-16.0.0_r4` ;
- manifeste Raspberry Vanilla : branche `android-16.0` ;
- dépôt device : `raspberry-vanilla/android_device_brcm_rpi5` ;
- commit Pi 5 : `8a59d09024b7fba6a7bce619e178c8c0d8e87c7d` ;
- cible : `aosp_rpi5-bp4a-userdebug` ;
- module : `com.android.hardware.audio.rpi` ;
- build ID observé : `BP4A.251205.006`.

Prévoir Linux x86_64, Java 17, au moins 250 Gio de SSD et idéalement 24 à
32 Gio de RAM.

## Initialiser et épingler les sources

```sh
mkdir android-rpi5
cd android-rpi5
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-16.0.0_r4
curl -o .repo/local_manifests/manifest_brcm_rpi.xml -L \
  https://raw.githubusercontent.com/raspberry-vanilla/android_local_manifest/android-16.0/manifest_brcm_rpi.xml \
  --create-dirs
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j8
git -C device/brcm/rpi5 fetch origin \
  8a59d09024b7fba6a7bce619e178c8c0d8e87c7d
git -C device/brcm/rpi5 checkout --detach \
  8a59d09024b7fba6a7bce619e178c8c0d8e87c7d
git -C device/brcm/rpi5 rev-parse HEAD
```

La dernière commande doit afficher exactement le commit attendu.

## Appliquer le patch et construire

```sh
git -C device/brcm/rpi5 apply --check \
  /chemin/rpi5-android-usb-wakeword-fix/patches/0002-audio-alsa-read-input-synchronously.patch
git -C device/brcm/rpi5 apply \
  /chemin/rpi5-android-usb-wakeword-fix/patches/0002-audio-alsa-read-input-synchronously.patch
git -C device/brcm/rpi5 diff --check

source build/envsetup.sh
lunch aosp_rpi5-bp4a-userdebug
OUT_DIR=out-audio-rpi5 m com.android.hardware.audio.rpi -j8
```

Artefact attendu :

```text
out-audio-rpi5/target/product/rpi5/vendor/apex/com.android.hardware.audio.rpi.apex
```

L’artefact validé mesure `16068608` octets et porte le SHA-256 :

```text
1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff
```

## Vérifier avant de distribuer

Contrôler l’APEX avec les outils hôte produits par AOSP (`apex-ls`, verifier
APEX, `apksigner` et `avbtool`). Comparer sa clé publique, son certificat et sa
signature AVB à l’APEX stock de la build cible. Une différence de révision ou
de signature impose un nouveau paquet et de nouvelles gardes SHA-256.

Construire ensuite le helper et les ZIP :

```sh
cd diagnostics/speech-test
gradle :app:assembleDebug --no-daemon
cd ../..
APEX_PATH=/chemin/com.android.hardware.audio.rpi.apex \
ROUTE_APK_PATH=diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk \
  ./scripts/build-release.sh
```

Le script refuse un APEX dont le hash diffère, vérifie les payloads, interdit
la présence d’un APEX stock et génère `dist/SHA256SUMS`. La release test2 a
utilisé le helper déjà validé sur matériel, de SHA-256
`77d3c3865f3b97b986d3cc190969a2754b4bf4eac838f2333618250e937ecd90`.
