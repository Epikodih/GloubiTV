import 'package:design_system/design_system.dart';
import 'package:epikodi_client/epikodi_client.dart' show ApiException;
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../l10n/app_localizations.dart';
import 'library_section.dart';
import 'media_card.dart';
import 'session_lists.dart';

/// Ouvre la fiche d'un média par-dessus la médiathèque.
///
/// Elle s'affiche tout de suite avec ce que la liste connaît déjà ([item]),
/// puis complète avec `GET /api/media/{id}` (résumé, favoris, « À regarder »).
/// Renvoie vrai si les favoris ou « À regarder » ont changé (la liste
/// affichée doit alors être rechargée).
/// [guestLists] : pour un invité, ses listes sont gardées par la TV le temps
/// de la session (rien n'est envoyé au serveur).
Future<bool> showMediaDetails(
  BuildContext context, {
  required Api api,
  required Map<String, dynamic> item,
  SessionLists? guestLists,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final reduced = MediaQuery.disableAnimationsOf(context);
  final changed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.close,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration:
        reduced ? Duration.zero : const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => MediaDetailsDialog(
      api: api,
      item: item,
      guestLists: guestLists,
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return changed ?? false;
}

/// Contenu de la fiche : affiche, titre, infos (année, type, durée,
/// classification, genres), résumé, puis les actions : Lecture, Favoris,
/// « À regarder ».
class MediaDetailsDialog extends StatefulWidget {
  const MediaDetailsDialog({
    super.key,
    required this.api,
    required this.item,
    this.guestLists,
  });

  final Api api;
  final Map<String, dynamic> item;

  /// Invité : listes de la session, gardées par la TV.
  final SessionLists? guestLists;

  @override
  State<MediaDetailsDialog> createState() => _MediaDetailsDialogState();
}

class _MediaDetailsDialogState extends State<MediaDetailsDialog> {
  late Map<String, dynamic> _media = {
    ...widget.item,
    if (widget.guestLists case final g?) ...{
      'in_favorites': g.contains('favorite', widget.item['id']),
      'in_watchlist': g.contains('watchlist', widget.item['id']),
    },
  };

  /// Fiche complète reçue (sinon : on ne connaît pas encore les listes).
  bool _loaded = false;
  bool _changed = false;

  /// Un ajout / retrait en cours (boutons désactivés pendant l'envoi).
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.fetchMediaDetail(widget.item['id']);
      if (!mounted) return;
      setState(() {
        _media = {
          ..._media,
          ...detail,
          // Invité : le serveur ne connaît pas ses listes, la TV si.
          if (widget.guestLists != null) ...{
            'in_favorites': _media['in_favorites'],
            'in_watchlist': _media['in_watchlist'],
          },
        };
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _message = AppLocalizations.of(context)!.mediaDetailsLoadError);
    }
  }

  bool get _inFavorites => _media['in_favorites'] == true;
  bool get _inWatchlist => _media['in_watchlist'] == true;

  Future<void> _toggle(String list, String field) async {
    if (_busy) return;
    final add = _media[field] != true;
    final guest = widget.guestLists;
    if (guest != null) {
      // Invité : gardé par la TV pour la session, rien n'est envoyé.
      guest.set(list, widget.item, add);
      _changed = true;
      setState(() {
        _message = null;
        _media = {..._media, field: add};
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _media = {..._media, field: add}; // tout de suite à l'écran
    });
    try {
      await widget.api.setInList(widget.item['id'], list, add);
      _changed = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _media = {..._media, field: !add}; // on remet comme avant
        _message = e is ApiException
            ? e.message
            : AppLocalizations.of(context)!.listUpdateError;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _play() {
    // À brancher : lecture (et reprise) du média.
    setState(() => _message = AppLocalizations.of(context)!.playSoon);
  }

  void _close() => Navigator.of(context).pop(_changed);

  /// Taille de l'affiche dans la fiche : son format (2:3 pour un film ou une
  /// série, carré pour la musique et les podcasts), réduit si l'écran est
  /// bas. C'est elle qui donne la hauteur de la fiche : pas de vide sous une
  /// pochette carrée.
  Size _posterSize(
      BuildContext context, MediaFamily? family, double maxHeight) {
    final square = family == MediaFamily.music || family == MediaFamily.podcast;
    final base = posterSize(context, family) * (square ? 1.8 : 1.6);
    final factor = base.height > maxHeight ? maxHeight / base.height : 1.0;
    return base * factor;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final m = _media;
    final family = MediaFamily.of(m['kind']);
    final missing = m['status'] == 'missing';
    final overview = m['overview'] as String?;
    final genres = [for (final g in (m['genres'] as List? ?? const [])) '$g'];

    // Marges autour de la fiche, puis à l'intérieur (+ bordure).
    const outer = AppSpacing.lg;
    const inner = AppSpacing.lg;
    final width = (size.width - 2 * outer).clamp(0.0, scaler.scale(1440));
    final poster =
        _posterSize(context, family, size.height - 2 * outer - 2 * inner - 4);

    final facts = <Widget>[
      if (family != null) _Fact(icon: family.icon, text: family.label(l10n)),
      if (m['year'] != null)
        _Fact(icon: Icons.calendar_today_rounded, text: '${m['year']}'),
      if (m['duration_s'] is int)
        _Fact(
            icon: Icons.schedule_rounded,
            text: formatDuration(l10n, m['duration_s'] as int)),
      _AgeBadge(rating: m['age_rating'] as int?),
    ];

    // Titre + croix de fermeture, infos, genres, résumé : défile si besoin.
    final details = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${m['title']}',
                    style: AppText.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              FocusableCard(
                key: const ValueKey('details-close'),
                borderRadius: 999,
                onTap: _close,
                semanticLabel: l10n.close,
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.close_rounded,
                    size: scaler.scale(32), color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: facts,
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final g in genres) _GenreChip(text: g)],
            ),
          ],
          if (missing) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: scaler.scale(28)),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(l10n.fileMissing,
                    style: AppText.label.copyWith(color: AppColors.error)),
              ),
            ]),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!_loaded && _message == null)
            const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else
            Text(
              overview?.isNotEmpty == true ? overview! : l10n.noOverview,
              key: const ValueKey('details-overview'),
              style: AppText.label.copyWith(
                  color: overview?.isNotEmpty == true
                      ? AppColors.text
                      : AppColors.textMuted,
                  height: 1.4),
            ),
        ],
      ),
    );

    // Barre d'actions, toujours visible en bas (hors de la partie qui
    // défile) : Lecture, « + » (À regarder), cœur (favoris), puis le message.
    final actions = Row(
      children: [
        _ActionButton(
          key: const ValueKey('details-play'),
          icon: Icons.play_arrow_rounded,
          text: l10n.play,
          primary: true,
          autofocus: true,
          enabled: !missing,
          onTap: _play,
        ),
        const SizedBox(width: AppSpacing.sm),
        _IconToggle(
          key: const ValueKey('details-watchlist'),
          icon: _inWatchlist ? Icons.check_rounded : Icons.add_rounded,
          label: _inWatchlist ? l10n.inWatchlist : l10n.addWatchlist,
          selected: _inWatchlist,
          enabled: !_busy,
          onTap: () => _toggle('watchlist', 'in_watchlist'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _IconToggle(
          key: const ValueKey('details-favorite'),
          icon: _inFavorites
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: _inFavorites ? l10n.inFavorites : l10n.addFavorite,
          selected: _inFavorites,
          selectedColor: const Color(0xFFFF5C7A),
          enabled: !_busy,
          onTap: () => _toggle('favorite', 'in_favorites'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _message == null
              ? const SizedBox.shrink()
              : Text(_message!,
                  key: const ValueKey('details-message'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.textMuted)),
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(); // Retour : ferme en gardant le résultat
      },
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            key: const ValueKey('media-details'),
            width: width,
            padding: const EdgeInsets.all(inner),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.surfaceHigh, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 48),
              ],
            ),
            child: FocusScope(
              // La hauteur de la fiche = celle de l'affiche.
              child: SizedBox(
                height: poster.height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MediaPoster(
                      key: const ValueKey('details-poster'),
                      item: m,
                      baseUrl: widget.api.baseUrl,
                      size: poster,
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(height: AppSpacing.sm),
                          actions,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hauteur commune des boutons de la fiche (Lecture, « + », cœur) :
/// cohérence visuelle, les ronds ont le diamètre de la pilule.
double actionHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(64);

/// « 1 h 40 min », « 14 min ».
String formatDuration(AppLocalizations l10n, int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return l10n.durationMinutes(minutes);
  return l10n.durationHours(minutes ~/ 60, minutes % 60);
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: MediaQuery.textScalerOf(context).scale(26),
            color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppText.label),
      ],
    );
  }
}

/// Classification : « Tous publics », « 12+ » ou « Non classé ».
class _AgeBadge extends StatelessWidget {
  const _AgeBadge({required this.rating});

  final int? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final r = rating;
    final text = r == null
        ? l10n.notRated
        : r == 0
            ? l10n.allAges
            : l10n.ageRating(r);
    final color = r == null
        ? AppColors.textMuted
        : r >= 16
            ? AppColors.error
            : r >= 10
                ? const Color(0xFFFFC857)
                : const Color(0xFF6BD68A);
    return Container(
      key: const ValueKey('details-age'),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(text,
          style: AppText.label
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs / 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.text)),
    );
  }
}

