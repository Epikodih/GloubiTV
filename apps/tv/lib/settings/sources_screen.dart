import 'package:design_system/design_system.dart';
import 'package:epikodi_client/epikodi_client.dart' show ApiException;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../l10n/app_localizations.dart';
import '../widgets/pill_button.dart';
import '../widgets/round_button.dart';

/// Ouvre le sélecteur de dossier du système. Renvoie le chemin, ou null.
typedef FolderPicker = Future<String?> Function();

Future<String?> _systemFolderPicker() => FilePicker.getDirectoryPath();

/// Paramètres du media center : les dossiers qu'il scanne pour remplir la
/// médiathèque (GET / POST / DELETE /api/sources, POST /api/sources/scan).
///
/// On ajoute un dossier en tapant son chemin (clavier du téléphone) ou avec
/// « Parcourir… » (sélecteur du système, à la souris). Chaque dossier montre
/// son état et son dernier scan, et peut être rescanné ou retiré.
/// Renvoie vrai à la fermeture si les dossiers ont changé (la médiathèque se
/// recharge).
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({
    super.key,
    required this.api,
    FolderPicker? pickFolder,
  }) : pickFolder = pickFolder ?? _systemFolderPicker;

  final Api api;
  final FolderPicker pickFolder;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _path = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future = widget.api.fetchSources();
  bool _busy = false;
  bool _changed = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  void _back() => Navigator.of(context).pop(_changed);

  void _reload() => setState(() {
        _future = widget.api.fetchSources();
      });

  void _say(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _error = error;
    });
  }

  String _errorText(Object e) => e is ApiException
      ? e.message
      : AppLocalizations.of(context)!.sourcesLoadError;

  Future<void> _browse() async {
    final pickError = AppLocalizations.of(context)!.folderPickError;
    try {
      final path = await widget.pickFolder();
      if (path != null && mounted) setState(() => _path.text = path);
    } catch (_) {
      _say(pickError, error: true);
    }
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context)!;
    final path = _path.text.trim();
    if (path.isEmpty) {
      _say(l10n.enterFolder, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final source = await widget.api.addSource(sourceUri(path));
      _path.clear();
      _changed = true;
      _say(l10n.sourceAdded('${source['name']}'));
      _reload();
    } catch (e) {
      _say(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan(Map<String, dynamic> source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.api.scanSources(uris: ['${source['uri']}']);
      _changed = true;
      _say(l10n.scanStarted('${source['name']}'));
    } catch (e) {
      _say(_errorText(e), error: true);
    }
  }

  /// « Tout scanner » : POST /api/sources/scan sans corps.
  Future<void> _scanAll() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final started = await widget.api.scanSources();
      _changed = true;
      _say(l10n.scanAllStarted(started.length));
      _reload();
    } catch (e) {
      _say(_errorText(e), error: true);
    }
  }

  Future<void> _remove(Map<String, dynamic> source) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        text: l10n.removeSourceConfirm('${source['name']}'),
        confirm: l10n.removeSource,
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.removeSource(source['id']);
      _changed = true;
      _say(l10n.sourceRemoved('${source['name']}'));
      _reload();
    } catch (e) {
      _say(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);

    final header = Row(
      children: [
        RoundButton(
          icon: Icons.arrow_back_rounded,
          semantic: l10n.back,
          onTap: _back,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Une ligne chacun : l'en-tête garde sa hauteur à côté du
              // bouton « Tout scanner ».
              Text(l10n.settings,
                  style: AppText.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(l10n.sourcesTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        PillButton(
          key: const ValueKey('sources-scan-all'),
          icon: Icons.sync_rounded,
          text: l10n.scanAll,
          onTap: _scanAll,
        ),
      ],
    );

    final addRow = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sourcesHint,
              style: AppText.label.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('source-path'),
            controller: _path,
            style: AppText.label.copyWith(color: AppColors.text),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              labelText: l10n.sourcePathLabel,
              hintText: l10n.sourcePathHint,
              labelStyle: AppText.label,
              hintStyle: AppText.label,
              prefixIcon: Icon(Icons.folder_rounded,
                  size: scaler.scale(30), color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.text, width: 3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PillButton(
                key: const ValueKey('source-browse'),
                icon: Icons.folder_open_rounded,
                text: l10n.browse,
                onTap: _browse,
              ),
              Opacity(
                opacity: _busy ? 0.5 : 1,
                child: PillButton(
                  key: const ValueKey('source-add'),
                  icon: Icons.add_rounded,
                  text: l10n.addSource,
                  onTap: _busy ? () {} : _add,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final list = FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(_errorText(snap.error!),
                      style: AppText.label.copyWith(color: AppColors.error)),
                ),
                PillButton(text: l10n.retry, onTap: _reload),
              ],
            ),
          );
        }
        final sources = snap.data ?? const [];
        if (sources.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.noSources,
                key: const ValueKey('no-sources'), style: AppText.label),
          );
        }
        return Column(
          children: [
            for (final s in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SourceRow(
                  key: ValueKey('source-${s['id']}'),
                  source: s,
                  onScan: () => _scan(s),
                  onRemove: () => _remove(s),
                ),
              ),
          ],
        );
      },
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _back,
        const SingleActivator(LogicalKeyboardKey.goBack): _back,
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          body: BrandBackground(
            child: TvSafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: scaler.scale(1200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                addRow,
                                if (_message != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    _message!,
                                    key: const ValueKey('sources-message'),
                                    style: AppText.label.copyWith(
                                        color: _error
                                            ? AppColors.error
                                            : AppColors.text),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                list,
                              ],
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
    );
  }
}

