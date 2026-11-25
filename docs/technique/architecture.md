# Architecture

> Schéma des composants (interface, médiathèque, lecture, extensions, API, mobile), flux de données, choix de stack justifiés.

La vue d'ensemble du monorepo est dans [ARCHITECTURE.md](../../ARCHITECTURE.md).

## Composants de l'app TV

| Composant | Dossier | Rôle |
|---|---|---|
| Lecture | `apps/tv/lib/player/` | moteur `PlaybackEngine` (media_kit), écran de lecture, `PlaybackHost` qui exécute les commandes du cœur, voir [Lecture](lecture.md) |

## Flux de lecture

```
Médiathèque (TV)        Cœur Rust                     Lecteur (TV)
      │  « Lecture »         │                              │
      ├─ POST /api/player/play ►│                           │
      │                      ├── player.command (load) ────►│ PlaybackHost
      │                      │   uri + start_s (WebSocket)  │ PlayerScreen
      │                      │◄── POST /api/player/state ───┤ PlayerReporter
      │                      │   (reprise, média suivant)   │
      │◄──────────── Retour ─┼──────────────────────────────┤ « stopped »
```

La TV ne choisit jamais seule ce qu'elle lit : le cœur décide (filtre parental, reprise, file) et la TV exécute ([ADR 0002](../adr/0002-lecture-pilotee-par-le-coeur.md)). Elle lit le fichier au chemin donné par le cœur, qui tourne sur la même machine.
