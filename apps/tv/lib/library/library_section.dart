import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Entrées du menu de gauche de la médiathèque, dans l'ordre d'affichage.
/// Chacune correspond à un appel de `GET /api/media` (voir [kind] et [list]).
enum LibrarySection {
  search,
  home,
  watchlist,
  favorites,
  movies,
  series,
  music,
  podcasts;

  /// Valeur du paramètre `kind` (catégories).
  String? get kind => switch (this) {
        movies => 'movie',
        series => 'series',
        music => 'artist',
        podcasts => 'podcast',
        _ => null,
      };

  /// Valeur du paramètre `list` (listes du profil).
  String? get list => switch (this) {
        watchlist => 'watchlist',
        favorites => 'favorites',
        _ => null,
      };

  /// Listes qui mélangent les types : chaque affiche porte l'icône du sien.
  bool get mixesKinds => this == watchlist || this == favorites;

  /// Catégories (films, séries…), séparées des listes par un trait.
  bool get isCategory => kind != null;

  IconData get icon => switch (this) {
        search => Icons.search_rounded,
        home => Icons.home_rounded,
        watchlist => Icons.bookmark_rounded,
        favorites => Icons.favorite_rounded,
        movies => Icons.movie_rounded,
        series => Icons.tv_rounded,
        music => Icons.music_note_rounded,
        podcasts => Icons.podcasts_rounded,
      };

  String label(AppLocalizations l10n) => switch (this) {
        search => l10n.navSearch,
        home => l10n.navHome,
        watchlist => l10n.navWatchlist,
        favorites => l10n.navFavorites,
        movies => l10n.sectionMovies,
        series => l10n.sectionSeries,
        music => l10n.sectionMusic,
        podcasts => l10n.sectionPodcasts,
      };

  /// Message quand la liste est vide.
  String emptyText(AppLocalizations l10n) => switch (this) {
        watchlist => l10n.emptyWatchlist,
        favorites => l10n.emptyFavorites,
        search => l10n.noResults,
        home => l10n.noMediaForProfile,
        _ => l10n.emptyCategory,
      };
}

/// Grandes familles de médias, pour l'icône posée sur l'affiche.
/// Les niveaux du dessous (saison, épisode, album, morceau…) prennent
/// l'icône de leur famille.
enum MediaFamily {
  movie,
  series,
  music,
  podcast;

  static MediaFamily? of(Object? kind) => switch (kind) {
        'movie' => movie,
        'series' || 'season' || 'episode' => series,
        'artist' || 'album' || 'track' => music,
        'podcast' || 'podcast_episode' => podcast,
        _ => null,
      };

  IconData get icon => switch (this) {
        movie => Icons.movie_rounded,
        series => Icons.tv_rounded,
        music => Icons.music_note_rounded,
        podcast => Icons.podcasts_rounded,
      };

  String label(AppLocalizations l10n) => switch (this) {
        movie => l10n.kindMovie,
        series => l10n.kindSeries,
        music => l10n.kindMusic,
        podcast => l10n.kindPodcast,
      };

  /// Valeur du paramètre `kind` pour filtrer la recherche : toute la
  /// famille, pour trouver aussi un épisode ou un morceau.
  String get kinds => switch (this) {
        movie => 'movie',
        series => 'series,season,episode',
        music => 'artist,album,track',
        podcast => 'podcast,podcast_episode',
      };
}