/// Chemin tapé ou choisi -> URI pour le serveur : `smb://…` et autres URI
/// gardés tels quels, un chemin de dossier devient `file:///…`.
String sourceUri(String path) {
  final p = path.trim();
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]+://').hasMatch(p)) return p;
  final windows = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(p) || p.startsWith(r'\\');
  return Uri.file(p, windows: windows).toString();
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    super.key,
    required this.source,
    required this.onScan,
    required this.onRemove,
  });

  final Map<String, dynamic> source;
  final VoidCallback onScan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scaler = MediaQuery.textScalerOf(context);
    final status = '${source['status']}';
    final (statusText, statusColor) = switch (status) {
      'online' => (l10n.sourceOnline, const Color(0xFF6BD68A)),
      'offline' => (l10n.sourceOffline, const Color(0xFFFFC857)),
      'error' => (l10n.sourceError, AppColors.error),
      _ => (l10n.sourceUnknown, AppColors.textMuted),
    };
    final scannedAt = DateTime.tryParse('${source['last_scan_at']}');
    final scanText = scannedAt == null
        ? l10n.neverScanned
        : l10n.lastScan(DateFormat.yMMMd(l10n.localeName)
            .add_Hm()
            .format(scannedAt.toLocal()));
    final count = source['media_count'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            source['protocol'] == 'local'
                ? Icons.folder_rounded
                : Icons.lan_rounded,
            size: scaler.scale(40),
            color: AppColors.text,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${source['name']}',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${source['uri']}',
                    style: AppText.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs / 2),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs / 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: scaler.scale(14), color: statusColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(statusText,
                            style: AppText.label.copyWith(color: statusColor)),
                      ],
                    ),
                    Text(scanText, style: AppText.label),
                    if (count is int)
                      Text(l10n.sourceMediaCount(count), style: AppText.label),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RoundButton(
            key: const ValueKey('source-scan'),
            icon: Icons.refresh_rounded,
            semantic: l10n.rescan,
            onTap: onScan,
          ),
          const SizedBox(width: AppSpacing.sm),
          RoundButton(
            key: const ValueKey('source-remove'),
            icon: Icons.delete_outline_rounded,
            semantic: l10n.removeSource,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.text, required this.confirm});

  final String text;
  final String confirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(text, style: AppText.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  _AutofocusPill(
                    text: l10n.cancel,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  PillButton(
                    key: const ValueKey('confirm-remove'),
                    icon: Icons.delete_outline_rounded,
                    text: confirm,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Annuler » a le focus : retirer un dossier demande un choix explicite.
class _AutofocusPill extends StatelessWidget {
  const _AutofocusPill({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      autofocus: true,
      borderRadius: 999,
      onTap: onTap,
      semanticLabel: text,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child:
          Text(text, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
