# Lecture

> Moteur de lecture retenu, formats supportés, sous-titres, reprise de lecture.

## Moteur de lecture

L'app TV lit les médias avec **media_kit** (libmpv), choix justifié dans l'[ADR 0001](../adr/0001-moteur-de-lecture.md).

Le moteur est isolé derrière l'interface `PlaybackEngine` (`apps/tv/lib/player/`). Les écrans ne dépendent que de cette interface, ce qui permet :

- de remplacer media_kit (par VLC par exemple) sans modifier l'interface utilisateur ;
- de tester l'écran de lecture avec un faux moteur, sans libmpv.

## Formats supportés

media_kit s'appuie sur les décodeurs de FFmpeg.

| Catégorie | Formats |
|---|---|
| Conteneurs | MKV, MP4, AVI, MOV, WebM, TS / M2TS, OGG |
| Vidéo | H.264, H.265 / HEVC, AV1, VP9, MPEG-2 (décodage matériel si disponible) |
| Audio | AAC, MP3, FLAC, Opus, AC3 / E-AC3, DTS, TrueHD |
| Sous-titres | SRT, ASS / SSA, PGS, VobSub, intégrés ou externes |

Sous Linux, la liste exacte dépend du FFmpeg de la distribution (`libmpv` système).

## Écran de lecture

