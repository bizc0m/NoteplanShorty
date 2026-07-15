# Version 2

Branche de travail pour la prochaine version de NotePlan Shortcut Maker.

## Base

- depart : `main` apres `v0.1.0`
- app actuelle : SwiftUI + drop AppKit natif
- release stable : `v0.1.0`

## Objectifs possibles

- option pour ajouter ou non une icone personnalisee optimisee
- verifier/ameliorer le drag Finder sur davantage de configurations macOS
- ajouter une signature/notarisation si distribution publique
- ajouter un workflow GitHub release automatise
- reduire encore le poids de l'icone si besoin
- ajouter un ecran d'aide minimal

## Regle

Ne pas casser le contrat principal :

`note.md` deposee -> `Destination/note.app` -> URL NotePlan encodee.

Si une icone est choisie, elle doit etre optimisee avant integration et ne jamais
embarquer l'image source pleine taille dans le raccourci genere.
