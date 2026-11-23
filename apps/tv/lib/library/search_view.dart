import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../l10n/app_localizations.dart';
import 'search_filters.dart';
import 'media_views.dart';

/// Barre de recherche de l'en-tête de la médiathèque.
///
/// Elle se remplit depuis le clavier du téléphone (comme les autres champs
/// de la TV). Les résultats et les filtres s'affichent sous l'en-tête
/// ([SearchView]).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);
    return TextField(
      key: const ValueKey('search-field'),
      controller: controller,
      focusNode: focusNode,
      maxLength: 60,
      textInputAction: TextInputAction.search,
      style: AppText.label.copyWith(color: AppColors.text),
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        hintStyle: AppText.label,
        prefixIcon: Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
          child: Icon(Icons.search_rounded,
              size: scaler.scale(32), color: AppColors.textMuted),
        ),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.text, width: 3),
        ),
      ),
    );
  }
}

/// Résultats de la recherche de l'en-tête ([controller]), avec les
/// [filters] choisis dans le menu déroulant « Filtres ».
///
/// La recherche part toute seule, un court instant après la dernière
/// lettre. Les résultats portent l'icône de leur type.
class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    required this.api,
    required this.controller,
    this.filters = SearchFilters.none,
    this.onOpen,
    this.debounce = const Duration(milliseconds: 400),
  });

  final Api api;

  /// Texte de la barre de recherche.
  final TextEditingController controller;

  final SearchFilters filters;

  /// OK sur un résultat : ouvre sa fiche.
  final MediaOpener? onOpen;

  /// Attente après la dernière lettre avant de chercher.
  final Duration debounce;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  Timer? _timer;

  late String _query = widget.controller.text.trim();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_typed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_typed);
    super.dispose();
  }

  void _typed() {
    if (widget.controller.text.trim() == _query) return; // curseur, sélection
    _timer?.cancel();
    _timer = Timer(widget.debounce, _search);
  }

  void _search() {
    _timer?.cancel();
    final value = widget.controller.text.trim();
    if (!mounted || value == _query) return;
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = widget.filters;
    return MediaLoader(
      request: (_query, f),
      load: () => widget.api.fetchMedia(
        query: _query,
        kind: f.family?.kinds,
        genre: f.genre,
        maxAge: f.maxAge,
      ),
      emptyIcon: Icons.search_off_rounded,
      emptyText: l10n.noResults,
      builder: (context, items) => MediaGrid(
        items: items,
        baseUrl: widget.api.baseUrl,
        showKind: true,
        onOpen: widget.onOpen,
      ),
    );
  }
}
