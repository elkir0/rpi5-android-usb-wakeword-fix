# Activer « Ok Google » avec un microphone USB sur Android Raspberry Pi 5

Ce tutoriel documente le correctif final validé le **19 août 2026** sur :

- Raspberry Pi 5 ;
- KonstaKANG LineageOS 23.2 / Android 16, build du 20 mai 2026 ;
- MindTheGapps 16.0 ARM64 et Voice Match activé ;
- microphone USB mono HNHK AI-Voice, S16_LE à 44,1/48 kHz.

Il ne modifie aucun XML d'Audio Policy.

> **Important :** l'APEX fourni est propre à cette build. Son installateur
> refuse volontairement un APEX d'origine dont le SHA-256 est inconnu. Pour une
> autre build, recompiler et signer un APEX compatible au lieu de forcer la
> copie.

## Résumé du problème et de la solution

Trois problèmes distincts se cumulaient :

| Problème | Symptôme | Correction |
|---|---|---|
| Faux `Built-In Mic` préféré par Android/Google | HOTWORD ouvert sur une entrée sans signal utile | Préférer le périphérique USB pour les presets 1, 6 et 1999, puis rendre le faux micro indisponible |
| Préférences `AudioSystem` volatiles | Le routage disparaît après reboot | Service `usb_mic_runtime` lancé après `sys.boot_completed=1` |
| Course entre AudioFlinger et le `MonoPipe` non bloquant du HAL Android 16 | Blocs hotword entiers remplacés par 240 frames de silence | Lecture ALSA synchrone pour l'entrée dans l'APEX audio |

Le troisième point était la cause du micro « visible mais sourd ». Le journal
répétait :

```text
AHAL_StreamAlsa: transfer: incomplete data received, inserting 240 frames of silence
```

À 48 kHz, le chemin hotword demande 240 frames, soit 5 ms. L'ancien HAL lançait
un thread ALSA de fond qui remplissait un `MonoPipe` non bloquant. Si
AudioFlinger lisait avant que ce thread ait rempli le bloc, le HAL complétait
la totalité avec des zéros. Changer la période USB à 20 ms n'éliminait pas la
course.

Le patch `patches/0002-audio-alsa-read-input-synchronously.patch` reprend pour
Android 16 l'architecture d'entrée présente dans Raspberry Vanilla Android 17 :

- entrée : appel direct à `proxy_read_with_retries()` depuis `transfer()` ;
- sortie : ancien thread asynchrone conservé ;
- aucun changement dans l'Audio Policy ni dans le chemin de sortie.

## Fichiers et empreintes

### Couche 1 — routage USB persistant

| Archive | SHA-256 |
|---|---|
| `install-usb-mic-boot-automation-rpi5.zip` | `2c8c7cedfb1ba6317493739341381e7689768ae5570ee9d67acf70f4e6c6aaab` |
| `disable-usb-mic-boot-automation-rpi5.zip` | `a9a12c566e4665ab1056573557e60359918b605923f6fd19563063bf9cb2ae9b` |

Le service règle le mixeur à 20/30 (`+18 dB`), active l'AGC et préfère l'USB
pour :

| Preset Android | Valeur | Périphérique |
|---|---:|---|
| MIC | 1 | `AUDIO_DEVICE_IN_USB_DEVICE` |
| VOICE_RECOGNITION | 6 | `AUDIO_DEVICE_IN_USB_DEVICE` |
| HOTWORD | 1999 | `AUDIO_DEVICE_IN_USB_DEVICE` |

### Couche 2 — lecture d'entrée synchrone

| Fichier | SHA-256 |
|---|---|
| `install-audio-apex-input-sync-rpi5.zip` | `8ab591acc6443b16be6419ae8f3cfa351b7d99071b3615af80a700500863a561` |
| `restore-stock-audio-apex-rpi5.zip` | `f8abdec64b6667da4344a4f4b9302d85879a3449ff2ff850df9f2197ed371546` |
| `artifacts/com.android.hardware.audio.rpi-input-sync.apex` | `1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff` |
| APEX d'origine sauvegardé | `ccf26258c38acdb741566023eefff0a2f288d807f69439904f08ac319b831f9a` |

Vérifier les téléchargements depuis la racine du dossier :

