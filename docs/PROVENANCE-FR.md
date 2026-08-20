# Provenance du correctif Pi 5

## Sources et artefact

| Élément | Valeur |
|---|---|
| Tag AOSP | `android-16.0.0_r4` |
| Manifeste Raspberry Vanilla | branche `android-16.0` |
| Commit `device/brcm/rpi5` | `8a59d09024b7fba6a7bce619e178c8c0d8e87c7d` |
| Patch publié | `8518d363a99b98aaa31878a69daf8140f7ac65d1486fb4aae3eb9be784028a31` |
| Cible | `aosp_rpi5-bp4a-userdebug` |
| Module | `com.android.hardware.audio.rpi` |
| Actions terminées | `9032/9032` |
| Taille APEX | `16068608` octets |
| SHA-256 APEX corrigé | `1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff` |
| SHA-256 helper de routage validé | `77d3c3865f3b97b986d3cc190969a2754b4bf4eac838f2333618250e937ecd90` |

Le patch ne modifie que `audio/alsa/StreamAlsa.cpp`. Il remplace le pipe
asynchrone pour l’entrée par `proxy_read_with_retries()` dans `transfer()` et
conserve le chemin de sortie asynchrone.

## Signatures contrôlées

L’artefact corrigé et l’APEX stock de la build testée utilisent les mêmes
identités attendues :

- certificat externe SHA-256 :
  `a1ceeef0869dbff08b0d5f8b6f01fa608256aaee61e27fb1276721c3aa739f99` ;
- `apex_pubkey` SHA-256 :
  `90b54ee285c08f6f6dd9168169f398162d4b81ff436823d1b598291eae90ae58` ;
- clé publique AVB SHA-1 :
  `e36c661b3c342b32557e5dc6ad945451afc16213` ;
- algorithme AVB : `SHA256_RSA4096`.

Ces valeurs ne dispensent jamais du contrôle du SHA-256 complet exigé par
l’installateur.

## Validation sur matériel réel

Le 19 août 2026, après installation sur le Pi 5 :

- disparition des blocs `incomplete data received` ;
- plusieurs millions de frames avec `readErrors=0` et `silenced=false` ;
- score hotword Google `0.979187` ;
- score de vérification du locuteur `0.734375` ;
- ouverture de l’Assistant/Gemini et lecture de sa réponse ;
- nouveau déclenchement réussi après redémarrage à froid.

Le paquet reste expérimental et strictement lié à la build et au hash stock
documentés.
