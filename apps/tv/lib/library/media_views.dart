import 'package:design_system/design_system.dart';
import 'package:epikodi_client/epikodi_client.dart' show ApiException;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'library_section.dart';
import 'media_card.dart';

typedef MediaList = List<Map<String, dynamic>>;

/// Ouvre la fiche d'un média (OK sur une affiche).
typedef MediaOpener = void Function(Map<String, dynamic> item);

/// Charge une liste de médias et gère les états : chargement, erreur (avec
/// « Réessayer »), liste vide. [builder] affiche la liste reçue.
///
/// La liste est rechargée quand [request] change (filtres de la recherche…).
/// Pendant un rechargement, l'ancienne liste reste affichée : pas de
/// clignotement à chaque lettre tapée.
class MediaLoader extends StatefulWidget {
  const MediaLoader({
    super.key,
    required this.request,
    required this.load,
    required this.emptyText,
    required this.builder,
    this.emptyIcon = Icons.video_library_outlined,
  });

  /// Identifie la requête : une valeur différente relance [load].
  final Object request;
  final Future<MediaList> Function() load;
  final String emptyText;
  final IconData emptyIcon;
  final Widget Function(BuildContext context, MediaList items) builder;

  @override
  State<MediaLoader> createState() => _MediaLoaderState();
}

class _MediaLoaderState extends State<MediaLoader> {
  late Future<MediaList> _future = widget.load();

  @override
  void didUpdateWidget(MediaLoader old) {
    super.didUpdateWidget(old);
    if (old.request != widget.request) _future = widget.load();
  }

  // Accolades obligatoires : `setState(() => _future = ...)` renverrait un
  // Future, ce que setState refuse.
  void _reload() => setState(() {
        _future = widget.load();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<MediaList>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        if (loading && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!loading && snap.hasError) {
          final message = snap.error is ApiException
              ? (snap.error as ApiException).message
              : l10n.libraryLoadError;
          return LibraryMessage(
            worried: true,
            text: message,
            actionText: l10n.retry,
            onAction: _reload,
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return LibraryMessage(icon: widget.emptyIcon, text: widget.emptyText);
        }
        return widget.builder(context, items);
      },
    );
  }
}

/// Toutes les affiches d'une liste, en grille. Tout est construit d'un coup
/// (pas de liste paresseuse) : les flèches trouvent toujours l'affiche
/// suivante, même hors de l'écran.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.baseUrl,
    this.showKind = false,
    this.scrollable = true,
    this.onOpen,
  });

  final MediaList items;
  final String baseUrl;
  final bool showKind;

  /// Faux : la grille est déjà dans une page qui défile (recherche).
  final bool scrollable;

  final MediaOpener? onOpen;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(AppSpacing.sm);
    final grid = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          MediaCard(
            key: ValueKey('media-${item['id']}'),
            item: item,
            baseUrl: baseUrl,
            showKind: showKind,
            onOpen: onOpen == null ? null : () => onOpen!(item),
          ),
      ],
    );
    return scrollable
        ? SingleChildScrollView(padding: padding, child: grid)
        : Padding(padding: padding, child: grid);
  }
}

/// Accueil : une rangée d'affiches par type (films, séries, musique,
/// podcasts), qui défile horizontalement.
class MediaRows extends StatelessWidget {
  const MediaRows({
    super.key,
    required this.items,
    required this.baseUrl,
    this.autofocusFirst = false,
    this.onOpen,
  });

  final MediaList items;
  final String baseUrl;
  final MediaOpener? onOpen;

  /// Donne le focus à la première affiche de la première rangée.
  final bool autofocusFirst;

  /// Ordre et titres des rangées, selon le champ `kind` du média.
  static Map<String, String> sections(AppLocalizations l10n) => {
        'movie': l10n.sectionMovies,
        'series': l10n.sectionSeries,
        'artist': l10n.sectionMusic,
        'podcast': l10n.sectionPodcasts,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = [
      for (final entry in sections(l10n).entries)
        if (items.any((m) => m['kind'] == entry.key))
          (entry.value, items.where((m) => m['kind'] == entry.key).toList()),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (title, list)) in rows.indexed)
            _MediaRow(
              title: title,
              items: list,
              baseUrl: baseUrl,
              autofocusFirst: autofocusFirst && i == 0,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.title,
    required this.items,
    required this.baseUrl,
    required this.autofocusFirst,
    required this.onOpen,
  });

  final String title;
  final MediaList items;
  final String baseUrl;
  final bool autofocusFirst;
  final MediaOpener? onOpen;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Une rangée = un seul type : toutes ses affiches ont le même format.
    final posterHeight =
        posterSize(context, MediaFamily.of(items.first['kind'])).height;
    final labelHeight = scaler
        .scale((AppText.label.fontSize ?? 20) * (AppText.label.height ?? 1.4));
    // Affiche + marges de la carte + libellé + marge pour le halo de focus.
    final rowHeight = posterHeight +
        2 * AppSpacing.sm +
        AppSpacing.sm +
        labelHeight +
        2 * AppSpacing.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(title, style: AppText.title),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => MediaCard(
              key: ValueKey('media-${items[i]['id']}'),
              item: items[i],
              baseUrl: baseUrl,
              autofocus: autofocusFirst && i == 0,
              onOpen: onOpen == null ? null : () => onOpen!(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}