```sh
shasum -a 256 \
  install-usb-mic-boot-automation-rpi5.zip \
  disable-usb-mic-boot-automation-rpi5.zip \
  install-audio-apex-input-sync-rpi5.zip \
  restore-stock-audio-apex-rpi5.zip \
  artifacts/com.android.hardware.audio.rpi-input-sync.apex
```

## Prérequis

- TWRP fonctionnel et testé.
- Sauvegarde de l'image ou au minimum de `/vendor`.
- Débogage root activé pour les contrôles ADB.
- Google app/Assistant déjà fonctionnel et compte connecté.
- Un seul périphérique de capture USB recommandé.

Le helper de routage utilise des API Android internes et le domaine SELinux
`u:r:su:s0` disponible sur cette build. Une autre version peut nécessiter une
adaptation.

## Installation recommandée avec TWRP

1. Copier les archives d'installation **et** de retour arrière :

   ```sh
   adb push install-usb-mic-boot-automation-rpi5.zip /sdcard/Download/
   adb push disable-usb-mic-boot-automation-rpi5.zip /sdcard/Download/
   adb push install-audio-apex-input-sync-rpi5.zip /sdcard/Download/
   adb push restore-stock-audio-apex-rpi5.zip /sdcard/Download/
   ```

2. Redémarrer dans TWRP.
3. Flasher `install-usb-mic-boot-automation-rpi5.zip`.
4. Flasher `install-audio-apex-input-sync-rpi5.zip`.
5. Redémarrer vers System.

L'installateur APEX :

- accepte uniquement l'APEX stock connu ou l'APEX déjà corrigé ;
- vérifie le SHA-256 avant et après copie ;
- retire l'ancien réglage de période 20 ms si l'ancien service est présent ;
- conserve un état réinstallable sans effet cumulatif.

## Installation manuelle par ADB

La méthode TWRP reste préférable. Cette section sert à reproduire précisément
l'opération sur la build validée. Remplacer `SERIAL` par `IP:PORT`.

### 1. Installer le routage tardif

```sh
adb -s SERIAL root
adb -s SERIAL shell 'mount -o rw,remount /vendor'

adb -s SERIAL push diagnostics/audio-policy/usb-mic-runtime.rc \
  /vendor/etc/init/usb-mic-runtime.rc
adb -s SERIAL push diagnostics/audio-policy/usb-mic-runtime.sh \
  /vendor/bin/usb-mic-runtime.sh
adb -s SERIAL push diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk \
  /vendor/etc/usb-mic-route.apk

adb -s SERIAL shell 'chown 0:0 \
  /vendor/etc/init/usb-mic-runtime.rc \
  /vendor/bin/usb-mic-runtime.sh \
  /vendor/etc/usb-mic-route.apk; \
  chmod 0644 /vendor/etc/init/usb-mic-runtime.rc \
  /vendor/etc/usb-mic-route.apk; \
  chmod 0755 /vendor/bin/usb-mic-runtime.sh; \
  restorecon /vendor/etc/init/usb-mic-runtime.rc \
  /vendor/bin/usb-mic-runtime.sh \
  /vendor/etc/usb-mic-route.apk'
```

### 2. Remplacer l'APEX atomiquement

```sh
adb -s SERIAL push artifacts/com.android.hardware.audio.rpi-input-sync.apex \
  /data/local/tmp/com.android.hardware.audio.rpi.apex

adb -s SERIAL shell 'sha256sum \
  /vendor/apex/com.android.hardware.audio.rpi.apex \
  /data/local/tmp/com.android.hardware.audio.rpi.apex'
```

Les deux valeurs attendues avant installation sont respectivement :

```text
ccf26258c38acdb741566023eefff0a2f288d807f69439904f08ac319b831f9a
1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff
```

Ne pas continuer si l'APEX stock a une autre empreinte.

```sh
adb -s SERIAL shell 'cp \
  /data/local/tmp/com.android.hardware.audio.rpi.apex \
  /vendor/apex/com.android.hardware.audio.rpi.apex.new && \
  chown 0:0 /vendor/apex/com.android.hardware.audio.rpi.apex.new && \
  chmod 0644 /vendor/apex/com.android.hardware.audio.rpi.apex.new && \
  restorecon /vendor/apex/com.android.hardware.audio.rpi.apex.new && \
  sha256sum /vendor/apex/com.android.hardware.audio.rpi.apex.new && \
  mv /vendor/apex/com.android.hardware.audio.rpi.apex.new \
     /vendor/apex/com.android.hardware.audio.rpi.apex && \
  sync'

adb -s SERIAL reboot
```

