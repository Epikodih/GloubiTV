# API de contrôle

> Référence des commandes et événements, appairage, découverte réseau, avec exemples.

Le contrat de référence est [fixtures/routes.json](../../fixtures/routes.json), décrit dans [fixtures/README.md](../../fixtures/README.md).

## Lecture

La lecture est pilotée par le cœur ([ADR 0002](../adr/0002-lecture-pilotee-par-le-coeur.md)) : la TV et les télécommandes partagent un seul lecteur.

| Étape | Route ou événement | Qui |
|---|---|---|
| Demander la lecture | `POST /api/player/play` `{"media_id": 2, "resume": true}` | médiathèque de la TV, télécommande |
| Ouvrir le fichier | événement WebSocket `player.command`, `action: "load"` | cœur → TV |
| Piloter | `POST /api/player/command` (`pause`, `seek`, `volume`…) → `player.command` | télécommande → cœur → TV |
| Publier l'état réel | `POST /api/player/state` (route locale) | TV → cœur |
| Suivre l'état | événement `player.state`, `GET /api/player` | télécommandes |

Exemple de commande reçue par la TV (`fixtures/events/player_command_load.json`) :

```json
{
  "type": "player.command",
  "data": {
    "action": "load",
    "now_playing": {
      "title": "Sintel",
      "uri": "/home/demo/media-demo/Films/Sintel (2010).mkv",
      "queue_item_id": 4,
      "media": { "id": 2, "kind": "movie", "...": "..." }
    },
    "start_s": 312.5
  }
}
```

`uri` est le chemin du fichier sur la machine du cœur : la TV, qui tourne sur la même machine, l'ouvre directement. Pour un lien envoyé vers la télé (`POST /api/player/cast`), c'est une URL.
