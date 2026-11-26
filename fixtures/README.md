# Fixtures : API du media center

Chaque fichier fixe la **forme** d'une requête ou d'une réponse (champs et types), pas un scénario. Ils sont partagés par le backend Rust, le backend de test Python et les apps Flutter (TV et télécommande). Si un nom de champ change ici, les tests des deux côtés doivent échouer.

## Utilisation

- **Rust** : un test lit chaque fichier, le décode dans la structure `serde`, le réencode et compare.
- **Flutter** : un test charge le même fichier, appelle `fromJson` puis `toJson` et compare.
- **Backend Python de test** : il lit `routes.json` et sert le fichier `response` de la route demandée. Pour les cas particuliers (erreurs, profil restreint), il adapte le contenu lui-même en suivant les règles ci-dessous.

## Conventions

- Dates en ISO 8601 UTC (`2026-11-07T18:31:12Z`), champs en `snake_case`.
- Valeurs fictives (code `482916`, PIN `1234`, token, adresses).
- Une erreur a toujours la forme de `errors/error.json` : `{"error": {"code", "message", "details"}}`. `details` est facultatif. Les apps se basent sur `code`, jamais sur `message`.

## Routes

| Route | Auth | Requête | Réponse |
|---|---|---|---|
| `GET /api/health` | aucune | | `health/ok.json` |
| `POST /api/tv/connect` (201) | localhost | `tv/connect_request.json` | `tv/connect_response.json` |
| `POST /api/tv/pairing/refresh` | localhost | `tv/refresh_request.json` | `tv/refresh_response.json` |
| `GET /api/tv/status` | localhost | | `tv/status.json` |
| `POST /api/tv/unpair` (204) | localhost | `tv/unpair_request.json` | |
| `POST /api/tv/text-input` (204) | localhost | `tv/text_input_request.json` | |
| `POST /api/remote/pair` | aucune | `pairing/request.json` | `pairing/response.json` |
| `POST /api/remote/input` (204) | Bearer | `remote/input_request.json` | |
| `POST /api/remote/text` (204) | Bearer | `remote/text_request.json` | |
| `POST /api/remote/shortcut` (204) | Bearer | `remote/shortcut_request.json` | |
| `GET /api/profiles` | Bearer | | `profiles/list.json` |
| `POST /api/profiles` (201) | Bearer | `profiles/create_request.json` | `profiles/create_response.json` |
| `GET /api/profiles/{id}` | Bearer | | `profiles/get_response.json` |
| `PATCH /api/profiles/{id}` | Bearer | `profiles/update_request.json` | `profiles/update_response.json` |
| `DELETE /api/profiles/{id}` (204) | Bearer | | |
| `GET /api/session` | Bearer | | `session/current.json` |
| `DELETE /api/session` (204) | Bearer | | |
| `POST /api/session/profile` | Bearer | `session/select_request.json` | `session/select_response.json` |
| `DELETE /api/session/profile` (204) | Bearer | | |
| `GET /api/media` | Bearer + profil choisi | | `media/list.json` |
| `GET /api/media/{id}` | Bearer + profil choisi | | `media/get_response.json` |
| `PUT` / `DELETE /api/media/{id}/favorite` (204) | Bearer + profil choisi | | |
| `PUT` / `DELETE /api/media/{id}/watchlist` (204) | Bearer + profil choisi | | |
| `GET /api/sources` | Bearer + compte non restreint | | `sources/list.json` |
| `POST /api/sources` (201) | Bearer + compte non restreint | `sources/create_request.json` | `sources/create_response.json` |
| `DELETE /api/sources/{id}` (204) | Bearer + compte non restreint | | |
| `POST /api/sources/scan` (202) | Bearer + compte non restreint | `sources/scan_request.json` (facultatif) | `sources/scan_response.json` |
| `GET /api/player` | Bearer | | `player/state.json` |
| `POST /api/player/command` | Bearer | `player/command_request.json` | `player/state.json` |
| `POST /api/player/play` | Bearer + profil choisi | `player/play_request.json` | `player/state.json` |
| `POST /api/player/state` | local (app TV) | `player/state_request.json` | `player/state.json` |
| `GET /api/queue` | Bearer + profil choisi | | `queue/list.json` |
| `POST /api/queue` | Bearer + profil choisi | `queue/add_request.json` | `queue/list.json` |

Les autres routes (listes, extensions, WebSocket...) sont
décrites dans `docs/dev/protocol.md`.

`routes.json` reprend ce tableau, avec les codes d'erreur possibles de chaque route.

## Règles que les fixtures ne peuvent pas montrer