`PlayerScreen` (`apps/tv/lib/player/player_screen.dart`) affiche la vidéo en plein écran et un bandeau de contrôles en bas : titre, barre de progression avec les temps écrits, boutons Reculer 10 s, Lecture / Pause, Avancer 30 s (#21).

### Touches

| Touche | Contrôles masqués | Contrôles affichés |
|---|---|---|
| Entrée / OK / Espace | lecture ↔ pause | active le bouton qui a le focus |
| ← / → | recule de 10 s / avance de 30 s | déplace le focus entre les boutons |
| ↑ / ↓ | affiche les contrôles | déplace le focus |
| Retour / Échap | quitte la lecture | quitte la lecture |
| Touches multimédia | lecture, pause, avance, retour rapide | idem |

Les contrôles se masquent après 5 s sans touche, seulement pendant la lecture. En pause, en erreur ou à la fin du média, ils restent affichés.

### Accessibilité

- **Focus** : au lancement, il est sur Lecture / Pause. Contour blanc de 4 px du design system, visible à 3 m.
- **Lecteur d'écran** : chaque bouton a un libellé (« Pause », « Avancer de 30 secondes »). La barre annonce « Position de lecture : 2:00 sur 10:00 ». Chargement, erreur et fin de lecture sont des zones annoncées automatiquement (`liveRegion`). La vidéo elle-même est exclue de l'arbre sémantique.
- **Pas seulement la couleur** : l'état « En pause » est écrit en toutes lettres, les temps sont affichés à côté de la barre.
- **Animations désactivées** (`reducedMotion`) : pas de fondu des contrôles, pas de roue de chargement (le texte « Chargement… » suffit). Aucun contenu clignotant.
- **Contraste** : texte blanc sur dégradé noir à 90 % en bas de l'image.

### Tests

`apps/tv/test/player_screen_test.dart` utilise un faux moteur (`test/support/fake_engine.dart`) : touches, masquage des contrôles, focus, Retour, erreurs, annonces du lecteur d'écran, fenêtre minimale.

## Pistes audio et sous-titres

Le bouton **Audio et sous-titres** du lecteur ouvre un panneau à droite (`apps/tv/lib/player/track_panel.dart`, #22). Les choix s'appliquent immédiatement ; Retour ferme le panneau et rend le focus à Lecture / Pause. Les contrôles restent affichés tant que le panneau est ouvert.

| Section | Choix |
|---|---|
| Audio | pistes du fichier, une par ligne |
| Sous-titres | Désactivés, puis les pistes du fichier |
| Taille des sous-titres | Petite (×0,75), Normale, Grande (×1,35), Très grande (×1,75) |
| Couleur du texte | Blanc, Jaune, Cyan |
| Fond | Aucun, Semi-transparent (70 %), Noir |

- **Libellé d'une piste** : titre et langue lus dans le fichier (`Français 5.1 · FRE`), sinon « Piste N ».
- **Audiodescription** : détectée dans le titre de la piste (`audiodescription`, `audio description`, `descriptive`, `AD`) et écrite en toutes lettres dans le libellé (`Français · FRE · Audiodescription`).
- **Style** (`SubtitleStyle`, `subtitle_style.dart`) : taille de base 44 px, multipliée par la taille choisie puis par la taille de texte globale de l'app. Sans fond, un contour noir garde le texte lisible. Les trois couleurs dépassent 4,5:1 sur noir.
- **Aperçu** : une ligne d'exemple sur fond gris montre le rendu avant de refermer le panneau.
- **Accessibilité** : chaque choix est annoncé « Sous-titres : Désactivés, sélectionné » ; l'état coché est porté par l'icône et le texte, pas par la couleur.

L'écran reçoit le style initial (`subtitleStyle`) et signale chaque changement (`onSubtitleStyleChanged`). L'enregistrement dans les préférences du profil (`user.preferences.subtitles`) attend la route correspondante du cœur.

## Lecture pilotée par le cœur

La TV ne choisit jamais seule ce qu'elle lit ([ADR 0002](../adr/0002-lecture-pilotee-par-le-coeur.md)). `PlaybackHost` (`apps/tv/lib/player/server_player.dart`), placé au-dessus du navigateur de l'app, écoute le WebSocket du cœur (`GET /api/ws`) quel que soit l'écran affiché.

| Commande `player.command` | Effet sur la TV |
|---|---|
| `load` | ouvre le lecteur sur `now_playing.uri` (chemin du fichier sur la machine du cœur) à partir de `start_s` ; un lecteur déjà ouvert est remplacé, pas empilé |
| `play`, `pause`, `toggle` | lecture, pause, bascule |
| `seek`, `seek_relative` | va à `position_s`, ou avance / recule de `delta_s` |
| `volume` | niveau de 0 à 100, `muted` coupe le son |
| `audio_track`, `subtitle_track` | choisit la piste par son identifiant (`null` : sous-titres désactivés) |
| `subtitle_delay` | décale les sous-titres de `delay_ms` |
| `stop` | ferme le lecteur |

Sans lecteur ouvert, les commandes autres que `load` sont ignorées.

### État publié

`PlayerReporter` publie l'état réel avec `POST /api/player/state` (`status`, `position_s`, `duration_s`, pistes) :

- à chaque changement de statut (`loading`, `playing`, `paused`, `ended`, `error`) ou de piste, une seule fois chacun : un `ended` envoyé deux fois ferait sauter un média ;
- toutes les 5 s pendant la lecture, pour la position ;
- `stopped` avec la position quand l'utilisateur quitte par Retour (le cœur enregistre la reprise) ;
- rien quand le cœur remplace le média ou demande l'arrêt : il est déjà au courant.

### Depuis la médiathèque

- **OK sur une affiche** ouvre sa fiche ; **Lecture** envoie `POST /api/player/play` (`media_id`, `resume: true`). Le cœur répond, puis envoie `load` : le lecteur s'ouvre par-dessus la fiche.
- **Retour** ferme le lecteur, libère le moteur et rend le focus à « Lecture » dans la fiche.
- **Séries, albums** : le cœur lit toutes leurs feuilles (une série reprend au premier épisode non vu). Rien à lire : le message du cœur s'affiche dans la fiche.
- **Média indisponible** (`status: "missing"`) : la carte l'annonce (« Elephants Dream, Indisponible ») et « Lecture » est désactivé dans la fiche.
- Un moteur neuf est créé à chaque `load` (`engineFactory`, media_kit par défaut). Le style des sous-titres choisi est gardé pendant la session.

### Tests

- `apps/tv/test/playback_host_test.dart` : chaque commande, remplacement du lecteur, états publiés (une fois chacun, toutes les 5 s, `stopped` au Retour), forme du rapport comparée à `fixtures/player/state_request.json`.
- `apps/tv/test/library_playback_test.dart` : parcours fiche → Lecture → lecteur → Retour, refus du cœur, média indisponible.

## Reprise de lecture

Le cœur calcule la position de reprise du profil et l'envoie dans `load` (`start_s`) ; `MediaKitEngine` attend que la durée du fichier soit connue, va à cette position, puis lance la lecture. Le cœur enregistre la position à partir des états publiés (toutes les 10 s, et à la pause, à l'arrêt et à la fin). Reste à afficher « Reprendre / Recommencer » dans la fiche (#24).
