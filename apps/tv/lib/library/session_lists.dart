/// Favoris et « À regarder » d'un invité, gardés par la TV le temps de la
/// session seulement.
///
/// Un invité n'existe pas en base : le serveur ne garde pas ses listes
/// (`guest_forbidden`). La médiathèque garde donc les médias ici, en mémoire.
/// Tout est perdu en changeant de profil ou en relançant l'app.
class SessionLists {
  final _lists = <String, Map<Object?, Map<String, dynamic>>>{
    'favorite': {},
    'watchlist': {},
  };

  /// [list] : `favorite` ou `watchlist` (comme les routes du serveur).
  bool contains(String list, Object? id) => _lists[list]!.containsKey(id);

  void set(String list, Map<String, dynamic> item, bool add) {
    final map = _lists[list]!;
    if (add) {
      map[item['id']] = item;
    } else {
      map.remove(item['id']);
    }
  }

  /// Médias de la liste, du plus récent au plus ancien ajout.
  List<Map<String, dynamic>> items(String list) =>
      _lists[list]!.values.toList().reversed.toList();
}