**`tv/status`** : `phase` vaut `pairing` (code affiché), `paired` (téléphone appairé, profil pas encore choisi) ou `ready` (profil actif). `pairing` est rempli seulement en phase `pairing`, sinon `null`. `device` reste `null` jusqu'à l'appairage. `active_profile` reste `null` jusqu'au choix du profil. Une session TV sans téléphone appairé est toujours en phase `pairing`, même si un profil est resté actif. `POST /api/tv/connect` (la TV démarre ou revient à l'appairage) déconnecte les téléphones encore appairés et oublie le profil actif : il faut appairer de nouveau, comme le téléphone le fait à chaque lancement.

**Touches de la télécommande** : `POST /api/remote/input` avec `key` = `up`, `down`, `left`, `right`, `ok`, `back`, `home`, `menu`, `info` ou `play_pause`. Le cœur relaie la touche à la TV sur le WebSocket `GET /api/ws` : `{"type": "input", "data": {"key": "up"}}`. La TV la traite comme une touche du clavier.

**Clavier et raccourcis de la télécommande** (même chemin, par le WebSocket) :
- `POST /api/remote/text` `{"value", "done"}` → la TV reçoit `{"type": "remote.text", "data": {"text", "done"}}` et écrit dans le champ qui a le focus (`done` : validé, comme Entrée). 1000 caractères au plus.
- `POST /api/remote/shortcut` `{"shortcut": "profile"}`, `{"shortcut": "switch_profile"}` ou `{"shortcut": "language", "language": "fr" | "en"}` → la TV reçoit `remote.shortcut`. `switch_profile` ramène la TV à « Qui regarde ? » (profil actif oublié) : le nouveau compte se choisit sur la TV, jamais sur le téléphone seul (pas de désynchronisation). Le téléphone suit le profil avec l'événement `profile.changed`.
- `POST /api/tv/text-input` (app TV) : le champ qui a le focus (`{"active": false}` quand il n'y en a plus) → les téléphones reçoivent `{"type": "text_input", "data": {...}}` et ouvrent leur clavier. Un téléphone qui ouvre son WebSocket pendant qu'un champ a le focus le reçoit tout de suite.
- Le téléphone écoute `GET /api/ws` avec son jeton. Si son jeton est révoqué (la TV l'a désappairé), le serveur envoie aussitôt `{"type": "error", "data": {"code": "unauthorized"}}` puis ferme la connexion.

**Désappairage** : « Appairage » sur la TV (`POST /api/tv/unpair`) ou sur le téléphone (`DELETE /api/session`) révoque le jeton du téléphone, oublie le profil actif et remet la TV en phase `pairing` (un nouveau `tv/status` part sur le flux de la TV). Le téléphone reçoit ensuite `unauthorized` et revient à son écran de connexion.

**Profil** (`profile` dans les réponses) : `kind` vaut `account` ou `guest`. Un invité a `id: null`, `icon: null`, `age: 0` et `is_restricted: true`. Il n'existe pas en base.

**`profiles/create_request`** : `pin` (4 chiffres) est obligatoire si `is_restricted` vaut `false`, et absent sinon. Un invité ne peut pas créer de compte.

**`GET /api/profiles`** : renvoie tout ce qu'il faut pour la page des comptes (invité, droit de créer, liste des comptes).

**`profiles/update_request`** : mêmes champs que la création. `pin` est obligatoire quand on touche à la restriction d'âge (`age` ou `is_restricted`) ; le serveur répond `pin_required` ou `pin_invalid` sinon. Un invité ne peut modifier aucun compte.

**Supprimer un compte** (`DELETE /api/profiles/{id}`, possible depuis « Qui regarde ? », sans profil choisi) : pas de PIN, le media center est local. Les favoris, la liste « À regarder » et la reprise de ce compte sont perdus ; les fichiers ne sont pas touchés.

**Créer un compte** (`POST /api/profiles`) : libre depuis « Qui regarde ? » (aucun profil choisi). Un compte restreint connecté ne peut pas créer de compte non restreint (`admin_required`) ; un invité ne peut rien créer (`guest_forbidden`). Revenir à « Qui regarde ? » oublie le profil actif (`DELETE /api/session/profile`).

**`session/select_request`** :
- `{"type": "guest"}` : ni `profile_id`, ni `pin`
- compte restreint : `profile_id` seul
- compte non restreint : `profile_id` et `pin`

**`session/current`** : `profile` est `null` tant qu'aucun profil n'est choisi.

**`media/list`** : paramètres facultatifs `kind`, `parent_id`, `list`, `q`, `genre`, `max_age`, `limit` (50 par défaut), `offset`. Ils se combinent.
- `kind` accepte plusieurs valeurs séparées par des virgules (`series,season,episode`).
- `list` : `favorites` (favoris du profil actif) ou `watchlist` (sa liste « À regarder »). Tous les niveaux sont possibles (un film, une série, un artiste…). Un invité reçoit une liste vide. Autre valeur : `invalid_query`.
- `q` : recherche dans tout le media center, sans tenir compte de la casse ni des accents, sur le titre. Avec `q`, `parent_id` est ignoré : épisodes et morceaux sont aussi trouvés.
- `genre` : garde les médias dont `genres` contient cette valeur (comparaison exacte).
- `max_age` : garde les médias dont `age_rating` est connu et inférieur ou égal (`0`, `10`, `12`, `16` ou `18`). C'est un filtre choisi à l'écran, en plus du filtre du profil.
- `genres` : genres du média (vient de `media_details.genres`), liste vide si inconnus.
- Sans `parent_id`, c'est le niveau du haut (films, séries, artistes, podcasts). Avec, c'est le contenu de ce média (saisons d'une série, épisodes d'une saison, morceaux d'un album).
- **Le serveur filtre selon le profil actif** : un profil restreint reçoit seulement les médias dont `age_rating` est connu et inférieur ou égal à son âge. L'app ne refait jamais ce filtre.
- `poster_url` est une URL de l'API (pas un chemin du disque), `null` sans affiche. Elle exige le token, donc le chargeur d'images de l'app doit l'envoyer dans l'en-tête.
- `status: "missing"` : le fichier a disparu, le média reste listé pour être affiché grisé.
- `match_status: "unmatched"` : le titre est le nom du fichier, sans affiche ni classification (`age_rating: null`).
- Tri par titre (sans tenir compte de la casse) au niveau du haut, par `sort_number` dans un parent.

**`media/get_response`** : la fiche d'un média (popup de la TV). Mêmes champs qu'un élément de `media/list`, plus :
- `overview` : résumé (vient de `media_details.overview`), `null` si inconnu ;
- `in_favorites`, `in_watchlist` : le média est dans les favoris / la liste « À regarder » du profil actif (toujours `false` pour un invité).
- Un média que le profil n'a pas le droit de voir répond `media_not_found`, comme un média inconnu.

**`PUT` / `DELETE /api/media/{id}/favorite`** et **`/watchlist`** : ajoute ou retire le média de la liste du profil actif. Sans corps, réponse `204` sans corps. Idempotent : ajouter un média déjà présent ou retirer un média absent répond aussi `204`. Un invité reçoit `guest_forbidden` : la TV garde elle-même ses favoris et sa liste « À regarder », en mémoire, le temps de la session (perdus en changeant de profil).

**`sources`** : les dossiers que le media center scanne (table `source`). Réservé aux comptes non restreints : un invité ou un compte restreint reçoit `settings_forbidden`.
- `uri` : `file:///D:/Films` pour un dossier du serveur, `smb://nas/films` pour un partage réseau. `protocol` (`local`, `smb`, `dlna`, `nfs`, `webdav`) est déduit de l'URI par le serveur.
- `status` : `online`, `offline`, `error` ou `unknown` (jamais vérifié). `last_scan_at` est `null` tant qu'aucun scan n'a eu lieu. `media_count` : médias trouvés dans ce dossier.
- `POST /api/sources` : `name` est facultatif (par défaut le nom du dossier). Dossier introuvable ou URI invalide : `validation_failed` (`details.fields.uri`). Dossier déjà ajouté : `source_exists`. Le serveur lance un premier scan.
- `DELETE /api/sources/{id}` : retire le dossier ; ses médias disparaissent de la médiathèque (les fichiers ne sont pas touchés).
- `POST /api/sources/scan` : relance le scan. Le corps est **facultatif** :
  - sans corps (ou `uris` vide) : **tous** les dossiers sont rescannés (bouton « Tout scanner ») ;
  - avec `{"uris": [...]}` : seulement ces dossiers (les `uri` de `sources/list`), par exemple le bouton « Rescanner » d'un dossier.
  Réponse `202` : `scanning` liste les dossiers dont le scan démarre ; il tourne en arrière-plan (`last_scan_at` et `media_count` se mettent à jour ensuite). Une URI qui n'est pas un dossier ajouté : `validation_failed` (`details.fields.uris`), rien n'est lancé.

**Lecture pilotée par le cœur** : la TV ne choisit jamais seule ce qu'elle lit.
- `POST /api/player/play` lance un média (toutes ses feuilles : une série reprend au premier épisode non vu), un élément de la file ou une liste de lecture. Un seul de `media_id`, `queue_item_id`, `playlist_id` ; `resume` (vrai par défaut) reprend là où le profil s'était arrêté. Rien à lire : `nothing_to_play`.
- Le cœur envoie alors à la TV l'événement WebSocket `player.command` (`events/player_command_load.json`) : `action: "load"`, `now_playing.uri` (chemin du fichier sur la machine du cœur, ou URL d'un lien envoyé vers la télé) et `start_s` (position de reprise). Les autres actions (`play`, `pause`, `toggle`, `stop`, `seek`, `seek_relative`, `volume`, `audio_track`, `subtitle_track`, `subtitle_delay`) pilotent le lecteur ouvert.
- La TV publie l'état réel avec `POST /api/player/state` (route locale) : à chaque changement de statut ou de piste, et toutes les 5 s pendant la lecture. `status: "ended"` fait enchaîner le média suivant ; le cœur enregistre la reprise.

## Codes d'erreur

| Code | HTTP | Quand |
|---|---|---|
| `unauthorized` | 401 | Token manquant, expiré ou révoqué : retour à l'écran d'appairage |
| `pairing_code_invalid` | 403 | Code incorrect (`details.attempts_left`) |
| `pairing_code_expired` | 410 | Code expiré, la TV en affiche un nouveau |
| `pairing_too_many_attempts` | 429 | Code invalidé (`details.retry_after_s`) |
| `profile_required` | 403 | Aucun profil choisi |
| `guest_forbidden` | 403 | Un invité tente de créer un compte |
| `pin_required` | 403 | Compte non restreint choisi sans PIN |
| `pin_invalid` | 403 | PIN incorrect (`details.attempts_left`) |
| `pin_locked` | 429 | Trop d'essais (`details.retry_after_s`) |
| `tv_session_not_found` | 404 | Session TV inconnue (serveur redémarré) : la TV refait `POST /api/tv/connect` |
| `profile_not_found` | 404 | Profil inconnu |
| `profile_name_taken` | 409 | Nom déjà pris |
| `validation_failed` | 422 | Champ invalide (`details.fields`) |
| `media_not_found` | 404 | Média ou `parent_id` inconnu, ou média masqué par le contrôle parental |
| `settings_forbidden` | 403 | Réglages du media center demandés par un invité ou un compte restreint |
| `source_not_found` | 404 | Dossier de scan inconnu |
| `source_exists` | 409 | Dossier déjà ajouté |
| `invalid_query` | 422 | Paramètre invalide (`details.fields`) |
| `nothing_to_play` | 409 | Rien à lire (série sans épisode, file vide) |
| `localhost_only` | 403 | Route réservée à l'app TV (accès local) |
| `admin_required` | 403 | Action réservée à un compte non restreint |

Liste complète : `docs/dev/protocol.md`.

Seule exception : `GET /api/health` répond `503` avec `{"status": "starting"}` tant que la base n'est pas prête.

## Choix à valider

1. La TV interroge `GET /api/tv/status` à intervalle régulier pour savoir quand l'appairage a réussi (pas de notification poussée).
2. Créer un compte l'active aussitôt (`"active": true`).
3. Le QR est une alternative au code tapé : il contient le code d'appairage (`code`), en plus de l'adresse, du port et de l'identifiant de session. Le téléphone connaît déjà le serveur : scanner suffit pour appairer (`POST /api/remote/pair` avec ce code). Aucun risque de plus : le même code est affiché en clair sous le QR. Le QR change donc à chaque nouveau code. Le schéma `mediacenter://` est provisoire.
4. Le token expire au bout de 30 jours (`expires_at`, `null` s'il n'expire pas).
5. Les médias `missing` sont renvoyés dans la liste.
6. Favoris, « À regarder » et recherche passent par `GET /api/media` (paramètres `list`, `q`, `genre`, `max_age`) : même réponse partout, une seule route à tester. On ajoute ou retire avec `PUT` / `DELETE /api/media/{id}/favorite` (ou `/watchlist`).

## Écarts avec `schema.sql` (réglés)

La migration `crates/storage/migrations/0002_profiles_devices.sql` ajoute :

- **PIN par compte** : `user.pin_hash` (argon2). `app_state.parental_pin_hash` n'est plus utilisé.
- **Âge à la création** : obligatoire, comme dans les fixtures.
- **Appareil** : `device.install_id`, `platform`, `expires_at`, `last_seen_at`.
- **Dossiers de scan** : `source` n'a pas de compteur de médias ; `media_count` se calcule avec `COUNT(*)` sur `media.source_id`.
- **« À regarder »** : table `watchlist(user_id, media_id, added_at)`.
