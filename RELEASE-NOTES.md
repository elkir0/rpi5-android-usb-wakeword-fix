# v0.1.1-test2

Deuxième prerelease expérimentale du correctif USB/HOTWORD pour Raspberry Pi 5
sur KonstaKANG LineageOS 23.2 / Android 16, build du 20 mai 2026.

## Compatibilité exacte

- build ID `BP4A.251205.006` ;
- APEX stock SHA-256 :
  `ccf26258c38acdb741566023eefff0a2f288d807f69439904f08ac319b831f9a` ;
- APEX corrigé SHA-256 :
  `1781c9c08197fdcc789350c71c759b9cdfe085683a93dad206037375908af0ff`.

## Assets

- `install-rpi5-android-usb-wakeword-fix.zip` : APEX corrigé et routage USB
  persistant dans un seul installateur ;
- `rollback-rpi5-android-usb-wakeword-fix.zip` : restauration de l’APEX stock
  sauvegardé par l’installateur et retrait contrôlé du routage ;
- `rpi5-android-usb-wakeword-fix-lineageos23.2-20260520-test2.zip` : bundle des
  deux ZIP, guide de compatibilité, licence et hashes ;
- `SHA256SUMS` : empreintes de tous les assets.

| Asset | SHA-256 |
|---|---|
| `install-rpi5-android-usb-wakeword-fix.zip` | `3b73371f695caf5f356cd182982bebb4cdb61eabef07ab073039719b3f8e4176` |
| `rollback-rpi5-android-usb-wakeword-fix.zip` | `4ce8a97c8e0c752ebd69f7a18c9a0692f49349661ed7415d30afa02b17744694` |
| `rpi5-android-usb-wakeword-fix-lineageos23.2-20260520-test2.zip` | `0cc8267e3b56f2fc76083119d19ba341d9613c08106ce9745c908f977d3313ef` |

## Changements depuis test1

- installation unifiée en une seule opération TWRP ;
- sauvegarde locale obligatoire et vérifiée de l’APEX stock ;
- rollback autonome sans redistribuer l’APEX KonstaKANG ;
- refus d’écraser ou supprimer des fichiers inconnus ;
- archives reproductibles et documentation Voice Match séparée ;
- workflow GitHub de validation statique.

## Niveau de validation

Les payloads fonctionnels sont ceux validés sur le Pi 5 : même APEX, même
service, même script et même helper de routage. Le chemin voix complet a
survécu à un redémarrage à froid : HOTWORD, vérification du locuteur et réponse
Assistant/Gemini. Le nouvel emballage TWRP test2 doit encore être flashé une
fois sur le matériel avant de retirer la mention prerelease.

Ne contournez jamais les gardes SHA-256. Faites aussi une sauvegarde TWRP de
`/vendor`. Aucun APEX stock n’est présent dans les assets.
