# Extensions du media center — spécification

23 novembre 2026

## Vue d'ensemble

Trois extensions de types différents couvrent l'exigence 02-E du sujet EpiKodi : une source, un fournisseur d'informations et un service. Elles tournent toutes dans le cœur Rust (runtime WASM) ; l'interface TV affiche ce qu'elles produisent, le téléphone n'en voit que les médias.

| Extension | Type | Rôle | Permissions | Ce que la TV affiche |
| --- | --- | --- | --- | --- |
| Internet Archive | `source` | Parcourir, chercher et lire en streaming des films du domaine public | `network` (archive.org) | Une source navigable : catégories, grilles d'affiches, fiches, lecture |
| OMDb Ratings | `metadata` | Ajouter aux fiches films les notes IMDb, Rotten Tomatoes et Metacritic, les récompenses, la classification et le box-office | `network` (omdbapi.com), `library_read` | Une ligne de notes sur la fiche film + choix supplémentaires en correction manuelle |
| Minuteur de veille | `service` | Mettre la lecture en pause après une durée, un nombre d'épisodes ou à la fin du média | `playback_control`, `events` | Un widget sur l'accueil + une notification avant l'arrêt |

À côté : deux thèmes (défaut + thème avec police et mascotte), installables par le même système avec le type `theme`, et des extensions de test « malveillantes » pour prouver l'isolation.

## Socle commun

Le cœur Rust exécute chaque extension dans une sandbox WebAssembly (`wasmtime`). L'extension ne voit que les fonctions hôtes que ses permissions acceptées débloquent. Elle ne parle jamais à l'interface TV : elle renvoie des données au cœur, qui les transforme en messages JSON pour la TV.

```
 Extensions (.wasm)              Cœur Rust                         Clients
┌──────────────────────┐      ┌──────────────────────────┐      ┌───────────────────────────┐
│ Internet Archive     │─────►│ Runtime WASM             │ JSON │ Interface TV              │
│ source · network     │      │ (wasmtime, limites)      │─────►│ widgets, fiches, notes    │
├──────────────────────┤      ├──────────────────────────┤      │ menu Extensions           │
│ OMDb Ratings         │─────►│ Permissions              │      │ mise en page du thème     │
│ metadata · network,  │      │ fonctions hôtes filtrées │      └───────────────────────────┘
│ library              │      ├──────────────────────────┤ API  ┌───────────────────────────┐
├──────────────────────┤      │ Registres + VLC          │─────►│ Téléphone                 │
│ Minuteur de veille   │─────►│ (sources, notes, widgets)│      │ médias et lecture via     │
│ service · playback,  │      └──────────────────────────┘      │ l'API de contrôle         │
│ events               │                                        └───────────────────────────┘
└──────────────────────┘
```

Chaque extension n'appelle que le cœur ; le cœur filtre ses appels par permissions, puis pousse les résultats en JSON à la TV.

### Format du paquet

Un `.zip` renommé avec votre extension de fichier (exemple : `.mcx`).

```
mon-extension-1.0.0.mcx
├── manifest.toml      # identité, type, permissions, réglages
├── extension.wasm     # le code compilé
├── icon.png           # 256 x 256
└── i18n/fr.json       # textes traduits (optionnel)
```

### Manifeste (champs communs)

| Champ | Exemple | Rôle |
| --- | --- | --- |
| `id` | `org.monproduit.archive` | Identifiant unique, format domaine inversé |
| `name`, `description`, `author` | `Internet Archive` | Affichés dans le menu Extensions |
| `version` | `1.0.0` | Semver, comparé lors des mises à jour |
| `type` | `source` / `metadata` / `service` / `widget` / `theme` | Indique au cœur où brancher l'extension |
| `api_version` | `1` | Version de l'API hôte attendue ; refus si incompatible |
| `[permissions]` | `network = ["archive.org"]` | Tout ce qui est absent est refusé |
| `[[settings]]` | `key`, `type`, `label`, `default` | La TV génère le formulaire de réglages à partir de cette liste |

### Permissions et fonctions hôtes

| Permission | Fonctions débloquées | Utilisée par |
| --- | --- | --- |
| `network = [domaines]` | `http_get(url)` : refusé si le domaine n'est pas dans la liste | Internet Archive, OMDb |
| `library_read` | `library_get(id)`, `library_search(query)` | OMDb |
| `playback_control` | `playback_pause()`, `playback_set_volume(v)`, `playback_state()` | Minuteur |
| `events` | Reçoit `on_event(evt)` : lecture démarrée, en pause, terminée, média suivant | Minuteur |
| `storage` | `storage_get(key)`, `storage_set(key, value)` : espace isolé par extension | Toutes (cache, état) |
| (toujours) | `log(level, msg)`, `settings_get(key)`, `notify(message)`, `now()`, `schedule(delay_ms)` | Toutes |

