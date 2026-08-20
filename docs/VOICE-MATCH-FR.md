# Entraîner Voice Match avec un microphone USB à capture unique

Le micro HNHK testé n’accepte qu’un flux de capture. Le listener HOTWORD peut
donc occuper le micro lorsque l’écran d’enrôlement tente de l’ouvrir.

## Procédure recommandée

Le compagnon public automatise les contrôles dangereux :

```sh
git clone https://github.com/elkir0/rpi-android-voice-setup.git
cd rpi-android-voice-setup
./tools/rpi-voice-setup doctor --serial IP:PORT
./tools/rpi-voice-setup set-language --serial IP:PORT --locale fr-FR
./tools/rpi-voice-setup open-voice-match --serial IP:PORT
```

Dans les réglages Google, ouvrir **Hey Google et Voice Match**, puis rester
juste avant **Réentraîner l’empreinte vocale Voice Match**. Lancer :

```sh
./tools/rpi-voice-setup prepare-enrollment --serial IP:PORT
```

Le script exige un unique processus dont l’utilisateur commence par `u0_i` et
dont la commande contient à la fois le paquet Google et `gsa.hot`. Il demande
la confirmation `OUI`, ne fait jamais de `pkill` et ne touche pas à
`:interactor`.

Dès la confirmation, toucher **Réentraîner** et prononcer les phrases. Puis :

```sh
./tools/rpi-voice-setup finish-enrollment --serial IP:PORT
```

Tester réellement « Hey Google », redémarrer à froid, puis le tester encore.

## Procédure manuelle auditable

Identifier le processus :

```sh
adb -s SERIAL shell \
  "ps -A -o USER,PID,PPID,ARGS | grep -i 'gsa.hot' | grep -v grep"
```

S’il y a zéro ligne, plusieurs lignes, un utilisateur différent de `u0_i*`,
ou une commande sans `com.google.android.googlequicksearchbox` et `gsa.hot`,
s’arrêter. Sinon, juste avant l’enrôlement :

```sh
adb -s SERIAL root
adb -s SERIAL shell kill -9 PID_ISOLE
```

Après les phrases :

```sh
adb -s SERIAL shell 'cmd voiceinteraction restart-detection'
adb -s SERIAL shell 'dumpsys voiceinteraction' | \
  grep -E 'Hotword detection connection|mPerformingSoftwareHotwordDetection'
adb -s SERIAL shell 'dumpsys media.audio_policy' | \
  sed -n '/Inputs (/,/Total Effects/p'
```

Le résultat attendu comprend
`mPerformingSoftwareHotwordDetection=true` et une entrée HOTWORD sur
`AUDIO_DEVICE_IN_USB_DEVICE`. Le tutoriel complet explique aussi le contrôle
des frames AudioFlinger et des journaux.
