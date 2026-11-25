# CI/CD et déroulé d'une contribution

## Le parcours d'une modification

1. Tu crées une branche depuis `dev` (`feature/...`, `fix/...`) et tu pushes.
2. **`auto-pr.yml`** ouvre automatiquement une pull request vers `dev`
   (une seule par branche), avec le modèle `.github/pull_request_template.md`.
   Les code owners (`.github/CODEOWNERS`) sont demandés en relecteurs,
   sauf l'auteur du push.
3. **Une CI par partie du projet** tourne sur le même commit, et ses résultats
   s'affichent sur la PR. Chacune ne lance ses jobs **que si sa partie a
   changé** (voir le tableau ci-dessous) ; sinon ses jobs sont sautés.
4. Chaque nouveau push sur la branche relance la CI. La PR existante se met à jour.
5. Quand la CI est verte **et** qu'un code owner a approuvé, tu merges dans `dev`.
   Le push sur `dev` relance la CI.
6. **`release.yml`** : un tag `v*` construit les paquets (Linux, Windows, macOS,
   APK Android) et publie une release GitHub.

## Les trois CI

| Workflow | Se lance si ça change | Jobs |
|---|---|---|
| `ci-tv.yml` | `apps/tv/`, `packages/` | `tv-lint`, `tv-tests (linux/windows/macos)`, `tv-build (linux/windows/macos)` |
| `ci-remote.yml` | `apps/remote/`, `packages/` | `remote-lint`, `remote-tests`, `remote-build (android)` |
| `ci-rust.yml` | `crates/`, `extensions/`, `Cargo.*`, réglages Rust | `rust-check` (fmt, clippy, tests), `rust-build (linux/windows/macos)` |

- `packages/` (client HTTP, design system) sert à la TV **et** à la
  télécommande : le modifier lance les deux CI Flutter.
- `fixtures/` est le contrat d'API commun : le modifier lance les trois CI.
- Modifier un workflow relance sa propre CI.
- Sur une branche de travail, on compare avec `dev` : tant que la branche
  touche la TV, la CI TV tourne à chaque push (la PR reste vérifiée en entier).
  Sur `dev` et `main`, on compare avec le push précédent.
- Un job a une durée max (`timeout-minutes`) : un blocage échoue vite au lieu
  de tourner jusqu'à 6 h.
- Lancer une CI en entier à la main : onglet *Actions* → le workflow →
  *Run workflow*.

## Version de Flutter : la même en local et en CI

La CI installe Flutter **3.44.6** (`FLUTTER_VERSION` dans `ci-tv.yml`,
`ci-remote.yml` et `release.yml`). En local, la même version est fixée dans
`.fvmrc` et installée par [fvm](https://fvm.app) dans `.fvm/` (ignoré par git) :

```bash
just setup
```

Ensuite `just tv`, `just remote`, `just lint` et `just test*` utilisent ce
Flutter-là (`.fvm/flutter_sdk`), sans toucher au Flutter installé sur la
machine. Avec une autre version, Flutter régénère `pubspec.lock`, les fichiers
de plugins et les projets natifs : ces changements ne doivent pas être commités.

- Dans un éditeur : choisir le SDK `.fvm/flutter_sdk` (VS Code et Android
  Studio le proposent quand `.fvmrc` est présent).
- Une commande hors `just` : `fvm flutter …` au lieu de `flutter …`.
- **Changer de version** : modifier `.fvmrc` **et** `FLUTTER_VERSION` dans les
  trois workflows, puis `just setup`. Les jobs `tv-lint` et `remote-lint`
  échouent si `.fvmrc` et les workflows ne sont pas d'accord.

## Lancer les tests en local

Même commande que la CI, sans connexion réseau. Marche sous Windows
(PowerShell, cmd ou Git Bash), macOS et Linux : `just` lance
`scripts/test.dart`, un script Dart (installé avec Flutter), sans bash requis.

```bash
just test            # tout
just test-tv         # app TV + packages partagés (comme ci-tv)
just test-remote     # télécommande + packages partagés (comme ci-remote)
just test-rust       # backend Rust (comme ci-rust)
just test-flutter    # toutes les apps et packages Flutter
```

Lancer un seul fichier ou un seul test :

```bash
cd apps/tv && flutter test test/pairing_screen_test.dart
cd apps/tv && flutter test --plain-name "Nouveau code"
cargo test -p epikodi-library nom_du_test
```

## Réglages GitHub à faire une fois (admin du dépôt)

Ces réglages ne se mettent pas dans un fichier. Sans eux, les workflows
tournent, mais rien n'empêche de merger une PR rouge.

1. **Settings → Actions → General → Workflow permissions** : cocher
   *Allow GitHub Actions to create and approve pull requests*.
   Le dépôt appartient à l'organisation Epikodih : le même réglage doit aussi
   être autorisé dans les paramètres de l'organisation. Sinon `auto-pr` échoue
   avec « GitHub Actions is not permitted to create or approve pull requests ».
2. **Settings → Collaborators and teams** : `malo-coet` et `loicosternaud`
   doivent avoir l'accès *Write*. Sans ce droit, GitHub ignore la ligne
   CODEOWNERS et ne les demande pas en relecteurs.
3. **Settings → Branches → règle pour `dev`, puis la même pour `main`** :
   - *Require a pull request before merging*
     - *Require approvals* : 1
     - *Require review from Code Owners*
   - *Require status checks to pass before merging*, avec les checks
     `tv-lint`, `tv-tests (linux)`, `tv-tests (windows)`, `tv-tests (macos)`,
     `tv-build (linux)`, `tv-build (windows)`, `tv-build (macos)`,
     `remote-lint`, `remote-tests`, `remote-build (android)`, `rust-check`,
     `rust-build (linux)`, `rust-build (windows)`, `rust-build (macos)`
     (ils apparaissent dans la liste après un premier run de chaque CI).
     Un job sauté, parce que sa partie n'a pas changé, compte comme validé.
   - *Do not allow bypassing the above settings*

## Limites connues

- Une PR créée par `auto-pr` a pour auteur `github-actions`. C'est normal :
  les commits restent ceux de leur auteur.
- Si la PR d'une branche a été fermée sans merge, le push suivant en rouvre une nouvelle.