### Canal cœur → interface TV

Le cœur pousse des messages JSON à la TV (WebSocket local ou IPC selon votre stack). Les extensions ne décident jamais de la position, des couleurs ni des polices : le thème actif s'en charge.

```json
{ "type": "extension.status", "extension_id": "org.monproduit.archive", "status": "active" }
{ "type": "notification", "level": "warning", "source": "org.monproduit.timer", "text": "Pause dans 1 minute" }
```

Valeurs de `status` : `installing`, `active`, `disabled`, `crashed`, `updating`.

### Filtres et tris

Le cœur est la seule source de vérité pour les filtres : il construit la liste à partir des sources actives et des extensions installées, puis l'envoie à la TV. La TV n'a aucun filtre codé en dur ; quand une extension est activée ou désactivée, le cœur renvoie la liste et l'interface se met à jour.

| Origine | Ce qu'elle apporte | Comment |
| --- | --- | --- |
| Cœur | Source, genre, année, vu / non vu, favoris ; tris titre, date d'ajout, année | Toujours présents |
| Extension `source` | Une option dans le filtre Source + ses propres filtres (collection, décennie…) | Fonction `list_filters()`, valeurs repassées à `list_items` / `search` |
| Extension `metadata` | Des champs triables ou filtrables (note, récompenses…) | Section `[[fields]]` du manifeste ; valeurs stockées en base par le cœur, filtrage en local et hors ligne |

Les identifiants venant d'une extension sont préfixés `ext:` pour éviter les collisions avec ceux du cœur.

```json
{
  "type": "library.filters",
  "view": "movies",
  "sort_options": [
    { "value": "title", "label": "Titre" },
    { "value": "added", "label": "Date d'ajout" },
    { "value": "ext:omdb.imdb_rating", "label": "Note IMDb" },
    { "value": "ext:omdb.box_office", "label": "Box-office" }
  ],
  "filters": [
    {
      "id": "source",
      "label": "Source",
      "kind": "single_choice",
      "options": [
        { "value": "all", "label": "Tout" },
        { "value": "local", "label": "Sur cet appareil" },
        { "value": "smb:nas-salon", "label": "NAS du salon" },
        { "value": "ext:archive", "label": "Internet Archive" }
      ],
      "selected": "all"
    },
    { "id": "genre", "label": "Genre", "kind": "multi_choice", "options": ["…"] },
    { "id": "year", "label": "Année", "kind": "range", "min": 1902, "max": 2026 },
    { "id": "ext:omdb.imdb_rating", "label": "Note IMDb minimum", "kind": "min", "min": 0, "max": 10, "step": 0.5 },
    { "id": "ext:omdb.oscars", "label": "Récompensés aux Oscars", "kind": "toggle" }
  ]
}
```

La TV renvoie le choix de l'utilisateur au cœur, qui répond avec la page de résultats :

```json
{ "type": "library.query", "view": "movies", "sort": "ext:omdb.imdb_rating", "order": "desc", "filters": { "source": "all", "ext:omdb.imdb_rating": 7 }, "page": 1 }
```

Types de filtre possibles : `single_choice`, `multi_choice`, `range`, `min`, `toggle`. Tous se règlent aux flèches et à Entrée.

### Cycle de vie

1. **Installation** : décompresser dans un dossier temporaire, valider le manifeste, compiler le `.wasm`. Un échec annule tout.
2. **Permissions** : la TV affiche la liste ; l'utilisateur accepte ou annule.
3. **Enregistrement** : copie dans `extensions/<id>/`, ligne en base (statut, permissions accordées, réglages).
4. **Activation** : instanciation avec un linker filtré par permissions, puis branchement dans le registre du type (sources, métadonnées, services).
5. **Mise à jour** : nouvelles permissions = nouvelle validation par l'utilisateur, puis remplacement à chaud.
6. **Désactivation / désinstallation** : retrait du registre, destruction de l'instance, suppression des données si l'utilisateur le demande.

### Isolation et ressources