Le remontage immédiat de `/vendor` en lecture seule peut répondre `busy`, car
l'APEX actif est encore monté. Le reboot rétablit le montage normal.

## Vérification après reboot

Ne pas lancer le script manuel avant ces contrôles : sinon on ne teste plus la
persistance.

```sh
adb -s SERIAL root
adb -s SERIAL shell getprop ro.audio.usb.period_us
adb -s SERIAL shell sha256sum /vendor/apex/com.android.hardware.audio.rpi.apex
adb -s SERIAL shell getprop init.svc.usb_mic_runtime
adb -s SERIAL shell cat /data/local/tmp/usb-mic-runtime.log
adb -s SERIAL shell dumpsys media.audio_policy
adb -s SERIAL shell dumpsys voiceinteraction
adb -s SERIAL shell dumpsys media.audio_flinger
```

Résultats attendus :

- `ro.audio.usb.period_us` est vide ;
- l'APEX porte l'empreinte `1781c9...ff0ff` ;
- `init.svc.usb_mic_runtime=stopped`, état normal du service `oneshot` fini ;
- le journal finit par `OK: active Android input is routed to the USB microphone` ;
- les presets 1, 6 et 1999 préfèrent `AUDIO_DEVICE_IN_USB_DEVICE` ;
- HOTWORD utilise le périphérique USB ;
- `mPerformingSoftwareHotwordDetection=true` ;
- AudioFlinger montre des frames lues, `readErrors=0` et `silenced=false`.

Pour un test propre, vider le journal, prononcer « Hey Google », puis chercher
les événements pertinents :

```sh
adb -s SERIAL logcat -c
# Prononcer « Hey Google », attendre la réponse, puis :
adb -s SERIAL logcat -d | grep -E \
  'Fired hotword model|hotword score|Speaker Detected|incomplete data received|read failed'
```

Le test final a donné :

```text
Fired hotword model
hotword score: 0.979187
Speaker Detected: true
speaker score: 0.734375
```

Il n'y avait plus aucun `incomplete data received` ni insertion de silence.
L'Assistant a ouvert son activité et lu sa réponse. Le warning occasionnel
`refinePosition: no opened devices` peut encore apparaître sur un stream fermé ;
il n'a pas affecté la capture active pendant les tests.

## Entraîner Voice Match

Le bug de silence en fonctionnement normal est corrigé par l'APEX. Un autre
problème peut toutefois apparaître pendant l'enrôlement : ce micro USB n'accepte
qu'un flux de capture à la fois et le listener HOTWORD peut déjà l'occuper.

Si l'écran d'entraînement n'écoute pas :

```sh
adb -s SERIAL shell "ps -A -o USER,PID,ARGS | grep -i 'gsa.hot'"
```

Juste avant de relancer l'enregistrement, arrêter uniquement le PID isolé
affiché en `u0_i...` :

```sh
adb -s SERIAL root
adb -s SERIAL shell kill -9 PID_ISOLE
```

Revenir immédiatement à l'écran et prononcer les quatre phrases. Google recrée
le listener ensuite. Cette manipulation concerne l'enrôlement seulement.

## Recompiler l'APEX pour Android 16

La base reproductible est :

- AOSP `android-16.0.0_r4` ;
- local manifest Raspberry Vanilla `android-16.0` ;
- device tree au commit
  `8a59d09024b7fba6a7bce619e178c8c0d8e87c7d` ;
- patch `patches/0002-audio-alsa-read-input-synchronously.patch`.

Initialisation officielle Raspberry Vanilla :

```sh
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-16.0.0_r4
curl -o .repo/local_manifests/manifest_brcm_rpi.xml -L \
  https://raw.githubusercontent.com/raspberry-vanilla/android_local_manifest/android-16.0/manifest_brcm_rpi.xml \
  --create-dirs
repo sync
```

Appliquer le patch et compiler uniquement l'APEX :

```sh
git -C device/brcm/rpi5 checkout \
  8a59d09024b7fba6a7bce619e178c8c0d8e87c7d
git -C device/brcm/rpi5 apply \
  /chemin/vers/patches/0002-audio-alsa-read-input-synchronously.patch

source build/envsetup.sh
lunch aosp_rpi5-bp4a-userdebug
OUT_DIR=out-audio m com.android.hardware.audio.rpi -j8
```

