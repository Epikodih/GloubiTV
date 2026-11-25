# ADR 0002 : lecture pilotée par le cœur

- **Statut** : accepté
- **Date** : 2026-11-25
- **Issue** : #10 (remplace la route prévue par #26)

## Contexte

L'app TV devait d'abord lire les médias par une route HTTP du cœur, `GET /api/media/{id}/stream` (requêtes `Range`, token dans l'en-tête), et décider seule d'ouvrir le lecteur depuis la médiathèque.

Le cœur Rust (#35) a été livré avec un autre modèle : un lecteur unique, partagé par la TV et les télécommandes, dont le cœur garde l'état (file, volume, reprise, enchaînement). L'équipe a convenu qu'en cas d'écart de contrat, le cœur fait foi et les apps s'adaptent.

L'app TV tourne sur la même machine que le cœur : les routes réservées à la TV n'acceptent que la boucle locale.

## Options étudiées

| Option | Pour | Contre |
|---|---|---|
| Route de flux HTTP (`/stream`) | la TV pourrait tourner sur une autre machine | route à écrire dans le cœur ; la TV et la télécommande pilotent chacune leur lecture ; reprise et enchaînement à refaire côté TV |
| **Commandes du cœur** (`player.command`) | un seul état de lecture pour tous ; reprise, file et enchaînement déjà faits par le cœur ; aucune nouvelle route | la TV doit voir les fichiers au même chemin que le cœur (même machine) |

## Décision

La TV ne choisit jamais seule ce qu'elle lit :

1. la médiathèque (bouton « Lecture ») ou la télécommande demandent `POST /api/player/play` ;
2. le cœur envoie l'événement WebSocket `player.command` : `load` donne le chemin du fichier (`now_playing.uri`) et la position de reprise (`start_s`) ; les autres actions (`pause`, `seek`, `volume`, pistes…) pilotent le lecteur ouvert ;
3. la TV publie l'état réel avec `POST /api/player/state` ; le cœur enregistre la reprise et enchaîne le média suivant à la fin.

Côté TV, `PlaybackHost` (`apps/tv/lib/player/server_player.dart`) écoute le WebSocket, ouvre ou remplace `PlayerScreen`, et `PlayerReporter` publie l'état. La route `/stream` est retirée du contrat.

## Conséquences

- La TV et le cœur doivent tourner sur la même machine (ou voir les fichiers au même chemin). Une TV distante demanderait de rétablir une route de flux.
- Sous macOS, l'app TV n'est pas dans le bac à sable d'Apple (`com.apple.security.app-sandbox` à `false`) : elle doit joindre le cœur en local et lire les fichiers où qu'ils soient (`~/Movies`, disque externe). Une distribution par l'App Store demanderait de revoir ce point.
- La reprise de lecture (#24) est calculée par le cœur : la TV ne fait qu'ouvrir à `start_s`.
- Les touches locales de la TV (pause, avance) agissent directement sur le moteur ; l'état publié garde le cœur à jour.
- L'ordre des commandes et des états reste à fiabiliser côté cœur (#41, numéro `seq`).
