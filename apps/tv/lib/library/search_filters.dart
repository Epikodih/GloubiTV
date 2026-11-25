import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../widgets/pill_choice.dart';
import 'library_section.dart';

/// Filtres de la recherche : type, genre et âge maximal (`null` = tous).
@immutable
class SearchFilters {
  const SearchFilters({this.family, this.genre, this.maxAge});

  static const none = SearchFilters();

  /// Âges proposés pour le filtre « Âge » (classifications du schéma).
  static const ages = [10, 12, 16];

  final MediaFamily? family;
  final String? genre;
  final int? maxAge;

  /// Nombre de filtres choisis (pastille du bouton).
  int get count =>
      (family != null ? 1 : 0) +
      (genre != null ? 1 : 0) +
      (maxAge != null ? 1 : 0);

  SearchFilters withFamily(MediaFamily? v) =>
      SearchFilters(family: v, genre: genre, maxAge: maxAge);
  SearchFilters withGenre(String? v) =>
      SearchFilters(family: family, genre: v, maxAge: maxAge);
  SearchFilters withMaxAge(int? v) =>
      SearchFilters(family: family, genre: genre, maxAge: v);

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.family == family &&
      other.genre == genre &&
      other.maxAge == maxAge;

  @override
  int get hashCode => Object.hash(family, genre, maxAge);
}

/// Bouton « Filtres » (icône seule), à droite de la barre de recherche. Il
/// ouvre un menu déroulant aligné sous la barre ([alignTo] : la barre et le
/// bouton) ; chaque choix s'applique tout de suite ([onChanged]). Une
/// pastille montre le nombre de filtres actifs.
class SearchFilterButton extends StatefulWidget {
  const SearchFilterButton({
    super.key,
    required this.filters,
    required this.loadGenres,
    required this.onChanged,
    required this.height,
    this.alignTo,
  });

  final SearchFilters filters;

  /// Genres proposés (ceux du catalogue du profil), lus à l'ouverture.
  final Future<List<String>> Function() loadGenres;
  final ValueChanged<SearchFilters> onChanged;

  /// Même hauteur que la barre de recherche.
  final double height;

  /// Zone sous laquelle le menu s'aligne (barre de recherche + bouton).
  /// Sans elle : sous le bouton.
  final GlobalKey? alignTo;

  @override
  State<SearchFilterButton> createState() => _SearchFilterButtonState();
}

class _SearchFilterButtonState extends State<SearchFilterButton> {
  final _anchorKey = GlobalKey();

  Future<void> _open() async {
    final l10n = AppLocalizations.of(context)!;
    final box = (widget.alignTo ?? _anchorKey)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Même bord gauche et même largeur que la barre, juste en dessous.
    final area = box.localToGlobal(Offset.zero) & box.size;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final genres = await widget.loadGenres();
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.closeMenu,
      barrierColor: Colors.black45,
      transitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _FilterPanel(
        area: area,
        initial: widget.filters,
        genres: genres,
        onChanged: widget.onChanged,
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.03), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);
    final count = widget.filters.count;
    final size = widget.height;
    return Tooltip(
      message: l10n.filters,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: FocusableCard(
                key: _anchorKey,
                borderRadius: 999,
                onTap: _open,
                semanticLabel:
                    count == 0 ? l10n.filters : l10n.filtersActive(count),
                child: Center(
                  child: Icon(Icons.tune_rounded,
                      size: scaler.scale(30), color: AppColors.text),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('filters-count'),
                    constraints: BoxConstraints(
                        minWidth: scaler.scale(28),
                        minHeight: scaler.scale(28)),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: Text('$count',
                        style: AppText.label.copyWith(
                            fontSize: 20,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.area,
    required this.initial,
    required this.genres,
    required this.onChanged,
  });

  /// Barre de recherche + bouton (coordonnées de l'écran).
  final Rect area;
  final SearchFilters initial;
  final List<String> genres;
  final ValueChanged<SearchFilters> onChanged;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late SearchFilters _filters = widget.initial;

  void _set(SearchFilters f) {
    if (f == _filters) return;
    setState(() => _filters = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    void close() => Navigator.of(context).pop();
    final f = _filters;

    Widget choice(String group, String text, bool selected, SearchFilters next,
            {bool autofocus = false}) =>
        PillChoice(
          key: ValueKey('filter-$group-$text'),
          text: text,
          selected: selected,
          compact: true,
          semanticPrefix: group,
          autofocus: autofocus,
          onTap: () => _set(next),
        );

    final top = widget.area.bottom + AppSpacing.sm;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): close,
        const SingleActivator(LogicalKeyboardKey.goBack): close,
      },
      child: Material(
        type: MaterialType.transparency,
        child: FocusScope(
          child: Stack(
            children: [
              Positioned(
                left: widget.area.left,
                top: top,
                child: Container(
                  key: const ValueKey('filter-panel'),
                  width: widget.area.width,
                  constraints: BoxConstraints(
                      maxHeight: size.height - top - AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.surfaceHigh, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 32,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête : titre, et « Effacer » quand un filtre
                        // est choisi.
                        Row(
                          children: [
                            Expanded(
                              child: Text(l10n.filters, style: AppText.title),
                            ),
                            if (f.count > 0)
                              FocusableCard(
                                key: const ValueKey('filters-clear'),
                                borderRadius: 999,
                                onTap: () => _set(SearchFilters.none),
                                semanticLabel: l10n.clearFilters,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded,
                                        size: scaler.scale(28),
                                        color: AppColors.text),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(l10n.clearFilters,
                                        style: AppText.label
                                            .copyWith(color: AppColors.text)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilterRow(
                          title: l10n.filterType,
                          children: [
                            choice(l10n.filterType, l10n.filterAll,
                                f.family == null, f.withFamily(null),
                                autofocus: true),
                            for (final fam in MediaFamily.values)
                              choice(l10n.filterType, fam.label(l10n),
                                  f.family == fam, f.withFamily(fam)),
                          ],
                        ),
                        if (widget.genres.isNotEmpty)
                          FilterRow(
                            title: l10n.filterGenre,
                            children: [
                              choice(l10n.filterGenre, l10n.filterAll,
                                  f.genre == null, f.withGenre(null)),
                              for (final g in widget.genres)
                                choice(l10n.filterGenre, g, f.genre == g,
                                    f.withGenre(g)),
                            ],
                          ),
                        FilterRow(
                          title: l10n.filterAge,
                          children: [
                            choice(l10n.filterAge, l10n.filterAll,
                                f.maxAge == null, f.withMaxAge(null)),
                            for (final age in SearchFilters.ages)
                              choice(l10n.filterAge, l10n.ageMax(age),
                                  f.maxAge == age, f.withMaxAge(age)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne de filtres : titre, puis les choix (passent à la ligne si
/// besoin). Peu de place : titre au-dessus.
class FilterRow extends StatelessWidget {
  const FilterRow({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final titleWidth = MediaQuery.textScalerOf(context).scale(110);
    final choices = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < titleWidth * 6
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label),
                  const SizedBox(height: AppSpacing.xs),
                  choices,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Aligné sur la première ligne de choix.
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: SizedBox(
                      width: titleWidth,
                      child: Text(title, style: AppText.label),
                    ),
                  ),
                  Expanded(child: choices),
                ],
              ),
      ),
    );
  }
}