| Risque | Protection | Ce que voit l'utilisateur |
| --- | --- | --- |
| Plantage (trap WASM) | Erreur rattrapée côté Rust ; après 3 plantages, désactivation | Notification + statut `crashed` dans le menu |
| Boucle infinie | Epoch interruption : appel coupé après un délai (ex. 5 s) | Notification « extension arrêtée » |
| Mémoire | `StoreLimits` (ex. 64 Mo par extension) | Idem |
| Accès non déclaré | Fonction hôte absente du linker ou domaine refusé | Rien : l'appel échoue côté extension, entrée dans les logs |

Les délais et plafonds ci-dessus sont des valeurs de départ à ajuster après mesure.

## Extension 1 — Internet Archive (`source`)

L'extension transforme le catalogue d'Internet Archive en une source navigable sur la TV, lue en streaming par VLC sans téléchargement. Elle ne fournit que des listes et des URL : c'est le cœur qui lit le flux.

### Périmètre

| Inclus | Exclu (v1) |
| --- | --- |
| Parcourir des collections choisies (films, documentaires, dessins animés), avec filtres collection, décennie et durée | Musique et livres audio d'Internet Archive |
| Recherche par titre | Compte utilisateur Internet Archive |
| Fiche : titre, année, description, vignette, licence | Téléchargement local (option possible plus tard, permission `downloads`) |
| Choix automatique du meilleur fichier vidéo | Sous-titres externes (si présents dans l'élément : bonus) |

### Manifeste

```toml
id = "org.monproduit.archive"
name = "Internet Archive"
version = "1.0.0"
type = "source"
api_version = "1"
description = "Films du domaine public depuis archive.org"

[permissions]
network = ["archive.org"]   # sous-domaines inclus
storage = true                # cache des recherches

[[settings]]
key = "collections"
type = "multi_choice"
label = "Collections affichées"
options = ["feature_films", "prelinger", "classic_cartoons"]
default = ["feature_films"]

[[settings]]
key = "quality"
type = "choice"
label = "Qualité préférée"
options = ["auto", "480p", "720p"]
default = "auto"
```

### Fonctions exportées

| Fonction | Appelée quand | Renvoie |
| --- | --- | --- |
| `list_items(path, page)` | L'utilisateur ouvre la source ou une collection | Dossiers (collections) ou médias, paginés par 50 |
| `search(query, page)` | L'utilisateur tape une recherche | Liste de médias |
| `get_item(id)` | Ouverture d'une fiche | Titre, année, description, durée, licence, vignette |
| `resolve_stream(id)` | Appui sur Lecture | URL du fichier vidéo choisi |

### Processus

1. **Ouverture de la source** : `list_items("/")` renvoie les collections activées dans les réglages.
2. **Parcours d'une collection** : l'extension appelle l'API de recherche d'Internet Archive.
   - `GET https://archive.org/advancedsearch.php?q=collection:feature_films AND mediatype:movies&fl[]=identifier&fl[]=title&fl[]=year&rows=50&page=1&output=json`
   - Vignette de chaque élément : `https://archive.org/services/img/{identifier}`
3. **Recherche** : même requête avec `title:(nosferatu)` ajouté au filtre de collection.
4. **Fiche** : `GET https://archive.org/metadata/{identifier}` donne la description, la licence (`licenseurl` quand elle existe) et la liste des fichiers.
5. **Lecture** : `resolve_stream` choisit dans la liste des fichiers un `.mp4` (puis `.ogv` à défaut) selon la qualité voulue et renvoie `https://archive.org/download/{identifier}/{fichier}`. Le cœur passe l'URL à VLC.
6. **Pendant la lecture** : comme un fichier local (reprise, progression par profil, pilotage téléphone). La reprise s'appuie sur l'identifiant `archive:{identifier}`.

### Filtres et place dans la médiathèque

L'extension ajoute l'option « Internet Archive » au filtre Source, et déclare ses propres filtres avec une fonction supplémentaire :

| Fonction | Appelée quand | Renvoie |
| --- | --- | --- |
| `list_filters()` | Le cœur construit `library.filters` alors que Source = Internet Archive | Collection (choix parmi celles activées), décennie, durée (court / long métrage) |

Le catalogue d'Internet Archive est trop grand pour être mélangé à la médiathèque. Règles :

- **Source = Tout** (par défaut) : médias locaux et réseau + uniquement les films Internet Archive que l'utilisateur a ajoutés (favoris, déjà vus, en cours). Ces films sont enregistrés en base par le cœur et enrichis comme les autres.
- **Source = Internet Archive** : le catalogue complet, chargé page par page depuis l'extension. Seuls les filtres de l'extension s'appliquent ; les tris et filtres du cœur basés sur la base (notes IMDb, vu / non vu) sont masqués.
- **Recherche globale** : le cœur interroge la médiathèque et l'extension en parallèle ; la TV affiche deux sections, « Dans ma médiathèque » et « Sur Internet Archive ». Si l'extension ne répond pas dans les 10 s, la première section s'affiche seule.
- **Bouton « Ajouter à ma médiathèque »** sur la fiche d'un film Internet Archive : il le fait apparaître dans Source = Tout.

### Données envoyées à la TV

Page de catalogue (le cœur relaie le résultat de `list_items` ou `search`) :

```json
{
  "type": "source.page",
  "extension_id": "org.monproduit.archive",
  "path": "/feature_films",
  "page": 1,
  "has_more": true,
  "items": [
    {
      "id": "archive:nosferatu_1922",
      "kind": "movie",
      "title": "Nosferatu",
      "year": 1922,
      "thumbnail": "https://archive.org/services/img/nosferatu_1922",
      "accessible_label": "Nosferatu, film de 1922"
    }
  ]
}
```

Fiche média :

```json
{
  "type": "media.details",
  "id": "archive:nosferatu_1922",
  "title": "Nosferatu",
  "year": 1922,
  "overview": "…",
  "duration_s": 5640,
  "license": "Domaine public",
  "provider": "Internet Archive",
  "actions": ["play", "add_favorite"]
}
```

`id`, `year` et la durée ci-dessus sont des exemples ; les vraies valeurs viennent de l'API.

### Erreurs et hors ligne

| Situation | Comportement |
| --- | --- |
| Pas de connexion | Dernières pages en cache affichées + bandeau « Hors ligne » ; lecture impossible, message clair |
| archive.org lent | Délai de 10 s par requête, puis message « Internet Archive ne répond pas » et bouton Réessayer |
| Aucun fichier vidéo lisible | Fiche affichée, bouton Lecture désactivé, mention « Format non disponible » |
| VLC échoue en cours de lecture | Événement `EncounteredError` → retour à la fiche + message |

### Légal

Tout ce qui est sur Internet Archive n'est pas libre de droits. Limitez l'extension à des collections domaine public connues, affichez la licence de chaque élément et masquez ceux dont la licence est inconnue si vous voulez être irréprochables devant le jury.

### Tests

- `list_items` et `search` sur des réponses JSON enregistrées (mocks, aucun réseau).
- Choix du fichier dans `resolve_stream` : mp4 présent, seulement ogv, aucun fichier vidéo.
- Appel à un domaine hors `archive.org` refusé par l'hôte.
- Comportement hors ligne : cache servi, erreur propre. Recherche globale : la section Internet Archive est absente si l'extension ne répond pas, sans bloquer la médiathèque.

## Extension 2 — OMDb Ratings (`metadata`)

L'extension ajoute aux fiches films les notes IMDb, Rotten Tomatoes et Metacritic, les récompenses, la classification d'âge et le box-office, et propose ses résultats comme choix supplémentaires lors d'une correction manuelle. Elle n'ajoute aucun média : elle enrichit ceux que le cœur a déjà reconnus.

### Périmètre

| Inclus | Exclu (v1) |
| --- | --- |
| Notes des films (IMDb, Rotten Tomatoes, Metacritic) | Avis d'utilisateurs (pas d'API publique chez IMDb ni Letterboxd) |
| Récompenses (Oscars, prix, nominations) | Nombre de votes IMDb |
| Classification d'âge, en secours de TMDB pour le contrôle parental | Résumé, casting, genres : fournis par TMDB dans le cœur |
| Box-office (recettes aux États-Unis) | Notes par épisode de série, musique, podcasts |
| Recherche par titre et année pour la correction manuelle | |
| Cache local (7 jours) | |