La compilation validée a terminé les `9 032/9 032` actions en `7 h 51 min 58 s`.
Le résultat doit être signé avec les mêmes identités que l'APEX stock de la
build cible.

### Contrôler les deux niveaux de signature APEX

L'artefact validé et l'APEX stock ont :

- certificat externe SHA-256 :
  `a1ceeef0869dbff08b0d5f8b6f01fa608256aaee61e27fb1276721c3aa739f99` ;
- `apex_pubkey` SHA-256 :
  `90b54ee285c08f6f6dd9168169f398162d4b81ff436823d1b598291eae90ae58` ;
- clé publique AVB SHA-1 :
  `e36c661b3c342b32557e5dc6ad945451afc16213` ;
- algorithme AVB : `SHA256_RSA4096`.

Exemples de contrôles :

```sh
apksigner verify --print-certs com.android.hardware.audio.rpi.apex
unzip -p com.android.hardware.audio.rpi.apex apex_pubkey | shasum -a 256
avbtool info_image --image com.android.hardware.audio.rpi.apex
```

Comparer systématiquement au fichier `/vendor/apex/...` du build cible. Une
simple égalité de nom ou de version Android ne suffit pas.

## Recompiler le helper de routage

Le code se trouve dans :

```text
diagnostics/speech-test/app/src/main/java/local/raspberry/speechtest/RouteMic.java
```

```sh
cd diagnostics/speech-test
gradle :app:assembleDebug --no-daemon
cd ../..
./build-usb-mic-recovery-zips.sh
```

Les appels internes
`AudioSystem.setDevicesRoleForCapturePreset()` et
`AudioSystem.setDeviceConnectionState()` doivent retourner `result=0`.

Pour réappliquer temporairement le routage pendant un diagnostic :

```sh
./apply-usb-mic-runtime.sh SERIAL
```

## Retour arrière

1. Démarrer dans TWRP.
2. Flasher `restore-stock-audio-apex-rpi5.zip`.
3. Si le routage USB doit aussi être retiré, flasher
   `disable-usb-mic-boot-automation-rpi5.zip`.
4. Redémarrer vers System.

Ne pas modifier ou supprimer au hasard les XML audio : les anciens essais ont
déjà provoqué une boucle sur les trois points de démarrage. Si nécessaire,
`restore-audio-policy-rpi5.zip` restaure uniquement l'Audio Policy connue comme
bootable pour cette image précise.

## Partager ou proposer le correctif en amont

Le fichier `StreamAlsa.cpp` modifié conserve son en-tête Apache‑2.0. Cette
licence autorise la modification et la redistribution, à condition notamment
de conserver la licence et les mentions d'origine et de signaler les fichiers
modifiés. Le patch identifie déjà clairement la modification et sa provenance
Android 17.

La proposition peut contenir deux livrables complémentaires :

1. **Source pour intégration** :
   `patches/0002-audio-alsa-read-input-synchronously.patch`, qui est le
   livrable principal et permet à KonstaKANG de relire puis reconstruire l'APEX
   avec sa chaîne officielle.
2. **Binaire de validation TWRP** :
   `install-audio-apex-input-sync-rpi5.zip`, accompagné obligatoirement de
   `restore-stock-audio-apex-rpi5.zip`. Il permet de reproduire immédiatement
   le résultat sur la build exacte du 20 mai 2026.

Le ZIP TWRP de test doit être présenté comme **non officiel et strictement
spécifique à la build testée**, avec ses SHA-256. Il ne doit jamais être forcé
sur une autre build ; l'installateur refuse déjà un APEX stock inconnu.

Dans le premier message à KonstaKANG, transmettre :

- le patch source ;
- le commit de base exact ;
- les symptômes et lignes de log avant/après ;
- les résultats de compilation et de test ;
- le modèle du microphone.

Joindre directement le petit patch source. Pour les deux ZIP TWRP, un lien ou
la mention « disponibles sur demande » est plus pratique qu'une pièce jointe
d'environ 16 Mo par archive et laisse à KonstaKANG le choix de les tester.

Ne jamais joindre ou publier l'image de sauvegarde, les GApps, Widevine ou un
miroir de la distribution. KonstaKANG interdit explicitement les miroirs de ses
builds et certaines parties de l'image sont sous licence non commerciale.
