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

Télécharger ensemble depuis la même release :

- `install-rpi5-android-usb-wakeword-fix.zip` ;
- `rollback-rpi5-android-usb-wakeword-fix.zip` ;
- `SHA256SUMS`.

Vérifier les deux ZIP avec `SHA256SUMS` avant de les copier. Le premier paquet
regroupe les deux couches ci-dessous ; le second restaure la sauvegarde créée
par l’installateur et retire le routage.

### Couche 1 — routage USB persistant

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
| APEX corrigé dans le ZIP | `1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff` |
| APEX d'origine sauvegardé | `ccf26258c38acdb741566023eefff0a2f288d807f69439904f08ac319b831f9a` |

Exemple de vérification :

```sh
shasum -a 256 -c SHA256SUMS
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
   adb push install-rpi5-android-usb-wakeword-fix.zip /sdcard/Download/
   adb push rollback-rpi5-android-usb-wakeword-fix.zip /sdcard/Download/
   ```

2. Redémarrer dans TWRP.
3. Flasher `install-rpi5-android-usb-wakeword-fix.zip`.
4. Redémarrer vers System.

L'installateur unifié :

- accepte uniquement l'APEX stock connu ou l'APEX déjà corrigé ;
- sauvegarde l’APEX stock sous `/data/local/tmp/rpi5-usb-wakeword-backup/` ;
- refuse de continuer sans sauvegarde stock vérifiée ;
- vérifie chaque payload avant et après copie ;
- installe l’APEX, le service, le script et le helper dans une seule opération ;
- refuse d’écraser un fichier de routage inconnu.

## Installation manuelle par ADB

La méthode TWRP reste préférable. Cette section sert à reproduire précisément
l'opération sur la build validée. Remplacer `SERIAL` par `IP:PORT`. Extraire
d’abord les payloads du ZIP public vérifié :

```sh
mkdir manual-payload
cd manual-payload
unzip ../install-rpi5-android-usb-wakeword-fix.zip 'payload/*'
cd ..
```

### 1. Installer le routage tardif

```sh
adb -s SERIAL root
adb -s SERIAL shell 'mount -o rw,remount /vendor'

adb -s SERIAL push manual-payload/payload/usb-mic-runtime.rc \
  /vendor/etc/init/usb-mic-runtime.rc
adb -s SERIAL push manual-payload/payload/usb-mic-runtime.sh \
  /vendor/bin/usb-mic-runtime.sh
adb -s SERIAL push manual-payload/payload/usb-mic-route.apk \
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
adb -s SERIAL push manual-payload/payload/com.android.hardware.audio.rpi.apex \
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
adb -s SERIAL shell 'mkdir -p /data/local/tmp/rpi5-usb-wakeword-backup && \
  cp /vendor/apex/com.android.hardware.audio.rpi.apex \
     /data/local/tmp/rpi5-usb-wakeword-backup/com.android.hardware.audio.rpi.apex && \
  sha256sum /data/local/tmp/rpi5-usb-wakeword-backup/com.android.hardware.audio.rpi.apex && \
  cp \
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

### 1. Aligner la langue Android et celle de l'Assistant

Faire ce réglage avant l'enrôlement. Pour utiliser le français de France :

```sh
adb -s SERIAL root
adb -s SERIAL shell 'cmd locale set-device-locale fr-FR'
adb -s SERIAL shell 'cmd locale get-device-locale; cmd activity get-config | head -n 1'
```

Les résultats attendus contiennent `fr-FR` et `fr-rFR`. L'interface Google doit
alors afficher « Hey Google et Voice Match ». Cette commande change la langue
de tout le système, pas uniquement celle de l'application Google.

### 2. Vérifier le micro avant l'enrôlement

Le routage HOTWORD doit viser le micro USB :

```sh
adb -s SERIAL shell 'dumpsys media.audio_policy' | sed -n '/Inputs (/,/Total Effects/p'
```

Sur le montage validé, on doit voir :

```text
AUDIO_FORMAT_PCM_16_BIT; 48000; Channel mask: 0x10
Devices: AUDIO_DEVICE_IN_USB_DEVICE, @:card=3;device=0
Source: 1999
```

### 3. Libérer temporairement l'unique flux USB

Si l'écran d'entraînement n'écoute pas, préparer d'abord l'écran Voice Match,
puis identifier le processus isolé du listener :

```sh
adb -s SERIAL shell \
  "ps -A -o USER,PID,PPID,ARGS | grep -i 'gsa.hot' | grep -v grep"