### Manifeste

```toml
id = "org.monproduit.omdb"
name = "OMDb Ratings"
version = "1.0.0"
type = "metadata"
api_version = "1"
description = "Notes, récompenses, classification et box-office via OMDb"
media_kinds = ["movie"]

[permissions]
network = ["www.omdbapi.com"]
library_read = true
storage = true

[[settings]]
key = "api_key"
type = "secret"        # stocké chiffré, jamais affiché en clair
label = "Clé d'API OMDb"

[[settings]]
key = "show"
type = "multi_choice"
label = "Informations affichées"
options = ["imdb", "rotten_tomatoes", "metacritic", "awards", "box_office"]
default = ["imdb", "rotten_tomatoes", "metacritic", "awards", "box_office"]
# la classification n'est pas désactivable : elle sert au contrôle parental
```

### Fonctions exportées

| Fonction | Appelée quand | Renvoie |
| --- | --- | --- |
| `details(media_ref)` | Le cœur enrichit un film (après scan ou à l'ouverture d'une fiche) | Notes, récompenses, classification, box-office |
| `search(title, year)` | Correction manuelle d'un film | Liste de candidats (titre, année, affiche, identifiant IMDb) |

### Processus

1. **Déclenchement** : le cœur reconnaît un film et l'enrichit avec TMDB (résumé, casting, genres, affiche), qui fournit aussi l'identifiant IMDb (`tt…`). Il appelle ensuite `details` sur chaque extension `metadata` active.
2. **Cache** : l'extension regarde d'abord dans `storage`. Une réponse de moins de 7 jours est renvoyée sans appel réseau.
3. **Appel OMDb** : `GET https://www.omdbapi.com/?i={imdb_id}&apikey={clé}`. Sans identifiant IMDb : `?t={titre}&y={année}&type=movie`. Un seul appel renvoie tout.
4. **Lecture de la réponse** :
   - `Ratings` : une entrée par site, normalisée sur 100 pour l'affichage.
   - `Awards` : texte en anglais (« Won 3 Oscars. 45 wins & 67 nominations »), affiché tel quel ou traduit par quelques règles simples.
   - `Rated` : classification américaine, convertie en âge minimum (table ci-dessous).
   - `BoxOffice` : recettes aux États-Unis en dollars, converties en nombre.
   - Toute valeur `"N/A"` est ignorée.
