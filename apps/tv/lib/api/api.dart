import 'package:epikodi_client/epikodi_client.dart';

import '../player/playback_state.dart';

/// Routes de comptes / session / médiathèque, utilisées par la TV uniquement.
///
/// Ce fichier vit dans l'app TV. Il ne refait aucun HTTP : tout passe par
/// l'[ApiClient] du package partagé `epikodi_client`, qui gère le JSON,
/// le token Bearer, le timeout et lève des [ApiException] typées
/// (status, code, message).
///
///     final client = EpikodiClient(baseUrl: '...');   // shared
///     final api = Api(client.http);                    // TV
///
/// Le token de la TV (reçu à /api/tv/connect) est celui de l'[ApiClient] :
/// il est envoyé automatiquement à chaque requête.
///
/// Routes :
/// - POST  /api/session/profile -> choisir un compte (PIN) ou l'invité
/// - POST  /api/profiles        -> créer un compte (devient actif)
/// - PATCH /api/profiles/{id}   -> modifier un compte (PIN si restriction d'âge)
/// - GET   /api/media           -> médias du compte actif (catégorie,
///                                  favoris, « À regarder », recherche)
/// - GET   /api/media/{id}/stream -> fichier à lire (via [streamSource])
class Api {
  const Api(this._client);

  final ApiClient _client;

  /// Adresse du serveur sans « / » final : sert à construire l'URL des
  /// affiches (`'$baseUrl$poster_url'`).
  String get baseUrl =>
      _client.baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');

  // ---------------------------------------------------------------- comptes

  /// Choisit un compte existant (avec son [pin] si besoin) ou l'invité.
  /// Renvoie le compte actif. Lève [ApiException] (ex. mauvais PIN).
  Future<Map<String, dynamic>> selectProfile({
    Object? profileId,
    String? pin,
    bool guest = false,
  }) async {
    final json = await _client.post(
      '/api/session/profile',
      body: guest
          ? {'type': 'guest'}
          : {
              'type': 'account',
              'profile_id': profileId,
              if (pin != null) 'pin': pin,
            },
    );
    return _activeProfile(json);
  }

  /// Crée un compte. Le serveur le rend actif tout de suite.
  Future<Map<String, dynamic>> createProfile({
    required String name,
    required String icon,
    required String language,
    required int age,
    required bool isRestricted,
  }) async {
    final json = await _client.post('/api/profiles', body: {
      'name': name,
      'icon': icon,
      'language': language,
      'age': age,
      'is_restricted': isRestricted,
    });
    return _activeProfile(json);
  }

  /// Modifie un compte et renvoie le compte à jour.
  /// [icon] : `avatar_0X` (couleur prédéfinie) ou `file:<chemin>` (photo).
  /// [pin] : requis quand on touche à la restriction d'âge. Le serveur doit
  /// le vérifier et répondre avec le code `pin_invalid` s'il est faux
  /// (lève alors une [ApiException]).
  Future<Map<String, dynamic>> updateProfile(
    Object id, {
    required String name,
    required String icon,
    required int age,
    required bool isRestricted,
    required String language,
    String? pin,
  }) async {
    final json = await _client.patch('/api/profiles/$id', body: {
      'name': name,
      'icon': icon,
      'age': age,
      'is_restricted': isRestricted,
      'language': language,
      if (pin != null) 'pin': pin,
    });
    return _activeProfile(json);
  }

  // ------------------------------------------------------------ médiathèque

  /// Médias du compte actif (le serveur filtre déjà selon l'âge).
  /// Le serveur répond { "items": [ ... ], "total", "limit", "offset" }
  /// (voir fixtures/media/list.json et ses règles dans fixtures/README.md).
  ///
  /// Filtres facultatifs, qui se combinent :
  /// - [kind] : `movie`, `series`, `artist`, `podcast`… ;
  /// - [list] : `favorites` ou `watchlist` (listes du profil) ;
  /// - [query] : recherche dans tout le media center (titre) ;
  /// - [genre] : un genre exact (`genres` du média) ;
  /// - [maxAge] : classification maximale (`age_rating` ≤ [maxAge]).
  Future<List<Map<String, dynamic>>> fetchMedia({
    String? kind,
    String? list,
    String? query,
    String? genre,
    int? maxAge,
  }) async {
    final q = query?.trim() ?? '';
    final json = await _client.get('/api/media', query: {
      if (kind != null) 'kind': kind,
      if (list != null) 'list': list,
      if (q.isNotEmpty) 'q': q,
      if (genre != null) 'genre': genre,
      if (maxAge != null) 'max_age': maxAge,
    });
    final items = json['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Fiche d'un média : champs de la liste, plus `overview`,
  /// `in_favorites` et `in_watchlist` (voir fixtures/media/get_response.json).
  Future<Map<String, dynamic>> fetchMediaDetail(Object id) =>
      _client.get('/api/media/$id');

  /// Ajoute ([add]) ou retire un média d'une liste du profil :
  /// [list] vaut `favorite` ou `watchlist`.
  /// PUT / DELETE /api/media/{id}/{list}, réponse 204.
  Future<void> setInList(Object id, String list, bool add) async {
    assert(list == 'favorite' || list == 'watchlist');
    final path = '/api/media/$id/$list';
    if (add) {
      await _client.put(path);
    } else {
      await _client.delete(path);
    }
  }

  // ------------------------------------------------- dossiers (paramètres)

  /// Dossiers que le media center scanne (voir fixtures/sources/list.json).
  Future<List<Map<String, dynamic>>> fetchSources() async {
    final json = await _client.get('/api/sources');
    final list = json['sources'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Ajoute un dossier ([uri] : `file:///…` ou `smb://…`). Le serveur lance
  /// un premier scan et renvoie le dossier créé.
  Future<Map<String, dynamic>> addSource(String uri, {String? name}) =>
      _client.post('/api/sources', body: {
        if (name != null) 'name': name,
        'uri': uri,
      });

  /// Retire un dossier (ses médias quittent la médiathèque).
  Future<void> removeSource(Object id) => _client.delete('/api/sources/$id');

  /// Relance le scan (en arrière-plan côté serveur) : seulement les dossiers
  /// [uris], ou **tous** les dossiers si [uris] est null ou vide (pas de corps).
  /// POST /api/sources/scan ; renvoie les dossiers dont le scan démarre.
  Future<List<Map<String, dynamic>>> scanSources({List<String>? uris}) async {
    final json = await _client.post('/api/sources/scan',
        body: (uris == null || uris.isEmpty) ? null : {'uris': uris});
    final list = json['scanning'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ---------------------------------------------------------------- lecture

  /// Source de lecture d'un média (film, épisode, morceau…).
  ///
  /// Le moteur lit `GET /api/media/{id}/stream` lui-même (requêtes `Range`
  /// pour l'avance rapide) : on lui donne l'URL et le token à mettre dans
  /// l'en-tête `Authorization`, jamais dans l'URL.
  PlaybackSource streamSource(Map<String, dynamic> media) {
    final token = _client.token;
    return PlaybackSource(
      uri: '$baseUrl/api/media/${media['id']}/stream',
      title: '${media['title'] ?? ''}',
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  // ----------------------------------------------------------------- interne

  /// Réponse { "profile": {...}, "token": "..." } ou le compte directement.
  /// Si le serveur renvoie un nouveau token, on le garde pour la suite.
  Map<String, dynamic> _activeProfile(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is String) _client.token = token;
    final profile = json['profile'];
    return profile is Map<String, dynamic> ? profile : json;
  }
}
