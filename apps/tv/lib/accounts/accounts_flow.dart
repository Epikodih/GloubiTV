import 'package:epikodi_client/epikodi_client.dart' show ApiException;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../l10n/app_localizations.dart';
import '../library/library_screen.dart';
import '../remote/remote_keys.dart';
import 'accounts_screen.dart';
import 'create_account_screen.dart';
import 'pin_dialog.dart';

/// Relie les écrans de choix de compte :
///
///   « Qui regarde ? » ──┬─ compte ──(PIN si requis)──┐
///                       ├─ Invité ───────────────────┼─> POST /api/session/profile ─> Médiathèque
///                       └─ Créer ─> CreateAccountScreen (POST /api/profiles) ─────────┘
///
/// C'est le seul endroit qui connaît à la fois l'API et la navigation :
/// les écrans, eux, restent de simples vues.
class AccountsFlow extends StatefulWidget {
  const AccountsFlow({
    super.key,
    required this.api,
    required this.data,
    required this.onBackToPairing,
  });

  final Api api;

  /// Réponse du serveur : { phase, profiles: [...], guest: {...}, can_create }.
  final Map<String, dynamic> data;

  /// Retour à l'écran d'appairage.
  final VoidCallback onBackToPairing;

  @override
  State<AccountsFlow> createState() => _AccountsFlowState();
}

class _AccountsFlowState extends State<AccountsFlow> {
  /// Copie locale : on y ajoute les comptes créés pendant la session.
  late Map<String, dynamic> _data = Map<String, dynamic>.of(widget.data);

  /// Évite les doubles appuis pendant un appel réseau.
  bool _busy = false;

  /// Mode « modifier » : supprimer des comptes.
  bool _editing = false;

  /// « Changer de profil » sur la télécommande : retour à cet écran, depuis
  /// n'importe où (médiathèque, fiche, lecteur…). Revenir ici oublie le
  /// profil actif (voir [_openLibrary]).
  void _switchProfile() {
    final route = ModalRoute.of(context);
    if (route == null || !mounted) return;
    Navigator.of(context).popUntil((r) => r == route);
  }

  @override
  void initState() {
    super.initState();
    remoteSwitchProfile = _switchProfile;
  }

  @override
  void dispose() {
    if (remoteSwitchProfile == _switchProfile) remoteSwitchProfile = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(AccountsFlow old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _data = Map<String, dynamic>.of(widget.data);
    }
  }

  // ------------------------------------------------------------- navigation

  Future<void> _openLibrary(Map<String, dynamic> profile) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: LibraryScreen.routeName),
      builder: (ctx) => LibraryScreen(
        api: widget.api,
        profile: profile,
        onChangeProfile: () => Navigator.of(ctx).pop(),
        onBackToPairing: widget.onBackToPairing,
      ),
    ));
    // Revenu à « Qui regarde ? », par n'importe quel chemin (« Changer de
    // profil », touche Retour…) : plus de profil actif. Sinon un invité ou
    // un enfant resterait actif et la création d'un compte serait refusée.
    if (mounted) await widget.api.clearProfile();
  }

  /// Erreur : popup qui disparaît toute seule (comme partout dans l'app).
  void _showError(String message) =>
      showErrorToast(context, message, scale: tvToastScale);

  List<Map<String, dynamic>> get _profiles =>
      (_data['profiles'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  /// Supprime un compte : une confirmation, puis `DELETE /api/profiles/{id}`
  /// (pas de PIN : le media center est local).
  Future<void> _delete(Map<String, dynamic> p) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(name: '${p['name']}'),
    );
    if (ok != true || !mounted) return;
    _busy = true;
    try {
      await widget.api.deleteProfile(p['id'] as Object);
      if (!mounted) return;
      setState(() {
        _data = {
          ..._data,
          'profiles': [
            for (final o in _profiles)
              if (o['id'] != p['id']) o,
          ],
        };
        if (_profiles.isEmpty) _editing = false;
      });
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      _busy = false;
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _pick(Map<String, dynamic> p) async {
    if (_busy) return;
    final id = p['id']; // entier, comme dans la fixture

    if (p['requires_pin'] == true) {
      Map<String, dynamic>? active;
      await showDialog<void>(
        context: context,
        builder: (_) => PinDialog(
          profileName: '${p['name']}',
          onSubmit: (pin) async {
            try {
              active = await widget.api.selectProfile(profileId: id, pin: pin);
              return null; // PIN bon : la popup se ferme.
            } on ApiException catch (e) {
              return e.message; // Affiché dans la popup, saisie effacée.
            }
          },
        ),
      );
      final result = active;
      if (result != null && mounted) await _openLibrary(result);
      return;
    }

    await _run(() => widget.api.selectProfile(profileId: id));
  }

  Future<void> _guest() => _run(() => widget.api.selectProfile(guest: true));

  Future<void> _create() async {
    if (_busy) return;
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(api: widget.api),
      ),
    );
    if (created == null || !mounted) return; // Annulé.

    // Le compte apparaît dans « Qui regarde ? » au retour.
    setState(() {
      _data = {
        ..._data,
        'profiles': [...(_data['profiles'] as List? ?? const []), created],
      };
    });
    // Le serveur l'a déjà rendu actif : on entre directement.
    await _openLibrary(created);
  }

  /// Appel réseau + ouverture de la médiathèque, avec gestion d'erreur.
  Future<void> _run(Future<Map<String, dynamic>> Function() call) async {
    if (_busy) return;
    _busy = true;
    try {
      final profile = await call();
      if (mounted) await _openLibrary(profile);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountsScreen(
      data: _data,
      onBackToPairing: widget.onBackToPairing,
      onProfile: _pick,
      onGuest: _guest,
      onCreate: _create,
      editing: _editing,
      onToggleEdit: () => setState(() => _editing = !_editing),
      onDelete: _delete,
    );
  }
}

/// « Supprimer le compte de Marc ? » : « Annuler » a le focus.
class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget action(String text, bool value,
            {bool autofocus = false, IconData? icon, Key? key}) =>
        FocusableCard(
          key: key,
          autofocus: autofocus,
          borderRadius: 999,
          onTap: () => Navigator.of(context).pop(value),
          semanticLabel: text,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.error),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(text,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.deleteAccountTitle(name),
                  style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.deleteAccountBody,
                  style: AppText.body.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  action(l10n.cancel, false, autofocus: true),
                  action(l10n.deleteAccount, true,
                      icon: Icons.delete_rounded,
                      key: const ValueKey('confirm-delete-account')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
