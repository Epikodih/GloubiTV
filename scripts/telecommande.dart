// Télécommande simulée, pour tester la lecture sur la TV sans téléphone.
// Écrit en Dart (installé avec Flutter), sans dépendance : marche pareil
// sous Windows, macOS et Linux.
//
//   dart scripts/telecommande.dart appairer 482916 # code affiché par la TV
//   dart scripts/telecommande.dart medias          # médias et leur numéro
//   dart scripts/telecommande.dart lire 3          # lit le média n° 3
//   dart scripts/telecommande.dart pause | reprendre | stop | etat
//
// `dart scripts/telecommande.dart aide` liste toutes les commandes.
// Serveur : http://127.0.0.1:7878, ou la variable EPIKODI_URL.
// Le jeton est gardé dans data/telecommande.json (ignoré par git).
import 'dart:convert';
import 'dart:io';

final baseUrl = Platform.environment['EPIKODI_URL'] ?? 'http://127.0.0.1:7878';

/// Racine du dépôt = dossier parent de scripts/.
final root = File.fromUri(Platform.script).parent.parent.path;
final tokenFile = File('$root/data/telecommande.json');

const aide = '''
Télécommande simulée (serveur : \$EPIKODI_URL, sinon http://127.0.0.1:7878)

  appairer <code>       appaire cette « télécommande » avec le code à 6
                        chiffres affiché par la TV
  medias                médias du profil actif, avec leur numéro
  lire <n°> [--debut]   lit un média (reprise par défaut, --debut : depuis 0)
  pause | reprendre | basculer | stop
  suivant | precedent   média suivant / précédent de la file
  aller <secondes>      va à une position
  avancer <secondes>    avance (ou recule avec un nombre négatif)
  volume <0-100>        règle le volume
  muet | son            coupe / remet le son
  audio <id>            piste audio (id donné par « etat »)
  soustitres <id|non>   sous-titres, ou « non » pour les désactiver
  decalage <ms>         décale les sous-titres (négatif : plus tôt)
  etat                  état du lecteur publié par la TV
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'aide') {
    stdout.write(aide);
    return;
  }
  final cmd = args.first;
  final rest = args.skip(1).toList();
  try {
    switch (cmd) {
      case 'appairer':
        if (rest.isEmpty) return usage('appairer <code affiché par la TV>');
        await appairer(rest.first);
      case 'medias':
        await medias();
      case 'lire':
        final id = int.tryParse(rest.isEmpty ? '' : rest.first);
        if (id == null) return usage('lire <n°> [--debut]');
        final r = await call('POST', '/api/player/play',
            {'media_id': id, 'resume': !rest.contains('--debut')});
        afficherEtat(r);
      case 'etat':
        afficherEtat(await call('GET', '/api/player'));
      case 'pause':
        await commande({'action': 'pause'});
      case 'reprendre':
        await commande({'action': 'play'});
      case 'basculer':
        await commande({'action': 'toggle'});
      case 'stop':
        await commande({'action': 'stop'});
      case 'suivant':
        await commande({'action': 'next'});
      case 'precedent':
        await commande({'action': 'previous'});
      case 'aller':
        await commande({'action': 'seek', 'position_s': nombre(rest)});
      case 'avancer':
        await commande({'action': 'seek_relative', 'delta_s': nombre(rest)});
      case 'volume':
        await commande({'action': 'volume', 'level': nombre(rest).round()});
      case 'muet':
        await commande({'action': 'mute'});
      case 'son':
        await commande({'action': 'unmute'});
      case 'audio':
        await commande({'action': 'audio_track', 'id': nombre(rest).round()});
      case 'soustitres':
        final off = rest.isNotEmpty && rest.first == 'non';
        await commande({
          'action': 'subtitle_track',
          'id': off ? null : nombre(rest).round(),
        });
      case 'decalage':
        await commande(
            {'action': 'subtitle_delay', 'delay_ms': nombre(rest).round()});
      default:
        stderr.write('Commande inconnue : $cmd\n\n$aide');
        exitCode = 64;
    }
  } on Erreur catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } on SocketException {
    stderr.writeln('Serveur injoignable sur $baseUrl : lance `just core`.');
    exitCode = 1;
  } finally {
    _http.close(force: true); // sinon le script attend la fin des connexions
  }
}

void usage(String forme) {
  stderr.writeln('Usage : dart scripts/telecommande.dart $forme');
  exitCode = 64;
}

num nombre(List<String> rest) {
  final n = num.tryParse(rest.isEmpty ? '' : rest.first);
  if (n == null) throw Erreur('Il faut un nombre après la commande.');
  return n;
}

class Erreur implements Exception {
  Erreur(this.message);
  final String message;
}

// ------------------------------------------------------------------ HTTP

final _http = HttpClient();

/// Appel JSON. Avec [auth], ajoute le jeton de la télécommande.
Future<Map<String, dynamic>> call(String method, String path,
    [Object? body, bool auth = true]) async {
  final req = await _http.openUrl(method, Uri.parse('$baseUrl$path'));
  req.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (auth) {
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${lireJeton()}');
  }
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  if (res.statusCode >= 300) {
    final err = json is Map ? json['error'] : null;
    final code = err is Map ? err['code'] : res.statusCode;
    final msg = err is Map ? err['message'] : text;
    if (code == 'unauthorized') {
      throw Erreur('Jeton refusé : relance `appairer`.');
    }
    throw Erreur('Refusé ($code) : $msg');
  }
  return json is Map<String, dynamic> ? json : {'items': json};
}

String lireJeton() {
  if (!tokenFile.existsSync()) {
    throw Erreur('Pas encore appairé : lance `dart scripts/telecommande.dart '
        'appairer` pendant que la TV affiche son code.');
  }
  return (jsonDecode(tokenFile.readAsStringSync()) as Map)['token'] as String;
}

// ------------------------------------------------------------- commandes

Future<void> appairer(String code) async {
  final res = await call(
      'POST',
      '/api/remote/pair',
      {
        'code': code,
        'device': {
          'name': 'Télécommande simulée',
          'install_id': 'script-telecommande',
          'platform': 'android',
        },
      },
      false);
  tokenFile.parent.createSync(recursive: true);
  tokenFile.writeAsStringSync(jsonEncode({'token': res['token']}));
  stdout.writeln('Appairée avec le code $code. La TV passe au choix du '
      'profil.');
}

Future<void> medias() async {
  final res = await call('GET', '/api/media?limit=200');
  final items = (res['items'] as List? ?? const []).cast<Map>();
  if (items.isEmpty) {
    stdout.writeln('Aucun média : choisis un profil sur la TV, puis ajoute '
        'un dossier (Paramètres > Dossiers du media center).');
    return;
  }
  for (final m in items) {
    final missing = m['status'] == 'missing' ? '  (indisponible)' : '';
    stdout.writeln(
        '${'${m['id']}'.padLeft(4)}  ${'${m['kind']}'.padRight(8)} ${m['title']}$missing');
  }
}

Future<void> commande(Map<String, dynamic> body) async =>
    afficherEtat(await call('POST', '/api/player/command', body));

void afficherEtat(Map<String, dynamic> s) {
  final now = s['now_playing'];
  final titre = now is Map ? now['title'] : '—';
  String temps(Object? v) {
    if (v is! num) return '--:--';
    final d = Duration(milliseconds: (v * 1000).round());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$sec';
  }

  String pistes(Object? list, Object? actif) => list is List && list.isNotEmpty
      ? list.map((t) {
          final nom = [t['title'], t['lang']].whereType<String>().join(' · ');
          final ad = t['audio_description'] == true ? ' · AD' : '';
          return '${t['id'] == actif ? '*' : ' '}${t['id']} $nom$ad';
        }).join('   ')
      : 'aucune';

  stdout.writeln('${s['status']} · $titre · ${temps(s['position_s'])} / '
      '${temps(s['duration_s'])} · volume ${s['volume']}'
      '${s['muted'] == true ? ' (muet)' : ''}');
  stdout
      .writeln('  audio      : ${pistes(s['audio_tracks'], s['audio_track'])}');
  stdout.writeln(
      '  sous-titres: ${pistes(s['subtitle_tracks'], s['subtitle_track'])}');
}
