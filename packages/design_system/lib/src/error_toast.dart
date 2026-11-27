import 'dart:async';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Taille des popups d'erreur sur la TV (lues de loin).
const tvToastScale = 1.6;

/// Popup d'erreur qui apparaît en haut de l'écran puis disparaît toute seule
/// après [duration] (un appui la ferme plus tôt). Une nouvelle erreur
/// remplace la précédente. Utilisée par toutes les apps pour leurs messages
/// d'erreur (« La TV ne connaît plus ce téléphone », code faux…).
///
/// [scale] : taille du texte et de l'icône (1 sur le téléphone, ~1.6 sur la
/// TV, vue de loin).
///
/// Si une popup est déjà affichée, son texte est simplement remplacé (pas de
/// nouvelle animation : utile pour un décompte « Réessaie dans 3 s »).
/// Renvoie un jeton pour [hideErrorToast].
Object? showErrorToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  double scale = 1,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final shown = _current;
  final state = shown == null ? null : _states[shown];
  if (shown != null && state != null && state.mounted && !state.closing) {
    state.setMessage(message, duration);
    return shown;
  }
  _current?.dismiss();
  late final _ToastHandle handle;
  final entry = OverlayEntry(
    builder: (_) => _ErrorToast(
      key: ValueKey(handle),
      message: message,
      duration: duration,
      scale: scale,
      onClosed: () => handle.remove(),
    ),
  );
  handle = _ToastHandle(entry);
  _current = handle;
  overlay.insert(entry);
  return handle;
}

/// Ferme la popup d'erreur affichée (s'il y en a une). Avec [token] (rendu
/// par [showErrorToast]) : seulement si c'est encore cette popup.
void hideErrorToast([Object? token]) {
  if (token != null && token != _current) return;
  _current?.dismiss();
}

_ToastHandle? _current;

class _ToastHandle {
  _ToastHandle(this.entry);

  final OverlayEntry entry;
  bool _removed = false;

  void dismiss() {
    final state = _states[this];
    if (state != null && state.mounted) {
      state.close();
    } else {
      remove();
    }
  }

  void remove() {
    if (_removed) return;
    _removed = true;
    if (_current == this) _current = null;
    _states.remove(this);
    if (entry.mounted) entry.remove();
  }
}

final _states = <_ToastHandle, _ErrorToastState>{};

/// Affiche [error] en popup quand il change. À appeler dans `build` :
///
/// ```dart
/// _toast.update(context, _error);
/// ```
/// La même erreur n'est montrée qu'une fois, jusqu'à ce qu'elle redevienne
/// `null` (nouvelle tentative) ; l'erreur disparue ferme sa popup.
class ErrorToastTrigger {
  ErrorToastTrigger({this.scale = 1});

  final double scale;
  String? _shown;
  Object? _token;

  void update(BuildContext context, String? error) {
    if (error == null) {
      clear();
      return;
    }
    if (error == _shown) return;
    _shown = error;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (context.mounted) {
          _token = showErrorToast(context, error, scale: scale);
        }
      })
      ..scheduleFrame();
  }

  /// L'erreur n'a plus lieu d'être : sa popup se ferme.
  void clear() {
    if (_shown != null) hideErrorToast(_token);
    _shown = null;
    _token = null;
  }
}

class _ErrorToast extends StatefulWidget {
  const _ErrorToast({
    super.key,
    required this.message,
    required this.duration,
    required this.scale,
    required this.onClosed,
  });

  final String message;
  final Duration duration;
  final double scale;
  final VoidCallback onClosed;

  @override
  State<_ErrorToast> createState() => _ErrorToastState();
}

class _ErrorToastState extends State<_ErrorToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _closing = false;
  bool _reduce = false;
  late String _message = widget.message;

  bool get closing => _closing;

  /// Nouveau texte, même popup : le délai repart.
  void setMessage(String message, Duration duration) {
    setState(() => _message = message);
    _timer?.cancel();
    _timer = Timer(duration, close);
  }

  @override
  void initState() {
    super.initState();
    final key = widget.key;
    if (key is ValueKey<_ToastHandle>) _states[key.value] = this;
    _timer = Timer(widget.duration, close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gardé ici : close() peut arriver pendant le démontage de l'écran.
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_anim.status == AnimationStatus.dismissed && !_closing) {
      if (_reduce) {
        _anim.value = 1;
      } else {
        _anim.forward();
      }
    }
  }

  Future<void> close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (!_reduce) {
      try {
        await _anim.reverse().orCancel;
      } on TickerCanceled {
        // écran démonté pendant l'animation
      }
    }
    if (mounted) widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    final key = widget.key;
    if (key is ValueKey<_ToastHandle>) _states.remove(key.value);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm * s),
          child: Center(
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.4), end: Offset.zero)
                    .animate(curved),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 560 * s),
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Material(
                      key: const ValueKey('error-toast'),
                      color: AppColors.surface,
                      elevation: 8,
                      shadowColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md * s),
                        side: BorderSide(
                            color: AppColors.error.withAlpha(160), width: 1.5),
                      ),
                      child: InkWell(
                        onTap: close,
                        borderRadius: BorderRadius.circular(AppRadius.md * s),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm * s,
                            vertical: (AppSpacing.sm - 4) * s,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 22 * s),
                              SizedBox(width: AppSpacing.xs * s),
                              Flexible(
                                child: Text(
                                  _message,
                                  style: TextStyle(
                                    fontSize: 15 * s,
                                    height: 1.3,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