5. **Retour au cœur** : le cœur fusionne les infos dans la fiche et pousse la mise à jour à la TV. Pour la classification, le cœur garde celle de TMDB pour la France si elle existe, et n'utilise OMDb qu'en secours.
6. **Correction manuelle** : quand l'utilisateur corrige un film, le cœur appelle `search` de TMDB et d'OMDb ; la TV affiche les deux listes, chaque résultat marqué de son fournisseur.

Correspondance des classifications (approximative, à valider par le groupe) :

| OMDb `Rated` | Âge minimum utilisé par le contrôle parental |
| --- | --- |
| G, TV-Y, TV-G | Tous publics |
| PG, TV-PG, TV-Y7 | 10 ans |
| PG-13, TV-14 | 12 ans |
| R | 16 ans |
| NC-17, TV-MA | 18 ans |
| Not Rated, Unrated, N/A | Inconnu : traité comme 18 ans dans un profil enfant |

### Tris et filtres

L'extension déclare dans son manifeste les champs qu'elle fournit et qu'on peut trier ou filtrer. Le cœur stocke leurs valeurs en base au moment de l'enrichissement : le filtrage se fait en local, sans appeler OMDb, et marche hors ligne.

```toml
[[fields]]
key = "imdb_rating"
label = "Note IMDb"
type = "number"        # 0 à 10
sortable = true
filterable = "min"

[[fields]]
key = "rt_score"
label = "Rotten Tomatoes"
type = "number"        # 0 à 100
sortable = true
filterable = "min"

[[fields]]
key = "metascore"
label = "Metacritic"
type = "number"        # 0 à 100
sortable = true
filterable = "min"

[[fields]]
key = "oscars"
label = "Récompensés aux Oscars"
type = "number"
filterable = "toggle"   # vrai si au moins 1 Oscar

[[fields]]
key = "box_office"
label = "Box-office"
type = "number"        # dollars
sortable = true
```

| Dans la vue Films | Exemple |
| --- | --- |
| Tri par note IMDb, Rotten Tomatoes ou Metacritic | « Mieux notés IMDb d'abord » |
| Tri par box-office | Les plus gros succès d'abord |
| Filtre note minimale | IMDb ≥ 7 |
| Filtre récompensés | Films oscarisés |
| Filtre classification | Fourni par le cœur (TMDB, OMDb en secours) ; le contrôle parental l'applique déjà aux profils enfants |

