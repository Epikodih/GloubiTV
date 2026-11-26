import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// Squelette commun des écrans : fond de marque, logo GloubiTV en haut,
/// contenu centré et défilant (petits écrans, texte agrandi), boutons en bas.
class RemotePage extends StatelessWidget {
  const RemotePage({
    super.key,
    required this.children,
    this.actions = const [],
    this.onBack,
    this.footer,
  });

  final List<Widget> children;

  /// Ligne discrète tout en bas (ex. adresse du serveur).
  final Widget? footer;

  /// Boutons du bas, du plus important au moins important.
  final List<Widget> actions;

  /// Affiche une flèche « Retour » en haut à gauche.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Clavier ouvert : peu de place. Les boutons défilent avec le contenu au
    // lieu de rester collés en bas, pour que rien ne soit caché.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final buttons = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm - 4),
          actions[i],
        ],
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  _Header(onBack: onBack),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...children,
                              if (keyboard && actions.isNotEmpty) ...[
                                buttons,
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              if (keyboard && footer != null) ...[
                                footer!,
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!keyboard && actions.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs,
                          AppSpacing.md, footer == null ? AppSpacing.md : 0),
                      child: buttons,
                    ),
                  if (!keyboard && footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 4, AppSpacing.md, AppSpacing.xs),
                      child: footer,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: double.infinity, // la flèche se cale à gauche, le logo au centre
      child: Stack(
        alignment: Alignment.center,
        children: [
          const GloubiLogo(size: 30),
          if (onBack != null)
            Positioned(
              left: AppSpacing.xs,
              child: IconButton(
                onPressed: onBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.text, size: 28),
              ),
            ),
        ],
      ),
    );
  }
}

/// Titre + texte d'un écran, centrés.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(title,
              style: RemoteText.headline, textAlign: TextAlign.center),
        ),
        if (body != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(body!, style: RemoteText.muted, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// Message d'erreur : affiché en popup en haut de l'écran, qui disparaît
/// toute seule après quelques secondes (`showErrorToast` du design system).
/// Ne prend aucune place dans la page. Une nouvelle popup part quand le
/// message change.
class ErrorMessage extends StatefulWidget {
  const ErrorMessage(this.text, {super.key});

  final String text;

  @override
  State<ErrorMessage> createState() => _ErrorMessageState();
}

class _ErrorMessageState extends State<ErrorMessage> {
  final _toast = ErrorToastTrigger();

  /// L'erreur a disparu de la page (nouvelle tentative) : sa popup se ferme.
  @override
  void dispose() {
    _toast.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _toast.update(context, widget.text);
    return const SizedBox.shrink();
  }
}
