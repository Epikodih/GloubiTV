import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../l10n/app_localizations.dart';
import '../player/media_kit_engine.dart';
import '../player/playback_engine.dart';
import '../player/player_screen.dart';
import '../player/subtitle_style.dart';
import '../profile/profile_screen.dart';
import '../settings/sources_screen.dart';
import '../widgets/profile_menu.dart';
import 'library_section.dart';
import 'library_sidebar.dart';
import 'media_details.dart';
import 'media_views.dart';
import 'session_lists.dart';
import 'search_filters.dart';
import 'search_view.dart';

/// Médiathèque, après le choix du profil.
///
/// - En haut : le logo, la barre de recherche, et à droite l'icône du
///   profil, qui ouvre un menu déroulant (« Profil », « Changer de profil »
///   ou retour à l'appairage). Le focus dans la barre de recherche affiche
///   les résultats et les filtres en dessous.
/// - À gauche : le menu (accueil, « À regarder », favoris, puis films,
///   séries, musique, podcasts), réduit aux icônes ; il se déplie quand le
///   focus y entre. OK sur une entrée l'affiche à droite.
/// - À droite : l'entrée choisie. L'accueil range les médias en rangées par
///   type ; les autres entrées sont des grilles. Favoris, « À regarder » et
///   recherche mélangent les types : chaque affiche porte l'icône du sien.
///
/// Tout passe par GET /api/media (le serveur filtre déjà selon l'âge du
/// profil). OK sur une affiche ouvre sa fiche ; « Lecture » y ouvre le
/// lecteur (films, épisodes, morceaux), Retour revient sur la fiche.
/// Ouvrir une série ou un album (saisons, pistes) n'est pas encore branché.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onChangeProfile,
    required this.onBackToPairing,
    this.engineFactory = MediaKitEngine.new,
  });

  final Api api;

  /// Compte actif (réponse de POST /api/session/profile).
  final Map<String, dynamic> profile;

  /// Retour à l'écran « Qui regarde ? » (depuis le menu du profil).
  final VoidCallback onChangeProfile;

  /// Retour à l'écran d'appairage (depuis le menu du profil).
  final VoidCallback onBackToPairing;

  /// Crée un moteur de lecture neuf à chaque ouverture du lecteur
  /// (media_kit par défaut, faux moteur dans les tests).
  final PlaybackEngine Function() engineFactory;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibrarySection _section = LibrarySection.home;

  /// Change à chaque modification du profil : les listes se rechargent
  /// (l'âge ou la restriction ont pu changer, le serveur re-filtre).
  int _generation = 0;

  /// Le focus est dans le menu de gauche : il est déplié.
  bool _menuOpen = false;

  final _searchText = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'search-field');

  /// Barre de recherche + bouton des filtres : le menu s'aligne dessous.
  final _searchArea = GlobalKey();
  SearchFilters _filters = SearchFilters.none;

  /// Genres proposés dans les filtres : ceux du catalogue du profil,
  /// chargés à la première ouverture du menu des filtres.
  Future<List<String>>? _genres;

  // Copie locale du profil : mise à jour après une modification.
  late Map<String, dynamic> _profile = widget.profile;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_searchFocused);
  }

  Future<List<String>> _loadGenres() => _genres ??= () async {
        try {
          final items = await widget.api.fetchMedia();
          final set = <String>{
            for (final m in items)
              for (final g in (m['genres'] as List? ?? const [])) '$g',
          };
          return set.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } catch (_) {
          _genres = null; // on réessaiera à la prochaine ouverture
          return const <String>[]; // pas de filtre de genre
        }
      }();

  /// Un filtre choisi affiche les résultats de la recherche.
  void _filtersChanged(SearchFilters f) {
    setState(() {
      _filters = f;
      _section = LibrarySection.search;
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchText.dispose();
    super.dispose();
  }

  /// Aller dans la barre de recherche affiche la recherche en dessous.
  void _searchFocused() {
    if (_searchFocus.hasFocus && _section != LibrarySection.search) {
      setState(() => _section = LibrarySection.search);
    }
  }

  void _select(LibrarySection section) {
    if (section == _section) return;
    setState(() {
      _section = section;
      _searchText.clear();
      _filters = SearchFilters.none;
    });
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(api: widget.api, profile: _profile),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _profile = {..._profile, ...updated};
      _generation++;
    });
  }

  /// « Paramètres » : dossiers scannés par le media center. Au retour, si
  /// les dossiers ont changé, la médiathèque se recharge.
  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SourcesScreen(api: widget.api)),
    );
    if (changed == true && mounted) {
      setState(() {
        _generation++;
        _genres = null;
      });
    }
  }

  /// Invité : ses favoris et « À regarder » ne vivent que le temps de la
  /// session, dans la TV (le serveur ne les garde pas).
  bool get _isGuest => _profile['kind'] == 'guest';
  final _guestLists = SessionLists();

  // Apparence des sous-titres gardée d'une lecture à l'autre (session).
  SubtitleStyle _subtitleStyle = const SubtitleStyle();

  /// « Lecture » dans la fiche : ouvre le lecteur par-dessus la fiche, sur
  /// le navigateur racine (celui de la fiche). Retour revient sur la fiche,
  /// focus sur « Lecture ».
  void _play(BuildContext context, Map<String, dynamic> item) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        engine: widget.engineFactory(),
        source: widget.api.streamSource(item),
        subtitleStyle: _subtitleStyle,
        onSubtitleStyleChanged: (s) => _subtitleStyle = s,
      ),
    ));
  }

  /// Les réglages du media center sont réservés aux comptes non restreints.
  bool get _canChangeSettings =>
      _profile['kind'] == 'account' && _profile['is_restricted'] != true;

  /// OK sur une affiche : fiche du média. Si les favoris ou « À regarder »
  /// ont changé, la liste affichée est rechargée.
  Future<void> _openMedia(Map<String, dynamic> item) async {
    final changed = await showMediaDetails(
      context,
      api: widget.api,
      item: item,
      guestLists: _isGuest ? _guestLists : null,
      onPlay: _play,
    );
    if (changed && mounted && _section.list != null) {
      setState(() => _generation++);
    }
  }

  Widget _content(AppLocalizations l10n) {
    final api = widget.api;
    final section = _section;
    final key = ValueKey((section, _generation));
    if (section == LibrarySection.search) {
      return SearchView(
          key: key,
          api: api,
          controller: _searchText,
          filters: _filters,
          onOpen: _openMedia);
    }
    final home = section == LibrarySection.home;
    return MediaLoader(
      key: key,
      request: key,
      load: () => _isGuest && section.list != null
          ? Future.value(_guestLists
              .items(section.list == 'favorites' ? 'favorite' : 'watchlist'))
          : api.fetchMedia(kind: section.kind, list: section.list),
      emptyIcon: home ? Icons.video_library_outlined : section.icon,
      emptyText: section.emptyText(l10n),
      builder: (context, items) => home
          // À l'arrivée, le focus est sur la première affiche.
          ? MediaRows(
              items: items,
              baseUrl: api.baseUrl,
              autofocusFirst: true,
              onOpen: _openMedia,
            )
          : MediaGrid(
              items: items,
              baseUrl: api.baseUrl,
              showKind: section.mixesKinds,
              onOpen: _openMedia,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = '${_profile['name'] ?? l10n.guestName}';
    final scaler = MediaQuery.textScalerOf(context);
    final collapsed = LibrarySidebar.collapsedWidth(context);
    // Menu déplié : la liste glisse vers la droite pour rester visible
    // (et atteignable avec la flèche droite).
    final shift =
        _menuOpen ? LibrarySidebar.expandedWidth(context) - collapsed : 0.0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final searchHeight = scaler.scale(62);
    // Petit écran (ou grand texte) : logo plus petit, bouton des filtres
    // réduit à son icône, pour laisser la place à la barre de recherche.
    final narrow = MediaQuery.sizeOf(context).width < scaler.scale(1400);

    return Scaffold(
      body: BrandBackground(
        child: TvSafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GloubiLogo(size: narrow ? 40 : 56),
                    SizedBox(width: narrow ? AppSpacing.sm : AppSpacing.lg),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: scaler.scale(960)),
                          child: Row(
                            key: _searchArea,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: searchHeight,
                                  child: SearchField(
                                    controller: _searchText,
                                    focusNode: _searchFocus,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SearchFilterButton(
                                filters: _filters,
                                loadGenres: _loadGenres,
                                onChanged: _filtersChanged,
                                height: searchHeight,
                                alignTo: _searchArea,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: narrow ? AppSpacing.sm : AppSpacing.lg),
                    ProfileMenuButton(
                      name: name,
                      onProfile: _openProfile,
                      onSwitchProfile: widget.onChangeProfile,
                      onPairing: widget.onBackToPairing,
                      onSettings: _canChangeSettings ? _openSettings : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        Positioned.fill(
                          left: collapsed + AppSpacing.md,
                          child: ClipRect(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: shift),
                              duration: reduce
                                  ? Duration.zero
                                  : LibrarySidebar.openDuration,
                              curve: LibrarySidebar.openCurve,
                              builder: (context, dx, child) =>
                                  Transform.translate(
                                      offset: Offset(dx, 0), child: child),
                              child: _content(l10n),
                            ),
                          ),
                        ),
                        // Hauteur du menu = ses entrées (défile si l'écran
                        // est trop petit).
                        Positioned(
                          left: 0,
                          top: 0,
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: box.maxHeight),
                            child: LibrarySidebar(
                              selected: _section,
                              onSelect: _select,
                              onOpenChanged: (open) =>
                                  setState(() => _menuOpen = open),
                              onSettings:
                                  _canChangeSettings ? _openSettings : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