- Films sans valeur (inconnus d'OMDb ou pas encore enrichis) : en fin de liste quand on trie, exclus quand on filtre sur un minimum.
- Ces options disparaissent si l'extension est désactivée, et sont masquées quand Source = Internet Archive (catalogue non enrichi).

### Données envoyées à la TV

Informations ajoutées à la fiche film :

```json
{
  "type": "media.extra_info",
  "media_id": "movie:42",
  "provider": "OMDb",
  "attribution": "Données : OMDb API",
  "ratings": [
    { "source": "imdb", "label": "IMDb", "display": "7,9/10", "score_100": 79 },
    { "source": "rotten_tomatoes", "label": "Rotten Tomatoes", "display": "97 %", "score_100": 97 },
    { "source": "metacritic", "label": "Metacritic", "display": "88/100", "score_100": 88 }
  ],
  "awards": {
    "display": "3 Oscars · 45 prix · 67 nominations",
    "raw": "Won 3 Oscars. 45 wins & 67 nominations"
  },
  "certification": { "system": "US", "code": "PG-13", "min_age": 12, "source": "omdb" },
  "box_office": { "amount": 292587330, "currency": "USD", "display": "292,6 M$ (États-Unis)" },
  "accessible_label": "Notes : IMDb 7,9 sur 10, Rotten Tomatoes 97 pour cent, Metacritic 88 sur 100. 3 Oscars. Déconseillé aux moins de 12 ans. Box-office : 292,6 millions de dollars aux États-Unis."
}
```

Candidats en correction manuelle :

```json
{
  "type": "match.candidates",
  "media_id": "movie:42",
  "candidates": [
    { "provider": "TMDB", "title": "Metropolis", "year": 1927, "poster": "…" },
    { "provider": "OMDb", "title": "Metropolis", "year": 1927, "imdb_id": "tt0017136", "poster": "…" }
  ]
}
```

Les valeurs ci-dessus sont des exemples. La TV choisit l'affichage (pastilles, ligne de texte) selon le thème, sans jamais porter l'information par la seule couleur.

### Erreurs et hors ligne

| Situation | Comportement |
| --- | --- |
| Pas de clé d'API | Extension active mais inerte ; la fiche de l'extension affiche « Clé d'API manquante » |
| Clé invalide ou quota dépassé | Notification une seule fois, notes en cache conservées |
| Pas de connexion ou OMDb muet | Notes en cache affichées, sinon la fiche s'affiche sans notes |
| Film inconnu d'OMDb | Rien n'est ajouté, aucune erreur visible |

### Points à respecter

- La clé n'est jamais dans le dépôt : l'utilisateur la saisit dans les réglages (exigence 03-B). Pour la démo, mettez-la dans `.env` et documentez-la dans `.env.example`.
- La clé gratuite est limitée à environ 1 000 requêtes par jour : le cache n'est pas optionnel.
- Affichez l'attribution OMDb et vérifiez ses conditions d'utilisation avant la soutenance.

### Tests

- Parsing d'une réponse OMDb complète, partielle (sans Metacritic) et `Response: False` (mocks).
- Cache : pas d'appel réseau si la note a moins de 7 jours.
- Absence de clé et quota dépassé ; réponse avec Awards, Rated ou BoxOffice à "N/A" ; conversion de chaque classification en âge.
- Un appel à `library_search` sans `library_read` est refusé (test du système de permissions).

## Extension 3 — Minuteur de veille (`service`)

L'extension met la lecture en pause selon trois modes : après une durée (30 min, 1 h…), après un nombre d'épisodes d'une série (1, 2, 3), ou à la fin du film ou de l'épisode en cours. Elle n'a aucun accès réseau ni à la médiathèque : c'est la démonstration d'une extension qui agit sur la lecture et rien d'autre.

### Périmètre

| Mode | Choix proposés | Disponible quand | Ce qui déclenche la pause |
| --- | --- | --- | --- |
| Durée | 15 min, 30 min, 45 min, 1 h, 1 h 30, 2 h | Toujours | L'échéance est atteinte (fondu du volume sur les 30 dernières secondes) |
| Épisodes | Après 1, 2 ou 3 épisodes | Un épisode de série est en cours | Le N-ième épisode se termine ; l'enchaînement automatique est bloqué |
| Fin du média | « Fin du film » ou « Fin de l'épisode » | Un film ou un épisode est en cours | Le média en cours se termine |

L'épisode en cours compte pour 1 : « après 2 épisodes » = finir celui-ci, puis le suivant. Dans les trois modes, l'utilisateur peut prolonger (+15 min ou +1 épisode) ou annuler. Exclus en v1 : mise en veille du système, programmation à heure fixe, pilotage depuis le téléphone.

### Manifeste

```toml
id = "org.monproduit.sleeptimer"
name = "Minuteur de veille"
version = "1.0.0"
type = "service"
api_version = "1"
description = "Met la lecture en pause après une durée, un nombre d'épisodes ou à la fin du média"
provides_widget = true

[permissions]
playback_control = true
events = ["playback.started", "playback.paused", "playback.ended", "playback.next"]
storage = true

[[settings]]
key = "default_mode"
type = "choice"
label = "Mode par défaut"
options = ["duration", "episodes", "end_of_media"]
default = "duration"

[[settings]]
key = "default_minutes"
type = "choice"
label = "Durée par défaut"
options = ["15", "30", "45", "60", "90", "120"]
default = "30"

[[settings]]
key = "default_episodes"
type = "choice"
label = "Nombre d'épisodes par défaut"
options = ["1", "2", "3"]
default = "1"

[[settings]]
key = "fade_out"
type = "bool"
label = "Baisser le volume progressivement"
default = true
```

### Fonctions exportées

| Fonction | Appelée quand | Rôle |
| --- | --- | --- |
| `start_duration(minutes)` | L'utilisateur choisit une durée | Mémorise l'échéance, demande un réveil à l'hôte |
| `start_episodes(n)` | L'utilisateur choisit 1, 2 ou 3 épisodes | Mémorise le nombre d'épisodes restants |
| `start_end_of_media()` | L'utilisateur choisit « fin du film / de l'épisode » | Équivaut à `start_episodes(1)`, valable aussi pour un film |
| `extend()`, `cancel()` | Boutons du widget ou de la notification | +15 min en mode durée, +1 épisode sinon ; ou annulation |
| `on_timer()` | L'hôte réveille l'extension (fonction hôte `schedule(delay_ms)`) | Préavis, fondu ou pause en mode durée |
| `on_event(evt)` | Événement de lecture | Compte les épisodes terminés, bloque l'épisode suivant, suspend le décompte en pause |
| `render()` | Le cœur rafraîchit le widget | Renvoie les données du widget |

Les événements de lecture doivent porter le type du média (`movie`, `episode`, `track`…) pour que l'extension sache si le mode épisodes s'applique.

L'extension ne fait jamais de boucle d'attente : elle demande à l'hôte de la rappeler. Une boucle serait de toute façon coupée par l'epoch interruption.

### Processus

1. **Choix du mode** : depuis le widget de l'accueil ou l'action rapide « Minuteur » du lecteur. La TV ne propose « Épisodes » que si un épisode de série est en cours, et libelle le troisième mode « Fin du film » ou « Fin de l'épisode » selon le média.
2. **Mode durée** :
   1. L'extension enregistre l'échéance dans `storage` et appelle `schedule` pour être réveillée une minute avant.
   2. À −1 min : `notify("Pause dans 1 minute")` avec Prolonger et Annuler.
   3. À −30 s : fondu du volume par paliers via `playback_set_volume`, réveil toutes les 2 s.
   4. À l'échéance : `playback_pause()`, puis restauration du volume d'origine.
   5. Sur `playback.paused`, le décompte est suspendu ; il reprend sur `playback.started`.
3. **Mode épisodes** (et fin du média, avec N = 1) :
   1. L'extension enregistre `remaining = N`.
   2. À chaque `playback.ended` d'un épisode : `remaining - 1`.
   3. Quand il reste 1 épisode et que celui-ci approche de sa fin (−1 min, via `playback_state()` + `schedule`) : `notify("Dernier épisode : pause à la fin")`.
   4. Quand `remaining` atteint 0 : sur `playback.next`, l'extension bloque l'enchaînement et met en pause ; la TV affiche l'écran de fin d'épisode.
   5. Si l'utilisateur change de média à la main (autre série, film), le compteur continue sur ce qui est lu.
4. **Fin** : le minuteur revient à l'état inactif, le widget aussi.

### Données envoyées à la TV

Widget de l'accueil (résultat de `render`, relayé par le cœur) :

```json
{
  "type": "home.widget",
  "extension_id": "org.monproduit.sleeptimer",
  "widget": {
    "kind": "card",
    "size": "small",
    "icon": "timer",
    "title": "Minuteur",
    "primary": "23:41",
    "secondary": "Pause à la fin du décompte",
    "progress": 0.21,
    "accessible_label": "Minuteur de veille : 23 minutes restantes",
    "actions": [
      { "id": "extend", "label": "+15 min" },
      { "id": "cancel", "label": "Annuler" }
    ]
  }
}
```

En mode épisodes, même carte avec un compteur à la place du temps :

```json
{
  "type": "home.widget",
  "extension_id": "org.monproduit.sleeptimer",
  "widget": {
    "kind": "card",
    "size": "small",
    "icon": "timer",
    "title": "Minuteur",
    "primary": "2 épisodes",
    "secondary": "Pause après S01E05",
    "accessible_label": "Minuteur de veille : pause après 2 épisodes, à la fin de l'épisode 5 de la saison 1",
    "actions": [
      { "id": "extend", "label": "+1 épisode" },
      { "id": "cancel", "label": "Annuler" }
    ]
  }
}
```

Minuteur inactif : même carte avec `primary: "Inactif"` et une action `start` par durée. Le cœur pousse une mise à jour toutes les 30 s, et à chaque action.

Préavis :

```json
{
  "type": "notification",
  "source": "org.monproduit.sleeptimer",
  "level": "info",
  "text": "Pause dans 1 minute",
  "actions": [ { "id": "extend", "label": "+15 min" }, { "id": "cancel", "label": "Annuler" } ],
  "timeout_s": 20
}
```

L'action choisie revient au cœur sous la forme `{ "type": "widget.action", "extension_id": "…", "action": "extend" }`, qui appelle `extend()`.

### Erreurs

| Situation | Comportement |
| --- | --- |
| L'extension plante pendant le fondu | Le cœur restaure le volume d'origine, notifie l'utilisateur ; la lecture continue |
| Redémarrage du media center | Échéance relue dans `storage` ; si dépassée, le minuteur est annulé |
| Aucune lecture en cours à l'échéance | Rien à faire, minuteur remis à zéro |

### Tests

- Avec une horloge simulée (`now()` contrôlée par le test) : préavis à −1 min, fondu, pause à l'échéance.
- Suspension pendant une pause manuelle, reprise ensuite.
- Modes épisodes et fin du média : compteur décrémenté à chaque épisode terminé, pause sur `playback.next`.
- Un appel à `http_get` est refusé (aucune permission réseau).

## Thèmes, extensions de test et démo

Les thèmes et les extensions de test ne comptent pas parmi les trois extensions exigées, mais ils réutilisent le même système et servent directement la soutenance.

### Thèmes (type `theme`)

Deux thèmes exigés par le sujet : le thème par défaut et votre thème avec police et mascotte. Un thème est déclaratif : aucun `.wasm`, aucune permission.

```
mon-theme-1.0.0.mcx
├── manifest.toml      # type = "theme"
├── theme.toml         # couleurs, polices, tailles, disposition de l'accueil
├── fonts/             # polices sous licence libre (OFL)
└── assets/mascot.svg  # mascotte, fonds
```

- Le cœur valide le thème au chargement : contraste du texte d'au moins 4,5:1, taille minimale du texte, focus visible. Un thème non conforme est refusé avec un message.
- Changement à chaud : le cœur envoie `{ "type": "theme.changed", "theme_id": "…" }` et la TV recharge ses variables sans redémarrer.

### Extensions de test (non livrées)

| Extension | Comportement | Ce qu'on vérifie |
| --- | --- | --- |
| `test.crash` | Provoque un trap au premier appel | Plantage rattrapé, statut `crashed`, notification |
| `test.loop` | Boucle infinie dans `list_items` | Arrêt par epoch interruption, le media center reste fluide |
| `test.memory` | Alloue sans fin | Arrêt par `StoreLimits` |
| `test.sneaky` | Appelle un domaine non déclaré et `library_search` sans permission | Appels refusés, rien ne fuit |
| `test.bad-manifest` | Manifeste invalide ou `api_version` inconnue | Installation refusée proprement |

Elles couvrent les tests obligatoires sur le cycle de vie des extensions et sur l'isolation (03-B), et tournent en CI.

### Checklist de soutenance

- [ ] Installer Internet Archive en direct depuis un fichier `.mcx`, avec l'écran des permissions
- [ ] Parcourir une collection et lancer un film en streaming, puis le reprendre depuis le téléphone
- [ ] Ouvrir une fiche film avec les notes, récompenses et box-office OMDb, puis trier la vue Films par note IMDb et filtrer par source ; corriger un film et montrer les candidats TMDB + OMDb
- [ ] Lancer le minuteur (durée puis épisodes), montrer le widget, le préavis et la pause
- [ ] Changer de thème à chaud (police + mascotte)
- [ ] Installer `test.loop` : l'extension est arrêtée, le media center continue
- [ ] Tout faire au clavier (flèches, Entrée, Retour), sans souris

### Documentation à produire

Le guide du développeur d'extensions (exigé en 03-C) peut reprendre ce document : socle commun = référence de l'API, et le minuteur = tutoriel « de zéro à une extension fonctionnelle », car c'est la plus simple.