/// Bouton d'action de la fiche, avec texte. [primary] : plein (Lecture).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fill = primary ? AppColors.primary : AppColors.surfaceHigh;
    // Même hauteur que les boutons ronds (bordure de focus comprise).
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        height: actionHeight(context),
        child: FocusableCard(
          autofocus: autofocus,
          borderRadius: 999,
          onTap: enabled ? onTap : null,
          semanticLabel: text,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: scaler.scale(32),
                    color: primary ? AppColors.onPrimary : AppColors.text),
                const SizedBox(width: AppSpacing.xs),
                Text(text,
                    style: AppText.label.copyWith(
                        color: primary ? AppColors.onPrimary : AppColors.text,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond avec une seule icône (« + » pour « À regarder », cœur pour
/// les favoris). Le libellé est lu par le lecteur d'écran et affiché en
/// bulle quand le bouton a le focus.
class _IconToggle extends StatefulWidget {
  const _IconToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.selectedColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  State<_IconToggle> createState() => _IconToggleState();
}

class _IconToggleState extends State<_IconToggle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final size = actionHeight(context);
    final color = widget.selected ? widget.selectedColor : AppColors.text;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Tooltip(
          message: widget.label,
          child: SizedBox(
            width: size,
            height: size,
            child: FocusableCard(
              borderRadius: 999,
              onTap: widget.enabled ? widget.onTap : null,
              semanticLabel: widget.label,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.fast,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? widget.selectedColor.withValues(alpha: 0.2)
                      : AppColors.surfaceHigh,
                  border: Border.all(
                    color: widget.selected || _focused
                        ? color
                        : AppColors.textMuted.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: size * 0.5, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
