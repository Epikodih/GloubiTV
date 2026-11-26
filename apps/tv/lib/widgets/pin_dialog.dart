import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../remote/remote_keys.dart';
import 'pill_metrics.dart';

/// Demande un code PIN. Renvoie le PIN saisi, ou `null` si annulé.
/// [errorText] : message affiché (ex. « Code PIN incorrect. » après un échec).
/// [title] / [subtitle] : par défaut, « Code PIN requis » (vérification).
Future<String?> showPinDialog(
  BuildContext context, {
  String? errorText,
  String? title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) =>
        _PinDialog(errorText: errorText, title: title, subtitle: subtitle),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({this.errorText, this.title, this.subtitle});

  final String? errorText;
  final String? title;
  final String? subtitle;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  static const _length = 4;
  String _pin = '';

  /// Pavé numérique sur le téléphone tant que la popup est ouverte.
  RemotePinEntry? _remote;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_remote != null) return;
    final l10n = AppLocalizations.of(context)!;
    _remote = RemotePinEntry(
      label: widget.errorText ?? widget.title ?? l10n.pinTitle,
      length: _length,
      onDigits: _setFromRemote,
    );
    // Après le build : pas de notification pendant la construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRemotePin(_remote!);
    });
  }

  @override
  void dispose() {
    hideRemotePin(_remote);
    super.dispose();
  }

  /// Saisie complète envoyée par le téléphone.
  void _setFromRemote(String digits) {
    if (!mounted) return;
    final pin = digits.length > _length ? digits.substring(0, _length) : digits;
    setState(() => _pin = pin);
    if (_pin.length == _length) Navigator.of(context).pop(_pin);
  }

  void _add(String digit) {
    if (_pin.length >= _length) return;
    setState(() => _pin += digit);
    if (_pin.length == _length) Navigator.of(context).pop(_pin);
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);

    // Clavier physique : chiffres, retour arrière, Échap.
    final bindings = <ShortcutActivator, VoidCallback>{
      for (var d = 0; d <= 9; d++)
        SingleActivator(LogicalKeyboardKey(0x00000000030 + d)): () =>
            _add('$d'),
      const SingleActivator(LogicalKeyboardKey.backspace): _delete,
      const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      const SingleActivator(LogicalKeyboardKey.goBack): _cancel,
    };

    return CallbackShortcuts(
      bindings: bindings,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scaler.scale(420)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? l10n.pinTitle,
                  style: AppText.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.subtitle ?? l10n.pinSubtitle,
                  style: AppText.body.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                _Dots(filled: _pin.length, total: _length),
                const SizedBox(height: AppSpacing.sm),
                // Place réservée : le dialogue ne saute pas quand l'erreur apparaît.
                SizedBox(
                  height: scaler.scale(32),
                  child: widget.errorText == null
                      ? null
                      : Text(
                          widget.errorText!,
                          style: AppText.body.copyWith(
                            color: AppColors.error,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Keypad(onDigit: _add, onDelete: _delete),
                const SizedBox(height: AppSpacing.md),
                FocusableCard(
                  borderRadius: 999,
                  onTap: _cancel,
                  semanticLabel: l10n.cancel,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: SizedBox(
                    height: scaler.scale(pillButtonHeight),
                    child: Center(
                      child: Text(
                        l10n.cancel,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
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

/// Les points (remplis au fur et à mesure de la saisie).
class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(20);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: i < filled ? AppBrand.gradient : null,
              color: i < filled ? null : AppColors.surfaceHigh,
            ),
          ),
        ],
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onDelete});

  final void Function(String digit) onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget digit(String d, {bool autofocus = false}) => _Key(
          semantic: l10n.pinDigitSemantics(d),
          autofocus: autofocus,
          onTap: () => onDigit(d),
          child: Text(d, style: AppText.title.copyWith(height: 1.3)),
        );

    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                children[i],
              ],
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit('1', autofocus: true), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        row([
          const _KeySpacer(),
          digit('0'),
          _Key(
            semantic: l10n.deleteDigit,
            onTap: onDelete,
            child: const Icon(Icons.backspace_outlined, color: AppColors.text),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.child,
    required this.onTap,
    required this.semantic,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semantic;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(72);
    return FocusableCard(
      autofocus: autofocus,
      borderRadius: 999,
      onTap: onTap,
      semanticLabel: semantic,
      child: SizedBox(width: size, height: size, child: Center(child: child)),
    );
  }
}

/// Case vide qui garde le « 0 » centré.
class _KeySpacer extends StatelessWidget {
  const _KeySpacer();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(72);
    return SizedBox(width: size, height: size);
  }
}
