// Faux canal vers le cœur : le test pousse les événements et lit les états
// publiés par la TV.
import 'dart:async';

import 'package:epikodi_tv/player/server_player.dart';

class FakePlayerLink implements PlayerLink {
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  /// États publiés (`POST /api/player/state`), dans l'ordre.
  final reports = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Envoie une commande `player.command` à la TV.
  void command(Map<String, dynamic> data) =>
      _events.add({'type': 'player.command', 'data': data});

  /// Envoie un événement brut (`{"type", "data"}`).
  void event(Map<String, dynamic> e) => _events.add(e);

  /// Statuts publiés, dans l'ordre.
  List<String> get statuses => [for (final r in reports) r['status'] as String];

  @override
  Future<void> report(Map<String, dynamic> state) async => reports.add(state);

  @override
  void close() {
    closed = true;
    _events.close();
  }
}
