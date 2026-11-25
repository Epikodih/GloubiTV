import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'library_section.dart';

/// Une affiche de média, sélectionnable à la télécommande.
///
/// [showKind] : petite icône du type (film, série, musique, podcast) en haut
/// à gauche de l'affiche, pour les listes qui mélangent les types (favoris,
/// « À regarder », recherche).
/// Un média `missing` (fichier disparu) est affiché grisé.
/// Format de l'affiche selon le type : voir [posterSize].
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.baseUrl,
    this.autofocus = false,
    this.showKind = false,
    this.onOpen,
  });

  final Map<String, dynamic> item;
  final String baseUrl;
  final bool autofocus;
  final bool showKind;

  /// OK sur l'affiche : ouvre la fiche.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = '${item['title']}';
    final family = MediaFamily.of(item['kind']);
    final missing = item['status'] == 'missing';
    final size = posterSize(context, family);
    final width = size.width;
    final height = size.height;

    var label = showKind && family != null
        ? l10n.mediaWithKind(title, family.label(l10n))
        : title;
    if (missing) label = '$label, ${l10n.unavailable}';

    Widget poster = MediaPoster(
      item: item,
      baseUrl: baseUrl,
      size: Size(width, height),
    );
    if (showKind && family != null) {
      poster = Stack(
        children: [
          poster,
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xs,
            child: KindBadge(family: family, size: width * 0.24),
          ),
        ],
      );
    }

    return FocusableCard(
      autofocus: autofocus,
      // OK : ouvre la fiche du média (popup).
      onTap: onOpen ?? () {},
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: label,
      // Si la place manque, la carte se réduit au lieu de déborder.
      child: Opacity(
        opacity: missing ? 0.4 : 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              poster,
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: width,
                child: Text(
                  title,
                  style: AppText.label.copyWith(color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'affiche seule (image du serveur, sinon l'icône du type), arrondie.
class MediaPoster extends StatelessWidget {
  const MediaPoster({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.size,
  });

  final Map<String, dynamic> item;
  final String baseUrl;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final posterUrl = item['poster_url'] as String?;
    final family = MediaFamily.of(item['kind']);
    final placeholder = Container(
      width: size.width,
      height: size.height,
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(family?.icon ?? Icons.movie_outlined,
          size: size.shortestSide * 0.4, color: AppColors.textMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg / 2),
      child: posterUrl == null
          ? placeholder
          : Image.network(
              '$baseUrl$posterUrl',
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// Pastille ronde avec l'icône du type de média, lisible sur toute affiche.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.family, required this.size});

  final MediaFamily family;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('kind-${family.name}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.5)),
      ),
      child: Icon(family.icon, size: size * 0.6, color: AppColors.text),
    );
  }
}

/// Taille d'une affiche (suit la taille du texte choisie) :
/// - films et séries : affiche verticale 2:3 ;
/// - musique et podcasts : carrée, comme une pochette d'album.
Size posterSize(BuildContext context, MediaFamily? family) {
  final scaler = MediaQuery.textScalerOf(context);
  return switch (family) {
    MediaFamily.music || MediaFamily.podcast => Size.square(scaler.scale(220)),
    _ => Size(scaler.scale(200), scaler.scale(300)),
  };
}

/// Message centré (chargement impossible, liste vide), avec un bouton
/// optionnel.
class LibraryMessage extends StatelessWidget {
  const LibraryMessage({
    super.key,
    this.icon,
    this.worried = false,
    required this.text,
    this.actionText,
    this.onAction,
  });

  /// Icône au-dessus du texte (si [worried] est faux).
  final IconData? icon;

  /// Erreur : Gloubi inquiet à la place de l'icône.
  final bool worried;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (worried)
            Gloubi(
              animation: GloubiAnimation.worried,
              size: scaler.scale(160),
            )
          else if (icon != null)
            Icon(icon, size: scaler.scale(56), color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: AppText.title, textAlign: TextAlign.center),
          if (actionText != null) ...[
            const SizedBox(height: AppSpacing.md),
            FocusableCard(
              autofocus: true,
              borderRadius: 999,
              onTap: onAction ?? () {},
              semanticLabel: actionText!,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(actionText!,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
