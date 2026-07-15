# NotePlan Shortcut Maker v3

App macOS SwiftUI minimale pour creer des raccourcis `.app` depuis des notes NotePlan `.md`.
Le logo est affiche dans l'app generateur, mais les raccourcis generes restent sans image ni icone.

## Regle v3

V3 genere uniquement des raccourcis sans icone personnalisee, sans image et sans logo embarque.
Le generateur lui-meme embarque seulement un petit logo 128 px.

Exemple :

- note : `TODO Suisse.md`
- raccourci : `DESTINATION/TODO Suisse.app`
- URL : `noteplan://x-callback-url/openNote?noteTitle=TODO%20Suisse`

La note `.md` n'est jamais modifiee, copiee ou deplacee.

## Lancer

```bash
./build-app.sh
open "dist/NotePlan Shortcut Maker.app"
```

Pour installer :

```bash
rm -rf "/Applications/NotePlan Shortcut Maker.app"
cp -R "dist/NotePlan Shortcut Maker.app" "/Applications/NotePlan Shortcut Maker.app"
open "/Applications/NotePlan Shortcut Maker.app"
```

## Utilisation

1. Cliquer sur `Choisir destination`.
2. Deposer une ou plusieurs notes `.md`.
3. Confirmer le remplacement si des `Nom.app` existent deja.
4. Cliquer sur `Reveler le raccourci`.

Fallback : `Choisir des notes .md` utilise le meme generateur que le drag & drop.

## Verification

```bash
./test-generation.sh
```

Le test verifie :

- generation simple
- remplacement sans `Nom 2.app`
- noms accentues NFC
- generation batch
- absence de `CFBundleIconFile`
- absence de `CFBundleIconName`
- absence de `applet.icns`
- absence de `CustomIcon.icns`