```

Exemple réel :

```text
u0_i9004  5063  608  com.google.android.googlequicksearchbox:...:gsa.hot
```

Vérifier impérativement les deux conditions suivantes avant de continuer :

- l'utilisateur commence par `u0_i` ;
- la commande contient `com.google.android.googlequicksearchbox` et `gsa.hot`.

Juste avant de toucher « Réentraîner l'empreinte vocale Voice Match », arrêter
uniquement ce PID isolé :

```sh
adb -s SERIAL root
adb -s SERIAL shell kill -9 PID_ISOLE
```

Ne pas utiliser `pkill`, ne pas tuer tous les processus Google et ne pas tuer
le processus `:interactor`. Revenir immédiatement à l'écran et prononcer les
phrases affichées. Google recrée automatiquement le listener isolé ensuite.
Cette manipulation concerne uniquement l'enrôlement.

### 4. Confirmer que l'écran reçoit réellement la voix

Pendant que l'écran écoute, contrôler AudioFlinger depuis un second terminal :

```sh
adb -s SERIAL shell 'dumpsys media.audio_flinger' | \
  grep -A35 'Input thread' | head -n 80
```

Les indicateurs importants sont :

- `Standby: no` ;
- `Channel count: 1` ;
- `Input device: AUDIO_DEVICE_IN_USB_DEVICE` ;
- `Frames read` augmente ;
- `Signal power history` contient des valeurs qui montent quand on parle ;
- `readErrors=0` et aucune ligne `incomplete data received`.

Le test Pi4 a lu plus de 600 000 frames pendant cette étape. Si `Frames read`
reste à zéro, ce n'est pas un problème de Voice Match : il faut d'abord réparer
le profil/routage USB ou le HAL.

### 5. Réarmer le wakeword après l'enrôlement

Une fois revenu à l'écran Voice Match :

```sh
adb -s SERIAL shell 'cmd voiceinteraction restart-detection'
adb -s SERIAL shell 'dumpsys voiceinteraction' | \
  grep -E 'Hotword detection connection|mPerformingSoftwareHotwordDetection'
adb -s SERIAL shell 'dumpsys media.audio_policy' | \
  sed -n '/Inputs (/,/Total Effects/p'
```

Le résultat attendu est `mPerformingSoftwareHotwordDetection=true`, avec une
entrée active `AUDIO_SOURCE_HOTWORD` / source `1999` sur
`AUDIO_DEVICE_IN_USB_DEVICE`.

Enfin, vider le journal, prononcer « Hey Google », puis vérifier :

```sh
adb -s SERIAL shell logcat -c
# Prononcer « Hey Google », puis :
adb -s SERIAL shell logcat -d | grep -E \
  'Fired hotword model|hotword score|Speaker Detected|speaker score|incomplete data received|read failed'
```

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
APEX_PATH=/chemin/com.android.hardware.audio.rpi.apex \
  ./scripts/build-release.sh
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
2. Flasher `rollback-rpi5-android-usb-wakeword-fix.zip`.
3. Redémarrer vers System.

Le rollback exige l’APEX stock sauvegardé par l’installateur, contrôle son hash
et refuse de supprimer un fichier de routage qui ne correspond pas à la
release. Si `/data` est perdu, restaurer la sauvegarde TWRP de `/vendor` ou
reflasher l’OTA officiel exactement correspondant. Ne jamais modifier au
hasard les XML audio : ils ne font pas partie du correctif Pi 5 final.

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
   `install-rpi5-android-usb-wakeword-fix.zip`, accompagné obligatoirement de
   `rollback-rpi5-android-usb-wakeword-fix.zip`. Il permet de reproduire
   immédiatement le résultat sur la build exacte du 20 mai 2026.

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
