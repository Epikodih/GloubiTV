import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'remote_events.dart';

/// Pavé numérique affiché à la place des flèches quand la TV demande un
/// code PIN (choix d'un compte, contrôle parental…).
///
/// Chaque appui envoie toute la saisie à la TV ([onDigits]) : elle remplit
/// ses points et valide toute seule au dernier chiffre. Une nouvelle demande
/// de la TV (autre [request.id], par exemple après un code faux) efface la
/// saisie. Les chiffres ne sont jamais affichés, seulement des points.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.request,
    required this.size,
    required this.onDigits,
  });

  final TextInputRequest request;

  /// Largeur (et hauteur max) disponible, comme le pavé des flèches.
  final double size;

  /// Saisie complète (`"12"`, puis `"123"`…) et si elle est terminée.
  final void Function(String digits, bool done) onDigits;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  int get _length => widget.request.maxLength ?? 4;

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.request.id != widget.request.id) _digits = '';
  }

  void _add(String d) {
    if (_digits.length >= _length) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += d);
    widget.onDigits(_digits, _digits.length == _length);
  }

  void _erase() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
    widget.onDigits(_digits, false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 4 rangées de touches + titre + points dans la place du pavé.
    final key = ((widget.size - 2 * AppSpacing.md) / 3)
        .clamp(48.0, 84.0)
        .toDouble();

    Widget button(String semantic, Widget child, VoidCallback onTap,
            {String? id}) =>
        Semantics(
          button: true,
          label: semantic,
          excludeSemantics: true,
          child: Container(
            key: id == null ? null : ValueKey(id),
            width: key,
            height: key,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              gradient: AppBrand.gradient,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: Center(child: child)),
            ),
          ),
        );

    Widget digit(String d) => button(
          d,
          Text(d,
              style: RemoteText.title
                  .copyWith(fontSize: key * 0.38, fontWeight: FontWeight.w600)),
          () => _add(d),
          id: 'pin-$d',
        );

    Widget row(List<Widget> keys) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys,
        );

    return SizedBox(
      width: widget.size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.request.label.isEmpty
                ? l10n.pinPadTitle
                : widget.request.label,
            key: const ValueKey('pin-title'),
            textAlign: TextAlign.center,
            style: RemoteText.title,
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: l10n.pinPadProgress(_digits.length, _length),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _length; i++)
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _digits.length
                            ? AppColors.text
                            : Colors.transparent,
                        border: Border.all(color: AppColors.text, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          row([digit('1'), digit('2'), digit('3')]),
          const SizedBox(height: AppSpacing.xs),
          row([digit('4'), digit('5'), digit('6')]),
          const SizedBox(height: AppSpacing.xs),
          row([digit('7'), digit('8'), digit('9')]),
          const SizedBox(height: AppSpacing.xs),
          row([
            SizedBox(width: key, height: key),
            digit('0'),
            button(
              l10n.pinPadErase,
              const Icon(Icons.backspace_outlined, color: AppColors.text),
              _erase,
              id: 'pin-erase',
            ),
          ]),
        ],
      ),
    );
  }
}
