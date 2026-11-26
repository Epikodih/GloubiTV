import 'package:epikodi_client/epikodi_client.dart';
import 'package:flutter/foundation.dart';

/// Touches de la télécommande.
enum TvKey { up, down, left, right, ok, back, home }

/// Raccourcis du menu : ouvrent directement un écran de la TV, sans passer
/// par les flèches. [id] : valeur envoyée au serveur.
enum TvShortcut {
  /// Page du profil.
  profile('profile'),

  /// « Qui regarde ? » sur la TV : le compte se choisit sur la TV.
  switchProfile('switch_profile');

  const TvShortcut(this.id);
  final String id;
}

/// Envoi des commandes à la TV.
///
/// Touches : `POST /api/remote/input` (le cœur les relaie à la TV).
/// Désappairage : `DELETE /api/session`. Raccourcis, texte et langue n'ont
/// pas encore de route dans le contrat : routes provisoires du faux serveur
/// (`test_api.py`), ignorées par le vrai backend.
abstract class TvCommands {
  /// Appelé quand le serveur refuse le jeton (`unauthorized`) : la TV a
  /// désappairé ce téléphone, il faut revenir à la connexion.
  VoidCallback? onUnauthorized;

  Future<void> key(TvKey key);
  Future<void> shortcut(TvShortcut shortcut);

  /// Texte tapé pour le champ qui a le focus sur la TV. [done] : validé
  /// (comme Entrée).
  Future<void> text(String value, {bool done = false});

  /// Langue de la TV : `fr` ou `en`.
  Future<void> language(String code);

  /// Désappaire ce téléphone : la TV revient à son écran d'appairage.
  Future<void> unpair();
}

/// Routes du cœur :
///  - `POST /api/remote/input`    `{"key": "up"}` (fixtures/remote/input_request.json)
///  - `DELETE /api/session`       désappaire : la TV revient à son code
///
/// Routes provisoires (faux serveur `test_api.py`, pas encore dans le contrat) :
///  - `POST /api/remote/shortcut` `{"shortcut": "profile"}`
///  - `POST /api/remote/text`     `{"value": "Léa", "done": false}`
///
/// Une touche perdue n'est pas grave : les erreurs (réseau, route absente)
/// sont ignorées, la télécommande reste utilisable. Seul `unauthorized`
/// compte : la TV a désappairé ce téléphone ([onUnauthorized]).
class HttpTvCommands implements TvCommands {
  HttpTvCommands(this._client);

  final EpikodiClient _client;

  @override
  VoidCallback? onUnauthorized;

  @override
  Future<void> key(TvKey key) => _send('/api/remote/input', {'key': key.name});

  @override
  Future<void> shortcut(TvShortcut shortcut) =>
      _send('/api/remote/shortcut', {'shortcut': shortcut.id});

  @override
  Future<void> text(String value, {bool done = false}) =>
      _send('/api/remote/text', {'value': value, 'done': done});

  @override
  Future<void> language(String code) =>
      _send('/api/remote/shortcut', {'shortcut': 'language', 'language': code});

  @override
  Future<void> unpair() async {
    try {
      await _client.http.delete('/api/session');
    } on ApiException catch (e) {
      // Déjà désappairé ou serveur injoignable : le téléphone oublie la TV
      // quand même (voir l'écran connecté).
      debugPrint('Télécommande : désappairage refusé ($e)');
    }
  }

  Future<void> _send(String path, Map<String, Object?> body) async {
    try {
      await _client.http.post(path, body: body);
    } on ApiException catch (e) {
      if (e.code == 'unauthorized') {
        onUnauthorized?.call();
        return;
      }
      debugPrint('Télécommande : $path refusé ($e)');
    }
  }
}
