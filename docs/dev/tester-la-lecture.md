# Tester la lecture sur un Mac

Le serveur (cœur Rust) et l'app TV tournent sur la même machine. Le téléphone
n'est utile que pour l'appairage et les commandes : le script
`scripts/telecommande.dart` le remplace. Un Mac seul suffit donc.

## Une fois pour toutes

1. Xcode installé et initialisé (sinon la compilation macOS échoue avec
   « xcodebuild failed to load a required plug-in ») :

   ```bash
   sudo xcodebuild -runFirstLaunch
   ```

2. Rust et Flutter : `just setup` (voir [backend.md](backend.md)).

## Lancer

Trois terminaux, à la racine du dépôt.

1. Le serveur :

   ```bash
   just core
   ```

2. L'app TV (première compilation : quelques minutes) :

   ```bash
   just tv macos
   ```

   La TV affiche un code à 6 chiffres.

3. La télécommande simulée, avec ce code :

   ```bash
   just telecommande appairer 482916
   ```

Sur la TV (clavier : flèches, Entrée, Échap pour Retour) :

1. créer un compte, puis le choisir ;
2. **Paramètres > Dossiers du media center** : ajouter un dossier qui contient
   des vidéos (ou de la musique), par exemple `/Users/<toi>/Movies` ;
3. attendre la fin du scan : les affiches apparaissent dans l'accueil.

Pas de vidéo sous la main ? Un fichier audio d'essai, sans rien télécharger :

```bash
mkdir -p ~/epikodi-essai/Musique && say -o /tmp/essai.aiff "Essai de lecture Epikodi" && afconvert -f m4af -d aac /tmp/essai.aiff ~/epikodi-essai/Musique/essai.m4a
```

## Ce qu'il faut vérifier

### Depuis la TV

| Action | Résultat attendu |
|---|---|
| OK sur une affiche, puis « Lecture » | le lecteur s'ouvre par-dessus la fiche et lit le média |
| Échap (Retour) pendant la lecture | retour sur la fiche, focus sur « Lecture » |
| « Lecture » à nouveau sur le même film | la lecture reprend là où on s'était arrêté |
| « Lecture » sur une série ou un album | le cœur choisit l'épisode / la piste et la lit |
| Média indisponible (fichier supprimé, puis rescan) | « Lecture » désactivé, « Indisponible » annoncé |

### Depuis la télécommande simulée

Pendant qu'un média est lu (`just telecommande aide` liste tout) :

```bash
just telecommande etat
```

```bash
just telecommande pause
```

```bash
just telecommande avancer 30
```

```bash
just telecommande volume 30
```

```bash
just telecommande soustitres non
```

```bash
just telecommande stop
```

| Commande | Résultat attendu sur la TV |
|---|---|
| `medias`, puis `lire <n°>` | le lecteur s'ouvre, quel que soit l'écran affiché |
| `lire <autre n°>` pendant une lecture | le lecteur change de média (un seul lecteur ouvert) |
| `pause`, `reprendre`, `avancer -10`, `aller 60` | l'image suit ; `etat` affiche la bonne position |
| `audio <id>`, `soustitres <id>` (ids donnés par `etat`) | la piste change, visible dans « Audio et sous-titres » |
| `stop` | le lecteur se ferme |
| `etat` pendant la lecture | la position avance (la TV la publie toutes les 5 s) |

## Avec un vrai téléphone

La télécommande (`apps/remote`) n'existe que pour Android pour l'instant ; elle
appaire, et sert de pavé et de clavier, mais n'a pas encore de commandes de
lecture. Téléphone et Mac doivent être sur le même Wi-Fi, port 7878 ouvert.
