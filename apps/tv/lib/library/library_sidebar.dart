import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'library_section.dart';

/// Menu de gauche de la médiathèque : accueil, listes du profil
/// (« À regarder », favoris), puis les catégories. La recherche est dans
/// l'en-tête.
///
/// - Réduit (icônes seules) tant que le focus est ailleurs ; il s'élargit et
///   montre les libellés quand le focus y entre ([onOpenChanged]).
/// - En entrant, le focus va sur l'entrée affichée. Ensuite, passer sur une
///   entrée l'affiche tout de suite à droite, sans valider.
/// - Sa hauteur suit ses entrées (pas de vide en bas).
/// - En bas, « Paramètres » ([onSettings]) : les dossiers du media center.
///   Lui ne s'ouvre qu'avec OK (pas au simple passage).
/// L'entrée affichée est marquée par une barre (et un texte en gras une fois
/// déplié), pas seulement par la couleur.
class LibrarySidebar extends StatefulWidget {
  const LibrarySidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onOpenChanged,
    this.onSettings,
  });

  /// Entrées du menu, dans l'ordre (sans la recherche).
  static final sections = [
    for (final s in LibrarySection.values)
      if (s != LibrarySection.search) s,
  ];

  /// Largeur réduite (icônes seules) et dépliée.
  static double collapsedWidth(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(32) + 72;
  static double expandedWidth(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(280);

  /// Durée et courbe de l'ouverture (aussi pour la liste qui glisse).
  static const openDuration = Duration(milliseconds: 280);
  static const openCurve = Curves.easeOutCubic;

  final LibrarySection selected;
  final ValueChanged<LibrarySection> onSelect;
  final ValueChanged<bool> onOpenChanged;

  /// Ouvre les paramètres. Null : entrée cachée (invité, compte restreint).
  final VoidCallback? onSettings;

  @override
  State<LibrarySidebar> createState() => _LibrarySidebarState();
}

class _LibrarySidebarState extends State<LibrarySidebar> {
  final _nodes = {
    for (final s in LibrarySidebar.sections)
      s: FocusNode(debugLabel: 'nav-${s.name}'),
  };
  final _settingsNode = FocusNode(debugLabel: 'nav-settings');
  bool _open = false;

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _settingsNode.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    widget.onOpenChanged(open);
  }

  /// Une entrée vient de prendre le focus ([section] null : Paramètres,
  /// qui ne change pas la liste affichée).
  void _itemFocused(LibrarySection? section) {
    if (!_open) {
      // On entre dans le menu : sur l'entrée affichée, pas sur la plus
      // proche (qui changerait la liste sans le vouloir).
      _setOpen(true);
      if (section != widget.selected) _nodes[widget.selected]!.requestFocus();
      return;
    }
    if (section != null) widget.onSelect(section);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : LibrarySidebar.openDuration;

    final children = <Widget>[];
    for (final section in LibrarySidebar.sections) {
      if (section == LibrarySection.movies) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(
              vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
          child: Divider(color: AppColors.surfaceHigh, thickness: 2),
        ));
      }
      children.add(Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (has) {
          if (has) _itemFocused(section);
        },
        child: _SidebarItem(
          key: ValueKey('nav-${section.name}'),
          focusNode: _nodes[section]!,
          icon: section.icon,
          label: section.label(l10n),
          selected: section == widget.selected,
          expanded: _open,
          duration: duration,
          onTap: () => widget.onSelect(section),
        ),
      ));
    }
    if (widget.onSettings case final open?) {
      children
        ..add(const Padding(
          padding: EdgeInsets.symmetric(
              vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
          child: Divider(color: AppColors.surfaceHigh, thickness: 2),
        ))
        ..add(Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (has) {
            if (has) _itemFocused(null);
          },
          child: _SidebarItem(
            key: const ValueKey('nav-settings'),
            focusNode: _settingsNode,
            icon: Icons.settings_rounded,
            label: l10n.settings,
            selected: false,
            expanded: _open,
            duration: duration,
            onTap: open,
          ),
        ));
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (inside) {
        if (!inside) _setOpen(false);
      },
      child: Semantics(
        container: true,
        label: l10n.libraryNavigation,
        child: AnimatedContainer(
          duration: duration,
          curve: LibrarySidebar.openCurve,
          width: _open
              ? LibrarySidebar.expandedWidth(context)
              : LibrarySidebar.collapsedWidth(context),
          decoration: BoxDecoration(
            color: _open
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _open ? 0.55 : 0),
                blurRadius: 32,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.duration,
    required this.onTap,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final color = selected ? AppColors.text : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xs / 2),
      child: FocusableCard(
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: AppRadius.md,
        semanticLabel: label,
        child: Semantics(
          selected: selected,
          child: AnimatedContainer(
            duration: duration,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                // Barre de l'entrée affichée.
                AnimatedContainer(
                  duration: duration,
                  width: 5,
                  height: scaler.scale(30),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(icon, size: scaler.scale(32), color: color),
                const SizedBox(width: AppSpacing.sm),
                // Toujours là, mais invisible quand le menu est réduit : il
                // apparaît en fondu pendant que le menu s'élargit.
                Expanded(
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: expanded ? const Interval(0.35, 1) : Curves.linear,
                    opacity: expanded ? 1 : 0,
                    child: ExcludeSemantics(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: AppText.label.copyWith(
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
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
